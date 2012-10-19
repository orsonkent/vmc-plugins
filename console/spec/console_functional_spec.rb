require "vmc/spec_helpers"
require "console-vmc-plugin/plugin"

describe "VMCConsole#console" do
  before(:all) do
    rails_app = File.expand_path("../assets/rails328_ruby187_app", __FILE__)
    @name = "app-#{random_str}"
    client.app_by_name(@name).should_not be

    @app = client.app
    @app.name = @name
    @app.space = client.current_space if client.current_space
    @app.framework = client.framework_by_name("rails3")
    @app.runtime = client.runtime_by_name("ruby18")
    @app.memory = client.is_a?(CFoundry::V2::Client) ? 128 : "128M"
    @app.total_instances = 1
    @app.console = true
    @app.create!

    @app.upload(rails_app)
    @app.start!

    @caldecott = client.app_by_name("caldecott")
    @caldecott_running = @caldecott.running? if @caldecott
  end

  after(:all) do
    if created = client.app_by_name(@name)
      created.delete!
    end

    if @caldecott
      client.app_by_name("caldecott").stop! unless @caldecott_running
    else
      client.app_by_name("caldecott").delete!
    end
  end

  it "runs with args APP" do
    running(:console, :app => @app) do
      does("Opening console on port 10000")
      kill
    end
  end

  it "runs with args APP and PORT" do
    port = "10024"
    running(:console, :app => @app, :port => port) do
      does("Opening console on port #{port}")
      kill
    end
  end
end