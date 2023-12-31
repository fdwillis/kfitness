# tvData = {"direction"=>"buy", "ticker"=>"EURJPY", "traderID"=>"d57307d7", "broker"=>"OANDA", 'type' => 'kill', 'killType' => 'all'}
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  def self.killType(tvData, apiKey = nil, secretKey = nil)
    if tvData['broker'] == 'OANDA'

      @userX = User.find_by(oandaToken: apiKey)
      @openTrades = Oanda.oandaPendingOrders(apiKey, secretKey)['orders']&.reject{|d|d['type'] == 'TAKE_PROFIT'}&.reject{|d|d['type'] == 'STOP_LOSS'}&.reject{|d|d['instrument'].delete('_') != tvData['ticker']}
      @closedTrades = Oanda.oandaRequest(apiKey, secretKey).account(secretKey).open_trades.show['trades'].reject{|d|d['instrument'].delete('_') != tvData['ticker']}

      (@closedTrades).each do |tradeX|
        @userX.trades.find_or_create_by(uuid: tradeX['id'], ticker:tvData['ticker'], traderID: tvData['traderID'], broker: tvData['broker'], cost: tradeX['initialMarginRequired'].to_f)
        begin

          requestK = Oanda.oandaOrder(apiKey, secretKey, tradeX['id'])
            
          if requestK['order']['state'] == 'CANCELLED'
            tradeX.update(status: 'canceled')
          elsif requestK['order']['state'] == 'PENDING'
            tradeX.update(status: 'open')
          elsif requestK['order']['state'] == 'FILLED'
            tradeX.update(status: 'closed')
          end
        rescue Exception => e

            break
          
        end
      end

              
      if tvData['direction'] == 'sell' && LastSignal&.find_by(ticker: tvData['ticker'])&.direction == 'buy'
        if tvData['killType'] == 'pending'
          @openTrades.each do |tradeX|
            cancel = Oanda.oandaCancel(apiKey, secretKey, tradeX['id'])
            puts "\n-- KILLED #{tradeX['id']} --\n"
          end
        elsif (tvData['killType'] == 'profit')
              
          @closedTrades.each do |tradeX|
            begin
              if tradeX['unrealizedPL'].to_f * (0.01 * traderFound&.reduceBy) >= 0.05  && tradeX['initialUnits'].to_i.negative? #and proper units
                takeProfitX = Oanda.closePosition(apiKey, secretKey, tvData, ourTradeX, tradeX, 'reduce')
              end   
            rescue Exception => e
              
              break

              
            end
          end
        elsif tvData['killType'] == 'all'
          # kill buy sell/put
          @openTrades.each do |tradeX|
            if tradeX['units'].to_f.negative?
              cancel = Oanda.oandaCancel(apiKey, secretKey, tradeX['id'])
              puts "\n-- KILLED #{tradeX['id']} --\n"
            end
          end
              
          (@closedTrades).each do |tradeX|
            begin
              ourTradeX = @userX.trades.find_by(uuid: tradeX['id'])
              takeProfitX = Oanda.closePosition(apiKey, secretKey, tvData, ourTradeX, tradeX, 'kill')
            rescue Exception => e
              
              break
              
            end
          end
        end
      end

      if tvData['direction'] == 'buy' && LastSignal&.find_by(ticker: tvData['ticker'])&.direction == 'sell'
        if tvData['killType'] == 'pending'
          @openTrades.each do |tradeX|
            cancel = Oanda.oandaCancel(apiKey, secretKey, tradeX['id'])
            puts "\n-- KILLED #{tradeX['id']} --\n"
          end
        elsif (tvData['killType'] == 'profit')
              
          @closedTrades.each do |tradeX|
            begin 
              if tradeX['unrealizedPL'].to_f * (0.01 * traderFound&.reduceBy) >= 0.05 && tradeX['initialUnits'].to_i.positive?#and proper units
                takeProfitX = Oanda.closePosition(apiKey, secretKey, tvData, ourTradeX, tradeX, 'reduce')
              end              
            rescue Exception => e
              
              break
              
            end
          end
        elsif tvData['killType'] == 'all'
          # kill buy sell/put
          @openTrades.each do |tradeX|
            if tradeX['units'].to_f.positive?
              cancel = Oanda.oandaCancel(apiKey, secretKey, tradeX['id'])
              puts "\n-- KILLED #{tradeX['id']} --\n"
            end
          end

          (@closedTrades).each do |tradeX|
            begin
              ourTradeX = @userX.trades.find_by(uuid: tradeX['id'])
              takeProfitX = Oanda.closePosition(apiKey, secretKey, tvData, ourTradeX, tradeX, 'kill')
            rescue Exception => e
            
              break
              
            end
          end
        end
      end


      # killall 
      # killprofitable

    elsif tvData['broker'] == 'TRADIER'
    end

    puts "\n-- KILL COMPLETE --\n"
  end

  def self.trailStop(tvData, apiKey = nil, secretKey = nil)
    if tvData['broker'] == 'OANDA'
      @userX = User.find_by(oandaToken: apiKey)
      @openTrades = Oanda.oandaRequest(apiKey, secretKey).account(secretKey).open_trades.show['trades'].reject{|d|d['instrument'].delete('_') != tvData['ticker']}
      @traderFound = @userX
    elsif tvData['broker'] == 'TRADIER'
    end

    puts "\n-- Current Price: #{tvData['currentPrice'].to_f} --\n"
    # update trade status
    if @openTrades.present? && @openTrades.size > 0
      @openTrades.each do |trade|
        @userX.trades.find_or_create_by(uuid: trade['id'], ticker:tvData['ticker'], traderID: tvData['traderID'], broker: tvData['broker'], cost: trade['initialMarginRequired'].to_f, direction: trade['initialUnits'].to_f.negative? ? 'sell' : 'buy')

        if tvData['ticker'] == 'OANDA'
          requestK = Oanda.oandaOrder(apiKey, secretKey, trade['id'])
            
          if requestK['order']['state'] == 'CANCELLED'
            @userX.trades.find_by(uuid: trade['id']).update(status: 'canceled')
          elsif requestK['order']['state'] == 'PENDING'
            @userX.trades.find_by(uuid: trade['id']).update(status: 'open')
          elsif requestK['order']['state'] == 'FILLED'
            @userX.trades.find_by(uuid: trade['id']).update(status: 'closed')
          end

        elsif tvData['ticker'] == 'TRADIER'
        end
      end
    end
    # pull closed/filled bot trades
    if tvData['broker'] == 'OANDA'
      afterUpdates =  @userX.trades.where(broker: 'OANDA', direction: tvData['direction'], ticker: tvData['ticker'])
    elsif tvData['broker'] == 'TRADIER'
    end


    # protect closed/filled bot trades
    if afterUpdates.present? && afterUpdates.size > 0
      afterUpdates.each do |tradeX|
        puts "\n-- Starting For #{tradeX.uuid} --\n"
        if tradeX&.broker == 'OANDA'
          @requestOriginalE = Oanda.oandaTrade(apiKey, secretKey, tradeX.uuid)['trade']
          
          originalPrice = @requestOriginalE['price'].present? ? @requestOriginalE['price'].to_f : 0
          originalVolume = @requestOriginalE['initialUnits'].to_f
        elsif tradeX&.broker == 'TRADIER'
        end

        profitTrigger = originalPrice * (0.01 * @traderFound&.profitTrigger)
        volumeTallyForTradex = 0
        openProfitCount = 0

        if tradeX&.broker == 'OANDA'
          profitTriggerPassed = (originalPrice + profitTrigger).round(5).to_f
        elsif tradeX&.broker == 'TRADIER'
        end

        # make trail proce profir trigger 
        if  @requestOriginalE['unrealizedPL'].to_f >= 0.03
          if @requestOriginalE['currentUnits'].to_f.positive?
            if tvData['direction'] == 'buy'
              if tradeX.take_profits.size == 0
                if  tvData['broker'] == 'OANDA'
                
                  @protectTrade = Oanda.closePosition(apiKey, secretKey, tvData, tradeX, @requestOriginalE, 'reduce')
                  
                  if @protectTrade.present? && !@protectTrade.empty?&& !@protectTrade.nil?# && @protectTrade['orderCreateTransaction']['id'].present?
                    puts 	"\n-- Taking Profit #{tradeX.uuid} --\n"
                  end

                elsif tvData['broker'] == 'TRADIER'
                end
              else

                tradeX.take_profits.each  do |profitTrade|
                  if  tvData['broker'] == 'OANDA'
                    requestProfitTradex = Oanda.oandaOrder(apiKey, secretKey, profitTrade.uuid.to_i - 1)

                    if requestProfitTradex['order']['state'] == 'FILLED'
                      profitTrade.update(status: 'closed')
                    elsif requestProfitTradex['order']['state'] == 'PENDING'
                      profitTrade.update(status: 'open')
                    elsif requestProfitTradex['order']['state'] == 'CANCELLED'
                      profitTrade.update(status: 'canceled')
                    end
                    volumeForProfit = requestProfitTradex['order']['units'].to_f
                    priceToBeat = requestProfitTradex['order']['price'].to_f
                  elsif tvData['broker'] == 'TRADIER'
                  end
                  
                  if profitTrade.status == 'open' # or other status from oanda/alpaca
                    volumeTallyForTradex += volumeForProfit
                    openProfitCount += 1
                    
                    if  tvData['broker'] == 'OANDA'
                      if @requestOriginalE['unrealizedPL'].to_f >= 0.03
                        cancel = Oanda.oandaCancel(apiKey, secretKey, profitTrade.uuid)
                        puts "\n-- Old Take Profit Canceled --\n"
                        @protectTrade = Oanda.closePosition(apiKey, secretKey, tvData, tradeX, @requestOriginalE, 'reduce')
                        
                        if @protectTrade.present? && !@protectTrade.empty?&& !@protectTrade.nil?# && @protectTrade['orderCreateTransaction']['id'].present?
                          puts  "\n-- Repainting Take Profit #{tradeX.uuid} --\n"
                        end
                        break
                      end

                    elsif tvData['broker'] == 'TRADIER'
                    end
                  elsif profitTrade.status == 'closed' # or other status from oanda/alpaca
                    volumeTallyForTradex += volumeForProfit
                  elsif profitTrade.status == 'canceled' # or other status from oanda/alpaca
                    puts "\n-- Removing Canceled Order #{profitTrade.uuid} --\n"
                    break
                  end
                end

                if volumeTallyForTradex < originalVolume
                  if openProfitCount == 0
                    if tvData['broker'] == 'OANDA'
                      @protectTrade = Oanda.closePosition(apiKey, secretKey, tvData, tradeX, @requestOriginalE, 'reduce')
                      
                      if @protectTrade.present? && !@protectTrade.empty?&& !@protectTrade.nil?# && @protectTrade['orderCreateTransaction']['id'].present?
                        puts  "\n-- Additional Take Profit #{tradeX.uuid} --\n"
                      end

                    elsif tvData['broker'] == 'TRADIER'
                    end
                  else
                    puts "\n-- Waiting To Close Open Take Profit --\n"
                  end
                else
                  if tvData['broker'] == 'OANDA'
                    checkFill = Oanda.oandaTrade(apiKey, secretKey, tradeX.uuid)
                  
                    if checkFill['trade']['state'] == 'PENDING'
                      tradeX.update(finalTakeProfit: nil)
                    elsif checkFill['trade']['state'] == 'CLOSED'
                      tradeX.update(finalTakeProfit:  tradeX.take_profits.last.uuid)
                      tradeX.take_profits.last.update(status: 'closed')
                    end
                  elsif tvData['broker'] == 'TRADIER'
                  end
                end
              end
            end
          elsif @requestOriginalE['currentUnits'].to_f.negative?
            if tvData['direction'] == 'sell'

              if tradeX.take_profits.size == 0
                  
                if tvData['broker'] == 'OANDA'
                  @protectTrade = Oanda.closePosition(apiKey, secretKey, tvData, tradeX, @requestOriginalE, 'reduce')
                  
                  if @protectTrade.present? && !@protectTrade.empty?&& !@protectTrade.nil?# && @protectTrade['orderCreateTransaction']['id'].present?
                    puts  "\n-- Taking Profit #{tradeX.uuid} --\n"
                  end

                elsif tvData['broker'] == 'TRADIER'
                end
              else

                tradeX.take_profits.each do |profitTrade|
                  if tvData['broker'] == 'OANDA'
                    requestProfitTradex = Oanda.oandaOrder(apiKey, secretKey, profitTrade.uuid.to_i - 1)

                    if requestProfitTradex['order']['state'] == 'CLOSED'
                      profitTrade.update(status: 'closed')
                    elsif requestProfitTradex['order']['state'] == 'OPEN'
                      profitTrade.update(status: 'open')
                    elsif requestProfitTradex['order']['state'] == 'CANCELLED'
                      profitTrade.update(status: 'canceled')
                    end
                    volumeForProfit = requestProfitTradex['order']['units'].to_f
                    priceToBeat = requestProfitTradex['order']['price'].to_f
                  elsif tvData['broker'] == 'TRADIER'
                  end

                  if profitTrade.status == 'open' # or other status from oanda/alpaca
                    volumeTallyForTradex += volumeForProfit
                    openProfitCount += 1

                    if tvData['broker'] == 'OANDA'
                      if @requestOriginalE['unrealizedPL'].to_f >= 0.03
                        cancel = Oanda.oandaCancel(apiKey, secretKey, profitTrade.uuid)
                        puts "\n-- Old Take Profit Canceled --\n"
                        @protectTrade = Oanda.closePosition(apiKey, secretKey, tvData, tradeX, @requestOriginalE, 'reduce')
                        
                        if @protectTrade.present? && !@protectTrade.empty?&& !@protectTrade.nil?# && @protectTrade['orderCreateTransaction']['id'].present?
                          puts  "\n-- Repainting Take Profit #{tradeX.uuid} --\n"
                        end
                      end
                    elsif tvData['broker'] == 'TRADIER'
                    end
                  elsif profitTrade.status == 'closed' # or other status from oanda/alpaca
                    volumeTallyForTradex += volumeForProfit
                  elsif profitTrade.status == 'canceled' # or other status from oanda/alpaca
                    puts "\n-- Removing Canceled Order #{profitTrade.uuid} --\n"
                    break
                  end
                end

                if volumeTallyForTradex > originalVolume
                  if openProfitCount == 0
                    if tvData['broker'] == 'OANDA'
                      @protectTrade = Oanda.closePosition(apiKey, secretKey, tvData, tradeX, @requestOriginalE, 'reduce')
                      if @requestOriginalE['currentUnits'].to_f < 0 && @requestOriginalE['unrealizedPL'].to_f >= 0.05

                        if @protectTrade.present? && !@protectTrade.empty?&& !@protectTrade.nil?# && @protectTrade['orderCreateTransaction']['id'].present?
                          puts  "\n-- Additional Take Profit #{tradeX.uuid} --\n"
                        end
                      end
                    elsif tvData['broker'] == 'TRADIER'
                    end
                  else
                    puts "\n-- Waiting To Close Open Take Profit --\n"
                  end
                else
                  if tvData['broker'] == 'OANDA'
                    checkFill = Oanda.oandaTrade(apiKey, secretKey, tradeX.uuid)
                    if checkFill['trade']['state'] == 'PENDING'
                      tradeX.update(finalTakeProfit: nil)
                    elsif checkFill['trade']['state'] == 'CLOSED'
                      tradeX.update(finalTakeProfit:  tradeX.take_profits.last.uuid)
                      tradeX.take_profits.last.update(status: 'closed')
                    end
                  elsif tvData['broker'] == 'TRADIER'
                  end
                end

              end
            end
          end
        else
          if @requestOriginalE['currentUnits'].to_f.abs == 0
            tradeX.update(finalTakeProfit: tradeX.take_profits.present? ? tradeX.take_profits.last.uuid : 'closed')
          else
            puts "\n-- Waiting For Profit --\n"
          end
        end
      end
    end

    puts 'Done Checking Profit'
  end

  def self.newEntry(tvData, apiKey = nil, secretKey = nil)
    # if there is a current open/pending trade -> do not make new one (let it fill or cancel when it flips)
    currentFilledListToSum =  @traderFound&.trades

    if tvData['broker'] == 'OANDA'
      @traderFound = User.find_by(oandaToken: apiKey)
    elsif tvData['broker'] == 'TRADIER'
      @traderFound = User.find_by(tradierToken: apiKey)
    end



    # variables
    orderforMulti = 0

    if tvData['broker'] == 'OANDA'
      @amountToRisk = Oanda.oandaRisk(tvData, apiKey, secretKey)

      oandaAccount = Oanda.oandaAccount(apiKey, secretKey)
      cleanTickers = oandaAccount['account']['positions'].map { |d| d['instrument'].tr!('_', '') }

      foundTickerPosition = oandaAccount['account']['positions'].reject { |d| d['instrument'] != tvData['ticker'] }.first
      foundTickerOrders = oandaAccount['account']['orders'].reject { |d| d['instrument'] != "#{tvData['ticker'][0..2]}_#{tvData['ticker'][3..5]}" }

      marginUsed = foundTickerPosition.present? && foundTickerPosition['marginUsed'].present? ? foundTickerPosition['marginUsed'].to_f : 0

      openOrders = (oandaAccount['account']['marginRate'].to_f * foundTickerOrders.map { |d| d['units'].to_i }.sum)
      openOrdersPending = openOrders
      accountBalance = ((marginUsed + openOrders) + oandaAccount['account']['marginAvailable'].to_f)

      orderforMulti += @traderFound&.allowMarketOrder == 'true' ? 1 : 0
      tvData['entries'].reject(&:blank?).size > 0 ? orderforMulti += tvData['entries'].reject(&:blank?).size : orderforMulti += 0
    elsif tvData['broker'] == 'TRADIER'
    end

    
    if tvData['broker'] == 'OANDA'
     @currentRisk = calculateRiskAfterTrade(marginUsed,openOrdersPending, (@amountToRisk * orderforMulti),  accountBalance)
    elsif tvData['broker'] == 'TRADIER'
    end

    # ticker specific

    if tvData['ticker'] == 'BTCUSD'
      @unitsFiltered = (@unitsToTrade > 0.0001 ? @unitsToTrade : 0.0001)
    end
    
    #logic permissionPass
    if  (@currentRisk.abs.round(2) < @traderFound&.maxRisk && @currentRisk.abs.round(2) >= 0)
      # market order
      if @traderFound&.allowMarketOrder == 'true'
        # set order params

        if tvData['broker'] == 'OANDA'
          oandaOrderParams = {
            'order' => {
              'units' => tvData['direction'] == 'buy' ? (@amountToRisk == oandaAccount['account']['marginRate'].to_f ? 1 : @amountToRisk.round).to_s : (@amountToRisk == oandaAccount['account']['marginRate'].to_f ? -1 : -@amountToRisk.round).to_s,
              'instrument' => "#{tvData['ticker'][0..2]}_#{tvData['ticker'][3..5]}",
              'timeInForce' => 'FOK',
              'type' => 'MARKET',
              'positionFill' => 'DEFAULT'
            }
          }
        elsif tvData['broker'] == 'TRADIER'
        end

        # call order
        if tvData['direction'] == 'buy' && LastSignal&.find_by(ticker: tvData['ticker'])&.direction == tvData['direction']

          if tvData['broker'] == 'OANDA'
            @requestK = Oanda.oandaEntry(apiKey, secretKey, oandaOrderParams)
          elsif tvData['broker'] == 'TRADIER'
          end
        end

        # put order
        if tvData['direction'] == 'sell' && LastSignal&.find_by(ticker: tvData['ticker'])&.direction == tvData['direction']

          if  tvData['broker'] == 'OANDA'
            @requestK = Oanda.oandaEntry(apiKey, secretKey, oandaOrderParams)
          elsif tvData['broker'] == 'TRADIER'
          end
        end

        # update database with ID from @requestK

        if tvData['broker'] == 'OANDA'

          if @requestK.present? && !@requestK['orderCancelTransaction'].present? && @requestK['orderFillTransaction']['tradeOpened'].present?
            puts "\n-- #{tvData['broker']} Entry Submitted --\n"
            puts "\n-- Current Risk #{@currentRisk.abs.round(2)} --\n"
          end
        elsif tvData['broker'] == 'TRADIER'
        end
      end

      # limit order
      
      if tvData['entries'].reject(&:blank?).size > 0
        tvData['entries'].reject(&:blank?).each do |entryPrice|
          # set order params

          if tvData['broker'] == 'OANDA'
            oandaOrderParams = {
              'order' => {
                'price' => entryPrice,
                'units' => tvData['direction'] == 'buy' ? (@amountToRisk == oandaAccount['account']['marginRate'].to_f ? 1 : @amountToRisk.round).to_s : (@amountToRisk == oandaAccount['account']['marginRate'].to_f ? -1 : -@amountToRisk.round).to_s,
                'instrument' => "#{tvData['ticker'][0..2]}_#{tvData['ticker'][3..5]}",
                'timeInForce' => 'GTC',
                'type' => 'LIMIT',
                'positionFill' => 'DEFAULT'
              }
            }
          elsif tvData['broker'] == 'TRADIER'

          end
          # call order
          if tvData['direction'] == 'buy' && LastSignal&.find_by(ticker: tvData['ticker'])&.direction == tvData['direction']

            if tvData['broker'] == 'OANDA'
              requestK = Oanda.oandaEntry(apiKey, secretKey, oandaOrderParams)
            elsif tvData['broker'] == 'TRADIER'
            end
          end
          # put order
          if tvData['direction'] == 'sell' && LastSignal&.find_by(ticker: tvData['ticker'])&.direction == tvData['direction']

            if tvData['broker'] == 'OANDA'
              requestK = Oanda.oandaEntry(apiKey, secretKey, oandaOrderParams)
            elsif tvData['broker'] == 'TRADIER'
            end
          end

          # update database with ID from requestK

          if tvData['broker'] == 'OANDA'

            if  requestK.present?
              puts "\n-- #{tvData['broker']} Entry Submitted --\n"
              puts "\n-- Current Risk #{@currentRisk.abs.round(2)} --\n"
            else
              puts "\n-- NOTHING --\n"
            end
          elsif tvData['broker'] == 'TRADIER'

          end
        end
      else
        puts "\n-- No Limit Orders Set --\n"
      end

    else
      puts "\n-- Max Risk Met (#{tvData['timeframe']} Minute) --\n"
      puts "\n-- Trader #{@traderFound.uuid} --\n"
      puts "\n-- Current Risk (#{@currentRisk.abs.round(2)}%) --\n"
      puts "\n-- Trader #{@traderFound.uuid} --\n"
    end
  end

  def self.calculateRiskAfterTrade(filledOrders,openOrdersPending, amountToRisk, accountBalance)
    ((filledOrders + openOrdersPending ) / accountBalance) * 100
  end

  # combine limit and market into one 'entry' call with logic to determine wich
end
