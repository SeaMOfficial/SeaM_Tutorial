--- SeaM_Tutorial :: configuration

Config = {}

Config.Enabled = true

--- What the tutorial waits for before its first line.
---
--- 'appearance'  after the clothing editor closes on a new character, which is
---               when the player is actually standing in the world looking at
---               it. Falls back to 'loaded' on its own if SeaM_MultiChar is
---               not running
--- 'loaded'      as soon as the character loads
Config.StartOn = 'appearance'

--- Seconds to wait after that before the first line appears. Long enough for
--- the fade to finish, short enough that it still reads as part of arriving.
Config.StartDelay = 4

--- Where the "seen it" flag lives.
---
--- true  stores it on the character, so a second character runs it again. That
---       is usually what you want for a roleplay intro. Written straight to the
---       database rather than queued, so a restart cannot lose it.
--- false stores it against the account in seam_tutorial, so it only ever shows
---       once no matter how many characters they make. Needs
---       install/tutorial.sql imported.
Config.PerCharacter = true

--- What happens when someone disconnects part way through.
---
--- true  they pick up at the step they had reached
--- false the tutorial is marked seen and never shown again
---
--- Either way they never replay the steps they already finished, which is the
--- thing that makes people skip it the second time.
Config.Resume = true

--- Whether a player can walk away from it.
Config.AllowSkip = true

--- Narrator ------------------------------------------------------------------
Config.Narrator = {
    --- Milliseconds per character. Around 22 reads at a natural pace; drop it
    --- to 12 for something brisker.
    Speed = 22,

    --- The key that advances a line, and finishes one early if it is still
    --- typing. 38 is E.
    AdvanceKey = 38,
    AdvanceLabel = 'E',
}

--- The skip command opens a warning instead of immediately ending the voyage.
--- These controls are read by the game, so the tutorial UI never steals mouse
--- or keyboard focus from the player. 38 is E; 177 is Backspace.
Config.SkipConfirmation = {
    ConfirmKey = 38,
    ConfirmLabel = 'E',
    CancelKey = 177,
    CancelLabel = 'BACKSPACE',
}

--- Objectives ----------------------------------------------------------------
Config.Objectives = {
    --- Draw a route on the minimap to a `goto` objective, not just a blip.
    Route = true,

    --- Blip used for the current objective.
    Blip = { sprite = 1, colour = 5, scale = 0.9 },
}

--- Waypoint ------------------------------------------------------------------
--- The marker over a `goto` objective, so a player can see where they are
--- going without staring at the minimap.
---
--- Drawn the same way SeaM_Islands draws island names: a world-space label that
--- scales and fades with distance, over a beacon on the ground. No DUI, no
--- dependencies, nothing to install.
Config.Waypoint = {
    Enabled = true,

    --- Hex.
    Colour = '#c08a37',

    --- Metres. Past this nothing is drawn and the loop sleeps.
    DrawDistance = 600.0,

    --- It fades in over the last stretch of that, rather than appearing whole
    --- the moment you cross the line.
    FadeInOver = 120.0,

    --- A thin line from the label down to the ground, so the marker has
    --- something to stand on.
    Beam = true,

    --- The floating label and distance readout.
    Label = true,

    --- Metres above the ground the label sits. Taller than before, since the
    --- beam now runs from the label down to the ground.
    Height = 6.0,

    --- Text size near and far. Distant objectives read smaller, which is what
    --- gives the marker a sense of depth.
    ScaleNear = 0.52,
    ScaleFar = 0.30,
}

--- Steps ---------------------------------------------------------------------
--- Each step shows its lines one at a time, then waits for its objective.
---
--- Objective types:
---   none        the line itself is the step, press the key to move on
---   wait        seconds, then it moves on by itself
---   goto        coords and radius. Gets a blip and a route
---   inventory   waits for the player to open their bag
---   target      waits for the player to use the third eye
---   item        waits until they are carrying something
---   event       waits for a client event you fire yourself
---
--- Optional per step:
---   speaker     the name above the text. Defaults to Config.Steps.Speaker
---   reward      granted the moment that step completes, same shape as
---               Config.Reward below

Config.DefaultSpeaker = 'Harbourmaster'

Config.Steps = {
    {
        id = 'welcome',
        lines = {
            'There you are. We were starting to think the sea had swallowed you.',
            'Take a breath. I will walk you through the first few things, then leave you to it.',
        },
        objective = { type = 'none' },
    },
    {
        id = 'inventory',
        lines = {
            'Everything you own, you carry. Weight matters more than space out here.',
            'Open your bag and have a look at what you were given.',
        },
        objective = {
            type = 'inventory',
            label = 'Open your inventory',
        },
    },
    {
        id = 'target',
        lines = {
            'Most things worth doing, you do by looking at them.',
            'Hold the third eye and you will see what is within reach.',
        },
        objective = {
            type = 'target',
            label = 'Hold Left Alt to use the third eye',
        },
    },
    {
        id = 'shop',
        lines = {
            'You will want supplies before you go anywhere.',
            'There is a store down the road. Get yourself something to drink.',
        },
        objective = {
            type = 'goto',
            coords = vector3(25.7, -1346.9, 29.5),
            radius = 20.0,
            label = 'Go to the convenience store',
        },
    },
    {
        id = 'buy',
        lines = {
            'Go on then. Anything wet will do.',
        },
        objective = {
            type = 'item',
            items = { 'water', 'cola', 'coffee', 'beer' },
            label = 'Buy something to drink',
        },
        reward = {
            money = { cash = 100 },
        },
    },
    {
        id = 'clothes',
        lines = {
            'You look like you have been dragged through a hedge.',
            'There is a clothing store nearby. Make yourself presentable.',
        },
        objective = {
            type = 'goto',
            coords = vector3(72.3, -1399.1, 29.38),
            radius = 20.0,
            label = 'Go to the clothing store',
        },
    },
    {
        id = 'done',
        lines = {
            'That is the shape of it. The rest you will pick up as you go.',
            'Keep your head down and your bag light. Good luck out there.',
        },
        objective = { type = 'none' },
    },
}

--- Reward -------------------------------------------------------------------
--- Granted once, when the last step completes.
Config.Reward = {
    money = {
        bank = 2500,
    },
    items = {
        { name = 'water',    count = 2 },
        { name = 'sandwich', count = 2 },
        { name = 'bandage',  count = 3 },
        { name = 'phone',    count = 1 },
    },
    --- Shown in the completion notification. Leave it out for no message.
    message = 'Welcome to Los Santos. Check your bank and your bag.',
}

--- Admin --------------------------------------------------------------------
Config.Admin = {
    --- Permission group needed for /tutorial and /tutorialreset.
    Permission = 'admin',
}
