# frozen_string_literal: true

require 'test_helper'
require 'fileutils'
require 'tmpdir'
# ActionView 7.1 references URI without requiring it (NameError on Ruby 3.3+ outside a full Rails app).
require 'uri'
require 'action_view'
require 'action_view/base'
require 'activemail/rails/template_handler'
require 'activemail/rails/compiled_stylesheet'
require File.expand_path('../../app/helpers/active_mail/styles_helper', __dir__)
require 'rails/generators'
require 'rails/generators/test_case'

require 'generators/activemail/install_generator'
require 'generators/activemail/views_generator'
require 'generators/activemail/styles_generator'
require 'generators/activemail/component_generator'

module ActiveMailGeneratorTestHelpers
  def file_content(relative)
    File.read(File.join(destination_root, relative))
  end

  def assert_generated(relative)
    assert File.exist?(File.join(destination_root, relative)), "expected #{relative} to be generated"
  end
end

class InstallGeneratorTest < Rails::Generators::TestCase
  include ActiveMailGeneratorTestHelpers

  tests ActiveMail::Generators::InstallGenerator
  destination File.join(Dir.tmpdir, 'activemail_install')
  setup :prepare_destination

  def test_creates_initializer_and_layout
    run_generator

    assert_generated 'config/initializers/activemail.rb'
    assert_generated 'app/views/layouts/mailer.html.inky-erb'

    assert_includes file_content('config/initializers/activemail.rb'), 'ActiveMail.configure do |config|'
    assert_includes file_content('app/views/layouts/mailer.html.inky-erb'), 'stylesheet_link_tag "activemail/activemail"'
    assert_includes file_content('app/views/layouts/mailer.html.inky-erb'), 'activemail_inline_styles'
    assert_includes file_content('app/views/layouts/mailer.html.inky-erb'), '<container>'
  end

  def test_does_not_create_a_host_stylesheet_entry
    run_generator

    refute File.exist?(File.join(destination_root, 'app/assets/stylesheets/activemail.scss'))
  end

  def test_haml_option_generates_haml_layout
    run_generator ['mailer', '--haml']

    assert_generated 'app/views/layouts/mailer.html.inky-haml'
    assert_includes file_content('app/views/layouts/mailer.html.inky-haml'), 'stylesheet_link_tag "activemail/activemail"'
  end

  def test_slim_option_generates_slim_layout
    run_generator ['mailer', '--slim']

    assert_generated 'app/views/layouts/mailer.html.inky-slim'
  end

  def test_preserves_an_existing_plain_mailer_layout
    layouts = seed_existing_layout

    run_generator

    preserved = Dir.glob(File.join(layouts, 'old_mailer_*.html.erb'))
    assert_equal 1, preserved.size
    assert_equal 'OLD', File.read(preserved.first)
  end

  def test_does_not_preserve_for_a_non_mailer_layout_name
    layouts = seed_existing_layout

    run_generator ['newsletter']

    assert_empty Dir.glob(File.join(layouts, 'old_mailer_*.html.erb'))
    assert_path_exists File.join(layouts, 'mailer.html.erb')
  end

  def test_does_not_preserve_when_haml_requested
    layouts = seed_existing_layout

    run_generator ['mailer', '--haml']

    assert_empty Dir.glob(File.join(layouts, 'old_mailer_*.html.erb'))
    assert_path_exists File.join(layouts, 'mailer.html.erb')
  end

  private

  def seed_existing_layout
    layouts = File.join(destination_root, 'app', 'views', 'layouts')
    FileUtils.mkdir_p(layouts)
    File.write(File.join(layouts, 'mailer.html.erb'), 'OLD')
    layouts
  end
end

class ViewsGeneratorTest < Rails::Generators::TestCase
  include ActiveMailGeneratorTestHelpers

  tests ActiveMail::Generators::ViewsGenerator
  destination File.join(Dir.tmpdir, 'activemail_views')
  setup :prepare_destination

  def test_ejects_default_layout_and_partials
    run_generator

    assert_generated 'app/views/layouts/activemail/mailer.html.inky-erb'
    assert_generated 'app/views/layouts/activemail/_head.html.inky-erb'
    assert_generated 'app/views/layouts/activemail/_footer.html.inky-erb'
  end
end

class StylesGeneratorTest < Rails::Generators::TestCase
  include ActiveMailGeneratorTestHelpers

  tests ActiveMail::Generators::StylesGenerator
  destination File.join(Dir.tmpdir, 'activemail_styles')
  setup :prepare_destination

  def test_ejects_framework_scss_partials
    run_generator

    assert_generated 'app/assets/stylesheets/activemail/activemail.scss'
    assert_generated 'app/assets/stylesheets/activemail/_grid.scss'
    assert_generated 'app/assets/stylesheets/activemail/_components.scss'
  end

  def test_does_not_eject_the_erb_token_bridge
    run_generator

    refute File.exist?(File.join(destination_root, 'app/assets/stylesheets/activemail/_activemail_tokens.scss.erb'))
  end
end

class EngineDefaultLayoutTest < ActiveMailTest
  ENGINE_VIEWS = File.expand_path('../../app/views', __dir__)

  def test_default_layout_renders_head_and_footer_partials
    Dir.mktmpdir do |dir|
      views = File.join(dir, 'views')
      FileUtils.mkdir_p(File.join(views, 'mailers'))
      # Engine layout/partials live alongside a throwaway body template.
      FileUtils.cp_r(File.join(ENGINE_VIEWS, 'layouts'), views)
      File.write(File.join(views, 'mailers', 'sample.html.inky-erb'), '<row><columns>BODY_CONTENT</columns></row>')

      lookup = ActionView::LookupContext.new([views])
      view = ActionView::Base.with_empty_template_cache.new(lookup, {}, nil)
      view.define_singleton_method(:stylesheet_link_tag) { |*| '' }
      # A real app auto-includes the engine's app/helpers into mailer views.
      view.extend(ActiveMail::StylesHelper)

      html = view.render(template: 'mailers/sample', layout: 'layouts/activemail/mailer')

      assert_includes html, 'BODY_CONTENT'
      # _head emits a <spacer size="24">, _footer an <h-line>; both expand to tables.
      assert_includes html, 'class="spacer"'
      assert_includes html, 'class="h-line"'
      assert_includes html, 'height="24"'
      assert_includes html, 'class="container"'
    end
  end
end

class ComponentGeneratorTest < Rails::Generators::TestCase
  include ActiveMailGeneratorTestHelpers

  tests ActiveMail::Generators::ComponentGenerator
  destination File.join(Dir.tmpdir, 'activemail_component')
  setup :prepare_destination

  def test_scaffolds_a_component_class
    output = run_generator ['Cta']

    assert_generated 'app/mailers/components/cta.rb'
    content = file_content('app/mailers/components/cta.rb')
    assert_includes content, 'class Cta < ActiveMail::Components::Base'
    assert_includes content, 'def transform(node, inner)'
    assert_includes content, '# typed: false'
    refute_includes content, 'extend T::Sig'
    assert_includes output, 'config.register_component "cta", Components::Cta'
  end

  def test_multiword_name_kebab_cases_the_tag
    run_generator ['SocialLinks']

    content = file_content('app/mailers/components/social_links.rb')
    assert_includes content, 'config.register_component "social-links", Components::SocialLinks'
    assert_includes content, 'combine_classes(node, "social-links")'
  end
end
