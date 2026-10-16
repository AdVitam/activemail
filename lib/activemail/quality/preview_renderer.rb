# typed: strict
# frozen_string_literal: true

require 'i18n'
require 'sorbet-runtime'

module ActiveMail
  module Quality
    module PreviewRenderer
      class << self
        extend T::Sig

        sig { params(preview: T.untyped, email: String).returns(String) }
        def key(preview, email)
          "#{preview.preview_name}##{email}"
        end

        # The message renders lazily: every read of it must happen inside the block.
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

        sig { returns(T::Array[[T.untyped, String]]) }
        def all
          return [] unless defined?(ActionMailer::Preview)

          ActionMailer::Preview.all.flat_map do |preview|
            preview.emails.map { |email| [preview, email] }
          end
        end

        # '' for a plain-text-only message: plain text must not be validated as HTML.
        sig { params(message: T.untyped).returns(String) }
        def html_body(message)
          unwrapped = mail(message)
          body = unwrapped.html_part&.body || single_part_html_body(unwrapped)
          return '' unless body

          body.respond_to?(:decoded) ? body.decoded : body.to_s
        end

        sig { params(message: T.untyped).returns(T.untyped) }
        def mail(message)
          message.respond_to?(:message) ? message.message : message
        end

        sig { params(message: T.untyped).returns(String) }
        def text_body(message)
          unwrapped = mail(message)
          body = unwrapped.text_part&.body || single_part_text_body(unwrapped)
          return '' unless body

          body.respond_to?(:decoded) ? body.decoded : body.to_s
        end

        # A send the mailer declined (NullMail, or nothing to deliver) has nothing to check.
        sig { params(mail: T.untyped).returns(T::Boolean) }
        def declined?(mail)
          mail.class.name.to_s.end_with?('::NullMail') || (!mail.multipart? && mail.body.to_s.strip.empty?)
        end

        sig { params(config: Configuration, previews: T::Array[[T.untyped, String]]).returns(T::Array[[T.untyped, String, Symbol]]) }
        def cases(config, previews = all)
          previews.flat_map { |preview, email| config.locales_for(preview).map { |locale| [preview, email, locale] } }
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
