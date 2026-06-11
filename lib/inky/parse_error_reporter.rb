# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'

module Inky
  # Surfaces libxml2 recover-mode repairs that would otherwise silently change
  # the rendered email, honoring Inky.configuration.on_parse_error.
  class ParseErrorReporter
    extend T::Sig

    # libxml2 XML_HTML_UNKNOWN_TAG: raised for every non-HTML4 tag, including
    # legitimate registered component tags.
    UNKNOWN_TAG_ERROR_CODE = 801

    sig { params(known_tags: T::Array[String]).void }
    def initialize(known_tags)
      @known_tags = T.let(known_tags, T::Array[String])
    end

    sig { params(errors: T::Array[Nokogiri::XML::SyntaxError]).void }
    def call(errors)
      mode = ::Inky.configuration.on_parse_error
      return if mode == :ignore

      relevant = errors.reject { |error| known_tag_error?(error) }
      return if relevant.empty?

      messages = relevant.map { |error| error.message.to_s.strip }.join('; ')
      raise Inky::ParseError, messages if mode == :raise

      Kernel.warn("[inky-rb] HTML parse issues: #{messages}")
    end

    private

    sig { params(error: Nokogiri::XML::SyntaxError).returns(T::Boolean) }
    def known_tag_error?(error)
      return false unless error.code == UNKNOWN_TAG_ERROR_CODE

      # Fragile by necessity: the 801 error does not carry the tag name, only
      # the libxml2 message text does. Locked by test against the pinned
      # Nokogiri; revisit on bump if that test breaks.
      tag = error.message.to_s[/Tag (\S+) invalid/, 1]
      !tag.nil? && @known_tags.include?(tag)
    end
  end
end
