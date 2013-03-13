module CFoundry
  class BaseClient
    def get(*args)
      options = args.reduce({}) do |opts, arg|
        arg.is_a?(Hash) ? arg : opts
      end
      tries = options.has_key?(:retry) && options[:retry] == false ? 1 : 3
      delay = options.has_key?(:delay) ? options[:delay] : 10
      with_retry(tries, delay, [CFoundry::TargetRefused, CFoundry::BadResponse]) do
        request("GET", *args)
      end
    end

    def with_retry(tries, delay=2, exceptions=[])
      try_count = 0
      loop do
        begin
          try_count += 1
          return yield
        rescue Exception => e
          if try_count > tries || !exceptions.include?(e.class)
            raise e
          end
          sleep delay * try_count
        end
      end
    end
  end
end
