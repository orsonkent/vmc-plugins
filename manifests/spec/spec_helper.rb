SPEC_ROOT = File.dirname(__FILE__).freeze

require "rspec"
require "vmc"
require "cfoundry"
require "webmock"
require "cfoundry/test_support"
require "vmc/test_support"

WebMock.disable_net_connect!

RSpec.configure do |c|
  c.include Fake::FakeMethods
  c.include VMC::TestSupport::InteractHelper
  c.mock_with :rr
end