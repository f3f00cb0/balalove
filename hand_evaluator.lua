-- hand_evaluator.lua

local HandEvaluator = {}

-- Numerical values for card ranks
-- Ace can be 14 (high) or 1 (low for A-5 straights)
HandEvaluator.rankValues = {
    ["2"] = 2, ["3"] = 3, ["4"] = 4, ["5"] = 5, ["6"] = 6, ["7"] = 7, ["8"] = 8, ["9"] = 9, ["10"] = 10,
    ["J"] = 11, ["Q"] = 12, ["K"] = 13, ["A"] = 14
}

-- Function to sort cards by rank (ascending)
-- Takes a list of card objects
function HandEvaluator.sortCardsByRank(cards)
    table.sort(cards, function(a, b)
        return HandEvaluator.rankValues[a.rank] < HandEvaluator.rankValues[b.rank]
    end)
    return cards -- Return sorted table (table is sorted in-place)
end

-- Helper function to get rank counts from a list of cards
function HandEvaluator.getRankCounts(cards)
    local counts = {}
    for _, card in ipairs(cards) do
        counts[card.rank] = (counts[card.rank] or 0) + 1
    end
    return counts
end

-- Helper function to get suit counts from a list of cards
function HandEvaluator.getSuitCounts(cards)
    local counts = {}
    for _, card in ipairs(cards) do
        counts[card.suit] = (counts[card.suit] or 0) + 1
    end
    return counts
end


-- Detection functions (will be filled in next)

HandEvaluator.isPair = function(cards)
    if #cards ~= 5 then return false end -- Assuming 5 card evaluation for now
    local rankCounts = HandEvaluator.getRankCounts(cards)
    local pairs = 0
    for rank, count in pairs(rankCounts) do
        if count == 2 then
            pairs = pairs + 1
        end
    end
    return pairs == 1
end

HandEvaluator.isTwoPair = function(cards)
    if #cards ~= 5 then return false end
    local rankCounts = HandEvaluator.getRankCounts(cards)
    local pairs = 0
    for rank, count in pairs(rankCounts) do
        if count == 2 then
            pairs = pairs + 1
        end
    end
    return pairs == 2
end

HandEvaluator.isThreeOfAKind = function(cards)
    if #cards ~= 5 then return false end
    local rankCounts = HandEvaluator.getRankCounts(cards)
    for rank, count in pairs(rankCounts) do
        if count == 3 then
            return true
        end
    end
    return false
end

HandEvaluator.isStraight = function(cards)
    if #cards ~= 5 then return false end
    
    -- Create a copy of cards to sort, to not modify the original hand object directly
    local sortedCards = {}
    for _, c in ipairs(cards) do table.insert(sortedCards, c) end
    HandEvaluator.sortCardsByRank(sortedCards) -- Sorts 2-A (A=14)

    -- Check for Ace-low straight (A, 2, 3, 4, 5)
    -- After sorting, this will appear as 2, 3, 4, 5, A
    if sortedCards[1].rank == "2" and
       sortedCards[2].rank == "3" and
       sortedCards[3].rank == "4" and
       sortedCards[4].rank == "5" and
       sortedCards[5].rank == "A" then
        return true
    end

    -- Check for standard straight (including 10, J, Q, K, A)
    local isNormalStraight = true
    for i = 1, #sortedCards - 1 do
        if HandEvaluator.rankValues[sortedCards[i+1].rank] ~= HandEvaluator.rankValues[sortedCards[i].rank] + 1 then
            isNormalStraight = false
            break
        end
    end
    
    return isNormalStraight
end


HandEvaluator.isFlush = function(cards)
    if #cards ~= 5 then return false end
    local firstSuit = cards[1].suit
    for i = 2, #cards do
        if cards[i].suit ~= firstSuit then
            return false
        end
    end
    return true
end

HandEvaluator.isFullHouse = function(cards)
    if #cards ~= 5 then return false end
    local rankCounts = HandEvaluator.getRankCounts(cards)
    local hasThree = false
    local hasPair = false
    for rank, count in pairs(rankCounts) do
        if count == 3 then
            hasThree = true
        elseif count == 2 then
            hasPair = true
        end
    end
    return hasThree and hasPair
