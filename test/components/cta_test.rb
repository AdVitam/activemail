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

  def test_info_box_reads_border_token
    ActiveMail.tokens.color(:border, '#445566')
    output = render('<info-box>note</info-box>')

    assert_includes output, 'border-left:5px solid #445566'
    assert_includes output, 'class="info-box"'
  end
end
