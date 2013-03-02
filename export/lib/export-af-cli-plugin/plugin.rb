require "vmc/cli"

module AFCLIExport
  class Export < VMC::CLI
    desc "Bind all services in one app to another."
    group :services, :manage
    input :src_app, :desc => "Source application", :argument => :optional,
          :from_given => by_name(:app)
    input :dest_app, :desc => "Destination application", :argument => :optional,
          :from_given => by_name(:app)
    def bind_services
      src_app = input[:src_app]
      fail "No services to bind." if src_app.services.empty?

      dest_app = input[:dest_app]

      src_app.services.each do |service|
        with_progress("Binding service #{c(service.name, :name)} to #{c(dest_app.name, :name)}") do |s|
          if dest_app.binds?(service)
            s.skip do
              err "App #{b(dest_app.name)} already binds #{b(service.name)}."
            end
          else
            dest_app.bind(service)
          end
        end
      end
    end

    desc "Export the data from a service"
    group :services, :manage
    input :export_service, :desc => "Service to export", :argument => :optional,
          :from_given => by_name(:service_instance, "service")
    def export_service
      service = input[:export_service]

      export_info =
        with_progress("Exporting service #{c(service.name, :name)}") do
          client.export_service(service.name)
        end

      line unless quiet?

      line "#{c(service.name, :name)} exported to: #{export_info[:uri]}"
    end

    desc "Import data from url"
    group :services, :manage
    input :import_service, :desc => "Service to import data to", :argument => :optional,
          :from_given => by_name(:service_instance, "service")
    input :url, :desc => "Data url to import", :argument => :optional
    def import_service
      service = input[:import_service]
      url = input[:url]

      import_info =
        with_progress("Importing data to service #{c(service.name, :name)}") do
          client.import_service(service.name, url)
        end

      line unless quiet?

      line "Data imported to #{c(service.name, :name)} successfully "
    end

    private

    def ask_url
      ask("Url to import from")
    end

    def ask_export_service
      services = client.service_instances
      fail "No services." if services.empty?

      ask("Export which service?", :choices => services.sort_by(&:name),
          :display => proc(&:name))
    end

    def ask_import_service
      services = client.service_instances
      fail "No services." if services.empty?

      ask("Import to which service?", :choices => services.sort_by(&:name),
          :display => proc(&:name))
    end

    def ask_src_app
      apps = client.apps
      fail "No applications." if apps.empty?

      ask("Which source application?", :choices => apps.sort_by(&:name),
          :display => proc(&:name))
    end

    def ask_dest_app
      apps = client.apps
      fail "No applications." if apps.empty?

      ask("Which destination application?", :choices => apps.sort_by(&:name),
          :display => proc(&:name))
    end
  end
end