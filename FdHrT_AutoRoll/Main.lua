AutoRoll = LibStub("AceAddon-3.0"):NewAddon("FdHrT_AutoRoll", "AceConsole-3.0", "AceEvent-3.0")
local FdHrT = FdHrT

--wow api, tis will do a lot other addons, i'm not sure is it local a lot faster?
local GetLootRollItemInfo = GetLootRollItemInfo
local GetLootRollItemLink = GetLootRollItemLink
local GetItemInfoInstant = GetItemInfoInstant
local GetNumGroupMembers = GetNumGroupMembers
local GetPlayerInfo = C_LootHistory.GetPlayerInfo



local rollOptions = {[0]="Passen", [1]="Bedarf", [2]="Gier"}
local itemQuality = {[2]="Außergewöhnlich", [3]="Selten", [4]="Episch", [5]="Legendär", [6]="Artifakt"}


local dbDefaults = {
	profile = {
		AutoRoll = {
			enabled = false,
			savedItems = { -- it will be possible to remember the decision on the roll frame. this is stored here
				--[19698] = 0,
			},
			itemGroups = { -- When not stored in the savedItems it will check the items groups
				{
					description = "Grüne ZG Münzen im Raid gerecht aufteilen",
					enabled = true,
					items = {[19698]=true,[19699]=true,[19700]=true,[19701]=true,[19702]=true,[19703]=true,[19704]=true,[19705]=true,[19706]=true}, -- ugly but it will be a lot faster and more readable to check is a itemid in this list
					rollOptionSuccsess = 2,
					rollOptionFail = 0,
					conditions = {
						share = true,
					},
				},
				{
					description = "Blaue ZG Schmuckstücke der Hakkari im Raid gerecht aufteilen",
					enabled = true,
					items = {[19707]=true,[19708]=true,[19709]=true,[19710]=true,[19711]=true,[19712]=true,[19713]=true,[19714]=true,[19715]=true},
					rollOptionSuccsess = 2,
					rollOptionFail = 0,
					conditions = {
						share = true,
					},
				},
				{ -- 
					description = "Auf restliche Grüne und Blaue Items passen",
					enabled = false,
					items = {['*']=true}, 
					rollOptionSuccsess = 0,
					rollOptionFail = nil,
					conditions = {
						quality = {
							"<=", 
							3, --0 - Poor, 1 - Common, 2 - Uncommon, 3 - Rare, 4 - Epic, 5 - Legendary, 6 - Artifact, 7 - Heirloom, 8 - WoW Token
						}, 
						-- the following conditions are not implemented yet, and only a hint for me
						-- dungeon = 309, -- condition work only in ZG
						-- inGroupWith = {
						--		oneOf = {"Player1","Player2","Player3"},
						--		allOf = {"Player1","Player2","Player3"},
						-- }, 
						-- perhaps i add a lua solution to, we will see
					},
				},
			},
		},
	},
}

local options = { 
    args = {
        
        ar={
        	handler = AutoRoll,
      		name = "AutoRoll",
      		type = "group",
      		args={
        		status = {
      				name = "Status",
      				desc = "Zeige addon status informationen",
      				type = "execute",
      				func = "PrintStatus"
    			},
    			reset = {
      				name = "Reset",
      				desc = "Setzt die gleichmässige itemvergabe zurück",
      				type = "execute",
      				func = "ResetFearLoot"
    			},
    			debug = {
      				name = "Verteile alles",
      				desc = "verteile alle items, nicht nur die münzen",
      				type = "toggle",
      				get = "IsDebug",
      				set = "ToggleDebug",
    			},
    			rs = {
      				name = "Roll Status",
      				desc = "auf grüne items wird automatisch:",
      				type = "select",
      				values = rollOptions,
      				get = "GetCrapRollStat",
      				set = "SetCrapRollStat",
      				style = "dropdown"
    			},
      		}
    	}
    },
}

function AutoRoll:GetCrapRollStat(info)
	return Crap_Roll_Stat
end

function AutoRoll:SetCrapRollStat(info, value)
	self:Print("setze Status auf: "..rollOptions[value])
	Crap_Roll_Stat = value
end



function AutoRoll:IsDebug(info)
	return Round_Lood_All == 1
end

function AutoRoll:ToggleDebug(info)
	if Round_Lood_All == 1 then
		Round_Lood_All = 0
	else
		Round_Lood_All = 1
	end
end






function AutoRoll:OnInitialize()
	LibStub("AceConfig-3.0"):RegisterOptionsTable("AutoRoll", options["args"]["ar"], {"ar"})
	AutoRoll.message = "Welcome Home!"

    -- Called when the addon is loaded
end

function AutoRoll:OnEnable()
    -- Called when the addon is enabled
    self:Print("geladen")
    self:RegisterEvent("ZONE_CHANGED")
    self:RegisterEvent("START_LOOT_ROLL")
    self:RegisterEvent("LOOT_HISTORY_ROLL_COMPLETE")
    -- Register AutoRoll db on Core addon, and set only the scope to this addon db. So profile reset works fine for all the addons.
    self.db = FdHrT:AddAddonDBDefaults(dbDefaults).profile.AutoRoll;
    FdHrT:AddAddonOptions(options);

    init()
end

function AutoRoll:ZONE_CHANGED()
    self:Print(self.message)
end

function AutoRoll:START_LOOT_ROLL(event, rollid)
	local texture, name, count, quality, bindOnPickUp, canNeed, canGreed, canDisenchant, reasonNeed, reasonGreed, reasonDisenchant, deSkillRequired = GetLootRollItemInfo(rollid);
	print(name..quality);
	local itemID, itemType, itemSubType, itemEquipLoc, icon, itemClassID, itemSubClassID = GetItemInfoInstant(GetLootRollItemLink(rollid));

	print(itemID.." "..name.. GetLootRollItemLink(rollid))
	if (itemID > 19698 and itemID < 19706) or Round_Lood_All == 1 then

		rolls[rollid] = 1;
		loot_counter = loot_counter +1;
		party_member = GetNumGroupMembers();
		print("vor würfeln. has_loot: "..has_loot)
		if has_loot < 1 then
			--würfeln
			print("Würfle auf Item "..loot_counter.."/"..party_member);
			RollOnLoot(rollid, 2);
		else
			print("Passe auf Item "..loot_counter.."/"..party_member);
			RollOnLoot(rollid, 0);
		end

		if party_member <= loot_counter then
			loot_counter = 0;
			has_loot = has_loot -1;
			loot_round = loot_round +1;
			print("Neue Runde, has_loot -1 "..has_loot);
		end
	elseif quality == 2 then
		RollOnLoot(rollid, Crap_Roll_Stat);
	end
end

function AutoRoll:LOOT_HISTORY_ROLL_COMPLETE()
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
		local name, class, rtype, roll, is_winner, is_me = GetPlayerInfo(hid, j)
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
end



function init()
	if loot_counter == nil then
		AutoRoll:ResetFearLoot();
		Round_Lood_All = 0;
		Crap_Roll_Stat = 0;
	end
end


function AutoRoll:ResetFearLoot()
	rolls = {};
	party_member = 20;
	loot_counter = 0;
	has_loot = 0;
	loot_round = 1;
	has_won = 0;
end

function AutoRoll:PrintStatus()
	print(loot_counter.."/"..party_member);
	print("has_loot: "..has_loot);
	print("runde: "..loot_round);
	print("has_won: "..has_won);
	print("verteile alles: "..Round_Lood_All);
	print("Für Müll wird automatisch "..rollOptions[Crap_Roll_Stat].." gewählt")
end