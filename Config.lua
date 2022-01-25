local addonName, addonTable = ...
local Addon = addonTable[1]
local E, L, V, P, G = unpack(ElvUI)

Addon.DEFAULT_LABELS = {5, 15, 30, 60, 120, 180, 300}
Addon.FILTERS = {
    NONE = "NONE"
}

local function GetOptionValue(setting)
    local value = E.db[addonName]
    for i, name in ipairs(setting) do
        value = value[name]
    end

    return value
end

local function GetDefaultOptionValue(setting)
    local value = P[addonName]
    for i, name in ipairs(setting) do
        value = value[name]
    end

    return value
end

local function SetOptionValue(setting, val)
    local value = E.db[addonName]
    for i, name in ipairs(setting) do
        if i == #setting then
            value[name] = val
        else
            value = value[name]
        end
    end

    return value
end

local function CreateToggleOption(caption, desc, order, width, setting, tristate, disabled, hidden)
    return {
        type = "toggle",
        name = caption,
        desc = desc,
        order = order,
        width = width,
        tristate = tristate,
        disabled = disabled,
        hidden = hidden,
        get = function(info)
            return GetOptionValue(setting)
        end,
        set = function(info, value)
            SetOptionValue(setting, value)
            Addon:OnSettingChanged(setting)
        end
    }
end

local function CreateRangeOption(caption, desc, order, min, max, step, setting, disabled, hidden)
    return {
        type = "range",
        name = caption,
        desc = desc,
        order = order,
        min = min,
        max = max,
        step = step,
        disabled = disabled,
        hidden = hidden,
        get = function(info)
            return GetOptionValue(setting)
        end,
        set = function(info, value)
            SetOptionValue(setting, value)
            Addon:OnSettingChanged(setting)
        end
    }
end

local function CreateColorOption(caption, order, setting, noAlpha, disabled, hidden)
    return {
        order = order,
        type = "color",
        name = caption,
        hasAlpha = not noAlpha,
        disabled = disabled,
        hidden = hidden,
        get = function(info)
            local t = GetOptionValue(setting)
            local d = GetDefaultOptionValue(setting)
            if d then
                return t[1], t[2], t[3], t[4], d[1], d[2], d[3], d[4] or 1
            elseif t then
                return t[1], t[2], t[3], t[4]
            end
        end,
        set = function(info, r, g, b, a)
            local t = GetOptionValue(setting)
            t[1], t[2], t[3], t[4] = r, g, b, a
            Addon:OnSettingChanged(setting)
        end
    }
end

if E.db[addonName] == nil then
    E.db[addonName] = {}
end
P[addonName] = {
    bars = {
        ["Cooldowns"] = {
            width = 396,
            height = 30,
            iconSize = 30,
            showLabels = true,
            filter = Addon.FILTERS.NONE
        }
    }
}

function Addon:InsertOptions()
    local options = {
        order = 100,
        type = "group",
        name = Addon.title,
        childGroups = "tab",
        args = {
            name = {order = 1, type = "header", name = Addon.title},
            layout = {
                order = 20,
                type = "group",
                name = L["Layout"],
                args = {
                    width = CreateRangeOption(L["Width"], nil, 1, 1, 3000, 1, {"bars", "Cooldowns", "width"}),
                    height = CreateRangeOption(L["Height"], nil, 2, 1, 3000, 1, {"bars", "Cooldowns", "height"}),
                    iconSize = CreateRangeOption(L["Icon Size"], nil, 3, 1, 120, 1, {"bars", "Cooldowns", "iconSize"}),
                    showLabels = CreateToggleOption(L["Show Labels"], nil, 4, "full", {"bars", "Cooldowns", "showLabels"})
                }
            }
        }
    }

    E.Options.args[addonName] = options
end
