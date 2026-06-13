# typed: strong
# frozen_string_literal: true

# Hand-written shim: premailer loads its API lazily, so `tapioca gem premailer`
# produces an empty RBI. Only the surface the adapter touches is declared.
class Premailer
  sig { params(html: String, options: T.untyped).void }
  def initialize(html, **options); end

  sig { returns(String) }
  def to_inline_css; end

  module Warnings
    NONE = 0
  end
end
