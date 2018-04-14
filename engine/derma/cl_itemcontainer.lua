local ITEM = {};

function ITEM:Init()
    self.ItemID = nil;
    self.ItemObj = nil;
end 

function ITEM:SetItem(itemID)
    local itemObj = tabnet.GetTable(itemID);
    if !itemObj then return; end

    self.ItemID = itemID;
    self.ItemObj = itemObj;
end 

function ITEM:ClearItem()
    self.ItemID = nil;
    self.ItemObj = nil;
end

function ITEM:OnMousePressed(mouse)
    if mouse == MOUSE_LEFT then
        --self:DragMousePress(MOUSE_LEFT);
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
    if !self.ItemObj then return; end

    draw.SimpleText(self.ItemID, "ChatFont", 8, h / 2, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER);
    surface.SetDrawColor(0, 0, 0);
    surface.DrawOutlinedRect(0, 0, w, h);
end 

vgui.Register("bash_ItemContainer", ITEM, "DPanel");