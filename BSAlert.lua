local BSAlertTimer = 0
local lastUpdate = 0
local updateInterval = .5
local BSAlert_combat = nil
local isLocked = true
local partyGUIDs = {}

local iconShown = false
local timerShown = false
local glowShown = false

local backdrop = {
    edgeFile = "Interface\\AddOns\\BSAlert\\border",
    edgeSize = 64,
    insets = { left = 64, right = 64, top = 64, bottom = 64 },
}
if not BSAlert then
    BSAlert = {
        timerPos       = { x = 0, y = -170 },
        iconPos        = { x = 0, y = -130 },
        enableGlow     = true,
        enableIcon     = false,
        enableTimer    = false,
        earlyGlow      = 5,
        timerFontSize  = 18,
        iconAlpha      = 0.6,
        iconSize       = 96,
		iconCombat = true,
		timerCombat = false,
    }
end

local BSAlertGlow = CreateFrame("Frame")
BSAlertGlow:SetFrameStrata("BACKGROUND")
BSAlertGlow:SetWidth(GetScreenWidth() * UIParent:GetEffectiveScale())
BSAlertGlow:SetHeight(GetScreenHeight() * UIParent:GetEffectiveScale())
BSAlertGlow:SetBackdrop(backdrop)
BSAlertGlow:SetPoint("CENTER", 0, 0)
BSAlertGlow:Hide()

local BSTimerframe = CreateFrame("FRAME", nil, UIParent)
BSTimerframe:SetWidth(48)
BSTimerframe:SetHeight(18)
BSTimerframe:SetPoint("CENTER", UIParent, "CENTER", BSAlert.timerPos.x or 0, BSAlert.timerPos.y or -170)
BSTimerframe:Hide()

BSTimerframe.texture = BSTimerframe:CreateTexture(nil, "ARTWORK")
BSTimerframe.texture:SetPoint("CENTER", BSTimerframe, "CENTER", 0, 0)
BSTimerframe.texture:SetWidth(24)
BSTimerframe.texture:SetHeight(24)
BSTimerframe.texture:SetAlpha(0.6)
BSTimerframe.texture:Show() 

BSTimerframe:SetMovable(true)
BSTimerframe:EnableMouse(true)
BSTimerframe:RegisterForDrag("LeftButton")

BSTimerframe.title = BSTimerframe:CreateFontString(nil, "OVERLAY")
BSTimerframe.title:SetFont("Fonts\\ARIALN.TTF", 18, "OUTLINE")
BSTimerframe.title:SetTextColor(1, 0, 0, 1)
BSTimerframe.title:SetPoint("CENTER", BSTimerframe.texture, "CENTER", 0, 0)
BSTimerframe.title:SetText("!")
BSTimerframe.title:Show()

local BSIconframe = CreateFrame("FRAME", nil, UIParent)
BSIconframe:SetWidth(96)
BSIconframe:SetHeight(96)
BSIconframe:SetPoint("CENTER", UIParent, "CENTER", BSAlert.iconPos.x or 0, BSAlert.iconPos.y or -130)
BSIconframe:Hide()

BSIconframe.texture = BSIconframe:CreateTexture(nil, "ARTWORK")
BSIconframe.texture:SetTexture("Interface\\Icons\\Ability_Warrior_BattleShout")
BSIconframe.texture:SetPoint("CENTER", BSIconframe, "CENTER", 0, 0)
BSIconframe.texture:SetWidth(96)
BSIconframe.texture:SetHeight(96)
BSIconframe.texture:SetAlpha(0.6)
BSIconframe.texture:Show()

BSIconframe:SetMovable(false)
BSIconframe:EnableMouse(false)
BSIconframe:RegisterForDrag("LeftButton")

