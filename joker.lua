-- Joker class
-- Represents a Joker card with a name, description, effect, and potentially limited uses.
Joker = {}
Joker.__index = Joker

-- Helper function for deep copying a table (simple version, handles nested tables, not functions or userdata)
local function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

--- Constructor for a new Joker instance.
-- @param data (table) A table containing all necessary fields for the Joker.
-- Fields expected in data:
--   name (string)
--   description (string)
--   effectType (string)
--   value (any) - Can be a simple type or a table. If a table, it's deep-copied.
--   rarity (string, optional) - Defaults to "Common".
--   conceptualCost (number, optional) - Defaults to 0.
--   uses_total (number, optional) - Total uses. Defaults to -1 (infinite).
function Joker:new(data)
    local instance = setmetatable({}, Joker)
    
    instance.name = data.name or "Unnamed Joker"
    instance.id = data.name or "Unnamed Joker" -- Use name as the unique ID for ownership checks.
    instance.description = data.description or "No description."
    instance.effectType = data.effectType or "none" -- The type of effect this Joker has.
    
    -- Deep copy 'value' if it's a table to prevent shared state issues if effects modify it.
    if type(data.value) == "table" then
        instance.value = deepcopy(data.value)
    else
        instance.value = data.value -- Handles simple types (number, string, boolean) or nil.
    end
    
    instance.rarity = data.rarity or "Common" 
    instance.conceptualCost = data.conceptualCost or 0 

    instance.uses_total = data.uses_total or -1 
    instance.uses_remaining = instance.uses_total 
    
    instance.active = true 
    instance.marked_for_destruction = false 
    instance.apply_ante_reduction_now = false 

    return instance
end

--- Returns a string representation of the Joker, including its state.
function Joker:__tostring()
    local str = self.name
    if self.uses_total ~= -1 then
        str = str .. " (" .. self.uses_remaining .. "/" .. self.uses_total .. " uses)"
    end
    str = str .. " [" .. self.effectType .. ": " 
    if type(self.value) == "table" then
        str = str .. "{...}" -- Keep it concise for tables
    else
        str = str .. tostring(self.value)
    end
    str = str .. "]"
    if not self.active then str = str .. " (Inactive)" end
    if self.marked_for_destruction then str = str .. " (To Be Destroyed)" end
    return str
end

-- Table to store all Joker effect handler functions.
Joker.effectHandlers = {}

-- Helper table mapping card suits to their colors (Red/Black).
local internalSuitColors = { Hearts = "Red", Diamonds = "Red", Clubs = "Black", Spades = "Black" }

--- Simple score multiplier.
-- Value: (number) The multiplier value.
function Joker.effectHandlers.score_multiplier(jokerInstance, scoreDetails)
    if jokerInstance.value and type(jokerInstance.value) == "number" then
        scoreDetails.score = scoreDetails.score * jokerInstance.value
        print("Applied joker '" .. jokerInstance.name .. "': score multiplied by " .. jokerInstance.value)
    else
        print("Warning: Joker '" .. jokerInstance.name .. "' has invalid value for score_multiplier: " .. tostring(jokerInstance.value))
    end
    return scoreDetails
end

--- Simple flat score bonus.
-- Value: (number) The bonus amount.
function Joker.effectHandlers.flat_score_bonus(jokerInstance, scoreDetails)
    if jokerInstance.value and type(jokerInstance.value) == "number" then
        scoreDetails.score = scoreDetails.score + jokerInstance.value
        print("Applied joker '" .. jokerInstance.name .. "': flat score bonus of " .. jokerInstance.value)
    else
        print("Warning: Joker '" .. jokerInstance.name .. "' has invalid value for flat_score_bonus: " .. tostring(jokerInstance.value))
    end
    return scoreDetails
end

--- Hand Type Score Multiplier.
-- Value: (table) { handType = "HandTypeNameString", multiplier = number }
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

--- Hand Type Flat Bonus.
-- Value: (table) { handType = "HandTypeNameString", bonus = number }
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

--- Rank-Specific Flat Bonus Per Card.
-- Value: (table) { rank = "RankString", bonusPerCard = number }
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

--- Conditional Flat Bonus if a Specific Rank is Present.
-- Value: (table) { rank = "RankString", bonus = number }
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

