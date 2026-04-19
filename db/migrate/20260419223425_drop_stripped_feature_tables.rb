class DropStrippedFeatureTables < ActiveRecord::Migration[7.1]
  STRIPPED_TABLES = %w[
    account_saml_settings
    agent_capacity_policies
    applied_slas
    article_embeddings
    articles
    assignment_policies
    audits
    automation_rules
    calls
    campaigns
    canned_responses
    captain_assistant_responses
    captain_assistants
    captain_custom_tools
    captain_documents
    captain_inboxes
    captain_scenarios
    categories
    channel_sms
    channel_tiktok
    channel_twilio_sms
    channel_twitter_profiles
    channel_voice
    copilot_messages
    copilot_threads
    inbox_assignment_policies
    inbox_capacity_limits
    leaves
    macros
    portals
    portals_members
    related_categories
    reporting_events
    reporting_events_rollups
    sla_events
    sla_policies
    team_members
    teams
  ].freeze

  def up
    remove_foreign_key :inboxes, :portals if foreign_key_exists?(:inboxes, :portals)

    remove_column :inboxes, :portal_id if column_exists?(:inboxes, :portal_id)
    remove_column :conversations, :team_id if column_exists?(:conversations, :team_id)
    remove_column :conversations, :campaign_id if column_exists?(:conversations, :campaign_id)
    remove_column :conversations, :sla_policy_id if column_exists?(:conversations, :sla_policy_id)
    remove_column :account_users, :agent_capacity_policy_id if column_exists?(:account_users, :agent_capacity_policy_id)

    STRIPPED_TABLES.each do |table|
      drop_table(table) if table_exists?(table)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          'Stripped-feature tables were removed intentionally. Restore from develop if needed.'
  end
end
