local __version__ = "0.01f"
-------------------------------------------------------------------------------
local function HasBuff(texture_name)
  for i=1, 32 do
    local texture = UnitBuff("player", i)
    if texture and string.find(texture, texture_name) then
      return true
    end
  end
  return false
end
local function ItemCount(search_name)
  local search_count = 0
  for bag_idx = 0, NUM_BAG_SLOTS do
    for slot_idx = 0, GetContainerNumSlots(bag_idx) do
      local item_link = GetContainerItemLink(bag_idx, slot_idx)
      if item_link and string.find(item_link, search_name) then
        local item_texture, item_slot_count = GetContainerItemInfo(bag_idx, slot_idx)
        search_count = search_count + item_slot_count
      end
    end
  end
  return search_count
end
local function UseItem(item_name)
  local function GetFirstItem(search_name)
    for bag_idx = 0, NUM_BAG_SLOTS do
      for slot_idx = 0, GetContainerNumSlots(bag_idx) do
        local item_link = GetContainerItemLink(bag_idx, slot_idx)
        if item_link and string.find(item_link, search_name) then
          return bag_idx, slot_idx
        end
      end
    end
    return nil, nil
  end
  
  local bag_idx, slot_idx = GetFirstItem(item_name)
  if bag_idx == nil then
    return false
  end
    
  UseContainerItem(bag_idx, slot_idx)
  return true
end
-------------------------------------------------------------------------------
local function setup(settings, defaults)
  if not ConjurerFrame then
    ConjurerFrame = CreateFrame("Frame", "Conjurer") 
  end

  ConjurerFrame:SetScript("OnEvent", OnError)
  ConjurerFrame:RegisterEvent("UI_ERROR_MESSAGE")
  
  defaults = defaults or {}
  defaults.water_rank        = defaults.water_rank        or 7
  defaults.water_amount      = defaults.water_amount      or 10*20
  defaults.food_rank         = defaults.food_rank         or 6
  defaults.food_amount       = defaults.food_amount       or 10*20
  defaults.regeneration_rank = defaults.regeneration_rank or 7
  defaults.outofmana_margin  = defaults.outofmana_margin  or 20
  
  settings = settings or {}
  return {
    water_rank        = settings.water_rank        or defaults.water_rank;
    water_amount      = settings.water_amount      or defaults.water_amount;
    food_rank         = settings.food_rank         or defaults.food_rank;
    food_amount       = settings.food_amount       or defaults.food_amount;
    regeneration_rank = settings.regeneration_rank or defaults.regeneration_rank;
    outofmana_margin  = settings.outofmana_margin  or defaults.outofmana_margin;  
  }
end
local function reset()
  if not ConjurerFrame then return end

  ConjurerFrame:SetScript("OnEvent", nil)
  ConjurerFrame:UnregisterEvent("UI_ERROR_MESSAGE")
end
-------------------------------------------------------------------------------
local ShowErrors = 0
local function disableErrorWarnings()
  ShowErrors = GetCVar("ShowErrors")
  SetCVar("ShowErrors", 0)
  UIErrorsFrame:UnregisterEvent("UI_ERROR_MESSAGE")
end
local function restoreErrorWarnings()
  SetCVar("ShowErrors", ShowErrors)
  UIErrorsFrame:RegisterEvent("UI_ERROR_MESSAGE")
end
-------------------------------------------------------------------------------
local errors = {}
local NEED_TO_BE_STANDING = "You must be standing to do that";
local NOT_ENOUGH_MANA = "Not enough mana"

function HasError(const_error)
  for n, item in errors do
    if item == const_error then
      return n
    end
  end
  return -1
end

function OnError()
  if arg1 == NEED_TO_BE_STANDING then
    if HasError(NEED_TO_BE_STANDING) < 0 then
      table.insert(errors, NEED_TO_BE_STANDING)
    end
  end
end

function ResolveError(const_error)
  n = HasError(const_error)
  if n >= 0 then table.remove(errors, n) end
end
-------------------------------------------------------------------------------
local conjuringspell = {
  [1] = { food = "Muffin";        water = "Water";            cost = 60; };
  [2] = { food = "Bread";         water = "Fresh Water";      cost = 105; };
  [3] = { food = "Rye";           water = "Purified Water";   cost = 180; };
  [4] = { food = "Pumpernickel";  water = "Spring Water";     cost = 285; };
  [5] = { food = "Sourdough";     water = "Mineral Water";    cost = 420; };
  [6] = { food = "Sweet Roll";    water = "Sparkling Water";  cost = 585; };
  [7] = { food = "Cinnamon Roll"; water = "Crystal Water";    cost = 705; };
  lookup = function(self, context, rank)
    return {
      spellname = 'Conjure '..context..'(Rank ' .. rank .. ')';
      itemname = 'Conjured ' .. self[rank][strlower(context)];
      spellcost = self[rank].cost;
    }
  end;
}
-------------------------------------------------------------------------------
local function LowStockOrdered(conjureables)
  for n, conjureable in conjureables do
    if ItemCount(conjureable.itemname) < conjureable.amount then
      return conjureable
    end
  end
  return nil
end
--= Actual Macro Function to be called =---------------------------------------
function Conjure_Click(settings)
  reset()
  local settings = setup(settings, {
    water_rank        = 7;
    water_amount      = 10*20;
    food_rank         = 6;
    food_amount       = 10*20;
    regeneration_rank = 7;
    outofmana_margin  = 20;
  })

  local food = conjuringspell:lookup("Food", settings.food_rank)
        food.amount = settings.food_amount
  local water = conjuringspell:lookup("Water", settings.water_rank)
        water.amount = settings.water_amount
  local drink = conjuringspell:lookup("Water", settings.regeneration_rank)
        drink.outofmana_margin = settings.outofmana_margin

  local conjureable = LowStockOrdered({water, food})
  if not conjureable then return true end

  disableErrorWarnings()
  if HasError(NEED_TO_BE_STANDING) >= 0 then
    DoEmote("Stand")
    ResolveError(NEED_TO_BE_STANDING)
  elseif not HasBuff('Drink') then
    if UnitMana('player') <= conjureable.spellcost+drink.outofmana_margin then
      UseItem(drink.itemname)
    else
      CastSpellByName(conjureable.spellname)
    end
  end
  restoreErrorWarnings()
end
