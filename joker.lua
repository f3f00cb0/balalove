-- Joker class
Joker = {}
Joker.__index = Joker

function Joker:new(name, description, effectType, value)
    local instance = setmetatable({}, Joker)
    instance.name = name or "Unnamed Joker"
    instance.id = name or "Unnamed Joker" -- Use name as the unique ID
    instance.description = description or "No description."
    instance.effectType = effectType or "none"
    instance.value = value or 0
    return instance
end

function Joker:__tostring()
    return self.name .. " (" .. self.effectType .. ": " .. tostring(self.value) .. ")"
end

-- Table to store joker effect handler functions
Joker.effectHandlers = {}

-- Helper for suit colors (can be defined globally in this module or locally within the handler)
local internalSuitColors = { Hearts = "Red", Diamonds = "Red", Clubs = "Black", Spades = "Black" }


-- score_multiplier effect handler
function Joker.effectHandlers.score_multiplier(jokerInstance, scoreDetails)
    if jokerInstance.value and type(jokerInstance.value) == "number" then
        scoreDetails.score = scoreDetails.score * jokerInstance.value
        print("Applied joker '" .. jokerInstance.name .. "': score multiplied by " .. jokerInstance.value)
    else
        print("Warning: Joker '" .. jokerInstance.name .. "' has invalid value for score_multiplier: " .. tostring(jokerInstance.value))
    end
    return scoreDetails
end

-- flat_score_bonus effect handler
function Joker.effectHandlers.flat_score_bonus(jokerInstance, scoreDetails)
    if jokerInstance.value and type(jokerInstance.value) == "number" then
        scoreDetails.score = scoreDetails.score + jokerInstance.value
        print("Applied joker '" .. jokerInstance.name .. "': flat score bonus of " .. jokerInstance.value)
    else
        print("Warning: Joker '" .. jokerInstance.name .. "' has invalid value for flat_score_bonus: " .. tostring(jokerInstance.value))
    end
    return scoreDetails
end

-- hand_type_score_multiplier effect handler
function Joker.effectHandlers.hand_type_score_multiplier(jokerInstance, scoreDetails)
    if jokerInstance.value and type(jokerInstance.value) == "table" and
       jokerInstance.value.handType and type(jokerInstance.value.handType) == "string" and
       jokerInstance.value.multiplier and type(jokerInstance.value.multiplier) == "number" then
        
        if scoreDetails.handType == jokerInstance.value.handType then
            scoreDetails.score = scoreDetails.score * jokerInstance.value.multiplier
            print("Applied joker '" .. jokerInstance.name .. "': score multiplied by " .. jokerInstance.value.multiplier .. " for hand type " .. scoreDetails.handType)
        end
    else
        print("Warning: Joker '" .. jokerInstance.name .. "' has invalid or incomplete 'value' table for hand_type_score_multiplier. Expected {handType=\"type\", multiplier=M}.")
    end
    return scoreDetails
end

-- hand_type_flat_bonus effect handler
function Joker.effectHandlers.hand_type_flat_bonus(jokerInstance, scoreDetails)
    if jokerInstance.value and type(jokerInstance.value) == "table" and
       jokerInstance.value.handType and type(jokerInstance.value.handType) == "string" and
       jokerInstance.value.bonus and type(jokerInstance.value.bonus) == "number" then

        if scoreDetails.handType == jokerInstance.value.handType then
            scoreDetails.score = scoreDetails.score + jokerInstance.value.bonus
            print("Applied joker '" .. jokerInstance.name .. "': flat bonus of " .. jokerInstance.value.bonus .. " for hand type " .. scoreDetails.handType)
        end
    else
        print("Warning: Joker '" .. jokerInstance.name .. "' has invalid or incomplete 'value' table for hand_type_flat_bonus. Expected {handType=\"type\", bonus=B}.")
    end
    return scoreDetails
end

-- rank_specific_flat_bonus_per_card effect handler
function Joker.effectHandlers.rank_specific_flat_bonus_per_card(jokerInstance, scoreDetails)
    if jokerInstance.value and type(jokerInstance.value) == "table" and
       jokerInstance.value.rank and type(jokerInstance.value.rank) == "string" and
       jokerInstance.value.bonusPerCard and type(jokerInstance.value.bonusPerCard) == "number" then

        local totalBonusAdded = 0
        for _, card in ipairs(scoreDetails.cards) do
            if card.rank == jokerInstance.value.rank then
                scoreDetails.score = scoreDetails.score + jokerInstance.value.bonusPerCard
                totalBonusAdded = totalBonusAdded + jokerInstance.value.bonusPerCard
            end
        end
        if totalBonusAdded > 0 then
            print("Applied joker '" .. jokerInstance.name .. "': total flat bonus of " .. totalBonusAdded .. " for rank " .. jokerInstance.value.rank)
        end
    else
        print("Warning: Joker '" .. jokerInstance.name .. "' has invalid or incomplete 'value' table for rank_specific_flat_bonus_per_card. Expected {rank=\"R\", bonusPerCard=BPC}.")
    end
    return scoreDetails
