local addonName, addonTable = ...
local Addon = addonTable[1]
local E, L, V, P, G = unpack(ElvUI)
local EP = LibStub("LibElvUIPlugin-1.0")
local S = E:GetModule("Skins")
local LAB = E.Libs.LAB

local MIN_DURATION = 3
local MAX_DURATION = 300
local TARGET_FPS = 60
local SMOOTHING_AMOUNT = 0.33
local WEAPON_ENCHANT_MAIN = "WEAPON_ENCHANT_MAIN"
local WEAPON_ENCHANT_OFFHAND = "WEAPON_ENCHANT_OFFHAND"
local WEAPON_ENCHANT_RANGED = "WEAPON_ENCHANT_RANGED"
local RES_TIMER = "RES_TIMER"
local COOLDOWN_TYPES = {
    SPELL = "SPELL",
    PET = "PET",
    ITEM = "ITEM",
    RES_TIMER = "RES_TIMER",
    WEAPON_ENCHANT = "WEAPON_ENCHANT"
}

Addon.cooldowns = {}

function Addon:Initialize()
    EP:RegisterPlugin(addonName, Addon.InsertOptions)

    if LibStub("Masque", true) then
        Addon.masqueGroup = LibStub("Masque", true):Group(Addon.title, "Cooldown Bars", true)
    end
    
    Addon:RegisterEvent("BAG_UPDATE_COOLDOWN")
    Addon:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
    Addon:RegisterEvent("PET_BAR_UPDATE_COOLDOWN")
    Addon:RegisterEvent("PLAYER_DEAD")
    Addon:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    Addon:RegisterEvent("UNIT_INVENTORY_CHANGED")

    Addon.bars = {}
    for name, config in pairs(E.db[addonName].bars) do
        Addon.bars[name] = Addon:CreateCooldownBar(name, config)
    end

    Addon:ScheduleRepeatingTimer("Update", 1 / 30)
end

function Addon:Update()
    for name, cd in pairs(Addon.cooldowns) do
        cd:Update()
    end

    for name, bar in pairs(Addon.bars) do
        if E.db[addonName].bars[name] then
            bar:Update()
        else
            bar:Hide()
            E:DisableMover(bar.mover:GetName())
            Addon.bars[name] = nil
        end
    end
end

function Addon:OnSettingChanged(setting)
    for name, config in pairs(E.db[addonName].bars) do
        local bar = Addon.bars[name]
        if not bar then
            bar = Addon:CreateCooldownBar(name, config)
        end
        bar:Configure()
    end
end

function Addon:BAG_UPDATE_COOLDOWN()
    Addon:ScanBags()
end

function Addon:ACTIONBAR_UPDATE_COOLDOWN()
    Addon:ScanActions()
end

function Addon:PET_BAR_UPDATE_COOLDOWN()
    Addon:ScanPetActions()
end

function Addon:PLAYER_DEAD()
    Addon:ScanResTimer()
end

function Addon:SPELL_UPDATE_COOLDOWN()
    Addon:ScanSpellBook()
end

function Addon:UNIT_INVENTORY_CHANGED()
    Addon:ScanWeaponEnchants()
end

function Addon:ScanBags()
    local _, spell, start, duration, texture
    local id
    local enabled
    for bag = 0, 4 do
        for slot = 1, GetContainerNumSlots(bag) do
            id = GetContainerItemID(bag, slot)
            Addon:CheckItemCooldown(id)
        end
    end
end

function Addon:ScanActions()
    local _, name, start, duration, enabled, texture
    local actionType, id
    local enabled
    for i = 1, 120 do
        actionType, id, subType = GetActionInfo(i)
        if actionType == "item" then
            Addon:CheckItemCooldown(id)
        elseif actionType == "spell" then
            Addon:CheckSpellCooldown(id)
        end
    end
    for i = 1, 19 do
        id = GetInventoryItemID("player", i)
        Addon:CheckItemCooldown(id)
    end
end

function Addon:ScanPetActions()
    for id = 1, 10 do
        Addon:CheckPetCooldown(id)
    end
end

