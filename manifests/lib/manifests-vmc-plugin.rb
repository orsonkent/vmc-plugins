require "yaml"
require "set"

require "manifests-vmc-plugin/loader"


module VMCManifests
  MANIFEST_FILE = "manifest.yml"

  @@showed_manifest_usage = false

  def manifest
    return @manifest if @manifest

    if manifest_file && File.exists?(manifest_file)
      @manifest = load_manifest(manifest_file)
    end
  end

  def save_manifest(save_to = manifest_file)
    fail "No manifest to save!" unless @manifest

    File.open(save_to, "w") do |io|
      YAML.dump(@manifest, io)
    end
  end

  # find the manifest file to work with
  def manifest_file
    return @manifest_file if @manifest_file

    unless path = input[:manifest]
      where = Dir.pwd
      while true
        if File.exists?(File.join(where, MANIFEST_FILE))
          path = File.join(where, MANIFEST_FILE)
          break
        elsif File.basename(where) == "/"
          path = nil
          break
        else
          where = File.expand_path("../", where)
        end
      end
    end

    return unless path

    @manifest_file = File.expand_path(path)
  end

  # load and resolve a given manifest file
  def load_manifest(file)
    Loader.new(file, self).manifest
  end

  # dynamic symbol resolution
  def resolve_symbol(sym)
    case sym
    when "target-url"
      client_target

    when "target-base"
      target_base

    when "random-word"
      sprintf("%04x", rand(0x0100000))

    when /^ask (.+)/
      ask($1)
    end
  end

  # find an app by its unique tag
  def app_by_tag(tag)
    manifest[:applications][tag]
  end

  # find apps by an identifier, which may be either a tag, a name, or a path
  def find_apps(identifier)
    return [] unless manifest

    if app = app_by_tag(identifier)
      return [app]
    end

    apps = apps_by(:name, identifier)

    if apps.empty?
      apps = apps_by(:path, from_manifest(identifier))
    end

    apps
  end

  # call a block for each app in a manifest (in dependency order), setting
  # inputs for each app
  def each_app(&blk)
    return unless manifest

    ordered_by_deps(manifest[:applications]).each(&blk)
  end

  # return all the apps described by the manifest, in dependency order
  def all_apps
    apps = []

    each_app do |app|
      apps << app
    end

    apps
  end

  # like each_app, but only acts on apps specified as paths instead of names
  #
  # returns the names that were not paths
  def specific_apps_or_all(input = nil, use_name = true, &blk)
    names_or_paths =
      if input.has?(:apps)
        # names may be given but be [], which will still cause
        # interaction, so use #direct instead of #[] here
        input.direct(:apps)
      elsif input.has?(:app)
        [input[:app]]
      else
        []
      end

    input = input.without(:app, :apps)
    in_manifest = []

    if names_or_paths.empty?
      apps = find_apps(Dir.pwd)

      if !apps.empty?
        in_manifest += apps
      else
        each_app(&blk)
        return []
      end
    end

    external = []
    names_or_paths.each do |x|
      if x.is_a?(String)
        path = File.expand_path(x)

        apps = find_apps(File.exists?(path) ? path : x)

        if !apps.empty?
          in_manifest += apps
        elsif app = client.app_by_name(x)
          external << app
        else
          fail("Unknown app '#{x}'")
        end
      else
        external << x
      end
    end

    in_manifest.each do |app|
      blk.call app
    end

    external
  end

  def create_manifest_for(app, path)
    meta = {
      "name" => app.name,
      "framework" => app.framework.name,
      "runtime" => app.runtime.name,
      "memory" => human_size(app.memory * 1024 * 1024, 0),
      "instances" => app.total_instances,
      "url" => app.url ? app.url.sub(target_base, '${target-base}') : "none",
      "path" => path
    }

    services = app.services

    unless services.empty?
      meta["services"] = {}

      services.each do |i|
        if v2?
          p = i.service_plan
          s = p.service

          meta["services"][i.name] = {
            "label" => s.label,
            "provider" => s.provider,
            "version" => s.version,
            "plan" => p.name
          }
        else
          meta["services"][i.name] = {
            "vendor" => i.vendor,
            "version" => i.version,
            "tier" => i.tier
          }
        end
      end
    end

    if cmd = app.command
      meta["command"] = cmd
    end

    meta
  end

  private

  def show_manifest_usage
    return if @@showed_manifest_usage

    path = Pathname.new(manifest_file).relative_path_from(Pathname.pwd)
    line "Using manifest file #{c(path, :name)}"
    line

    @@showed_manifest_usage = true
  end

  def no_apps
    fail "No applications or manifest to operate on."
  end

  def apps_by(attr, val)
    found = []
    manifest[:applications].each do |tag, info|
      if info[attr] == val
        found << info
      end
    end

    found
  end

  # expand a path relative to the manifest file's directory
  def from_manifest(path)
    File.expand_path(path, File.dirname(manifest_file))
  end

  # sort applications in dependency order
  # e.g. if A depends on B, B will be listed before A
  def ordered_by_deps(apps, processed = Set[])
    ordered = []
    apps.each do |tag, info|
      next if processed.include?(tag)

      if deps = Array(info[:"depends-on"])
        dep_apps = {}
        deps.each do |dep|
          dep = dep.to_sym
          fail "Circular dependency detected." if processed.include? dep
          dep_apps[dep] = apps[dep]
        end

        processed.add(tag)

        ordered += ordered_by_deps(dep_apps, processed)
        ordered << info
      else
        ordered << info
        processed.add(tag)
      end
    end

    ordered
  end

  def ask_to_save(input, app)
    return if manifest_file
    return unless ask("Save configuration?", :default => false)

    manifest = create_manifest_for(app, input[:path])

    with_progress("Saving to #{c("manifest.yml", :name)}") do
      File.open("manifest.yml", "w") do |io|
        YAML.dump(
          { "applications" => [manifest] },
          io)
      end
    end
  end

  def env_hash(val)
    if val.is_a?(Hash)
      val
    else
      hash = {}

      val.each do |pair|
        name, val = pair.split("=", 2)
        hash[name] = val
      end

      hash
    end
  end

  def setup_env(app, info)
    return unless info[:env]
    app.env = env_hash(info[:env])
  end

  def setup_services(app, info)
    return if !info[:services] || info[:services].empty?

    offerings = client.services

    to_bind = []

    info[:services].each do |name, svc|
      name = name.to_s

      if instance = client.service_instance_by_name(name)
        to_bind << instance
      else
        offering = offerings.find { |o|
          o.label == (svc[:label] || svc[:type] || svc[:vendor]) &&
            (!svc[:version] || o.version == svc[:version]) &&
            (o.provider == (svc[:provider] || "core"))
        }

        fail "Unknown service offering: #{svc.inspect}." unless offering

        if v2?
          plan = offering.service_plans.find { |p|
            p.name == (svc[:plan] || "D100")
          }

          fail "Unknown service plan: #{svc[:plan]}." unless plan
        end

        invoke :create_service,
          :name => name,
          :offering => offering,
          :plan => plan,
          :app => app
      end
    end

    to_bind.each do |s|
      # TODO: splat
      invoke :bind_service, :app => app, :service => s
    end
  end

  def target_base
    client_target.sub(/^[^\.]+\./, "")
  end
end
