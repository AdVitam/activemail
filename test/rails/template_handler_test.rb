# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'
# ActionView 7.1 references URI without requiring it (NameError on Ruby 3.3+ outside a full Rails app).
require 'uri'
require 'action_view'
require 'action_view/base'
require 'inky/rails/template_handler'

class TemplateHandlerTest < InkyTest
  def test_inky_handler_is_registered
    handler = ActionView::Template.registered_template_handler(:inky)

    assert_instance_of Inky::Rails::TemplateHandler, handler
  end

  def test_composed_handlers_are_registered_for_existing_engines
    handler = ActionView::Template.registered_template_handler(:'inky-erb')

    assert_instance_of Inky::Rails::TemplateHandler, handler
  end

  def test_call_wraps_the_underlying_engine_output_with_inky
    handler = ActionView::Template.registered_template_handler(:inky)
    template = ActionView::Template.new('<container></container>', 'test', handler, locals: [], format: :html)
    compiled = handler.call(template, '<container></container>')

    assert_includes compiled, 'Inky::Core.new.release_the_kraken'
  end

  def test_engine_handler_raises_for_unknown_engine
    Inky.configuration.template_engine = :does_not_exist
    handler = Inky::Rails::TemplateHandler.new

    assert_raises(RuntimeError) { handler.engine_handler }
  end

  def test_renders_an_inky_template_through_action_view
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'mail.html.inky'), "<container><row><columns><%= 'Hello' %></columns></row></container>")
      lookup = ActionView::LookupContext.new([dir])
      view = ActionView::Base.with_empty_template_cache.new(lookup, {}, nil)
      html = view.render(template: 'mail')

      assert_includes html, 'class="container"'
      assert_includes html, 'Hello'
      assert_includes html, 'role="presentation"'
    end
  end

  def test_output_is_html_safe_when_active_support_is_loaded
    output = Inky::Core.new.release_the_kraken('<row></row>')

    assert_predicate output, :html_safe?
  end
end
