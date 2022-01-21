local addonName, addonTable = ...
local Addon = addonTable[1]
local E, L, V, P, G = unpack(ElvUI)
local S = E:GetModule("Skins")
local LAB = E.Libs.LAB

local MIN_DURATION = 3
local MAX_DURATION = 300
local TARGET_FPS = 60
local SMOOTHING_AMOUNT = 0.33
local WEAPON_ENCHANT_MAIN = "WEAPON_ENCHANT_MAIN"
local WEAPON_ENCHANT_OFFHAND = "WEAPON_ENCHANT_OFFHAND"
local WEAPON_ENCHANT_RANGED = "WEAPON_ENCHANT_RANGED"
local COOLDOWN_TYPES = {
    SPELL = "SPELL",
    ITEM = "ITEM",
    WEAPON_ENCHANT = "WEAPON_ENCHANT"
}

function Addon:Print(value, ...)
    print(Addon.title .. ":", string.format(value, ...))
end

function Addon:PrintError(value, ...)
    print(Addon.title .. ": error ", string.format(value, ...))
end

function Addon:IsCloseEnough(new, target, range)
	if range > 0 then
		return abs((new - target) / range) <= 0.001
	end

	return true
end

local function FixNormalTextureSize(button)
    local normalTexture = button:GetNormalTexture()
    if normalTexture then
        local texturePath = normalTexture:GetTexture()
        if texturePath == "Interface\\Buttons\\UI-Quickslot2" then
            local size = 66 * (button:GetWidth() / 36)
            normalTexture:SetSize(size, size)
        end
    end
end

local function CreateMover(frame, name, textString)
    E:CreateMover(frame, name, textString, nil, nil, nil, "ALL,ACTIONBARS")
end

local function CalculateOffset(timeLeft, range)
    return max(0, min(1, log10(timeLeft * 0.5) / log10(MAX_DURATION * 0.5)) * range)
end

local function AddCooldown(bar, name, id, start, duration, texture, type)
    local cd = bar.cooldowns[name]
    if duration < MIN_DURATION then
        return
    elseif cd then
        cd.start = start
        cd.duration = duration
        cd.texture = texture
        bar:UpdateCooldown(cd)
        return
    end

    cd = CreateFrame("Frame", bar:GetName().."_"..name, bar, BackdropTemplateMixin and "BackdropTemplate")
    cd.id = id
    cd.name = name
    cd.start = start
    cd.duration = duration
    cd.texture = texture
    cd.type = type
    cd.bar = bar

    cd.icon = cd:CreateTexture(nil, "ARTWORK")
    cd.icon:SetTexture(texture)
    cd.icon:SetAllPoints(cd)    
    S:HandleIcon(cd.icon, true)

    cd.cooldown = CreateFrame("Cooldown", cd:GetName().."Cooldown", cd, "CooldownFrameTemplate")
    cd.cooldown:SetInside()
    E:RegisterCooldown(cd.cooldown)

    cd.enabled = false
    cd.Enable = function(self)
        self.offset = 0
        self.enabled = true
		CooldownFrame_Set(self.cooldown, self.start, self.duration, true)        
        self:Show()
        --Addon:Print("Enabled cooldown for %s. Duration: %.1f second(s).", name, duration)
    end
    cd.Disable = function(self)
        self.enabled = false
        self:Hide()
        --Addon:Print("Disabled cooldown for %s.", name)
    end
    cd:SetScript("OnEnter", function(self)
        local timeLeft = self.start + self.duration - GetTime()
        local hours = floor(mod(timeLeft, 86400) / 3600)
        local minutes = floor(mod(timeLeft, 3600) / 60)
        local seconds = floor(mod(timeLeft, 60))

        _G.GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        local text
        if hours > 0 then            
            text = string.format("%s: %.0fh %.0fm %.0fs.", self.name, hours, minutes, seconds)
        elseif minutes > 0 then
            text = string.format("%s: %.0fm %.0fs.", self.name, minutes, seconds)
        else
            text = string.format("%s: %.0f second(s).", self.name, seconds)
        end
        _G.GameTooltip:SetText(string.format("|T%s:20:20:0:0:64:64:5:59:5:59:%d|t %s", self.texture, 40, text))
        _G.GameTooltip:Show()
    end)
    cd:SetScript("OnLeave", function(self)
        _G.GameTooltip:Hide()
    end)

    bar.cooldowns[name] = cd
    bar:UpdateCooldown(cd)
