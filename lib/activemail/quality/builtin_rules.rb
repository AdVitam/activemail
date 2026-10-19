# typed: strict
# frozen_string_literal: true

require 'nokogiri'
require 'sorbet-runtime'

require_relative '../libxml'
require_relative 'builtin_message_rules'
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
          title anchor_href placeholder unsupported_color text_entities
        ].freeze,
        T::Array[Symbol]
      )
      MARKUP_IN_TEXT = %r{<(?:table|div|span|p|br|a)[\s>/]}i
      MISSING_TRANSLATION = /translation[ _]missing/i
      # An unresolved `{{variable}}` of a user-editable template; public so a host can refuse it before sending.
      PLACEHOLDER = /\{\{[^{}]+\}\}/
      # Clients drop or mangle these CSS color forms in a style attribute.
      UNSUPPORTED_COLOR = /rgba?\([^)]*%[^)]*\)|hsla?\(|color-mix\(|\bvar\(/i
      HTML_ENTITY = /&(?:[a-z][a-z0-9]*|#\d+|#x\h+);/i
      STYLE_AND_SCRIPT = %r{<(style|script)\b[\s\S]*?</\1\s*>}i
      ROOTS = T.let({ html: /<html[\s>]/i, body: /<body[\s>]/i }.freeze, T::Hash[Symbol, Regexp])

      sig { params(max_bytes: Integer, min_full_doc_bytes: Integer).void }
      def initialize(max_bytes:, min_full_doc_bytes:)
        # A non-positive threshold would silently disable (or invert) a check.
        @max_bytes = T.let(::ActiveMail.positive_integer!(:max_bytes, max_bytes), Integer)
        @min_full_doc_bytes = T.let(::ActiveMail.positive_integer!(:min_full_doc_bytes, min_full_doc_bytes), Integer)
      end

      sig { returns(T::Array[Rule]) }
      def rules
        structure_rules + content_rules + BuiltinMessageRules.new.rules
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
          Rule.html(:img_alt) { |doc, _html| img_alt_message(doc) },
          Rule.html(:anchor_href) { |doc, _html| anchor_href_message(doc) },
          Rule.html(:unsupported_color) { |doc, html| unsupported_color_message(doc, html) }
        ]
      end

      sig { returns(T::Array[Rule]) }
      def content_rules
        [
          Rule.html(:translation_missing) { |_doc, html| translation_missing_message(html) },
          Rule.html(:single_root) { |_doc, html| single_root_messages(html) },
          Rule.html(:min_full_doc_bytes) { |_doc, html| min_full_doc_message(html) },
          Rule.html(:lang) { |doc, html| lang_message(doc, html) },
          Rule.html(:title) { |doc, html| title_message(doc, html) },
          Rule.html(:placeholder) { |_doc, html| placeholder_message(html) }
        ]
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

      sig { params(doc: Nokogiri::XML::Document).returns(T.nilable(String)) }
      def anchor_href_message(doc)
        offenders = doc.css('a').count { |anchor| anchor['href'].to_s.strip.empty? }
        "#{offenders} <a> without a href" unless offenders.zero?
      end

      # The raw-string pre-check keeps the per-node scan off the common, clean path.
      sig { params(doc: Nokogiri::XML::Document, html: String).returns(T.nilable(String)) }
      def unsupported_color_message(doc, html)
        return unless html.match?(UNSUPPORTED_COLOR)

        offenders = doc.xpath('//*[@style]').filter_map { |node| node['style'].to_s[UNSUPPORTED_COLOR] }
        return if offenders.empty?

        "#{offenders.size} inline style(s) use a color clients ignore (rgb(%), hsl, color-mix, var()): #{offenders.uniq.first(3).join(', ')}"
      end

      sig { params(html: String).returns(T.nilable(String)) }
      def translation_missing_message(html)
        'rendered HTML contains a missing i18n translation' if html.match?(MISSING_TRANSLATION)
      end

      # Counted on the raw string: libxml2 silently merges duplicate roots.
      sig { params(html: String).returns(T::Array[String]) }
      def single_root_messages(html)
        ROOTS.filter_map do |tag, pattern|
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

      sig { params(doc: Nokogiri::XML::Document, html: String).returns(T.nilable(String)) }
      def title_message(doc, html)
        return unless ::ActiveMail.full_document?(html)

        '<head> must contain a non-blank <title>' if doc.at_css('title')&.text.to_s.strip.empty?
      end

      sig { params(html: String).returns(T.nilable(String)) }
      def placeholder_message(html)
        return unless html.include?('{{')

        found = html.gsub(STYLE_AND_SCRIPT, '').scan(PLACEHOLDER).uniq
        "unresolved placeholder(s): #{found.first(3).join(', ')}" unless found.empty?
      end
    end
  end
end
