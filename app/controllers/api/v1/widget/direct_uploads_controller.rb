class Api::V1::Widget::DirectUploadsController < ActiveStorage::DirectUploadsController
  include WebsiteTokenHelper

  DISALLOWED_CONTENT_TYPES = %w[
    image/svg+xml
    text/html
    application/xhtml+xml
    text/xml
    application/xml
  ].freeze

  MAX_BYTE_SIZE = 10 * 1024 * 1024

  before_action :set_web_widget
  before_action :set_contact
  before_action :validate_blob_params, only: :create

  def create
    return if @contact.nil? || @current_account.nil?

    super
  end

  private

  def validate_blob_params
    blob = params[:blob] || {}
    content_type = blob[:content_type].to_s.split(';').first&.strip&.downcase

    if DISALLOWED_CONTENT_TYPES.include?(content_type)
      render json: { error: 'Unsupported content type' }, status: :unprocessable_entity
    elsif blob[:byte_size].to_i > MAX_BYTE_SIZE
      render json: { error: 'File too large' }, status: :unprocessable_entity
    end
  end
end
