# frozen_string_literal: true

require 'test_plugin_helper'
require 'fog/ovirt/models/compute/quota'

module Api
  module V2
    class OvirtComputeResourcesControllerTest < ActionController::TestCase
      tests Api::V2::ComputeResourcesController

      def setup
        Fog.mock!
      end

      def teardown
        Fog.unmock!
      end

      context 'ovirt available resources' do
        setup do
          @ovirt_object = Object.new
          @ovirt_object.stubs(:name).returns('test_ovirt_object')
          @ovirt_object.stubs(:id).returns('my11-test35-uuid99')

          quota = Fog::Ovirt::Compute::Quota.new(id: '1', name: 'Default')
          client_mock = mock.tap { |m| m.stubs(datacenters: [], quotas: [quota], servers: []) }
          ForemanOvirt::Ovirt.any_instance.stubs(:client).returns(client_mock)

          @ovirt_cr = FactoryBot.create(:ovirt_cr)
        end

        teardown do
          if @response.present? && @response.code.to_i.between?(200, 299)
            available_objects = ActiveSupport::JSON.decode(@response.body)
            assert_not_empty available_objects
          end
        end

        test 'should get available virtual machines' do
          ForemanOvirt::Ovirt.any_instance.stubs(:available_virtual_machines).returns([@ovirt_object])
          get :available_virtual_machines, params: { id: @ovirt_cr.to_param }
        end

        test 'should get available networks' do
          ForemanOvirt::Ovirt.any_instance.stubs(:available_networks).returns([@ovirt_object])
          get :available_networks, params: { id: @ovirt_cr.to_param, cluster_id: '123-456-789' }
        end

        test 'should get available clusters' do
          ForemanOvirt::Ovirt.any_instance.stubs(:available_clusters).returns([@ovirt_object])
          get :available_clusters, params: { id: @ovirt_cr.to_param }
        end

        test 'should get available storage domains' do
          ForemanOvirt::Ovirt.any_instance.stubs(:available_storage_domains).returns([@ovirt_object])
          get :available_storage_domains, params: { id: @ovirt_cr.to_param }
        end
      end

      context 'ovirt datacenters' do
        setup do
          quota = Fog::Ovirt::Compute::Quota.new(id: '1', name: 'Default')
          client_mock = mock.tap { |m| m.stubs(datacenters: [], quotas: [quota], servers: []) }
          ForemanOvirt::Ovirt.any_instance.stubs(:client).returns(client_mock)
        end

        test 'should create with datacenter name' do
          datacenter_uuid = Foreman.uuid
          ForemanOvirt::Ovirt.any_instance.stubs(:datacenters).returns([['test', datacenter_uuid]])
          ForemanOvirt::Ovirt.any_instance.stubs(:test_connection).returns(true)

          attrs = { name: 'Ovirt-create-test', url: 'https://myovirt/api', provider: 'ovirt',
                    datacenter: 'test', user: 'user@example.com', password: 'secret' }
          post :create, params: { compute_resource: attrs }

          assert_response :created
          show_response = ActiveSupport::JSON.decode(@response.body)
          # Assert it was converted to the specific UUID we mocked
          assert_equal datacenter_uuid, show_response['datacenter']
        end

        test 'should create with datacenter uuid' do
          datacenter_uuid = Foreman.uuid
          ForemanOvirt::Ovirt.any_instance.stubs(:datacenters).returns([['test', datacenter_uuid]])

          attrs = { name: 'Ovirt-create-test', url: 'https://myovirt/api', provider: 'ovirt',
                    datacenter: datacenter_uuid, user: 'user@example.com', password: 'secret' }
          post :create, params: { compute_resource: attrs }

          assert_response :created
          show_response = ActiveSupport::JSON.decode(@response.body)
          assert Foreman.is_uuid?(show_response['datacenter'])
        end

        test 'should update with datacenter name' do
          datacenter_uuid = Foreman.uuid
          compute_resource = FactoryBot.create(:ovirt_cr)

          # Mock the client to include the datacenters for the extension to find
          quota = Fog::Ovirt::Compute::Quota.new(id: '1', name: 'Default')
          client_mock = mock.tap { |m| m.stubs(datacenters: [], quotas: [quota], servers: []) }
          ForemanOvirt::Ovirt.any_instance.stubs(:client).returns(client_mock)
          ForemanOvirt::Ovirt.any_instance.stubs(:datacenters).returns([['test', datacenter_uuid]])
          ForemanOvirt::Ovirt.any_instance.stubs(:test_connection).returns(true)

          attrs = { datacenter: 'test' }
          put :update, params: { id: compute_resource.id, compute_resource: attrs }

          assert_response :ok
          show_response = ActiveSupport::JSON.decode(@response.body)

          # Assert it was converted to the specific UUID we mocked
          assert_equal datacenter_uuid, show_response['datacenter']
        end

        test 'should handle datacenter conversion failure' do
          # Simulate connection/SSL error during conversion
          ForemanOvirt::Ovirt.any_instance.stubs(:datacenters).raises(StandardError.new('Connection refused'))

          attrs = { name: 'Ovirt-rescue-test', url: 'https://myovirt/api', provider: 'ovirt',
                    datacenter: 'Failing-DC', user: 'user@example.com', password: 'secret' }
          post :create, params: { compute_resource: attrs }

          # Should still create (rescue block catches exception)
          # Datacenter stays as-is, not converted to UUID
          assert_response :created
          show_response = ActiveSupport::JSON.decode(@response.body)
          assert_equal 'Failing-DC', show_response['datacenter']
        end

        test 'should skip datacenter conversion if datacenter param is blank' do
          attrs = { name: 'Ovirt-blank-test', url: 'https://myovirt/api', provider: 'ovirt',
                    datacenter: '', user: 'user@example.com', password: 'secret' }
          post :create, params: { compute_resource: attrs }

          assert_response :created
          show_response = ActiveSupport::JSON.decode(@response.body)

          # Datacenter should remain blank/nil, not converted
          assert_includes [nil, ''], show_response['datacenter']
        end

        test 'should skip conversion and preserve existing datacenter if omitted from update params' do
          compute_resource = FactoryBot.create(:ovirt_cr)
          original_datacenter = compute_resource.datacenter

          # Update only description, omit datacenter entirely
          attrs = { description: 'Only updating the description' }
          put :update, params: { id: compute_resource.id, compute_resource: attrs }

          assert_response :ok
          show_response = ActiveSupport::JSON.decode(@response.body)

          # Description updated, but original datacenter UUID untouched
          assert_equal 'Only updating the description', show_response['description']
          assert_equal original_datacenter, show_response['datacenter']
        end
      end

      context 'ovirt cache refreshing' do
        test 'should fail if unsupported' do
          ovirt_cr = FactoryBot.create(:ovirt_cr)
          put :refresh_cache, params: { id: ovirt_cr.to_param }
          assert_response :error
        end
      end
    end
  end
end
