--[[
    CPlayer server functionality.
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

--
-- Plugins functions.
--

function PLUG:KickPlayer(ply, reason, kicker)

end

function PLUG:BanPlayer(ply, reason, length, banner)

end