--- Conditional Score Multiplier if All Cards are of a Specific Color.
-- Value: (table) { color = "Red" or "Black", multiplier = number }
function Joker.effectHandlers.conditional_score_multiplier_all_suits_are_color(jokerInstance, scoreDetails)
    if jokerInstance.value and type(jokerInstance.value) == "table" and
       jokerInstance.value.color and (jokerInstance.value.color == "Red" or jokerInstance.value.color == "Black") and
       jokerInstance.value.multiplier and type(jokerInstance.value.multiplier) == "number" then

        local allMatchColor = true
        if #scoreDetails.cards == 0 then 
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

local function getRankCountsForJoker(cards)
    local counts = {}
    for _, card in ipairs(cards) do
        counts[card.rank] = (counts[card.rank] or 0) + 1
    end
    return counts
end

local function isRankEven(rank)
    if HandEvaluator and HandEvaluator.rankValues and HandEvaluator.rankValues[rank] then
        return HandEvaluator.rankValues[rank] % 2 == 0
    end
    print("Warning: HandEvaluator.rankValues not accessible for rank parity check on rank: " .. tostring(rank))
    return false 
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
        local criticalRankValue = 0
        
        if jokerInstance.value.handType == "Pair" then 
            for rank, count in pairs(rankCounts) do
                if count == 2 then
                    if HandEvaluator and HandEvaluator.rankValues and HandEvaluator.rankValues[rank] then
                        criticalRankValue = HandEvaluator.rankValues[rank]
                    else 
                        print("Warning: HandEvaluator.rankValues not accessible for Pair Parity joker.")
                        return scoreDetails 
                    end
                    break 
                end
            end
            
            if criticalRankValue > 0 then
                if criticalRankValue % 2 == 0 then
                    scoreDetails.score = scoreDetails.score + jokerInstance.value.evenBonus
                    print("Applied joker '" .. jokerInstance.name .. "': +" .. jokerInstance.value.evenBonus .. " (rank " .. criticalRankValue .. " is even).")
                else
                    scoreDetails.score = scoreDetails.score + jokerInstance.value.oddBonus
                    print("Applied joker '" .. jokerInstance.name .. "': +" .. jokerInstance.value.oddBonus .. " (rank " .. criticalRankValue .. " is odd).")
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
            jokerInstance.value.property and jokerInstance.value.property == "isFaceCard" and 
            jokerInstance.value.threshold and type(jokerInstance.value.threshold) == "number" and
            jokerInstance.value.bonus and type(jokerInstance.value.bonus) == "number") then
        print("Warning: Joker '" .. jokerInstance.name .. "' has invalid or incomplete 'value' table. Expected {property='isFaceCard', threshold=T, bonus=B}.")
        return scoreDetails
    end

    local propertyCount = 0
    if jokerInstance.value.property == "isFaceCard" then
        local faceRanks = { ["J"] = true, ["Q"] = true, ["K"] = true }
        for _, card in ipairs(scoreDetails.cards) do
            if faceRanks[card.rank] then
                propertyCount = propertyCount + 1
            end
        end
    end

    if propertyCount >= jokerInstance.value.threshold then
        scoreDetails.score = scoreDetails.score + jokerInstance.value.bonus
        print("Applied joker '" .. jokerInstance.name .. "': +" .. jokerInstance.value.bonus .. " (" .. propertyCount .. " " .. jokerInstance.value.property .. "s >= threshold " .. jokerInstance.value.threshold .. ").")
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

    if #scoreDetails.cards < 2 then return scoreDetails end 

    local tempCards = {}
    for _, c in ipairs(scoreDetails.cards) do table.insert(tempCards, {rank = c.rank, suit = c.suit}) end 

    table.sort(tempCards, function(a,b)
        local valA = (HandEvaluator and HandEvaluator.rankValues and HandEvaluator.rankValues[a.rank]) or tonumber(a.rank) or 0
        local valB = (HandEvaluator and HandEvaluator.rankValues and HandEvaluator.rankValues[b.rank]) or tonumber(b.rank) or 0
        return valA < valB
    end)
    
    local isConsecutive = true
    for i = 1, #tempCards - 1 do
        local valCurrent = (HandEvaluator and HandEvaluator.rankValues and HandEvaluator.rankValues[tempCards[i].rank])
        local valNext = (HandEvaluator and HandEvaluator.rankValues and HandEvaluator.rankValues[tempCards[i+1].rank])
        if not valCurrent or not valNext or (valNext ~= valCurrent + 1) then
            isConsecutive = false
            break
        end
    end
    
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
            sum = sum + 11 
        elseif card.rank == "K" or card.rank == "Q" or card.rank == "J" then
            sum = sum + 10
        else
            sum = sum + (tonumber(card.rank) or 0)
        end
    end

    while sum > jokerInstance.value.targetSum and aceCount > 0 do
        sum = sum - 10 
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
    if bonus ~= 0 then 
        print("Applied joker '" .. jokerInstance.name .. "': +" .. bonus .. " (Round " .. (scoreDetails.roundNumber or 0) .. " * " .. jokerInstance.value.multiplier .. ").")
    end
    return scoreDetails
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
            matches = not isRankEven(card.rank) 
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

    local otherJokerCount = math.max(0, scoreDetails.playerJokerCount - 1) 
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

