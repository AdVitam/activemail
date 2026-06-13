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

    # Public extension point: subclass, implement #transform(node, inner), then register.
    class Base
      extend T::Sig
      extend T::Helpers

      abstract!

      IGNORED_ON_PASSTHROUGH = T.let(
        %w[class id href size large no-expander small target up size-sm size-lg style].freeze,
        T::Array[String]
      )

      # Layout tables: presentation role (a11y) and zeroed legacy spacing.
      TABLE_RESET = 'role="presentation" border="0" cellpadding="0" cellspacing="0"'

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

      # Author attributes are untrusted: "abc".to_i would silently become 0.
      sig { params(value: T.untyped).returns(T.nilable(Integer)) }
      def positive_int(value)
        # The RBI types Integer(exception: false) as non-nilable; it does return nil.
        int = T.let(Integer(value.to_s, exception: false), T.nilable(Integer))
        int if int&.positive?
      end

      sig { params(node: Nokogiri::XML::Node).returns(String) }
      def pass_through_attributes(node)
        node.attributes.reject { |name, _| IGNORED_ON_PASSTHROUGH.include?(name.downcase) }.map do |name, value|
          %(#{name}="#{escape_attr(value)}" )
        end.join
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
        !((node.attr('class') || '') =~ /(^|\s)#{Regexp.escape(klass)}($|\s)/).nil?
      end

      sig { params(node: Nokogiri::XML::Node, extra_classes: T.nilable(String)).returns(String) }
      def combine_classes(node, extra_classes)
        existing = node['class'].to_s.split
        to_add = extra_classes.to_s.split
        (existing + to_add).uniq.join(' ')
      end

      sig { params(node: Nokogiri::XML::Node, extra_classes: T.nilable(String)).returns(String) }
      def combine_attributes(node, extra_classes = nil)
        classes = combine_classes(node, extra_classes)
        [pass_through_attributes(node), %(class="#{classes}")].join
      end

      sig { params(node: Nokogiri::XML::Node).returns(String) }
      def target_attribute(node)
        node.attributes['target'] ? %( target="#{escape_attr(node.attributes['target'])}") : ''
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
