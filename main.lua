-- Global variables
screenWidth = 800
screenHeight = 600
gameState = "menu" -- Valid states: "menu", "gameplay", "shop", "gameover"

-- UI Message variables
currentUIMessage = ""
uiMessageTimer = 0
uiMessageDuration = 2.5 -- seconds

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

function setUIMessage(message)
    currentUIMessage = message
    uiMessageTimer = uiMessageDuration
end


-- LÖVE 2D Callbacks

function love.load()
    love.window.setTitle("Balatro-Like Card Game")
    love.window.setMode(screenWidth, screenHeight)

    -- Load external modules
    require("card_graphics") -- Defines cardWidth, cardHeight, suitColors, drawCardPlaceholder
    Card = require("card")
    Deck = require("deck")
    Hand = require("hand")
    HandEvaluator = require("hand_evaluator")
    Joker = require("joker") -- Load Joker class

    -- Game loop variables
    playerScore = 0 -- Score for the current round
    playerCash = 0 -- Cash for the player
    currentRound = 1
    targetScore = 100 -- First Blind
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


    gameDeck = Deck:new()
    gameDeck:shuffle()
    playerHand = Hand:new()
    
    refillHand() -- Initial hand fill
    setUIMessage("Welcome! Jokers Loaded. Press '2' to start.")
    -- gameState = "menu" -- To start at menu, uncomment this and change default above
end

-- Helper function to refill hand up to initialHandSize
function refillHand()
    local cardsNeeded = initialHandSize - playerHand:getCount()
    if cardsNeeded > 0 then
        print("Refilling hand with " .. cardsNeeded .. " cards.")
        for i = 1, cardsNeeded do
            if #gameDeck.cards == 0 then
                print("Deck empty. Reshuffling.")
                gameDeck:reshuffle()
                setUIMessage("Deck reshuffled!")
            end
            local newCard = gameDeck:deal()
            if newCard then
                playerHand:addCard(newCard)
            else
                print("Error: Deck still empty after attempting reshuffle or newCard is nil.")
                setUIMessage("Error: Deck problem after reshuffle.")
                break 
            end
        end
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

