local ITEM = {};

function ITEM:Init()
    self.ItemID = "";
    self.ItemObj = {};
    self.ItemName = nil;
    self.SizeX = 2;
    self.SizeY = 2;
    self.GhostHovering = false;

    self:Receiver("bash_TestDrag", self.ReceiveItem, {"Someshit"});
    self:Droppable("bash_TestDrag");
end

function ITEM:SetItem(itemID)
    if bash.TableNet.IsRegistered(itemID) then
        self.ItemID = itemID;
        self.ItemObj = bash.TableNet.Get(itemID);
        self.ItemName = self.ItemObj:Get("ItemNum");
    end
end

function ITEM:ClearItem()
    self.ItemID = "";
    self.ItemObj = nil;
    self.ItemName = nil;
end

function ITEM:DragHoverEnd()
    self.GhostHovering = false;
end

function ITEM:ReceiveItem(panels, dropped, index, x, y)
    self.GhostHovering = !dropped;
    if !droppen then
        local posX, posY = self:GetPos();
        self:GetParent():ReceiveItem(panels, dropped, index, posX + x, posY + y);
    end

    --[[
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
    ]]
end

function ITEM:Paint(w, h)
    surface.SetDrawColor(self.GhostHovering and color_blue or color_white);
    surface.DrawOutlinedRect(0, 0, w, h);

    if self.ItemName then
        draw.SimpleText(self.ItemName, "ChatFont", w / 2, h / 2, color_black, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER);
    end
end

vgui.Register("bash_TestInvItem", ITEM, "DPanel");
