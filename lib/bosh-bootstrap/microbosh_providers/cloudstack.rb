require "bosh-bootstrap/microbosh_providers/base"

module Bosh::Bootstrap::MicroboshProviders
  class Cloudstack < Base

    def to_hash
      data = super.merge({
      "network"=>network_configuration,
       "resources"=>
        {"persistent_disk"=>persistent_disk,
         "cloud_properties"=>resources_cloud_properties},
       "cloud"=>
        {"plugin"=>"cloudstack",
         "properties"=>
          {"cloudstack"=>cloud_properties}},
       "apply_spec"=>
        {"agent"=>
          {"blobstore"=>{"address"=>public_ip},
           "nats"=>{"address"=>public_ip}},
          "properties"=>
            {"cloudstack_registry"=>{"address"=>public_ip},
            "hm"=>{"resurrector_enabled" => true}}},
      })
      if zone = settings.exists?("provider.zone")
        data["resources"]["cloud_properties"]["zone"] = zone
      end
      if vpc?
        dns = settings.exists?("recursor") ? settings.recursor : vpc_dns(public_ip)
        data["apply_spec"]["properties"]["dns"] = {}
        data["apply_spec"]["properties"]["dns"]["recursor"] = dns
      end
      if proxy?
        data["apply_spec"]["properties"]["director"] = {"env" => proxy}
      end
      data
    end

    def network_configuration
      if vpc?
        {
          "type" =>"manual",
          "ip"   => public_ip,
          "dns"  => [vpc_dns(public_ip)],
          "cloud_properties" => {
            "subnet" => settings.address.subnet_id
          }
        }

      else
        {
          "type"=>"dynamic",
          "vip"=>public_ip
        }
      end
    end

    def persistent_disk
      settings.bosh.persistent_disk
    end

    def resources_cloud_properties
      {"instance_type"=>"Medium Instance",
       "ephemeral_disk"=>{"size" => 163840, "type" => "gp2"}}
    end

    def cloud_properties
      {"access_key_id"=>settings.provider.credentials.cloudstack_access_key,
       "secret_access_key"=>settings.provider.credentials.cloudstack_secret_key,
       "zone"=>settings.provider.zone,
       "auth_url"=>settings.provider.credentials.cloudstack_auth_url}
    end

    def security_groups
      sg_suffix=""
      if vpc?
        sg_suffix="-#{settings.address.vpc_id}"
      end
      [
        "ssh#{sg_suffix}",
        "dns-server#{sg_suffix}",
        "bosh#{sg_suffix}"
      ]
    end

    def cloudstack_zone
      settings.provider.zone
    end

    # @return Bosh::Cli::PublicStemcell latest stemcell for cloudstack/trusty
    # If us-east-1 region, then return light stemcell
    def latest_stemcell
      @latest_stemcell ||= begin
        trusty_stemcells = recent_stemcells.select do |s|
            s.name =~ /cloudstack/ && s.name =~ /trusty/ && s.name =~ /^light/
        end
        trusty_stemcells.sort {|s1, s2| s2.version <=> s1.version}.first
      end
    end

    # only us-east-1 has light stemcells published
    def light_stemcell?
      cloudstack_region == "us-east-1"
    end

    def vpc?
      settings.address["subnet_id"]
    end
    # Note: this should work for all /16 vpcs and may run into issues with other blocks
    def vpc_dns(ip_address)
      ip_address.gsub(/^(\d+)\.(\d+)\..*/, '\1.\2.0.2')
    end

    # @return [Hash] description of each self-owned AMI
    # {"blockDeviceMapping"=>
    #  [{"deviceName"=>"/dev/sda",
    #    "snapshotId"=>"snap-56c7089e",
    #    "volumeSize"=>2,
    #    "deleteOnTermination"=>"true"},
    #   {"deviceName"=>"/dev/sdb", "virtualName"=>"ephemeral0"}],
    # "productCodes"=>[],
    # "stateReason"=>{},
    # "tagSet"=>{"Name"=>"bosh-cloudstack-xen-ubuntu-trusty-go_agent 2732"},
    # "imageId"=>"ami-c19ed3f1",
    # "imageLocation"=>"357913607455/BOSH-64a71269-18a2-450b-9e61-713ed70fa62a",
    # "imageState"=>"available",
    # "imageOwnerId"=>"357913607455",
    # "isPublic"=>false,
    # "architecture"=>"x86_64",
    # "imageType"=>"machine",
    # "kernelId"=>"aki-94e26fa4",
    # "name"=>"BOSH-64a71269-18a2-450b-9e61-713ed70fa62a",
    # "description"=>"bosh-cloudstack-xen-ubuntu-trusty-go_agent 2732",
    # "rootDeviceType"=>"ebs",
    # "rootDeviceName"=>"/dev/sda1",
    # "virtualizationType"=>"paravirtual",
    # "hypervisor"=>"xen"}
    def owned_templates
      my_templates_raw = fog_compute.describe_templates('Owner' => 'self')
      my_templates_raw.body["imagesSet"]
    end

    # @return [String] Any AMI imageID, e.g. "ami-c19ed3f1" for given BOSH stemcell name/version
    # Usage: find_ami_for_stemcell("bosh-cloudstack-xen-ubuntu-trusty-go_agent", "2732")
    def find_template_for_stemcell(name, version)
      image = owned_templates.find do |image|
        image["description"] == "#{name} #{version}"
      end
      image["imageId"] if image
    end

    def discover_if_stemcell_image_already_uploaded
      find_template_for_stemcell(latest_stemcell.stemcell_name, latest_stemcell.version)
    end
  end
end
Bosh::Bootstrap::MicroboshProviders.register_provider("cloudstack", Bosh::Bootstrap::MicroboshProviders::Cloudstack)
