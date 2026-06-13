# typed: strict
# frozen_string_literal: true

require 'fileutils'

require_relative '../quality'

module ActiveMail
  module Quality
    # Drives the active_mail:emails:render_all rake task: renders every host
    # preview to disk, runs the Guard on each, and reports. Kept out of the
    # Rakefile so the task block stays thin and the logic is unit-testable.
    class RenderAll
      extend T::Sig

      class Result < T::Struct
        const :rendered, Integer
        const :render_failures, T::Hash[String, String]
        const :guard_failures, T::Hash[String, T::Array[Guard::Violation]]
        const :broken_required, T::Array[String]
      end

      sig { params(output_root: T.any(String, Pathname), config: Configuration).void }
      def initialize(output_root:, config: ActiveMail::Quality.config)
        @output_root = T.let(Pathname(output_root), Pathname)
        @config = T.let(config, Configuration)
      end

      sig { returns(Result) }
      def call
        FileUtils.rm_rf(@output_root)
        FileUtils.mkdir_p(@output_root)

        render_failures = {}
        guard_failures = {}
        rendered = render_all(render_failures, guard_failures)

        required = @config.required_previews
        broken = (render_failures.keys & required) | (guard_failures.keys & required)
        Result.new(rendered: rendered, render_failures: render_failures, guard_failures: guard_failures, broken_required: broken)
      end

      private

      sig do
        params(render_failures: T::Hash[String, String], guard_failures: T::Hash[String, T::Array[Guard::Violation]]).returns(Integer)
      end
      def render_all(render_failures, guard_failures)
        PreviewRenderer.all.count do |preview, email|
          key = "#{preview.preview_name}##{email}"
          path = render_one(preview, email, render_failures, key)
          next false unless path

          violations = @config.guard.violations(File.read(path))
          guard_failures[key] = violations unless violations.empty?
          true
        end
      end

      sig do
        params(preview: T.untyped, email: String, failures: T::Hash[String, String], key: String).returns(T.nilable(Pathname))
      end
      def render_one(preview, email, failures, key)
        PreviewRenderer.render_to_disk(preview, email, @output_root)
      rescue StandardError => e
        failures[key] = "#{e.class} #{e.message}"
        nil
      end
    end
  end
end
