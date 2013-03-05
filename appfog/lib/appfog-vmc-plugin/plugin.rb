require "vmc/cli"
require "appfog-vmc-plugin/help"

command_files = "../commands/**/*.rb"
Dir[File.expand_path(command_files, __FILE__)].each do |file|
  require file
end
