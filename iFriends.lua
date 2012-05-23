--
-- iFriends - WoW LDB plugin
-- written by Tobias Schulz (grdn) 2011, EU-Onyxia (Germany)
--
-- It's no rewrite of an existing addon. My mods are completely selfmade.
-- If there are things that could be made better, feel free to contact me.
-- wow-addons@grdn.eu
--

-----------------------------------
-- Setting up scope, upvalues and libs
-----------------------------------

local AddonName = select(1, ...);
iFriends = LibStub("AceAddon-3.0"):NewAddon(AddonName, "AceEvent-3.0");

local L = LibStub("AceLocale-3.0"):GetLocale(AddonName);

local LibQTip = LibStub("LibQTip-1.0");
local LibTourist = LibStub("LibTourist-3.0");
local LibCrayon = LibStub("LibCrayon-3.0");

local _G = _G; -- I always use _G.FUNC when I call a Global. Upvalueing done here.

-----------------------------------------
-- Variables, functions and colors
-----------------------------------------

local Tooltip; -- out tooltip
local MAX_LEVEL = 85; -- really dirty here, but it doesn't need to be set once a week, so... GET USED TO IT!

local COLOR_GOLD = "|cfffed100%s|r";
local COLOR_BNET = _G.FRIENDS_BNET_NAME_COLOR_CODE;

local FactionColors = {"EE1919", "247FAA"}; -- we define the faction hex colors for the faction columns.

-- the Roster table, which is the basic data storage of iFriends. To save memory, data is stored by index, not by key.
-- To prevent using constructs like Roster[4] for selecting a Level, we set some names for the indexes. Looks like a table with keys now!
local Roster = {};
local ROSTER_BNET = 1;
local ROSTER_GAME = 2;
local ROSTER_CHAR_NAME = 3;
local ROSTER_CHAR_LEVEL = 4;
local ROSTER_CHAR_CLASS = 5;
local ROSTER_CHAR_ZONE = 6;
local ROSTER_CHAR_STATUS = 7;
local ROSTER_CHAR_NOTE = 8;
local ROSTER_CHAR_REALM = 9;
local ROSTER_CHAR_RACE = 10;
local ROSTER_CHAR_FACTION = 11;
local ROSTER_BNET_BROADCAST = 12;
local ROSTER_BNET_REALID = 13;
local ROSTER_BNET_PID = 14;
local ROSTER_BNET_TOONID = 15;
---------------------------------------------------------------

local ClassColors = {};
local ClassLoc = {};
for k, v in pairs(_G.LOCALIZED_CLASS_NAMES_MALE) do
	local c = _G.RAID_CLASS_COLORS[k];
	ClassColors[v] = ("|cff%02x%02x%02x"):format(c.r *255, c.g *255, c.b *255);
	ClassLoc[v] = k;
end
for k, v in pairs(_G.LOCALIZED_CLASS_NAMES_FEMALE) do
	local c = _G.RAID_CLASS_COLORS[k];
	ClassColors[v] = ("|cff%02x%02x%02x"):format(c.r *255, c.g *255, c.b *255);
	ClassLoc[v] = k;
end

-- this is my try to clean up some memory.
local function tclear(t, wipe)
	if( type(t) ~= "table" ) then return end;
	for k in pairs(t) do
		t[k] = nil;
	end
	t[''] = 1;
	t[''] = nil;
	if( wipe ) then
		t = nil;
	end
end

-----------------------------
-- Setting up the feed
-----------------------------

iFriends.Feed = LibStub("LibDataBroker-1.1"):NewDataObject(AddonName, {
	type = "data source",
	text = "",
	icon = "Interface\\Addons\\iFriends\\Images\\iFriends",
});

iFriends.Feed.OnClick = function(_, button)
	if( button == "LeftButton" ) then
		-- alt + left click = add new friend
		-- I borrowed the following code snippet from the original WoW UI - (c) Blizzard
		if( _G.IsAltKeyDown() ) then
			if( _G.BNFeaturesEnabled() ) then
				_G.AddFriendEntryFrame_Collapse(true);
				_G.AddFriendFrame.editFocus = _G.AddFriendNameEditBox;
				_G.StaticPopupSpecial_Show(_G.AddFriendFrame);
				if( _G.GetCVarBool("addFriendInfoShown") ) then
					_G.AddFriendFrame_ShowEntry();
				else
					_G.AddFriendFrame_ShowInfo();
				end
			else
				_G.StaticPopup_Show("ADD_FRIEND");
			end
		-- left click = open friends frame
		else
			_G.ToggleFriendsFrame(1);
		end
		-- thanks Blizzard
		
	-- right click will open iFriends options
	elseif( button == "RightButton" ) then
		iFriends:OpenOptions();
	end
