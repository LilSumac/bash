local ITEM = {};

function ITEM:Init()
    self:ClearItem();
    self.GhostHovering = false;

    self:Receiver("bash_TestDrag", self.ReceiveItem, {"Someshit"});
    self:Droppable("bash_TestDrag");
end

function ITEM:SetItem(itemID)
    if bash.TableNet.IsRegistered(itemID) then
        self.ItemID = itemID;
        self.ItemObj = bash.TableNet.Get(itemID);
        self.ItemName = self.ItemObj:Get("ItemNum");
        local pos = self.ItemObj:Get("PosInInv", {});
        self.PosX = pos.X;
        self.PosY = pos.Y;
        self.InvID = self.ItemObj:Get("Owner", "");
    end
end

function ITEM:ClearItem()
    self.ItemID = "";
    self.ItemObj = nil;
    self.ItemName = nil;
    self.PosX = -1;
    self.PosY = -1;
    self.SizeX = 2;
    self.SizeY = 2;
    self.InvID = "";
end

function ITEM:DragHoverEnd()
    self.GhostHovering = false;
    self.GhostPanel = nil;
end

function ITEM:ReceiveItem(panels, dropped, index, x, y)
    local ghost = panels[1];
    self.GhostHovering = !dropped;
    self.GhostPanel = ghost;

    local posX, posY = self:GetPos();
    if dropped and panels[1] != self then
        local opts = DermaMenu(self:GetParent());
        opts:AddOption("Swap", function()
            local moveReq = vnet.CreatePacket("bash_Net_ItemMoveRequest");
            moveReq:String(ghost.ItemID);   -- Dropped item.
            moveReq:String(self.ItemID);    -- Current item (none).
            moveReq:String(ghost.InvID);    -- Dropped item inv.
            moveReq:String(self.InvID);     -- Current item inv.
            moveReq:Table({X = ghost.PosX, Y = ghost.PosY});    -- Dropped item pos.
            moveReq:Table({X = self.PosX, Y = self.PosY});      -- Current item pos.
            moveReq:AddServer();
            moveReq:Send();
        end);
        opts:AddOption("Combine", function() end);
        opts:AddSpacer();
        local sub = opts:AddSubMenu("Some sub.");
        local subIcon = sub:AddOption("Icon thing.");
        subIcon:SetIcon("icon16/bug.png");
        opts:SetPos(posX + x, posY + y);
        opts:Open();
    else
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
    local col;
    if self:IsHovered() then
        if self.GhostHovering then
            if self.GhostPanel != self then
                -- One item hovered over another.
                col = Color(200, 200, 255, 150);
            end
        else
            -- Item hovered over.
            col = Color(200, 255, 200, 150);
        end
    end
    -- Idle.
    if !col then col = Color(255, 255, 255, 150); end

    surface.SetDrawColor(col);
    surface.DrawRect(0, 0, w, h);

    if self.ItemName then
        draw.SimpleText(self.ItemName, "ChatFont", w / 2, h / 2, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER);
    end
end

vgui.Register("bash_TestInvItem", ITEM, "DPanel");
