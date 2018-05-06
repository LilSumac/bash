--[[
    Junk item.
]]

local ITEM = {};

-- Static fields.
ITEM.Static = {
    Base = "base_item",
    ID = "junk",
    Name = "Junk",
    WorldModel = "models/props_lab/box01a.mdl",
    Size = ITEM_LARGE,
    SizeX = 2,
    SizeY = 2,
    CanStack = true,
    MaxStack = 1000000
};

bash.Item.RegisterType(ITEM);
