# frozen_string_literal: true

require 'test_helper'

class ConfigurationTest < ActiveMailTest
  def test_defaults
    config = ActiveMail::Configuration.new

    assert_equal :erb, config.template_engine
    assert_equal 12, config.column_count
    assert_equal 600, config.container_width
    assert_empty config.components
  end

  def test_template_engine_setter_coerces_to_symbol
    config = ActiveMail::Configuration.new
    config.template_engine = 'slim'

    assert_equal :slim, config.template_engine
  end

  def test_template_engine_setter_rejects_invalid
    config = ActiveMail::Configuration.new

    assert_raises(TypeError) { config.template_engine = [] }
  end

  def test_column_count_setter_rejects_invalid
    config = ActiveMail::Configuration.new

    assert_raises(TypeError) { config.column_count = :nope }
  end

  def test_container_width_setter
    config = ActiveMail::Configuration.new
    config.container_width = 480

    assert_equal 480, config.container_width
  end

  def test_container_width_setter_rejects_invalid
    config = ActiveMail::Configuration.new

    assert_raises(TypeError) { config.container_width = :nope }
  end

  def test_setters_reject_non_positive_dimensions
    config = ActiveMail::Configuration.new

    assert_raises(ArgumentError) { config.column_count = 0 }
    assert_raises(ArgumentError) { config.column_count = -3 }
    assert_raises(ArgumentError) { config.container_width = 0 }
    assert_equal 12, config.column_count
    assert_equal 600, config.container_width
  end

  def test_dimension_setters_reject_floats_instead_of_truncating
    config = ActiveMail::Configuration.new

    assert_raises(TypeError) { config.column_count = 12.9 }
    assert_equal 12, config.column_count
  end

  def test_constructor_rejects_non_positive_dimensions
    assert_raises(ArgumentError) { ActiveMail::Core.new(column_count: 0) }
    assert_raises(ArgumentError) { ActiveMail::Core.new(container_width: -1) }
  end

  def test_columns_render_with_valid_constructor_dimensions
    output = render('<columns>x</columns>', column_count: 10, container_width: 500)

    assert_includes output, 'small-10 large-10'
    assert_includes output, 'max-width:500px'
  end

  def test_configuration_assignment_rejects_non_configuration
    assert_raises(TypeError) { ActiveMail.configuration = {} }
  end

  def test_configure_block_yields_configuration
    ActiveMail.configure { |c| c.column_count = 16 }

    assert_equal 16, ActiveMail.configuration.column_count
  end

  def test_default_inliner_is_premailer
    assert_instance_of ActiveMail::Inliner::Premailer, ActiveMail::Configuration.new.resolved_inliner
  end

  def test_resolved_inliner_maps_symbols
    config = ActiveMail::Configuration.new

    config.inliner = :null

    assert_instance_of ActiveMail::Inliner::Null, config.resolved_inliner

    config.inliner = :premailer

    assert_instance_of ActiveMail::Inliner::Premailer, config.resolved_inliner
  end

  def test_resolved_inliner_passes_instance_through
    config = ActiveMail::Configuration.new
    instance = ActiveMail::Inliner::Null.new
    config.inliner = instance

    assert_same instance, config.resolved_inliner
  end

  def test_resolved_inliner_is_memoized_until_reassigned
    config = ActiveMail::Configuration.new
    config.inliner = :premailer
    first = config.resolved_inliner

    assert_same first, config.resolved_inliner

    config.inliner = :null
    refute_same first, config.resolved_inliner
    assert_instance_of ActiveMail::Inliner::Null, config.resolved_inliner
  end

  def test_resolved_inliner_instantiates_a_class
    config = ActiveMail::Configuration.new
    config.inliner = ActiveMail::Inliner::Null

    assert_instance_of ActiveMail::Inliner::Null, config.resolved_inliner
  end

  def test_inliner_setter_coerces_string_to_symbol
    config = ActiveMail::Configuration.new
    config.inliner = 'null'

    assert_instance_of ActiveMail::Inliner::Null, config.resolved_inliner
  end

  def test_inliner_setter_rejects_unknown_symbol_eagerly
    config = ActiveMail::Configuration.new

    assert_raises(ArgumentError) { config.inliner = :nope }
  end

  def test_register_inline_interceptor_defaults_true
    assert ActiveMail::Configuration.new.register_inline_interceptor
  end

  # The defaults are set by direct ivar assignment (bypassing the validating
  # setters); this guards against a future default that those setters would reject.
  def test_defaults_satisfy_their_own_validation
    config = ActiveMail::Configuration.new

    assert_kind_of ActiveMail::Inliner::Base, config.resolved_inliner
    assert_includes ActiveMail::Configuration::ON_PARSE_ERROR_MODES, config.on_parse_error
    assert_operator config.column_count, :>, 0
    assert_operator config.container_width, :>, 0
    assert_includes [true, false], config.register_inline_interceptor
    assert_respond_to config.template_engine, :to_sym
  end

  def test_register_inline_interceptor_rejects_non_boolean
    config = ActiveMail::Configuration.new

    assert_raises(TypeError) { config.register_inline_interceptor = 'yes' }
    config.register_inline_interceptor = false
    refute config.register_inline_interceptor
  end

  def test_tokens_is_memoized
    config = ActiveMail::Configuration.new
    tokens = config.tokens

    assert_same tokens, config.tokens
  end

  def test_top_level_tokens_delegates_to_configuration
    tokens = ActiveMail.configuration.tokens

    assert_same tokens, ActiveMail.tokens
  end
