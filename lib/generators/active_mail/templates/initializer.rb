# frozen_string_literal: true

# ActiveMail configuration. Works zero-config; uncomment to customize.
ActiveMail.configure do |config|
  # Template engine ActiveMail composes with for `.inky` views (`.inky-erb`,
  # `.inky-haml`, … are always available regardless of this default).
  # config.template_engine = :erb

  # Layout geometry.
  # config.column_count = 12
  # config.container_width = 600

  # CSS inliner: :premailer (default), :roadie, :null, or a custom
  # ActiveMail::Inliner::Base subclass/instance.
  # config.inliner = :premailer

  # Set false if another inliner (e.g. premailer-rails) already runs on mailers.
  # config.register_inline_interceptor = true

  # How malformed markup is handled: :warn (default), :ignore, or :raise.
  # config.on_parse_error = :warn

  # Design tokens — the single source of truth, bridged to SCSS via $am-*.
  # config.tokens.color :primary, "#2a9d8f"
  # config.tokens.color :secondary, "#264653"
  # config.tokens.font :heading, "Georgia, serif"
  # config.tokens.spacing :lg, "32px"

  # Register custom components (see `rails g active_mail:component`).
  # config.register_component "cta", Components::Cta
end
