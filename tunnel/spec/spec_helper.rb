SPEC_ROOT = File.dirname(__FILE__).freeze

require "rspec"
require "cfoundry"
require "cfoundry/test_support"
require "vmc"
require "vmc/test_support"

require "#{SPEC_ROOT}/../lib/appfog-tunnel-vmc-plugin/plugin"

RSpec.configure do |c|
  c.include Fake::FakeMethods
  c.mock_with :rr
  c.include VMC::TestSupport::FakeHomeDir
end