class Enterprise::Billing::HandleStripeEventService
  CLOUD_PLANS_CONFIG = 'CHATWOOT_CLOUD_PLANS'.freeze

  STARTUP_PLAN_FEATURES = Enterprise::Billing::ReconcilePlanFeaturesService::STARTUP_PLAN_FEATURES
  BUSINESS_PLAN_FEATURES = Enterprise::Billing::ReconcilePlanFeaturesService::BUSINESS_PLAN_FEATURES
  ENTERPRISE_PLAN_FEATURES = Enterprise::Billing::ReconcilePlanFeaturesService::ENTERPRISE_PLAN_FEATURES

  def perform(event:)
    @event = event

    case @event.type
    when 'customer.subscription.updated'
      process_subscription_updated
    when 'customer.subscription.deleted'
      process_subscription_deleted
    else
      Rails.logger.debug { "Unhandled event type: #{event.type}" }
    end
  end

  private

  def process_subscription_updated
    plan = find_plan(subscription['plan']['product']) if subscription['plan'].present?

    # skipping self hosted plan events
    return if plan.blank? || account.blank?

    update_account_attributes(subscription, plan)
    Enterprise::Billing::ReconcilePlanFeaturesService.new(account: account).perform
  end

  def update_account_attributes(subscription, plan)
    # https://stripe.com/docs/api/subscriptions/object
    account.update(
      custom_attributes: account.custom_attributes.merge(
        'stripe_customer_id' => subscription.customer,
        'stripe_price_id' => subscription['plan']['id'],
        'stripe_product_id' => subscription['plan']['product'],
        'plan_name' => plan['name'],
        'subscribed_quantity' => subscription['quantity'],
        'subscription_status' => subscription['status'],
        'subscription_ends_on' => Time.zone.at(subscription['current_period_end'])
      )
    )
  end

  def process_subscription_deleted
    # skipping self hosted plan events
    return if account.blank?

    Enterprise::Billing::CreateStripeCustomerService.new(account: account).perform
  end

  def subscription
    @subscription ||= @event.data.object
  end

  def previous_attributes
    @previous_attributes ||= JSON.parse((@event.data.previous_attributes || {}).to_json)
  end

  def plan_changed?
    return false if previous_attributes['plan'].blank?

    previous_plan_id = previous_attributes.dig('plan', 'id')
    current_plan_id = subscription['plan']['id']

    previous_plan_id != current_plan_id
  end

  def billing_period_renewed?
    return false if previous_attributes['current_period_start'].blank?

    previous_attributes['current_period_start'] != subscription['current_period_start']
  end

  def account
    @account ||= Account.where("custom_attributes->>'stripe_customer_id' = ?", subscription.customer).first
  end

  def find_plan(plan_id)
    cloud_plans = InstallationConfig.find_by(name: CLOUD_PLANS_CONFIG)&.value || []
    cloud_plans.find { |config| config['product_id'].include?(plan_id) }
  end
end
