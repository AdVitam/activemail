# typed: strong
# frozen_string_literal: true

# Hand-written shims for symbols the opt-in quality layer references but that
# live in the HOST app (ActionMailer previews) or an optional test dependency
# (RSpec). Neither is a hard gem dependency, so no gem RBI is generated.

module ActionMailer
  class Preview
    class << self
      sig { returns(T::Array[T.untyped]) }
      def all; end
    end
  end
end

module RSpec
  module Matchers; end
end
