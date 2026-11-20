local constants = {
    "CRAFTING_TYPE_BLACKSMITHING", "CRAFTING_TYPE_CLOTHIER", "CRAFTING_TYPE_WOODWORKING",
    "CRAFTING_TYPE_JEWELRYCRAFTING", "CRAFTING_TYPE_PROVISIONING", "CRAFTING_TYPE_ENCHANTING",
    "CRAFTING_TYPE_ALCHEMY", "NON_COMBAT_BONUS_BLACKSMITHING_LEVEL",
    "NON_COMBAT_BONUS_CLOTHIER_LEVEL", "NON_COMBAT_BONUS_WOODWORKING_LEVEL",
    "NON_COMBAT_BONUS_JEWELRYCRAFTING_LEVEL", "NON_COMBAT_BONUS_PROVISIONING_LEVEL",
    "NON_COMBAT_BONUS_PROVISIONING_RARITY_LEVEL", "NON_COMBAT_BONUS_PROVISIONING_CREATE_EXTRA_DRINK",
    "NON_COMBAT_BONUS_PROVISIONING_CREATE_EXTRA_FOOD", "NON_COMBAT_BONUS_ENCHANTING_LEVEL",
    "NON_COMBAT_BONUS_ENCHANTING_RARITY_LEVEL", "NON_COMBAT_BONUS_ALCHEMY_LEVEL",
    "NON_COMBAT_BONUS_ALCHEMY_THIRD_SLOT", "NON_COMBAT_BONUS_ALCHEMY_CREATE_EXTRA",
    "ITEM_STYLE_CHAPTER_CHESTS", "ITEM_STYLE_CHAPTER_BOOTS", "ITEM_STYLE_CHAPTER_GLOVES",
    "ITEM_STYLE_CHAPTER_HELMETS", "ITEM_STYLE_CHAPTER_LEGS", "ITEM_STYLE_CHAPTER_SHOULDERS",
    "ITEM_STYLE_CHAPTER_BELTS", "ITEM_STYLE_CHAPTER_AXES", "ITEM_STYLE_CHAPTER_MACES",
    "ITEM_STYLE_CHAPTER_SWORDS", "ITEM_STYLE_CHAPTER_DAGGERS", "ITEM_STYLE_CHAPTER_BOWS",
    "ITEM_STYLE_CHAPTER_SHIELDS", "ITEM_STYLE_CHAPTER_STAVES",
    "ITEMTYPE_MASTER_WRIT", "ITEMTYPE_DRINK", "ITEMTYPE_FOOD", "SI_TOOLTIP_ITEM_NAME",
    "LINK_STYLE_DEFAULT", "CT_LABEL", "CT_CONTROL", "CT_BACKDROP", "CT_TEXTURE",
    "TOPLEFT", "TOPRIGHT", "TOP", "CENTER", "TEXT_ALIGN_LEFT", "TEXT_ALIGN_RIGHT", "TEXT_ALIGN_CENTER",
    "EVENT_ADD_ON_LOADED", "ITEM_TRAIT_TYPE_ARMOR_DIVINES",
    "BOTTOMRIGHT", "DL_OVERLAY", "INVENTORY_BACKPACK",
    "EVENT_PLAYER_ACTIVATED", "EVENT_INVENTORY_FULL_UPDATE", "EVENT_INVENTORY_SINGLE_SLOT_UPDATE",
    "EVENT_SKILL_POINTS_CHANGED", "EVENT_SKILL_RANK_UPDATE", "EVENT_SKILL_RESPEC_RESULT",
    "EVENT_SMITHING_TRAIT_RESEARCH_COMPLETED", "EVENT_RECIPE_LEARNED", "EVENT_LORE_BOOK_LEARNED",
}
for index, name in ipairs(constants) do _G[name] = index end

local state, event
local function Reset()
    state = { stocks = {}, bonuses = {}, known = true, research = 9, setTraits = 3,
        motif = 1, recipeKnown = true, upgrade = { 2, 3, 4, 8 }, chapters = {} }