end

-- conditional_flat_bonus_on_rank_present effect handler
function Joker.effectHandlers.conditional_flat_bonus_on_rank_present(jokerInstance, scoreDetails)
    if jokerInstance.value and type(jokerInstance.value) == "table" and
       jokerInstance.value.rank and type(jokerInstance.value.rank) == "string" and
       jokerInstance.value.bonus and type(jokerInstance.value.bonus) == "number" then

        local rankFound = false
        for _, card in ipairs(scoreDetails.cards) do
            if card.rank == jokerInstance.value.rank then
                rankFound = true
                break
            end
        end
        if rankFound then
            scoreDetails.score = scoreDetails.score + jokerInstance.value.bonus
            print("Applied joker '" .. jokerInstance.name .. "': flat bonus of " .. jokerInstance.value.bonus .. " because rank " .. jokerInstance.value.rank .. " was present.")
        end
    else
        print("Warning: Joker '" .. jokerInstance.name .. "' has invalid or incomplete 'value' table for conditional_flat_bonus_on_rank_present. Expected {rank=\"R\", bonus=B}.")
    end
    return scoreDetails
end

-- conditional_score_multiplier_all_suits_are_color effect handler
function Joker.effectHandlers.conditional_score_multiplier_all_suits_are_color(jokerInstance, scoreDetails)
    if jokerInstance.value and type(jokerInstance.value) == "table" and
       jokerInstance.value.color and (jokerInstance.value.color == "Red" or jokerInstance.value.color == "Black") and
       jokerInstance.value.multiplier and type(jokerInstance.value.multiplier) == "number" then

        local allMatchColor = true
        if #scoreDetails.cards == 0 then -- No cards, condition arguably not met, or met vacuously. Let's say not met.
            allMatchColor = false
        end

        for _, card in ipairs(scoreDetails.cards) do
            local cardColor = internalSuitColors[card.suit]
            if not cardColor or cardColor ~= jokerInstance.value.color then
                allMatchColor = false
                break
            end
        end

        if allMatchColor then
            scoreDetails.score = scoreDetails.score * jokerInstance.value.multiplier
            print("Applied joker '" .. jokerInstance.name .. "': score multiplied by " .. jokerInstance.value.multiplier .. " because all cards were " .. jokerInstance.value.color)
        end
    else
        print("Warning: Joker '" .. jokerInstance.name .. "' has invalid or incomplete 'value' table for conditional_score_multiplier_all_suits_are_color. Expected {color=\"Red/Black\", multiplier=M}.")
    end
    return scoreDetails
end

-- Helper function to get rank counts, similar to HandEvaluator's, but local if needed
local function getRankCountsForJoker(cards)
    local counts = {}
    for _, card in ipairs(cards) do
        counts[card.rank] = (counts[card.rank] or 0) + 1
    end
    return counts
end

-- Helper function to get numerical rank, specific for Blackjack (Ace as 1 or 11)
local function getBlackjackRankValue(rankString, currentSum)
    if rankString == "A" then
        return (currentSum + 11 <= 21) and 11 or 1
    elseif rankString == "K" or rankString == "Q" or rankString == "J" then
        return 10
    else
        return tonumber(rankString) or 0 -- tonumber will handle "2" through "10"
    end
end


-- Set B Joker Effect Handlers

