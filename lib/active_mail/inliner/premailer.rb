# typed: strict
# frozen_string_literal: true

require_relative 'base'

module ActiveMail
  module Inliner
    class Premailer < Base
      extend T::Sig

      sig { override.params(html: String).returns(String) }
      def inline(html)
        require 'premailer'
        # warn_level NONE: premailer's un-inlinable-CSS warnings are noise at delivery
        # time; the quality layer is where coverage gaps should surface.
        ::Premailer.new(html, with_html_string: true, warn_level: ::Premailer::Warnings::NONE).to_inline_css
      end
    end
  end
end
