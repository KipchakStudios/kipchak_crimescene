if Bridge.Target ~= 'qb' then return end

local function options()
    local list = {}
    if Config.Target.Info then
        list[#list + 1] = {
            icon = 'fas fa-circle-info',
            label = L('target_info'),
            action = function(entity) Actions.Info(EntityIds[entity]) end
        }
    end
    if Config.Target.Note and Config.Markers.Notes.Enabled then
        list[#list + 1] = {
            icon = 'fas fa-pen',
            label = L('target_note'),
            canInteract = function(entity) return Actions.CanNote(EntityIds[entity]) end,
            action = function(entity) Actions.EditNote(EntityIds[entity]) end
        }
    end
    if Config.Target.Remove then
        list[#list + 1] = {
            icon = 'fas fa-trash',
            label = L('target_remove'),
            canInteract = function(entity) return Actions.CanManage(EntityIds[entity]) end,
            action = function(entity) Actions.Remove(EntityIds[entity]) end
        }
    end
    return list
end

local targetOptions = options()

function Target.Add(entity)
    if #targetOptions == 0 then return end
    exports['qb-target']:AddTargetEntity(entity, { options = targetOptions, distance = Config.Target.Distance })
end

function Target.Remove(entity)
    if #targetOptions == 0 then return end
    exports['qb-target']:RemoveTargetEntity(entity)
end
