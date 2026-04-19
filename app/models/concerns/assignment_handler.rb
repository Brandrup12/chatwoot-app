module AssignmentHandler
  extend ActiveSupport::Concern
  include Events::Types

  included do
    after_commit :notify_assignment_change, :process_assignment_changes
  end

  private

  def notify_assignment_change
    dispatcher_dispatch(ASSIGNEE_CHANGED, previous_changes) if saved_change_to_assignee_id?
  end

  def process_assignment_changes
    process_assignment_activities
  end

  def process_assignment_activities
    user_name = Current.user.name if Current.user.present?
    create_assignee_change_activity(user_name) if saved_change_to_assignee_id?
  end

  def self_assign?(assignee_id)
    assignee_id.present? && Current.user&.id == assignee_id
  end
end