function Joker.effectHandlers.conditional_hand_type_bonus_rank_math(jokerInstance, scoreDetails)
    if not (jokerInstance.value and type(jokerInstance.value) == "table" and
            jokerInstance.value.handType and type(jokerInstance.value.handType) == "string" and
            jokerInstance.value.evenBonus and type(jokerInstance.value.evenBonus) == "number" and
            jokerInstance.value.oddBonus and type(jokerInstance.value.oddBonus) == "number") then
        print("Warning: Joker '" .. jokerInstance.name .. "' has invalid or incomplete 'value' table. Expected {handType='type', evenBonus=E, oddBonus=O}.")
        return scoreDetails
    end

    if scoreDetails.handType == jokerInstance.value.handType then
        local rankCounts = getRankCountsForJoker(scoreDetails.cards)
        local pairedRankValue = 0
        
        if jokerInstance.value.handType == "Pair" then
            for rank, count in pairs(rankCounts) do
                if count == 2 then
                    -- Use HandEvaluator.rankValues if available, otherwise define a local map.
                    -- Assuming HandEvaluator is loaded and globally accessible as 'HandEvaluator'
                    if HandEvaluator and HandEvaluator.rankValues and HandEvaluator.rankValues[rank] then
                        pairedRankValue = HandEvaluator.rankValues[rank]
                    else 
                        -- Fallback or error if HandEvaluator.rankValues isn't accessible
                        print("Warning: HandEvaluator.rankValues not accessible for Pair Parity joker.")
                        return scoreDetails 
                    end
                    break -- Found the pair
                end
            end
            
            if pairedRankValue > 0 then
                -- For a single pair, its value * 2 is the sum of ranks.
                -- Or, if it's just the rank value itself:
                if pairedRankValue % 2 == 0 then
                    scoreDetails.score = scoreDetails.score + jokerInstance.value.evenBonus
                    print("Applied joker '" .. jokerInstance.name .. "': +" .. jokerInstance.value.evenBonus .. " (rank " .. pairedRankValue .. " is even).")
                else
                    scoreDetails.score = scoreDetails.score + jokerInstance.value.oddBonus
                    print("Applied joker '" .. jokerInstance.name .. "': +" .. jokerInstance.value.oddBonus .. " (rank " .. pairedRankValue .. " is odd).")
                end
            end
        else
             print("Warning: Joker '" .. jokerInstance.name .. "' is configured for handType '" .. jokerInstance.value.handType .. "', but this logic is specific to 'Pair'.")
        end
    end
    return scoreDetails
end

function Joker.effectHandlers.conditional_flat_bonus_card_property_count(jokerInstance, scoreDetails)
    if not (jokerInstance.value and type(jokerInstance.value) == "table" and
            jokerInstance.value.property and jokerInstance.value.property == "isFaceCard" and -- Currently only supports "isFaceCard"
            jokerInstance.value.threshold and type(jokerInstance.value.threshold) == "number" and
            jokerInstance.value.bonus and type(jokerInstance.value.bonus) == "number") then
        print("Warning: Joker '" .. jokerInstance.name .. "' has invalid or incomplete 'value' table. Expected {property='isFaceCard', threshold=T, bonus=B}.")
        return scoreDetails
    end

    local faceCardCount = 0
    local faceRanks = { ["J"] = true, ["Q"] = true, ["K"] = true }

    for _, card in ipairs(scoreDetails.cards) do
        if faceRanks[card.rank] then
            faceCardCount = faceCardCount + 1
        end
    end

    if faceCardCount >= jokerInstance.value.threshold then
        scoreDetails.score = scoreDetails.score + jokerInstance.value.bonus
        print("Applied joker '" .. jokerInstance.name .. "': +" .. jokerInstance.value.bonus .. " (" .. faceCardCount .. " face cards >= threshold " .. jokerInstance.value.threshold .. ").")
    end
    return scoreDetails
end

function Joker.effectHandlers.flat_bonus_per_unique_suit_in_played_hand(jokerInstance, scoreDetails)
    if not (jokerInstance.value and type(jokerInstance.value) == "table" and
            jokerInstance.value.bonusPerUniqueSuit and type(jokerInstance.value.bonusPerUniqueSuit) == "number") then
        print("Warning: Joker '" .. jokerInstance.name .. "' has invalid 'value' table. Expected {bonusPerUniqueSuit=BUS}.")
        return scoreDetails
    end

    local uniqueSuits = {}
    for _, card in ipairs(scoreDetails.cards) do
        uniqueSuits[card.suit] = true
    end
    local numUniqueSuits = 0
    for _ in pairs(uniqueSuits) do
        numUniqueSuits = numUniqueSuits + 1
    end

    local totalBonus = numUniqueSuits * jokerInstance.value.bonusPerUniqueSuit
    scoreDetails.score = scoreDetails.score + totalBonus
    if totalBonus > 0 then
        print("Applied joker '" .. jokerInstance.name .. "': +" .. totalBonus .. " (" .. numUniqueSuits .. " unique suits * " .. jokerInstance.value.bonusPerUniqueSuit .. ").")
    end
    return scoreDetails
end

