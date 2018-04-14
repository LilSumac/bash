local CONT = {};

function CONT:Init()
    self.Collapsed = false;
    self.InvID = nil;
    self.InvObj = nil;
    self.CachedMaxSize = nil;
    self.CachedSize = nil;

    self.HeaderBar = nil;
    self.CurrentSizeBar = nil;
    self.ItemContent = nil;
end

function CONT:SetInventory(invID)
    local invObj = tabnet.GetTable(invID);
    if !invObj then return; end

    self.InvID = invID;
    self.InvObj = invObj;
    self:ComputeCurrentInvSize();

    if !ispanel(self.HeaderBar) then
        self:CreateHeaderBar();
    end
    if !ispanel(self.CurrentSizeBar) then
        self:CreateSizeBar();
    end
    if !ispanel(self.ItemContent) then
        self:CreateItemContent();
    end

    self:PopulateItems();
end

function CONT:ComputeCurrentInvSize()
    if !self.InvObj then return; end

    local size = 0;
    local curItem, curItemTypeID, curItemType;
    for itemID, _ in pairs(self.InvObj:GetField("Contents", {})) do 
        curItem = tabnet.GetTable(itemID);
        if !curItem then continue; end
        
        curItemTypeID = curItem:GetField("ItemType");
        curItemType = bash.Item.GetType(curItemTypeID);
        if !curItemType then continue; end

        size = size + curItemType.Static.Size;
    end

    local invTypeID = self.InvObj:GetField("InvType");
    local invType = bash.Inventory.GetType(invTypeID);
    if invType then
        self.CachedMaxSize = invType.MaxTotalSize;
    end 

    self.CachedSize = size;
end

function CONT:ClearInventory()
    self.InvID = nil;
    self.InvObj = nil;
    self.CachedMaxSize = nil;
    self.CachedSize = nil;
end 

function CONT:CreateHeaderBar()
    if ispanel(self.HeaderBar) then
        self.HeaderBar:Remove();
        self.HeaderBar = nil;
    end

    self.HeaderBar = vgui.Create("DButton", self);
    self.HeaderBar:SetText("");
    self.HeaderBar:SetPos(0, 0);
    self.HeaderBar:SetSize(self:GetWide(), (self:GetWide() / 4) - 8);
    self.HeaderBar.DoClick = function(_self)
        if self.Collapsed then
            self:Expand();
        else
            self:Collapse();
        end
    end 
    self.HeaderBar.Paint = function(_self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, self.InvID != nil and color_green or color_red);
        draw.SimpleText(self.Collapsed and "+" or "-", "ChatFont", 12, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER);

        if self.InvID then
            draw.SimpleText(self.InvID, "ChatFont", 24, h / 2, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER);
        end
    end
end

function CONT:CreateSizeBar()
    if ispanel(self.CurrentSizeBar) then
        self.CurrentSizeBar:Remove();
        self.CurrentSizeBar = nil;
    end

    local posY = 0;
    if ispanel(self.HeaderBar) then
        local _x, _y = self.HeaderBar:GetPos();
        local _h = self.HeaderBar:GetTall();
        posY = _y + _h;
    end

    self.CurrentSizeBar = vgui.Create("DPanel", self);
    self.CurrentSizeBar:SetPos(0, posY);
    self.CurrentSizeBar:SetSize(self:GetWide(), 8);
    self.CurrentSizeBar.Paint = function(_self, w, h)
        if !self.CachedMaxSize or !self.CachedSize then return; end
        
        local minus;
        if self.CachedSize == 0 then
            minus = w;
        else
            minus = (self.CachedSize / self.CachedMaxSize);
        end 

        draw.RoundedBox(0, 0, 0, w - (minus * w), h, color_red);
        surface.SetDrawColor(0, 0, 0);
        surface.DrawOutlinedRect(0, 0, w, h);
    end
end

function CONT:CreateItemContent()
    if ispanel(self.ItemContent) then
        self.ItemContent:Remove();
        self.ItemContent = nil;
    end

    local posY = 0;
    if ispanel(self.CurrentSizeBar) then
        local _x, _y = self.CurrentSizeBar:GetPos();
        local _h = self.CurrentSizeBar:GetTall();
        posY = _y + _h;
    end

    self.ItemContent = vgui.Create("DListLayout", self);
    self.ItemContent:SetPos(0, posY);
    self.ItemContent:SetSize(self:GetWide(), 0);
    self.ItemContent:SetPaintBackground(true);
    self.ItemContent:SetBackgroundColor(Color(255, 255, 255));
end

function CONT:PopulateItems()
    if !self.InvObj then return; end

    if !ispanel(self.ItemContent) then
        self:CreateItemContent();
    end

    self.ItemContent:Clear();

    local curY = 0;
    local curItem, curItemPanel;
    for itemID, _ in pairs(self.InvObj:GetField("Contents", {})) do
        curItem = tabnet.GetTable(itemID);
        if !curItem then continue; end

        curItemPanel = vgui.Create("bash_ItemContainer", self.ItemContent);
        curItemPanel:SetSize(self:GetWide(), self:GetWide() / 4);
        curItemPanel:SetItem(itemID);
        self.ItemContent:Add(curItemPanel);
        curY = curY + curItemPanel:GetTall();
    end

    self.ItemContent:SetTall(curY);

    self:InvalidateLayout();
end

function CONT:Collapse()
    if self.Collapsed then return; end
    if !self.InvObj then return; end 

    self.Collapsed = true;

    if ispanel(self.ItemContent) then
        self.ItemContent:SetVisible(false);
        self:InvalidateLayout();
    end 
end

function CONT:Expand()
    if !self.Collapsed then return; end
    if !self.InvObj then return; end 

    self.Collapsed = false;

    if ispanel(self.ItemContent) then
        self.ItemContent:SetVisible(true);
        self:InvalidateLayout();
    end 
end

function CONT:Paint(w, h) end

function CONT:PerformLayout(w, h)
    local calcY = 0;
    if ispanel(self.HeaderBar) then
        calcY = calcY + self.HeaderBar:GetTall();
    end
    if ispanel(self.CurrentSizeBar) then
        calcY = calcY + self.CurrentSizeBar:GetTall();
    end
    if ispanel(self.ItemContent) and !self.Collapsed then
        calcY = calcY + self.ItemContent:GetTall();
    end

    self:SetTall(calcY);
end 

vgui.Register("bash_InvContainer", CONT, "DPanel");