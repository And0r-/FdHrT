AutoRoll = LibStub("AceAddon-3.0"):GetAddon("FdHrT_AutoRoll")

-- 48	Blackfathom Deeps
-- 230	Blackrock Depths
-- 229	Blackrock Spire
-- 429	Dire Maul
-- 90	Gnomeregan
-- 349	Maraudon
-- 389	Ragefire Chasm
-- 129	Razorfen Downs
-- 47	Razorfen Kraul
-- 1001	Scarlet Halls
-- 1004	Scarlet Monastery
-- 1007	Scholomance
-- 33	Shadowfang Keep
-- 329	Stratholme
-- 36	The Deadmines
-- 34	The Stockade
-- 109	The Temple of Atal'Hakkar
-- 70	Uldaman
-- 43	Wailing Caverns
-- 209	Zul'Farrak
-- 309	Zul'Gurub

-- 469	Blackwing Lair
-- 409	Molten Core
-- 509	Ruins of Ahn'Qiraj
-- 531	Temple of Ahn'Qira


function AutoRoll:GetOptions()
	return { 
    	handler = AutoRoll,
  		name = "",
  		type = "group",
  		childGroups = "tab",
  		args = {
			settings = {
				name = "Einstellungen",
				type = "group",
				order = 1,
				args = self:GetOptionSettings(),
		    },
			itemGroups = {
				name = "Erweiterte Einstellungen",
				type = "group",
				order = 2,
				args = self:GetOptionItemGroups(),
		    },
			debug = {
				name = "Debug",
				type = "group",
				order = 3,
				args = self:GetOptionDebug(),
		    },
      	},
	}
end

function AutoRoll:GetOptionSettings()
	return { --profileItemGroupsEnabled
		raidItemGroups = {
			name = "Gildenleitung kann bestimmen was ich würfeln soll (kommt in Beta2)",
			desc = "Wärend einem Raid kann die Gildenleitung meine eigenen Regeln überschreiben.",
			type = "toggle",
			order = 1,
			get = "IsGuildItemGroupsEnabled",
			set = "ToggleGuildItemGroupsEnabled",
			width = "full",
		},
		saveRollOptionsEnabled = {
			name = "Beim würfeln kann man angeben das nächste mal wieder das selbe zu wählen",
			desc = "Past/würfelt das nächste mal beim selben item automatisch, wenn 'merken' im Würfelfenster aktiviert wird",
			type = "toggle",
			order = 2,
			get = "IssavedItemsEnabled",
			set = "TogglesavedItemsEnabled",
			width = "full",
		},
		profileItemGroups = {
			name = "Würfelregeln Einschalten",
			desc = "Schaltet die definierten Regeln ein",
			type = "toggle",
			order = 3,
			get = "IsProfileItemGroupsEnabled",
			set = "ToggleProfileItemGroupsEnabled",
			width = "full",
		},
		-- show a short enable disable list for the itemGroups when enabled. disable advanced tab when not enabled.

	}
end

function AutoRoll:GetOptionDebug()
	return {
		status = {
			name = "Status",
			desc = "Zeige informationen über die share itemvergabe",
			type = "execute",
			order = 2,
			func = "PrintAllShareStatus",
		},
		reset = {
			name = "Reset",
			desc = "Setzt die gleichmässige itemvergabe zurück",
			type = "execute",
			order = 3,
			func = "ResetShare",
		},
		nl2 = {
			type = "header",
			name = "",
			order = 4,
		},
		debug = {
			name = "Debug",
			desc = "verteile alle items, nicht nur die münzen",
			type = "toggle",
			order = 5,
			get = "IsDebug",
			set = "ToggleDebug",
		},
	}
end


