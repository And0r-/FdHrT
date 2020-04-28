FdHrT = LibStub("AceAddon-3.0"):NewAddon("FdHrT", "AceConsole-3.0")

local InvMembersString = "";

FdHOptions = { 
    name = "FdHrT",
    handler = FdHrT,
    type = "group",
    childGroups = "tab",
    args = {

        
    },
}

local FdHDbDefaults = {
	profile = {
		['**'] = {
			enabled = false
		}
	}
}

function FdHrT:OnInitialize()
	self:RegisterChatCommand("rl", function() ReloadUI() end)
	FdHrT:AddAddonDBDefaults();
    FdHrT:AddAddonOptions();
	self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("FdHrT", "FdH Raid Tool")
	self:RegisterChatCommand("fdh", "ChatCommand")
    -- Called when the addon is loaded
end

function FdHrT:OnEnable()
	self:Print("geladen")
	-- Called when the addon is enabled
end


function FdHrT:AddAddonDBDefaults(dbDefaults)
	if dbDefaults then
		FdHDbDefaults = FdHrT:tableMerge(FdHDbDefaults, dbDefaults)
	end

	self.db = LibStub("AceDB-3.0"):New("FdHrTDB", FdHDbDefaults, true)
	FdHOptions.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
	return self.db
end

function FdHrT:AddAddonOptions(options)
	if options then
		FdHOptions = FdHrT:tableMerge(FdHOptions, options)
	end

	LibStub("AceConfig-3.0"):RegisterOptionsTable("FdHrT", FdHOptions)
end

function FdHrT:ChatCommand(input)
    if not input or input:trim() == "" then
        InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
        InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
    else
        LibStub("AceConfigCmd-3.0"):HandleCommand("fdh", "FdHrT", input)
    end
end


function FdHrT:tableMerge(t1, t2)
    for k,v in pairs(t2) do
        if type(v) == "table" then
            if type(t1[k] or false) == "table" then
                FdHrT:tableMerge(t1[k] or {}, t2[k] or {})
            else
                t1[k] = v
            end
        else
            t1[k] = v
        end
    end
    return t1
end