function Addon:ScanResTimer()
    local resTimer = GetCorpseRecoveryDelay()
    if resTimer > 0 then
        Addon:AddCooldown(RES_TIMER, nil, GetTime(), resTimer, "Interface\\Icons\\Ability_Creature_Cursed_02", COOLDOWN_TYPES.RES_TIMER)
    end
end

function Addon:ScanSpellBook()
    for i = 1, GetNumSpellTabs() do
        local _, _, offset, numSlots = GetSpellTabInfo(i)
        for j = offset + 1, offset + numSlots do
            local id = select(2, GetSpellBookItemInfo(j, BOOKTYPE_SPELL))
            Addon:CheckSpellCooldown(id)
        end
    end
end

function Addon:ScanWeaponEnchants()
    local hasMainHandEnchant, mainHandExpiration, mainHandCharges, hasOffHandEnchant, offHandExpiration, offHandCharges, hasThrownEnchant, thrownExpiration, thrownCharges = GetWeaponEnchantInfo()

    if hasMainHandEnchant then
        local texture = GetInventoryItemTexture("player", select(1, GetInventorySlotInfo("MainHandSlot")))
        Addon:AddCooldown(WEAPON_ENCHANT_MAIN, nil, GetTime(), mainHandExpiration / 1000, texture, COOLDOWN_TYPES.WEAPON_ENCHANT)
    elseif Addon.cooldowns[WEAPON_ENCHANT_MAIN] then
        Addon.cooldowns[WEAPON_ENCHANT_MAIN]:Update()
    end
    if hasOffHandEnchant and offHandExpiration then
        local texture = GetInventoryItemTexture("player", select(1, GetInventorySlotInfo("SecondaryHandSlot")))
        Addon:AddCooldown(WEAPON_ENCHANT_OFFHAND, nil, GetTime(), offHandExpiration / 1000, texture, COOLDOWN_TYPES.WEAPON_ENCHANT)
    elseif Addon.cooldowns[WEAPON_ENCHANT_OFFHAND] then
        Addon.cooldowns[WEAPON_ENCHANT_OFFHAND]:Update()
    end
    if hasThrownEnchant and thrownExpiration then
        local texture = GetInventoryItemTexture("player", select(1, GetInventorySlotInfo("RangedSlot")))
        Addon:AddCooldown(WEAPON_ENCHANT_RANGED, nil, GetTime(), thrownExpiration / 1000, texture, COOLDOWN_TYPES.WEAPON_ENCHANT)
    elseif Addon.cooldowns[WEAPON_ENCHANT_RANGED] then
        Addon.cooldowns[WEAPON_ENCHANT_RANGED]:Update()
    end
end

local function UpdateCooldown(cd)
    if not cd then
        return
    end

    if cd.type == COOLDOWN_TYPES.SPELL then        
        local start, duration = GetSpellCooldown(cd.id)
        if duration and duration > MIN_DURATION then
            cd.start = start
            cd.duration = duration
        end
    end

    cd.timeLeft = cd.start + cd.duration - GetTime()

    if cd.enabled and (cd.timeLeft < 0.01) then
        cd.enabled = false
    elseif (not cd.enabled) and (cd.timeLeft > 0.01) then
        cd.enabled = true 
    end
end

function Addon:AddCooldown(name, id, start, duration, texture, type)
    if duration < MIN_DURATION then
        return
    end

    local cd = Addon.cooldowns[name]
    if cd then
        cd.start = start
        cd.duration = duration
        cd.texture = texture
    else
        cd = { id = id, name = name, start = start, duration = duration, texture = texture, type = type}
        cd.Update = UpdateCooldown
        Addon.cooldowns[name] = cd
    end

    cd:Update()
end

function Addon:CheckItemCooldown(id)
    if id then
        local name, _, _, _, _, _, _, _, _, texture, _, classID, subclassID = GetItemInfo(id)
        if name then
            local start, duration, enabled = GetItemCooldown(id)
            if enabled then
                if classID == Enum.ItemClass.Consumable then
                    if subclassID == Enum.ItemConsumableSubclass.Potion then
                        name = "Potion"
                        texture = "Interface\\Icons\\inv_potion_137"
                    elseif subclassID == Enum.ItemConsumableSubclass.Generic then
                        name = "Stone"
                        texture = "Interface\\Icons\\INV_Stone_04"
                    end
                end
                Addon:AddCooldown(name, id, start, duration, texture, COOLDOWN_TYPES.ITEM)
            end
        end
    end
