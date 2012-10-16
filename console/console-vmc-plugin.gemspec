# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "console-vmc-plugin/version"

Gem::Specification.new do |s|
  s.name        = "console-vmc-plugin"
  s.version     = VMCConsole::VERSION
  s.authors     = ["Alex Suraci"]
  s.email       = ["asuraci@vmware.com"]
  s.homepage    = "http://cloudfoundry.com/"
  s.summary     = %q{
    Port of rails-console to vmc-ng.
  }

  s.rubyforge_project = "console-vmc-plugin"

  s.files         = %w{Rakefile} + Dir.glob("lib/**/*")
  s.test_files    = Dir.glob("spec/**/*")
  s.require_paths = ["lib"]

  s.add_runtime_dependency "tunnel-vmc-plugin", "~> 0.1.8"

  s.add_development_dependency "rake"
  s.add_development_dependency "rspec", "~> 2.0"
  s.add_development_dependency "vmc", ">= 0.4.0.beta.42"
  s.add_development_dependency "ruby-debug19"
end
