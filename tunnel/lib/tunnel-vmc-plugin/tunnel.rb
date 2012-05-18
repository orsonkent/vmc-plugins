require "addressable/uri"

begin
  require "caldecott"
rescue LoadError
end

class CFTunnel
  HELPER_NAME = "caldecott"
  HELPER_APP = File.expand_path("../../../helper-app", __FILE__)

  # bump this AND the version info reported by HELPER_APP/server.rb
  # this is to keep the helper in sync with any updates here
  HELPER_VERSION = "0.0.4"

  def initialize(client, service, port = 10000)
    @client = client
    @service = service
    @port = port
  end

  def open!
    if helper.exists?
      auth = helper_auth

      unless helper_healthy?(auth)
        delete_helper
        auth = create_helper
      end
    else
      auth = create_helper
    end

    bind_to_helper unless helper_already_binds?

    info = get_connection_info(auth)

    start_tunnel(info, auth)

    info
  end

  def wait_for_start
    10.times do |n|
      begin
        TCPSocket.open("localhost", @port).close
        return true
      rescue => e
        sleep 1
      end
    end

    raise "Could not connect to local tunnel."
  end

  def wait_for_end
    if @local_tunnel_thread
      @local_tunnel_thread.join
    else
      raise "Tunnel wasn't started!"
    end
  end

  PORT_RANGE = 10
  def pick_port!(port = @port)
    original = port

    PORT_RANGE.times do |n|
      begin
        TCPSocket.open("localhost", port)
        port += 1
      rescue
        return @port = port
      end
    end

    @port = grab_ephemeral_port
  end

  private

  def helper
    @helper ||= @client.app(HELPER_NAME)
  end

  def create_helper
    auth = UUIDTools::UUID.random_create.to_s
    push_helper(auth)
    start_helper
    auth
  end

  def helper_auth
    helper.env.each do |e|
      name, val = e.split("=", 2)
      return val if name == "CALDECOTT_AUTH"
    end

    nil
  end

  def helper_healthy?(token)
    return false unless helper.healthy?

    begin
      response = RestClient.get(
        "#{helper_url}/info",
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

  def helper_already_binds?
    helper.services.include? @service.name
  end

  def push_helper(token)
    target_base = @client.target.sub(/^[^\.]+\./, "")

    app = @client.app(HELPER_NAME)
    app.framework = "sinatra"
    app.url = "#{random_helper_url}.#{target_base}"
    app.total_instances = 1
    app.memory = 64
    app.env = ["CALDECOTT_AUTH=#{token}"]
    app.services = [@service.name]
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
    helper.delete!
    invalidate_tunnel_app_info
  end

  def stop_helper
    helper.stop!
    invalidate_tunnel_app_info
  end

  TUNNEL_CHECK_LIMIT = 60
  def start_helper
    helper.start!

    seconds = 0
    until helper.healthy?
      sleep 1
      seconds += 1
      if seconds == TUNNEL_CHECK_LIMIT
        raise "Helper application failed to start."
      end
    end

    invalidate_tunnel_app_info
  end

  def bind_to_helper
    helper.bind(@service.name)
    helper.restart!
  end

  def invalidate_tunnel_app_info
    @helper_url = nil
    @helper = nil
  end

  def helper_url
    return @helper_url if @helper_url

    tun_url = helper.url

    ["https", "http"].each do |scheme|
      url = "#{scheme}://#{tun_url}"
      begin
        RestClient.get(url)

      # https failed
      rescue Errno::ECONNREFUSED

      # we expect a 404 since this request isn't auth'd
      rescue RestClient::ResourceNotFound
        return @helper_url = url
      end
    end

    raise "Cannot determine URL for #{tun_url}"
  end

  def get_connection_info(token)
    response = nil
    10.times do
      begin
        response =
          RestClient.get(
            helper_url + "/" + safe_path("services", @service.name),
            "Auth-Token" => token)

        break
      rescue RestClient::Exception => e
        p [e, e.to_s]
        sleep 1
      end
    end

    unless response
      raise "Remote tunnel helper is unaware of #{@service.name}!"
    end

    info = JSON.parse(response)
    case @service.vendor
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
      raise "Could not determine #{k} for #{@service.name}" if info[k].nil?
    end

    info
  end

  def start_tunnel(conn_info, auth)
    @local_tunnel_thread = Thread.new do
      Caldecott::Client.start({
        :local_port => @port,
        :tun_url => helper_url,
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

  def random_helper_url
    random = sprintf("%x", rand(1000000))
    "caldecott-#{random}"
  end

  def safe_path(*segments)
    segments.flatten.collect { |x|
      URI.encode x.to_s, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]")
    }.join("/")
  end

  def grab_ephemeral_port
    socket = TCPServer.new("0.0.0.0", 0)
    socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)
    Socket.do_not_reverse_lookup = true
    socket.addr[1]
  ensure
    socket.close
  end
end

module VMCTunnel
  CLIENTS_FILE = "#{VMC::CONFIG_DIR}/tunnel-clients.yml"
  STOCK_CLIENTS = File.expand_path("../../../config/clients.yml", __FILE__)

  def display_tunnel_connection_info(info)
    puts "Service connection info:"

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
end
