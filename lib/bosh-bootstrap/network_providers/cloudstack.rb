module Bosh::Bootstrap::NetworkProviders
  class Cloudstack
    attr_reader :cyoi_provider_client

    def initialize(cyoi_provider_client)
      @cyoi_provider_client = cyoi_provider_client
    end

    def perform(settings)
      attributes = {}
      sg_suffix = ""
      if vpc_id = settings.exists?("address.vpc_id")
        attributes[:vpc_id] = vpc_id
        # sg_suffix = "-#{vpc_id}"
      end
      # this is an ACL...
      security_groups.each do |name, ports|
        sg_name = "#{name}#{sg_suffix}"
        # cyoi_provider_client.create_security_group(sg_name, name.to_s, {ports: ports}, attributes)
      end
    end

    protected
    def security_groups
      {
        "ssh" => 22,
        "dns-server" => { protocol: "udp", ports: (53..53) },
        "bosh" => [4222, 6868, 25250, 25555, 25777]
      }
    end
  end
end
Bosh::Bootstrap::NetworkProviders.register_provider("cloudstack", Bosh::Bootstrap::NetworkProviders::Cloudstack)
