# typed: strict
# frozen_string_literal: true

require 'digest'
require 'premailer'
require 'sorbet-runtime'

module ActiveMail
  module Inliner
    class Premailer < Base
      # Premailer re-parses every <style> block with css_parser on each email; the framework
      # CSS never changes between two emails, so its rule sets are parsed once per fingerprint.
      class Document < ::Premailer
        extend T::Sig

        # Mirrors the parser Premailer builds for these options.
        PARSER_OPTIONS = T.let(
          { absolute_paths: true, import: true, io_exceptions: false, rule_set_exceptions: true, allow_local_network: false }.freeze,
          T::Hash[Symbol, T.untyped]
        )

        # FIFO-bounded and thread-safe: mailers render from several threads and a dev reload
        # compiles new CSS under a new fingerprint.
        class RuleSetCache
          extend T::Sig

          LIMIT = 16

          sig { void }
          def initialize
            @entries = T.let({}, T::Hash[T.untyped, T.untyped])
            @mutex = T.let(Mutex.new, Mutex)
          end

          sig { params(key: T.untyped, block: T.proc.returns(T.untyped)).returns(T.untyped) }
          def fetch(key, &block)
            @mutex.synchronize { @entries[key] } || store(key, block.call)
          end

          sig { void }
          def clear
            @mutex.synchronize { @entries.clear }
          end

          sig { returns(Integer) }
          def size
            @mutex.synchronize { @entries.size }
          end

          private

          sig { params(key: T.untyped, value: T.untyped).returns(T.untyped) }
          def store(key, value)
            @mutex.synchronize do
              @entries[key] = value
              @entries.shift while @entries.size > LIMIT
            end
            value
          end
        end

        class CachedParser < ::CssParser::Parser
          extend T::Sig

          sig { params(block: String, options: T::Hash[Symbol, T.untyped]).void }
          def add_block!(block, options = {})
            Document.rule_sets.fetch([Digest::SHA256.hexdigest(block), options]) { parse(block, options) }.each do |rule_set, media_types|
              add_rule_set!(rule_set, media_types)
            end
          end

          private

          sig { params(block: String, options: T::Hash[Symbol, T.untyped]).returns(T::Array[T.untyped]) }
          def parse(block, options)
            parser = ::CssParser::Parser.new(PARSER_OPTIONS)
            parser.add_block!(block, options)
            rule_sets = T.let([], T::Array[T.untyped])
            parser.each_rule_set { |rule_set, media_types| rule_sets << [rule_set, media_types] }
            rule_sets
          end
        end

        sig { returns(RuleSetCache) }
        def self.rule_sets
          @rule_sets ||= T.let(RuleSetCache.new, T.nilable(RuleSetCache))
        end

        protected

        # Premailer exposes no hook for its parser: swap it before the <style> blocks are read.
        sig { void }
        def load_css_from_html!
          T.unsafe(self).instance_variable_set(:@css_parser, CachedParser.new(PARSER_OPTIONS))
          super
        end
      end
    end
  end
end
