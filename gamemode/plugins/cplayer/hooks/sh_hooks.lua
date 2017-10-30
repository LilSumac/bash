--[[
    CPlayer shared hooks.
]]

-- Gamemode hooks.
hook.Add("bash_GatherPrelimData_Base", "CPlayer_AddTableNet", function()
    local tabnet = getService("CTableNet");
    tabnet:AddDomain{
        ID = "Player",
        ParentMeta = FindMetaTable("Player"),
        StoredInSQL = true,
        SQLTable = "bash_plys",
        GetRowCondition = function(_self, ply)
            return Format("SteamID = '%s'", ply:SteamID());
        end
    };

    tabnet:AddVariable{
        ID = "Name",
        Domain = "Player",
        Type = "string",
        MaxLength = 32,
        Public = true,
        InSQL = true,
        OnGenerate = function(_self, ply)
            return ply:Name();
        end,
        OnInit = function(_self, ply, oldVal)
            return ply:Name();
        end
    };

    tabnet:AddVariable{
        ID = "SteamID",
        Domain = "Player",
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
        ID = "Addresses",
        Domain = "Player",
        Type = "table",
        MaxLength = 255,
        InSQL = true,
        OnGenerate = function(_self, ply)
            return {[ply:IPAddress()] = true};
        end,
        OnInit = function(_self, ply, oldVal)
            oldVal[ply:IPAddress()] = true;
            return oldVal;
        end
    };

    tabnet:AddVariable{
        ID = "FirstLogin",
        Domain = "Player",
        Type = "number",
        MaxLength = 10,
        Public = true,
        InSQL = true,
        OnGenerate = function(_self, ply)
            return os.time();
        end
    };

    tabnet:AddVariable{
        ID = "NewPlayer",
        Domain = "Player",
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
        ID = "Playtime",
        Domain = "Player",
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
end);
