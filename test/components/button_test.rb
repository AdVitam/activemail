# frozen_string_literal: true

require 'test_helper'

class ButtonTest < InkyTest
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

    assert_equal output.scan('<table').size, output.scan('role="presentation"').size
  end

  def test_href_with_double_quote_is_escaped
    output = render('<button href="https://x.test/?q=&quot;a&quot;">B</button>')
    anchor = Nokogiri::HTML.fragment(output).at_css('a')

    assert_equal 'https://x.test/?q="a"', anchor['href']
  end
end
