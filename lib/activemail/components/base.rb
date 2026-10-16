# typed: strict
# frozen_string_literal: true

require 'cgi/escape'
require 'sorbet-runtime'

module ActiveMail
  module Components
    class << self
      extend T::Sig

      # A non-class (e.g. a tag-name string) would NoMethodError downstream; reject it here.
      sig { params(tag: T.any(String, Symbol), klass: T.untyped).void }
      def validate_component!(tag, klass)
        return if klass.is_a?(Class) && klass < Components::Base

        raise TypeError,
              "component for tag '#{tag}' must be a class inheriting from ActiveMail::Components::Base, " \
              "got #{klass.inspect}. Register components with " \
              'ActiveMail.configuration.register_component(tag, ComponentClass).'
      end
    end

    # `inner` is an opaque slot: interpolate it exactly once; the engine moves the
    # already transformed children there.
    class Base
      extend T::Sig
      extend T::Helpers

      abstract!

      HANDLED_ATTRIBUTES = T.let(%w[class style].freeze, T::Array[String])
      LINK_ATTRIBUTES = T.let(%w[href target rel].freeze, T::Array[String])

      # Layout tables: presentation role (a11y) and zeroed legacy spacing.
      TABLE_RESET = 'role="presentation" border="0" cellpadding="0" cellspacing="0"'
      TABLE_RESET_ATTRIBUTES = T.let(%w[role border cellpadding cellspacing].freeze, T::Array[String])

      sig { params(core: ::ActiveMail::Core).void }
      def initialize(core)
        @core = core
      end

      sig { abstract.params(node: Nokogiri::XML::Node, inner: String).returns(String) }
      def transform(node, inner); end

      private

      # Private: a component is a pure transformer; the engine handle stays internal.
      sig { returns(::ActiveMail::Core) }
      attr_reader :core

      sig { params(value: T.untyped).returns(String) }
      def escape_attr(value)
        CGI.escapeHTML(value.to_s)
      end

      sig { params(value: T.untyped).returns(T.nilable(Integer)) }
      def positive_int(value)
        ActiveMail.parse_positive_integer(value)
      end

      sig { overridable.returns(T::Array[String]) }
      def consumed_attributes
        []
      end

      sig do
        params(node: Nokogiri::XML::Node, classes: T.nilable(String), layout_style: String, skip: T::Array[String]).returns(String)
      end
      def root_attributes(node, classes:, layout_style: '', skip: [])
        "#{class_attribute(node, classes)}#{passthrough_attributes(node, skip)}#{style_attribute(node, layout_style)}"
      end

      sig { params(node: Nokogiri::XML::Node, classes: T.nilable(String)).returns(String) }
      def class_attribute(node, classes)
        merged = combine_classes(node, classes)
        merged.empty? ? '' : %( class="#{escape_attr(merged)}")
      end

      sig { params(node: Nokogiri::XML::Node, skip: T::Array[String]).returns(String) }
      def passthrough_attributes(node, skip = [])
        reserved = HANDLED_ATTRIBUTES + consumed_attributes + skip
        node.attributes.except(*reserved).map { |name, attr| %( #{name}="#{escape_attr(attr.value)}") }.join
      end

      # Author style merged after layout (a duplicated style attribute would be
      # dropped by parsers); author wins on overlapping properties.
      sig { params(node: Nokogiri::XML::Node, layout: String).returns(String) }
      def style_attribute(node, layout = '')
        user = escape_attr(node.attr('style').to_s.strip)
        user = "#{user};" unless user.empty? || user.end_with?(';')
        value = "#{layout}#{user}"
        value.empty? ? '' : %( style="#{value}")
      end

      sig { params(node: Nokogiri::XML::Node, klass: String).returns(T::Boolean) }
      def class?(node, klass)
        node['class'].to_s.split.include?(klass)
      end

      sig { params(node: Nokogiri::XML::Node, extra_classes: T.nilable(String)).returns(String) }
      def combine_classes(node, extra_classes)
        existing = node['class'].to_s.split
        to_add = extra_classes.to_s.split
        (existing + to_add).uniq.join(' ')
      end

      sig { params(node: Nokogiri::XML::Node).returns(String) }
      def link_attributes(node)
        target = node.attributes['target']&.value
        rel = resolve_rel(node, target)
        [
          target ? %( target="#{escape_attr(target)}") : '',
          rel ? %( rel="#{escape_attr(rel)}") : ''
        ].join
      end

      sig { params(node: Nokogiri::XML::Node, inner: String, before: String, after: String).returns(String) }
      def anchor(node, inner, before: '', after: '')
        %(<a#{before} href="#{escape_attr(node.attr('href'))}"#{link_attributes(node)}#{after}>#{inner}</a>)
      end

      sig { params(node: Nokogiri::XML::Node, target: T.nilable(String)).returns(T.nilable(String)) }
      def resolve_rel(node, target)
        rel = node.attributes['rel']&.value
        rel = nil if rel&.strip&.empty?
        rel || (core.config.blank_link_rel if target == '_blank')
      end

      sig { returns(Integer) }
      def column_count
        core.column_count
      end

      sig { returns(Integer) }
      def container_width
        core.container_width
      end
    end
  end
end
