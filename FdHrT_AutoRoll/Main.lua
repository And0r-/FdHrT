AutoRoll = LibStub("AceAddon-3.0"):NewAddon("FdHrT_AutoRoll", "AceConsole-3.0", "AceEvent-3.0")
local FdHrT = FdHrT

AutoRoll.Roll = {} --

local itemQuality = {[2]="Außergewöhnlich", [3]="Selten", [4]="Episch", [5]="Legendär", [6]="Artifakt"}
local conditionOperaters = {["=="]="ist gleich",[">="]="ist mindestens",["<="]="ist höchstens",[">"]="ist höher als",["<"]="ist kleiner als"}


--wow api, tis will do a lot other addons, i'm not sure is it local a lot faster?
local GetLootRollItemInfo = GetLootRollItemInfo
local GetLootRollItemLink = GetLootRollItemLink
local GetItemInfoInstant = GetItemInfoInstant
local GetNumGroupMembers = GetNumGroupMembers
local GetPlayerInfo = C_LootHistory.GetPlayerInfo


local dbDefaults = {
	profile = {
		AutoRoll = {
			enabled = true, -- the addon self is enabled per default
			raidItemGroupsEnabled = true, -- use a group config to auto roll in a raid from a guild leader
			savedItemsEnabled = true, -- add the options to store 
			profileItemGroupsEnabled = false, -- on default it should not use any ItemGroups to auto roll.

			savedItems = { -- it will be possible to remember the decision on the roll frame. this is stored here
				--[19698] = 0,
			}, 
			itemGroupsRaid = {}, -- here are the groups stored you recive from raid lead
			itemGroups = { -- When not stored in the savedItems it will check the items groups
				{
					description = "Grüne ZG Münzen im Raid gerecht aufteilen",
					enabled = true,
					share = {
						enabled = true,
						size = "raid"
					},
					rollOptionSuccsess = 2,
					conditions = {
						[1] = {
							type = "item",
							args = {"19698,19699,19700,19701,19702,19703,19704,19705,19706"},
						}
					},
				},
				{
					description = "Blaue ZG Schmuckstücke der Hakkari im Raid gerecht aufteilen",
					enabled = true,
					share = {
						enabled = true,
					},
					rollOptionSuccsess = 2,
					conditions = {
						[1] = {
							type = "item",
							args = {"19707,19708,19709,19710,19711,19712,19713,19714,19715"},
						}
					},
				},
				{ -- 
					description = "Auf restliche Grüne und Blaue Items passen",
					enabled = false, 
					share = {
						enabled = false,
					},
					rollOptionSuccsess = 0,
					conditions = {
						[1] = {
							type = "quality",
							args = {
								"<=", 
								3, --0 - Poor, 1 - Common, 2 - Uncommon, 3 - Rare, 4 - Epic, 5 - Legendary, 6 - Artifact, 7 - Heirloom, 8 - WoW Token
							}, 
						}
						-- the following conditions are not implemented yet, and only a hint for me
						-- dungeon = 309, -- condition work only in ZG
						-- inGroupWith = {
						--		"oneOf", "Player1,Player2,Player3",
						--		"allOf", "Player1,Player2,Player3",
						-- }, 
						-- perhaps i add a lua solution to, we will see
					},
				},
			},
		},
	},
}

function AutoRoll:OnInitialize()
	--self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("FdHrT", "FdH Raid Tool")
	--self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("FdHrT_AutoRoll", "AutoRoll", "FdH Raid Tool")

    -- Called when the addon is loaded
end

function AutoRoll:OnEnable()
    -- Called when the addon is enabled
    self:Print("geladen")
    self:RegisterEvent("START_LOOT_ROLL")
    self:RegisterEvent("LOOT_HISTORY_ROLL_COMPLETE")
    -- Register AutoRoll db on Core addon, and set only the scope to this addon db. So profile reset works fine for all the addons.
    self.db = FdHrT:AddAddonDBDefaults(dbDefaults).profile.AutoRoll;
    local options = self:GetOptions();
    FdHrT:AddAddonOptions(options,"AutoRoll");
    --LibStub("AceConfig-3.0"):RegisterOptionsTable("AutoRoll", options.args.ar, {"ar"})
 
    init()
end

function AutoRoll:GetRollIdData(rollid)
	local itemInfo = {["rollid"] = rollid}
	itemInfo.texture, itemInfo.name, itemInfo.count, itemInfo.quality, itemInfo.bindOnPickUp, itemInfo.canNeed, itemInfo.canGreed, itemInfo.canDisenchant, itemInfo.reasonNeed, itemInfo.reasonGreed, itemInfo.reasonDisenchant, itemInfo.deSkillRequired = GetLootRollItemInfo(rollid);
	print(itemInfo.name..itemInfo.quality);
	itemInfo.itemId, itemInfo.itemType, itemInfo.itemSubType, itemInfo.itemEquipLoc, itemInfo.icon, itemInfo.itemClassID, itemInfo.itemSubClassID = GetItemInfoInstant(GetLootRollItemLink(itemInfo.rollid));

	itemInfo.itemLink = GetLootRollItemLink(itemInfo.rollid)

	return itemInfo
