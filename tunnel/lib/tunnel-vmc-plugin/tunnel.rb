require "addressable/uri"

begin
  require "caldecott"
rescue LoadError
end

module VMCTunnel
  PORT_RANGE = 10

  CLIENTS_FILE = "#{VMC::CONFIG_DIR}/tunnel-clients.yml"

  HELPER_APP = File.expand_path("../../../helper-app", __FILE__)
  STOCK_CLIENTS = File.expand_path("../../../config/clients.yml", __FILE__)

  # bump this AND the version info reported by HELPER_APP/server.rb
  # this is to keep the helper in sync with any updates here
  HELPER_VERSION = "0.0.4"

  def tunnel_uniquename
    random = sprintf("%x", rand(1000000))
    "caldecott-#{random}"
  end

  def tunnel_appname
    "caldecott"
  end

  def tunnel_app
    @tunnel_app ||= client.app(tunnel_appname)
  end

  def tunnel_auth
    tunnel_app.env.each do |e|
      name, val = e.split("=", 2)
      return val if name == "CALDECOTT_AUTH"
    end
    nil
  end

  def tunnel_url
    return @tunnel_url if @tunnel_url

    tun_url = tunnel_app.url

    ["https", "http"].each do |scheme|
      url = "#{scheme}://#{tun_url}"
      begin
        RestClient.get(url)

      # https failed
      rescue Errno::ECONNREFUSED

      # we expect a 404 since this request isn't auth'd
      rescue RestClient::ResourceNotFound
        return @tunnel_url = url
      end
    end

    raise "Cannot determine URL for #{tun_url}"
  end

  def tunnel_pushed?
    tunnel_app.exists?
  end

  def tunnel_healthy?(token)
    return false unless tunnel_app.healthy?

    begin
      response = RestClient.get(
        "#{tunnel_url}/info",
        "Auth-Token" => token
      )

      info = JSON.parse(response)
      if info["version"] == HELPER_VERSION
        true
      else
        stop_helper
        false
      end
    rescue RestClient::Exception
      stop_helper
      false
    end
  end

  def tunnel_binds?(service)
    tunnel_app.services.include? service
  end

  def tunnel_connection_info(type, service, token)
    response = nil
    10.times do
      begin
        response =
          RestClient.get(
            tunnel_url + "/" + safe_path("services", service),
            "Auth-Token" => token)

        break
      rescue RestClient::Exception
        sleep 1
      end
    end

    unless response
      raise "Remote tunnel helper is unaware of #{service}!"
    end

    info = JSON.parse(response)
    case type
    when "rabbitmq"
      uri = Addressable::URI.parse info["url"]
      info["hostname"] = uri.host
      info["port"] = uri.port
      info["vhost"] = uri.path[1..-1]
      info["user"] = uri.user
      info["password"] = uri.password
      info.delete "url"

    # we use "db" as the "name" for mongo
    # existing "name" is junk
    when "mongodb"
      info["name"] = info["db"]
      info.delete "db"

    # our "name" is irrelevant for redis
    when "redis"
      info.delete "name"
    end

    ["hostname", "port", "password"].each do |k|
      raise "Could not determine #{k} for #{service}" if info[k].nil?
    end

    info
  end

  def display_tunnel_connection_info(info)
    puts "Service connection info: "

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

    to_show.each do |k|
      # TODO: modify the server services rest call to have explicit knowledge
      # about the items to return.  It should return all of them if
      # the service is unknown so that we don't have to do this weird
      # filtering.
      print "  #{k.ljust align_len}: "
      puts c("#{info[k]}", :yellow)
    end

    puts ""
  end

  def start_tunnel(local_port, conn_info, auth)
    @local_tunnel_thread = Thread.new do
      Caldecott::Client.start({
        :local_port => local_port,
        :tun_url => tunnel_url,
        :dst_host => conn_info["hostname"],
        :dst_port => conn_info["port"],
        :log_file => STDOUT,
        :log_level => ENV["VMC_TUNNEL_DEBUG"] || "ERROR",
        :auth_token => auth,
        :quiet => true
      })
    end

    at_exit { @local_tunnel_thread.kill }
  end

  def pick_tunnel_port(port)
    original = port

    PORT_RANGE.times do |n|
      begin
        TCPSocket.open("localhost", port)
        port += 1
      rescue
        return port
      end
    end

    grab_ephemeral_port
  end

  def wait_for_tunnel_start(port)
    10.times do |n|
      begin
        TCPSocket.open("localhost", port).close
        return true
      rescue => e
        sleep 1
      end
    end

    raise "Could not connect to local tunnel."
  end

  def wait_for_tunnel_end
    @local_tunnel_thread.join
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
          raise "Invalid environment variable: #{e}"
        end
      end
    when String
      cmdline << resolve_symbols(client, info, port)
    else
      raise "Unknown client info: #{client.inspect}."
    end

    if verbose?
      puts ""
      puts "Launching '#{cmdline}'"
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

  def push_helper(token, service = nil)
    target_base = client.target.sub(/^[^\.]+\./, "")

    app = client.app(tunnel_appname)
    app.framework = "sinatra"
    app.url = "#{tunnel_uniquename}.#{target_base}"
    app.total_instances = 1
    app.memory = 64
    app.env = ["CALDECOTT_AUTH=#{token}"]
    app.services = [service] if service
    app.create!

    begin
      app.upload(HELPER_APP)
      invalidate_tunnel_app_info
    rescue
      app.delete!
      raise
    end
  end

  def delete_helper
    tunnel_app.delete!
    invalidate_tunnel_app_info
  end

  def stop_helper
    tunnel_app.stop!
    invalidate_tunnel_app_info
  end

  TUNNEL_CHECK_LIMIT = 60

  def start_helper
    tunnel_app.start!

    seconds = 0
    until tunnel_app.healthy?
      sleep 1
      seconds += 1
      if seconds == TUNNEL_CHECK_LIMIT
        raise "Helper application failed to start."
      end
    end

    invalidate_tunnel_app_info
  end

  def bind_to_helper(service)
    tunnel_app.bind(service)
    tunnel_app.restart!
  end

  private

  def invalidate_tunnel_app_info
    @tunnel_url = nil
    @tunnel_app = nil
  end

  def grab_ephemeral_port
    socket = TCPServer.new("0.0.0.0", 0)
    socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)
    Socket.do_not_reverse_lookup = true
    port = socket.addr[1]
    socket.close
    return port
  end

  def resolve_symbols(str, info, local_port)
    str.gsub(/\$\{\s*([^\}]+)\s*\}/) do
      case $1
      when "host"
        # TODO: determine proper host
        "localhost"
      when "port"
        local_port
      when "user", "username"
        info["username"]
      else
        info[$1] || ask($1)
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

  def safe_path(*segments)
    segments.flatten.collect { |x|
      URI.encode x.to_s, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]")
    }.join("/")
  end
end
