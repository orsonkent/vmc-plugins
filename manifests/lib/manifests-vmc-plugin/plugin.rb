require "pathname"

require "vmc/plugin"
require "manifests-vmc-plugin"


class ManifestsPlugin < VMC::App::Base
  include VMCManifests
  include VMC::App::Sync

  option :manifest, :aliases => "-m", :value => :file,
    :desc => "Path to manifest file to use"


  def wrap_with_optional_name(name_made_optional, cmd, input)
    return cmd.call if input[:all]

    unless manifest
      # if the command knows how to handle this
      if input.has?(:app) || !name_made_optional
        return cmd.call
      else
        return no_apps
      end
    end

    internal, external = apps_in_manifest(input)

    return cmd.call if internal.empty? && !external.empty?

    show_manifest_usage

    apps = internal + external

    if apps.empty?
      apps = current_apps if apps.empty?
      apps = all_apps if apps.empty?
      apps = apps.collect { |app| app[:name] }
    end

    return no_apps if apps.empty?

    apps.each.with_index do |app, num|
      line unless quiet? || num == 0
      cmd.call(input.without(:apps).merge_given(:app => app))
    end
  end

  # basic commands that, when given no name, act on the
  # app(s) described by the manifest, in dependency-order
  [ :start, :restart, :instances, :logs, :env,
    :health, :stats, :scale, :app
  ].each do |wrap|
    name_made_optional = change_argument(wrap, :app, :optional)

    around(wrap) do |cmd, input|
      wrap_with_optional_name(name_made_optional, cmd, input)
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
          existing_app = client.app_by_name(app[:name])

          # only set inputs if creating app or updating with --reset
          if input[:reset] || !existing_app
            app_input = input.rebase_given(app)
          else
            # assign manifest values to detect differences
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