end

function AutoRoll:GetRollIdDataDebug(rollid)
	local itemInfo = {
		rollid = rollid,
		name = "test item",
		count = 1,
		quality = 3,
		itemId = 19698,


	}
	return itemInfo
end

-- /run AutoRoll:troll(1)
-- /run AutoRoll:troll(1,1234)
-- Debug function to emulate a roll windows event
function AutoRoll:troll(rollId, itemId)
	local itemInfo = self:GetRollIdDataDebug(rollid);
	if itemId then itemInfo.itemId = itemId end
	self:CheckRoll(itemInfo)
end

function AutoRoll:START_LOOT_ROLL(event, rollid)
	local itemInfo = self:GetRollIdData(rollid);
	self:CheckRoll(itemInfo)
end

function AutoRoll:CheckRoll(itemInfo)
	local itemGroups = self.db.itemGroups;

	local groupId = AutoRoll:findGroup(itemInfo,itemGroups);

	if groupId then
		self:Print("gefundene Gruppe: "..itemGroups[groupId].description)
	end
end

function AutoRoll:CheckConditions(itemInfo, itemGroup)
	if itemGroup.conditions == nil then return false end

	-- Check all Conditions
	for ic, condition in pairs(itemGroup.conditions) do
		if AutoRoll:CheckCondition(itemInfo, condition) == false then
			-- Condition fails try next itemGroup
			return false
		end
	end
	-- All Conditions true, une this itemGroup
	return true
end

function AutoRoll:CheckCondition(itemInfo, condition)
	if condition.type == "item" then 
		return tContains({strsplit(",",condition.args[1])},tostring(itemInfo.itemId))
	elseif condition.type == "disabled" then 
		return true
	elseif condition.type == "lua" then 
		return true
	elseif condition.type == "party_member" then
		for i,playerName in ipairs({strsplit(",",condition.args[2])}) do
			if UnitInRaid(playerName) or UnitInParty(playerName) then
				if condition.args[1] == "oneOf" then
					return true
				end
			else
				if condition.args[1] == "allOf" then
					return false
				end
			end
		end
		if condition.args[1] == "oneOf" then
			return false
		else
			return true
		end
	elseif condition.type == "dungeon" then 
		local instanceId = select(8,GetInstanceInfo())
		return instanceId == condition.args[1]
	elseif condition.type == "quality" then 
		-- Validate bevore use loadstring
		if conditionOperaters[condition.args[1]] == nil or itemQuality[condition.args[2]] == nil then return false end
		 
		local f = assert(loadstring("return "..itemInfo.quality.." "..condition.args[1].." "..condition.args[2]))
		return f()
	end

	return true -- Condition type not known, ignore it
end

function AutoRoll:findGroup(itemInfo, itemGroups)
	if itemGroups == nil then return nil end

	for i, itemGroup in pairs(itemGroups) do
		if itemGroup.enabled == false then break end

		if self:CheckConditions(itemInfo, itemGroup) then 
			return i 
		end

					-- conditions = {
					-- 	[1] = {
					-- 		type = "item",
					-- 		args = {"19707,19708,19709,19710,19711,19712,19713,19714,19715"},
					-- 	}
					-- },
					-- conditions = {
					-- 	[1] = {
					-- 		type = "quality",
					-- 		args = {
					-- 			"<=", 
					-- 			3, --0 - Poor, 1 - Common, 2 - Uncommon, 3 - Rare, 4 - Epic, 5 - Legendary, 6 - Artifact, 7 - Heirloom, 8 - WoW Token
					-- 		}, 
					-- 	}
						-- the following conditions are not implemented yet, and only a hint for me
						-- dungeon = 309, -- condition work only in ZG
						-- inGroupWith = {
						--		"oneOf", "Player1,Player2,Player3",
						--		"allOf", "Player1,Player2,Player3",
						-- }, 


	end



	-- if (itemID > 19698 and itemID < 19706) or Round_Lood_All == 1 then

	-- 	rolls[rollid] = 1;
	-- 	loot_counter = loot_counter +1;
	-- 	party_member = GetNumGroupMembers();
	-- 	print("vor würfeln. has_loot: "..has_loot)
	-- 	if has_loot < 1 then
	-- 		--würfeln
	-- 		print("Würfle auf Item "..loot_counter.."/"..party_member);
	-- 		RollOnLoot(rollid, 2);
	-- 	else
	-- 		print("Passe auf Item "..loot_counter.."/"..party_member);
	-- 		RollOnLoot(rollid, 0);
	-- 	end

	-- 	if party_member <= loot_counter then
	-- 		loot_counter = 0;
	-- 		has_loot = has_loot -1;
	-- 		loot_round = loot_round +1;
	-- 		print("Neue Runde, has_loot -1 "..has_loot);
	-- 	end
	-- elseif quality == 2 then
	-- 	RollOnLoot(rollid, Crap_Roll_Stat);
	-- end
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


