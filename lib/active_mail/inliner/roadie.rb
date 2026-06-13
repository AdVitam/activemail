# typed: strict
# frozen_string_literal: true

require_relative 'base'

module ActiveMail
  module Inliner
    # Optional adapter — roadie is not a runtime dependency of the gem.
    class Roadie < Base
      extend T::Sig

      sig { override.params(html: String).returns(String) }
      def inline(html)
        require_roadie!
        ::Roadie::Document.new(html).transform
      end

      private

      sig { void }
      def require_roadie!
        require 'roadie'
      rescue LoadError => e
        raise LoadError, "ActiveMail::Inliner::Roadie requires the 'roadie' gem. Add it to your Gemfile. (#{e.message})"
      end
    end
  end
end
