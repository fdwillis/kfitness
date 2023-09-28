class ApplicationController < ActionController::Base
  before_action :authenticate_user!, only: %i[loved list your_membership pause_membership]

  def resume_membership
    Stripe::Subscription.update(
      params['id'],
      {
        pause_collection: ''
      }, {stripe_account: ENV['appStripeAccount']})

    flash[:success] = 'Subscription Resumed'
    redirect_to request.referrer
  end

  def pause_membership
    # only pause of ID passed
    Stripe::Subscription.update(params['id'], {pause_collection: {behavior: 'void' }}, {stripe_account: ENV['appStripeAccount']})

    flash[:success] = 'Subscription Paused'
    redirect_to request.referrer
  end

  def your_membership
    @subscriptionList = []
    @stripeCustomer = Stripe::Customer.retrieve(current_user&.stripeCustomerID, {stripe_account: ENV['appStripeAccount']})
    @stripeCustomerSubsctiptions = Stripe::Subscription.list({ limit: 100, customer: current_user&.stripeCustomerID }, {stripe_account: ENV['appStripeAccount']})['data']

    @stripeCustomerSubsctiptions.each do |subInfo|
      @subscriptionList << {active: subInfo['pause_collection'].nil? ? true : false, price: subInfo['items']['data'].map(&:price).map(&:id).first, subscription: subInfo['id']}
    end

    successURL = "https://kyneticfitclub.com/thank-you?session={CHECKOUT_SESSION_ID}"
    customFields = [{
      key: 'type',
      label: { custom: 'Include Membership Card ($5)', type: 'custom' },
      type: 'dropdown',
      dropdown: { options: [
        { label: 'Yes', value: 'yes' },
        { label: 'No', value: 'no' }
      ] }
    }]
    @authBasicSession = Stripe::Checkout::Session.create({
      success_url: successURL,
      phone_number_collection: {
       enabled: true
      },
      customer: current_user&.stripeCustomerID,
      line_items: [
       { price: ENV['oneTime'], quantity: 1 }
      ],
      subscription_data: {
        application_fee_percent: 10
      },
      mode: 'subscription',
    }, {stripe_account: ENV['appStripeAccount']})
    
    @oneTimePrice = Stripe::Price.retrieve(ENV['oneTime'], {stripe_account: ENV['appStripeAccount']})
    @oneTimeProduct = Stripe::Product.retrieve(@oneTimePrice['product'], {stripe_account: ENV['appStripeAccount']})

    @authBizSession = Stripe::Checkout::Session.create({
      success_url: successURL,
      phone_number_collection: {
       enabled: true
      },
      customer: current_user&.stripeCustomerID,
      line_items: [
       { price: ENV['twoTime'], quantity: 1 }
      ],
      subscription_data: {
        application_fee_percent: 10
      },
      mode: 'subscription',
    }, {stripe_account: ENV['appStripeAccount']})

    @twoTimePrice = Stripe::Price.retrieve(ENV['twoTime'], {stripe_account: ENV['appStripeAccount']})
    @twoTimeProduct = Stripe::Product.retrieve(@twoTimePrice['product'], {stripe_account: ENV['appStripeAccount']})

    @authEquitySession = Stripe::Checkout::Session.create({
      success_url: successURL,
      phone_number_collection: {
       enabled: true
      },
      customer: current_user&.stripeCustomerID,
      line_items: [
       { price: ENV['threeTime'], quantity: 1 }
      ],
      subscription_data: {
        application_fee_percent: 10
      },
      mode: 'subscription',
    }, {stripe_account: ENV['appStripeAccount']})

    @threeTimePrice = Stripe::Price.retrieve(ENV['threeTime'], {stripe_account: ENV['appStripeAccount']})
    @threeTimeProduct = Stripe::Product.retrieve(@threeTimePrice['product'], {stripe_account: ENV['appStripeAccount']})

    @fourTime = Stripe::Checkout::Session.create({
      success_url: successURL,
      phone_number_collection: {
       enabled: true
      },
      customer: current_user&.stripeCustomerID,
      line_items: [
       { price: ENV['fourTime'], quantity: 1 }
      ],
      subscription_data: {
        application_fee_percent: 10
      },
      mode: 'subscription',
    }, {stripe_account: ENV['appStripeAccount']})

    @fourTimePrice = Stripe::Price.retrieve(ENV['fourTime'], {stripe_account: ENV['appStripeAccount']})
    @fourTimeProduct = Stripe::Product.retrieve(@fourTimePrice['product'], {stripe_account: ENV['appStripeAccount']})

  end


  def traders
  end

  def captains
  end

  def users
    
  end

  def invite
    
  end

  def travel_trade
  end

  def inquiry
    if params['newInquiry'].present?
      customMade = Custominquiry.create(email: params['newInquiry']['email'], phone: params['newInquiry']['phone'], interval: params['newInquiry']['interval'], memberType: params['newInquiry']['memberType'])

      if customMade.present?
        flash[:success] = 'Inquiry Submitted'
        # text me
        oarlinMessage = "#{params['newInquiry']['email']} Joined The Waiting List!"
        textSent = User.twilioText(params['newInquiry']['phone'], "#{oarlinMessage}")
        redirect_to request.referrer
      else
        flash[:error] = 'Something Happened'
        redirect_to membership_path
      end
    else
      flash[:error] = 'Something Happened'
      redirect_to request.referrer
    end
  rescue Exception => e
    flash[:error] = e.to_s
    redirect_to request.referrer
  end

  def update_discount
    membershipDetails = current_user&.checkMembership
    subscriptions = Stripe::Subscription.list({ limit: 100, customer: current_user&.stripeCustomerID })
    subscriptions.each do |subs|
      Stripe::Subscription.update(
        subs['id'],
        { coupon: session['coupon'] }
      )
    end
    flash[:success] = 'Coupon Claimed'
    redirect_to profile_path
  rescue Stripe::StripeError => e
    flash[:error] = e.error.message.to_s
    redirect_to request.referrer
  rescue Exception => e
    flash[:error] = e.to_s
    redirect_to request.referrer
  end

  def discounts # sprint2
    if session['coupon'].nil?
      @discountsFor = current_user&.present? ? current_user&.checkMembership : nil
      @discountList = Stripe::Coupon.list({ limit: 100 })['data'].reject { |c| c['valid'] == false }.reject { |c| c['duration'] == 'forever' }.reject { |c| c['max_redemptions'] == 0 }

      if @discountsFor.nil? || !@discountsFor.map { |s| s[:membershipType] }.include?('free')
        
        @newList = @discountList.reject { |c| c['percent_off'] > 10 }.reject { |c| c['percent_off'] > 90 }.size > 0 ? @discountList.reject { |c| c['percent_off'] > 10 }.reject { |c| c['percent_off'] > 90 }.sample['id'] : 0
      elsif @discountsFor.map { |s| s[:membershipType] }.include?('affiliate')
        @newList = @discountList.reject { |c| c['percent_off'] > 20 || c['percent_off'] < 10 }.reject { |c| c['percent_off'] > 90 }.size > 0 ? @discountList.reject { |c| c['percent_off'] > 20 || c['percent_off'] < 10 }.reject { |c| c['percent_off'] > 90 }.sample['id'] : 0
      elsif @discountsFor.map { |s| s[:membershipType] }.include?('business')
        @newList = @discountList.reject { |c| c['percent_off'] > 30 || c['percent_off'] < 20 }.reject { |c| c['percent_off'] > 90 }.size > 0 ? @discountList.reject { |c| c['percent_off'] > 30 || c['percent_off'] < 20 }.reject { |c| c['percent_off'] > 90 }.sample['id'] : 0
      elsif @discountsFor.map { |s| s[:membershipType] }.include?('automation')
        @newList = @discountList.reject { |c| c['percent_off'] > 40 || c['percent_off'] < 30 }.reject { |c| c['percent_off'] > 90 }.size > 0 ? @discountList.reject { |c| c['percent_off'] > 40 || c['percent_off'] < 30 }.reject { |c| c['percent_off'] > 90 }.sample['id'] : 0
      elsif @discountsFor.map { |s| s[:membershipType] }.include?('custom')
        @newList = @discountList.reject { |c| c['percent_off'] > 50 || c['percent_off'] < 40 }.reject { |c| c['percent_off'] > 90 }.size > 0 ? @discountList.reject { |c| c['percent_off'] > 50 || c['percent_off'] < 40 }.reject { |c| c['percent_off'] > 90 }.sample['id'] : 0
      end

      session['coupon'] = @newList
    else
      if Stripe::Coupon.list({ limit: 100 }).map(&:id).include?(session['coupon']) == true
        @newList = session['coupon']
      else
        session['coupon'] = nil
        @newList = session['coupon']
      end
    end
  end

  def display_discount
    # setcoupon code in header
    if session['coupon'].nil?
      codes = Stripe::Coupon.list({ limit: 100 })['data'].reject { |c| c['valid'] == false }.reject { |c| c['duration'] == 'forever' }.reject { |c| c['max_redemptions'] == 0 }
      if codes.size > 0
        session['coupon'] = codes.sample['id']
        flash[:success] = 'Coupon Assigned'
        redirect_to request.referrer
        nil
      else
        flash[:notice] = 'Waiting For New Coupons'
        redirect_to discounts_path
        nil
      end
    end
  end

  def split_session
    redirect_to "#{request.fullpath.split('?')[0]}?&referredBy=#{params[:splitSession]}"
  end

  def cancel
    allSubscriptions = Stripe::Subscription.list({ customer: current_user&.stripeCustomerID })['data'].map(&:id)
    allSubscriptions.each do |id|
      upda = Stripe::Subscription.update(id, {pause_collection: {
        behavior: 'keep_as_draft' }})
    end


    flash[:success] = 'Membership Paused'
    redirect_to request.referrer
  end

  def commissions
    affiliateFromId = User.find_by(uuid: params[:id])
    @pulledAffiliate = Stripe::Customer.retrieve(affiliateFromId&.stripeCustomerID)
    @pulledCommissions = Stripe::Customer.list(limit: 100)
    @accountsFromAffiliate = @pulledCommissions['data'].reject { |e| e['metadata']['referredBy'] != params[:id] }
    @activeSubs = []
    @inactiveSubs = []
    @accountItemsDue = Stripe::Account.retrieve(Stripe::Customer.retrieve(affiliateFromId&.stripeCustomerID)['metadata']['connectAccount'])['requirements']['currently_due']
    @accountsFromAffiliate.each do |cusID|
      listofSubscriptionsFromCusID = Stripe::Subscription.list(limit: 100, customer: cusID)['data']
      next unless listofSubscriptionsFromCusID.size > 0

      listofSubscriptionsFromCusID.each do |subscriptionX|
        if subscriptionX['status'] == 'active'
          @activeSubs << subscriptionX
        else
          @inactiveSubs << subscriptionX
        end
      end
    end
    @combinedCommissions = 0
    @monthlyCommissions = 0
    @annualCommissions = 0

    @activeSubs.map(&:items).map(&:data).flatten.map(&:plan).each do |plan|
      if plan['interval'] == 'month'
        @combinedCommissions += (plan['amount'] * 12) * (@pulledAffiliate['metadata']['commissionRate'].to_i * 0.01)
        @monthlyCommissions += 1
      end

      next unless plan['interval'] == 'year'

      @combinedCommissions += (plan['amount']) * (@pulledAffiliate['metadata']['commissionRate'].to_i * 0.01)
      @annualCommissions += 1
    end

    @combinedCommissions

    @payouts = Stripe::Payout.list({ limit: 3 }, { stripe_account: @pulledAffiliate['metadata']['connectAccount'] })['data']
  rescue Stripe::StripeError => e
    flash[:error] = e.error.message.to_s
    redirect_to request.referrer
  rescue Exception => e
    flash[:error] = e.to_s
    redirect_to request.referrer
  end

  def analytics; end

  def checkout
    begin

      if params['price'] == ENV['thursdayClass'] || params['price'] == ENV['sundayClass']

        @session = Stripe::Checkout::Session.create({
                                                    success_url: "https://kyneticfitclub.com/thank-you?session={CHECKOUT_SESSION_ID}",
                                                    phone_number_collection: {
                                                      enabled: true
                                                    },
                                                    customer: current_user.present? ? current_user&.stripeCustomerID : nil,
                                                    line_items: [
                                                      { price: params['price'], quantity: 1 }
                                                    ],
                                                    subscription_data: {
                                                      application_fee_percent: 10
                                                    },
                                                    mode: 'payment'
                                                  }, {stripe_account: ENV['appStripeAccount']})
      else
        @session = Stripe::Checkout::Session.create({
                                                    success_url: "https://kyneticfitclub.com/thank-you?session={CHECKOUT_SESSION_ID}",
                                                    phone_number_collection: {
                                                      enabled: true
                                                    },
                                                    customer: current_user.present? ? current_user&.stripeCustomerID : nil,
                                                    line_items: [
                                                      { price: params['price'], quantity: 1 }
                                                    ],
                                                    subscription_data: {
                                                      application_fee_percent: 10
                                                    },
                                                    mode: 'subscription'
                                                  }, {stripe_account: ENV['appStripeAccount']})
      end
      
      redirect_to @session['url']
    rescue Stripe::StripeError => e
      session['coupon'] = nil
      flash[:error] = e.error.message.to_s
      redirect_to request.referrer
    rescue Exception => e
      session['coupon'] = nil
      flash[:error] = e.to_s
      redirect_to request.referrer
    end
  end

  def questions; end

  def profile
    @userFound = params['id'].present? ? User.find_by(uuid: params['id']) : current_user
    @profile = @userFound.present? ? Stripe::Customer.retrieve(@userFound&.stripeCustomerID, {stripe_account: ENV['appStripeAccount']}) : nil
    @membershipDetails = @userFound.present? ? @userFound&.checkMembership : nil
    @profileMetadata = @profile.present? ? @profile['metadata'] : nil
    your_membership
    
  end

  def welcome
    @codes = Stripe::Coupon.list({ limit: 100 }).reject { |c| c['valid'] == false }.reject { |c| c['duration'] == 'forever' }
    @prob1 = [
      {prob:'Too Busy Working?', solu: "Oarlin hunts for financial opportunities while you are busy"},
      {prob:'Too Busy With Home?', solu: "Trust Oarlin to protect your financial goals while you are busy"},
      {prob:'Too Busy For Investing?', solu: 'Oarlin secures your investment goals so that you can secure your life goals'},
      {prob:'Volatility Making You Hesitate?', solu: 'Oarlin will trade when the time is right'},
      {prob:'Invest Today Like You Know You Should', solu: 'Stop putting off your investment goals'},
      {prob:"Still Learning About Investing?", solu: 'Oarlin makes you money while you keep learning'},
      {prob:"The Only Social Platform For Trading", solu: 'Oarlin is the home all traders have been waiting for'},
    ] 

    @subline = ['In Person & Virtual Sessions']
    @headlines = ['Achieve Your Fitness Goals']

  end

end
