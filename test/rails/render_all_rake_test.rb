# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'
require 'tmpdir'
require 'rake'
require 'activemail/quality'

# The CI contract lives in the rake wrapper: abort (non-zero exit) when a
# required preview is broken. RenderAll is unit-tested; this guards the glue.
class RenderAllRakeTest < ActiveMailTest
  def setup
    super
    @saved_app = Rake.application
    Rake.application = Rake::Application.new
    Rake::Task.define_task(:environment)
    load File.expand_path('../../lib/tasks/activemail.rake', __dir__)
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
        assert_raises(SystemExit) { Rake::Task['activemail:emails:render_all'].invoke }
      end
    end
  end

  def test_does_not_abort_when_nothing_required_is_broken
    capture_io do
      stub_render_all(broken: []) do
        Rake::Task['activemail:emails:render_all'].invoke
      end
    end
  end

  def test_tokens_export_writes_the_scss_partial_creating_dirs
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'nested', '_tokens.scss')
      capture_io { Rake::Task['activemail:tokens:export'].invoke(path) }

      written = File.read(path)
      assert_includes written, '$am-color-primary:'
      assert_includes written, '$am-grid-container-width:' # must match the .scss.erb bridge
    end
  end
end
