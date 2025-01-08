local AddOn = "PlateCastBar"
local select = select
local pairs = pairs
local tinsert = tinsert

-- Quick logger for debugging
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
}

local Textures = {
    Font   = "Interface\\AddOns\\".. AddOn .."\\Textures\\DorisPP.ttf",
    CastBar= "Interface\\AddOns\\".. AddOn .."\\Textures\\media\\Blinkii.tga",
}

if not _G[AddOn .. "_SavedVariables"] then
    _G[AddOn .. "_SavedVariables"] = {}
end
if not _G[AddOn .. "_SavedVariables"]["CastBar"] then
    _G[AddOn .. "_SavedVariables"]["CastBar"] = {}
end

-- Now set defaults if they’re missing:
if not _G[AddOn .. "_SavedVariables"]["CastBar"].Width then
    _G[AddOn .. "_SavedVariables"]["CastBar"].Width = 105
end
if not _G[AddOn .. "_SavedVariables"]["CastBar"].Height then
    _G[AddOn .. "_SavedVariables"]["CastBar"].Height = 11
end


-- Example saved variables with a single place to read Width/Height
_G[AddOn .. "_SavedVariables"] = {
    ["CastBar"] = {
        ["Width"]  = 105,
        ["Height"] = 11,   -- <--- Add a Height field here
        ["PointX"] = 15,
        ["PointY"] = -5,
    },
    ["Icon"] = {
        ["PointX"] = -62,
        ["PointY"] =  0,
    },
    ["Timer"] = {
        ["Anchor"] = "RIGHT",
        ["PointX"] =  52,
        ["PointY"] =  0,
        ["Format"] = "LEFT"
    },
    ["Spell"] = {
        ["Anchor"] = "LEFT",
        ["PointX"] =  -53,
        ["PointY"] =  0,
    },
    ["Enable"] = {
        ["Test"]       = false,
        ["Player Pet"] = true,
        ["Icon"]       = true,
        ["Timer"]      = true,
        ["Spell"]      = true,
    },
}

-- This table will hold references to the castbar frames by unit
local castbarsByUnit = {}
local width  = 95
local height = 7

---------------------------------------------------------------------
-- 1) A helper function to update size & positions consistently
---------------------------------------------------------------------
local function UpdateCastBarDimensions(CastBar)
    local sv = _G[AddOn .. "_SavedVariables"]
	

    -- The castbar frame itself
    CastBar:SetWidth(width)
    CastBar:SetHeight(height)

    -- The actual bar texture
	CastBar.Texture:ClearAllPoints()
	CastBar.Texture:SetPoint("LEFT", CastBar, "LEFT", 0, 0)
	CastBar.Texture:SetWidth(width)
	CastBar.Texture:SetHeight(height)

    -- The border can scale relative to width or height
    CastBar.Border:SetWidth(width + 4)
    CastBar.Border:SetHeight(height + 4)

    -- The icon position is set by user offsets; size is your choice
    -- or you might scale it proportionally to castbar height:
    -- e.g. Icon is 1.4 * castbar height (40%)
    local iconSize = math.floor(height * 1.5)
    CastBar.Icon:SetWidth(iconSize)
    CastBar.Icon:SetHeight(iconSize)
    CastBar.Icon:ClearAllPoints()
    CastBar.Icon:SetPoint("RIGHT", CastBar, "LEFT", -5, 0)
	
	CastBar.IconBorder:ClearAllPoints()
    CastBar.IconBorder:SetPoint("CENTER", CastBar.Icon, "CENTER", 0, 0)
    CastBar.IconBorder:SetWidth(iconSize + 1)
    CastBar.IconBorder:SetHeight(iconSize + 1)

    -- Re-anchor SpellName and CastTime if you want them to shift
    -- with width/height changes, or they can remain absolute
    local SpellSV = sv.Spell
	CastBar.SpellName:ClearAllPoints()
    CastBar.SpellName:SetPoint("LEFT", CastBar, "LEFT", 0, 0)

    local TimerSV = sv.Timer
    CastBar.CastTime:ClearAllPoints()
    CastBar.CastTime:SetPoint("RIGHT", CastBar, "RIGHT", 0, 0)
end

---------------------------------------------------------------------
-- 2) Creating a single castbar for a given unit's nameplate
---------------------------------------------------------------------
local function UnitCastBar_Create(unit, namePlate)
    local sv = _G[AddOn .. "_SavedVariables"]
    local frameName = AddOn .. "_Frame_" .. unit .. "CastBar"
    local CastBar = CreateFrame("Frame", frameName, namePlate)

    CastBar:SetFrameStrata("BACKGROUND")
    CastBar:SetPoint("TOP", namePlate, "BOTTOM", 0, 22)
    CastBar:Hide()

    -- Bar texture
    local Texture = CastBar:CreateTexture(nil, "ARTWORK", nil, 1)
    Texture:SetTexture(Textures.CastBar)
    
	CastBar.Texture = Texture


    -- Icon
    local Icon = CastBar:CreateTexture(nil, "ARTWORK", nil, 2)
    Icon:Show()  -- We'll hide it if user disabled in a sec

    local IconBorder = CastBar:CreateTexture(nil, "BACKGROUND")
	

    -- SpellName
    local SpellName = CastBar:CreateFontString(nil)
    SpellName:SetFont(Textures.Font, 6, "OUTLINE")

    -- CastTime
    local CastTime = CastBar:CreateFontString(nil)
    CastTime:SetFont(Textures.Font, 7, "OUTLINE")

    -- Border
    local Border = CastBar:CreateTexture(nil, "BACKGROUND")
    Border:SetPoint("CENTER", CastBar, "CENTER")

    -- Background
    local Background = CastBar:CreateTexture(nil,"BORDER")
    Background:SetTexture(1/10, 1/10, 1/10, 1)
    Background:SetAllPoints(CastBar)

    -- Store references
    CastBar.Texture    = Texture
    CastBar.Icon       = Icon
    CastBar.IconBorder = IconBorder
    CastBar.SpellName  = SpellName
    CastBar.CastTime   = CastTime
    CastBar.Border     = Border
    CastBar.unit       = unit

    -- Show/Hide sub-elements based on user "Enable"
    if not sv.Enable.Icon  then Icon:Hide() IconBorder:Hide() end
    if not sv.Enable.Spell then SpellName:Hide() end
    if not sv.Enable.Timer then CastTime:Hide() end

    -- Now call our dimension update
    UpdateCastBarDimensions(CastBar)

    castbarsByUnit[unit] = CastBar
    return CastBar