function AutoRoll:GetOptionItemGroups()

	local itemGroups = {
		headerDescription = {
			type = "description",
			name = "Hier können verschiedene Gruppen definiert werden. \rWenn alle Regeln der ersten gruppe erfüllt sind, wird die Aktion ausgeführt. \rWenn nicht, wird die nächste Gruppe überprüft.",
			order = 0,
		},
	}

	for itemGroupId,dbItemGroup in ipairs(self.db.profile.itemGroups) do

		itemGroups["itemGroup"..itemGroupId] = {
			name = dbItemGroup.description,
			type = "group",
			inline = true,
			width = "full",
			order  = itemGroupId,
			args = {
				enabled = {
					name = "Aktiv",
					desc = "Regel Gruppe ist Aktiv",
					type = "toggle",
					order = 1,
					get = "IsItemGroupEnabled",
					set = "ToggleItemGroupEnabled",
					arg = itemGroupId,
				},
				share = {
					name = "Aufteilen",
					desc = "In gruppe Aufteilen",
					type = "toggle",
					order = 2,
					get = "IsItemGroupShareEnabled",
					set = "ToggleItemGroupShareEnabled",
					arg = itemGroupId,
				},
				shareOptions = self:GetItemGroupShareOptions(itemGroupId), 
				description = {
					name = "Beschreibung",
					type = "input",
					order = 0,
					get = "getItemGroupDescription",
					set = "setItemGroupDescription",
					arg = itemGroupId,
					width = "full",
				},
				conditions = {
					name = "Regeln",
					desc = "Bedingungen damit die Gruppe zum einsatz kommt",
					type = "group",
					order = 4,
					inline = true,
					width = "full",
					args = self:GetOptionItemGroupConditions(itemGroupId),
				},
				rs = {
      				name = "Automatisch Würfeln:",
      				desc = "Gibt an was mit den Items geschehen soll, welche alle Regeln erfüllen.",
      				type = "select",
      				order = 6,
      				values = self.rollOptions,
      				get = "GetItemGroupRollOptionSuccsess",
      				set = "SetItemGroupRollOptionSuccsess",
      				style = "dropdown",
      				arg = itemGroupId,
    			},
			}
		};
	end

	itemGroups.addItemGroupButton = {
		name = "Gruppe hinzufügen",
		desc = "Gruppe hinzufügen",
		type = "execute",
		order = -1,
		func = "AddItemGroupOption",
		--arg = itemGroupId,
	}

	return itemGroups;
end

function AutoRoll:GetItemGroupShareOptions(itemGroupId)
	return {
		name = "",
		type = "group",
		width = "full",
		order  = 3,
		hidden = self:IsItemGroupShareEnabled({["arg"]=itemGroupId}) == false,
		args = {
			description = {
				name = "Aufteilen ist aktiv. Auf ein Item wird nur gefürfelt bis man eins hat. \rDanach wird gepasst bis alle eins haben.",
				type = "description",
				order = 1,
			},
		},
		arg = itemGroupId,
	}
end

function AutoRoll:GetOptionItemGroupConditions(itemGroupId)
	local conditions = {}
	conditions.addConditionButton = {
		name = "Regel hinzufügen",
		desc = "Regel hinzufügen",
		type = "execute",
		order = -1,
		func = "AddConditionOption",
		arg = itemGroupId,
	}

	if self.db.profile.itemGroups[itemGroupId].conditions == nil then return conditions end

	local order = 1;
	for conditionId,condition in ipairs(self.db.profile.itemGroups[itemGroupId].conditions) do
		if condition.type ~= "deleted" then 

			conditions["condition"..conditionId] = {
	  				name = "",
	  				desc = "",
	  				type = "select",
	  				order = order,
	  				values = self.conditionList,
	  				get = "GetConditionType",
	  				set = "SetConditionType",
	  				style = "dropdown",
	  				--width = "half",
	  				arg = {itemGroupId,conditionId},
			}
			order = order +1;

			if condition.type == "item" then conditions, order =self:AddItemConditonOptions(conditions,order,itemGroupId,conditionId) end
			if condition.type == "quality" then conditions, order =self:AddQualityConditonOptions(conditions,order,itemGroupId,conditionId) end
			if condition.type == "dungeon" then conditions, order =self:AddDungeonConditonOptions(conditions,order,itemGroupId,conditionId) end
			if condition.type == "party_member" then conditions, order =self:AddPartyMemberConditonOptions(conditions,order,itemGroupId,conditionId) end
			if condition.type == "lua" then conditions, order =self:AddLuaConditonOptions(conditions,order,itemGroupId,conditionId) end


			conditions["condition"..conditionId.."nl"] = {
				type = "header",
				name = "",
				order = order,
			}
			order = order +1;
		end
	end

	return conditions
