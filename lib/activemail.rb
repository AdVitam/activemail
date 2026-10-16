# typed: strict
# frozen_string_literal: true

require 'nokogiri'
require 'securerandom'
require 'sorbet-runtime'

require_relative 'activemail/version'
require_relative 'activemail/errors'
require_relative 'activemail/components/base'
require_relative 'activemail/components/button_renderer'
require_relative 'activemail/components/button'
require_relative 'activemail/components/row'
require_relative 'activemail/components/columns'
require_relative 'activemail/components/container'
require_relative 'activemail/components/block_grid'
require_relative 'activemail/components/menu'
require_relative 'activemail/components/menu_item'
require_relative 'activemail/components/center'
require_relative 'activemail/components/callout'
require_relative 'activemail/components/spacer'
require_relative 'activemail/components/h_line'
require_relative 'activemail/components/wrapper'
require_relative 'activemail/components/cta'
require_relative 'activemail/components/info_box'
require_relative 'activemail/configuration'
require_relative 'activemail/pipeline'
require_relative 'activemail/parse_error_reporter'

module ActiveMail
  class Core
    extend T::Sig

    # Nokogiri cannot parse a bare <th> outside a <tr>; components that emit
    # <th> use this placeholder, swapped back at the end.
    INTERIM_TH_TAG = 'activemail-interim-th'

    # Comment placeholder handed to components as `inner`; the transformed children
    # are moved there without being re-serialized.
    SLOT_TEXT = 'activemail-slot'
    SLOT = "<!--#{SLOT_TEXT}-->".freeze

    # The component markup repeats the id of the node it replaces, which libxml2 still has registered.
    LIBXML_ID_REDEFINED_CODE = 513

    RAW_REGEX = T.let(%r{< *raw *>([\s\S]*?)</ *raw *>}i, Regexp)

    # One pass over the serialized output; <style>/<script> bodies are matched first so they are left alone.
    POSTPROCESS_REGEX = T.let(
      %r{(?<verbatim><(?<tag>style|script)\b[\s\S]*?</\k<tag>\s*>)|(?<=<|</)#{Regexp.escape(INTERIM_TH_TAG)}(?![\w-])|\u00A0}i,
      Regexp
    )

    DEFAULT_COMPONENTS = T.let(
      {
        'button' => ActiveMail::Components::Button,
        'cta' => ActiveMail::Components::Cta,
        'info-box' => ActiveMail::Components::InfoBox,
        'row' => ActiveMail::Components::Row,
        'columns' => ActiveMail::Components::Columns,
        'container' => ActiveMail::Components::Container,
        'block-grid' => ActiveMail::Components::BlockGrid,
        'menu' => ActiveMail::Components::Menu,
        'item' => ActiveMail::Components::MenuItem,
        'center' => ActiveMail::Components::Center,
        'callout' => ActiveMail::Components::Callout,
        'spacer' => ActiveMail::Components::Spacer,
        'h-line' => ActiveMail::Components::HLine,
        'wrapper' => ActiveMail::Components::Wrapper
      }.freeze,
      ActiveMail::ComponentMap
    )

    sig { returns(Integer) }
    attr_reader :column_count, :container_width

    sig do
      params(
        config: ActiveMail::Configuration,
        components: T.untyped,
        column_count: T.untyped,
        container_width: T.untyped
      ).void
    end
    def initialize(config: ::ActiveMail.configuration, components: nil, column_count: nil, container_width: nil)
      @component_instances = T.let(build_components(config, components), T::Hash[String, ActiveMail::Components::Base])
      @column_count = T.let(ActiveMail.positive_integer!(:column_count, column_count || config.column_count), Integer)
      @container_width = T.let(ActiveMail.positive_integer!(:container_width, container_width || config.container_width), Integer)
      @error_reporter = T.let(ParseErrorReporter.new(@component_instances.keys + [INTERIM_TH_TAG]), ParseErrorReporter)
    end

    # Object, not String: ActionView::OutputBuffer is no longer a String since Rails 7.1.
    # Holds no per-call state: the instance is shared across threads.
    sig { params(html_string: Object).returns(String) }
    def transpile(html_string)
      marker = "activemail-raw-#{SecureRandom.hex(8)}-"
      raws = {}
      str = extract_raws(normalize_input(html_string), marker, raws)
      parse_cmd = ::ActiveMail.full_document?(str) ? :parse : :fragment
      html = Nokogiri::HTML.public_send(parse_cmd, str)
      @error_reporter.call(html.errors)
      transform_doc(html)
      re_inject_raws(postprocess(html.to_html), marker, raws)
    end

    private

    sig { returns(T::Hash[String, ActiveMail::Components::Base]) }
    attr_reader :component_instances

    sig { params(node: Nokogiri::XML::Node).void }
    def transform_doc(node)
      node.children.each { |child| transform_doc(child) }
      component = component_instances[node.name]
      replace_with_component(node, component.transform(node, SLOT)) if component
    end

    # Only the component's own markup is parsed; the node's children are moved into
    # its slot, never re-serialized.
    sig { params(node: Nokogiri::XML::Node, markup: String).void }
    def replace_with_component(node, markup)
      fragment = Nokogiri::HTML::DocumentFragment.new(node.document, markup, node)
      @error_reporter.call(fragment.errors.reject { |error| error.code == LIBXML_ID_REDEFINED_CODE })
      slot = fragment.xpath('.//comment()').find { |comment| comment.content == SLOT_TEXT }
      slot&.replace(node.children)
      node.replace(fragment)
    end

    sig { params(string: String, marker: String, raws: T::Hash[String, String]).returns(String) }
    def extract_raws(string, marker, raws)
      # Only the tags + content, across lines: surrounding whitespace is left in
      # place (true pass-through; eating adjacent newlines corrupts <pre>/inline text).
      string.gsub(RAW_REGEX) do
        placeholder = "#{marker}#{raws.size}~"
        raws[placeholder] = T.must(Regexp.last_match(1))
        placeholder
      end
    end

    # U+00A0 is what Nokogiri decodes the nbsp entity to; re-encoded for email clients that mishandle raw NBSP bytes.
    sig { params(string: String).returns(String) }
    def postprocess(string)
      string.gsub(POSTPROCESS_REGEX) do |match|
        next match if Regexp.last_match(:verbatim)

        match == "\u00A0" ? '&nbsp;' : 'th'
      end
    end

    sig { params(string: String, marker: String, raws: T::Hash[String, String]).returns(String) }
    def re_inject_raws(string, marker, raws)
      str = raws.empty? ? string : string.gsub(/#{Regexp.escape(marker)}\d+~/) { |token| raws.fetch(token) }
      str = str.html_safe if str.respond_to?(:html_safe)
      str
    end

    sig { params(config: ActiveMail::Configuration, overrides: T.untyped).returns(T::Hash[String, ActiveMail::Components::Base]) }
    def build_components(config, overrides)
      # Lookup is by node name (String); a Symbol key would never match.
      overrides = (overrides || {}).transform_keys(&:to_s)
      overrides.each { |tag, klass| ActiveMail::Components.validate_component!(tag, klass) }
      DEFAULT_COMPONENTS.merge(config.components).merge(overrides).transform_values { |klass| klass.new(self) }
    end

    sig { params(html_string: Object).returns(String) }
    def normalize_input(html_string)
      html_string = html_string.to_s
      html_string = html_string.dup.force_encoding(Encoding::UTF_8) if html_string.encoding == Encoding::BINARY
      html_string = ::ActiveMail.scrub_invalid_bytes(html_string) unless html_string.valid_encoding?
      html_string
    end
  end
end

if defined?(Rails::Engine)
  require 'activemail/rails/engine'
  require 'activemail/rails/template_handler'
end
