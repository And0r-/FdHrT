AutoRoll = LibStub("AceAddon-3.0"):NewAddon("FdHrT_AutoRoll", "AceConsole-3.0", "AceEvent-3.0")
local FdHrT = FdHrT

AutoRoll.sharedata = {} --
-- @todo:  save this in AutoRoll, to not have dublications...
local rollOptions = {[0]="Passen", [1]="Bedarf", [2]="Gier"}
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
			rolls = {}, -- data about current rolls with share function, when this rollId is finished we have to check do we have won the item. and update the itemgroup share data. rolls[rollId] = itemGroupId
			share = {}, -- round robin data of all groups. e.g: share[itemGroupId].loot_counter 
			enabled = true, -- the addon self is enabled per default
			guildItemGroupsEnabled = true, -- use a group config to auto roll in a raid from a guild leader
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

end

function AutoRoll:GetRollIdData(rollId)
	local itemInfo = {["rollId"] = rollId}
	itemInfo.texture, itemInfo.name, itemInfo.count, itemInfo.quality, itemInfo.bindOnPickUp, itemInfo.canNeed, itemInfo.canGreed, itemInfo.canDisenchant, itemInfo.reasonNeed, itemInfo.reasonGreed, itemInfo.reasonDisenchant, itemInfo.deSkillRequired = GetLootRollItemInfo(rollId);
	print(itemInfo.name..itemInfo.quality);
	itemInfo.itemId, itemInfo.itemType, itemInfo.itemSubType, itemInfo.itemEquipLoc, itemInfo.icon, itemInfo.itemClassID, itemInfo.itemSubClassID = GetItemInfoInstant(GetLootRollItemLink(itemInfo.rollId));

	itemInfo.itemLink = GetLootRollItemLink(itemInfo.rollId)

	return itemInfo
end

function AutoRoll:GetRollIdDataDebug(rollId)
	local itemInfo = {
		rollId = rollId,
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
	self:Print("rollId ist: "..rollId)
	local itemInfo = self:GetRollIdDataDebug(rollId);
	if itemId then itemInfo.itemId = itemId end
	self:CheckRoll(itemInfo)
end

function AutoRoll:START_LOOT_ROLL(event, rollId)
	local itemInfo = self:GetRollIdData(rollId);
	self:CheckRoll(itemInfo)
end

function AutoRoll:CheckRoll(itemInfo)
	if self.db.enabled == false then return false end
	local currentItemGroupId

	-- if raiditem then
	-- 	if raidItemGroupsEnabled and self:isRaidItemGroup then
	-- 		currentItemGroupId = self:findGroup(itemInfo,self.db.itemGroupsRaid);
	-- 		if currentItemGroupId then currentItemGroup = self.db.itemGroupsRaid[currentItemGroupId] end
	-- 	end
	-- else
		if self.db.profileItemGroupsEnabled then
			currentItemGroupId = self:findGroup(itemInfo,self.db.itemGroups);
		end
	-- end

	-- no active itemGroup found for this roll window, abort
	if currentItemGroupId == nil then return false end

	local currentItemGroup = self.db.itemGroups[currentItemGroupId]

	if currentItemGroup then
		self:Print("gefundene Gruppe: "..currentItemGroup.description)
	end


	if currentItemGroup.share then

		self:Print("checke round robin für rollId: "..itemInfo.rollId)
		-- round robin mode. only roll when player not have more then the other from currentItemGroupId.
		self:CheckShare(itemInfo.rollId, currentItemGroupId, currentItemGroup)
	else
		-- auto roll
		self:Print("auto roll: ".. rollOptions[currentItemGroup.rollOptionSuccsess])
	end

end


-- function AutoRoll:isRaidItemGroup()
-- 	-- There are no dungeon session id, so i have to track self is it the same group
-- end

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
		-- Validate bevore use the evel loadstring function...
		if conditionOperaters[condition.args[1]] == nil or itemQuality[condition.args[2]] == nil then return false end
		 
		local f = assert(loadstring("return "..itemInfo.quality.." "..condition.args[1].." "..condition.args[2]))
		return f()
	end

	return true -- Condition type not known, ignore it
end

function AutoRoll:findGroup(itemInfo, itemGroups)
	if itemGroups == nil then return nil end -- no itemGroups created

	for i, itemGroup in pairs(itemGroups) do
		if itemGroup.enabled == false then break end

		if self:CheckConditions(itemInfo, itemGroup) then 
			return i 
		end
	end
	return nil




end

-- a little bit messy at the moment, 
function AutoRoll:CheckShare(rollId, currentItemGroupId)
	 self.db.rolls[rollId] = currentItemGroupId;
	 if self.db.share[currentItemGroupId] == nil then self:initShare(currentItemGroupId) end
 	local sharedata = self.db.share[currentItemGroupId];

	sharedata.loot_counter = sharedata.loot_counter +1;
	local party_member = GetNumGroupMembers(); -- it is possible that one of the group do not want any zg coins. so we need a option later to change the party_member size by hand...
--		print("vor würfeln. has_loot: "..has_loot)
	if sharedata.has_loot < 1 then
		--würfeln
		print("Würfle auf Item drops:"..sharedata.loot_counter.." spieler anz:"..party_member);
		RollOnLoot(rollId, 2);
	else
		print("Passe auf Items, da ich schon eins habe. drops:"..sharedata.loot_counter.." spieler anz:"..party_member);
		RollOnLoot(rollId, 0);
	end

	if party_member <= sharedata.loot_counter then
		sharedata.loot_counter = 0;
		sharedata.has_loot = sharedata.has_loot -1;
		sharedata.loot_round = sharedata.loot_round +1;
		print("Neue Runde, has_loot -1 "..sharedata.has_loot);
	end
end

function AutoRoll:initShare(currentItemGroupId)
	self.db.share[currentItemGroupId] = {
		loot_counter = 0,
		has_loot = 0,
		loot_round = 1,
	}
end

function AutoRoll:LOOT_HISTORY_ROLL_COMPLETE()
	local hid, rollId, players, done, _ = 1;
	print("roll complete detect");

	while true do
		print("get item history "..hid)
		rollId, _, players, done = C_LootHistory.GetItem(hid);
		if not rollId then
			return
		elseif done and rolls[rollId] == 1 then
			print(rollId.." abgeschlossen ");
			break
		end
		hid = hid+1
	end

	rolls[rollId] = 2

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

function AutoRoll:ResetShare(itemGroupId)
	if itemGroupId then
		-- reset share loot from this itemGroupId
		self.db.share[itemGroupId] = {}
	else
		-- reset all share loots!
		self.db.share = {}
	end
end

function AutoRoll:PrintShareStatus(itemGroupId)
	local sharedata = self.db.share[currentItemGroupId]

	self:Print(self.db.itemGroups[itemGroupId].description)
	self:Print(sharedata.loot_counter.."/"..sharedata.party_member);
	self:Print("has_loot: "..sharedata.has_loot);
	self:Print("runde: "..sharedata.loot_round);
	self:Print("has_won: "..sharedata.has_won);
end

function AutoRoll:PrintAllShareStatus()
	for i in ipairs(self.db.share) do
		self:PrintShareStatus(i)
	end
end


