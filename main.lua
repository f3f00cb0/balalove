-- Global variables
gameState = "menu" -- Initial game state

-- UI Message variables
currentUIMessage = ""
uiMessageTimer = 0
uiMessageDuration = 3 -- seconds

-- Sound Effects (placeholders)
sfxCardDeal = nil
sfxCardSelect = nil
sfxCardPlay = nil
sfxDiscard = nil
sfxError = nil
sfxShopPurchase = nil
sfxRoundClear = nil
sfxActionConfirm = nil
sfxActionCancel = nil
sfxShopReroll = nil 
sfxShopSell = nil -- New placeholder for selling

-- Player Stats
playerStats = {} 
previousRoundShopStatus = false 
playerMoney = 0 

-- Shop Variables
baseRerollCost = 0 
currentRerollCost = 0
shopMode = "buy" -- "buy" or "sell"
selectedOwnedJokerIndex = nil -- For selecting owned jokers in sell mode

function playSound(soundEffect)
    if soundEffect and love.audio then 
        love.audio.stop(soundEffect) 
        love.audio.play(soundEffect)
    end
end

function updateUIMessage(dt)
    if uiMessageTimer > 0 then
        uiMessageTimer = uiMessageTimer - dt
        if uiMessageTimer <= 0 then
            currentUIMessage = ""
        end
    end
end

function setUIMessage(message, duration)
    currentUIMessage = message
    uiMessageTimer = duration or uiMessageDuration
end


-- LÖVE 2D Callbacks

-- Shop related variables
shopItems = {}
availableShopJokers = {} 
selectedShopItemIndex = 1 

-- Helper function to check if player already owns a specific joker by ID (name)
function playerOwnsJoker(jokerId)
    for _, ownedJoker in ipairs(playerJokers) do
        if ownedJoker.id == jokerId then
            return true
        end
    end
    return false
end

