local GRID = {};

local BLOCK_SIZE = 40;

function GRID:Init()
    self.GridDisabled = false;
    self.GhostX = -1;
    self.GhostY = -1;
    self:ClearInv();

    self:Receiver("bash_TestDrag", self.ReceiveItem, {"Someshit"});

    self.HookID = string.random(12);
    hook.Add("OnUpdateTable", "bash_InventoryWatchForUpdate_" .. self.HookID, function(item, name, newVal, oldVal)
        -- TODO: Update on inv/item changes.
        if !self.InvObj then return; end
        local itemID = item:GetField("ItemID");
        if !itemID then return; end

        if name == "Owner" then
            if newVal == self.InvID then
                self:AddItem(itemID);
            else
                self:RemoveItem(itemID);
            end
        end

        if item:GetField("Owner") != self.InvID then return; end

        if name == "Position" then
            if newVal.X != oldVal.X or newVal.Y != oldVal.Y then
                local panel = self.Items[itemID];
                if panel then
                    self:RemoveItem(itemID);
                end
    
                self:AddItem(itemID, true);
            end
        end
    end);

    hook.Add("OnDeleteTable", "bash_InventoryWatchForDelete_" .. self.HookID, function(inv)
        -- TODO: Update on inv/item delete.
        if !self.InvObj then return; end
        local invID = inv:GetField("InvID");
        if !invID then return; end

        if self.InvID == invID then
            self:Remove();
        end
    end);
end

function GRID:SetDisabled(disable)
    self.GridDisabled = disable;
end

function GRID:SetInv(invID)
    -- Check for invalid inventories.
    local inv = tabnet.GetTable(invID);
    if !inv then
        bash.Util.MsgErr("NoValidInvTable", invID);
        return;
    end

    local invTypeID = inv:GetField("InvType", "");
    local invType = bash.Inventory.Types[invTypeID];
    if !invType then
        bash.Util.MsgErr("NoValidInvType", invTypeID, invID);
        return;
    end

    self:ClearInv();

    -- Setup member variables.
    self.InvID = invID;
    self.InvObj = inv;
    self.InvType = invType;
    self.GridSizeX = invType.SizeX;
    self.GridSizeY = invType.SizeY;

    self:SetSize(invType.SizeX * BLOCK_SIZE, invType.SizeY * BLOCK_SIZE);

    self.Occupied = {};
    for xIndex = 1, invType.SizeX do
        self.Occupied[xIndex] = self.Occupied[xIndex] or {};
        for yIndex = 1, invType.SizeY do
            self.Occupied[xIndex][yIndex] = 0;
        end
    end

    -- Load inventory contents.
    local contents = inv:GetField("Contents", {});
    local item;
    for itemID, _ in pairs(contents) do
        self:AddItem(itemID);
    end
end

function GRID:ClearInv()
    -- Remove item objects from inventory.
    if self.Items then
        for itemID, panel in pairs(self.Items) do
            panel:Remove();
        end
    end

    -- Clear member variables.
    self.InvID = "";
    self.InvObj = nil;
    self.InvType = nil;
    self.GridSizeX = 0;
    self.GridSizeY = 0;
    self.Occupied = {};
    self.Items = {};
end

function GRID:AddItem(itemID, force)
    local item = tabnet.GetTable(itemID);
    if !item then
        bash.Util.MsgErr("NoValidItem", itemID);
        return;
    end

    local pos = item:GetField("Position", {});
    if !pos.X or !pos.Y then return; end

    -- TODO: Add item structs!
    local itemTypeID = item:GetField("ItemType", "");
    local itemType = bash.Item.Types[itemTypeID];
    if !itemType then return; end

    local sizeX, sizeY = itemType.Static.SizeX, itemType.Static.SizeY;
    if !self:CanFit(pos.X, pos.Y, sizeX, sizeY) and !force then return; end

    local newItem = vgui.Create("bash_TestInvItem", self);
    newItem:SetSize(sizeX * BLOCK_SIZE, sizeY * BLOCK_SIZE);
    newItem:SetPos((pos.X - 1) * BLOCK_SIZE, (pos.Y - 1) * BLOCK_SIZE);
    newItem:SetItem(itemID);

    for xIndex = pos.X, pos.X + (sizeX - 1) do
        for yIndex = pos.Y, pos.Y + (sizeY - 1) do
            self.Occupied[xIndex][yIndex] = itemID;
        end
    end

    self.Items[itemID] = newItem;
