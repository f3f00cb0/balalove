-- Joker class
Joker = {}
Joker.__index = Joker

function Joker:new(name, description, effectType, value)
    local instance = setmetatable({}, Joker)
    instance.name = name or "Unnamed Joker"
    instance.description = description or "No description."
    instance.effectType = effectType or "none"
    instance.value = value or 0
    return instance
end

function Joker:__tostring()
    return self.name .. " (" .. self.effectType .. ": " .. tostring(self.value) .. ")"
end

return Joker
