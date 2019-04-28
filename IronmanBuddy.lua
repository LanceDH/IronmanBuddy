local _addonName, _addon = ...;

local IMB = LibStub("AceAddon-3.0"):NewAddon("IronmanBuddy");
_addon.IMB = IMB;

local _rules = _addon.modes.iron;

local _blockerPoolItem = CreateFramePool("FRAME", nil, "IMB_ItemBlockerTemplate");
local _blockerPoolFrame = CreateFramePool("FRAME", nil, "IMB_FrameBlockerTemplate");
local _colorRed = CreateColor(1, 0, 0);
local _colorYellow = CreateColor(.8, .8, 0);
local _colorCyan = CreateColor(0, .8, .8);

function IMB:GetModeInfo(mode)
	if (mode == IMB_TYPE_IRON) then return "Ironman" end;
	if (mode == IMB_TYPE_TIN) then return "Tinman" end;
	if (mode == IMB_TYPE_GREEN) then return "Greenman" end;
	return "Unknown mode";
end

function IMB:GetFlagInfo(flagID)
	if (flagID == IMB_FLAG_RED) then return "Red Flag", _colorRed end;
	if (flagID == IMB_FLAG_YELLOW) then return "Yellow Flag", _colorYellow end;
	if (flagID == IMB_FLAG_WARNING) then return "Warning", _colorCyan end;
	return "", _colorRed;
end

local function PassesItemConditions(itemID, out_rules)
	local success = true;
	local maxFlag = 0;
	itemID = tonumber(itemID);
	
	if (itemID) then
		for k, condition in ipairs(_rules.itemConditions) do
			if (not condition:func(itemID)) then 
				maxFlag = condition.flag > maxFlag and condition.flag or maxFlag;
				tinsert(out_rules, condition.rule);
				success = false
			end
		end
	end
	return success, maxFlag;
end

local function checkPass(itemID)
	if itemID then
		local reasons = {};
		local name = GetItemInfo(itemID);
		local pass, flag = PassesItemConditions(itemID, reasons);
		
		if not pass then
			local reasonString = reasons[1];
			for i = 2, #reasons do
				reasonString = reasonString .. " " .. reasons[i];
			end
			print(name, flag, reasonString);
		else
			print(name, "passed");
		end
	end
end

local function slashcmd(msg, editbox)
	local itemID = tonumber(msg);
	if (itemID) then
		local name, _, _, _, _, itemType, itemSubType, _, _, _, _, itemClassID, itemSubClassID = GetItemInfo(itemID);
		if (name) then
			print(string.format("%s: %s (%d) | %s (%d)",name, itemType, itemClassID, itemSubType, itemSubClassID));
			checkPass(itemID);
		end
		
		return;
	end
		
	if(msg == "iron" or msg == "tin" or msg == "green") then
		print("Switched to", msg);
		if (msg == "iron") then
			_rules = _addon.modes.iron;
		elseif (msg == "tin") then
			_rules = _addon.modes.tin;
		elseif (msg == "green") then
			_rules = _addon.modes.green;
		end
	end
end

local function RunRuleActions(actions)
	for k, action in ipairs(actions) do
		if (action.hook) then
			hooksecurefunc(action.hook, action.func);
		else
			action:func();
		end
	end
end

IMB.events = CreateFrame("FRAME", "IMB_EventFrame"); 
IMB.events:RegisterEvent("GET_ITEM_INFO_RECEIVED");
IMB.events:RegisterEvent("PLAYER_TARGET_CHANGED");
IMB.events:RegisterEvent("CHAT_MSG_ADDON");
IMB.events:RegisterEvent("ADDON_LOADED");
IMB.events:SetScript("OnEvent", function(self, event, ...) self[event](self, ...) end)

function IMB.events:CHAT_MSG_ADDON(prefix, msg, channel, sender)
	if (prefix == _addonName) then
		if (msg == "TELLME") then
			C_ChatInfo.SendAddonMessage(_addonName, _rules.mode, "WHISPER", sender);
		else
			print(IMB:GetModeInfo(tonumber(msg)));
		end
	end
end

function IMB.events:PLAYER_TARGET_CHANGED()
	if (not UnitIsPlayer("target")) then return end;
	
	local name, realm = UnitName("target");
	name = realm and name.."-"..realm or name;
	if (name) then
		C_ChatInfo.SendAddonMessage(_addonName, "TELLME", "WHISPER", name);
	end
end

function IMB.events:GET_ITEM_INFO_RECEIVED(itemID, success)
	if (success) then
		local name, _, _, _, _, itemType, itemSubType, _, _, _, _, itemClassID, itemSubClassID = GetItemInfo(itemID);
		print(string.format("%s: %s (%d) | %s (%d)",name, itemType, itemClassID, itemSubType, itemSubClassID));
		checkPass(itemID);
	elseif (itemID > 0) then
		print("Invalid itemID: " .. itemID);
	end
end

function IMB.events:ADDON_LOADED(loadedAddon)
	print(loadedAddon);
	if (loadedAddon == "Blizzard_AuctionUI") then
		hooksecurefunc("AuctionFrameBrowse_Update", function() 
			local offset = FauxScrollFrame_GetOffset(BrowseScrollFrame);
			for i=1, NUM_BROWSE_TO_DISPLAY do
				local _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, itemID =  GetAuctionItemInfo("list", offset + i);
			
				local itemButton = _G["BrowseButton"..i.."Item"];
				
				IMB:UpdateItemButton(itemButton, itemID);
			end
		end);
	end
	
	-- Check for addon related rules
	for k, rule in ipairs(_rules.general) do
		if (rule[loadedAddon]) then
			RunRuleActions(rule[loadedAddon]);
		end
	end
