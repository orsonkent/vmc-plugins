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
  [:start, :instances, :logs].each do |wrap|
    around(wrap) do |cmd, args|
      if args.empty?
        each_app do |a|
          cmd.call(a["name"])
          puts "" unless simple_output?
        end || err("No applications to act on.")
      else
        cmd.call(args)
      end
    end
  end

  # same as above but in reverse dependency-order
  around(:stop) do |cmd, args|
    if args.empty?
      reversed = []
      each_app do |a|
        reversed.unshift a["name"]
      end || err("No applications to act on.")

      reversed.each do |name|
        cmd.call(name)
        puts "" unless simple_output?
      end
    else
      cmd.call(args)
    end
  end

  around(:delete) do |cmd, args|
    if args.empty? && !options[:all]
      reversed = []
      has_manifest =
        each_app do |a|
          reversed.unshift a["name"]
        end

      unless has_manifest
        return cmd.call(args)
      end

      reversed.each do |name|
        cmd.call(name)
        puts "" unless simple_output?
      end
    else
      cmd.call(args)
    end
  end

  # stop apps in reverse dependency order,
  # and then start in dependency order
  around(:restart) do |cmd, args|
    if args.empty?
      reversed = []
      forwards = []
      each_app do |a|
        reversed.unshift a["name"]
        forwards << a["name"]
      end || err("No applications to act on.")

      reversed.each do |name|
        stop(name)
      end

      puts "" unless simple_output?

      forwards.each do |name|
        start(name)
      end
    else
      cmd.call(args)
    end
  end

  # push and sync meta changes in the manifest
  # also sets env data on creation if present in manifest
  around(:push) do |push, args|
    if args.empty?
      all_pushed =
        each_app do |a|
          app = client.app(a["name"])
          updating = app.exists?

          start = input(:start)

          begin
            inputs[:start] = false

            sync_changes(a)
            push.call(a["name"])

            unless updating
              app.env = a["env"]

              if start
                start(a["name"])
              else
                app.update!
              end
            end
          ensure
            inputs[:start] = start
          end

          puts "" unless simple_output?
        end

      push.call unless all_pushed
    else
      push.call(args)
    end
  end
end
