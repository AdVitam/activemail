# frozen_string_literal: true

require 'test_helper'

class CalloutTest < ActiveMailTest
  def test_basic_callout
    assert_renders(
      '<callout>Callout</callout>',
      <<~HTML
        <table class="callout" role="presentation" border="0" cellpadding="0" cellspacing="0" style="width:100%;"><tbody><tr>
          <th class="callout-inner">Callout</th>
          <th class="expander"></th>
        </tr></tbody></table>
      HTML
    )
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
        <table class="spacer" role="presentation" border="0" cellpadding="0" cellspacing="0" style="width:100%;"><tbody><tr>
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
end

class HLineTest < ActiveMailTest
  def test_basic_h_line
    assert_renders(
      '<h-line></h-line>',
      '<table class="h-line" role="presentation" border="0" cellpadding="0" cellspacing="0" style="width:100%;"><tbody><tr><th>&nbsp;</th></tr></tbody></table>'
    )
  end

  def test_copies_classes
    output = render('<h-line class="dashed"></h-line>')

    assert_includes output, 'dashed h-line'
  end
end

class WrapperTest < ActiveMailTest
  def test_basic_wrapper
    assert_renders(
      '<wrapper class="header"></wrapper>',
      '<table class="header wrapper" role="presentation" border="0" cellpadding="0" cellspacing="0" align="center" style="width:100%;"><tbody><tr><td class="wrapper-inner"></td></tr></tbody></table>'
    )
  end
end

class BlockGridTest < ActiveMailTest
  def test_basic_block_grid
    assert_renders(
      '<block-grid up="4"></block-grid>',
      '<table class="block-grid up-4" role="presentation" border="0" cellpadding="0" cellspacing="0" style="width:100%;"><tbody><tr></tr></tbody></table>'
    )
  end

  def test_copies_classes
    output = render('<block-grid up="4" class="show-for-large"></block-grid>')

    assert_includes output, 'show-for-large'
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

  def test_nested_centers_do_not_choke
    output = render('<center><center>a</center></center>')

    assert_includes output, 'float-center'
  end

  def test_applies_float_center_to_menu_items
    output = render('<center><menu><item href="#"></item></menu></center>')

    assert_includes output, 'menu-item float-center'
  end
end

class InkyComponentTest < ActiveMailTest
  def test_inky_tag_renders_a_bare_tr
    assert_renders('<inky></inky>', '<tr></tr>')
  end
end
