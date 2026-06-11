# typed: strict
# frozen_string_literal: true

require_relative 'base'

module Inky
  module Components
    class Columns < Base
      extend T::Sig

      sig { override.params(node: Nokogiri::XML::Node, inner: String).returns(String) }
      def transform(node, inner)
        small, large = column_sizes(node)
        width_px = ghost_width(large)

        [
          %(<!--[if mso | IE]><td width="#{width_px}" valign="top"><![endif]-->),
          column_markup(node, inner, column_classes(node, small, large), width_px, expander(node, large)),
          '<!--[if mso | IE]></td><![endif]-->'
        ].join
      end

      private

      sig { params(node: Nokogiri::XML::Node).returns([Integer, Integer]) }
      def column_sizes(node)
        small_val = node.attr('small')
        large_val = node.attr('large')
        small = (small_val || column_count).to_i
        large = (large_val || small_val || (column_count / node.parent.elements.size)).to_i
        [small, large]
      end

      sig { params(node: Nokogiri::XML::Node, small: Integer, large: Integer).returns(String) }
      def column_classes(node, small, large)
        classes = combine_classes(node, "small-#{small} large-#{large} columns")
        classes += ' first' unless node.previous_element
        classes += ' last' unless node.next_element
        classes
      end

      sig { params(node: Nokogiri::XML::Node, large: Integer).returns(String) }
      def expander(node, large)
        subrows = node.elements.css('.row').to_a.concat(node.elements.css('row').to_a)
        return '' unless large == column_count && subrows.empty?

        %(<th class="expander"></th>)
      end

      # Clamp: an oversized `large` would push the MSO ghost cell past the
      # container and force a wrap in Outlook Word.
      sig { params(large: Integer).returns(Integer) }
      def ghost_width(large)
        [((large.to_f / column_count) * container_width).round, container_width].min
      end

      sig { params(node: Nokogiri::XML::Node, inner: String, classes: String, width_px: Integer, expander: String).returns(String) }
      def column_markup(node, inner, classes, width_px, expander)
        # display:inline-block + max-width gives natural stacking on small screens
        # without a media query; MSO ghost cells restore the grid in Outlook Word.
        style = "display:inline-block;vertical-align:top;width:100%;max-width:#{width_px}px;"
        # Neutralize the client default th rendering (bold, centered).
        content_style = 'font-weight:normal;text-align:left;'
        [
          %(<#{::Inky::Core::INTERIM_TH_TAG} class="#{classes}"#{style_attribute(node, style)} #{pass_through_attributes(node)}>),
          %(<table #{TABLE_RESET} style="width:100%;"><tbody><tr>),
          %(<th style="#{content_style}">#{inner}</th>#{expander}),
          %(</tr></tbody></table></#{::Inky::Core::INTERIM_TH_TAG}>)
        ].join
      end
    end
  end
end
