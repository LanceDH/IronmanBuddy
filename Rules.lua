local _addonName, _addon = ...;

IMB_FLAG_WARNING = 0;
IMB_FLAG_YELLOW = 1;
IMB_FLAG_RED = 2;

IMB_TYPE_IRON = 1;
IMB_TYPE_TIN = 2;
IMB_TYPE_GREEN = 3;

local playerClassID = select(3, UnitClass("player"));
local _secodaryProfessions = {[PROFESSIONS_FISHING] = true, [PROFESSIONS_COOKING] = true, [PROFESSIONS_ARCHAEOLOGY] = true};
-- /run for k, v in pairs(C_TradeSkillUI.GetAllProfessionTradeSkillLines()) do print(v, C_TradeSkillUI.GetTradeSkillDisplayName(v)) end
local _primProfessionIDs = {186, 197, 202, 333, 393, 164, 165, 171, 182, 755, 773};
local _primaryProfessions = {};
for k, id in ipairs(_primProfessionIDs) do
	_primaryProfessions[C_TradeSkillUI.GetTradeSkillDisplayName(id)] = true;
end

local L = {};
L["QUALITY_WHITE"] = "Don't equip gear higher than white quality";
L["IRON_NO_ELIXIR"] = "No elixirs, potions, flasks, or healthstones for non-warlocks.";
L["TIN_NO_ELIXIR"] = "No elixirs or flasks.";
L["ENCHANTS"] = "Don't enchant your gear."
L["SCOPE"] = "Weapon scopes are not allowed as they are enchents. It's impossible to detect the difference between an explosive and a scope.";
L["NOTALENTS"] = "Talents are not allowed."
L["QUALITY_GREEN"] = "Don't equip gear higher than green quality";
L["PRIMARY_PROFESSION"] = "No primary professions are allowed";
L["SECONDARY_PROFESSION"] = "No secondary professions allowed";
L["PvEPvP"] = "No dungeons, raids, arenas, or battlegrounds allowed.";
L["FOODBUFF"] = "Food buffs are not allowed. If this food provides a buff, remove it once it is applied.";

local function BlockTrainer(professionType, flag, reason)
	if (IsTradeskillTrainer()) then
		local matchType = false;
		local skillName = "";
		for i=1, CLASS_TRAINER_SKILLS_DISPLAYED do 
			skillName = GetTrainerServiceSkillReq(i)
			if (skillName and ((professionType == 1 and _primaryProfessions[skillName]) or (professionType == 2 and _secodaryProfessions[skillName]))) then
				matchType = true;
				break;
			end
		end
		
		if (matchType) then
			_addon.IMB:BlockFrame(ClassTrainerFrameSkillStepButton, flag, reason);
			for i=1, CLASS_TRAINER_SKILLS_DISPLAYED do 
				local button = _G["ClassTrainerScrollFrameButton"..i];
				_addon.IMB:BlockFrame(button, flag, reason);
			end
		end
	end
end

local function MaxEquipQuality(itemID, maxQuality) 
	local _, _, quality, _, _, itemType, itemSubType, _, _, _, _, itemClassID = GetItemInfo(itemID);
	-- weapon == 2, armor == 4
	local isEquipment = itemClassID == 2 or itemClassID == 4
	return not quality or not isEquipment or quality <= maxQuality;
end

local function BannedItemTypes(itemID, bannedTypes, noHealtstones)
	local _, _, _, _, _, itemType, itemSubType, _, _, _, _, itemClassID, itemSubClassID = GetItemInfo(itemID);
	
	--print("\/", itemType, itemSubType, itemClassID, itemSubClassID)
	if (bannedTypes[itemClassID] and (bannedTypes[itemClassID][-1] or bannedTypes[itemClassID][itemSubClassID])) then
		return false;
	elseif (noHealtstones and itemID == 5512 and playerClassID ~= 9) then
		-- No healthstones for non-warlocks
		return false;
	end
	return true;
end

local NoTalents = {
	["Blizzard_TalentUI"] = {
		-- Highlight talent buttons
		{["func"] = function()
				for i=1, MAX_TALENT_TIERS do
					local tier = PlayerTalentFrameTalents["tier"..i];
					if (tier and tier.talents) then
						for i, button in ipairs(tier.talents) do
							_addon.IMB:BlockFrame(button, IMB_FLAG_RED, L["NOTALENTS"]);
						end
					end
				end
			end}
		-- Add text to talent tooltips
		,{["hook"] = "PlayerTalentFrameTalent_OnEnter", ["func"] = function()
				local text, color = _addon.IMB:GetFlagInfo(IMB_FLAG_RED)
				GameTooltip:AddLine(" ")
				GameTooltip:AddLine(text, color:GetRGB());
				GameTooltip:AddLine(L["NOTALENTS"], color:GetRGB());
				GameTooltip:Show();
			end}
	}
}