end

function IMB:BlockFrame(frame, flag, rule, skipHook)
	if (not frame) then return; end

	local blocker = frame.ImbBlocker;
	if (not blocker) then 
		blocker = _blockerPoolFrame:Acquire();
		frame.ImbBlocker = blocker;
		blocker:Show();
	end
	blocker:SetFrameLevel(frame:GetFrameLevel() + 1);
	blocker:SetParent(frame);
	blocker:SetAllPoints();
	
	if (not frame.IMBrules) then
		frame.IMBrules = {};
	end
	wipe(frame.IMBrules);
	tinsert(frame.IMBrules, rule);
	
	local flagString, color = IMB:GetFlagInfo(flag);
	blocker.flagString = flagString;
	blocker.Flag.Icon:SetVertexColor(color:GetRGB());
	for k, part in ipairs(blocker.highlightParts) do
		part:SetVertexColor(color:GetRGB());
	end
end

function IMB:UpdateItemButton(itemButton, itemID)
    if not itemButton:GetName() then
		return true;
	end

	itemButton.IconBorder:SetAlpha(1);
	
	if (itemButton.ImbBlocker) then
		_blockerPoolItem:Release(itemButton.ImbBlocker);
		itemButton.ImbBlocker.reasons = nil;
		itemButton.ImbBlocker.flagString = nil;
		itemButton.ImbBlocker = nil;
	end

	if (not itemID or type(itemID) ~= "number") then
		return true;
	end

	if (not itemButton.IMBrules) then
		itemButton.IMBrules = {};
	end
	wipe(itemButton.IMBrules);

	local iconTexture = _G[itemButton:GetName().."IconTexture"];

	local name = GetItemInfo(itemID);
	local pass, flag = PassesItemConditions(itemID, itemButton.IMBrules);
	local isWarning = flag == 0;
	iconTexture:SetDesaturated(not pass and not isWarning);

	if not pass then
		local blocker = itemButton.ImbBlocker;
		if (not blocker) then
			blocker = _blockerPoolItem:Acquire();
			blocker:SetParent(itemButton);
			blocker:SetFrameLevel(itemButton:GetFrameLevel() + 1);
			blocker:SetAllPoints();
			blocker:Show();
			itemButton.ImbBlocker = blocker;
		end
		
		--CopyTableToTable()
		--local reasons = itemButton.IMBrules[1];
		--for i = 2, #itemButton.IMBrules do
		--	reasons = reasons .. " " .. itemButton.IMBrules[i];
		--end
		-- = reasons;
		local flagString, color = IMB:GetFlagInfo(flag);
		blocker.flagString = flagString;
		blocker.Flag.Icon:SetVertexColor(color:GetRGB());
		
		blocker.Highlight:SetVertexColor(color:GetRGB());
		itemButton.IconBorder:SetAlpha(0);
	end
	
	return pass;
end

function IMB:OnEnable()
	SLASH_IMBSLASH1 = '/imb';
	SlashCmdList["IMBSLASH"] = slashcmd

	C_ChatInfo.RegisterAddonMessagePrefix(_addonName)
	
	
	for k, rule in ipairs(_rules.general) do
		if (rule["Default"]) then
			RunRuleActions(rule["Default"]);
		end
	end
	
	-----------------------
	-- Item management
	-----------------------
	hooksecurefunc("ContainerFrame_Update", function(container) 
			local id = container:GetID();
			local name = container:GetName();
			
			for i=1, container.size, 1 do
				local itemButton = _G[name.."Item"..i];
				local _, _, _, _, _, _, _, _, _, itemID = GetContainerItemInfo(id, itemButton:GetID());
			
				IMB:UpdateItemButton(itemButton, itemID)
			end
		end);
	
	hooksecurefunc("PaperDollItemSlotButton_Update", function(itemButton) 
			local itemID = GetInventoryItemID("player", itemButton:GetID());
			IMB:UpdateItemButton(itemButton, itemID);
		end);
	
	hooksecurefunc("BankFrameItemButton_Update", function(itemButton) 
			local container = itemButton:GetParent():GetID();
			local _, _, _, _, _, _, _, _, _, itemID = GetContainerItemInfo(container, itemButton:GetID());
			
			IMB:UpdateItemButton(itemButton, itemID)
		end);
		
end

local function AddTooltipLine(tooltip)
	local name, itemLink = tooltip:GetItem();
	-- If the tooltip doesn't have an itemLink, don't continue
	if (not itemLink) then return; end
	
	local reasons = {};
	local itemID = tonumber(string.match(itemLink, "Hitem:(%d+)"));
	local pass, flag = PassesItemConditions(itemID, reasons);
	
	if (not pass) then
		local flagString, color = IMB:GetFlagInfo(flag);
		tooltip:AddDoubleLine(" ", " ");
		tooltip:AddLine(flagString, color:GetRGB());
		for k, reason in ipairs(reasons) do
			tooltip:AddLine(reason, color.r, color.g, color.b, true);
		end
	end
	
end

GameTooltip:HookScript("OnTooltipSetItem", AddTooltipLine);
hooksecurefunc(GameTooltip, "SetHyperlink", AddTooltipLine);
ItemRefTooltip:HookScript("OnTooltipSetItem", AddTooltipLine);
ShoppingTooltip1:HookScript("OnTooltipSetItem", AddTooltipLine);
WorldMapTooltip.ItemTooltip.Tooltip:HookScript('OnTooltipSetItem', AddTooltipLine);