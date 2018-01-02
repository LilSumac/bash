--[[
    Test slot overlay element.
]]

local OVERLAY = {};

function OVERLAY:Init()
    self.ItemID = "";
    self.ItemObj = nil;
    self.ItemName = nil;
    self:Droppable("bash_ItemDrag");
end

function OVERLAY:SetItem(itemID)
    if bash.TableNet.IsRegistered(itemID) then
        self.ItemID = itemID;
        self.ItemObj = bash.TableNet.Get(itemID);
        self.ItemName = self.ItemObj:Get("ItemNum");
    end
end

function OVERLAY:ClearItem()
    self.ItemID = "";
    self.ItemObj = nil;
    -- TODO: Remove draggable item overlay.
end

function OVERLAY:Paint(w, h)
    if !self.ItemObj then return; end

    draw.SimpleText(tostring(self.ItemName), "ChatFont", w / 2, h / 2, color_black, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER);
end

vgui.Register("bash_TestSlotOverlay", OVERLAY, "DPanel");
