require "vmc/plugin"
require "manifests-vmc-plugin"


class Manifests < VMC::CLI
  include VMCManifests

  option :manifest, :aliases => "-m", :value => :file,
    :desc => "Path to manifest file to use"


  def no_apps
    err "No applications or manifest to operate on."
  end


  # basic commands that, when given no name, act on the
  # app(s) described by the manifest, in dependency-order
  [ :start, :instances, :logs, :file, :files, :env,
    :health, :stats, :scale
  ].each do |wrap|
    change_argument(wrap, :name, :optional)

    around(wrap) do |cmd, input|
      use_manifest =
        specific_apps_or_all(input) do |app|
          cmd.call(input.merge(:name => app[:name]))
          puts "" unless quiet?
        end

      # array of unhandled names
      if use_manifest === Array
        cmd.call(input.merge(:names => use_manifest))

      # no manifest or no apps described by it
      elsif !use_manifest
        no_apps
      end
    end
  end


  # same as above but in reverse dependency-order
  [:stop, :delete].each do |wrap|
    around(wrap) do |cmd, input|
      next cmd.call if input[:all]

      reversed = []
      use_manifest =
        specific_apps_or_all(input) do |app|
          reversed.unshift app[:name]
        end

      # array of unhandled names
      if use_manifest === Array
        cmd.call(input.merge(:names => use_manifest))

      # no manifest or no apps described by it
      elsif !use_manifest
        next no_apps
      end

      cmd.call(input.merge(:names => reversed))
    end
  end


  # push and sync meta changes in the manifest
  # also sets env data on creation if present in manifest
  change_argument(:push, :name, :optional)
  around(:push) do |push, input|
    use_manifest =
      specific_apps_or_all(input, true) do |app|
        sync_changes(app)

        with_filters(
            :push => {
              :push_app =>
                proc { |a| setup_app(a, app); a }
            }) do
          push.call(
            input.merge(app).merge(
              :bind_services => false,
              :create_services => false))
        end
      end

    unless use_manifest
      bound = []

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
