--[[
    Base 'string' library extentions.
]]

--
-- Local storage.
--

local math = math;
local string = string;

--
-- String functions.
--

-- Generate a random string from a table of characters.
function string.random(len, chars, pre)
    if len < 0 then return; end
    if len == 0 then return ""; end

    len = len or 8;
    chars = chars or CHAR_ALPHANUM;
    pre = pre or "";

    local lenChars = #chars;
    local ran, index = {}, 0;
    while index != len do
        ran[index + 1] = chars[math.random(1, lenChars)];
        index = index + 1;
    end
    return pre .. table.concat(ran);
end
