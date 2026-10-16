# typed: strict
# frozen_string_literal: true

require_relative 'base'

module ActiveMail
  module Components
    class HLine < Base
      extend T::Sig

      sig { override.params(node: Nokogiri::XML::Node, _inner: String).returns(String) }
      def transform(node, _inner)
        %(<table#{root_attributes(node, classes: 'h-line', layout_style: 'width:100%;')} #{TABLE_RESET}><tbody><tr><th>&nbsp;</th></tr></tbody></table>)
      end

      private

      sig { override.returns(T::Array[String]) }
      def consumed_attributes
        TABLE_RESET_ATTRIBUTES
      end
    end
  end
end
