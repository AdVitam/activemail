# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'

module ActiveMail
  module Inliner
    # Raised when an adapter fails; the original (premailer/roadie/nokogiri)
    # exception is preserved as Exception#cause with its backtrace intact.
    class Error < StandardError; end

    # DIP seam: ActiveMail depends on this abstraction, not premailer/roadie.
    class Base
      extend T::Sig
      extend T::Helpers

      abstract!

      sig { abstract.params(html: String).returns(String) }
      def inline(html); end

      # Lets the interceptor skip work without type-checking concrete adapters.
      sig { returns(T::Boolean) }
      def noop?
        false
      end
    end
  end
end
