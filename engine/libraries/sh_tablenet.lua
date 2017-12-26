--[[
    Table Networking functionality.
]]

--
-- Local storage.
--

local bash = bash;

local LOG_TABNET = {pre = "[TABNET]", col = color_darkgreen};

local TABNET_META = {};
TABNET_META.__index = TABNET_META;

--
-- Global storage.
--

NET_PUBLIC = "Public";
NET_PRIVATE = "Private";
NET_GLOBAL = "Global";

bash.TableNet           = bash.TableNet or {};
bash.TableNet.Registry  = bash.TableNet.Registry or {};

--
-- Setup operations.
--

-- something

--
-- TableNet meta functions.
--

-- Getter for networked variables.
function TABNET_META:Get(id, def)
    if self.Data.Public[id] != nil then
        return self.Data.Public[id];
    elseif self.Data.Private[id] != nil then
        return self.Data.Private[id];
    else
        return def;
    end
end

-- Check to see if the table is global.
function TABNET_META:IsGlobal()
    return self.Listeners == NET_GLOBAL;
end

-- Check to see if a table has a particular listener.
function TABNET_META:HasListener(list, scope)
    if self:IsGlobal() then return true; end

    if scope then
        return self.Listeners[scope][list];
    else
        return self.Listeners.Public[list] or self.Listeners.Private[list];
    end
end

if SERVER then

    -- Setter for networked variables.
    function TABNET_META:Set(id, val, scope, network)
        -- TODO: Handle client-side requests for changes.

        scope = scope or NET_PUBLIC;
        self.Data[scope][id] = val;

        if network then
            -- TODO: Network to listeners.

            self:Network({[scope] = {[id] = val}});
        end
    end

    -- Multi-setter for networked variables.
    function TABNET_META:SetData(data)
        -- TODO: Handle client-side requests for changes.

        if !data.Public and !data.Private then return; end

        -- Silently make changes with data.
        for id, val in pairs(data.Public) do
            self:Set(id, val, NET_PUBLIC, false);
        end
        for id, val in pairs(data.Private) do
            self:Set(id, val, NET_PRIVATE, false);
        end

        -- TODO: Network to listeners.
        self:Network(data);
    end

    -- Network table's data to listeners.
    function TABNET_META:Network(changes)
        -- Don't network useless tables!
        if !self:IsGlobal() and table.IsEmpty(self.Listeners.Public) and table.IsEmpty(self.Listeners.Private) then
            bash.Util.MsgDebug(LOG_TABNET, "No network for %s!", self.RegistryID);
            return;
        end

        -- If we're only networking specific changes...
        if changes then

            -- If there are changes to the public data and valid public listeners...
            if changes.Public and !table.IsEmpty(changes.Public) and (self:IsGlobal() or !table.IsEmpty(self.Listeners.Public)) then
                local pubUpdate = vnet.CreatePacket("bash_Net_TableNetUpdate");
                pubUpdate:String(self.RegistryID);
                pubUpdate:String(NET_PUBLIC);
                pubUpdate:Table(changes.Public);

                if self:IsGlobal() then
                    pubUpdate:Broadcast();
                else
                    pubUpdate:AddTargets(self.Listeners.Public);
                    pubUpdate:Send();
                end
            end

            -- If there are changes to the private data and valid private listeners...
            if changes.Private and !table.IsEmpty(changes.Private) and !table.IsEmpty(self.Listeners.Private) then
                local privUpdate = vnet.CreatePacket("bash_Net_TableNetUpdate");
                privUpdate:String(self.RegistryID);
                privUpdate:String(NET_PRIVATE);
                privUpdate:Table(changes.Private);
                privUpdate:AddTargets(self.Listeners.Private);
                privUpdate:Send();
            end

        -- else, if we're networking the whole table...
        else

            -- If there is valid public data and public listeners...
            if !table.IsEmpty(self.Data.Public) and (self:IsGlobal() or !table.IsEmpty(self.Listeners.Public)) then
                local pubUpdate = vnet.CreatePacket("bash_Net_TableNetUpdate");
                pubUpdate:String(self.RegistryID);
                pubUpdate:String(NET_PUBLIC);
                pubUpdate:Table(self.Data.Public);

                if self:IsGlobal() then
                    pubUpdate:Broadcast();
                else
                    pubUpdate:AddTargets(self.Listeners.Public);
                    pubUpdate:Send();
                end
            end

            -- If there is valid private data and private listeners...
            if !table.IsEmpty(self.Data.Private) and !table.IsEmpty(self.Listeners.Private) then
                local privUpdate = vnet.CreatePacket("bash_Net_TableNetUpdate");
                privUpdate:String(self.RegistryID);
                privUpdate:String(NET_PRIVATE);
                privUpdate:Table(self.Data.Private);
                privUpdate:AddTargets(self.Listeners.Private);
                privUpdate:Send();
            end
        end
    end

    function TABNET_META:Send(list)
        if !self:HasListener(list) then return; end

        local send = vnet.CreatePacket("bash_Net_TableNetUpdate");
        send:String(self.RegistryID);
        if self:IsGlobal() or self.Listeners.Public[list] then
            send:String(NET_PUBLIC);
            send:Table(self.Data.Public);
        elseif self.Listeners.Private[list] then
            send:String(NET_PRIVATE);
            send:Table(self.Data.Private);
        end
        send:AddTargets(list);
        send:Send();
    end

    -- Add a listener to a table.
    function TABNET_META:AddListener(list, scope)
        scope = scope or NET_PUBLIC;
        self.Listeners[scope][list] = true;
    end

    -- Remove a listener from a table.
    function TABNET_META:RemoveListener(list, scope)
        if scope then
            self.Listeners[scope][list] = nil;
        else
            self.Listeners.Public[list] = nil;
            self.Listeners.Private[list] = nil;
        end
    end

    -- Remove all listeners from a table.
    function TABNET_META:RemoveListeners(scope)
        if scope then
            self.Listeners[scope] = {};
        else
            self.Listeners.Public = {};
            self.Listeners.Private = {};
        end
    end

    -- Change a table's global status, using the cache if requested.
    function TABNET_META:SetGlobal(global, useCache)
        if global then
            if useCache then
                self.ListenerCache = self.Listeners;
            end

            self.Listeners = NET_GLOBAL;
        else
            if useCache then
                self.Listeners = self.ListenerCache or {Public = {}, Private = {}};
            else
                self.Listeners = {Public = {}, Private = {}};
            end
        end
    end

