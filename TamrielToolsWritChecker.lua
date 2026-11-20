TamrielToolsWritChecker = {
    name = "TamrielToolsWritChecker",
    templates = {},
}
local W = TamrielToolsWritChecker

local function Group(craft, material, templates)
    for _, template in ipairs(templates) do
        W.templates[template] = { craft = craft, material = material }
    end
end

Group(CRAFTING_TYPE_BLACKSMITHING, 64489, { 53, 56, 59, 68, 69, 67, 62, 46, 50, 52, 44, 49, 47, 48 })
Group(CRAFTING_TYPE_CLOTHIER, 64504, { 28, 75, 32, 34, 26, 31, 29, 30 })
Group(CRAFTING_TYPE_CLOTHIER, 64506, { 37, 41, 43, 35, 40, 38, 39 })
Group(CRAFTING_TYPE_WOODWORKING, 64502, { 70, 65, 72, 73, 74, 71 })
Group(CRAFTING_TYPE_JEWELRYCRAFTING, 135146, { 24, 18 })

W.levelBonuses = {
    [CRAFTING_TYPE_BLACKSMITHING] = NON_COMBAT_BONUS_BLACKSMITHING_LEVEL,
    [CRAFTING_TYPE_CLOTHIER] = NON_COMBAT_BONUS_CLOTHIER_LEVEL,
    [CRAFTING_TYPE_WOODWORKING] = NON_COMBAT_BONUS_WOODWORKING_LEVEL,
    [CRAFTING_TYPE_JEWELRYCRAFTING] = NON_COMBAT_BONUS_JEWELRYCRAFTING_LEVEL,
}

local armorChapters = {
    ITEM_STYLE_CHAPTER_CHESTS, ITEM_STYLE_CHAPTER_BOOTS, ITEM_STYLE_CHAPTER_GLOVES,
    ITEM_STYLE_CHAPTER_HELMETS, ITEM_STYLE_CHAPTER_LEGS, ITEM_STYLE_CHAPTER_SHOULDERS,
    ITEM_STYLE_CHAPTER_BELTS,
}

function W.GetResearchLine(craft, pattern)
    if craft == CRAFTING_TYPE_CLOTHIER then
        return math.max(1, pattern - 1)
    elseif craft == CRAFTING_TYPE_WOODWORKING then
        return ({ 1, 6, 2, 3, 4, 5 })[pattern]
    elseif craft == CRAFTING_TYPE_JEWELRYCRAFTING then
        return 3 - pattern
    end
    return pattern
end

function W.GetChapter(craft, pattern)
    if craft == CRAFTING_TYPE_BLACKSMITHING then
        if pattern <= 7 then
            return ({
                ITEM_STYLE_CHAPTER_AXES, ITEM_STYLE_CHAPTER_MACES, ITEM_STYLE_CHAPTER_SWORDS,
                ITEM_STYLE_CHAPTER_AXES, ITEM_STYLE_CHAPTER_MACES, ITEM_STYLE_CHAPTER_SWORDS,
                ITEM_STYLE_CHAPTER_DAGGERS,
            })[pattern]
        end
        return armorChapters[pattern - 7]
    elseif craft == CRAFTING_TYPE_CLOTHIER then
        return armorChapters[(W.GetResearchLine(craft, pattern) - 1) % 7 + 1]
    elseif craft == CRAFTING_TYPE_WOODWORKING then
        return pattern == 1 and ITEM_STYLE_CHAPTER_BOWS
            or pattern == 2 and ITEM_STYLE_CHAPTER_SHIELDS or ITEM_STYLE_CHAPTER_STAVES
    end
end

function W.ItemLink(itemId)
    return string.format("|H1:item:%d:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", itemId)
end

function W.ItemName(link)
    return zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(link))
end