end

function GRID:RemoveItem(itemID)
    local panel = self.Items[itemID];
    if !panel then return; end

    for xIndex = panel.PosX, panel.PosX + (panel.SizeX - 1) do
        for yIndex = panel.PosY, panel.PosY + (panel.SizeY - 1) do
            self.Occupied[xIndex][yIndex] = 0;
        end
    end

    panel:ClearItem();
    panel:Remove();
end

function GRID:CanFit(posX, posY, sizeX, sizeY, ignoreItem)
    if table.IsEmpty(self.Occupied) then return false; end

    for xIndex = posX, posX + (sizeX - 1) do
        if self.Occupied[xIndex] == nil then return false; end
        for yIndex = posY, posY + (sizeY - 1) do
            if ignoreItem and self.Occupied[xIndex][yIndex] == ignoreItem then continue; end
            if self.Occupied[xIndex][yIndex] != 0 then return false; end
        end
    end

    return true;
end

function GRID:ReceiveItem(panels, dropped, index, x, y)
    local ghost = panels[1];
    local ghostX = math.floor(x / BLOCK_SIZE);
    local ghostY = math.floor(y / BLOCK_SIZE);
    local ghostW = ghost.SizeX;
    local ghostH = ghost.SizeY;
    if (self.InvID == ghost.InvID) and (ghostX + 1) == ghost.PosX and (ghostY + 1) == ghost.PosY then return; end
    if !self:CanFit(ghostX + 1, ghostY + 1, ghost.SizeX, ghost.SizeY, ghost.ItemID) then
        self.GhostX = -1;
        self.GhostY = -1;
        self.GhostSizeX = -1;
        self.GhostSizeY = -1;
        self.GhostPanel = nil;
        return;
    end

    if !dropped then
        self.GhostX = ghostX;
        self.GhostY = ghostY;
        self.GhostSizeX = ghost.SizeX;
        self.GhostSizeY = ghost.SizeY;
        self.GhostPanel = ghost;
    else
        self.GhostX = -1;
        self.GhostY = -1;
        self.GhostSizeX = -1;
        self.GhostSizeY = -1;
        self.GhostPanel = nil;

        local fromInv = ghost.InvID;
        local toInv = self.InvID;

        local moveReq = vnet.CreatePacket("bash_Net_ItemMoveRequest");
        moveReq:Table({
            DroppedItemID = ghost.ItemID,
            DroppedInvID = fromInv,
            DroppedItemPos = {
                X = ghost.PosX,
                Y = ghost.PosY
            },

            CurrentItemID = nil,
            CurrentInvID = toInv,
            CurrentItemPos = {
                X = ghostX + 1,
                Y = ghostY + 1
            }
        });
        moveReq:AddServer();
        moveReq:Send();
    end
end

function GRID:Paint(w, h)
    surface.SetDrawColor(color_green);
    surface.DrawRect(0, 0, w, h);

    surface.SetDrawColor(color_white);
    surface.DrawOutlinedRect(0, 0, w, h);

    local xInterval = (self:GetWide() / self.GridSizeX);
    for xIndex = 1, self.GridSizeX do
        surface.DrawLine(xIndex * xInterval, 1, xIndex * xInterval, h - 1);
    end
    local yInterval = (self:GetTall() / self.GridSizeY);
    for yIndex = 1, self.GridSizeY do
        surface.DrawLine(1, yIndex * yInterval, w - 1, yIndex * yInterval);
    end

    if self.GhostX != -1 and self.GhostY != -1 then
        local ghostX = (self.GhostX * BLOCK_SIZE);
        local ghostY = (self.GhostY * BLOCK_SIZE);
        local ghostW = (self.GhostSizeX * BLOCK_SIZE);
        local ghostH = (self.GhostSizeY * BLOCK_SIZE);
        local col = Color(255, 200, 200, 150);
        surface.SetDrawColor(col);
        surface.DrawRect(ghostX, ghostY, ghostW, ghostH);
        draw.SimpleText(self.GhostPanel.ItemName, "ChatFont", ghostX + (ghostW / 2), ghostY + (ghostH / 2), col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER);
    end
end

function GRID:OnRemove()
    hook.Remove("OnUpdateTable", "bash_InventoryWatchForUpdate_" .. self.HookID);
    hook.Remove("OnDeleteTable", "bash_InventoryWatchForDelete_" .. self.HookID);
end

vgui.Register("bash_TestInvGrid", GRID, "DPanel");
