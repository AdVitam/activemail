# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'inky/version'

Gem::Specification.new do |s|
  s.name        = 'inky-rb'
  s.version     = Inky::VERSION
  s.summary     = 'Transpiles simple HTML email tags into responsive, email-client-ready table markup.'
  s.description = <<~DESC
    Inky is an HTML-based templating language that converts simple, semantic tags
    (<container>, <row>, <columns>, <button>, <menu>, <callout>...) into the verbose,
    bulletproof table markup required by email clients. v2 generates modern
    fluid-hybrid markup with MSO ghost tables for Outlook, role="presentation" on
    every layout table, and bulletproof buttons. Components are an extensible,
    open/closed registry: register your own tags with full access to the Nokogiri DOM.
  DESC
  s.authors  = %w[Foundation Advitam]
  s.email    = ['contact@get.foundation']
  s.homepage = 'https://github.com/foundation/inky-rb'
  s.licenses = ['MIT']

  s.required_ruby_version = '>= 3.2'

  s.metadata = {
    'homepage_uri' => s.homepage,
    'source_code_uri' => s.homepage,
    'changelog_uri' => "#{s.homepage}/blob/develop/CHANGELOG.md",
    'bug_tracker_uri' => "#{s.homepage}/issues",
    'rubygems_mfa_required' => 'true'
  }

  s.files = Dir['lib/**/*', 'sorbet/**/*', 'LICENSE.txt', 'README.md', 'CHANGELOG.md']
  s.require_paths = ['lib']

  s.add_dependency 'nokogiri', '>= 1.16'
  s.add_dependency 'sorbet-runtime', '>= 0.5'
end
