# An opinion sent from the app, delivered to whoever runs this copy. Nothing is kept in the app. The
# sender's address is in the message only when they ticked "you can reply to me".
class FeedbackMailer < ApplicationMailer
  def feedback(address:, helps:, missing:, recommend:, reply_to_address:, context:)
    @helps = helps
    @missing = missing
    @recommend = recommend
    @context = context
    mail to: address, reply_to: reply_to_address, subject: "Migraine Tracker : avis (#{context[:locale]})"
  end
end
