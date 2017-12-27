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

-- Getter for key with a certain value.
function TABNET_META:GetKey(val, def)
    local key;
    if self.Data.Public then
        key = table.KeyFromValue(self.Data.Public, val);
    end
    if key then return key; end

    if self.Data.Private then
        key = table.KeyFromValue(self.Data.Private, val);
    end
    if key then return key; end

    return def;
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
    function TABNET_META:Set(id, val, scope, silent)
        -- TODO: Handle client-side requests for changes.
        if !id then return; end

        scope = scope or NET_PUBLIC;
        self.Data[scope] = self.Data[scope] or {};
        self.Data[scope][id] = val;

        if !silent then
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

    -- Delete an entry in a table.
    function TABNET_META:Delete(id, silent)
        local recips, scope = {};
        if self.Data.Public and self.Data.Public[id] then
            if self:IsGlobal() then recips = player.GetAll();
            else recips = self.Listeners.Public; end
            scope = NET_PUBLIC;
        elseif self.Data.Private and self.Data.Private[id] then
            recips = self.Listeners.Private;
            scope = NET_PRIVATE;
        else return; end

        if !silent then
            local delUpdate = vnet.CreatePacket("bash_Net_TableNetDeleteEntry");
            delUpdate:String(self.RegistryID);
            delUpdate:Variable(id);
            delUpdate:String(scope);
            delUpdate:AddTargets(recips);
            delUpdate:Send();
        end
    end

    -- Network table's data to listeners.
    function TABNET_META:Network(changes)
        -- Don't network useless tables!
        if !self:IsGlobal() and table.IsEmpty(self.Listeners.Public) and table.IsEmpty(self.Listeners.Private) then
            bash.Util.MsgDebug(LOG_TABNET, "No network for '%s'!", self.RegistryID);
            return;
        end

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
    function TABNET_META:AddListener(list, scope)
        if !isplayer(list) then return; end

        scope = scope or NET_PUBLIC;
        if self:IsGlobal() and scope == NET_PUBLIC then return; end
        if self.Listeners[scope][list] then return; end

        self.Listeners[scope][list] = true;
        if scope == NET_PUBLIC then
            self.Listeners.Private[list] = nil;
            self:RemoveFrom(list, NET_PRIVATE);
        elseif scope == NET_PRIVATE and !self:IsGlobal() then
            self.Listeners.Public[list] = nil;
        end

        self:Send(list);
    end

    -- Remove a listener from a table.
    function TABNET_META:RemoveListener(list, scope)
        if !isplayer(list) then return; end

        scope = scope or NET_ALL;
        if self:IsGlobal() and scope != NET_PRIVATE then return; end

        if scope == NET_ALL then
            self.Listeners.Public[list] = nil;
            self.Listeners.Private[list] = nil;
        else
            self.Listeners[scope][list] = nil;
        end

        self:RemoveFrom(list, scope);
    end

    -- Remove all listeners from a table.
    function TABNET_META:RemoveListeners(scope)
        if self:IsGlobal() and scope != NET_PRIVATE then return; end

        local del = vnet.CreatePacket("bash_Net_TableNetDelete");
        del:String(self.RegistryID);
        if scope then
            del:String(scope);
            del:AddTargets(self.Listeners[scope]);
            del:Send();

            self.Listeners[scope] = {};
        else
            del:String(NET_ALL);
            del:Broadcast();

            self.Listeners.Public = {};
            self.Listeners.Private = {};
        end
    end

    -- Change a table's global status.
    function TABNET_META:SetGlobal(global)
        if global == self:IsGlobal() then return; end

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

    if SERVER then tab:Network(); end

    return tab;
end

-- Delete an existing networked table from the registry.
-- All references to this table must be squashed as well.
function bash.TableNet.DeleteTable(id)
    local tab = bash.TableNet.Registry[id];
    if !tab then return; end

    bash.TableNet.Registry[id] = nil;
    bash.Util.MsgDebug(LOG_TABNET, "Deleting networked table with ID '%s'!", id);
    hook.Run("TableDelete", id);

    if SERVER then
        local delUpdate = vnet.CreatePacket("bash_Net_TableNetDelete");
        delUpdate:String(id);
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
            if tab:IsGlobal() then continue; end

            ghosts = bash.Player.GetAllAsKeys();
            for _, ply in pairs(tab.Listeners.Public) do
                ghosts[ply] = nil;
            end
            for _, ply in pairs(tab.Listeners.Private) do
                ghosts[ply] = nil;
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

elseif CLIENT then

    --
    -- Network hooks.
    --

    -- Watch for table updates.
    vnet.Watch("bash_Net_TableNetUpdate", function(pck)
        local regID = pck:String();
        local data = pck:Table();

        bash.Util.MsgDebug(LOG_TABNET, "Receiving updates from networked table '%s'...", regID);
        -- TODO: Figure out a better way of hooking this?

        if !bash.TableNet.IsRegistered(regID) then
            bash.TableNet.NewTable(data, nil, regID);

            if data.Public then
                for id, val in pairs(data.Public) do
                    hook.Run("TableUpdate", regID, id, val);
                end
            end
            if data.Private then
                for id, val in pairs(data.Private) do
                    hook.Run("TableUpdate", regID, id, val);
                end
            end
        else
            local tab = bash.TableNet.Get(regID);
            if !tab then return; end

            if data.Public then
                tab.Data.Public = tab.Data.Public or {};

                for id, val in pairs(data.Public) do
                    tab.Data.Public[id] = val;
                    hook.Run("TableUpdate", regID, id, val);
                end
            end
            if data.Private then
                tab.Data.Private = tab.Data.Private or {};

                for id, val in pairs(data.Private) do
                    tab.Data.Private[id] = val;
                    hook.Run("TableUpdate", regID, id, val);
                end
            end
        end
    end);

    -- Watch for table entry deletions.
    vnet.Watch("bash_Net_TableNetDeleteEntry", function(pck)
        local regID = pck:String();
        local id = pck:Variable();
        local scope = pck:String();
        local tab = bash.TableNet.Get(regID);

        if !tab then return; end

        bash.Util.MsgDebug(LOG_TABNET, "Deleting entry '%s' in networked table '%s'...", id, regID);
        tab.Data[scope][id] = nil;
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
