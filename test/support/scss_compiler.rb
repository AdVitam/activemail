# frozen_string_literal: true

require 'erb'
require 'tmpdir'
require 'fileutils'
require 'sass-embedded'

# The .scss.erb token bridge is ERB-rendered first, as the asset pipeline would before Sass.
module ScssCompiler
  STYLESHEETS_ROOT = File.expand_path('../../app/assets/stylesheets', __dir__)
  FRAMEWORK_DIR = File.join(STYLESHEETS_ROOT, 'activemail')
  TOKENS_ERB = '_activemail_tokens.scss.erb'

  class DeprecationError < StandardError; end

  # Any Sass warning (deprecation or @warn) is a framework bug, not noise to hide.
  class StrictLogger
    def warn(message, deprecation: false, span: nil, **)
      raise DeprecationError, "#{deprecation ? 'deprecation' : 'warning'}: #{message} #{span}"
    end

    def debug(message, span: nil); end
  end

  module_function

  def compile(source = nil)
    Dir.mktmpdir do |tmp|
      stage(tmp)
      options = { load_paths: [tmp], logger: StrictLogger.new }
      if source
        Sass.compile_string(source, **options).css
      else
        Sass.compile(File.join(tmp, 'activemail', 'activemail.scss'), **options).css
      end
    end
  end

  def stage(tmp)
    dest = File.join(tmp, 'activemail')
    FileUtils.mkdir_p(dest)
    Dir.glob(File.join(FRAMEWORK_DIR, '*')).each do |file|
      next if File.basename(file) == TOKENS_ERB

      FileUtils.cp(file, File.join(dest, File.basename(file)))
    end
    File.write(File.join(dest, '_activemail_tokens.scss'), render_tokens)
  end

  def render_tokens
    ERB.new(File.read(File.join(FRAMEWORK_DIR, TOKENS_ERB))).result(binding)
  end
end
