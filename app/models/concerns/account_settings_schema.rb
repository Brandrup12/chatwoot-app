module AccountSettingsSchema
  extend ActiveSupport::Concern

  SETTINGS_PARAMS_SCHEMA = {
    'type': 'object',
    'properties':
      {
        'auto_resolve_after': { 'type': %w[integer null], 'minimum': 10, 'maximum': 1_439_856 },
        'auto_resolve_message': { 'type': %w[string null] },
        'auto_resolve_ignore_waiting': { 'type': %w[boolean null] },
        'auto_resolve_label': { 'type': %w[string null] },
        'keep_pending_on_bot_failure': { 'type': %w[boolean null] },
        'conversation_required_attributes': {
          'type': %w[array null],
          'items': { 'type': 'string' }
        }
      },
    'required': [],
    'additionalProperties': true
  }.to_json.freeze
end
