# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'

module Inky
  module Components
    # Base class for every Inky component. A component receives the matched
    # Nokogiri node and the owning Core instance, and returns the replacement
    # markup (an HTML String) for that node.
    #
    # Subclasses implement #transform. Helper methods cover the attribute and
    # class manipulation shared by the built-in components, and are available to
    # custom components registered via Inky.configuration.register_component.
    class Base
      extend T::Sig
      extend T::Helpers

      abstract!

      # Attributes consumed by components themselves and never copied onto the
      # generated markup.
      IGNORED_ON_PASSTHROUGH = T.let(
        %w[class id href size large no-expander small target up size-sm size-lg style].freeze,
        T::Array[String]
      )

      sig { params(core: ::Inky::Core).void }
      def initialize(core)
        @core = core
      end

      sig { returns(::Inky::Core) }
      attr_reader :core

      # @param node the matched custom-tag node
      # @param inner the already-transformed inner HTML of the node
      # @return the replacement markup
      sig { abstract.params(node: Nokogiri::XML::Node, inner: String).returns(String) }
      def transform(node, inner); end

      private

      sig { params(node: Nokogiri::XML::Node).returns(String) }
      def pass_through_attributes(node)
        node.attributes.reject { |name, _| IGNORED_ON_PASSTHROUGH.include?(name.downcase) }.map do |name, value|
          %(#{name}="#{value.to_s.gsub('"', '&quot;')}" )
        end.join
      end

      # Merges the author's style after the layout style (a duplicated style
      # attribute would make HTML parsers drop one of the two). Author wins on
      # overlapping properties.
      sig { params(node: Nokogiri::XML::Node, layout: String).returns(String) }
      def style_attribute(node, layout = '')
        user = node.attr('style').to_s.strip
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
        node.attributes['target'] ? %( target="#{node.attributes['target']}") : ''
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
