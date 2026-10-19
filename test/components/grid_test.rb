# frozen_string_literal: true

require 'test_helper'

class GridTest < ActiveMailTest
  def test_row_renders_a_presentation_table
    assert_renders(
      '<row></row>',
      '<table class="row" style="width:100%;" role="presentation" border="0" cellpadding="0" cellspacing="0"><tbody><tr></tr></tbody></table>'
    )
  end

  def test_single_column_default_classes_and_ghost_cells
    assert_renders(
      '<columns>One</columns>',
      <<~HTML
        <!--[if mso]><td width="600" valign="top"><table role="presentation" border="0" cellpadding="0" cellspacing="0" width="600"><tr><![endif]-->
        <th class="small-12 large-12 columns first last" style="display:inline-block;vertical-align:top;width:100%;max-width:600px;"><table role="presentation" border="0" cellpadding="0" cellspacing="0" style="width:100%;"><tbody><tr><th style="font-weight:normal;text-align:left;">One</th><th class="expander"></th></tr></tbody></table></th>
        <!--[if mso]></tr></table></td><![endif]-->
      HTML
    )
  end

  def test_ghost_cell_wraps_the_column_in_its_own_table
    ghost = render('<columns large="6">One</columns>')[/<!--\[if mso\]><td.*?<!\[endif\]-->/m]

    assert_includes ghost, '<td width="300" valign="top"><table role="presentation" border="0" cellpadding="0" cellspacing="0" width="300"><tr>'
  end

  def test_nested_ghost_width_is_relative_to_the_enclosing_column
    output = render('<row><columns large="6"><row><columns large="6">in</columns><columns large="6">in</columns></row></columns></row>')
    ghosts = output.scan(/<!--\[if mso\]><td width="(\d+)"/).flatten.map(&:to_i)

    # The parent column (300px) keeps a 16px container gutter on each side: 268px of content.
    assert_equal [300, 134, 134], ghosts
    assert_equal [134, 134, 300], output.scan(/max-width:(\d+)px/).flatten.map(&:to_i).sort
  end

  def test_nested_columns_fit_in_a_full_width_parent
    output = render('<row><columns><row><columns large="6">A</columns><columns large="6">B</columns></row></columns></row>')

    assert_equal [600, 284, 284], output.scan(/<!--\[if mso\]><td width="(\d+)"/).flatten.map(&:to_i)
  end

  def test_nested_columns_take_the_inner_gutter_of_a_middle_parent
    output = render('<row><columns large="4">a</columns><columns large="4"><row><columns>in</columns></row></columns><columns large="4">c</columns></row>')

    assert_includes output.scan(/<!--\[if mso\]><td width="(\d+)"/).flatten.map(&:to_i), 184
  end

  def test_nested_columns_of_a_collapsed_row_use_the_whole_parent
    output = render('<row class="collapse"><columns large="6"><row><columns large="6">in</columns></row></columns></row>')

    assert_equal [300, 150], output.scan(/<!--\[if mso\]><td width="(\d+)"/).flatten.map(&:to_i)
  end

  def test_ghost_width_clamps_an_oversized_share_per_level
    output = render('<row><columns large="20"><row><columns large="12">in</columns></row></columns></row>')

    assert_equal [600, 568], output.scan(/<!--\[if mso\]><td width="(\d+)"/).flatten.map(&:to_i)
  end

  def test_column_count_option_changes_default_sizes
    output = render('<columns>One</columns>', column_count: 5)

    assert_includes output, 'small-5 large-5'
  end

  def test_column_count_from_global_configuration
    ActiveMail.configure { |config| config.column_count = 5 }
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

  def test_sizing_attributes_do_not_leak_into_output
    output = render('<columns small="6" large="8">x</columns>')
    th = Nokogiri::HTML.fragment(output).at_css('th.columns')

    assert_nil th['small']
    assert_nil th['large']
  end

  def test_sizing_attributes_are_matched_case_insensitively
    output = render('<columns SMALL="12" Large="6">x</columns>')
    th = Nokogiri::HTML.fragment(output).at_css('th.columns')

    assert_nil th['small']
    assert_nil th['large']
    assert_includes output, 'large-6'
  end

  def test_id_and_aria_attributes_pass_through
    output = render('<columns id="col" aria-label="Left" role="region">x</columns>')
    th = Nokogiri::HTML.fragment(output).at_css('th.columns')

    assert_equal 'col', th['id']
    assert_equal 'Left', th['aria-label']
    assert_equal 'region', th['role']
  end

  def test_only_column_siblings_count_for_the_default_width
    output = render('<div><columns>One</columns><p>between</p><columns>Two</columns></div>')

    assert_equal 2, output.scan('large-6').size
    assert_includes output, 'columns first'
    assert_includes output, 'columns last'
  end

  def test_non_column_sibling_does_not_break_first_and_last
    output = render('<div><p>intro</p><columns>One</columns></div>')

    assert_includes output, 'large-12 columns first last'
  end

  def test_user_style_is_not_emitted_twice_on_the_column
    output = render('<columns style="background:#fff">x</columns>')
    th_open_tag = output[/<th class="[^"]*columns[^"]*"[^>]*>/]

    assert_equal 1, th_open_tag.scan('style="').size
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
