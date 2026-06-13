# frozen_string_literal: true

require_relative 'quality_test_helper'
require 'mail'

class PreviewRendererTest < QualityTest
  HTML_BODY = '<html lang="en"><body><p>hello</p></body></html>'

  # Minimal stand-in for an ActionMailer::Preview: #call returns a Mail::Message.
  class FakePreview
    def initialize(message)
      @message = message
    end

    def call(_email)
      @message
    end

    def preview_name
      'fake_mailer'
    end
  end

  def test_extracts_html_part_from_multipart_message
    message = Mail.new do
      text_part { body 'plain text' }
      html_part do
        content_type 'text/html; charset=UTF-8'
        body PreviewRendererTest::HTML_BODY
      end
    end

    html = ActiveMail::Quality::PreviewRenderer.html_body(message)

    assert_includes html, 'hello'
    refute_includes html, 'plain text'
  end

  def test_extracts_body_from_single_part_message
    message = Mail.new do
      content_type 'text/html; charset=UTF-8'
      body PreviewRendererTest::HTML_BODY
    end

    html = ActiveMail::Quality::PreviewRenderer.html_body(message)

    assert_includes html, 'hello'
  end

  def test_plain_text_only_message_yields_empty_html
    message = Mail.new do
      content_type 'text/plain; charset=UTF-8'
      body 'just plain text'
    end

    html = ActiveMail::Quality::PreviewRenderer.html_body(message)

    assert_empty html
  end

  def test_multipart_without_html_part_yields_empty_html
    message = Mail.new do
      text_part { body 'plain text only' }
    end

    html = ActiveMail::Quality::PreviewRenderer.html_body(message)

    assert_empty html
  end

  def test_render_calls_preview_and_extracts_html
    message = Mail.new do
      content_type 'text/html; charset=UTF-8'
      body PreviewRendererTest::HTML_BODY
    end

    html = ActiveMail::Quality::PreviewRenderer.render(FakePreview.new(message), 'welcome')

    assert_includes html, 'hello'
  end

  def test_render_to_disk_writes_file
    message = Mail.new do
      content_type 'text/html; charset=UTF-8'
      body PreviewRendererTest::HTML_BODY
    end

    Dir.mktmpdir do |dir|
      path = ActiveMail::Quality::PreviewRenderer.render_to_disk(FakePreview.new(message), 'welcome', dir)

      assert_path_exists path
      assert_equal 'welcome.html', path.basename.to_s
      assert_includes File.read(path), 'hello'
    end
  end

  def test_all_returns_empty_without_action_mailer_previews
    # No host Rails app / ActionMailer::Preview loaded in the gem test suite.
    refute defined?(ActionMailer::Preview), 'precondition: ActionMailer::Preview not loaded'
    assert_empty ActiveMail::Quality::PreviewRenderer.all
  end
end
