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
    Hearts = "♥",   -- U+2665
    Diamonds = "♦", -- U+2666
    Clubs = "♣",    -- U+2663
    Spades = "♠"    -- U+2660
}

-- Store the default font and a potentially larger one for symbols
local defaultFont = nil
local symbolFont = nil

-- Function to draw a card placeholder
function drawCardPlaceholder(x, y, suit, rank)
    local cardBackgroundColor = {0.95, 0.95, 0.94} -- Very light grey / off-white
    local borderColor = {0.3, 0.3, 0.3} -- Darker grey for border
    local innerBorderColor = {0.7, 0.7, 0.7} -- Lighter grey for inner accent

    -- Draw card background
    love.graphics.setColor(cardBackgroundColor)
    love.graphics.rectangle("fill", x, y, cardWidth, cardHeight)

    -- Draw outer border
    love.graphics.setColor(borderColor)
    love.graphics.setLineWidth(2) -- Thicker outer border
    love.graphics.rectangle("line", x, y, cardWidth, cardHeight)
    
    -- Draw a subtle inner border line for accent
    love.graphics.setColor(innerBorderColor)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x + 3, y + 3, cardWidth - 6, cardHeight - 6)


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

    -- Font management
    if not defaultFont then
        defaultFont = love.graphics.getFont() -- Get the default font set in main.lua or LÖVE's default
        -- Attempt to create a slightly larger font for symbols if needed, or a specific one known to support them.
        -- For now, we'll try using the defaultFont for symbols too, but adjust size if possible or use a new one.
        -- Let's try a common system font first. If not available, LÖVE will use its default.
        -- symbolFont = love.graphics.newFont("DejaVu Sans", 20) -- Example, might not be available
        -- If the default font (often Vera Sans) handles it, this might not be strictly necessary.
        -- The font size for rank and suit will be driven by the font set before calling this function (from main.lua).
        -- We can override for symbols if needed.
    end
    
    local currentFont = love.graphics.getFont()
    local rankFontSize = currentFont:getHeight() -- Base size from the font object
    
    -- For suit symbols, we might want them to be a bit larger or use a specific symbol font if available
    -- For now, we'll use the same font but can adjust size if LÖVE supported dynamic size printf.
    -- Since it doesn't directly, we'd typically need another font object for a different size.
    -- Let's keep it simple and use the same font, focusing on positioning.
    -- We can make the suit symbol appear slightly larger by ensuring it has enough space.

    local textPadding = 4 -- Reduced padding a bit for more space
    local cornerOffset = 2 -- How far from the border the text starts

    -- Top-Left Text (Rank and Suit)
    love.graphics.printf(rankText, x + textPadding + cornerOffset, y + textPadding, cardWidth - 2 * (textPadding+cornerOffset), "left")
    love.graphics.printf(suitSymbol, x + textPadding + cornerOffset, y + textPadding + rankFontSize -2 , cardWidth - 2 * (textPadding+cornerOffset), "left") -- Suit below rank

    -- Bottom-Right Text (Rank and Suit) - requires more care for alignment
    local rankTextWidth = currentFont:getWidth(rankText)
    local suitSymbolWidth = currentFont:getWidth(suitSymbol)

    love.graphics.printf(rankText, x + cardWidth - textPadding - cornerOffset - rankTextWidth, y + cardHeight - textPadding - rankFontSize - (rankFontSize-2) , cardWidth, "left")
    love.graphics.printf(suitSymbol, x + cardWidth - textPadding - cornerOffset - suitSymbolWidth, y + cardHeight - textPadding - (rankFontSize-2) , cardWidth, "left")
    
    -- Reset line width and color
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1) -- Default to white for next draw operations
end
