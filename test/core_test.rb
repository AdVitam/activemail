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

  def test_word_doctype_in_text_is_untouched
    output = render('<p>the doctype of a doctype</p>')

    assert_includes output, 'the doctype of a doctype'
    refute_includes output, 'DOCTYPE'
  end

  def test_nbsp_inside_style_is_not_rewritten
    nbsp = "\u00A0"
    output = render(%(<style>a:after{content:"#{nbsp}"}</style><p>#{nbsp}</p><script>var s = "#{nbsp}";</script>))

    assert_includes output, %(content:"#{nbsp}")
    assert_includes output, %(var s = "#{nbsp}")
    assert_includes output, '<p>&nbsp;</p>'
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

  def test_raw_preserves_surrounding_whitespace
    output = render("<pre>a\n<raw>b</raw>\nc</pre>")

    assert_includes output, "a\n", 'newline before <raw> must survive'
    assert_includes output, "\nc", 'newline after </raw> must survive'
  end

  def test_text_shaped_like_a_placeholder_from_another_run_is_untouched
    lookalike = 'activemail-raw-0123456789abcdef-0~'
    output = render("<div><raw><b>kept</b></raw><p>#{lookalike}</p></div>")

    assert_includes output, '<b>kept</b>'
    assert_includes output, "<p>#{lookalike}</p>"
  end

  def test_two_raws_keep_their_own_content
    output = render('<div><raw><x-one></raw>|<raw><x-two></raw></div>')

    assert_includes output, '<x-one>|<x-two>'
  end

  def test_raw_containing_a_component_tag_is_not_transformed
    output = render('<div><raw><button href="#">raw</button></raw><button href="#">real</button></div>')

    assert_includes output, '<button href="#">raw</button>'
    assert_equal 1, output.scan('class="button"').size
  end

  def test_many_raws_are_all_restored
    output = render('<p>x</p><raw><i>r</i></raw>' * 300)

    assert_equal 300, output.scan('<i>r</i>').size
  end

  def test_deeply_nested_components_keep_their_content
    html = "#{'<row><columns>' * 60}deep#{'</columns></row>' * 60}"
    output = render(html)

    assert_equal 60, output.scan('class="row"').size
    assert_includes output, 'deep'
  end

  def test_multiple_raw_blocks
    output = render('<div><raw><a></raw><button href="#">b</button><raw><c></raw></div>')

    assert_includes output, '<a>'
    assert_includes output, '<c>'
    assert_includes output, 'class="button"'
  end
end

class IgnoredSlotComponent < ActiveMail::Components::Base
  extend T::Sig

  sig { override.params(_node: Nokogiri::XML::Node, _inner: String).returns(String) }
  def transform(_node, _inner)
    '<div>no slot</div>'
  end
end

class DoubleSlotComponent < ActiveMail::Components::Base
  extend T::Sig

  sig { override.params(_node: Nokogiri::XML::Node, inner: String).returns(String) }
  def transform(_node, inner)
    "<div>#{inner}</div><div>#{inner}</div>"
  end
end

class SlotContractTest < ActiveMailTest
  def setup
    super
    ActiveMail.configuration.register_component('no-slot', IgnoredSlotComponent)
    ActiveMail.configuration.register_component('two-slots', DoubleSlotComponent)
  end

  def test_component_ignoring_inner_with_content_raises
    error = assert_raises(ActiveMail::Error) { render('<no-slot><p>lost</p></no-slot>') }

    assert_includes error.message, '<no-slot>'
    assert_includes error.message, 'IgnoredSlotComponent'
  end

  def test_component_ignoring_inner_with_text_raises
    assert_raises(ActiveMail::Error) { render('<no-slot>lost</no-slot>') }
  end

  def test_component_ignoring_inner_on_empty_or_blank_node_is_fine
    assert_includes render('<no-slot></no-slot>'), '<div>no slot</div>'
    assert_includes render('<no-slot>  </no-slot>'), '<div>no slot</div>'
  end

  def test_component_repeating_inner_raises
    error = assert_raises(ActiveMail::Error) { render('<two-slots>x</two-slots>') }

    assert_includes error.message, 'DoubleSlotComponent'
  end

  def test_builtin_components_ignoring_inner_accept_empty_nodes
    assert_includes render('<h-line></h-line><spacer></spacer>'), 'class="h-line"'
  end
end

class DedicatedConfigTest < ActiveMailTest
  def test_core_applies_its_own_config_rather_than_the_global_one
    dedicated = ActiveMail::Configuration.new
    dedicated.on_parse_error = :raise
    dedicated.tokens.color(:primary, '#123456')
    dedicated.blank_link_rel = 'noreferrer'
    ActiveMail.configuration.on_parse_error = :ignore
    core = ActiveMail::Core.new(config: dedicated)

    assert_same dedicated, core.config
    assert_raises(ActiveMail::ParseError) { core.transpile('<container><b><i>x</b></i></container>') }

    output = core.transpile('<button href="#" target="_blank">Go</button>')

    assert_includes output, 'background:#123456'
    assert_includes output, 'rel="noreferrer"'
    refute_includes render('<button href="#">Go</button>'), '#123456'
  end

  def test_info_box_reads_the_core_config_tokens
    dedicated = ActiveMail::Configuration.new
    dedicated.tokens.color(:border, '#abcdef')
    output = ActiveMail::Core.new(config: dedicated).transpile('<info-box>n</info-box>')

    assert_includes output, 'border-left:5px solid #abcdef'
  end
end