end

---------------------------------------------------------------------
-- 3) The main OnUpdate logic, using the dimension function
--    to keep everything consistent
---------------------------------------------------------------------
local function UpdateCastBar(unit, isChannel)
    local CastBar = castbarsByUnit[unit]
    if not CastBar or not CastBar:IsShown() then return end

    local name, _, text, texture, startTime, endTime
    if isChannel then
        name, _, text, texture, startTime, endTime = UnitChannelInfo(unit)
    else
        name, _, text, texture, startTime, endTime = UnitCastingInfo(unit)
    end

    if name then
        if string.len(name) > 17 then
            name = string.sub(name,1,17) .. ".. "
        end
        CastBar.SpellName:SetText(name)
        CastBar.Icon:SetTexture(texture)
        CastBar.Border:SetTexture(0,0,0,1)
        CastBar.IconBorder:SetTexture(0,0,0,1)

        local currentTime = GetTime()
        local maxCastTime = (endTime - startTime) / 1000
        local castTime    = (isChannel)
                          and ((endTime/1000) - currentTime)
                           or (currentTime - (startTime/1000))

        local sv = _G[AddOn .. "_SavedVariables"]
        local barWidth = width  -- Single place to read width
        -- "fill" the bar
        CastBar.Texture:SetWidth(barWidth * (castTime / maxCastTime))
        CastBar.Texture:ClearAllPoints()
        CastBar.Texture:SetPoint("CENTER", CastBar, "CENTER",
            -barWidth/2 + barWidth*(castTime/maxCastTime)/2, 0)
        CastBar.Texture:SetVertexColor(1, 0.5, 0)

        local total    = string.format("%.2f", maxCastTime)
        local leftTime = (isChannel)
                         and string.format("%.1f", castTime)
                          or string.format("%.1f", (maxCastTime - castTime))

        local timerFormat = sv.Timer.Format
        if timerFormat == "LEFT" then
            CastBar.CastTime:SetText(leftTime)
        elseif timerFormat == "TOTAL" then
            CastBar.CastTime:SetText(total)
        elseif timerFormat == "BOTH" then
            CastBar.CastTime:SetText(leftTime .. " / " .. total)
        end
    else
        -- no cast => hide
        CastBar:Hide()
    end
end

---------------------------------------------------------------------
-- 4) The main frame events
---------------------------------------------------------------------
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

Frame:SetScript("OnEvent", function(self, event, unit, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        -- Usually, you'd do initialization, etc.
        if not _G[AddOn .. "_PlayerEnteredWorld"] then
            _G[AddOn .. "_PlayerEnteredWorld"] = true
        end

    elseif event == "NAME_PLATE_UNIT_ADDED" then
        local namePlate = C_NamePlate.GetNamePlateForUnit(unit)
        if namePlate then
			local CastBar = castbarsByUnit[unit]
			if not CastBar then
				CastBar = UnitCastBar_Create(unit, namePlate)
			end
			 if UnitCastingInfo(unit) or UnitChannelInfo(unit) then
                CastBar:Show()
                UpdateCastBar(unit, UnitChannelInfo(unit) ~= nil)
            end 
        end

    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        if castbarsByUnit[unit] then
            castbarsByUnit[unit]:Hide()
            castbarsByUnit[unit] = nil
        end

    elseif event == "UNIT_SPELLCAST_START"
        or event == "UNIT_SPELLCAST_DELAYED"
        or event == "UNIT_SPELLCAST_CHANNEL_START"
        or event == "UNIT_SPELLCAST_CHANNEL_UPDATE"
    then
        if castbarsByUnit[unit] then
            local isChannel = (event == "UNIT_SPELLCAST_CHANNEL_START" 
                            or event == "UNIT_SPELLCAST_CHANNEL_UPDATE")
            castbarsByUnit[unit]:Show()
            UpdateCastBar(unit, isChannel)
        end

    elseif event == "UNIT_SPELLCAST_INTERRUPTED"
        or event == "UNIT_SPELLCAST_STOP"
        or event == "UNIT_SPELLCAST_FAILED"
    then
        if castbarsByUnit[unit] then
            castbarsByUnit[unit]:Hide()
        end

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- typically we do nothing special; the castbar fades on its own
    end
end)

---------------------------------------------------------------------
-- 5) OnUpdate to keep updating times
---------------------------------------------------------------------
Frame:SetScript("OnUpdate", function(self, elapsed)
    for unit, CastBar in pairs(castbarsByUnit) do
        if CastBar:IsShown() then
            local isChannel = (UnitChannelInfo(unit) ~= nil)
            UpdateCastBar(unit, isChannel)
        end
    end
end)