end


function AutoRoll:AddItemConditonOptions(conditions,order,itemGroupId,conditionId)
--		arg = {itemGroupId,conditionId},

	conditions["condition"..conditionId.."Items"] = {
		name = "",
		desc = ", separierte liste mit Item Id's. Z.b: 19698,19699,19700",
		type = "input",
		order = order,
		get = "GetConditionArg",
		set = "SetConditionArg",
		arg = {itemGroupId,conditionId,1},
		width = 1.9,
	}
	order = order +1

	return conditions, order;
end

function AutoRoll:AddQualityConditonOptions(conditions,order,itemGroupId,conditionId)
--		arg = {itemGroupId,conditionId},

	conditions["condition"..conditionId.."QualityOperator"] = {
		name = "",
		desc = "",
		type = "select",
		order = order,
		get = "GetConditionArg",
		set = "SetConditionArg",
		style = "dropdown",
		values = self.conditionOperaters,
		arg = {itemGroupId,conditionId,1},
	}
	order = order +1

	conditions["condition"..conditionId.."Quality"] = {
		name = "",
		desc = "Item Qualität",
		type = "select",
		order = order,
		get = "GetConditionArg",
		set = "SetConditionArg",
		style = "dropdown",
		values = self.itemQuality,
		arg = {itemGroupId,conditionId,2},
	}
	order = order +1

	return conditions, order;
end

function AutoRoll:AddDungeonConditonOptions(conditions,order,itemGroupId,conditionId)
--		arg = {itemGroupId,conditionId},

	conditions["condition"..conditionId.."Dungeon"] = {
		name = "",
		desc = "Item Qualität",
		type = "select",
		order = order,
		get = "GetConditionArg",
		set = "SetConditionArg",
		style = "dropdown",
		values = self.dungeonList,
		arg = {itemGroupId,conditionId,1},
	}
	order = order +1

	return conditions, order;
end

function AutoRoll:AddPartyMemberConditonOptions(conditions,order,itemGroupId,conditionId)
--		arg = {itemGroupId,conditionId},
	conditions["condition"..conditionId.."PartyMemberOperator"] = {
		name = "",
		desc = "Item Qualität",
		type = "select",
		order = order,
		get = "GetConditionArg",
		set = "SetConditionArg",
		style = "dropdown",
		values = {["oneOf"]="Einer von",["allOf"]="Alle von"},
		arg = {itemGroupId,conditionId,1},
	}
	order = order +1

	conditions["condition"..conditionId.."PartyMember"] = {
		name = "",
		desc = ", separierte liste von Spielernamen",
		type = "input",
		order = order,
		get = "GetConditionArg",
		set = "SetConditionArg",
		arg = {itemGroupId,conditionId,2},
	}
	order = order +1

	return conditions, order;
end

function AutoRoll:AddLuaConditonOptions(conditions,order,itemGroupId,conditionId)
--		arg = {itemGroupId,conditionId},

	conditions["condition"..conditionId.."Lua"] = {
		name = "Noch nicht umgesetzt, kommt bald :D",
		desc = "",
		type = "description",
		order = order,
		--get = "GetConditionArg",
		--set = "SetConditionArg",
		--arg = {itemGroupId,conditionId,1},
		--width = 1.9,
	}
	order = order +1

	return conditions, order;
end

function AutoRoll:refreshOptions()
	local options = self:GetOptions();
	options.args.profiles = self.profilOptions
    LibStub("AceConfig-3.0"):RegisterOptionsTable("AutoRoll", options)
end

function AutoRoll:GetConditionArg(info)
	return self.db.profile.itemGroups[info.arg[1]].conditions[info.arg[2]].args[info.arg[3]]
end

function AutoRoll:SetConditionArg(info, value)
	self.db.profile.itemGroups[info.arg[1]].conditions[info.arg[2]].args[info.arg[3]] = value
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

