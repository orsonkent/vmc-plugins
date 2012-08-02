# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "tunnel-vmc-plugin/version"

Gem::Specification.new do |s|
  s.name        = "tunnel-vmc-plugin"
  s.version     = VMCTunnel::VERSION
  s.authors     = ["Alex Suraci"]
  s.email       = ["asuraci@vmware.com"]
  s.homepage    = "http://cloudfoundry.com/"
  s.summary     = %q{
    External access to your services on Cloud Foundry via a Caldecott HTTP
    tunnel.
  }

  s.rubyforge_project = "tunnel-vmc-plugin"

  s.files         = %w{Rakefile} + Dir.glob("{lib,helper-app,config}/**/*")
  s.test_files    = Dir.glob("spec/**/*")
  s.require_paths = ["lib"]

  s.add_runtime_dependency "cfoundry", "~> 0.3.18"

  s.add_runtime_dependency "addressable", "~> 2.2.6"
  s.add_runtime_dependency "eventmachine", "~> 1.0.0.beta"
  s.add_runtime_dependency "caldecott", "~> 0.0.5"
end
