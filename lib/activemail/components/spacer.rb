# typed: strict
# frozen_string_literal: true

require_relative 'table_component'

module ActiveMail
  module Components
    class Spacer < TableComponent
      extend T::Sig

      sig { override.params(node: Nokogiri::XML::Node, _inner: String).returns(String) }
      def transform(node, _inner)
        size_sm = node.attr('size-sm')
        size_lg = node.attr('size-lg')

        return build_table(node, 'spacer', size_for(node.attr('size')), skip: []) unless size_sm || size_lg

        tables = []
        tables << ['spacer hide-for-large', size_for(size_sm)] if size_sm
        tables << ['spacer show-for-large', size_for(size_lg)] if size_lg
        tables.each_with_index.map { |(classes, size), index| build_table(node, classes, size, skip: index.zero? ? [] : %w[id]) }.join
      end

      private

      sig { override.returns(T::Array[String]) }
      def consumed_attributes
        [*super, 'size', 'size-sm', 'size-lg']
      end

      sig { params(value: T.untyped).returns(Integer) }
      def size_for(value)
        positive_int(value) || 16
      end

      # A repeated id would be invalid HTML: only the first table carries it.
      sig { params(node: Nokogiri::XML::Node, classes: String, size: Integer, skip: T::Array[String]).returns(String) }
      def build_table(node, classes, size, skip:)
        # mso-line-height-rule:exactly keeps Outlook from inflating the spacer.
        style = "font-size:#{size}px;line-height:#{size}px;mso-line-height-rule:exactly;"
        [
          %(<table#{root_attributes(node, classes: classes, layout_style: 'width:100%;', skip: skip)} #{TABLE_RESET}><tbody><tr>),
          %(<td height="#{size}" style="#{style}">&nbsp;</td>),
          '</tr></tbody></table>'
        ].join
      end
    end
  end
end
