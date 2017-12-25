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
    local pluginHooks = bash.Plugin.HookCache[hookID];
    if pluginHooks then
        -- TODO: Call plugin hooks.
    end

    if SCHEMA and SCHEMA[hookID] then
        -- TODO: Call schema hook.
    end

    -- TODO: Do other stuff.
end
