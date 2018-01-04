local GRID = {};

local BLOCK_SIZE = 40;

function GRID:Init()
    self.GridDisabled = false;
    self.GhostX = -1;
    self.GhostY = -1;
    self:ClearInv();

    self:Receiver("bash_TestDrag", self.ReceiveItem, {"Someshit"});
end

function GRID:SetDisabled(disable)
    self.GridDisabled = disable;
end

function GRID:SetInv(invID)
    -- Check for invalid inventories.
    local invObj = bash.TableNet.Get(invID);
    if !invObj then
        bash.Util.MsgErr("NoValidInvTable", invID);
        return;
    end

    local invTypeID = invObj:Get("InvType", "");
    local invType = bash.Inventory.Types[invTypeID];
    if !invType then
        bash.Util.MsgErr("NoValidInvType", invTypeID, invID);
        return;
    end

    self:ClearInv();

    -- Setup member variables.
    self.InvID = invID;
    self.InvObj = invObj;
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
    local contents = invObj:Get("Contents", {});
    for itemID, _ in pairs(contents) do
        self:AddItem(itemID);
    end
    PrintTable(self.Occupied);
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

function GRID:AddItem(itemID)
    local item = bash.TableNet.Get(itemID);
    if !item then
        bash.Util.MsgErr("NoValidItem", itemID);
        return;
    end

    local pos = item:Get("PosInInv", {});
    if !pos.X or !pos.Y then return; end

    -- TODO: Add item structs!
    local sizeX, sizeY = 2, 2;
    if !self:CanFit(pos.X, pos.Y, sizeX, sizeY) then return; end

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

function GRID:CanFit(posX, posY, sizeX, sizeY)
    if table.IsEmpty(self.Occupied) then return false; end

    for xIndex = posX, posX + (sizeX - 1) do
        if self.Occupied[xIndex] == nil then return false; end
        for yIndex = posY, posY + (sizeY - 1) do
            if self.Occupied[xIndex][yIndex] != 0 then return false; end
        end
    end

    return true;
end

function GRID:ReceiveItem(panels, dropped, index, x, y)
    if !dropped then
        local ghost = panels[1];
        self.GhostX = math.floor(x / BLOCK_SIZE);
        self.GhostY = math.floor(y / BLOCK_SIZE);
        self.GhostSizeX = ghost.SizeX;
        self.GhostSizeY = ghost.SizeY;
        self.GhostName = ghost.ItemName;
    else
        self.GhostX = -1;
        self.GhostY = -1;
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

function GRID:Paint(w, h)
    surface.SetDrawColor(color_green);
    surface.DrawRect(0, 0, w, h);

    if self.GhostX != -1 and self.GhostY != -1 then
        if !self:CanFit(self.GhostX + 1, self.GhostY + 1, self.GhostSizeX, self.GhostSizeY) then return; end

        local ghostX = (self.GhostX * BLOCK_SIZE);
        local ghostY = (self.GhostY * BLOCK_SIZE);
        local ghostW = (self.GhostSizeX * BLOCK_SIZE);
        local ghostH = (self.GhostSizeY * BLOCK_SIZE);
        surface.SetDrawColor(Color(255, 255, 255, 150));
        surface.DrawOutlinedRect(ghostX, ghostY, ghostW, ghostH);

        if self.GhostName then
            draw.SimpleText(self.GhostName, "ChatFont", ghostX + (ghostW / 2), ghostY + (ghostH / 2), Color(0, 0, 0, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER);
        end
    end
end

vgui.Register("bash_TestInvGrid", GRID, "DPanel");
