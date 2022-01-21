local addonName, addonTable = ...
local E, L, V, P, G = unpack(ElvUI) -- Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local EP = LibStub("LibElvUIPlugin-1.0")
local version = GetAddOnMetadata(addonName, "Version")

local Addon = E:NewModule(addonName, "AceHook-3.0", "AceEvent-3.0", "AceTimer-3.0")
Addon.name = "Cooldown Bars"
Addon.title = "|cff1784d1ElvUI|r |cffFFB600Cooldown Bars|r"

addonTable[1] = Addon
_G[addonName] = Addon

function Addon:Initialize()
    EP:RegisterPlugin(addonName, Addon.InsertOptions)

    if LibStub("Masque", true) then
        Addon.masqueGroup = LibStub("Masque", true):Group(Addon.title, "Cooldown Bars", true)
    end

    Addon.bars = {}
    for name, config in pairs(E.db[addonName].bars) do
        Addon.bars[name] = Addon:CreateCooldownBar(name, config)
    end

    Addon:ScheduleRepeatingTimer("Update", 1 / 60)
end

function Addon:Update()
    for name, bar in pairs(Addon.bars) do
        if E.db[addonName].bars[name] then
            Addon:UpdateCooldownBar(bar)
        else
            bar:Hide()
            E:DisableMover(bar.mover:GetName())
            Addon.bars[name] = nil
        end
    end

    for name, config in pairs(E.db[addonName].bars) do
        if not Addon.bars[name] then
            Addon.bars[name] = Addon:CreateCooldownBar(name, config)
        end
    end
end

function Addon:OnSettingChanged(setting)
    Addon:Update()
end

E:RegisterModule(Addon:GetName())
