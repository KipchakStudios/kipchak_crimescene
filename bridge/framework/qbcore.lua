if Bridge.Framework ~= 'qbcore' then return end

local QBCore = exports['qb-core']:GetCoreObject()

local function getPlayer(src)
    return QBCore.Functions.GetPlayer(src)
end

function Bridge.GetIdentifier(src)
    local player = getPlayer(src)
    return player and player.PlayerData.citizenid
end

function Bridge.GetName(src)
    local player = getPlayer(src)
    if not player then return GetPlayerName(src) or tostring(src) end
    local info = player.PlayerData.charinfo
    return ('%s %s'):format(info.firstname, info.lastname)
end

function Bridge.GetJob(src)
    local player = getPlayer(src)
    if not player then return end
    local job = player.PlayerData.job
    return job.name, job.grade and job.grade.level or 0, job.onduty == true
end
