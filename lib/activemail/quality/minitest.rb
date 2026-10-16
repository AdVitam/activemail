# typed: strict
# frozen_string_literal: true

require_relative '../quality'

module ActiveMail
  module Quality
    module Minitest
      extend T::Sig

      # html_or_message: an HTML String, or a Mail::Message / ActionMailer::MessageDelivery
      # (which also runs the message-level rules).
      sig { params(html_or_message: T.untyped, guard: Guard).void }
      def assert_email_quality(html_or_message, guard: ActiveMail::Quality.guard)
        assert_no_quality_violations(guard.violations(html_or_message))
      end

      sig do
        params(preview: T.untyped, email: String, guard: Guard, locale: Symbol, around_each: T.nilable(Proc)).void
      end
      def assert_preview_quality(preview, email, guard: ActiveMail::Quality.guard, locale: I18n.default_locale,
                                 around_each: ActiveMail::Quality.config.around_each)
        assert_no_quality_violations(PreviewRenderer.within(preview, email, locale, around_each) { |mail| guard.violations(mail) })
      end

      module ClassMethods
        extend T::Sig

        # One test per discovered preview and configured locale; a non-required
        # preview that can't render is skipped, a required one fails (see
        # #render_preview_or_skip). locales and around_each come from Quality.config.
        sig { params(guard: Guard).void }
        def assert_quality_for_all_previews(guard: ActiveMail::Quality.guard)
          required = ActiveMail::Quality.config.required_previews
          cases = quality_cases
          # A silent no-test run would look like everything passed.
          Kernel.warn('[activemail] assert_quality_for_all_previews: no previews discovered.') if cases.empty?
          cases.each_with_index do |(preview, email, locale), i|
            key = PreviewRenderer.key(preview, email)
            # Index prefix: distinct keys can normalize to the same method name.
            T.unsafe(self).define_method("test_#{i}_#{key.gsub(/\W/, '_')}_#{locale}_email_quality") do
              violations = T.unsafe(self).send(:render_preview_or_skip, preview, email, locale, guard, required)
              T.unsafe(self).send(:assert_no_quality_violations, violations)
            end
          end
        end

        private

        sig { returns(T::Array[[T.untyped, String, Symbol]]) }
        def quality_cases
          config = ActiveMail::Quality.config
          PreviewRenderer.all.flat_map { |preview, email| config.locales_for(preview).map { |locale| [preview, email, locale] } }
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
                              "email quality violations:\n#{violations.map { |v| "  - [#{v.rule}] #{v.message}" }.join("\n")}"
      end

      # Returns the guard's violations; a non-required preview that fails to render is
      # skipped (not a silent pass), a required one fails. flunk/skip are injected by
      # Minitest; both raise.
      sig do
        params(preview: T.untyped, email: String, locale: Symbol, guard: Guard, required: T::Array[String])
          .returns(T::Array[Guard::Violation])
      end
      def render_preview_or_skip(preview, email, locale, guard, required)
        PreviewRenderer.within(preview, email, locale, ActiveMail::Quality.config.around_each) { |mail| guard.violations(mail) }
      rescue StandardError => e
        key = PreviewRenderer.key(preview, email)
        msg = "#{key} [#{locale}] did not render (#{e.class}: #{e.message})"
        required.include?(key) ? T.unsafe(self).flunk("required preview #{msg}") : T.unsafe(self).skip(msg)
      end
    end
  end
end
