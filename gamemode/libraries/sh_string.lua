--[[
    Base 'string' library extentions.
]]

local math = math;
local string = string;

function string.random(len, chars, pre)
    len = len or 8;
    chars = chars or CHAR_ALPHANUM;
    pre = pre or "";

    local ran = "";
    while #ran != len do
        ran = ran .. chars[math.random(1, #chars)];
    end
    return pre .. ran;
end
