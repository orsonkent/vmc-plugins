module Net
  class HTTP
    HTTP_TIMEOUT = ENV['TIMEOUT'] ? ENV['TIMEOUT'].to_i : 10*60

    alias _request_ request
    def request(req, body=nil, &block)
      @socket.read_timeout = HTTP_TIMEOUT
      return _request_(req, body, &block)
    end
  end
end