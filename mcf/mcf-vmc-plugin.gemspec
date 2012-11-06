# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "mcf-vmc-plugin/version"

Gem::Specification.new do |s|
  s.name        = "mcf-vmc-plugin"
  s.version     = VMCMicro::VERSION
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
end