function Joker.effectHandlers.conditional_flat_bonus_consecutive_ranks(jokerInstance, scoreDetails)
    if not (jokerInstance.value and type(jokerInstance.value) == "table" and
            jokerInstance.value.bonus and type(jokerInstance.value.bonus) == "number") then
        print("Warning: Joker '" .. jokerInstance.name .. "' has invalid 'value' table. Expected {bonus=B}.")
        return scoreDetails
    end

    if #scoreDetails.cards < 2 then return scoreDetails end -- Need at least 2 cards for consecutive check

    local tempCards = {}
    for _, c in ipairs(scoreDetails.cards) do table.insert(tempCards, {rank = c.rank, suit = c.suit}) end -- Shallow copy

    -- Sort by rank (Ace high for general case, Ace low handled specifically if needed)
    table.sort(tempCards, function(a,b)
        local valA = (HandEvaluator and HandEvaluator.rankValues and HandEvaluator.rankValues[a.rank]) or tonumber(a.rank) or 0
        local valB = (HandEvaluator and HandEvaluator.rankValues and HandEvaluator.rankValues[b.rank]) or tonumber(b.rank) or 0
        return valA < valB
    end)
    
    local isConsecutive = true
    -- Check standard consecutive
    for i = 1, #tempCards - 1 do
        local valCurrent = (HandEvaluator and HandEvaluator.rankValues and HandEvaluator.rankValues[tempCards[i].rank])
        local valNext = (HandEvaluator and HandEvaluator.rankValues and HandEvaluator.rankValues[tempCards[i+1].rank])
        if not valCurrent or not valNext or (valNext ~= valCurrent + 1) then
            isConsecutive = false
            break
        end
    end
    
    -- Special check for A-2-3-4-5 (if HandEvaluator.rankValues makes Ace 14)
    -- This specific check is for 5 cards, if the joker should apply to any number of consecutive cards, this needs generalization.
    -- For simplicity, this joker will trigger for any sequence of N consecutive cards, not just 5-card straights.
    -- The current `isConsecutive` check above handles general consecutiveness.

    if isConsecutive then
        scoreDetails.score = scoreDetails.score + jokerInstance.value.bonus
        print("Applied joker '" .. jokerInstance.name .. "': +" .. jokerInstance.value.bonus .. " (ranks are consecutive).")
    end
    return scoreDetails
end

function Joker.effectHandlers.conditional_score_multiplier_blackjack_sum(jokerInstance, scoreDetails)
    if not (jokerInstance.value and type(jokerInstance.value) == "table" and
            jokerInstance.value.targetSum and type(jokerInstance.value.targetSum) == "number" and
            jokerInstance.value.multiplier and type(jokerInstance.value.multiplier) == "number") then
        print("Warning: Joker '" .. jokerInstance.name .. "' has invalid 'value' table. Expected {targetSum=TS, multiplier=M}.")
        return scoreDetails
    end

    local sum = 0
    local aceCount = 0
    for _, card in ipairs(scoreDetails.cards) do
        if card.rank == "A" then
            aceCount = aceCount + 1
            sum = sum + 11 -- Add Ace as 11 initially
        elseif card.rank == "K" or card.rank == "Q" or card.rank == "J" then
            sum = sum + 10
        else
            sum = sum + (tonumber(card.rank) or 0)
        end
    end

    -- Adjust for Aces if sum > targetSum
    while sum > jokerInstance.value.targetSum and aceCount > 0 do
        sum = sum - 10 -- Change one Ace from 11 to 1
        aceCount = aceCount - 1
    end

    if sum == jokerInstance.value.targetSum then
        scoreDetails.score = scoreDetails.score * jokerInstance.value.multiplier
        print("Applied joker '" .. jokerInstance.name .. "': score multiplied by " .. jokerInstance.value.multiplier .. " (Blackjack sum is " .. sum .. ").")
    end
    return scoreDetails
end

function Joker.effectHandlers.flat_bonus_based_on_round_number(jokerInstance, scoreDetails)
    if not (jokerInstance.value and type(jokerInstance.value) == "table" and
            jokerInstance.value.multiplier and type(jokerInstance.value.multiplier) == "number") then
        print("Warning: Joker '" .. jokerInstance.name .. "' has invalid 'value' table. Expected {multiplier=M}.")
        return scoreDetails
    end

    local bonus = (scoreDetails.roundNumber or 0) * jokerInstance.value.multiplier
    scoreDetails.score = scoreDetails.score + bonus
    if bonus ~= 0 then -- Print only if bonus is applied (roundNumber > 0 or multiplier not 0)
        print("Applied joker '" .. jokerInstance.name .. "': +" .. bonus .. " (Round " .. (scoreDetails.roundNumber or 0) .. " * " .. jokerInstance.value.multiplier .. ").")
    end
    return scoreDetails
end

