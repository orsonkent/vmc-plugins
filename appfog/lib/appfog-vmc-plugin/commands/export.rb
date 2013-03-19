module VMCAppfog
  class Export < VMC::CLI
    desc "Export the data from a service"
    group :services, :manage
    input :service, :desc => "Service to export", :argument => :optional,
          :from_given => by_name(:service_instance, "service")
    def export_service
      service = input[:service]

      export_info =
        with_progress("Exporting service #{c(service.name, :name)}") do
          client.export_service(service.name)
        end

      line unless quiet?

      line "#{c(service.name, :name)} exported to: #{export_info[:uri]}"
    end

    private

    def ask_url
      ask("Url to import from")
    end

    def ask_service
      services = client.service_instances
      fail "No services." if services.empty?

      ask("Export which service?", :choices => services.sort_by(&:name),
          :display => proc(&:name))
    end
  end
end