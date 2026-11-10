-- SIMPLEHUNTER - WOW FOREVER (INTERFACE 16001)

------------------------------------------------------------------------------
-- CONFIGURATION
local ADDON_NAME = "SimpleHunter"
local LOW_AMMO_THRESHOLD = 400
local UPDATE_INTERVAL = 0.5
local TARGET_UPDATE_INTERVAL = 0.2

------------------------------------------------------------------------------
-- STATE COLORS AND LABELS
local ZONE_COLORS = {
    ranged = { 0, 1, 0 },
    deadzone = { 1, 0, 0 },
    tooclose = { 0.4, 0.8, 1 },
    out = { 0.6, 0.6, 0.6 },
}
local ZONE_LABELS = {
    ranged = "ON RANGED",
    deadzone = "DEADZONE",
    tooclose = "TOO CLOSE",
    out = "OUT OF RANGE",
}

------------------------------------------------------------------------------
-- REFERENCE SPELLS
local SPELL_ATTACK = 6603
local SPELL_AUTOSHOT = 75
local MELEE_SPELL_IDS = { SPELL_ATTACK }
local RANGED_SPELL_IDS = { SPELL_AUTOSHOT }

------------------------------------------------------------------------------
-- FIXED CLIENT BANDS
local FIXED_MELEE_INDEX = 3
local FIXED_NEAR_INDEX = 4

------------------------------------------------------------------------------
-- CHAT MESSAGE
local function DebugMessage(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[" .. ADDON_NAME .. "]|r " .. message)
end

------------------------------------------------------------------------------
-- MAIN FRAME
local ammoFrame = CreateFrame("Button", "AmmoCounterFrame", UIParent)
ammoFrame:SetSize(38, 38)
ammoFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
ammoFrame:SetMovable(true)
ammoFrame:EnableMouse(true)
ammoFrame:RegisterForDrag("LeftButton")
ammoFrame:SetClampedToScreen(true)

------------------------------------------------------------------------------
-- ICON
local ammoIcon = ammoFrame:CreateTexture(nil, "ARTWORK")
ammoIcon:SetAllPoints(ammoFrame)
ammoIcon:SetTexture("Interface/Icons/INV_Misc_QuestionMark")

------------------------------------------------------------------------------
-- COUNTER
local ammoCountText = ammoFrame:CreateFontString(nil, "OVERLAY")
ammoCountText:SetFont("Fonts\\FRIZQT__.TTF", 20, "OUTLINE")
ammoCountText:SetPoint("LEFT", ammoFrame, "RIGHT", 6, 0)
ammoCountText:SetText("...")

------------------------------------------------------------------------------
-- TARGET TEXT
local targetText = ammoFrame:CreateFontString(nil, "OVERLAY")
targetText:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
targetText:SetPoint("BOTTOM", ammoFrame, "TOP", 0, 6)
targetText:SetJustifyH("CENTER")
targetText:SetText("")

-- CENTER TARGET TEXT OVER ICON AND COUNTER
local function CenterTargetText()
    local countWidth = ammoCountText:GetStringWidth() or 0
    targetText:ClearAllPoints()
    targetText:SetPoint("BOTTOM", ammoFrame, "TOP", (6 + countWidth) / 2, 6)
end

CenterTargetText()

------------------------------------------------------------------------------
-- ALERT BORDER
local border = {}

-- CREATE BORDER TEXTURE
local function CreateBorderTexture(point, relativePoint, x, y, width, height)
    local texture = ammoFrame:CreateTexture(nil, "OVERLAY")
    texture:SetPoint(point, ammoFrame, relativePoint, x, y)
    texture:SetSize(width, height)
    texture:SetColorTexture(1, 0, 0, 1)
    return texture
end

border.top = CreateBorderTexture("TOPLEFT", "TOPLEFT", 0, 0, 28, 2)
border.bottom = CreateBorderTexture("BOTTOMLEFT", "BOTTOMLEFT", 0, 0, 28, 2)
border.left = CreateBorderTexture("TOPLEFT", "TOPLEFT", 0, 0, 2, 28)
border.right = CreateBorderTexture("TOPRIGHT", "TOPRIGHT", 0, 0, 2, 28)

-- SET BORDER COLOR
local function SetBorderColor(r, g, b)
    for _, texture in pairs(border) do
        texture:SetColorTexture(r, g, b, 1)
    end
end

-- SHOW OR HIDE BORDER
local function ShowBorder(show)
    for _, texture in pairs(border) do
        if show then
            texture:Show()
        else
            texture:Hide()
        end
    end
end

ShowBorder(false)

------------------------------------------------------------------------------
-- SAVED POSITION

-- SAVE FRAME POSITION
local function SavePosition()
    if not AmmoCounterDB then
        AmmoCounterDB = {}
    end

    local point, _, relativePoint, xOfs, yOfs = ammoFrame:GetPoint(1)
    AmmoCounterDB.point = point
    AmmoCounterDB.relativePoint = relativePoint
    AmmoCounterDB.xOfs = xOfs
    AmmoCounterDB.yOfs = yOfs

    DebugMessage("Position saved.")
end

-- RESTORE FRAME POSITION
local function RestorePosition()
    if AmmoCounterDB and AmmoCounterDB.point then
        ammoFrame:ClearAllPoints()
        ammoFrame:SetPoint(
            AmmoCounterDB.point,
            UIParent,
            AmmoCounterDB.relativePoint or AmmoCounterDB.point,
            AmmoCounterDB.xOfs or 0,
            AmmoCounterDB.yOfs or 0
        )
        DebugMessage("Previous position restored.")
    end
end

------------------------------------------------------------------------------
-- MOVE WITH SHIFT + CLICK
ammoFrame:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" and IsShiftKeyDown() then
        self:StartMoving()
    end
end)

