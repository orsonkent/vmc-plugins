require "yaml"
require "set"

module VMCManifests
  MANIFEST_FILE = "manifest.yml"

  def manifest
    return @manifest if @manifest

    if manifest_file && File.exists?(manifest_file)
      @manifest = load_manifest(manifest_file)
    end
  end

  def save_manifest(save_to = manifest_file)
    raise "No manifest to save!" unless @manifest

    File.open(save_to, "w") do |io|
      YAML.dump(@manifest, io)
    end
  end

  # find the manifest file to work with
  def manifest_file
    return option(:manifest) if option(:manifest)
    return @manifest_file if @manifest_file

    where = Dir.pwd
    while true
      if File.exists?(File.join(where, MANIFEST_FILE))
        @manifest_file = File.join(where, MANIFEST_FILE)
        break
      elsif File.basename(where) == "/"
        @manifest_file = nil
        break
      else
        where = File.expand_path("../", where)
      end
    end

    @manifest_file
  end

  # load and resolve a given manifest file
  def load_manifest(file)
    manifest = build_manifest(file)
    resolve_manifest(manifest)
    manifest
  end

  # parse a manifest and merge with its inherited manifests
  def build_manifest(file)
    manifest = YAML.load_file file

    Array(manifest["inherit"]).each do |p|
      manifest = merge_parent(manifest, p)
    end

    manifest
  end

  # merge the manifest at `path' into the `child'
  def merge_parent(child, path)
    file = File.expand_path(path, File.dirname(manifest_file))
    merge_manifest(child, build_manifest(file))
  end

  # deep hash merge
  def merge_manifest(child, parent)
    merge = proc do |_, old, new|
      if new.is_a?(Hash) and old.is_a?(Hash)
        old.merge(new, &merge)
      else
        new
      end
    end

    parent.merge(child, &merge)
  end

  # resolve symbols in a manifest
  def resolve_manifest(manifest)
    if apps = manifest["applications"]
      apps.each_value do |v|
        resolve_lexically(v, [manifest])
      end
    end

    resolve_lexically(manifest, [manifest])

    nil
  end

  # resolve symbols, with hashes introducing new lexical symbols
  def resolve_lexically(val, ctx)
    case val
    when Hash
      val.each_value do |v|
        resolve_lexically(v, [val] + ctx)
      end
    when Array
      val.each do |v|
        resolve_lexically(v, ctx)
      end
    when String
      val.gsub!(/\$\{([^\}]+)\}/) do
        resolve_symbol($1, ctx)
      end
    end

    nil
  end

  # resolve a symbol to its value, and then resolve that value
  def resolve_symbol(sym, ctx)
    case sym
    when "target-url"
      target_url(ctx)

    when "target-base"
      target_url(ctx).sub(/^[^\.]+\./, "")

    when "random-word"
      "%04x" % [rand(0x0100000)]

    when /^ask (.+)/
      ask($1)

    else
      found = find_symbol(sym, ctx)

      if found
        resolve_lexically(found, ctx)
        found
      else
        raise("Unknown symbol in manifest: #{sym}")
      end
    end
  end

  # get the target url from either the manifest or the current client
  def target_url(ctx = [])
    find_symbol("target", ctx) || client_target
  end

  # search for a symbol introduced in the lexical context
  def find_symbol(sym, ctx)
    ctx.each do |h|
      if val = resolve_in(h, sym)
        return val
      end
    end

    nil
  end

  # find a value, searching in explicit properties first
  def resolve_in(hash, *where)
    find_in_hash(hash, ["properties"] + where) ||
      find_in_hash(hash, where)
  end

  # helper for following a path of values in a hash
  def find_in_hash(hash, where)
    what = hash
    where.each do |x|
      return nil unless what.is_a?(Hash)
      what = what[x]
    end

    what
  end

  MANIFEST_META = ["applications", "properties"]

  def toplevel_attributes
    if m = manifest
      info =
        m.reject do |k, _|
          MANIFEST_META.include? k
        end

      if info["framework"].is_a?(Hash)
        info["framework"] = info["framework"]["name"]
      end

      info
    end
  end

  def app_info(find_path, input = nil)
    return unless manifest

    mandir = File.dirname(manifest_file)
    full_path = File.expand_path(find_path, mandir)

    path, info =
      if apps = manifest["applications"]
        manifest["applications"].find do |path, info|
          if info["framework"].is_a?(Hash)
            info["framework"] = info["framework"]["name"]
          end

          app = File.expand_path(path, mandir)
          File.expand_path(path, mandir) == full_path
        end
      elsif find_path == "."
        [".", {}]
      end

    return unless info

    data = { :path => full_path }

    toplevel_attributes.merge(info).each do |k, v|
      name = k.to_sym

      if name == :mem
        name = :memory
      end

      data[name] = input && input.given(name) || v
    end

    data
  end

  # call a block for each app in a manifest (in dependency order), setting
  # inputs for each app
  def each_app(input = nil, &blk)
    if manifest and all_apps = manifest["applications"]
      use_inputs = all_apps.size == 1

      ordered_by_deps(all_apps).each do |path|
        yield app_info(path, use_inputs && input)
      end

      true

    # manually created or legacy single-app manifest
    elsif single = toplevel_attributes
      yield app_info(".", input)

      true

    else
      false
    end
  end

  # like each_app, but only acts on apps specified as paths instead of names
  #
  # returns the names that were not paths
  def specific_apps_or_all(input = nil, use_name = true, &blk)
    return false unless manifest && apps = manifest["applications"]

    use_name = false if apps.size > 1

    names_or_paths =
      if input.given?(:names)
        input[:names]
      elsif input.given?(:name)
        [input[:name]]
      else
        []
      end

    return each_app(input, &blk) if names_or_paths.empty?

    input = input.without(:name, :names)

    paths = []
    names = []
    names_or_paths.each do |x|
      path = File.expand_path(x)

      if File.exists?(path)
        paths << path
      else
        names << x
      end
    end

    paths.each do |path|
      blk.call app_info(path, input)
    end

    if use_name && names.size == 1
      blk.call(
        app_info(
          manifest["applications"].keys.first,
          input.merge(:name => names.first)))
    end

    names
  end


  private

  # sort applications in dependency order
  # e.g. if A depends on B, B will be listed before A
  def ordered_by_deps(apps, abspaths = nil, processed = Set[])
    mandir = File.dirname(manifest_file)

    unless abspaths
      abspaths = {}
      apps.each do |p, i|
        ep = File.expand_path(p, mandir)
        abspaths[ep] = i
      end
    end

    ordered = []
    apps.each do |path, info|
      epath = File.expand_path(path, mandir)

      if deps = info["depends-on"]
        dep_apps = {}
        deps.each do |dep|
          edep = File.expand_path(dep, mandir)

          raise "Circular dependency detected." if processed.include? edep

          dep_apps[dep] = abspaths[edep]
        end

        processed.add(epath)

        ordered += ordered_by_deps(dep_apps, abspaths, processed)
        ordered << path
      elsif not processed.include? epath
        ordered << path
        processed.add(epath)
      end
    end

    ordered
  end

  # detect changes in app info, and update the app if necessary.
  #
  # redeploys the app if necessary (after prompting the user), e.g. for
  # runtime/framework change
  def sync_changes(info)
    app = client.app(info[:name])
    return unless app.exists?

    diff = {}
    need_restage = []
    info.each do |k, v|
      case k.to_s
      when /ur[li]s?/
        old = app.urls
        new = Array(v)
        if old != new
          diff[:urls] = [old.inspect, new.inspect]
          app.urls = new
        end
      when "env"
        old = app.env
        if old != v
          diff[k] = [old.inspect, v.inspect]
          app.env = v
        end
      when "framework", "runtime", "command"
        old = app.send(k)
        if old != v
          diff[k] = [old, v]
          app.send(:"#{k}=", v)
          need_restage << k
        end
      when "instances"
        old = app.total_instances
        if old != v
          diff[k] = [old, v]
          app.total_instances = v
        end
      when "mem", "memory"
        old = app.memory
        new = megabytes(v)

        if old != new
          diff[:memory] = [human_size(old * 1024 * 1024, 0), v]
          app.memory = new
        end
      end
    end

    return if diff.empty?

    unless quiet?
      puts "Detected the following changes to #{c(app.name, :name)}:"
      diff.each do |k, d|
        old, new = d
        label = c(k, need_restage.include?(k) ? :bad : :good)
        puts "  #{label}: #{old} #{c("->", :dim)} #{new}"
      end

      puts ""
    end

    if need_restage.empty?
      with_progress("Updating #{c(app.name, :name)}") do
        app.update!
      end
    else
      unless quiet?
        puts "The following changes require the app to be recreated:"
        need_restage.each do |n|
          puts "  #{c(n, :error)}"
        end
        puts ""
      end

      if force? || ask("Redeploy?", :default => false)
        with_progress("Deleting #{c(app.name, :name)}") do
          app.delete!
        end

        with_progress("Recreating #{c(app.name, :name)}") do
          app.create!
        end
      end
    end
  end

  def ask_to_save(input, app)
    return if manifest_file

    services = app.services.collect { |name| client.service(name) }

    meta = {
      "name" => app.name,
      "framework" => app.framework,
      "runtime" => app.runtime,
      "memory" => human_size(app.memory, 0),
      "instances" => app.total_instances,
      "url" => app.url
    }

    unless services.empty?
      meta["services"] = {}

      services.each do |s|
        meta["services"][s.name] = {
          "vendor" => s.vendor,
          "version" => s.version
        }
      end
    end

    if cmd = app.command
      meta["command"] = cmd
    end

    if ask("Save configuration?", :default => false)
      File.open("manifest.yml", "w") do |io|
        YAML.dump(
          {"applications" => {(input[:path] || ".") => meta}},
          io)
      end

      puts "Saved to #{c("manifest.yml", :name)}."
    end
  end

  def setup_app(app, info)
    app.env = info[:env]

    return if !info[:services] || info[:services].empty?

    services = client.system_services

    info[:services].each do |name, svc|
      service = client.service(name)

      unless service.exists?
        service.vendor = svc["vendor"] || svc["type"]

        service_meta = services[service.vendor]

        service.type = service_meta[:type]
        service.version = svc["version"] || service_meta[:versions].first
        service.tier = "free"

        with_progress("Creating service #{c(service.name, :name)}") do
          service.create!
        end
      end
    end

    app.services = info[:services].keys
  end
end
