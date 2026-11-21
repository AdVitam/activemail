# typed: strict
# frozen_string_literal: true

require 'sorbet-runtime'

require_relative 'libxml'

module ActiveMail
  class UnknownTagCollector
    extend T::Sig

    sig { params(ignored_names: T::Array[String]).void }
    def initialize(ignored_names)
      @ignored_names = T.let(ignored_names.to_set, T::Set[String])
      @unknown = T.let(Set.new, T::Set[String])
    end

    sig { params(node: Nokogiri::XML::Node).void }
    def collect(node)
      return unless node.element?

      name = node.name
      return if @ignored_names.include?(name)

      @unknown << name unless Libxml.known_html_tag?(name)
    end

    sig { returns(T::Array[String]) }
    def names
      @unknown.to_a
    end
  end
end
