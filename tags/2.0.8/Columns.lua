-----------------------------
-- Get the addon table
-----------------------------

local AddonName, iFriends = ...;

local L = LibStub("AceLocale-3.0"):GetLocale(AddonName);

local LibCrayon = LibStub("LibCrayon-3.0");
local LibTourist = LibStub("LibTourist-3.0"); -- a really memory-eating lib.

local _G = _G; -- I always use _G.FUNC when I call a Global. Upvalueing done here.
local format = string.format;

local iconSize = 14;

-----------------------------------------
-- Variables, functions and colors
-----------------------------------------

local COLOR_GOLD = "|cfffed100%s|r";

--local FactionColors = {"00ff00", "EE1919", "247FAA"}; -- we define the faction hex colors for the faction columns.
--local FactionColors = {Horde = "EE1919", Alliance = "247FAA"};
--setmetatable(FactionColors, {__index = function() return "FED100" end});

--local FactionCity = {
--	LibStub("LibBabble-3.0").data["LibBabble-Zone-3.0"].current["Dalaran"],
--	LibStub("LibBabble-3.0").data["LibBabble-Zone-3.0"].current["Orgrimmar"],
--	LibStub("LibBabble-3.0").data["LibBabble-Zone-3.0"].current["Stormwind City"]
--};

local FactionMeta = {
	Horde = {
		Color = "EE1919",
		City  = LibStub("LibBabble-3.0").data["LibBabble-Zone-3.0"].current["Orgrimmar"]
	},
	Alliance = {
		Color = "247FAA",
		City  = LibStub("LibBabble-3.0").data["LibBabble-Zone-3.0"].current["Stormwind City"]
	}
};
setmetatable(FactionMeta, {
	__index = function(t, k)
		if( k == "Color" ) then
			return "FED100";
		elseif( k == "City" ) then
			return LibStub("LibBabble-3.0").data["LibBabble-Zone-3.0"].current["Dalaran"];
		end
	end
});

-----------------
-- Columns
-----------------

-- iFriends dynamically displays columns in the order defined by the user. That's why we need to set up a table containing column info.
-- Each key of the table is named by the internal column name and stores another table, which defines how the column will behave. Keys:
--   label: simply stores the displayed name of a column.
--   brush(v): the brush defines how content in a column-cell is displayed. v is Roster-data (see top of file)
--   canUse(v): this OPTIONAL function checks if a column can be displayed for the user. Returns 1 or nil.
--   script(anchor, v, button): defines the click handler of a column-cell. This is optional! v is Roster-data.
--   scriptUse(v): this OPTIONAL function will check if a click handler will be attached to the column-cell. v is Roster-data. Returns 1 or nil.
--   isBN: this OPTIONAL boolean indicates whether the column is for Battle.net friends only

