SPEC_ROOT = File.dirname(__FILE__).freeze

require "rspec"
require "vmc"
require "cfoundry"
require "cfoundry/test_support"
require "webmock/rspec"
require "vmc/test_support"

require "#{SPEC_ROOT}/../lib/appfog-admin-vmc-plugin/plugin"

RSpec.configure do |c|
  c.include Fake::FakeMethods
  c.mock_with :rr

  c.include VMC::TestSupport::FakeHomeDir
  c.include VMC::TestSupport::CommandHelper
end