# typed: strict
# frozen_string_literal: true

require 'nokogiri'
require 'sorbet-runtime'

require_relative 'active_mail/version'
require_relative 'active_mail/components/base'
require_relative 'active_mail/components/button'
require_relative 'active_mail/components/row'
require_relative 'active_mail/components/columns'
require_relative 'active_mail/components/container'
require_relative 'active_mail/components/inky'
require_relative 'active_mail/components/block_grid'
require_relative 'active_mail/components/menu'
require_relative 'active_mail/components/menu_item'
require_relative 'active_mail/components/center'
require_relative 'active_mail/components/callout'
require_relative 'active_mail/components/spacer'
require_relative 'active_mail/components/h_line'
require_relative 'active_mail/components/wrapper'
require_relative 'active_mail/components/cta'
require_relative 'active_mail/components/info_box'
require_relative 'active_mail/configuration'
require_relative 'active_mail/inliner/interceptor'
require_relative 'active_mail/parse_error_reporter'

module ActiveMail
  class ParseError < StandardError; end

  class Core
    extend T::Sig

    # Nokogiri cannot parse a bare <th> outside a <tr>; components that emit
    # <th> use this placeholder, swapped back at the end.
    INTERIM_TH_TAG = 'active-mail-interim-th'
    INTERIM_TH_TAG_REGEX = T.let(%r{(?<=<|</)#{Regexp.escape(INTERIM_TH_TAG)}}, Regexp)

    DEFAULT_COMPONENTS = T.let(
      {
        'button' => ActiveMail::Components::Button,
        'row' => ActiveMail::Components::Row,
        'columns' => ActiveMail::Components::Columns,
        'container' => ActiveMail::Components::Container,
        'inky' => ActiveMail::Components::Inky,
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
    attr_reader :column_count

    sig { returns(Integer) }
    attr_reader :container_width

    sig { returns(T::Hash[String, ActiveMail::Components::Base]) }
    attr_reader :component_instances

    sig { params(options: T::Hash[Symbol, T.untyped]).void }
    def initialize(options = {})
      config = ::ActiveMail.configuration
      @component_instances = T.let(build_components(config, options[:components]), T::Hash[String, ActiveMail::Components::Base])
      @column_count = T.let(ActiveMail.assert_positive_dimension!(:column_count, options[:column_count] || config.column_count), Integer)
      @container_width = T.let(ActiveMail.assert_positive_dimension!(:container_width, options[:container_width] || config.container_width), Integer)
    end

    # Object, not String: ActionView::OutputBuffer is no longer a String since Rails 7.1.
    sig { params(html_string: Object).returns(String) }
    def release_the_kraken(html_string)
      raws, str = ActiveMail::Core.extract_raws(normalize_input(html_string))
      parse_cmd = str =~ /<html/i ? :parse : :fragment
      html = Nokogiri::HTML.public_send(parse_cmd, str)
      ParseErrorReporter.new(component_instances.keys).call(html.errors)
      transform_doc(html)
      string = html.to_html
      string = string.gsub(INTERIM_TH_TAG_REGEX, 'th')
      # Needle is a literal U+00A0 (Nokogiri decodes the nbsp entity to one); re-encode
      # it to the entity for email clients that mishandle raw NBSP bytes.
      string = string.gsub(' ', '&nbsp;')
      ActiveMail::Core.re_inject_raws(string, raws)
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
      component = component_instances[node.name]
      return unless component

      # Nokogiri::NodeSet has no #join; map to String first.
      inner = node.children.map(&:to_s).join # rubocop:disable Style/MapJoin
      component.transform(node, inner)
    end

    sig { params(string: String).returns([T::Array[String], String]) }
    def self.extract_raws(string)
      raws = []
      i = 0
      # Captures everything between non-nested raw tags, across lines.
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
      # scrub: invalid bytes (whatever the claimed encoding) degrade
      # deterministically to U+FFFD instead of raising on the first gsub.
      html_string = html_string.scrub unless html_string.valid_encoding?
      html_string.gsub(/doctype/i, 'DOCTYPE')
    end
  end
end

if defined?(Rails::Engine)
  require 'active_mail/rails/engine'
  require 'active_mail/rails/template_handler'
end
