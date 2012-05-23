-----------------------------
-- Get the addon table
-----------------------------

local AddonName = select(1, ...);
local iFriends = LibStub("AceAddon-3.0"):GetAddon(AddonName);

local L = LibStub("AceLocale-3.0"):GetLocale(AddonName);

---------------------------
-- Utility functions
---------------------------

-- a better strsplit function :)
local function strsplit(delimiter, text)
  local list = {}
  local pos = 1
  if strfind("", delimiter, 1) then -- this would result in endless loops
    --error("delimiter matches empty string!")
  end
  while 1 do
    local first, last = strfind(text, delimiter, pos)
    if first then -- found?
      tinsert(list, strsub(text, pos, first-1))
      pos = last+1
    else
      tinsert(list, strsub(text, pos))
      break
    end
  end
  return list
end

---------------------------------
-- The configuration table
---------------------------------

function iFriends:GetConfigColumns()
	self.ConfigColumns = strsplit(",%s*", self.db.Display);
end

local function CreateConfig()
	CreateConfig = nil; -- we just need this function once, thus removing it from memory.
	
	local db = {
		type = "group",
		name = AddonName,
		order = 1,
		get = function(info)
			return iFriends.db.Column[info.arg.k][info.arg.v];
		end,
		set = function(info, value, arg)
			iFriends.db.Column[info.arg.k][info.arg.v] = value;
		end,
		args = {
			Infotext1 = {
				type = "description",
				name = L["iFriends provides some pre-layoutet columns for character names, zones, etc. In order to display them in the tooltip, write their names in the desired order into the beneath input."].."\n",
				fontSize = "medium",
				order = 1,
			},
			Infotext2 = {
				type = "description",
				name = "",
				fontSize = "medium",
				order = 2,
			},
			Display = {
				type = "input",
				name = "",
				order = 3,
				width = "full",
				validate = function(info, value)
					local list = strsplit(",%s*", value);
					for i = 1, #list do
						if( not iFriends.Columns[list[i]] ) then
							return L["Invalid column name!"];
						end
					end
					return true;
				end,
				get = function(info)
					return iFriends.db.Display;
				end,
				set = function(info, value)
					iFriends.db.Display = value;
					iFriends:GetConfigColumns();
					iFriends:GetDisplayedColumns();
				end,
			},
			Spacer1 = {
				type = "description",
				name = " ",
				order = 4,
			},
			Column_realid = {
				type = "group",
				name = L["RealID"],
				order = 5,
				args = {
					ShowLabel = {
						type = "toggle",
						name = L["Show Label"],
						order = 1,
						arg = {k = "realid", v = "ShowLabel"},
					},
					Justification = {
						type = "select",
						name = L["Justification"],
						order = 2,
						values = {
							["LEFT"] = L["Left"],
							["CENTER"] = L["Center"],
							["RIGHT"] = L["Right"],
						},
						arg = {k = "realid", v = "Align"},
					},
				},
			},
			Column_realm = {
				type = "group",
				name = L["Game/Realm"],
				order = 6,
				args = {
					ShowLabel = {
						type = "toggle",
						name = L["Show Label"],
						order = 1,
						arg = {k = "realm", v = "ShowLabel"},
					},
					Justification = {
						type = "select",
						name = L["Justification"],
						order = 2,
						values = {
							["LEFT"] = L["Left"],
							["CENTER"] = L["Center"],
							["RIGHT"] = L["Right"],
						},
						arg = {k = "realm", v = "Align"},
					},
					UseIcon = {
						type = "toggle",
						name = L["Use Icon"],
						order = 3,
						arg = {k = "realm", v = "Icon"},
					},
					ColorOption = {
						type = "select",
						name = _G.COLOR,
						order = 4,
						values = {
							[1] = _G.NONE,
							[2] = L["By Hostility"],
							[3] = L["By Faction"],
						},
						arg = {k = "realm", v = "Color"},
					},
				},
			},
			Column_level = {
				type = "group",
				name = L["Level"],
				order = 7,
				args = {
					ShowLabel = {
						type = "toggle",
						name = L["Show Label"],
						order = 1,
						arg = {k = "level", v = "ShowLabel"},
					},
					Justification = {
						type = "select",
						name = L["Justification"],
						order = 2,
						values = {
							["LEFT"] = L["Left"],
							["CENTER"] = L["Center"],
							["RIGHT"] = L["Right"],
						},
						arg = {k = "level", v = "Align"},
					},
					ColorOption = {
						type = "select",
						name = _G.COLOR,
						order = 3,
						values = {
							[1] = _G.NONE,
							[2] = L["By Difficulty"],
							[3] = L["By Threshold"],
						},
						arg = {k = "level", v = "Color"},
					},
				},
			},
			Column_name = {
				type = "group",
				name = _G.NAME,
				order = 8,
				args = {
					ShowLabel = {
						type = "toggle",
						name = L["Show Label"],
						order = 1,
						arg = {k = "name", v = "ShowLabel"},
					},
					Justification = {
						type = "select",
						name = L["Justification"],
						order = 2,
						values = {
							["LEFT"] = L["Left"],
							["CENTER"] = L["Center"],
							["RIGHT"] = L["Right"],
						},
						arg = {k = "name", v = "Align"},
					},
					ColorOption = {
						type = "select",
						name = _G.COLOR,
						order = 3,
						values = {
							[1] = _G.NONE,
							[2] = L["By Class"],
						},
						arg = {k = "name", v = "Color"},
					},
				},
			},
			Column_race = {
				type = "group",
				name = _G.RACE,
				order = 9,
				args = {
					ShowLabel = {
						type = "toggle",
						name = L["Show Label"],
						order = 1,
						arg = {k = "race", v = "ShowLabel"},
					},
					Justification = {
						type = "select",
						name = L["Justification"],
						order = 2,
						values = {
							["LEFT"] = L["Left"],
							["CENTER"] = L["Center"],
							["RIGHT"] = L["Right"],
						},
						arg = {k = "race", v = "Align"},
					},
					ColorOption = {
						type = "select",
						name = _G.COLOR,
						order = 3,
						values = {
							[1] = _G.NONE,
							[2] = L["By Hostility"],
						},
						arg = {k = "race", v = "Color"},
					},
				},
			},
			Column_zone = {
				type = "group",
				name = _G.ZONE,
				order = 10,
				args = {
					ShowLabel = {
						type = "toggle",
						name = L["Show Label"],
						order = 1,
						arg = {k = "zone", v = "ShowLabel"},
					},
					Justification = {
						type = "select",
						name = L["Justification"],
						order = 2,
						values = {
							["LEFT"] = L["Left"],
							["CENTER"] = L["Center"],
							["RIGHT"] = L["Right"],
						},
						arg = {k = "zone", v = "Align"},
					},
				},
			},
			Column_note = {
				type = "group",
				name = L["Note"],
				order = 5,
				args = {
					ShowLabel = {
						type = "toggle",
						name = L["Show Label"],
						order = 1,
						arg = {k = "note", v = "ShowLabel"},
					},
					Justification = {
						type = "select",
						name = L["Justification"],
						order = 2,
						values = {
							["LEFT"] = L["Left"],
							["CENTER"] = L["Center"],
							["RIGHT"] = L["Right"],
						},
						arg = {k = "note", v = "Align"},
					},
				},
			},
			Column_class = {
				type = "group",
				name = _G.CLASS,
				order = 6,
				args = {
					ShowLabel = {
						type = "toggle",
						name = L["Show Label"],
						order = 1,
						arg = {k = "class", v = "ShowLabel"},
					},
					Justification = {
						type = "select",
						name = L["Justification"],
						order = 2,
						values = {
							["LEFT"] = L["Left"],
							["CENTER"] = L["Center"],
							["RIGHT"] = L["Right"],
						},
						arg = {k = "class", v = "Align"},
					},
					UseIcon = {
						type = "toggle",
						name = L["Use Icon"],
						order = 3,
						arg = {k = "class", v = "Icon"},
					},
					ColorOption = {
						type = "select",
						name = _G.COLOR,
						order = 4,
						values = {
							[1] = _G.NONE,
							[2] = L["By Class"],
						},
						arg = {k = "class", v = "Color"},
					},
				},
			},
			Column_broadcast = {
				type = "group",
				name = L["Broadcast"],
				order = 7,
				args = {
					ShowLabel = {
						type = "toggle",
						name = L["Show Label"],
						order = 1,
						arg = {k = "broadcast", v = "ShowLabel"},
					},
					Justification = {
						type = "select",
						name = L["Justification"],
						order = 2,
						values = {
							["LEFT"] = L["Left"],
							["CENTER"] = L["Center"],
							["RIGHT"] = L["Right"],
						},
						arg = {k = "broadcast", v = "Align"},
					},
				},
			},
		},
	};
	
	local colnames = {};
	for k, _ in pairs(iFriends.Columns) do
		table.insert(colnames, k);
	end
	
	db.args.Infotext2.name = ("%s: |cfffed100%s|r\n"):format(
		L["Available columns"],
		table.concat(colnames, ", ")
	);
	
	return db;
