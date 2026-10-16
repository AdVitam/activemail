# frozen_string_literal: true

require_relative 'quality_test_helper'
require 'activemail/quality/minitest'
require 'mail'

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

  def test_assert_quality_for_all_previews_generates_a_runnable_test_per_preview
    preview = build_preview(CLEAN)
    klass = Class.new(Minitest::Test) { include ActiveMail::Quality::Minitest }

    ActiveMail::Quality::PreviewRenderer.stub(:all, [[preview, 'welcome']]) do
      klass.assert_quality_for_all_previews
    end

    generated = klass.instance_methods.find { |m| m.to_s.start_with?('test_') && m.to_s.include?('email_quality') }
    assert generated, 'expected one generated quality test per preview'
    klass.new(generated).send(generated) # clean HTML → passes without raising
  end

  def test_assert_quality_for_all_previews_skips_a_non_required_unrenderable_preview
    raising = Object.new
    raising.define_singleton_method(:preview_name) { 'fake' }
    raising.define_singleton_method(:call) { |_email| raise 'boom' }
    klass = Class.new(Minitest::Test) { include ActiveMail::Quality::Minitest }

    ActiveMail::Quality::PreviewRenderer.stub(:all, [[raising, 'welcome']]) do
      klass.assert_quality_for_all_previews
    end

    generated = klass.instance_methods.find { |m| m.to_s.include?('email_quality') }
    # Not required → skipped (visible), not a silent pass.
    assert_raises(Minitest::Skip) { klass.new(generated).send(generated) }
  end

  def test_assert_email_quality_accepts_a_message_and_runs_message_rules
    html_only = Mail.new do
      content_type 'text/html; charset=UTF-8'
      body CLEAN
    end

    assert_raises(Minitest::Assertion) { assert_email_quality(html_only) }
    assert_email_quality(build_preview(CLEAN).call('welcome'))
  end

  def test_assert_email_quality_applies_custom_rules
    rule = ActiveMail::Quality::Rule.html(:no_x) { |_doc, html| 'has x' if html.include?('x ') }
    guard = ActiveMail::Quality::Guard.new(rules: [rule])

    assert_raises(Minitest::Assertion) { assert_email_quality(CLEAN, guard: guard) }
  end

  def test_assert_quality_for_all_previews_generates_a_test_per_locale_and_wraps_in_around_each
    wrapped = []
    ActiveMail::Quality.configure do |config|
      config.locales = %i[en fr]
      config.around_each = lambda do |_preview, _email, locale, &block|
        wrapped << locale
        block.call
      end
    end
    klass = Class.new(Minitest::Test) { include ActiveMail::Quality::Minitest }

    ActiveMail::Quality::PreviewRenderer.stub(:all, [[build_preview(CLEAN), 'welcome']]) do
      klass.assert_quality_for_all_previews
    end

    generated = klass.instance_methods.grep(/\Atest_.*email_quality/)
    assert_equal 2, generated.size
    generated.each { |name| klass.new(name).send(name) }
    assert_equal %i[en fr], wrapped.sort
  end

  private

  def build_preview(html)
    require 'mail'
    message = Mail.new do
      text_part { body 'plain' }
      html_part do
        content_type 'text/html; charset=UTF-8'
        body html
      end
    end
    preview = Object.new
    preview.define_singleton_method(:call) { |_email| message }
    preview.define_singleton_method(:preview_name) { 'fake' }
    preview
  end
end
