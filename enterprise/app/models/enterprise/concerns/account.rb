module Enterprise::Concerns::Account
  extend ActiveSupport::Concern

  included do
    store_accessor :settings, :conversation_required_attributes

    has_many :custom_roles, dependent: :destroy_async

    has_many :companies, dependent: :destroy_async
  end
end
