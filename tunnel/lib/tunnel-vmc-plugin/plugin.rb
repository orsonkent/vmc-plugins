require "vmc/cli"
require "tunnel-vmc-plugin/tunnel"

module VMCTunnel
  class Tunnel < VMC::CLI
    CLIENTS_FILE = "#{VMC::CONFIG_DIR}/tunnel-clients.yml"
    STOCK_CLIENTS = File.expand_path("../../../config/clients.yml", __FILE__)

    desc "Create a local tunnel to a service."
    group :services, :manage
    input(:instance, :argument => :optional,
          :from_given => find_by_name("service instance"),
          :desc => "Service instance to tunnel to") { |instances|
      ask("Which service instance?", :choices => instances,
          :display => proc(&:name))
    }
    input(:client, :argument => :optional,
          :desc => "Client to automatically launch") { |clients|
      if clients.empty?
        "none"
      else
        ask("Which client would you like to start?",
            :choices => clients.keys.unshift("none"))
      end
    }
    input(:port, :default => 10000, :desc => "Port to bind the tunnel to")
    def tunnel
      instances = client.service_instances
      fail "No services available for tunneling." if instances.empty?

      instance = input[:instance, instances.sort_by(&:name)]
      clients = tunnel_clients[instance.vendor] || {}
      client_name = input[:client, clients]

      tunnel = CFTunnel.new(client, instance)
      port = tunnel.pick_port!(input[:port])

      conn_info =
        with_progress("Opening tunnel on port #{c(port, :name)}") do
          tunnel.open!
        end

      if client_name == "none"
        unless quiet?
          line
          display_tunnel_connection_info(conn_info)

          line
          line "Open another shell to run command-line clients or"
          line "use a UI tool to connect using the displayed information."
          line "Press Ctrl-C to exit..."
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

    private

    def display_tunnel_connection_info(info)
      line "Service connection info:"

      to_show = [nil, nil, nil] # reserved for user, pass, db name
      info.keys.each do |k|
        case k
        when "host", "hostname", "port", "node_id"
          # skip
        when "user", "username"
          # prefer "username" over "user"
          to_show[0] = k unless to_show[0] == "username"
        when "password"
          to_show[1] = k
        when "name"
          to_show[2] = k
        else
          to_show << k
        end
      end
      to_show.compact!

      align_len = to_show.collect(&:size).max + 1

      indented do
        to_show.each do |k|
          # TODO: modify the server services rest call to have explicit knowledge
          # about the items to return.  It should return all of them if
          # the service is unknown so that we don't have to do this weird
          # filtering.
          line "#{k.ljust align_len}: #{b(info[k])}"
        end
      end

      line
    end

    def start_local_prog(clients, command, info, port)
      client = clients[File.basename(command)]

      cmdline = "#{command} "

      case client
      when Hash
        cmdline << resolve_symbols(client["command"], info, port)
        client["environment"].each do |e|
          if e =~ /([^=]+)=(["']?)([^"']*)\2/
            ENV[$1] = resolve_symbols($3, info, port)
          else
            fail "Invalid environment variable: #{e}"
          end
        end
      when String
        cmdline << resolve_symbols(client, info, port)
      else
        raise "Unknown client info: #{client.inspect}."
      end

      if verbose?
        line
        line "Launching '#{cmdline}'"
      end

      system(cmdline)
    end

    def tunnel_clients
      return @tunnel_clients if @tunnel_clients

      stock = YAML.load_file(STOCK_CLIENTS)
      clients = File.expand_path CLIENTS_FILE
      if File.exists? clients
        user = YAML.load_file(clients)
        @tunnel_clients = deep_merge(stock, user)
      else
        @tunnel_clients = stock
      end
    end

    def resolve_symbols(str, info, local_port)
      str.gsub(/\$\{\s*([^\}]+)\s*\}/) do
        sym = $1

        case sym
        when "host"
          # TODO: determine proper host
          "localhost"
        when "port"
          local_port
        when "user", "username"
          info["username"]
        when /^ask (.+)/
          ask($1)
        else
          info[sym] || raise("Unknown symbol in config: #{sym}")
        end
      end
    end

    def deep_merge(a, b)
      merge = proc { |old, new|
        if old === Hash && new === Hash
          old.merge(new, &merge)
        else
          new
        end
      }

      a.merge(b, &merge)
    end
  end
end
