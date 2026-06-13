# typed: strict
# frozen_string_literal: true

require 'nokogiri'
require 'sorbet-runtime'

module ActiveMail
  module Quality
    # Pure, framework-agnostic HTML email checker: feed it an HTML string, get a
    # list of structured violations back. No Rails, no ActionMailer.
    class Guard
      extend T::Sig

      # One failed invariant. :rule is a stable symbol for programmatic matching;
      # :message is human-facing.
      class Violation < T::Struct
        const :rule, Symbol
        const :message, String
      end

      # Gmail clips messages past ~102KB.
      DEFAULT_MAX_BYTES = 102_400
      # A full HTML document smaller than this carries no real layout (e.g. an
      # attachment-only carrier body) and is suspect.
      DEFAULT_MIN_FULL_DOC_BYTES = 1_024

      sig do
        params(
          max_bytes: Integer,
          require_table_role: T::Boolean,
          require_img_alt: T::Boolean,
          require_lang: T::Boolean,
          min_full_doc_bytes: Integer
        ).void
      end
      def initialize(
        max_bytes: DEFAULT_MAX_BYTES,
        require_table_role: true,
        require_img_alt: true,
        require_lang: true,
        min_full_doc_bytes: DEFAULT_MIN_FULL_DOC_BYTES
      )
        @max_bytes = T.let(max_bytes, Integer)
        @require_table_role = T.let(require_table_role, T::Boolean)
        @require_img_alt = T.let(require_img_alt, T::Boolean)
        @require_lang = T.let(require_lang, T::Boolean)
        @min_full_doc_bytes = T.let(min_full_doc_bytes, Integer)
      end

      sig { params(html: String).returns(T::Array[Violation]) }
      def violations(html)
        violations = []
        check_size(html, violations)

        doc = Nokogiri::HTML(html)
        check_table_roles(doc, violations)
        check_img_alts(doc, violations)
        check_full_document(html, doc, violations) if full_document?(html)
        violations
      end

      sig { params(html: String).returns(T::Boolean) }
      def valid?(html)
        violations(html).empty?
      end

      private

      # Mirrors how Core decides parse vs fragment: a full document carries <html.
      sig { params(html: String).returns(T::Boolean) }
      def full_document?(html)
        !(html =~ /<html/i).nil?
      end

      sig { params(html: String, violations: T::Array[Violation]).void }
      def check_size(html, violations)
        return if html.bytesize <= @max_bytes

        violations << Violation.new(
          rule: :max_bytes,
          message: "HTML is #{html.bytesize} bytes, exceeds #{@max_bytes} (Gmail clipping)"
        )
      end

      sig { params(doc: Nokogiri::HTML4::Document, violations: T::Array[Violation]).void }
      def check_table_roles(doc, violations)
        return unless @require_table_role

        offenders = doc.css('table').count { |table| table['role'] != 'presentation' }
        return if offenders.zero?

        violations << Violation.new(
          rule: :table_role,
          message: %(#{offenders} <table> missing role="presentation")
        )
      end

      sig { params(doc: Nokogiri::HTML4::Document, violations: T::Array[Violation]).void }
      def check_img_alts(doc, violations)
        return unless @require_img_alt

        offenders = doc.css('img').count { |img| !img.key?('alt') }
        return if offenders.zero?

        violations << Violation.new(
          rule: :img_alt,
          message: "#{offenders} <img> missing an alt attribute"
        )
      end

      sig { params(html: String, doc: Nokogiri::HTML4::Document, violations: T::Array[Violation]).void }
      def check_full_document(html, doc, violations)
        if html.bytesize < @min_full_doc_bytes
          violations << Violation.new(
            rule: :min_full_doc_bytes,
            message: "full HTML document is only #{html.bytesize} bytes, under #{@min_full_doc_bytes} (suspiciously small)"
          )
        end
        check_lang(doc, violations)
      end

      sig { params(doc: Nokogiri::HTML4::Document, violations: T::Array[Violation]).void }
      def check_lang(doc, violations)
        return unless @require_lang

        html_tag = doc.at_css('html')
        lang = html_tag && html_tag['lang']
        return if lang && !lang.empty?

        violations << Violation.new(rule: :lang, message: '<html> must declare a non-empty lang attribute')
      end
    end
  end
end
