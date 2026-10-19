# frozen_string_literal: true

require_relative 'quality_test_helper'
require 'tmpdir'
require 'mail'
require 'action_mailer'
require 'activemail/quality/render_all'

class RenderAllTest < QualityTest
  CLEAN = <<~HTML.freeze
    <!DOCTYPE html>
    <html lang="en"><head><title>Welcome</title></head><body>
      <table role="presentation"><tr><td>#{'x ' * 600}</td></tr></table>
    </body></html>
  HTML

  VIOLATING = '<html><body><img src="x.png"></body></html>'

  # emails_to_html: { email_sym => html String | :raise | :declined }. Records the locale each call ran under.
  def build_preview(name, calls: [], **emails_to_html)
    preview = Object.new
    preview.define_singleton_method(:preview_name) { name }
    preview.define_singleton_method(:emails) { emails_to_html.keys.map(&:to_s) }
    preview.define_singleton_method(:call) do |email, params = {}|
      calls << [email, I18n.locale, params[:locale]]
      html = emails_to_html.fetch(email.to_sym)
      raise 'boom' if html == :raise
      next ActionMailer::Base::NullMail.new if html == :declined

      Mail.new do
        text_part { body "text of #{email}" }
        html_part do
          content_type 'text/html; charset=UTF-8'
          body html
        end
      end
    end
    preview
  end

  def run_with_previews(previews, config)
    ActiveMail::Quality::PreviewRenderer.stub(:all, previews.flat_map { |p| p.emails.map { |e| [p, e] } }) do
      Dir.mktmpdir do |dir|
        result = ActiveMail::Quality::RenderAll.new(root: dir, config: config).call
        @written = Dir.glob('**/*', base: result.output_root.to_s).select { |f| File.file?(File.join(result.output_root, f)) }.sort
        @contents = @written.to_h { |f| [f, File.read(File.join(result.output_root, f))] }
        return result
      end
    end
  end

  def test_reports_discovered_count
    preview = build_preview('mailer', welcome: CLEAN, goodbye: CLEAN)
    result = run_with_previews([preview], ActiveMail::Quality::Configuration.new)

    assert_equal 2, result.discovered
  end

  def test_discovered_is_zero_when_no_previews
    result = run_with_previews([], ActiveMail::Quality::Configuration.new)

    assert_equal 0, result.discovered
    assert_equal 0, result.rendered
  end

  def test_renders_and_writes_html_and_text
    preview = build_preview('mailer', welcome: CLEAN)
    result = run_with_previews([preview], ActiveMail::Quality::Configuration.new)

    assert_equal 1, result.rendered
    assert_empty result.render_failures
    assert_empty result.guard_failures
    assert_empty result.broken_required
    assert_equal %w[mailer/welcome.html mailer/welcome.txt], @written
    assert_equal 'text of welcome', @contents['mailer/welcome.txt']
  end

  def test_declined_send_fails_unless_allowed_and_writes_no_files
    preview = build_preview('mailer', skipped: :declined)
    result = run_with_previews([preview], ActiveMail::Quality::Configuration.new)

    assert_equal 1, result.rendered
    assert_empty result.render_failures
    assert_equal [:declined], result.guard_failures['mailer#skipped'].map(&:rule)
    assert_empty @written
  end

  def test_allowed_declined_send_is_rendered_without_files_or_failures
    config = ActiveMail::Quality::Configuration.new
    config.allow_declined = ['mailer#skipped']
    result = run_with_previews([build_preview('mailer', skipped: :declined)], config)

    assert_equal 1, result.rendered
    assert_empty result.guard_failures
    assert_empty @written
  end

  def test_collects_guard_failures
    preview = build_preview('mailer', bad: VIOLATING)
    result = run_with_previews([preview], ActiveMail::Quality::Configuration.new)

    assert_includes result.guard_failures.keys, 'mailer#bad'
    assert_empty result.broken_required
  end

  def test_guard_checks_message_level_rules
    preview = Object.new
    preview.define_singleton_method(:preview_name) { 'mailer' }
    preview.define_singleton_method(:emails) { ['notext'] }
    preview.define_singleton_method(:call) do |_email, _params = {}|
      Mail.new do
        content_type 'text/html; charset=UTF-8'
        body CLEAN
      end
    end
    result = run_with_previews([preview], ActiveMail::Quality::Configuration.new)

    assert_includes result.guard_failures['mailer#notext'].map(&:rule), :text_part_present
  end

  def test_guard_receives_the_rendered_message_not_disk_content
    seen = []
    rule = ActiveMail::Quality::Rule.html(:spy) { |_doc, html| (seen << html) && nil }
    config = ActiveMail::Quality::Configuration.new
    config.guard = ActiveMail::Quality::Guard.new(rules: [rule])
    config.output_filters = [[/x/, 'MASKED']]
    run_with_previews([build_preview('mailer', welcome: CLEAN)], config)

    assert_equal [CLEAN], seen
    refute_includes @contents['mailer/welcome.html'], 'x '
  end

  def test_collects_render_failures
    preview = build_preview('mailer', oops: :raise)
    result = run_with_previews([preview], ActiveMail::Quality::Configuration.new)

    assert_equal 0, result.rendered
    assert_includes result.render_failures.keys, 'mailer#oops'
  end

  def test_required_guard_failure_marks_broken
    config = ActiveMail::Quality::Configuration.new
    config.required_previews = ['mailer#bad']
    result = run_with_previews([build_preview('mailer', bad: VIOLATING)], config)

    assert_includes result.broken_required, 'mailer#bad'
  end

  def test_required_render_failure_marks_broken
    config = ActiveMail::Quality::Configuration.new
    config.required_previews = ['mailer#oops']
    result = run_with_previews([build_preview('mailer', oops: :raise)], config)

    assert_includes result.broken_required, 'mailer#oops'
  end

  def test_required_preview_never_discovered_marks_broken
    config = ActiveMail::Quality::Configuration.new
    config.required_previews = ['mailer#ghost']
    result = run_with_previews([build_preview('mailer', welcome: CLEAN)], config)

    assert_includes result.broken_required, 'mailer#ghost'
  end

  def test_locales_list_renders_each_locale_and_suffixes_non_default_ones
    calls = []
    config = ActiveMail::Quality::Configuration.new
    config.locales = [I18n.default_locale, :fr]
    result = run_with_previews([build_preview('mailer', welcome: CLEAN, calls: calls)], config)

    assert_equal 2, result.rendered
    assert_equal [['welcome', I18n.default_locale, I18n.default_locale], ['welcome', :fr, :fr]], calls
    assert_equal %w[mailer/welcome.fr.html mailer/welcome.fr.txt mailer/welcome.html mailer/welcome.txt], @written
  end

  def test_locales_proc_receives_the_preview
    config = ActiveMail::Quality::Configuration.new
    config.locales = ->(preview) { preview.preview_name == 'multi' ? %i[fr de] : [:fr] }
    result = run_with_previews([build_preview('multi', a: CLEAN), build_preview('single', a: CLEAN)], config)

    assert_equal 3, result.rendered
  end

  def test_failure_in_a_secondary_locale_is_labelled_and_breaks_the_required_key
    config = ActiveMail::Quality::Configuration.new
    config.locales = [I18n.default_locale, :fr]
    config.required_previews = ['mailer#welcome']
    preview = build_preview('mailer', welcome: CLEAN)
    preview.define_singleton_method(:call) do |_email, _params = {}|
      raise 'fr only' if I18n.locale == :fr

      Mail.new { body 'x' }
    end
    result = run_with_previews([preview], config)

    assert_equal ['mailer#welcome [fr]'], result.render_failures.keys
    assert_equal ['mailer#welcome'], result.broken_required
  end

  def test_formats_limit_the_written_files
    config = ActiveMail::Quality::Configuration.new
    config.formats = [:text]
    run_with_previews([build_preview('mailer', welcome: CLEAN)], config)

    assert_equal ['mailer/welcome.txt'], @written
  end

  def test_around_each_wraps_each_rendering_once
    events = []
    config = ActiveMail::Quality::Configuration.new
    config.locales = [I18n.default_locale, :fr]
    config.around_each = lambda do |preview, email, locale, &block|
      events << [:before, preview.preview_name, email, locale]
      block.call
      events << :after
    end
    calls = []
    run_with_previews([build_preview('mailer', welcome: CLEAN, calls: calls)], config)

    assert_equal 2, events.grep(Array).size
    assert_equal 2, events.count(:after)
    assert_equal 2, calls.size, 'each preview is rendered exactly once per locale'
  end

  def test_around_each_that_does_not_yield_is_a_render_failure
    config = ActiveMail::Quality::Configuration.new
    config.around_each = ->(_preview, _email, _locale, &_block) {}
    result = run_with_previews([build_preview('mailer', welcome: CLEAN)], config)

    assert_includes result.render_failures.keys, 'mailer#welcome'
  end

  def test_output_filters_apply_to_files_but_not_to_the_guard
    config = ActiveMail::Quality::Configuration.new
    config.output_filters = [[/text of/, 'TEXT:'], ->(content) { content.sub('welcome', 'masked') }]
    result = run_with_previews([build_preview('mailer', welcome: CLEAN)], config)

    assert_equal 'TEXT: masked', @contents['mailer/welcome.txt']
    assert_empty result.guard_failures
  end

  def run_in(root, dir: 'out')
    config = ActiveMail::Quality::Configuration.new
    config.output_dir = dir
    ActiveMail::Quality::PreviewRenderer.stub(:all, []) do
      ActiveMail::Quality::RenderAll.new(root: root, config: config).call
    end
  end

  def test_second_run_removes_its_own_files_and_keeps_foreign_ones
    Dir.mktmpdir do |root|
      run_in(root)
      out = File.join(root, 'out')
      FileUtils.mkdir_p(File.join(out, 'old'))
      File.write(File.join(out, 'old', 'stale.html'), 'stale')
      File.write(File.join(out, 'notes.md'), 'keep')
      File.write(File.join(out, 'old', 'keep.json'), 'keep')

      run_in(root)

      refute_path_exists File.join(out, 'old', 'stale.html')
      assert_equal 'keep', File.read(File.join(out, 'notes.md'))
      assert_equal 'keep', File.read(File.join(out, 'old', 'keep.json'))
      assert_path_exists File.join(out, ActiveMail::Quality::RenderAll::MARKER)
    end
  end

  def test_refuses_a_non_empty_directory_without_marker
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p(File.join(root, 'public'))
      File.write(File.join(root, 'public', '404.html'), 'precious')

      error = assert_raises(ArgumentError) { run_in(root, dir: 'public') }

      assert_includes error.message, ActiveMail::Quality::RenderAll::MARKER
      assert_equal 'precious', File.read(File.join(root, 'public', '404.html'))
    end
  end

  def test_accepts_an_existing_empty_directory
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p(File.join(root, 'out'))

      run_in(root)

      assert_path_exists File.join(root, 'out', ActiveMail::Quality::RenderAll::MARKER)
    end
  end

  def test_refuses_a_symlink_escaping_the_root
    Dir.mktmpdir do |root|
      Dir.mktmpdir do |outside|
        File.write(File.join(outside, '404.html'), 'precious')
        FileUtils.mkdir_p(File.join(root, 'tmp'))
        File.symlink(outside, File.join(root, 'tmp', 'x'))

        assert_raises(ArgumentError) { run_in(root, dir: 'tmp/x') }
        assert_raises(ArgumentError) { run_in(root, dir: 'tmp/x/sub') }
        assert_equal 'precious', File.read(File.join(outside, '404.html'))
      end
    end
  end

  def test_empty_preview_directories_are_pruned
    Dir.mktmpdir do |root|
      run_in(root)
      FileUtils.mkdir_p(File.join(root, 'out/gone/deeper'))
      File.write(File.join(root, 'out/gone/deeper/a.txt'), 'x')

      run_in(root)

      assert_path_exists File.join(root, 'out')
      refute_path_exists File.join(root, 'out/gone')
    end
  end

  def test_refuses_an_output_dir_outside_the_root
    Dir.mktmpdir do |root|
      config = ActiveMail::Quality::Configuration.new
      # Bypass the setter: RenderAll must defend itself even against a hand-built config.
      config.instance_variable_set(:@output_dir, '../escape')

      assert_raises(ArgumentError) { ActiveMail::Quality::RenderAll.new(root: root, config: config) }
    end
  end

  def test_refuses_the_root_itself_and_absolute_paths
    Dir.mktmpdir do |root|
      ['.', '/tmp/x', 'a/../..', ''].each do |dir|
        config = ActiveMail::Quality::Configuration.new
        config.instance_variable_set(:@output_dir, dir)

        assert_raises(ArgumentError, dir) { ActiveMail::Quality::RenderAll.new(root: root, config: config) }
      end
    end
  end
end
