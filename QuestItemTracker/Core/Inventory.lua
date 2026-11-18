-- QITF / Core/Inventory.lua: owns core responsibilities.
local addonName, NS = ...
assert(type(NS) == "table", "QIT requires WoW's addon namespace")
local S = assert(NS.state, "QIT Core/History.lua must load first")
local api = assert(NS.api)
local SafeCall = assert(api.SafeCall, "QIT load order: SafeCall")

local function GetItemIDFromLink(link)
    if type(link) ~= "string" then return nil end
    local id = string.match(link, "item:(%d+)")
    return id and tonumber(id) or nil
end

local function GetItemName(itemID, tooltipName)
    if type(tooltipName) == "string" and tooltipName ~= "" then return tooltipName end
    local name = SafeCall(C_Item and C_Item.GetItemName, itemID)
    if type(name) == "string" and name ~= "" then return name end
    name = SafeCall(GetItemInfo, itemID)
    return name or ("Item " .. tostring(itemID))
end

local function IsBankOpen()
    if BankFrame and type(BankFrame.IsShown) == "function" then
        return BankFrame:IsShown()
    end
    return false
end

local function CountItemInContainer(itemID, bagID)
    if not C_Container or type(C_Container.GetContainerNumSlots) ~= "function"
        or type(C_Container.GetContainerItemID) ~= "function" then
        return 0
    end
    local total = 0
    local slots = SafeCall(C_Container.GetContainerNumSlots, bagID) or 0
    for slot = 1, slots do
        local slotItemID = SafeCall(C_Container.GetContainerItemID, bagID, slot)
        if tonumber(slotItemID) == tonumber(itemID) then
            local info = SafeCall(C_Container.GetContainerItemInfo, bagID, slot)
            total = total + (info and tonumber(info.stackCount) or 1)
        end
    end
    return total
end

local function CountItemInventory(itemID)
    local bags, bank = 0, 0
    if not C_Container then return bags, bank end

    for bag = 0, (NUM_BAG_SLOTS or 4) do
        bags = bags + CountItemInContainer(itemID, bag)
    end

    -- The personal bank is only readable while the bank window is open.
    -- Classic/Forever uses container -1 for the main bank and bag IDs after
    -- the player's normal bags for purchased bank bags.
    if IsBankOpen() then
        bank = bank + CountItemInContainer(itemID, BANK_CONTAINER or -1)
        local firstBankBag = (NUM_BAG_SLOTS or 4) + 1
        local bankBagCount = NUM_BANKBAGSLOTS or 7
        for bag = firstBankBag, firstBankBag + bankBagCount - 1 do
            bank = bank + CountItemInContainer(itemID, bag)
        end
    end
    return bags, bank
end

api.GetItemIDFromLink = GetItemIDFromLink
api.GetItemName = GetItemName
api.IsBankOpen = IsBankOpen
api.CountItemInventory = CountItemInventory
