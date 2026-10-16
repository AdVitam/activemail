# frozen_string_literal: true

class PlainMailer < ActionMailer::Base
  layout false

  def hello
    mail(to: 'to@example.com', from: 'from@example.com', subject: 'Hello')
  end
end