function AutoRoll:AddConditionOption(info)
	if self.db.profile.itemGroups[info.arg].conditions == nil then self.db.profile.itemGroups[info.arg].conditions = {} end
	tinsert(self.db.profile.itemGroups[info.arg].conditions, {type = "disabled", args = {true}});

	self:refreshOptions();
end

function AutoRoll:AddItemGroupOption(info)
	tinsert(self.db.profile.itemGroups, {description = "Neue Gruppe", conditions = {}, share = {}});
	self:refreshOptions();
end


function AutoRoll:GetConditionType(info)
	return self.db.profile.itemGroups[info.arg[1]].conditions[info.arg[2]].type
end

function AutoRoll:SetConditionType(info, value)
	self.db.profile.itemGroups[info.arg[1]].conditions[info.arg[2]].type = value

	self:refreshOptions();
end

function AutoRoll:GetItemGroupRollOptionSuccsess(info)
	return self.db.profile.itemGroups[info.arg].rollOptionSuccsess
end

function AutoRoll:SetItemGroupRollOptionSuccsess(info, value)
	self.db.profile.itemGroups[info.arg].rollOptionSuccsess = value
end

function AutoRoll:getItemGroupDescription(info)
	return self.db.profile.itemGroups[info.arg].description
end

function AutoRoll:setItemGroupDescription(info, value)
	self.db.profile.itemGroups[info.arg].description = value
	self:refreshOptions();
end

function AutoRoll:IsItemGroupEnabled(info)
	return self.db.profile.itemGroups[info.arg].enabled
end

function AutoRoll:ToggleItemGroupEnabled(info, value)
	self.db.profile.itemGroups[info.arg].enabled = value
end

function AutoRoll:IsProfileItemGroupsEnabled(info)
	return self.db.profile.profileItemGroupsEnabled
end

function AutoRoll:ToggleProfileItemGroupsEnabled(info, value)
	self.db.profile.profileItemGroupsEnabled = value
end

function AutoRoll:IsGuildItemGroupsEnabled(info)
	return self.db.profile.guildItemGroupsEnabled
end

function AutoRoll:ToggleGuildItemGroupsEnabled(info, value)
	self.db.profile.guildItemGroupsEnabled = value
end

function AutoRoll:IssavedItemsEnabled(info)
	return self.db.profile.savedItemsEnabled
end

function AutoRoll:TogglesavedItemsEnabled(info, value)
	self.db.profile.savedItemsEnabled = value
end



function AutoRoll:IsItemGroupShareEnabled(info)
	if self.db.profile.itemGroups[info.arg].share == nil then
		return false
	else
		return self.db.profile.itemGroups[info.arg].share.enabled
	end
end

function AutoRoll:ToggleItemGroupShareEnabled(info, value)
	self.db.profile.itemGroups[info.arg].share.enabled = value
	self:refreshOptions();
end

 
 function AutoRoll:ResetShare(info)
	if info.arg then
		-- reset share loot from this itemGroupId
		self:Print("Resette share von itemGroup: ".. info.arg)
		self.db.profile.share[info.arg] = {}
	else
		-- reset all share loots!
		self:Print("Resette alle share daten")
		self.db.profile.share = {}
	end
end

function AutoRoll:PrintShareStatus(info)
	local sharedata = self.db.profile.share[info.arg]

	self:Print(self.db.profile.itemGroups[info.arg].description)
	self:Print("Drops in dieser Runde: "..sharedata.loot_counter)
	self:Print("Spieler in Gruppe: "..sharedata.party_member);
	if sharedata.has_loot == 1 then
		self:Print("Habe bereits mein/e Items erhalten, passe auf das nächste.")
	else
		self:Print("Habe noch anrecht auf "..(sharedata.has_loot*-1)+1 .." item/s, würfle auf das nächste")
	end
	self:Print("Runde: "..sharedata.loot_round);
	self:Print("Total gewonnen: "..sharedata.has_won_total);
end

function AutoRoll:PrintAllShareStatus(info)
	for i in pairs(self.db.profile.share) do
		self:PrintShareStatus({["arg"]=i})
	end
end