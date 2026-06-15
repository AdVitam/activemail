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
          inliner = ActiveMail.configuration.resolved_inliner
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

        # Handles both multipart messages (html part nested anywhere) and a
        # single-part message whose own content-type is text/html.
        sig { params(message: T.untyped).returns(T::Array[T.untyped]) }
        def html_parts(message)
          return collect_html_parts(message.all_parts) if message.multipart?

          message.mime_type == 'text/html' ? [message] : []
        end

        sig { params(parts: T::Array[T.untyped]).returns(T::Array[T.untyped]) }
        def collect_html_parts(parts)
          parts.select { |part| part.respond_to?(:mime_type) && part.mime_type == 'text/html' }
        end
      end
    end
  end
end
