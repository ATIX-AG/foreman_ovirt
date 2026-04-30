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
      Rails.logger.info "[OVirt API] convert_ovirt_datacenter_to_uuid started"
      Rails.logger.debug "[OVirt API] cr_params: #{cr_params.inspect}"
      return unless ovirt_resource?(cr_params)

      datacenter_param = cr_params&.dig(:datacenter)
      Rails.logger.debug "[OVirt API] datacenter_param: #{datacenter_param}"
      return if datacenter_param.blank? || Foreman.is_uuid?(datacenter_param)

      uuid = fetch_datacenter_uuid(cr_params, datacenter_param)
      Rails.logger.info "[OVirt API] UUID conversion result: #{uuid}"
      params[:compute_resource][:datacenter] = uuid if uuid.present?
    rescue StandardError => e
      Rails.logger.warn "[OVirt API] Datacenter conversion failed: #{e.class}: #{e.message}"
      # Intentionally silent : model validations during save will catch and report credential errors
    end

    def ovirt_resource?(cr_params)
      resource = fetch_resource
      # Only process oVirt resources with datacenter names (not UUIDs)
      provider = cr_params&.dig(:provider) || resource&.provider
      is_ovirt = provider&.downcase == 'ovirt' || resource.is_a?(ForemanOvirt::Ovirt)
      Rails.logger.debug "[OVirt API] ovirt_resource? => #{is_ovirt} (provider: #{provider}, resource type: #{resource&.class})"
      is_ovirt
    end

    # Fetch resource manually since plugin hooks often run before core's `find_resource`
    def fetch_resource
      @compute_resource || (params[:id] && ::ComputeResource.unscoped.find_by(id: params[:id]))
    end

    def fetch_datacenter_uuid(cr_params, datacenter_param)
      resource = fetch_resource
      Rails.logger.debug "[OVirt API] fetch_datacenter_uuid called for: #{datacenter_param}"
      # Build temp CR credentials:
      # - For UPDATE: @compute_resource exists. We merge new incoming params into existing attributes
      #   so the temporary object has the URL/password needed to connect, even if not sent in this request.
      # - For CREATE: @compute_resource is nil. We fallback to using just the incoming request params.
      merged_params = resource&.attributes&.merge(cr_params.to_unsafe_hash) || cr_params.to_unsafe_hash
      merged_params[:provider] ||= 'ovirt'
      Rails.logger.debug "[OVirt API] Creating temp CR with provider: #{merged_params[:provider]}"

      temp_cr = ::ComputeResource.new_provider(merged_params.with_indifferent_access.except(:datacenter))
      Rails.logger.debug "[OVirt API] temp_cr created: #{temp_cr.class}"

      uuid = temp_cr.get_datacenter_uuid(datacenter_param)
      Rails.logger.debug "[OVirt API] get_datacenter_uuid returned: #{uuid}"
      uuid
    end
  end
end