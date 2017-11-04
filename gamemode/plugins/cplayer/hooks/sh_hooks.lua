--[[
    CPlayer shared hooks.
]]

--
-- Local storage.
--

-- Micro-optimizations.
local bash          = bash;
local CurTime       = CurTime;
local os            = os;
local FindMetaTable = FindMetaTable;
local Format        = Format;

--
-- bash hooks.
--

-- Add player variables to TableNet.
hook.Add("GatherPrelimData_Base", "CPlayer_AddTableNet", function()
    local tabnet = bash.Util.GetPlugin("CTableNet");
    -- Domain.
    tabnet:AddDomain{
        ID = "Player",
        ParentMeta = FindMetaTable("Player"),
        StoredInSQL = true,
        SQLTable = "bash_plys",
        GetRowCondition = function(_self, ply)
            return Format("SteamID = '%s'", ply:SteamID());
        end
    };

    -- Variables.
    tabnet:AddVariable{
        Domain = "Player",
        ID = "Name",
        Type = "string",
        MaxLength = 32,
        Public = true,
        InSQL = true,
        OnGenerate = function(_self, ply)
            return ply:Name();
        end,
        OnInit = function(_self, ply, oldVal)
            if ply:Name() != oldVal then
                ply:SetNetVar("Player", "Name", ply:Name());
            end
        end,
        OnDeinit = function(_self, ply, oldVal)
            if ply:Name() != oldVal then
                ply:SetNetVar("Player", "Name", ply:Name());
            end
        end
    };
    tabnet:AddVariable{
        Domain = "Player",
        ID = "SteamID",
        Type = "string",
        MaxLength = 18,
        Public = true,
        InSQL = true,
        PrimaryKey = true,
        OnGenerate = function(_self, ply)
            return ply:SteamID();
        end
    };
    tabnet:AddVariable{
        Domain = "Player",
        ID = "Addresses",
        Type = "table",
        MaxLength = 255,
        InSQL = true,
        OnGenerate = function(_self, ply)
            return {[ply:IPAddress()] = true};
        end,
        OnInit = function(_self, ply, oldVal)
            oldVal[ply:IPAddress()] = true;
            ply:SetNetVar("Player", "Addresses", oldVal);
        end
    };
    tabnet:AddVariable{
        Domain = "Player",
        ID = "FirstLogin",
        Type = "number",
        MaxLength = 10,
        Public = true,
        InSQL = true,
        OnGenerate = function(_self, ply)
            return os.time();
        end
    };
    tabnet:AddVariable{
        Domain = "Player",
        ID = "NewPlayer",
        Type = "boolean",
        Public = true,
        InSQL = true,
        OnGenerate = true,
        OnInit = function(_self, ply, oldVal)
            local playtime = ply:GetNetVar("Player", "Playtime");
            if playtime > 21600 then
                ply:SetNetVar("Player", "NewPlayer", false);
            end
        end
    };
    tabnet:AddVariable{
        Domain = "Player",
        ID = "Playtime",
        Type = "number",
        MaxLength = 10,
        Public = true,
        InSQL = true,
        OnGenerate = 0,
        OnInit = function(_self, ply, oldVal)
            ply.StartTime = CurTime();
        end,
        OnDeinit = function(_self, ply, oldVal)
            local startTime = ply.StartTime or CurTime();
            local played = CurTime() - startTime;
            local newTime = oldVal + played;
            ply:SetNetVar("Player", "Playtime", newTime);
        end
    };
    tabnet:AddVariable{
        Domain = "Player",
        ID = "Country",
        Type = "string",
        Public = true,
        OnGenerate = function(_self, ply)
            return bash.Util.GetClientData(ply, "Country");
        end
    };
    tabnet:AddVariable{
        Domain = "Player",
        ID = "OS",
        Type = "number",
        Public = true,
        OnGenerate = function(_self, ply)
            return bash.Util.GetClientData(ply, "OS");
        end
    };
end);
