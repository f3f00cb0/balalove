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
    shopItems = {} 
    selectedShopItemIndex = 1
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
            table.insert(shopItems, Joker:new(chosenJokerData.name, chosenJokerData.description, chosenJokerData.effectType, chosenJokerData.value))
        end
        if attempts > maxAttemptsPerSlot * numItemsToOffer then 
             print("Warning: Max attempts reached in generateShopItems. Shop might not be full.")
             break
        end
    end

    if #shopItems > 0 then
        setUIMessage("Welcome to the Shop! Select (1-" .. #shopItems .. "), Enter to buy. 'C' to continue.", 5)
    else
        setUIMessage("Shop is empty (no new Jokers to offer or all owned). Press 'C' to continue.", 5)
    end
end


function love.load()
    -- Load external modules
    require("card_graphics") 
    Card = require("card")
    Deck = require("deck")
    Hand = require("hand")
    HandEvaluator = require("hand_evaluator")
    Joker = require("joker") 

    -- Load Sound Effects
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

    -- Game loop variables
    playerScore = 0 
    currentRound = 1
    targetScore = 100 
    initialPlayerPlaysAllowed = 4 -- Define initial plays for a round
    playerDiscardsRemaining = 3
    playerPlaysRemaining = initialPlayerPlaysAllowed -- Use the new variable
    initialHandSize = 8 
    
    handSelectedCardIndices = {} 
    stagedCards = {}             
    currentActionType = nil      
    discardPile = {} -- Initialize discard pile

    playerJokers = {} 
    
    -- Populate availableShopJokers (master list for the shop)
    table.insert(availableShopJokers, {name="Joker of Spades", description="+15 flat bonus", effectType="flat_score_bonus", value=15})
    table.insert(availableShopJokers, {name="Joker of Hearts", description="Score x1.2", effectType="score_multiplier", value=1.2})
    table.insert(availableShopJokers, {name="Joker of Clubs", description="+25 flat bonus", effectType="flat_score_bonus", value=25})
    table.insert(availableShopJokers, {name="Joker of Diamonds", description="Score x1.3", effectType="score_multiplier", value=1.3})
    table.insert(availableShopJokers, {name="Glass Joker", description="Score x2 (Fragile!)", effectType="score_multiplier", value=2.0})
    table.insert(availableShopJokers, {name="Stone Joker", description="+50 flat bonus", effectType="flat_score_bonus", value=50})
    table.insert(availableShopJokers, {name="Golden Joker", description="Score x1.5", effectType="score_multiplier", value=1.5})
    table.insert(availableShopJokers, {name="Lucky Joker", description="+7 flat bonus", effectType="flat_score_bonus", value=7})
    -- Set A Jokers
    table.insert(availableShopJokers, {name = "Straight Shooter", description = "Straights score an additional x2 multiplier.", effectType = "hand_type_score_multiplier", value = { handType = "Straight", multiplier = 2 }})
    table.insert(availableShopJokers, {name = "Flush Fever", description = "Flushes gain a +75 flat score bonus.", effectType = "hand_type_flat_bonus", value = { handType = "Flush", bonus = 75 }})
    table.insert(availableShopJokers, {name = "Ace High Club", description = "+15 score for each Ace in your played hand.", effectType = "rank_specific_flat_bonus_per_card", value = { rank = "A", bonusPerCard = 15 }})
    table.insert(availableShopJokers, {name = "Lucky Number Seven", description = "Any played hand containing at least one '7' gets a +35 flat score bonus.", effectType = "conditional_flat_bonus_on_rank_present", value = { rank = "7", bonus = 35 }})
    table.insert(availableShopJokers, {name = "Red Suit Riches", description = "Played hands containing only Red suit cards (Hearts, Diamonds) get an additional x1.5 multiplier.", effectType = "conditional_score_multiplier_all_suits_are_color", value = { color = "Red", multiplier = 1.5 }})
    -- Set B Jokers
    table.insert(availableShopJokers, {name = "Pair Parity", description = "Pairs: +20 if paired rank is even, +10 if odd.", effectType = "conditional_hand_type_bonus_rank_math", value = { handType = "Pair", evenBonus = 20, oddBonus = 10 }})
    table.insert(availableShopJokers, {name = "High Roller", description = "Played hands with 3+ Face Cards (J,Q,K) get +50 score.", effectType = "conditional_flat_bonus_card_property_count", value = { property = "isFaceCard", threshold = 3, bonus = 50 }})
    table.insert(availableShopJokers, {name = "Suit Sampler", description = "+10 score for each unique suit in the played hand.", effectType = "flat_bonus_per_unique_suit_in_played_hand", value = { bonusPerUniqueSuit = 10 }})
    table.insert(availableShopJokers, {name = "Consecutive Bonus", description = "If played hand's ranks are consecutive, gain +25 score.", effectType = "conditional_flat_bonus_consecutive_ranks", value = { bonus = 25 }})
    table.insert(availableShopJokers, {name = "Steady Scorer", description = "All played hands get a +10 flat score bonus.", effectType = "flat_score_bonus", value = 10})
    table.insert(availableShopJokers, {name = "Blackjack Bonus", description = "If sum of ranks in played hand is 21 (Ace=1/11, JQK=10), score x2.", effectType = "conditional_score_multiplier_blackjack_sum", value = { targetSum = 21, multiplier = 2 }})
    table.insert(availableShopJokers, {name = "Round Number Riches", description = "Gain flat score bonus = current round number x 3.", effectType = "flat_bonus_based_on_round_number", value = { multiplier = 3 }})
    -- Set C Jokers
    table.insert(availableShopJokers, {name = "Three's Company", description = "Three of a Kind scores an additional x2.5 multiplier.", effectType = "hand_type_score_multiplier", value = { handType = "ThreeOfAKind", multiplier = 2.5 }})
    table.insert(availableShopJokers, {name = "Full House Fortune", description = "Full Houses gain a +100 flat score bonus.", effectType = "hand_type_flat_bonus", value = { handType = "FullHouse", bonus = 100 }})
    table.insert(availableShopJokers, {name = "Royal Treatment", description = "+25 score for each King or Queen in your played hand.", effectType = "multi_rank_specific_flat_bonus_per_card", value = { ranks = {"K", "Q"}, bonusPerCard = 25 }})
    table.insert(availableShopJokers, {name = "Even Stevens", description = "If all cards in played hand have EVEN ranks, score x2.", effectType = "conditional_score_multiplier_all_cards_property", value = { property = "isEvenRank", multiplier = 2 }})
    table.insert(availableShopJokers, {name = "Odd Baller", description = "If all cards in played hand have ODD ranks, score x2.", effectType = "conditional_score_multiplier_all_cards_property", value = { property = "isOddRank", multiplier = 2 }})
    table.insert(availableShopJokers, {name = "Monochrome Hand (Red)", description = "Played hands with only Red suit cards get +50 score.", effectType = "conditional_flat_bonus_all_suits_are_color", value = { color = "Red", bonus = 50 }})
    table.insert(availableShopJokers, {name = "Monochrome Hand (Black)", description = "Played hands with only Black suit cards get +50 score.", effectType = "conditional_flat_bonus_all_suits_are_color", value = { color = "Black", bonus = 50 }})
    table.insert(availableShopJokers, {name = "Discard Power", description = "Gain +5 score for each discard remaining on your last play.", effectType = "end_of_round_bonus_discards_remaining", value = { bonusPerDiscard = 5 }})
    table.insert(availableShopJokers, {name = "Hand Size Bonus", description = "Gain +10 score for each card in your hand when playing.", effectType = "flat_bonus_per_card_in_current_hand_on_play", value = { bonusPerCard = 10 }})
    table.insert(availableShopJokers, {name = "Joker Hoarder", description = "Gain +20 score for each OTHER Joker you possess.", effectType = "flat_bonus_per_other_joker_owned", value = { bonusPerJoker = 20 }})
    table.insert(availableShopJokers, {name = "First Play Focus", description = "Your first hand played each round gets a x1.5 multiplier.", effectType = "conditional_multiplier_first_play_of_round", value = { multiplier = 1.5 }})
    table.insert(availableShopJokers, {name = "Last Chance Saloon", description = "If this is your last play of the round, gain +75 flat bonus.", effectType = "conditional_flat_bonus_last_play_of_round", value = { bonus = 75 }})

    -- Set D Jokers
    table.insert(availableShopJokers, {name = "Fourberie", description = "Four of a Kind scores an additional x3 multiplier.", effectType = "hand_type_score_multiplier", value = { handType = "FourOfAKind", multiplier = 3 }})
    table.insert(availableShopJokers, {name = "Straight Flush Supreme", description = "Straight Flushes gain a +250 flat score bonus.", effectType = "hand_type_flat_bonus", value = { handType = "StraightFlush", bonus = 250 }})
    table.insert(availableShopJokers, {name = "Low Card Loyalty", description = "+5 score for each card rank 2-6 in your played hand.", effectType = "multi_rank_range_flat_bonus_per_card", value = { ranks_low = 2, ranks_high = 6, bonusPerCard = 5 }})
    table.insert(availableShopJokers, {name = "High Card Honcho", description = "+5 score for each card rank 10-A in your played hand.", effectType = "multi_rank_range_flat_bonus_per_card", value = { ranks_low = 10, ranks_high = 14, bonusPerCard = 5 }})
    table.insert(availableShopJokers, {name = "Perfectly Balanced", description = "If played hand has 2 Red & 2 Black cards (4+ card hands), score x2.", effectType = "conditional_score_multiplier_specific_color_counts", value = { redCount = 2, blackCount = 2, minCards = 4, multiplier = 2 }})
    table.insert(availableShopJokers, {name = "Solo Performance", description = "If only one card is played, it scores a x5 multiplier.", effectType = "conditional_multiplier_if_card_count_is", value = { cardCount = 1, multiplier = 5 }})
    table.insert(availableShopJokers, {name = "Empty Hand Echo", description = "If this play empties your hand, gain +50 flat bonus.", effectType = "conditional_flat_bonus_if_hand_emptied", value = { bonus = 50 }})
    table.insert(availableShopJokers, {name = "The Minimalist", description = "If you have 0 discards remaining, all scores this round x1.5.", effectType = "conditional_multiplier_discards_remaining_is_zero", value = { multiplier = 1.5 }})
    table.insert(availableShopJokers, {name = "The Collector", description = "Gain +1 flat score for every card in your discard pile.", effectType = "flat_bonus_per_card_in_discard_pile", value = { bonusPerCard = 1 }})
    table.insert(availableShopJokers, {name = "Early Bird Bonus", description = "If played in Round 1 or 2, hand gets +100 flat bonus.", effectType = "conditional_flat_bonus_early_rounds", value = { maxRound = 2, bonus = 100 }})
    table.insert(availableShopJokers, {name = "Late Game Larry", description = "If played in Round 5 or later, hand gets x2 multiplier.", effectType = "conditional_multiplier_late_rounds", value = { minRound = 5, multiplier = 2 }})
    table.insert(availableShopJokers, {name = "Joker Synergy", description = "If you have 3 or more Jokers, all scores +25 flat bonus.", effectType = "conditional_flat_bonus_joker_count_threshold", value = { threshold = 3, bonus = 25 }})


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
    love.graphics.printf("Target: " .. targetScore, 0, topBarY, currentScreenWidth, "center")
    love.graphics.printf("Score: " .. playerScore, 20, topBarY, currentScreenWidth - 40, "right")
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
    love.graphics.printf("Shop - Round " .. currentRound .. " Cleared!", 0, 50, currentScreenWidth, "center")
    love.graphics.setFont(love.graphics.newFont(20))
    if #shopItems == 0 then
        love.graphics.printf("Shop is currently empty or sold out!", 0, 150, currentScreenWidth, "center")
    else
        for i, item in ipairs(shopItems) do
            local itemText = i .. ". " .. item.name .. " - " .. item.description
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
    love.graphics.printf("Use number keys to select, [Enter] to Buy.", 0, currentScreenHeight - 100, currentScreenWidth, "center")
    love.graphics.printf("[C] to Continue to Next Round", 0, currentScreenHeight - 70, currentScreenWidth, "center")
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
                            discardPileSize = #discardPile
                        }
                        
                        playerPlaysRemaining = playerPlaysRemaining - 1 
                        
                        local scoreForThisHand, handType = HandEvaluator.calculateScore(stagedCards, playerJokers, currentPlayContext)
                        playerScore = playerScore + scoreForThisHand
                        print("Confirmed PLAY: " .. handType .. ", Score: " .. scoreForThisHand .. ". Round Score: " .. playerScore .. ". Plays left: " .. playerPlaysRemaining)
                        playSound(sfxCardPlay)
                        if playerScore >= targetScore then
                            setUIMessage("Round " .. currentRound .. " Cleared! Target: " .. targetScore .. ", Score: " .. playerScore .. ". Entering Shop.", 4)
                            gameState = "shop"
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
        local numKey = tonumber(key)
        if numKey and numKey >= 1 and numKey <= #shopItems then
            selectedShopItemIndex = numKey
            setUIMessage("Selected: " .. shopItems[selectedShopItemIndex].name)
            playSound(sfxCardSelect) 
        end

        if (key == "return" or key == "kpenter") and #shopItems > 0 and selectedShopItemIndex then
            local itemToBuy = shopItems[selectedShopItemIndex]
            if itemToBuy then
                if playerOwnsJoker(itemToBuy.id) then
                    setUIMessage("You already have this Joker: " .. itemToBuy.name, 2)
                    playSound(sfxError)
                else
                    local purchasedJoker = table.remove(shopItems, selectedShopItemIndex)
                    table.insert(playerJokers, purchasedJoker)
                    setUIMessage("Purchased: " .. purchasedJoker.name .. "!", 2)
                    print("Purchased Joker: " .. purchasedJoker.name)
                    playSound(sfxShopPurchase)
                    selectedShopItemIndex = math.max(1, selectedShopItemIndex -1) 
                    if #shopItems == 0 then selectedShopItemIndex = nil end
                end
            else
                 setUIMessage("Item not available.", 2)
                 playSound(sfxError)
            end
        end

        if key == "c" then
            playSound(sfxActionConfirm) 
            currentRound = currentRound + 1
            targetScore = targetScore + 50 * currentRound 
            playerScore = 0 
            playerPlaysRemaining = initialPlayerPlaysAllowed 
            playerDiscardsRemaining = 3 
            refillHand()
            gameState = "gameplay"
            setUIMessage("Starting Round " .. currentRound .. ". Target: " .. targetScore, 3)
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
            playerScore = 0; currentRound = 1; targetScore = 100
            playerDiscardsRemaining = 3; playerPlaysRemaining = initialPlayerPlaysAllowed
            initialHandSize = 8
            gameDeck = Deck:new(); gameDeck:shuffle()
            playerHand = Hand:new()
            stagedCards = {}; currentActionType = nil; handSelectedCardIndices = {}
            discardPile = {} 
            refillHand()
            setUIMessage("New game started! Select cards, then P or D.")
        end
        gameState = "gameplay"
    end
    if key == "f4" then 
        if gameState ~= "shop" then
            setUIMessage("DEBUG: Entering Shop", 2)
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
        playerScore = 0; currentRound = 1; targetScore = 100
        playerDiscardsRemaining = 3; playerPlaysRemaining = initialPlayerPlaysAllowed
        initialHandSize = 8
        gameDeck = Deck:new(); gameDeck:shuffle()
        playerHand = Hand:new()
        stagedCards = {}; currentActionType = nil; handSelectedCardIndices = {}
        playerJokers = {} 
        discardPile = {} 
        refillHand()
        setUIMessage("New game started! Select cards, then P or D.")
        gameState = "gameplay" 
        playSound(sfxRoundClear) 
    end
end

[end of main.lua]
