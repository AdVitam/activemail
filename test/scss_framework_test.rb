# frozen_string_literal: true

require 'test_helper'

# Source-level regression guard for the shipped SCSS framework. A full compile
# smoke would need a Sass toolchain dependency in the test group (deferred); this
# catches the likeliest regression — the dark-mode rules or an import going missing.
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
