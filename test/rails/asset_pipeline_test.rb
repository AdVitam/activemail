# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'
require 'activemail/asset_pipeline'

class AssetPipelineTest < ActiveMailTest
  Config = Struct.new(:enable_reloading)
  App = Struct.new(:assets, :assets_manifest, :config)
  Environment = Struct.new(:sources, :lookups) do
    def find_asset(path)
      self.lookups += 1
      sources[path]
    end
  end
  Manifest = Struct.new(:assets, :directory)

  def test_for_falls_back_to_null_without_a_known_pipeline
    pipeline = ActiveMail::AssetPipeline.for(App.new(nil, nil, Config.new(false)))

    assert_instance_of ActiveMail::AssetPipeline::Null, pipeline
    assert_nil pipeline.read('activemail/activemail.css')
  end

  def test_for_selects_the_strategy_by_loaded_constant
    app = App.new(nil, nil, Config.new(false))

    with_constant(:Propshaft) { assert_instance_of ActiveMail::AssetPipeline::Propshaft, ActiveMail::AssetPipeline.for(app) }
  end

  def test_sprockets_reads_from_the_live_environment
    environment = Environment.new({ 'a.css' => 'a{}' }, 0)
    pipeline = ActiveMail::AssetPipeline::Sprockets.new(App.new(environment, nil, Config.new(true)))

    assert_equal 'a{}', pipeline.read('a.css')
    assert_nil pipeline.read('missing.css')
  end

  def test_sprockets_reads_the_compiled_file_from_the_manifest_without_an_environment
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'a-123.css'), 'a{}')
      manifest = Manifest.new({ 'a.css' => 'a-123.css' }, dir)
      pipeline = ActiveMail::AssetPipeline::Sprockets.new(App.new(nil, manifest, Config.new(false)))

      assert_equal 'a{}', pipeline.read('a.css')
      assert_nil pipeline.read('missing.css')
    end
  end

  def test_reads_are_memoized_unless_reloading
    memoized = Environment.new({ 'a.css' => 'a{}' }, 0)
    reloading = Environment.new({ 'a.css' => 'a{}' }, 0)
    cached = ActiveMail::AssetPipeline::Sprockets.new(App.new(memoized, nil, Config.new(false)))
    live = ActiveMail::AssetPipeline::Sprockets.new(App.new(reloading, nil, Config.new(true)))

    2.times do
      cached.read('a.css')
      live.read('a.css')
    end

    assert_equal 1, memoized.lookups
    assert_equal 2, reloading.lookups
  end

  def test_misses_are_not_memoized
    environment = Environment.new({}, 0)
    pipeline = ActiveMail::AssetPipeline::Sprockets.new(App.new(environment, nil, Config.new(false)))
    pipeline.read('a.css')
    environment.sources['a.css'] = 'a{}'

    assert_equal 'a{}', pipeline.read('a.css')
  end

  def test_register_precompile_extends_the_sprockets_list
    assets = Struct.new(:precompile).new(['x.css'])
    app = App.new(nil, nil, Struct.new(:assets, :enable_reloading).new(assets, false))
    ActiveMail::AssetPipeline::Sprockets.new(app).register_precompile(['activemail/activemail.css'])

    assert_equal ['x.css', 'activemail/activemail.css'], assets.precompile
  end

  private

  def with_constant(name)
    Object.const_set(name, Module.new)
    yield
  ensure
    Object.send(:remove_const, name)
  end
end
