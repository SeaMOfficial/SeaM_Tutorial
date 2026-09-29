local Core = exports.SeaM_Core:GetCoreObject()

local state = {
    running = false,
    confirmingSkip = false,
    steps = {},
    index = 0,
    blip = nil,
    objective = nil,
    waitingFor = nil,
}

local nui = {
    ready = false,
    pending = {},
}

local function send(action, data)
    local message = { action = action, data = data }

    if not nui.ready then
        -- Keep only the newest distance update while Chromium is starting.
        -- Everything else stays ordered so an early open/line cannot be lost.
        if action == 'objective' then
            for index = #nui.pending, 1, -1 do
                if nui.pending[index].action == 'objective' then
                    nui.pending[index] = message
                    return
                end
            end
        end

        nui.pending[#nui.pending + 1] = message

        if #nui.pending > 64 then table.remove(nui.pending, 1) end
        return
    end

    SendNUIMessage(message)
end

RegisterNUICallback('ready', function(_, cb)
    if not nui.ready then
        nui.ready = true

        for index = 1, #nui.pending do
            SendNUIMessage(nui.pending[index])
        end

        nui.pending = {}
    end

    cb({ ok = true })
end)

local function points(enabled)
    if GetResourceState('SeaM_Core') ~= 'started' then return end
    exports.SeaM_Core:SetPointsEnabled(enabled)
end

local function clearBlip()
    if state.blip and DoesBlipExist(state.blip) then
        SetBlipRoute(state.blip, false)
        RemoveBlip(state.blip)
    end
    state.blip = nil
end

local function setBlip(coords)
    clearBlip()

    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, Config.Objectives.Blip.sprite or 1)
    SetBlipColour(blip, Config.Objectives.Blip.colour or 5)
    SetBlipScale(blip, Config.Objectives.Blip.scale or 0.9)
    SetBlipAsShortRange(blip, false)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Objective')
    EndTextCommandSetBlipName(blip)

    if Config.Objectives.Route then
        SetBlipRoute(blip, true)
        SetBlipRouteColour(blip, Config.Objectives.Blip.colour or 5)
    end

    state.blip = blip
end

local function stop(finished)
    state.running = false
    state.confirmingSkip = false
    state.objective = nil
    state.waitingFor = nil

    clearBlip()
    Marker.clear()
    points(true)
    send('close')

    if finished then Core.Callbacks.await('tutorial:finish') end
end

local function hasAny(items)
    if GetResourceState('SeaM_Inventory') ~= 'started' then return true end

    for _, name in ipairs(items or {}) do
        if exports.SeaM_Inventory:GetItemCount(name) > 0 then return true end
    end

    return false
end

local function objectiveMet(objective)
    local kind = objective.type

    if kind == 'goto' then
        return #(GetEntityCoords(PlayerPedId()) - objective.coords) <= (objective.radius or 5.0)
    end

    if kind == 'inventory' then
        return GetResourceState('SeaM_Inventory') == 'started'
            and exports.SeaM_Inventory:IsOpen()
    end

    if kind == 'target' then
        return GetResourceState('SeaM_Target') == 'started'
            and exports.SeaM_Target:isActive()
    end

    if kind == 'item' then
        return hasAny(objective.items)
    end

    if kind == 'event' then
        return state.waitingFor == nil
    end

    return true
end

local function distanceTo(objective)
    if objective.type ~= 'goto' then return nil end
    return #(GetEntityCoords(PlayerPedId()) - objective.coords)
end

local function runObjective(objective, onDone)
    state.objective = objective

    if objective.type == 'none' then
        state.objective = nil
        return onDone()
    end

    if objective.type == 'goto' and objective.coords then
        setBlip(objective.coords)
        Marker.set(objective.coords, objective.label)
    end
    if objective.type == 'event' then state.waitingFor = objective.event end

    send('objective', {
        label = objective.label or 'Continue',
        distance = distanceTo(objective),
    })

    CreateThread(function()
        if objective.type == 'wait' then
            Wait(math.max(tonumber(objective.seconds) or 3, 1) * 1000)
        else
            while state.running and not objectiveMet(objective) do
                if objective.type == 'goto' then
                    send('objective', {
                        label = objective.label or 'Continue',
                        distance = distanceTo(objective),
                    })
                end

                Wait(300)
            end
        end

        if not state.running then return end

        clearBlip()
        Marker.clear()
        state.objective = nil
        state.waitingFor = nil

        send('objectiveDone')
        Wait(600)

        onDone()
    end)
