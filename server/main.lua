local lastPlace = {}
local rate = {}

local FATAL = {
    no_permission = true,
    limit_player = true,
    limit_scene = true,
    limit_total = true,
    limit_tape = true,
    disabled = true
}

local function notify(src, message, kind)
    TriggerClientEvent('ox_lib:notify', src, { title = L('title'), description = message, type = kind or 'inform' })
end

local function sendLog(kind, title, description)
    if not Config.Logs.Enabled or not Config.Logs[kind] or SvConfig.Webhook == '' then return end
    PerformHttpRequest(SvConfig.Webhook, function() end, 'POST', json.encode({
        username = SvConfig.LogName,
        embeds = { {
            title = title,
            description = description,
            color = SvConfig.LogColor,
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
        } }
    }), { ['Content-Type'] = 'application/json' })
end

local function getAccess(src)
    local access = { allowed = false, removeOthers = false, clear = false }
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return access end
    access.identifier = identifier

    if Config.Permissions.AdminAce and IsPlayerAceAllowed(src, Config.Permissions.AdminAce) then
        access.allowed, access.removeOthers, access.clear = true, true, true
        return access
    end

    local job, grade, onDuty = Bridge.GetJob(src)
    local minGrade = job and Config.AllowedJobs[job]
    if not minGrade or (grade or 0) < minGrade then return access end
    if Config.RequireOnDuty and not onDuty then return access end

    access.allowed = true
    access.removeOthers = grade >= Config.Permissions.RemoveOthersGrade
    access.clear = grade >= Config.Permissions.ClearSceneGrade
    return access
end

local function allowRate(src)
    local now = GetGameTimer()
    local entry = rate[src]
    if not entry or now - entry.start >= Config.Limits.RateLimit.Window * 1000 then
        entry = { start = now, count = 0 }
        rate[src] = entry
    end
    entry.count = entry.count + 1
    return entry.count <= Config.Limits.RateLimit.Count
end

local function isNumber(v)
    return type(v) == 'number' and v == v and v ~= math.huge and v ~= -math.huge
end

local function readCoords(c)
    local t = type(c)
    if t ~= 'vector3' and t ~= 'table' then return end
    if not isNumber(c.x) or not isNumber(c.y) or not isNumber(c.z) then return end
    return vector3(c.x, c.y, c.z)
end

local function playerCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    return GetEntityCoords(ped)
end

