# typed: strict
# frozen_string_literal: true

require 'nokogiri'
require 'sorbet-runtime'

module ActiveMail
  module Libxml
    extend T::Sig

    UNKNOWN_TAG_CODE = 801

    # The component markup repeats the id of the node it replaces, which libxml2 still has registered.
    ID_REDEFINED_CODE = 513

    # libxml2 < 2.14 reports every non-HTML4 tag as 801 and >= 2.14 never does: unknown tags are detected by name.
    sig { params(errors: T::Array[Nokogiri::XML::SyntaxError]).returns(T::Array[Nokogiri::XML::SyntaxError]) }
    def self.markup_errors(errors)
      errors.reject { |error| error.code == UNKNOWN_TAG_CODE }
    end

    sig { params(name: String).returns(T::Boolean) }
    def self.known_html_tag?(name)
      !Nokogiri::HTML4::ElementDescription[name].nil?
    end
  end
end
