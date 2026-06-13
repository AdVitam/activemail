# typed: strict
# frozen_string_literal: true

require_relative '../quality'

module ActiveMail
  module Quality
    # Minitest assertions for email quality. Host mailer tests `include` this:
    #
    #   class MailerQualityTest < ActiveSupport::TestCase
    #     include ActiveMail::Quality::Minitest
    #     assert_quality_for_all_previews
    #   end
    module Minitest
      extend T::Sig

      # Asserts the HTML passes the guard; on failure, flunks listing every
      # violation rather than swallowing them.
      sig { params(html: String, guard: Guard).void }
      def assert_email_quality(html, guard: ActiveMail::Quality.guard)
        violations = guard.violations(html)
        # assert is injected by the host's Minitest test class.
        T.unsafe(self).assert violations.empty?,
                              "email quality violations:\n#{violations.map { |v| "  - [#{v.rule}] #{v.message}" }.join("\n")}"
      end

      # Renders a preview email and asserts its quality.
      sig { params(preview: T.untyped, email: String, guard: Guard).void }
      def assert_preview_quality(preview, email, guard: ActiveMail::Quality.guard)
        assert_email_quality(PreviewRenderer.render(preview, email), guard: guard)
      end

      module ClassMethods
        extend T::Sig

        # Defines one test per discovered host preview. A preview that cannot
        # render in the test env (missing fixture, dev-only data) is skipped
        # unless it is listed in config.required_previews, in which case a render
        # failure fails the test.
        sig { params(guard: Guard).void }
        def assert_quality_for_all_previews(guard: ActiveMail::Quality.guard)
          required = ActiveMail::Quality.config.required_previews
          PreviewRenderer.all.each do |preview, email|
            key = "#{preview.preview_name}##{email}"
            T.unsafe(self).define_method("test_#{key.gsub(/\W/, '_')}_email_quality") do
              html = T.unsafe(self).send(:render_preview_or_skip, preview, email, key, required)
              T.unsafe(self).assert_email_quality(html, guard: guard) if html
            end
          end
        end
      end

      sig { params(base: T.untyped).void }
      def self.included(base)
        base.extend(ClassMethods)
      end

      private

      # Returns rendered HTML, or nil when a non-required preview fails to render.
      sig { params(preview: T.untyped, email: String, key: String, required: T::Array[String]).returns(T.nilable(String)) }
      def render_preview_or_skip(preview, email, key, required)
        PreviewRenderer.render(preview, email)
      rescue StandardError => e
        # flunk is injected by the host's Minitest test class.
        T.unsafe(self).flunk("#{key} is required to render but raised #{e.class}: #{e.message}") if required.include?(key)
        nil
      end
    end
  end
end
