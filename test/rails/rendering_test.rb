# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'
# ActionView 7.1 references URI without requiring it (NameError on Ruby 3.3+ outside a full Rails app).
require 'uri'
require 'action_mailer'
require 'activemail/rails/template_handler'
require 'activemail/rails/rendering'

class RenderingTest < ActiveMailTest
  class FixtureMailer < ActionMailer::Base
    prepend ActiveMail::Rails::Rendering::MailerExtension

    self.mailer_name = 'fixture_mailer'

    layout 'mailer'
    default from: 'from@example.com', to: 'to@example.com'

    def welcome
      mail(subject: 'Welcome')
    end

    def text_only
      mail(subject: 'Text')
    end

    def plain
      mail(subject: 'Plain') { |format| format.html { render html: '<row><columns>x</columns></row>'.html_safe, layout: false } }
    end
  end

  VIEWS = {
    'layouts/mailer.html.inky-erb' => '<html><head><style>.am{color:red}</style></head><body><container><%= yield %></container></body></html>',
    'fixture_mailer/welcome.html.inky-erb' => '<row><columns><raw><button href="#">x</button></raw><p class="am">hi</p></columns></row>',
    'fixture_mailer/welcome.text.erb' => 'plain text <row>',
    'fixture_mailer/text_only.text.inky-erb' => '<row><columns>text</columns></row>'
  }.freeze

  def setup
    super
    @dir = Dir.mktmpdir
    VIEWS.each do |path, content|
      full = File.join(@dir, path)
      FileUtils.mkdir_p(File.dirname(full))
      File.write(full, content)
    end
    FixtureMailer.view_paths = [@dir]
    @transpiles = count_transpiles
  end

  def teardown
    FileUtils.rm_rf(@dir)
    super
  end

  def test_html_part_is_transpiled_and_inlined_once
    html = FixtureMailer.welcome.message.html_part.body.decoded

    assert_equal 1, @transpiles.call
    assert_includes html, 'role="presentation"'
    assert_match(/<p[^>]*style="[^"]*color:\s*red/i, html)
  end

  def test_raw_content_survives_the_layout
    html = FixtureMailer.welcome.message.html_part.body.decoded

    assert_includes html, '<button href="#">x</button>'
  end

  def test_text_part_is_left_untouched
    assert_equal 'plain text <row>', FixtureMailer.welcome.message.text_part.body.decoded
  end

  def test_inky_text_template_is_not_transpiled
    assert_equal '<row><columns>text</columns></row>', FixtureMailer.text_only.message.body.decoded
    assert_equal 0, @transpiles.call
  end

  def test_non_inky_html_mail_is_left_untouched
    assert_equal '<row><columns>x</columns></row>', FixtureMailer.plain.message.body.decoded
    assert_equal 0, @transpiles.call
  end

  def test_null_inliner_transpiles_without_inlining
    ActiveMail.configuration.inliner = :null

    html = FixtureMailer.welcome.message.html_part.body.decoded

    assert_includes html, '<style>.am{color:red}</style>'
    refute_match(/style="[^"]*color:\s*red/i, html)
  end

  def test_process_transpiles_immediately_outside_a_mailer_scope
    assert_includes ActiveMail::Rails::Rendering.process('<row></row>', :html), 'role="presentation"'
  end

  def test_process_passes_output_through_inside_a_scope
    ActiveMail::Rails::Rendering.scoped do
      assert_equal '<row></row>', ActiveMail::Rails::Rendering.process('<row></row>', :text)
    end
  end

  def test_nested_scopes_run_the_pipeline_once_at_the_outermost_exit
    body = ActiveMail::Rails::Rendering.scoped do
      inner = ActiveMail::Rails::Rendering.scoped { ActiveMail::Rails::Rendering.process('<row></row>', :html) }

      assert_equal '<row></row>', inner
      inner
    end

    assert_includes body, 'role="presentation"'
  end

  def test_scope_is_closed_when_the_block_raises
    assert_raises(RuntimeError) { ActiveMail::Rails::Rendering.scoped { raise 'boom' } }

    assert_includes ActiveMail::Rails::Rendering.process('<row></row>', :html), 'role="presentation"'
  end

  private

  def count_transpiles
    count = 0
    ActiveMail.configuration.core.singleton_class.prepend(
      Module.new do
        define_method(:transpile) do |html|
          count += 1
          super(html)
        end
      end
    )
    -> { count }
  end
end