-- Helper function for rank parity checks
local function isRankEven(rank)
    if HandEvaluator and HandEvaluator.rankValues and HandEvaluator.rankValues[rank] then
        return HandEvaluator.rankValues[rank] % 2 == 0
    end
    print("Warning: HandEvaluator.rankValues not accessible for rank parity check on rank: " .. tostring(rank))
    return false -- Default or error
end


-- Set C Joker Effect Handlers

function Joker.effectHandlers.multi_rank_specific_flat_bonus_per_card(jokerInstance, scoreDetails)
    if not (jokerInstance.value and type(jokerInstance.value) == "table" and
            jokerInstance.value.ranks and type(jokerInstance.value.ranks) == "table" and
            jokerInstance.value.bonusPerCard and type(jokerInstance.value.bonusPerCard) == "number") then
        print("Warning: Joker '" .. jokerInstance.name .. "' has invalid 'value' table. Expected {ranks={'R1','R2'}, bonusPerCard=BPC}.")
        return scoreDetails
    end

    local totalBonusAdded = 0
    local targetRanks = {}
    for _, r in ipairs(jokerInstance.value.ranks) do targetRanks[r] = true end

    for _, card in ipairs(scoreDetails.cards) do
        if targetRanks[card.rank] then
            scoreDetails.score = scoreDetails.score + jokerInstance.value.bonusPerCard
            totalBonusAdded = totalBonusAdded + jokerInstance.value.bonusPerCard
        end
    end
    if totalBonusAdded > 0 then
        print("Applied joker '" .. jokerInstance.name .. "': total flat bonus of " .. totalBonusAdded .. " for specified ranks.")
    end
    return scoreDetails
end

function Joker.effectHandlers.conditional_score_multiplier_all_cards_property(jokerInstance, scoreDetails)
    if not (jokerInstance.value and type(jokerInstance.value) == "table" and
            jokerInstance.value.property and type(jokerInstance.value.property) == "string" and 
            (jokerInstance.value.property == "isEvenRank" or jokerInstance.value.property == "isOddRank") and
            jokerInstance.value.multiplier and type(jokerInstance.value.multiplier) == "number") then
        print("Warning: Joker '" .. jokerInstance.name .. "' has invalid 'value' table. Expected {property='isEvenRank'/'isOddRank', multiplier=M}.")
        return scoreDetails
    end

    local allMatchProperty = true
    if #scoreDetails.cards == 0 then allMatchProperty = false end

    for _, card in ipairs(scoreDetails.cards) do
        local matches = false
        if jokerInstance.value.property == "isEvenRank" then
            matches = isRankEven(card.rank)
        elseif jokerInstance.value.property == "isOddRank" then
            matches = not isRankEven(card.rank) -- Assumes non-even is odd for numerical ranks
        end
        if not matches then
            allMatchProperty = false
            break
        end
    end

    if allMatchProperty then
        scoreDetails.score = scoreDetails.score * jokerInstance.value.multiplier
        print("Applied joker '" .. jokerInstance.name .. "': score multiplied by " .. jokerInstance.value.multiplier .. " (all cards are " .. jokerInstance.value.property .. ").")
    end
    return scoreDetails
end

function Joker.effectHandlers.conditional_flat_bonus_all_suits_are_color(jokerInstance, scoreDetails)
    -- This is similar to conditional_score_multiplier_all_suits_are_color, but applies a flat bonus.
    if not (jokerInstance.value and type(jokerInstance.value) == "table" and
       jokerInstance.value.color and (jokerInstance.value.color == "Red" or jokerInstance.value.color == "Black") and
       jokerInstance.value.bonus and type(jokerInstance.value.bonus) == "number") then
        print("Warning: Joker '" .. jokerInstance.name .. "' has invalid 'value' table. Expected {color='Red/Black', bonus=B}.")
        return scoreDetails
    end

    local allMatchColor = true
    if #scoreDetails.cards == 0 then allMatchColor = false end

    for _, card in ipairs(scoreDetails.cards) do
        local cardColor = internalSuitColors[card.suit]
        if not cardColor or cardColor ~= jokerInstance.value.color then
            allMatchColor = false
            break
        end
    end

    if allMatchColor then
        scoreDetails.score = scoreDetails.score + jokerInstance.value.bonus
        print("Applied joker '" .. jokerInstance.name .. "': flat bonus of " .. jokerInstance.value.bonus .. " (all cards " .. jokerInstance.value.color .. ").")
    end
    return scoreDetails
end

