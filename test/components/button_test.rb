# frozen_string_literal: true

require 'test_helper'

class ButtonTest < ActiveMailTest
  def test_simple_button_is_bulletproof
    assert_renders(
      '<button href="http://zurb.com">Button</button>',
      <<~HTML
        <table class="button" role="presentation" border="0" cellpadding="0" cellspacing="0"><tbody><tr><td>
          <table role="presentation" border="0" cellpadding="0" cellspacing="0"><tbody><tr><td>
            <a href="http://zurb.com" style="display:inline-block;text-decoration:none;padding:12px 24px;">Button</a>
          </td></tr></tbody></table>
        </td></tr></tbody></table>
      HTML
    )
  end

  def test_padding_lives_on_the_anchor
    output = render('<button href="#">Go</button>')

    assert_match(/<a [^>]*style="[^"]*padding:12px 24px;[^"]*"/, output)
  end

  def test_target_blank_is_preserved
    output = render('<button href="#" target="_blank">B</button>')

    assert_includes output, 'target="_blank"'
  end

  def test_target_blank_injects_default_rel
    output = render('<button href="#" target="_blank">B</button>')

    assert_includes output, 'rel="noopener"'
  end

  def test_non_blank_target_gets_no_rel
    output = render('<button href="#" target="_self">B</button>')

    refute_includes output, 'rel='
  end

  def test_no_target_gets_no_rel
    output = render('<button href="#">B</button>')

    refute_includes output, 'rel='
  end

  def test_explicit_rel_wins_without_duplication
    output = render('<button href="#" target="_blank" rel="noopener noreferrer">B</button>')

    assert_includes output, 'rel="noopener noreferrer"'
    assert_equal 1, output.scan('rel="').size
  end

  def test_empty_rel_falls_back_to_default
    output = render('<button href="#" target="_blank" rel="">B</button>')

    assert_includes output, 'rel="noopener"'
    assert_equal 1, output.scan('rel="').size
  end

  def test_rel_is_escaped
    output = render('<button href="#" target="_blank" rel="a&quot;b">B</button>')
    anchor = Nokogiri::HTML.fragment(output).at_css('a')

    assert_equal 'a"b', anchor['rel']
  end

  def test_classes_are_merged_with_button
    output = render('<button class="small alert" href="#">B</button>')

    assert_includes output, 'small alert button'
  end

  def test_expanded_button_adds_center_and_expander
    output = render('<button class="expand" href="#">B</button>')

    assert_includes output, '<center>'
    assert_includes output, 'class="expander"'
    assert_includes output, 'class="float-center"'
  end

  def test_button_without_href_has_no_anchor
    output = render('<button>Plain</button>')

    refute_includes output, '<a '
    assert_includes output, 'Plain'
  end

  def test_every_table_is_presentation_role
    output = render('<button href="#">B</button>')
    tables = output.scan('<table').size

    assert_operator tables, :>=, 1
    assert_equal tables, output.scan('role="presentation"').size
  end

  def test_href_with_ampersand_and_angle_brackets_round_trips
    output = render('<button href="https://x.test/?a=1&amp;b=&lt;2&gt;">B</button>')
    anchor = Nokogiri::HTML.fragment(output).at_css('a')

    assert_equal 'https://x.test/?a=1&b=<2>', anchor['href']
  end

  def test_href_with_double_quote_is_escaped
    output = render('<button href="https://x.test/?q=&quot;a&quot;">B</button>')
    anchor = Nokogiri::HTML.fragment(output).at_css('a')

    assert_equal 'https://x.test/?q="a"', anchor['href']
  end
end
