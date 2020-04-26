local _, ItemProfConstants = ...

local frame = CreateFrame( "Frame" )

local previousItemID = -1
local itemIcons = ""
local iconSize

local loot_status_name = {[0]="passen", [1]="Bedarf", [2]="Gier"}

local ITEM_VENDOR_FLAG = ItemProfConstants.VENDOR_ITEM_FLAG
local ITEM_DMF_FLAG = ItemProfConstants.DMF_ITEM_FLAG


local ITEM_PROF_FLAGS2 = ItemProfConstants.ITEM_PROF_FLAGS2
local QUEST_FLAG = ItemProfConstants.QUEST_FLAG
local NUM_PROFS_TRACKED = ItemProfConstants.NUM_PROF_FLAGS
local PROF_TEXTURES = ItemProfConstants.PROF_TEXTURES

local showProfs
local showQuests
local profFilter
local questFilter
local includeVendor
local showDMF

ItemProfConstants.configTooltipIconsRealm = GetRealmName()
ItemProfConstants.configTooltipIconsChar = UnitName( "player" )

local LibDeflate = LibStub:GetLibrary("LibDeflate")

-- Create ThreatLib as an AceAddon
local FdH = LibStub("AceAddon-3.0"):GetAddon("FdH", true) or LibStub("AceAddon-3.0"):NewAddon("FdH")
-- embedd mixin libraries
LibStub("AceAddon-3.0"):EmbedLibraries(FdH,
	"AceComm-3.0",
	"AceSerializer-3.0"
)
local AceGUI = LibStub("AceGUI-3.0")



local function ModifyItemTooltip( tt ) 
		
	local itemName, itemLink = tt:GetItem() 
	if not itemName then return end
	local itemID = select( 1, GetItemInfoInstant( itemName ) )
	
	if itemID == nil then
		-- Extract ID from link: GetItemInfoInstant unreliable with AH items (uncached on client?)
		itemID = tonumber( string.match( itemLink, "item:?(%d+):" ) )
		if itemID == nil then
			-- The item link doesn't contain the item ID field
			return
		end
	end
	
	-- Reuse the texture state if the item hasn't changed
	if previousItemID == itemID then
		tt:AddLine( itemIcons )
		return
	end
	
	-- Check if the item is a profession reagent
	local itemNeed = ITEM_PROF_FLAGS[ itemID ]
	if itemNeed == nil then
		-- Don't modify the tooltip
		return
	end
	
	-- Convert the flags into texture icons
	previousItemID = itemID
	itemIcons = "Gewünscht von: " .. itemNeed
	
	tt:AddLine( itemIcons )
end


function ItemProfConstants:ConfigChanged()


	previousItemID = -1		-- Reset line
end

function ResetFearLoot()
	rolls = {};
	party_member = 20;
	loot_counter = 0;
	has_loot = 0;
	loot_round = 1;
	has_won = 0;
end


function FdH:OnCommReceived(prefix, message, distribution, sender)
	ctext = LibDeflate:DecodeForWoWAddonChannel(message)
	text = LibDeflate:DecompressDeflate(ctext)

	b,a = FdH:Deserialize(text);
	print(a["v"])
	print(ITEM_PROF_FLAGS["v"])
	if a["v"] > ITEM_PROF_FLAGS["v"] then
		print("Neue Version entdeckt. Erhalte version: " .. a["v"])
		ITEM_PROF_FLAGS = a
	end
end