ammoFrame:SetScript("OnMouseUp", function(self)
    self:StopMovingOrSizing()
    SavePosition()
end)

ammoFrame:SetScript("OnHide", function(self)
    self:StopMovingOrSizing()
end)

------------------------------------------------------------------------------
-- AMMO
local ammoSlotID

-- UPDATE AMMO COUNTER
local function UpdateAmmo()
    if not ammoSlotID then
        if type(GetInventorySlotInfo) ~= "function" then
            ammoCountText:SetText("API unavailable")
            SetBorderColor(1, 0.5, 0)
            ShowBorder(true)
            DebugMessage("ERROR: GetInventorySlotInfo is not available.")
            return
        end

        ammoSlotID = GetInventorySlotInfo("AmmoSlot")
    end

    if not ammoSlotID then
        ammoCountText:SetText("No slot")
        ammoIcon:SetTexture("Interface/Icons/INV_Misc_QuestionMark")
        SetBorderColor(1, 0.5, 0)
        ShowBorder(true)
        DebugMessage("ERROR: AmmoSlot slot not found.")
        return
    end

    local ammoCount = GetInventoryItemCount("player", ammoSlotID)
    local icon = GetInventoryItemTexture("player", ammoSlotID)

    if not icon then
        ammoIcon:SetTexture("Interface/Icons/INV_Misc_QuestionMark")
        ammoCountText:SetText("No ammo")
        ammoCountText:SetTextColor(1, 0.5, 0)
        SetBorderColor(1, 0.5, 0)
        ShowBorder(true)
        return
    end

    ammoCount = tonumber(ammoCount) or 0

    ammoIcon:SetTexture(icon)
    ammoCountText:SetText(tostring(ammoCount))

    if ammoCount < LOW_AMMO_THRESHOLD then
        ammoCountText:SetTextColor(1, 0, 0)
        SetBorderColor(1, 0, 0)
        ShowBorder(true)
    else
        ammoCountText:SetTextColor(1, 1, 1)
        ShowBorder(false)
    end
end

------------------------------------------------------------------------------
-- TARGET RANGE

