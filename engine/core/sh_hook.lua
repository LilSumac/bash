--[[
    Hook library functions.
]]

--
-- Local storage.
--

local bash = bash;
local hook = hook;

--
-- Hook functions.
--

-- Old hook.Call function.
hook.CallEngine = hook.CallEngine or hook.Call;

-- New hook.Call function for plugins and schema.
function hook.Call(hookID, gm, ...)
    local pluginHooks = bash.Plugins.HookCache[hookID];
    local success, result;
    if pluginHooks then
        for plugin, func in pairs(pluginHooks) do
            success, result = pcall(func, plugin, ...);
            if success then
                result = {result};
                if #result > 0 then
                    return unpack(result);
                end
            else
                bash.Util.MsgErr("HookError", hookID, plugin.UniqueID, result);
            end
        end
    end

    if SCHEMA and SCHEMA[hookID] then
        success, result = pcall(SCHEMA[hookID], SCHEMA, ...);
        if success then
            result = {result};
            if #result > 0 then
                return unpack(result);
            end
        else
            bash.Util.MsgErr("HookError", hookID, SCHEMA.Name, result);
        end
    end

    hook.CallEngine(hookID, gm, ...);
end
