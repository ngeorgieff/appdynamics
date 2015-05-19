module Puppet::Parser::Functions
  newfunction(:appd_hiera, :type => :rvalue) do |*args|
    require 'hiera_puppet'
    key, default, override = HieraPuppet.parse_args(args)

    # use a default override if one is not given...
    if override.nil?
      override = ["appdynamics/%{appd_network}", "appdynamics/common"]
    end

    HieraPuppet.lookup(key, default, self, override, :priority)
  end
end
