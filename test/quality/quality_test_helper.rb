# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'
require 'mail'
require 'activemail/quality'

I18n.enforce_available_locales = false

# Shared base for quality-layer tests: resets the module-level Quality.config so
# a test that calls ActiveMail::Quality.configure cannot pollute its siblings.
class QualityTest < Minitest::Test
  def setup
    @default_quality_config = ActiveMail::Quality.config
    ActiveMail::Quality.config = ActiveMail::Quality::Configuration.new
  end

  def teardown
    ActiveMail::Quality.config = @default_quality_config
  end

  private

  def build_mail(html:, text: 'plain', subject: 'Hello')
    Mail.new do
      subject subject
      text_part { body text } if text
      html_part do
        content_type 'text/html; charset=UTF-8'
        body html
      end
    end
  end
end
