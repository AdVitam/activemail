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

  def test_output_dir_rejects_paths_that_could_escape_the_root
    ['.', './', '..', '../x', '/tmp/x', 'a/../../b', 'a/..'].each do |value|
      assert_raises(ArgumentError, value) { @config.output_dir = value }
    end
  end

  def test_output_dir_accepts_a_nested_relative_path
    @config.output_dir = 'tmp/previews/out'

    assert_equal 'tmp/previews/out', @config.output_dir
  end

  def test_locales_default_to_the_i18n_default_locale
    assert_equal [I18n.default_locale], @config.locales_for(Object.new)
  end

  def test_locales_accept_a_list_coerced_to_symbols
    @config.locales = %w[fr en]

    assert_equal %i[fr en], @config.locales_for(Object.new)
  end

  def test_locales_accept_a_proc_receiving_the_preview
    @config.locales = ->(preview) { preview == :multi ? %i[fr en] : [:fr] }

    assert_equal %i[fr en], @config.locales_for(:multi)
    assert_equal [:fr], @config.locales_for(:single)
  end

  def test_locales_reject_invalid_values
    assert_raises(TypeError) { @config.locales = :fr }
    assert_raises(ArgumentError) { @config.locales = [] }
    @config.locales = ->(_preview) { [] }
    assert_raises(ArgumentError) { @config.locales_for(Object.new) }
  end

  def test_formats_default_to_html_and_text
    assert_equal %i[html text], @config.formats
  end

  def test_formats_accept_a_subset
    @config.formats = %w[text]

    assert_equal [:text], @config.formats
  end

  def test_formats_reject_unknown_or_empty
    assert_raises(ArgumentError) { @config.formats = [:pdf] }
    assert_raises(ArgumentError) { @config.formats = [] }
    assert_raises(TypeError) { @config.formats = :html }
  end

  def test_around_each_accepts_a_proc_or_nil
    hook = ->(_preview, _email, _locale, &block) { block.call }
    @config.around_each = hook

    assert_same hook, @config.around_each
    @config.around_each = nil
    assert_nil @config.around_each
    assert_raises(TypeError) { @config.around_each = 'nope' }
  end

  def test_output_filters_normalize_procs_and_regexp_pairs
    @config.output_filters = [[/\d+/, '<n>'], :upcase.to_proc]

    assert_equal 'A<N>', @config.output_filters.reduce('a12') { |acc, filter| filter.call(acc) }
    assert_equal '<n>', @config.output_filters.first.call('42')
  end

  def test_output_filters_reject_invalid_entries
    assert_raises(TypeError) { @config.output_filters = 'x' }
    assert_raises(TypeError) { @config.output_filters = ['x'] }
    assert_raises(TypeError) { @config.output_filters = [%w[x y]] }
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

  def test_allow_declined_coerces_to_strings_and_is_frozen
    assert_empty @config.allow_declined
    @config.allow_declined = [:skipped, 'mailer#hi']

    assert_equal %w[skipped mailer#hi], @config.allow_declined
    assert_predicate @config.allow_declined, :frozen?
    assert @config.allow_declined?('mailer#hi')
    refute @config.allow_declined?('mailer#other')
  end

  def test_allow_declined_rejects_non_enumerable
    assert_raises(TypeError) { @config.allow_declined = 42 }
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
