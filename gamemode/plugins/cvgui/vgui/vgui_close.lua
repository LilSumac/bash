--[[
    bash.Close element.
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
    self:SetText("");
    self.Scheme = SCHEME_BASH;
    self.Target = self:GetParent();
end

function BUTTON:Paint(w, h)
    local bgCol, textCol;
    if self:IsHovered() then
        bgCol = self.Scheme["ButtonHover"];
        textCol = self.Scheme["ButtonClose"];
    else
        bgCol = self.Scheme["ButtonPassive"];
        textCol = self.Scheme["ButtonTextPassive"];
    end

    draw.SimpleText("r", "marlett", w / 2, h / 2, textCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER);
    return true;
end

function BUTTON:DoClick()
    if ispanel(self.Target) then
        self.Target:Close();
    end
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

vgui.Register("bash.Close", BUTTON, "DButton");
