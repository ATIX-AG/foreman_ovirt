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
    # Handles credential merging for updates to use new credentials if provided.
    def convert_ovirt_datacenter_to_uuid
      cr_params = params[:compute_resource]

      # Only process oVirt resources with datacenter names (not UUIDs)
      is_ovirt = cr_params&.dig(:provider)&.downcase == 'ovirt' || @compute_resource.is_a?(ForemanOvirt::Ovirt)
      return unless is_ovirt

      datacenter_param = cr_params&.dig(:datacenter)
      return if datacenter_param.blank? || Foreman.is_uuid?(datacenter_param)

      # Build temp CR with merged attributes for updates (to use new credentials if provided)
      if @compute_resource
        merged = @compute_resource.attributes.merge(cr_params.to_unsafe_hash).except(:datacenter)
        temp_cr = ::ComputeResource.new_provider(merged)
      else
        temp_cr = ::ComputeResource.new_provider(cr_params.to_unsafe_hash.except(:datacenter))
      end

      return unless temp_cr.respond_to?(:get_datacenter_uuid)

      # Test connection and halt on errors
      temp_cr.test_connection
      if temp_cr.errors.any?
        render_exception(
          Foreman::Exception.new(temp_cr.errors.full_messages.join('; ')),
          status: :unprocessable_entity
        )
        return
      end

      # Convert datacenter name to UUID
      params[:compute_resource][:datacenter] = temp_cr.get_datacenter_uuid(datacenter_param)
    end
  end
end
