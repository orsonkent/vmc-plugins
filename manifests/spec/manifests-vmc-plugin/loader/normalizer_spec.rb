require "spec_helper"

require "manifests-vmc-plugin/loader"


describe VMCManifests::Normalizer do
  let(:manifest) { {} }
  let(:loader) { VMCManifests::Loader.new(nil, nil) }

  describe '#normalize!' do
    subject do
      loader.normalize!(manifest)
      manifest
    end

    context 'with a manifest where the applications have no path set' do
      let(:manifest) { { "applications" => { "." => { "name" => "foo" } } } }

      it "sets the path to their tag, assuming it's a path" do
        expect(subject).to eq(
          :applications => [{ :name => "foo", :path => "." }])
      end
    end

    context 'with a manifest where the url is nil' do
      let(:manifest) { { "applications" => { "." => { "url" => nil } } } }

      it "sets it to none" do
        expect(subject).to eq(
          :applications => [{ :path => ".", :url => "none" }])
      end
    end

    context 'with a manifest with toplevel attributes' do
      context 'and properties' do
        let(:manifest) {
          { "name" => "foo", "properties" => { "fizz" => "buzz" } }
        }

        it 'keeps the properties at the toplevel' do
          expect(subject).to eq(
            :applications => [{ :name => "foo", :path => "." }],
            :properties => { :fizz => "buzz" })
        end
      end

      context 'and no applications' do
        context 'and no path' do
          let(:manifest) { { "name" => "foo" } }

          it 'adds it as an application with path .' do
            expect(subject).to eq(
              :applications => [{ :name => "foo", :path => "." }])
          end
        end

        context 'and a path' do
          let(:manifest) { { "name" => "foo", "path" => "./foo" } }

          it 'adds it as an application with the proper tag and path' do
            expect(subject).to eq(
              :applications => [{ :name => "foo", :path => "./foo" }])
          end
        end
      end

      context 'and applications' do
        let(:manifest) {
          { "runtime" => "ruby19",
            "applications" => {
              "./foo" => { "name" => "foo" },
              "./bar" => { "name" => "bar" },
              "./baz" => { "name" => "baz", "runtime" => "ruby18" }
            }
          }
        }

        it "merges the toplevel attributes into the applications" do
          expect(subject[:applications]).to match_array [
            { :name => "foo", :path => "./foo", :runtime => "ruby19" },
            { :name => "bar", :path => "./bar", :runtime => "ruby19" },
            { :name => "baz", :path => "./baz", :runtime => "ruby18" }
          ]
        end
      end
    end

    context 'with a manifest where applications is a hash' do
      let(:manifest) { { "applications" => { "foo" => { "name" => "foo" } } } }

      it 'converts the array to a hash, with the path as the key' do
        expect(subject).to eq(
          :applications => [{ :name => "foo", :path => "foo" }])
      end

      context "and the applications had dependencies" do
        let(:manifest) do
          { "applications" => {
              "bar" => { "name" => "bar", "depends-on" => "foo" },
              "foo" => { "name" => "foo" }
            }
          }
        end

        it "converts using dependency order" do
          expect(subject).to eq(
            :applications => [{ :name => "foo", :path => "foo" }, { :name => "bar", :path => "bar" }])
        end

        context "and there's a circular dependency" do
          let(:manifest) do
            { "applications" => {
               "bar" => { "name" => "bar", "depends-on" => "foo" },
               "foo" => { "name" => "foo", "depends-on" => "bar" }
              }
            }
          end

          it "doesn't blow up" do
            expect(subject).to be_true
          end
        end
      end
    end
  end

  describe '#normalize_app!' do
    subject do
      loader.send(:normalize_app!, manifest)
      manifest
    end

    context 'with framework as a hash' do
      let(:manifest) {
        { "name" => "foo",
          "framework" => { "name" => "ruby19", "mem" => "64M" }
        }
      }

      it 'sets the framework to just the name' do
        expect(subject).to eq(
          "name" => "foo",
          "framework" => "ruby19")
      end
    end

    context 'with mem instead of memory' do
      let(:manifest) { { "name" => "foo", "mem" => "128M" } }

      it 'renames mem to memory' do
        expect(subject).to eq("name" => "foo", "memory" => "128M")
      end
    end
  end
end
