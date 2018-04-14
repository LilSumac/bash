--[[
    Basic inventory type.
]]

local INV = {};
INV.ID = "invtype_basic";
INV.Name = "Basic";
INV.SizeX = 5;
INV.SizeY = 5;
INV.MaxItemSize = ITEM_HUGE;
bash.Inventory.RegisterType(INV);
