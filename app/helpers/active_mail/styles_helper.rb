# typed: false
# frozen_string_literal: true

module ActiveMail
  # Embeds the compiled framework CSS as a <style> block so the Premailer adapter
  # (string-only) inlines it — it can't fetch the stylesheet_link_tag's asset URL.
  module StylesHelper
    FRAMEWORK_STYLESHEET = 'active_mail/active_mail.css'

    # '' (not raise) when the asset can't be read — degrades to the link fallback,
    # but warns, since the email then ships unstyled.
    def active_mail_inline_styles
      css = active_mail_compiled_css
      if css.blank?
        ActiveMail.log_warning('[activemail] framework stylesheet could not be read from the asset pipeline; ' \
                               'email ships without inlined framework CSS')
        return ''.html_safe
      end

      content_tag(:style, css.html_safe, type: 'text/css')
    end

    private

    def active_mail_compiled_css
      ActiveMail::CompiledStylesheet.read(FRAMEWORK_STYLESHEET)
    end
  end
end
