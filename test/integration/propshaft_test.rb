# frozen_string_literal: true

require 'test_helper'
require 'fileutils'
require_relative 'support/dummy_runner'
require_relative '../support/scss_compiler'

# Propshaft does not preprocess SCSS: the stylesheet is compiled before boot, as `dartsass:build` would.
class PropshaftIntegrationTest < Minitest::Test
  include DummyAppAssertions

  def test_boots_and_inlines_from_the_load_path
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, 'activemail'))
      File.write(File.join(dir, 'activemail', 'activemail.css'), ScssCompiler.compile)

      result = DummyRunner.run('dummy_propshaft', 'ACTIVEMAIL_ASSETS_DIR' => dir)

      assert_equal 'ActiveMail::AssetPipeline::Propshaft', result['pipeline']
      assert_inlined_single_pass_mail(result)
      assert_untouched_and_failing_cases(result)
    end
  end
end
