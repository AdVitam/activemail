# frozen_string_literal: true

require 'test_helper'

class ConfigurationTest < InkyTest
  def test_defaults
    config = Inky::Configuration.new

    assert_equal :erb, config.template_engine
    assert_equal 12, config.column_count
    assert_equal 600, config.container_width
    assert_empty config.components
  end

  def test_template_engine_setter_coerces_to_symbol
    config = Inky::Configuration.new
    config.template_engine = 'slim'

    assert_equal :slim, config.template_engine
  end

  def test_template_engine_setter_rejects_invalid
    config = Inky::Configuration.new

    assert_raises(TypeError) { config.template_engine = [] }
  end

  def test_column_count_setter_rejects_invalid
    config = Inky::Configuration.new

    assert_raises(TypeError) { config.column_count = :nope }
  end

  def test_container_width_setter
    config = Inky::Configuration.new
    config.container_width = 480

    assert_equal 480, config.container_width
  end

  def test_container_width_setter_rejects_invalid
    config = Inky::Configuration.new

    assert_raises(TypeError) { config.container_width = :nope }
  end

  def test_configuration_assignment_rejects_non_configuration
    assert_raises(TypeError) { Inky.configuration = {} }
  end

  def test_configure_block_yields_configuration
    Inky.configure { |c| c.column_count = 16 }

    assert_equal 16, Inky.configuration.column_count
  end
end

class CustomComponent < Inky::Components::Base
  extend T::Sig

  sig { override.params(node: Nokogiri::XML::Node, inner: String).returns(String) }
  def transform(node, inner)
    klass = combine_classes(node, 'custom')
    %(<div class="#{klass}">#{inner}</div>)
  end
end

class RegistryTest < InkyTest
  def test_register_component_adds_a_tag
    Inky.configuration.register_component('my-box', CustomComponent)
    output = render('<my-box class="x">hi</my-box>')

    assert_includes output, '<div class="x custom">hi</div>'
  end

  def test_register_component_rejects_non_base_classes
    assert_raises(TypeError) { Inky.configuration.register_component('bad', String) }
  end

  def test_components_setter_rejects_1x_string_values
    assert_raises(TypeError) { Inky.configuration.components = { button: 'inky-button' } }
    assert_empty Inky.configuration.components
  end

  def test_constructor_components_option_rejects_1x_string_values
    assert_raises(TypeError) { Inky::Core.new(components: { button: 'inky-button' }) }
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
    Inky.configuration.components = { button: CustomComponent }

    assert_equal({ 'button' => CustomComponent }, Inky.configuration.components)
    assert_includes render('<button href="#">B</button>'), '<div class="custom">'
  end

  def test_register_component_accepts_symbol_tags
    Inky.configuration.register_component(:'my-box', CustomComponent)

    assert_includes render('<my-box>hi</my-box>'), '<div class="custom">hi</div>'
  end

  def test_custom_component_has_dom_access
    counter = Class.new(Inky::Components::Base) do
      def transform(node, _inner)
        "<span>#{node.elements.size}</span>"
      end
    end
    output = render('<count><a></a><b></b></count>', components: { 'count' => counter })

    assert_includes output, '<span>2</span>'
  end
end
