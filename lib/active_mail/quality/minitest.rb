# typed: strict
# frozen_string_literal: true

require_relative '../quality'

module ActiveMail
  module Quality
    module Minitest
      extend T::Sig

      sig { params(html: String, guard: Guard).void }
      def assert_email_quality(html, guard: ActiveMail::Quality.guard)
        violations = guard.violations(html)
        # assert is injected by the host's Minitest test class.
        T.unsafe(self).assert violations.empty?,
                              "email quality violations:\n#{violations.map { |v| "  - [#{v.rule}] #{v.message}" }.join("\n")}"
      end

      sig { params(preview: T.untyped, email: String, guard: Guard).void }
      def assert_preview_quality(preview, email, guard: ActiveMail::Quality.guard)
        assert_email_quality(PreviewRenderer.render(preview, email), guard: guard)
      end

      module ClassMethods
        extend T::Sig

        # One test per discovered preview; a non-required preview that can't render
        # is skipped, a required one fails (see #render_preview_or_skip).
        sig { params(guard: Guard).void }
        def assert_quality_for_all_previews(guard: ActiveMail::Quality.guard)
          required = ActiveMail::Quality.config.required_previews
          previews = PreviewRenderer.all
          # A silent no-test run would look like everything passed.
          Kernel.warn('[activemail] assert_quality_for_all_previews: no previews discovered.') if previews.empty?
          previews.each_with_index do |(preview, email), i|
            key = PreviewRenderer.key(preview, email)
            # Index prefix: distinct keys can normalize to the same method name.
            T.unsafe(self).define_method("test_#{i}_#{key.gsub(/\W/, '_')}_email_quality") do
              html = T.unsafe(self).send(:render_preview_or_skip, preview, email, key, required)
              T.unsafe(self).assert_email_quality(html, guard: guard)
            end
          end
        end
      end

      sig { params(base: T.untyped).void }
      def self.included(base)
        base.extend(ClassMethods)
      end

      private

      # Returns rendered HTML; a non-required preview that fails is skipped (not a
      # silent pass), a required one fails. flunk/skip are injected by Minitest; both raise.
      sig { params(preview: T.untyped, email: String, key: String, required: T::Array[String]).returns(String) }
      def render_preview_or_skip(preview, email, key, required)
        PreviewRenderer.render(preview, email)
      rescue StandardError => e
        msg = "#{key} did not render (#{e.class}: #{e.message})"
        required.include?(key) ? T.unsafe(self).flunk("required preview #{msg}") : T.unsafe(self).skip(msg)
      end
    end
  end
end
