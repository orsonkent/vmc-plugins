require "vmc/cli"

module VMCTunnelDummy
  class TunnelCommand < VMC::CLI
    desc "Tells you to install tunnel-vmc-plugin"
    group :services, :manage
    input :instance, :argument => :optional
    input :client, :argument => :optional
    input :port, :default => 10000
    def tunnel
      err "Please install 'tunnel-vmc-plugin' to enable tunnelling."
      line ""
      line "Pardon the extra step; it can't be a direct dependency because it"
      line "requires native compilation."
    end
  end
end
