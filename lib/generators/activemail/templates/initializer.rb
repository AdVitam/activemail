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
  # Configure values here (literals, including rgba()/transparent) rather than
  # parsing SCSS back into Ruby: the bridge only flows Ruby → SCSS.
  # config.tokens.color :primary, "#2a9d8f"
  # config.tokens.color :secondary, "#264653"
  # config.tokens.font :heading, "Georgia, serif"
  # config.tokens.spacing :lg, "32px"
  # config.tokens.radius :button, "6px"   # <cta>/.button corner radius
  # config.tokens.radius :box, "8px"       # <info-box> corner radius
  #
  # Outline secondary button (filled by default): give the secondary variant its
  # own text + border instead of just a fill.
  # config.tokens.color :secondary, "#ffffff"
  # config.tokens.color :secondary_text, "#0f4447"
  # config.tokens.color :secondary_border, "rgba(15, 68, 71, 0.6)"
  #
  # Box-scoped colors (fall back to :background/:border/:text when unset).
  # config.tokens.color :info_box_background, "#fff7ef"
  #
  # Or configure everything in one block:
  # config.tokens.load(
  #   color: { primary: "#2a9d8f", secondary_text: "#0f4447" },
  #   radius: { button: "6px", box: "8px" }
  # )

  # Register components (built-ins like ActiveMail::Components::Cta, or your own
  # Components::* from `rails g activemail:component`).
  # config.register_component "cta", ActiveMail::Components::Cta
end
