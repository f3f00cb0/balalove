-- Global variables
screenWidth = 800
screenHeight = 600
gameState = "menu" -- Valid states: "menu", "gameplay", "shop", "gameover"


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
    if soundEffect and love.audio then -- Check if love.audio module is available too
        love.audio.stop(soundEffect) -- Stop previous instance if any, to prevent overlap/spam
        love.audio.play(soundEffect)
    end
end

-- Joker Activation Message variables
activatedJokerMessages = {}
jokerMessageTimer = 0
jokerMessageDuration = 2.0 -- seconds

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

function generateShopItems()
    shopItems = {} 
    selectedShopItemIndex = 1
    local numItemsToOffer = math.min(#availableShopJokers, math.random(2, 3))
    local tempAvailable = {}
    for _, jokerData in ipairs(availableShopJokers) do
        table.insert(tempAvailable, jokerData)
    end
    for i = 1, numItemsToOffer do
        if #tempAvailable == 0 then break end 
        local randomIndex = math.random(#tempAvailable)
        local jokerData = table.remove(tempAvailable, randomIndex)
        table.insert(shopItems, Joker:new(jokerData.name, jokerData.description, jokerData.effectType, jokerData.value))
    end
    setUIMessage("Welcome to the Shop! Select (1-" .. #shopItems .. "), Enter to buy. 'C' to continue.", 5)
end


function love.load()
    -- Load external modules
    require("card_graphics") 
    Card = require("card")
    Deck = require("deck")
    Hand = require("hand")
    HandEvaluator = require("hand_evaluator")
    Joker = require("joker") 

    -- Load Sound Effects (placeholders - will be nil if files don't exist)
    -- To use actual sounds, replace nil with: love.audio.newSource("assets/sounds/filename.ogg", "static")
    -- Example: sfxCardDeal = love.audio.newSource("assets/sounds/card_deal.ogg", "static")
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
    -- Adding confirm/cancel sounds as they are distinct actions in the new flow
    if love.filesystem.exists("assets/sounds/action_confirm.ogg") then
        sfxActionConfirm = love.audio.newSource("assets/sounds/action_confirm.ogg", "static")
    end
    if love.filesystem.exists("assets/sounds/action_cancel.ogg") then
        sfxActionCancel = love.audio.newSource("assets/sounds/action_cancel.ogg", "static")
    end


    -- Game loop variables
    playerScore = 0 -- Score for the current round
    playerCash = 0 -- Cash for the player

    currentRound = 1
    targetScore = 100 
    playerDiscardsRemaining = 3
    playerPlaysRemaining = 4
    initialHandSize = 8 -- Max hand size
    selectedShopItemIndex = nil
    
    selectedCardsIndices = {}
    playerJokers = {} -- Initialize player jokers list
    shopItems = {
        {name="Minor Mult Joker", description="Score x1.2", effectType="score_multiplier", value=1.2, price=50, id="joker_mult_minor"},
        -- {name="Bonus Points Joker", description="+10 to score", effectType="flat_bonus", value=10, price=30, id="joker_bonus_flat"}, -- This was never implemented in HandEvaluator
        {name="Card Sharp Joker", description="Score x1.5 if hand has 3 or less cards", effectType="conditional_multiplier", value=1.5, price=75, id="joker_sharp_conditional"},
        
        -- New Jokers for this subtask
        {name="Hearts Bonus", description="+25 if hand contains at least 2 Hearts", effectType="conditional_bonus_suit", value={ suit = "Hearts", count = 2, bonus = 25 }, price=75, id="joker_hearts_bonus"},
        {name="Ace High Multiplier", description="Score x1.5 if hand is High Card and contains an Ace", effectType="conditional_mult_highcard_ace", value=1.5, price=60, id="joker_ace_high_mult"},
        {name="Small Token Joker", description="+2 score for each card in the played hand", effectType="bonus_per_card", value=2, price=40, id="joker_small_token"}
    }

    -- Add a test joker
    local testJoker = Joker:new("Multiplier Joker", "Multiplies score by 1.5x", "score_multiplier", 1.5)
    table.insert(playerJokers, testJoker)
    local testJoker2 = Joker:new("Flat Bonus Joker", "+10 to score (not implemented yet)", "flat_bonus", 10)
    table.insert(playerJokers, testJoker2)

    playerJokers = {} 
    
    table.insert(availableShopJokers, {name="Joker of Spades", description="+15 flat bonus", effectType="flat_score_bonus", value=15})
    table.insert(availableShopJokers, {name="Joker of Hearts", description="Score x1.2", effectType="score_multiplier", value=1.2})
    table.insert(availableShopJokers, {name="Joker of Clubs", description="+25 flat bonus", effectType="flat_score_bonus", value=25})
    table.insert(availableShopJokers, {name="Joker of Diamonds", description="Score x1.3", effectType="score_multiplier", value=1.3})
    table.insert(availableShopJokers, {name="Glass Joker", description="Score x2 (Fragile!)", effectType="score_multiplier", value=2.0})
    table.insert(availableShopJokers, {name="Stone Joker", description="+50 flat bonus", effectType="flat_score_bonus", value=50})

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
                playSound(sfxCardDeal) -- Sound for reshuffle might be same as deal
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
        if dealtCardThisRefill then playSound(sfxCardDeal) end -- Play deal sound once if any cards were dealt
    end
end

function love.update(dt)
    updateUIMessage(dt) -- Update message timer

    -- Update Joker Activation Message Timer
    if jokerMessageTimer > 0 then
        jokerMessageTimer = jokerMessageTimer - dt
        if jokerMessageTimer <= 0 then
            activatedJokerMessages = {} -- Clear messages when timer expires
        end
    end
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
    love.graphics.printf("Round: " .. currentRound, 20, topBarY, screenWidth - 40, "left")
    love.graphics.printf("Cash: $" .. playerCash, 200, topBarY, screenWidth - 40, "left") -- Display cash
    love.graphics.printf("Target: " .. targetScore, 0, topBarY, screenWidth, "center")
    love.graphics.printf("Score: " .. playerScore, 20, topBarY, screenWidth - 40, "right")

    -- Joker Display Area
    local jokerAreaX = 20
    local jokerAreaY = topBarY + 40 
    love.graphics.setFont(love.graphics.newFont(16))
    love.graphics.print("Jokers:", jokerAreaX, jokerAreaY)
    local currentJokerY = jokerAreaY + 20
    if #playerJokers == 0 then
        love.graphics.print("None", jokerAreaX, currentJokerY)
        currentJokerY = currentJokerY + 20
    else
        for i, joker in ipairs(playerJokers) do
            love.graphics.print(joker.name .. ": " .. joker.description, jokerAreaX, currentJokerY)
            currentJokerY = currentJokerY + 20
        end
    end

    -- Display Activated Joker Messages
    if jokerMessageTimer > 0 and #activatedJokerMessages > 0 then
        love.graphics.setFont(love.graphics.newFont(16))
        love.graphics.setColor(0, 1, 0, 0.8) -- Green color for activation messages
        currentJokerY = currentJokerY + 10 -- Add some padding
        love.graphics.print("Activated:", jokerAreaX, currentJokerY)
        currentJokerY = currentJokerY + 20
        for _, msg in ipairs(activatedJokerMessages) do
            love.graphics.print("- " .. msg, jokerAreaX + 10, currentJokerY)
            currentJokerY = currentJokerY + 20
        end
        love.graphics.setColor(1,1,1) -- Reset color
    end

    love.graphics.setFont(love.graphics.newFont(20)) -- Reset font

    -- Plays and Discards (Info near buttons)
    local bottomInfoY = screenHeight - 45 
    love.graphics.setFont(love.graphics.newFont(20))
    love.graphics.printf("Plays: " .. playerPlaysRemaining, currentScreenWidth / 2 - 180, bottomInfoY, 100, "left")
    love.graphics.printf("Discards: " .. playerDiscardsRemaining, currentScreenWidth / 2 + 80, bottomInfoY, 100, "right")
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
            if i == selectedShopItemIndex then
                love.graphics.setColor(1,1,0) 
            else
                love.graphics.setColor(1,1,1)
            end
            love.graphics.printf(itemText, 50, 120 + (i * 40), currentScreenWidth - 100, "left")
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
        love.graphics.printf("Press 'R' to Restart", 0, screenHeight / 2 + 70, screenWidth, "center")
    elseif gameState == "shop" then
        love.graphics.setFont(love.graphics.newFont(40))
        love.graphics.printf("Shop", 0, 50, screenWidth, "center") -- Title moved up

        love.graphics.setFont(love.graphics.newFont(22))
        love.graphics.printf("Cash: $" .. playerCash, 20, 20, screenWidth, "left") -- Cash top left

        love.graphics.setFont(love.graphics.newFont(18))
        local itemStartY = 120
        local itemHeight = 60 -- Increased height for more info
        local itemPadding = 10

        for i, item in ipairs(shopItems) do
            local itemTextY = itemStartY + (i - 1) * (itemHeight + itemPadding)
            
            -- Visual highlight for selected item
            if selectedShopItemIndex == i then
                love.graphics.setColor(0.2, 0.6, 0.2, 0.5) -- Semi-transparent green
                love.graphics.rectangle("fill", 40, itemTextY - 5, screenWidth - 80, itemHeight)
                love.graphics.setColor(1, 1, 1) -- Reset color for text
            end

            love.graphics.printf(i .. ". " .. item.name, 50, itemTextY, screenWidth - 100, "left")
            love.graphics.printf(item.description, 70, itemTextY + 20, screenWidth - 100, "left")
            love.graphics.printf("Price: $" .. item.price, 50, itemTextY + 40, screenWidth - 100, "right")
        end
        
        love.graphics.setFont(love.graphics.newFont(20))
        love.graphics.printf("Press 'C' to Continue. Press 'B' to Buy selected item.", 0, screenHeight - 70, screenWidth, "center")

        if currentUIMessage ~= "" then -- Show messages in shop too
            love.graphics.setFont(love.graphics.newFont(20))
            love.graphics.setColor(1,1,0.3)
            love.graphics.printf(currentUIMessage, 0, screenHeight - 50, screenWidth, "center")
            love.graphics.setColor(1,1,1)
        end
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
                playSound(sfxCardSelect) -- Sound for staging action
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
                playSound(sfxCardSelect) -- Sound for staging action
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
                        playerPlaysRemaining = playerPlaysRemaining - 1
                        -- Pass playerJokers to calculateScore
                        local scoreForThisHand, handType, activatedJokers = HandEvaluator.calculateScore(cardsToPlayObjects, playerJokers)
                        playerScore = playerScore + scoreForThisHand
                        print("Played Hand: " .. handType .. ", Score: " .. scoreForThisHand .. ". Round Score: " .. playerScore .. ". Plays left: " .. playerPlaysRemaining)
                        
                        if activatedJokers and #activatedJokers > 0 then
                            activatedJokerMessages = activatedJokers
                            jokerMessageTimer = jokerMessageDuration
                        end
                        
                        for _, cardObj in ipairs(cardsToPlayObjects) do playerHand:removeCard(cardObj) end
                        selectedCardsIndices = {} 

                        if playerScore >= targetScore then
                            playerCash = playerCash + (playerScore - targetScore) + 50 -- Award cash
                            setUIMessage("Round " .. currentRound .. " Cleared! Entering Shop. Cash: $" .. playerCash)
                            gameState = "shop" -- Transition to shop
                        elseif playerPlaysRemaining == 0 then
                            setUIMessage("Game Over - Target: " .. targetScore .. ", Final Score: " .. playerScore, 5)
                            gameState = "gameover"
                            playSound(sfxError) -- Or a specific game over sound
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
                 playSound(sfxCardDeal) -- Sound for cards returning to hand
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
            playSound(sfxCardSelect) -- Sound for selecting shop item
        end

        if (key == "return" or key == "kpenter") and #shopItems > 0 and selectedShopItemIndex then
            if shopItems[selectedShopItemIndex] then
                local purchasedJoker = table.remove(shopItems, selectedShopItemIndex)
                table.insert(playerJokers, purchasedJoker)
                setUIMessage("Purchased: " .. purchasedJoker.name .. "!", 2)
                print("Purchased Joker: " .. purchasedJoker.name)
                playSound(sfxShopPurchase)
                selectedShopItemIndex = math.max(1, selectedShopItemIndex -1) 
                if #shopItems == 0 then selectedShopItemIndex = nil end
            else
                 setUIMessage("Item not available.", 2)
                 playSound(sfxError)
            end
        end
    elseif gameState == "shop" then
        if key == "c" then
            -- Setup next round
            currentRound = currentRound + 1
            targetScore = targetScore + 50 * currentRound 
            playerScore = 0
            playerPlaysRemaining = 4 
            playerDiscardsRemaining = 3 
            refillHand()
            selectedCardsIndices = {} -- Reset selected cards for the new round
            setUIMessage("Starting Round " .. currentRound .. ". Target: " .. targetScore)
            gameState = "gameplay"
        else
            local numKey = tonumber(key)
            if numKey and numKey >= 1 and numKey <= #shopItems then
                selectedShopItemIndex = numKey
                setUIMessage("Selected: " .. shopItems[selectedShopItemIndex].name)
            elseif key == "b" then
                if selectedShopItemIndex then
                    local item = shopItems[selectedShopItemIndex]
                    if playerCash >= item.price then
                        playerCash = playerCash - item.price
                        -- Create a new joker object. Note: Joker class needs to handle these params.
                        -- Assuming Joker:new(name, description, effectType, value)
                        local newJoker = Joker:new(item.name, item.description, item.effectType, item.value)
                        table.insert(playerJokers, newJoker)
                        setUIMessage("Purchased: " .. item.name)
                        -- For now, allow re-buying. selectedShopItemIndex will be reset below.
                    else
                        setUIMessage("Not enough cash for: " .. item.name)
                    end
                    selectedShopItemIndex = nil -- Reset selection after purchase attempt
                else
                    setUIMessage("Select an item to buy first (1-" .. #shopItems .. ").")
                end
            end
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
            playerDiscardsRemaining = 3; playerPlaysRemaining = 4
            initialHandSize = 8
            gameDeck = Deck:new(); gameDeck:shuffle()
            playerHand = Hand:new()
            stagedCards = {}; currentActionType = nil; handSelectedCardIndices = {}
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
        playerDiscardsRemaining = 3; playerPlaysRemaining = 4
        initialHandSize = 8
        gameDeck = Deck:new(); gameDeck:shuffle()
        playerHand = Hand:new()
        stagedCards = {}; currentActionType = nil; handSelectedCardIndices = {}
        refillHand()
        setUIMessage("New game started! Select cards, then P or D.")
        gameState = "gameplay" 
        playSound(sfxRoundClear) -- Or a specific game start sound
    end
end

function Hand:removeCardByIndex(indexToRemove)
    if indexToRemove >= 1 and indexToRemove <= #self.cards then
        local card = table.remove(self.cards, indexToRemove)
        return card
    end
    return nil
end
