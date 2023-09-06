class ApplicationController < ActionController::Base
  before_action :authenticate_user!, only: %i[loved list]

  def external
    @link = 'https://oarlin.com/learn-trading' 
  end

  def traders
  end

  def captains
  end

  def users
    
  end

  def skip
    @peopleProfiles = [
      {
        name: 'Kevin',
        image: 'kevin.jpg',
        quote: "I did not think trading existed this way",
      },{
        name: 'Bella',
        image: 'bella.jpg',
        quote: "I rarely have time for my coffee, but now Oarlin pays it!",
      },{
        name: 'Cindy',
        image: 'cindy.jpg',
        quote: "Becoming an Oarlin Captain changed my life",
      },{
        name: 'Nick',
        image: 'nick.jpg',
        quote: "Oarlin just makes sense to me...it's the future",
      },{
        name: 'Payton',
        image: 'payton.jpg',
        quote: "This has to be magic!",
      },
    ]



    if params['interval'] == 'month'
      if params['memberType'] == 'user'
        @stripePlan = Stripe::Price.retrieve(ENV['userMonth'])
      end
      if params['memberType'] == 'captain'
        @stripePlan = Stripe::Price.retrieve(ENV['captainMonth'])
      end
      if params['memberType'] == 'trader'
        @stripePlan = Stripe::Price.retrieve(ENV['traderMonth'])
      end
    end

    if params['interval'] == 'annual'
      if params['memberType'] == 'user'
        @stripePlan = Stripe::Price.retrieve(ENV['userAnnual'])
      end
      if params['memberType'] == 'captain'
        @stripePlan = Stripe::Price.retrieve(ENV['captainAnnual'])
      end
      if params['memberType'] == 'trader'
        @stripePlan = Stripe::Price.retrieve(ENV['traderAnnual'])
      end
    end
    successURL = "https://app.oarlin.com/trading?session={CHECKOUT_SESSION_ID}&referredBy=#{params['referredBy']}"
    if session['coupon'].present?
      @session = Stripe::Checkout::Session.create({
                                                               success_url: successURL,
                                                               phone_number_collection: {
                                                                 enabled: true
                                                               },
                                                               discounts: [
                                                                 coupon: session['coupon']
                                                               ],
                                                               line_items: [
                                                                 { price: @stripePlan, quantity: 1 }
                                                               ],
                                                               mode: 'subscription'
                                                             })
    else
      @session = Stripe::Checkout::Session.create({
                                                               success_url: successURL,
                                                               phone_number_collection: {
                                                                 enabled: true
                                                               },
                                                               discounts: [
                                                                 coupon: session['coupon']
                                                               ],
                                                               line_items: [
                                                                 { price: @stripePlan, quantity: 1 }
                                                               ],
                                                               mode: 'subscription'
                                                             })
    end
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
      
      @session = Stripe::Checkout::Session.create({
                                                    success_url: "https://kyneticfitclub.com/thank-you?session={CHECKOUT_SESSION_ID}",
                                                    phone_number_collection: {
                                                      enabled: true
                                                    },
                                                    subscription_data: {
                                                      application_fee_percent: 10
                                                    },
                                                    line_items: [
                                                      { price: params['price'], quantity: 1 }
                                                    ],
                                                    mode: 'subscription'
                                                  }, { stripe_account: params['account'] })
      
      
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

  def autotrading
    @codes = Stripe::Coupon.list({ limit: 100 }).reject { |c| c['valid'] == false }
    successURL = "https://app.oarlin.com/trading?session={CHECKOUT_SESSION_ID}&referredBy=#{params['referredBy']}"

    if session['coupon'].nil?
      @autoTradingMonthlyMembership = Stripe::Checkout::Session.create({
                                                                         success_url: successURL,
                                                                         line_items: [
                                                                           { price: ENV['autoTradingMonthlyMembership'], quantity: 1 }
                                                                         ],
                                                                         mode: 'subscription'
                                                                       })
      @autoTradingAnnualMembership = Stripe::Checkout::Session.create({
                                                                        success_url: successURL,
                                                                        line_items: [
                                                                          { price: ENV['autoTradingAnnualMembership'], quantity: 1 }
                                                                        ],
                                                                        mode: 'subscription'
                                                                      })
    else
      if @codes.map(&:id).include?(session['coupon']) == true && Stripe::Coupon.retrieve(session['coupon']).valid == true
        # free -> build on page,
        # affiliate,
        @selfTradingAnnualMembership = Stripe::Checkout::Session.create({
                                                                          success_url: successURL,
                                                                          line_items: [
                                                                            { price: ENV['selfTradingAnnualMembership'], quantity: 1 }
                                                                          ],
                                                                          mode: 'subscription',
                                                                          discounts: [
                                                                            coupon: session['coupon']
                                                                          ]
                                                                        })
        @selfTradingMonthlyMembership = Stripe::Checkout::Session.create({
                                                                           success_url: successURL,
                                                                           line_items: [
                                                                             { price: ENV['selfTradingMonthlyMembership'], quantity: 1 }
                                                                           ],
                                                                           mode: 'subscription',
                                                                           discounts: [
                                                                             coupon: session['coupon']
                                                                           ]
                                                                         })
        # business,
        @autoTradingMonthlyMembership = Stripe::Checkout::Session.create({
                                                                           success_url: successURL,
                                                                           line_items: [
                                                                             { price: ENV['autoTradingMonthlyMembership'], quantity: 1 }
                                                                           ],
                                                                           mode: 'subscription',
                                                                           discounts: [
                                                                             coupon: session['coupon']
                                                                           ]
                                                                         })
        @autoTradingAnnualMembership = Stripe::Checkout::Session.create({
                                                                          success_url: successURL,
                                                                          line_items: [
                                                                            { price: ENV['autoTradingAnnualMembership'], quantity: 1 }
                                                                          ],
                                                                          mode: 'subscription',
                                                                          discounts: [
                                                                            coupon: session['coupon']
                                                                          ]
                                                                        })
      else
        session['coupon'] = nil
        flash[:notice] = 'Coupon Expired'
        redirect_to request.referrer
        nil
      end
    end
  end

  def membership
    @codes = Stripe::Coupon.list({ limit: 100 }).reject { |c| c['valid'] == false }

    customFields = [{
      key: 'type',
      label: { custom: 'Account Type', type: 'custom' },
      type: 'dropdown',
      dropdown: { options: [
        { label: 'Individual', value: 'individual' },
        { label: 'Company', value: 'company' }
      ] }
    }, {
      key: 'country',
      label: { custom: 'Country', type: 'custom' },
      type: 'dropdown',
      dropdown: { options: [
        { label: 'Australia', value: 'AU' },
        { label: 'Belgium', value: 'BE' },
        { label: 'Canada', value: 'CA' },
        { label: 'France', value: 'FR' },
        { label: 'Germany', value: 'DE' },
        { label: 'Italy', value: 'IT' },
        { label: 'Japan', value: 'JP' },
        { label: 'Mexico', value: 'MX' },
        { label: 'Netherlands', value: 'NL' },
        { label: 'Poland', value: 'PL' },
        { label: 'Singapore', value: 'SG' },
        { label: 'Spain', value: 'ES' },
        { label: 'Sweden', value: 'SE' },
        { label: 'United Arab Emirates', value: 'AE' },
        { label: 'United Kingdom', value: 'GB' },
        { label: 'United States', value: 'US' }
      ] }
    }]
    allowedCountries = %w[
      AU
      BE
      CA
      FR
      DE
      IT
      JP
      MX
      NL
      PL
      SG
      ES
      SE
      AE
      GB
      US
    ]
    successURL = "https://app.oarlin.com/new-password-set?session={CHECKOUT_SESSION_ID}&referredBy=#{params['referredBy']}"

    if session['coupon'].nil?
      # free -> build on page,
      # affiliate,
      @freeMembership = Stripe::Checkout::Session.create({
                                                           success_url: successURL,
                                                           custom_fields: customFields,
                                                           phone_number_collection: {
                                                             enabled: true
                                                           },
                                                           shipping_address_collection: { allowed_countries: allowedCountries },
                                                           line_items: [
                                                             { price: ENV['freeMembership'], quantity: 1 }
                                                           ],
                                                           mode: 'subscription'
                                                         })

      @affiliateMonthly = Stripe::Checkout::Session.create({
                                                             success_url: successURL,
                                                             custom_fields: customFields,
                                                             phone_number_collection: {
                                                               enabled: true
                                                             },
                                                             shipping_address_collection: { allowed_countries: allowedCountries },
                                                             line_items: [
                                                               { price: ENV['affiliateMonthly'], quantity: 1 }
                                                             ],
                                                             mode: 'subscription'
                                                           })
      @affiliateAnnual = Stripe::Checkout::Session.create({
                                                            success_url: successURL,
                                                            custom_fields: customFields,
                                                            phone_number_collection: {
                                                              enabled: true
                                                            },
                                                            shipping_address_collection: { allowed_countries: allowedCountries },
                                                            line_items: [
                                                              { price: ENV['affiliateAnnual'], quantity: 1 }
                                                            ],
                                                            mode: 'subscription'
                                                          })
      # business,
      @businessMonthly = Stripe::Checkout::Session.create({
                                                            success_url: successURL,
                                                            custom_fields: customFields,
                                                            phone_number_collection: {
                                                              enabled: true
                                                            },
                                                            shipping_address_collection: { allowed_countries: allowedCountries },
                                                            line_items: [
                                                              { price: ENV['businessMonthly'], quantity: 1 }
                                                            ],
                                                            mode: 'subscription'
                                                          })
      @businessAnnual = Stripe::Checkout::Session.create({
                                                           success_url: successURL,
                                                           custom_fields: customFields,
                                                           phone_number_collection: {
                                                             enabled: true
                                                           },
                                                           shipping_address_collection: { allowed_countries: allowedCountries },
                                                           line_items: [
                                                             { price: ENV['businessAnnual'], quantity: 1 }
                                                           ],
                                                           mode: 'subscription'
                                                         })

      @automationMonthly = Stripe::Checkout::Session.create({
                                                              success_url: successURL,
                                                              custom_fields: customFields,
                                                              phone_number_collection: {
                                                                enabled: true
                                                              },
                                                              shipping_address_collection: { allowed_countries: allowedCountries },
                                                              line_items: [
                                                                { price: ENV['automationMonthly'], quantity: 1 }
                                                              ],
                                                              mode: 'subscription'
                                                            })
      @automationAnnual = Stripe::Checkout::Session.create({
                                                             success_url: successURL,
                                                             custom_fields: customFields,
                                                             phone_number_collection: {
                                                               enabled: true
                                                             },
                                                             shipping_address_collection: { allowed_countries: allowedCountries },
                                                             line_items: [
                                                               { price: ENV['automationAnnual'], quantity: 1 }
                                                             ],
                                                             mode: 'subscription'
                                                           })
      # custom -> build on page,
    else
      if @codes.map(&:id).include?(session['coupon']) == true && Stripe::Coupon.retrieve(session['coupon']).valid == true
        # free -> build on page,
        # affiliate,
        @freeMembership = Stripe::Checkout::Session.create({
                                                             success_url: successURL,
                                                             custom_fields: customFields,
                                                             phone_number_collection: {
                                                               enabled: true
                                                             },
                                                             discounts: [
                                                               coupon: session['coupon']
                                                             ],
                                                             shipping_address_collection: { allowed_countries: allowedCountries },
                                                             line_items: [
                                                               { price: ENV['freeMembership'], quantity: 1 }
                                                             ],
                                                             mode: 'subscription'
                                                           })

        @affiliateMonthly = Stripe::Checkout::Session.create({
                                                               success_url: successURL,
                                                               custom_fields: customFields,
                                                               phone_number_collection: {
                                                                 enabled: true
                                                               },
                                                               discounts: [
                                                                 coupon: session['coupon']
                                                               ],
                                                               shipping_address_collection: { allowed_countries: allowedCountries },
                                                               line_items: [
                                                                 { price: ENV['affiliateMonthly'], quantity: 1 }
                                                               ],
                                                               mode: 'subscription'
                                                             })
        @affiliateAnnual = Stripe::Checkout::Session.create({
                                                              success_url: successURL,
                                                              custom_fields: customFields,
                                                              phone_number_collection: {
                                                                enabled: true
                                                              },
                                                              discounts: [
                                                                coupon: session['coupon']
                                                              ],
                                                              shipping_address_collection: { allowed_countries: allowedCountries },
                                                              line_items: [
                                                                { price: ENV['affiliateAnnual'], quantity: 1 }
                                                              ],
                                                              mode: 'subscription'
                                                            })
        # business,
        @businessMonthly = Stripe::Checkout::Session.create({
                                                              success_url: successURL,
                                                              custom_fields: customFields,
                                                              phone_number_collection: {
                                                                enabled: true
                                                              },
                                                              discounts: [
                                                                coupon: session['coupon']
                                                              ],
                                                              shipping_address_collection: { allowed_countries: allowedCountries },
                                                              line_items: [
                                                                { price: ENV['businessMonthly'], quantity: 1 }
                                                              ],
                                                              mode: 'subscription'
                                                            })
        @businessAnnual = Stripe::Checkout::Session.create({
                                                             success_url: successURL,
                                                             custom_fields: customFields,
                                                             phone_number_collection: {
                                                               enabled: true
                                                             },
                                                             discounts: [
                                                               coupon: session['coupon']
                                                             ],
                                                             shipping_address_collection: { allowed_countries: allowedCountries },
                                                             line_items: [
                                                               { price: ENV['businessAnnual'], quantity: 1 }
                                                             ],
                                                             mode: 'subscription'
                                                           })

        @automationMonthly = Stripe::Checkout::Session.create({
                                                                success_url: successURL,
                                                                custom_fields: customFields,
                                                                phone_number_collection: {
                                                                  enabled: true
                                                                },
                                                                discounts: [
                                                                  coupon: session['coupon']
                                                                ],
                                                                shipping_address_collection: { allowed_countries: allowedCountries },
                                                                line_items: [
                                                                  { price: ENV['automationMonthly'], quantity: 1 }
                                                                ],
                                                                mode: 'subscription'
                                                              })
        @automationAnnual = Stripe::Checkout::Session.create({
                                                               success_url: successURL,
                                                               custom_fields: customFields,
                                                               phone_number_collection: {
                                                                 enabled: true
                                                               },
                                                               discounts: [
                                                                 coupon: session['coupon']
                                                               ],
                                                               shipping_address_collection: { allowed_countries: allowedCountries },
                                                               line_items: [
                                                                 { price: ENV['automationAnnual'], quantity: 1 }
                                                               ],
                                                               mode: 'subscription'
                                                             })
        # custom -> build on page,
      else
        session['coupon'] = nil
        flash[:notice] = 'Coupon Expired'
        redirect_to request.referrer
        nil
      end
    end
  end

  def profile
    @userFound = params['id'].present? ? User.find_by(uuid: params['id']) : current_user
    @profile = @userFound.present? ? Stripe::Customer.retrieve(@userFound&.stripeCustomerID) : nil
    @membershipDetails = @userFound.present? ? @userFound&.checkMembership : nil
    @profileMetadata = @profile.present? ? @profile['metadata'] : nil
    @accountItemsDue = @userFound.present? && Stripe::Customer.retrieve(@userFound&.stripeCustomerID)['metadata']['connectAccount'].present? ? Stripe::Account.retrieve(Stripe::Customer.retrieve(@userFound&.stripeCustomerID)['metadata']['connectAccount'])['requirements']['currently_due'] : nil

    if @userFound.present? && Stripe::Customer.retrieve(@userFound&.stripeCustomerID)['metadata']['connectAccount'].present?
      @stripeAccountUpdate = Stripe::AccountLink.create(
        {
          account: Stripe::Customer.retrieve(@userFound&.stripeCustomerID)['metadata']['connectAccount'],
          refresh_url: "https://app.oarlin.com/?&referredBy=#{@userFound&.uuid}",
          return_url: "https://app.oarlin.com/?&referredBy=#{@userFound&.uuid}",
          type: 'account_onboarding'
        }
      )

      if @accountItemsDue.count == 0
        @loginLink = Stripe::Account.create_login_link(
          Stripe::Customer.retrieve(@userFound&.stripeCustomerID)['metadata']['connectAccount']
        )
      end
    end
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
