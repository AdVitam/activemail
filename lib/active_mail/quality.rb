# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'

require_relative 'quality/guard'
require_relative 'quality/configuration'
require_relative 'quality/preview_renderer'

module ActiveMail
  # Opt-in email-quality layer. Host apps require this explicitly from their test
  # suite; `require 'active_mail'` must NOT pull it in.
  module Quality
    extend T::Sig

    sig { returns(Configuration) }
    def self.config
      @config ||= T.let(Configuration.new, T.nilable(Configuration))
    end

    sig { params(config: T.untyped).returns(Configuration) }
    def self.config=(config)
      raise TypeError, 'Not an ActiveMail::Quality::Configuration' unless config.is_a?(Configuration)

      @config = config
    end

    sig { params(block: T.proc.params(config: Configuration).void).void }
    def self.configure(&block)
      block.call(config)
    end

    sig { returns(Guard) }
    def self.guard
      config.guard
    end
  end
end
