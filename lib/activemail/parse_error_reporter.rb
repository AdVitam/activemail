# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'

require_relative 'libxml'

module ActiveMail
  # Surfaces libxml2 recover-mode repairs that would otherwise silently change
  # the rendered email, honoring the config's on_parse_error.
  class ParseErrorReporter
    extend T::Sig

    sig { params(config: ActiveMail::Configuration).void }
    def initialize(config)
      @config = config
    end

    sig { returns(T::Boolean) }
    def active?
      @config.on_parse_error != :ignore
    end

    sig { params(errors: T::Array[Nokogiri::XML::SyntaxError], unknown_tags: T::Array[String]).void }
    def call(errors, unknown_tags = [])
      return unless active?

      issues = Libxml.markup_errors(errors).map { |error| error.message.to_s.strip } +
               unknown_tags.map { |tag| "unknown tag <#{tag}>" }
      return if issues.empty?

      messages = issues.join('; ')
      raise ActiveMail::ParseError, messages if @config.on_parse_error == :raise

      ::ActiveMail.log_warning("[activemail] HTML parse issues: #{messages}")
    end
  end
end