local function Addon_OnEvent(self, event, prefix, ...)
	if event == "CHAT_MSG_ADDON" and prefix == AddonPrefix then
		New_Message(...);
	elseif event == "PLAYER_LOGIN" then
		print("Player login hook")
		local successfulRequest = C_ChatInfo.RegisterAddonMessagePrefix(AddonPrefix)	
	elseif event == "PLAYER_ENTERING_WORLD" then
		if ITEM_PROF_FLAGS == nil or type( ITEM_PROF_FLAGS["v"] ) == "number" or ItemProfConstants.ITEM_PROF_FLAGS["v"] > ITEM_PROF_FLAGS["v"] then
			print("copy installed to cache")
			ITEM_PROF_FLAGS = ItemProfConstants.ITEM_PROF_FLAGS
		end
		FdH:SendMsg(ITEM_PROF_FLAGS)

		if loot_counter == nil then
			ResetFearLoot();
			Round_Lood_All = 0;
			Crap_Roll_Stat = 0;
		end
	elseif event == "START_LOOT_ROLL" then
		local texture, name, count, quality, bindOnPickUp, canNeed, canGreed, canDisenchant, reasonNeed, reasonGreed, reasonDisenchant, deSkillRequired = GetLootRollItemInfo(prefix);
		print(name..quality);
		local itemID, itemType, itemSubType, itemEquipLoc, icon, itemClassID, itemSubClassID = GetItemInfoInstant(GetLootRollItemLink(prefix));

		print(itemID.." "..name.. GetLootRollItemLink(prefix))
		if (itemID > 19698 and itemID < 19706) or Round_Lood_All == 1 then

			rolls[prefix] = 1;
			loot_counter = loot_counter +1;
			party_member = GetNumGroupMembers();
			print("vor würfeln. has_loot: "..has_loot)
			if has_loot < 1 then
				--würfeln
				print("Würfle auf Item "..loot_counter.."/"..party_member);
				RollOnLoot(prefix, 2);
			else
				print("Passe auf Item "..loot_counter.."/"..party_member);
				RollOnLoot(prefix, 0);
			end

			if party_member <= loot_counter then
				loot_counter = 0;
				has_loot = has_loot -1;
				loot_round = loot_round +1;
				print("Neue Runde, has_loot -1 "..has_loot);
			end
		elseif quality == 2 then
			RollOnLoot(prefix, Crap_Roll_Stat);
		end

	elseif event == "LOOT_HISTORY_ROLL_COMPLETE" then
		local hid, rollid, players, done, _ = 1;
		print("roll complete detect");

		while true do
			print("get item history "..hid)
			rollid, _, players, done = C_LootHistory.GetItem(hid);
			if not rollid then
				return
			elseif done and rolls[rollid] == 1 then
				print(rollid.." abgeschlossen ");
				break
			end
			hid = hid+1
		end

		rolls[rollid] = 2

		for j=1, players do
			print("check winner char: "..j);
			local name, class, rtype, roll, is_winner, is_me = C_LootHistory.GetPlayerInfo(hid, j)
			-- roll = roll and roll or true
			if is_winner then
				print("gewinner von ".._.." ist: "..name.." class: "..class);
				if is_me then
					has_loot = has_loot +1;
					has_won = has_won +1;
					print("ich hab gewonnen has_loot +1 "..has_loot);
				end
				break
			end
		end
--local party_member = 20
--local loot_counter = 0;
--local has_loot = false;




	end
	
	
end

function FdH:SendMsg(m)
	s = FdH:Serialize(m)
	cs = LibDeflate:CompressDeflate(s)
	cs = LibDeflate:EncodeForWoWAddonChannel(cs)
	FdH:SendCommMessage(AddonPrefix, cs, "GUILD", "", "BULK")
end

function EnhanceRCMoreInfo(tip)
	local name = _G["RCVotingFrameMoreInfoTextLeft1"]:GetText();

	if ItemProfConstants.FDH_USER_STATS[name] == nil then
		tip:AddLine("Keine Loot per raid daten für "..name);
	else
		tip:AddLine("Loot per Raid: "..ItemProfConstants.FDH_USER_STATS[name][1]);
	end
	tip:Show();
	return;
end