function Joker.effectHandlers.end_of_round_bonus_discards_remaining(jokerInstance, scoreDetails)
    if not (jokerInstance.value and type(jokerInstance.value) == "table" and
            jokerInstance.value.bonusPerDiscard and type(jokerInstance.value.bonusPerDiscard) == "number") then
        print("Warning: Joker '" .. jokerInstance.name .. "' has invalid 'value' table. Expected {bonusPerDiscard=BPD}.")
        return scoreDetails
    end

    if scoreDetails.isLastPlay then
        local bonus = scoreDetails.discardsRemaining * jokerInstance.value.bonusPerDiscard
        scoreDetails.score = scoreDetails.score + bonus
        if bonus ~= 0 then
             print("Applied joker '" .. jokerInstance.name .. "': +" .. bonus .. " (" .. scoreDetails.discardsRemaining .. " discards remaining * " .. jokerInstance.value.bonusPerDiscard .. ").")
        end
    end
    return scoreDetails
end

function Joker.effectHandlers.flat_bonus_per_card_in_current_hand_on_play(jokerInstance, scoreDetails)
    if not (jokerInstance.value and type(jokerInstance.value) == "table" and
            jokerInstance.value.bonusPerCard and type(jokerInstance.value.bonusPerCard) == "number") then
        print("Warning: Joker '" .. jokerInstance.name .. "' has invalid 'value' table. Expected {bonusPerCard=BPC}.")
        return scoreDetails
    end
    
    local bonus = scoreDetails.playerHandActualSize * jokerInstance.value.bonusPerCard
    scoreDetails.score = scoreDetails.score + bonus
    if bonus ~= 0 then
        print("Applied joker '" .. jokerInstance.name .. "': +" .. bonus .. " (" .. scoreDetails.playerHandActualSize .. " cards in hand * " .. jokerInstance.value.bonusPerCard .. ").")
    end
    return scoreDetails
end

function Joker.effectHandlers.flat_bonus_per_other_joker_owned(jokerInstance, scoreDetails)
    if not (jokerInstance.value and type(jokerInstance.value) == "table" and
            jokerInstance.value.bonusPerJoker and type(jokerInstance.value.bonusPerJoker) == "number") then
        print("Warning: Joker '" .. jokerInstance.name .. "' has invalid 'value' table. Expected {bonusPerJoker=BPJ}.")
        return scoreDetails
    end

    local otherJokerCount = math.max(0, scoreDetails.playerJokerCount - 1) -- Subtract self
    local bonus = otherJokerCount * jokerInstance.value.bonusPerJoker
    scoreDetails.score = scoreDetails.score + bonus
    if bonus ~= 0 then
        print("Applied joker '" .. jokerInstance.name .. "': +" .. bonus .. " (" .. otherJokerCount .. " other jokers * " .. jokerInstance.value.bonusPerJoker .. ").")
    end
    return scoreDetails
end

function Joker.effectHandlers.conditional_multiplier_first_play_of_round(jokerInstance, scoreDetails)
    if not (jokerInstance.value and type(jokerInstance.value) == "table" and
            jokerInstance.value.multiplier and type(jokerInstance.value.multiplier) == "number") then
        print("Warning: Joker '" .. jokerInstance.name .. "' has invalid 'value' table. Expected {multiplier=M}.")
        return scoreDetails
    end

    if scoreDetails.isFirstPlay then
        scoreDetails.score = scoreDetails.score * jokerInstance.value.multiplier
        print("Applied joker '" .. jokerInstance.name .. "': score multiplied by " .. jokerInstance.value.multiplier .. " (first play of round).")
    end
    return scoreDetails
end

function Joker.effectHandlers.conditional_flat_bonus_last_play_of_round(jokerInstance, scoreDetails)
     if not (jokerInstance.value and type(jokerInstance.value) == "table" and
            jokerInstance.value.bonus and type(jokerInstance.value.bonus) == "number") then
        print("Warning: Joker '" .. jokerInstance.name .. "' has invalid 'value' table. Expected {bonus=B}.")
        return scoreDetails
    end

    if scoreDetails.isLastPlay then
        scoreDetails.score = scoreDetails.score + jokerInstance.value.bonus
        print("Applied joker '" .. jokerInstance.name .. "': +" .. jokerInstance.value.bonus .. " (last play of round).")
    end
    return scoreDetails
end

-- Set D Joker Effect Handlers

