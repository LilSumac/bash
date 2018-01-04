--[[
    Test inventory element.
]]

local INV = {};

function INV:Init()
    self:SetSize(SCRH * 0.33, SCRH * 0.33);
    self:Center();
    self:MakePopup();
    self:ShowCloseButton(false);
    self:SetSizable(true);
    self.InvID = "";
    self.InvObj = nil;
    self.WaitingOnInv = true;
    self.HookID = string.random(8);

    self.CloseButton = vgui.Create("bash_Close", self);
    self.CloseButton:SetSize(16, 16);
    self.CloseButton:SetPos(self:GetWide() - 20, 4);

    self.GridContainer = vgui.Create("DPanel", self);
    self.GridContainer:Dock(FILL);
    self.ItemRef = {};

    hook.Add("TableUpdate", "bash_InventoryWatchForUpdate_" .. self.HookID, function(regID, data)
        -- TODO: Update on inv/item changes.
        if !self.InvObj then return; end
        local item = bash.TableNet.Get(regID);
        if !item:Get("ItemID") then return; end

        --[[
        if isInv and regID == self.InvID then
            local contents = self.InvObj:Get("Contents", {});
            if contents[regID] then
                -- TODO: Item has been added to inv.
                local oldPos = self.ItemRef[regID];

                if self.InvGrid[oldPos.X][oldPos.Y] then
                    self.InvGrid[oldPos.X][oldPos.Y]:ClearItem();
                    self.ItemRef[regID] = nil;
                end
                if self.InvGrid[newPos.X][newPos.Y] then
                    self.InvGrid[newPos.X][newPos.Y]:SetItem(regID);
                    self.ItemRef[regID] = newPos;
                end
            else
                -- TODO: Item has been removed from inv.
                local oldPos = self.ItemRef[regID];
                if !oldPos then return; end

                if self.InvGrid[oldPos.X][oldPos.Y] then
                    self.InvGrid[oldPos.X][oldPos.Y]:ClearItem();
                    self.ItemRef[regID] = nil;
                end
            end
        end
        ]]

        MsgN("FRAME HOOK");
        MsgN(regID);
        PrintTable(data);

        if data["Owner"] then
            if data["Owner"] == self.InvID then
                -- TODO: Item was added to this inv.
                local newPos = item:Get("PosInInv");
                if !newPos then return; end

                if self.InvGrid[newPos.X][newPos.Y] then
                    self.InvGrid[newPos.X][newPos.Y]:SetItem(regID);
                    self.ItemRef[regID] = newPos;
                end
            else
                -- TODO: Item was removed from this inv.
                local oldPos = self.ItemRef[regID];
                if !oldPos then return; end
                local oldPanel = self.InvGrid[oldPos.X][oldPos.Y];

                if ispanel(oldPanel) and oldPanel:GetItem() == regID then
                    -- TODO: Cancel active drag.
                    dragndrop.Drop();

                    oldPanel:ClearItem();
                    self.ItemRef[regID] = nil;
                end
            end
        end

        if item:Get("Owner") != self.InvID then return; end

        if data["PosInInv"] then
            local oldPos = self.ItemRef[regID];
            local newPos = data["PosInInv"];
            local oldPanel = self.InvGrid[oldPos.X][oldPos.Y];
            local newPanel = self.InvGrid[newPos.X][newPos.Y];

            if ispanel(oldPanel) and oldPanel:GetItem() == regID then
                self.InvGrid[oldPos.X][oldPos.Y]:ClearItem();
                self.ItemRef[regID] = nil;
            end
            if ispanel(newPanel) then
                self.InvGrid[newPos.X][newPos.Y]:SetItem(regID);
                self.ItemRef[regID] = newPos;
            end
        end
    end);

    hook.Add("TableDelete", "bash_InventoryWatchForDelete_" .. self.HookID, function(regID, data)
        -- TODO: Update on inv/item delete.
        if !self.InvObj then return; end

        if self.InvID == regID then
            self:Remove();
        end
    end);
end

function INV:SetInventory(invID)
    if bash.TableNet.IsRegistered(invID) then
        self.InvID = invID;
        self.InvObj = bash.TableNet.Get(invID);
        self.WaitingOnInv = false;
        self:SetTitle(self.InvID);
        self:CreateTemplate();
    end
end

function INV:CreateTemplate()
    if self.WaitingOnInv then return; end

    self:RemoveTemplate();
    local invType = self.InvObj:Get("InvType");
    local invStruct = bash.Inventory.Types[invType];
    if !invStruct then return; end

    self.InvGrid = {};
    self.GridContainer:SetSize(invStruct.SizeX * 50, invStruct.SizeY * 50);
    local frameX, frameY = 0, 0;
    for xIndex = 1, invStruct.SizeX do
        self.InvGrid[xIndex] = {};
        for yIndex = 1, invStruct.SizeY do
            self.InvGrid[xIndex][yIndex] = vgui.Create("bash_TestSlot", self.GridContainer);
            self.InvGrid[xIndex][yIndex]:SetSize(50, 50);
            self.InvGrid[xIndex][yIndex]:SetPos((xIndex - 1) * 50, (yIndex - 1) * 50);
            self.InvGrid[xIndex][yIndex]:SetInv(self.InvID);
            self.InvGrid[xIndex][yIndex]:SetGridPos(xIndex, yIndex);
        end
    end

    self:PopulateTemplate();
end

function INV:RemoveTemplate()

end

function INV:EmptyTemplate()
    if self.WaitingOnInv then return; end

    local invType = self.InvObj:Get("InvType");
    local invStruct = bash.Inventory.Types[invType];
    if !invStruct then return; end

    for xIndex = 1, invStruct.SizeX do
        if !self.InvGrid[xIndex] then continue; end

        for yIndex = 1, invStruct.SizeY do
            if !self.InvGrid[xIndex][yIndex] then continue; end
            self.InvGrid[xIndex][yIndex]:ClearItem();
        end
    end

    self.ItemRef = {};
end

function INV:PopulateTemplate()
    if self.WaitingOnInv then return; end

    self:EmptyTemplate();
    local contents = self.InvObj:Get("Contents", {});
    local curObj, pos, xPos, yPos;
    for itemID, _ in pairs(contents) do
        curObj = bash.TableNet.Get(itemID);
        if !curObj then continue; end

        pos = curObj:Get("PosInInv", {});
        if !pos.X or !pos.Y then return; end

        if !self.InvGrid[pos.X][pos.Y] then continue; end
        self.InvGrid[pos.X][pos.Y]:SetItem(itemID);
        self.ItemRef[itemID] = {X = pos.X, Y = pos.Y};
    end
end

function INV:PaintOver(w, h)
    if self.WaitingOnInv then
        draw.SimpleText("Waiting on inventory...", "ChatFont", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER);
    end
end

function INV:OnRemove()
    hook.Remove("TableUpdate", "bash_InventoryWatchForUpdate_" .. self.HookID);
    hook.Remove("TableDelete", "bash_InventoryWatchForDelete_" .. self.HookID);
    bash[self.InvID] = nil;
end

vgui.Register("bash_TestFrame", INV, "DFrame");