-- GET SPELL NAME BY ID
local function GetSpellNameByID(id)
    local name
    if C_Spell and C_Spell.GetSpellName then
        name = C_Spell.GetSpellName(id)
    elseif GetSpellInfo then
        name = GetSpellInfo(id)
        if type(name) == "table" then
            name = name.name
        end
    end
    return name
end

-- CHECK SPELL RANGE BY NAME
local function SpellRange(name, unit)
    if not name or type(IsSpellInRange) ~= "function" then
        return nil
    end
    local result = IsSpellInRange(name, unit)
    if result == true or result == 1 then
        return 1
    elseif result == false or result == 0 then
        return 0
    end
    return nil
end

local actionSlots
local MELEE_NAMES, RANGED_NAMES

-- BUILD SPELL NAME SETS
local function BuildNameSets()
    MELEE_NAMES, RANGED_NAMES = {}, {}
    for _, id in ipairs(MELEE_SPELL_IDS) do
        local name = GetSpellNameByID(id)
        if name then
            MELEE_NAMES[name] = true
        end
    end
    for _, id in ipairs(RANGED_SPELL_IDS) do
        local name = GetSpellNameByID(id)
        if name then
            RANGED_NAMES[name] = true
        end
    end
end

-- SCAN ACTION BARS AND SPELLBOOK
local function ScanActionSlots()
    actionSlots = { melee = {}, ranged = {}, bookMelee = {}, bookRanged = {} }

    if not MELEE_NAMES then
        BuildNameSets()
    end

    if type(GetActionInfo) == "function" then
        for slot = 1, 120 do
            if not HasAction or HasAction(slot) then
                local actionType, id = GetActionInfo(slot)

                if type(IsAttackAction) == "function" and IsAttackAction(slot) then
                    table.insert(actionSlots.melee, slot)
                elseif actionType == "spell" and id then
                    local name = GetSpellNameByID(id)
                    if name and MELEE_NAMES[name] then
                        table.insert(actionSlots.melee, slot)
                    elseif name and RANGED_NAMES[name] then
                        table.insert(actionSlots.ranged, slot)
                    end
                end
            end
        end
    end

    local getBookName = GetSpellBookItemName or GetSpellName
    if getBookName then
        for index = 1, 300 do
            local name = getBookName(index, "spell")
            if not name then
                break
            end
            if MELEE_NAMES[name] then
                table.insert(actionSlots.bookMelee, index)
            elseif RANGED_NAMES[name] then
                table.insert(actionSlots.bookRanged, index)
            end
        end
    end
end

-- CHECK SPELLBOOK SPELL RANGE BY INDEX
local function BookRange(index, unit)
    if type(IsSpellInRange) ~= "function" then
        return nil
    end
    local ok, result = pcall(IsSpellInRange, index, "spell", unit)
    if not ok then
        return nil
    end
    if result == true or result == 1 then
        return 1
    elseif result == false or result == 0 then
        return 0
    end
    return nil
end

-- CHECK ACTION BAR BUTTON RANGE
local function ActionRange(slot, unit)
    if not slot or type(IsActionInRange) ~= "function" then
        return nil
    end
    local result = IsActionInRange(slot, unit)
    if result == true or result == 1 then
        return 1
    elseif result == false or result == 0 then
        return 0
    end
    return nil
end

-- CHECK AUTO ATTACK RANGE (MELEE OR RANGED)
local function AutoAttackRange(kind, unit)
    if not actionSlots then
        ScanActionSlots()
    end

    local slots, book, names
    if kind == "melee" then
        slots, book = actionSlots.melee, actionSlots.bookMelee
        names = MELEE_SPELL_IDS
    else
        slots, book = actionSlots.ranged, actionSlots.bookRanged
        names = RANGED_SPELL_IDS
    end

    local anyOutOfRange = false
    local function Check(result)
        if result == 1 then
            return true
        elseif result == 0 then
            anyOutOfRange = true
        end
        return false
    end

    for _, slot in ipairs(slots) do
        if Check(ActionRange(slot, unit)) then
            return 1
        end
    end
    for _, index in ipairs(book) do
        if Check(BookRange(index, unit)) then
            return 1
        end
    end
    for _, id in ipairs(names) do
        if Check(SpellRange(GetSpellNameByID(id), unit)) then
            return 1
        end
    end

    if anyOutOfRange then
        return 0
    end
    return nil
