# frozen_string_literal: true

require 'test_helper'

class CoreTest < ActiveMailTest
  def test_handles_binary_input
    output = render('<container/>'.b)

    assert_includes output, 'class="container"'
  end

  def test_binary_input_with_invalid_bytes_degrades_deterministically
    output = render("<container>a\xFFb</container>".b)

    assert_predicate output, :valid_encoding?
    assert_includes output, 'class="container"'
  end

  def test_utf8_marked_input_with_invalid_bytes_degrades_deterministically
    input = "<container>a\xFFb</container>".dup.force_encoding(Encoding::UTF_8)
    output = render(input)

    assert_predicate output, :valid_encoding?
    assert_includes output, 'class="container"'
  end

  def test_handles_utf8_input
    output = render('<container><p>Güten tag Marc-André</p></container>')

    assert_includes output, 'Güten tag Marc-André'
  end

  def test_handles_us_ascii_input
    input = '<container><row><columns>plain ascii</columns></row></container>'.dup.force_encoding(Encoding::US_ASCII)
    output = render(input)

    assert_includes output, 'plain ascii'
    assert_predicate output, :valid_encoding?
  end

  def test_invalid_bytes_raise_when_on_parse_error_is_raise
    ActiveMail.configuration.on_parse_error = :raise

    assert_raises(ActiveMail::ParseError) { render("a\xFF".dup.force_encoding(Encoding::UTF_8)) }
  end

  def test_invalid_bytes_are_scrubbed_silently_when_ignored
    ActiveMail.configuration.on_parse_error = :ignore
    output = render("<container>a\xFFb</container>".dup.force_encoding(Encoding::UTF_8))

    assert_predicate output, :valid_encoding?
  end

  def test_handles_multiple_root_nodes
    output = render('<row></row><row></row>')

    assert_equal 2, output.scan('class="row"').size
  end

  def test_passes_through_unknown_tags
    output = render('<p>hello</p>')

    assert_includes output, '<p>hello</p>'
  end

  def test_uppercases_doctype
    output = render('<!doctype html><html><body></body></html>')

    assert_includes output, '<!DOCTYPE html>'
  end

  def test_unclosed_component_tag_is_still_transformed
    ActiveMail.configuration.on_parse_error = :ignore
    output = render('<row><columns>One')

    assert_includes output, 'class="row"'
    assert_includes output, 'columns'
    assert_includes output, 'One'
  end

  def test_mismatched_nesting_does_not_raise
    ActiveMail.configuration.on_parse_error = :ignore
    output = render('<container><b><i>x</b></i></container>')

    assert_includes output, 'class="container"'
    assert_includes output, 'x'
  end

  def test_component_with_missing_attributes_renders
    output = render('<menu><item>No href</item></menu>')

    assert_includes output, 'class="menu-item"'
    assert_includes output, 'No href'
    refute_includes output, '<a' # no href → no broken anchor
  end

  def test_interim_th_literal_in_author_content_is_untouched
    literal = ActiveMail::Core::INTERIM_TH_TAG
    output = render("<p>#{literal}</p>")

    assert_includes output, "<p>#{literal}</p>"
  end

  def test_newlines_in_content_are_preserved
    output = render("<container><row><columns><p>line1\nline2</p></columns></row></container>")

    assert_includes output, "line1\nline2"
  end

  def test_pre_content_is_preserved_verbatim
    pre = "<pre>def f\n  42\nend</pre>"
    output = render("<container>#{pre}</container>")

    assert_includes output, pre
  end

  def test_non_breaking_space_becomes_entity
    output = render('<p>a b</p>')

    assert_includes output, '&nbsp;'
  end
end

class RawTest < ActiveMailTest
  def test_single_line_raw_passes_through_untouched
    input = "<div><raw><<LCG Default='246996'>></raw></div>"
    output = render(input)

    assert_includes output, "<<LCG Default='246996'>>"
    refute_includes output, '<raw>'
  end

  def test_raw_is_not_transformed
    output = render('<raw><button href="#">x</button></raw>')

    assert_includes output, '<button href="#">x</button>'
    refute_includes output, 'class="button"'
  end

  def test_multi_line_raw_is_supported
    output = render(<<~INKY)
      <div>
        <raw>
          <asdf>untouched</asdf>
        </raw>
        <button href="#">Test</button>
      </div>
    INKY

    assert_includes output, '<asdf>untouched</asdf>'
    assert_includes output, 'class="button"'
  end

  def test_raw_preserves_backslashes_and_backreference_sequences
    payload = 'price \1 = \0 and \& or \\\\ done'
    output = render("<div><raw>#{payload}</raw></div>")

    assert_includes output, payload
  end

  def test_multiple_raw_blocks
    output = render('<div><raw><a></raw><button href="#">b</button><raw><c></raw></div>')

    assert_includes output, '<a>'
    assert_includes output, '<c>'
    assert_includes output, 'class="button"'
  end
end
