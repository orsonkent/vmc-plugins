require "vmc/plugin"
require "manifests-vmc-plugin"


class Manifests < VMC::CLI
  include VMCManifests

  option :manifest, :aliases => "-m", :value => :file,
    :desc => "Path to manifest file to use"


  def no_apps
    fail "No applications or manifest to operate on."
  end


  # basic commands that, when given no name, act on the
  # app(s) described by the manifest, in dependency-order
  [ :start, :restart, :instances, :logs, :file, :files, :env,
    :health, :stats, :scale, :app
  ].each do |wrap|
    optional_name = change_argument(wrap, :app, :optional)

    around(wrap) do |cmd, input|
      unless manifest
        if optional_name && !input.given?(:app)
          no_apps
        else
          next cmd.call
        end
      end

      case wrap
      when :file, :files
        # treat 'vmc files app/' as 'vmc files <app> app/'
        if input.given?(:app) && !input.given?(:path)
          path = input.given(:app)
          input = input.without(:app).merge_given(:path => path)
        end
      end

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
    app =
      if input.given?(:name)
        path = File.expand_path(input[:name])
        find_by = File.exists?(path) ? path : input[:name]

        app_info(find_by, input.without(:name))
      end

    app ||= app_info(".", input)

    if app
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
          input = input.merge_given(app)
        end

        push.call(input.merge(
          :name => app[:name],
          :bind_services => false,
          :create_services => false))
      end
    else
      with_filters(
          :push => {
            :push_app =>
              proc { |a| ask_to_save(input, a); a }
          }) do
        push.call
      end
    end
  end
end
