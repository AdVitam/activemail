# typed: strict
# frozen_string_literal: true

require 'i18n'
require 'sorbet-runtime'

module ActiveMail
  module Quality
    module PreviewRenderer
      class << self
        extend T::Sig

        # preview and message are external/dynamic ActionMailer & Mail objects.
        sig { params(preview: T.untyped, email: String).returns(String) }
        def render(preview, email)
          html_body(preview.call(email))
        end

        # The single source for the "preview_name#email" key format (config keys,
        # render_all, the Minitest helper).
        sig { params(preview: T.untyped, email: String).returns(String) }
        def key(preview, email)
          "#{preview.preview_name}##{email}"
        end

        # The message is processed lazily, so everything that reads it (html_body,
        # text_body, the Guard) must run inside the block, within locale and around_each.
        sig do
          params(preview: T.untyped, email: String, locale: Symbol, around_each: T.nilable(Proc), block: T.proc.params(mail: T.untyped).returns(T.untyped))
            .returns(T.untyped)
        end
        def within(preview, email, locale, around_each, &block)
          ran = T.let(false, T::Boolean)
          result = T.let(nil, T.untyped)
          run = lambda do
            ran = true
            result = I18n.with_locale(locale) { block.call(mail(preview.call(email))) }
          end
          around_each ? around_each.call(preview, email, locale, &run) : run.call
          raise ArgumentError, 'around_each must yield' unless ran

          result
        end

        # [] when ActionMailer previews aren't loaded (host has none / previews disabled).
        sig { returns(T::Array[[T.untyped, String]]) }
        def all
          return [] unless defined?(ActionMailer::Preview)

          ActionMailer::Preview.all.flat_map do |preview|
            preview.emails.map { |email| [preview, email] }
          end
        end

        # Returns '' for a plain-text-only message so the Guard surfaces missing
        # HTML instead of validating plain text as if it were HTML.
        sig { params(message: T.untyped).returns(String) }
        def html_body(message)
          unwrapped = mail(message)
          body = unwrapped.html_part&.body || single_part_html_body(unwrapped)
          return '' unless body

          body.respond_to?(:decoded) ? body.decoded : body.to_s
        end

        # Unwraps an ActionMailer::MessageDelivery into its Mail::Message.
        sig { params(message: T.untyped).returns(T.untyped) }
        def mail(message)
          message.respond_to?(:message) ? message.message : message
        end

        # '' when the message has no text/plain alternative.
        sig { params(message: T.untyped).returns(String) }
        def text_body(message)
          unwrapped = mail(message)
          body = unwrapped.text_part&.body || single_part_text_body(unwrapped)
          return '' unless body

          body.respond_to?(:decoded) ? body.decoded : body.to_s
        end

        private

        sig { params(mail: T.untyped).returns(T.untyped) }
        def single_part_text_body(mail)
          mail.body if !mail.multipart? && mail.mime_type == 'text/plain'
        end

        # A single-part body counts as HTML only when its content-type says so
        # (or is unset); a declared text/plain body is not HTML.
        sig { params(mail: T.untyped).returns(T.untyped) }
        def single_part_html_body(mail)
          return if mail.multipart?

          mail.body if mail.mime_type.nil? || mail.mime_type == 'text/html'
        end
      end
    end
  end
end
