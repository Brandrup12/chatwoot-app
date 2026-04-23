# One-time bootstrap: creates the first admin account and logs the API token.
# Gated on BOOTSTRAP_ADMIN_EMAIL env var — remove this file and the env var after first boot.
return unless ENV['BOOTSTRAP_ADMIN_EMAIL'].present? && Account.count.zero?

Rails.application.config.after_initialize do
  begin
    email    = ENV['BOOTSTRAP_ADMIN_EMAIL']
    password = ENV.fetch('BOOTSTRAP_ADMIN_PASSWORD', 'ChangeMe2026!')

    account = Account.create!(name: 'HelpCore Gateway', locale: :en)
    user = User.new(
      name: 'Nicklas Brandrup',
      email: email,
      password: password,
      password_confirmation: password
    )
    user.confirm
    user.save!
    AccountUser.create!(account: account, user: user, role: :administrator)
    token = user.access_token.token

    Rails.logger.info "[bootstrap] Account #{account.id} created. API token: #{token}"
  rescue => e
    Rails.logger.error "[bootstrap] Failed: #{e.message}"
  end
end
