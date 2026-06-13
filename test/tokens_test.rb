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

  def test_strict_color_reader_raises_on_unknown_key
    tokens = ActiveMail::Tokens.new

    assert_equal tokens.color(:primary), tokens.color!(:primary)
    assert_raises(KeyError) { tokens.color!(:does_not_exist) }
  end

  def test_setter_accepts_string_name
    tokens = ActiveMail::Tokens.new
    tokens.spacing('md', '20px')

    assert_equal '20px', tokens.spacing(:md)
  end

  def test_getter_returns_nil_for_unknown
    assert_nil ActiveMail::Tokens.new.color(:does_not_exist)
  end

  def test_readers_return_frozen_dup
    tokens = ActiveMail::Tokens.new

    assert_predicate tokens.colors, :frozen?
    assert_raises(FrozenError) { tokens.colors[:primary] = '#000' }
    # The internal store is untouched by mutating the returned hash.
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
end
