# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "appfog-admin-vmc-plugin/version"

Gem::Specification.new do |s|
  s.name        = "appfog-admin-vmc-plugin"
  s.version     = VMCAdmin::VERSION.dup
  s.authors     = ["Alex Suraci"]
  s.email       = ["asuraci@vmware.com"]
  s.homepage    = "http://cloudfoundry.com/"
  s.summary     = %q{
    Cloud Foundry administration commands.
  }

  s.rubyforge_project = "appfog-admin-vmc-plugin"

  s.add_runtime_dependency "cfoundry", "~> 0.5.0"

  s.files         = %w{Rakefile} + Dir.glob("lib/**/*")
  s.test_files    = Dir.glob("spec/**/*")
  s.require_paths = ["lib"]
end
