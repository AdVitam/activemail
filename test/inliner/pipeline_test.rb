# frozen_string_literal: true

require 'test_helper'
require 'activemail/pipeline'

class PipelineTest < ActiveMailTest
  class ExplodingInliner < ActiveMail::Inliner::Base
    def inline(_html)
      raise ArgumentError, 'boom'
    end
  end

  class RaisingInlinerError < ActiveMail::Inliner::Base
    def inline(_html)
      raise ActiveMail::Inliner::Error, 'already wrapped'
    end
  end

  HTML = '<style>.x{color:red}</style><row class="x"><columns>hi</columns></row>'

  def test_transpiles_then_inlines
    output = ActiveMail::Pipeline.call(HTML)

    assert_includes output, 'role="presentation"'
    assert_match(/<table[^>]*style="[^"]*color:\s*red/i, output)
  end

  def test_null_inliner_transpiles_without_inlining
    ActiveMail.configuration.inliner = :null

    output = ActiveMail::Pipeline.call(HTML)

    assert_includes output, 'role="presentation"'
    assert_includes output, '<style>.x{color:red}</style>'
    refute_match(/style="[^"]*color:\s*red/i, output)
  end

  def test_inliner_failure_is_raised_with_inliner_name_and_cause
    ActiveMail.configuration.inliner = ExplodingInliner

    error = assert_raises(ActiveMail::Inliner::Error) { ActiveMail::Pipeline.call(HTML) }

    assert_includes error.message, 'ExplodingInliner'
    assert_includes error.message, 'CSS inlining failed: boom'
    assert_instance_of ArgumentError, error.cause
  end

  def test_inliner_error_is_not_wrapped_twice
    ActiveMail.configuration.inliner = RaisingInlinerError

    error = assert_raises(ActiveMail::Inliner::Error) { ActiveMail::Pipeline.call(HTML) }

    assert_equal 'already wrapped', error.message
  end

  def test_reads_the_configuration_at_call_time
    ActiveMail.configuration.inliner = :null
    first = ActiveMail::Pipeline.call(HTML)
    ActiveMail.configuration.inliner = :premailer
    second = ActiveMail::Pipeline.call(HTML)

    refute_equal first, second
  end

  def test_explicit_config_overrides_the_global_one
    config = ActiveMail::Configuration.new
    config.inliner = :null

    assert_includes ActiveMail::Pipeline.call(HTML, config: config), '<style>.x{color:red}</style>'
  end
end
