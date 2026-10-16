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

      # One failed invariant. :rule is a stable symbol for programmatic matching;
      # :message is human-facing.
      class Violation < T::Struct
        const :rule, Symbol
        const :message, String
      end

      DISABLEABLE = BuiltinRules::NAMES
      # Gmail clips messages past ~102KB.
      DEFAULT_MAX_BYTES = 102_400
      # A full HTML document smaller than this carries no real layout and is suspect.
      DEFAULT_MIN_FULL_DOC_BYTES = 1_024

      # disable: any subset of DISABLEABLE to skip those built-in checks.
      # rules: custom Rule objects, checked in addition to the built-in ones.
      sig { params(max_bytes: Integer, min_full_doc_bytes: Integer, disable: T::Array[Symbol], rules: T::Array[Rule]).void }
      def initialize(max_bytes: DEFAULT_MAX_BYTES, min_full_doc_bytes: DEFAULT_MIN_FULL_DOC_BYTES, disable: [], rules: [])
        all = assemble_rules(BuiltinRules.new(max_bytes: max_bytes, min_full_doc_bytes: min_full_doc_bytes), disable, rules)
        @html_rules = T.let(all.select { |rule| rule.level == :html }, T::Array[Rule])
        @message_rules = T.let(all.select { |rule| rule.level == :message }, T::Array[Rule])
      end

      # A String is checked as HTML (message rules do not apply). A Mail::Message
      # (or ActionMailer::MessageDelivery) is checked on its HTML part plus the
      # message rules; a message without HTML (declined send) has nothing to check.
      sig { params(html_or_message: T.untyped).returns(T::Array[Violation]) }
      def violations(html_or_message)
        return html_violations(html_or_message) if html_or_message.is_a?(String)

        mail = PreviewRenderer.mail(html_or_message)
        html = PreviewRenderer.html_body(mail)
        return [] if html.empty?

        html_violations(html) + apply(@message_rules, [mail])
      end

      sig { params(html_or_message: T.untyped).returns(T::Boolean) }
      def valid?(html_or_message)
        violations(html_or_message).empty?
      end

      private

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

      sig { params(html: String).returns(T::Array[Violation]) }
      def html_violations(html)
        apply(@html_rules, [Nokogiri::HTML(html), html])
      end

      sig { params(rules: T::Array[Rule], args: T::Array[T.untyped]).returns(T::Array[Violation]) }
      def apply(rules, args)
        rules.flat_map do |rule|
          rule.messages(args).map { |message| Violation.new(rule: rule.name, message: message) }
        end
      end
    end
  end
end