end
Reset()
function GetItemLinkItemId(link) return tonumber(link:match("item:(%d+)")) or 0 end
function GetItemLinkItemType(link)
    if GetItemLinkItemId(link) == 900 then return ITEMTYPE_MASTER_WRIT end
    return ITEMTYPE_FOOD
end
function ZO_LinkHandler_ParseLink(link)
    local fields = { "", "1", "item" }
    for field in (link:match("item:([^|]+)") or ""):gmatch("[^:]+") do fields[#fields + 1] = field end
    return unpack(fields)
end
function GetItemLinkName(link) return "Item " .. GetItemLinkItemId(link) end
function GetItemLinkIcon() return "icon.dds" end
function zo_strformat(format, ...)
    local values = { ... }
    if type(format) ~= "string" then return values[1] end
    return (format:gsub("<<(%d+)>>", function(index)
        return (values[tonumber(index)]:gsub("%^%a+", ""))
    end))
end
function zo_strlower(text) return text:lower() end
function zo_strtrim(text) return text:match("^%s*(.-)%s*$") end
function GetString(kind, index)
    if kind == "SI_ITEMSTYLECHAPTER" and state.chapterName then return state.chapterName end
    return kind .. " " .. tostring(index)
end
function GetNonCombatBonus(bonus)
    if state.bonuses[bonus] ~= nil then return state.bonuses[bonus] end
    if bonus == NON_COMBAT_BONUS_ALCHEMY_CREATE_EXTRA
        or bonus == NON_COMBAT_BONUS_PROVISIONING_CREATE_EXTRA_FOOD then return 3 end
    return 10
end
function GetItemLinkStacks(link)
    local stock = state.stocks[GetItemLinkItemId(link)]
    if type(stock) == "table" then return unpack(stock) end
    return stock or 1000, 0, 0, 99999
end
function GetSmithingResearchLineInfo(craft, line)
    state.lastResearch = { craft, line }
    return "Piece " .. line, "", 9
end
function GetSmithingResearchLineTraitInfo(_, _, index)
    return index, "", state.known and index <= state.research
end
function GetItemStyleName(style) return state.styleName or "Style " .. style end
function GetItemStyleMaterialLink(style) return TamrielToolsWritChecker.ItemLink(70000 + style) end
function GetSmithingTraitItemLink(trait) return TamrielToolsWritChecker.ItemLink(80000 + trait) end
function GetSmithingImprovementItemLink(_, quality) return TamrielToolsWritChecker.ItemLink(81000 + quality) end
function GetSmithingGuaranteedImprovementItemAmount(_, quality) return state.upgrade[quality] end
LibSets = {
    GetTraitsNeeded = function() return state.setTraits end,
    GetSetName = function() return "Test Set" end,
}
LibCharacterKnowledge = {
    EVENT_INITIALIZED = 1, EVENT_UPDATE_REFRESH = 2,
    KNOWLEDGE_KNOWN = 1, KNOWLEDGE_UNKNOWN = 2,
    GetMotifKnowledgeForCharacter = function(style, chapter)
        state.chapters[#state.chapters + 1] = { style, chapter }
        return state.motif
    end,
    GetSourceItemIdFromResultItem = function() return state.recipeMissing and 0 or 100 end,
}
LibLazyCrafting = {
    GetItemTemplateIdPatternIndex = function(template)
        return ({ [52] = 10, [31] = 6, [18] = 2, [24] = 1, [65] = 2, [75] = 2 })[template]
    end,
    functionTable = {
        GetMatRequirements = function(pattern, tier, craft)
            assert(tier == 40)
            if craft == CRAFTING_TYPE_JEWELRYCRAFTING then return pattern == 1 and 10 or 15 end
            return pattern == 6 and 14 or 13
        end,
    },
    getGlyphInfo = function()
        return { { 1, 2, 43573, 26580, "", "", 0, 0, 45831 } },
            { { 1, 64509, cp = 150 }, { -1, 64508, cp = 150 }, { 1, 68341, cp = 160 } },
            { 45850, 45851, 45852, 45853, 45854 }
    end,
}
function IsItemLinkRecipeKnown() return state.recipeKnown end
function GetItemLinkRecipeNumTradeskillRequirements() return 1 end
function GetItemLinkRecipeTradeskillRequirement() return CRAFTING_TYPE_PROVISIONING, 6 end
function GetItemLinkRecipeQualityRequirement() return 4 end
function GetItemLinkRecipeResultItemLink() return TamrielToolsWritChecker.ItemLink(68276) end
function GetItemLinkRecipeNumIngredients() return 2 end
function GetItemLinkRecipeIngredientInfo(_, index) return "", 0, index end
function GetItemLinkRecipeIngredientItemLink(_, index) return TamrielToolsWritChecker.ItemLink(82000 + index) end

LibAlchemy = {
    potionEffectIdToString = { [1] = "A", [2] = "B", [3] = "C" },
    reagents = {
        [101] = { "", 1, { "A", "B" } }, [102] = { "", 1, { "A", "C" } },
        [103] = { "", 1, { "B", "C" } }, [104] = { "", 1, { "A", "B" } },
    },
    opposites = {},
    ThreeEffects = function() return { { 101, 102, 103 }, { 104, 102, 103 } } end,
    ThreeEffectsAlt = function() return {} end,
    sortOutWrongCombinations3 = function(_, combinations) return combinations end,
}
local realAlchemy = arg and arg[1]
if realAlchemy then
    dofile(realAlchemy .. "\\LibAlchemy.lua")
    dofile(realAlchemy .. "\\LibAlchemy_Database.lua")
end

local Control = {}
Control.__index = Control
function Control:SetWidth(width) self.width = width end
function Control:GetWidth() return self.width or 400 end
function Control:SetHeight(height) self.height = height end
function Control:SetFont(font) self.font = font end
function Control:SetText(text) self.text = text end
function Control:SetHidden(hidden) self.hidden = hidden end
function Control:SetHorizontalAlignment(align) self.align = align end
function Control:SetAnchor(...) self.anchor = { ... } end
function Control:IsHidden() return self.hidden == true end
function Control:GetNamedChild(name)
    self.children = self.children or {}
    self.children[name] = self.children[name] or setmetatable({}, Control)
    return self.children[name]
end
function Control:GetTextHeight()
    local text = (self.text or ""):gsub("|c%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|t.-|t", "X")
    local lines = 0
    for line in (text .. "\n"):gmatch("(.-)\n") do
        lines = lines + math.max(1, math.ceil(#line * 7 / self:GetWidth()))
    end
    return lines * 18
end
for _, method in ipairs({ "ClearAnchors", "SetAnchorFill", "SetCenterColor",
    "SetEdgeColor", "SetEdgeTexture", "SetColor", "SetTexture",
    "SetMouseEnabled", "SetDrawLayer", "AddVerticalPadding" }) do Control[method] = function() end end
function Control:AddControl(card)
    self.cards = (self.cards or 0) + 1
    self.lastCard = card
end
function Control:Clear()
    self.writCheckerLink = nil
    if self.OnCleared then self.OnCleared(self) end
end
function Control:SetLink(link)
    self:Clear()
    self.originalCalls = (self.originalCalls or 0) + 1
    self.originalLink = link
end
function Control:SetBagItem() self:SetLink(state.bagLink) end
WINDOW_MANAGER = {
    CreateControl = function() return setmetatable({}, Control) end,
    CreateControlFromVirtual = function() return setmetatable({}, Control) end,
}
ItemTooltip = setmetatable({}, Control)
PopupTooltip = setmetatable({}, Control)
function ZO_PreHookHandler(control, handler, callback) control[handler] = callback end
function ZO_PostHook(control, method, callback)
    local original = control[method]
    control[method] = function(self, ...)
        original(self, ...)
        callback(self, ...)
    end
end
function zo_iconFormat(icon) return "|t18:18:" .. icon .. "|t" end
function GetItemLink(_, slotIndex)
    return state.inventoryLinks and state.inventoryLinks[slotIndex] or state.bagLink
end
local events, knowledgeCallbacks, timers = {}, {}, {}
EVENT_MANAGER = {
    RegisterForEvent = function(_, _, eventCode, callback)
        if eventCode == EVENT_ADD_ON_LOADED then event = callback end
        events[eventCode] = callback
    end,
    UnregisterForEvent = function() end,
}
function LibCharacterKnowledge.RegisterForCallback(_, eventCode, callback)
    knowledgeCallbacks[eventCode] = callback
    return true
end
function zo_callLater(callback) timers[#timers + 1] = callback end
local function FlushTimers()
    local pending = timers
    timers = {}
    for _, callback in ipairs(pending) do callback() end
end
local inventoryDataType = {
    setupCallback = function(row) row.originalSetupCalls = (row.originalSetupCalls or 0) + 1 end,
}
local inventoryList = setmetatable({ hidden = true, dataTypes = { [1] = inventoryDataType } }, Control)
PLAYER_INVENTORY = {
    inventories = { [INVENTORY_BACKPACK] = { listView = inventoryList, listDataType = 1 } },
}
function ZO_ScrollList_RefreshVisible(list)
    list.refreshes = (list.refreshes or 0) + 1
    for _, entry in ipairs(list.rows or {}) do inventoryDataType.setupCallback(entry.row, entry.slot) end
end
SLASH_COMMANDS = {}
function d() end
dofile("TamrielToolsWritChecker.lua")
local W = TamrielToolsWritChecker

local passed = 0
local function Test(name, callback)
    Reset()
    callback()
    passed = passed + 1
    print("PASS " .. name)
end
local function Equal(actual, expected)
    assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function Writ(a, b, c, e, f, g)
    local values = { 900, 6, 1, 0, 0, 0, a, b or 0, c or 0, e or 0, f or 0, g or 0,
        0, 0, 0, 0, 0, 0, 0, 0, 1220000 }
    return "|H1:item:" .. table.concat(values, ":") .. "|h|h"
end
local function Material(report, id)
    for _, material in ipairs(report.materials) do if material.id == id then return material end end
    error("material not found: " .. id)
end
local gauntlets = Writ(52, 188, 5, 43, 9, 14)

Test("legendary gauntlets: exact trait, motif chapter and all upgrade steps", function()
    local report = W.Evaluate(gauntlets)
    Equal(report.status, "ready")
    Equal(state.lastResearch[2], 10)
    Equal(state.chapters[1][2], ITEM_STYLE_CHAPTER_GLOVES)
    Equal(Material(report, 81004).need, 8)
    Equal(Material(report, 64489).need, 13)
end)
Test("motif names use ESO formatting to hide grammatical suffixes", function()
    state.styleName, state.chapterName = "Dwemer", "Gloves^p"
    local report = W.Evaluate(gauntlets)
    local found = false
    for _, check in ipairs(report.checks) do
        if check.label == "Motif chapter" then
            Equal(check.detail, "Dwemer - Gloves")
            Equal(check.passed, true)
            found = true
        end
    end
    assert(found)
end)
Test("missing trait blocks even when set trait count is satisfied", function()
    state.research = 8
    Equal(W.Evaluate(gauntlets).status, "blocked")
end)
Test("insufficient set traits blocks a known requested trait", function()
    state.research, state.setTraits = 4, 8
    Equal(W.Evaluate(Writ(52, 188, 4, 43, 2, 14)).status, "blocked")
end)
Test("unknown set data cannot produce ready", function()
    state.setTraits = nil
    Equal(W.Evaluate(gauntlets).status, "unknown")
end)
Test("motif must be learned even with a mimic stone", function()
    state.motif = 2
    state.stocks[70014] = 0
    local report = W.Evaluate(gauntlets)
    Equal(report.status, "blocked")
    Equal(Material(report, 71668).need, 1)
end)
Test("missing style material needs supplies when no mimic stone is available", function()
    state.stocks[70014], state.stocks[71668] = 0, 0
    local report = W.Evaluate(gauntlets)
    Equal(report.status, "materials")
    Equal(Material(report, 70014).missing, 1)
end)
Test("unavailable motif knowledge is not treated as missing or learned", function()
    state.motif = 0
    Equal(W.Evaluate(gauntlets).status, "unknown")
end)
Test("necklace and ring use their distinct reversed research lines; no motif", function()
    local necklace = W.Evaluate(Writ(18, 255, 4, 37, 4, 0))
    Equal(state.lastResearch[2], 1)
    Equal(#state.chapters, 0)
    Equal(Material(necklace, 135146).need, 15)
    W.Evaluate(Writ(24, 255, 4, 37, 4, 0))
    Equal(state.lastResearch[2], 2)
end)
Test("breeches and jerkin use the correct cloth research lines and chapters", function()
    W.Evaluate(Writ(31, 194, 4, 43, 1, 14))
    Equal(state.lastResearch[2], 5)
    Equal(state.chapters[1][2], ITEM_STYLE_CHAPTER_LEGS)
    W.Evaluate(Writ(75, 194, 4, 43, 1, 14))
    Equal(state.lastResearch[2], 1)
    Equal(state.chapters[2][2], ITEM_STYLE_CHAPTER_CHESTS)
end)
Test("shield uses armor research and shield motif, not staff research", function()
    W.Evaluate(Writ(65, 192, 5, 43, 3, 14))
    Equal(state.lastResearch[2], 6)
    Equal(state.chapters[1][2], ITEM_STYLE_CHAPTER_SHIELDS)
end)
Test("bank and craft bag count; housing storage never counts", function()
    state.stocks[64489] = { 2, 3, 8, 99999 }
    Equal(W.Evaluate(gauntlets).status, "ready")
    state.stocks[64489] = { 2, 3, 7, 99999 }
    local report = W.Evaluate(gauntlets)
    Equal(report.status, "materials")
    Equal(Material(report, 64489).missing, 1)
    Equal(report.materials[1].id, 64489)
end)
Test("material passive is required, combat level is not consulted", function()
    state.bonuses[NON_COMBAT_BONUS_BLACKSMITHING_LEVEL] = 9
    Equal(W.Evaluate(gauntlets).status, "blocked")
end)
Test("upgrade amounts follow current guaranteed-success API", function()
    state.upgrade = { 5, 7, 10, 20 }
    Equal(Material(W.Evaluate(gauntlets), 81004).need, 20)
end)
Test("unavailable upgrade material data is unverified, never ready", function()
    state.upgrade[4] = nil
    Equal(W.Evaluate(gauntlets).status, "unknown")
end)
Test("provisioning scales batches with current yield and checks the recipe", function()
    local link = Writ(68276)
    Equal(Material(W.Evaluate(link), 82002).need, 4)
    state.bonuses[NON_COMBAT_BONUS_PROVISIONING_CREATE_EXTRA_FOOD] = 0
    Equal(Material(W.Evaluate(link), 82002).need, 16)
    state.recipeKnown = false
    Equal(W.Evaluate(link).status, "blocked")
    state.recipeMissing = true
    Equal(W.Evaluate(link).status, "unknown")
end)
Test("provisioning checks both improvement and quality passives", function()
    state.bonuses[NON_COMBAT_BONUS_PROVISIONING_RARITY_LEVEL] = 3
    Equal(W.Evaluate(Writ(68276)).status, "blocked")
end)
Test("enchanting resolves exact runes and aspect rank", function()
    local link = Writ(26580, 207, 5)
    local report = W.Evaluate(link)
    Equal(report.status, "ready")
    Equal(Material(report, 64509).need, 1)
    Equal(Material(report, 45854).need, 1)
    state.bonuses[NON_COMBAT_BONUS_ENCHANTING_RARITY_LEVEL] = 3
    Equal(W.Evaluate(link).status, "blocked")
    Equal(W.Evaluate(Writ(999999, 207, 5)).status, "unknown")
end)
Test("CP160 glyph requires potency rank ten rather than nine", function()
    state.bonuses[NON_COMBAT_BONUS_ENCHANTING_LEVEL] = 9
    Equal(W.Evaluate(Writ(26580, 207, 5)).status, "ready")
    Equal(W.Evaluate(Writ(26580, 225, 5)).status, "blocked")
end)
Test("malformed, unsupported and non-writ links never produce ready", function()
    Equal(W.Evaluate(""), nil)
    Equal(W.Evaluate(W.ItemLink(2)), nil)
    Equal(W.Evaluate(W.ItemLink(900)).status, "unknown")
    Equal(W.Evaluate(Writ(88888, 123, 4)).status, "unknown")
end)
Test("duplicate material costs accumulate before stock comparison", function()
    local report = { checks = {}, materials = {}, notes = {} }
    W.AddMaterial(report, W.ItemLink(10), 3)
    W.AddMaterial(report, W.ItemLink(10), 4)
    Equal(W.Finalize(report).materials[1].need, 7)
end)

if not realAlchemy then
    Test("alchemy chooses stocked alternatives and recalculates after stock changes", function()
        state.stocks[101] = 0
        local report = W.Evaluate(Writ(199, 1, 2, 3))
        Equal(report.status, "ready")
        Equal(Material(report, 104).need, 4)
        state.stocks[104], state.stocks[101] = 0, 20
        report = W.Evaluate(Writ(199, 1, 2, 3))
        Equal(Material(report, 101).need, 4)
        Equal(Material(W.Evaluate(Writ(239, 1, 2, 3)), 75365).need, 1)
        state.bonuses[NON_COMBAT_BONUS_ALCHEMY_CREATE_EXTRA] = 0
        Equal(Material(W.Evaluate(Writ(199, 1, 2, 3)), 64501).need, 16)
    end)
else
    Test("real LibAlchemy: three-effect formulas satisfy every requested effect", function()
        local ids = {}
        for id, effect in pairs(LibAlchemy.potionEffectIdToString) do
            if effect == "RestoreHealth" then ids[1] = id end
            if effect == "RestoreMagicka" then ids[2] = id end
            if effect == "RestoreStamina" then ids[3] = id end
        end
        assert(#ids == 3)
        local report = W.Evaluate(Writ(199, ids[1], ids[2], ids[3]))
        Equal(report.status, "ready")
        Equal(#report.materials, 4)
        for _, effect in ipairs({ "RestoreHealth", "RestoreMagicka", "RestoreStamina" }) do
            local count = 0
            for _, material in ipairs(report.materials) do
                local reagent = LibAlchemy.reagents[material.id]
                if reagent then
                    for _, found in ipairs(reagent[3]) do
                        if found == effect then count = count + 1 end
                        if found == LibAlchemy.opposites[effect] then count = count - 1 end
                    end
                end
            end
            assert(count >= 2, effect .. " is absent or cancelled")
        end
    end)
end
Test("alchemy unknown middle effect is explicitly unverified", function()
    Equal(W.Evaluate(Writ(199, 1, 999999, 3)).status, "unknown")
end)
Test("tooltip hooks preserve original content, avoid nested duplicates and reset cleanly", function()
    event(nil, W.name)
    FlushTimers()
    state.bagLink = gauntlets
    ItemTooltip:SetBagItem(1, 1)
    Equal(ItemTooltip.originalLink, gauntlets)
    Equal(ItemTooltip.originalCalls, 1)
    Equal(ItemTooltip.cards, 1)
    local card = ItemTooltip.lastCard
    assert(card.height > 100)
    local labels = #card.labels
    ItemTooltip:SetBagItem(1, 1)
    Equal(ItemTooltip.cards, 2)
    Equal(ItemTooltip.lastCard, card)
    Equal(#card.labels, labels)
    state.stocks[64489] = 0
    ItemTooltip:SetBagItem(1, 1)
    local statusText = card.labels[1].text
    assert(statusText:find("JUST NEED MATERIALS", 1, true))
    ItemTooltip:SetLink(W.ItemLink(5))
    Equal(card.hidden, true)
    Equal(ItemTooltip.writCheckerLink, nil)
    PopupTooltip:SetLink(Writ(68276))
    assert(PopupTooltip.lastCard ~= card)
    assert(SLASH_COMMANDS["/writchecker"])
end)

local function CardText(card)
    local text = {}
    for index = 1, card.used do text[#text + 1] = card.labels[index].text end
    return table.concat(text, "\n")
end

Test("Crafting Ledger retains every requirement and exact material quantities without settings libraries", function()
    local report = W.Finalize({
        checks = {
            { label = "Learned requirement", passed = true, detail = "Known" },
            { label = "Missing requirement", passed = false, detail = "Learn this" },
            { label = "Uncertain requirement", detail = "Not verified" },
        },
        materials = {
            { id = 1, name = "Available supply", icon = "icon.dds", have = 12, need = 3 },
            { id = 2, name = "Missing supply", icon = "icon.dds", have = 2, need = 8 },
        }, notes = {},
    })
    local card = W.CreateCard(ItemTooltip)
    W.RenderCard(card, report, 360)
    local text = CardText(card)
    for _, expected in ipairs({
        "REQUIREMENTS MISSING", "Learned requirement", "Missing requirement", "Uncertain requirement",
        "Available supply", "Missing supply", "2 / 8  (-6)", "12 / 3",
    }) do
        assert(text:find(expected, 1, true), expected)
    end
    for index = 1, card.used do
        local label = card.labels[index]
        if label.text:find("2 / 8", 1, true) or label.text:find("Learn this", 1, true) then
            Equal(label.align, TEXT_ALIGN_RIGHT)
            Equal(card.labels[index - 1].align, TEXT_ALIGN_LEFT)
            Equal(label.anchor[5], card.labels[index - 1].anchor[5])
        end
    end
    assert(card.divider)
    assert(not text:find("TAMRIEL TOOLS", 1, true))
end)
Test("tooltip headings are centered for every verdict and the divider follows the card width", function()
    local card = W.CreateCard(ItemTooltip)
    for index, status in ipairs({ "ready", "blocked", "materials", "unknown" }) do
        Reset()
        if status == "blocked" then state.research = 8 end
        if status == "materials" then state.stocks[64489] = 0 end
        if status == "unknown" then state.motif = 0 end
        local report = W.Evaluate(gauntlets)
        Equal(report.status, status)
        local width = 400 - index * 20
        W.RenderCard(card, report, width)
        Equal(card.divider.width, width - 8)
        Equal(card.divider.hidden, false)
        assert(card.divider.height > 0)
        assert(card.labels[1].anchor[5] > card.divider.height)
        Equal(card.labels[1].align, TEXT_ALIGN_CENTER)
        Equal(card.labels[2].align, TEXT_ALIGN_CENTER)
        local headings = 0
        for labelIndex = 3, card.used do
            local label = card.labels[labelIndex]
            if label.text:find("Crafting requirements", 1, true)
                or label.text:find("Materials (owned / needed)", 1, true)
                or label.text:find("Use a Test Set crafting station.", 1, true) then
                Equal(label.align, TEXT_ALIGN_CENTER)
                headings = headings + 1
            elseif label.text:find("Material passive", 1, true)
                or label.text:find("Item 64489", 1, true) then
                Equal(label.align, TEXT_ALIGN_LEFT)
                Equal(card.labels[labelIndex + 1].align, TEXT_ALIGN_RIGHT)
            end
        end
        Equal(headings, 3)
    end
end)
Test("crafting station appears within requirements, with no inventory-scope footer", function()
    local card = W.CreateCard(ItemTooltip)
    W.RenderCard(card, W.Evaluate(gauntlets), 360)
    local text = CardText(card)
    local requirements = assert(text:find("Crafting requirements", 1, true))
    local motif = assert(text:find("Motif chapter", 1, true))
    local station = assert(text:find("Use a Test Set crafting station.", 1, true))
    local materials = assert(text:find("Materials (owned / needed)", 1, true))
    assert(requirements < motif and motif < station and station < materials)
    assert(not text:find("This character", 1, true))
    assert(not text:find("Backpack, bank & Craft Bag", 1, true))
    W.RenderCard(card, W.Evaluate(Writ(26580, 207, 5)), 360)
    assert(not CardText(card):find("crafting station", 1, true))
end)
Test("Crafting Ledger hides unused pooled rows when a shorter writ replaces a longer one", function()
    local report = W.Evaluate(gauntlets)
    local card = W.CreateCard(ItemTooltip)
    W.RenderCard(card, report, 360)
    local fullHeight, labels = card.height, card.used
    W.RenderCard(card, W.Evaluate(Writ(26580, 207, 5)), 360)
    assert(card.height < fullHeight)
    assert(card.used < labels)
    assert(CardText(card):find("READY TO CRAFT", 1, true))
    for index = card.used + 1, #card.labels do Equal(card.labels[index].hidden, true) end
end)

Test("inventory markers match readiness and reset when rows are reused for ordinary items", function()
    state.bagLink = gauntlets
    local row = setmetatable({}, Control)
    local slot = { bagId = 1, slotIndex = 1 }
    inventoryDataType.setupCallback(row, slot)
    local marker = row.writCheckerMarker
    Equal(row.originalSetupCalls, 1)
    Equal(marker.text, "|c87AD73+|r")
    Equal(marker.hidden, false)
    Equal(marker.anchor[2], row:GetNamedChild("Button"))
    state.stocks[64489] = 0
    inventoryDataType.setupCallback(row, slot)
    Equal(marker.text, "|cE07777!|r")
    state.stocks[64489], state.research = 1000, 8
    inventoryDataType.setupCallback(row, slot)
    Equal(marker.text, "|cE07777!|r")
    state.research, state.motif = 9, 0
    inventoryDataType.setupCallback(row, slot)
    Equal(marker.text, "|cA09F91?|r")
    state.bagLink = W.ItemLink(5)
    inventoryDataType.setupCallback(row, slot)
    Equal(marker.hidden, true)
    Equal(row.writCheckerMarker, marker)
    state.bagLink = W.ItemLink(900)
    inventoryDataType.setupCallback(row, slot)
    Equal(marker.text, "|cA09F91?|r")
    Equal(marker.hidden, false)
end)
Test("visible inventory refreshes after stock and knowledge changes, coalescing event bursts", function()
    state.bagLink = gauntlets
    local row = setmetatable({}, Control)
    inventoryList.rows = { { row = row, slot = { bagId = 1, slotIndex = 1 } } }
    inventoryList.hidden = false
    inventoryList.OnEffectivelyShown()
    FlushTimers()
    Equal(row.writCheckerMarker.text, "|c87AD73+|r")
    local refreshes = inventoryList.refreshes
    state.stocks[64489] = 0
    for _ = 1, 10 do events[EVENT_INVENTORY_SINGLE_SLOT_UPDATE]() end
    Equal(#timers, 1)
    FlushTimers()
    Equal(inventoryList.refreshes, refreshes + 1)
    Equal(row.writCheckerMarker.text, "|cE07777!|r")
    state.stocks[64489], state.motif = 1000, 0
    knowledgeCallbacks[LibCharacterKnowledge.EVENT_UPDATE_REFRESH]()
    FlushTimers()
    Equal(row.writCheckerMarker.text, "|cA09F91?|r")
    state.motif = 1
    knowledgeCallbacks[LibCharacterKnowledge.EVENT_UPDATE_REFRESH]()
    FlushTimers()
    Equal(row.writCheckerMarker.text, "|c87AD73+|r")
    state.research = 8
    events[EVENT_SMITHING_TRAIT_RESEARCH_COMPLETED]()
    FlushTimers()
    Equal(row.writCheckerMarker.text, "|cE07777!|r")
    inventoryList.hidden = true
    state.research = 9
    refreshes = inventoryList.refreshes
    events[EVENT_SKILL_POINTS_CHANGED]()
    FlushTimers()
    Equal(inventoryList.refreshes, refreshes)
    inventoryList.hidden = false
    inventoryList.OnEffectivelyShown()
    FlushTimers()
    Equal(row.writCheckerMarker.text, "|c87AD73+|r")
    inventoryList.hidden, inventoryList.rows = true, {}
end)

print(string.format("%d tests passed%s", passed, realAlchemy and " (real LibAlchemy integration)" or ""))
