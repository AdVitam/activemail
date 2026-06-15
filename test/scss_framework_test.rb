# frozen_string_literal: true

require 'test_helper'

# Source-level regression guard for the shipped SCSS framework: imports, the
# dark-mode dual strategy, and the token bridge. The compiled + inlined behavior
# (gutter overflow, collapse selector, container_width) is proven by the
# render-validation harness in scss_render_harness_test.rb.
class ScssFrameworkTest < ActiveMailTest
  SCSS_DIR = File.expand_path('../app/assets/stylesheets/active_mail', __dir__)

  def read(partial)
    File.read(File.join(SCSS_DIR, partial))
  end

  def test_entry_imports_every_partial
    entry = read('active_mail.scss')

    %w[settings grid components utilities dark].each do |partial|
      assert_includes entry, %(@import "active_mail/#{partial}"), "active_mail.scss must import #{partial}"
    end
  end

  def test_dark_mode_ships_the_dual_strategy
    dark = read('_dark.scss')

    assert_includes dark, 'prefers-color-scheme: dark', 'Apple Mail / iOS dark mode'
    assert_includes dark, '[data-ogsc]', 'Outlook.com dark mode'
  end

  def test_settings_pull_from_the_token_bridge
    assert_includes read('_settings.scss'), 'active_mail_tokens'
  end
end
