class RegistrationsController < ApplicationController

  def new
    if request.get?
    else
      createdUser = User.create(setSessionVarParams)
      if createdUser.present?
        flash[:success] = 'Sign Up Complete'
        redirect_to request.referrer
        return
      else
        flash[:error] = "Something Went Wrong"
        redirect_to request.referrer
        return
      end
    end
  end

  def thank_you
    if request.post?
      begin
        if setSessionVarParams[:password_confirmation] == setSessionVarParams[:password]
          stripeSessionInfo = Stripe::Checkout::Session.retrieve(
            setSessionVarParams['stripeSession'], {stripe_account: ENV['appStripeAccount']}
          )
          stripeCustomer = Stripe::Customer.retrieve(stripeSessionInfo['customer'])

          loadedAffililate = User.find_by(uuid: setSessionVarParams['referredBy'])

          stripePlan = Stripe::Subscription.list({ customer: stripeSessionInfo['customer'] })['data'][0]['items']['data'][0]['plan']['id']

          if cardNew.present? && cardHolderNew.present?
            customerUpdated = Stripe::Customer.update(
              stripeSessionInfo['customer'], {
                metadata: {
                  connectAccount: newStripeAccount['id'],
                  cardHolder: cardHolderNew['id'],
                  issuedCard: cardNew['id'],
                  referredBy: setSessionVarParams['referredBy'].present? ? setSessionVarParams['referredBy'] : ','
                }.merge(commissionRate)
              }
            )

          else
            customerUpdated = Stripe::Customer.update(
              stripeSessionInfo['customer'], {
                metadata: {
                  connectAccount: newStripeAccount['id'],
                  # recipientAccount: recipientAccount['id'],
                  referredBy: setSessionVarParams['referredBy'].present? ? setSessionVarParams['referredBy'] : ','
                }.merge(commissionRate)
              }
            )
          end
          # make user with password passed

          loadedCustomer = User.create(
            referredBy: setSessionVarParams['referredBy'].present? ? setSessionVarParams['referredBy'] : ',',
            email: stripeCustomer['email'],
            password: setSessionVarParams['password'],
            amazonCountry: stripeSessionInfo['custom_fields'][1]['dropdown']['value'],
            amazonUUID: setSessionVarParams['amazonUUID'],
            accessPin: setSessionVarParams['accessPin'],
            stripeCustomerID: stripeSessionInfo['customer'],
            uuid: SecureRandom.uuid[0..7]
          )

          flash[:success] = 'Your Account Setup Is Complete!'

          redirect_to new_password_path
        else
          flash[:alert] = 'Password Must Match'
          redirect_to request.referrer
          nil
        end
      rescue Stripe::StripeError => e
        flash[:error] = e.error.message.to_s
        redirect_to request.referrer
      rescue Exception => e
        flash[:error] = e.to_s
        redirect_to request.referrer
      end
    else
      @stripeSession = Stripe::Checkout::Session.retrieve(
        params['session'], {stripe_account: ENV['appStripeAccount']}
      )
    end
  end

  def trading
    # route here after successful checkout of price
    # email them their sessionLink via webhook sessionLinkEmail

    if request.post?
      begin
        if newTraderParams[:password_confirmation] == newTraderParams[:password]
          stripeSessionInfo = Stripe::Checkout::Session.retrieve(
            newTraderParams['stripeSession']
          )
          stripeCustomer = Stripe::Customer.retrieve(stripeSessionInfo['customer'])

          stripePlan = Stripe::Subscription.list({ customer: stripeSessionInfo['customer'] })['data'][0]['items']['data'][0]['plan']['id']

          newStripeAccount = Stripe::Account.create({
                                                      type: 'standard',
                                                      country: stripeSessionInfo['customer_details']['address']['country'],
                                                      email: stripeCustomer['email']
                                                    })

          customerUpdated = Stripe::Customer.update(
            stripeSessionInfo['customer'], {
              metadata: {
                referredBy: newTraderParams['referredBy'].present? ? newTraderParams['referredBy'] : ',',
                commissionRate: 10,
                connectAccount: newStripeAccount['id']
              }
            }
          )
          # make user with password passed
          loadedCustomer = User.create(
            referredBy: newTraderParams['referredBy'].present? ? newTraderParams['referredBy'] : ',',
            email: stripeCustomer['email'],
            username: newTraderParams['username'],
            password: newTraderParams['password'],
            accessPin: newTraderParams['accessPin'],
            stripeCustomerID: stripeSessionInfo['customer'],
            uuid: SecureRandom.uuid[0..7],
            amazonCountry: stripeSessionInfo['customer_details']['address']['country']
          )

          loadedCustomer.checkMembership
          if loadedCustomer.trial?
            loadedCustomer.update(authorizedList: stripeSessionInfo['custom_fields'][0]['dropdown']['value'])
          end

          flash[:success] = 'Your Account Is Setup!'
          redirect_to request.referrer
          nil
        else
          flash[:alert] = 'Password Must Match'
          redirect_to request.referrer
          nil
        end
      rescue Stripe::StripeError => e
        flash[:error] = e.error.message.to_s
        redirect_to request.referrer
      rescue Exception => e
        flash[:error] = e.to_s
        redirect_to request.referrer
      end
    else
      @stripeSession = Stripe::Checkout::Session.retrieve(
        params['session']
      )
    end
  end

  def trial; end

  private

  def setSessionVarParams
    paramsClean = params.require(:setSessionVar).permit(:email, :password_confirmation, :password, :stripeSession, :referredBy, :accessPin, :amazonUUID)
    paramsClean.reject { |_, v| v.blank? }
  end

  def newTraderParams
    paramsClean = params.require(:newTrader).permit(:username, :password_confirmation, :password, :stripeSession, :referredBy, :accessPin, :country)
    paramsClean.reject { |_, v| v.blank? }
  end
end
