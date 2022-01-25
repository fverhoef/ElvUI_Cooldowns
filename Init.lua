local addonName, addonTable = ...
local E, L, V, P, G = unpack(ElvUI) -- Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local EP = LibStub("LibElvUIPlugin-1.0")
local version = GetAddOnMetadata(addonName, "Version")

local Addon = E:NewModule(addonName, "AceHook-3.0", "AceEvent-3.0", "AceTimer-3.0")
Addon.name = "Cooldown Bars"
Addon.title = "|cff1784d1ElvUI|r |cffFFB600Cooldown Bars|r"

addonTable[1] = Addon
_G[addonName] = Addon

E:RegisterModule(Addon:GetName())
