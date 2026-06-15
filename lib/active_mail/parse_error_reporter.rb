# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'

require_relative 'libxml'

module ActiveMail
  # Surfaces libxml2 recover-mode repairs that would otherwise silently change
  # the rendered email, honoring ActiveMail.configuration.on_parse_error.
  class ParseErrorReporter
    extend T::Sig

    sig { params(known_tags: T::Array[String]).void }
    def initialize(known_tags)
      # dup.freeze: the caller's array stays decoupled and cannot be mutated under us.
      @known_tags = T.let(known_tags.dup.freeze, T::Array[String])
    end

    sig { params(errors: T::Array[Nokogiri::XML::SyntaxError]).void }
    def call(errors)
      mode = ::ActiveMail.configuration.on_parse_error
      return if mode == :ignore

      relevant = errors.reject { |error| known_tag_error?(error) }
      return if relevant.empty?

      messages = relevant.map { |error| error.message.to_s.strip }.join('; ')
      raise ActiveMail::ParseError, messages if mode == :raise

      ::ActiveMail.log_warning("[activemail] HTML parse issues: #{messages}")
    end

    private

    sig { params(error: Nokogiri::XML::SyntaxError).returns(T::Boolean) }
    def known_tag_error?(error)
      return false unless error.code == LIBXML_UNKNOWN_TAG_CODE

      # Fragile by necessity: the 801 error does not carry the tag name, only
      # the libxml2 message text does. Locked by test against the pinned
      # Nokogiri; revisit on bump if that test breaks.
      tag = error.message.to_s[/Tag (\S+) invalid/, 1]
      !tag.nil? && @known_tags.include?(tag)
    end
  end
end