local function InitOptions()
	if BSAlert.timerPos then
		local ux, uy = UIParent:GetCenter()
		BSTimerframe:ClearAllPoints()
		BSTimerframe:SetPoint("CENTER", UIParent, "CENTER",
			BSAlert.timerPos.x,
			BSAlert.timerPos.y
		)
	end
	if BSAlert.iconPos then
		local ux, uy = UIParent:GetCenter()
		BSIconframe:ClearAllPoints()
		BSIconframe:SetPoint("CENTER", UIParent, "CENTER",
			BSAlert.iconPos.x,
			BSAlert.iconPos.y
		)
	end
    BSIconframe:SetWidth(BSAlert.iconSize or 96)
    BSIconframe:SetHeight(BSAlert.iconSize or 96)
    BSIconframe.texture:SetWidth(BSAlert.iconSize or 96)
    BSIconframe.texture:SetHeight(BSAlert.iconSize or 96)
    BSIconframe.texture:SetAlpha(BSAlert.iconAlpha or 0.6)
    BSTimerframe.title:SetFont("Fonts\\ARIALN.TTF", BSAlert.timerFontSize or 18, "OUTLINE")
end


local function EnableDrag()
    BSTimerframe:SetMovable(true)
    BSTimerframe:EnableMouse(true)
    BSTimerframe:RegisterForDrag("LeftButton")
    BSTimerframe:SetScript("OnDragStart", function() this:StartMoving() end)
    BSTimerframe:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        local x, y = this:GetCenter()
        local ux, uy = UIParent:GetCenter()
        BSAlert.timerPos.x = math.floor(x - ux + 0.5)
        BSAlert.timerPos.y = math.floor(y - uy + 0.5)
    end)

    BSIconframe:SetMovable(true)
    BSIconframe:EnableMouse(true)
    BSIconframe:RegisterForDrag("LeftButton")
    BSIconframe:SetScript("OnDragStart", function() this:StartMoving() end)
    BSIconframe:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        local x, y = this:GetCenter()
        local ux, uy = UIParent:GetCenter()
        BSAlert.iconPos.x = math.floor(x - ux + 0.5)
        BSAlert.iconPos.y = math.floor(y - uy + 0.5)
    end)

end

local function DisableDrag()
    BSTimerframe:SetMovable(false)
    BSTimerframe:EnableMouse(false)
    BSTimerframe:SetScript("OnDragStart", nil)
    BSTimerframe:SetScript("OnDragStop", nil)
    BSIconframe:SetMovable(false)
    BSIconframe:EnableMouse(false)
    BSIconframe:SetScript("OnDragStart", nil)
    BSIconframe:SetScript("OnDragStop", nil)
end

local function CheckExistingBattleShout()
    local found = false
    for i = 0, 31 do
        local buffIndex = GetPlayerBuff(i, "HELPFUL")
        if buffIndex < 0 then break end
        local texture = GetPlayerBuffTexture(buffIndex)
        if texture == "Interface\\Icons\\Ability_Warrior_BattleShout" then
            local timeLeft = GetPlayerBuffTimeLeft(buffIndex)
            if timeLeft and timeLeft > 0 then
				lastUpdate = GetTime()
				BSAlertTimer = timeLeft
                BSTimerframe.title:SetText(math.floor(timeLeft))
                BSTimerframe.title:SetTextColor(1, 1, 1, 1)
                found = true
                break
            end
        end
    end
    if not found then
        BSAlertTimer = 0  
    end
end

function HasBuff()
    return BSAlertTimer > BSAlert.earlyGlow
end