end

iFriends.Feed.OnEnter = function(anchor)
	if( #Roster < 1 ) then
		return; -- when no friends are present, we won't show a tooltip (I dislike that!).
	end
	
	-- LibQTip has the power to show one or more tooltips, but on a broker bar, where more than one QTips are present, this is really disturbing.
	-- So we release the tooltips of the i-Addons here.
	for k, v in LibQTip:IterateTooltips() do
		if( type(k) == "string" and strsub(k, 1, 6) == "iSuite" ) then
			v:Release(k);
		end
	end
	
	_G.ShowFriends();
	Tooltip = LibQTip:Acquire("iSuite"..AddonName);
	Tooltip:SetAutoHideDelay(0.1, anchor);
	Tooltip:SmartAnchorTo(anchor);
	iFriends:UpdateTooltip();
	Tooltip:Show();
end

-----------------
-- Columns
-----------------

local player_realm = _G.GetRealmName(); -- we need our realm for later usage.
local factioncity = {L["Hordecity"], L["Allycity"]}; -- helps us determining hostility colors

-- iFriends dynamically displays columns in the order defined by the user. That's why we need to set up a table containing column info.
-- Each key of the table is named by the internal column name and stores another table, which defines how the column will behave. Keys:
--   Label: simply stores the displayed name of a column.
--   Brush(v): the brush defines how content in a column-cell is displayed. v is Roster-data (see top of file)
--   CanUse(v): this OPTIONAL function checks if a column can be displayed for the user. Returns 1 or nil.
--   Script(anchor, v, button): defines the click handler of a column-cell. This is optional! v is Roster-data.
--   ScriptUse(v): this OPTIONAL function will check if a click handler will be attached to the column-cell. v is Roster-data. Returns 1 or nil.

iFriends.Columns = {
	realid = {
		Label = L["RealID"],
		Brush = function(v)
			if( v[ROSTER_BNET] ) then
				return (COLOR_BNET.."%s|r"):format(v[ROSTER_BNET_REALID]);
			else
				return ("%s%s|r"):format(_G.FRIENDS_OTHER_NAME_COLOR_CODE, L["local friend"]);
			end
		end,
	},
	realm = {
		Label = L["Game/Realm"],
		Brush = function(v)
			if( v[ROSTER_GAME] ~= _G.BNET_CLIENT_WOW ) then
				if( v[ROSTER_GAME] == _G.BNET_CLIENT_SC2 ) then
					return (iFriends.db.Column.realm.Icon and "|TInterface\\Addons\\iFriends\\Images\\S2:14:14|t " or "").."Starcraft 2";
				elseif( v[ROSTER_GAME] == "D3" ) then
					return (iFriends.db.Column.realm.Icon and "|TInterface\\Addons\\iFriends\\Images\\D3:14:14|t " or "").."Diablo 3";
				else
					return v[ROSTER_GAME];
				end
				return "";
			end
			
			if( v[ROSTER_BNET] ) then
				local icon = iFriends.db.Column.realm.Icon and "|TInterface\\Addons\\iFriends\\Images\\FACTION"..v[ROSTER_CHAR_FACTION]..":14:14|t" or "";
				if( icon ) then
					icon = icon.." ";
				end
				
				-- encolor by hostility
				if( iFriends.db.Column.realm.Color == 2 ) then
					local r, g, b = LibTourist:GetFactionColor(factioncity[v[ROSTER_CHAR_FACTION] +1]);
					return ("%s|cff%02x%02x%02x%s|r"):format(icon, r *255, g *255, b *255, v[ROSTER_CHAR_REALM]);
				-- encolor by faction
				elseif( iFriends.db.Column.realm.Color == 3 ) then
					return ("%s|cff%s%s|r"):format(icon, FactionColors[v[ROSTER_CHAR_FACTION] +1], v[ROSTER_CHAR_REALM]);
				-- no color
				else
					return ("%s"..COLOR_GOLD):format(icon, v[ROSTER_CHAR_REALM]);
				end
			else
				return "";
			end
		end,
	},
	level = {
		Label = L["Level"],
		Brush = function(v)
			if( v[ROSTER_GAME] ~= _G.BNET_CLIENT_WOW ) then
				return "";
			end
			
			-- encolor by difficulty
			if( iFriends.db.Column.level.Color == 2 ) then
				local c = _G.GetQuestDifficultyColor(v[ROSTER_CHAR_LEVEL]);
				return ("|cff%02x%02x%02x%s|r"):format(c.r *255, c.g *255, c.b *255, v[ROSTER_CHAR_LEVEL]);
			-- encolor by threshold
			elseif( iFriends.db.Column.level.Color == 3 ) then
				return ("|cff%s%s|r"):format(LibCrayon:GetThresholdHexColor(v[ROSTER_CHAR_LEVEL], MAX_LEVEL), v[ROSTER_CHAR_LEVEL]);
			-- no color
			else
				return (COLOR_GOLD):format(v[ROSTER_CHAR_LEVEL]);
			end
		end,
	},
	name = {
		Label = _G.NAME,
		Brush = function(v)
			if( v[ROSTER_GAME] ~= _G.BNET_CLIENT_WOW ) then
				return "";
			end
			
			-- encolor by class
			if( iFriends.db.Column.name.Color == 2 ) then
				local c = _G.RAID_CLASS_COLORS[v[ROSTER_CHAR_CLASS]];
				return ("%s%s%s|r"):format(ClassColors[v[ROSTER_CHAR_CLASS]], v[ROSTER_CHAR_STATUS] or "", v[ROSTER_CHAR_NAME]);
			-- no color
			else
				return (COLOR_GOLD):format( ("%s%s"):format(v[ROSTER_CHAR_STATUS] or "", v[ROSTER_CHAR_NAME]) );
			end
		end,
		Script = function(_, v, button)
			if( button == "LeftButton" ) then
				_G.SetItemRef(("player:%s"):format(v[ROSTER_CHAR_NAME]), ("|Hplayer:%s|h[%s]|h"):format(v[ROSTER_CHAR_NAME], v[ROSTER_CHAR_NAME]), "LeftButton");
			end
		end,
		ScriptUse = function(v) return v[ROSTER_BNET] and _G.CanCooperateWithToon(v[ROSTER_BNET_TOONID]) end,
	},
	race = {
		Label = _G.RACE,
		Brush = function(v)
			if( v[ROSTER_GAME] == _G.BNET_CLIENT_WOW and v[ROSTER_BNET] ) then
				-- encolor by hostility
				if( iFriends.db.Column.race.Color == 2 ) then
					local r, g, b = LibTourist:GetFactionColor(factioncity[v[ROSTER_CHAR_FACTION] +1]);
					return ("|cff%02x%02x%02x%s|r"):format(r *255, g *255, b *255, v[ROSTER_CHAR_RACE]);
				-- no color
				else
					return (COLOR_GOLD):format(v[ROSTER_CHAR_RACE]);
				end
			end
			
			return "";
		end,
	},
	zone = {
		Label = _G.ZONE,
		Brush = function(v)
			if( v[ROSTER_GAME] ~= _G.BNET_CLIENT_WOW ) then
				return "";
			end
			
			-- encolor by hostility
			local r, g, b = LibTourist:GetFactionColor(v[ROSTER_CHAR_ZONE]);
			return ("|cff%02x%02x%02x%s|r"):format(r *255, g *255, b *255, v[ROSTER_CHAR_ZONE]);
		end,
	},
	note = {
		Label = L["Note"],
		Brush = function(v)
			if( v[ROSTER_CHAR_NOTE] ) then
				return (COLOR_GOLD):format(v[ROSTER_CHAR_NOTE]);
			end
			
			return "";
		end,
	},
	class = {
		Label = _G.CLASS,
		Brush = function(v)
			if( v[ROSTER_GAME] ~= _G.BNET_CLIENT_WOW ) then
				return "";
			end
			
			if( iFriends.db.Column.class.Icon == true ) then
				return "|TInterface\\Addons\\iFriends\\Images\\"..ClassLoc[v[ROSTER_CHAR_CLASS]]..":14:14|t";
			end
			
			-- encolor by class
			if( iFriends.db.Column.class.Color == 2 ) then
				return ("%s%s|r"):format(ClassColors[v[ROSTER_CHAR_CLASS]], v[ROSTER_CHAR_CLASS]);
			-- no color
			else
				return (COLOR_GOLD):format(v[ROSTER_CHAR_CLASS]);
			end
		end,
	},
	broadcast = {
		Label = L["Broadcast"],
		Brush = function(v)
			if( v[ROSTER_BNET_BROADCAST] ) then
				return ("%s%s|r"):format(COLOR_BNET, v[ROSTER_BNET_BROADCAST]);
			end
			
			return "";
		end,
	}
};

-- the DisplayedColumns table defines which columns gonna be displayed in the tooltip. It sorts out columns we cannot use (CanUse option).
local DisplayedColumns = {};
function iFriends:GetDisplayedColumns()
	tclear(DisplayedColumns);
	
	local insert, CanUse;
	for i = 1, #self.ConfigColumns do
		insert = true;
		CanUse = self.Columns[self.ConfigColumns[i]].CanUse;
		
		if( type(CanUse) == "boolean" and not CanUse ) then
			insert = false;
		elseif( type(CanUse) == "function" and not CanUse() ) then
			insert = false;
		end
		
		if( insert ) then
			table.insert(DisplayedColumns, self.ConfigColumns[i]);
		end
	end
	
end

----------------------
-- OnInitialize
----------------------

function iFriends:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("iFriendsDB", self:CreateDB(), "Default").profile;
	
	-- dirty check if someone is using an old iFriends config, where this table-field was a table too
	if( type(self.db.Display) == "table" ) then
		self.db.Display = "realid, realm, level, name, race, zone, note";
	end
	
	self:GetConfigColumns();
	self:GetDisplayedColumns();

	self:RegisterEvent("FRIENDLIST_UPDATE", "EventHandler");
	self:RegisterEvent("BN_FRIEND_INFO_CHANGED", "EventHandler");
	self:RegisterEvent("BN_FRIEND_LIST_SIZE_CHANGED", "EventHandler");
end

function iFriends:OnEnable()
	_G.ShowFriends();
	LibStub("AceTimer-3.0"):ScheduleRepeatingTimer(_G.ShowFriends, 55);
end

----------------------
-- EventHandler
----------------------

function iFriends:EventHandler()
	local friends, friendsOn = _G.GetNumFriends();
	local bnet, bnetOn = 0, 0;
	
	if( _G.BNFeaturesEnabledAndConnected() ) then
		bnet, bnetOn = _G.BNGetNumFriends();
	end
	
	local total = friends + bnet;
	local totalOn = friendsOn + bnetOn;
	
	self.Feed.text = ("%d/%d"):format(totalOn, total);
	self:SetupFriendsData(friendsOn, bnetOn);
	
	if( LibQTip:IsAcquired("iSuite"..AddonName) ) then
		self:UpdateTooltip();
	end
end

--------------------------------------
-- SetupFriendsData and Sorting
--------------------------------------

-- the function Roster_Sort is deprecated and got removed, the WoW API is sorting them by itself

function iFriends:SetupFriendsData(friendsOn, bnetOn)
	tclear(Roster);
	
	-- preventing Lua from declaring local values 10000x times per loop - saving memory!
	local _, charName, charLevel, charClass, charZone, isOnline, charStatus, charNote;
	local pID, givenName, surName, toonID, isAFK, isDND, Broadcast, Game, charRealm, charFaction, charRace, realID; -- additional bnet vars
	
	-- iterate through our friends
	for i = 1, friendsOn do
		charName, charLevel, charClass, charZone, isOnline, charStatus, charNote = _G.GetFriendInfo(i);
		
		if( isOnline ) then
			Roster[i] = {
				[ROSTER_BNET] = false,
				[ROSTER_GAME] = _G.BNET_CLIENT_WOW,
				[ROSTER_CHAR_NAME] = charName,
				[ROSTER_CHAR_LEVEL] = tonumber(charLevel),
				[ROSTER_CHAR_CLASS] = charClass,
				[ROSTER_CHAR_ZONE] = charZone or _G.UNKNOWN,
				[ROSTER_CHAR_STATUS] = charStatus or nil,
				[ROSTER_CHAR_NOTE] = charNote or nil,
			};
		end
	end
	
	-- iterate through our battle.net friends, if battle.net is connected
	if( _G.BNFeaturesEnabledAndConnected() ) then
		for i = 1, bnetOn do
			pID, givenName, surName, _, toonID, _, isOnline, _, isAFK, isDND, Broadcast, charNote, _, _ = _G.BNGetFriendInfo(i);
			
			if( isOnline ) then
				_, charName, Game, charRealm, _, charFaction, charRace, charClass, _, charZone, charLevel, _ = _G.BNGetToonInfo(pID);
				realID = (_G.BATTLENET_NAME_FORMAT):format(givenName, surName);
				
				charStatus = nil;
				if( isAFK ) then
					charStatus = ("<%s>"):format(_G.AFK);
				elseif( isDND ) then
					charStatus = ("<%s>"):format(_G.DND);
				end
				
				if( Game ~= _G.BNET_CLIENT_WOW ) then
					Roster[friendsOn +i] = {
						[ROSTER_BNET] = true,
						[ROSTER_GAME] = Game,
						[ROSTER_BNET_BROADCAST] = Broadcast or nil,
						[ROSTER_BNET_REALID] = realID,
						[ROSTER_BNET_PID] = pID,
						[ROSTER_BNET_TOONID] = toonID,
					};
				else
					Roster[friendsOn +i] = {
						[ROSTER_BNET] = true,
						[ROSTER_GAME] = Game,
						[ROSTER_CHAR_NAME] = charName,
						[ROSTER_CHAR_LEVEL] = tonumber(charLevel),
						[ROSTER_CHAR_CLASS] = charClass,
						[ROSTER_CHAR_ZONE] = charZone or _G.UNKNOWN,
						[ROSTER_CHAR_STATUS] = charStatus or nil,
						[ROSTER_CHAR_NOTE] = charNote or nil,
						[ROSTER_CHAR_REALM] = charRealm,
						[ROSTER_CHAR_RACE] = charRace,
						[ROSTER_CHAR_FACTION] = charFaction,
						[ROSTER_BNET_BROADCAST] = Broadcast or nil,
						[ROSTER_BNET_REALID] = realID,
						[ROSTER_BNET_PID] = pID,
						[ROSTER_BNET_TOONID] = toonID,
					};
				end
			end
		end -- end for
	end -- end if battle.net
end

-----------------------
-- UpdateTooltip
-----------------------

local function LineClick(_, v, button)
	if( _G.IsAltKeyDown() ) then
		_G.InviteUnit(v[ROSTER_CHAR_NAME]);
	else
		if( v[ROSTER_BNET] ) then
			local itemRef = ("%s:%d"):format(v[ROSTER_BNET_REALID], v[ROSTER_BNET_PID])
			_G.SetItemRef(("BNplayer:%s"):format(itemRef), ("|HBNplayer:%s|h[%s]|h"):format(itemRef, v[ROSTER_BNET_REALID]), "LeftButton");
		else
			_G.SetItemRef(("player:%s"):format(v[ROSTER_CHAR_NAME]), ("|Hplayer:%s|h[%s]|h"):format(v[ROSTER_CHAR_NAME], v[ROSTER_CHAR_NAME]), "LeftButton");
		end
	end
end

function iFriends:UpdateTooltip()
	Tooltip:Clear();
	Tooltip:SetColumnLayout(#DisplayedColumns);
	
	local name, info;
	
	-- Looping thru Roster and displaying columns and lines
	for y = 0, #Roster do
		local member;
		
		for x = 1, #DisplayedColumns do
			name = DisplayedColumns[x];
			info = self.Columns[name];
			
			if( x == 1 ) then
				if( y == 0) then
					Tooltip:AddHeader(" "); -- we have line 0, it's the header line.
				else
					Tooltip:AddLine(" "); -- all others are member lines.
				end
			end
			
			if( y == 0 ) then
				if( self.db.Column[name].ShowLabel ) then
					-- in the header line (y = 0), we check if column labels are to be shown.
					Tooltip:SetCell(y +1, x, info.Label, nil, self.db.Column[name].Align);
				end
				
			else
				member = Roster[y]; -- fetch member from Roster and brush infos to the cells
				Tooltip:SetCell(y +1, x, info.Brush(member), nil, self.db.Column[name].Align);
				
				if( info.Script and info.ScriptUse(member) ) then
					Tooltip:SetCellScript(y +1, x, "OnMouseDown", info.Script, member);
				end
			end
		end
		
		if( member ) then
			Tooltip:SetLineScript(y +1, "OnMouseDown", LineClick, member);
			
			if( member[ROSTER_GAME] ~= _G.BNET_CLIENT_WOW ) then
				local a, r, g, b = 0, 1, 1, 1;
				
				if( member[ROSTER_GAME] == _G.BNET_CLIENT_SC2 ) then
					a, r, g, b = 0.3, 0.1, 0.8, 1;
				elseif( member[ROSTER_GAME] == "D3") then
					a, r, g, b = 0.3, 1, 0.1, 0.1;
				end
				
				Tooltip:SetLineColor(y +1, r, g, b, a);
			end
		end
	end
end