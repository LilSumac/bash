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
NET_ALL = "All";

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
    if self.Data.Public and self.Data.Public[id] != nil then
        return self.Data.Public[id];
    elseif self.Data.Private and self.Data.Private[id] != nil then
        return self.Data.Private[id];
    else
        return def;
    end
end

-- Getter for keys with a certain value.
function TABNET_META:GetKeys(val)
    local keys, _keys = {};

    if self.Data.Public then
        _keys = table.KeysFromValue(self.Data.Public, val);
        table.Merge(keys, _keys);
    end

    if self.Data.Private then
        _keys = table.KeysFromValue(self.Data.Private, val);
        table.Merge(keys, _keys);
    end

    return keys;
end

-- Check to see if the table is global.
function TABNET_META:IsGlobal()
    return self.Listeners.Public == NET_GLOBAL;
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
    function TABNET_META:Set(id, val, scope)
        scope = scope or NET_PUBLIC;
        self:SetData{
            [scope] = {[id] = val}
        };

        --[[
        -- TODO: Handle client-side requests for changes.
        if !id then return; end

        scope = scope or NET_PUBLIC;
        self.Data[scope] = self.Data[scope] or {};
        self.Data[scope][id] = val;

        if !silent then
            self:Network({[scope] = {[id] = val}});
        end
        ]]
    end

    -- Multi-setter for networked variables.
    function TABNET_META:SetData(data)
        -- TODO: Handle client-side requests for changes.

        if !data.Public and !data.Private then return; end

        -- Silently make changes with data.
        local hookData = {};
        if data.Public then
            for id, val in pairs(data.Public) do
                self.Data.Public = self.Data.Public or {};
                self.Data.Public[id] = val;
                hookData[id] = val;
                --self:Set(id, val, NET_PUBLIC, true);
            end
        end
        if data.Private then
            for id, val in pairs(data.Private) do
                self.Data.Private = self.Data.Private or {};
                self.Data.Private[id] = val;
                hookData[id] = val;
                --self:Set(id, val, NET_PRIVATE, true);
            end
        end

        hook.Run("TableUpdate", self.RegistryID, hookData);

        -- TODO: Network to listeners.
        self:Network(data);
    end

    -- Delete an entry in a table.
    function TABNET_META:Delete(...)
        local ids = {...};
        if table.IsEmpty(ids) then return; end

        local hookData = {};
        for _, id in pairs(ids) do
            if self.Data.Public then
                hookData[id] = self.Data.Public[id];
                self.Data.Public[id] = nil;
            end
            if self.Data.Private then
                hookData[id] = self.Data.Private[id];
                self.Data.Private[id] = nil;
            end
        end

        hook.Run("TableDeleteEntry", self.RegistryID, hookData);

        local delUpdate = vnet.CreatePacket("bash_Net_TableNetDeleteEntry");
        delUpdate:String(self.RegistryID);
        delUpdate:Table(ids);
        delUpdate:Broadcast();
    end

    -- Network table's data to listeners.
    function TABNET_META:Network(changes)
        -- Don't network useless tables!
        if !self:IsGlobal() and table.IsEmpty(self.Listeners.Public) and table.IsEmpty(self.Listeners.Private) then
            bash.Util.MsgDebug(LOG_TABNET, "No network for '%s'!", self.RegistryID);
            return;
        end

        -- TODO: WHY. Ugh.
        self:CleanListeners();

        -- If we're only networking specific changes...
        if changes then

            -- If there are changes to the public data and valid public listeners...
            if changes.Public and !table.IsEmpty(changes.Public) and (self:IsGlobal() or !table.IsEmpty(self.Listeners.Public) or !table.IsEmpty(self.Listeners.Private)) then
                local pubUpdate = vnet.CreatePacket("bash_Net_TableNetUpdate");
                pubUpdate:String(self.RegistryID);
                pubUpdate:Table({Public = changes.Public});

                if self:IsGlobal() then
                    pubUpdate:Broadcast();
                else
                    pubUpdate:AddTargets(self.Listeners.Public);
                    pubUpdate:AddTargets(self.Listeners.Private);
                    pubUpdate:Send();
                end
            end

            -- If there are changes to the private data and valid private listeners...
            if changes.Private and !table.IsEmpty(changes.Private) and !table.IsEmpty(self.Listeners.Private) then
                local privUpdate = vnet.CreatePacket("bash_Net_TableNetUpdate");
                privUpdate:String(self.RegistryID);
                privUpdate:Table({Private = changes.Private});
                privUpdate:AddTargets(self.Listeners.Private);
                privUpdate:Send();
            end

        -- else, if we're networking the whole table...
        else

            -- If there is valid public data and public listeners...
            if !table.IsEmpty(self.Data.Public) and (self:IsGlobal() or !table.IsEmpty(self.Listeners.Public) or !table.IsEmpty(self.Listeners.Private)) then
                local pubUpdate = vnet.CreatePacket("bash_Net_TableNetUpdate");
                pubUpdate:String(self.RegistryID);
                pubUpdate:Table({Public = self.Data.Public});

                if self:IsGlobal() then
                    pubUpdate:Broadcast();
                else
                    pubUpdate:AddTargets(self.Listeners.Public);
                    pubUpdate:AddTargets(self.Listeners.Private);
                    pubUpdate:Send();
                end
            end

            -- If there is valid private data and private listeners...
            if !table.IsEmpty(self.Data.Private) and !table.IsEmpty(self.Listeners.Private) then
                local privUpdate = vnet.CreatePacket("bash_Net_TableNetUpdate");
                privUpdate:String(self.RegistryID);
                privUpdate:Table({Private = self.Data.Private});
                privUpdate:AddTargets(self.Listeners.Private);
                privUpdate:Send();
            end
        end
    end

    -- Send an entire table to a specific client.
    function TABNET_META:Send(list)
        if !self:HasListener(list) then return; end
        if !isplayer(list) then return; end

        -- TODO: WHY. Ugh.
        self:CleanListeners();

        local send = vnet.CreatePacket("bash_Net_TableNetUpdate");
        local data = {};
        send:String(self.RegistryID);

        if self.Listeners.Private[list] then
            data.Public = self.Data.Public;
            data.Private = self.Data.Private;
        elseif self:IsGlobal() or self.Listeners.Public[list] then
            data.Public = self.Data.Public;
        end

        send:Table(data);
        send:AddTargets(list);
        send:Send();
        bash.Util.MsgDebug(LOG_TABNET, "Sending networked table '%s' to '%s'!", self.RegistryID, list:Name());
    end

    -- Send a deletion notice to a specific client.
    function TABNET_META:RemoveFrom(list, scope)
        if !isplayer(list) then return; end

        scope = scope or NET_ALL;
        local del = vnet.CreatePacket("bash_Net_TableNetDelete");
        del:String(self.RegistryID);
        del:String(scope);
        del:AddTargets(list);
        del:Send();
    end

    -- Add a listener to a table.
    function TABNET_META:AddListener(list, scope, silent)
        if !isplayer(list) then return; end

        scope = scope or NET_PUBLIC;
        if self:IsGlobal() and scope == NET_PUBLIC then return; end
        if self.Listeners[scope][list] then return; end

        bash.Util.MsgDebug(LOG_TABNET, "Adding player '%s' to '%s' listeners for networked table '%s'...", tostring(list), scope, self.RegistryID);

        self.Listeners[scope][list] = true;
        if scope == NET_PUBLIC then
            self.Listeners.Private[list] = nil;
            self:RemoveFrom(list, NET_PRIVATE);
        elseif scope == NET_PRIVATE and !self:IsGlobal() then
            self.Listeners.Public[list] = nil;
        end

        if !silent then
            self:Send(list);
        end
    end

    -- Remove a listener from a table.
    function TABNET_META:RemoveListener(list, scope, silent)
        if !isplayer(list) then return; end

        scope = scope or NET_ALL;
        if self:IsGlobal() and scope != NET_PRIVATE then return; end

        bash.Util.MsgDebug(LOG_TABNET, "Removing player '%s' from '%s' listeners for networked table '%s'...", tostring(list), scope, self.RegistryID);
        if scope == NET_ALL then
            self.Listeners.Public[list] = nil;
            self.Listeners.Private[list] = nil;
        else
            self.Listeners[scope][list] = nil;
        end

        if !silent then
            self:RemoveFrom(list, scope);
        end
    end

    -- Remove all listeners from a table.
    function TABNET_META:RemoveListeners(scope)
        if self:IsGlobal() and scope != NET_PRIVATE then return; end

        local del = vnet.CreatePacket("bash_Net_TableNetDelete");
        del:String(self.RegistryID);
        if scope then
            bash.Util.MsgDebug(LOG_TABNET, "Removing all '%s' listeners from networked table '%s'...", scope, self.RegistryID);
            del:String(scope);
            del:AddTargets(self.Listeners[scope]);
            del:Send();

            self.Listeners[scope] = {};
        else
            bash.Util.MsgDebug(LOG_TABNET, "Removing all listeners from networked table '%s'...", self.RegistryID);

            del:String(NET_ALL);
            del:Broadcast();

            self.Listeners.Public = {};
            self.Listeners.Private = {};
        end
    end

    -- Checks to see if there are any NULL listeners, and removes them.
    function TABNET_META:CleanListeners()
        if !self:IsGlobal() then
            for ply, _ in pairs(self.Listeners.Public) do
                if !ply:IsValid() then
                    bash.Util.MsgDebug(LOG_TABNET, "Removing NULL 'Public' listener from networked table '%s'...", self.RegistryID);
                    self.Listeners.Public[ply] = nil;
                end
            end
        end
        for ply, _ in pairs(self.Listeners.Private) do
            if !ply:IsValid() then
                bash.Util.MsgDebug(LOG_TABNET, "Removing NULL 'Private' listener from networked table '%s'...", self.RegistryID);
                self.Listeners.Private[ply] = nil;
            end
        end
    end

    -- Change a table's global status.
    function TABNET_META:SetGlobal(global)
        if global == self:IsGlobal() then return; end

        bash.Util.MsgDebug(LOG_TABNET, "Making networked table '%s' %s...", self.RegistryID, global and "global" or "non-global");
        if global then
            self.Listeners.Public = NET_GLOBAL;

            local send = vnet.CreatePacket("bash_Net_TableNetUpdate");
            send:String(self.RegistryID);
            send:Table({Public = self.Data.Public});
            send:Broadcast();
        else
            self.Listeners.Public = {};

            local del = vnet.CreatePacket("bash_Net_TableNetDelete");
            del:String(self.RegistryID);
            del:String(NET_PUBLIC);
            del:Broadcast();
        end
    end

