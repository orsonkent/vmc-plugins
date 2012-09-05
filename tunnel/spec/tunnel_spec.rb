require "vmc/spec_helpers"
require "tunnel-vmc-plugin/plugin"

describe "VMCtunnel#tunnel" do
  before(:all) do
    instance_name = "postgres-#{random_str}"
    client.service_instance_by_name(instance_name).should_not be
    psql_service = client.services.find { |svc| svc.label == "postgresql" }

    @instance = client.service_instance
    @instance.name = instance_name

    if client.is_a?(CFoundry::V2::Client)
      @instance.service_plan = psql_service.service_plans.first
      @instance.space = client.current_space
    else
      @instance.type = psql_service.type
      @instance.vendor = psql_service.label
      @instance.version = psql_service.version
      @instance.tier = "free"
    end

    @instance.create!
  end

  after(:all) do
    @instance.delete!
  end

  it "runs with no arguments" do
    running(:tunnel) do
      asks("Which service instance?")
      given(@instance.name)
      has_input(:instance, @instance)

      asks("Which client would you like to start?")
      given("none")
      has_input(:client, "none")

      does("Opening tunnel on port 10000")
      kill
    end
  end

  it "runs with args INSTANCE" do
    running(:tunnel, :instance => @instance) do
      asks("Which client would you like to start?")
      given("none")
      has_input(:client, "none")

      does("Opening tunnel on port 10000")
      kill
    end
  end

  it "runs with args --port" do
    port = "10024"
    running(:tunnel, :port => port) do
      asks("Which service instance?")
      given(@instance.name)
      has_input(:instance, @instance)

      asks("Which client would you like to start?")
      given("none")
      has_input(:client, "none")

      does("Opening tunnel on port #{port}")
      kill
    end
  end
end