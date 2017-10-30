--[[
    CChar shared hooks.
]]

-- Gamemode hooks.
hook.Add("bash_GatherPrelimData_Base", "CChar_AddCharVars", function()
    local tabnet = getService("CTableNet");
    tabnet:AddDomain{
        ID = "Char",
        ParentMeta = getMeta("CChar"),
        StoredInSQL = true,
        SQLTable = "bash_chars",
        GetRowCondition = function(_self, char)
            return Format("CharID = '%s'", char:GetNetVar("Char", "CharID"));
        end
    };

    tabnet:AddVariable{
        ID = "CharID",
        Domain = "Char",
        Type = "string",
        MaxLength = 17,
        Public = true,
        InSQL = true,
        OnGenerate = function(_self, char)
            return string.random(12, CHAR_ALPHANUM, "char_");
        end
    };
    tabnet:AddVariable{
        ID = "Name",
        Domain = "Char",
        Type = "string",
        MaxLength = 32,
        Public = true,
        InSQL = true
    };
end);
