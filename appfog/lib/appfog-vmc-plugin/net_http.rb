module Net
  class HTTP
    HTTP_TIMEOUT = ENV['TIMEOUT'] ? ENV['TIMEOUT'].to_i : 10*60

    # alias _initialize_ initialize
    # def initialize(address, port = nil, p_addr = :ENV, p_port = nil, p_user = nil, p_pass = nil)
    #   puts address
    #   require 'debugger'; debugger
    #   return _initialize_(address, port)
    # end

    # def HTTP.new(address, port = nil, p_addr = nil, p_port = nil, p_user = nil, p_pass = nil)
    #   Proxy(p_addr, p_port, p_user, p_pass).newobj(address, port)
    # end

    alias _request_ request
    def request(req, body=nil, &block)
      @socket.read_timeout = HTTP_TIMEOUT unless @socket.nil?
      return _request_(req, body, &block)
    end
  end
end