end

local function speak(step, onDone)
    local line = 1

    points(false)

    CreateThread(function()
        while state.running and line <= #step.lines do
            send('line', {
                speaker = step.speaker or Config.DefaultSpeaker,
                text = step.lines[line],
                speed = Config.Narrator.Speed,
                key = Config.Narrator.AdvanceLabel,
                step = state.index,
                total = #state.steps,
            })

            local typed = false
            local waited = 0

            while state.running do
                Wait(0)

                if not state.confirmingSkip and IsControlJustReleased(0, Config.Narrator.AdvanceKey) then
                    if typed then break end
                    typed = true
                    send('reveal')
                end

                waited = waited + GetFrameTime() * 1000
                if not typed and waited > (#step.lines[line] * Config.Narrator.Speed) + 400 then
                    typed = true
                end
            end

            line = line + 1
        end

        points(true)
        if state.running then onDone() end
    end)
end

local function runStep(index)
    if not state.running then return end

    state.index = index
    local step = state.steps[index]

    if not step then return stop(true) end

    speak(step, function()
        runObjective(step.objective or { type = 'none' }, function()
            Core.Callbacks.await('tutorial:stepReward', step.id)
            runStep(index + 1)
        end)
    end)
end

RegisterNetEvent('SeaM_Tutorial:client:start', function(steps, from)
    if state.running or type(steps) ~= 'table' or #steps == 0 then return end

    from = math.min(math.max(math.floor(tonumber(from) or 1), 1), #steps)

    state.running = true
    state.steps = steps

    send('open', {
        total = #steps,
        allowSkip = Config.AllowSkip,
        key = Config.Narrator.AdvanceLabel,
    })

    if from > 1 then
        TriggerEvent('SeaM_Core:notify', 'Picking up where you left off.', 'inform')
    end

    runStep(from)
end)

RegisterNetEvent('SeaM_Tutorial:client:complete', function(eventName)
    if state.waitingFor and state.waitingFor == eventName then state.waitingFor = nil end
end)

RegisterNetEvent('SeaM_Core:player:unloaded', function()
    if state.running then stop(false) end
end)

if Config.AllowSkip then
    local function requestSkip()
        if not state.running or state.confirmingSkip then return end

        local confirmation = Config.SkipConfirmation
        state.confirmingSkip = true

        send('skipConfirm', {
            confirmKey = confirmation.ConfirmLabel,
            cancelKey = confirmation.CancelLabel,
        })

        CreateThread(function()
            while state.running and state.confirmingSkip do
                Wait(0)

                DisableControlAction(0, confirmation.ConfirmKey, true)
                DisableControlAction(0, confirmation.CancelKey, true)

                if IsDisabledControlJustReleased(0, confirmation.ConfirmKey) then
                    state.confirmingSkip = false
                    stop(false)

                    local skipped = Core.Callbacks.await('tutorial:skip')
                    if skipped then
                        TriggerEvent('SeaM_Core:notify', 'The tutorial has been cast overboard.', 'inform')
                    end

                    return
                end

                if IsDisabledControlJustReleased(0, confirmation.CancelKey) then
                    state.confirmingSkip = false
                    send('skipConfirmClose')
                    return
                end
            end
        end)
    end

    RegisterCommand('skiptutorial', function()
        requestSkip()
    end, false)
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    clearBlip()
    Marker.clear()
    points(true)
    SendNUIMessage({ action = 'close' })
end)

exports('IsRunning', function() return state.running end)
exports('Complete', function(eventName)
    if state.waitingFor and state.waitingFor == eventName then state.waitingFor = nil end
end)

-- The UI page is created as soon as the resource starts. Queueing an explicit
-- close guarantees that a restarted resource never inherits a painted frame.
send('close')
