# frozen_string_literal: true

require_relative 'quality_test_helper'
require 'activemail/quality/minitest'

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