end

--
-- TableNet functions.
--

-- Create a new networked table.
function bash.TableNet.NewTable(data, list, idOverride)
    local tab = {};
    setmetatable(tab, TABNET_META);

    -- TODO: Random string for ID.
    local id = idOverride;
    if !id then
        repeat
            id = string.random(8);
        until !bash.TableNet.Registry[id];
    end

    tab.RegistryID = id;
    tab.Data = {
        Public = data and data.Public or nil,
        Private = data and data.Private or nil
    };

    if SERVER then
        if list == NET_GLOBAL then
            tab.Listeners = {
                Public = NET_GLOBAL,
                Private = {}
            };
        else
            tab.Listeners = {
                Public = (list and list.Public) or {},
                Private = (list and list.Private) or {}
            };
        end
    end

    bash.TableNet.Registry[tab.RegistryID] = tab;
    bash.Util.MsgDebug(LOG_TABNET, "Creating networked table with ID '%s'!", tab.RegistryID);
    hook.Run("TableCreate", tab.RegistryID, tab);

    if SERVER then tab:Network(); end

    return tab;
end

-- Delete an existing networked table from the registry.
-- All references to this table must be squashed as well.
function bash.TableNet.DeleteTable(id)
    local tab = bash.TableNet.Registry[id];
    if !tab then return; end

    hook.Run("TableDelete", id, tab);
    bash.TableNet.Registry[id] = nil;
    bash.Util.MsgDebug(LOG_TABNET, "Deleting networked table with ID '%s'!", id);

    if SERVER then
        local delUpdate = vnet.CreatePacket("bash_Net_TableNetDelete");
        delUpdate:String(id);
        delUpdate:String(NET_ALL);
        delUpdate:Broadcast();
    end
