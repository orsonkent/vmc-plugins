require "manifests-vmc-plugin/loader/builder"
require "manifests-vmc-plugin/loader/normalizer"
require "manifests-vmc-plugin/loader/resolver"

module VMCManifests
  class Loader
    include Builder
    include Normalizer
    include Resolver

    def initialize(file, resolver)
      @file = file
      @resolver = resolver
    end

    def manifest
      info = build(@file)
      normalize! info
      resolve! info, @resolver
      info
    end
  end
end
