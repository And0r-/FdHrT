AutoRoll = LibStub("AceAddon-3.0"):GetAddon("FdHrT_AutoRoll")
local FdHrT = FdHrT



local conditionList = {["quality"]="Qualität", ["dungeon"]="Dungeon", ["party_member"]="In der Gruppe mit", ["lua"]="Lua",["disabled"]="Deaktiviert",["deleted"]="Löschen",["item"]="Item"}
local rollOptions = {[0]="Passen", [1]="Bedarf", [2]="Gier"}
local itemQuality = {[2]="Außergewöhnlich", [3]="Selten", [4]="Episch", [5]="Legendär", [6]="Artifakt"}
local dungeonList = {[697]="Zul'Gurub",[718]="Ony", [696]="MC", [755]="BWL"}

local conditionOperaters = {["="]="ist gleich",[">="]="ist mindestens",["<="]="ist höchstens",[">"]="ist höher als",["<"]="ist kleiner als"}

function AutoRoll:GetOptions()
	return { 
    	handler = AutoRoll,
  		name = "",
  		type = "group",
  		childGroups = "tab",
  		args = {
			settings = {
				name = "Debug",
				type = "group",
				order = 2,
				args = self:GetOptionSettings(),
		    },
			itemGroups = {
				name = "Regeln",
				type = "group",
				order = 1,
				args = self:GetOptionItemGroups(),
		    },
      	},
	}
end

function AutoRoll:GetOptionSettings()
	return {
		status = {
			name = "Status",
			desc = "Zeige informationen über die share itemvergabe",
			type = "execute",
			order = 2,
			func = "PrintStatus",
		},
		reset = {
			name = "Reset",
			desc = "Setzt die gleichmässige itemvergabe zurück",
			type = "execute",
			order = 3,
			func = "ResetFearLoot",
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

	for itemGroupId,dbItemGroup in ipairs(self.db.itemGroups) do

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
      				values = rollOptions,
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

	if self.db.itemGroups[itemGroupId].conditions == nil then return conditions end

	local order = 1;
	for conditionId,condition in ipairs(self.db.itemGroups[itemGroupId].conditions) do
		if condition.type ~= "deleted" then 

			conditions["condition"..conditionId] = {
	  				name = "",
	  				desc = "",
	  				type = "select",
	  				order = order,
	  				values = conditionList,
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
		values = conditionOperaters,
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
		values = itemQuality,
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
		values = dungeonList,
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

function AutoRoll:GetConditionArg(info)
	return self.db.itemGroups[info.arg[1]].conditions[info.arg[2]].args[info.arg[3]]
end

function AutoRoll:SetConditionArg(info, value)
	self.db.itemGroups[info.arg[1]].conditions[info.arg[2]].args[info.arg[3]] = value
end

function AutoRoll:GetCrapRollStat(info)
	self:Print(info.arg)
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

function AutoRoll:AddConditionOption(info)
	if self.db.itemGroups[info.arg].conditions == nil then self.db.itemGroups[info.arg].conditions = {} end
	tinsert(self.db.itemGroups[info.arg].conditions, {type = "disabled", args = {true}});

	options = self:GetOptions();
    FdHrT:AddAddonOptions(options,"AutoRoll");
end

function AutoRoll:AddItemGroupOption(info)
	tinsert(self.db.itemGroups, {description = "Neue Gruppe", conditions = {}});

	options = self:GetOptions();
    FdHrT:AddAddonOptions(options,"AutoRoll");
end


function AutoRoll:GetConditionType(info)
	return self.db.itemGroups[info.arg[1]].conditions[info.arg[2]].type
end

function AutoRoll:SetConditionType(info, value)
	self.db.itemGroups[info.arg[1]].conditions[info.arg[2]].type = value

	-- I have to find a other way to delete options. at the moment i merge the table of changed sub addons with the global one.
	FdHOptions.AutoRoll.args.itemGroups.args["itemGroup"..info.arg[1]].args.conditions = nil -- Remove the conditions from the global options
	options = self:GetOptions();
	FdHrT:AddAddonOptions(options,"AutoRoll");
end

function AutoRoll:GetItemGroupRollOptionSuccsess(info)
	return self.db.itemGroups[info.arg].rollOptionSuccsess
end

function AutoRoll:SetItemGroupRollOptionSuccsess(info, value)
	self.db.itemGroups[info.arg].rollOptionSuccsess = value
end

function AutoRoll:getItemGroupDescription(info)
	return self.db.itemGroups[info.arg].description
end

function AutoRoll:setItemGroupDescription(info, value)
	self.db.itemGroups[info.arg].description = value

	options = self:GetOptions();
	FdHrT:AddAddonOptions(options,"AutoRoll");
end

function AutoRoll:IsItemGroupEnabled(info)
	return self.db.itemGroups[info.arg].enabled
end

function AutoRoll:ToggleItemGroupEnabled(info, value)
	self.db.itemGroups[info.arg].enabled = value
end

function AutoRoll:IsItemGroupShareEnabled(info)
	if self.db.itemGroups[info.arg].share == nil then
		return false
	else
		return self.db.itemGroups[info.arg].share.enabled
	end
end

function AutoRoll:ToggleItemGroupShareEnabled(info, value)
	self.db.itemGroups[info.arg].share.enabled = value
	FdHOptions.AutoRoll.args.itemGroups.args["itemGroup"..info.arg] = nil -- Remove the conditions from the global options
	options = self:GetOptions();
	FdHrT:AddAddonOptions(options,"AutoRoll");
end

 