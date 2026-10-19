# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'

require_relative 'preview_renderer'
require_relative 'rule'

module ActiveMail
  module Quality
    # The built-in rules that read the Mail message (subject, text part) rather than the HTML.
    class BuiltinMessageRules
      extend T::Sig

      sig { returns(T::Array[Rule]) }
      def rules
        [
          Rule.message(:translation_missing_text) { |mail| translation_missing_text_message(mail) },
          Rule.message(:html_part_present) { |mail| html_part_present_message(mail) },
          Rule.message(:text_part_present) { |mail| text_part_present_message(mail) },
          Rule.message(:text_part_plain) { |mail| text_part_plain_message(mail) },
          Rule.message(:text_entities) { |mail| text_entities_message(mail) }
        ]
      end

      private

      sig { params(mail: T.untyped).returns(T.nilable(String)) }
      def text_entities_message(mail)
        found = PreviewRenderer.text_body(mail).scan(BuiltinRules::HTML_ENTITY).uniq
        "text/plain part contains HTML entities: #{found.first(3).join(', ')}" unless found.empty?
      end

      sig { params(mail: T.untyped).returns(T.nilable(String)) }
      def translation_missing_text_message(mail)
        text = "#{mail.subject}\n#{PreviewRenderer.text_body(mail)}"
        'subject or text part contains a missing i18n translation' if text.match?(BuiltinRules::MISSING_TRANSLATION)
      end

      sig { params(mail: T.untyped).returns(T.nilable(String)) }
      def html_part_present_message(mail)
        'message has no HTML part' if PreviewRenderer.html_body(mail).empty?
      end

      sig { params(mail: T.untyped).returns(T.nilable(String)) }
      def text_part_present_message(mail)
        return if mail.multipart? && !PreviewRenderer.text_body(mail).strip.empty?

        'message must be multipart with a non-empty text/plain part'
      end

      sig { params(mail: T.untyped).returns(T.nilable(String)) }
      def text_part_plain_message(mail)
        'text/plain part contains HTML markup' if PreviewRenderer.text_body(mail).match?(BuiltinRules::MARKUP_IN_TEXT)
      end
    end
  end
end
