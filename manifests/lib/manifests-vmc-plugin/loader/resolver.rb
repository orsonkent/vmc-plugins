module VMCManifests
  module Resolver
    def resolve!(manifest, resolver)
      manifest["applications"].each_value do |v|
        resolve_lexically(resolver, v, [manifest])
      end

      resolve_lexically(resolver, manifest, [manifest])

      nil
    end

    private

    # resolve symbols, with hashes introducing new lexical symbols
    def resolve_lexically(resolver, val, ctx)
      case val
      when Hash
        val.each_value do |v|
          resolve_lexically(resolver, v, [val] + ctx)
        end
      when Array
        val.each do |v|
          resolve_lexically(resolver, v, ctx)
        end
      when String
        val.gsub!(/\$\{([^\}]+)\}/) do
          resolve(resolver, $1, ctx)
        end
      end

      nil
    end

    # resolve a symbol to its value, and then resolve that value
    def resolve(resolver, sym, ctx)
      found = find_symbol(sym, ctx)

      if found
        resolve_lexically(resolver, found, ctx)
        found
      elsif dynamic = resolver.resolve_symbol(sym)
        dynamic
      else
        fail("Unknown symbol in manifest: #{sym}")
      end
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
  end
end