local PrimairyProfessions = {
	["Default"] = {
		-- Spellbook highlights
		{["func"] = function()
				for i=1, 2 do
					local prim = _G["PrimaryProfession"..i];
					if prim then
						_addon.IMB:BlockFrame(prim, IMB_FLAG_RED, L["PRIMARY_PROFESSION"]);
					end
				end
			end}
	}
	,["Blizzard_TrainerUI"] = {
		-- Skill trainer
		{["hook"] = "ClassTrainerFrame_Update", ["func"] = function()
				BlockTrainer(1, IMB_FLAG_RED, L["PRIMARY_PROFESSION"]);
			end}
	}
}

local SecondaryProfession = {
	["Default"] = {
		-- Spellbook highlights
		{["func"] = function()
				for i=1, 3 do
					local sec = _G["SecondaryProfession"..i];
					if sec then
						_addon.IMB:BlockFrame(sec, IMB_FLAG_YELLOW, L["SECONDARY_PROFESSION"]);
					end
				end
			end}
			
	}
	,["Blizzard_TrainerUI"] = {
		-- Skill trainer
		{["hook"] = "ClassTrainerFrame_Update", ["func"] = function()
				BlockTrainer(2, IMB_FLAG_YELLOW, L["SECONDARY_PROFESSION"]);
			end}
	}
}

local PvEPvP = 
{
	["Default"] = {
		-- PvE queues
		{["func"] = function()
				for i=1, 4 do
					local frame = _G["GroupFinderFrameGroupButton"..i];
					if frame then
						_addon.IMB:BlockFrame(frame, IMB_FLAG_RED, L["PvEPvP"]);
					end
				end
			end}
	}
	,["Blizzard_PVPUI"] = {
		-- PVP queues
		{["func"] = function()
				for i=1, 3 do
					local frame = _G["PVPQueueFrameCategoryButton"..i];
					if frame then
						_addon.IMB:BlockFrame(frame, IMB_FLAG_RED, L["PvEPvP"]);
					end
				end
			end}
	}
}


local ConsumablesIron = 
{
	[0] = {			-- Consumables
		[1] = true		-- Potions
		,[2] = true		-- Elixirs
		,[3] = true		-- Flasks
	}
}
local EnchantsIron = 
{
	[8] = {		-- Enchants
		[-1] = true		-- All
	}
}
local ironmanItemTypesWarning = 
{
	[0] = { -- Consumables
		[0] = true -- Explosives and Devices -> Could be scope (item enchant)
	}
}

local tinmanItemTypes = 
{
	[0] = {[2] = true, [3] = true}
}

local FoodBuff =
{
	[0] = { 
		[5] = true;
	}
}

-----------------------
-- Modes
-----------------------
_addon.modes = {};

_addon.modes["iron"] = {
	["mode"] = IMB_TYPE_IRON
	,["itemConditions"] = {
		-- Nothing above white
		{["func"] = function(self, itemID) return MaxEquipQuality(itemID, LE_WORLD_QUEST_QUALITY_COMMON) end, ["flag"] = IMB_FLAG_RED, ["rule"] = L["QUALITY_WHITE"]}
		-- No flasks/elixirs/potions
		,{["func"] = function(self, itemID) return BannedItemTypes(itemID, ConsumablesIron, true) end, ["flag"] = IMB_FLAG_YELLOW, ["rule"] = L["IRON_NO_ELIXIR"]}
		-- No enchanting
		,{["func"] = function(self, itemID) return BannedItemTypes(itemID, EnchantsIron, true) end, ["flag"] = IMB_FLAG_RED, ["rule"] = L["ENCHANTS"]}
		-- Warning because scopes (enchant) share type with bombs
		,{["func"] = function(self, itemID) return BannedItemTypes(itemID, ironmanItemTypesWarning, false) end, ["flag"] = IMB_FLAG_WARNING, ["rule"] = L["SCOPE"]}
		-- Warning on food because food buffs
		,{["func"] = function(self, itemID) return BannedItemTypes(itemID, FoodBuff, false) end, ["flag"] = IMB_FLAG_WARNING, ["rule"] = L["FOODBUFF"]}
	}
	,["general"] = {
		NoTalents
		,PrimairyProfessions
		,SecondaryProfession
		,PvEPvP
	}
}

_addon.modes["tin"] = {
	["mode"] = IMB_TYPE_TIN
	,["itemConditions"] = {
		{["func"] = function(self, itemID) return MaxEquipQuality(itemID, LE_WORLD_QUEST_QUALITY_COMMON) end, ["flag"] = IMB_FLAG_RED, ["rule"] = L["QUALITY_WHITE"]}
		,{["func"] = function(self, itemID) return BannedItemTypes(itemID, tinmanItemTypes, false) end, ["flag"] = IMB_FLAG_RED, ["rule"] = L["TIN_NO_ELIXIR"]}
	}
}

_addon.modes["green"] = {
	["mode"] = IMB_TYPE_GREEN
	,["itemConditions"] = {
		{["func"] = function(self, itemID) return MaxEquipQuality(itemID, LE_WORLD_QUEST_QUALITY_RARE) end, ["flag"] = IMB_FLAG_RED, ["rule"] = L["QUALITY_GREEN"]}
		,{["func"] = function(self, itemID) return BannedItemTypes(itemID, ConsumablesIron, true) end, ["flag"] = IMB_FLAG_RED, ["rule"] = L["IRON_NO_ELIXIR"]}
	}
}

