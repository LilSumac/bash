--[[
    BClose button.
]]

--
-- Local storage.
--

-- Micro-optimizations.

-- Button object.
local BUTTON = {};

--
-- DButton functions.
--

function BUTTON:Init()

end

function BUTTON:Paint()
    return true;
end

--
-- BClose functions.
--

function BUTTON:GetTarget()
    return self.Target;
end

function BUTTON:SetTarget(targ)
    self.Target = targ;
end
