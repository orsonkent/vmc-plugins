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
    return options[:manifest] if options[:manifest]
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

  def app_info(find_path)
    return unless manifest and manifest["applications"]
    
    manifest["applications"].each do |path, info|
      if info["framework"].is_a?(Hash)
        info["framework"] = info["framework"]["name"]
      end

      app = File.expand_path(path, File.dirname(manifest_file))
      if find_path == app
        return toplevel_attributes.merge info
      end
    end

    nil
  end

  # call a block for each app in a manifest (in dependency order), setting
  # inputs for each app
  def each_app
    given_path = passed_value(:path)

    if manifest and all_apps = manifest["applications"]
      # given a specific application
      if given_path
        full_path = File.expand_path(given_path)

        if info = app_info(full_path)
          with_app(full_path, info) do
            yield info
          end
        else
          raise "Path #{given_path} is not described by the manifest."
        end
      else
        # all apps in the manifest
        ordered_by_deps(all_apps).each do |path|
          app = File.expand_path(path, File.dirname(manifest_file))
          info = app_info(app)

          with_app(app, info) do
            yield info
          end
        end
      end

      true
    
    # manually created or legacy single-app manifest
    elsif single = toplevel_attributes
      with_app(full_path || ".", single) do
        yield single
      end

      true

    else
      false
    end
  end

  private

  # call the block as if the app info and path were given as flags
  def with_app(path, info, &blk)
    inputs = {:path => path}
    info.each do |k, v|
      if k == "mem"
        k = "memory"
      end

      inputs[k.to_sym] = v
    end

    with_inputs(inputs, &blk)
  end

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
    app = client.app(info["name"])
    return unless app.exists?

    diff = {}
    need_restage = []
    info.each do |k, v|
      case k
      when /ur[li]s?/
        old = app.urls
        if old != Array(v)
          diff[k] = [old, v]
          app.urls = Array(v)
        end
      when "env"
        old = app.env
        if old != v
          diff[k] = [old, v]
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
          diff["memory"] = [old, new]
          app.memory = new
        end
      end
    end

    return if diff.empty?

    unless simple_output?
      puts "Detected the following changes to #{c(app.name, :name)}:"
      diff.each do |k, d|
        old, new = d
        label = c(k, need_restage.include?(k) ? :bad : :good)
        puts "  #{label}: #{old.inspect} #{c("->", :dim)} #{new.inspect}"
      end

      puts ""
    end

    if need_restage.empty?
      with_progress("Updating #{c(app.name, :name)}") do
        app.update!
      end
    else
      unless simple_output?
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
end
