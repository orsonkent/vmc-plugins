require "rake"

$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
require "admin-vmc-plugin/version"

task :default => :spec

desc "Run specs"
task :spec => ["bundler:install", "test:spec"]

desc "Run integration tests"
task :test => ["bundler:install", "test:integration"]

task :build do
  sh "gem build admin-vmc-plugin.gemspec"
end

task :install => :build do
  sh "gem install --local admin-vmc-plugin-#{VMCAdmin::VERSION}.gem"
end

task :uninstall do
  sh "gem uninstall admin-vmc-plugin"
end

task :reinstall => [:uninstall, :install]

task :release => :build do
  sh "gem push admin-vmc-plugin-#{VMCAdmin::VERSION}.gem"
end

namespace "bundler" do
  desc "Install gems"
  task "install" do
    sh("bundle install")
  end
end

namespace "test" do
  task "spec" do |t|
    # nothing
  end

  task "integration" do |t|
    sh("cd spec && bundle exec rake spec")
  end
end
