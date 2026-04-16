# frozen_string_literal: true

module ForemanOvirt
  module ApiComputeResourcesControllerExtension
    extend ActiveSupport::Concern

    included do
      # rubocop:disable Rails/LexicallyScopedActionFilter
      before_action :convert_ovirt_datacenter_to_uuid, only: %i[create update]
      # rubocop:enable Rails/LexicallyScopedActionFilter
    end

    private

    # Converts oVirt datacenter names to UUIDs before saving.
    # This ensures API responses contain the UUID, not the datacenter name.
    def convert_ovirt_datacenter_to_uuid
      cr_params = params[:compute_resource]

      # Check if this is an oVirt resource:
      # - For create: check the provider param
      # - For update: check the existing resource type
      is_ovirt = if cr_params&.dig(:provider)&.downcase == 'ovirt'
                   true
                 elsif @compute_resource.is_a?(ForemanOvirt::Ovirt)
                   true
                 else
                   false
                 end

      return unless is_ovirt

      datacenter_param = cr_params&.dig(:datacenter)

      return if datacenter_param.blank? || Foreman.is_uuid?(datacenter_param)

      temp_cr = @compute_resource || ::ComputeResource.new_provider(cr_params.to_unsafe_hash.except(:datacenter))

      return unless temp_cr.respond_to?(:get_datacenter_uuid)

      temp_cr.test_connection
      # Mutate the params object directly. When the core create/update method runs,
      # it will read this updated UUID instead of the datacenter name string.
      params[:compute_resource][:datacenter] = temp_cr.get_datacenter_uuid(datacenter_param)
    end
  end
end