function Joker.effectHandlers.multi_rank_range_flat_bonus_per_card(jokerInstance, scoreDetails)
    if not (jokerInstance.value and type(jokerInstance.value) == "table" and
            jokerInstance.value.ranks_low and type(jokerInstance.value.ranks_low) == "number" and
            jokerInstance.value.ranks_high and type(jokerInstance.value.ranks_high) == "number" and
            jokerInstance.value.bonusPerCard and type(jokerInstance.value.bonusPerCard) == "number") then
        print("Warning: Joker '" .. jokerInstance.name .. "' has invalid 'value' table. Expected {ranks_low=RL, ranks_high=RH, bonusPerCard=BPC}.")
        return scoreDetails
    end

    local totalBonusAdded = 0
    for _, card in ipairs(scoreDetails.cards) do
        local rankValue = HandEvaluator and HandEvaluator.rankValues and HandEvaluator.rankValues[card.rank]
        if rankValue then
            if rankValue >= jokerInstance.value.ranks_low and rankValue <= jokerInstance.value.ranks_high then
                scoreDetails.score = scoreDetails.score + jokerInstance.value.bonusPerCard
                totalBonusAdded = totalBonusAdded + jokerInstance.value.bonusPerCard
            end
        else
            print("Warning: Could not get rankValue for card " .. card.rank .. " in joker " .. jokerInstance.name)
        end
    end
    if totalBonusAdded > 0 then
        print("Applied joker '" .. jokerInstance.name .. "': total flat bonus of " .. totalBonusAdded .. " for ranks in range [" .. jokerInstance.value.ranks_low .. "-" .. jokerInstance.value.ranks_high .. "].")
    end
    return scoreDetails
end

function Joker.effectHandlers.conditional_score_multiplier_specific_color_counts(jokerInstance, scoreDetails)
    if not (jokerInstance.value and type(jokerInstance.value) == "table" and
            jokerInstance.value.redCount and type(jokerInstance.value.redCount) == "number" and
            jokerInstance.value.blackCount and type(jokerInstance.value.blackCount) == "number" and
            jokerInstance.value.minCards and type(jokerInstance.value.minCards) == "number" and
            jokerInstance.value.multiplier and type(jokerInstance.value.multiplier) == "number") then
        print("Warning: Joker '" .. jokerInstance.name .. "' has invalid 'value' table. Expected {redCount=RC, blackCount=BC, minCards=MC, multiplier=M}.")
        return scoreDetails
    end

    if #scoreDetails.cards >= jokerInstance.value.minCards then
        local currentRedCount = 0
        local currentBlackCount = 0
        for _, card in ipairs(scoreDetails.cards) do
            local cardColor = internalSuitColors[card.suit]
            if cardColor == "Red" then
                currentRedCount = currentRedCount + 1
            elseif cardColor == "Black" then
                currentBlackCount = currentBlackCount + 1
            end
        end

        if currentRedCount == jokerInstance.value.redCount and currentBlackCount == jokerInstance.value.blackCount then
            scoreDetails.score = scoreDetails.score * jokerInstance.value.multiplier
            print("Applied joker '" .. jokerInstance.name .. "': score multiplied by " .. jokerInstance.value.multiplier .. " (Red:" .. currentRedCount .. ", Black:" .. currentBlackCount .. ").")
        end
    end
    return scoreDetails
end

