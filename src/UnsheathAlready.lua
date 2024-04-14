UnsheatheAlready = LibStub("AceAddon-3.0"):NewAddon("UnsheatheAlready", "AceTimer-3.0", "AceConsole-3.0")

local eventFrame
local repeatingTimer
local onceTimer
local debug = false
local lastUnsheath = 0

local function destroyTimer()
    if onceTimer ~= nil then
        UnsheatheAlready:CancelTimer(onceTimer)
        onceTimer = nil
    end
    if repeatingTimer ~= nil then
        UnsheatheAlready:CancelTimer(repeatingTimer)
        repeatingTimer = nil
    end
end

local function startTimer()
    destroyTimer()
    repeatingTimer = UnsheatheAlready:ScheduleRepeatingTimer("UnsheathIfNeeded", 2)
end

local function shouldToggleSheath()
    return GetSheathState() == 1
            and GetUnitSpeed("player") < 10
            and not InCombatLockdown()
            and not IsSwimming()
            and not IsSubmerged()
            and not IsResting()
end

function UnsheatheAlready:UnsheathIfNeededOnce()
    onceTimer = nil
    UnsheatheAlready:UnsheathIfNeeded()
end

function UnsheatheAlready:UnsheathIfNeeded()
    local toggle = shouldToggleSheath()
    if debug and not toggle and GetSheathState() == 1 then
        print("Not toggling sheath due to:")
        print("Combat " .. tostring(InCombatLockdown()))
        print("Swimming " .. tostring(IsSwimming()))
        print("Submerged " .. tostring(IsSubmerged()))
        print("Resting " .. tostring(IsResting()))
    end
    if toggle then
        local t = GetTime()
        if debug then
            print("Seconds since last toggle" .. tostring(t - lastUnsheath))
        end
        if t - 0.75 > lastUnsheath then
            lastUnsheath = t
            ToggleSheath()
        end
    end
end

function UnsheatheAlready:OnInitialize()
    lastUnsheath = 0
    onceTimer = nil

    eventFrame = CreateFrame("FRAME", "UnsheatheAlreadyEventFrame")
    local events = {
        'ADDON_LOADED',
        'PLAYER_REGEN_ENABLED',
        'LOOT_CLOSED',
        'PLAYER_ENTERING_WORLD',
    }
    for i = 1, #events do
        eventFrame:RegisterEvent(events[i])
    end
    eventFrame:SetScript("OnEvent", function(frame, event, first, second)
        if debug then
            print("Calling UnsheathIfNeeded for event " .. event)
        end
        if onceTimer == nil then
            onceTimer = UnsheatheAlready:ScheduleTimer("UnsheathIfNeededOnce", 0.5)
        end
    end)
end

function UnsheatheAlready:OnEnable()
    startTimer()
end

function UnsheatheAlready:OnDisable()
    destroyTimer()
end
