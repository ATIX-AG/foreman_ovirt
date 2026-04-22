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

    def convert_ovirt_datacenter_to_uuid
      cr_params = params[:compute_resource]

      # Only process oVirt resources with datacenter names (not UUIDs)
      is_ovirt = cr_params&.dig(:provider)&.downcase == 'ovirt' || @compute_resource.is_a?(ForemanOvirt::Ovirt)
      return unless is_ovirt

      datacenter_param = cr_params&.dig(:datacenter)
      return if datacenter_param.blank? || Foreman.is_uuid?(datacenter_param)

      # Build temp CR credentials:
      # - For UPDATE: @compute_resource exists. We merge new incoming params into existing attributes
      #   so the temporary object has the URL/password needed to connect, even if not sent in this request.
      # - For CREATE: @compute_resource is nil. We fallback to using just the incoming request params.
      merged_params = @compute_resource&.attributes&.merge(cr_params.to_unsafe_hash) || cr_params.to_unsafe_hash
      temp_cr = ::ComputeResource.new_provider(merged_params.except(:datacenter))

      # Convert datacenter name to UUID
      params[:compute_resource][:datacenter] = temp_cr.get_datacenter_uuid(datacenter_param)
    rescue Foreman::Exception
      # Intentionally silent - model validations during save will catch and report credential errors
    end
  end
end
