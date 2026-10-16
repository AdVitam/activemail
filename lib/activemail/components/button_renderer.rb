# typed: strict
# frozen_string_literal: true

require_relative 'base'

module ActiveMail
  module Components
    # Bulletproof button shared by <button> and <cta>: styles are inlined from the
    # tokens (read at transform time) so it survives clients that strip <style>.
    class ButtonRenderer < Base
      extend T::Sig
      extend T::Helpers

      abstract!

      CONTROL_PADDING = 'padding:12px 24px;'

      sig { abstract.returns(String) }
      def root_class; end

      sig { override.params(node: Nokogiri::XML::Node, inner: String).returns(String) }
      def transform(node, inner)
        style = ActiveMail.tokens.button_style(class?(node, 'secondary') ? :secondary : :primary)
        expand = class?(node, 'expand')
        width = expand ? ' style="width:100%;"' : ''
        [
          %(<table#{class_attribute(node, root_class)} #{TABLE_RESET}#{width}><tbody><tr><td>),
          %(<table #{TABLE_RESET}#{width}><tbody><tr><td style="#{cell_style(style, expand)}">),
          control(node, inner, style, expand),
          '</td></tr></tbody></table></td></tr></tbody></table>'
        ].join
      end

      private

      sig { override.returns(T::Array[String]) }
      def consumed_attributes
        %w[href target rel]
      end

      # Padding on the control makes the whole button a clickable target.
      sig { params(node: Nokogiri::XML::Node, inner: String, style: ActiveMail::Tokens::ButtonStyle, expand: T::Boolean).returns(String) }
      def control(node, inner, style, expand)
        css = control_style(style, expand)
        extra = passthrough_attributes(node)
        href = node.attr('href')
        return %(<span#{extra}#{style_attribute(node, css)}>#{inner}</span>) unless href

        %(<a#{extra} href="#{escape_attr(href)}"#{link_attributes(node)}#{style_attribute(node, css)}>#{inner}</a>)
      end

      # The outline lives on the cell only: repeating it on the control would double the line.
      sig { params(style: ActiveMail::Tokens::ButtonStyle, expand: T::Boolean).returns(String) }
      def cell_style(style, expand)
        border = style.border ? "border:1px solid #{style.border};" : ''
        "background:#{style.background};border-radius:#{style.radius};#{border}#{'text-align:center;' if expand}"
      end

      sig { params(style: ActiveMail::Tokens::ButtonStyle, expand: T::Boolean).returns(String) }
      def control_style(style, expand)
        "display:#{expand ? 'block' : 'inline-block'};text-decoration:none;#{CONTROL_PADDING}" \
          "background:#{style.background};color:#{style.color};font-weight:bold;border-radius:#{style.radius};"
      end
    end
  end
end
