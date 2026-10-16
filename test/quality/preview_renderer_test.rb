# frozen_string_literal: true

require_relative 'quality_test_helper'
require 'mail'
require 'action_mailer'
require 'i18n'

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

  def test_key_builds_the_preview_name_hash_email_format
    preview = FakePreview.new(Mail.new)

    assert_equal 'fake_mailer#welcome', ActiveMail::Quality::PreviewRenderer.key(preview, 'welcome')
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

  def test_declined_detects_empty_and_null_mail
    null_mail = ActionMailer::Base::NullMail.new

    assert ActiveMail::Quality::PreviewRenderer.declined?(null_mail)
    assert ActiveMail::Quality::PreviewRenderer.declined?(Mail.new)
    refute ActiveMail::Quality::PreviewRenderer.declined?(Mail.new { body 'x' })
  end

  def test_mail_keeps_a_null_mail_whose_message_is_nil
    null_mail = ActionMailer::Base::NullMail.new

    assert_same null_mail, ActiveMail::Quality::PreviewRenderer.mail(null_mail)
    assert ActiveMail::Quality::PreviewRenderer.declined?(ActiveMail::Quality::PreviewRenderer.mail(null_mail))
  end

  def test_cases_expands_previews_by_locale
    config = ActiveMail::Quality::Configuration.new
    config.locales = %i[en fr]
    preview = FakePreview.new(Mail.new)

    cases = ActiveMail::Quality::PreviewRenderer.cases(config, [[preview, 'welcome']])

    assert_equal [[preview, 'welcome', :en], [preview, 'welcome', :fr]], cases
  end

  def test_text_body_reads_the_text_part
    message = Mail.new do
      text_part { body 'plain text' }
      html_part do
        content_type 'text/html; charset=UTF-8'
        body PreviewRendererTest::HTML_BODY
      end
    end

    assert_equal 'plain text', ActiveMail::Quality::PreviewRenderer.text_body(message)
  end

  def test_text_body_is_empty_for_html_only_message
    message = Mail.new do
      content_type 'text/html; charset=UTF-8'
      body PreviewRendererTest::HTML_BODY
    end

    assert_empty ActiveMail::Quality::PreviewRenderer.text_body(message)
  end

  def test_within_yields_the_mail_under_the_locale
    message = Mail.new { body 'x' }
    seen = ActiveMail::Quality::PreviewRenderer.within(FakePreview.new(message), 'welcome', :fr, nil) do |mail|
      [mail, I18n.locale]
    end

    assert_equal [message, :fr], seen
  end

  def test_within_wraps_the_block_in_around_each
    calls = []
    around = lambda do |preview, email, locale, &block|
      calls << [preview.preview_name, email, locale]
      block.call
    end
    ActiveMail::Quality::PreviewRenderer.within(FakePreview.new(Mail.new), 'welcome', :en, around) { :ok }

    assert_equal [['fake_mailer', 'welcome', :en]], calls
  end

  def test_within_rejects_an_around_each_that_never_yields
    around = ->(_preview, _email, _locale, &_block) {}

    assert_raises(ArgumentError) do
      ActiveMail::Quality::PreviewRenderer.within(FakePreview.new(Mail.new), 'welcome', :en, around) { :ok }
    end
  end

  def test_all_returns_empty_when_no_preview_is_defined
    require 'action_mailer'
    ActionMailer::Preview.stub(:all, []) { assert_empty ActiveMail::Quality::PreviewRenderer.all }
  end
end
