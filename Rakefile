require "rake"

task :default => :spec

desc "Run specs"
task :spec do
  %w{manifests mcf console}.each do |plugin|
    Dir.chdir(File.expand_path("../#{plugin}", __FILE__)) do
      sh("(gem list --local bundler | grep bundler || gem install bundler) && (bundle check || bundle install)")
      sh("bundle exec rspec")

      code = $1.to_i
      exit(code) if code != 0
    end
  end
end
