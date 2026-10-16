# typed: strict
# frozen_string_literal: true

module ActiveMail
  class Error < StandardError; end

  class ParseError < Error; end

  class StylesheetNotFound < Error; end

  module Inliner
    # The adapter's original exception is preserved as Exception#cause.
    class Error < ActiveMail::Error; end
  end
end
