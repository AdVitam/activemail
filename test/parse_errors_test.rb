# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'

class ParseErrorsTest < ActiveMailTest
  def test_default_mode_is_warn
    assert_equal :warn, ActiveMail::Configuration.new.on_parse_error
  end

  def test_setter_rejects_unknown_mode
    assert_raises(ArgumentError) { ActiveMail.configuration.on_parse_error = :explode }
  end

  def test_valid_markup_with_every_builtin_tag_is_silent
    input = '<container><row><columns>One</columns></row><spacer size="10"></spacer>' \
            '<h-line></h-line><block-grid up="2"></block-grid><menu><item href="#">I</item></menu>' \
            '<callout>C</callout><wrapper>W</wrapper><button href="#">B</button></container>'

    assert_silent { render(input) }
  end

  def test_component_markup_repeating_a_node_id_is_silent
    assert_silent { render('<container id="c"><cta href="#" id="z">Go</cta><spacer id="s" size-sm="2" size-lg="3"></spacer></container>') }
  end

  def test_duplicate_author_ids_still_warn
    assert_output(nil, /\S/) { render('<p id="a">x</p><p id="a">y</p>') }
  end

  def test_registered_custom_tag_is_silent
    ActiveMail.configuration.register_component('my-box', CustomComponent)

    assert_silent { render('<my-box>hi</my-box>') }
  end

  def test_unregistered_unknown_tag_warns
    assert_output(nil, /\S/) { render('<my-widget>x</my-widget>') }
  end

  def test_malformed_markup_warns_by_default
    assert_output(nil, /\S/) { render('<container><b><i>x</b></i></container>') }
  end

  def test_raise_mode_raises_parse_error
    ActiveMail.configuration.on_parse_error = :raise

    assert_raises(ActiveMail::ParseError) { render('<container><b><i>x</b></i></container>') }
  end

  def test_raise_mode_does_not_raise_on_valid_inky_markup
    ActiveMail.configuration.on_parse_error = :raise

    assert_includes render('<row><columns>One</columns></row>'), 'class="row"'
  end

  def test_ignore_mode_is_silent_on_malformed_markup
    ActiveMail.configuration.on_parse_error = :ignore

    assert_silent { render('<container><b><i>x</b></i></container>') }
  end

  def test_raise_mode_names_the_unknown_tag
    ActiveMail.configuration.on_parse_error = :raise

    error = assert_raises(ActiveMail::ParseError) { render('<row><colums>x</colums></row>') }

    assert_includes error.message, 'unknown tag <colums>'
  end

  def test_html5_section_tag_warns
    assert_output(nil, /unknown tag <section>/) { render('<section>x</section>') }
  end

  def test_unknown_tag_inside_raw_is_silent
    assert_silent { render('<raw><my-widget>x</my-widget></raw>') }
  end

  def test_repeated_unknown_tag_is_reported_once
    ActiveMail.configuration.on_parse_error = :raise

    error = assert_raises(ActiveMail::ParseError) { render('<my-widget>a</my-widget><my-widget>b</my-widget>') }

    assert_equal 1, error.message.scan('unknown tag <my-widget>').size
  end

  def test_ignore_mode_never_looks_up_tag_descriptions
    ActiveMail.configuration.on_parse_error = :ignore
    lookups = 0

    Nokogiri::HTML4::ElementDescription.stub(:[], ->(_name) { lookups += 1 }) do
      render('<my-widget>x</my-widget>')
    end

    assert_equal 0, lookups
  end
end
