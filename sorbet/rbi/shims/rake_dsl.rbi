# typed: true
# frozen_string_literal: true

# Shim: rake's gem RBI has no signatures, so task bodies would only see T.untyped blocks.

module Rake
  module DSL
    sig { params(description: String).void }
    def desc(description); end

    sig { params(name: T.nilable(T.any(String, Symbol)), block: T.proc.void).returns(Rake::NameSpace) }
    def namespace(name = nil, &block); end

    sig do
      params(
        args: T.untyped,
        block: T.nilable(T.proc.params(task: Rake::Task, args: Rake::TaskArguments).void)
      ).returns(Rake::Task)
    end
    def task(*args, &block); end
  end
end
