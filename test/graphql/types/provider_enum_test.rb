# frozen_string_literal: true

require 'test_plugin_helper'

module ForemanOvirt
  class ProviderEnumTest < ActiveSupport::TestCase
    test 'Ovirt provider is registered in ProviderEnum when plugin is loaded' do
      assert_includes ::Types::ProviderEnum.values.keys, 'Ovirt',
        'Ovirt provider should be registered in ProviderEnum by the foreman_ovirt plugin'
    end
  end
end
