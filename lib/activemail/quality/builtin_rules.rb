# typed: strict
# frozen_string_literal: true

require 'nokogiri'
require 'sorbet-runtime'

require_relative '../libxml'
require_relative 'preview_renderer'
require_relative 'rule'

module ActiveMail
  module Quality
    class BuiltinRules
      extend T::Sig

      NAMES = T.let(
        %i[
          max_bytes parse_error table_role img_alt lang min_full_doc_bytes translation_missing single_root
          translation_missing_text html_part_present text_part_present text_part_plain
        ].freeze,
        T::Array[Symbol]
      )
      MARKUP_IN_TEXT = %r{<(?:table|div|span|p|br|a)[\s>/]}i
      MISSING_TRANSLATION = /translation missing/i

      sig { params(max_bytes: Integer, min_full_doc_bytes: Integer).void }
      def initialize(max_bytes:, min_full_doc_bytes:)
        # A non-positive threshold would silently disable (or invert) a check.
        @max_bytes = T.let(positive_threshold!(:max_bytes, max_bytes), Integer)
        @min_full_doc_bytes = T.let(positive_threshold!(:min_full_doc_bytes, min_full_doc_bytes), Integer)
      end

      sig { returns(T::Array[Rule]) }
      def rules
        structure_rules + content_rules + message_rules
      end

      private

      sig { returns(T::Array[Rule]) }
      def structure_rules
        [
          Rule.html(:max_bytes) { |_doc, html| size_message(html) },
          # The Core surfaces libxml2 repairs on input; the validation layer must not
          # silently bless malformed *output* (mismatched tags, bad entities) before send.
          Rule.html(:parse_error) { |doc, _html| parse_error_message(doc) },
          Rule.html(:table_role) { |doc, _html| table_role_message(doc) },
          Rule.html(:img_alt) { |doc, _html| img_alt_message(doc) }
        ]
      end

      sig { returns(T::Array[Rule]) }
      def content_rules
        [
          Rule.html(:translation_missing) { |doc, html| translation_missing_message(doc, html) },
          Rule.html(:single_root) { |_doc, html| single_root_messages(html) },
          Rule.html(:min_full_doc_bytes) { |_doc, html| min_full_doc_message(html) },
          Rule.html(:lang) { |doc, html| lang_message(doc, html) }
        ]
      end

      sig { returns(T::Array[Rule]) }
      def message_rules
        [
          Rule.message(:translation_missing_text) { |mail| translation_missing_text_message(mail) },
          Rule.message(:html_part_present) { |mail| html_part_present_message(mail) },
          Rule.message(:text_part_present) { |mail| text_part_present_message(mail) },
          Rule.message(:text_part_plain) { |mail| text_part_plain_message(mail) }
        ]
      end

      sig { params(name: Symbol, value: Integer).returns(Integer) }
      def positive_threshold!(name, value)
        raise ArgumentError, "#{name} must be a positive integer, got #{value}" unless value.positive?

        value
      end

      sig { params(html: String).returns(T.nilable(String)) }
      def size_message(html)
        return if html.bytesize <= @max_bytes

        "HTML is #{html.bytesize} bytes, exceeds #{@max_bytes} (Gmail clipping)"
      end

      sig { params(doc: Nokogiri::XML::Document).returns(T.nilable(String)) }
      def parse_error_message(doc)
        errors = doc.errors.reject { |e| e.code == LIBXML_UNKNOWN_TAG_CODE }
        return if errors.empty?

        "malformed HTML: #{errors.first(3).map { |e| e.message.to_s.strip }.join('; ')}"
      end

      sig { params(doc: Nokogiri::XML::Document).returns(T.nilable(String)) }
      def table_role_message(doc)
        offenders = doc.css('table').count { |table| table['role'] != 'presentation' }
        %(#{offenders} <table> missing role="presentation") unless offenders.zero?
      end

      sig { params(doc: Nokogiri::XML::Document).returns(T.nilable(String)) }
      def img_alt_message(doc)
        offenders = doc.css('img').count { |img| !img.key?('alt') }
        "#{offenders} <img> missing an alt attribute" unless offenders.zero?
      end

      sig { params(doc: Nokogiri::XML::Document, html: String).returns(T.nilable(String)) }
      def translation_missing_message(doc, html)
        return unless html.match?(MISSING_TRANSLATION) || doc.at_css('.translation_missing')

        'rendered HTML contains a missing i18n translation'
      end

      # Counted on the raw string: libxml2 silently merges duplicate roots.
      sig { params(html: String).returns(T::Array[String]) }
      def single_root_messages(html)
        { html: /<html[\s>]/i, body: /<body[\s>]/i }.filter_map do |tag, pattern|
          count = html.scan(pattern).size
          "#{count} <#{tag}> roots, expected at most one" if count > 1
        end
      end

      sig { params(html: String).returns(T.nilable(String)) }
      def min_full_doc_message(html)
        return unless ::ActiveMail.full_document?(html) && html.bytesize < @min_full_doc_bytes

        "full document is only #{html.bytesize} bytes (under #{@min_full_doc_bytes})"
      end

      sig { params(doc: Nokogiri::XML::Document, html: String).returns(T.nilable(String)) }
      def lang_message(doc, html)
        return unless ::ActiveMail.full_document?(html)

        html_tag = doc.at_css('html')
        lang = html_tag && html_tag['lang']
        '<html> must declare a non-blank lang attribute' if lang.nil? || lang.strip.empty?
      end

      sig { params(mail: T.untyped).returns(T.nilable(String)) }
      def translation_missing_text_message(mail)
        text = "#{mail.subject}\n#{PreviewRenderer.text_body(mail)}"
        'subject or text part contains a missing i18n translation' if text.match?(MISSING_TRANSLATION)
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
        'text/plain part contains HTML markup' if PreviewRenderer.text_body(mail).match?(MARKUP_IN_TEXT)
      end
    end
  end
end