function FdH:testGui()
	local frame = AceGUI:Create("Frame")
	frame:SetTitle("Example Frame")
	frame:SetStatusText("AceGUI-3.0 Example Container Frame")
	frame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)
	frame:SetLayout("Flow")

	local editbox = AceGUI:Create("EditBox")
	editbox:SetLabel("Insert text:")
	editbox:SetWidth(200)
	editbox:SetCallback("OnEnterPressed", function(widget, event, text) textStore = text end)
	frame:AddChild(editbox)

	local button = AceGUI:Create("Button")
	button:SetText("Click Me!")
	button:SetWidth(200)
	button:SetCallback("OnClick", function() print(textStore) end)
	frame:AddChild(button)


	local cb = AceGUI:Create("CheckBox")
	cb:SetValue(true)
	cb:SetType("radio")
	cb:SetLabel("Passen")
	frame:AddChild(cb)





	local dropdown = AceGUI:Create("Dropdown")
	dropdown:SetValue(Crap_Roll_Stat)
	dropdown:SetList(loot_status_name)
	dropdown:SetText(loot_status_name[Crap_Roll_Stat])
	dropdown:SetLabel("Label: Auf grünen Müll:")
	dropdown:SetCallback("OnValueChanged", function(widget, event, key) Crap_Roll_Stat = key; print("dropdown change: "..key) end)
	frame:AddChild(dropdown)





end

function SlashCmdList.FDH(command, editBox)
	if command == "sync" then
		FdH:SendMsg(ITEM_PROF_FLAGS)
	elseif command == "config" then
		print("comming soon")
	elseif command == "moreinfo" then
		print("hook moreInfo:show");
		RCVotingFrameMoreInfo:HookScript("OnShow", EnhanceRCMoreInfo)
	elseif command == "zg loot" then
		print("Zul'Gurup Lootverteilung aktiv");
		frame:RegisterEvent("START_LOOT_ROLL");
	elseif command == "version" then
		print("Addon Version: "..AddonPrefix.." Daten Version: "..ITEM_PROF_FLAGS["v"])
	elseif command == "zg loot reset" then
		ResetFearLoot();
	elseif command == "zg loot test" then
		print("schalte loot test ein, alles wird verteilt")
		Round_Lood_All = 1;
	elseif command == "zg loot notest" then
		print("schalte loot test aus, nur münzen werden verteilt, andere grüne items werden als müll behandelt");
		Round_Lood_All = 0;
	elseif command == "zg crap roll not" then
		Crap_Roll_Stat = 0;
		print("auf grünen müll wird jetzt automatisch "..loot_status_name[Crap_Roll_Stat].." gewählt");
	elseif command == "zg crap roll gier" then
		Crap_Roll_Stat = 1;
		print("auf grünen müll wird jetzt automatisch "..loot_status_name[Crap_Roll_Stat].." gewählt");
	elseif command == "zg crap roll need" then
		Crap_Roll_Stat = 2;
		print("auf grünen müll wird jetzt automatisch "..loot_status_name[Crap_Roll_Stat].." gewählt");
	elseif command == "test" then
		print(loot_counter.."/"..party_member);
		print("has_loot: "..has_loot);
		print("runde: "..loot_round);
		print("has_won: "..has_won);
		print("verteile alles: "..Round_Lood_All);
		print("Für Müll wird automatisch "..loot_status_name[Crap_Roll_Stat].." gewählt")

	elseif command == "test2" then
		FdH:testGui()
	else
		print("FdH Tool")
		print("Zeigt die prio3 items als tooltip an")
		print("/fdh sync -> sendet deine version zu den andern")
		print("/fdh version -> zeigt version an")
		print("/fdh corona -> gibt es nicht")
		print("/fdh config -> Einstellungen yay")
	end
end




local function InitFrame()
	GameTooltip:HookScript( "OnTooltipSetItem", ModifyItemTooltip )
	FdH:RegisterComm(AddonPrefix)
	
	frame:SetScript("OnEvent", Addon_OnEvent);
	frame:RegisterEvent("PLAYER_LOGIN");
	frame:RegisterEvent("PLAYER_ENTERING_WORLD");
	--frame:RegisterEvent("LOOT_HISTORY_ROLL_COMPLETE");
	--.frame:RegisterEvent("START_LOOT_ROLL");
	

	
	
	SLASH_FDH1 = '/fdh';
end




AddonPrefix = "fdh1";
print("FdH addon geladen :) Version: "..AddonPrefix)





InitFrame()