end

-- Check to see if a table with a particular ID has been registered.
function bash.TableNet.IsRegistered(id)
    return bash.TableNet.Registry[id] != nil;
end

-- Get a table with a particular ID from the registry.
function bash.TableNet.Get(id)
    return bash.TableNet.Registry[id];
end

if SERVER then

    -- Timed event to make sure only valid listeners have access to correct data.
    function bash.TableNet.ValidateListeners()
        bash.Util.MsgDebug(LOG_TABNET, "Checking for network ghosts...");

        local ghosts, delGhosts;
        for id, tab in pairs(bash.TableNet.Registry) do
            ghosts = bash.Player.GetAllAsKeys();

            if !tab:IsGlobal() then
                for ply, _ in pairs(tab.Listeners.Public) do
                    if !ply:IsValid() then
                        bash.Util.MsgDebug(LOG_TABNET, "Found NULL player in 'Public' listeners for networked table '%s'! Removing...", id);
                        tab.Listeners.Public[ply] = nil;
                    else
                        ghosts[ply] = nil;
                    end
                end
            end

            for ply, _ in pairs(tab.Listeners.Private) do
                if !ply:IsValid() then
                    bash.Util.MsgDebug(LOG_TABNET, "Found NULL player in 'Private' listeners for networked table '%s'! Removing...", id);
                    tab.Listeners.Private[ply] = nil;
                else
                    ghosts[ply] = nil;
                end
            end

            if !table.IsEmpty(ghosts) then
                delGhosts = vnet.CreatePacket("bash_Net_TableNetDelete");
                delGhosts:String(id);
                delGhosts:String(NET_ALL);
                delGhosts:AddTargets(ghosts);
                delGhosts:Send();
            end
        end

        bash.Util.MsgDebug(LOG_TABNET, "Ghost check complete.");
    end
    timer.Create("bash_Timer_TableNetValidate", 300, 0, bash.TableNet.ValidateListeners);

    --
    -- Engine hooks.
    --

    -- Hooked event to make sure newly-connected players get their tables.
    function bash.TableNet.SendTablesOnConnect(ply)
        for id, tab in pairs(bash.TableNet.Registry) do
            if tab:HasListener(ply) then
                tab:Send(ply);
            end
        end
    end
    hook.Add("PlayerInit", "bash_TableNetOnConnect", bash.TableNet.SendTablesOnConnect);

    --[[ TODO: Come back to this, find out why it's not working.
    hook.Add("EntityRemoved", "bash_TableNetDeleteListenerOnRemove", function(ent)
        if !isplayer(ent) then return; end
        MsgN(ent);
        for regID, tab in pairs(bash.TableNet.Registry) do
            MsgN(regID);
            MsgN(tab:IsGlobal());
            if !tab:IsGlobal() then
                MsgN("REMOVING PUBLIC");
                bash.TableNet.Registry[regID].Listeners.Public[ent] = nil;
                MsgN("LOOKIT: ", tostring(bash.TableNet.Registry[regID].Listeners.Public[ent]));
            end
            bash.TableNet.Registry[regID].Listeners.Private[ent] = nil;
        end
        MsgN(ent);
        PrintTable(bash.TableNet.Registry);
    end);
    ]]

