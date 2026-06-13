# typed: strong
# frozen_string_literal: true

# Minimal shim: roadie is an optional adapter, not a hard dependency, so its
# gem RBI is not generated. Only the surface the adapter touches is declared.
module Roadie
  class Document
    sig { params(html: String).void }
    def initialize(html); end

    sig { returns(String) }
    def transform; end
  end
end
