module VMCAppfog
  class BindAll < VMC::CLI
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

    private

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