end

function Addon:CheckSpellCooldown(id)
    if id then
        local name, _, texture = GetSpellInfo(id)
        local start, duration, enabled = GetSpellCooldown(id)
        if enabled then
            Addon:AddCooldown(name, id, start, duration, texture, COOLDOWN_TYPES.SPELL)
        end
    end
end

function Addon:CheckPetCooldown(id)
    if id then
        local name, _, texture = GetPetActionInfo(id)
        if name then
            local start, duration, enabled = GetPetActionCooldown(id)
            if enabled then
                Addon:AddCooldown(name, id, start, duration, texture, COOLDOWN_TYPES.PET)
            end
        end
    end
end

local function CreateMover(frame, name, textString)
    E:CreateMover(frame, name, textString, nil, nil, nil, "ALL,ACTIONBARS")
end

local function CalculateOffset(timeLeft, range)
    return max(0, min(1, (0.5 + log10(timeLeft * 0.5)) / (0.5 + log10(MAX_DURATION * 0.5))) * range)
end

local function UpdateCooldownButton(button)    
    if not button.enabled then
        return
    end

    button:SetSize(button.bar.db.iconSize, button.bar.db.iconSize)

    local width = button.bar:GetWidth()
    local range = width - button:GetWidth()
    local newOffset = CalculateOffset(button.cd.timeLeft, range)

    button.offset = button.offset and Lerp(newOffset, button.offset, 0.05) or newOffset
    if math.abs(button.offset - newOffset) <= 0.001 then
        button.offset = newOffset
    end

    button:SetPoint("LEFT", button.bar, "LEFT", button.offset, 0)
end

local function CreateCooldownButton(bar, cd)    
    local button = CreateFrame("Frame", bar:GetName() .. "_" .. cd.name, bar, BackdropTemplateMixin and "BackdropTemplate")
    button.bar = bar
    button.cd = cd
    button.Update = UpdateCooldownButton

    button.icon = button:CreateTexture(button:GetName() .. "Icon", "ARTWORK")
    button.icon:SetTexture(cd.texture)
    button.icon:SetAllPoints() 
    S:HandleIcon(button.icon, true)

    button.cooldown = CreateFrame("Cooldown", button:GetName() .. "Cooldown", button, "CooldownFrameTemplate")
    button.cooldown:SetInside()
    E:RegisterCooldown(button.cooldown)

    button.enabled = false
    button.Enable = function(self)
        if not self.enabled then
            self.enabled = true
            self.offset = 0
            CooldownFrame_Set(self.cooldown, self.cd.start, self.cd.duration, true)        
            self:Show()
        end
    end
    button.Disable = function(self)
        self.enabled = false
        self:Hide()
    end

    button.ShowTooltip = function(self)
        local timeLeft = self.cd.start + self.cd.duration - GetTime()
        local hours = floor(mod(timeLeft, 86400) / 3600)
        local minutes = floor(mod(timeLeft, 3600) / 60)
        local seconds = floor(mod(timeLeft, 60))

        local text
        if hours > 0 then            
            text = string.format("%s: %.0fh %.0fm %.0fs.", self.cd.name, hours, minutes, seconds)
        elseif minutes > 0 then
            text = string.format("%s: %.0fm %.0fs.", self.cd.name, minutes, seconds)
        elseif timeLeft > 2.5 then
            text = string.format("%s: %.0f second(s).", self.cd.name, seconds)
        else
            text = string.format("%s: %.1f second(s).", self.cd.name, timeLeft)
        end
        if self.tooltip ~= text then
            self.tooltip = text
            _G.GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
            _G.GameTooltip:SetText(string.format("|T%s:20:20:0:0:64:64:5:59:5:59:%d|t %s", self.cd.texture, 40, self.tooltip))
            _G.GameTooltip:Show()
        end
    end

    button:SetScript("OnEnter", function(self)
        self.mouseOver = true
    end)
    button:SetScript("OnLeave", function(self)
        self.mouseOver = false
        _G.GameTooltip:Hide()
    end)
    button:SetScript("OnUpdate", function(self, elapsed)
        if self.mouseOver then
            self:ShowTooltip()
        end
    end)

    bar.buttons[cd.name] = button
    return button
