# frozen_string_literal: true

require 'test_helper'

class CoreTest < InkyTest
  def test_handles_binary_input
    output = render('<container/>'.b)

    assert_includes output, 'class="container"'
  end

  def test_handles_utf8_input
    output = render('<container><p>Güten tag Marc-André</p></container>')

    assert_includes output, 'Güten tag Marc-André'
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

  def test_non_breaking_space_becomes_entity
    output = render('<p>a b</p>')

    assert_includes output, '&nbsp;'
  end
end

class RawTest < InkyTest
  def test_single_line_raw_passes_through_untouched
    input = "<body><raw><<LCG Default='246996'>></raw></body>"
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

  def test_multiple_raw_blocks
    output = render('<div><raw><a></raw><button href="#">b</button><raw><c></raw></div>')

    assert_includes output, '<a>'
    assert_includes output, '<c>'
    assert_includes output, 'class="button"'
  end
end
