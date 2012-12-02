-----------------------------
-- Get the addon table
-----------------------------

local AddonName, iFriends = ...;

local L = LibStub("AceLocale-3.0"):GetLocale(AddonName);

local _G = _G; -- I always use _G.FUNC when I call a Global. Upvalueing done here.
local format = string.format;

-----------------------------------------
-- Variables, functions and colors
-----------------------------------------

local cfg; -- this stores our configuration GUI

local COLOR_RED  = "|cffff0000%s|r";
local COLOR_GREEN= "|cff00ff00%s|r";

---------------------------
-- The options table
---------------------------

function iFriends:CreateDB()
	iFriends.CreateDB = nil;
	
	return { profile = {
		Display = "realid, level, class, name, race, zone, broadcast",
		DisplayWoWFriends = true,
		ShowNumBNetFriends = false,
		ShowLabelsWoW = true, -- this option is set by the mod itself
		ShowLabelsBN = true, -- this option is set by the mod itself
		Column = {
			realid = {
				ShowLabel = true,
				Align = "LEFT",
			},
			battletag = {
				ShowLabel = false,
				Align = "LEFT",
			},
			realm = {
				ShowLabel = true,
				Align = "LEFT",
				Color = 3,
				Icon = true,
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
				EnableScript = true,
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
				ShowLabel = false,
				Align = "LEFT",
				Icon = true,
				Color = 2,
			},
			broadcast = {
				ShowLabel = true,
				Align = "LEFT",
				Icon = true,
			},
		},
	}};
end

---------------------------------
-- The configuration table
---------------------------------

local function sort_colored_columns(a, b) return a < b end
local function show_colored_columns()
	local cols = {};
	
	for k, _ in pairs(iFriends.Columns) do
		table.insert(cols, (_G.tContains(iFriends.DisplayedColumns, k) and COLOR_GREEN or COLOR_RED):format(k) );
	end
	table.sort(cols, sort_colored_columns);
	
	cfg.args.Infotext2.name = ("%s: |cfffed100%s|r\n"):format(
		L["Available columns"],
		table.concat(cols, ", ")
	);
	
	local clean, prefix, suffix;
	for i, v in ipairs(cols) do
		clean  = v:sub(11,-3); -- **
		prefix = v:sub(1, 10); -- since I formatted the string to spare out another table, we need some CPU here. :-P
		suffix = v:sub(-3, 0); -- **
		cfg.args["Column_"..clean].name = prefix..iFriends.Columns[clean].label..suffix;
	end
end
-- for usage once
iFriends.show_colored_columns = show_colored_columns;

local function check_labels_hide()
	-- check battle.net columns
	local show = false;
	
	for i, v in ipairs(iFriends.DisplayedColumns) do
		if( iFriends.db.Column[v].ShowLabel ) then
			show = true;
			break;
		end
	end
	iFriends.db.ShowLabelsBN = show;
	
	-- check local friend columns
	show = false;
	
	for i, v in ipairs(iFriends.DisplayedColumnsLocal) do
		if( iFriends.db.Column[v].ShowLabel ) then
			show = true;
			break;
		end
	end
	iFriends.db.ShowLabelsWoW = show;
end

