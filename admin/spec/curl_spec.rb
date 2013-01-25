require "spec_helper"

describe VMCAdmin::Curl do
  use_fake_home_dir { "#{SPEC_ROOT}/fixtures/fake_home_dir" }

  subject { vmc ["curl", "--mode", "GET", "--path", "apps/5/instances"] }

  before do
    any_instance_of(CFoundry::Client) do |client|
      stub(client).info { { :version => 2 } }
    end
  end

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