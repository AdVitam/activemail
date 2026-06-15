# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'
require 'activemail/quality'

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
end
