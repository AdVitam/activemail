# typed: strict
# frozen_string_literal: true

require 'nokogiri'
require 'sorbet-runtime'

require_relative 'inky/version'
require_relative 'inky/components/base'
require_relative 'inky/components/button'
require_relative 'inky/components/row'
require_relative 'inky/components/columns'
require_relative 'inky/components/container'
require_relative 'inky/components/inky'
require_relative 'inky/components/block_grid'
require_relative 'inky/components/menu'
require_relative 'inky/components/menu_item'
require_relative 'inky/components/center'
require_relative 'inky/components/callout'
require_relative 'inky/components/spacer'
require_relative 'inky/components/h_line'
require_relative 'inky/components/wrapper'
require_relative 'inky/configuration'
require_relative 'inky/parse_error_reporter'

module Inky
  class ParseError < StandardError; end

  class Core
    extend T::Sig

    # Used to circumvent a Nokogiri limitation: a bare <th> cannot live outside a
    # <tr>, so components that emit <th> use this placeholder, swapped back at the
    # end. See https://github.com/zurb/inky-rb/pull/94
    INTERIM_TH_TAG = 'inky-interim-th'
    INTERIM_TH_TAG_REGEX = T.let(%r{(?<=<|</)#{Regexp.escape(INTERIM_TH_TAG)}}, Regexp)

    DEFAULT_COMPONENTS = T.let(
      {
        'button' => Inky::Components::Button,
        'row' => Inky::Components::Row,
        'columns' => Inky::Components::Columns,
        'container' => Inky::Components::Container,
        'inky' => Inky::Components::Inky,
        'block-grid' => Inky::Components::BlockGrid,
        'menu' => Inky::Components::Menu,
        'item' => Inky::Components::MenuItem,
        'center' => Inky::Components::Center,
        'callout' => Inky::Components::Callout,
        'spacer' => Inky::Components::Spacer,
        'h-line' => Inky::Components::HLine,
        'wrapper' => Inky::Components::Wrapper
      }.freeze,
      Inky::ComponentMap
    )

    sig { returns(Integer) }
    attr_reader :column_count

    sig { returns(Integer) }
    attr_reader :container_width

    sig { returns(T::Hash[String, Inky::Components::Base]) }
    attr_reader :components

    sig { params(options: T::Hash[Symbol, T.untyped]).void }
    def initialize(options = {})
      config = ::Inky.configuration
      @components = T.let(build_components(config, options[:components]), T::Hash[String, Inky::Components::Base])
      @column_count = T.let((options[:column_count] || config.column_count).to_i, Integer)
      @container_width = T.let((options[:container_width] || config.container_width).to_i, Integer)
    end

    sig { params(html_string: T.untyped).returns(String) }
    def release_the_kraken(html_string)
      raws, str = Inky::Core.extract_raws(normalize_input(html_string))
      parse_cmd = str =~ /<html/i ? :parse : :fragment
      html = Nokogiri::HTML.public_send(parse_cmd, str)
      ParseErrorReporter.new(components.keys).call(html.errors)
      transform_doc(html)
      string = html.to_html
      string = string.gsub(INTERIM_TH_TAG_REGEX, 'th')
      string = string.gsub(' ', '&nbsp;')
      Inky::Core.re_inject_raws(string, raws)
    end

    sig { params(elem: Nokogiri::XML::Node).returns(Nokogiri::XML::Node) }
    def transform_doc(elem)
      if elem.respond_to?(:children)
        elem.children.each { |child| transform_doc(child) }
        markup = component_factory(elem)
        elem.replace(markup) if markup
      end
      elem
    end

    sig { params(node: Nokogiri::XML::Node).returns(T.nilable(String)) }
    def component_factory(node)
      component = components[node.name]
      return unless component

      # Nokogiri::NodeSet has no #join; map to String first.
      inner = node.children.map(&:to_s).join # rubocop:disable Style/MapJoin
      component.transform(node, inner)
    end

    sig { params(string: String).returns([T::Array[String], String]) }
    def self.extract_raws(string)
      raws = []
      i = 0
      # Multi-line aware (PR #101): captures everything between non-nested raw tags.
      regex = %r{(?:\n *)?< *raw *>([\s\S]*?)</ *raw *>(?: *\n)?}i
      str = string
      while (raw = str.match(regex))
        raws[i] = T.must(raw[1])
        str = str.sub(regex, "###RAW#{i}###")
        i += 1
      end
      [raws, str]
    end

    sig { params(string: String, raws: T::Array[String]).returns(String) }
    def self.re_inject_raws(string, raws)
      str = string
      raws.each_with_index do |val, i|
        # Block form: the 2-arg String#sub would expand \0/\1/\& in val.
        str = str.sub("###RAW#{i}###") { val }
      end
      str = str.html_safe if str.respond_to?(:html_safe)
      str
    end

    private

    sig { params(config: Inky::Configuration, overrides: T.untyped).returns(T::Hash[String, Inky::Components::Base]) }
    def build_components(config, overrides)
      # Lookup is by node name (String); 1.x callers used Symbol keys.
      overrides = (overrides || {}).transform_keys(&:to_s)
      overrides.each { |tag, klass| Inky::Components.validate_component!(tag, klass) }
      DEFAULT_COMPONENTS.merge(config.components).merge(overrides).transform_values { |klass| klass.new(self) }
    end

    sig { params(html_string: T.untyped).returns(String) }
    def normalize_input(html_string)
      html_string = html_string.to_s
      # scrub: invalid bytes degrade deterministically (U+FFFD) instead of
      # whatever the Nokogiri version at hand does with an invalid String.
      html_string = html_string.dup.force_encoding(Encoding::UTF_8).scrub if html_string.encoding == Encoding::BINARY
      html_string.gsub(/doctype/i, 'DOCTYPE')
    end
  end
end

if defined?(Rails::Engine)
  require 'inky/rails/engine'
  require 'inky/rails/template_handler'
  require 'inky/rails/version'
end
