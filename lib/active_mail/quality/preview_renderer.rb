# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'

module ActiveMail
  module Quality
    # Renders ActionMailer previews to HTML strings (and to disk) for visual
    # diffing and quality checks. Works on any host's previews — no app-specific
    # preview list lives here.
    module PreviewRenderer
      class << self
        extend T::Sig

        # preview and message are external/dynamic ActionMailer & Mail objects.

        # Renders a single preview email to its text/html body.
        sig { params(preview: T.untyped, email: String).returns(String) }
        def render(preview, email)
          html_body(preview.call(email))
        end

        # Renders a preview email and writes it to <output_root>/<preview>/<email>.html.
        sig { params(preview: T.untyped, email: String, output_root: T.any(String, Pathname)).returns(Pathname) }
        def render_to_disk(preview, email, output_root)
          dir = Pathname(output_root).join(preview.preview_name)
          FileUtils.mkdir_p(dir)
          path = dir.join("#{email}.html")
          File.write(path, render(preview, email))
          path
        end

        # Every [preview, email] pair the host exposes, or [] when ActionMailer
        # previews are not loaded.
        sig { returns(T::Array[[T.untyped, String]]) }
        def all
          return [] unless defined?(ActionMailer::Preview)

          ActionMailer::Preview.all.flat_map do |preview|
            preview.emails.map { |email| [preview, email] }
          end
        end

        # Extracts the text/html part from a Mail::Message (or MessageDelivery),
        # mirroring the inline interceptor's part-finding logic. Returns '' for a
        # plain-text-only message so the Guard surfaces missing HTML rather than
        # validating plain text as if it were HTML.
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
