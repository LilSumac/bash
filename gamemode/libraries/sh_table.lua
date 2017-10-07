local table = table;

function table.IsEmpty(tab)
    if !tab or type(tab) != "table" then return true; end
    for _, __ in pairs(tab) do return false; end
    return true;
end
