# frozen_string_literal: true

require 'test_helper'

class MenuTest < InkyTest
  def test_menu_with_item
    assert_renders(
      '<menu><item href="http://zurb.com">Item</item></menu>',
      <<~HTML
        <table class="menu" role="presentation" border="0" cellpadding="0" cellspacing="0"><tbody><tr><td>
          <table role="presentation" border="0" cellpadding="0" cellspacing="0"><tbody><tr>
            <th class="menu-item"><a href="http://zurb.com">Item</a></th>
          </tr></tbody></table>
        </td></tr></tbody></table>
      HTML
    )
  end

  def test_item_preserves_target
    output = render('<menu><item href="#" target="_blank">I</item></menu>')

    assert_includes output, 'target="_blank"'
  end

  def test_menu_merges_classes
    output = render('<menu class="vertical"></menu>')

    assert_includes output, 'vertical menu'
  end

  def test_works_with_raw_th_items
    output = render('<menu><th class="menu-item"><a href="#">I</a></th></menu>')

    assert_includes output, 'class="menu-item"'
  end

  def test_item_href_with_double_quote_is_escaped
    output = render('<menu><item href="https://x.test/?q=&quot;a&quot;">I</item></menu>')
    anchor = Nokogiri::HTML.fragment(output).at_css('th.menu-item a')

    assert_equal 'https://x.test/?q="a"', anchor['href']
  end
end
