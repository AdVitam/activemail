# typed: strict
# frozen_string_literal: true

require_relative '../quality'

module ActiveMail
  module Quality
    module Minitest
      extend T::Sig

      sig { params(html_or_message: T.untyped, guard: Guard).void }
      def assert_email_quality(html_or_message, guard: ActiveMail::Quality.guard)
        assert_no_quality_violations(guard.violations(html_or_message))
      end

      sig do
        params(preview: T.untyped, email: String, guard: Guard, locale: Symbol, around_each: T.nilable(Proc)).void
      end
      def assert_preview_quality(preview, email, guard: ActiveMail::Quality.guard, locale: I18n.default_locale,
                                 around_each: ActiveMail::Quality.config.around_each)
        assert_no_quality_violations(preview_violations(preview, email, locale, guard, around_each))
      end

      module ClassMethods
        extend T::Sig

        sig { params(guard: Guard).void }
        def assert_quality_for_all_previews(guard: ActiveMail::Quality.guard)
          config = ActiveMail::Quality.config
          cases = PreviewRenderer.cases(config)
          # A silent no-test run would look like everything passed.
          Kernel.warn('[activemail] assert_quality_for_all_previews: no previews discovered.') if cases.empty?
          cases.each_with_index do |(preview, email, locale), i|
            # Index prefix: distinct keys can normalize to the same method name.
            name = "test_#{i}_#{PreviewRenderer.key(preview, email).gsub(/\W/, '_')}_#{locale}_email_quality"
            T.unsafe(self).define_method(name) do
              violations = T.unsafe(self).send(:render_preview_or_skip, preview, email, locale, guard, config.required_previews)
              T.unsafe(self).send(:assert_no_quality_violations, violations)
            end
          end
        end
      end

      sig { params(base: T.untyped).void }
      def self.included(base)
        base.extend(ClassMethods)
      end

      private

      sig { params(violations: T::Array[Guard::Violation]).void }
      def assert_no_quality_violations(violations)
        # assert is injected by the host's Minitest test class.
        T.unsafe(self).assert violations.empty?,
                              "email quality violations:\n#{violations.map { |v| "  - #{v}" }.join("\n")}"
      end

      sig do
        params(preview: T.untyped, email: String, locale: Symbol, guard: Guard, around_each: T.nilable(Proc))
          .returns(T::Array[Guard::Violation])
      end
      def preview_violations(preview, email, locale, guard, around_each)
        PreviewRenderer.within(preview, email, locale, around_each) { |mail| guard.violations(mail) }
      end

      # A non-required preview that can't render is skipped, not a silent pass.
      sig do
        params(preview: T.untyped, email: String, locale: Symbol, guard: Guard, required: T::Array[String])
          .returns(T::Array[Guard::Violation])
      end
      def render_preview_or_skip(preview, email, locale, guard, required)
        preview_violations(preview, email, locale, guard, ActiveMail::Quality.config.around_each)
      rescue StandardError => e
        key = PreviewRenderer.key(preview, email)
        msg = "#{key} [#{locale}] did not render (#{e.class}: #{e.message})"
        required.include?(key) ? T.unsafe(self).flunk("required preview #{msg}") : T.unsafe(self).skip(msg)
      end
    end
  end
end
