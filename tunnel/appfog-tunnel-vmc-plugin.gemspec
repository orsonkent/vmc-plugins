# -*- encoding: utf-8 -*-

#############
# WARNING: Separate from the Gemfile. Please update both files
#############

$:.push File.expand_path("../lib", __FILE__)
require "appfog-tunnel-vmc-plugin/version"

Gem::Specification.new do |s|
  s.name        = "appfog-tunnel-vmc-plugin"
  s.version     = VMCTunnel::VERSION.dup
  s.authors     = ["Alex Suraci, Tim Santeford"]
  s.email       = ["support@appfog.com"]
  s.homepage    = "http://appfog.com/"
  s.summary     = %q{
    External access to your services on AppFog via a Caldecott HTTP
    tunnel.
  }

  s.rubyforge_project = "appfog-tunnel-vmc-plugin"

  s.files         = %w{Rakefile} + Dir.glob("{lib,helper-app,config}/**/*")
  s.test_files    = Dir.glob("spec/**/*")
  s.require_paths = ["lib"]

  s.add_runtime_dependency "cfoundry", "~> 0.5.0"

  s.add_runtime_dependency "addressable", "~> 2.2"
  s.add_runtime_dependency "caldecott-client", "~> 0.0.2"
  s.add_runtime_dependency "rest-client", "~> 1.6"
  s.add_runtime_dependency "uuidtools", "~> 2.1"

  s.add_development_dependency "rake", "~> 0.9"
  s.add_development_dependency "rspec", "~> 2.11"
  s.add_development_dependency "webmock", "~> 1.9"
  s.add_development_dependency "rr", "~> 1.0"
end
