Scene = {}

local KVP_KEY = 'kipchak_crimescene:data'

local objects = {}
local scenes = {}
local nextId = 1
local nextSceneId = 1
local saveQueued = false
local salt = ('%d:%d'):format(os.time(), math.random(100000, 999999))

local function toVector(c)
    return vector3(c.x + 0.0, c.y + 0.0, c.z + 0.0)
end

local function plain(v)
    return { x = v.x, y = v.y, z = v.z }
end

function Scene.OwnerTag(identifier)
    return GetHashKey(salt .. tostring(identifier))
end

function Scene.Public(obj)
    return {
        id = obj.id,
        kind = obj.kind,
        model = obj.model,
        coords = obj.coords,
        heading = obj.heading,
        number = obj.number,
        note = obj.note,
        ownerTag = Scene.OwnerTag(obj.owner),
        ownerName = obj.ownerName,
        timeText = os.date('%d.%m %H:%M', obj.time),
        sceneId = obj.sceneId,
        link = obj.link,
        style = obj.style
    }
end

function Scene.Api(obj)
    return {
        id = obj.id,
        number = obj.number,
        coords = obj.coords,
        note = obj.note,
        owner = obj.owner,
        ownerName = obj.ownerName,
        time = obj.time,
        sceneId = obj.sceneId
    }
end

function Scene.Get(id)
    return objects[id]
end

function Scene.All()
    return objects
end

function Scene.Find(coords)
    local best, bestDist
    for _, scene in pairs(scenes) do
        local dist = #(coords - scene.center)
        if dist <= Config.Scene.Radius and (not bestDist or dist < bestDist) then
            best, bestDist = scene, dist
        end
    end
    return best
end

local function findOrCreate(coords)
    local scene = Scene.Find(coords)
    if scene then return scene end
    scene = { id = nextSceneId, center = coords }
    nextSceneId = nextSceneId + 1
    scenes[scene.id] = scene
    return scene
end

local function sceneEmpty(sceneId)
    for _, obj in pairs(objects) do
        if obj.sceneId == sceneId then return false end
    end
    return true
end

function Scene.Count(filter)
    local count = 0
    for _, obj in pairs(objects) do
        if filter(obj) then count = count + 1 end
    end
    return count
end

function Scene.NextNumber(coords)
    local scene = Scene.Find(coords)
    if not scene then return 1 end
    local highest = 0
    for _, obj in pairs(objects) do
        if obj.kind == 'marker' and obj.sceneId == scene.id and obj.number > highest then
            highest = obj.number
        end
    end
    return highest + 1
end

function Scene.MarkersInScene(coords)
    local scene = Scene.Find(coords)
    if not scene then return 0 end
    return Scene.Count(function(obj) return obj.kind == 'marker' and obj.sceneId == scene.id end)
end

function Scene.HasChild(id)
    for _, obj in pairs(objects) do
        if obj.link == id then return true end
    end
    return false
end