end

-- GET TARGET RANGE STATE
local function GetRangeZone(unit)
    local rangedRange = AutoAttackRange("ranged", unit)
    local meleeRange = AutoAttackRange("melee", unit)

    if rangedRange == 1 then
        return "ranged"
    end

    if rangedRange == nil and meleeRange == nil then
        return nil
    end

    local checkDistance = type(CheckInteractDistance) == "function"

    if meleeRange == 1 or (checkDistance and CheckInteractDistance(unit, FIXED_MELEE_INDEX)) then
        return "tooclose"
    end

    if checkDistance and CheckInteractDistance(unit, FIXED_NEAR_INDEX) then
        return "deadzone"
    end

    return "out"
end

-- UPDATE TARGET TEXT
local function UpdateTarget()
    if not UnitExists("target") then
        targetText:SetText("")
        return
    end

    CenterTargetText()

    local name = UnitName("target") or "?"
    local zone = GetRangeZone("target")

    if zone then
        local color = ZONE_COLORS[zone]
        targetText:SetTextColor(color[1], color[2], color[3])
        targetText:SetText(name .. "\n" .. ZONE_LABELS[zone])
    else
        targetText:SetTextColor(1, 1, 1)
        targetText:SetText(name)
    end
end

------------------------------------------------------------------------------
-- AMMO TOOLTIP
ammoFrame:SetScript("OnEnter", function(self)

    if not ammoSlotID then
        ammoSlotID = GetInventorySlotInfo("AmmoSlot")
    end

    if ammoSlotID and GetInventoryItemTexture("player", ammoSlotID) then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetInventoryItem("player", ammoSlotID)
        GameTooltip:Show()
    end
end)

ammoFrame:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

------------------------------------------------------------------------------
-- COMMANDS
SLASH_SIMPLEHUNTER1 = "/SH"
SlashCmdList["SIMPLEHUNTER"] = function(message)
    message = string.lower(message or "")
    message = message:match("^%s*(.-)%s*$")

    if message == "on" then
        ammoFrame:Show()
        UpdateAmmo()
        UpdateTarget()
        DebugMessage("Enabled.")
    elseif message == "off" then
        ammoFrame:Hide()
        DebugMessage("Disabled.")
    elseif message == "reset" then
        AmmoCounterDB = {}
        ammoFrame:ClearAllPoints()
        ammoFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
        SavePosition()
        DebugMessage("Position reset.")
    else
        DebugMessage("Commands: /SH on | /SH off | /SH reset")
    end
end

------------------------------------------------------------------------------
-- EVENTS
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
eventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("BAG_UPDATE")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")

eventFrame:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_TARGET_CHANGED" then
        UpdateTarget()
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        actionSlots = nil
    end

    if event == "ACTIONBAR_SLOT_CHANGED" then
        actionSlots = nil
        return
    end

    if event == "UNIT_INVENTORY_CHANGED" and unit and unit ~= "player" then
        return
    end

    UpdateAmmo()
end)

------------------------------------------------------------------------------
-- PERIODIC UPDATE
local elapsed = 0
local targetElapsed = 0
eventFrame:SetScript("OnUpdate", function(self, delta)
    elapsed = elapsed + delta
    if elapsed >= UPDATE_INTERVAL then
        elapsed = 0
        UpdateAmmo()
    end

    targetElapsed = targetElapsed + delta
    if targetElapsed >= TARGET_UPDATE_INTERVAL then
        targetElapsed = 0
        UpdateTarget()
    end
end)

------------------------------------------------------------------------------
-- STARTUP
eventFrame:HookScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        RestorePosition()
        UpdateAmmo()
        UpdateTarget()
        DebugMessage("SimpleHunter loaded...")
        DebugMessage("Use SHIFT + left click to move the counter.")
        DebugMessage("Commands: /SH on | /SH off | /SH reset")
    end
end)