end

HandEvaluator.isFourOfAKind = function(cards)
    if #cards ~= 5 then return false end
    local rankCounts = HandEvaluator.getRankCounts(cards)
    for rank, count in pairs(rankCounts) do
        if count == 4 then
            return true
        end
    end
    return false
end

HandEvaluator.isStraightFlush = function(cards)
    if #cards ~= 5 then return false end
    return HandEvaluator.isStraight(cards) and HandEvaluator.isFlush(cards)
end

HandEvaluator.isRoyalFlush = function(cards)
    if #cards ~= 5 then return false end
    if not HandEvaluator.isFlush(cards) then return false end -- Must be a flush

    local sortedCards = HandEvaluator.sortCardsByRank(cards)
    -- Check for A, K, Q, J, 10 sequence (Ace high)
    return HandEvaluator.rankValues[sortedCards[1].rank] == 10 and
           HandEvaluator.rankValues[sortedCards[2].rank] == 11 and
           HandEvaluator.rankValues[sortedCards[3].rank] == 12 and
           HandEvaluator.rankValues[sortedCards[4].rank] == 13 and
           HandEvaluator.rankValues[sortedCards[5].rank] == 14 -- Ace
end

-- Primary evaluation function
HandEvaluator.evaluateHand = function(cards)
    if #cards == 0 then return "No cards" end -- Handle empty hand case
    if #cards < 5 then -- Balatro allows scoring smaller hands, this is a placeholder
        -- For now, just check for simple cases if not 5 cards.
        -- This part can be expanded significantly for Balatro scoring.
        if #cards == 1 then return "HighCard" end -- Or specific single card score
        if #cards == 2 and HandEvaluator.isPair(cards) then return "Pair" end -- isPair needs to be adapted for 2 cards
        -- For now, we are focusing on 5-card evaluation as per instructions
        -- So, if not 5 cards, we'll just say "Requires 5 cards for standard evaluation"
        return "Requires 5 cards for standard poker evaluation"
    end
    
    -- Ensure cards are sorted for some checks, though individual functions might re-sort
    -- It's good practice to work with a sorted copy if functions modify order,
    -- but our sortCardsByRank sorts in-place. Let's make copies for evaluation.
    local cardsCopy = {}
    for _, c in ipairs(cards) do table.insert(cardsCopy, c) end

    if HandEvaluator.isRoyalFlush(cardsCopy) then return "RoyalFlush" end
    if HandEvaluator.isStraightFlush(cardsCopy) then return "StraightFlush" end
    if HandEvaluator.isFourOfAKind(cardsCopy) then return "FourOfAKind" end
    if HandEvaluator.isFullHouse(cardsCopy) then return "FullHouse" end
    if HandEvaluator.isFlush(cardsCopy) then return "Flush" end
    if HandEvaluator.isStraight(cardsCopy) then return "Straight" end
    if HandEvaluator.isThreeOfAKind(cardsCopy) then return "ThreeOfAKind" end
    if HandEvaluator.isTwoPair(cardsCopy) then return "TwoPair" end
    if HandEvaluator.isPair(cardsCopy) then return "Pair" end
    
    return "HighCard" -- Default if no other hand is found
end

-- Scoring system
HandEvaluator.handBaseScores = {
    HighCard = 5,
    Pair = 10,
    TwoPair = 20,
    ThreeOfAKind = 30,
    Straight = 40,
    Flush = 50,
    FullHouse = 80,
    FourOfAKind = 100,
    StraightFlush = 200,
    RoyalFlush = 500,
    ["Requires 5 cards for standard poker evaluation"] = 0, -- Handle non-standard hand size
    ["No cards"] = 0 -- Handle empty hand
}

