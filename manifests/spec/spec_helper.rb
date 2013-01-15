SPEC_ROOT = File.dirname(__FILE__).freeze

require "rspec"
require "vmc"
require "cfoundry"
require "cfoundry/test_support"

RSpec.configure do |c|
  c.include Fake::FakeMethods
  c.mock_with :rr
end