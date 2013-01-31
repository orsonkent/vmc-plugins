require 'spec_helper'
require 'manifests-vmc-plugin'

describe VMCManifests do
  let(:client) { fake_client }

  let(:cmd) do
    manifest = VMC::App::Push.new
    manifest.extend VMCManifests
    stub(manifest).client { client }
    manifest
  end

  let(:target_base) { "some-cloud.com" }

  before do
    stub(cmd).target_base { target_base }
    stub(cmd).v2? { true }
  end

  describe '#find_apps' do
    subject { cmd.find_apps(nil) }

    context 'when there is no manifest file' do
      before { stub(cmd).manifest { nil } }
      it { should eq [] }
    end
  end

  describe '#create_manifest_for' do
    let(:app) {
      fake :app,
        :framework => fake(:framework),
        :runtime => fake(:runtime),
        :memory => 2048,
        :total_instances => 2,
        :command => "ruby main.rb",
        :routes => [
          fake(:route,
               :host => "some-app-name",
               :domain => fake(:domain, :name => target_base))
        ],
        :service_bindings => [
          fake(
            :service_binding,
            :service_instance =>
              fake(
                :service_instance,
                :name => "service-1",
                :service_plan =>
                  fake(
                    :service_plan,
                    :name => "P200",
                    :service => fake(:service))))
        ]
    }

    subject { cmd.create_manifest_for(app, "some-path") }

    its(["name"]) { should eq app.name }
    its(["framework"]) { should eq app.framework.name }
    its(["runtime"]) { should eq app.runtime.name }
    its(["memory"]) { should eq "2G" }
    its(["instances"]) { should eq 2 }
    its(["path"]) { should eq "some-path" }
    its(["url"]) { should eq "some-app-name.${target-base}" }
    its(["command"]) { should eq "ruby main.rb" }

    it "contains the service information" do
      expect(subject["services"]).to be_a Hash

      services = subject["services"]
      app.service_bindings.each do |b|
        service = b.service_instance

        expect(services).to include service.name

        info = services[service.name]

        plan = service.service_plan
        offering = plan.service

        { "plan" => plan.name,
          "label" => offering.label,
          "provider" => offering.provider,
          "version" => offering.version
        }.each do |attr, val|
          expect(info).to include attr
          expect(info[attr]).to eq val
        end
      end
    end

    context 'when there is no url' do
      let(:app) {
        fake :app,
          :framework => fake(:framework),
          :runtime => fake(:runtime),
          :memory => 2048,
          :total_instances => 2
      }

      its(["url"]) { should eq "none" }
    end

    context 'when there is no command' do
      let(:app) {
        fake :app,
          :framework => fake(:framework),
          :runtime => fake(:runtime),
          :memory => 2048,
          :total_instances => 2
      }

      it { should_not include "command" }
    end

    context 'when there are no service bindings' do
      let(:app) {
        fake :app,
          :framework => fake(:framework),
          :runtime => fake(:runtime),
          :memory => 2048,
          :total_instances => 2
      }

      it { should_not include "services" }
    end
  end

  describe "#setup_services" do
    let(:service_bindings) { [] }
    let(:app) { fake :app, :service_bindings => service_bindings }

    before do
      dont_allow_ask(anything, anything)
    end

    context "when services are defined in the manifest" do
      let(:info) {
        { :services => { "service-1" => { :label => "mysql", :plan => "100" } } }
      }

      let(:service_1) { fake(:service_instance, :name => "service-1") }

      let(:plan_100) { fake :service_plan, :name => "100" }

      let(:mysql) {
        fake(
          :service,
          :label => "mysql",
          :provider => "core",
          :service_plans => [plan_100])
      }

      let(:service_instances) { [] }

      let(:client) {
        fake_client :services => [mysql], :service_instances => service_instances
      }

      context "and the services exist" do
        let(:service_instances) { [service_1] }

        context "and are already bound" do
          let(:service_bindings) { [fake(:service_binding, :service_instance => service_1)] }

          it "does neither create nor bind the service again" do
            dont_allow(cmd).invoke :create_service, anything
            dont_allow(cmd).invoke :bind_service, anything
            cmd.send(:setup_services, app, info)
          end
        end

        context "but are not bound" do
          it "does not create the services" do
            dont_allow(cmd).invoke :create_service, anything
            stub(cmd).invoke :bind_service, anything
            cmd.send(:setup_services, app, info)
          end

          it "binds the service" do
            mock(cmd).invoke :bind_service, :app => app, :service => service_1
            cmd.send(:setup_services, app, info)
          end
        end
      end

      context "and the services do not exist" do
        it "creates the services" do
          mock(cmd).invoke :create_service, :app => app,
            :name => service_1.name, :offering => mysql, :plan => plan_100
          dont_allow(cmd).invoke :bind_service, anything
          cmd.send(:setup_services, app, info)
        end
      end
    end

    context "when there are no services defined" do
      let(:info) { {} }

      it "does not ask anything" do
        cmd.send(:setup_services, app, info)
      end
    end
  end
end