elseif CLIENT then

    --
    -- Network hooks.
    --

    -- Watch for table updates.
    vnet.Watch("bash_Net_TableNetUpdate", function(pck)
        local regID = pck:String();
        local data = pck:Table();

        bash.Util.MsgDebug(LOG_TABNET, "Receiving updates from networked table '%s'...", regID);

        if !bash.TableNet.IsRegistered(regID) then
            bash.TableNet.NewTable(data, nil, regID);
            hook.Run("TableCreate", regID, data);
        else
            local tab = bash.TableNet.Get(regID);
            if !tab then return; end

            if data.Public then
                tab.Data.Public = tab.Data.Public or {};
                for id, val in pairs(data.Public) do
                    tab.Data.Public[id] = val;
                end
            end
            if data.Private then
                tab.Data.Private = tab.Data.Private or {};
                for id, val in pairs(data.Private) do
                    tab.Data.Private[id] = val;
                end
            end
        end

        -- TODO: Figure out a better way of hooking this?
        local hookData = {};
        table.Merge(hookData, data.Public or {});
        table.Merge(hookData, data.Private or {});
        hook.Run("TableUpdate", regID, hookData);
    end);

    -- Watch for table entry deletions.
    vnet.Watch("bash_Net_TableNetDeleteEntry", function(pck)
        local regID = pck:String();
        local ids = pck:Table();
        local tab = bash.TableNet.Get(regID);
        if !tab then return end;

        bash.Util.MsgDebug(LOG_TABNET, "Deleting %d entries in networked table '%s'...", #ids, regID);

        local hookData = {};
        for _, id in pairs(ids) do
            if tab.Data.Public then
                hookData[id] = tab.Data.Public[id];
                tab.Data.Public[id] = nil;
            end
            if tab.Data.Private then
                hookData[id] = tab.Data.Private[id];
                tab.Data.Private[id] = nil
            end
        end

        hook.Run("TableDeleteEntry", regID, hookData);
    end);

    -- Watch for table deletions.
    vnet.Watch("bash_Net_TableNetDelete", function(pck)
        local id = pck:String();
        local scope = pck:String();

        if scope == NET_ALL then
            bash.TableNet.DeleteTable(id);
        else
            local tab = bash.TableNet.Get(id);
            if !tab then return; end
            if tab.Data.Private and scope == NET_PUBLIC then return; end

            tab.Data[scope] = nil;
            if !tab.Data.Public and !tab.Data.Private then
                bash.TableNet.DeleteTable(id);
            end
        end
    end);

end