end

local function UpdateCooldown(bar, cd)
    if not cd then
        return
    end

    if cd.type == COOLDOWN_TYPES.SPELL then        
        local start, duration = GetSpellCooldown(cd.id)
        if start then
            cd.start = start
            cd.duration = duration
        end
    end

    local timeLeft = cd.start + cd.duration - GetTime()

    if cd.enabled and (timeLeft < 0.01) then
        cd:Disable()
    elseif (not cd.enabled) and (timeLeft > 0.01) then
        cd:Enable()
    end
    
    if cd.enabled then
        cd:SetSize(bar.db.iconSize, bar.db.iconSize)

        local width = bar:GetWidth()
        local range = width - cd:GetWidth()
        local newOffset = CalculateOffset(timeLeft, range)

        cd.offset = cd.offset and Lerp(newOffset, cd.offset, 0.05) or newOffset
        if math.abs(cd.offset - newOffset) <= 0.001 then
            cd.offset = newOffset
        end

        cd:SetPoint("LEFT", bar, "LEFT", cd.offset, 0)
    end
end

local function ScanActions(bar)
    local _, name, start, duration, enabled, texture
    local actionType, id
    local enabled
    for i = 1, 120 do
        actionType, id, subType = GetActionInfo(i)
        if actionType == "item" then
            name, _, _, _, _, _, _, _, _, texture = GetItemInfo(id)
            if spell then
                start, duration, enabled = GetItemCooldown(id)
                if enabled then
                    bar:AddCooldown(name, id, start, duration, texture, COOLDOWN_TYPES.ITEM)
                else
                    bar:EndCooldown(name)
                end
            end
        elseif actionType == "spell" then            
            name, _, texture = GetSpellInfo(id)
            start, duration, enabled = GetSpellCooldown(id)
            if enabled then
                bar:AddCooldown(name, id, start, duration, texture, COOLDOWN_TYPES.SPELL)
            else
                bar:EndCooldown(name)
            end
        end
    end
    for i = 1, 19 do
        id = GetInventoryItemID("player", i)
        if id then
            name, _, _, _, _, _, _, _, _, texture = GetItemInfo(id)
            if name then
                start, duration, enabled = GetItemCooldown(id)
                if enabled then
                    bar:AddCooldown(name, id, start, duration, texture, COOLDOWN_TYPES.ITEM)
                else
                    bar:EndCooldown(name)
                end
            end
        end
    end
end

local function ScanPlayerSpellBook(bar)
    for i = 1, GetNumSpellTabs() do
        local _, _, offset, numSlots = GetSpellTabInfo(i)
        for j = offset + 1, offset + numSlots do
            local id = select(2, GetSpellBookItemInfo(j, BOOKTYPE_SPELL))
            if id then
                local name, _, texture = GetSpellInfo(id)
                local start, duration, enabled = GetSpellCooldown(id)
                if enabled then
                    bar:AddCooldown(name, id, start, duration, texture, COOLDOWN_TYPES.SPELL)
                else
                    bar:EndCooldown(name)
                end
            end
        end
    end
end

