require "spec_helper"

describe VMCTunnel::Tunnel do
  describe "#tunnel_clients" do
    context "when the user has a custom clients.yml in their vmc directory" do
      use_fake_home_dir { "#{SPEC_ROOT}/fixtures/fake_home_dirs/with_custom_clients" }

      it "overrides the default client config with the user's customizations" do
        expect(subject.tunnel_clients["postgresql"]).to eq({
          "psql" => {
            "command"=>"-h ${host} -p ${port} -d ${name} -U ${user} -w",
            "environment" => ["PGPASSWORD='dont_ask_password'"]
          }
        })
      end
    end

    context "when the user does not have a custom clients.yml" do
      it "returns the default client config" do
        expect(subject.tunnel_clients["postgresql"]).to eq({
          "psql" => {
            "command"=>"-h ${host} -p ${port} -d ${name} -U ${user} -w",
            "environment" => ["PGPASSWORD='${password}'"]
          }
        })
      end
    end
  end
end