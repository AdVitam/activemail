# frozen_string_literal: true

require 'minitest/autorun'
require 'activemail'

module ActiveMailTestHelpers
  # Normalize generated and expected HTML so comparisons ignore insignificant
  # whitespace, attribute ordering, and class ordering.
  def reformat_html(html)
    html
      .gsub(/\s+/, ' ')
      .gsub(/> *</, ">\n<")
      .gsub(%r{<(\w+)([^>]*)>\n</\1>}, '<\1\2/>')
      .gsub(' "', '"').gsub('=" ', '="')
      .gsub(' <', '<').gsub('> ', '>')
      .gsub(/(align="[^"]+") (class="[^"]+")/, '\2 \1')
      .gsub(/class="([^"]+)"/) { %(class="#{::Regexp.last_match(1).split.sort.join(' ')}") }
      .strip
  end

  def assert_same_html(expected, actual)
    assert_equal reformat_html(expected), reformat_html(actual)
  end

  def render(input, **options)
    ActiveMail::Core.new(options).transpile(input)
  end

  def assert_renders(input, expected, **)
    assert_same_html(expected, render(input, **))
  end
end

# Shared fixture: a minimal custom component used across several test files.
class CustomComponent < ActiveMail::Components::Base
  extend T::Sig

  sig { override.params(node: Nokogiri::XML::Node, inner: String).returns(String) }
  def transform(node, inner)
    klass = combine_classes(node, 'custom')
    %(<div class="#{klass}">#{inner}</div>)
  end
end

class ActiveMailTest < Minitest::Test
  include ActiveMailTestHelpers

  def setup
    @default_config = ActiveMail.configuration
    ActiveMail.configuration = ActiveMail::Configuration.new
  end

  def teardown
    ActiveMail.configuration = @default_config
  end
end
