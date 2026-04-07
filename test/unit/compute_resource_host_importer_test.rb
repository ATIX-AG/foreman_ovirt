# frozen_string_literal: true

require 'test_plugin_helper'

module ForemanOvirt
  class ComputeResourceHostImporterTest < ActiveSupport::TestCase
    setup do
      Fog.mock!
      User.current = users :admin
    end

    teardown do
      Fog.unmock!
    end

    let(:importer) do
      ComputeResourceHostImporter.new(
        compute_resource: compute_resource,
        vm: vm
      )
    end
    let(:host) { importer.host }
    let(:vm) { compute_resource.find_vm_by_uuid(uuid) }

    context 'on ovirt' do
      let(:uuid) { '52b9406e-cf66-4867-8655-719a094e324c' }

      let(:compute_resource) do
        cr = FactoryBot.build(:ovirt_cr)
        client = mock
        servers = mock

        # Create mock VM with required attributes for host import
        vm = mock('vm')
        vm.stubs(:identity).returns(uuid)
        vm.stubs(:hostname).returns('vm01')
        vm.stubs(:name).returns('vm01')
        vm.stubs(:mac).returns('00:1a:4a:23:1b:8f')
        vm.stubs(:attributes).returns({})
        vm.stubs(:volumes).returns([])

        # For compute attributes, the importer needs to access interfaces
        interface = mock('interface')
        interface.stubs(:name).returns('nic1')
        interface.stubs(:mac).returns('00:1a:4a:23:1b:8f')
        interface.stubs(:network).returns('00000000-0000-0000-0000-000000000009')
        interface.stubs(:vnic_profile).returns('871f3a06-ef53-4ab1-922f-5aa2bea2e94e')
        interface.stubs(:interface).returns('virtio')

        vm.stubs(:interfaces).returns([interface])

        servers.stubs(:get).with(uuid).returns(vm)
        client.stubs(:servers).returns(servers)
        cr.stubs(:client).returns(client)
        cr
      end

      test 'imports the VM with all parameters' do
        assert_equal 'vm01', host.name
        assert_equal uuid, host.uuid
        assert_nil host.domain
        assert_equal '00:1a:4a:23:1b:8f', host.mac
        assert_equal(
          {
            'name' => 'nic1',
            'network' => '00000000-0000-0000-0000-000000000009',
            'interface' => 'virtio',
            'vnic_profile' => '871f3a06-ef53-4ab1-922f-5aa2bea2e94e',
          },
          host.primary_interface.compute_attributes
        )
        assert_equal compute_resource, host.compute_resource
      end
    end
  end
end
