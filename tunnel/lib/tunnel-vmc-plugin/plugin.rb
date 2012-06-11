require "vmc/plugin"
require File.expand_path("../tunnel", __FILE__)

VMC.Plugin(VMC::Service) do
  include VMCTunnel

  desc "tunnel [SERVICE] [CLIENT]", "Create a local tunnel to a service."
  group :services, :manage
  flag(:service) { |choices|
    ask("Which service?", :choices => choices)
  }
  flag(:client)
  flag(:port, :default => 10000)
  def tunnel(service = nil, client_name = nil)
    client_name ||= input(:client)

    services = client.services

    fail "No services available for tunneling." if services.empty?

    service ||= input(:service, services.collect(&:name).sort)

    info = services.find { |s| s.name == service }

    fail "Unknown service '#{service}'" unless info

    clients = tunnel_clients[info.vendor] || {}

    unless client_name
      if clients.empty?
        client_name = "none"
      else
        client_name = ask(
          "Which client would you like to start?",
          :choices => ["none"] + clients.keys)
      end
    end

    tunnel = CFTunnel.new(client, info)
    port = tunnel.pick_port!(input(:port))

    conn_info =
      with_progress("Opening tunnel on port #{c(port, :name)}") do
        tunnel.open!
      end

    if client_name == "none"
      unless simple_output?
        puts ""
        display_tunnel_connection_info(conn_info)

        puts ""
        puts "Open another shell to run command-line clients or"
        puts "use a UI tool to connect using the displayed information."
        puts "Press Ctrl-C to exit..."
      end

      tunnel.wait_for_end
    else
      with_progress("Waiting for local tunnel to become available") do
        tunnel.wait_for_start
      end

      unless start_local_prog(clients, client_name, conn_info, port)
        fail "'#{client_name}' execution failed; is it in your $PATH?"
      end
    end
  end
end