local function UpdateVisibility()
    local showIcon = false
    local showTimer = false
    local showGlow = false

    if not isLocked then
        showIcon = BSAlert.enableIcon
        showTimer = BSAlert.enableTimer
		showIcon = true
        showTimer = true
        showGlow = false
    else

        if BSAlert.enableGlow and BSAlert_combat and (not HasBuff()) then
            showGlow = true
        end

        if BSAlert.enableIcon and (not HasBuff()) then
            if BSAlert.iconCombat then
                showIcon = BSAlert_combat and true or false
            else
                showIcon = true
            end
        end

        if BSAlert.enableTimer then
            if BSAlert.timerCombat then
                showTimer = BSAlert_combat and true or false
            else
                showTimer = true
            end
        end
    end

    if showIcon ~= iconShown then
        if showIcon then
            BSIconframe:Show()
        else
            BSIconframe:Hide()
        end
        iconShown = showIcon
    end

    if showTimer ~= timerShown then
        if showTimer then
            BSTimerframe.texture:SetAlpha(0.6)
            BSTimerframe.title:SetAlpha(1)
            BSTimerframe:Show()
        else
            BSTimerframe.texture:SetAlpha(0)
            BSTimerframe.title:SetAlpha(0)
            BSTimerframe:Hide()
        end
        timerShown = showTimer
    end

    if showGlow ~= glowShown then
        if showGlow then
            BSAlertGlow:Show()
        else
            BSAlertGlow:Hide()
        end
        glowShown = showGlow
    end
end


local function UpdateBS()
    local now = GetTime()
    if lastUpdate == 0 then lastUpdate = now return end
    if now - lastUpdate < updateInterval then return end

    local delta = now - lastUpdate
    lastUpdate = now

    if BSAlertTimer > 0 then
        BSAlertTimer = BSAlertTimer - delta
		BSTimerframe.title:SetText(math.floor(BSAlertTimer))
		BSTimerframe.title:SetTextColor(1, 1, 1, 1)
		UpdateVisibility() --dont love this here, maybe can change or add if needed flag?
        if BSAlertTimer < 0 then
            BSAlertTimer = 0
			lastUpdate = 0
			BSTimerframe.title:SetTextColor(1, 0, 0, 1) 
			BSTimerframe.title:SetText("!")
			BSAlertFrame:SetScript("OnUpdate", nil)
        end
    end
end

local function UpdatePartyGUIDs()
    partyGUIDs = {}

    local exists, playerGUID = UnitExists("player")
    if playerGUID then
        partyGUIDs[tostring(playerGUID)] = true
    end

    for i = 1, GetNumPartyMembers() do
        local unit = "party" .. i
        local exists, guid = UnitExists(unit)
        if guid then
            partyGUIDs[tostring(guid)] = true
            local name = UnitName(unit) or "unknown"
        end
    end
end

local function ToggleLock()
    if isLocked then
	    isLocked = false
        EnableDrag()
        BSTimerframe:Show()
		BSIconframe:Show()

        DEFAULT_CHAT_FRAME:AddMessage("BSAlert Frames Unlocked. Drag to reposition.")
    else
	    isLocked = true
        DisableDrag()
        DEFAULT_CHAT_FRAME:AddMessage("BSAlert Frames Locked.")
    end
	UpdateVisibility()
end


function BSAlert_OnLoad()
    this:RegisterEvent("PLAYER_REGEN_ENABLED")
    this:RegisterEvent("PLAYER_ENTERING_WORLD")
    this:RegisterEvent("PLAYER_REGEN_DISABLED")
    this:RegisterEvent("UNIT_CASTEVENT")
    this:RegisterEvent("PARTY_MEMBERS_CHANGED")
end

--option menu frames
local BSOptions = CreateFrame("Frame", "BSOptions", UIParent)
BSOptions:SetWidth(200)
BSOptions:SetHeight(360)
BSOptions:SetPoint("CENTER", 250, 0)
BSOptions:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
BSOptions:SetBackdropColor(0,0,0,0.85)
BSOptions.entries = 0
BSOptions:Hide()


BSOptions.title = BSOptions:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
BSOptions.title:SetPoint("TOP", 0, -8)
BSOptions.title:SetText("BSAlert Options")
--add hieght or font size ?

