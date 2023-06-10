class TradingviewController < ApplicationController
	protect_from_forgery with: :null_session

	def manage_trading_keys
		if autoTradingKeysparams.present?
			current_user.update(autoTradingKeysparams)
			flash[:success] = "Keys Updated"
			redirect_to request.referrer
			return
		else
			flash[:notice] = "Cannot Be Blank"
			redirect_to request.referrer
			return
		end
	end

	def signals
		# check user exists from uuid
		# if user subscription is active -> continue
		traderID = params['traderID']
		traderFound = User.find_by(uuid: traderID)

		if traderID.present? && traderFound && traderFound.checkMembership.map{|d| d[:membershipType]}.include?('trader')
			case true
			when params['tickerType'] == "crypto"

				case true
				when params['type'].include?('Stop')
					# BackgroundJob.perform_async(params)
					Kraken.krakenTrailStop(params, traderFound)
				when params['type'] == 'entry'
					limitOrder = Kraken.krakenLimitOrder(params, traderFound)
					
					if params['allowMarketOrder'] == 'true'
						marketOrder = Kraken.krakenMarketOrder(params, traderFound)
					end

				when params['type'].include?('profit')
				end

				render json: {success: true}
			when params['tickerType'] == "forex"	
			# build for oanda 
			end
		else
			puts "\n-- No Trader Found --\n"
		end

	end
	private

	def autoTradingKeysparams
    params.require(:editKeys).permit(:krakenLiveAPI, :krakenLiveSecret, :krakenTestAPI, :krakenTestSecret)
  end
end

