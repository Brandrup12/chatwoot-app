module Enterprise::Api::V1::Accounts::ConversationsController
  extend ActiveSupport::Concern

  def reporting_events
    @reporting_events = @conversation.reporting_events.order(created_at: :asc)
  end

  def permitted_update_params
    super.merge(params.permit(:sla_policy_id))
  end
end
