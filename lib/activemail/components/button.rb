# typed: strict
# frozen_string_literal: true

require_relative 'button_renderer'

module ActiveMail
  module Components
    class Button < ButtonRenderer
      extend T::Sig

      sig { override.returns(String) }
      def root_class
        'button'
      end
    end
  end
end
