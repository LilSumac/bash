--[[
    CTableNet client hooks.
]]

--
-- Loacl storage.
--

-- Micro-optimizations.
local bash      = bash;
local Format    = Format;
local hook      = hook;
local MsgLog    = MsgLog;
local pairs     = pairs;
local vnet      = vnet;

--
-- Local functions.
--

-- Send back an acknowledgement of registry reciept.
local function sendRegAck()
    local ackPck = vnet.CreatePacket("CTableNet_Net_RegSendAck");
    ackPck:AddServer();
    ackPck:Send();
end

--
-- Network hooks.
--

-- Receive the entire registry.
vnet.Watch("CTableNet_Net_RegSend", function(pck)
    local tabnet = bash.Util.GetPlugin("CTableNet");
    local registry = tabnet:GetRegistry();

    local reg = pck:Table();
    local count = 0;
    local tab, varData;
    for regID, regData in pairs(reg) do
        for domain, data in pairs(regData) do
            if domain == "_RegObj" then continue; end

            if tabnet:IsRegistered(regID, domain) then
                tab = tabnet:GetTable(regID);
                for id, val in pairs(data) do
                    varData = tabnet:GetVariable(domain, id);
                    if !varData then continue; end

                    if varData.Public then
                        tab.TableNet[domain].Public[id] = val;
                    else
                        tab.TableNet[domain].Private[id] = val;
                    end
                end
            else
                tabnet:NewTable(domain, data, regData._RegObj, regID);
            end
            count = count + 1;
        end
    end

    MsgLog(LOG_TABNET, "Received %d objects from registry!", count);

    local ack = pck:Bool();
    if ack then
        sendRegAck();
    end
end);

-- Receive object updates.
vnet.Watch("CTableNet_Net_ObjUpdate", function(pck)
    local tabnet = bash.Util.GetPlugin("CTableNet");
    local registry = tabnet:GetRegistry();

    local regID = pck:String();
    local domain = pck:String();
    local data = pck:Table();
    local firstSend = pck:Bool();
    local obj;
    if pck:Bool() then
        obj = pck:Entity();
    end

    local domInfo = tabnet:GetDomain(domain);
    local tab, varData;
    if registry[regID] then
        tab = registry[regID];
        for id, val in pairs(data) do
            varData = tabnet:GetVariable(domain, id);
            if !varData then continue; end

            if varData.Public then
                tab.TableNet[domain].Public[id] = val;
            else
                tab.TableNet[domain].Private[id] = val;
            end
            hook.Run(Format("CTableNet_OnUpdate_%s_%s", domain, id), tab);
        end
    else
        tab = tabnet:NewTable(domain, data, obj, regID);
    end
end);

-- Receive a table deletion.
vnet.Watch("CTableNet_Net_ObjOutOfScope", function(pck)
    local regID = pck:String();
    local domain = pck:String();
    local tablenet = bash.Util.GetPlugin("CTableNet");
    tablenet:RemoveTable(regID, domain);
end);
