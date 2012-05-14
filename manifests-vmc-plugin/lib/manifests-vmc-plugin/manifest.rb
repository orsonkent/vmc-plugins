require "yaml"
require "set"

module VMCManifests
  class Manifest
    def initialize(file)
      @file = file
    end

    def body
      @body ||= load
    end

    # load and resolve a given manifest file
    def load
      manifest = build_manifest(@file)
      resolve_manifest(manifest)
      manifest
    end

    def save(dest = @file)
      File.open(save_to, "w") do |io|
        YAML.dump(@body, io)
      end
    end

    MANIFEST_META = ["applications", "properties"]

    def toplevel_attributes
      info =
        body.reject do |k, _|
          MANIFEST_META.include? k
        end

      if info["framework"].is_a?(Hash)
        info["framework"] = info["framework"]["name"]
      end

      info
    end

    def app_info(find_path)
      return unless body["applications"]

      body["applications"].each do |path, info|
        if info["framework"].is_a?(Hash)
          info["framework"] = info["framework"]["name"]
        end

        app = File.expand_path("../" + path, manifest_file)
        if find_path == app
          return toplevel_attributes.merge info
        end
      end

      nil
    end

    # sort applications in dependency order
    # e.g. if A depends on B, B will be listed before A
    def applications(
        apps = body["applications"],
        abspaths = nil,
        processed = Set[])
      unless abspaths
        abspaths = {}
        apps.each do |p, i|
          ep = File.expand_path("../" + p, manifest_file)
          abspaths[ep] = i
        end
      end

      ordered = []
      apps.each do |path, info|
        epath = File.expand_path("../" + path, manifest_file)

        if deps = info["depends-on"]
          dep_apps = {}
          deps.each do |dep|
            edep = File.expand_path("../" + dep, manifest_file)

            raise CircularDependency.new(edep) if processed.include?(edep)

            dep_apps[dep] = abspaths[edep]
          end

          processed.add(epath)

          ordered += applications(dep_apps, abspaths, processed)
          ordered << path
        elsif not processed.include? epath
          ordered << path
          processed.add(epath)
        end
      end

      ordered
    end

    private

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
      file = File.expand_path("../" + path, @file)
      deep_merge(child, build_manifest(file))
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
        val.gsub!(/\$\{([[:alnum:]\-]+)\}/) do
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

      else
        found = find_symbol(sym, ctx)

        if found
          resolve_lexically(found, ctx)
          found
        else
          raise UnknownSymbol.new(sym)
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

    # deep hash merge
    def deep_merge(child, parent)
      merge = proc do |_, old, new|
        if new.is_a?(Hash) and old.is_a?(Hash)
          old.merge(new, &merge)
        else
          new
        end
      end

      parent.merge(child, &merge)
    end
  end
end
