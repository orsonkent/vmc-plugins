require "vmc/plugin"
require "manifests-vmc-plugin"

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
  [:start, :instances, :logs, :file, :files, :health, :stats].each do |wrap|
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

        sync_changes(a)

        with_filters(:push_app => proc { |app| app.env = a["env"]; app }) do
          push.call(
            :name => a["name"],
            :bind_services => false,
            :create_services => false)
        end

        puts "" unless simple_output?
      end

    unless all_pushed
      bound = []

      with_filters(:push_app => proc { |app| ask_to_save(app); app }) do
        push.call
      end
    end
  end

  # need to do this specially so it doesn't call it with the instance/memory
  # flags set (via each_app), which would cause it to do nothing
  around(:scale) do |cmd, args|
    if args.empty? && !passed_value(:name)
      apps = []
      has_manifest =
        each_app do |a|
          apps << a["name"]
        end

      if has_manifest
        apps.each do |name|
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
end
