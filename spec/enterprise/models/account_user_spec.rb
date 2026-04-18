# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccountUser, type: :model do
  describe 'associations' do
    # option and dependant nullify
    it { is_expected.to belong_to(:custom_role).optional }
  end

  describe 'permissions' do
    context 'when custom role is assigned' do
      it 'returns permissions of the custom role along with `custom_role` permission' do
        account = create(:account)
        custom_role = create(:custom_role, account: account)
        account_user = create(:account_user, account: account, custom_role: custom_role)

        expect(account_user.permissions).to eq(custom_role.permissions + ['custom_role'])
      end
    end

    context 'when custom role is not assigned' do
      it 'returns permissions of the default role' do
        account = create(:account)
        account_user = create(:account_user, account: account)

        expect(account_user.permissions).to eq([account_user.role])
      end
    end
  end

end
