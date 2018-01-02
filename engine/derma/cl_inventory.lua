--[[
    Inventory element.
]]

local INV = {};

function INV:Init()
    self:SetSize(SCRH * 0.33, SCRH * 0.33);
    self:Center();
    self:MakePopup();
    self:ShowCloseButton(true);
    self.InvID = "";
    self.InvObj = nil;
    self.WaitingOnInv = true;

    hook.Add("TableUpdate", "bash_InventoryWatchForUpdate", function(regID, data)
        -- TODO: Update on inv/item changes.
        if !self.InvObj then return; end

        local contents = self.InvObj:Get("Contents", {});
        if contents[regID] then
            -- TODO: Move item?
            self:RepopulateList();
        end
    end);

    hook.Add("TableDelete", "bash_InventoryWatchForDelete", function(regID, data)
        -- TODO: Update on inv/item delete.
        if !self.InvObj then return; end

        local contents = self.InvObj:Get("Contents", {});
        if self.InvID == regID then
            self:Remove();
        elseif contents[regID] then
            self.ListContainer:RemoveLine(self.ItemList[regID]);
            self.ItemList[regID] = nil;
        end
    end);
end

function INV:SetInventory(invID)
    if bash.TableNet.IsRegistered(invID) then
        self.InvID = invID;
        self.InvObj = bash.TableNet.Get(invID);
        self.WaitingOnInv = false;
        self:RepopulateList();
    end
end

function INV:RepopulateList()
    self:RemoveList();

    self.ListContainer = vgui.Create("DListView", self);
    self.ListContainer:Dock(FILL);
    self.ListContainer:SetMultiSelect(false);
    self.ListContainer:AddColumn("ItemID");
    self.ListContainer:AddColumn("ItemNum");
    self.ItemList = {};

    local contents = self.InvObj:Get("Contents", {});
    PrintTable(contents);
    local index, curItem = 1;
    for itemID, _ in pairs(contents) do
        curItem = bash.TableNet.Get(itemID);
        if !curItem then continue; end

        self.ListContainer:AddLine(itemID, curItem:Get("ItemNum"));
        self.ItemList[itemID] = index;
        index = index + 1;
    end

    self.ListContainer.OnRowSelected = function(_self, index, panel)
        MsgN("Selected " .. panel:GetColumnText(1) .. " at index " .. index .. ".");
    end
end

function INV:RemoveList()
    if self.ListContainer then
        self.ListContainer:Remove();
        self.ListContainer = nil;
    end
end

function INV:PaintOver(w, h)
    if self.WaitingOnInv then
        draw.SimpleText("Waiting on inventory...", "ChatFont", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER);
    end
end

function INV:OnRemove()
    hook.Remove("TableUpdate", "bash_InventoryWatchForUpdate");
    bash.CharInv = nil;
end

vgui.Register("bash_Inventory", INV, "DFrame");
