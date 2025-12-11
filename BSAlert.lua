local BSAlertTimer = 0
local lastUpdate = 0
local updateInterval = 1
local backdrop = {
    edgeFile = "Interface\\AddOns\\BSAlert\\border",
    edgeSize = 64,
    insets = { left = 64, right = 64, top = 64, bottom = 64 },
}
local BSAlert_combat = nil

local BSAlert = CreateFrame("Frame")
BSAlert:SetFrameStrata("BACKGROUND")
BSAlert:SetWidth(GetScreenWidth() * UIParent:GetEffectiveScale())
BSAlert:SetHeight(GetScreenHeight() * UIParent:GetEffectiveScale())
BSAlert:SetBackdrop(backdrop)
BSAlert:SetPoint("CENTER", 0, 0)
BSAlert:Hide()

local partyGUIDs = {}

function HasBuff()
    return BSAlertTimer > 0
end

local function UpdateBS()
    local now = GetTime()
    if lastUpdate == 0 then lastUpdate = now end
    if now - lastUpdate < updateInterval then
        return
    end
	local delta = now - lastUpdate
    lastUpdate = now

    if BSAlertTimer > 0 then
        BSAlertTimer = BSAlertTimer - delta
        if BSAlertTimer < 0 then
            BSAlertTimer = 0
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
        local unit = "party"..i
        local exists, guid = UnitExists(unit)
        if guid then
            partyGUIDs[tostring(guid)] = true
            local name = UnitName(unit) or "unknown"
        end
    end
end


function BSAlert_OnLoad()
    this:RegisterEvent("PLAYER_REGEN_ENABLED")
	this:RegisterEvent("PLAYER_ENTERING_WORLD")
    this:RegisterEvent("PLAYER_REGEN_DISABLED")
    this:RegisterEvent("UNIT_CASTEVENT")
    this:RegisterEvent("PARTY_MEMBERS_CHANGED")

    this:SetScript("OnUpdate", UpdateBS)
end


function BSAlert_OnEvent(event)
	if event == "PLAYER_ENTERING_WORLD" then
		UpdatePartyGUIDs()
		this:UnregisterEvent("PLAYER_ENTERING_WORLD")
	end
    if event == "PLAYER_REGEN_DISABLED" then
        BSAlert_combat = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        BSAlert_combat = nil
    end

    if event == "PARTY_MEMBERS_CHANGED" then
        UpdatePartyGUIDs()
    end

    if event == "UNIT_CASTEVENT" and arg4 == 25289 then
        if partyGUIDs[arg1] then
			local dist = UnitXP("distanceBetween", "player", arg1)
			if dist and dist > 20 then
				return
			end 
            BSAlertTimer = 115  
        end
    end

    if BSAlert_combat and (not HasBuff()) then
        BSAlert:Show()
    else
        BSAlert:Hide()
    end
end
