# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'activemail/version'

Gem::Specification.new do |s|
  s.name        = 'activemail'
  s.version     = ActiveMail::VERSION
  s.summary     = 'Plug & play gem to send modern emails, entirely in Ruby, with dark mode and more out of the box.'
  s.description = <<~DESC
    ActiveMail is a plug & play gem for sending beautiful emails, written entirely in Ruby.
    It turns simple, semantic tags into responsive, bulletproof email markup and ships with
    modern standards — dark mode and accessibility — out of the box. Batteries included:
    design tokens, components, automatic CSS inlining, and generators, all overridable.
  DESC
  s.authors  = ['Advitam']
  s.homepage = 'https://github.com/AdVitam/activemail'
  s.licenses = ['MIT']
  s.required_ruby_version = '>= 3.2'
  s.metadata = {
    'source_code_uri' => s.homepage,
    'changelog_uri' => "#{s.homepage}/blob/master/CHANGELOG.md",
    'bug_tracker_uri' => "#{s.homepage}/issues",
    'rubygems_mfa_required' => 'true'
  }

  s.files = Dir['lib/**/*', 'app/**/*', 'LICENSE.txt', 'README.md', 'CHANGELOG.md']
  s.require_paths = ['lib']

  # The markup engine works without Rails; the engine/generators/interceptor load
  # only when Rails is present, so railties is intentionally not a hard dependency.
  s.add_dependency 'nokogiri', '>= 1.16'
  s.add_dependency 'premailer', '>= 1.21'
  s.add_dependency 'sorbet-runtime', '>= 0.5'
end
