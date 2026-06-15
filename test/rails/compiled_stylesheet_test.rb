# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'
require 'activemail/rails/compiled_stylesheet'

# CompiledStylesheet probes whichever pipeline the host runs (Sprockets or
# Propshaft) by duck-type; both shapes and the miss path are covered with fakes so
# the test needs no Rails boot.
class CompiledStylesheetTest < ActiveMailTest
  LOGICAL = 'activemail/activemail.css'
  CSS = '.container{max-width:600px}'

  def teardown
    super
    restore_rails
  end

  def test_reads_sprockets_source
    stub_rails(sprockets_assets(CSS))

    assert_equal CSS, ActiveMail::CompiledStylesheet.read(LOGICAL)
  end

  def test_reads_propshaft_source
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'activemail.css')
      File.write(path, CSS)
      stub_rails(propshaft_assets(path))

      assert_equal CSS, ActiveMail::CompiledStylesheet.read(LOGICAL)
    end
  end

  def test_returns_empty_string_when_asset_missing
    stub_rails(propshaft_assets(nil))

    assert_equal '', ActiveMail::CompiledStylesheet.read(LOGICAL)
  end

  def test_returns_empty_string_without_rails
    hide_rails

    assert_equal '', ActiveMail::CompiledStylesheet.read(LOGICAL)
  end

  private

  # Swap the real Rails const (railties is loaded in the suite) for a fake whose
  # only surface is application.config.assets; restored in teardown.
  def stub_rails(assets)
    config = Struct.new(:assets).new(assets)
    application = Struct.new(:config).new(config)
    rails = Module.new
    rails.define_singleton_method(:application) { application }
    swap_rails(rails)
  end

  def hide_rails
    swap_rails(nil)
  end

  def swap_rails(replacement)
    @saved_rails = Object.const_get(:Rails) if Object.const_defined?(:Rails)
    @rails_swapped = true
    silence_const_warning { Object.send(:remove_const, :Rails) } if Object.const_defined?(:Rails)
    silence_const_warning { Object.const_set(:Rails, replacement) } if replacement
  end

  def restore_rails
    return unless @rails_swapped

    silence_const_warning { Object.send(:remove_const, :Rails) } if Object.const_defined?(:Rails)
    silence_const_warning { Object.const_set(:Rails, @saved_rails) } if @saved_rails
    @rails_swapped = false
  end

  def silence_const_warning
    original = $VERBOSE
    $VERBOSE = nil
    yield
  ensure
    $VERBOSE = original
  end

  def sprockets_assets(source)
    asset = source && Struct.new(:source).new(source)
    environment = Object.new
    environment.define_singleton_method(:find_asset) { |_path| asset }
    Struct.new(:environment).new(environment)
  end

  def propshaft_assets(path)
    asset = path && Struct.new(:path).new(path)
    load_path = Object.new
    load_path.define_singleton_method(:find) { |_path| asset }
    Struct.new(:load_path).new(load_path)
  end
end
