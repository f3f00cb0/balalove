-- Card dimensions
cardWidth = 70
cardHeight = 100

-- Suit colors
suitColors = {
    Hearts = {1, 0, 0},   -- Red
    Diamonds = {1, 0, 0}, -- Red
    Clubs = {0, 0, 0},     -- Black
    Spades = {0, 0, 0}     -- Black
}

-- Suit symbols for drawing
suitSymbols = {
    Hearts = "♥", -- U+2665
    Diamonds = "♦", -- U+2666
    Clubs = "♣", -- U+2663
    Spades = "♠"  -- U+2660
}

-- Function to draw a card placeholder
function drawCardPlaceholder(x, y, suit, rank)
    -- Draw card background (white)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("fill", x, y, cardWidth, cardHeight, 5, 5) -- Added rounding

    -- Draw card border (black)
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("line", x, y, cardWidth, cardHeight, 5, 5) -- Added rounding

    -- Set text color based on suit
    local color = suitColors[suit]
    if not color then
        color = {0,0,0} -- Default to black if suit is unknown
        print("Warning: Unknown suit '" .. tostring(suit) .. "', defaulting to black.")
    end
    love.graphics.setColor(color)

    -- Prepare text
    local suitSymbol = suitSymbols[suit] or "?"
    local rankText = tostring(rank)
    local cardTextTopLeft = rankText .. "\n" .. suitSymbol
    local cardTextBottomRight = suitSymbol .. "\n" .. rankText


    -- Draw rank and suit text
    local font = love.graphics.getFont() -- Use current font, or set a specific one
    local textPadding = 5

    -- Top-left text
    love.graphics.printf(cardTextTopLeft, x + textPadding, y + textPadding, cardWidth - 2 * textPadding, "left")

    -- Bottom-right text (rotated for effect, optional)
    -- For simplicity, we'll just draw it normally at the bottom right
    -- To align text to bottom, we need to calculate its height or use a fixed offset
    local textHeight = font:getHeight() * 2 -- Approximate height for two lines
    love.graphics.printf(cardTextBottomRight, x + textPadding, y + cardHeight - textPadding - textHeight, cardWidth - 2*textPadding, "right")

    -- Reset color to white (or previous color)
    love.graphics.setColor(1, 1, 1)
end
