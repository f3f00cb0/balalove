-- Import Card class
local Card = require("card")

-- Deck class
Deck = {}
Deck.__index = Deck

function Deck:new()
    local instance = setmetatable({}, Deck)
    instance.cards = {}
    local suits = {"Hearts", "Diamonds", "Clubs", "Spades"}
    local ranks = {"2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"}

    for _, suit in ipairs(suits) do
        for _, rank in ipairs(ranks) do
            table.insert(instance.cards, Card:new(suit, rank))
        end
    end
    return instance
end

function Deck:shuffle()
    -- Fisher-Yates shuffle
    for i = #self.cards, 2, -1 do
        local j = math.random(i)
        self.cards[i], self.cards[j] = self.cards[j], self.cards[i]
    end
end

function Deck:deal()
    if #self.cards == 0 then
        return nil -- or handle empty deck error
    end
    return table.remove(self.cards)
end

function Deck:reshuffle()
    print("Reshuffling the deck.")
    self.cards = {} -- Clear existing cards
    local suits = {"Hearts", "Diamonds", "Clubs", "Spades"}
    local ranks = {"2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"}

    for _, suit in ipairs(suits) do
        for _, rank in ipairs(ranks) do
            table.insert(self.cards, Card:new(suit, rank))
        end
    end
    self:shuffle() -- Reuse the existing shuffle method
end

return Deck
