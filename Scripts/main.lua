-- ============================================================
-- Retro Rewind - Auto Restock Snacks
-- Version: 1.9
--
-- Automatically restocks snack shelves, fridges, and candy
-- dispensers when the store opens, and again at configured
-- ingame hours. Deducts snack purchase costs from funds;
-- credits candy dispenser revenue to the player's account.
-- ============================================================

-- ============================================================
-- CONFIG
-- ============================================================
local CONFIG = {
    restockHours = { 18 }, -- Additional restock hours after opening
    deductCost = true,     -- Set to false for free snack restock
    restockCandy = true,   -- Set to false to skip candy dispensers
    Debug = false,         -- true = log hook registrations and internal errors
}

-- ============================================================
-- CONSTANTS
-- ============================================================
local SNACK_COUNT_KEY = "Numberofsnack_6_DAA7E0CC43A15C60F16C9CA869EF530B"

-- ============================================================
-- INTERNAL
-- ============================================================
local P = "[AutoRestock-QoL] "

local function log(msg)
    print(P .. msg .. "\n")
end

local function debug(msg)
    if CONFIG.Debug then
        log(msg)
    end
end

local function safe(label, fn, ...)
    local results = {pcall(fn, ...)}
    if not results[1] then
        log(label .. " FAILED: " .. tostring(results[2]))
        return nil
    end
    return table.unpack(results, 2)
end

local registeredHooks = {}

local function registerHookOptional(path, callback)
    if registeredHooks[path] then return end
    registeredHooks[path] = true
    local ok, err = pcall(function() RegisterHook(path, callback) end)
    if ok then
        debug("Hook active: " .. path)
    else
        log("Hook error: " .. path .. " / " .. tostring(err))
    end
end

local lastRestockHour = -1
local openedAtHour    = -1

-- Pre-built set for O(1) lookup during the per-minute timer
local restockHourSet = {}
for _, h in ipairs(CONFIG.restockHours) do restockHourSet[h] = true end

-- ============================================================
-- CACHED REFERENCE: Core_Gamemode_C
-- ============================================================
local cachedGamemode = nil

local function getGamemode()
    if not cachedGamemode or not cachedGamemode:IsValid() then
        local gms = FindAllOf("Core_Gamemode_C")
        cachedGamemode = gms and gms[1] or nil
    end
    return cachedGamemode
end

-- ============================================================
-- HELPER: Deduct money via Core_Gamemode_C:Change Money
-- ============================================================
local function deductMoney(amount)
    if amount <= 0 then return end
    local gm = getGamemode()
    if not gm then
        log("Gamemode not available - cost not deducted")
        return
    end
    local hasEnough = {}
    local newMoney = {}
    local ok, err = pcall(function()
        gm["Change Money"](-amount, false, true, hasEnough, newMoney)
    end)
    if not ok then
        log("Change Money error: " .. tostring(err))
    end
end

-- ============================================================
-- HELPER: Read the sale price of snacks stored in a pack.
-- ============================================================
local function getSnackSalePrice(pack)
    local price = 0
    safe("getSnackSalePrice", function()
        local containers = pack["Snack Container Array"]
        if not containers then return end
        
        local count = 0
        pcall(function() count = containers:GetArrayNum() end)

        if count > 0 then
            for i = 1, count do
                local container = containers[i]
                if container then
                    local snack = container["Snack Stored"]
                    if snack then
                        local p = snack["Price"]
                        if type(p) == "number" and p > 0 then
                            price = p
                            return
                        end
                    end
                end
            end
        else
            -- Fallback when GetArrayNum is unavailable; ForEach cannot break early,
            -- so we guard against overwriting once a price is found.
            containers:ForEach(function(_, cElem)
                if price > 0 then return end
                local container = cElem:get()
                if not container then return end
                local snack = container["Snack Stored"]
                if not snack then return end
                local p = snack["Price"]
                if type(p) == "number" and p > 0 then
                    price = p
                end
            end)
        end
    end)
    return price
end