-- Set E Joker Effect Handlers

--- 50/50 Chance Score Multiplier or Score Set to Low Value (Limited Uses).
-- Effect: 50% chance to multiply score, 50% chance score becomes `failScore`. Decrements uses.
-- Value: (table) { multiplier = number, failScore = number }
-- Instance Fields: `uses_remaining`, `uses_total`, `marked_for_destruction`.
function Joker.effectHandlers.final_score_gambler(jokerInstance, scoreDetails)
    if not (jokerInstance.value and type(jokerInstance.value) == "table" and
            jokerInstance.value.multiplier and type(jokerInstance.value.multiplier) == "number" and
            jokerInstance.value.failScore and type(jokerInstance.value.failScore) == "number") then
        print("Warning: Joker '" .. jokerInstance.name .. "' has invalid 'value' table. Expected {multiplier=M, failScore=FS}.")
        return scoreDetails
    end

    if math.random() < 0.5 then
        scoreDetails.score = scoreDetails.score * jokerInstance.value.multiplier
        print("Applied joker '" .. jokerInstance.name .. "': Lucky! Score multiplied by " .. jokerInstance.value.multiplier)
    else
        scoreDetails.score = jokerInstance.value.failScore
        print("Applied joker '" .. jokerInstance.name .. "': Unlucky! Score set to " .. jokerInstance.value.failScore)
    end
    
    if jokerInstance.uses_total ~= -1 then
        jokerInstance.uses_remaining = jokerInstance.uses_remaining - 1
        if jokerInstance.uses_remaining <= 0 then
            jokerInstance.marked_for_destruction = true
            print("Joker '" .. jokerInstance.name .. "' used up and marked for destruction.")
        end
    end
    return scoreDetails
end

--- Conditional Score Minimum and Self-Destruct.
-- Effect: If current score is <= 0, sets score to a minimum value. Joker is then destroyed.
-- Value: (table) { minimumScore = number }
-- Instance Fields: `marked_for_destruction`.
function Joker.effectHandlers.conditional_score_minimum_and_destroy(jokerInstance, scoreDetails)
    if not (jokerInstance.value and type(jokerInstance.value) == "table" and
            jokerInstance.value.minimumScore and type(jokerInstance.value.minimumScore) == "number") then
        print("Warning: Joker '" .. jokerInstance.name .. "' has invalid 'value' table. Expected {minimumScore=MS}.")
        return scoreDetails
    end

    if scoreDetails.score <= 0 then
        scoreDetails.score = jokerInstance.value.minimumScore
        print("Applied joker '" .. jokerInstance.name .. "': Score was <= 0, set to minimum " .. jokerInstance.value.minimumScore)
    end
    jokerInstance.marked_for_destruction = true 
    print("Joker '" .. jokerInstance.name .. "' used and marked for destruction.")
    return scoreDetails
end

