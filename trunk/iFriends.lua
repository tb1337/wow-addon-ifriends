-----------------------------------
-- Setting up scope, upvalues and libs
-----------------------------------

local AddonName, iFriends = ...;
LibStub("AceEvent-3.0"):Embed(iFriends);

local L = LibStub("AceLocale-3.0"):GetLocale(AddonName);

local _G = _G; -- I always use _G.FUNC when I call a Global. Upvalueing done here.
local format = string.format;

_G.iFriends = iFriends;

-------------------------------
-- Registering with iLib
-------------------------------

LibStub("iLib"):Register(AddonName, nil, iFriends);

-----------------------------------------
-- Variables, functions and colors
-----------------------------------------

-- the Roster tables, which is the basic data storage of iFriends. Every index is a guild member array.
iFriends.Roster = {};
iFriends.BNRoster = {};

local ClassTranslate = {};
for k, v in pairs(_G.LOCALIZED_CLASS_NAMES_MALE) do
	ClassTranslate[v] = k;
end
for k, v in pairs(_G.LOCALIZED_CLASS_NAMES_FEMALE) do
	ClassTranslate[v] = k;
end

-----------------------------
-- Setting up the LDB
-----------------------------

iFriends.ldb = LibStub("LibDataBroker-1.1"):NewDataObject(AddonName, {
	type = "data source",
	text = "",
	icon = "Interface\\Addons\\iFriends\\Images\\iFriends",
});

iFriends.ldb.OnClick = function(_, button)
	if( button == "LeftButton" ) then
		if( _G.IsModifierKeyDown() ) then
			-- alt + left click = add new friend
			if( _G.IsAltKeyDown() ) then
				if( _G.BNFeaturesEnabledAndConnected() ) then
					-- I borrowed the following code snippet from the original WoW UI - (c) Blizzard
					_G.AddFriendEntryFrame_Collapse(true);
					_G.AddFriendFrame.editFocus = _G.AddFriendNameEditBox;
					_G.StaticPopupSpecial_Show(_G.AddFriendFrame);
					if( _G.GetCVarBool("addFriendInfoShown") ) then
						_G.AddFriendFrame_ShowEntry();
					else
						_G.AddFriendFrame_ShowInfo();
					end
					-- thanks Blizzard
				else
					_G.StaticPopup_Show("ADD_FRIEND");
				end
			end
		else
			-- normal click opens friends frame
			_G.ToggleFriendsFrame(1);
		end
	elseif( button == "RightButton" ) then
		if( not _G.IsModifierKeyDown() ) then
			iFriends:OpenOptions();
		end
	end
end

