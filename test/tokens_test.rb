# frozen_string_literal: true

require 'test_helper'

class TokensTest < ActiveMailTest
  def test_ships_neutral_defaults
    tokens = ActiveMail::Tokens.new

    refute_empty tokens.color(:primary).to_s
    refute_empty tokens.color(:text).to_s
    refute_empty tokens.color(:background).to_s
    refute_empty tokens.font(:body).to_s
    refute_empty tokens.spacing(:md).to_s
  end

  def test_setter_overrides_value
    tokens = ActiveMail::Tokens.new
    tokens.color(:primary, '#123456')

    assert_equal '#123456', tokens.color(:primary)
  end

  def test_rejects_blank_values
    tokens = ActiveMail::Tokens.new

    assert_raises(ArgumentError) { tokens.color(:primary, '') }
    assert_raises(ArgumentError) { tokens.color(:primary, '   ') }
  end

  def test_strict_readers_raise_on_unknown_key
    tokens = ActiveMail::Tokens.new
    primary = tokens.color(:primary)

    assert_equal primary, tokens.color!(:primary)
    assert_raises(KeyError) { tokens.color!(:does_not_exist) }
    assert_raises(KeyError) { tokens.font!(:does_not_exist) }
    assert_raises(KeyError) { tokens.spacing!(:does_not_exist) }
  end

  def test_setter_accepts_string_name
    tokens = ActiveMail::Tokens.new
    tokens.spacing('md', '20px')

    assert_equal '20px', tokens.spacing(:md)
  end

  def test_getter_returns_nil_for_unknown
    assert_nil ActiveMail::Tokens.new.color(:does_not_exist)
  end

  def test_to_h_returns_frozen_snapshot
    tokens = ActiveMail::Tokens.new

    assert_predicate tokens.to_h, :frozen?
    assert_predicate tokens.to_h[:color], :frozen?
    assert_raises(FrozenError) { tokens.to_h[:color][:primary] = '#000' }
    # The internal store is untouched by mutating the returned snapshot.
    refute_nil tokens.color(:primary)
  end

  def test_to_scss_emits_prefixed_vars
    scss = ActiveMail::Tokens.new.to_scss

    assert_includes scss, '$am-color-primary:'
    assert_includes scss, '$am-font-body:'
    assert_includes scss, '$am-spacing-md:'
    assert_includes scss, '!default;'
  end

  def test_to_scss_reflects_overrides
    tokens = ActiveMail::Tokens.new
    tokens.color(:primary, '#abcdef')

    assert_includes tokens.to_scss, '$am-color-primary: #abcdef !default;'
  end

  def test_to_scss_underscores_become_dashes
    assert_includes ActiveMail::Tokens.new.to_scss, '$am-color-button-text:'
  end

  def test_radius_group_ships_defaults_and_overrides
    tokens = ActiveMail::Tokens.new

    refute_empty tokens.radius(:button).to_s
    tokens.radius(:button, '6px')

    assert_equal '6px', tokens.radius(:button)
    assert_equal '6px', tokens.radius!(:button)
    assert_raises(KeyError) { tokens.radius!(:does_not_exist) }
  end

  def test_to_scss_emits_radius_vars
    assert_includes ActiveMail::Tokens.new.to_scss, '$am-radius-button:'
    assert_includes ActiveMail::Tokens.new.to_scss, '$am-radius-box:'
  end

  def test_load_bulk_configures_grouped_tokens
    tokens = ActiveMail::Tokens.new
    tokens.load(color: { primary: '#111111', secondary_text: '#222222' }, radius: { button: '6px' })

    assert_equal '#111111', tokens.color(:primary)
    assert_equal '#222222', tokens.color(:secondary_text)
    assert_equal '6px', tokens.radius(:button)
  end

  def test_load_rejects_unknown_group
    assert_raises(KeyError) { ActiveMail::Tokens.new.load(nope: { a: 'b' }) }
  end

  def test_button_style_defaults_to_filled_variant
    style = ActiveMail::Tokens.new.button_style(:primary)

    assert_equal '#2a9d8f', style.background
    assert_equal '#ffffff', style.color
    assert_equal '4px', style.radius
    assert_nil style.border
  end

  def test_button_style_secondary_falls_back_to_button_text_without_outline
    style = ActiveMail::Tokens.new.button_style(:secondary)

    assert_equal '#264653', style.background
    assert_equal '#ffffff', style.color
    assert_nil style.border
  end

  def test_button_style_outline_is_token_driven
    tokens = ActiveMail::Tokens.new
    tokens.load(color: { secondary: '#ffffff', secondary_text: '#0f4447', secondary_border: 'rgba(15, 68, 71, 0.6)' })
    style = tokens.button_style(:secondary)

    assert_equal '#ffffff', style.background
    assert_equal '#0f4447', style.color
    assert_equal 'rgba(15, 68, 71, 0.6)', style.border
  end
end