iFriends.Columns = {
	realid = {
		label = L["RealID"],
		brush = function(member)
			return (_G.FRIENDS_BNET_NAME_COLOR_CODE.."%s|r"):format(member.realid);
		end,
		isBN = true,
	},
	realm = {
		label = L["Game/Realm"],
		brush = function(member)
			local icon = "";
			
			if( not member.isWoW ) then
				icon = member.game; -- forward compatbility :-P
				
				if( member.game == _G.BNET_CLIENT_SC2 ) then
					icon = "StarCraft 2";
					icon = (iFriends.db.Column.realm.Icon and "|TInterface\\FriendsFrame\\Battlenet-Sc2icon:"..iconSize..":"..iconSize.."|t "..icon or icon);
				elseif( member.game == _G.BNET_CLIENT_D3 ) then
					icon = "Diablo 3";
					icon = (iFriends.db.Column.realm.Icon and "|TInterface\\FriendsFrame\\Battlenet-D3icon:"..iconSize..":"..iconSize.."|t "..icon or icon);
				end
				
				return icon;
			end
			
			if( iFriends.db.Column.realm.Icon ) then
				if( member.faction == "Horde" or member.faction == "Alliance" ) then
					icon = "|TInterface\\FriendsFrame\\PlusManz-"..member.faction..":"..iconSize..":"..iconSize.."|t ";
				else
					icon = "|TInterface\\Addons\\iFriends\\Images\\FACTION-1:"..iconSize..":"..iconSize.."|t ";
				end
			end
			
			-- encolor by hostility
			if( iFriends.db.Column.realm.Color == 2 ) then
				--local r, g, b = LibTourist:GetFactionColor(FactionCity[member.faction +2]);
				local r, g, b = LibTourist:GetFactionColor(FactionMeta[member.faction].City);
				return ("%s|cff%02x%02x%02x%s|r"):format(icon, r *255, g *255, b *255, member.realm);
			-- encolor by faction
			elseif( iFriends.db.Column.realm.Color == 3 ) then
				--return ("%s|cff%s%s|r"):format(icon, FactionColors[member.faction], member.realm);
				return ("%s|cff%s%s|r"):format(icon, FactionMeta[member.faction].Color, member.realm);
			-- no color
			else
				return ("%s"..COLOR_GOLD):format(icon, member.realm);
			end
		end,
		isBN = true,
	},
	level = {
		label = _G.LEVEL,
		brush = function(member)
			if( not member.isWoW ) then
				return "";
			end
			
			-- encolor by difficulty
			if( iFriends.db.Column.level.Color == 2 ) then
				local c = _G.GetQuestDifficultyColor(member.level);
				return ("|cff%02x%02x%02x%s|r"):format(c.r *255, c.g *255, c.b *255, member.level);
			-- encolor by threshold
			elseif( iFriends.db.Column.level.Color == 3 ) then
				return ("|cff%s%s|r"):format(LibCrayon:GetThresholdHexColor(member.level, _G.MAX_PLAYER_LEVEL), member.level);
			-- no color
			else
				return (COLOR_GOLD):format(member.level);
			end
		end,
	},
	name = {
		label = _G.NAME,
		brush = function(member)
			if( not member.isWoW ) then
				return member.name;
			end
			
			-- encolor by class
			if( iFriends.db.Column.name.Color == 2 ) then
				return ("|c%s%s%s|r"):format(_G.RAID_CLASS_COLORS[member.CLASS].colorStr, member.status, member.name);
			-- no color
			else
				return (COLOR_GOLD):format( ("%s%s"):format(member.status, member.name) );
			end
		end,
		script = function(_, member, button)
			if( button == "LeftButton" ) then
				_G.SetItemRef(("player:%s"):format(member.name), ("|Hplayer:%s|h[%s]|h"):format(member.name, member.name), "LeftButton");
			end
		end,
		scriptUse = function(member) return member.realid and _G.CanCooperateWithToon(member.toon) end,
	},
	race = {
		label = _G.RACE,
		brush = function(member)
			if( not member.isWoW ) then
				return "";
			end
			
			local icon = "";
			
			if( iFriends.db.Column.race.Icon ) then
				if( member.faction == "Horde" or member.faction == "Alliance" ) then
					icon = "|TInterface\\FriendsFrame\\PlusManz-"..member.faction..":"..iconSize..":"..iconSize.."|t ";
				else
					icon = "|TInterface\\Addons\\iFriends\\Images\\FACTION-1:"..iconSize..":"..iconSize.."|t ";
				end
			end
			
			-- encolor by hostility
			if( iFriends.db.Column.race.Color == 2 ) then
				--local r, g, b = LibTourist:GetFactionColor(FactionCity[member.faction +2]);
				local r, g, b = LibTourist:GetFactionColor(FactionMeta[member.faction].City);
				return ("%s|cff%02x%02x%02x%s|r"):format(icon, r *255, g *255, b *255, member.race);
			-- encolor by faction
			elseif( iFriends.db.Column.race.Color == 3 ) then
				--return ("%s|cff%s%s|r"):format(icon, FactionColors[member.faction +2], member.race);
				return ("%s|cff%s%s|r"):format(icon, FactionMeta[member.faction].Color, member.race);
			-- no color
			else
				return ("%s"..COLOR_GOLD):format(icon, member.race);
			end
		end,
		isBN = true,
	},
	zone = {
		label = _G.ZONE,
		brush = function(member)
			if( not member.isWoW ) then
				return member.zone;
			end
			
			-- encolor by hostility
			local r, g, b = LibTourist:GetFactionColor(member.zone);
			return ("|cff%02x%02x%02x%s|r"):format(r *255, g *255, b *255, member.zone);
		end,
	},
	note = {
		label = L["Note"],
		brush = function(member)			
			return (COLOR_GOLD):format(member.note);
		end,
	},
	class = {
		label = _G.CLASS,
		brush = function(member)
			if( not member.isWoW ) then
				return "";
			end
			
			if( iFriends.db.Column.class.Icon ) then
				return "|TInterface\\Addons\\iFriends\\Images\\"..member.CLASS..":"..iconSize..":"..iconSize.."|t";
			end
			
			-- encolor by class
			if( iFriends.db.Column.class.Color == 2 ) then
				return ("|c%s%s|r"):format(_G.RAID_CLASS_COLORS[member.CLASS].colorStr, member.class);
			-- no color
			else
				return (COLOR_GOLD):format(member.class);
			end
		end,
	},
	broadcast = {
		label = L["Broadcast"],
		brush = function(member)
			return ("%s%s|r"):format(_G.FRIENDS_BNET_NAME_COLOR_CODE,
				(member.broadcast ~= "" and iFriends.db.Column.broadcast.Icon
				 and "|TInterface\\FriendsFrame\\BroadcastIcon:"..iconSize..":"..iconSize.."|t" or ""
				)
				..member.broadcast
			); 
		end,
		isBN = true,
	}
};
