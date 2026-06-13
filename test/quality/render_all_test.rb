# frozen_string_literal: true

require_relative 'quality_test_helper'
require 'tmpdir'
require 'mail'
require 'active_mail/quality/render_all'

class RenderAllTest < QualityTest
  CLEAN = <<~HTML.freeze
    <!DOCTYPE html>
    <html lang="en"><head></head><body>
      <table role="presentation"><tr><td>#{'x ' * 600}</td></tr></table>
    </body></html>
  HTML

  VIOLATING = '<html><body><img src="x.png"></body></html>'

  def build_preview(name, emails_to_html)
    preview = Object.new
    preview.define_singleton_method(:preview_name) { name }
    preview.define_singleton_method(:emails) { emails_to_html.keys.map(&:to_s) }
    preview.define_singleton_method(:call) do |email|
      html = emails_to_html.fetch(email.to_sym)
      raise 'boom' if html == :raise

      Mail.new do
        content_type 'text/html; charset=UTF-8'
        body html
      end
    end
    preview
  end

  def run_with_previews(previews, config)
    ActiveMail::Quality::PreviewRenderer.stub(:all, previews.flat_map { |p| p.emails.map { |e| [p, e] } }) do
      Dir.mktmpdir do |dir|
        return ActiveMail::Quality::RenderAll.new(output_root: dir, config: config).call
      end
    end
  end

  def test_renders_and_writes_clean_previews
    preview = build_preview('mailer', welcome: CLEAN)
    config = ActiveMail::Quality::Configuration.new
    result = run_with_previews([preview], config)

    assert_equal 1, result.rendered
    assert_empty result.render_failures
    assert_empty result.guard_failures
    assert_empty result.broken_required
  end

  def test_collects_guard_failures
    preview = build_preview('mailer', bad: VIOLATING)
    config = ActiveMail::Quality::Configuration.new
    result = run_with_previews([preview], config)

    assert_includes result.guard_failures.keys, 'mailer#bad'
    assert_empty result.broken_required
  end

  def test_collects_render_failures
    preview = build_preview('mailer', oops: :raise)
    config = ActiveMail::Quality::Configuration.new
    result = run_with_previews([preview], config)

    assert_equal 0, result.rendered
    assert_includes result.render_failures.keys, 'mailer#oops'
  end

  def test_required_guard_failure_marks_broken
    preview = build_preview('mailer', bad: VIOLATING)
    config = ActiveMail::Quality::Configuration.new
    config.required_previews = ['mailer#bad']
    result = run_with_previews([preview], config)

    assert_includes result.broken_required, 'mailer#bad'
  end

  def test_required_render_failure_marks_broken
    preview = build_preview('mailer', oops: :raise)
    config = ActiveMail::Quality::Configuration.new
    config.required_previews = ['mailer#oops']
    result = run_with_previews([preview], config)

    assert_includes result.broken_required, 'mailer#oops'
  end
end
