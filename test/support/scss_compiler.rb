# frozen_string_literal: true

require 'erb'
require 'tmpdir'
require 'fileutils'
require 'sass-embedded'

# Compiles the shipped framework SCSS exactly as the asset pipeline would: the
# _activemail_tokens.scss.erb bridge is ERB-rendered first (it reads
# ActiveMail.tokens / config), then dart-sass compiles activemail.scss with the
# app/assets/stylesheets load path. Used by the render-validation harness.
module ScssCompiler
  STYLESHEETS_ROOT = File.expand_path('../../app/assets/stylesheets', __dir__)
  FRAMEWORK_DIR = File.join(STYLESHEETS_ROOT, 'activemail')
  TOKENS_ERB = '_activemail_tokens.scss.erb'

  # Deprecations are dart-sass migration noise (@import, global color funcs) on a
  # framework that intentionally targets the legacy module system — silence them so
  # the harness output stays readable and deterministic.
  SILENCED_DEPRECATIONS = %w[import global-builtin color-functions].freeze

  module_function

  def compile
    Dir.mktmpdir do |tmp|
      dest = File.join(tmp, 'activemail')
      FileUtils.mkdir_p(dest)
      Dir.glob(File.join(FRAMEWORK_DIR, '*')).each do |file|
        next if File.basename(file) == TOKENS_ERB

        FileUtils.cp(file, File.join(dest, File.basename(file)))
      end
      File.write(File.join(dest, '_activemail_tokens.scss'), render_tokens)
      Sass.compile(
        File.join(dest, 'activemail.scss'),
        load_paths: [tmp],
        silence_deprecations: SILENCED_DEPRECATIONS
      ).css
    end
  end

  def render_tokens
    ERB.new(File.read(File.join(FRAMEWORK_DIR, TOKENS_ERB))).result(binding)
  end
end
