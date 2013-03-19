require "spec_helper"

describe VMCAdmin::Curl do
  use_fake_home_dir { "#{SPEC_ROOT}/fixtures/fake_home_dir" }

  subject { vmc ["curl", "--mode", "GET", "--path", path] }

  before do
    any_instance_of(CFoundry::Client) do |client|
      stub(client).info { { :version => 2 } }
    end
  end

  context "with an implicit target" do
    let(:path) { "apps/5/instances" }

    it "makes a request to the current target" do
      stub_request(:get, "https://api.some-target-for-vmc-curl.com/apps/5/instances").to_return(
        :status => 200,
        :body => 'some-body'
      )

      subject

      expect(stdout.string).to include('"status": "200"')
      expect(stdout.string).to include('"body": "some-body"')
    end
  end

  context "with an explicit target" do
    let(:path) { "https://example.com/apps/5/instances" }

    it "makes a request to the given target" do
      stub_request(:get, "https://example.com/apps/5/instances").to_return(
        :status => 200,
        :body => 'some-other-body'
      )

      subject

      expect(stdout.string).to include('"status": "200"')
      expect(stdout.string).to include('"body": "some-other-body"')
    end
  end
end
