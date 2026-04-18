# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Inbox do
  let!(:inbox) { create(:inbox) }

  describe 'member_ids_with_assignment_capacity' do
    let!(:inbox_member_1) { create(:inbox_member, inbox: inbox) }
    let!(:inbox_member_2) { create(:inbox_member, inbox: inbox) }
    let!(:inbox_member_3) { create(:inbox_member, inbox: inbox) }
    let!(:inbox_member_4) { create(:inbox_member, inbox: inbox) }

    before do
      create(:conversation, inbox: inbox, assignee: inbox_member_1.user)
      # to test conversations in other inboxes won't impact
      create_list(:conversation, 3, assignee: inbox_member_1.user)
      create_list(:conversation, 2, inbox: inbox, account: inbox.account, assignee: inbox_member_2.user)
      create_list(:conversation, 3, inbox: inbox, account: inbox.account, assignee: inbox_member_3.user)
    end

    it 'validated max_assignment_limit' do
      account = create(:account)
      expect(build(:inbox, account: account, auto_assignment_config: { max_assignment_limit: 0 })).not_to be_valid
      expect(build(:inbox, account: account, auto_assignment_config: {})).to be_valid
      expect(build(:inbox, account: account, auto_assignment_config: { max_assignment_limit: 1 })).to be_valid
    end

    it 'returns member ids with assignment capacity with inbox max_assignment_limit is configured' do
      # agent 1 has 1 conversations, agent 2 has 2 conversations, agent 3 has 3 conversations and agent 4 with none
      inbox.update(auto_assignment_config: { max_assignment_limit: 2 })
      expect(inbox.member_ids_with_assignment_capacity).to contain_exactly(inbox_member_1.user_id, inbox_member_4.user_id)
    end

    it 'returns all member ids when inbox max_assignment_limit is not configured' do
      expect(inbox.member_ids_with_assignment_capacity).to match_array(inbox.members.ids)
    end
  end

  describe 'member_ids_with_assignment_capacity with V2 capacity' do
    let(:account) { create(:account) }
    let(:v2_inbox) { create(:inbox, account: account, enable_auto_assignment: true) }

    let!(:agent1) { create(:user, account: account, role: :agent, auto_offline: false) }
    let!(:agent2) { create(:user, account: account, role: :agent, auto_offline: false) }

    before do
      create(:inbox_member, inbox: v2_inbox, user: agent1)
      create(:inbox_member, inbox: v2_inbox, user: agent2)

      allow(OnlineStatusTracker).to receive(:get_available_users).and_return(
        agent1.id.to_s => 'online',
        agent2.id.to_s => 'online'
      )
    end

    context 'when assignment_v2 is disabled (V1 path)' do
      before do
        v2_inbox.update(auto_assignment_config: { max_assignment_limit: 2 })
      end

      it 'uses V1 max_assignment_limit' do
        create_list(:conversation, 2, inbox: v2_inbox, account: account, assignee: agent1, status: :open)

        result = v2_inbox.member_ids_with_assignment_capacity
        expect(result).not_to include(agent1.id)
        expect(result).to include(agent2.id)
      end
    end
  end
end
