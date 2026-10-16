# typed: strict
# frozen_string_literal: true

require 'i18n'
require 'sorbet-runtime'

require_relative 'guard'
require_relative 'output_dir'

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
        @required_previews.dup.freeze
      end

      sig { params(value: T.untyped).returns(T::Array[String]) }
      def required_previews=(value)
        raise TypeError, "#{value.inspect} (#{value.class}) does not respond to 'to_a'" unless value.respond_to?(:to_a)

        @required_previews = value.to_a.map(&:to_s)
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

        @output_filters = value.map { |filter| output_filter(filter) }
      end

      sig { void }
      def initialize
        @guard = T.let(Guard.new, Guard)
        @output_dir = T.let('tmp/activemail_previews', String)
        @required_previews = T.let([], T::Array[String])
        @locales = T.let(DEFAULT_LOCALES, T.any(T::Array[Symbol], Proc))
        @formats = T.let(FORMATS, T::Array[Symbol])
        @around_each = T.let(nil, T.nilable(Proc))
        @output_filters = T.let([], T::Array[Proc])
      end

      private

      sig { params(value: T.untyped).returns(T::Array[Symbol]) }
      def normalize_locales(value)
        raise TypeError, "locales must be an Array, got #{value.class}" unless value.is_a?(Array)
        raise ArgumentError, 'locales must not be empty' if value.empty?

        value.map(&:to_sym)
      end

      sig { params(filter: T.untyped).returns(Proc) }
      def output_filter(filter)
        return filter if filter.is_a?(Proc)

        pattern, replacement = filter if filter.is_a?(Array) && filter.size == 2
        raise TypeError, "output filter must be a Proc or [Regexp, String], got #{filter.inspect}" unless pattern.is_a?(Regexp) && replacement.is_a?(String)

        ->(content) { content.gsub(pattern, replacement) }
      end
    end
  end
end
