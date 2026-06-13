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
end

class CustomComponent < ActiveMail::Components::Base
  extend T::Sig

  sig { override.params(node: Nokogiri::XML::Node, inner: String).returns(String) }
  def transform(node, inner)
    klass = combine_classes(node, 'custom')
    %(<div class="#{klass}">#{inner}</div>)
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
