local FdHrTO = LibStub("AceAddon-3.0"):NewAddon("FdHrT_Offi", "AceConsole-3.0", "AceEvent-3.0")
local FdHrT = FdHrT

--first prototyp, i have to refactor and test a lot

-- I will build it in groups
-- ech groups has his own roll settings and rules to match items
-- when you use the "share" roll setting on a group it will roll pass and gier, so that everyone get the same amount.

local InvMembersString = "";
local convert_to_raid = 0;

--local dbDefaults = {};

local options = { 
    args = {
        
        inv={
          handler = FdHrTO,
      		name = "Invite",
      		type = "group",
      		
      		args={
      			members = {
      				name = "Raid Teilnehmer",
      				desc = "einzuladende Teilnehmer",
      				type = "input",
      				multiline = true,
      				get = "GetMembers",
      				set = "SetMembers",
      				width = "full",
    			},
    			status = {
      				name = "Status",
      				desc = "Zeigt den Invite status",
      				type = "execute",
      				func = "PrintInvStatus"
    			},
        		inv = {
      				name = "Invite",
      				desc = "Invite ",
      				type = "execute",
      				func = "Invite",
      				order = -1,
    			},
      		}
    	}
    },
}


function FdHrTO:OnInitialize()

    -- Called when the addon is loaded
end

function FdHrTO:OnEnable()
	self:Print("geladen")
  	--self.db = FdHrT:AddAddonDBDefaults(dbDefaults);
	FdHrT:AddAddonOptions(options);
  	self:RegisterEvent("RAID_TARGET_UPDATE")
	-- Called when the addon is enabled
end

function FdHrTO:RAID_TARGET_UPDATE()
	print("Raid_Update. convert:"..convert_to_raid)
    if convert_to_raid == 1 then
        ConvertToRaid();
        convert_to_raid = 0;
    end
end

function FdHrTO:PrintInvStatus(info)
  local mm = MissingRaidMembers();
  self:Print("Es fehlen: "..table.concat(mm, ", "))
end

function FdHrTO:GetMembers(info)
	return InvMembersString;
end

function FdHrTO:SetMembers(info, value)
	InvMembersString = value;
end

function FdHrTO:Invite(info, value)
	if IsInRaid() == false then
		convert_to_raid = 1;
		ConvertToRaid(); -- When Inviter is allready in a group we have to convert it allready, perhaps there are members that we don't neet to invite
	end
	for i, v in ipairs(MissingRaidMembers()) do
	    self:Print("inv: "..v)
	    InviteUnit(v);
	end
end

-- works only in raid not in party
function MissingRaidMembers()
	local mm = {}
	for i,v in ipairs({strsplit(",", InvMembersString)}) do
		if UnitInRaid(v) == nil then
			table.insert(mm,v)
		end
	end
	return mm;
end






