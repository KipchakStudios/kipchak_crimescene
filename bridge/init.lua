Bridge = {}

local function isStarted(name)
    local state = GetResourceState(name)
    return state == 'started' or state == 'starting'
end

if IsDuplicityVersion() then
    local function detectFramework()
        if Config.Framework and Config.Framework ~= 'auto' then
            return Config.Framework
        end
        if isStarted('qbx_core') then return 'qbox' end
        if isStarted('qb-core') then return 'qbcore' end
        if isStarted('es_extended') then return 'esx' end
    end

    Bridge.Framework = detectFramework()

    function Bridge.GetIdentifier() end
    function Bridge.GetName(src) return GetPlayerName(src) or tostring(src) end
    function Bridge.GetJob() end
else
    local function detectTarget()
        if not Config.Target.Enabled then return end
        if Config.Target.System and Config.Target.System ~= 'auto' then
            return Config.Target.System
        end
        if isStarted('ox_target') then return 'ox' end
        if isStarted('qb-target') then return 'qb' end
    end

    Bridge.Target = detectTarget()

    Target = {
        Add = function() end,
        Remove = function() end
    }
end
