# frozen_string_literal: true

require 'test_helper'

class RoadieInlinerTest < ActiveMailTest
  def setup
    super
    require 'roadie'
  rescue LoadError
    skip 'roadie not installed'
  end

  def test_inlines_style_into_attribute
    output = ActiveMail::Inliner::Roadie.new.inline('<style>p{color:red}</style><p>x</p>')

    assert_match(/<p[^>]*style="[^"]*color:\s*red/i, output)
  end
end
