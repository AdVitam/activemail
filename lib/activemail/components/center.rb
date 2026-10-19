# typed: strict
# frozen_string_literal: true

require_relative 'base'

module ActiveMail
  module Components
    class Center < Base
      extend T::Sig

      sig { override.params(node: Nokogiri::XML::Node, inner: String).returns(String) }
      def transform(node, inner)
        %(<center#{root_attributes(node, classes: 'float-center')} align="center">#{inner}</center>)
      end

      private

      sig { override.returns(T::Array[String]) }
      def consumed_attributes
        ['align']
      end
    end
  end
end
