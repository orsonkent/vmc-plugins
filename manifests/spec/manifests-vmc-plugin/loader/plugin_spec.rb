require "spec_helper"

require "manifests-vmc-plugin/plugin"


describe ManifestsPlugin do
  let(:manifest) { {} }
  let(:manifest_file) { nil }
  let(:inputs_hash) { {} }
  let(:given_hash) { {} }
  let(:global_hash) { { :quiet => true } }
  let(:inputs) { Mothership::Inputs.new(nil, nil, inputs_hash, given_hash, global_hash) }
  let(:plugin) { ManifestsPlugin.new(nil, inputs) }

  before do
    stub(plugin).manifest { manifest }
    stub(plugin).manifest_file { manifest_file } if manifest_file
  end

  describe "#wrap_with_optional_name" do
    let(:name_made_optional) { true }
    let(:command) { mock! }

    subject { plugin.wrap_with_optional_name(name_made_optional, command, inputs) }

    context "when --all is given" do
      let(:inputs_hash) { { :all => true } }

      it "skips all manifest-related logic, and invokes the command" do
        mock(command).call
        dont_allow(plugin).show_manifest_usage
        subject
      end
    end

    context "when there is no manifest" do
      let(:manifest) { nil }

      context "and an app is given" do
        let(:given_hash) { { :app => "foo" } }

        it "passes through to the command" do
          mock(command).call
          dont_allow(plugin).show_manifest_usage
          subject
        end
      end

      context "and an app is NOT given" do
        let(:inputs_hash) { {} }

        context "and we made it optional" do
          it "fails manually" do
            mock(plugin).no_apps
            subject
          end
        end

        context "and we did NOT make it optional" do
          let(:name_made_optional) { false }

          it "passes through to the command" do
            mock(command).call
            dont_allow(plugin).show_manifest_usage
            subject
          end
        end
      end
    end

    context "when there is a manifest" do
      let(:manifest_file) { "/abc/manifest.yml" }

      before do
        stub(plugin).show_manifest_usage
      end

      context "when no apps are given" do
        context "and the user's working directory matches a particular app in the manifest" do
          let(:manifest) { { :applications => [{ :name => "foo", :path => "/abc/foo" }] } }

          it "calls the command for only that app" do
            mock(command).call(anything) do |inputs|
              expect(inputs.given[:app]).to eq "foo"
            end

            stub(Dir).pwd { "/abc/foo" }

            subject
          end
        end

        context "and the user's working directory isn't in the manifest" do
          let(:manifest) { { :applications => [{ :name => "foo" }, { :name => "bar" }] } }

          it "calls the command for all apps in the manifest" do
            uncalled_apps = ["foo", "bar"]
            mock(command).call(anything).twice do |inputs|
              uncalled_apps.delete inputs.given[:app]
            end

            subject

            expect(uncalled_apps).to be_empty
          end
        end
      end

      context "when any of the given apps are not in the manifest" do
        let(:manifest) { { :applications => [{ :name => "a" }, { :name => "b" }] } }

        context "and --apps is given" do
          let(:given_hash) { { :apps => ["x", "a"] } }

          it "passes through to the original command" do
            mock(plugin).show_manifest_usage

            uncalled_apps = ["a", "x"]
            mock(command).call(anything).twice do |inputs|
              uncalled_apps.delete inputs.given[:app]
            end

            subject

            expect(uncalled_apps).to be_empty
            subject
          end
        end
      end

      context "when none of the given apps are in the manifest" do
        let(:manifest) { { :applications => [{ :name => "a" }, { :name => "b" }] } }

        context "and --apps is given" do
          let(:given_hash) { { :apps => ["x", "y"] } }

          it "passes through to the original command" do
            dont_allow(plugin).show_manifest_usage
            mock(command).call
            subject
          end
        end
      end

      context "when an app name that's in the manifest is given" do
        let(:manifest) { { :applications => [{ :name => "foo" }] } }
        let(:given_hash) { { :app => "foo" } }

        it "calls the command with that app" do
          mock(command).call(anything) do |inputs|
            expect(inputs.given[:app]).to eq "foo"
          end

          subject
        end
      end

      context "when a path to an app that's in the manifest is given" do
        let(:manifest) { { :applications => [{ :name => "foo", :path => "/abc/foo" }] } }
        let(:given_hash) { { :app => "/abc/foo" } }

        it "calls the command with that app" do
          mock(command).call(anything) do |inputs|
            expect(inputs.given[:app]).to eq "foo"
          end

          subject
        end
      end
    end
  end
end