-- Function to draw Gameplay UI
function drawGameplayUI()
    -- Hand Display
    love.graphics.setFont(love.graphics.newFont(18)) -- Font for card text
    local handCards = playerHand:getCards()
    local cardSpacing = cardWidth + 20 
    local handDisplayWidth = (#handCards * cardSpacing) - 20 
    if #handCards == 0 then handDisplayWidth = 0 end
    local startX = (screenWidth - handDisplayWidth) / 2 
    local handYPosition = screenHeight - cardHeight - 70 

    for i, card in ipairs(handCards) do
        local currentX = startX + (i - 1) * cardSpacing
        local currentY = handYPosition

        local isSelected = false
        for _, selectedIdx in ipairs(selectedCardsIndices) do
            if selectedIdx == i then
                isSelected = true
                break
            end
        end

        if isSelected then
            currentY = handYPosition - 20 -- Move selected card up
            love.graphics.setColor(0, 0.7, 0) -- Green highlight
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", currentX - 3, currentY - 3, cardWidth + 6, cardHeight + 6)
            love.graphics.setLineWidth(1)
            love.graphics.setColor(1,1,1) -- Reset color
        end
        drawCardPlaceholder(currentX, currentY, card.suit, card.rank)
    end

    -- Score and Round Info (Top Bar)
    love.graphics.setFont(love.graphics.newFont(22))
    local topBarY = 15
    love.graphics.setColor(0.2, 0.2, 0.2, 0.85) 
    love.graphics.rectangle("fill", 0, 0, screenWidth, 50)
    love.graphics.setColor(1,1,1) 
    love.graphics.printf("Round: " .. currentRound, 20, topBarY, screenWidth - 40, "left")
    love.graphics.printf("Cash: $" .. playerCash, 200, topBarY, screenWidth - 40, "left") -- Display cash
    love.graphics.printf("Target: " .. targetScore, 0, topBarY, screenWidth, "center")
    love.graphics.printf("Score: " .. playerScore, 20, topBarY, screenWidth - 40, "right")

    -- Joker Display Area
    local jokerAreaX = 20
    local jokerAreaY = topBarY + 40 -- Below top bar
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
    love.graphics.printf("Plays: " .. playerPlaysRemaining, screenWidth / 2 - 180, bottomInfoY, 100, "left")
    love.graphics.printf("Discards: " .. playerDiscardsRemaining, screenWidth / 2 + 80, bottomInfoY, 100, "right")

    -- Button Placeholders
    local buttonWidth = 160
    local buttonHeight = 40
    local buttonY = screenHeight - 55 

    -- Play Button
    love.graphics.setColor(0.3, 0.7, 0.3, 0.9) 
    love.graphics.rectangle("fill", screenWidth / 2 - buttonWidth - 10, buttonY, buttonWidth, buttonHeight)
    love.graphics.setColor(1,1,1)
    love.graphics.printf("[P] Play Hand", screenWidth / 2 - buttonWidth - 10, buttonY + 10, buttonWidth, "center")

    -- Discard Button
    love.graphics.setColor(0.7, 0.3, 0.3, 0.9) 
    love.graphics.rectangle("fill", screenWidth / 2 + 10, buttonY, buttonWidth, buttonHeight)
    love.graphics.setColor(1,1,1)
    love.graphics.printf("[D] Discard", screenWidth / 2 + 10, buttonY + 10, buttonWidth, "center")
    
    -- Instructions / UI Messages
    love.graphics.setFont(love.graphics.newFont(20))
    local instructionTextY = 60 
    if currentUIMessage ~= "" then
        love.graphics.setColor(1,1,0.3) -- Light Yellow for messages
        love.graphics.printf(currentUIMessage, 0, instructionTextY, screenWidth, "center")
    else
        love.graphics.setColor(0.85, 0.85, 0.85) -- Default instruction color
        local instructionText = "Select cards (1-" .. playerHand:getCount() .. ")"
        if playerHand:getCount() == 0 then
            instructionText = "No cards in hand."
        end
        if #selectedCardsIndices > 0 then
            instructionText = instructionText .. " (" .. #selectedCardsIndices .. " selected)"
        end
        love.graphics.printf(instructionText, 0, instructionTextY, screenWidth, "center")
    end
    love.graphics.setColor(1,1,1) -- Reset color
end

function love.draw()
    love.graphics.setBackgroundColor(0.1, 0.1, 0.1) 

    if gameState == "menu" then
        love.graphics.setFont(love.graphics.newFont(40))
        love.graphics.printf("Balatro-Like Card Game", 0, screenHeight / 3 - 20, screenWidth, "center")
        love.graphics.setFont(love.graphics.newFont(28))
        love.graphics.printf("Press '2' to Start Game", 0, screenHeight / 2 + 30, screenWidth, "center")
        love.graphics.printf("Press '`' (Backtick) to Quit", 0, screenHeight / 2 + 70, screenWidth, "center")
        if currentUIMessage ~= "" then -- Show messages on menu too
            love.graphics.setFont(love.graphics.newFont(20))
            love.graphics.setColor(1,1,0.3)
            love.graphics.printf(currentUIMessage, 0, screenHeight - 50, screenWidth, "center")
            love.graphics.setColor(1,1,1)
        end
    elseif gameState == "gameplay" then
        drawGameplayUI()
    elseif gameState == "gameover" then
        love.graphics.setFont(love.graphics.newFont(50))
        love.graphics.printf("Game Over", 0, screenHeight / 3 - 20, screenWidth, "center")
        love.graphics.setFont(love.graphics.newFont(30))
        love.graphics.printf("You reached Round: " .. currentRound, 0, screenHeight / 2 + 20, screenWidth, "center")
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
        local numKey = tonumber(key)
        if numKey and numKey >= 1 and numKey <= playerHand:getCount() then
            local indexInSelected = nil
            for i, idx in ipairs(selectedCardsIndices) do
                if idx == numKey then indexInSelected = i break end
            end
            if indexInSelected then
                table.remove(selectedCardsIndices, indexInSelected)
                setUIMessage("Deselected card at hand index: " .. numKey)
            else
                table.insert(selectedCardsIndices, numKey)
                setUIMessage("Selected card at hand index: " .. numKey)
            end
            table.sort(selectedCardsIndices)
        end

        if key == "p" then
            if #selectedCardsIndices > 0 then
                local cardsToPlayObjects = {}
                local handCards = playerHand:getCards()
                for _, handIdx in ipairs(selectedCardsIndices) do
                    if handIdx >= 1 and handIdx <= #handCards then
                        table.insert(cardsToPlayObjects, handCards[handIdx])
                    end
                end

                if #cardsToPlayObjects > 0 then
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
                            setUIMessage("Game Over - Target: " .. targetScore .. ", Final Score: " .. playerScore)
                            gameState = "gameover"
                        else
                             setUIMessage("Played: " .. handType .. " (" .. scoreForThisHand .. "). Plays left: " .. playerPlaysRemaining)
                        end
                    else
                        setUIMessage("No plays remaining this round!")
                    end
                else
                    setUIMessage("Error: Selection did not yield cards to play. Try again.")
                     -- This case should ideally not happen if selection logic is sound.
                end
            else
                setUIMessage("Select cards to play first!")
            end
        end

        if key == "d" then
            if playerDiscardsRemaining > 0 then
                if #selectedCardsIndices > 0 then
                    local cardsToDiscardObjects = {}
                    local handCards = playerHand:getCards()
                    for _, handIdx in ipairs(selectedCardsIndices) do
                        if handIdx >= 1 and handIdx <= #handCards then
                            table.insert(cardsToDiscardObjects, handCards[handIdx])
                        end
                    end

                    if #cardsToDiscardObjects > 0 then
                        playerDiscardsRemaining = playerDiscardsRemaining - 1
                        for _, cardObj in ipairs(cardsToDiscardObjects) do playerHand:removeCard(cardObj) end
                        refillHand() 
                        setUIMessage("Discarded " .. #cardsToDiscardObjects .. " cards. " .. playerDiscardsRemaining .. " discards left.")
                    else
                        setUIMessage("No valid cards selected to discard!")
                    end
                    selectedCardsIndices = {} 
                else
                    setUIMessage("Select cards to discard first!")
                end
            else
                setUIMessage("No discards remaining this round!")
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

    if key == "f1" or (gameState == "menu" and key == "1") then 
        gameState = "menu"
        setUIMessage("Returned to Menu.")
    end
    if key == "f2" or (gameState == "menu" and key == "2") then
        if gameState ~= "gameplay" then -- Avoid resetting if already in gameplay and F2 is hit
            print("Starting game from menu or F2 press...")
            playerScore = 0; currentRound = 1; targetScore = 100
            playerDiscardsRemaining = 3; playerPlaysRemaining = 4
            initialHandSize = 8
            gameDeck = Deck:new(); gameDeck:shuffle()
            playerHand = Hand:new(); refillHand()
            selectedCardsIndices = {}
            setUIMessage("New game started!")
        end
        gameState = "gameplay"
    end
    if key == "`" then love.event.quit() end

    if gameState == "gameover" and key == "r" then
        print("Resetting game...")
        playerScore = 0; currentRound = 1; targetScore = 100
        playerDiscardsRemaining = 3; playerPlaysRemaining = 4
        initialHandSize = 8
        -- playerJokers list persists between games for now, or could be reset here
        -- playerJokers list persists between games for now, or could be reset here
        -- To reset jokers: playerJokers = {} 
        -- (and re-add any default/starting jokers if desired)
        gameDeck = Deck:new(); gameDeck:shuffle()
        playerHand = Hand:new(); refillHand()
        selectedCardsIndices = {}
        setUIMessage("New game started after Game Over!")
        gameState = "gameplay" 
    end
end
