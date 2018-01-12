--[[
    Money item.
]]

local ITEM = {};
ITEM.Static = {
    ID = "money",
    Name = "Money",
    SizeX = 2,
    SizeY = 2,
    CanStack = true,
    MaxStack = 1000000
};
ITEM.Dynamic = {
    Stack = 1
};
bash.Item.Register(ITEM);
