if Bridge.Target ~= 'ox' then return end

local function options()
    local list = {}
    local distance = Config.Target.Distance
    if Config.Target.Info then
        list[#list + 1] = {
            name = 'kipchak_crimescene_info',
            icon = 'fa-solid fa-circle-info',
            label = L('target_info'),
            distance = distance,
            onSelect = function(data) Actions.Info(EntityIds[data.entity]) end
        }
    end
    if Config.Target.Note and Config.Markers.Notes.Enabled then
        list[#list + 1] = {
            name = 'kipchak_crimescene_note',
            icon = 'fa-solid fa-pen',
            label = L('target_note'),
            distance = distance,
            canInteract = function(entity) return Actions.CanNote(EntityIds[entity]) end,
            onSelect = function(data) Actions.EditNote(EntityIds[data.entity]) end
        }
    end
    if Config.Target.Remove then
        list[#list + 1] = {
            name = 'kipchak_crimescene_remove',
            icon = 'fa-solid fa-trash',
            label = L('target_remove'),
            distance = distance,
            canInteract = function(entity) return Actions.CanManage(EntityIds[entity]) end,
            onSelect = function(data) Actions.Remove(EntityIds[data.entity]) end
        }
    end
    return list
end

local targetOptions = options()

function Target.Add(entity)
    if #targetOptions == 0 then return end
    exports.ox_target:addLocalEntity(entity, targetOptions)
end

function Target.Remove(entity)
    if #targetOptions == 0 then return end
    exports.ox_target:removeLocalEntity(entity)
end
