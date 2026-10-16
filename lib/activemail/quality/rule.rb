# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'

module ActiveMail
  module Quality
    # :html rules receive (Nokogiri document, html), :message rules the mail; a check
    # returns nil/false to pass, else one message or an Array of them.
    class Rule
      extend T::Sig

      LEVELS = T.let(%i[html message].freeze, T::Array[Symbol])

      sig { returns(Symbol) }
      attr_reader :name

      sig { returns(Symbol) }
      attr_reader :level

      sig { params(name: Symbol, level: Symbol, check: Proc).void }
      def initialize(name, level, check)
        raise ArgumentError, "rule level must be one of #{LEVELS.inspect}, got #{level.inspect}" unless LEVELS.include?(level)

        @name = name
        @level = level
        @check = check
      end

      sig { params(name: Symbol, check: Proc).returns(Rule) }
      def self.html(name, &check)
        new(name, :html, check)
      end

      sig { params(name: Symbol, check: Proc).returns(Rule) }
      def self.message(name, &check)
        new(name, :message, check)
      end

      sig { params(args: T::Array[T.untyped]).returns(T::Array[String]) }
      def messages(args)
        result = T.unsafe(@check).call(*args)
        result ? Array(result).map(&:to_s) : []
      end
    end
  end
end
