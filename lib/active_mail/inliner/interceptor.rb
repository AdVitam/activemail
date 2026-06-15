# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'

module ActiveMail
  module Inliner
    class Interceptor
      class << self
        extend T::Sig

        sig { params(message: T.untyped).void }
        def delivering_email(message)
          config = ActiveMail.configuration
          # Runtime check: an engine initializer runs before the host's, so a
          # boot-time flag read would always see the default.
          return unless config.register_inline_interceptor

          inliner = config.resolved_inliner
          return if inliner.noop?

          html_parts(message).each do |part|
            part.body = inliner.inline(part.body.to_s)
          rescue StandardError => e
            # Surface which inliner failed; do not swallow (a silently non-inlined
            # mail is worse). Ruby sets e as #cause, preserving the original backtrace.
            raise ActiveMail::Inliner::Error, "[#{inliner.class}] CSS inlining failed: #{e.message}"
          end
        end

        private

        # The html part(s) to inline: a single text/html message, or every text/html
        # part of a multipart message. Attachments are never inlined.
        sig { params(message: T.untyped).returns(T::Array[T.untyped]) }
        def html_parts(message)
          return message.all_parts.select { |part| html_body_part?(part) } if message.multipart?

          html_body_part?(message) ? [message] : []
        end

        sig { params(part: T.untyped).returns(T::Boolean) }
        def html_body_part?(part)
          return false unless part.respond_to?(:mime_type) && part.mime_type == 'text/html'

          !(part.respond_to?(:attachment?) && part.attachment?)
        end
      end
    end
  end
end
