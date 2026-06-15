# frozen_string_literal: true

require 'test_helper'
require 'zeitwerk'

# Ruby files under app/ are autoloaded by the host application's Zeitwerk loader,
# which uses the default inflector. A directory named `activemail` would resolve
# to the constant `Activemail`, not `ActiveMail` — so every such file must live
# under a path the default inflector camelizes back to its declared namespace,
# or the engine's `helper ActiveMail::StylesHelper` raises NameError at boot.
class AutoloadPathsTest < ActiveMailTest
  ROOT = File.expand_path('../..', __dir__)
  INFLECTOR = Zeitwerk::Inflector.new

  def test_app_ruby_files_match_zeitwerk_default_inflection
    Dir.glob(File.join(ROOT, 'app', '*', '**', '*.rb')).each do |path|
      require path

      # app/<kind>/<autoload-root>/... — the autoload root is the segment after
      # the kind dir (e.g. app/helpers/active_mail/styles_helper.rb).
      relative = path.sub(%r{\A#{Regexp.escape(ROOT)}/app/[^/]+/}, '')
      expected = relative.sub(/\.rb\z/, '').split('/').map { |s| INFLECTOR.camelize(s, nil) }.join('::')

      assert defined_constant?(expected),
             "#{path} autoloads to ::#{expected} under Zeitwerk's default inflector, " \
             'but that constant is not defined'
    end
  end

  private

  def defined_constant?(name)
    name.split('::').reduce(Object) do |mod, const|
      return false unless mod.const_defined?(const, false)

      mod.const_get(const, false)
    end
    true
  rescue NameError
    false
  end
end
