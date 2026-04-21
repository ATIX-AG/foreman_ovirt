# frozen_string_literal: true

require 'test_plugin_helper'
require 'integration_test_helper'

module ForemanOvirt
  # Migrated from foreman core: tests oVirt compute profile template selection and
  # attribute population (skipped in plugin - requires full Foreman integration environment)
  #
  # This test is skipped by default in the plugin test suite because it requires webpack
  # assets to be available. The test is designed to run in a full Foreman integration
  # environment where webpack has been compiled.
  #
  # This follows the pattern in Foreman core (lib/tasks/jenkins.rake):
  #   task :integration => ['webpack:compile', 'jenkins:setup:minitest', 'rake:test:integration']
  class ComputeProfileJSTest < IntegrationTestWithJavascript
    setup do
      Fog.mock!
    end

    teardown do
      Fog.unmock!
    end

    test 'create compute profile' do
      unless ENV['RUN_INTEGRATION_TESTS']
        skip 'Requires full Foreman integration test environment with webpack assets. ' \
             'Set RUN_INTEGRATION_TESTS=true to run.'
      end

      @ovirt_cr = FactoryBot.create(:ovirt_cr)

      visit compute_profiles_path
      click_on('Create Compute Profile')
      fill_in('compute_profile_name', with: 'test')
      click_on('Submit')
      assert click_link(@ovirt_cr.to_s)
      selected_profile = find('#s2id_compute_attribute_compute_profile_id .select2-chosen').text
      assert select2('hwp_small', from: 'compute_attribute_vm_attrs_template')
      wait_for_ajax
      assert click_button('Submit')
      visit compute_profile_path(selected_profile)
      assert click_link(@ovirt_cr.to_s)
      assert_equal '512 MB', find_field('compute_attribute_vm_attrs_memory').value
      assert_equal '1', find_field('compute_attribute[vm_attrs][cores]').value
    end
  end
end
