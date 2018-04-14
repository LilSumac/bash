--[[
    Junk item.
]]

local ITEM = {};
ITEM.Static = {
    ID = "junk",
    Name = "Junk",
    WorldModel = "models/props_lab/box01a.mdl",
    Size = ITEM_LARGE,
    SizeX = 2,
    SizeY = 2,
    CanStack = true,
    MaxStack = 1000000
};
ITEM.Dynamic = {
    Stack = 1
};
bash.Item.RegisterType(ITEM);
