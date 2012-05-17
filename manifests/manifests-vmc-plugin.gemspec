# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "manifests-vmc-plugin/version"

Gem::Specification.new do |s|
  s.name        = "manifests-vmc-plugin"
  s.version     = VMCManifests::VERSION
  s.authors     = ["Alex Suraci"]
  s.email       = ["asuraci@vmware.com"]
  s.homepage    = "http://cloudfoundry.com/"
  s.summary     = %q{
    Cloud Foundry automation via manifest documents.
  }

  s.rubyforge_project = "manifests-vmc-plugin"

  s.files         = %w{Rakefile} + Dir.glob("lib/**/*")
  s.test_files    = Dir.glob("spec/**/*")
  s.require_paths = ["lib"]
end
