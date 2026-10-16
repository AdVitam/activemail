# frozen_string_literal: true

require 'test_helper'

class CalloutTest < ActiveMailTest
  def test_basic_callout
    assert_renders(
      '<callout>Callout</callout>',
      <<~HTML
        <table class="callout" style="width:100%;" role="presentation" border="0" cellpadding="0" cellspacing="0"><tbody><tr>
          <th class="callout-inner">Callout</th>
          <th class="expander"></th>
        </tr></tbody></table>
      HTML
    )
  end

  def test_callout_passes_through_attributes
    table = Nokogiri::HTML.fragment(render('<callout id="c" aria-label="note">C</callout>')).at_css('table')

    assert_equal 'c', table['id']
    assert_equal 'note', table['aria-label']
  end

  def test_layout_attributes_are_not_overridden_by_the_author
    assert_silent { render('<callout role="note" border="3">C</callout>') }
    table = Nokogiri::HTML.fragment(render('<callout role="note">C</callout>')).at_css('table')

    assert_equal 'presentation', table['role']
  end

  def test_callout_copies_classes_to_inner
    output = render('<callout class="primary">C</callout>')

    assert_includes output, 'primary callout-inner'
  end
end

class SpacerTest < ActiveMailTest
  def test_basic_spacer
    assert_renders(
      '<spacer size="10"></spacer>',
      <<~HTML
        <table class="spacer" style="width:100%;" role="presentation" border="0" cellpadding="0" cellspacing="0"><tbody><tr>
          <td height="10" style="font-size:10px;line-height:10px;mso-line-height-rule:exactly;">&nbsp;</td>
        </tr></tbody></table>
      HTML
    )
  end

  def test_default_size_is_16
    output = render('<spacer></spacer>')

    assert_includes output, 'height="16"'
  end

  def test_non_numeric_size_falls_back_to_default
    output = render('<spacer size="abc"></spacer>')

    assert_includes output, 'height="16"'
    refute_includes output, 'height="abc"'
  end

  def test_small_only
    output = render('<spacer size-sm="10"></spacer>')

    assert_includes output, 'spacer hide-for-large'
    refute_includes output, 'show-for-large'
  end

  def test_large_only
    output = render('<spacer size-lg="20"></spacer>')

    assert_includes output, 'spacer show-for-large'
    refute_includes output, 'hide-for-large'
  end

  def test_small_and_large_emit_two_tables
    output = render('<spacer size-sm="10" size-lg="20"></spacer>')

    assert_includes output, 'hide-for-large'
    assert_includes output, 'show-for-large'
    assert_equal 2, output.scan('<table').size
  end

  def test_mso_line_height_rule_present
    output = render('<spacer size="10"></spacer>')

    assert_includes output, 'mso-line-height-rule:exactly'
  end

  def test_copies_classes
    output = render('<spacer size="10" class="bgcolor"></spacer>')

    assert_includes output, 'bgcolor spacer'
  end

  def test_id_is_emitted_once_when_two_tables_are_rendered
    output = render('<spacer id="gap" aria-hidden="true" size-sm="10" size-lg="20"></spacer>')
    tables = Nokogiri::HTML.fragment(output).css('table')

    assert_equal 1, output.scan('id="gap"').size
    assert_equal 'gap', tables.first['id']
    assert_equal(%w[true true], tables.map { |table| table['aria-hidden'] })
  end

  def test_sizing_attributes_do_not_leak
    table = Nokogiri::HTML.fragment(render('<spacer size="10" size-sm="4"></spacer>')).at_css('table')

    %w[size size-sm size-lg].each { |name| assert_nil table[name] }
  end
end

class HLineTest < ActiveMailTest
  def test_basic_h_line
    assert_renders(
      '<h-line></h-line>',
      '<table class="h-line" style="width:100%;" role="presentation" border="0" cellpadding="0" cellspacing="0"><tbody><tr><th>&nbsp;</th></tr></tbody></table>'
    )
  end

  def test_copies_classes
    output = render('<h-line class="dashed"></h-line>')

    assert_includes output, 'dashed h-line'
  end

  def test_passes_through_attributes
    table = Nokogiri::HTML.fragment(render('<h-line id="rule" data-x="1"></h-line>')).at_css('table')

    assert_equal 'rule', table['id']
    assert_equal '1', table['data-x']
  end
end

class WrapperTest < ActiveMailTest
  def test_passes_through_attributes
    table = Nokogiri::HTML.fragment(render('<wrapper id="w" aria-label="Wrap"></wrapper>')).at_css('table')

    assert_equal 'w', table['id']
    assert_equal 'Wrap', table['aria-label']
  end

  def test_basic_wrapper
    assert_renders(
      '<wrapper class="header"></wrapper>',
      '<table class="header wrapper" style="width:100%;" role="presentation" border="0" cellpadding="0" cellspacing="0" align="center"><tbody><tr><td class="wrapper-inner"></td></tr></tbody></table>'
    )
  end
end

class BlockGridTest < ActiveMailTest
  def test_basic_block_grid
    assert_renders(
      '<block-grid up="4"></block-grid>',
      '<table class="block-grid up-4" style="width:100%;" role="presentation" border="0" cellpadding="0" cellspacing="0"><tbody><tr></tr></tbody></table>'
    )
  end

  def test_copies_classes
    output = render('<block-grid up="4" class="show-for-large"></block-grid>')

    assert_includes output, 'show-for-large'
  end

  def test_passes_through_attributes_without_leaking_up
    table = Nokogiri::HTML.fragment(render('<block-grid up="3" id="grid" aria-label="Grid"></block-grid>')).at_css('table')

    assert_equal 'grid', table['id']
    assert_equal 'Grid', table['aria-label']
    assert_nil table['up']
  end

  def test_non_numeric_up_is_dropped
    output = render('<block-grid up="abc"></block-grid>')

    assert_includes output, 'class="block-grid"'
    refute_includes output, 'up-abc'
  end
end

class CenterTest < ActiveMailTest
  def test_centers_child
    assert_renders(
      '<center><div></div></center>',
      '<center><div align="center" class="float-center"></div></center>'
    )
  end

  def test_nested_centers_propagate_align_to_the_inner_element
    output = render('<center><center>a</center></center>')

    assert_includes output, '<center align="center" class="float-center">'
  end

  def test_keeps_its_own_attributes_and_children
    output = render('<center id="mid" class="x"><p>kept</p></center>')

    assert_includes output, '<center class="x" id="mid">'
    assert_includes output, '<p align="center" class="float-center">kept</p>'
  end

  def test_applies_float_center_to_menu_items
    output = render('<center><menu><item href="#"></item></menu></center>')

    assert_includes output, 'menu-item float-center'
  end
end
