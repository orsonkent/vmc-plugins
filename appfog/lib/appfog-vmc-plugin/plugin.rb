require "vmc/cli"
require "appfog-vmc-plugin/non_uaa"
require "appfog-vmc-plugin/cfoundry"
require "appfog-vmc-plugin/vmc"
require "appfog-vmc-plugin/help"

command_files = "../deprecated/**/*.rb"
Dir[File.expand_path(command_files, __FILE__)].each do |file|
  require file
end

command_files = "../commands/**/*.rb"
Dir[File.expand_path(command_files, __FILE__)].each do |file|
  require file
end