-- ============================================================
-- RESTOCK: Fill a single shelf and return its purchase cost.
-- ============================================================
local function restockShelf(shelf)
    local packs = shelf["As Snack Pack"]
    if not packs then return 0 end

    local shelfCost = 0

    packs:ForEach(function(_, elem)
        safe("pack restock", function()
            local pack = elem:get()
            if not pack then return end

            local emptySlots = 0
            local totalSlots = 0
            
            local containers = pack["Snack Container Array"]
            if containers then
                containers:ForEach(function(_, cElem)
                    totalSlots = totalSlots + 1
                    local container = cElem:get()
                    if container and not container["has a Snack"] then
                        emptySlots = emptySlots + 1
                    end
                end)
            end

            -- Accumulate purchase cost for this pack
            if CONFIG.deductCost and emptySlots > 0 then
                local salePrice = getSnackSalePrice(pack)
                
                local ok, stockPriceOff = pcall(function() return pack["Stock Price Off"] end)
                stockPriceOff = ok and stockPriceOff or 0.25
                
                local buyPrice = salePrice * stockPriceOff
                if buyPrice > 0 then
                    shelfCost = shelfCost + math.floor(buyPrice * emptySlots * 100)
                end
            end

            -- Build save struct and fill to full capacity.
            local savePack = {}
            local saved = false
            pcall(function() 
                pack["Return Snack Base Save Struct"](savePack)
                saved = true
            end)
            
            if saved and totalSlots > 0 then
                savePack[SNACK_COUNT_KEY] = totalSlots
                pcall(function() pack["Spawn and Fill Snack"](savePack) end)
            end
        end)
    end)

    return shelfCost
end

-- ============================================================
-- RESTOCK: Iterate all shelves and fridges
-- ============================================================
local function restockAllShelves()
    local shelves = FindAllOf("SnackShelf_C")
    if not shelves or #shelves == 0 then
        log("No shelves found")
        return
    end

    log("Restocking " .. #shelves .. " shelves...")

    local totalCost = 0
    for _, shelf in ipairs(shelves) do
        if shelf:IsValid() then
            local cost = safe("restockShelf", restockShelf, shelf)
            if type(cost) == "number" then
                totalCost = totalCost + cost
            end
        end
    end

    if CONFIG.deductCost and totalCost > 0 then
        deductMoney(totalCost)
        log("Total restock cost: $" .. string.format("%.2f", totalCost / 100))
    end

    log("Shelf restock complete!")
end

-- ============================================================
-- RESTOCK: Refill all candy dispensers
-- ============================================================
local function restockCandyDispensers()
    local dispensers = FindAllOf("CandyDispense_01_C")
    if not dispensers or #dispensers == 0 then
        debug("No candy dispensers found")
        return
    end

    log("Restocking " .. #dispensers .. " candy dispenser(s)...")

    local count = 0
    for _, dispenser in ipairs(dispensers) do
        if dispenser:IsValid() then
            local ok = safe("Refill by Player", function()
                dispenser["Refill by Player"]()
                return true
            end)
            if ok then count = count + 1 end
        end
    end

    log(count .. " candy dispenser(s) refilled!")
end

-- ============================================================
-- RESTOCK: Run all restock routines in sequence.
-- ============================================================
local function restockAll()
    restockAllShelves()
    if CONFIG.restockCandy then
        restockCandyDispensers()
    end
end

-- ============================================================
-- HELPER: Reset per-day state
-- ============================================================
local function resetTrackers()
    lastRestockHour = -1
    openedAtHour    = -1
    cachedGamemode  = nil
end

-- ============================================================
-- HOOK REGISTRATION
-- ============================================================

ExecuteWithDelay(3000, function()

    registerHookOptional(
        "/Game/VideoStore/asset/prop/opensign/OpenSign.OpenSign_C:Change Sign",
        function(self)
            safe("OpenSign Change Sign", function()
                local sign = self:get()
                if not sign["is Open"] then return end

                local hour = -1
                local ws = FindAllOf("WeatherSystem_C")
                if ws and ws[1] then hour = ws[1]["Hour"] end

                if openedAtHour == hour then return end
                openedAtHour = hour
                lastRestockHour = hour
                log("Store opened at " .. tostring(hour) .. ":00 - restocking...")
                restockAll()
            end)
        end
    )

    registerHookOptional(
        "/Game/VideoStore/asset/outside/WeatherSystem.WeatherSystem_C:Timer Event - Add one minute",
        function(self)
            safe("Weather timer", function()
                local ws = self:get()
                local hour = ws["Hour"]
                local minute = ws["Minute"]

                -- Additional configured restock hours
                if restockHourSet[hour]
                    and minute == 0
                    and lastRestockHour ~= hour
                    and hour > openedAtHour
                    and openedAtHour ~= -1 then

                    lastRestockHour = hour
                    log("Scheduled restock at " .. tostring(hour) .. ":00...")
                    restockAll()
                end
            end)
        end
    )

    registerHookOptional(
        "/Game/VideoStore/asset/outside/WeatherSystem.WeatherSystem_C:ReceiveBeginPlay",
        function()
            resetTrackers()
            debug("Save reloaded - trackers reset")
        end
    )

    registerHookOptional(
        "/Game/VideoStore/core/gamemode/Core_Gamemode.Core_Gamemode_C:End of the day",
        function()
            resetTrackers()
            debug("Day ended - trackers reset")
        end
    )

    log("Auto Restock Snacks - QoL active")
end)

-- ============================================================
log("Auto Restock Snacks - QoL loaded.")