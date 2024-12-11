local AddOn = "PlateCastBar"
local select = select
local pairs = pairs
local tinsert = tinsert

local function log(...)
    local text = ""
    for i = 1, select("#", ...) do
        text = text .. " " .. tostring(select(i, ...))
    end
    DEFAULT_CHAT_FRAME:AddMessage(text)
end

local Table = {
    ["Nameplates"] = {},
    ["CastBar"] = {
        ["Blizzard"] = {
            Width = 123,
            Height = 30.73,
        },
    },
    ["CheckButtons"] = {
        ["Test"] = {
            ["PointX"] = 170,
            ["PointY"] = -10,
        },
        ["Player Pet"] = {
            ["PointX"] = 300,
            ["PointY"] = -90,
        },
        ["Icon"] = {
            ["PointX"] = 300,
            ["PointY"] = -120,
        },
        ["Timer"] = {
            ["PointX"] = 300,
            ["PointY"] = -150,
        },
        ["Spell"] = {
            ["PointX"] = 300,
            ["PointY"] = -180,
        },
    },
}
local Textures = {
    Font = "Interface\\AddOns\\".. AddOn .."\\Textures\\DorisPP.ttf",
    CastBar = "Interface\\AddOns\\".. AddOn .."\\Textures\\LiteStep.tga",
}

_G[AddOn .. "_SavedVariables"] = {
    ["CastBar"] = {
        ["Width"] = 105,
        ["PointX"] = 15,
        ["PointY"] = -5,
    },
    ["Icon"] = {
        ["PointX"] = -62,
        ["PointY"] = 0,
    },
    ["Timer"] = {
        ["Anchor"] = "RIGHT",
        ["PointX"] = 52,
        ["PointY"] = 0,
        ["Format"] = "LEFT"
    },
    ["Spell"] = {
        ["Anchor"] = "LEFT",
        ["PointX"] = -53,
        ["PointY"] = 0,
    },
    ["Enable"] = {
        ["Test"] = false,
        ["Player Pet"] = true,
        ["Icon"] = true,
        ["Timer"] = true,
        ["Spell"] = true,
    },
}

-- This table will hold references to the castbar frames by unit
local castbarsByUnit = {}

-- Create a single castbar for a given unit's nameplate
local function UnitCastBar_Create(unit, namePlate)
    local frameName = AddOn .. "_Frame_" .. unit .. "CastBar"
    local CastBar = CreateFrame("Frame", frameName, namePlate)
    CastBar:SetFrameStrata("BACKGROUND")
    CastBar:SetWidth(_G[AddOn .. "_SavedVariables"]["CastBar"]["Width"])
    CastBar:SetHeight(11)
    CastBar:SetPoint("TOP", namePlate, "BOTTOM", 0, 0)
    CastBar:Hide()

    local Texture = CastBar:CreateTexture(nil, "ARTWORK", nil, 1)
    Texture:SetHeight(11)
    Texture:SetTexture(Textures.CastBar)
    Texture:SetPoint("CENTER", CastBar, "CENTER")

    local Icon = CastBar:CreateTexture(nil, "ARTWORK", nil, 2)
    Icon:SetHeight(13)
    Icon:SetWidth(13)
    Icon:SetPoint("CENTER", CastBar, "CENTER",
        _G[AddOn .. "_SavedVariables"]["Icon"]["PointX"],
        _G[AddOn .. "_SavedVariables"]["Icon"]["PointY"])
    if _G[AddOn .. "_SavedVariables"]["Enable"]["Icon"] then
        Icon:Show()
    else
        Icon:Hide()
    end

    local IconBorder = CastBar:CreateTexture(nil,"BACKGROUND")
    IconBorder:SetHeight(16)
    IconBorder:SetWidth(16)
    IconBorder:SetPoint("CENTER", Icon, "CENTER")
    if _G[AddOn .. "_SavedVariables"]["Enable"]["Icon"] then
        IconBorder:Show()
    else
        IconBorder:Hide()
    end

    local SpellName = CastBar:CreateFontString(nil)
    SpellName:SetFont(Textures.Font, 9, "OUTLINE")
    SpellName:SetPoint(_G[AddOn .. "_SavedVariables"]["Spell"]["Anchor"],
        CastBar, "CENTER",
        _G[AddOn .. "_SavedVariables"]["Spell"]["PointX"],
        _G[AddOn .. "_SavedVariables"]["Spell"]["PointY"])
    if _G[AddOn .. "_SavedVariables"]["Enable"]["Spell"] then
        SpellName:Show()
    else
        SpellName:Hide()
    end

    local CastTime = CastBar:CreateFontString(nil)
    CastTime:SetFont(Textures.Font, 9, "OUTLINE")
    CastTime:SetPoint(_G[AddOn .. "_SavedVariables"]["Timer"]["Anchor"],
        CastBar, "CENTER",
        _G[AddOn .. "_SavedVariables"]["Timer"]["PointX"],
        _G[AddOn .. "_SavedVariables"]["Timer"]["PointY"])
    if _G[AddOn .. "_SavedVariables"]["Enable"]["Timer"] then
        CastTime:Show()
    else
        CastTime:Hide()
    end

    local Border = CastBar:CreateTexture(nil, "BACKGROUND")
    Border:SetPoint("CENTER", CastBar, "CENTER")
    Border:SetWidth(_G[AddOn .. "_SavedVariables"]["CastBar"]["Width"]+5)
    Border:SetHeight(16)

    local Background = CastBar:CreateTexture(nil, "BORDER")
    Background:SetTexture(1/10, 1/10, 1/10, 1)
    Background:SetAllPoints(CastBar)

    -- Store references
    CastBar.Texture = Texture
    CastBar.Icon = Icon
    CastBar.IconBorder = IconBorder
    CastBar.SpellName = SpellName
    CastBar.CastTime = CastTime
    CastBar.Border = Border
    CastBar.unit = unit

    castbarsByUnit[unit] = CastBar
    return CastBar
