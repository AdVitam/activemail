# frozen_string_literal: true

require 'test_helper'
require 'support/scss_compiler'

class ScssFrameworkTest < ActiveMailTest
  SCSS_DIR = File.expand_path('../app/assets/stylesheets/activemail', __dir__)

  def read(partial)
    File.read(File.join(SCSS_DIR, partial))
  end

  def host(config = '')
    ScssCompiler.compile(%(@use "activemail/activemail" with (#{config});))
  end

  def block(selector, css)
    css[/^#{Regexp.escape(selector)}\s*\{[^}]*\}/m].to_s
  end

  def test_no_partial_uses_the_legacy_import
    Dir.glob(File.join(SCSS_DIR, '*')).each do |file|
      refute_match(/@import/, File.read(file), "#{File.basename(file)} still uses @import")
    end
  end

  def test_compiles_without_any_deprecation
    refute_empty ScssCompiler.compile
  end

  def test_dark_mode_ships_the_dual_strategy
    dark = read('_dark.scss')

    assert_includes dark, 'prefers-color-scheme: dark', 'Apple Mail / iOS dark mode'
    assert_includes dark, '[data-ogsc]', 'Outlook.com dark mode'
  end

  def test_dark_mode_goes_through_the_button_layer
    dark = read('_dark.scss')

    assert_includes dark, '$am-button-primary-bg'
    assert_includes dark, '$am-button-secondary-color'
    refute_match(/\$am-color-(primary|secondary|button-text)\b/, dark)
  end

  def test_dark_mode_uses_secondary_button_tokens
    ActiveMail.tokens.color(:secondary_text, '#123456')
    css = ScssCompiler.compile

    assert_match(/\.button\.secondary a[^{]*\{[^}]*color: #123456 !important/m, css)
  end

  def test_host_overrides_tokens_through_use_with
    css = host('$am-color-primary: #ff0000, $am-container-width: 480px')

    assert_match(/max-width: 480px/, block('.container', css))
    assert_match(/background: #ff0000 !important/, css)
  end

  def test_host_overrides_the_dark_palette
    css = host('$am-dark-bg: #010101, $am-dark-link: #020202')

    assert_match(/body \{\s*background-color: #010101 !important/, css)
    assert_match(/\ba \{\s*color: #020202 !important/, css)
  end

  def test_only_settings_declares_configurable_variables
    Dir.glob(File.join(SCSS_DIR, '*.scss')).each do |file|
      next if File.basename(file) == '_settings.scss'

      refute_match(/!default/, File.read(file), "#{File.basename(file)} declares a variable a host cannot configure")
    end
  end

  def test_host_overrides_the_button_layer
    css = host('$am-button-secondary-color: #010203')

    assert_match(/color: #010203 !important/, css)
  end

  def test_secondary_button_color_follows_secondary_text_then_button_text
    assert_includes ScssCompiler.compile, 'color: #ffffff !important'

    ActiveMail.tokens.color(:button_text, '#111111')

    assert_includes ScssCompiler.compile, 'color: #111111 !important'

    ActiveMail.tokens.color(:secondary_text, '#222222')

    assert_includes ScssCompiler.compile, 'color: #222222 !important'
  end

  def test_info_box_follows_its_tokens
    ActiveMail.tokens.color(:info_box_border, '#abcdef')
    ActiveMail.tokens.color(:info_box_background, '#fedcba')
    css = ScssCompiler.compile

    assert_match(/border-left: 5px solid #abcdef/, css)
    assert_match(/background-color: #fedcba/, block('.info-box td', css))
  end

  def test_callout_inner_has_no_border_color
    refute_match(/border-left-color/, block('.callout-inner', ScssCompiler.compile))
  end

  def test_breakpoint_follows_the_container_width
    assert_includes ScssCompiler.compile, '@media only screen and (min-width: 600px)'

    ActiveMail.configuration.container_width = 480

    assert_includes ScssCompiler.compile, '@media only screen and (min-width: 480px)'
    assert_includes host('$am-breakpoint: 640px'), '(min-width: 640px)'
  end

  def test_h_line_rules
    css = ScssCompiler.compile

    assert_match(/border-top: 1px solid #e5e7eb/, block('.h-line', css))
    assert_match(/font-size: 1px;\s*line-height: 1px/, css)
  end

  def test_block_grid_up_n_rules_follow_the_column_count
    css = ScssCompiler.compile

    assert_match(/\.block-grid\.up-3 > tbody > tr > th[^{]*\{\s*width: 33\.33/, css)
    assert_includes css, '.block-grid.up-12'
    refute_includes host('$am-column-count: 4'), '.block-grid.up-5'
  end

  def test_menu_and_expander_rules
    css = ScssCompiler.compile

    assert_match(/\.menu-item \{[^}]*padding: 8px 16px/m, css)
    assert_match(/\.menu \{[^}]*width: auto/m, css)
    assert_match(/\.expander \{[^}]*visibility: hidden/m, css)
  end

  def test_dark_mode_targets_links_and_spans_of_both_buttons
    css = ScssCompiler.compile

    %w[.button .cta .button.secondary .cta.secondary].each do |root|
      assert_match(/#{Regexp.escape(root)} a,\s*#{Regexp.escape(root)} span/, css)
    end
  end

  def test_buttons_carry_no_css_only_color_rules
    refute_match(/^\.button table td,\n\.button a \{[^}]*border-radius/m, ScssCompiler.compile)
  end
end