iFriends.ldb.OnEnter = function(anchor)
	local showLocal, showBN = (#iFriends.Roster > 0 and iFriends.db.DisplayWoWFriends), (#iFriends.BNRoster > 0);
	local showBoth = (showLocal and showBN);
	
	if( iFriends:IsTooltip("BNet") or iFriends:IsTooltip("WoW") or (not showLocal and not showBN) ) then
		return; -- when no friends are present, we won't show a tooltip (I dislike that!).
	end
	iFriends:HideAllTooltips();
	
	_G.ShowFriends();
	
	local tip;
	if( showBN and showLocal ) then
		local tip2;
		tip = iFriends:GetTooltip("BNet", "UpdateTooltip");
		tip:SmartAnchorTo(anchor);
		tip:Show();
		
		tip2 = iFriends:GetTooltip("WoW", "UpdateTooltip2");
		tip2:SetPoint("TOPLEFT", tip, "BOTTOMLEFT", 0, 0);
		tip2:Show();
		
		iFriends:SetSharedAutoHideDelay(0.25, tip, tip2, anchor);		
	else
		if( showBN ) then
			tip = iFriends:GetTooltip("BNet", "UpdateTooltip");
			tip:SmartAnchorTo(anchor);
			tip:SetAutoHideDelay(0.25, anchor);
			tip:Show();
		else
			tip = iFriends:GetTooltip("WoW", "UpdateTooltip2");
			tip:SmartAnchorTo(anchor);
			tip:SetAutoHideDelay(0.25, anchor);
			tip:Show();
		end
	end
end

iFriends.ldb.OnLeave = function() end -- some display addons refuse to display brokers when this is not defined

-- the DisplayedColumns table defines which columns gonna be displayed in the tooltip. It sorts out columns we cannot use (CanUse option).
iFriends.DisplayedColumns = {};
iFriends.DisplayedColumnsLocal = {};
function iFriends:GetDisplayedColumns(isLocal)
	_G.wipe(self.DisplayedColumns);
	_G.wipe(self.DisplayedColumnsLocal);
	
	local cols = {strsplit(",", self.db.Display)};
	local canUse;
	
	for i, v in ipairs(cols) do
		v = strtrim(v);
		canUse = self.Columns[v].canUse;
		
		if( canUse and not canUse() ) then
			canUse = false;
		else
			canUse = true;
		end
		
		if( canUse ) then
			table.insert(self.DisplayedColumns, v);
			
			if( not self.Columns[v].isBN ) then
				table.insert(self.DisplayedColumnsLocal, v);
			end	
		end
	end
end

----------------------
-- Boot
----------------------

function iFriends:Boot()
	self.db = LibStub("AceDB-3.0"):New("iFriendsDB", self:CreateDB(), "Default").profile;
	
	-- dirty check if someone is using an old iFriends config, where this table-field was a table too
	if( type(self.db.Display) == "table" ) then
		self.db.Display = "realid, level, class, name, race, zone, broadcast";
	end
	
	self:GetDisplayedColumns();
	-- the following code snippet is used once after login
	self.show_colored_columns();
	self.show_colored_columns = nil;

	self:RegisterEvent("FRIENDLIST_UPDATE", "EventHandler");
	self:RegisterEvent("BN_FRIEND_INFO_CHANGED", "EventHandler");
	self:RegisterEvent("BN_FRIEND_LIST_SIZE_CHANGED", "EventHandler");
	
	_G.ShowFriends();
	LibStub("AceTimer-3.0"):ScheduleRepeatingTimer(_G.ShowFriends, 55);
	
	self:UnregisterEvent("PLAYER_ENTERING_WORLD");
end
iFriends:RegisterEvent("PLAYER_ENTERING_WORLD", "Boot");

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
	
	if( self.db.ShowNumBNetFriends ) then
		self.ldb.text = ("%d/%d (%d)"):format(totalOn, total, bnet);
	else
		self.ldb.text = ("%d/%d"):format(totalOn, total);
	end
	
	self:SetupFriendsData(friendsOn, bnetOn);
	self:CheckTooltips("Bnet", "WoW");
end

--------------------------------------
-- SetupFriendsData and Sorting
--------------------------------------

do
	local mt = {
		__index = function(t, k)
			if    ( k == "name"  ) then return t[1]
			elseif( k == "level" ) then return t[2]
			elseif( k == "class" ) then return t[3]
			elseif( k == "CLASS" ) then return ClassTranslate[t[3]]
			elseif( k == "zone"  ) then return t[4]
			elseif( k == "status") then return t[5]
			elseif( k == "note"  ) then return t[6]
			elseif( k == "pid"   ) then return t[7]
			elseif( k == "toon"  ) then return t[8]
			elseif( k == "realid") then return t[9]
			elseif( k == "battletag")then return t[10]
			elseif( k == "broadcast")then return t[11]
			elseif( k == "game"  ) then return t[12]
			elseif( k == "realm" ) then return t[13]
			elseif( k == "faction")then return t[14]
			elseif( k == "race"  ) then return t[15]
			-- virtual
			elseif( k == "isWoW" ) then return (not t[12] or t[12] == _G.BNET_CLIENT_WOW)
			end
		end,
	};
	
	function iFriends:SetupFriendsData(friendsOn, bnetOn)
		_G.wipe(self.Roster);
		_G.wipe(self.BNRoster);
		
		-- preventing Lua from declaring local values 10000x times per loop
		local _, charName, charLevel, charClass, charZone, isOnline, charStatus, charNote;
		--local pID, givenName, surName, toonID, isAFK, isDND, Broadcast, Game, charRealm, charFaction, charRace, realID; -- additional bnet vars
		local pID, presenceName, battleTag, isBattleTagPresence, toonID, isAFK, isDND, Broadcast, Game, charRealm, charFaction, charRace, realID; -- additional bnet vars
		
		-- iterate through our friends
		for i = 1, friendsOn do
			charName, charLevel, charClass, charZone, isOnline, charStatus, charNote = _G.GetFriendInfo(i);
			
			if( isOnline ) then
				self.Roster[i] = {
					[1] = charName,
					[2] = charLevel,
					[3] = charClass,
					[4] = charZone or _G.UNKNOWN,  -- actually may happen o_O
					[5] = charStatus or "",
					[6] = charNote or ""
				};
				
				setmetatable(self.Roster[i], mt);
			end
		end
		
		-- iterate through our battle.net friends, if battle.net is connected
		if( _G.BNFeaturesEnabledAndConnected() ) then
			for i = 1, bnetOn do
				--pID, givenName, surName, _, toonID, _, isOnline, _, isAFK, isDND, Broadcast, charNote, _, _, _ = _G.BNGetFriendInfo(i);
				pID, presenceName, battleTag, isBattleTagPresence, _, toonID, _, isOnline, _, isAFK, isDND, Broadcast, charNote, _,_,_ = _G.BNGetFriendInfo(i);
				
				if( isOnline ) then
					_, charName, Game, charRealm, _, charFaction, charRace, charClass, _, charZone, charLevel, gameText, _, _, _, _ = _G.BNGetToonInfo(pID);
					--realID = (_G.BATTLENET_NAME_FORMAT):format(givenName, surName);
					
					charStatus = "";
					if( isAFK ) then
						charStatus = ("<%s>"):format(_G.AFK);
					elseif( isDND ) then
						charStatus = ("<%s>"):format(_G.DND);
					end
					
					if( Game == _G.BNET_CLIENT_WOW ) then
						self.BNRoster[i] = {
							[1]  = charName,
							[2]  = tonumber(charLevel), -- the b.net API returns the level as string. WTH
							[3]  = charClass,
							[4]  = ((not charZone or charZone == "") and _G.UNKNOWN or charZone), -- currently no zones in beta O_o
							[5]  = charStatus,
							[6]  = charNote or "",
							[7]  = pID,
							[8]  = toonID,
							--[9]  = realID,
							[9]  = presenceName,
							[10] = battleTag or "",
							[11] = Broadcast or "",
							[12] = Game,
							[13] = charRealm,
							[14] = charFaction,
							[15] = charRace
						};
					else
						self.BNRoster[i] = {
							[1]  = charName,
							[2]  = "",
							[3]  = "",
							[4]  = gameText,
							[5]  = "",
							[6]  = "",
							[7]  = pID, -- from now on, b.net specific vars
							[8]  = toonID,
							[9]  = presenceName,
							[10] = battleTag or "",
							[11] = Broadcast or "",
							[12] = Game,
						};
					end
					
					setmetatable(self.BNRoster[i], mt);
				end
			end -- end for
		end -- end if battle.net
		
		--@do-not-package@
		--[[
			-- add local player
			table.insert(self.Roster, {
				"Testchar1", 90, _G.LOCALIZED_CLASS_NAMES_MALE["MONK"], "Orgrimmar", "", ""
			});
			setmetatable(self.Roster[(#self.Roster)], mt);
			-- add local player
			table.insert(self.Roster, {
				"Testchar2", 90, _G.LOCALIZED_CLASS_NAMES_MALE["WARRIOR"], "Stormwind City", "", ""
			});
			setmetatable(self.Roster[(#self.Roster)], mt);
			-- add alliance player
			table.insert(self.BNRoster, {
				"Testchar3", 88, _G.LOCALIZED_CLASS_NAMES_MALE["SHAMAN"], "Blasted Lands", "", "", 1, 1, "Tony Test", "Hey friends!", "WoW", "Testrealm", 1, "Dwarf"
			});
			setmetatable(self.BNRoster[(#self.BNRoster)], mt);
			-- add horde player
			table.insert(self.BNRoster, {
				"Testchar4", 71, _G.LOCALIZED_CLASS_NAMES_MALE["WARLOCK"], "Hyjal", "", "", 1, 1, "Brigitta Bug", "", "WoW", "Testrealm", 0, "Orc"
			});
			setmetatable(self.BNRoster[(#self.BNRoster)], mt);
			-- add panda player
			table.insert(self.BNRoster, {
				"Testchar5", 86, _G.LOCALIZED_CLASS_NAMES_MALE["DEATHKNIGHT"], "The Maelstrom", "", "", 1, 1, "Daniel Developer", "", "WoW", "Testrealm", -1, "Pandaren"
			});
			setmetatable(self.BNRoster[(#self.BNRoster)], mt);
			-- add SC2 player
			table.insert(self.BNRoster, {
				"S2Char", "", "", "In Menus", "", "", 1, 1, "Eric Error", "I'm master!", "",  "S2"
			});
			setmetatable(self.BNRoster[(#self.BNRoster)], mt);
			-- add D3 player
			table.insert(self.BNRoster, {
				"D3Char", "", "", "In Menus", "", "", 1, 1, "Peter Patch", "", "", "D3"
			});
			setmetatable(self.BNRoster[(#self.BNRoster)], mt);
			-- add TCG player
			table.insert(self.BNRoster, {
				"HSChar", "", "", "In Menus", "", "", 1, 1, "Peter Patch", "", "", "WTCG"
			});
			setmetatable(self.BNRoster[(#self.BNRoster)], mt);
			--]]
			--@end-do-not-package@
	end -- end function
end

-----------------------
-- UpdateTooltip
-----------------------

local function LineClick(_, member, button)
	if( button == "LeftButton" ) then
		if( _G.IsModifierKeyDown() ) then
			if( _G.IsAltKeyDown() ) then
				if( member.realid and not _G.CanCooperateWithToon(member.toon) ) then else
					_G.InviteUnit(member.name);
				end
			end
		else
			if( member.realid ) then
				local itemRef = ("%s:%d"):format(member.realid, member.pid)
				_G.SetItemRef(("BNplayer:%s"):format(itemRef), ("|HBNplayer:%s|h[%s]|h"):format(itemRef, member.realid), "LeftButton");
			else
				_G.SetItemRef(("player:%s"):format(member.name), ("|Hplayer:%s|h[%s]|h"):format(member.name, member.name), "LeftButton");
			end
		end
	end
end

function iFriends:UpdateTooltip2(tip)
	self:UpdateTooltip(tip, true);
end

function iFriends:UpdateTooltip(tip, isLocal)	
	local Roster = isLocal and self.Roster or self.BNRoster;
	local DisplayedColumns = isLocal and self.DisplayedColumnsLocal or self.DisplayedColumns;
	local ShowLabels = isLocal and self.db.ShowLabelsWoW or self.db.ShowLabelsBN;
	
	tip:Clear();
	tip:SetColumnLayout(#DisplayedColumns);
	
	if( LibStub("iLib"):IsUpdate(AddonName) and not isLocal ) then
		line = tip:AddHeader("");
		tip:SetCell(line, 1, "|cffff0000"..L["Addon update available!"].."|r", nil, "CENTER", 0);
	end
	
	local name, info, line, member;
	
	-- Looping thru Roster and displaying columns and lines
	for y = (ShowLabels and 0 or 1), #Roster do
		for x = 1, #DisplayedColumns do
			name = DisplayedColumns[x];
			info = self.Columns[name];
			
			-- check if we add a line or a header
			if( x == 1 ) then
				if( y == 0 ) then
					line = tip:AddHeader(" "); -- we have line 0, it's the header line.
				else
					line = tip:AddLine(" "); -- all others are member lines.
				end
			end
			
			-- fill lines with content
			if( y == 0 ) then
				if( self.db.Column[name].ShowLabel ) then
					-- in the header line (y = 0), we check if column labels are to be shown.
					tip:SetCell(line, x, info.label, nil, self.db.Column[name].Align);
				end
			else
				member = Roster[y]; -- fetch member from Roster and brush infos to the cells
				tip:SetCell(line, x, info.brush(member), nil, self.db.Column[name].Align);
				
				if( info.script and self.db.Column[name].EnableScript and info.scriptUse(member) ) then
					tip:SetCellScript(line, x, "OnMouseDown", info.script, member);
				end
			end
		end -- end for x
		
		if( member ) then
			tip:SetLineScript(line, "OnMouseDown", LineClick, member);
			if( member.game ~= _G.BNET_CLIENT_WOW ) then
				local a, r, g, b = 0, 0, 0, 0;
				
				if( member.game == _G.BNET_CLIENT_SC2 ) then
					a, r, g, b = 0.3, 0.1, 0.8, 1;
				elseif( member.game == _G.BNET_CLIENT_D3 ) then
					a, r, g, b = 0.3, 1, 0.1, 0.1;
				elseif( member.game == _G.BNET_CLIENT_WTCG ) then
					a, r, g, b = 0.3, 0.1, 1, 1;
				end
				
				tip:SetLineColor(line, r, g, b, a);
			end
			member = nil;
		end
		
	end -- end for y
end