end

local Frame = CreateFrame("Frame")
Frame:RegisterEvent("PLAYER_ENTERING_WORLD")
Frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
Frame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
Frame:RegisterEvent("UNIT_SPELLCAST_START")
Frame:RegisterEvent("UNIT_SPELLCAST_DELAYED")
Frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
Frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
Frame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
Frame:RegisterEvent("UNIT_SPELLCAST_STOP")
Frame:RegisterEvent("UNIT_SPELLCAST_FAILED")
Frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

-- Update castbar logic
local function UpdateCastBar(unit, isChannel)
    local CastBar = castbarsByUnit[unit]
    if not CastBar or not CastBar:IsShown() then return end

    local name, nameSubtext, text, texture, startTime, endTime, _, castID, notInterruptible
    if not isChannel then
        name, nameSubtext, text, texture, startTime, endTime = UnitCastingInfo(unit)
    else
        name, nameSubtext, text, texture, startTime, endTime = UnitChannelInfo(unit)
    end

    if name then
        -- Update visuals
        if string.len(name) > 12 then 
            name = string.sub(name,1,12) .. ".. " 
        end
        CastBar.SpellName:SetText(name)
        CastBar.Icon:SetTexture(texture)
        CastBar.Border:SetTexture(0,0,0,1)
        CastBar.IconBorder:SetTexture(0,0,0,1)

        local currentTime = GetTime()
        local maxCastTime = (endTime - startTime) / 1000
        local castTime = isChannel and ((endTime/1000) - currentTime) or (currentTime - (startTime/1000))
        CastBar.Texture.castTime = castTime
        CastBar.Texture.maxCastTime = maxCastTime

        local Width = _G[AddOn .. "_SavedVariables"]["CastBar"]["Width"]
        CastBar.Texture:SetWidth(Width * (castTime/maxCastTime))
        local _, _, _, xOfs, yOfs = CastBar.Texture:GetPoint()
        CastBar.Texture:ClearAllPoints()
        if isChannel then
            CastBar.Texture:SetPoint("CENTER", CastBar, "CENTER", Width/2 - (Width * castTime/maxCastTime)* (1), yOfs)
        else
            CastBar.Texture:SetPoint("CENTER", CastBar, "CENTER", -Width/2 + Width*(castTime/maxCastTime)/2, yOfs)
        end

        CastBar.Texture:SetVertexColor(1, 0.5, 0)

        local total = string.format("%.2f", maxCastTime)
        local left = isChannel and string.format("%.1f", castTime) or string.format("%.1f", total - castTime)
        local timerFormat = _G[AddOn .. "_SavedVariables"]["Timer"]["Format"]
        if timerFormat == "LEFT" then
            CastBar.CastTime:SetText(left)
        elseif timerFormat == "TOTAL" then
            CastBar.CastTime:SetText(total)
        elseif timerFormat == "BOTH" then
            CastBar.CastTime:SetText(left .. " /" .. total)
        end
    else
        -- No cast, hide
        CastBar:Hide()
    end
end

-- OnUpdate handler to continuously update the castbars
Frame:SetScript("OnUpdate", function(self, elapsed)
    for unit, CastBar in pairs(castbarsByUnit) do
        if CastBar:IsShown() then
            local isChannel = UnitChannelInfo(unit) ~= nil
            UpdateCastBar(unit, isChannel)
        end
    end
end)

Frame:SetScript("OnEvent", function(self, event, unit, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        if not _G[AddOn .. "_PlayerEnteredWorld"] then
            _G[AddOn .. "_PlayerEnteredWorld"] = true
        end

    elseif event == "NAME_PLATE_UNIT_ADDED" then
        local namePlate = C_NamePlate.GetNamePlateForUnit(unit)
        if namePlate and not castbarsByUnit[unit] then
            UnitCastBar_Create(unit, namePlate)
        end

    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        -- Hide castbar for this unit
        if castbarsByUnit[unit] then
            castbarsByUnit[unit]:Hide()
            castbarsByUnit[unit] = nil
        end

    elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_DELAYED" 
        or event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
        if castbarsByUnit[unit] then
            local isChannel = (event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE")
            castbarsByUnit[unit]:Show()
            UpdateCastBar(unit, isChannel)
        end

    elseif event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_FAILED" then
        if castbarsByUnit[unit] then
            castbarsByUnit[unit]:Hide()
        end

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- If you want to do something special on spellcast succeeded, handle here.
        -- Otherwise, we typically let the castbar just vanish at the end of the cast.
    end
end)
