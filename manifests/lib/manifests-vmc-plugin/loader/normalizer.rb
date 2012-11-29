module VMCManifests
  module Normalizer
    MANIFEST_META = ["applications", "properties"]

    def normalize!(manifest)
      toplevel = toplevel_attributes(manifest)

      apps = manifest["applications"]
      apps ||= [{}]

      default_paths_to_keys!(apps)

      apps = convert_from_array(apps) 

      merge_toplevel!(toplevel, manifest, apps)
      normalize_apps!(apps)

      manifest["applications"] = apps

      nil
    end

    private

    def convert_from_array(apps)
      return apps unless apps.is_a?(Array)

      apps_hash = {}
      apps.each.with_index do |a, i|
        apps_hash[i.to_s] = a
      end

      apps_hash
    end

    def default_paths_to_keys!(apps)
      return if apps.is_a?(Array)

      apps.each do |tag, app|
        app["path"] ||= tag
      end
    end

    def normalize_apps!(apps)
      apps.each_value do |app|
        normalize_app!(app)
      end
    end

    def merge_toplevel!(toplevel, manifest, apps)
      return if toplevel.empty?

      apps.each do |t, a|
        apps[t] = toplevel.merge(a)
      end

      toplevel.each do |k, _|
        manifest.delete k
      end
    end

    def normalize_app!(app)
      if app["framework"].is_a?(Hash)
        app["framework"] = app["framework"]["name"]
      end

      if app.key?("mem")
        app["memory"] = app.delete("mem")
      end
    end

    def toplevel_attributes(manifest)
      top =
        manifest.reject { |k, _|
          MANIFEST_META.include? k
        }

      # implicit toplevel path of .
      top["path"] ||= "."

      top
    end
  end
end
