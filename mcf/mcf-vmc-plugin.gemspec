# -*- encoding: utf-8 -*-

#############
# WARNING: Separate from the Gemfile. Please update both files
#############

$:.push File.expand_path("../lib", __FILE__)
require "mcf-vmc-plugin/version"

Gem::Specification.new do |s|
  s.name        = "mcf-vmc-plugin"
  s.version     = VMCMicro::VERSION.dup
  s.authors     = ["Alex Suraci"]
  s.email       = ["asuraci@vmware.com"]
  s.homepage    = "http://cloudfoundry.com/"
  s.summary     = %q{
    Provides a fake tunnel command that tells you to install the real plugin.
  }

  s.rubyforge_project = "mcf-vmc-plugin"

  s.files         = %w{Rakefile} + Dir.glob("{lib,config}/**/*")
  s.test_files    = Dir.glob("spec/**/*")
  s.require_paths = ["lib"]

  s.add_development_dependency "rake", "~> 0.9"
  s.add_development_dependency "rspec", "~> 2.11"
  s.add_development_dependency "webmock", "~> 1.9"
  s.add_development_dependency "rr", "~> 1.0"
end
