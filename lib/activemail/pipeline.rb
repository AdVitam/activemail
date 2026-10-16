# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'

module ActiveMail
  module Pipeline
    extend T::Sig

    sig { params(html: String, config: ActiveMail::Configuration).returns(String) }
    def self.call(html, config: ActiveMail.configuration)
      transpiled = config.core.transpile(html)
      inliner = config.resolved_inliner
      return transpiled if inliner.noop?

      inline(inliner, transpiled)
    end

    sig { params(inliner: ActiveMail::Inliner::Base, html: String).returns(String) }
    def self.inline(inliner, html)
      inliner.inline(html)
    rescue ActiveMail::Inliner::Error
      raise
    rescue StandardError => e
      # A silently non-inlined mail is worse than a failed one.
      raise ActiveMail::Inliner::Error, "[#{inliner.class}] CSS inlining failed: #{e.message}"
    end
    private_class_method :inline
  end
end
