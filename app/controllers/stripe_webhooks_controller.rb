class StripeWebhooksController < ApplicationController
  protect_from_forgery with: :null_session
  #   ApplicationMailer.sessionLink(stripeObject['id']).deliver_now

  def update
    event = params['stripe_webhook']['type']
    stripeObject = params['data']['object']

    if event == 'checkout.session.completed'
      transferX = Stripe::Transfer.create({
        amount: (stripeObject['amount_total'] * 0.10).to_i,
        currency: 'usd',
        destination: ENV['oarlinStripeAccount'],
        description: 'Kynetic Membership',
        source_transaction: Stripe::Invoice.retrieve(stripeObject['invoice'])['charge']
      })
      render json: {
        success: true
      }
      return
    end


  end
end