function Joker.effectHandlers.conditional_multiplier_if_card_count_is(jokerInstance, scoreDetails)
    if not (jokerInstance.value and type(jokerInstance.value) == "table" and
            jokerInstance.value.cardCount and type(jokerInstance.value.cardCount) == "number" and
            jokerInstance.value.multiplier and type(jokerInstance.value.multiplier) == "number") then
        print("Warning: Joker '" .. jokerInstance.name .. "' has invalid 'value' table. Expected {cardCount=CC, multiplier=M}.")
        return scoreDetails
    end

    if #scoreDetails.cards == jokerInstance.value.cardCount then
        scoreDetails.score = scoreDetails.score * jokerInstance.value.multiplier
        print("Applied joker '" .. jokerInstance.name .. "': score multiplied by " .. jokerInstance.value.multiplier .. " (#cards is " .. #scoreDetails.cards .. ").")
    end
    return scoreDetails
end

function Joker.effectHandlers.conditional_flat_bonus_if_hand_emptied(jokerInstance, scoreDetails)
    if not (jokerInstance.value and type(jokerInstance.value) == "table" and
            jokerInstance.value.bonus and type(jokerInstance.value.bonus) == "number") then
        print("Warning: Joker '" .. jokerInstance.name .. "' has invalid 'value' table. Expected {bonus=B}.")
        return scoreDetails
    end
    
    -- playerHandActualSize is the size *before* the played cards were removed.
    -- So, if playerHandActualSize == #scoreDetails.cards, it means all cards from hand were played.
    if scoreDetails.playerHandActualSize == #scoreDetails.cards then
        scoreDetails.score = scoreDetails.score + jokerInstance.value.bonus
        print("Applied joker '" .. jokerInstance.name .. "': +" .. jokerInstance.value.bonus .. " (hand emptied).")
    end
    return scoreDetails
end

function Joker.effectHandlers.conditional_multiplier_discards_remaining_is_zero(jokerInstance, scoreDetails)
    if not (jokerInstance.value and type(jokerInstance.value) == "table" and
            jokerInstance.value.multiplier and type(jokerInstance.value.multiplier) == "number") then
        print("Warning: Joker '" .. jokerInstance.name .. "' has invalid 'value' table. Expected {multiplier=M}.")
        return scoreDetails
    end

    if scoreDetails.discardsRemaining == 0 then
        scoreDetails.score = scoreDetails.score * jokerInstance.value.multiplier
        print("Applied joker '" .. jokerInstance.name .. "': score multiplied by " .. jokerInstance.value.multiplier .. " (0 discards remaining).")
    end
    return scoreDetails
end

function Joker.effectHandlers.flat_bonus_per_card_in_discard_pile(jokerInstance, scoreDetails)
    if not (jokerInstance.value and type(jokerInstance.value) == "table" and
            jokerInstance.value.bonusPerCard and type(jokerInstance.value.bonusPerCard) == "number") then
        print("Warning: Joker '" .. jokerInstance.name .. "' has invalid 'value' table. Expected {bonusPerCard=BPD}.")
        return scoreDetails
    end

    local bonus = scoreDetails.discardPileSize * jokerInstance.value.bonusPerCard
    scoreDetails.score = scoreDetails.score + bonus
    if bonus ~= 0 then
        print("Applied joker '" .. jokerInstance.name .. "': +" .. bonus .. " (" .. scoreDetails.discardPileSize .. " cards in discard * " .. jokerInstance.value.bonusPerCard .. ").")
    end
    return scoreDetails
end

function Joker.effectHandlers.conditional_flat_bonus_early_rounds(jokerInstance, scoreDetails)
    if not (jokerInstance.value and type(jokerInstance.value) == "table" and
            jokerInstance.value.maxRound and type(jokerInstance.value.maxRound) == "number" and
            jokerInstance.value.bonus and type(jokerInstance.value.bonus) == "number") then
        print("Warning: Joker '" .. jokerInstance.name .. "' has invalid 'value' table. Expected {maxRound=MR, bonus=B}.")
        return scoreDetails
    end

    if scoreDetails.roundNumber <= jokerInstance.value.maxRound then
        scoreDetails.score = scoreDetails.score + jokerInstance.value.bonus
        print("Applied joker '" .. jokerInstance.name .. "': +" .. jokerInstance.value.bonus .. " (Round " .. scoreDetails.roundNumber .. " <= " .. jokerInstance.value.maxRound .. ").")
    end
    return scoreDetails
end

function Joker.effectHandlers.conditional_multiplier_late_rounds(jokerInstance, scoreDetails)
    if not (jokerInstance.value and type(jokerInstance.value) == "table" and
            jokerInstance.value.minRound and type(jokerInstance.value.minRound) == "number" and
            jokerInstance.value.multiplier and type(jokerInstance.value.multiplier) == "number") then
        print("Warning: Joker '" .. jokerInstance.name .. "' has invalid 'value' table. Expected {minRound=MR, multiplier=M}.")
        return scoreDetails
    end

    if scoreDetails.roundNumber >= jokerInstance.value.minRound then
        scoreDetails.score = scoreDetails.score * jokerInstance.value.multiplier
        print("Applied joker '" .. jokerInstance.name .. "': score multiplied by " .. jokerInstance.value.multiplier .. " (Round " .. scoreDetails.roundNumber .. " >= " .. jokerInstance.value.minRound .. ").")
    end
    return scoreDetails
end

function Joker.effectHandlers.conditional_flat_bonus_joker_count_threshold(jokerInstance, scoreDetails)
    if not (jokerInstance.value and type(jokerInstance.value) == "table" and
            jokerInstance.value.threshold and type(jokerInstance.value.threshold) == "number" and
            jokerInstance.value.bonus and type(jokerInstance.value.bonus) == "number") then
        print("Warning: Joker '" .. jokerInstance.name .. "' has invalid 'value' table. Expected {threshold=T, bonus=B}.")
        return scoreDetails
    end

    if scoreDetails.playerJokerCount >= jokerInstance.value.threshold then
        scoreDetails.score = scoreDetails.score + jokerInstance.value.bonus
        print("Applied joker '" .. jokerInstance.name .. "': +" .. jokerInstance.value.bonus .. " (" .. scoreDetails.playerJokerCount .. " jokers >= threshold " .. jokerInstance.value.threshold .. ").")
    end
    return scoreDetails
end


return Joker
