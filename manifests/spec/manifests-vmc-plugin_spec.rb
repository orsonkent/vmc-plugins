require 'spec_helper'
require 'manifests-vmc-plugin'

require 'cfoundry/test_support'

describe VMCManifests do
  let(:cmd) do
    manifest = VMC::App::Push.new
    manifest.extend VMCManifests
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
end
