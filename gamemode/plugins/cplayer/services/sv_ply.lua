--[[
    CPlayer server service.
]]

-- Network pool.
util.AddNetworkString("CPlayer_Net_RespondClient");

-- Local functions.
local function createPlyData(ply)
    MsgLog(LOG_DB, "Creating new row for '%s'...", ply:Name());

    local tablenet = getService("CTableNet");
    local vars = tablenet:GetDomainVars("CPlayer");
    local data = {};
    for id, var in pairs(vars) do
        data[id] = handleFunc(var.OnGenerate, var, ply);
    end

    local db = getService("CDatabase");
    db:InsertRow(
        "bash_plys",            -- Table to query.
        data,                   -- Data to insert.

        function(_ply, results) -- Callback function upon completion.
            local preinit = ply.PreInitTask;
            if !preinit then return; end

            MsgLog(LOG_DB, "Created row for player '%s'.", ply:Name());
            preinit:PassData("SQLData", data);
            preinit:Update("WaitForSQL", 1);
        end,

        ply                     -- Argument #1 for callback.
    );
end

local function getPlyData(ply)
    MsgDebug(LOG_DB, "Gathering player data for '%s'...", ply:Name());

    local db = getService("CDatabase");
    db:SelectRow(
        "bash_plys",                                        -- Table to query.
        "*",                                                -- Columns to get.
        Format("WHERE SteamID = \'%s\'", ply:SteamID()),    -- Condition to compare against.

        function(_ply, results)                             -- Callback function upon completion.
            if #results > 1 then
                MsgLog(LOG_WARN, "Multiple rows found for %s [%s]! Remove duplicate rows ASAP.", ply:Name(), ply:SteamID());
            end

            results = results[1];
            if table.IsEmpty(results.data) then
                createPlyData(_ply);
            else
                for id, val in pairs(results.data[1]) do

                end

                MsgDebug(LOG_DB, "Found row for player '%s'.", _ply:Name());
                local preinit = ply.PreInitTask;
                if !preinit then return; end
                --PrintTable(results);
                -- UPDATE THIS
                preinit:PassData("SQLData", {});
                preinit:Update("WaitForSQL", 1);
            end
        end,

        ply                                                 -- Argument #1 for callback.
    );
end

local function sendPlyTables(ply)
    local tabnet = getService("CTableNet");
    if tabnet:IsRegistryEmpty() then
        MsgDebug(LOG_DEF, "Empty registry! Not sending to %s.", ply:Name());
        return;
    end

    local delay = 0.1;
    for id, obj in pairs(tabnet:GetRegistry()) do
        if !IsValid(obj) then continue; end

        for dom, vars in pairs(obj.TableNet) do
            timer.Simple(delay, function()
                -- Prevent sending tables that were removed during delay.
                if !tabnet:IsRegistered(id) then return; end
                tabnet:SendTable(ply, id, dom);
            end);
            delay = delay + 0.1;
        end
    end

    timer.Simple(delay, function()
        local oninit = ply.OnInitTask;
        oninit:Update("WaitForTableNet", 1);
    end);
end

-- Service functions.
function SVC:Initialize(ply)
    if ply.Initialized then return; end

    ply.Initialized = true;

    local respondPck = vnet.CreatePacket("CPlayer_Net_RespondClient");
    respondPck:AddTargets(ply);
    respondPck:Send();

    hook.Run("bash_PlayerOnInit", ply);
end

function SVC:PostInitialize(ply)
    if ply.PostInitialized then return; end

    ply.PostInitialized = true;
    hook.Run("bash_PlayerPostInit", ply);
end

function SVC:KickPlayer(ply, reason, kicker)

end

function SVC:BanPlayer(ply, reason, length, banner)

end
