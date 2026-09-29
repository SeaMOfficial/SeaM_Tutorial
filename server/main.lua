local Core = exports.SeaM_Core:GetCoreObject()
local SeaM = exports.SeaM_Core

local METADATA_KEY = 'tutorial'

local function inventory()
    return GetResourceState('SeaM_Inventory') == 'started' and exports.SeaM_Inventory or nil
end

local function licenseOf(source)
    -- `SeaM` in this file is the exports proxy; config lives on the core object.
    return GetPlayerIdentifierByType(source, Core.Config.Server.RequiredIdent)
end

local function readState(source)
    if Config.PerCharacter then
        return SeaM:GetMetadata(source, METADATA_KEY)
    end

    local license = licenseOf(source)
    if not license then return nil end

    local row = Core.DB.single('SELECT state FROM seam_tutorial WHERE license = ?', { license })
    if not row then return nil end

    return tonumber(row.state) or row.state
end

local function writeState(source, value)
    if Config.PerCharacter then
        SeaM:SetMetadata(source, METADATA_KEY, value)
        SeaM:SavePlayer(source, true)
        return
    end

    local license = licenseOf(source)
    if not license then return end

    if value == nil or value == false then
        Core.DB.execute('DELETE FROM seam_tutorial WHERE license = ?', { license })
        return
    end

    Core.DB.execute([[
        INSERT INTO seam_tutorial (license, state) VALUES (?, ?)
        ON DUPLICATE KEY UPDATE state = VALUES(state)
    ]], { license, tostring(value) })
end

local function completed(source)
    return readState(source) == 'done'
end

--- Where they got to, so a disconnect part way through resumes instead of
--- starting over or being skipped entirely.
local function resumeAt(source)
    local state = readState(source)
    local step = tonumber(state)

    if not step or step < 1 or step > #Config.Steps then return 1 end
    return step
end

local function grant(source, reward)
    if type(reward) ~= 'table' then return end

    for account, amount in pairs(reward.money or {}) do
        if (tonumber(amount) or 0) > 0 then
            SeaM:AddMoney(source, account, amount, 'tutorial reward')
        end
    end

    local items = reward.items
    if items and #items > 0 then
        local bag = inventory()

        if bag then
            local ok = bag:AddItems(source, items)

            if not ok then
                for _, entry in ipairs(items) do
                    bag:AddItem(source, entry.name, entry.count or 1)
                end
            end
        end
    end
end

Core.Callbacks.register('tutorial:stepReward', function(source, stepId)
    if completed(source) then return false end

    -- Steps only move forward. Without this a client could call this in a loop and
    -- collect the same step reward (e.g. the 'buy' step's cash) over and over.
    local reached = tonumber(readState(source)) or 1

    for index, step in ipairs(Config.Steps) do
        if step.id == stepId then
            if index < reached then return false end
            if step.reward then grant(source, step.reward) end

            writeState(source, index + 1)
            return true
        end
    end

    return false
end)

Core.Callbacks.register('tutorial:finish', function(source)
    if completed(source) then return false end

    writeState(source, 'done')
    grant(source, Config.Reward)

    if Config.Reward.message then
        SeaM:Notify(source, Config.Reward.message, 'success', 10000, 'Tutorial complete')
    end

    Core.Log.audit('join', 'Tutorial complete',
        ('`%s` finished the tutorial'):format(GetPlayerName(source) or source))

    return true
end)

Core.Callbacks.register('tutorial:skip', function(source)
    if not Config.AllowSkip or completed(source) then return false end

    writeState(source, 'done')
    return true
end)

CreateThread(function()
    if Config.PerCharacter then return end

    local ok = pcall(function()
        Core.DB.single('SELECT license FROM seam_tutorial LIMIT 1')
    end)

    if not ok then
        Core.Log.error('tutorial',
            'Config.PerCharacter is false but seam_tutorial is missing. Import install/tutorial.sql, or set PerCharacter true.')
    end
end)

local started = {}

local function begin(source)
    if started[source] then return end
    if not Config.Enabled then return end
    if not GetPlayerName(source) then return end
    if completed(source) then return end

    started[source] = true

    local from = resumeAt(source)

    if from > 1 and not Config.Resume then
        writeState(source, 'done')
        return
    end

    TriggerClientEvent('SeaM_Tutorial:client:start', source, Config.Steps, from)
end

AddEventHandler('playerDropped', function() started[source] = nil end)
AddEventHandler('SeaM_Core:player:unloaded', function(source) started[source] = nil end)

--- The clothing editor takes the screen on a new character, so starting on
--- player:loaded would have the narrator talking to itself behind it.
AddEventHandler('SeaM_MultiChar:playerReady', function(source)
    if Config.StartOn ~= 'appearance' then return end

    SetTimeout(math.max(Config.StartDelay, 1) * 1000, function() begin(source) end)
end)

AddEventHandler('SeaM_Core:player:loaded', function(source)
    if Config.StartOn == 'appearance' and GetResourceState('SeaM_MultiChar') == 'started' then
        return
    end

    SetTimeout(math.max(Config.StartDelay, 1) * 1000, function() begin(source) end)
end)

Core.Commands.register('tutorial', {
    help = 'Run the tutorial again, on yourself or someone else',
    permission = Config.Admin.Permission,
    params = {
        { name = 'target', type = 'source', help = 'Server id', optional = true },
    },
    handler = function(source, args)
        local target = args.target or source
        if target == 0 then return SeaM:Notify(source, 'Name a player.', 'error') end

        writeState(target, nil)
        started[target] = true
        TriggerClientEvent('SeaM_Tutorial:client:start', target, Config.Steps, 1)

        SeaM:Notify(source, ('Started the tutorial for %s.')
            :format(GetPlayerName(target) or target), 'success')
    end,
})

Core.Commands.register('tutorialreset', {
    help = 'Mark the tutorial as unseen so it runs on their next login',
    permission = Config.Admin.Permission,
    params = {
        { name = 'target', type = 'source', help = 'Server id' },
    },
    handler = function(source, args)
        writeState(args.target, nil)

        SeaM:Notify(source, ('Reset the tutorial for %s.')
            :format(GetPlayerName(args.target) or args.target), 'success')
    end,
})

exports('HasCompleted', function(source) return completed(source) end)

exports('Start', function(source)
    started[source] = true
    TriggerClientEvent('SeaM_Tutorial:client:start', source, Config.Steps, 1)
    return true
end)

exports('MarkComplete', function(source)
    writeState(source, 'done')
    return true
end)

exports('Reset', function(source)
    writeState(source, nil)
    return true
end)
