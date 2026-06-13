# frozen_string_literal: true

require_relative 'quality_test_helper'
require 'active_mail/quality/minitest'

class MinitestQualityTest < QualityTest
  include ActiveMail::Quality::Minitest

  CLEAN = <<~HTML.freeze
    <!DOCTYPE html>
    <html lang="en"><head></head><body>
      <table role="presentation"><tr><td>#{'x ' * 600}</td></tr></table>
    </body></html>
  HTML

  VIOLATING = '<html><body><img src="x.png"></body></html>'

  def test_assert_email_quality_passes_on_clean_html
    assert_email_quality(CLEAN)
  end

  def test_assert_email_quality_raises_on_violating_html
    assert_raises(Minitest::Assertion) { assert_email_quality(VIOLATING) }
  end

  def test_assert_email_quality_respects_custom_guard
    tiny = ActiveMail::Quality::Guard.new(max_bytes: 10)

    assert_raises(Minitest::Assertion) { assert_email_quality(CLEAN, guard: tiny) }
  end

  def test_assert_preview_quality_renders_and_checks
    preview = build_preview(CLEAN)
    assert_preview_quality(preview, 'welcome')

    bad = build_preview(VIOLATING)
    assert_raises(Minitest::Assertion) { assert_preview_quality(bad, 'welcome') }
  end

  private

  def build_preview(html)
    require 'mail'
    message = Mail.new do
      content_type 'text/html; charset=UTF-8'
      body html
    end
    preview = Object.new
    preview.define_singleton_method(:call) { |_email| message }
    preview.define_singleton_method(:preview_name) { 'fake' }
    preview
  end
end
