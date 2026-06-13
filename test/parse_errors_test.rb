# frozen_string_literal: true

require 'test_helper'

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

  # Locks the libxml2 message format the tag filter depends on: if a Nokogiri
  # bump changes it, this fails before users drown in false warnings.
  def test_unknown_tag_filter_matches_pinned_libxml2_message_format
    error = Nokogiri::HTML.fragment('<row></row>').errors
                          .find { |e| e.code == ActiveMail::ParseErrorReporter::UNKNOWN_TAG_ERROR_CODE }

    refute_nil error
    assert_silent { ActiveMail::ParseErrorReporter.new(['row']).call([error]) }
    assert_output(nil, /\S/) { ActiveMail::ParseErrorReporter.new([]).call([error]) }
  end
end
