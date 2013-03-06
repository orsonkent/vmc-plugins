command_files = "../vmc/**/*.rb"
Dir[File.expand_path(command_files, __FILE__)].each do |file|
  require file
end