end

class RegistryTest < ActiveMailTest
  def test_register_component_adds_a_tag
    ActiveMail.configuration.register_component('my-box', CustomComponent)
    output = render('<my-box class="x">hi</my-box>')

    assert_includes output, '<div class="x custom">hi</div>'
  end

  def test_register_component_rejects_non_base_classes
    assert_raises(TypeError) { ActiveMail.configuration.register_component('bad', String) }
  end

  def test_components_setter_rejects_1x_string_values
    assert_raises(TypeError) { ActiveMail.configuration.components = { button: 'inky-button' } }
    assert_empty ActiveMail.configuration.components
  end

  def test_constructor_components_option_rejects_1x_string_values
    assert_raises(TypeError) { ActiveMail::Core.new(components: { button: 'inky-button' }) }
  end

  def test_components_getter_cannot_be_mutated_to_bypass_validation
    assert_raises(FrozenError) { ActiveMail.configuration.components['x'] = String }
    assert_empty ActiveMail.configuration.components
    assert_includes render('<button href="#">B</button>'), 'class="button"'
  end

  def test_constructor_components_option_overrides_registry
    output = render('<button href="#">B</button>', components: { 'button' => CustomComponent })

    assert_includes output, '<div class="custom">'
    refute_includes output, 'class="button"'
  end

  def test_constructor_components_option_accepts_symbol_keys
    output = render('<button href="#">B</button>', components: { button: CustomComponent })

    assert_includes output, '<div class="custom">'
    refute_includes output, 'class="button"'
  end

  def test_components_setter_normalizes_symbol_keys
    ActiveMail.configuration.components = { button: CustomComponent }

    assert_equal({ 'button' => CustomComponent }, ActiveMail.configuration.components)
    assert_includes render('<button href="#">B</button>'), '<div class="custom">'
  end

  def test_register_component_accepts_symbol_tags
    ActiveMail.configuration.register_component(:'my-box', CustomComponent)

    assert_includes render('<my-box>hi</my-box>'), '<div class="custom">hi</div>'
  end

  def test_custom_component_has_dom_access
    counter = Class.new(ActiveMail::Components::Base) do
      def transform(node, _inner)
        "<span>#{node.elements.size}</span>"
      end
    end
    output = render('<count><a></a><b></b></count>', components: { 'count' => counter })

    assert_includes output, '<span>2</span>'
  end
end
