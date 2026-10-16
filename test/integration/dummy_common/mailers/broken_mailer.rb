# frozen_string_literal: true

class BrokenMailer < ActionMailer::Base
  layout 'missing_stylesheet'

  def hello
    mail(to: 'to@example.com', from: 'from@example.com', subject: 'Broken')
  end
end