HandEvaluator.calculateScore = function(playedCards, activeJokers)
    if not playedCards or #playedCards == 0 then
        return 0, "No cards"
    end

    local handType = HandEvaluator.evaluateHand(playedCards)
    local currentScore = HandEvaluator.handBaseScores[handType]

    if not currentScore then
        print("Warning: No base score defined for hand type: " .. handType)
        currentScore = 0 -- Default to 0 if hand type has no score defined
    end

    local activatedJokerNames = {} -- Collect names of activated jokers

    -- Apply Joker effects
    if activeJokers and #activeJokers > 0 then
        for _, joker in ipairs(activeJokers) do
            if joker.effectType == "score_multiplier" then
                if joker.value and type(joker.value) == "number" then
                    currentScore = currentScore * joker.value
                    print("Applied joker '" .. joker.name .. "': score multiplied by " .. joker.value)
                    table.insert(activatedJokerNames, joker.name .. " (x" .. joker.value .. ")")
                else
                    print("Warning: Joker '" .. joker.name .. "' has invalid value for score_multiplier: " .. tostring(joker.value))
                end
            -- Example for flat_bonus, if it were implemented and should show feedback
            -- elseif joker.effectType == "flat_bonus" then
            --     if joker.value and type(joker.value) == "number" then
            --         currentScore = currentScore + joker.value
            --         print("Applied joker '" .. joker.name .. "': flat bonus of " .. joker.value)
            --         table.insert(activatedJokerNames, joker.name .. " (+" .. joker.value .. ")")
            --     else
            --         print("Warning: Joker '" .. joker.name .. "' has invalid value for flat_bonus: " .. tostring(joker.value))
            --     end
            elseif joker.effectType == "conditional_bonus_suit" then
                if joker.value and type(joker.value) == "table" and
                   joker.value.suit and joker.value.count and joker.value.bonus then
                    local suitCounts = HandEvaluator.getSuitCounts(playedCards)
                    if (suitCounts[joker.value.suit] or 0) >= joker.value.count then
                        currentScore = currentScore + joker.value.bonus
                        print("Applied joker '" .. joker.name .. "': +" .. joker.value.bonus .. " for " .. joker.value.count .. " " .. joker.value.suit)
                        table.insert(activatedJokerNames, joker.name .. " (+" .. joker.value.bonus .. ")")
                    end
                else
                    print("Warning: Joker '" .. joker.name .. "' has invalid value for conditional_bonus_suit: " .. tostring(joker.value))
                end
            elseif joker.effectType == "conditional_mult_highcard_ace" then
                if handType == "HighCard" then
                    local hasAce = false
                    for _, card in ipairs(playedCards) do
                        if card.rank == "A" then
                            hasAce = true
                            break
                        end
                    end
                    if hasAce then
                        if joker.value and type(joker.value) == "number" then
                            currentScore = currentScore * joker.value
                            print("Applied joker '" .. joker.name .. "': score multiplied by " .. joker.value .. " for Ace HighCard")
                            table.insert(activatedJokerNames, joker.name .. " (x" .. joker.value .. ")")
                        else
                             print("Warning: Joker '" .. joker.name .. "' has invalid value for conditional_mult_highcard_ace: " .. tostring(joker.value))
                        end
                    end
                end
            elseif joker.effectType == "bonus_per_card" then
                if joker.value and type(joker.value) == "number" then
                    local bonus = joker.value * #playedCards
                    currentScore = currentScore + bonus
                    print("Applied joker '" .. joker.name .. "': +" .. bonus .. " for " .. #playedCards .. " cards")
                    table.insert(activatedJokerNames, joker.name .. " (+" .. bonus .. ")")
                else
                    print("Warning: Joker '" .. joker.name .. "' has invalid value for bonus_per_card: " .. tostring(joker.value))
                end
            end
            -- Other effect types like 'conditional_multiplier' could be handled here (e.g. Card Sharp Joker, not part of this subtask's new additions)
            -- For example, Card Sharp Joker:
            -- elseif joker.effectType == "conditional_multiplier" then
            --    if #playedCards <= 3 then -- Example condition
            --        currentScore = currentScore * joker.value
            --        table.insert(activatedJokerNames, joker.name .. " (x" .. joker.value .. " for small hand)")
            --    end

        end
    end

    return currentScore, handType, activatedJokerNames
end

return HandEvaluator
