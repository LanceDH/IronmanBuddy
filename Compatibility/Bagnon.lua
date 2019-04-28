local _addonName, _addon = ...;

if (IsAddOnLoaded("Bagnon")) then
	hooksecurefunc(Bagnon.ItemSlot, "Update", function(itemButton) 
		if (not _addon.IMB:UpdateItemButton(itemButton, itemButton.info and itemButton.info.id)) then
			itemButton.IconGlow:SetAlpha(0);
		end

	end)
end

