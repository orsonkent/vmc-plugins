require "vmc/plugin"
require File.expand_path("../tunnel", __FILE__)

VMC.Plugin(VMC::Service) do
  include VMCTunnel

  desc "tunnel SERVICE [CLIENT]", "create a local tunnel to a service"
  flag(:service) { |choices|
    ask("Which service?", :choices => choices)
  }
  flag(:client)
  flag(:port, :default => 10000)
  def tunnel(service = nil, client_name = nil)
    unless defined? Caldecott
      $stderr.puts "To use `vmc tunnel', you must first install Caldecott:"
      $stderr.puts ""
      $stderr.puts "\tgem install caldecott"
      $stderr.puts ""
      $stderr.puts "Note that you'll need a C compiler. If you're on OS X, Xcode"
      $stderr.puts "will provide one. If you're on Windows, try DevKit."
      $stderr.puts ""
      $stderr.puts "This manual step will be removed in the future."
      $stderr.puts ""
      err "Caldecott is not installed."
      return
    end

    client_name ||= input(:client)

    services = client.services
    if services.empty?
      err "No services available to tunnel to"
      return
    end

    service ||= input(:service, services.collect(&:name).sort)

    info = services.find { |s| s.name == service }

    unless info
      err "Unknown service '#{service}'"
      return
    end

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
      with_progress("Opening tunnel on port #{c(port, :blue)}") do
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
        err "'#{client_name}' execution failed; is it in your $PATH?"
      end
    end
  end
end
