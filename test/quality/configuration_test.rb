# frozen_string_literal: true

require_relative 'quality_test_helper'

class QualityConfigurationTest < QualityTest
  def setup
    super
    @config = ActiveMail::Quality::Configuration.new
  end

  def test_defaults
    assert_kind_of ActiveMail::Quality::Guard, @config.guard
    assert_equal 'tmp/activemail_previews', @config.output_dir
    assert_empty @config.required_previews
  end

  # Defaults are set by direct ivar assignment; guard against a future default the
  # validating setters would reject (output_dir must be non-blank, guard a Guard).
  def test_defaults_satisfy_their_own_validation
    config = ActiveMail::Quality::Configuration.new

    assert_kind_of ActiveMail::Quality::Guard, config.guard
    refute_empty config.output_dir.strip
  end

  def test_output_dir_rejects_blank
    assert_raises(ArgumentError) { @config.output_dir = '' }
    assert_raises(ArgumentError) { @config.output_dir = '   ' }
  end

  def test_guard_rejects_a_non_guard
    assert_raises(TypeError) { @config.guard = 'foo' }
  end

  def test_required_previews_coerces_to_strings
    @config.required_previews = [:welcome, 'mailer#hi']

    assert_equal %w[welcome mailer#hi], @config.required_previews
  end

  def test_required_previews_reader_is_frozen
    assert_predicate @config.required_previews, :frozen?
  end

  def test_required_previews_rejects_non_enumerable
    assert_raises(TypeError) { @config.required_previews = 42 }
  end

  def test_module_configure_yields_shared_config
    custom = ActiveMail::Quality::Guard.new(max_bytes: 5)
    ActiveMail::Quality.configure { |c| c.guard = custom }

    assert_same custom, ActiveMail::Quality.config.guard
    assert_same custom, ActiveMail::Quality.guard
  end

  def test_config_setter_rejects_wrong_type
    assert_raises(TypeError) { ActiveMail::Quality.config = Object.new }
  end
end
