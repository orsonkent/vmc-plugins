require "pathname"

require "vmc/plugin"
require "manifests-vmc-plugin"


class Manifests < VMC::App::Base
  include VMCManifests

  option :manifest, :aliases => "-m", :value => :file,
    :desc => "Path to manifest file to use"


  # basic commands that, when given no name, act on the
  # app(s) described by the manifest, in dependency-order
  [ :start, :restart, :instances, :logs, :env,
    :health, :stats, :scale, :app
  ].each do |wrap|
    optional_name = change_argument(wrap, :app, :optional)

    around(wrap) do |cmd, input|
      next cmd.call if input[:all]

      unless manifest
        if optional_name && !input.has?(:app)
          no_apps
        else
          next cmd.call
        end
      end

      show_manifest_usage

      num = 0
      rest =
        specific_apps_or_all(input) do |info|
          puts "" unless quiet? || num == 0
          cmd.call(input.without(:apps).merge_given(:app => info[:name]))
          num += 1
        end

      if rest
        rest.each do |name|
          cmd.call(input.without(:apps).merge(:app => name))
        end

      # fail manually for commands whose name we made optional
      elsif optional_name
        no_apps
      end
    end
  end


  # same as above but in reverse dependency-order
  [:stop, :delete].each do |wrap|
    around(wrap) do |cmd, input|
      next cmd.call if input[:all] || !manifest

      show_manifest_usage

      reversed = []
      rest =
        specific_apps_or_all(input) do |info|
          reversed.unshift info[:name]
        end

      unless reversed.empty?
        cmd.call(input.without(:apps).merge_given(:apps => reversed))
      end

      unless rest.empty?
        cmd.call(input.without(:apps).merge(:apps => rest))
      end
    end
  end


  # push and sync meta changes in the manifest
  # also sets env data on creation if present in manifest
  #
  # vmc push [name in manifest] = push that app from its path
  # vmc push [name not in manifest] = push new app using given name
  # vmc push [path] = push app from its path
  change_argument :push, :name, :optional

  add_input :push, :reset, :type => :boolean, :default => false,
    :desc => "Reset to values in the manifest"

  around(:push) do |push, input|
    particular =
      if input.has?(:name)
        path = File.expand_path(input[:name])
        find_by = File.exists?(path) ? path : input[:name]

        find_apps(find_by)
      else
        []
      end

    if particular.empty?
      particular = find_apps(Dir.pwd)
    end

    apps = particular.empty? ? all_apps : particular

    if apps.empty?
      with_filters(
          :push => {
            :push_app =>
              proc { |a| ask_to_save(input, a); a }
          }) do
        push.call
      end
    else
      show_manifest_usage

      spaced(apps) do |app|
        with_filters(
            :push => {
              :create_app => proc { |a|
                setup_env(a, app)
                a
              },
              :push_app => proc { |a|
                setup_services(a, app)
                a
              }
            }) do
          # only set inputs if creating app or updating with --reset
          if input[:reset] || !client.app_by_name(app[:name])
            app_input = input.rebase_given(app)
          else
            app_input = input.merge(:path => from_manifest(app[:path]))
          end

          push.call(app_input.merge(
            :name => app[:name],
            :bind_services => false,
            :create_services => false))
        end
      end
    end
  end
end
