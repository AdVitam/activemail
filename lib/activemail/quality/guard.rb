# typed: strict
# frozen_string_literal: true

require 'nokogiri'
require 'sorbet-runtime'

require_relative 'builtin_rules'
require_relative 'preview_renderer'
require_relative 'rule'

module ActiveMail
  module Quality
    class Guard
      extend T::Sig

      class Violation < T::Struct
        extend T::Sig

        const :rule, Symbol
        const :message, String

        sig { returns(String) }
        def to_s
          "[#{rule}] #{message}"
        end
      end

      DISABLEABLE = BuiltinRules::NAMES
      # Gmail clips messages past ~102KB.
      DEFAULT_MAX_BYTES = 102_400
      # A full HTML document smaller than this carries no real layout and is suspect.
      DEFAULT_MIN_FULL_DOC_BYTES = 1_024
      NO_SKIP = T.let([].freeze, T::Array[Symbol])

      sig { params(max_bytes: Integer, min_full_doc_bytes: Integer, disable: T::Array[Symbol], rules: T::Array[Rule]).void }
      def initialize(max_bytes: DEFAULT_MAX_BYTES, min_full_doc_bytes: DEFAULT_MIN_FULL_DOC_BYTES, disable: [], rules: [])
        all = assemble_rules(BuiltinRules.new(max_bytes: max_bytes, min_full_doc_bytes: min_full_doc_bytes), disable, rules)
        @html_rules = T.let(all.select { |rule| rule.level == :html }, T::Array[Rule])
        @message_rules = T.let(all.select { |rule| rule.level == :message }, T::Array[Rule])
        # A disabled built-in rule stays a known name: exempting a preview from it is harmless, not a typo.
        @rule_names = T.let((DISABLEABLE + rules.map(&:name)).freeze, T::Array[Symbol])
      end

      # A String only gets the HTML rules; a message gets both levels. A declined send
      # (NullMail) has nothing to check, but it is a violation unless the caller expects it.
      sig { params(html_or_message: T.untyped, allow_declined: T::Boolean, skip: T::Array[Symbol]).returns(T::Array[Violation]) }
      def violations(html_or_message, allow_declined: false, skip: NO_SKIP)
        check_skippable!(skip)
        return html_violations(html_or_message, skip) if html_or_message.is_a?(String)

        mail = PreviewRenderer.mail(html_or_message)
        return declined_violations(allow_declined) if PreviewRenderer.declined?(mail)

        html = PreviewRenderer.html_body(mail)
        (html.empty? ? [] : html_violations(html, skip)) + apply(@message_rules, [mail], skip)
      end

      sig { params(html_or_message: T.untyped, allow_declined: T::Boolean, skip: T::Array[Symbol]).returns(T::Boolean) }
      def valid?(html_or_message, allow_declined: false, skip: NO_SKIP)
        violations(html_or_message, allow_declined: allow_declined, skip: skip).empty?
      end

      sig { params(skip: T::Array[Symbol]).void }
      def check_skippable!(skip)
        return if skip.empty?

        unknown = skip - @rule_names
        raise ArgumentError, "unknown rule(s) to skip: #{unknown.inspect}, expected a subset of #{@rule_names.inspect}" unless unknown.empty?
      end

      private

      sig { params(allowed: T::Boolean).returns(T::Array[Violation]) }
      def declined_violations(allowed)
        allowed ? [] : [Violation.new(rule: :declined, message: 'the mailer declined to send (NullMail)')]
      end

      sig { params(builtin: BuiltinRules, disable: T::Array[Symbol], custom: T::Array[Rule]).returns(T::Array[Rule]) }
      def assemble_rules(builtin, disable, custom)
        unknown = disable - DISABLEABLE
        raise ArgumentError, "unknown rule(s): #{unknown.inspect}, expected a subset of #{DISABLEABLE.inspect}" unless unknown.empty?

        unique_names!(builtin.rules.reject { |rule| disable.include?(rule.name) } + custom)
      end

      sig { params(rules: T::Array[Rule]).returns(T::Array[Rule]) }
      def unique_names!(rules)
        duplicates = rules.map(&:name).tally.select { |_name, count| count > 1 }.keys
        raise ArgumentError, "duplicate rule name(s): #{duplicates.inspect}" unless duplicates.empty?

        rules
      end

      sig { params(html: String, skip: T::Array[Symbol]).returns(T::Array[Violation]) }
      def html_violations(html, skip)
        apply(@html_rules, [Nokogiri::HTML(html), html], skip)
      end

      sig { params(rules: T::Array[Rule], args: T::Array[T.untyped], skip: T::Array[Symbol]).returns(T::Array[Violation]) }
      def apply(rules, args, skip)
        rules.flat_map do |rule|
          next [] if skip.include?(rule.name)

          rule.messages(args).map { |message| Violation.new(rule: rule.name, message: message) }
        end
      end
    end
  end
end
