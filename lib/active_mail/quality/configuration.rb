# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'

require_relative 'guard'

module ActiveMail
  module Quality
    # Opt-in config for the quality layer. Mirrors ActiveMail::Configuration:
    # frozen dup readers, type-checked writers, sensible defaults.
    class Configuration
      extend T::Sig

      sig { returns(Guard) }
      attr_accessor :guard

      # Default directory for active_mail:emails:render_all output.
      sig { returns(String) }
      attr_accessor :output_dir

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
