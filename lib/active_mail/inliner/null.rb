# typed: strict
# frozen_string_literal: true

require_relative 'base'

module ActiveMail
  module Inliner
    # Opt-out / test adapter: returns HTML untouched.
    class Null < Base
      extend T::Sig

      sig { override.params(html: String).returns(String) }
      def inline(html)
        html
      end

      sig { override.returns(T::Boolean) }
      def noop?
        true
      end
    end
  end
end
