# frozen_string_literal: true

require 'test_helper'
require_relative 'support/dummy_runner'

class SprocketsIntegrationTest < Minitest::Test
  include DummyAppAssertions

  def test_compiles_and_inlines_from_the_live_environment
    Dir.mktmpdir do |dir|
      result = DummyRunner.run('dummy_sprockets', 'ACTIVEMAIL_ASSETS_DIR' => dir)

      assert_equal 'ActiveMail::AssetPipeline::Sprockets', result['pipeline']
      assert_inlined_single_pass_mail(result)
      assert_untouched_and_failing_cases(result)
    end
  end

  def test_inlines_from_the_precompiled_manifest
    Dir.mktmpdir do |dir|
      DummyRunner.run('dummy_sprockets', 'ACTIVEMAIL_ASSETS_DIR' => dir, 'ACTIVEMAIL_PRECOMPILE_ONLY' => '1')
      result = DummyRunner.run('dummy_sprockets', 'ACTIVEMAIL_ASSETS_DIR' => dir, 'ACTIVEMAIL_PRECOMPILED' => '1')

      assert_inlined_single_pass_mail(result)
    end
  end
end
