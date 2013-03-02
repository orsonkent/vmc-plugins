# -*- encoding: utf-8 -*-

#############
# WARNING: Separate from the Gemfile. Please update both files
#############

$:.push File.expand_path("../lib", __FILE__)
require "clone-af-cli-plugin/version"

Gem::Specification.new do |s|
  s.name        = "clone-af-cli-plugin"
  s.version     = AFCLIClone::VERSION.dup
  s.authors     = ["Tim Santeford"]
  s.email       = ["tim@appfog.com"]
  s.homepage    = "http://www.appfog.com/"
  s.summary     = %q{
    Clones applications between infras
  }

  s.rubyforge_project = "clone-af-cli-plugin"

  s.files         = %w{Rakefile} + Dir.glob("{lib}/**/*")
  s.test_files    = Dir.glob("spec/**/*")
  s.require_paths = ["lib"]

  s.add_runtime_dependency "cfoundry", "~> 0.5.0"
end