--- Specific Suit Flush Multiplier.
-- Effect: Multiplies score if the hand is a Flush and all cards are of a specific suit.
-- Value: (table) { suit = "TargetSuitString", multiplier = number }
function Joker.effectHandlers.specific_suit_flush_multiplier(jokerInstance, scoreDetails)
    if not (jokerInstance.value and type(jokerInstance.value) == "table" and
            jokerInstance.value.suit and type(jokerInstance.value.suit) == "string" and
            jokerInstance.value.multiplier and type(jokerInstance.value.multiplier) == "number") then
        print("Warning: Joker '" .. jokerInstance.name .. "' has invalid 'value' table. Expected {suit='TargetSuit', multiplier=M}.")
        return scoreDetails
    end

    if scoreDetails.handType == "Flush" then
        local allMatchSuit = true
        if #scoreDetails.cards == 0 then allMatchSuit = false end

        for _, card in ipairs(scoreDetails.cards) do
            if card.suit ~= jokerInstance.value.suit then
                allMatchSuit = false
                break
            end
        end
        if allMatchSuit then
            scoreDetails.score = scoreDetails.score * jokerInstance.value.multiplier
            print("Applied joker '" .. jokerInstance.name .. "': score multiplied by " .. jokerInstance.value.multiplier .. " for " .. jokerInstance.value.suit .. " Flush.")
        end
    end
    return scoreDetails
end

--- Conditional Multiplier if Joker Count is Exactly a Specific Number.
-- Effect: Multiplies score if the player's total number of Jokers is exactly a specific count.
-- Value: (table) { count = number, multiplier = number }
-- Dependencies: `scoreDetails.playerJokerCount`.
function Joker.effectHandlers.conditional_multiplier_joker_count_is_exactly(jokerInstance, scoreDetails)
    if not (jokerInstance.value and type(jokerInstance.value) == "table" and
            jokerInstance.value.count and type(jokerInstance.value.count) == "number" and
            jokerInstance.value.multiplier and type(jokerInstance.value.multiplier) == "number") then
        print("Warning: Joker '" .. jokerInstance.name .. "' has invalid 'value' table. Expected {count=C, multiplier=M}.")
        return scoreDetails
    end

    if scoreDetails.playerJokerCount == jokerInstance.value.count then
        scoreDetails.score = scoreDetails.score * jokerInstance.value.multiplier
        print("Applied joker '" .. jokerInstance.name .. "': score multiplied by " .. jokerInstance.value.multiplier .. " (Joker count is exactly " .. scoreDetails.playerJokerCount .. ").")
    end
    return scoreDetails
end

