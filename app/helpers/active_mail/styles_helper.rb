# typed: false
# frozen_string_literal: true

require 'activemail/asset_pipeline'

module ActiveMail
  # Embeds the compiled CSS as a <style> block: the inliners take an HTML string
  # and cannot fetch the digest URL a stylesheet_link_tag would emit.
  module StylesHelper
    FRAMEWORK_STYLESHEET = 'activemail/activemail'

    def activemail_inline_styles(*logical_paths)
      paths = logical_paths.empty? ? [FRAMEWORK_STYLESHEET] : logical_paths
      css = paths.map { |path| activemail_compiled_css(path.to_s) }.join("\n")
      content_tag(:style, css.html_safe, type: 'text/css')
    end

    private

    def activemail_compiled_css(logical_path)
      asset = logical_path.end_with?('.css') ? logical_path : "#{logical_path}.css"
      css = ActiveMail::AssetPipeline.current.read(asset)
      return css if css.present?

      raise ActiveMail::StylesheetNotFound, "stylesheet #{asset.inspect} is missing or empty in the asset pipeline"
    end
  end
end
