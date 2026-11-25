Store = {}
Spawned = {}
EntityIds = {}
StoreVersion = 0

local nearMarkers = {}

local function normalize(data)
    data.coords = vector3(data.coords.x, data.coords.y, data.coords.z)
    return data
end

local function despawn(id)
    local entity = Spawned[id]
    if not entity then return end
    Target.Remove(entity)
    if DoesEntityExist(entity) then
        DeleteEntity(entity)
    end
    Spawned[id] = nil
    EntityIds[entity] = nil
end

local function spawn(obj)
    local hash = Util.LoadModel(obj.model, obj.kind == 'marker' and Config.Markers.FallbackModel or nil)
    if not hash then return end
    if Store[obj.id] ~= obj or Spawned[obj.id] then
        SetModelAsNoLongerNeeded(hash)
        return
    end
    local info = Util.ModelInfo(hash)
    local c = obj.coords
    local entity = CreateObjectNoOffset(hash, c.x, c.y, c.z + info.base, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if entity == 0 then return end
    SetEntityHeading(entity, obj.heading)
    FreezeEntityPosition(entity, true)
    SetEntityInvincible(entity, true)
    obj.top = c.z + info.height
    Spawned[obj.id] = entity
    EntityIds[entity] = obj.id
    Target.Add(entity)
end

local function addObject(data)
    local obj = normalize(data)
    if Store[obj.id] then despawn(obj.id) end
    Store[obj.id] = obj
    StoreVersion = StoreVersion + 1
end

RegisterNetEvent('kipchak_crimescene:add', function(data)
    addObject(data)
end)

RegisterNetEvent('kipchak_crimescene:update', function(data)
    local obj = Store[data.id]
    if not obj then return end
    obj.note = data.note
    obj.link = data.link
    StoreVersion = StoreVersion + 1
end)

RegisterNetEvent('kipchak_crimescene:remove', function(ids)
    local removed = {}
    for _, id in ipairs(ids) do
        despawn(id)
        Store[id] = nil
        removed[id] = true
    end
    for _, obj in pairs(Store) do
        if obj.link and removed[obj.link] then
            obj.link = nil
        end
    end
    StoreVersion = StoreVersion + 1
end)

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do
        Wait(250)
    end
    local list = lib.callback.await('kipchak_crimescene:getAll', false)
    for _, data in ipairs(list or {}) do
        if not Store[data.id] then
            addObject(data)
        end
    end
end)

CreateThread(function()
    local distance = Config.Streaming.Distance
    local textDistance = Config.Markers.TextDistance
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        local toSpawn, near = {}, {}
        for id, obj in pairs(Store) do
            local dist = #(pos - obj.coords)
            if dist <= distance then
                if not Spawned[id] then
                    toSpawn[#toSpawn + 1] = obj
                end
                if obj.kind == 'marker' and dist <= textDistance then
                    near[#near + 1] = obj
                end
            elseif Spawned[id] and dist > distance + 10.0 then
                despawn(id)
            end
        end
        nearMarkers = near
        for _, obj in ipairs(toSpawn) do
            if Store[obj.id] == obj then
                spawn(obj)
            end
        end
        Wait(Config.Streaming.Interval)
    end
end)

CreateThread(function()
    local markers = Config.Markers
    while true do
        if #nearMarkers == 0 or not markers.Enabled then
            Wait(500)
        else
            local pos = GetEntityCoords(PlayerPedId())
            local closest, closestDist
            for _, obj in ipairs(nearMarkers) do
                if Store[obj.id] == obj then
                    local dist = #(pos - obj.coords)
                    if not closestDist or dist < closestDist then
                        closest, closestDist = obj, dist
                    end
                    local top = vector3(obj.coords.x, obj.coords.y, MarkerTextZ(obj.coords.z, obj.top))
                    Util.DrawText3D(top, tostring(obj.number), markers.TextScale, markers.TextColor)
                    if markers.Notes.Enabled and obj.note and dist <= markers.Notes.Distance then
                        Util.DrawText3D(top, obj.note, markers.TextScale * 0.6, markers.Notes.Color, 0.03)
                    end
                end
            end
            if markers.Info.Enabled and closest and closestDist <= markers.Info.Distance then
                local top = vector3(closest.coords.x, closest.coords.y, MarkerTextZ(closest.coords.z, closest.top))
                local offset = (markers.Notes.Enabled and closest.note) and 0.052 or 0.03
                Util.DrawText3D(top, L('info_officer', closest.ownerName or '?', closest.timeText or ''), markers.TextScale * 0.55, markers.Info.Color, offset)
            end
            Wait(0)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for id in pairs(Spawned) do
        despawn(id)
    end
end)
