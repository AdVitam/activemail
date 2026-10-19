# typed: strict
# frozen_string_literal: true

require_relative 'base'

module ActiveMail
  module Components
    class Columns < Base
      extend T::Sig

      sig { override.params(node: Nokogiri::XML::Node, inner: String).returns(String) }
      def transform(node, inner)
        small, large = column_sizes(node)
        width_px = ghost_width(node, large)

        [
          %(<!--[if mso]><td width="#{width_px}" valign="top"><table #{TABLE_RESET} width="#{width_px}"><tr><![endif]-->),
          column_markup(node, inner, column_classes(node, small, large), width_px, expander(node, large)),
          '<!--[if mso]></tr></table></td><![endif]-->'
        ].join
      end

      private

      sig { override.returns(T::Array[String]) }
      def consumed_attributes
        %w[small large]
      end

      sig { params(node: Nokogiri::XML::Node).returns([Integer, Integer]) }
      def column_sizes(node)
        small = positive_int(node.attr('small'))
        large = positive_int(node.attr('large'))
        [small || column_count, large || small || [column_count / column_siblings(node).size, 1].max]
      end

      # Already transformed columns are interim <th class="columns"> elements; other siblings take no width.
      sig { params(node: Nokogiri::XML::Node).returns(T::Array[Nokogiri::XML::Node]) }
      def column_siblings(node)
        return [node] unless node.parent

        node.parent.elements.select { |sibling| sibling.name == node.name || column?(sibling) }
      end

      sig { params(node: Nokogiri::XML::Node).returns(T::Boolean) }
      def column?(node)
        return false unless node.name == ::ActiveMail::Core::INTERIM_TH_TAG

        class?(node, 'columns')
      end

      sig { params(node: Nokogiri::XML::Node, small: Integer, large: Integer).returns(String) }
      def column_classes(node, small, large)
        siblings = column_siblings(node)
        classes = combine_classes(node, "small-#{small} large-#{large} columns")
        classes += ' first' if siblings.first == node
        classes += ' last' if siblings.last == node
        classes
      end

      sig { params(node: Nokogiri::XML::Node, large: Integer).returns(String) }
      def expander(node, large)
        return '' unless large == column_count && node.at_css('.row').nil?

        %(<th class="expander"></th>)
      end

      # Columns are transformed leaves first, so the enclosing <columns> are still raw
      # nodes whose sizes are readable. Each share is clamped: an oversized `large`
      # would push the MSO ghost cell past its parent and force a wrap in Outlook Word.
      sig { params(node: Nokogiri::XML::Node, large: Integer).returns(Integer) }
      def ghost_width(node, large)
        shares = [large, *node.ancestors('columns').map { |ancestor| column_sizes(ancestor).last }]
        ratio = shares.reduce(Rational(1)) { |product, share| product * Rational([share, column_count].min, column_count) }
        (container_width * ratio).round
      end

      sig { params(node: Nokogiri::XML::Node, inner: String, classes: String, width_px: Integer, expander: String).returns(String) }
      def column_markup(node, inner, classes, width_px, expander)
        # display:inline-block + max-width gives natural stacking on small screens
        # without a media query; MSO ghost cells restore the grid in Outlook Word.
        style = "display:inline-block;vertical-align:top;width:100%;max-width:#{width_px}px;"
        # Neutralize the client default th rendering (bold, centered).
        content_style = 'font-weight:normal;text-align:left;'
        [
          %(<#{::ActiveMail::Core::INTERIM_TH_TAG}#{root_attributes(node, classes: classes, layout_style: style)}>),
          %(<table #{TABLE_RESET} style="width:100%;"><tbody><tr>),
          %(<th style="#{content_style}">#{inner}</th>#{expander}),
          %(</tr></tbody></table></#{::ActiveMail::Core::INTERIM_TH_TAG}>)
        ].join
      end
    end
  end
end
