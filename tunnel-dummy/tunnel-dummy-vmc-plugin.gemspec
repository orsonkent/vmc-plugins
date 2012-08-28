# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "tunnel-dummy-vmc-plugin/version"

Gem::Specification.new do |s|
  s.name        = "tunnel-dummy-vmc-plugin"
  s.version     = VMCTunnelDummy::VERSION
  s.authors     = ["Alex Suraci"]
  s.email       = ["asuraci@vmware.com"]
  s.homepage    = "http://cloudfoundry.com/"
  s.summary     = %q{
    Provides a fake tunnel command that tells you to install the real plugin.
  }

  s.rubyforge_project = "tunnel-dummy-vmc-plugin"

  s.add_runtime_dependency "cfoundry", "~> 0.3.14"

  s.files         = %w{Rakefile} + Dir.glob("lib/**/*")
  s.test_files    = Dir.glob("spec/**/*")
  s.require_paths = ["lib"]
end
