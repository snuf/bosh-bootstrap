require "readwritesettings"
require "bosh-bootstrap/microbosh_providers/cloudstack"

describe Bosh::Bootstrap::MicroboshProviders::Cloudstack do
  include Bosh::Bootstrap::Cli::Helpers::Settings

  let(:microbosh_yml) { File.expand_path("~/.microbosh/deployments/micro_bosh.yml")}
  let(:fog_compute) { instance_double("Fog::Compute::Cloudstack") }

  context "creates micro_bosh.yml manifest" do
    it "with advanced networking" do
      setting "provider.name", "cloudstack"
      setting "provider.credentials.cloudstack_zone_id", "Zone"
      setting "provider.credentials.cloudstack_path", "http://10.0.0.1:8080/client/api"
      setting "provider.credentials.cloudstack_api_key", "KEY"
      setting "provider.credentials.cloudstack_secret_access_key", "SECRET"
      setting "address.ip", "1.2.3.4"
      setting "key_pair.path", "~/.microbosh/ssh/test-bosh"
      setting "bosh.name", "test-bosh"
      setting "bosh.salted_password", "salted_password"
      setting "bosh.persistent_disk", 32768

      subject = Bosh::Bootstrap::MicroboshProviders::Cloudstack.new(microbosh_yml, settings, fog_compute)

      subject.create_microbosh_yml(settings)
      expect(File).to be_exists(microbosh_yml)
      yaml_files_match(microbosh_yml, spec_asset("microbosh_yml/cloudstack_vpc.yml"))
    end

  describe "existing stemcells as cloudstack images" do

    it "finds match" do
      subject = Bosh::Bootstrap::MicroboshProviders::Cloudstack.new(microbosh_yml, settings, fog_compute)
      expect(subject).to receive(:owned_images).and_return([
        instance_double("Fog::Compute::Cloudstack::Image",
          name: "BOSH-14c85f35-3dd3-4200-af85-ada65216b2de",
          metadata: [
            instance_double("Fog::Compute::Cloudstack::Metadata",
              key: "name", value: "bosh-cloudstack-kvm-ubuntu-trusty-go_agent"),
            instance_double("Fog::Compute::Cloudstack::Metadata",
              key: "version", value: "2732"),
        ])
      ])
      expect(subject.find_image_for_stemcell("bosh-cloudstack-kvm-ubuntu-trusty-go_agent", "2732")).to eq("BOSH-14c85f35-3dd3-4200-af85-ada65216b2de")
    end

    it "doesn't find match" do
      subject = Bosh::Bootstrap::MicroboshProviders::Cloudstack.new(microbosh_yml, settings, fog_compute)
      expect(subject).to receive(:owned_images).and_return([])
      expect(subject.find_image_for_stemcell("xxxx", "12345")).to be_nil
    end
  end
end
