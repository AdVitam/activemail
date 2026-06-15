# typed: strict
# frozen_string_literal: true

require 'nokogiri'
require 'sorbet-runtime'

module ActiveMail
  module Quality
    class Guard
      extend T::Sig

      # One failed invariant. :rule is a stable symbol for programmatic matching;
      # :message is human-facing.
      class Violation < T::Struct
        const :rule, Symbol
        const :message, String
      end

      DISABLEABLE = T.let(%i[max_bytes parse_error table_role img_alt lang min_full_doc_bytes].freeze, T::Array[Symbol])
      # libxml2 code for a non-HTML4 tag; benign (HTML5/custom tags), not malformedness.
      UNKNOWN_TAG_CODE = 801
      # Gmail clips messages past ~102KB.
      DEFAULT_MAX_BYTES = 102_400
      # A full HTML document smaller than this carries no real layout and is suspect.
      DEFAULT_MIN_FULL_DOC_BYTES = 1_024

      # disable: any subset of DISABLEABLE to skip those checks.
      sig { params(max_bytes: Integer, min_full_doc_bytes: Integer, disable: T::Array[Symbol]).void }
      def initialize(max_bytes: DEFAULT_MAX_BYTES, min_full_doc_bytes: DEFAULT_MIN_FULL_DOC_BYTES, disable: [])
        # A non-positive threshold would silently disable (or invert) a check.
        @max_bytes = T.let(positive_threshold!(:max_bytes, max_bytes), Integer)
        @min_full_doc_bytes = T.let(positive_threshold!(:min_full_doc_bytes, min_full_doc_bytes), Integer)
        unknown = disable - DISABLEABLE
        raise ArgumentError, "unknown rule(s): #{unknown.inspect}, expected a subset of #{DISABLEABLE.inspect}" unless unknown.empty?

        @disabled = T.let(disable.to_set, T::Set[Symbol])
      end

      sig { params(html: String).returns(T::Array[Violation]) }
      def violations(html)
        violations = []
        check_size(html, violations)

        doc = Nokogiri::HTML(html)
        check_well_formed(doc, violations)
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

      sig { params(rule: Symbol).returns(T::Boolean) }
      def enabled?(rule)
        !@disabled.include?(rule)
      end

      sig { params(name: Symbol, value: Integer).returns(Integer) }
      def positive_threshold!(name, value)
        raise ArgumentError, "#{name} must be a positive integer, got #{value}" unless value.positive?

        value
      end

      # Mirrors how Core decides parse vs fragment: a full document carries <html.
      sig { params(html: String).returns(T::Boolean) }
      def full_document?(html)
        !(html =~ /<html/i).nil?
      end

      sig { params(html: String, violations: T::Array[Violation]).void }
      def check_size(html, violations)
        return unless enabled?(:max_bytes)
        return if html.bytesize <= @max_bytes

        violations << Violation.new(rule: :max_bytes, message: "HTML is #{html.bytesize} bytes, exceeds #{@max_bytes} (Gmail clipping)")
      end

      # The Core surfaces libxml2 repairs on input; the validation layer must not
      # silently bless malformed *output* (mismatched tags, bad entities) before send.
      sig { params(doc: Nokogiri::XML::Document, violations: T::Array[Violation]).void }
      def check_well_formed(doc, violations)
        return unless enabled?(:parse_error)

        errors = doc.errors.reject { |e| e.respond_to?(:code) && e.code == UNKNOWN_TAG_CODE }
        return if errors.empty?

        violations << Violation.new(rule: :parse_error, message: "malformed HTML: #{errors.first(3).map { |e| e.message.to_s.strip }.join('; ')}")
      end

      sig { params(doc: Nokogiri::XML::Document, violations: T::Array[Violation]).void }
      def check_table_roles(doc, violations)
        return unless enabled?(:table_role)

        offenders = doc.css('table').count { |table| table['role'] != 'presentation' }
        return if offenders.zero?

        violations << Violation.new(rule: :table_role, message: %(#{offenders} <table> missing role="presentation"))
      end

      sig { params(doc: Nokogiri::XML::Document, violations: T::Array[Violation]).void }
      def check_img_alts(doc, violations)
        return unless enabled?(:img_alt)

        offenders = doc.css('img').count { |img| !img.key?('alt') }
        return if offenders.zero?

        violations << Violation.new(rule: :img_alt, message: "#{offenders} <img> missing an alt attribute")
      end

      sig { params(html: String, doc: Nokogiri::XML::Document, violations: T::Array[Violation]).void }
      def check_full_document(html, doc, violations)
        if enabled?(:min_full_doc_bytes) && html.bytesize < @min_full_doc_bytes
          violations << Violation.new(rule: :min_full_doc_bytes, message: "full document is only #{html.bytesize} bytes (under #{@min_full_doc_bytes})")
        end
        check_lang(doc, violations)
      end

      sig { params(doc: Nokogiri::XML::Document, violations: T::Array[Violation]).void }
      def check_lang(doc, violations)
        return unless enabled?(:lang)

        html_tag = doc.at_css('html')
        lang = html_tag && html_tag['lang']
        return if lang && !lang.strip.empty?

        violations << Violation.new(rule: :lang, message: '<html> must declare a non-blank lang attribute')
      end
    end
  end
end
