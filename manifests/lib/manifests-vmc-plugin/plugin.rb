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
  [ :start, :instances, :logs, :file, :files, :env,
    :health, :stats, :scale
  ].each do |wrap|
    optional_name = change_argument(wrap, :name, :optional)

    around(wrap) do |cmd, input|
      rest =
        specific_apps_or_all(input) do |app|
          cmd.call(input.without(:names).merge(:name => app[:name]))
          puts "" unless quiet?
        end

      if rest
        rest.each do |n|
          cmd.call(input.merge(:name => n))
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
      next cmd.call if input[:all]

      reversed = []
      rest =
        specific_apps_or_all(input) do |app|
          reversed.unshift app[:name]
        end

      unless reversed.empty?
        cmd.call(input.merge(:names => reversed))
      end

      if rest
        cmd.call(input.merge(:names => rest)) unless rest.empty?
      else
        cmd.call(input.without(:names))
      end
    end
  end


  # push and sync meta changes in the manifest
  # also sets env data on creation if present in manifest
  #
  # vmc push [name in manifest] = push that app from its path
  # vmc push [name not in manifest] = push new app using given name
  # vmc push [path] = push app from its path
  change_argument(:push, :name, :optional)
  around(:push) do |push, input|
    app =
      if input.given?(:name)
        path = File.expand_path(input[:name])
        find_by = File.exists?(path) ? path : input[:name]

        app_info(find_by, input.without(:name))
      end

    app ||= app_info(".", input)

    if app
      sync_changes(app)

      with_filters(
          :push => {
            :push_app => proc { |a| setup_app(a, app); a }
          }) do
        push.call(input.merge(app).merge(
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
