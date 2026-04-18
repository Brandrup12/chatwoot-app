# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Account, type: :model do
  include ActiveJob::TestHelper

  describe 'associations' do
    it { is_expected.to have_many(:sla_policies).dependent(:destroy_async) }
    it { is_expected.to have_many(:applied_slas).dependent(:destroy_async) }
    it { is_expected.to have_many(:custom_roles).dependent(:destroy_async) }
  end

  describe 'sla_policies' do
    let!(:account) { create(:account) }
    let!(:sla_policy) { create(:sla_policy, account: account) }

    it 'returns associated sla policies' do
      expect(account.sla_policies).to eq([sla_policy])
    end

    it 'deletes associated sla policies' do
      perform_enqueued_jobs do
        account.destroy!
      end
      expect { sla_policy.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  context 'with usage_limits' do
    let(:account) { create(:account, { custom_attributes: { plan_name: 'startups' } }) }

    before do
      create(:installation_config, name: 'ACCOUNT_AGENTS_LIMIT', value: 20)
    end

    it 'returns max limits from global config when enterprise version' do
      expect(account.usage_limits[:agents]).to eq(20)
    end

    it 'returns max limits from account when enterprise version' do
      account.update(limits: { agents: 10 })
      expect(account.usage_limits[:agents]).to eq(10)
    end

    it 'returns limits based on subscription' do
      account.update(limits: { agents: 10 }, custom_attributes: { subscribed_quantity: 5 })
      expect(account.usage_limits[:agents]).to eq(5)
    end

    it 'returns max limits from global config if account limit is absent' do
      account.update(limits: { agents: '' })
      expect(account.usage_limits[:agents]).to eq(20)
    end

    it 'returns max limits from app limit if account limit and installation config is absent' do
      account.update(limits: { agents: '' })
      InstallationConfig.where(name: 'ACCOUNT_AGENTS_LIMIT').update(value: '')

      expect(account.usage_limits[:agents]).to eq(ChatwootApp.max_limit)
    end
  end

  describe 'subscribed_features' do
    let(:account) { create(:account) }
    let(:plan_features) do
      {
        'hacker' => %w[feature1 feature2],
        'startups' => %w[feature1 feature2 feature3 feature4]
      }
    end

    before do
      InstallationConfig.where(name: 'CHATWOOT_CLOUD_PLAN_FEATURES').first_or_create(value: plan_features)
    end

    context 'when plan_name is hacker' do
      it 'returns the features for the hacker plan' do
        account.custom_attributes = { 'plan_name': 'hacker' }
        account.save!

        expect(account.subscribed_features).to eq(%w[feature1 feature2])
      end
    end

    context 'when plan_name is startups' do
      it 'returns the features for the startups plan' do
        account.custom_attributes = { 'plan_name': 'startups' }
        account.save!

        expect(account.subscribed_features).to eq(%w[feature1 feature2 feature3 feature4])
      end
    end

    context 'when plan_features is blank' do
      it 'returns an empty array' do
        account.custom_attributes = {}
        account.save!

        expect(account.subscribed_features).to be_nil
      end
    end
  end

  describe 'account deletion' do
    let(:account) { create(:account) }
    let(:admin) { create(:user, account: account, role: :administrator) }

    describe '#mark_for_deletion' do
      it 'sets the marked_for_deletion_at and marked_for_deletion_reason attributes' do
        expect do
          account.mark_for_deletion('inactivity')
        end.to change { account.reload.custom_attributes['marked_for_deletion_at'] }.from(nil).to(be_present)
           .and change { account.reload.custom_attributes['marked_for_deletion_reason'] }.from(nil).to('inactivity')
      end

      it 'sends a user-initiated deletion email when reason is manual_deletion' do
        mailer = double
        expect(AdministratorNotifications::AccountNotificationMailer).to receive(:with).with(account: account).and_return(mailer)
        expect(mailer).to receive(:account_deletion_user_initiated).with(account, 'manual_deletion').and_return(mailer)
        expect(mailer).to receive(:deliver_later)

        account.mark_for_deletion('manual_deletion')
      end

      it 'sends a system-initiated deletion email when reason is not manual_deletion' do
        mailer = double
        expect(AdministratorNotifications::AccountNotificationMailer).to receive(:with).with(account: account).and_return(mailer)
        expect(mailer).to receive(:account_deletion_for_inactivity).with(account, 'inactivity').and_return(mailer)
        expect(mailer).to receive(:deliver_later)

        account.mark_for_deletion('inactivity')
      end

      it 'returns true when successful' do
        expect(account.mark_for_deletion).to be_truthy
      end
    end

    describe '#unmark_for_deletion' do
      before do
        account.update!(
          custom_attributes: {
            'marked_for_deletion_at' => 7.days.from_now.iso8601,
            'marked_for_deletion_reason' => 'test_reason'
          }
        )
      end

      it 'removes the marked_for_deletion_at and marked_for_deletion_reason attributes' do
        expect do
          account.unmark_for_deletion
        end.to change { account.reload.custom_attributes['marked_for_deletion_at'] }.from(be_present).to(nil)
           .and change { account.reload.custom_attributes['marked_for_deletion_reason'] }.from('test_reason').to(nil)
      end

      it 'returns true when successful' do
        expect(account.unmark_for_deletion).to be_truthy
      end
    end
  end
end
