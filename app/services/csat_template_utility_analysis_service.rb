class CsatTemplateUtilityAnalysisService
  include CsatTemplateUtilityRubric

  pattr_initialize [:account!, :inbox!, :message!, { button_text: nil, language: 'en' }]

  def perform
    rule_based_result
  end

  private

  def rule_based_result
    text = sanitized_message
    marketing_hits_count = MARKETING_PATTERNS.count { |pattern| pattern.match?(text) }
    utility_hits_count = UTILITY_PATTERNS.count { |pattern| pattern.match?(text) }
    criteria = evaluate_criteria(text: text, marketing_hits_count: marketing_hits_count)
    classification = classify(criteria: criteria, utility_hits_count: utility_hits_count)
    build_rule_payload(
      classification: classification
    )
  end

  def build_rule_payload(payload)
    {
      classification: payload[:classification],
      optimized_message: optimized_message_for(payload[:classification])
    }
  end

  def sanitized_message
    message.to_s.squish
  end

  def classify(criteria:, utility_hits_count:)
    return 'LIKELY_MARKETING' unless criteria[:marketing_prohibition]
    return 'LIKELY_MARKETING' unless criteria[:prohibited_content]
    return 'LIKELY_UTILITY' if criteria.values.all? && utility_hits_count >= 2

    'UNCLEAR'
  end

  def optimized_message_for(classification)
    return sanitized_message if classification == 'LIKELY_UTILITY'

    build_input_aware_utility_message
  end
end
