# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'
require 'rake'
require 'active_mail/quality'

# The CI contract lives in the rake wrapper: abort (non-zero exit) when a
# required preview is broken. RenderAll is unit-tested; this guards the glue.
class RenderAllRakeTest < ActiveMailTest
  def setup
    super
    @saved_app = Rake.application
    Rake.application = Rake::Application.new
    Rake::Task.define_task(:environment)
    load File.expand_path('../../lib/tasks/active_mail.rake', __dir__)
  end

  def teardown
    Rake.application = @saved_app
    super
  end

  def stub_render_all(broken:, &)
    result = ActiveMail::Quality::RenderAll::Result.new(
      discovered: 1, rendered: 0, render_failures: {}, guard_failures: {}, broken_required: broken
    )
    runner = Object.new
    runner.define_singleton_method(:call) { result }
    # Return runner from .new via a lambda so minitest doesn't treat runner (which
    # responds to :call) as the callable and invoke it with new's kwargs.
    ActiveMail::Quality::RenderAll.stub(:new, ->(*_args, **_kwargs) { runner }, &)
  end

  def test_aborts_when_a_required_preview_is_broken
    capture_io do
      stub_render_all(broken: ['mailer#welcome']) do
        assert_raises(SystemExit) { Rake::Task['active_mail:emails:render_all'].invoke }
      end
    end
  end

  def test_does_not_abort_when_nothing_required_is_broken
    capture_io do
      stub_render_all(broken: []) do
        Rake::Task['active_mail:emails:render_all'].invoke
      end
    end
  end
end
