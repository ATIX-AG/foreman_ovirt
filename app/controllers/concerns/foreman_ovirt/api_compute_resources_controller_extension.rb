# frozen_string_literal: true

module ForemanOvirt
  module ApiComputeResourcesControllerExtension
    extend ActiveSupport::Concern

    included do
      # rubocop:disable Rails/LexicallyScopedActionFilter
      before_action :convert_datacenter_to_uuid, only: %i[create update]
      # rubocop:enable Rails/LexicallyScopedActionFilter
    end

    private

    def convert_datacenter_to_uuid
      datacenter = params[:compute_resource][:datacenter]
      return if datacenter.blank? || Foreman.is_uuid?(datacenter)

      if params[:action] == 'create'
        return unless compute_resource_params[:provider]&.downcase == 'ovirt'
        @compute_resource = ComputeResource.new_provider(compute_resource_params.except(:datacenter))
      end

      uuid = change_datacenter_to_uuid(datacenter)
      params[:compute_resource][:datacenter] = uuid if uuid.present?
    rescue StandardError
      # Intentionally silent : model validations during save will catch and report credential errors
    end

    def change_datacenter_to_uuid(datacenter)
      return unless @compute_resource.respond_to?(:get_datacenter_uuid)
      @compute_resource.test_connection
      @compute_resource.get_datacenter_uuid(datacenter)
    end
  end
end
