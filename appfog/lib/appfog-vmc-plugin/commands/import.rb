module VMCAppfog
  class Import < VMC::CLI
    desc "Import data from url"
    group :services, :manage
    input :service, :desc => "Service to import data to", :argument => :optional,
          :from_given => by_name(:service_instance, "service")
    input :url, :desc => "Data url to import", :argument => :optional
    def import_service
      service = input[:service]
      url = input[:url]

      import_info =
        with_progress("Importing data to service #{c(service.name, :name)}") do
          client.import_service(service.name, url)
        end

      line unless quiet?

      line "Data imported to #{c(service.name, :name)} successfully "
    end

    private

    def ask_service
      services = client.service_instances
      fail "No services." if services.empty?

      ask("Import to which service?", :choices => services.sort_by(&:name),
          :display => proc(&:name))
    end
  end
end