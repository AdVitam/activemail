# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'

module ActiveMail
  module Inliner
    # DIP seam: ActiveMail depends on this abstraction, not premailer/roadie.
    class Base
      extend T::Sig
      extend T::Helpers

      abstract!

      sig { abstract.params(html: String).returns(String) }
      def inline(html); end
    end
  end
end
