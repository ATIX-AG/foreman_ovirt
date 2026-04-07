# frozen_string_literal: true

require 'test_plugin_helper'
require 'fog/ovirt/models/compute/quota'

module ForemanOvirt
  class HostsControllerTest < ActionController::TestCase
    tests ::HostsController

    setup do
      User.current = users(:admin)
    end

    test '#host update preserves association despite quota validation' do
      hostgroup = FactoryBot.create(:hostgroup, :with_subnet, :with_domain, :with_os)

      compute_resource = FactoryBot.build(:ovirt_cr)
      compute_resource.stubs(:update_public_key)

      # Setup quota mock to test that quota validation doesn't interfere with host update
      quota = Fog::Ovirt::Compute::Quota.new(id: '1', name: 'Default')
      client_mock = mock.tap { |m| m.stubs(datacenters: [], quotas: [quota]) }
      compute_resource.stubs(:client).returns(client_mock)
      compute_resource.save!

      compute_resource.update(locations: hostgroup.locations, organizations: hostgroup.organizations)
      host = FactoryBot.create(:host, hostgroup: hostgroup, compute_resource: compute_resource)

      # Simulate form submission without compute_resource_id to test preservation
      host_attributes = host.attributes.except('id', 'created_at', 'updated_at', 'compute_resource_id')

      put :update, params: { commit: 'Update', id: host.id, host: host_attributes }, session: set_session_user

      assert_response :redirect
      host.reload
      assert_equal compute_resource.id, host.compute_resource_id,
        'Host should remain associated with compute resource after update'
    end

    private

    def set_session_user
      { user: User.current.id }
    end
  end
end