function generateShopItems()
    currentRerollCost = baseRerollCost 
    shopItems = {} 
    selectedShopItemIndex = 1
    shopMode = "buy" -- Default to buy mode when shop is (re)generated
    selectedOwnedJokerIndex = nil -- Clear sell selection

    local numItemsToOffer = math.min(#availableShopJokers, math.random(2, 3))
    
    local offeredJokerIds = {} 
    local tempAvailable = {}
    for _, jokerData in ipairs(availableShopJokers) do
        table.insert(tempAvailable, jokerData)
    end

    local attempts = 0
    local maxAttemptsPerSlot = #availableShopJokers * 2 

    for i = 1, numItemsToOffer do
        if #tempAvailable == 0 then break end 
        
        local chosenJokerData = nil
        local foundUniqueUnowned = false
        local currentSlotAttempts = 0

        while not foundUniqueUnowned and #tempAvailable > 0 and currentSlotAttempts < maxAttemptsPerSlot do
            local randomIndex = math.random(#tempAvailable)
            local potentialJokerData = tempAvailable[randomIndex] 

            if not playerOwnsJoker(potentialJokerData.name) and not offeredJokerIds[potentialJokerData.name] then
                chosenJokerData = table.remove(tempAvailable, randomIndex) 
                offeredJokerIds[chosenJokerData.name] = true
                foundUniqueUnowned = true
            else
                table.remove(tempAvailable, randomIndex) 
            end
            currentSlotAttempts = currentSlotAttempts + 1
            attempts = attempts + 1
        end

        if chosenJokerData then
            table.insert(shopItems, Joker:new(chosenJokerData.name, chosenJokerData.description, chosenJokerData.effectType, chosenJokerData.value, chosenJokerData.uses_total))
            if chosenJokerData.conceptualCost then shopItems[#shopItems].conceptualCost = chosenJokerData.conceptualCost end
            if chosenJokerData.rarity then shopItems[#shopItems].rarity = chosenJokerData.rarity end
        end
        if attempts > maxAttemptsPerSlot * numItemsToOffer then 
             print("Warning: Max attempts reached in generateShopItems. Shop might not be full.")
             break
        end
    end

    if #shopItems > 0 then
        setUIMessage("Shop: Buy Mode. Select (1-" .. #shopItems .. "), Enter to buy. [S] to Sell. [C] to continue.", 5)
    else
        setUIMessage("Shop: Buy Mode. Shop empty. [S] to Sell. [C] to continue.", 5)
    end
end

function cleanupAndApplyJokerRoundEndEffects()
    for _, joker in ipairs(playerJokers) do
        if joker.apply_ante_reduction_now and joker.value and joker.value.reductionPercent then
            local reduction = joker.value.reductionPercent
            targetScore = math.floor(targetScore * (1 - reduction))
            print("Joker '" .. joker.name .. "' reduced next ante by " .. (reduction * 100) .. "%. New target for upcoming round: " .. targetScore)
            joker.apply_ante_reduction_now = false 
        end
    end

    local i = #playerJokers
    while i >= 1 do
        if playerJokers[i].marked_for_destruction then
            print("Removing used up/destroyed Joker: " .. playerJokers[i].name)
            table.remove(playerJokers, i)
            playSound(sfxError) 
        end
        i = i - 1
    end
end


function love.load()
    require("card_graphics") 
    Card = require("card")
    Deck = require("deck")
    Hand = require("hand")
    HandEvaluator = require("hand_evaluator")
    Joker = require("joker") 

    if love.filesystem.exists("assets/sounds/card_deal.ogg") then
        sfxCardDeal = love.audio.newSource("assets/sounds/card_deal.ogg", "static")
    end
    if love.filesystem.exists("assets/sounds/card_select.ogg") then
        sfxCardSelect = love.audio.newSource("assets/sounds/card_select.ogg", "static")
    end
    if love.filesystem.exists("assets/sounds/card_play.ogg") then
        sfxCardPlay = love.audio.newSource("assets/sounds/card_play.ogg", "static")
    end
    if love.filesystem.exists("assets/sounds/discard.ogg") then
        sfxDiscard = love.audio.newSource("assets/sounds/discard.ogg", "static")
    end
    if love.filesystem.exists("assets/sounds/error.ogg") then
        sfxError = love.audio.newSource("assets/sounds/error.ogg", "static")
    end
    if love.filesystem.exists("assets/sounds/shop_purchase.ogg") then
        sfxShopPurchase = love.audio.newSource("assets/sounds/shop_purchase.ogg", "static")
    end
    if love.filesystem.exists("assets/sounds/round_clear.ogg") then
        sfxRoundClear = love.audio.newSource("assets/sounds/round_clear.ogg", "static")
    end
    if love.filesystem.exists("assets/sounds/action_confirm.ogg") then
        sfxActionConfirm = love.audio.newSource("assets/sounds/action_confirm.ogg", "static")
    end
    if love.filesystem.exists("assets/sounds/action_cancel.ogg") then
        sfxActionCancel = love.audio.newSource("assets/sounds/action_cancel.ogg", "static")
    end
    if love.filesystem.exists("assets/sounds/shop_reroll.ogg") then 
        sfxShopReroll = love.audio.newSource("assets/sounds/shop_reroll.ogg", "static")
    else
        sfxShopReroll = sfxCardDeal 
    end
     if love.filesystem.exists("assets/sounds/shop_sell.ogg") then -- New sound for selling
        sfxShopSell = love.audio.newSource("assets/sounds/shop_sell.ogg", "static")
    else
        sfxShopSell = sfxShopPurchase -- Fallback
    end


    -- Game loop variables
    playerScore = 0 
    currentRound = 1
    targetScore = 100 
    initialPlayerPlaysAllowed = 4 
    playerDiscardsRemaining = 3
    playerPlaysRemaining = initialPlayerPlaysAllowed 
    initialHandSize = 8 
    playerMoney = 10 
    baseRerollCost = 1 
    currentRerollCost = baseRerollCost
    shopMode = "buy" -- Initialize shop mode
    
    playerStats = { maxHandSize = initialHandSize, boughtInShopLastRound = false }

    handSelectedCardIndices = {} 
    stagedCards = {}             
    currentActionType = nil      
    discardPile = {} 

    playerJokers = {} 
    
    -- Populate availableShopJokers (master list for the shop)
    table.insert(availableShopJokers, {name="Joker of Spades", description="+15 flat bonus", effectType="flat_score_bonus", value=15, rarity = "Common", conceptualCost = 4})
    table.insert(availableShopJokers, {name="Joker of Hearts", description="Score x1.2", effectType="score_multiplier", value=1.2, rarity = "Common", conceptualCost = 5})
    table.insert(availableShopJokers, {name="Joker of Clubs", description="+25 flat bonus", effectType="flat_score_bonus", value=25, rarity = "Common", conceptualCost = 5})
    table.insert(availableShopJokers, {name="Joker of Diamonds", description="Score x1.3", effectType="score_multiplier", value=1.3, rarity = "Common", conceptualCost = 6})
    table.insert(availableShopJokers, {name="Glass Joker", description="Score x2 (Fragile!)", effectType="score_multiplier", value=2.0, rarity = "Uncommon", conceptualCost = 8}) 
    table.insert(availableShopJokers, {name="Stone Joker", description="+50 flat bonus", effectType="flat_score_bonus", value=50, rarity = "Uncommon", conceptualCost = 7})
    table.insert(availableShopJokers, {name="Golden Joker", description="Score x1.5", effectType="score_multiplier", value=1.5, rarity = "Uncommon", conceptualCost = 7}) 
    table.insert(availableShopJokers, {name="Lucky Joker", description="+7 flat bonus", effectType="flat_score_bonus", value=7, rarity = "Common", conceptualCost = 4})
    -- Set A Jokers
    table.insert(availableShopJokers, {name = "Straight Shooter", description = "Straights score an additional x2 multiplier.", effectType = "hand_type_score_multiplier", value = { handType = "Straight", multiplier = 2 }, rarity = "Uncommon", conceptualCost = 7})
    table.insert(availableShopJokers, {name = "Flush Fever", description = "Flushes gain a +75 flat score bonus.", effectType = "hand_type_flat_bonus", value = { handType = "Flush", bonus = 75 }, rarity = "Uncommon", conceptualCost = 7})
    table.insert(availableShopJokers, {name = "Ace High Club", description = "+15 score for each Ace in your played hand.", effectType = "rank_specific_flat_bonus_per_card", value = { rank = "A", bonusPerCard = 15 }, rarity = "Common", conceptualCost = 5})
    table.insert(availableShopJokers, {name = "Lucky Number Seven", description = "Any played hand containing at least one '7' gets a +35 flat score bonus.", effectType = "conditional_flat_bonus_on_rank_present", value = { rank = "7", bonus = 35 }, rarity = "Common", conceptualCost = 4})
    table.insert(availableShopJokers, {name = "Red Suit Riches", description = "Played hands containing only Red suit cards (Hearts, Diamonds) get an additional x1.5 multiplier.", effectType = "conditional_score_multiplier_all_suits_are_color", value = { color = "Red", multiplier = 1.5 }, rarity = "Uncommon", conceptualCost = 6})
    -- Set B Jokers
    table.insert(availableShopJokers, {name = "Pair Parity", description = "Pairs: +20 if paired rank is even, +10 if odd.", effectType = "conditional_hand_type_bonus_rank_math", value = { handType = "Pair", evenBonus = 20, oddBonus = 10 }, rarity = "Common", conceptualCost = 5})
    table.insert(availableShopJokers, {name = "High Roller", description = "Played hands with 3+ Face Cards (J,Q,K) get +50 score.", effectType = "conditional_flat_bonus_card_property_count", value = { property = "isFaceCard", threshold = 3, bonus = 50 }, rarity = "Uncommon", conceptualCost = 7})
    table.insert(availableShopJokers, {name = "Suit Sampler", description = "+10 score for each unique suit in the played hand.", effectType = "flat_bonus_per_unique_suit_in_played_hand", value = { bonusPerUniqueSuit = 10 }, rarity = "Common", conceptualCost = 5})
    table.insert(availableShopJokers, {name = "Consecutive Bonus", description = "If played hand's ranks are consecutive, gain +25 score.", effectType = "conditional_flat_bonus_consecutive_ranks", value = { bonus = 25 }, rarity = "Common", conceptualCost = 5})
    table.insert(availableShopJokers, {name = "Steady Scorer", description = "All played hands get a +10 flat score bonus.", effectType = "flat_score_bonus", value = 10, rarity = "Common", conceptualCost = 4})
    table.insert(availableShopJokers, {name = "Blackjack Bonus", description = "If sum of ranks in played hand is 21 (Ace=1/11, JQK=10), score x2.", effectType = "conditional_score_multiplier_blackjack_sum", value = { targetSum = 21, multiplier = 2 }, rarity = "Rare", conceptualCost = 10})
    table.insert(availableShopJokers, {name = "Round Number Riches", description = "Gain flat score bonus = current round number x 3.", effectType = "flat_bonus_based_on_round_number", value = { multiplier = 3 }, rarity = "Uncommon", conceptualCost = 7})
    -- Set C Jokers
    table.insert(availableShopJokers, {name = "Three's Company", description = "Three of a Kind scores an additional x2.5 multiplier.", effectType = "hand_type_score_multiplier", value = { handType = "ThreeOfAKind", multiplier = 2.5 }, rarity = "Uncommon", conceptualCost = 8})
    table.insert(availableShopJokers, {name = "Full House Fortune", description = "Full Houses gain a +100 flat score bonus.", effectType = "hand_type_flat_bonus", value = { handType = "FullHouse", bonus = 100 }, rarity = "Rare", conceptualCost = 10})
    table.insert(availableShopJokers, {name = "Royal Treatment", description = "+25 score for each King or Queen in your played hand.", effectType = "multi_rank_specific_flat_bonus_per_card", value = { ranks = {"K", "Q"}, bonusPerCard = 25 }, rarity = "Uncommon", conceptualCost = 7})
    table.insert(availableShopJokers, {name = "Even Stevens", description = "If all cards in played hand have EVEN ranks, score x2.", effectType = "conditional_score_multiplier_all_cards_property", value = { property = "isEvenRank", multiplier = 2 }, rarity = "Rare", conceptualCost = 10})
    table.insert(availableShopJokers, {name = "Odd Baller", description = "If all cards in played hand have ODD ranks, score x2.", effectType = "conditional_score_multiplier_all_cards_property", value = { property = "isOddRank", multiplier = 2 }, rarity = "Rare", conceptualCost = 10})
    table.insert(availableShopJokers, {name = "Monochrome Hand (Red)", description = "Played hands with only Red suit cards get +50 score.", effectType = "conditional_flat_bonus_all_suits_are_color", value = { color = "Red", bonus = 50 }, rarity = "Uncommon", conceptualCost = 6})
    table.insert(availableShopJokers, {name = "Monochrome Hand (Black)", description = "Played hands with only Black suit cards get +50 score.", effectType = "conditional_flat_bonus_all_suits_are_color", value = { color = "Black", bonus = 50 }, rarity = "Uncommon", conceptualCost = 6})
    table.insert(availableShopJokers, {name = "Discard Power", description = "Gain +8 score for each discard remaining on your last play.", effectType = "end_of_round_bonus_discards_remaining", value = { bonusPerDiscard = 8 }, rarity = "Common", conceptualCost = 5}) 
    table.insert(availableShopJokers, {name = "Hand Size Bonus", description = "Gain +10 score for each card in your hand when playing.", effectType = "flat_bonus_per_card_in_current_hand_on_play", value = { bonusPerCard = 10 }, rarity = "Uncommon", conceptualCost = 6})
    table.insert(availableShopJokers, {name = "Joker Hoarder", description = "Gain +20 score for each OTHER Joker you possess.", effectType = "flat_bonus_per_other_joker_owned", value = { bonusPerJoker = 20 }, rarity = "Rare", conceptualCost = 12})
    table.insert(availableShopJokers, {name = "First Play Focus", description = "Your first hand played each round gets a x1.5 multiplier.", effectType = "conditional_multiplier_first_play_of_round", value = { multiplier = 1.5 }, rarity = "Uncommon", conceptualCost = 7})
    table.insert(availableShopJokers, {name = "Last Chance Saloon", description = "If this is your last play of the round, gain +75 flat bonus.", effectType = "conditional_flat_bonus_last_play_of_round", value = { bonus = 75 }, rarity = "Uncommon", conceptualCost = 8})
    -- Set D Jokers
    table.insert(availableShopJokers, {name = "Fourberie", description = "Four of a Kind scores an additional x3 multiplier.", effectType = "hand_type_score_multiplier", value = { handType = "FourOfAKind", multiplier = 3 }, rarity = "Rare", conceptualCost = 12})
    table.insert(availableShopJokers, {name = "Straight Flush Supreme", description = "Straight Flushes gain a +250 flat score bonus.", effectType = "hand_type_flat_bonus", value = { handType = "StraightFlush", bonus = 250 }, rarity = "Legendary", conceptualCost = 15})
    table.insert(availableShopJokers, {name = "Low Card Loyalty", description = "+5 score for each card rank 2-6 in your played hand.", effectType = "multi_rank_range_flat_bonus_per_card", value = { ranks_low = 2, ranks_high = 6, bonusPerCard = 5 }, rarity = "Common", conceptualCost = 5})
    table.insert(availableShopJokers, {name = "High Card Honcho", description = "+5 score for each card rank 10-A in your played hand.", effectType = "multi_rank_range_flat_bonus_per_card", value = { ranks_low = 10, ranks_high = 14, bonusPerCard = 5 }, rarity = "Common", conceptualCost = 5})
    table.insert(availableShopJokers, {name = "Perfectly Balanced", description = "If played hand has 2 Red & 2 Black cards (4+ card hands), score x2.", effectType = "conditional_score_multiplier_specific_color_counts", value = { redCount = 2, blackCount = 2, minCards = 4, multiplier = 2 }, rarity = "Rare", conceptualCost = 9})
    table.insert(availableShopJokers, {name = "Solo Performance", description = "If only one card is played, it scores a x5 multiplier.", effectType = "conditional_multiplier_if_card_count_is", value = { cardCount = 1, multiplier = 5 }, rarity = "Uncommon", conceptualCost = 7})
    table.insert(availableShopJokers, {name = "Empty Hand Echo", description = "If this play empties your hand, gain +50 flat bonus.", effectType = "conditional_flat_bonus_if_hand_emptied", value = { bonus = 50 }, rarity = "Uncommon", conceptualCost = 7})
    table.insert(availableShopJokers, {name = "The Minimalist", description = "If you have 0 discards remaining, all scores this round x1.5.", effectType = "conditional_multiplier_discards_remaining_is_zero", value = { multiplier = 1.5 }, rarity = "Rare", conceptualCost = 11})
    table.insert(availableShopJokers, {name = "The Collector", description = "Gain +1 flat score for every card in your discard pile.", effectType = "flat_bonus_per_card_in_discard_pile", value = { bonusPerCard = 1 }, rarity = "Rare", conceptualCost = 10})
    table.insert(availableShopJokers, {name = "Early Bird Bonus", description = "If played in Round 1 or 2, hand gets +75 flat bonus.", effectType = "conditional_flat_bonus_early_rounds", value = { maxRound = 2, bonus = 75 }, rarity = "Uncommon", conceptualCost = 8}) 
    table.insert(availableShopJokers, {name = "Late Game Larry", description = "If played in Round 5 or later, hand gets x2 multiplier.", effectType = "conditional_multiplier_late_rounds", value = { minRound = 5, multiplier = 2 }, rarity = "Rare", conceptualCost = 12})
    table.insert(availableShopJokers, {name = "Joker Synergy", description = "If you have 3 or more Jokers, all scores +25 flat bonus.", effectType = "conditional_flat_bonus_joker_count_threshold", value = { threshold = 3, bonus = 25 }, rarity = "Uncommon", conceptualCost = 6})
    -- Set E Jokers
    table.insert(availableShopJokers, {name = "The Gambler", description = "50% chance to x3 score, 50% chance score becomes 1. (5 uses)", effectType = "final_score_gambler", value = { multiplier = 3, failScore = 1 }, uses_total = 5, rarity = "Rare", conceptualCost = 10})
    table.insert(availableShopJokers, {name = "Safety Net", description = "First time score is <= 0, it becomes 50. Consumed.", effectType = "conditional_score_minimum_and_destroy", value = { minimumScore = 50 }, uses_total = 1, rarity = "Uncommon", conceptualCost = 8})
    table.insert(availableShopJokers, {name = "Lucky Seven Again", description = "Played hands with a '7' get +40 flat score bonus.", effectType = "conditional_flat_bonus_on_rank_present", value = { rank = "7", bonus = 40 }, rarity = "Uncommon", conceptualCost = 6})
    table.insert(availableShopJokers, {name = "Heartfelt Hand", description = "Flushes made of only Hearts score an additional x2.5 multiplier.", effectType = "specific_suit_flush_multiplier", value = { suit = "Hearts", multiplier = 2.5 }, rarity = "Rare", conceptualCost = 9})
    table.insert(availableShopJokers, {name = "Seeing Double", description = "If you have exactly two Jokers, score x1.5.", effectType = "conditional_multiplier_joker_count_is_exactly", value = { count = 2, multiplier = 1.5 }, rarity = "Uncommon", conceptualCost = 7})
    table.insert(availableShopJokers, {name = "Five Card Bonus", description = "Playing exactly 5 cards gives +50 score.", effectType = "conditional_flat_bonus_if_card_count_is", value = { cardCount = 5, bonus = 50 }, rarity = "Common", conceptualCost = 5})
    table.insert(availableShopJokers, {name = "Thrifty Spender", description = "If you bought no items in the shop last round, gain +50 score.", effectType = "bonus_if_no_shop_purchase_previous_round", value = { bonus = 50 }, rarity = "Uncommon", conceptualCost = 7})
    table.insert(availableShopJokers, {name = "Ante Annihilator", description = "Reduces current Ante by 25% this round. Consumed.", effectType = "ante_reducer_one_time_and_destroy", value = { reductionPercent = 0.25 }, uses_total = 1, rarity = "Legendary", conceptualCost = 15})
    table.insert(availableShopJokers, {name = "Big Hand Theory", description = "If your max hand size is 8 or more, +50 score.", effectType = "conditional_flat_bonus_if_max_hand_size_is", value = { minSize = 8, bonus = 50 }, rarity = "Uncommon", conceptualCost = 6})
    table.insert(availableShopJokers, {name = "Ephemeral Power", description = "Score x5. This Joker is destroyed after 1 use.", effectType = "multiplier_and_destroy_after_uses", value = { multiplier = 5 }, uses_total = 1, rarity = "Rare", conceptualCost = 10})
    table.insert(availableShopJokers, {name = "High Card King", description = "If your best hand is High Card, score +50.", effectType = "hand_type_flat_bonus", value = { handType = "HighCard", bonus = 50 }, rarity = "Common", conceptualCost = 5})


    gameDeck = Deck:new()
    gameDeck:shuffle()
    playerHand = Hand:new()
    
    refillHand() 
    generateShopItems() 
    setUIMessage("Select cards (1-8), then 'P' to Play or 'D' to Discard.")
end

function refillHand()
    local cardsNeeded = initialHandSize - playerHand:getCount()
    if cardsNeeded > 0 then
        print("Refilling hand with " .. cardsNeeded .. " cards.")
        local dealtCardThisRefill = false
        for i = 1, cardsNeeded do
            if #gameDeck.cards == 0 then
                print("Deck empty. Reshuffling.")
                gameDeck:reshuffle()
                setUIMessage("Deck reshuffled!", 2)
                playSound(sfxCardDeal) 
            end
            local newCard = gameDeck:deal()
            if newCard then
                playerHand:addCard(newCard)
                dealtCardThisRefill = true
            else
                print("Error: Deck still empty after attempting reshuffle or newCard is nil.")
                setUIMessage("Error: Deck problem after reshuffle.", 3)
                playSound(sfxError)
                break 
            end
        end
        if dealtCardThisRefill then playSound(sfxCardDeal) end 
    end
end

function love.update(dt)
    updateUIMessage(dt) 
end

function drawGameplayUI()
    local currentScreenWidth = love.graphics.getWidth()
    local currentScreenHeight = love.graphics.getHeight()
    love.graphics.setFont(love.graphics.newFont(18)) 
    local handCards = playerHand:getCards()
    local cardSpacing = cardWidth + 20 
    local handDisplayWidth = (#handCards * cardSpacing) - 20 
    if #handCards == 0 then handDisplayWidth = 0 end
    local handStartX = (currentScreenWidth - handDisplayWidth) / 2 
    local handYPosition = currentScreenHeight - cardHeight - 70 
    for i, card in ipairs(handCards) do
        local currentX = handStartX + (i - 1) * cardSpacing
        local currentY = handYPosition
        local isSelected = false
        if currentActionType == nil then 
            for _, selectedIdx in ipairs(handSelectedCardIndices) do
                if selectedIdx == i then
                    isSelected = true
                    break
                end
            end
        end
        if isSelected then
            currentY = handYPosition - 20 
            love.graphics.setColor(0, 0.7, 0) 
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", currentX - 3, currentY - 3, cardWidth + 6, cardHeight + 6)
            love.graphics.setLineWidth(1)
            love.graphics.setColor(1,1,1) 
        end
        drawCardPlaceholder(currentX, currentY, card.suit, card.rank)
    end
    local stagingAreaY = handYPosition - cardHeight - 30 
    local stagingAreaHeight = cardHeight + 20
    love.graphics.setColor(0.25, 0.25, 0.3, 0.7) 
    love.graphics.rectangle("fill", 50, stagingAreaY - 10, currentScreenWidth - 100, stagingAreaHeight)
    love.graphics.setColor(1,1,1)
    love.graphics.setFont(love.graphics.newFont(18))
    if currentActionType then
        love.graphics.printf("Staging for: " .. string.upper(currentActionType), 60, stagingAreaY - 30, currentScreenWidth - 120, "left")
    else
        love.graphics.printf("Staging Area (Empty)", 60, stagingAreaY - 30, currentScreenWidth - 120, "left")
    end
    if #stagedCards > 0 then
        local stagedCardSpacing = cardWidth + 15
        local stagedTotalWidth = (#stagedCards * stagedCardSpacing) - 15
        local stagedStartX = (currentScreenWidth - stagedTotalWidth) / 2
        for i, card in ipairs(stagedCards) do
            drawCardPlaceholder(stagedStartX + (i-1) * stagedCardSpacing, stagingAreaY, card.suit, card.rank)
        end
    end
    love.graphics.setFont(love.graphics.newFont(22))
    local topBarY = 15
    love.graphics.setColor(0.2, 0.2, 0.2, 0.85) 
    love.graphics.rectangle("fill", 0, 0, currentScreenWidth, 50)
    love.graphics.setColor(1,1,1) 
    love.graphics.printf("Round: " .. currentRound, 20, topBarY, currentScreenWidth - 40, "left")
    love.graphics.printf("Target: " .. targetScore, currentScreenWidth / 2 - 100, topBarY, 200, "center")
    love.graphics.printf("Score: " .. playerScore, currentScreenWidth / 2 + 20, topBarY, 150, "center")
    love.graphics.printf("$" .. playerMoney, currentScreenWidth - 100, topBarY, 80, "right")


    local jokerAreaX = 20
    local jokerAreaY = topBarY + 40 
    love.graphics.setFont(love.graphics.newFont(16))
    love.graphics.print("Jokers:", jokerAreaX, jokerAreaY)
    if #playerJokers == 0 then
        love.graphics.print("None", jokerAreaX, jokerAreaY + 20)
    else
        for i, joker in ipairs(playerJokers) do
            love.graphics.print(joker.name .. ": " .. joker.description, jokerAreaX, jokerAreaY + (i * 20))
        end
    end
    local bottomInfoY = currentScreenHeight - 45 
    love.graphics.setFont(love.graphics.newFont(20))
    love.graphics.printf("Plays: " .. playerPlaysRemaining, currentScreenWidth / 2 - 180, bottomInfoY, 100, "left")
    love.graphics.printf("Discards: " .. playerDiscardsRemaining, currentScreenWidth / 2 + 80, bottomInfoY, 100, "right")
    love.graphics.printf("Discard Pile: " .. #discardPile, currentScreenWidth / 2, bottomInfoY + 20, 0, "center") 

    local buttonWidth = 160
    local buttonHeight = 40
    local buttonY = currentScreenHeight - 55 
    if currentActionType == nil then
        love.graphics.setColor(0.3, 0.7, 0.3, 0.9) 
        love.graphics.rectangle("fill", currentScreenWidth / 2 - buttonWidth - 10, buttonY, buttonWidth, buttonHeight)
        love.graphics.setColor(1,1,1)
        love.graphics.printf("[P] Stage Play", currentScreenWidth / 2 - buttonWidth - 10, buttonY + 10, buttonWidth, "center")
        love.graphics.setColor(0.7, 0.3, 0.3, 0.9) 
        love.graphics.rectangle("fill", currentScreenWidth / 2 + 10, buttonY, buttonWidth, buttonHeight)
        love.graphics.setColor(1,1,1)
        love.graphics.printf("[D] Stage Discard", currentScreenWidth / 2 + 10, buttonY + 10, buttonWidth, "center")
    else 
        love.graphics.setColor(0.3, 0.7, 0.3, 0.9) 
        love.graphics.rectangle("fill", currentScreenWidth / 2 - buttonWidth - 10, buttonY, buttonWidth, buttonHeight)
        love.graphics.setColor(1,1,1)
        love.graphics.printf("[Enter] Confirm", currentScreenWidth / 2 - buttonWidth - 10, buttonY + 10, buttonWidth, "center")
        love.graphics.setColor(0.7, 0.3, 0.3, 0.9) 
        love.graphics.rectangle("fill", currentScreenWidth / 2 + 10, buttonY, buttonWidth, buttonHeight)
        love.graphics.setColor(1,1,1)
        love.graphics.printf("[Esc] Cancel", currentScreenWidth / 2 + 10, buttonY + 10, buttonWidth, "center")
    end
    love.graphics.setFont(love.graphics.newFont(20))
    local instructionTextY = 60 
    if currentUIMessage ~= "" then
        love.graphics.setColor(1,1,0.3) 
        love.graphics.printf(currentUIMessage, 0, instructionTextY, currentScreenWidth, "center")
    else
        love.graphics.setColor(0.85, 0.85, 0.85) 
        local instructionText = ""
        if currentActionType == nil then
            instructionText = "Select cards (1-" .. playerHand:getCount() .. "). Then [P] or [D]."
            if playerHand:getCount() == 0 then instructionText = "No cards in hand." end
            if #handSelectedCardIndices > 0 then
                instructionText = instructionText .. " (" .. #handSelectedCardIndices .. " selected)"
            end
        elseif currentActionType == "play" then
            instructionText = "Staged for PLAY. [Enter] to confirm, [Esc] to cancel."
        elseif currentActionType == "discard" then
            instructionText = "Staged for DISCARD. [Enter] to confirm, [Esc] to cancel."
        end
        love.graphics.printf(instructionText, 0, instructionTextY, currentScreenWidth, "center")
    end
    love.graphics.setColor(1,1,1) 
end

function drawShopUI()
    local currentScreenWidth = love.graphics.getWidth()
    local currentScreenHeight = love.graphics.getHeight()
    love.graphics.setFont(love.graphics.newFont(30))
    love.graphics.printf("Shop - Round " .. currentRound .. " Cleared!", 0, 30, currentScreenWidth, "center")
    love.graphics.setFont(love.graphics.newFont(22))
    love.graphics.printf("Your Money: $" .. playerMoney, 0, 70, currentScreenWidth, "center")


    love.graphics.setFont(love.graphics.newFont(20))
    if #shopItems == 0 then
        love.graphics.printf("Shop is currently empty or sold out!", 0, 150, currentScreenWidth, "center")
    else
        for i, item in ipairs(shopItems) do
            local itemText = i .. ". " .. item.name .. " (" .. item.rarity .. ", $" .. item.conceptualCost .. ") - " .. item.description
            if playerOwnsJoker(item.id) then 
                 itemText = itemText .. " (Owned)"
                 love.graphics.setColor(0.6, 0.6, 0.6) 
            elseif i == selectedShopItemIndex then
                love.graphics.setColor(1,1,0) 
            else
                love.graphics.setColor(1,1,1)
            end
            love.graphics.printf(itemText, 50, 120 + (i * 40), currentScreenWidth - 100, "left")
            love.graphics.setColor(1,1,1) 
        end
    end
    love.graphics.setColor(1,1,1)
    love.graphics.setFont(love.graphics.newFont(18))
    local shopInstructionY = currentScreenHeight - 100
    
    if shopMode == "buy" then
        love.graphics.printf("Select item (1-" .. #shopItems .. "), [Enter] to Buy. [S] for Sell Mode.", 0, shopInstructionY, currentScreenWidth, "center")
    else -- shopMode == "sell"
        love.graphics.printf("SELL MODE: Select owned Joker (1-" .. #playerJokers .. "), [Enter] to Sell. [S] for Buy Mode.", 0, shopInstructionY, currentScreenWidth, "center")
        -- Placeholder for owned joker display (to be implemented in next subtask)
        if #playerJokers == 0 then
            love.graphics.printf("You have no Jokers to sell.", 0, 150, currentScreenWidth, "center")
        else
            -- This area will be replaced by actual owned joker list for selling
            love.graphics.printf("Owned Jokers will be listed here for selling.", 0, 150, currentScreenWidth, "center")
        end
    end

    love.graphics.printf("Press [R] to Re-roll Shop ($" .. currentRerollCost .. ")", 0, shopInstructionY + 20, currentScreenWidth, "center")
    love.graphics.printf("[C] to Continue to Next Round", 0, shopInstructionY + 40, currentScreenWidth, "center")
    
    if currentUIMessage ~= "" then
        love.graphics.setFont(love.graphics.newFont(20))
        love.graphics.setColor(1,1,0.3)
        love.graphics.printf(currentUIMessage, 0, currentScreenHeight - 130, currentScreenWidth, "center")
        love.graphics.setColor(1,1,1)
    end
end

function love.draw()
    love.graphics.setBackgroundColor(0.1, 0.1, 0.1) 
    local currentScreenWidth = love.graphics.getWidth()
    local currentScreenHeight = love.graphics.getHeight()
    if gameState == "menu" then
        love.graphics.setFont(love.graphics.newFont(40))
        love.graphics.printf("Balatro-Like Card Game", 0, currentScreenHeight / 3 - 20, currentScreenWidth, "center")
        love.graphics.setFont(love.graphics.newFont(28))
        love.graphics.printf("Press '2' to Start Game", 0, currentScreenHeight / 2 + 30, currentScreenWidth, "center")
        love.graphics.printf("Press '`' (Backtick) to Quit", 0, currentScreenHeight / 2 + 70, currentScreenWidth, "center")
        if currentUIMessage ~= "" then 
            love.graphics.setFont(love.graphics.newFont(20))
            love.graphics.setColor(1,1,0.3)
            love.graphics.printf(currentUIMessage, 0, currentScreenHeight - 50, currentScreenWidth, "center")
            love.graphics.setColor(1,1,1)
        end
    elseif gameState == "gameplay" then
        drawGameplayUI()
    elseif gameState == "shop" then
        drawShopUI()
    elseif gameState == "gameover" then
        love.graphics.setFont(love.graphics.newFont(50))
        love.graphics.printf("Game Over", 0, currentScreenHeight / 3 - 20, currentScreenWidth, "center")
        love.graphics.setFont(love.graphics.newFont(30))
        love.graphics.printf("You reached Round: " .. currentRound, 0, currentScreenHeight / 2 + 20, currentScreenWidth, "center")
        love.graphics.setFont(love.graphics.newFont(25))
        love.graphics.printf("Press 'R' to Restart", 0, currentScreenHeight / 2 + 70, currentScreenWidth, "center")
    end
end

function love.keypressed(key)
    if gameState == "gameplay" then
        if currentActionType == nil then
            local numKey = tonumber(key)
            if numKey and numKey >= 1 and numKey <= playerHand:getCount() then
                local alreadySelectedIdx = nil
                for i, idxValue in ipairs(handSelectedCardIndices) do
                    if idxValue == numKey then alreadySelectedIdx = i break end
                end
                if alreadySelectedIdx then
                    table.remove(handSelectedCardIndices, alreadySelectedIdx)
                    setUIMessage("Deselected card " .. numKey .. " from hand.")
                else
                    table.insert(handSelectedCardIndices, numKey)
                    setUIMessage("Selected card " .. numKey .. " from hand.")
                end
                playSound(sfxCardSelect)
                table.sort(handSelectedCardIndices) 
            end
        end

        if key == "p" and currentActionType == nil then
            if #handSelectedCardIndices > 0 then
                currentActionType = "play"
                local cardsToMove = {}
                for i = #handSelectedCardIndices, 1, -1 do 
                    local handIdx = handSelectedCardIndices[i]
                    local card = playerHand:removeCardByIndex(handIdx) 
                    if card then table.insert(cardsToMove, 1, card) end 
                end
                stagedCards = cardsToMove
                handSelectedCardIndices = {}
                setUIMessage("Staging for PLAY. [Enter] to confirm, [Esc] to cancel.", 5)
                playSound(sfxCardSelect) 
            else
                setUIMessage("Select cards from hand first to stage for play!")
                playSound(sfxError)
            end
        end

        if key == "d" and currentActionType == nil then
            if #handSelectedCardIndices > 0 then
                currentActionType = "discard"
                local cardsToMove = {}
                for i = #handSelectedCardIndices, 1, -1 do 
                    local handIdx = handSelectedCardIndices[i]
                    local card = playerHand:removeCardByIndex(handIdx) 
                    if card then table.insert(cardsToMove, 1, card) end
                end
                stagedCards = cardsToMove
                handSelectedCardIndices = {}
                setUIMessage("Staging for DISCARD. [Enter] to confirm, [Esc] to cancel.", 5)
                playSound(sfxCardSelect) 
            else
                setUIMessage("Select cards from hand first to stage for discard!")
                playSound(sfxError)
            end
        end

        if (key == "return" or key == "kpenter" or key == "space") and currentActionType ~= nil then
            if #stagedCards > 0 then
                playSound(sfxActionConfirm)
                if currentActionType == "play" then
                    if playerPlaysRemaining > 0 then
                        
                        local currentPlayContext = {
                            roundNumber = currentRound,
                            discardsRemaining = playerDiscardsRemaining,
                            playerHandActualSize = playerHand:getCount(), 
                            playerJokerCount = #playerJokers,
                            isFirstPlay = (playerPlaysRemaining == initialPlayerPlaysAllowed), 
                            isLastPlay = (playerPlaysRemaining == 1), 
                            discardPileSize = #discardPile,
                            maxHandSize = playerStats.maxHandSize,
                            boughtInShopLastRound = previousRoundShopStatus 
                        }
                        
                        playerPlaysRemaining = playerPlaysRemaining - 1 
                        
                        local scoreForThisHand, handType = HandEvaluator.calculateScore(stagedCards, playerJokers, currentPlayContext)
                        playerScore = playerScore + scoreForThisHand
                        print("Confirmed PLAY: " .. handType .. ", Score: " .. scoreForThisHand .. ". Round Score: " .. playerScore .. ". Plays left: " .. playerPlaysRemaining)
                        playSound(sfxCardPlay)
                        if playerScore >= targetScore then
                            setUIMessage("Round " .. currentRound .. " Cleared! Target: " .. targetScore .. ", Score: " .. playerScore .. ". Entering Shop.", 4)
                            gameState = "shop"
                            shopMode = "buy" -- Ensure shop starts in buy mode
                            selectedOwnedJokerIndex = nil
                            generateShopItems() 
                            playSound(sfxRoundClear)
                        elseif playerPlaysRemaining == 0 then
                            setUIMessage("Game Over - Target: " .. targetScore .. ", Final Score: " .. playerScore, 5)
                            gameState = "gameover"
                            playSound(sfxError) 
                        else
                            setUIMessage("Played: " .. handType .. " (" .. scoreForThisHand .. "). Plays left: " .. playerPlaysRemaining, 3)
                        end
                    else
                        setUIMessage("No plays remaining this round! Action cancelled.", 3)
                        playSound(sfxError)
                        for _, card in ipairs(stagedCards) do playerHand:addCard(card) end
                    end
                elseif currentActionType == "discard" then
                    if playerDiscardsRemaining > 0 then
                        playerDiscardsRemaining = playerDiscardsRemaining - 1
                        print("Confirmed DISCARD: " .. #stagedCards .. " cards. Discards left: " .. playerDiscardsRemaining)
                        for _, card in ipairs(stagedCards) do 
                            table.insert(discardPile, card)
                        end
                        setUIMessage("Discarded " .. #stagedCards .. " cards. " .. playerDiscardsRemaining .. " discards left.", 3)
                        playSound(sfxDiscard)
                        refillHand() 
                    else
                        setUIMessage("No discards remaining this round! Action cancelled.", 3)
                        playSound(sfxError)
                        for _, card in ipairs(stagedCards) do playerHand:addCard(card) end
                    end
                end
                stagedCards = {}
                currentActionType = nil
                if gameState == "gameplay" then refillHand() end 
            else
                setUIMessage("No cards staged for action. Action cancelled.", 3)
                playSound(sfxError)
                currentActionType = nil 
            end
        end

        if key == "escape" and currentActionType ~= nil then
            playSound(sfxActionCancel)
            if #stagedCards > 0 then
                for _, card in ipairs(stagedCards) do playerHand:addCard(card) end
                 playSound(sfxCardDeal) 
            end
            stagedCards = {}
            currentActionType = nil
            handSelectedCardIndices = {} 
            setUIMessage("Action cancelled. Cards returned to hand.", 3)
        end

    elseif gameState == "shop" then
        if key == "s" then -- Toggle Sell Mode
            if shopMode == "buy" then
                shopMode = "sell"
                selectedShopItemIndex = nil -- Clear buy selection
                selectedOwnedJokerIndex = nil -- Clear any previous sell selection
                setUIMessage("Sell Mode: Select Joker (1-" .. #playerJokers .. ") to sell. [S] to Buy.", 4)
            else -- shopMode == "sell"
                shopMode = "buy"
                selectedOwnedJokerIndex = nil -- Clear sell selection
                selectedShopItemIndex = (#shopItems > 0) and 1 or nil -- Reset buy selection
                setUIMessage("Buy Mode: Select item (1-" .. #shopItems .. "). [S] to Sell.", 4)
            end
            playSound(sfxCardSelect) -- Generic toggle sound
        end

        if shopMode == "buy" then
            local numKey = tonumber(key)
            if numKey and numKey >= 1 and numKey <= #shopItems then
                selectedShopItemIndex = numKey
                setUIMessage("Selected: " .. shopItems[selectedShopItemIndex].name .. " ($" .. shopItems[selectedShopItemIndex].conceptualCost .. ")")
                playSound(sfxCardSelect) 
            end

            if (key == "return" or key == "kpenter") and selectedShopItemIndex and #shopItems > 0 then
                local itemToBuy = shopItems[selectedShopItemIndex]
                if itemToBuy then
                    local cost = itemToBuy.conceptualCost or 0 
                    if playerOwnsJoker(itemToBuy.id) then
                        setUIMessage("You already have this Joker: " .. itemToBuy.name, 2)
                        playSound(sfxError)
                    elseif playerMoney >= cost then
                        playerMoney = playerMoney - cost
                        playerStats.boughtInShopLastRound = true 
                        local purchasedJoker = table.remove(shopItems, selectedShopItemIndex)
                        table.insert(playerJokers, purchasedJoker)
                        setUIMessage("Purchased: " .. purchasedJoker.name .. " for $" .. cost .. "!", 2)
                        print("Purchased Joker: " .. purchasedJoker.name .. " for $" .. cost .. ". Money left: $" .. playerMoney)
                        playSound(sfxShopPurchase)
                        selectedShopItemIndex = math.max(1, selectedShopItemIndex -1) 
                        if #shopItems == 0 then selectedShopItemIndex = nil end
                    else
                        setUIMessage("Not enough money! Need $" .. cost .. ", have $" .. playerMoney .. ".", 3)
                        playSound(sfxError)
                    end
                else
                     setUIMessage("Item not available.", 2)
                     playSound(sfxError)
                end
            elseif (key == "return" or key == "kpenter") and (#shopItems == 0 or not selectedShopItemIndex) then
                 setUIMessage("No item selected or shop empty.", 2)
                 playSound(sfxError)
            end
        elseif shopMode == "sell" then
            -- Sell mode selection/confirmation logic will be added in the next subtask
            -- For now, just allow toggling back
        end


        if key == "r" then -- Re-roll
            if playerMoney >= currentRerollCost then
                playerMoney = playerMoney - currentRerollCost
                playerStats.boughtInShopLastRound = true 
                print("Player re-rolled shop for $" .. currentRerollCost .. ". Money left: $" .. playerMoney)
                setUIMessage("Shop re-rolled for $" .. currentRerollCost .. "!", 2)
                
                generateShopItems() -- This also resets currentRerollCost to baseRerollCost and shopMode to "buy"
                
                playSound(sfxShopReroll)
            else
                setUIMessage("Not enough money to re-roll! Need $" .. currentRerollCost .. ".", 3)
                playSound(sfxError)
            end
        end

        if key == "c" then
            playSound(sfxActionConfirm) 
            
            previousRoundShopStatus = playerStats.boughtInShopLastRound 
            playerStats.boughtInShopLastRound = false 

            local roundClearBonus = 5 
            local moneyEarnedThisRound = roundClearBonus
            
            local scoreBonus = math.floor(playerScore / 10) 
            if scoreBonus > 0 then
                moneyEarnedThisRound = moneyEarnedThisRound + scoreBonus
            end
            playerMoney = playerMoney + moneyEarnedThisRound
            print("Player earned $" .. moneyEarnedThisRound .. " this round. Total money: " .. playerMoney)
            
            currentRound = currentRound + 1
            targetScore = targetScore + 50 * currentRound 
            
            cleanupAndApplyJokerRoundEndEffects() 

            playerScore = 0 
            playerPlaysRemaining = initialPlayerPlaysAllowed 
            playerDiscardsRemaining = 3 
            refillHand()
            gameState = "gameplay"
            setUIMessage("Earned $" .. moneyEarnedThisRound .. "! Starting Round " .. currentRound .. ". Target: " .. targetScore, 4)
        end
    end

    -- Global game state controls
    if key == "f1" or (gameState == "menu" and key == "1") then 
        gameState = "menu"
        currentActionType = nil; stagedCards = {}; handSelectedCardIndices = {} 
        setUIMessage("Returned to Menu.")
    end
    if key == "f2" or (gameState == "menu" and key == "2") then
        if gameState ~= "gameplay" or currentActionType ~= nil then 
            print("Starting/Resetting game from menu or F2 press...")
            playerScore = 0; currentRound = 1; targetScore = 100; playerMoney = 10
            playerDiscardsRemaining = 3; playerPlaysRemaining = initialPlayerPlaysAllowed
            initialHandSize = 8; baseRerollCost = 1; currentRerollCost = baseRerollCost; shopMode = "buy"
            gameDeck = Deck:new(); gameDeck:shuffle()
            playerHand = Hand:new()
            stagedCards = {}; currentActionType = nil; handSelectedCardIndices = {}
            discardPile = {} 
            playerJokers = {}
            playerStats = { maxHandSize = initialHandSize, boughtInShopLastRound = false }
            previousRoundShopStatus = false
            cleanupAndApplyJokerRoundEndEffects() 
            refillHand()
            setUIMessage("New game started! Select cards, then P or D.")
        end
        gameState = "gameplay"
    end
    if key == "f4" then 
        if gameState ~= "shop" then
            setUIMessage("DEBUG: Entering Shop", 2)
            shopMode = "buy" -- Ensure shop starts in buy mode on debug entry
            selectedOwnedJokerIndex = nil
            generateShopItems()
            gameState = "shop"
        else
            setUIMessage("DEBUG: Exiting Shop to Gameplay", 2)
            gameState = "gameplay" 
        end
    end

    if key == "`" then love.event.quit() end

    if gameState == "gameover" and key == "r" then
        print("Resetting game from Game Over...")
        playerScore = 0; currentRound = 1; targetScore = 100; playerMoney = 10
        playerDiscardsRemaining = 3; playerPlaysRemaining = initialPlayerPlaysAllowed
        initialHandSize = 8; baseRerollCost = 1; currentRerollCost = baseRerollCost; shopMode = "buy"
        gameDeck = Deck:new(); gameDeck:shuffle()
        playerHand = Hand:new()
        stagedCards = {}; currentActionType = nil; handSelectedCardIndices = {}
        playerJokers = {} 
        discardPile = {} 
        playerStats = { maxHandSize = initialHandSize, boughtInShopLastRound = false }
        previousRoundShopStatus = false
        cleanupAndApplyJokerRoundEndEffects() 
        refillHand()
        setUIMessage("New game started! Select cards, then P or D.")
        gameState = "gameplay" 
        playSound(sfxRoundClear) 
    end
end

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]