BSOptions.btnClose = CreateFrame("Button", nil, BSOptions)
BSOptions.btnClose:SetHeight(16)
BSOptions.btnClose:SetWidth(16)
BSOptions.btnClose:SetPoint("RIGHT", BSOptions.title, "RIGHT", 25, -5)
BSOptions.btnClose.caption = BSOptions.btnClose:CreateFontString(nil, "OVERLAY", "GameFontWhite")
BSOptions.btnClose.caption:SetFont(STANDARD_TEXT_FONT, 16)
BSOptions.btnClose.caption:SetText("x")
BSOptions.btnClose.caption:SetAllPoints()

BSOptions.btnClose:SetScript("OnClick", function()
    BSOptions:Hide()
end)


local function CreateConfig(parent, label, ctype, getter, setter, min, max, step)
    parent.entries = (parent.entries or 0) + 1
    local yOffset
    if ctype == "boolean" then
        yOffset = -parent.entries * 25 - 5  -- 
    else
        yOffset = -parent.entries * 45 + 140 -- sliders
    end
    local text = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    text:SetPoint("TOPLEFT", 10, yOffset)
    text:SetText(label)

    if ctype == "boolean" then
        local chk = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        chk:SetPoint("LEFT", text, "RIGHT", 10, 0)
        chk:SetChecked(getter())
        chk:SetScript("OnClick", function()
            setter(chk:GetChecked())
        end)
        return chk

    elseif ctype == "number" then
        local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
        slider:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 10, -5)
        slider:SetWidth(160)
        slider:SetHeight(16)
        slider:SetOrientation("HORIZONTAL")
        slider:SetMinMaxValues(min or 0, max or 100)
        slider:SetValueStep(step or 1)

        local startVal = getter() or min or 0
        slider:SetValue(startVal)
        local valText = slider:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        valText:SetPoint("TOP", slider, "BOTTOM", 0, 2)
        valText:SetText(startVal)

        slider:SetScript("OnValueChanged", function(self, val)
            val = val or this:GetValue()
            setter(val)
            if type(val) == "number" then
				local rounded = floor(val * 100 + 0.5) / 100 
				valText:SetText(rounded)
			else
				valText:SetText(val)
			end

            if label == "Icon Size" then
                BSIconframe:SetWidth(val)
                BSIconframe:SetHeight(val)
                BSIconframe.texture:SetWidth(val)
                BSIconframe.texture:SetHeight(val)
            elseif label == "Timer Font Size" then
                BSTimerframe.title:SetFont("Fonts\\ARIALN.TTF", val, "OUTLINE")
            elseif label == "Icon Transparency" then
                BSIconframe.texture:SetAlpha(val)
            end
        end)
        return slider
    end
end

