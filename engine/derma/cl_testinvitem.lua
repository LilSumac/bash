local ITEM = {};

function ITEM:Init()
    self:ClearItem();
    self.GhostHovering = false;
    self.Disabled = false;
    self.DisabledTime = nil;

    self:Receiver("bash_TestDrag", self.ReceiveItem, {"Someshit"});
    self:Droppable("bash_TestDrag");
end

function ITEM:SetItem(itemID)
    if tabnet.GetTable(itemID) then
        self.ItemID = itemID;
        self.ItemObj = tabnet.GetTable(itemID);
        self.ItemName = self.ItemObj:GetField("ItemID");

        local pos = self.ItemObj:GetField("Position", {});
        self.PosX = pos.x;
        self.PosY = pos.y;

        local itemTypeID = self.ItemObj:GetField("ItemType", "");
        local itemType = bash.Item.Types[itemTypeID];
        self.SizeX = itemType.Static.SizeX;
        self.SizeY = itemType.Static.SizeY;

        self.InvID = self.ItemObj:GetField("Owner");
    end
end

function ITEM:ClearItem()
    self.ItemID = "";
    self.ItemObj = nil;
    self.ItemName = nil;
    self.PosX = -1;
    self.PosY = -1;
    self.SizeX = -1;
    self.SizeY = -1;
    self.InvID = "";
end

function ITEM:SetDisabled(disable)
    self.DisabledTime = (disable and CurTime()) or nil;
    self.Disabled = disable;
end 

function ITEM:IsDisabled()
    return self.Disabled;
end 

function ITEM:DragHoverEnd()
    self.GhostHovering = false;
    self.GhostPanel = nil;
end

function ITEM:ReceiveItem(panels, dropped, index, x, y)
    if self:IsDisabled() then return; end

    local ghost = panels[1];
    if ghost:IsDisabled() then
        local grid = self:GetParent();
        grid:ClearGhost();
        return;
    end 

    self.GhostHovering = !dropped;
    self.GhostPanel = ghost;

    local posX, posY = self:GetPos();
    if dropped and panels[1] != self then
        local opts = DermaMenu(self:GetParent());
        opts:AddOption("Swap", function()
            local moveReq = vnet.CreatePacket("bash_Net_ItemMoveRequest");
            moveReq:Table({
                WasLeftClick = true,    -- TODO: Work.
                DroppedItemID = ghost.ItemID,
                DroppedItemPos = {
                    x = ghost.PosX,
                    y = ghost.PosY
                },
                DroppedItemOwner = ghost.InvID,
    
                TargetItemID = self.ItemID,
                TargetItemPos = {
                    x = self.PosX,
                    y = self.PosY
                },
                TargetItemOwner = self.InvID
            });

            local grid = self:GetParent();
            grid:ClearGhost();

            ghost:SetDisabled(true);
            self:SetDisabled(true);
            
            --[[
            moveReq:Table({
                DroppedItemID = ghost.ItemID,
                DroppedInvID = ghost.InvID,
                DroppedItemPos = {
                    x = ghost.PosX,
                    y = ghost.PosY
                },

                CurrentItemID = self.ItemID,
                CurrentInvID = self.InvID,
                CurrentItemPos = {
                    x = self.PosX,
                    y = self.PosY
                }
            });
            ]]

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
end

function ITEM:OnMousePressed(mouse)
    if mouse == MOUSE_LEFT then
        self:DragMousePress(MOUSE_LEFT);
    elseif mouse == MOUSE_RIGHT then
        local itemTypeID = self.ItemObj:GetField("ItemType", "");
        local itemType = bash.Item.Types[itemTypeID];
        if !itemType then return; end 

        local opts = DermaMenu(self:GetParent());
        local added = 0;

        for name, func in pairs(itemType.Functions) do 
            if !func.ShowInInv then continue; end
            if !func.CanShow(self.ItemObj) then continue; end

            opts:AddOption(func.MenuName or name, function()
                if func.RunOnClient then
                    func.Run(LocalPlayer(), self.ItemObj, {});
                else
                    local sendData = (func.GetSendData and func.GetSendData(self.ItemObj)) or {};
                    local sendUse = vnet.CreatePacket("bash_Net_ItemFuncRequest");
                    sendUse:Table({
                        ItemID = self.ItemID,
                        UseFunc = name,
                        SendData = sendData
                    });
                    sendUse:AddServer();
                    sendUse:Send();
                end
            end);

            added = added + 1;
        end

        if added > 0 then
            local posX, posY = gui.MousePos();
            opts:SetPos(posX, posY);
            opts:Open();
        else
            opts:Remove();
        end 
    end 
end

function ITEM:Paint(w, h)
    local col;
    if self:IsDisabled() then
        if self.DisabledTime and CurTime() - self.DisabledTime > 0.5 then
            self:SetDisabled(false);
            return;
        end

        col = Color(255, 200, 200, 150);
    else 
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
