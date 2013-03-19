require "mothership/help"

module Mothership::Help

  class << self
    def insert_group(name, args)
      index = 0
      @@tree.each_with_index do |(key, value), i|
        index = i
        break if key == name
      end
      add_group(@@groups[index][:children], @@tree[name][:children], *args)
    end
  end

end

Mothership::Help.insert_group(:apps, [:download, "Download"])
