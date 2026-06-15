# frozen_string_literal: true

require 'test_helper'

# Source-level regression guard for the shipped SCSS framework: imports, the
# dark-mode dual strategy, and the token bridge. The compiled + inlined behavior
# (gutter overflow, collapse selector, container_width) is proven by the
# render-validation harness in scss_render_harness_test.rb.
class ScssFrameworkTest < ActiveMailTest
  SCSS_DIR = File.expand_path('../app/assets/stylesheets/activemail', __dir__)

  def read(partial)
    File.read(File.join(SCSS_DIR, partial))
  end

  def test_entry_imports_every_partial
    entry = read('activemail.scss')

    %w[settings grid components utilities dark].each do |partial|
      assert_includes entry, %(@import "activemail/#{partial}"), "activemail.scss must import #{partial}"
    end
  end

  def test_dark_mode_ships_the_dual_strategy
    dark = read('_dark.scss')

    assert_includes dark, 'prefers-color-scheme: dark', 'Apple Mail / iOS dark mode'
    assert_includes dark, '[data-ogsc]', 'Outlook.com dark mode'
  end

  def test_settings_pull_from_the_token_bridge
    assert_includes read('_settings.scss'), 'activemail_tokens'
  end

  def test_button_radius_is_token_driven_and_always_on
    settings = read('_settings.scss')
    components = read('_components.scss')

    assert_includes settings, '$am-button-radius: $am-radius-button !default;'
    # Radius lives on the base rule, not an opt-in .radius selector.
    assert_match(/\.button table td,\s*\.button a \{[^}]*border-radius: \$am-button-radius;/m, components)
    refute_match(/\.button\.radius/, components)
  end

  def test_secondary_and_info_box_mirror_their_tokens
    components = read('_components.scss')

    assert_match(/\.button\.secondary[^{]*\{[^}]*border: 1px solid \$am-button-secondary-border;/m, components)
    assert_match(/\.info-box td \{[^}]*border-radius: \$am-box-radius;/m, components)
  end
end
