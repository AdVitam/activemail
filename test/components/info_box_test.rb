# frozen_string_literal: true

require 'test_helper'

class InfoBoxTest < ActiveMailTest
  def setup
    super
    ActiveMail.configuration.register_component('info-box', ActiveMail::Components::InfoBox)
  end

  def test_falls_back_to_page_palette
    ActiveMail.tokens.load(color: { background: '#fafafa', border: '#445566', text: '#111111' })
    output = render('<info-box>note</info-box>')

    assert_includes output, 'background-color:#fafafa'
    assert_includes output, 'border-left:5px solid #445566'
    assert_includes output, 'color:#111111'
    assert_includes output, 'class="info-box"'
  end

  def test_box_scoped_tokens_override_page_palette
    ActiveMail.tokens.load(
      color: { background: '#ffffff', info_box_background: '#fff7ef', info_box_border: '#2c666e', info_box_text: '#2c666e' }
    )
    output = render('<info-box>note</info-box>')

    assert_includes output, 'background-color:#fff7ef'
    assert_includes output, 'border-left:5px solid #2c666e'
    assert_includes output, 'color:#2c666e'
    refute_includes output, 'background-color:#ffffff'
  end

  def test_border_radius_comes_from_box_token
    ActiveMail.tokens.radius(:box, '8px')
    output = render('<info-box>note</info-box>')

    assert_includes output, 'border-radius:8px'
  end
end
