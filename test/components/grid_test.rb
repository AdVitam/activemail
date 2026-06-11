# frozen_string_literal: true

require 'test_helper'

class GridTest < InkyTest
  def test_row_renders_a_presentation_table
    assert_renders(
      '<row></row>',
      '<table class="row" role="presentation" border="0" cellpadding="0" cellspacing="0" style="width:100%;"><tbody><tr></tr></tbody></table>'
    )
  end

  def test_single_column_default_classes_and_ghost_cells
    assert_renders(
      '<columns>One</columns>',
      <<~HTML
        <!--[if mso | IE]><td width="600" valign="top"><![endif]-->
        <th class="small-12 large-12 columns first last" style="display:inline-block;vertical-align:top;width:100%;max-width:600px;"><table role="presentation" border="0" cellpadding="0" cellspacing="0" style="width:100%;"><tbody><tr><th style="font-weight:normal;text-align:left;">One</th><th class="expander"></th></tr></tbody></table></th>
        <!--[if mso | IE]></td><![endif]-->
      HTML
    )
  end

  def test_column_count_option_changes_default_sizes
    output = render('<columns>One</columns>', column_count: 5)

    assert_includes output, 'small-5 large-5'
  end

  def test_column_count_from_global_configuration
    Inky.configure { |config| config.column_count = 5 }
    output = render('<columns>One</columns>')

    assert_includes output, 'small-5 large-5'
  end

  def test_two_columns_get_first_and_last
    output = render(<<~INKY)
      <div>
        <columns large="6" small="12">One</columns>
        <columns large="6" small="12">Two</columns>
      </div>
    INKY

    assert_includes output, 'small-12 large-6 columns first'
    assert_includes output, 'small-12 large-6 columns last'
  end

  def test_three_columns_middle_has_no_first_or_last
    output = render(<<~INKY)
      <div>
        <columns large="4" small="12">One</columns>
        <columns large="4" small="12">Two</columns>
        <columns large="4" small="12">Three</columns>
      </div>
    INKY

    middle = output.scan(/class="([^"]*)"/).flatten.find { |c| c.include?('large-4') && !c.include?('first') && !c.include?('last') }

    refute_nil middle
  end

  def test_borrows_large_from_small_when_large_missing
    output = render('<div><columns small="4">One</columns><columns small="8">Two</columns></div>')

    assert_includes output, 'small-4 large-4'
    assert_includes output, 'small-8 large-8'
  end

  def test_small_defaults_to_full_width_when_only_large_given
    output = render('<div><columns large="4">One</columns><columns large="8">Two</columns></div>')

    assert_includes output, 'small-12 large-4'
    assert_includes output, 'small-12 large-8'
  end

  def test_two_columns_without_sizes_split_large_in_half
    output = render('<div><columns>One</columns><columns>Two</columns></div>')

    assert_includes output, 'small-12 large-6 columns first'
    assert_includes output, 'small-12 large-6 columns last'
  end

  def test_transfers_extra_classes_and_attributes
    output = render('<columns small="6" valign="middle" foo="bar">x</columns>')

    assert_includes output, 'valign="middle"'
    assert_includes output, 'foo="bar"'
    assert_includes output, 'small-6 large-6'
  end

  def test_passed_through_attribute_values_are_escaped
    output = render('<columns title="a &quot;b&quot;">x</columns>')
    th = Nokogiri::HTML.fragment(output).at_css('th.columns')

    assert_equal 'a "b"', th['title']
  end

  def test_expander_only_on_full_width_without_nested_row
    full = render('<columns>One</columns>')
    nested = render('<row><columns><row></row></columns></row>')

    assert_includes full, 'class="expander"'
    refute_includes nested, 'class="expander"'
  end

  def test_supports_nested_grids
    output = render('<row><columns><row></row></columns></row>')

    assert_equal 2, output.scan('class="row"').size
  end

  def test_column_max_width_scales_with_large_size
    output = render('<div><columns large="6">One</columns><columns large="6">Two</columns></div>')

    assert_includes output, 'max-width:300px'
  end

  def test_non_numeric_small_falls_back_to_default
    output = render('<columns small="abc">x</columns>')

    assert_includes output, 'small-12'
    refute_includes output, 'small-0'
  end

  def test_negative_large_falls_back_to_default
    output = render('<columns large="-3">x</columns>')

    assert_includes output, 'large-12'
  end

  def test_non_numeric_large_borrows_valid_small
    output = render('<columns small="6" large="abc">x</columns>')

    assert_includes output, 'small-6 large-6'
  end

  def test_ghost_cell_width_is_clamped_to_container_width
    output = render('<columns large="14">One</columns>')

    assert_includes output, 'width="600"'
    assert_includes output, 'max-width:600px'
    refute_includes output, 'max-width:700px'
  end

  def test_column_content_cell_neutralizes_th_defaults
    output = render('<columns>One</columns>')

    assert_includes output, 'font-weight:normal;text-align:left;'
  end
end
