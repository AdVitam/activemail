# frozen_string_literal: true

require 'test_helper'
require 'mail'

class InterceptorTest < ActiveMailTest
  HTML_BODY = '<style>p{color:red}</style><p>x</p>'

  def setup
    super
    ActiveMail.configuration.inliner = :premailer
  end

  def test_multipart_inlines_only_the_html_part
    message = Mail.new do
      text_part { body 'plain text' }
      html_part do
        content_type 'text/html; charset=UTF-8'
        body HTML_BODY
      end
    end

    ActiveMail::Inliner::Interceptor.delivering_email(message)

    assert_match(/style="[^"]*color:\s*red/i, message.html_part.body.to_s)
    assert_equal 'plain text', message.text_part.body.to_s
  end

  def test_single_part_html_is_inlined
    message = Mail.new do
      content_type 'text/html; charset=UTF-8'
      body HTML_BODY
    end

    ActiveMail::Inliner::Interceptor.delivering_email(message)

    assert_match(/style="[^"]*color:\s*red/i, message.body.to_s)
  end

  def test_plain_text_only_is_untouched
    message = Mail.new { body 'just text' }

    ActiveMail::Inliner::Interceptor.delivering_email(message)

    assert_equal 'just text', message.body.to_s
  end

  def test_inlining_error_is_reraised_with_an_activemail_breadcrumb
    failing = Class.new(ActiveMail::Inliner::Base) { def inline(_html) = raise('boom') }
    ActiveMail.configuration.inliner = failing.new
    message = Mail.new do
      content_type 'text/html; charset=UTF-8'
      body HTML_BODY
    end

    error = assert_raises(ActiveMail::Inliner::Error) { ActiveMail::Inliner::Interceptor.delivering_email(message) }
    assert_instance_of RuntimeError, error.cause # original exception + backtrace preserved
    assert_equal 'boom', error.cause.message
  end

  def test_register_inline_interceptor_false_is_a_no_op_at_runtime
    ActiveMail.configuration.register_inline_interceptor = false
    message = Mail.new do
      content_type 'text/html; charset=UTF-8'
      body HTML_BODY
    end

    ActiveMail::Inliner::Interceptor.delivering_email(message)

    assert_equal HTML_BODY, message.body.to_s
  end

  def test_html_attachment_is_not_inlined
    message = Mail.new do
      html_part do
        content_type 'text/html; charset=UTF-8'
        body HTML_BODY
      end
      add_file(filename: 'report.html', content: HTML_BODY)
    end
    # Force the attachment's content-type to text/html so only attachment? distinguishes it.
    message.attachments['report.html'].content_type = 'text/html; charset=UTF-8'

    ActiveMail::Inliner::Interceptor.delivering_email(message)

    refute_match(/style="/, message.attachments['report.html'].body.to_s)
  end

  def test_null_inliner_is_a_no_op
    ActiveMail.configuration.inliner = :null
    message = Mail.new do
      content_type 'text/html; charset=UTF-8'
      body HTML_BODY
    end

    ActiveMail::Inliner::Interceptor.delivering_email(message)

    assert_equal HTML_BODY, message.body.to_s
  end
end
