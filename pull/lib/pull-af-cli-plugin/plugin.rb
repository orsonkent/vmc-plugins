require "vmc/cli"
require "pull-af-cli-plugin/help"

module AFCLIPull
  class Pull < VMC::CLI
    desc "Downloads last pushed source to app name or path"
    group :apps, :download
    input :app, :desc => "Application to pull", :argument => :optional,
          :from_given => by_name(:app)
    input :path,      :desc => "Path to store app"
    def pull
      app = input[:app]
      path = File.expand_path(input[:path] || app.name)

      with_progress("Pulling last pushed source code to #{c(app.name, :name)}") do
        client.app_pull(app.name, path)
      end
    end

    desc "Downloads last pushed source to zipfile"
    group :apps, :download
    input :app, :desc => "Application to pull", :argument => :optional,
          :from_given => by_name(:app)
    input :path,      :desc => "Path to store app"
    def download
      app = input[:app]
      path = File.expand_path(input[:path] || "#{app.name}.zip")
      with_progress("Downloading last pushed source code to #{c(path, :path)}") do
        client.app_download(app.name, path)
      end
    end

    def ask_app
      apps = client.apps
      fail "No applications." if apps.empty?

      ask("Which application?", :choices => apps.sort_by(&:name),
          :display => proc(&:name))
    end
  end
end