function Scene.Save()
    if not Config.Persistence or saveQueued then return end
    saveQueued = true
    SetTimeout(2000, function()
        saveQueued = false
        local list, sceneList = {}, {}
        for _, obj in pairs(objects) do
            local copy = {}
            for k, v in pairs(obj) do copy[k] = v end
            copy.coords = plain(obj.coords)
            list[#list + 1] = copy
        end
        for _, scene in pairs(scenes) do
            sceneList[#sceneList + 1] = { id = scene.id, center = plain(scene.center) }
        end
        SetResourceKvp(KVP_KEY, json.encode({ nextId = nextId, nextSceneId = nextSceneId, objects = list, scenes = sceneList }))
    end)
end

function Scene.Add(obj)
    local scene = findOrCreate(obj.coords)
    obj.id = nextId
    nextId = nextId + 1
    obj.sceneId = scene.id
    obj.time = os.time()
    if obj.kind == 'pole' and not obj.tape then
        obj.tape = obj.id
    end
    objects[obj.id] = obj
    TriggerClientEvent('kipchak_crimescene:add', -1, Scene.Public(obj))
    Scene.Save()
    return obj
end

function Scene.Update(obj)
    TriggerClientEvent('kipchak_crimescene:update', -1, { id = obj.id, note = obj.note, link = obj.link })
    Scene.Save()
end

function Scene.RemoveMany(ids, reason, src)
    local removed, removedIds = {}, {}
    for _, id in ipairs(ids) do
        local obj = objects[id]
        if obj then
            objects[id] = nil
            removed[#removed + 1] = obj
            removedIds[#removedIds + 1] = id
        end
    end
    if #removed == 0 then return removed end

    for _, obj in pairs(objects) do
        if obj.link and not objects[obj.link] then
            obj.link = nil
        end
    end

    for _, obj in ipairs(removed) do
        if scenes[obj.sceneId] and sceneEmpty(obj.sceneId) then
            scenes[obj.sceneId] = nil
        end
    end

    TriggerClientEvent('kipchak_crimescene:remove', -1, removedIds)

    for _, obj in ipairs(removed) do
        if obj.kind == 'marker' then
            TriggerEvent('kipchak_crimescene:markerRemoved', Scene.Api(obj), reason, src)
        end
    end

    Scene.Save()
    return removed
end

function Scene.Load()
    if not Config.Persistence then return end
    local raw = GetResourceKvpString(KVP_KEY)
    if not raw or raw == '' then return end
    local ok, data = pcall(json.decode, raw)
    if not ok or type(data) ~= 'table' then return end

    for _, scene in ipairs(data.scenes or {}) do
        if scene.id and scene.center then
            scenes[scene.id] = { id = scene.id, center = toVector(scene.center) }
        end
    end

    for _, obj in ipairs(data.objects or {}) do
        if obj.id and obj.coords and scenes[obj.sceneId] then
            obj.coords = toVector(obj.coords)
            objects[obj.id] = obj
        end
    end

    nextId = math.max(tonumber(data.nextId) or 1, 1)
    nextSceneId = math.max(tonumber(data.nextSceneId) or 1, 1)
    for id in pairs(objects) do
        if id >= nextId then nextId = id + 1 end
    end
    for id, scene in pairs(scenes) do
        if id >= nextSceneId then nextSceneId = id + 1 end
        if sceneEmpty(scene.id) then scenes[id] = nil end
    end
end

local function expire()
    if (Config.Scene.ExpireMinutes or 0) <= 0 then return end
    local limit = os.time() - Config.Scene.ExpireMinutes * 60
    local ids = {}
    for id, obj in pairs(objects) do
        if obj.time <= limit then ids[#ids + 1] = id end
    end
    if #ids > 0 then
        Scene.RemoveMany(ids, 'expired')
    end
end

CreateThread(function()
    Scene.Load()
    expire()
    while true do
        Wait(30000)
        expire()
    end
end)

local function argVector(coords)
    local t = type(coords)
    if t ~= 'vector3' and t ~= 'vector4' and t ~= 'table' then return end
    local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    if not x or not y or not z then return end
    return vector3(x, y, z)
end

exports('GetMarkers', function(coords, radius)
    local center = argVector(coords)
    if not center then return {} end
    radius = tonumber(radius) or Config.Scene.Radius
    local list = {}
    for _, obj in pairs(objects) do
        if obj.kind == 'marker' and #(obj.coords - center) <= radius then
            list[#list + 1] = Scene.Api(obj)
        end
    end
    table.sort(list, function(a, b)
        if a.sceneId == b.sceneId then return a.number < b.number end
        return a.sceneId < b.sceneId
    end)
    return list
end)

exports('GetMarker', function(id)
    local obj = objects[tonumber(id)]
    if not obj or obj.kind ~= 'marker' then return end
    return Scene.Api(obj)
end)

exports('GetSceneAt', function(coords)
    local center = argVector(coords)
    if not center then return end
    local scene = Scene.Find(center)
    if not scene then return end
    return { id = scene.id, center = scene.center }
end)
