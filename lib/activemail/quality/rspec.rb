# typed: strict
# frozen_string_literal: true

require_relative '../quality'

module ActiveMail
  module Quality
    module Rspec
      class ValidEmailMatcher
        extend T::Sig

        sig { params(guard: Guard, allow_declined: T::Boolean).void }
        def initialize(guard: ActiveMail::Quality.guard, allow_declined: false)
          @guard = T.let(guard, Guard)
          @allow_declined = T.let(allow_declined, T::Boolean)
          @violations = T.let([], T::Array[Guard::Violation])
        end

        sig { params(html_or_message: T.untyped).returns(T::Boolean) }
        def matches?(html_or_message)
          @violations = @guard.violations(html_or_message, allow_declined: @allow_declined)
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
          @violations.map { |v| "  - #{v}" }.join("\n")
        end
      end
    end
  end
end

if defined?(RSpec)
  module RSpec
    module Matchers
      extend T::Sig

      sig { params(guard: ActiveMail::Quality::Guard, allow_declined: T::Boolean).returns(ActiveMail::Quality::Rspec::ValidEmailMatcher) }
      def be_a_valid_email(guard: ActiveMail::Quality.guard, allow_declined: false)
        ActiveMail::Quality::Rspec::ValidEmailMatcher.new(guard: guard, allow_declined: allow_declined)
      end
    end
  end
end