local function Check(report, label, passed, detail)
    report.checks[#report.checks + 1] = { label = label, passed = passed, detail = detail }
end
W.AddCheck = Check

function W.AddMaterial(report, link, quantity)
    if not link or link == "" or not quantity or quantity <= 0 or GetItemLinkItemId(link) == 0 then
        Check(report, "Materials", nil, "Material data unavailable")
        return
    end
    local id = GetItemLinkItemId(link)
    for _, material in ipairs(report.materials) do
        if material.id == id then
            material.need = material.need + quantity
            return
        end
    end
    local backpack, bank, craftBag = GetItemLinkStacks(link)
    report.materials[#report.materials + 1] = {
        id = id, link = link, name = W.ItemName(link), icon = GetItemLinkIcon(link),
        need = quantity, have = backpack + bank + craftBag,
    }
end

local function Rank(report, label, bonus, required)
    local current = GetNonCombatBonus(bonus)
    Check(report, label, current >= required, string.format("%d / %d", current, required))
end

function W.CheckSmithing(report, fields, template)
    local craft = template.craft
    report.craft = craft
    local pattern = LibLazyCrafting.GetItemTemplateIdPatternIndex(fields[1])
    if not pattern or fields[3] < 2 or fields[3] > 5 or fields[4] <= 0 or fields[5] <= 0 then
        Check(report, "Writ data", nil, "Unsupported equipment requirements")
        return
    end
    Rank(report, "Material passive", W.levelBonuses[craft], craft == CRAFTING_TYPE_JEWELRYCRAFTING and 5 or 10)

    local line = W.GetResearchLine(craft, pattern)
    local piece, _, traitCount = GetSmithingResearchLineInfo(craft, line)
    local knownCount, traitKnown = 0, false
    for index = 1, traitCount do
        local trait, _, known = GetSmithingResearchLineTraitInfo(craft, line, index)
        if known then knownCount = knownCount + 1 end
        if trait == fields[5] then traitKnown = known end
    end
    Check(report, "Trait researched", traitKnown, GetString("SI_ITEMTRAITTYPE", fields[5]))

    local required = LibSets.GetTraitsNeeded(fields[4])
    report.setName = LibSets.GetSetName(fields[4])
    Check(report, "Set research", required and knownCount >= required,
        required and string.format("%s: %d / %d", piece, knownCount, required) or "Set data not loaded")
    report.station = report.setName and ("Use a " .. report.setName .. " crafting station.")
        or "Use the required set crafting station."

    if craft ~= CRAFTING_TYPE_JEWELRYCRAFTING then
        local chapter = W.GetChapter(craft, pattern)
        local knowledge = LibCharacterKnowledge.GetMotifKnowledgeForCharacter(fields[6], chapter)
        local passed
        if knowledge == LibCharacterKnowledge.KNOWLEDGE_KNOWN then
            passed = true
        elseif knowledge == LibCharacterKnowledge.KNOWLEDGE_UNKNOWN then
            passed = false
        end
        Check(report, "Motif chapter", passed,
            zo_strformat("<<1>> - <<2>>", GetItemStyleName(fields[6]), GetString("SI_ITEMSTYLECHAPTER", chapter)))
        local styleLink = GetItemStyleMaterialLink(fields[6], LINK_STYLE_DEFAULT)
        local have = styleLink ~= "" and W.CountMaterial(styleLink) or 0
        if have < 1 and W.CountMaterial(W.ItemLink(71668)) >= 1 then
            W.AddMaterial(report, W.ItemLink(71668), 1)
            report.notes[#report.notes + 1] = "Uses a Crown Mimic Stone in place of the style material."
        else
            W.AddMaterial(report, styleLink, 1)
        end
    end

    local quantity = LibLazyCrafting.functionTable.GetMatRequirements(pattern, 40, craft)
    W.AddMaterial(report, W.ItemLink(template.material), quantity)
    W.AddMaterial(report, GetSmithingTraitItemLink(fields[5] + 1, LINK_STYLE_DEFAULT), 1)
    for quality = 1, fields[3] - 1 do
        W.AddMaterial(report, GetSmithingImprovementItemLink(craft, quality, LINK_STYLE_DEFAULT),
            GetSmithingGuaranteedImprovementItemAmount(craft, quality))
    end
    report.notes[#report.notes + 1] = "CP150 equipment; upgrades calculated at 100% success."
end

function W.CountMaterial(link)
    local backpack, bank, craftBag = GetItemLinkStacks(link)
    return backpack + bank + craftBag
end

function W.CheckProvisioning(report, fields)
    report.craft = CRAFTING_TYPE_PROVISIONING
    local recipeId = LibCharacterKnowledge.GetSourceItemIdFromResultItem(fields[1])
    if not recipeId or recipeId == 0 then
        Check(report, "Recipe", nil, "Recipe data not loaded or recipe unsupported")
        return
    end
    local recipe = W.ItemLink(recipeId)
    Check(report, "Recipe learned", IsItemLinkRecipeKnown(recipe), W.ItemName(recipe))
    local requirements = GetItemLinkRecipeNumTradeskillRequirements(recipe)
    if requirements == 0 then
        Check(report, "Recipe skills", nil, "Recipe skill requirements unavailable")
    end
    for index = 1, requirements do
        local craft, level = GetItemLinkRecipeTradeskillRequirement(recipe, index)
        if craft == CRAFTING_TYPE_PROVISIONING then
            Rank(report, "Recipe Improvement", NON_COMBAT_BONUS_PROVISIONING_LEVEL, level)
        else
            Check(report, "Recipe skills", nil, "Unsupported recipe crafting skill")
        end
    end
    Rank(report, "Recipe Quality", NON_COMBAT_BONUS_PROVISIONING_RARITY_LEVEL,
        GetItemLinkRecipeQualityRequirement(recipe))
    local result = GetItemLinkRecipeResultItemLink(recipe, LINK_STYLE_DEFAULT)
    local isDrink = GetItemLinkItemType(result) == ITEMTYPE_DRINK
    local extra = GetNonCombatBonus(isDrink and NON_COMBAT_BONUS_PROVISIONING_CREATE_EXTRA_DRINK
        or NON_COMBAT_BONUS_PROVISIONING_CREATE_EXTRA_FOOD)
    local batches = math.ceil(8 / (1 + extra))
    local ingredients = GetItemLinkRecipeNumIngredients(recipe)
    if ingredients == 0 then Check(report, "Ingredients", nil, "Ingredient data unavailable") end
    for index = 1, ingredients do
        local _, _, quantity = GetItemLinkRecipeIngredientInfo(recipe, index)
        W.AddMaterial(report, GetItemLinkRecipeIngredientItemLink(recipe, index, LINK_STYLE_DEFAULT), quantity * batches)
    end
    report.notes[#report.notes + 1] = string.format("8 servings / %d batches with your current passives.", batches)
end

function W.CheckEnchanting(report, fields)
    report.craft = CRAFTING_TYPE_ENCHANTING
    local cp = ({ [207] = 150, [225] = 160 })[fields[2]]
    if not cp or fields[3] < 2 or fields[3] > 5 then
        Check(report, "Glyph", nil, "Unsupported glyph level or quality")
        return
    end
    local essenceData, potencyData, aspectData = LibLazyCrafting.getGlyphInfo()
    local parity, essence
    for _, entry in ipairs(essenceData) do
        if entry[3] == fields[1] then parity, essence = -1, entry[9] end
        if entry[4] == fields[1] then parity, essence = 1, entry[9] end
    end
    local potency
    for _, entry in ipairs(potencyData) do
        if entry.cp == cp and entry[1] == parity then potency = entry[2] end
    end
    if not potency or not essence or not aspectData[fields[3]] then
        Check(report, "Runes", nil, "Glyph components unavailable")
        return
    end
    Rank(report, "Potency Improvement", NON_COMBAT_BONUS_ENCHANTING_LEVEL, cp == 150 and 9 or 10)
    local aspectRank = ({ 1, 1, 2, 3, 4 })[fields[3]]
    Rank(report, "Aspect Improvement", NON_COMBAT_BONUS_ENCHANTING_RARITY_LEVEL, aspectRank)
    for _, id in ipairs({ potency, essence, aspectData[fields[3]] }) do
        W.AddMaterial(report, W.ItemLink(id), 1)
    end
    report.notes[#report.notes + 1] = "Rune translations are not required to craft a glyph."
end

local alchemyFormulas = {}

local function HasAlchemyEffects(combination, effects)
    for _, effect in ipairs(effects) do
        local matches = 0
        for _, id in ipairs(combination) do
            for _, reagentEffect in ipairs(LibAlchemy.reagents[id][3]) do
                if reagentEffect == effect then matches = matches + 1 end
                if reagentEffect == LibAlchemy.opposites[effect] then matches = matches - 1 end
            end
        end
        if matches < 2 then return false end
    end
    return true
end

function W.CheckAlchemy(report, fields)
    report.craft = CRAFTING_TYPE_ALCHEMY
    Rank(report, "Solvent Proficiency", NON_COMBAT_BONUS_ALCHEMY_LEVEL, 8)
    Rank(report, "Laboratory Use", NON_COMBAT_BONUS_ALCHEMY_THIRD_SLOT, 1)
    local effects = {}
    for index = 2, 4 do
        local effect = LibAlchemy.potionEffectIdToString[fields[index]]
        if not effect then
            Check(report, "Alchemy formula", nil, "Unsupported alchemy effect")
            return
        end
        effects[#effects + 1] = effect
    end
    local key = table.concat(effects, ":")
    local combinations = alchemyFormulas[key]
    if not combinations then
        local candidates = LibAlchemy:ThreeEffects(effects[1], effects[2], effects[3])
        local alternatives = LibAlchemy:ThreeEffectsAlt(effects[1], effects[2], effects[3])
        for _, combination in ipairs(alternatives) do candidates[#candidates + 1] = combination end
        candidates = LibAlchemy:sortOutWrongCombinations3(candidates, effects)
        combinations = {}
        for _, combination in ipairs(candidates) do
            if #combination == 3 and combination[1] ~= combination[2]
                and combination[1] ~= combination[3] and combination[2] ~= combination[3]
                and HasAlchemyEffects(combination, effects) then
                combinations[#combinations + 1] = combination
            end
        end
        alchemyFormulas[key] = combinations
    end
    local poison = fields[1] == 239
    local yield = (1 + GetNonCombatBonus(NON_COMBAT_BONUS_ALCHEMY_CREATE_EXTRA)) * (poison and 4 or 1)
    local batches = math.ceil(16 / yield)
    local best, bestMissing, bestStock
    for _, combination in ipairs(combinations) do
        if #combination == 3 and combination[1] ~= combination[2]
            and combination[1] ~= combination[3] and combination[2] ~= combination[3] then
            local missing, stock = 0, 0
            for _, id in ipairs(combination) do
                local have = W.CountMaterial(W.ItemLink(id))
                missing = missing + math.max(0, batches - have)
                stock = stock + have
            end
            if not best or missing < bestMissing or (missing == bestMissing and stock > bestStock) then
                best, bestMissing, bestStock = combination, missing, stock
            end
        end
    end
    if not best then
        Check(report, "Alchemy formula", nil, "No supported three-reagent combination")
        return
    end
    W.AddMaterial(report, W.ItemLink(poison and 75365 or 64501), batches)
    for _, id in ipairs(best) do W.AddMaterial(report, W.ItemLink(id), batches) end
    report.notes[#report.notes + 1] = string.format("16 required / %d batches. Formula selected from your stocks.", batches)
    report.notes[#report.notes + 1] = "Undiscovered reagent effects do not prevent manual crafting."
end

function W.Finalize(report)
    local failed, unknown, passed = 0, 0, 0
    for _, check in ipairs(report.checks) do
        if check.passed == nil then unknown = unknown + 1
        elseif check.passed then passed = passed + 1
        else failed = failed + 1 end
    end
    local missing = 0
    for _, material in ipairs(report.materials) do
        material.missing = math.max(0, material.need - material.have)
        if material.missing > 0 then missing = missing + 1 end
    end
    table.sort(report.materials, function(a, b)
        if (a.missing > 0) ~= (b.missing > 0) then return a.missing > 0 end
        return a.name < b.name
    end)
    report.passed, report.failed, report.unknown, report.missing = passed, failed, unknown, missing
    report.status = failed > 0 and "blocked" or unknown > 0 and "unknown"
        or missing > 0 and "materials" or #report.materials == 0 and "unknown" or "ready"
    return report
end

function W.Evaluate(link)
    if not link or link == "" or GetItemLinkItemType(link) ~= ITEMTYPE_MASTER_WRIT then return end
    local report = { link = link, checks = {}, materials = {}, notes = {} }
    local parsed = { ZO_LinkHandler_ParseLink(link) }
    local fields = {}
    for index = 1, 6 do fields[index] = tonumber(parsed[index + 9]) end
    for index = 1, 6 do
        if not fields[index] or fields[index] < 0 or fields[index] % 1 ~= 0 then
            Check(report, "Writ data", nil, "Unrecognized sealed writ link")
            return W.Finalize(report)
        end
    end
    local template = W.templates[fields[1]]
    if template then
        W.CheckSmithing(report, fields, template)
    elseif fields[1] == 199 or fields[1] == 239 then
        W.CheckAlchemy(report, fields)
    elseif fields[2] == 207 or fields[2] == 225 then
        W.CheckEnchanting(report, fields)
    elseif fields[1] > 0 and fields[2] == 0 and fields[3] == 0 then
        W.CheckProvisioning(report, fields)
    else
        Check(report, "Writ type", nil, "This contract is not supported yet")
    end
    return W.Finalize(report)
end

local COLORS = {
    gold = "C5C29E", muted = "A09F91",
    ready = "87AD73", blocked = "E07777", materials = "D5B56E", unknown = "C5B887",
}
local STATUS = {
    ready = { title = "READY TO CRAFT", subtitle = "Knowledge checked. Materials in hand." },
    blocked = { title = "REQUIREMENTS MISSING", subtitle = "This character needs a little more preparation." },
    materials = { title = "JUST NEED MATERIALS", subtitle = "You know how. Time to stock up." },
    unknown = { title = "NEEDS VERIFICATION", subtitle = "Some requirements could not be verified." },
}

local function Color(color, text)
    return "|c" .. COLORS[color] .. text .. "|r"
end

local function Label(card, text, x, y, width, font, align)
    card.used = card.used + 1
    local label = card.labels[card.used]
    if not label then
        label = WINDOW_MANAGER:CreateControl(nil, card, CT_LABEL)
        card.labels[card.used] = label
    end
    label:ClearAnchors()
    label:SetAnchor(TOPLEFT, card, TOPLEFT, x, y)
    label:SetWidth(width)
    label:SetFont(font or "ZoFontGameSmall")
    label:SetHorizontalAlignment(align or TEXT_ALIGN_LEFT)
    label:SetColor(1, 1, 1, 1)
    label:SetText(text)
    label:SetHidden(false)
    return label:GetTextHeight()
end

local function Rule(card, y, width, text)
    local height = Label(card, Color("gold", text), 4, y, width - 8, "ZoFontGame", TEXT_ALIGN_CENTER)
    return y + height + 5
end

function W.CreateCard(tooltip)
    local card = WINDOW_MANAGER:CreateControl(nil, tooltip, CT_CONTROL)
    card.labels = {}
    card:SetMouseEnabled(false)
    card.divider = WINDOW_MANAGER:CreateControlFromVirtual(nil, card, "ZO_BaseTooltipDivider")
    card.divider:ClearAnchors()
    card.divider:SetAnchor(TOP, card, TOP, 0, 0)
    card.divider:SetHeight(3)
    return card
end

local function Marker(state)
    return ({ ready = "+", blocked = "!", unknown = "?" })[state]
end

local function Rows(card, rows, y, width)
    local available = width - 8
    local leftWidth = math.floor(available * 0.45)
    for _, row in ipairs(rows) do
        local name = row.icon and zo_iconFormat(row.icon, 18, 18) .. " " .. row.name
            or Marker(row.state) .. "  " .. row.name
        local height = math.max(
            Label(card, Color(row.state, name), 4, y, leftWidth),
            Label(card, Color(row.state, row.detail), 4 + leftWidth + 8, y,
                available - leftWidth - 8, nil, TEXT_ALIGN_RIGHT))
        y = y + height + 5
    end
    return y
end

function W.RenderCard(card, report, width)
    card.used = 0
    card:SetWidth(width)
    local padding = 4
    local contentWidth = width - padding * 2
    card.divider:SetWidth(contentWidth)
    card.divider:SetHidden(false)
    local y = 14
    local status = STATUS[report.status]
    y = y + Label(card, Color(report.status, status.title), padding, y, contentWidth,
        "ZoFontWinH4", TEXT_ALIGN_CENTER) + 4
    local completed = report.passed + #report.materials - report.missing
    local total = #report.checks + #report.materials
    local summary = string.format("%d / %d checks passed", completed, total)
    y = y + Label(card, Color("muted", summary), padding, y, contentWidth, nil, TEXT_ALIGN_CENTER) + 9

    local checks, materials = {}, {}
    for _, check in ipairs(report.checks) do
        checks[#checks + 1] = {
            name = check.label, detail = check.detail or "Data unavailable",
            state = check.passed == nil and "unknown" or check.passed and "ready" or "blocked",
        }
    end
    for _, material in ipairs(report.materials) do
        local detail = string.format("%d / %d", material.have, material.need)
        if material.missing > 0 then detail = detail .. "  (-" .. material.missing .. ")" end
        materials[#materials + 1] = {
            name = material.name, detail = detail, icon = material.icon,
            state = material.missing > 0 and "blocked" or "ready",
        }
    end
    if #checks > 0 or report.station then
        y = Rule(card, y, width, "Crafting requirements")
        y = Rows(card, checks, y, width)
        if report.station then
            y = y + 5 + Label(card, Color("gold", report.station), padding, y + 5, contentWidth,
                nil, TEXT_ALIGN_CENTER)
        end
    end
    if #materials > 0 then
        y = Rule(card, y + 3, width, "Materials (owned / needed)")
        y = Rows(card, materials, y, width)
    end
    y = y + 8
    for index = card.used + 1, #card.labels do card.labels[index]:SetHidden(true) end
    card:SetHeight(y)
    card:SetHidden(false)
end

function W.AppendTooltip(tooltip, link)
    if tooltip.writCheckerLink == link then return end
    local report = W.Evaluate(link)
    if not report then return end
    tooltip.writCheckerLink = link
    local card = tooltip.writCheckerCard
    if not card then
        card = W.CreateCard(tooltip)
        tooltip.writCheckerCard = card
    end
    W.RenderCard(card, report, math.max(260, tooltip:GetWidth() - 32))
    tooltip:AddVerticalPadding(10)
    tooltip:AddControl(card)
    card:ClearAnchors()
    card:SetAnchor(CENTER)
end

function W.HookTooltips()
    local methods = {
        SetLink = function(link) return link end,
        SetBagItem = GetItemLink,
        SetTradeItem = GetTradeItemLink,
        SetBuybackItem = GetBuybackItemLink,
        SetStoreItem = GetStoreItemLink,
        SetAttachedMailItem = GetAttachedItemLink,
        SetLootItem = GetLootItemLink,
        SetTradingHouseItem = GetTradingHouseSearchResultItemLink,
        SetTradingHouseListing = GetTradingHouseListingItemLink,
    }
    for _, tooltip in ipairs({ ItemTooltip, PopupTooltip }) do
        ZO_PreHookHandler(tooltip, "OnCleared", function(control)
            control.writCheckerLink = nil
            if control.writCheckerCard then control.writCheckerCard:SetHidden(true) end
        end)
        for method, getLink in pairs(methods) do
            if tooltip[method] then
                ZO_PostHook(tooltip, method, function(control, ...)
                    W.AppendTooltip(control, getLink(...))
                end)
            end
        end
    end
end

local MARKERS = {
    ready = "|c87AD73+|r",
    blocked = "|cE07777!|r",
    materials = "|cE07777!|r",
    unknown = "|cA09F91?|r",
}

function W.UpdateInventoryRow(row, slot)
    local marker = row.writCheckerMarker
    if marker then marker:SetHidden(true) end
    local report = W.Evaluate(GetItemLink(slot.bagId, slot.slotIndex))
    if not report then return end
    if not marker then
        marker = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
        marker:SetFont("ZoFontWinH4")
        marker:SetWidth(18)
        marker:SetHeight(22)
        marker:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        marker:SetAnchor(BOTTOMRIGHT, row:GetNamedChild("Button"), BOTTOMRIGHT, 5, 3)
        marker:SetDrawLayer(DL_OVERLAY)
        marker:SetMouseEnabled(false)
        row.writCheckerMarker = marker
    end
    marker:SetText(MARKERS[report.status])
    marker:SetHidden(false)
end

function W.HookInventory()
    local inventory = PLAYER_INVENTORY.inventories[INVENTORY_BACKPACK]
    local list = inventory.listView
    ZO_PostHook(list.dataTypes[inventory.listDataType], "setupCallback", W.UpdateInventoryRow)

    local refreshPending = false
    local function Refresh()
        if refreshPending then return end
        refreshPending = true
        zo_callLater(function()
            refreshPending = false
            if not list:IsHidden() then ZO_ScrollList_RefreshVisible(list) end
        end, 100)
    end
    ZO_PreHookHandler(list, "OnEffectivelyShown", Refresh)
    for _, event in ipairs({
        EVENT_PLAYER_ACTIVATED,
        EVENT_INVENTORY_FULL_UPDATE,
        EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        EVENT_SKILL_POINTS_CHANGED,
        EVENT_SKILL_RANK_UPDATE,
        EVENT_SKILL_RESPEC_RESULT,
        EVENT_SMITHING_TRAIT_RESEARCH_COMPLETED,
        EVENT_RECIPE_LEARNED,
        EVENT_LORE_BOOK_LEARNED,
    }) do
        EVENT_MANAGER:RegisterForEvent(W.name .. "Inventory", event, Refresh)
    end
    for _, event in ipairs({
        LibCharacterKnowledge.EVENT_INITIALIZED,
        LibCharacterKnowledge.EVENT_UPDATE_REFRESH,
    }) do
        assert(LibCharacterKnowledge.RegisterForCallback(W.name .. "Inventory", event, Refresh),
            "Writ Checker: could not register inventory knowledge refresh")
    end
    Refresh()
end

local function Loaded(_, addonName)
    if addonName ~= W.name then return end
    EVENT_MANAGER:UnregisterForEvent(W.name, EVENT_ADD_ON_LOADED)
    W.HookTooltips()
    W.HookInventory()
    SLASH_COMMANDS["/writchecker"] = function()
        d("|cD8BC78Tamriel Tools: Writ Checker|r - Hover a sealed master writ, or click a writ link in chat.")
        d("Checks the current character and materials in your backpack, bank and Craft Bag. Re-hover to refresh.")
        d("Inventory writ icons: green + ready, red ! cannot craft, grey ? unverified.")
    end
end

EVENT_MANAGER:RegisterForEvent(W.name, EVENT_ADD_ON_LOADED, Loaded)
