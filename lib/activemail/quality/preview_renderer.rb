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
            result = I18n.with_locale(locale) { block.call(mail(preview.call(email, locale: locale))) }
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
        sig { params(mail: T.untyped).returns(String) }
        def html_body(mail)
          body_of(mail, mail.html_part, [nil, 'text/html'])
        end

        sig { params(mail: T.untyped).returns(String) }
        def text_body(mail)
          body_of(mail, mail.text_part, ['text/plain'])
        end

        # NullMail answers every respond_to? and returns nil: it is its own message.
        sig { params(message: T.untyped).returns(T.untyped) }
        def mail(message)
          (message.message if message.respond_to?(:message)) || message
        end

        sig { params(mail: T.untyped).returns(T::Boolean) }
        def declined?(mail)
          mail.class.name.to_s.end_with?('::NullMail')
        end

        sig { params(config: Configuration, previews: T::Array[[T.untyped, String]]).returns(T::Array[[T.untyped, String, Symbol]]) }
        def cases(config, previews = all)
          previews.flat_map { |preview, email| config.locales_for(preview).map { |locale| [preview, email, locale] } }
        end

        private

        # A single-part body counts only when its content-type says so (unset counts as HTML).
        sig { params(mail: T.untyped, part: T.untyped, mime_types: T::Array[T.nilable(String)]).returns(String) }
        def body_of(mail, part, mime_types)
          body = part&.body || (mail.body if !mail.multipart? && mime_types.include?(mail.mime_type))
          body ? body.decoded : ''
        end
      end
    end
  end
end
