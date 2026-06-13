# typed: strict
# frozen_string_literal: true

require_relative '../quality'

module ActiveMail
  module Quality
    module Rspec
      # Standalone matcher object — testable without booting RSpec. The
      # RSpec::Matchers.define registration below merely delegates to it.
      class ValidEmailMatcher
        extend T::Sig

        sig { params(guard: Guard).void }
        def initialize(guard: ActiveMail::Quality.guard)
          @guard = T.let(guard, Guard)
          @violations = T.let([], T::Array[Guard::Violation])
        end

        sig { params(html: String).returns(T::Boolean) }
        def matches?(html)
          @violations = @guard.violations(html)
          @violations.empty?
        end

        sig { returns(String) }
        def failure_message
          "expected email HTML to be valid, but found violations:\n#{formatted_violations}"
        end

        sig { returns(String) }
        def failure_message_when_negated
          'expected email HTML to have quality violations, but it was valid'
        end

        sig { returns(String) }
        def description
          'be a valid email'
        end

        private

        sig { returns(String) }
        def formatted_violations
          @violations.map { |v| "  - [#{v.rule}] #{v.message}" }.join("\n")
        end
      end
    end
  end
end

if defined?(RSpec)
  # ValidEmailMatcher already implements the full matcher protocol, so a simple
  # helper returning it is enough — no RSpec::Matchers.define DSL needed.
  module RSpec
    module Matchers
      extend T::Sig

      sig { params(guard: ActiveMail::Quality::Guard).returns(ActiveMail::Quality::Rspec::ValidEmailMatcher) }
      def be_a_valid_email(guard: ActiveMail::Quality.guard)
        ActiveMail::Quality::Rspec::ValidEmailMatcher.new(guard: guard)
      end
    end
  end
end
