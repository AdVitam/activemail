# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'

require_relative 'guard'

module ActiveMail
  module Quality
    # Rules a preview is exempt from, keyed by preview name (every email of it) or by
    # preview key ("preview_name#email"); values are rule names, built-in or custom.
    module RuleExemptions
      extend T::Sig

      sig { returns(T::Hash[String, T::Array[Symbol]]) }
      def rule_exemptions
        exemptions.dup.freeze
      end

      sig { params(value: T.untyped).void }
      def rule_exemptions=(value)
        Kernel.raise TypeError, "rule_exemptions must be a Hash, got #{value.class}" unless value.is_a?(Hash)

        exemptions = value.to_h { |key, rules| [key.to_s.freeze, Kernel.Array(rules).map(&:to_sym).freeze] }
        @exemptions = T.let(exemptions, T.nilable(T::Hash[String, T::Array[Symbol]]))
      end

      sig { params(key: String).returns(T::Array[Symbol]) }
      def exempt_rules_for(key)
        by_key = exemptions.fetch(key, Guard::NO_SKIP)
        by_name = exemptions.fetch(key.split('#', 2).first.to_s, Guard::NO_SKIP)
        by_key.empty? ? by_name : by_key | by_name
      end

      # Called before any preview renders: a bad name would otherwise surface as a render failure, or a skip.
      sig { params(guard: Guard).void }
      def check_exemptions!(guard)
        exemptions.each_value { |rules| guard.check_skippable!(rules) }
      end

      private

      sig { returns(T::Hash[String, T::Array[Symbol]]) }
      def exemptions
        @exemptions ||= T.let({}, T.nilable(T::Hash[String, T::Array[Symbol]]))
      end
    end
  end
end
