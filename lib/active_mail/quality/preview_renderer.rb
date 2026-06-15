# typed: strict
# frozen_string_literal: true

require 'fileutils'
require 'pathname'
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

        sig { params(preview: T.untyped, email: String, output_root: T.any(String, Pathname)).returns(Pathname) }
        def render_to_disk(preview, email, output_root)
          dir = Pathname(output_root).join(preview.preview_name)
          FileUtils.mkdir_p(dir)
          path = dir.join("#{email}.html")
          File.write(path, render(preview, email))
          path
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
          mail = message.respond_to?(:message) ? message.message : message
          body = mail.html_part&.body || single_part_html_body(mail)
          return '' unless body

          body.respond_to?(:decoded) ? body.decoded : body.to_s
        end

        private

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
