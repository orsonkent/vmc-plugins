require "vmc/plugin"
require File.expand_path("../../manifests-vmc-plugin", __FILE__)

VMC.Plugin do
  class_option :manifest,
    :aliases => "-m", :desc => "Manifest file"

  class_option :path,
    :aliases => "-p", :desc => "Application path"
end

VMC.Plugin(VMC::App) do
  include VMCManifests

  # basic commands that, when given no args, act on the
  # app(s) described by the manifest, in dependency-order
  [:start, :instances, :scale, :logs,
   :file, :files, :health, :stats].each do |wrap|
    around(wrap) do |cmd, args|
      if args.empty? && !passed_value(:name)
        each_app do |a|
          cmd.call(:name => a["name"])
          puts "" unless simple_output?
        end || err("No applications to act on.")
      else
        cmd.call
      end
    end
  end

  # same as above but in reverse dependency-order
  around(:stop) do |cmd, args|
    if args.empty? && !passed_value(:name)
      reversed = []
      each_app do |a|
        reversed.unshift a["name"]
      end || err("No applications to act on.")

      reversed.each do |name|
        cmd.call(:name => name)
        puts "" unless simple_output?
      end
    else
      cmd.call
    end
  end

  around(:delete) do |cmd, args|
    if args.empty? && !options[:all] && !passed_value(:name)
      reversed = []
      has_manifest =
        each_app do |a|
          reversed.unshift a["name"]
        end

      if has_manifest
        reversed.each do |name|
          cmd.call(:name => name)
          puts "" unless simple_output?
        end
      else
        cmd.call
      end
    else
      cmd.call
    end
  end

  # stop apps in reverse dependency order,
  # and then start in dependency order
  around(:restart) do |cmd, args|
    if args.empty? && !passed_value(:name)
      reversed = []
      forwards = []
      each_app do |a|
        reversed.unshift a["name"]
        forwards << a["name"]
      end || err("No applications to act on.")

      reversed.each do |name|
        with_inputs(:name => name) do
          stop
        end
      end

      puts "" unless simple_output?

      forwards.each do |name|
        with_inputs(:name => name) do
          start
        end
      end
    else
      cmd.call
    end
  end

  # push and sync meta changes in the manifest
  # also sets env data on creation if present in manifest
  around(:push) do |push, args|
    name = passed_value(:name) || args.first

    all_pushed =
      each_app do |a|
        next if name && a["name"] != name

        app = client.app(a["name"])
        updating = app.exists?

        sync_changes(a)
        push.call(
          :name => a["name"],
          :start => false,
          :bind_services => false,
          :create_services => false)

        unless updating
          app.env = a["env"]

          if input(:start)
            with_inputs(:name => a["name"]) do
              start
            end
          else
            app.update!
          end
        end

        puts "" unless simple_output?
      end

    unless all_pushed
      begin
        push.call
      ensure
        meta = {
          "name" => passed_value(:name) || args.first,
          "framework" => passed_value(:framework),
          "runtime" => passed_value(:runtime),
          "memory" => passed_value(:memory),
          "instances" => passed_value(:instances).to_i,
          "url" => passed_value(:url)
        }

        if cmd = passed_value(:command)
          meta["command"] = cmd
        end

        unless manifest_file || meta.any? { |k, v| v.nil? }
          puts ""

          if ask("Save configuration?", :default => false)
            File.open("manifest.yml", "w") do |io|
              YAML.dump(
                {"applications" => {(options[:path] || ".") => meta}},
                io)
            end
          end
        end
      end
    end
  end
end
