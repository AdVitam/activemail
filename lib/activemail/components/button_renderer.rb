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
      MSO_CELL_PADDING = 'mso-padding-alt:12px 24px;'
      LINE_HEIGHT = '1.25'

      sig { abstract.returns(String) }
      def root_class; end

      sig { override.params(node: Nokogiri::XML::Node, inner: String).returns(String) }
      def transform(node, inner)
        style = core.config.tokens.button_style(class?(node, 'secondary') ? :secondary : :primary)
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
        LINK_ATTRIBUTES
      end

      # Padding on the control makes the whole button a clickable target; Outlook Word
      # ignores it there, so the cell repeats it as `mso-padding-alt`.
      sig { params(node: Nokogiri::XML::Node, inner: String, style: ActiveMail::Tokens::ButtonStyle, expand: T::Boolean).returns(String) }
      def control(node, inner, style, expand)
        css = control_style(style, expand)
        extra = passthrough_attributes(node)
        return %(<span#{extra}#{style_attribute(node, css)}>#{inner}</span>) unless node.attr('href')

        anchor(node, inner, before: extra, after: style_attribute(node, css))
      end

      # Fill, corners and outline live on the cell only: repeating them on the control would double them.
      sig { params(style: ActiveMail::Tokens::ButtonStyle, expand: T::Boolean).returns(String) }
      def cell_style(style, expand)
        border = style.border ? "border:1px solid #{style.border};" : ''
        "background:#{style.background};border-radius:#{style.radius};#{border}#{MSO_CELL_PADDING}#{'text-align:center;' if expand}"
      end

      sig { params(style: ActiveMail::Tokens::ButtonStyle, expand: T::Boolean).returns(String) }
      def control_style(style, expand)
        "display:#{expand ? 'block' : 'inline-block'};text-decoration:none;#{CONTROL_PADDING}" \
          "font-family:#{escape_attr(core.config.tokens.font!(:body))};line-height:#{LINE_HEIGHT};" \
          "color:#{style.color};font-weight:bold;"
      end
    end
  end
end
