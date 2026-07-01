# frozen_string_literal: true

require 'test_helper'

class CtaTest < ActiveMailTest
  def setup
    super
    ActiveMail.configuration.register_component('cta', ActiveMail::Components::Cta)
    ActiveMail.configuration.register_component('info-box', ActiveMail::Components::InfoBox)
  end

  def test_cta_requires_href
    assert_raises(ArgumentError) { render('<cta>Go</cta>') }
  end

  def test_cta_uses_primary_token_by_default
    ActiveMail.tokens.color(:primary, '#aa0011')
    output = render('<cta href="https://x.test">Go</cta>')

    assert_includes output, '#aa0011'
    assert_match(%r{<a [^>]*href="https://x.test"}, output)
  end

  def test_cta_emits_cta_hook_class
    output = render('<cta href="#">Go</cta>')
    outer = Nokogiri::HTML.fragment(output).at_css('table')

    assert_includes outer['class'].to_s.split, 'cta'
  end

  def test_cta_secondary_variant_uses_secondary_token
    ActiveMail.tokens.color(:secondary, '#00cc33')
    output = render('<cta class="secondary" href="#">Go</cta>')

    assert_includes output, '#00cc33'
  end

  def test_cta_radius_comes_from_token
    ActiveMail.tokens.radius(:button, '9px')
    output = render('<cta href="#">Go</cta>')

    assert_includes output, 'border-radius:9px'
    refute_includes output, 'border-radius:4px'
  end

  def test_cta_default_secondary_has_no_outline
    output = render('<cta class="secondary" href="#">Go</cta>')

    refute_includes output, 'border:1px solid'
  end

  def test_cta_secondary_outline_is_token_driven
    ActiveMail.tokens.load(
      color: { secondary: '#ffffff', secondary_text: '#0f4447', secondary_border: 'rgba(15, 68, 71, 0.6)' }
    )
    output = render('<cta class="secondary" href="#">Go</cta>')

    assert_includes output, 'background:#ffffff'
    assert_includes output, 'color:#0f4447'
    assert_includes output, 'border:1px solid rgba(15, 68, 71, 0.6)'
    # Border on the cell only — never doubled on the nested anchor.
    assert_equal 1, output.scan('border:1px solid').size
    refute_includes Nokogiri::HTML.fragment(output).at_css('a')['style'].to_s, 'border:1px solid'
  end

  def test_cta_secondary_keeps_secondary_class
    output = render('<cta class="secondary" href="#">Go</cta>')
    outer = Nokogiri::HTML.fragment(output).at_css('table')
    classes = outer['class'].to_s.split

    assert_includes classes, 'cta'
    assert_includes classes, 'secondary'
  end

  def test_cta_is_bulletproof_presentation_tables
    output = render('<cta href="#">Go</cta>')
    tables = output.scan('<table').size

    assert_operator tables, :>=, 1
    assert_equal tables, output.scan('role="presentation"').size
  end

  def test_cta_blank_injects_default_rel
    output = render('<cta href="#" target="_blank">Go</cta>')

    assert_includes output, 'target="_blank"'
    assert_includes output, 'rel="noopener"'
  end

  def test_cta_non_blank_gets_no_rel
    output = render('<cta href="#">Go</cta>')

    refute_includes output, 'rel='
  end

  def test_cta_explicit_rel_wins_without_duplication
    output = render('<cta href="#" target="_blank" rel="noopener noreferrer">Go</cta>')

    assert_includes output, 'rel="noopener noreferrer"'
    assert_equal 1, output.scan('rel="').size
  end

  def test_info_box_reads_border_token
    ActiveMail.tokens.color(:border, '#445566')
    output = render('<info-box>note</info-box>')

    assert_includes output, 'border-left:5px solid #445566'
    assert_includes output, 'class="info-box"'
  end
end
