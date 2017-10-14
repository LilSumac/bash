local table = table;

function table.IsEmpty(tab)
    if !tab or type(tab) != "table" then return false; end
    return next(tab) == nil;
end