cfg = {
		type = "group",
		name = AddonName,
		order = 1,
		get = function(info)
			if( not info.arg ) then
				return iFriends.db[info[#info]];
			else
				return iFriends.db.Column[info.arg.k][info.arg.v];
			end
		end,
		set = function(info, value)
			if( not info.arg ) then
				iFriends.db[info[#info]] = value;
			else
				iFriends.db.Column[info.arg.k][info.arg.v] = value;
				if( info[#info] == "ShowLabel" ) then
					check_labels_hide();
				end
			end
		end,
		args = {
			Header1 = {
				type = "header",
				name = L["General Options"],
				order = 2,
			},
			DisplayWoWFriends = {
				type = "toggle",
				name = L["Display WoW Friends in another Tooltip"],
				order = 5,
				width = "full",
			},
			ShowNumBNetFriends = {
				type = "toggle",
				name = L["Display the number of your Battle.net friends on the plugin"],
				order = 10,
				width = "full"
			},
			Spacer2 = {
				type = "description",
				name = " ",
				fontSize = "small",
				order = 20,
			},
			Header2 = {
				type = "header",
				name = L["Tooltip Options"],
				order = 30,
			},
			Infotext1 = {
				type = "description",
				name = L["iFriends provides some pre-layoutet columns for character names, zones, etc. In order to display them in the tooltip, write their names in the desired order into the beneath input."].."\n",
				fontSize = "medium",
				order = 40,
			},
			Infotext2 = {
				type = "description",
				name = "",
				fontSize = "medium",
				order = 50,
			},
			Display = {
				type = "input",
				name = "",
				order = 60,
				width = "full",
				validate = function(info, value)
					local list = {strsplit(",", value)};
					
					for i, v in ipairs(list) do
						if( not iFriends.Columns[strtrim(v)] ) then
							_G.StaticPopup_Show("IADDONS_ERROR_CFG");
							return L["Invalid column name!"];
						end
					end
					
					return true;
				end,
				set = function(info, value)
					iFriends.db.Display = value;
					iFriends:GetDisplayedColumns();
					show_colored_columns();
				end,
			},
			Spacer1 = {
				type = "description",
				name = " ",
				order = 70,
			},
			Column_realid = {
				type = "group",
				name = "",
				order = 80,
				args = {
					Infotext = {
						type = "description",
						name = L["Displays the RealID of your Battle.net friends."].."\n",
						order = 1,
						fontSize = "medium",
					},
					ShowLabel = {
						type = "toggle",
						name = L["Show Label"],
						order = 5,
						arg = {k = "realid", v = "ShowLabel"},
					},
					Justification = {
						type = "select",
						name = L["Justification"],
						order = 10,
						values = {
							["LEFT"] = L["Left"],
							["CENTER"] = L["Center"],
							["RIGHT"] = L["Right"],
						},
						arg = {k = "realid", v = "Align"},
					},
				},
			},
			Column_battletag = {
				type = "group",
				name = "",
				order = 81,
				args = {
					Infotext = {
						type = "description",
						name = L["Displays the BattleTag of your Battle.net friends."].."\n",
						order = 1,
						fontSize = "medium",
					},
					ShowLabel = {
						type = "toggle",
						name = L["Show Label"],
						order = 5,
						arg = {k = "battletag", v = "ShowLabel"},
					},
					Justification = {
						type = "select",
						name = L["Justification"],
						order = 10,
						values = {
							["LEFT"] = L["Left"],
							["CENTER"] = L["Center"],
							["RIGHT"] = L["Right"],
						},
						arg = {k = "battletag", v = "Align"},
					},
				},
			},
			Column_realm = {
				type = "group",
				name = "",
				order = 90,
				args = {
					Infotext = {
						type = "description",
						name = L["Displays the logged on realm of your Battle.net friends."].."\n",
						order = 1,
						fontSize = "medium",
					},
					ShowLabel = {
						type = "toggle",
						name = L["Show Label"],
						order = 5,
						arg = {k = "realm", v = "ShowLabel"},
					},
					Justification = {
						type = "select",
						name = L["Justification"],
						order = 10,
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
						order = 15,
						arg = {k = "realm", v = "Icon"},
					},
					ColorOption = {
						type = "select",
						name = _G.COLOR,
						order = 20,
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
				name = "",
				order = 100,
				args = {
					Infotext = {
						type = "description",
						name = L["Displays the level of your friends."].."\n",
						order = 1,
						fontSize = "medium",
					},
					ShowLabel = {
						type = "toggle",
						name = L["Show Label"],
						order = 5,
						arg = {k = "level", v = "ShowLabel"},
					},
					Justification = {
						type = "select",
						name = L["Justification"],
						order = 10,
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
						order = 15,
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
				name = "",
				order = 110,
				args = {
					Infotext = {
						type = "description",
						name = L["Displays the name of your friends. In addition, a short info is shown if they are AFK or DND."].."\n",
						order = 1,
						fontSize = "medium",
					},
					ShowLabel = {
						type = "toggle",
						name = L["Show Label"],
						order = 5,
						arg = {k = "name", v = "ShowLabel"},
					},
					Justification = {
						type = "select",
						name = L["Justification"],
						order = 10,
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
						order = 15,
						values = {
							[1] = _G.NONE,
							[2] = L["By Class"],
						},
						arg = {k = "name", v = "Color"},
					},
					EnableScript = {
						type = "toggle",
						name = L["Enable Script"],
						desc = L["If activated, clicking on the given cell will result in something special."],
						order = 20,
						width = "full",
						arg = {k = "name", v = "EnableScript"},
					},
				},
			},
			Column_race = {
				type = "group",
				name = "",
				order = 120,
				args = {
					Infotext = {
						type = "description",
						name = L["Displays the race of your Battle.net friends."].."\n",
						order = 1,
						fontSize = "medium",
					},
					ShowLabel = {
						type = "toggle",
						name = L["Show Label"],
						order = 5,
						arg = {k = "race", v = "ShowLabel"},
					},
					Justification = {
						type = "select",
						name = L["Justification"],
						order = 10,
						values = {
							["LEFT"] = L["Left"],
							["CENTER"] = L["Center"],
							["RIGHT"] = L["Right"],
						},
						arg = {k = "race", v = "Align"},
					},
					UseIcon = {
						type = "toggle",
						name = L["Use Icon"],
						order = 15,
						arg = {k = "race", v = "Icon"},
					},
					ColorOption = {
						type = "select",
						name = _G.COLOR,
						order = 20,
						values = {
							[1] = _G.NONE,
							[2] = L["By Hostility"],
							[3] = L["By Faction"],
						},
						arg = {k = "race", v = "Color"},
					},
				},
			},
			Column_zone = {
				type = "group",
				name = "",
				order = 130,
				args = {
					Infotext = {
						type = "description",
						name = L["Displays the zone of your friends."].."\n",
						order = 1,
						fontSize = "medium",
					},
					ShowLabel = {
						type = "toggle",
						name = L["Show Label"],
						order = 5,
						arg = {k = "zone", v = "ShowLabel"},
					},
					Justification = {
						type = "select",
						name = L["Justification"],
						order = 10,
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
				name = "",
				order = 140,
				args = {
					Infotext = {
						type = "description",
						name = L["Displays the individual note of your friends."].."\n",
						order = 1,
						fontSize = "medium",
					},
					ShowLabel = {
						type = "toggle",
						name = L["Show Label"],
						order = 5,
						arg = {k = "note", v = "ShowLabel"},
					},
					Justification = {
						type = "select",
						name = L["Justification"],
						order = 10,
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
				name = "",
				order = 150,
				args = {
					Infotext = {
						type = "description",
						name = L["Displays the class of your friends. Choose whether to show the class name or the class icon."].."\n",
						order = 1,
						fontSize = "medium",
					},
					ShowLabel = {
						type = "toggle",
						name = L["Show Label"],
						order = 5,
						arg = {k = "class", v = "ShowLabel"},
					},
					Justification = {
						type = "select",
						name = L["Justification"],
						order = 10,
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
						order = 15,
						arg = {k = "class", v = "Icon"},
					},
					ColorOption = {
						type = "select",
						name = _G.COLOR,
						order = 20,
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
				name = "",
				order = 160,
				args = {
					Infotext = {
						type = "description",
						name = L["Displays the last broadcast message of your Battle.net friends."].."\n",
						order = 1,
						fontSize = "medium",
					},
					ShowLabel = {
						type = "toggle",
						name = L["Show Label"],
						order = 5,
						arg = {k = "broadcast", v = "ShowLabel"},
					},
					Justification = {
						type = "select",
						name = L["Justification"],
						order = 10,
						values = {
							["LEFT"] = L["Left"],
							["CENTER"] = L["Center"],
							["RIGHT"] = L["Right"],
						},
						arg = {k = "broadcast", v = "Align"},
					},
					UseIcon = {
						type = "toggle",
						name = L["Use Icon"],
						order = 15,
						arg = {k = "broadcast", v = "Icon"},
					},
				},
			},
		},
};
show_colored_columns();

function iFriends:OpenOptions()
	_G.InterfaceOptionsFrame_OpenToCategory(AddonName);
end

LibStub("AceConfig-3.0"):RegisterOptionsTable(AddonName, cfg);
LibStub("AceConfigDialog-3.0"):AddToBlizOptions(AddonName);
_G.SlashCmdList["IFRIENDS"] = iFriends.OpenOptions;
_G["SLASH_IFRIENDS1"] = "/ifriends";

_G.StaticPopupDialogs["IADDONS_ERROR_CFG"] = {
	preferredIndex = 3, -- apparently avoids some UI taint
	text = L["Invalid column name!"],
	button1 = _G.OKAY,
	showAlert = 1,
	timeout = 2.5,
	hideOnEscape = true,
};