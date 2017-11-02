--[[
    CPlayer server service.
]]

--[[
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
]]

-- Service functions.
function SVC:Initialize(ply)
    if ply.Initialized then return; end

    ply.Initialized = true;

    bash.Util.RespondToClient(ply);

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
