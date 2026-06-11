# frozen_string_literal: true

require 'test_helper'

# A duplicated style attribute makes HTML parsers drop one of the two: either
# the author styling or the critical fluid-hybrid layout CSS.
class StyleMergeTest < InkyTest
  def test_columns_merge_user_style_after_layout_style
    output = render('<columns style="background:#fff">x</columns>')
    style = Nokogiri::HTML.fragment(output).at_css('th.columns')['style']

    assert_includes style, 'display:inline-block'
    assert_includes style, 'max-width:600px'
    assert_includes style, 'background:#fff'
    assert_operator style.index('display:inline-block'), :<, style.index('background:#fff')
  end

  def test_container_merges_user_style
    output = render('<container style="background:#eee"></container>')
    style = Nokogiri::HTML.fragment(output).at_css('table.container')['style']

    assert_includes style, 'max-width:600px'
    assert_includes style, 'background:#eee'
  end

  def test_row_merges_user_style
    output = render('<row style="background:#eee"></row>')
    style = Nokogiri::HTML.fragment(output).at_css('table.row')['style']

    assert_includes style, 'width:100%'
    assert_includes style, 'background:#eee'
  end

  def test_button_anchor_merges_user_style
    output = render('<button href="#" style="color:#fff">B</button>')
    style = Nokogiri::HTML.fragment(output).at_css('a')['style']

    assert_includes style, 'padding:12px 24px'
    assert_includes style, 'color:#fff'
  end

  def test_user_style_can_override_non_critical_property
    output = render('<button href="#" style="padding:4px">B</button>')
    style = Nokogiri::HTML.fragment(output).at_css('a')['style']

    assert_operator style.index('padding:12px 24px'), :<, style.index('padding:4px')
  end

  def test_menu_preserves_user_style
    output = render('<menu style="background:#000"></menu>')
    style = Nokogiri::HTML.fragment(output).at_css('table.menu')['style']

    assert_includes style, 'background:#000'
  end

  def test_menu_item_preserves_user_style
    output = render('<menu><item href="#" style="color:red">I</item></menu>')
    style = Nokogiri::HTML.fragment(output).at_css('th.menu-item')['style']

    assert_includes style, 'color:red'
  end

  def test_wrapper_callout_h_line_spacer_block_grid_merge_user_style
    {
      '<wrapper style="background:#eee"></wrapper>' => 'table.wrapper',
      '<callout style="background:#eee">C</callout>' => 'table.callout',
      '<h-line style="background:#eee"></h-line>' => 'table.h-line',
      '<spacer size="10" style="background:#eee"></spacer>' => 'table.spacer',
      '<block-grid up="2" style="background:#eee"></block-grid>' => 'table.block-grid'
    }.each do |input, selector|
      style = Nokogiri::HTML.fragment(render(input)).at_css(selector)['style']

      assert_includes style, 'width:100%', "layout style missing for #{selector}"
      assert_includes style, 'background:#eee', "user style lost for #{selector}"
    end
  end

  def test_no_user_style_emits_layout_style_only
    output = render('<row></row>')
    style = Nokogiri::HTML.fragment(output).at_css('table.row')['style']

    assert_equal 'width:100%;', style
  end

  def test_user_style_without_trailing_semicolon_is_terminated
    output = render('<row style="background:#eee"></row>')
    style = Nokogiri::HTML.fragment(output).at_css('table.row')['style']

    assert_includes style, 'background:#eee;'
  end
end
