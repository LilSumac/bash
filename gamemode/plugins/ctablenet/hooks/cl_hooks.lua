--[[
    CTableNet client hooks.
]]

-- Local functions.
local function sendRegAck()
    local ackPck = vnet.CreatePacket("CTableNet_Net_RegSendAck");
    ackPck:AddServer();
    ackPck:Send();
end

-- Network hooks.
vnet.Watch("CTableNet_Net_RegSend", function(pck)
    local tabnet = getService("CTableNet");
    local registry = tabnet:GetRegistry();

    local reg = pck:Table();
    PrintTable(reg);
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

    local ack = pck:Bool();
    if ack then
        sendRegAck();
    end
    -- Acknowledge registry send (maybe)
    -- DEBUG
    -- Show count
end);

vnet.Watch("CTableNet_Net_ObjUpdate", function(pck)
    local tabnet = getService("CTableNet");
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
        end
    else
        tab = tabnet:NewTable(domain, data, obj, regID);
    end
end);

vnet.Watch("CTableNet_Net_ObjOutOfScope", function(pck)
    local regID = pck:String();
    local domain = pck:String();
    local tablenet = getService("CTableNet");
    tablenet:RemoveTable(regID, domain);
end);