end

function iFriends:CreateDB()
	iFriends.CreateDB = nil;
	
	return { profile = {
		Display = "realid, realm, level, name, race, zone, broadcast",
		Column = {
			realid = {
				ShowLabel = true,
				Align = "LEFT",
			},
			realm = {
				ShowLabel = true,
				Align = "CENTER",
				Color = 3,
				Icon = false,
			},
			level = {
				ShowLabel = false,
				Align = "RIGHT",
				Color = 2,
			},
			name = {
				ShowLabel = true,
				Align = "LEFT",
				Color = 2,
			},
			race = {
				ShowLabel = true,
				Align = "CENTER",
				Color = 1,
			},
			zone = {
				ShowLabel = true,
				Align = "CENTER",
			},
			note = {
				ShowLabel = true,
				Align = "LEFT",
			},
			class = {
				ShowLabel = true,
				Align = "LEFT",
				Icon = true,
				Color = 2,
			},
			broadcast = {
				ShowLabel = true,
				Align = "LEFT",
			},
		},
	}};
end

function iFriends:OpenOptions()
	_G.InterfaceOptionsFrame_OpenToCategory(AddonName);
end

LibStub("AceConfig-3.0"):RegisterOptionsTable(AddonName, CreateConfig);
LibStub("AceConfigDialog-3.0"):AddToBlizOptions(AddonName);
_G.SlashCmdList["IFRIENDS"] = iFriends.OpenOptions;
_G["SLASH_IFRIENDS1"] = "/ifriends";