local function BuildOptions()
    CreateConfig(BSOptions, "Lock Frames", "boolean",
        function() return isLocked end,
        function(val) if val ~= isLocked then ToggleLock() end end
    )
    CreateConfig(BSOptions, "Enable Screen Glow", "boolean",
        function() return BSAlert.enableGlow end,
        function(val) BSAlert.enableGlow = val
UpdateVisibility()
		end
    )
    CreateConfig(BSOptions, "Enable Icon", "boolean",
        function() return BSAlert.enableIcon end,
        function(val) BSAlert.enableIcon = val 
		UpdateVisibility()
		end
    )
	local iconCombatChk = CreateConfig(BSOptions, "    Only in Combat", "boolean",
		function() return BSAlert.iconCombat end,
		function(val) BSAlert.iconCombat = val 
		UpdateVisibility()
		end
	)
	iconCombatChk:SetScript("OnUpdate", function()
		local enabled = BSAlert.enableIcon
		iconCombatChk:EnableMouse(enabled)
		iconCombatChk:SetAlpha(enabled and 1 or 0.3)
	end)
    CreateConfig(BSOptions, "Enable Timer", "boolean",
        function() return BSAlert.enableTimer end,
        function(val) BSAlert.enableTimer = val
			UpdateVisibility()
		end
    )
	local timerOnlyCombatChk = CreateConfig(BSOptions, "    Only in Combat", "boolean",
		function() return BSAlert.timerCombat end,
		function(val) BSAlert.timerCombat = val
UpdateVisibility()
		end
	)

	timerOnlyCombatChk:SetScript("OnUpdate", function()
		local enabled = BSAlert.enableTimer
		timerOnlyCombatChk:EnableMouse(enabled)
		timerOnlyCombatChk:SetAlpha(enabled and 1 or 0.3)
	end)
    CreateConfig(BSOptions, "Timer Font Size", "number",
        function() return BSAlert.timerFontSize or 14 end,
        function(val)
            BSAlert.timerFontSize = val
            BSTimerframe.title:SetFont("Fonts\\ARIALN.TTF", val, "OUTLINE")
        end,
        8, 32, 1
    )
    CreateConfig(BSOptions, "Icon Transparency", "number",
        function() return BSAlert.iconAlpha or 0.5 end,
	   function(val)
		val = math.max(0, math.min(1, val))
		local rounded = floor(val * 100 + 0.5) / 100   -- round to 2 decimals
		BSAlert.iconAlpha = rounded
		BSIconframe.texture:SetAlpha(rounded)
	end,
        0, 1, 0.05
    )
    CreateConfig(BSOptions, "Icon Size", "number",
        function() return BSAlert.iconSize or 48 end,
        function(val)
            BSAlert.iconSize = val
            BSIconframe:SetWidth(val)
            BSIconframe:SetHeight(val)
            BSIconframe.texture:SetWidth(val)
            BSIconframe.texture:SetHeight(val)
        end,
        0, 500, 8
    )
    CreateConfig(BSOptions, "Early Warning Icon/Glow", "number",
        function() return BSAlert.earlyGlow or 5 end,
        function(val) BSAlert.earlyGlow = val end,
        1, 30, 1
    )
end

BSOptions:SetMovable(true)
BSOptions:EnableMouse(true)
BSOptions:RegisterForDrag("LeftButton")
BSOptions:SetScript("OnDragStart", function(self) this:StartMoving() end)
BSOptions:SetScript("OnDragStop", function(self) this:StopMovingOrSizing() end)


function BSAlert_OnEvent(event)
	local NeedUpdate = false
    if event == "PLAYER_ENTERING_WORLD" then
        local HasUnitXP = pcall(UnitXP, "nop", "nop")
        if HasUnitXP then
            UpdatePartyGUIDs()
			InitOptions()
			BuildOptions()
			CheckExistingBattleShout()
			if BSAlertTimer > 0 then
				BSAlertFrame:SetScript("OnUpdate", UpdateBS)
			end
			NeedUpdate = true
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[BSAlert]|r loaded.")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cff00ffff[BSAlert]|r NOT loaded. UnitXP NOT Detected")
        end
        this:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end

    if event == "PLAYER_REGEN_DISABLED" then
        BSAlert_combat = true
		NeedUpdate = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        BSAlert_combat = nil
		NeedUpdate = true
    end

    if event == "PARTY_MEMBERS_CHANGED" then
        UpdatePartyGUIDs()
    end

	if event == "UNIT_CASTEVENT" then
		if arg4 ~= 25289 then
			return
		end

		if partyGUIDs[arg1] then
			local dist = UnitXP("distanceBetween", "player", arg1)
			if dist and dist > 20 then
				return
			end
			NeedUpdate = true
			BSAlertTimer = 120
			lastUpdate = GetTime()
			BSTimerframe.title:SetText(120)
			BSTimerframe.title:SetTextColor(1, 1, 1, 1)
			BSAlertFrame:SetScript("OnUpdate", UpdateBS)
		end
	end
	if NeedUpdate then 
	UpdateVisibility()
	end
end


SLASH_BS1 = "/BS"
SlashCmdList["BS"] = function(msg)
    msg = string.lower(msg or "")
    if msg == "" or msg == "opt" or msg == "options" then
        if BSOptions:IsShown() then
            BSOptions:Hide()
        else
            BSOptions:Show()
        end
    end
end

