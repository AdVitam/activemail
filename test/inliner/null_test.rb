# frozen_string_literal: true

require 'test_helper'

class NullInlinerTest < ActiveMailTest
  def test_returns_input_unchanged
    html = '<style>p{color:red}</style><p>x</p>'

    assert_equal html, ActiveMail::Inliner::Null.new.inline(html)
  end
end
