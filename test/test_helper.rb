# frozen_string_literal: true

require 'minitest/autorun'
require 'inky'

module InkyTestHelpers
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
    Inky::Core.new(options).release_the_kraken(input)
  end

  def assert_renders(input, expected, **)
    assert_same_html(expected, render(input, **))
  end
end

class InkyTest < Minitest::Test
  include InkyTestHelpers

  def setup
    @default_config = Inky.configuration
    Inky.configuration = Inky::Configuration.new
  end

  def teardown
    Inky.configuration = @default_config
  end
end