local function ScanWeaponEnchants(bar)
    local hasMainHandEnchant, mainHandExpiration, mainHandCharges, hasOffHandEnchant, offHandExpiration, offHandCharges, hasThrownEnchant, thrownExpiration, thrownCharges = GetWeaponEnchantInfo()

    if hasMainHandEnchant then
        local texture = GetInventoryItemTexture("player", select(1, GetInventorySlotInfo("MainHandSlot")))
        bar:AddCooldown(WEAPON_ENCHANT_MAIN, nil, GetTime(), mainHandExpiration / 1000, texture, COOLDOWN_TYPES.WEAPON_ENCHANT)
    else
        bar:UpdateCooldown(bar.cooldowns[WEAPON_ENCHANT_MAIN])
    end
    if hasOffHandEnchant and offHandExpiration then
        local texture = GetInventoryItemTexture("player", select(1, GetInventorySlotInfo("SecondaryHandSlot")))
        bar:AddCooldown(WEAPON_ENCHANT_OFFHAND, nil, GetTime(), offHandExpiration / 1000, texture, COOLDOWN_TYPES.WEAPON_ENCHANT)
    else
        bar:UpdateCooldown(bar.cooldowns[WEAPON_ENCHANT_MAIN])
    end
    if hasThrownEnchant and thrownExpiration then
        local texture = GetInventoryItemTexture("player", select(1, GetInventorySlotInfo("RangedSlot")))
        bar:AddCooldown(WEAPON_ENCHANT_RANGED, nil, GetTime(), thrownExpiration / 1000, texture, COOLDOWN_TYPES.WEAPON_ENCHANT)
    else
        bar:UpdateCooldown(bar.cooldowns[WEAPON_ENCHANT_MAIN])
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
    bar.cooldowns = {}
    bar.name = name

    bar.AddCooldown = AddCooldown
    bar.UpdateCooldown = UpdateCooldown
    bar.ScanActions = ScanActions
    bar.ScanPlayerSpellBook = ScanPlayerSpellBook
    bar.ScanWeaponEnchants = ScanWeaponEnchants
    
    bar:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
    bar:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    bar:RegisterEvent("UNIT_INVENTORY_CHANGED")
    bar:HookScript("OnEvent", function(self, event)
        if event == "ACTIONBAR_UPDATE_COOLDOWN" then
            bar:ScanActions()
        elseif event == "SPELL_UPDATE_COOLDOWN" then
            bar:ScanPlayerSpellBook()
        elseif event == "UNIT_INVENTORY_CHANGED" then
            bar:ScanWeaponEnchants()
        end
    end)

    CreateMover(bar, addonName .. "_Mover", name)

    bar:ScanActions()
    bar:ScanPlayerSpellBook()
    bar:ScanWeaponEnchants()

    bar:SetSize(bar.db.width, bar.db.height)

    local labels = {
        {5, "5"}, {10, "10"}, {30, "30"}, {60, "1m"}, {120, "2m"}, {180, "3m"}, {300, "5m"}
    }
    for i, labelData in ipairs(labels) do
        local label = CreateFrame("Frame", nil, bar)

        label.text = label:CreateFontString(nil, "BACKGROUND")
        label.text:SetAllPoints()
        label.text:SetJustifyH("CENTER")
        label.text:SetJustifyV("CENTER")
        label.text:SetShadowOffset(1, -1)
        label.text:SetFont(_G.STANDARD_TEXT_FONT, 11)
        label.text:SetText(labelData[2])
        label.text:SetTextColor(0.5, 0.5, 0.5)

        label.indicator = label:CreateTexture(nil, "BACKGROUND")
        label.indicator:SetTexture(E.media.blankTex)
        label.indicator:SetPoint("TOP", label, "TOP", 0, -2)
        label.indicator:SetPoint("BOTTOM", label, "BOTTOM", 0, 2)
        label.indicator:SetWidth(1)
        label.indicator:SetVertexColor(0.5, 0.5, 0.5)
        label.indicator:SetAlpha(0.5)

        label:SetSize(bar.db.height, 24)
        local offset = math.floor(CalculateOffset(labelData[1], bar:GetWidth()))
        label:SetPoint("CENTER", bar, "LEFT", offset, 0)
    end

    return bar
end

function Addon:UpdateCooldownBar(bar)
     if not bar then
         return
     end

     bar:SetSize(bar.db.width, bar.db.height)

     for name, cd in pairs(bar.cooldowns) do
        bar:UpdateCooldown(cd)
    end
end
