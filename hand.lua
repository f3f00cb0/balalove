-- Hand class
Hand = {}
Hand.__index = Hand

function Hand:new()
    local instance = setmetatable({}, Hand)
    instance.cards = {} -- List to store card objects
    return instance
end

function Hand:addCard(card)
    if card then
        table.insert(self.cards, card)
    else
        print("Warning: Attempted to add a nil card to hand.")
    end
end

-- Removes a specific card object from the hand.
-- This relies on card objects having a unique identifier or comparing by reference.
-- For now, we'll assume we can find the card by reference or a unique ID.
-- If card objects are recreated, this might need adjustment (e.g., remove by index or unique ID).
function Hand:removeCard(cardToRemove)
    for i = #self.cards, 1, -1 do
        if self.cards[i] == cardToRemove then
            table.remove(self.cards, i)
            return true -- Card found and removed
        end
    end
    return false -- Card not found
end

-- Function to remove multiple cards based on their indices in the hand.
-- Indices should be 1-based and provided in descending order to avoid issues with shifting elements.
function Hand:removeCardsByIndices(indices)
    -- Sort indices in descending order to prevent issues with table.remove shifting elements
    table.sort(indices, function(a,b) return a > b end)

    local removedCards = {}
    for _, index in ipairs(indices) do
        if index >= 1 and index <= #self.cards then
            local card = table.remove(self.cards, index)
            table.insert(removedCards, 1, card) -- Insert at the beginning to maintain original order
        else
            print("Warning: Invalid index " .. index .. " for removing card from hand.")
        end
    end
    return removedCards
end


function Hand:getCards()
    return self.cards
end

function Hand:getCount()
    return #self.cards
end

-- Removes a card by its 1-based index in the hand's internal cards table.
-- Returns the removed card object, or nil if index is invalid.
function Hand:removeCardByIndex(indexToRemove)
    if type(indexToRemove) ~= "number" or indexToRemove < 1 or indexToRemove > #self.cards then
        print("Warning: Invalid index for removeCardByIndex: " .. tostring(indexToRemove))
        return nil
    end
    local card = table.remove(self.cards, indexToRemove)
    return card
end

return Hand
