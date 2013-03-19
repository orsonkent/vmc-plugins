module VMCAppfog
  class Clone < VMC::CLI
    desc "Clone the application and services"
    group :apps, :manage
    input :src_app, :desc => "Source application", :argument => :optional,
          :from_given => by_name(:app)
    input :name,    :desc => "Application name", :argument => :optional
    input :infra,   :desc => "Infrastructure to use", :from_given => by_name(:infra)
    input :url,     :desc => "Application url", :argument => :optional
    input :nostart, :desc => "Do not start app", :default => false
    def clone
      src_app = input[:src_app]
      dest_infra = input[:infra]
      dest_app_name = input[:name, "#{src_app.name}-#{"%04x" % [rand(0x0100000)]}"]
      app = client.app_by_name(dest_app_name)
      fail "Application '#{dest_app_name}' already exists" unless app.nil?
      dest_url = input[:url, "#{dest_app_name}.#{dest_infra.base}"]

      # Start Clone
      Dir.mktmpdir do |dir|

        # Download source
        zip_path = File.join(dir, src_app.name)
        with_progress("Pulling last pushed source code") do
          client.app_pull(src_app.name, zip_path)
        end

        # manifest = {
        #   :name => "#{dest_appname}",
        #   :staging => app[:staging],
        #   :uris => [ url ],
        #   :instances => app[:instances],
        #   :resources => app[:resources]
        # }
        # manifest[:staging][:command] = app[:staging][:command] if app[:staging][:command]
        # manifest[:infra] = { :provider => dest_infra.name } if dest_infra

        dest_app = client.app
        dest_app.name = dest_app_name
        dest_app.infra = dest_infra
        dest_app.url = dest_url
        dest_app.uris = [dest_url]
        dest_app.total_instances = 1
        dest_app.framework = src_app.framework
        dest_app.command = src_app.command unless src_app.command.nil?
        dest_app.runtime = src_app.runtime
        dest_app.memory = src_app.memory
        dest_app.env = src_app.env
        dest_app = filter(:create_app, dest_app)
        with_progress("Creating #{c(dest_app.name, :name)}") do
          dest_app.create!
        end

        # Upload source
        with_progress("Uploading source to #{c(dest_app.name, :name)}") do
          dest_app.upload(zip_path)
        end

        # Clone services
        src_app.services.each do |src_service|

          # Export service data
          export_info =
            with_progress("Exporting service #{c(src_service.name, :name)}") do
              client.export_service(src_service.name)
            end

          export_url = export_info[:uri]

          # Create new service
          cloned_service_name = generate_cloned_service_name(src_app.name, dest_app_name, src_service.name, dest_infra.name)
          dest_service = client.service_instance
          dest_service.infra_name = dest_infra.name
          dest_service.name = cloned_service_name
          dest_service.type = src_service.type
          dest_service.vendor = src_service.vendor
          dest_service.version = src_service.version.to_s
          dest_service.tier = src_service.tier
          with_progress("Creating service #{c(dest_service.name, :name)}") do
            dest_service.create!
          end

          # Bind new service to app
          with_progress("Binding service #{c(dest_service.name, :name)} to #{c(dest_app.name, :name)}") do 
            dest_app.bind(dest_service)
          end

          # Import service data
          import_info =
            with_progress("Importing data to service #{c(dest_service.name, :name)}") do
              client.import_service(dest_service.name, export_url)
            end
        end

        if !input[:nostart]
          with_progress("Starting #{c(dest_app.name, :name)}") do 
            dest_app.start!
          end
        end

      end
    end

    private

    def ask_url(default)
      ask("New application url?", :default => default)
    end

    def ask_name(default)
      ask("New application name?", :default => default)
    end

    def ask_infra
      ask("Which Infrastructure?", :choices => client.infras,
        :display => proc(&:name))
    end

    def generate_cloned_service_name(src_appname, dest_appname, src_servicename, dest_infra)
      r = "%04x" % [rand(0x0100000)]
      dest_servicename = src_servicename.sub(src_appname, dest_appname).sub(/-[0-9A-Fa-f]{4,5}/,"-#{r}")
      if src_servicename == dest_servicename
        if dest_infra
          dest_servicename = "#{dest_servicename}-#{dest_infra}"
        else
          dest_servicename = "#{dest_servicename}-#{r}"
        end
      end
      dest_servicename
    end
  end
end