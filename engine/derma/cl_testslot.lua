--[[
    Test slot element.
]]

local SLOT = {};

function SLOT:Init()
    self.InvID = "";
    self.ItemID = "";
    self.ItemObj = nil;
    self.GridX = nil;
    self.GridY = nil;
    self.DragID = nil;

    self:Receiver("bash_ItemDrag", self.ReceiveItem, {"Someshit"});
    self:Droppable("bash_ItemDrag");
end

function SLOT:SetInv(invID)
    self.InvID = invID;
end

function SLOT:SetGridPos(x, y)
    self.GridX = x;
    self.GridY = y;
end

function SLOT:GetItem()
    return self.ItemID;
end

function SLOT:SetItem(itemID)
    if bash.TableNet.IsRegistered(itemID) then
        self.ItemID = itemID;
        self.ItemObj = bash.TableNet.Get(itemID);
        self.ItemName = self.ItemObj:Get("ItemNum");
    end
end

function SLOT:ClearItem()
    self.ItemID = "";
    self.ItemObj = nil;
    self.ItemName = nil;
end

function SLOT:OnStartDragging()
    self.DragID = self.ItemID;
end

function SLOT:ReceiveItem(panels, dropped, index, x, y)
    if !dropped then return; end

    local dropItem = panels[1];
    if !dropItem then return; end
    if dropItem == self then return; end
    if dropItem.DragID != dropItem.ItemID then return; end
    local fromInv = dropItem.InvID;
    local toInv = self.InvID;

    local moveReq = vnet.CreatePacket("bash_Net_ItemMoveRequest");
    moveReq:String(dropItem.ItemID);    -- Dropped item.
    moveReq:String(self.ItemID);        -- Current item.
    moveReq:String(fromInv);            -- Dropped item inv.
    moveReq:String(toInv);              -- Current item inv.
    moveReq:Table({X = dropItem.GridX, Y = dropItem.GridY});    -- Dropped item pos.
    moveReq:Table({X = self.GridX, Y = self.GridY});            -- Current item pos.
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
