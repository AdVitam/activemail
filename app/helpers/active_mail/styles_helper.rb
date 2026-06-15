# typed: false
# frozen_string_literal: true

module ActiveMail
  # Inlines the compiled framework CSS into the mailer <head> as a <style> block.
  #
  # The default layout cannot rely on stylesheet_link_tag for inlining: the
  # Premailer adapter receives only the HTML string (with_html_string: true) and
  # cannot resolve a relative /assets/*.css link, so it silently drops the link and
  # ships a zero-config email with NO framework CSS. Premailer DOES inline <style>
  # blocks present in the HTML, so we read the compiled asset bytes and embed them.
  #
  # Reading the compiled bytes directly (rather than pointing Premailer at a URL)
  # is deterministic and offline — no asset host assumption, no HTTP fetch at
  # delivery time — and works identically under Sprockets and Propshaft.
  module StylesHelper
    FRAMEWORK_STYLESHEET = 'active_mail/active_mail.css'

    # The <style> the Premailer adapter inlines onto the elements. Returns '' when
    # the asset can't be located so the layout degrades to the link-tag fallback
    # rather than raising — but warns, since the email then ships unstyled.
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
