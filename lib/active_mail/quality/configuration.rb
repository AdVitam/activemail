# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'

require_relative 'guard'

module ActiveMail
  module Quality
    # Opt-in config for the quality layer.
    class Configuration
      extend T::Sig

      sig { returns(Guard) }
      attr_reader :guard

      sig { params(value: T.untyped).void }
      def guard=(value)
        raise TypeError, "guard must be an ActiveMail::Quality::Guard, got #{value.class}" unless value.is_a?(Guard)

        @guard = value
      end

      sig { returns(String) }
      attr_reader :output_dir

      sig { params(value: String).void }
      def output_dir=(value)
        raise ArgumentError, 'output_dir must not be blank' if value.strip.empty?

        @output_dir = value
      end

      # Preview keys ("preview_name#email") that MUST render and pass the guard;
      # a failure on any of these aborts the rake task. Other previews are only
      # reported.
      sig { returns(T::Array[String]) }
      def required_previews
        @required_previews.dup.freeze
      end

      sig { params(value: T.untyped).returns(T::Array[String]) }
      def required_previews=(value)
        raise TypeError, "#{value.inspect} (#{value.class}) does not respond to 'to_a'" unless value.respond_to?(:to_a)

        @required_previews = value.to_a.map(&:to_s)
      end

      sig { void }
      def initialize
        @guard = T.let(Guard.new, Guard)
        @output_dir = T.let('tmp/active_mail_previews', String)
        @required_previews = T.let([], T::Array[String])
      end
    end
  end
end
