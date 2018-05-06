--[[
    Base bash item.
]]

local BASE = {};

-- Static fields.
BASE.Static             = {};
BASE.Static.ID          = "base_item";
BASE.Static.Name        = "Item";
BASE.Static.WorldModel  = "models/props_lab/box01a.mdl";
BASE.Static.CanStack    = false;
BASE.Static.MaxStack    = 1;

-- Dynamic fields.
BASE.Dynamic        = {};
BASE.Dynamic.Stack  = 1;

-- Function fields.
BASE.Functions  = {};
BASE.Functions.Drop = {

    ShowOnClick = true,
    ShowOnDrop = false,
    ShowOnUse = false,

    CanShow = function(item)
        -- TODO: Add if player is viewing another inventory, return false.
        -- Can basically replace all of this func.
        if !item then return false; end
        local itemID = item:GetField("ItemID");

        local char = LocalPlayer():GetCharacter();
        local charID = char:GetField("CharID");
        if !char then return false; end
        if !bash.Character.HasSpecificItem(charID, itemID) then return false; end

        return true;
    end,

    MenuName = "Drop",

    RunOnClient = false,
    RunOnServer = true,

    GetSendData = function(item)
        local traceTab = {};
        traceTab.start = LocalPlayer():EyePos();
        traceTab.endpos = traceTab.start + LocalPlayer():GetAimVector() * 90;
        traceTab.filter = LocalPlayer();
        local trace = util.TraceLine(traceTab);
        local worldPos = trace.HitPos;
        worldPos.z = worldPos.z + 2;
        -- TODO: Add position constraints.

        return {
            WorldPos = worldPos
        };
    end,

    Run = function(ply, item, sendData)
        if !item then return; end
        
        local itemID = item:GetField("ItemID");
        local invID = item:GetField("Owner");
        local owner = bash.Inventory.GetPlayerOwner(invID);
        if owner != ply then return; end

        bash.Item.SpawnInWorld(itemID, sendData.WorldPos);
    end

};
BASE.Functions.PickUp = {

    ShowOnClick = false,
    ShowOnDrop = false,
    ShowOnUse = true,

    CanShow = function(item, ent)
        -- TODO: Add if player is viewing another inventory, return false.
        -- Can basically replace all of this func.
        if !item then return false; end
        if !isent(ent) then return false; end

        local char = LocalPlayer():GetCharacter();
        if !char then return false; end

        return true;
    end,

    MenuName = "Pick Up",

    RunOnClient = false,
    RunOnServer = true,

    Run = function(ply, item, sendData)
        if !item then return; end

        local itemID = item:GetField("ItemID");
        local invID = item:GetField("Owner");
        if invID != "!WORLD!" then return; end

        local char = ply:GetCharacter();
        if !char then return; end
        local charID = char:GetField("CharID");

        if !bash.Character.GiveItem(charID, itemID) then
            MsgN("Couldn't pick up idiot!");
            -- TODO: Send notif.
        end
    end

};
BASE.Functions.Stack = {

    ShowOnClick = false,
    ShowOnDrop = true,
    ShowOnUse = false,

    CanShow = function(sourceItem, targetItem)
        if !sourceItem or !targetItem then return false; end
        
        local sourceItemTypeID = sourceItem:GetField("ItemType");
        local targetItemTypeID = targetItem:GetField("ItemType");
        if sourceItemTypeID != targetItemTypeID then return false; end 

        local sourceItemType = bash.Item.GetType(sourceItemTypeID);
        local targetItemType = bash.Item.GetType(targetItemTypeID);
        if !sourceItemType or !targetItemType then return false; end
        if !sourceItemType.Static.CanStack or !targetItemType.Static.CanStack then return false; end

        local targetItemID = targetItem:GetField("ItemID");
        local targetStackAmt = bash.Item.GetDynamicData(targetItemID, "Stack");
        if targetStackAmt >= targetItemType.Static.MaxStack then return false; end

        return true;
    end,

    MenuName = "Stack",

    RunOnClient = false,
    RunOnServer = true,

    GetSendData = function(sourceItem, targetItem)
        return {
            TargetItemID = targetItem:GetField("ItemID")
        };
    end,

    Run = function(ply, sourceItem, sendData)
        if !sourceItem then return; end
        local sourceItemID = sourceItem:GetField("ItemID");
        if !sourceItemID then return; end
        
        local targetItemID = sendData.TargetItemID;
        local targetItem = tabnet.GetTable(targetItemID);
        if !targetItem then return; end 


        --bash.Item.Stack(sourceItem,);
    end

};

bash.Item.RegisterBase(BASE);