--- Conditional Flat Bonus if Played Hand has an Exact Number of Cards.
-- Effect: Adds a flat bonus if the number of cards in the played hand is exactly a specific count.
-- Value: (table) { cardCount = number, bonus = number }
function Joker.effectHandlers.conditional_flat_bonus_if_card_count_is(jokerInstance, scoreDetails)
    if not (jokerInstance.value and type(jokerInstance.value) == "table" and
            jokerInstance.value.cardCount and type(jokerInstance.value.cardCount) == "number" and
            jokerInstance.value.bonus and type(jokerInstance.value.bonus) == "number") then
        print("Warning: Joker '" .. jokerInstance.name .. "' has invalid 'value' table. Expected {cardCount=CC, bonus=B}.")
        return scoreDetails
    end

    if #scoreDetails.cards == jokerInstance.value.cardCount then
        scoreDetails.score = scoreDetails.score + jokerInstance.value.bonus
        print("Applied joker '" .. jokerInstance.name .. "': +" .. jokerInstance.value.bonus .. " (#cards played is " .. #scoreDetails.cards .. ").")
    end
    return scoreDetails
end

--- Bonus if No Shop Purchase in the Previous Round.
-- Effect: Adds a flat bonus if no items were bought from the shop in the round preceding the current one.
-- Value: (table) { bonus = number }
-- Dependencies: `scoreDetails.boughtInShopLastRound`.
function Joker.effectHandlers.bonus_if_no_shop_purchase_previous_round(jokerInstance, scoreDetails)
    if not (jokerInstance.value and type(jokerInstance.value) == "table" and
            jokerInstance.value.bonus and type(jokerInstance.value.bonus) == "number") then
        print("Warning: Joker '" .. jokerInstance.name .. "' has invalid 'value' table. Expected {bonus=B}.")
        return scoreDetails
    end

    if scoreDetails.boughtInShopLastRound == false then
        scoreDetails.score = scoreDetails.score + jokerInstance.value.bonus
        print("Applied joker '" .. jokerInstance.name .. "': +" .. jokerInstance.value.bonus .. " (no shop purchase last round).")
    end
    return scoreDetails
end

--- One-Time Ante Reducer and Self-Destruct.
-- Effect: Signals `main.lua` to reduce the next ante by a percentage. Deactivates and marks for destruction.
-- Value: (table) { reductionPercent = number (0.0-1.0) }
-- Instance Fields: `apply_ante_reduction_now`, `active`, `marked_for_destruction`.
function Joker.effectHandlers.ante_reducer_one_time_and_destroy(jokerInstance, scoreDetails)
    if not (jokerInstance.value and type(jokerInstance.value) == "table" and
            jokerInstance.value.reductionPercent and type(jokerInstance.value.reductionPercent) == "number") then
        print("Warning: Joker '" .. jokerInstance.name .. "' has invalid 'value' table. Expected {reductionPercent=RP (0.0-1.0)}.")
        return scoreDetails
    end

    if jokerInstance.active then 
        jokerInstance.apply_ante_reduction_now = true 
        jokerInstance.active = false 
        jokerInstance.marked_for_destruction = true 
        print("Joker '" .. jokerInstance.name .. "' activated: Ante reduction pending. Joker marked for destruction.")
    end
    return scoreDetails
end

--- Conditional Flat Bonus if Max Hand Size Meets a Threshold.
-- Effect: Adds a flat bonus if the player's maximum hand size is at or above a minimum size.
-- Value: (table) { minSize = number, bonus = number }
-- Dependencies: `scoreDetails.maxHandSize`.
function Joker.effectHandlers.conditional_flat_bonus_if_max_hand_size_is(jokerInstance, scoreDetails)
    if not (jokerInstance.value and type(jokerInstance.value) == "table" and
            jokerInstance.value.minSize and type(jokerInstance.value.minSize) == "number" and
            jokerInstance.value.bonus and type(jokerInstance.value.bonus) == "number") then
        print("Warning: Joker '" .. jokerInstance.name .. "' has invalid 'value' table. Expected {minSize=MS, bonus=B}.")
        return scoreDetails
    end

    if scoreDetails.maxHandSize >= jokerInstance.value.minSize then
        scoreDetails.score = scoreDetails.score + jokerInstance.value.bonus
        print("Applied joker '" .. jokerInstance.name .. "': +" .. jokerInstance.value.bonus .. " (Max hand size " .. scoreDetails.maxHandSize .. " >= " .. jokerInstance.value.minSize .. ").")
    end
    return scoreDetails
end

--- Score Multiplier with Limited Uses, Then Self-Destruct.
-- Effect: Multiplies score. Decrements uses. Marks for destruction if uses run out.
-- Value: (table) { multiplier = number }
-- Instance Fields: `uses_remaining`, `uses_total`, `marked_for_destruction`.
function Joker.effectHandlers.multiplier_and_destroy_after_uses(jokerInstance, scoreDetails)
    if not (jokerInstance.value and type(jokerInstance.value) == "table" and
            jokerInstance.value.multiplier and type(jokerInstance.value.multiplier) == "number") then
        print("Warning: Joker '" .. jokerInstance.name .. "' has invalid 'value' table. Expected {multiplier=M}.")
        return scoreDetails
    end

    if jokerInstance.uses_total == -1 or jokerInstance.uses_remaining > 0 then
        scoreDetails.score = scoreDetails.score * jokerInstance.value.multiplier
        print("Applied joker '" .. jokerInstance.name .. "': score multiplied by " .. jokerInstance.value.multiplier)
        
        if jokerInstance.uses_total ~= -1 then
            jokerInstance.uses_remaining = jokerInstance.uses_remaining - 1
            print("Joker '" .. jokerInstance.name .. "' uses remaining: " .. jokerInstance.uses_remaining .. "/" .. jokerInstance.uses_total)
            if jokerInstance.uses_remaining <= 0 then
                jokerInstance.marked_for_destruction = true
                print("Joker '" .. jokerInstance.name .. "' used up and marked for destruction.")
            end
        end
    else
        print("Joker '" .. jokerInstance.name .. "' has no uses remaining.")
    end
    return scoreDetails
end


return Joker

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of joker.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua]

[end of main.lua