local function sanitizeNote(note)
    if type(note) ~= 'string' then return nil end
    note = note:gsub('[%c~<>\\^]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    if note == '' then return nil end
    if #note > Config.Markers.Notes.MaxLength then
        note = note:sub(1, Config.Markers.Notes.MaxLength)
        while #note > 0 and not utf8.len(note) do
            note = note:sub(1, -2)
        end
    end
    return note
end

local function canManage(access, obj)
    return obj.owner == access.identifier or access.removeOthers
end

local function inReach(src, coords)
    local pos = playerCoords(src)
    return pos and #(pos - coords) <= Config.Permissions.InteractDistance + 2.0
end

local markerModels = {}
markerModels[Config.Markers.Model] = true
for _, model in pairs(Config.Markers.Models) do
    markerModels[model] = true
end

local propModels = {}
for _, prop in ipairs(Config.Props) do
    propModels[prop.model] = true
end

local function kindEnabled(kind)
    if kind == 'marker' then return Config.Menu.Marker and Config.Markers.Enabled end
    if kind == 'pole' then return Config.Menu.Tape and Config.Tape.Enabled end
    if kind == 'prop' then return Config.Menu.Props and #Config.Props > 0 end
    return false
end

local function modelAllowed(kind, model)
    if type(model) ~= 'string' then return false end
    if kind == 'marker' then return markerModels[model] == true end
    if kind == 'pole' then return model == Config.Tape.PoleModel end
    if kind == 'prop' then return propModels[model] == true end
    return false
end

local function place(src, data)
    local access = getAccess(src)
    if not access.allowed then return false, 'no_permission' end
    if type(data) ~= 'table' then return false, 'invalid' end

    local kind = data.kind
    if not kindEnabled(kind) then return false, 'disabled' end
    if not modelAllowed(kind, data.model) then return false, 'invalid_model' end

    local coords = readCoords(data.coords)
    if not coords or not isNumber(data.heading) then return false, 'invalid' end

    local pos = playerCoords(src)
    if not pos or #(pos - coords) > Config.Placement.MaxDistance + 3.0 then return false, 'too_far' end

    local now = GetGameTimer()
    if lastPlace[src] and now - lastPlace[src] < Config.Limits.PlaceCooldown then return false, 'cooldown' end
    if not allowRate(src) then return false, 'rate_limit' end

    if Scene.Count(function(obj) return obj.owner == access.identifier end) >= Config.Limits.MaxPerPlayer then
        return false, 'limit_player'
    end
    if Scene.Count(function() return true end) >= Config.Limits.MaxTotal then
        return false, 'limit_total'
    end

    local obj = {
        kind = kind,
        model = data.model,
        coords = coords,
        heading = data.heading % 360.0,
        owner = access.identifier,
        ownerName = Bridge.GetName(src)
    }

    if kind == 'marker' then
        if Scene.MarkersInScene(coords) >= Config.Limits.MaxMarkersPerScene then return false, 'limit_scene' end
        obj.number = Scene.NextNumber(coords)
        obj.model = MarkerModel(obj.number)
        if Config.Markers.Notes.Enabled then
            obj.note = sanitizeNote(data.note)
        end
    elseif kind == 'pole' then
        if data.link ~= nil then
            local prev = Scene.Get(tonumber(data.link))
            if not prev or prev.kind ~= 'pole' or prev.owner ~= access.identifier or Scene.HasChild(prev.id) then
                return false, 'invalid'
            end
            if #(prev.coords - coords) > Config.Tape.MaxSegment + 0.5 then return false, 'too_long' end
            if Scene.Count(function(o) return o.kind == 'pole' and o.tape == prev.tape end) >= Config.Tape.MaxPolesPerTape then
                return false, 'limit_tape'
            end
            obj.link = prev.id
            obj.tape = prev.tape
            obj.style = prev.style
        else
            obj.style = Config.Tape.Styles[data.style] and data.style or Config.Tape.DefaultStyle
        end
    end

    lastPlace[src] = now
    Scene.Add(obj)

    if kind == 'marker' then
        TriggerEvent('kipchak_crimescene:markerPlaced', Scene.Api(obj), src)
    end

    sendLog('Place', L('log_place_title'), L('log_place', obj.ownerName, src, kind, obj.model, obj.number or '-', obj.coords.x, obj.coords.y, obj.coords.z))
    return true, obj.id, obj.number
end

lib.callback.register('kipchak_crimescene:getAll', function()
    local list = {}
    for _, obj in pairs(Scene.All()) do
        list[#list + 1] = Scene.Public(obj)
    end
    return list
end)

lib.callback.register('kipchak_crimescene:getAccess', function(src)
    local access = getAccess(src)
    return {
        allowed = access.allowed,
        removeOthers = access.removeOthers,
        clear = access.clear,
        tag = access.identifier and Scene.OwnerTag(access.identifier)
    }
end)

lib.callback.register('kipchak_crimescene:nextNumber', function(src)
    local pos = playerCoords(src)
    if not pos then return 1 end
    return Scene.NextNumber(pos)
end)

lib.callback.register('kipchak_crimescene:place', function(src, data)
    local ok, result, number = place(src, data)
    if not ok then return false, result, FATAL[result] == true end
    return true, result, number
end)

lib.callback.register('kipchak_crimescene:closeTape', function(src, firstId, lastId)
    local access = getAccess(src)
    if not access.allowed then return false, 'no_permission' end
    if not allowRate(src) then return false, 'rate_limit' end

    local first, last = Scene.Get(tonumber(firstId)), Scene.Get(tonumber(lastId))
    if not first or not last or first == last then return false, 'invalid' end
    if first.kind ~= 'pole' or last.kind ~= 'pole' or first.tape ~= last.tape then return false, 'invalid' end
    if first.owner ~= access.identifier or first.link or Scene.HasChild(last.id) then return false, 'invalid' end
    if Scene.Count(function(o) return o.kind == 'pole' and o.tape == first.tape end) < 3 then return false, 'tape_short' end
    if #(first.coords - last.coords) > Config.Tape.MaxSegment + 0.5 then return false, 'too_long' end

    first.link = last.id
    Scene.Update(first)
    return true
end)

lib.callback.register('kipchak_crimescene:remove', function(src, id)
    local access = getAccess(src)
    if not access.allowed then return false, 'no_permission' end
    if not allowRate(src) then return false, 'rate_limit' end

    local obj = Scene.Get(tonumber(id))
    if not obj then return false, 'not_found' end
    if not canManage(access, obj) then return false, 'not_owner' end
    if not inReach(src, obj.coords) then return false, 'too_far' end

    Scene.RemoveMany({ obj.id }, 'removed', src)
    sendLog('Remove', L('log_remove_title'), L('log_remove', Bridge.GetName(src), src, obj.kind, obj.model, obj.number or '-', obj.ownerName))
    return true
end)

lib.callback.register('kipchak_crimescene:setNote', function(src, id, note)
    if not Config.Markers.Notes.Enabled then return false, 'disabled' end
    local access = getAccess(src)
    if not access.allowed then return false, 'no_permission' end
    if not allowRate(src) then return false, 'rate_limit' end

    local obj = Scene.Get(tonumber(id))
    if not obj or obj.kind ~= 'marker' then return false, 'not_found' end
    if not canManage(access, obj) then return false, 'not_owner' end
    if not inReach(src, obj.coords) then return false, 'too_far' end

    obj.note = sanitizeNote(note)
    Scene.Update(obj)
    return true
end)

local function clearArea(src, access, radius)
    local pos = playerCoords(src)
    if not pos then return 0 end
    local ids, sceneIds, seen = {}, {}, {}
    for id, obj in pairs(Scene.All()) do
        if #(obj.coords - pos) <= radius then
            ids[#ids + 1] = id
            if not seen[obj.sceneId] then
                seen[obj.sceneId] = true
                sceneIds[#sceneIds + 1] = obj.sceneId
            end
        end
    end
    local removed = Scene.RemoveMany(ids, 'cleared', src)
    if #removed > 0 then
        TriggerEvent('kipchak_crimescene:sceneCleared', { mode = 'radius', coords = pos, radius = radius, sceneIds = sceneIds, count = #removed, owner = access.identifier }, src)
        sendLog('Clear', L('log_clear_title'), L('log_clear_radius', Bridge.GetName(src), src, #removed, radius, pos.x, pos.y, pos.z))
    end
    return #removed
end

local function clearOwn(src, access)
    local ids, sceneIds, seen = {}, {}, {}
    for id, obj in pairs(Scene.All()) do
        if obj.owner == access.identifier then
            ids[#ids + 1] = id
            if not seen[obj.sceneId] then
                seen[obj.sceneId] = true
                sceneIds[#sceneIds + 1] = obj.sceneId
            end
        end
    end
    local removed = Scene.RemoveMany(ids, 'cleared', src)
    if #removed > 0 then
        TriggerEvent('kipchak_crimescene:sceneCleared', { mode = 'own', sceneIds = sceneIds, count = #removed, owner = access.identifier }, src)
        sendLog('Clear', L('log_clear_title'), L('log_clear_own', Bridge.GetName(src), src, #removed))
    end
    return #removed
end

lib.callback.register('kipchak_crimescene:clear', function(src, mode, radius)
    if not Config.Menu.Clear then return false, 'disabled' end
    local access = getAccess(src)
    if not access.allowed then return false, 'no_permission' end
    if not allowRate(src) then return false, 'rate_limit' end

    if mode == 'own' then
        return true, clearOwn(src, access)
    elseif mode == 'radius' then
        if not access.clear then return false, 'no_permission' end
        radius = tonumber(radius)
        if not isNumber(radius) or radius <= 0 then return false, 'invalid' end
        return true, clearArea(src, access, math.min(radius, Config.Permissions.MaxClearRadius))
    end
    return false, 'invalid'
end)

if Config.Commands.ClearScene.Enabled then
    RegisterCommand(Config.Commands.ClearScene.Name, function(src, args)
        if src <= 0 then return end
        local access = getAccess(src)
        if not access.allowed or not access.clear then
            notify(src, L('err_no_permission'), 'error')
            return
        end
        if not allowRate(src) then
            notify(src, L('err_rate_limit'), 'error')
            return
        end
        local radius = tonumber(args[1]) or Config.Scene.Radius
        if not isNumber(radius) or radius <= 0 then
            notify(src, L('err_invalid'), 'error')
            return
        end
        radius = math.min(radius, Config.Permissions.MaxClearRadius)
        notify(src, L('cleared', clearArea(src, access, radius)), 'success')
    end, false)
end

AddEventHandler('playerDropped', function()
    lastPlace[source] = nil
    rate[source] = nil
end)
