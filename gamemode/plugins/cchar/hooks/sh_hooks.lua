--[[
    CChar shared hooks.
]]

--
-- Local storage.
--

-- Micro-optimizations.
local bash      = bash;
local Format    = Format;
local string    = string;

--
-- bash hooks.
--

-- Add character variables to TableNet.
hook.Add("GatherPrelimData_Base", "CChar_AddCharVars", function()
    local tabnet = bash.Util.GetPlugin("CTableNet");
    -- Domain.
    tabnet:AddDomain{
        ID = "Char",
        ParentMeta = bash.Util.GetMeta("CChar"),
        StoredInSQL = true,
        SQLTable = "bash_chars",
        GetRowCondition = function(_self, char)
            return Format("CharID = '%s'", char:GetNetVar("Char", "CharID"));
        end
    };

    -- Variables.
    tabnet:AddVariable{
        Domain = "Char",
        ID = "CharID",
        Type = "string",
        MaxLength = 17,
        Public = true,
        InSQL = true,
        OnGenerate = function(_self, char)
            return string.random(12, CHAR_ALPHANUM, "char_");
        end
    };
    tabnet:AddVariable{
        Domain = "Char",
        ID = "Name",
        Type = "string",
        MaxLength = 32,
        Public = true,
        InSQL = true
    };
end);
