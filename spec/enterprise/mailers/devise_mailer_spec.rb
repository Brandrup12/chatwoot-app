# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Devise::Mailer' do
  describe 'confirmation_instructions with Enterprise features' do
    let(:account) { create(:account) }
    let!(:confirmable_user) { create(:user, inviter: inviter_val, account: account) }
    let(:inviter_val) { nil }
    let(:mail) { Devise::Mailer.confirmation_instructions(confirmable_user.reload, nil, {}) }

    before do
      confirmable_user.update!(confirmed_at: nil)
      confirmable_user.send(:generate_confirmation_token)
    end

    context 'when account does not have SAML enabled' do
      context 'when user has inviter' do
        let(:inviter_val) { create(:user, :administrator, skip_confirmation: true, account: account) }

        it 'shows standard invitation without SSO references' do
          expect(mail.body).to match('has invited you to try out Chatwoot')
          expect(mail.body).not_to match('via Single Sign-On')
          expect(mail.body).not_to match('SSO portal')
        end

        it 'shows password reset link' do
          expect(mail.body).to include('app/auth/password/edit')
        end
      end

      context 'when user has no inviter' do
        it 'shows standard welcome message and activation instructions' do
          expect(mail.body).to match('We have a suite of powerful tools ready for you to explore')
          expect(mail.body).to match('Please take a moment and click the link below and activate your account')
        end

        it 'shows confirmation link' do
          expect(mail.body).to include("app/auth/confirmation?confirmation_token=#{confirmable_user.confirmation_token}")
        end
      end

      context 'when user is already confirmed' do
        let(:inviter_val) { create(:user, :administrator, skip_confirmation: true, account: account) }

        before do
          confirmable_user.confirm
        end

        it 'shows regular login link' do
          expect(mail.body).to include('/auth/sign_in')
          expect(mail.body).not_to match('SSO portal')
        end
      end

      context 'when user updates email' do
        before do
          confirmable_user.update!(email: 'updated@example.com')
        end

        it 'shows confirmation link for email verification' do
          expect(mail.body).to include('app/auth/confirmation?confirmation_token')
          expect(confirmable_user.unconfirmed_email.blank?).to be false
        end
      end
    end
  end
end
