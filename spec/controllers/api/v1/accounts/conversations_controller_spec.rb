require 'rails_helper'

RSpec.describe 'Conversations API', type: :request do
  let(:account) { create(:account) }

  describe 'GET /api/v1/accounts/{account.id}/conversations' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/conversations"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }
      let(:conversation) { create(:conversation, account: account) }

      before do
        create(:inbox_member, user: agent, inbox: conversation.inbox)
      end

    end
  end

  describe 'GET /api/v1/accounts/{account.id}/conversations/meta' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/conversations/meta"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }

      before do
        conversation = create(:conversation, account: account)
        create(:inbox_member, user: agent, inbox: conversation.inbox)
      end

      it 'returns all conversations counts' do
        get "/api/v1/accounts/#{account.id}/conversations/meta",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        body = JSON.parse(response.body, symbolize_names: true)
        expect(body[:meta].keys).to include(:all_count, :mine_count, :assigned_count, :unassigned_count)
        expect(body[:meta][:all_count]).to eq(1)
      end
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/conversations/search' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/conversations/search", params: { q: 'test' }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }

      before do
        conversation = create(:conversation, account: account)
        create(:message, conversation: conversation, account: account, content: 'test1')
        create(:message, conversation: conversation, account: account, content: 'test2')
        create(:inbox_member, user: agent, inbox: conversation.inbox)
      end

      it 'returns all conversations with messages containing the search query' do
        get "/api/v1/accounts/#{account.id}/conversations/search",
            headers: agent.create_new_auth_token,
            params: { q: 'test1' },
            as: :json

        expect(response).to have_http_status(:success)
        response_data = JSON.parse(response.body, symbolize_names: true)
        expect(response_data[:meta][:all_count]).to eq(1)
        expect(response_data[:payload].first[:messages].first[:content]).to eq 'test1'
      end
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/conversations/filter' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/conversations/filter", params: { q: 'test' }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }

      before do
        conversation = create(:conversation, account: account)
        create(:message, conversation: conversation, account: account, content: 'test1')
        create(:message, conversation: conversation, account: account, content: 'test2')
        create(:inbox_member, user: agent, inbox: conversation.inbox)
      end

      it 'returns error if the filters contain invalid attributes' do
        post "/api/v1/accounts/#{account.id}/conversations/filter",
             headers: agent.create_new_auth_token,
             params: {
               payload: [{
                 attribute_key: 'phone_number',
                 filter_operator: 'equal_to',
                 values: ['open']
               }]
             },
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        response_data = JSON.parse(response.body, symbolize_names: true)
        expect(response_data[:error]).to include('Invalid attribute key - [phone_number]')
      end

      it 'returns error if the filters contain invalid operator' do
        post "/api/v1/accounts/#{account.id}/conversations/filter",
             headers: agent.create_new_auth_token,
             params: {
               payload: [{
                 attribute_key: 'status',
                 filter_operator: 'eq',
                 values: ['open']
               }]
             },
             as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        response_data = JSON.parse(response.body, symbolize_names: true)
        expect(response_data[:error]).to eq('Invalid operator. The allowed operators for status are [equal_to,not_equal_to].')
      end
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/conversations/:id' do
    let(:conversation) { create(:conversation, account: account) }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }
      let(:administrator) { create(:user, account: account, role: :administrator) }

      it 'does not shows the conversation if you do not have access to it' do
        get "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:unauthorized)
      end

    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/conversations/:id' do
    let(:conversation) { create(:conversation, account: account) }
    let(:params) { { priority: 'high' } }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        patch "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}",
              params: params

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }
      let(:administrator) { create(:user, account: account, role: :administrator) }

      it 'does not update the conversation if you do not have access to it' do
        patch "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}",
              params: params,
              headers: agent.create_new_auth_token,
              as: :json

        expect(response).to have_http_status(:unauthorized)
      end

    end
  end

  describe 'POST /api/v1/accounts/{account.id}/conversations' do
    let(:contact) { create(:contact, account: account) }
    let(:inbox) { create(:inbox, account: account) }
    let!(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox) }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/conversations",
             params: { source_id: contact_inbox.source_id },
             as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent, auto_offline: false) }

      it 'will not create a new conversation if agent does not have access to inbox' do
        allow(Rails.configuration.dispatcher).to receive(:dispatch)
        additional_attributes = { test: 'test' }
        post "/api/v1/accounts/#{account.id}/conversations",
             headers: agent.create_new_auth_token,
             params: { source_id: contact_inbox.source_id, additional_attributes: additional_attributes },
             as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/conversations/:id/toggle_status' do
    let(:conversation) { create(:conversation, account: account) }
    let(:inbox) { create(:inbox, account: account) }
    let(:pending_conversation) { create(:conversation, inbox: inbox, account: account, status: 'pending') }
    let(:agent_bot) { create(:agent_bot, account: account) }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/toggle_status"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }
      let(:administrator) { create(:user, account: account, role: :administrator) }

      before do
        create(:inbox_member, user: agent, inbox: conversation.inbox)
      end

      it 'toggles the conversation status if status is empty' do
        expect(conversation.status).to eq('open')

        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/toggle_status",
             headers: agent.create_new_auth_token,
             params: { status: '' },
             as: :json

        expect(response).to have_http_status(:success)
        expect(conversation.reload.status).to eq('resolved')
      end

      it 'toggles the conversation status to open from pending' do
        conversation.update!(status: 'pending')

        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/toggle_status",
             headers: agent.create_new_auth_token,
             params: { status: 'open' },
             as: :json

        expect(response).to have_http_status(:success)
        expect(response).to conform_schema(200)
        expect(conversation.reload.status).to eq('open')
      end

      it 'self assign if agent changes the conversation status to open' do
        conversation.update!(status: 'pending')
        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/toggle_status",
             headers: agent.create_new_auth_token,
             as: :json
        expect(response).to have_http_status(:success)
        expect(conversation.reload.status).to eq('open')
        expect(conversation.reload.assignee_id).to eq(agent.id)
      end

      it 'disbale self assign if admin changes the conversation status to open' do
        conversation.update!(status: 'pending')
        conversation.update!(assignee_id: nil)
        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/toggle_status",
             headers: administrator.create_new_auth_token,
             as: :json
        expect(response).to have_http_status(:success)
        expect(conversation.reload.status).to eq('open')
        expect(conversation.reload.assignee_id).not_to eq(administrator.id)
      end

      it 'toggles the conversation status to specific status when parameter is passed' do
        expect(conversation.status).to eq('open')

        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/toggle_status",
             headers: agent.create_new_auth_token,
             params: { status: 'pending' },
             as: :json

        expect(response).to have_http_status(:success)
        expect(conversation.reload.status).to eq('pending')
      end

      it 'toggles the conversation status to snoozed when parameter is passed' do
        expect(conversation.status).to eq('open')
        snoozed_until = (DateTime.now.utc + 2.days).to_i
        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/toggle_status",
             headers: agent.create_new_auth_token,
             params: { status: 'snoozed', snoozed_until: snoozed_until },
             as: :json

        expect(response).to have_http_status(:success)
        expect(conversation.reload.status).to eq('snoozed')
        expect(conversation.reload.snoozed_until.to_i).to eq(snoozed_until)
      end
    end

    context 'when it is an authenticated bot' do
      # this test will basically ensure that the status actually changes
      # regardless of the value to be done
      it 'returns authorized for arbritrary status' do
        create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot)

        conversation.update!(status: 'open')
        expect(conversation.reload.status).to eq('open')
        snoozed_until = (DateTime.now.utc + 2.days).to_i

        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/toggle_status",
             headers: { api_access_token: agent_bot.access_token.token },
             params: { status: 'snoozed', snoozed_until: snoozed_until },
             as: :json

        expect(response).to have_http_status(:success)
        expect(conversation.reload.status).to eq('snoozed')
      end

      it 'triggers handoff event when moving from pending to open' do
        create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot)
        allow(Rails.configuration.dispatcher).to receive(:dispatch)

        post "/api/v1/accounts/#{account.id}/conversations/#{pending_conversation.display_id}/toggle_status",
             headers: { api_access_token: agent_bot.access_token.token },
             params: { status: 'open' },
             as: :json

        expect(response).to have_http_status(:success)
        expect(pending_conversation.reload.status).to eq('open')
        expect(Rails.configuration.dispatcher).to have_received(:dispatch)
          .with(Events::Types::CONVERSATION_BOT_HANDOFF, kind_of(Time), conversation: pending_conversation, notifiable_assignee_change: false,
                                                                        changed_attributes: anything, performed_by: anything)
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/conversations/:id/toggle_priority' do
    let(:inbox) { create(:inbox, account: account) }
    let(:conversation) { create(:conversation, account: account) }
    let(:pending_conversation) { create(:conversation, inbox: inbox, account: account, status: 'pending') }
    let(:agent) { create(:user, account: account, role: :agent) }
    let(:agent_bot) { create(:agent_bot, account: account) }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/toggle_priority"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:administrator) { create(:user, account: account, role: :administrator) }

      before do
        create(:inbox_member, user: agent, inbox: conversation.inbox)
      end

      it 'toggles the conversation priority to nil if no value is passed' do
        expect(conversation.priority).to be_nil

        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/toggle_priority",
             headers: agent.create_new_auth_token,
             params: { priority: 'low' },
             as: :json

        expect(response).to have_http_status(:success)
        expect(conversation.reload.priority).to eq('low')
      end

      it 'toggles the conversation priority' do
        conversation.priority = 'low'
        conversation.save!
        expect(conversation.reload.priority).to eq('low')

        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/toggle_priority",
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        expect(conversation.reload.priority).to be_nil
      end
    end

    context 'when it is an authenticated bot' do
      it 'toggle the priority of the bot agent conversation' do
        create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot)

        conversation.update!(priority: 'low')
        expect(conversation.reload.priority).to eq('low')

        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/toggle_priority",
             headers: { api_access_token: agent_bot.access_token.token },
             params: { priority: 'high' },
             as: :json

        expect(response).to have_http_status(:success)
        expect(conversation.reload.priority).to eq('high')
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/conversations/:id/toggle_typing_status' do
    let(:conversation) { create(:conversation, account: account) }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/toggle_typing_status"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }

      before do
        create(:inbox_member, user: agent, inbox: conversation.inbox)
      end

      it 'toggles the conversation status' do
        allow(Rails.configuration.dispatcher).to receive(:dispatch)
        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/toggle_typing_status",
             headers: agent.create_new_auth_token,
             params: { typing_status: 'on', is_private: false },
             as: :json

        expect(response).to have_http_status(:success)
        expect(Rails.configuration.dispatcher).to have_received(:dispatch)
          .with(Conversation::CONVERSATION_TYPING_ON, kind_of(Time), { conversation: conversation, user: agent, is_private: false })
      end

      it 'toggles the conversation status for private notes' do
        allow(Rails.configuration.dispatcher).to receive(:dispatch)
        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/toggle_typing_status",
             headers: agent.create_new_auth_token,
             params: { typing_status: 'on', is_private: true },
             as: :json

        expect(response).to have_http_status(:success)
        expect(Rails.configuration.dispatcher).to have_received(:dispatch)
          .with(Conversation::CONVERSATION_TYPING_ON, kind_of(Time), { conversation: conversation, user: agent, is_private: true })
      end
    end

    context 'when it is an authenticated bot' do
      let(:agent_bot) { create(:agent_bot, account: account) }

      it 'toggles the conversation typing status' do
        create(:agent_bot_inbox, inbox: conversation.inbox, agent_bot: agent_bot)
        allow(Rails.configuration.dispatcher).to receive(:dispatch)

        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/toggle_typing_status",
             headers: { api_access_token: agent_bot.access_token.token },
             params: { typing_status: 'on', is_private: false },
             as: :json

        expect(response).to have_http_status(:success)
        expect(Rails.configuration.dispatcher).to have_received(:dispatch)
          .with(Conversation::CONVERSATION_TYPING_ON, kind_of(Time), { conversation: conversation, user: agent_bot, is_private: false })
      end
    end

    context 'when it is an authenticated platform app token' do
      let(:platform_app) { create(:platform_app) }

      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/toggle_typing_status",
             headers: { api_access_token: platform_app.access_token.token },
             params: { typing_status: 'on', is_private: false },
             as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/conversations/:id/update_last_seen' do
    let(:conversation) { create(:conversation, account: account) }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/update_last_seen"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/conversations/:id/unread' do
    let(:conversation) { create(:conversation, account: account) }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/unread"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/conversations/:id/mute' do
    let(:conversation) { create(:conversation, account: account) }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/mute"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }

      before do
        create(:inbox_member, user: agent, inbox: conversation.inbox)
      end

      it 'mutes conversation' do
        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/mute",
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        expect(conversation.reload.resolved?).to be(true)
        expect(conversation.reload.muted?).to be(true)
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/conversations/:id/unmute' do
    let(:conversation) { create(:conversation, account: account).tap(&:mute!) }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/unmute"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }

      before do
        create(:inbox_member, user: agent, inbox: conversation.inbox)
      end

      it 'unmutes conversation' do
        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/unmute",
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        expect(conversation.reload.muted?).to be(false)
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/conversations/:id/transcript' do
    let(:conversation) { create(:conversation, account: account) }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/transcript"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }
      let(:params) { { email: 'test@test.com' } }

      before do
        create(:inbox_member, user: agent, inbox: conversation.inbox)
      end

      it 'mutes conversation' do
        mailer = double
        allow(ConversationReplyMailer).to receive(:with).and_return(mailer)
        allow(mailer).to receive(:conversation_transcript)
        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/transcript",
             headers: agent.create_new_auth_token,
             params: params,
             as: :json

        expect(response).to have_http_status(:success)
        expect(mailer).to have_received(:conversation_transcript).with(conversation, 'test@test.com')
      end

      it 'renders error when parameter missing' do
        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/transcript",
             headers: agent.create_new_auth_token,
             params: {},
             as: :json
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/conversations/:id/custom_attributes' do
    let(:conversation) { create(:conversation, account: account) }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/custom_attributes"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }
      let(:custom_attributes) { { user_id: 1001, created_date: '23/12/2012', subscription_id: 12 } }
      let(:valid_params) { { custom_attributes: custom_attributes } }

      before do
        create(:inbox_member, user: agent, inbox: conversation.inbox)
      end

      it 'updates custom attributes' do
        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/custom_attributes",
             headers: agent.create_new_auth_token,
             params: valid_params,
             as: :json

        expect(response).to have_http_status(:success)
        expect(conversation.reload.custom_attributes).not_to be_nil
        expect(conversation.reload.custom_attributes.count).to eq 3
      end
    end

    context 'when it is a bot' do
      let(:agent_bot) { create(:agent_bot, account: account) }
      let(:custom_attributes) { { bot_id: 1001, flow_name: 'support_flow', step: 'greeting' } }
      let(:valid_params) { { custom_attributes: custom_attributes } }

      before do
        create(:agent_bot_inbox, agent_bot: agent_bot, inbox: conversation.inbox)
      end

      it 'updates custom attributes' do
        post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/custom_attributes",
             headers: { api_access_token: agent_bot.access_token.token },
             params: valid_params,
             as: :json

        expect(response).to have_http_status(:success)
        expect(conversation.reload.custom_attributes).not_to be_nil
        expect(conversation.reload.custom_attributes.count).to eq 3
      end
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/conversations/:id/attachments' do
    let(:conversation) { create(:conversation, account: account) }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/attachments"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }
      let(:administrator) { create(:user, account: account, role: :administrator) }

      before do
        create(:message, :with_attachment, conversation: conversation, account: account, inbox: conversation.inbox, message_type: 'incoming')
      end

      it 'does not return the attachments if you do not have access to it' do
        get "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/attachments",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:unauthorized)
      end

      it 'return the attachments if you are an administrator' do
        get "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/attachments",
            headers: administrator.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        response_body = response.parsed_body
        expect(response_body['payload'].first['file_type']).to eq('image')
        expect(response_body['payload'].first['sender']['id']).to eq(conversation.messages.last.sender.id)
      end

      it 'return the attachments if you are an agent with access to inbox' do
        get "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/attachments",
            headers: administrator.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        response_body = response.parsed_body
        expect(response_body['payload'].length).to eq(1)
      end
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/conversations/:id' do
    let(:conversation) { create(:conversation, account: account) }
    let(:agent) { create(:user, account: account, role: :agent) }
    let(:administrator) { create(:user, account: account, role: :administrator) }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        delete "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated agent' do
      before do
        create(:inbox_member, user: agent, inbox: conversation.inbox)
      end

      it 'returns unauthorized' do
        delete "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}",
               headers: agent.create_new_auth_token,
               as: :json

        expect(response).to have_http_status(:unauthorized)
        response_body = response.parsed_body
        expect(response_body['error']).to eq('You are not authorized to do this action')
      end
    end

    context 'when it is an authenticated administrator' do
      before do
        create(:inbox_member, user: administrator, inbox: conversation.inbox)
      end

      it 'successfully deletes the conversation' do
        expect do
          delete "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}",
                 headers: administrator.create_new_auth_token,
                 as: :json
        end.to have_enqueued_job(DeleteObjectJob).with(conversation, administrator, anything)

        expect(response).to have_http_status(:ok)
      end

      it 'can delete conversations from inboxes without direct access' do
        other_inbox = create(:inbox, account: account)
        other_conversation = create(:conversation, account: account, inbox: other_inbox)

        expect do
          delete "/api/v1/accounts/#{account.id}/conversations/#{other_conversation.display_id}",
                 headers: administrator.create_new_auth_token,
                 as: :json
        end.to have_enqueued_job(DeleteObjectJob).with(other_conversation, administrator, anything)

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
