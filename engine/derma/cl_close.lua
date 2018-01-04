--[[
    Close button element.
]]

local CLOSE = {};

function CLOSE:Init()
    self:SetText("");
end

function CLOSE:DoClick()
    if ispanel(self:GetParent()) then
        self:GetParent():Remove();
    end
end

function CLOSE:Paint(w, h)
    derma.SkinHook("Paint", "CloseButton", self, w, h);
end

vgui.Register("bash_Close", CLOSE, "DButton");
