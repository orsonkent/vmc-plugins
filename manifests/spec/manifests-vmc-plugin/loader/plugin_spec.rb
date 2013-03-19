require "spec_helper"

require "manifests-vmc-plugin/plugin"


describe ManifestsPlugin do
  let(:manifest) { {} }
  let(:manifest_file) { nil }
  let(:inputs_hash) { {} }
  let(:given_hash) { {} }
  let(:global_hash) { { :quiet => true } }
  let(:command) { nil }
  let(:inputs) { Mothership::Inputs.new(Mothership.commands[:push], nil, inputs_hash, given_hash, global_hash) }
  let(:plugin) { ManifestsPlugin.new(command, inputs) }

  let(:client) { fake_client }

  before do
    stub(plugin).manifest { manifest }
    stub(plugin).manifest_file { manifest_file } if manifest_file
    stub(plugin).client { client }
  end

  describe "#wrap_with_optional_name" do
    let(:name_made_optional) { true }
    let(:wrapped) { mock! }

    subject { plugin.send(:wrap_with_optional_name, name_made_optional, wrapped, inputs) }

    context "when --all is given" do
      let(:inputs_hash) { { :all => true } }

      it "skips all manifest-related logic, and invokes the command" do
        mock(wrapped).call
        dont_allow(plugin).show_manifest_usage
        subject
      end
    end

    context "when there is no manifest" do
      let(:manifest) { nil }

      context "and an app is given" do
        let(:given_hash) { { :app => "foo" } }

        it "passes through to the command" do
          mock(wrapped).call
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
            mock(wrapped).call
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
            mock(wrapped).call(anything) do |inputs|
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
            mock(wrapped).call(anything).twice do |inputs|
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
            mock(wrapped).call(anything).twice do |inputs|
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
            mock(wrapped).call
            subject
          end
        end
      end

      context "when an app name that's in the manifest is given" do
        let(:manifest) { { :applications => [{ :name => "foo" }] } }
        let(:given_hash) { { :app => "foo" } }

        it "calls the command with that app" do
          mock(wrapped).call(anything) do |inputs|
            expect(inputs.given[:app]).to eq "foo"
          end

          subject
        end
      end

      context "when a path to an app that's in the manifest is given" do
        let(:manifest) { { :applications => [{ :name => "foo", :path => "/abc/foo" }] } }
        let(:given_hash) { { :app => "/abc/foo" } }

        it "calls the command with that app" do
          mock(wrapped).call(anything) do |inputs|
            expect(inputs.given[:app]).to eq "foo"
          end

          subject
        end
      end
    end
  end

  describe "#wrap_push" do
    let(:wrapped) { mock! }
    let(:command) { Mothership.commands[:push] }

    subject { plugin.send(:wrap_push, wrapped, inputs) }

    before do
      stub(plugin).show_manifest_usage
    end

    context "with a manifest" do
      let(:manifest_file) { "/abc/manifest.yml" }

      let(:manifest) do
        { :applications => [
          { :name => "a",
            :path => "/abc/a",
            :instances => "200",
            :memory => "128M"
          }
        ]
        }
      end

      # vmc push foo
      context "and a name is given" do
        context "and the name is present in the manifest" do
          let(:given_hash) { { :name => "a" } }

          context "and the app exists" do
            let(:app) { fake :app, :name => "a" }
            let(:client) { fake_client :apps => [app] }

            context "and --reset was given" do
              let(:inputs_hash) { { :reset => true } }
              let(:given_hash) { { :name => "a", :instances => "100" } }

              it "rebases their inputs on the manifest's values" do
                mock(wrapped).call(anything) do |inputs|
                  expect(inputs.given).to eq(
                    :name => "a", :path => "/abc/a", :instances => "100", :memory => "128M")
                end

                subject
              end
            end

            context "and --reset was NOT given" do
              let(:given_hash) { { :name => "a", :instances => "100" } }

              context "and the app settings differ" do
                let(:app) { fake :app, :name => "a", :memory => 256 }

                it "tells the user to use --reset to apply changes" do
                  mock(plugin).warn_reset_changes
                  mock(wrapped).call(anything) do |inputs|
                    expect(inputs.given).to eq(
                      :name => "a", :instances => "100")
                  end
                  subject
                end
              end

              it "does not add the manifest's values to the inputs" do
                stub(plugin).warn_reset_changes
                mock(wrapped).call(anything) do |inputs|
                  expect(inputs.given).to eq(
                    :name => "a", :instances => "100")
                end

                subject
              end
            end
          end

          context "and the app does NOT exist" do
            it "pushes a new app with the inputs from the manifest" do
              mock(wrapped).call(anything) do |inputs|
                expect(inputs.given).to eq(
                  :name => "a", :path => "/abc/a", :instances => "200", :memory => "128M")
              end

              subject
            end
          end
        end

        context "and the name is NOT present in the manifest" do
          let(:given_hash) { { :name => "x" } }

          it "fails, saying that name was not found in the manifest" do
            expect { subject }.to raise_error(VMC::UserError, /Could not find .+ in the manifest./)
          end
        end
      end

      # vmc push ./abc
      context "and a path is given" do
        context "and there are apps matching that path in the manifest" do
          let(:manifest) do
            { :applications => [
              { :name => "a",
                :path => "/abc/a",
                :instances => "200",
                :memory => "128M"
              },
              { :name => "b",
                :path => "/abc/a",
                :instances => "200",
                :memory => "128M"
              }
            ]
            }
          end

          let(:given_hash) { { :name => "/abc/a" } }

          it "pushes the found apps" do
            pushed_apps = []
            mock(wrapped).call(anything).twice do |inputs|
              pushed_apps << inputs[:name]
            end

            subject

            expect(pushed_apps).to eq(["a", "b"])
          end
        end

        context "and there are NOT apps matching that path in the manifest" do
          let(:given_hash) { { :name => "/abc/x" } }

          it "fails, saying that the path was not found in the manifest" do
            expect { subject }.to raise_error(VMC::UserError, /Path .+ is not present in manifest/)
          end
        end
      end
    end

    context "without a manifest" do
      let(:app) { mock! }
      let(:manifest) { nil }

      it "asks to save the manifest when uploading the application" do
        mock_ask("Save configuration?", :default => false)
        stub(wrapped).call { plugin.filter(:push_app, app) }
        subject
      end
    end
  end
end