end

--
-- TableNet functions.
--

function bash.TableNet.DeleteTable(id)
    local tab = bash.TableNet.Registry[id];
    if !tab then return; end

    bash.TableNet.Registry[id] = nil;
    bash.Util.MsgDebug(LOG_TABNET, "Deleting table '%s'!", id);

    if SERVER then
        local delUpdate = vnet.CreatePacket("bash_Net_TableNetDelete");
        delUpdate:String(id);
        delUpdate:Broadcast();
    end
end

if SERVER then

    -- Timed event to make sure only valid listeners have access to correct data.
    function bash.TableNet.ValidateListeners()
        -- TODO: This function.
    end
    timer.Create("bash_Timer_TableNetValidate", 60, 0, bash.TableNet.ValidateListeners);

    -- Hooked event to make sure newly-connected players get their tables.
    function bash.TableNet.SendTablesOnConnect(ply)
        bash.Util.MsgDebug(LOG_TABNET, "Sending tables to %s!", ply:Name());

        for id, tab in pairs(bash.TableNet.Registry) do
            if tab:HasListener(ply) then
                tab:Send(ply);
            end
        end
    end
    hook.Add("PlayerInit", "bash_TableNetOnConnect", bash.TableNet.SendTablesOnConnect);

elseif CLIENT then

    -- Watch for table updates.
    vnet.Watch("bash_Net_TableNetUpdate", function(pck)

    end);

    -- Watch for table deletions.
    vnet.Watch("bash_Net_TableNetDelete", function(pck)
        local id = pck:String();
        bash.TableNet.DeleteTable(id);
    end);

end
