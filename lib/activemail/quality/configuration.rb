# typed: strict
# frozen_string_literal: true

require 'i18n'
require 'sorbet-runtime'

require_relative 'guard'
require_relative 'output_dir'
require_relative 'output_filter'

module ActiveMail
  module Quality
    class Configuration
      extend T::Sig

      FORMATS = T.let(%i[html text].freeze, T::Array[Symbol])
      DEFAULT_LOCALES = T.let(->(_preview) { [I18n.default_locale] }, Proc)

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
        @output_dir = OutputDir.validate!(value)
      end

      # Preview keys ("preview_name#email") that MUST render and pass the guard;
      # a failure on any of these aborts the rake task. Other previews are only
      # reported.
      sig { returns(T::Array[String]) }
      def required_previews
        @preview_keys.fetch(:required).dup.freeze
      end

      sig { params(value: T.untyped).void }
      def required_previews=(value)
        @preview_keys[:required] = preview_keys(value)
      end

      # Preview keys that may legitimately decline to send (NullMail); any other
      # preview returning one is a violation.
      sig { returns(T::Array[String]) }
      def allow_declined
        @preview_keys.fetch(:allow_declined).dup.freeze
      end

      sig { params(value: T.untyped).void }
      def allow_declined=(value)
        @preview_keys[:allow_declined] = preview_keys(value)
      end

      sig { params(key: String).returns(T::Boolean) }
      def allow_declined?(key)
        @preview_keys.fetch(:allow_declined).include?(key)
      end

      sig { returns(T.any(T::Array[Symbol], Proc)) }
      attr_reader :locales

      sig { params(value: T.untyped).void }
      def locales=(value)
        @locales = value.is_a?(Proc) ? value : normalize_locales(value)
      end

      sig { params(preview: T.untyped).returns(T::Array[Symbol]) }
      def locales_for(preview)
        value = @locales
        value.is_a?(Proc) ? normalize_locales(value.call(preview)) : value
      end

      sig { returns(T::Array[Symbol]) }
      def formats
        @formats.dup.freeze
      end

      sig { params(value: T.untyped).void }
      def formats=(value)
        raise TypeError, "formats must be an Array, got #{value.class}" unless value.is_a?(Array)

        formats = value.map(&:to_sym)
        unknown = formats - FORMATS
        raise ArgumentError, "unknown format(s): #{unknown.inspect}, expected a subset of #{FORMATS.inspect}" unless unknown.empty?
        raise ArgumentError, 'formats must not be empty' if formats.empty?

        @formats = formats.uniq
      end

      # ->(preview, email, locale, &block) wrapping each rendering; it must call block.
      sig { returns(T.nilable(Proc)) }
      attr_reader :around_each

      sig { params(value: T.untyped).void }
      def around_each=(value)
        raise TypeError, "around_each must be a Proc or nil, got #{value.class}" unless value.nil? || value.is_a?(Proc)

        @around_each = value
      end

      # Applied to written files only: the Guard always sees the unfiltered content.
      sig { returns(T::Array[Proc]) }
      attr_reader :output_filters

      sig { params(value: T.untyped).void }
      def output_filters=(value)
        raise TypeError, "output_filters must be an Array, got #{value.class}" unless value.is_a?(Array)

        @output_filters = value.map { |filter| OutputFilter.coerce(filter) }
      end

      sig { void }
      def initialize
        @guard = T.let(Guard.new, Guard)
        @output_dir = T.let('tmp/activemail_previews', String)
        @preview_keys = T.let({ required: [], allow_declined: [] }, T::Hash[Symbol, T::Array[String]])
        @locales = T.let(DEFAULT_LOCALES, T.any(T::Array[Symbol], Proc))
        @formats = T.let(FORMATS, T::Array[Symbol])
        @around_each = T.let(nil, T.nilable(Proc))
        @output_filters = T.let([], T::Array[Proc])
      end

      private

      sig { params(value: T.untyped).returns(T::Array[String]) }
      def preview_keys(value)
        raise TypeError, "#{value.inspect} (#{value.class}) does not respond to 'to_a'" unless value.respond_to?(:to_a)

        value.to_a.map(&:to_s)
      end

      sig { params(value: T.untyped).returns(T::Array[Symbol]) }
      def normalize_locales(value)
        raise TypeError, "locales must be an Array, got #{value.class}" unless value.is_a?(Array)
        raise ArgumentError, 'locales must not be empty' if value.empty?

        value.map(&:to_sym)
      end
    end
  end
end
