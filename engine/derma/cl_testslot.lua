--[[
    Test slot element.
]]

local SLOT = {};

function SLOT:Init()
    self.ItemID = "";
    self.ItemObj = nil;
    self.GridX = nil;
    self.GridY = nil;

    self:Receiver("bash_ItemDrag", self.ReceiveItem, {"Someshit"});
    self:Droppable("bash_ItemDrag");
end

function SLOT:SetGridPos(x, y)
    self.GridX = x;
    self.GridY = y;
end

function SLOT:SetItem(itemID)
    if bash.TableNet.IsRegistered(itemID) then
        self.ItemID = itemID;
        self.ItemObj = bash.TableNet.Get(itemID);
        self.ItemName = self.ItemObj:Get("ItemNum");
        --self:CreateOverlay();
    end
end

function SLOT:ClearItem()
    self.ItemID = "";
    self.ItemObj = nil;
    self.ItemName = nil;
    --self:RemoveOverlay();
end

--[[
function SLOT:CreateOverlay()
    if !self.ItemID then return; end

    self:RemoveOverlay();
    self.ItemOverlay = vgui.Create("bash_TestSlotOverlay", self);
    self.ItemOverlay:Dock(FILL);
    self.ItemOverlay:SetItem(self.ItemID);
end
]]

--[[
function SLOT:RemoveOverlay()
    if self.ItemOverlay then
        self.ItemOverlay:Remove();
        self.ItemOverlay = nil;
    end
end
]]

function SLOT:ReceiveItem(panels, dropped, index, x, y)
    if !dropped then return; end

    local dropItem = panels[1];
    if !dropItem then return; end
    PrintTable(panels);
    MsgN(dropped);
    MsgN(index);
    MsgN(x);
    MsgN(y);

    local moveReq = vnet.CreatePacket("bash_Net_ItemMoveRequest");
    moveReq:String(dropItem.ItemID);
    moveReq:Table({X = self.GridX, Y = self.GridY}); -- NewPos
    moveReq:AddServer();
    moveReq:Send();
end

function SLOT:Paint(w, h)
    surface.SetDrawColor(color_white);
    surface.DrawOutlinedRect(0, 0, w, h);

    if self.ItemName then
        draw.SimpleText(self.ItemName, "ChatFont", w / 2, h / 2, color_black, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER);
    end
end

vgui.Register("bash_TestSlot", SLOT, "DPanel");
