# frozen_string_literal: true

require 'test_helper'

class ButtonTest < ActiveMailTest
  def test_simple_button_is_bulletproof
    ActiveMail.tokens.font(:body, 'Arial, sans-serif')
    assert_renders(
      '<button href="https://example.com">Button</button>',
      <<~HTML
        <table class="button" role="presentation" border="0" cellpadding="0" cellspacing="0"><tbody><tr><td>
          <table role="presentation" border="0" cellpadding="0" cellspacing="0"><tbody><tr><td style="background:#2a9d8f;border-radius:4px;mso-padding-alt:12px 24px;">
            <a href="https://example.com" style="display:inline-block;text-decoration:none;padding:12px 24px;font-family:Arial, sans-serif;line-height:1.25;color:#ffffff;font-weight:bold;">Button</a>
          </td></tr></tbody></table>
        </td></tr></tbody></table>
      HTML
    )
  end

  def test_padding_lives_on_the_anchor_and_is_mirrored_for_outlook
    fragment = Nokogiri::HTML.fragment(render('<button href="#">Go</button>'))

    assert_includes fragment.at_css('a')['style'], 'padding:12px 24px;'
    assert_includes fragment.at_css('td[style*="background"]')['style'], 'mso-padding-alt:12px 24px;'
  end

  def test_fill_and_radius_live_on_the_cell_only
    fragment = Nokogiri::HTML.fragment(render('<button href="#">Go</button>'))

    refute_match(/background|border-radius/, fragment.at_css('a')['style'])
    assert_match(/background:#2a9d8f;border-radius:4px;/, fragment.at_css('td[style*="background"]')['style'])
  end

  def test_anchor_carries_the_body_font_and_line_height
    ActiveMail.tokens.font(:body, 'Georgia, serif')
    style = Nokogiri::HTML.fragment(render('<button href="#">Go</button>')).at_css('a')['style']

    assert_includes style, 'font-family:Georgia, serif;'
    assert_includes style, 'line-height:1.25;'
  end

  def test_colors_come_from_tokens
    ActiveMail.tokens.color(:primary, '#aa0011')
    output = render('<button href="#">Go</button>')

    assert_includes output, 'background:#aa0011'
  end

  def test_secondary_class_selects_the_secondary_variant
    ActiveMail.tokens.color(:secondary, '#00cc33')
    output = render('<button class="secondary" href="#">Go</button>')

    assert_includes output, 'background:#00cc33'
    assert_includes Nokogiri::HTML.fragment(output).at_css('table')['class'].split, 'secondary'
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

  def test_expanded_button_is_full_width
    output = render('<button class="expand" href="#">B</button>')
    fragment = Nokogiri::HTML.fragment(output)

    assert_equal 2, fragment.css('table[style*="width:100%"]').size
    assert_includes fragment.at_css('a')['style'], 'display:block'
    assert_includes fragment.at_css('table')['class'].split, 'expand'
  end

  def test_regular_button_is_not_full_width
    output = render('<button href="#">B</button>')

    refute_includes output, 'width:100%'
  end

  def test_id_and_aria_attributes_reach_the_anchor
    output = render('<button href="#" id="go" aria-label="Go now" data-track="x">B</button>')
    anchor = Nokogiri::HTML.fragment(output).at_css('a')

    assert_equal 'go', anchor['id']
    assert_equal 'Go now', anchor['aria-label']
    assert_equal 'x', anchor['data-track']
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