end

local function UpdateCooldownBar(bar)
     if not bar then
         return
     end

     local count = 0
     local sortedButtons = {}
     for name, cd in pairs(Addon.cooldowns) do        
        local button = bar.buttons[cd.name]
        if cd.enabled then
            if not button then
                button = bar:CreateButton(cd)
            end
            button:Enable()
            button:Update()

            table.insert(sortedButtons, button)

            count = count + 1
        elseif button.enabled then
            button:Disable()
        end
    end
    
    if count > 1 then
        table.sort(sortedButtons, function(a, b) return a.cd.timeLeft > b.cd.timeLeft end)

        local baseFrameLevel = bar:GetFrameLevel()
        local frameLevel
        for _, button in pairs(sortedButtons) do
            frameLevel = (frameLevel or baseFrameLevel) + 4
            button:SetFrameLevel(frameLevel)
            if button.icon.backdrop and button.icon.backdrop.border then
                button.icon.backdrop.border:SetFrameLevel(frameLevel + 1)
            end
        end
    end
end

local function ConfigureCooldownBar(bar)
    if not bar then return end

    bar:SetSize(bar.db.width, bar.db.height)

    local labels = bar.db.showLabels and (bar.db.labels or Addon.DEFAULT_LABELS) or {}
    for i, time in ipairs(labels) do
        local label = bar.labels[i]
        if not label then
            label = CreateFrame("Frame", nil, bar)

            label.text = label:CreateFontString(nil, "OVERLAY")
            label.text:SetAllPoints()
            label.text:SetJustifyH("CENTER")
            label.text:SetJustifyV("CENTER")
            label.text:SetShadowOffset(1, -1)
            label.text:SetFont(_G.STANDARD_TEXT_FONT, 11)
            label.text:SetTextColor(0.5, 0.5, 0.5)

            label.indicator = label:CreateTexture(nil, "BACKGROUND")
            label.indicator:SetTexture(E.media.blankTex)
            label.indicator:SetPoint("TOP", label, "TOP", 0, -1)
            label.indicator:SetPoint("BOTTOM", label, "BOTTOM", 0, 1)
            label.indicator:SetWidth(1)
            label.indicator:SetVertexColor(0.5, 0.5, 0.5)
            label.indicator:SetAlpha(0.5)
        end
        label:Show()

        local minutes = math.floor(time / 60)
        local seconds = time % 60
        local text
        if minutes > 0 and seconds > 0 then
            text = string.format("%.0fm %.0fs", minutes, seconds)
        elseif minutes > 0 then
            text = string.format("%.0fm", minutes)
        elseif seconds > 0 then
            text = string.format("%.0fs", seconds)
        end
        label.text:SetText(text)

        label:SetSize(bar.db.height, 24)
        label:SetPoint("CENTER", bar, "LEFT", math.floor(CalculateOffset(time, bar:GetWidth())), 0)

        bar.labels[i] = label
    end

    for i, label in ipairs(bar.labels) do
        if not labels[i] then label:Hide() end
    end
end

function Addon:CreateCooldownBar(name, config)
    local bar = CreateFrame("Frame", addonName .. "_" .. name,
                            E.UIParent or _G.UIParent)
    bar:SetPoint("CENTER", E.UIParent or _G.UIParent, "CENTER", 0, 0)
    bar:CreateBackdrop("Transparent")

    --bar.backdrop:SetAlpha(0.5)
    bar.db = config
    bar.buttons = {}
    bar.labels = {}
    bar.CreateButton = CreateCooldownButton
    bar.Configure = ConfigureCooldownBar
    bar.Update = UpdateCooldownBar

    CreateMover(bar, addonName .. "_Mover", name)
    bar:Configure()
    bar:Update()

    return bar
end
