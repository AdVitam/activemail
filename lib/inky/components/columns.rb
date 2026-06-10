# typed: strict
# frozen_string_literal: true

require_relative 'base'

module Inky
  module Components
    class Columns < Base
      extend T::Sig

      sig { override.params(node: Nokogiri::XML::Node, inner: String).returns(String) }
      def transform(node, inner)
        col_count = node.parent.elements.size

        small_val = node.attr('small')
        large_val = node.attr('large')
        small_size = (small_val || column_count).to_i
        large_size = (large_val || small_val || (column_count / col_count)).to_i

        classes = combine_classes(node, "small-#{small_size} large-#{large_size} columns")
        classes += ' first' unless node.previous_element
        classes += ' last' unless node.next_element

        subrows = node.elements.css('.row').to_a.concat(node.elements.css('row').to_a)
        expander = %(<th class="expander"></th>) if large_size == column_count && subrows.empty?

        width_px = ((large_size.to_f / column_count) * container_width).round
        # display:inline-block + max-width gives natural stacking on small screens
        # without a media query; MSO ghost cells restore the grid in Outlook Word.
        style = "display:inline-block;vertical-align:top;width:100%;max-width:#{width_px}px;"

        <<~HTML.delete("\n")
          <!--[if mso | IE]><td width="#{width_px}" valign="top"><![endif]-->
          <#{::Inky::Core::INTERIM_TH_TAG} class="#{classes}" style="#{style}" #{pass_through_attributes(node)}><table role="presentation" border="0" cellpadding="0" cellspacing="0" style="width:100%;"><tbody><tr><th>#{inner}</th>#{expander}</tr></tbody></table></#{::Inky::Core::INTERIM_TH_TAG}>
          <!--[if mso | IE]></td><![endif]-->
        HTML
      end
    end
  end
end
