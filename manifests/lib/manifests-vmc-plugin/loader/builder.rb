module VMCManifests
  module Builder
    # parse a manifest and merge with its inherited manifests
    def build(file)
      manifest = YAML.load_file file

      Array(manifest["inherit"]).each do |path|
        manifest = merge_parent(path, manifest)
      end

      manifest
    end

    private

    # merge the manifest at `parent_path' into the `child'
    def merge_parent(parent_path, child)
      merge_manifest(build(from_manifest(parent_path)), child)
    end

    # deep hash merge
    def merge_manifest(parent, child)
      merge = proc do |_, old, new|
        if new.is_a?(Hash) && old.is_a?(Hash)
          old.merge(new, &merge)
        else
          new
        end
      end

      parent.merge(child, &merge)
    end
  end
end
