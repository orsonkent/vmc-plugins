require "vmc/cli"

module VMCAdmin
  class Curl < VMC::CLI
    def precondition
      check_target
    end

    desc "Execute a raw request"
    group :admin
    input :mode, :argument => :required,
      :desc => "Request mode (Get/Put/etc.)"
    input :path, :argument => :required,
      :desc => "Request path"
    input :headers, :argument => :splat,
      :desc => "Headers (i.e. Foo: bar)"
    input :body, :alias => "-b",
      :desc => "Request body"
    def curl
      mode = input[:mode].upcase
      path = input[:path]
      body = input[:body]

      headers = {}
      input[:headers].each do |h|
        k, v = h.split(/\s*:\s*/, 2)
        headers[k.downcase] = v
      end

      content = headers["content-type"]
      accept = headers["accept"]

      content ||= :json if body
      accept ||= :json unless %w(DELETE HEAD).include?(mode)

      req, res =
        client.base.request_raw(
          mode,
          remove_leading_slash(path),
          :headers => headers,
          :accept => accept,
          :payload => body,
          :content => body && content)

      if [:json, "application/json"].include? accept
        puts MultiJson.dump(res, :pretty => true)
      else
        puts res
      end
    end

    def remove_leading_slash(path)
      path.sub(%r{^/}, '')
    end
  end
end
