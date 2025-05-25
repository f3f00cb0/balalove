-- Card class
Card = {}
Card.__index = Card

function Card:new(suit, rank)
    local instance = setmetatable({}, Card)
    instance.suit = suit
    instance.rank = rank
    instance.id = suit .. "_" .. rank -- Unique ID for the card
    -- Store parameters for drawCardPlaceholder (can be managed by hand/display logic later)
    instance.drawX = 0
    instance.drawY = 0
    return instance
end

function Card:__tostring()
    return self.rank .. " of " .. self.suit
end

return Card
