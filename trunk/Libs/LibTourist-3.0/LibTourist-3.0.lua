--[[
Name: LibTourist-3.0
Revision: $Rev: 137 $
Author(s): ckknight (ckknight@gmail.com), Arrowmaster, Odica (maintainer)
Website: http://ckknight.wowinterface.com/
Documentation: http://www.wowace.com/addons/libtourist-3-0/
SVN: svn://svn.wowace.com/wow/libtourist-3-0/mainline/trunk
Description: A library to provide information about zones and instances.
Dependencies: LibBabble-Zone-3.0
License: MIT
]]

local MAJOR_VERSION = "LibTourist-3.0"
local MINOR_VERSION = 90000 + tonumber(("$Revision: 137 $"):match("(%d+)"))

if not LibStub then error(MAJOR_VERSION .. " requires LibStub") end
if not LibStub("LibBabble-Zone-3.0") then error(MAJOR_VERSION .. " requires LibBabble-Zone-3.0.") end

local Tourist, oldLib = LibStub:NewLibrary(MAJOR_VERSION, MINOR_VERSION)
if not Tourist then
	return
end
if oldLib then
	oldLib = {}
	for k, v in pairs(Tourist) do
		Tourist[k] = nil
		oldLib[k] = v
	end
end

function trace(msg)
--	DEFAULT_CHAT_FRAME:AddMessage(msg)
end

local BZ = LibStub("LibBabble-Zone-3.0"):GetLookupTable()
local BZR = LibStub("LibBabble-Zone-3.0"):GetReverseLookupTable()

local playerLevel = 1
local _,race = UnitRace("player")
local isHorde = (race == "Orc" or race == "Troll" or race == "Tauren" or race == "Scourge" or race == "BloodElf" or race == "Goblin")
local isWestern = GetLocale() == "enUS" or GetLocale() == "deDE" or GetLocale() == "frFR" or GetLocale() == "esES"

local Kalimdor, Eastern_Kingdoms, Outland, Northrend, The_Maelstrom = GetMapContinents()
if not Outland then
	Outland = "Outland"
end
if not Northrend then
	Northrend = "Northrend"
end
if not The_Maelstrom then
	The_Maelstrom = "The Maelstrom"
end

local Azeroth = BZ["Azeroth"]

local X_Y_ZEPPELIN = "%s - %s Zeppelin"
local X_Y_BOAT = "%s - %s Boat"
local X_Y_PORTAL = "%s - %s Portal"
local X_Y_TELEPORT = "%s - %s Teleport"


if GetLocale() == "zhCN" then
	X_Y_ZEPPELIN = "%s - %s 飞艇"
	X_Y_BOAT = "%s - %s 船"
	X_Y_PORTAL = "%s - %s 传送门"
	X_Y_TELEPORT = "%s - %s 传送门"
elseif GetLocale() == "zhTW" then
	X_Y_ZEPPELIN = "%s - %s 飛艇"
	X_Y_BOAT = "%s - %s 船"
	X_Y_PORTAL = "%s - %s 傳送門"
	X_Y_TELEPORT = "%s - %s 傳送門"
elseif GetLocale() == "frFR" then
	X_Y_ZEPPELIN = "Zeppelin %s - %s"
	X_Y_BOAT = "Bateau %s - %s"
	X_Y_PORTAL = "Portail %s - %s"
	X_Y_TELEPORT = "Téléport %s - %s"
elseif GetLocale() == "koKR" then
	X_Y_ZEPPELIN = "%s - %s 비행선"
	X_Y_BOAT = "%s - %s 배"
	X_Y_PORTAL = "%s - %s 차원문"
	X_Y_TELEPORT = "%s - %s 차원문"
end

local recZones = {}
local recInstances = {}
local lows = setmetatable({}, {__index = function() return 0 end})
local highs = setmetatable({}, getmetatable(lows))
local continents = {}
local instances = {}
local paths = {}
local types = {}
local groupSizes = {}
local groupAltSizes = {}
local factions = {}
local yardWidths = {}
local yardHeights = {}
local yardXOffsets = {}
local yardYOffsets = {}
local fishing = {}
local cost = {}
local textures = {}
local textures_rev = {}
local complexOfInstance = {}
local zoneComplexes = {}
local entrancePortals_zone = {}
local entrancePortals_x = {}
local entrancePortals_y = {}

local function PLAYER_LEVEL_UP(self, level)
	playerLevel = level or UnitLevel("player")
	for k in pairs(recZones) do
		recZones[k] = nil
	end
	for k in pairs(recInstances) do
		recInstances[k] = nil
	end
	for k in pairs(cost) do
		cost[k] = nil
	end
	for zone in pairs(lows) do
		if not self:IsHostile(zone) then
			local low, high = self:GetLevel(zone)
			local zoneType = self:GetType(zone)
			if zoneType == "Zone" or zoneType == "PvP Zone" and low and high then
				if low <= playerLevel and playerLevel <= high then
					recZones[zone] = true
				end
			elseif zoneType == "Battleground" and low and high then
				local playerLevel = playerLevel
				if playerLevel >= low and (playerLevel == MAX_PLAYER_LEVEL or math.fmod(playerLevel, 10) >= 6) then
					recInstances[zone] = true
				end
			elseif zoneType == "Instance" and low and high then
				if low <= playerLevel and playerLevel <= high then
					recInstances[zone] = true
				end
			end
		end
	end
end

-- Minimum fishing skill to fish these zones junk-free
function Tourist:GetFishingLevel(zone)
	return fishing[zone]
end

function Tourist:GetLevelString(zone)
	local lo, hi = Tourist:GetLevel(zone)
	if lo and hi then
		if lo == hi then
			return tostring(lo)
		else
			return tostring(lo).."-"..tostring(hi)
		end
	else
		return tostring(lo) or tostring(hi) or ""
	end
end

function Tourist:GetLevel(zone)
	if types[zone] == "Battleground" then
		-- Note: Not all BG's start at level 10, but all BG's support players up to MAX_PLAYER_LEVEL.
		
		local playerLvl = playerLevel
		if playerLvl <= lows[zone] then
			-- Player is too low level to enter the BG -> return the lowest available bracket
			-- by assuming the player is at the min level required for the BG.
			playerLvl = lows[zone]
		end
	
		-- Find the most suitable bracket
		if playerLvl >= MAX_PLAYER_LEVEL then
			return MAX_PLAYER_LEVEL, MAX_PLAYER_LEVEL
		elseif playerLvl >= 80 then
			return 80, 84
		elseif playerLvl >= 75 then
			return 75, 79
		elseif playerLvl >= 70 then
			return 70, 74
		elseif playerLvl >= 65 then
			return 65, 69
		elseif playerLvl >= 60 then
			return 60, 64
		elseif playerLvl >= 55 then
			return 55, 59
		elseif playerLvl >= 50 then
			return 50, 54
		elseif playerLvl >= 45 then
			return 45, 49
		elseif playerLvl >= 40 then
			return 40, 44
		elseif playerLvl >= 35 then
			return 35, 39
		elseif playerLvl >= 30 then
			return 30, 34
		elseif playerLvl >= 25 then
			return 25, 29
		elseif playerLvl >= 20 then
			return 20, 24
		elseif playerLvl >= 15 then
			return 15, 19
		else
			return 10, 14
		end
	end
	
	-- All non-battlegrounds:
	return lows[zone], highs[zone]
end


function Tourist:GetLevelColor(zone)
	local low, high = self:GetLevel(zone)

	if types[zone] == "Battleground" then
		if playerLevel < low then
			-- player cannot enter the lowest bracket of the BG -> red
			return 1, 0, 0
		end
	end

	if low <= 0 and high <= 0 then
		-- City or level unknown
		return 1, 1, 1
	elseif playerLevel == low and playerLevel == high then
		return 1, 1, 0
	elseif playerLevel <= low - 3 then
		return 1, 0, 0
	elseif playerLevel <= low then
		return 1, (playerLevel - low - 3) / -6, 0
	elseif playerLevel <= (low + high) / 2 then
		return 1, (playerLevel - low) / (high - low) + 0.5, 0
	elseif playerLevel <= high then
		return 2 * (playerLevel - high) / (low - high), 1, 0
	elseif playerLevel <= high + 3 then
		local num = (playerLevel - high) / 6
		return num, 1 - num, num
	else
		return 0.5, 0.5, 0.5
	end
end

function Tourist:GetFactionColor(zone)
	if factions[zone] == (isHorde and "Alliance" or "Horde") then
		-- Red
		return 1, 0, 0
	elseif factions[zone] == (isHorde and "Horde" or "Alliance") then
		-- Green
		return 0, 1, 0
	elseif factions[zone] == "Sanctuary" then
		-- Blue
		return 0.41, 0.8, 0.94
	elseif self:IsPvPZone(zone) then
		-- Orange
		return 1, 0.7, 0
	else
		-- Yellow
		return 1, 1, 0
	end
end

function Tourist:GetZoneYardSize(zone)
	return yardWidths[zone], yardHeights[zone]
end

local ekXOffset = 15525.32200715066
local ekYOffset = 672.3934326738229

local kalXOffset = -8310.762035321373
local kalYOffset = 1815.149000954498

function Tourist:GetYardDistance(zone1, x1, y1, zone2, x2, y2)
	local zone1_yardXOffset = yardXOffsets[zone1]
	if not zone1_yardXOffset then
		return nil
	end
	local zone2_yardXOffset = yardXOffsets[zone2]
	if not zone2_yardXOffset then
		return nil
	end
	local zone1_yardYOffset = yardYOffsets[zone1]
	local zone2_yardYOffset = yardYOffsets[zone2]

	local zone1_continent = continents[zone1]
	local zone2_continent = continents[zone2]
	if (zone1_continent == Outland) ~= (zone2_continent == Outland) then
		return nil
	end

	local zone1_yardWidth = yardWidths[zone1]
	local zone1_yardHeight = yardHeights[zone1]
	local zone2_yardWidth = yardWidths[zone2]
	local zone2_yardHeight = yardHeights[zone2]

	local x1_yard = zone1_yardWidth*x1
	local y1_yard = zone1_yardHeight*y1
	local x2_yard = zone2_yardWidth*x2
	local y2_yard = zone2_yardHeight*y2

	if zone1 ~= zone2 then
		x1_yard = x1_yard + zone1_yardXOffset
		y1_yard = y1_yard + zone1_yardYOffset

		x2_yard = x2_yard + zone2_yardXOffset
		y2_yard = y2_yard + zone2_yardYOffset

		if zone1_continent ~= zone2_continent then
			if zone1_continent == Kalimdor then
				x1_yard = x1_yard + kalXOffset
				y1_yard = y1_yard + kalYOffset
			elseif zone1_continent == Eastern_Kingdoms then
				x1_yard = x1_yard + ekXOffset
				y1_yard = y1_yard + ekYOffset
			end

			if zone2_continent == Kalimdor then
				x2_yard = x2_yard + kalXOffset
				y2_yard = y2_yard + kalYOffset
			elseif zone2_continent == Eastern_Kingdoms then
				x2_yard = x2_yard + ekXOffset
				y2_yard = y2_yard + ekYOffset
			end
		end
	end

	local x_diff = x1_yard - x2_yard
	local y_diff = y1_yard - y2_yard
	local dist_2 = x_diff*x_diff + y_diff*y_diff
	return dist_2^0.5
end

function Tourist:TransposeZoneCoordinate(x, y, zone1, zone2)
	if zone1 == zone2 then
		return x, y
	end

	local zone1_yardXOffset = yardXOffsets[zone1]
	if not zone1_yardXOffset then
		return nil
	end
	local zone2_yardXOffset = yardXOffsets[zone2]
	if not zone2_yardXOffset then
		return nil
	end
	local zone1_yardYOffset = yardYOffsets[zone1]
	local zone2_yardYOffset = yardYOffsets[zone2]

	local zone1_continent = continents[zone1]
	local zone2_continent = continents[zone2]
	if (zone1_continent == Outland) ~= (zone2_continent == Outland) then
		return nil
	end

	local zone1_yardWidth = yardWidths[zone1]
	local zone1_yardHeight = yardHeights[zone1]
	local zone2_yardWidth = yardWidths[zone2]
	local zone2_yardHeight = yardHeights[zone2]

	local x_yard = zone1_yardWidth*x
	local y_yard = zone1_yardHeight*y

	x_yard = x_yard + zone1_yardXOffset
	y_yard = y_yard + zone1_yardYOffset

	if zone1_continent ~= zone2_continent then
		if zone1_continent == Kalimdor then
			x_yard = x_yard + kalXOffset
			y_yard = y_yard + kalYOffset
		elseif zone1_continent == Eastern_Kingdoms then
			x_yard = x_yard + ekXOffset
			y_yard = y_yard + ekYOffset
		end

		if zone2_continent == Kalimdor then
			x_yard = x_yard - kalXOffset
			y_yard = y_yard - kalYOffset
		elseif zone2_continent == Eastern_Kingdoms then
			x_yard = x_yard - ekXOffset
			y_yard = y_yard - ekYOffset
		end
	end

	x_yard = x_yard - zone2_yardXOffset
	y_yard = y_yard - zone2_yardYOffset

	x = x_yard / zone2_yardWidth
	y = y_yard / zone2_yardHeight

	return x, y
end

local zonesToIterate = setmetatable({}, {__index = function(self, key)
	local t = {}
	self[key] = t
	for k,v in pairs(continents) do
		if v == key and v ~= k and yardXOffsets[k] then
			t[#t+1] = k
		end
	end
	return t
end})

local kal_yardWidth
local kal_yardHeight
local ek_yardWidth
local ek_yardHeight

function Tourist:GetBestZoneCoordinate(x, y, zone)
	if not kal_yardWidth then
		kal_yardWidth = yardWidths[Kalimdor]
		kal_yardHeight = yardHeights[Kalimdor]
		ek_yardWidth = yardWidths[Eastern_Kingdoms]
		ek_yardHeight = yardHeights[Eastern_Kingdoms]
	end

	local zone_yardXOffset = yardXOffsets[zone]
	if not zone_yardXOffset then
		return x, y, zone
	end
	local zone_yardYOffset = yardYOffsets[zone]

	local zone_yardWidth = yardWidths[zone]
	local zone_yardHeight = yardHeights[zone]

	local x_yard = zone_yardWidth*x
	local y_yard = zone_yardHeight*y

	x_yard = x_yard + zone_yardXOffset
	y_yard = y_yard + zone_yardYOffset

	local zone_continent = continents[zone]
	local azeroth = false
	if zone_continent == Kalimdor then
		if x_yard < 0 or y_yard < 0 or x_yard > kal_yardWidth or y_yard > kal_yardHeight then
			x_yard = x_yard + kalXOffset
			y_yard = y_yard + kalYOffset
			azeroth = true
		end
	elseif zone_continent == Eastern_Kingdoms then
		if x_yard < 0 or y_yard < 0 or x_yard > ek_yardWidth or y_yard > ek_yardHeight then
			x_yard = x_yard + ekXOffset
			y_yard = y_yard + ekYOffset
			azeroth = true
		end
	end
	if azeroth then
		local kal, ek = zone_continent ~= Kalimdor, zone_continent ~= Eastern_Kingdoms
		if kal and (x_yard < kalXOffset or y_yard < kalYOffset or x_yard > kalXOffset + kal_yardWidth or y_yard > kalYOffset + kal_yardWidth) then
			kal = false
		end
		if ek and (x_yard < ekXOffset or y_yard < ekYOffset or x_yard > ekXOffset + ek_yardWidth or y_yard > ekYOffset + ek_yardWidth) then
			ek = false
		end
		if kal then
			x_yard = x_yard - kalXOffset
			y_yard = y_yard - kalYOffset
			zone_continent = Kalimdor
		elseif ek then
			x_yard = x_yard - ekXOffset
			y_yard = y_yard - ekYOffset
			zone_continent = Eastern_Kingdoms
		else
			return x_yard / yardWidths[Azeroth], y_yard / yardHeights[Azeroth], Azeroth
		end
	end

	local best_zone, best_x, best_y, best_value

	for _,z in ipairs(zonesToIterate[zone_continent]) do
		local z_yardXOffset = yardXOffsets[z]
		local z_yardYOffset = yardYOffsets[z]
		local z_yardWidth = yardWidths[z]
		local z_yardHeight = yardHeights[z]

		local x_yd = x_yard - z_yardXOffset
		local y_yd = y_yard - z_yardYOffset

		if x_yd >= 0 and y_yd >= 0 and x_yd <= z_yardWidth and y_yd <= z_yardHeight then
			if types[z] == "City" then
				return x_yd/z_yardWidth, y_yd/z_yardHeight, z
			end
			local x_tmp = x_yd - z_yardWidth / 2
			local y_tmp = y_yd - z_yardHeight / 2
			local value = x_tmp*x_tmp + y_tmp*y_tmp
			if not best_value or value < best_value then
				best_zone = z
				best_value = value
				best_x = x_yd/z_yardWidth
				best_y = y_yd/z_yardHeight
			end
		end
	end
	if not best_zone then
		return x_yard / yardWidths[zone_continent], y_yard / yardHeights[zone_continent], zone_continent
	end
	return best_x, best_y, best_zone
end

local function retNil() return nil end
local function retOne(object, state)
	if state == object then
		return nil
	else
		return object
	end
end

local function retNormal(t, position)
	return (next(t, position))
end

local function mysort(a,b)
	if not lows[a] then
		return false
	elseif not lows[b] then
		return true
	else
		local aval, bval = groupSizes[a], groupSizes[b]
		if aval and bval then
			if aval ~= bval then
				return aval < bval
			end
		end
		aval, bval = lows[a], lows[b]
		if aval ~= bval then
			return aval < bval
		end
		aval, bval = highs[a], highs[b]
		if aval ~= bval then
			return aval < bval
		end
		return a < b
	end
end
local t = {}
local function myiter(t)
	local n = t.n
	n = n + 1
	local v = t[n]
	if v then
		t[n] = nil
		t.n = n
		return v
	else
		t.n = nil
	end
end
function Tourist:IterateZoneInstances(zone)
	local inst = instances[zone]

	if not inst then
		return retNil
	elseif type(inst) == "table" then
		for k in pairs(t) do
			t[k] = nil
		end
		for k in pairs(inst) do
			t[#t+1] = k
		end
		table.sort(t, mysort)
		t.n = 0
		return myiter, t, nil
	else
		return retOne, inst, nil
	end
end

function Tourist:IterateZoneComplexes(zone)
	local compl = zoneComplexes[zone]

	if not compl then
		return retNil
	elseif type(compl) == "table" then
		for k in pairs(t) do
			t[k] = nil
		end
		for k in pairs(compl) do
			t[#t+1] = k
		end
		table.sort(t, mysort)
		t.n = 0
		return myiter, t, nil
	else
		return retOne, compl, nil
	end
end

function Tourist:GetInstanceZone(instance)
	for k, v in pairs(instances) do
		if v then
			if type(v) == "string" then
				if v == instance then
					return k
				end
			else -- table
				for l in pairs(v) do
					if l == instance then
						return k
					end
				end
			end
		end
	end
end

function Tourist:GetComplexZone(complex)
	for k, v in pairs(zoneComplexes) do
		if v then
			if type(v) == "string" then
				if v == complex then
					return k
				end
			else -- table
				for l in pairs(v) do
					if l == complex then
						return k
					end
				end
			end
		end
	end
end

function Tourist:DoesZoneHaveInstances(zone)
	return not not instances[zone]
end

function Tourist:DoesZoneHaveComplexes(zone)
	return not not zoneComplexes[zone]
end

local zonesInstances
local function initZonesInstances()
	if not zonesInstances then
		zonesInstances = {}
		for zone, v in pairs(lows) do
			if types[zone] ~= "Transport" then
				zonesInstances[zone] = true
			end
		end
	end
	initZonesInstances = nil
end

function Tourist:IterateZonesAndInstances()
	if initZonesInstances then
		initZonesInstances()
	end
	return retNormal, zonesInstances, nil
end

local function zoneIter(_, position)
	local k = next(zonesInstances, position)
	while k ~= nil and (types[k] == "Instance" or types[k] == "Battleground" or types[k] == "Arena") do
		k = next(zonesInstances, k)
	end
	return k
end
function Tourist:IterateZones()
	if initZonesInstances then
		initZonesInstances()
	end
	return zoneIter, nil, nil
end

local function instanceIter(_, position)
	local k = next(zonesInstances, position)
	while k ~= nil and (types[k] ~= "Instance" and types[k] ~= "Battleground" and types[k] ~= "Arena") do
		k = next(zonesInstances, k)
	end
	return k
end
function Tourist:IterateInstances()
	if initZonesInstances then
		initZonesInstances()
	end
	return instanceIter, nil, nil
end

local function bgIter(_, position)
	local k = next(zonesInstances, position)
	while k ~= nil and types[k] ~= "Battleground" do
		k = next(zonesInstances, k)
	end
	return k
end
function Tourist:IterateBattlegrounds()
	if initZonesInstances then
		initZonesInstances()
	end
	return bgIter, nil, nil
end

local function arIter(_, position)
	local k = next(zonesInstances, position)
	while k ~= nil and types[k] ~= "Arena" do
		k = next(zonesInstances, k)
	end
	return k
end
function Tourist:IterateArenas()
	if initZonesInstances then
		initZonesInstances()
	end
	return arIter, nil, nil
end

local function compIter(_, position)
	local k = next(zonesInstances, position)
	while k ~= nil and types[k] ~= "Complex" do
		k = next(zonesInstances, k)
	end
	return k
end
function Tourist:IterateComplexes()
	if initZonesInstances then
		initZonesInstances()
	end
	return compIter, nil, nil
end

local function pvpIter(_, position)
	local k = next(zonesInstances, position)
	while k ~= nil and types[k] ~= "PvP Zone" do
		k = next(zonesInstances, k)
	end
	return k
end
function Tourist:IteratePvPZones()
	if initZonesInstances then
		initZonesInstances()
	end
	return pvpIter, nil, nil
end

local function allianceIter(_, position)
	local k = next(zonesInstances, position)
	while k ~= nil and factions[k] ~= "Alliance" do
		k = next(zonesInstances, k)
	end
	return k
end
function Tourist:IterateAlliance()
	if initZonesInstances then
		initZonesInstances()
	end
	return allianceIter, nil, nil
end

local function hordeIter(_, position)
	local k = next(zonesInstances, position)
	while k ~= nil and factions[k] ~= "Horde" do
		k = next(zonesInstances, k)
	end
	return k
end
function Tourist:IterateHorde()
	if initZonesInstances then
		initZonesInstances()
	end
	return hordeIter, nil, nil
end

if isHorde then
	Tourist.IterateFriendly = Tourist.IterateHorde
	Tourist.IterateHostile = Tourist.IterateAlliance
else
	Tourist.IterateFriendly = Tourist.IterateAlliance
	Tourist.IterateHostile = Tourist.IterateHorde
end

local function sanctIter(_, position)
	local k = next(zonesInstances, position)
	while k ~= nil and factions[k] ~= "Sanctuary" do
		k = next(zonesInstances, k)
	end
	return k
end
function Tourist:IterateSanctuaries()
	if initZonesInstances then
		initZonesInstances()
	end
	return sanctIter, nil, nil
end

local function contestedIter(_, position)
	local k = next(zonesInstances, position)
	while k ~= nil and factions[k] do
		k = next(zonesInstances, k)
	end
	return k
end
function Tourist:IterateContested()
	if initZonesInstances then
		initZonesInstances()
	end
	return contestedIter, nil, nil
end

local function kalimdorIter(_, position)
	local k = next(zonesInstances, position)
	while k ~= nil and continents[k] ~= Kalimdor do
		k = next(zonesInstances, k)
	end
	return k
end
function Tourist:IterateKalimdor()
	if initZonesInstances then
		initZonesInstances()
	end
	return kalimdorIter, nil, nil
end

local function easternKingdomsIter(_, position)
	local k = next(zonesInstances, position)
	while k ~= nil and continents[k] ~= Eastern_Kingdoms do
		k = next(zonesInstances, k)
	end
	return k
end
function Tourist:IterateEasternKingdoms()
	if initZonesInstances then
		initZonesInstances()
	end
	return easternKingdomsIter, nil, nil
end

local function outlandIter(_, position)
	local k = next(zonesInstances, position)
	while k ~= nil and continents[k] ~= Outland do
		k = next(zonesInstances, k)
	end
	return k
end
function Tourist:IterateOutland()
	if initZonesInstances then
		initZonesInstances()
	end
	return outlandIter, nil, nil
end

local function northrendIter(_, position)
	local k = next(zonesInstances, position)
	while k ~= nil and continents[k] ~= Northrend do
		k = next(zonesInstances, k)
	end
	return k
end
function Tourist:IterateNorthrend()
	if initZonesInstances then
		initZonesInstances()
	end
	return northrendIter, nil, nil
end

local function theMaelstromIter(_, position)
	local k = next(zonesInstances, position)
	while k ~= nil and continents[k] ~= The_Maelstrom do
		k = next(zonesInstances, k)
	end
	return k
end
function Tourist:IterateTheMaelstrom()
	if initZonesInstances then
		initZonesInstances()
	end
	return theMaelstromIter, nil, nil
end

function Tourist:IterateRecommendedZones()
	return retNormal, recZones, nil
end

function Tourist:IterateRecommendedInstances()
	return retNormal, recInstances, nil
end

function Tourist:HasRecommendedInstances()
	return next(recInstances) ~= nil
end

function Tourist:IsInstance(zone)
	local t = types[zone]
	return t == "Instance" or t == "Battleground" or t == "Arena"
end

function Tourist:IsZone(zone)
	local t = types[zone]
	return t and t ~= "Instance" and t ~= "Battleground" and t ~= "Transport" and t ~= "Arena"
end

function Tourist:GetComplex(zone)
	return complexOfInstance[zone]
end

function Tourist:GetType(zone)
	return types[zone] or "Zone"
end

function Tourist:IsZoneOrInstance(zone)
	local t = types[zone]
	return t and t ~= "Transport"
end

function Tourist:IsTransport(zone)
	local t = types[zone]
	return t == "Transport"
end

function Tourist:IsComplex(zone)
	local t = types[zone]
	return t == "Complex"
end

function Tourist:IsBattleground(zone)
	local t = types[zone]
	return t == "Battleground"
end

function Tourist:IsArena(zone)
	local t = types[zone]
	return t == "Arena"
end

function Tourist:IsPvPZone(zone)
	local t = types[zone]
	return t == "PvP Zone"
end

function Tourist:IsCity(zone)
	local t = types[zone]
	return t == "City"
end

function Tourist:IsAlliance(zone)
	return factions[zone] == "Alliance"
end

function Tourist:IsHorde(zone)
	return factions[zone] == "Horde"
end

if isHorde then
	Tourist.IsFriendly = Tourist.IsHorde
	Tourist.IsHostile = Tourist.IsAlliance
else
	Tourist.IsFriendly = Tourist.IsAlliance
	Tourist.IsHostile = Tourist.IsHorde
end

function Tourist:IsSanctuary(zone)
	return factions[zone] == "Sanctuary"
end

function Tourist:IsContested(zone)
	return not factions[zone]
end

function Tourist:GetContinent(zone)
	return continents[zone] or UNKNOWN
end

function Tourist:IsInKalimdor(zone)
	return continents[zone] == Kalimdor
end

function Tourist:IsInEasternKingdoms(zone)
	return continents[zone] == Eastern_Kingdoms
end

function Tourist:IsInOutland(zone)
	return continents[zone] == Outland
end

function Tourist:IsInNorthrend(zone)
	return continents[zone] == Northrend
end

function Tourist:IsInTheMaelstrom(zone)
	return continents[zone] == The_Maelstrom
end

function Tourist:GetInstanceGroupSize(instance)
	return groupSizes[instance] or 0
end

function Tourist:GetInstanceAltGroupSize(instance)
	return groupAltSizes[instance] or 0
end

function Tourist:GetTexture(zone)
	return textures[zone]
end

function Tourist:GetZoneFromTexture(texture)
	if not texture then
		return BZ["Azeroth"]
	end
	local zone = textures_rev[texture]
	if zone then 
		return zone
	else
		-- Might be phased terrain, look for "_terrain<number>" postfix
		local pos = string.find(texture, "_terrain")
		if pos then
			-- Remove the postfix from the texture name
			texture = string.sub(texture, 0, pos - 1)
			return textures_rev[texture]
		end
	end
	return nil
end

function Tourist:GetEnglishZoneFromTexture(texture)
	if not texture then
		return "Azeroth"
	end
	local zone = textures_rev[texture]
	if zone then
		return BZR[zone]
	else
		-- Might be phased terrain, look for "_terrain<number>" postfix
		local pos = string.find(texture, "_terrain")
		if pos then
			-- Remove the postfix from the texture name
			texture = string.sub(texture, 0, pos - 1)
			zone = textures_rev[texture]
			if zone then
				return BZR[zone]
			end
		end
	end
	return nil
end

function Tourist:GetEntrancePortalLocation(instance)
	return entrancePortals_zone[instance], entrancePortals_x[instance], entrancePortals_y[instance]
end

local inf = math.huge
local stack = setmetatable({}, {__mode='k'})
local function iterator(S)
	local position = S['#'] - 1
	S['#'] = position
	local x = S[position]
	if not x then
		for k in pairs(S) do
			S[k] = nil
		end
		stack[S] = true
		return nil
	end
	return x
end

setmetatable(cost, {
	__index = function(self, vertex)
		local price = 1

		if lows[vertex] > playerLevel then
			price = price * (1 + math.ceil((lows[vertex] - playerLevel) / 6))
		end

		if factions[vertex] == (isHorde and "Horde" or "Alliance") then
			price = price / 2
		elseif factions[vertex] == (isHorde and "Alliance" or "Horde") then
			if types[vertex] == "City" then
				price = price * 10
			else
				price = price * 3
			end
		end

		if types[x] == "Transport" then
			price = price * 2
		end

		self[vertex] = price
		return price
	end
})

function Tourist:IteratePath(alpha, bravo)
	if paths[alpha] == nil or paths[bravo] == nil then
		return retNil
	end

	local d = next(stack) or {}
	stack[d] = nil
	local Q = next(stack) or {}
	stack[Q] = nil
	local S = next(stack) or {}
	stack[S] = nil
	local pi = next(stack) or {}
	stack[pi] = nil

	for vertex, v in pairs(paths) do
		d[vertex] = inf
		Q[vertex] = v
	end
	d[alpha] = 0

	while next(Q) do
		local u
		local min = inf
		for z in pairs(Q) do
			local value = d[z]
			if value < min then
				min = value
				u = z
			end
		end
		if min == inf then
			return retNil
		end
		Q[u] = nil
		if u == bravo then
			break
		end

		local adj = paths[u]
		if type(adj) == "table" then
			local d_u = d[u]
			for v in pairs(adj) do
				local c = d_u + cost[v]
				if d[v] > c then
					d[v] = c
					pi[v] = u
				end
			end
		elseif adj ~= false then
			local c = d[u] + cost[adj]
			if d[adj] > c then
				d[adj] = c
				pi[adj] = u
			end
		end
	end

	local i = 1
	local last = bravo
	while last do
		S[i] = last
		i = i + 1
		last = pi[last]
	end

	for k in pairs(pi) do
		pi[k] = nil
	end
	for k in pairs(Q) do
		Q[k] = nil
	end
	for k in pairs(d) do
		d[k] = nil
	end
	stack[pi] = true
	stack[Q] = true
	stack[d] = true

	S['#'] = i

	return iterator, S
end

local function retWithOffset(t, key)
	while true do
		key = next(t, key)
		if not key then
			return nil
		end
		if yardYOffsets[key] then
			return key
		end
	end
end

function Tourist:IterateBorderZones(zone, zonesOnly)
	local path = paths[zone]
	if not path then
		return retNil
	elseif type(path) == "table" then
		return zonesOnly and retWithOffset or retNormal, path
	else
		if zonesOnly and not yardYOffsets[path] then
			return retNil
		end
		return retOne, path
	end
end

do
	Tourist.frame = oldLib and oldLib.frame or CreateFrame("Frame", MAJOR_VERSION .. "Frame", UIParent)
	Tourist.frame:UnregisterAllEvents()
	Tourist.frame:RegisterEvent("PLAYER_LEVEL_UP")
	Tourist.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	Tourist.frame:SetScript("OnEvent", function(frame, event, ...)
		PLAYER_LEVEL_UP(Tourist, ...)
	end)

	local BOOTYBAY_RATCHET_BOAT = string.format(X_Y_BOAT, BZ["Booty Bay"], BZ["Ratchet"])
	local MENETHIL_THERAMORE_BOAT = string.format(X_Y_BOAT, BZ["Menethil Harbor"], BZ["Theramore Isle"])
	local MENETHIL_HOWLINGFJORD_BOAT = string.format(X_Y_BOAT, BZ["Menethil Harbor"], BZ["Howling Fjord"])
	local DARNASSUS_EXODAR_PORTAL = string.format(X_Y_PORTAL, BZ["Darnassus"], BZ["The Exodar"])
	local EXODAR_DARNASSUS_PORTAL = string.format(X_Y_PORTAL, BZ["The Exodar"], BZ["Darnassus"])
	local TELDRASSIL_AZUREMYST_BOAT = string.format(X_Y_BOAT, BZ["Teldrassil"], BZ["Azuremyst Isle"])
	local TELDRASSIL_STORMWIND_BOAT = string.format(X_Y_BOAT, BZ["Teldrassil"], BZ["Stormwind City"])
	local DARNASSUS_BLASTEDLANDS_PORTAL = string.format(X_Y_PORTAL, BZ["Darnassus"], BZ["Blasted Lands"])
	local EXODAR_BLASTEDLANDS_PORTAL = string.format(X_Y_PORTAL, BZ["The Exodar"], BZ["Blasted Lands"])
	local STORMWIND_BOREANTUNDRA_BOAT = string.format(X_Y_BOAT, BZ["Stormwind City"], BZ["Borean Tundra"])
	local STORMWIND_BLASTEDLANDS_PORTAL = string.format(X_Y_PORTAL, BZ["Stormwind City"], BZ["Blasted Lands"])
	local IRONFORGE_BLASTEDLANDS_PORTAL = string.format(X_Y_PORTAL, BZ["Ironforge"], BZ["Blasted Lands"])
	local ORGRIMMAR_BOREANTUNDRA_ZEPPELIN = string.format(X_Y_ZEPPELIN, BZ["Orgrimmar"], BZ["Borean Tundra"])
	local ORGRIMMAR_UNDERCITY_ZEPPELIN = string.format(X_Y_ZEPPELIN, BZ["Orgrimmar"], BZ["Undercity"])
	local ORGRIMMAR_GROMGOL_ZEPPELIN = string.format(X_Y_ZEPPELIN, BZ["Orgrimmar"], BZ["Grom'gol Base Camp"])
	local ORGRIMMAR_THUNDERBLUFF_ZEPPELIN = string.format(X_Y_ZEPPELIN, BZ["Orgrimmar"], BZ["Thunder Bluff"])
	local ORGRIMMAR_BLASTEDLANDS_PORTAL = string.format(X_Y_PORTAL, BZ["Orgrimmar"], BZ["Blasted Lands"])
	local UNDERCITY_HOWLINGFJORD_ZEPPELIN = string.format(X_Y_ZEPPELIN, BZ["Undercity"], BZ["Howling Fjord"])
	local UNDERCITY_GROMGOL_ZEPPELIN = string.format(X_Y_ZEPPELIN, BZ["Undercity"], BZ["Grom'gol Base Camp"])
	local UNDERCITY_BLASTEDLANDS_PORTAL = string.format(X_Y_PORTAL, BZ["Undercity"], BZ["Blasted Lands"])
	local THUNDERBLUFF_BLASTEDLANDS_PORTAL = string.format(X_Y_PORTAL, BZ["Thunder Bluff"], BZ["Blasted Lands"])
	local SILVERMOON_UNDERCITY_TELEPORT = string.format(X_Y_TELEPORT, BZ["Silvermoon City"], BZ["Undercity"])
	local SILVERMOON_BLASTEDLANDS_PORTAL = string.format(X_Y_PORTAL, BZ["Silvermoon City"], BZ["Blasted Lands"])
	local SHATTRATH_QUELDANAS_PORTAL = string.format(X_Y_PORTAL, BZ["Shattrath City"], BZ["Isle of Quel'Danas"])
	local SHATTRATH_COT_PORTAL = string.format(X_Y_PORTAL, BZ["Shattrath City"], BZ["Caverns of Time"])
	local MOAKI_UNUPE_BOAT = string.format(X_Y_BOAT, BZ["Dragonblight"], BZ["Borean Tundra"])
	local MOAKI_KAMAGUA_BOAT = string.format(X_Y_BOAT, BZ["Dragonblight"], BZ["Howling Fjord"])
	local DALARAN_COT_PORTAL = string.format(X_Y_PORTAL, BZ["Dalaran"], BZ["Caverns of Time"])
	local DALARAN_CRYSTALSONG_TELEPORT = string.format(X_Y_TELEPORT, BZ["Dalaran"], BZ["Crystalsong Forest"])
	local ORGRIMMAR_TWILIGHTHIGHLANDS_PORTAL = string.format(X_Y_PORTAL, BZ["Orgrimmar"], BZ["Twilight Highlands"])
	local ORGRIMMAR_MOUNTHYJAL_PORTAL = string.format(X_Y_PORTAL, BZ["Orgrimmar"], BZ["Mount Hyjal"])
	local ORGRIMMAR_DEEPHOLM_PORTAL = string.format(X_Y_PORTAL, BZ["Orgrimmar"], BZ["Deepholm"])
	local DEEPHOLM_ORGRIMMAR_PORTAL = string.format(X_Y_PORTAL, BZ["Deepholm"], BZ["Orgrimmar"])
	local ORGRIMMAR_ULDUM_PORTAL = string.format(X_Y_PORTAL, BZ["Orgrimmar"], BZ["Uldum"])
	local ORGRIMMAR_VASHJIR_PORTAL = string.format(X_Y_PORTAL, BZ["Orgrimmar"], BZ["Vashj'ir"])
	local ORGRIMMAR_TOLBARAD_PORTAL = string.format(X_Y_PORTAL, BZ["Orgrimmar"], BZ["Tol Barad Peninsula"])
	local TOLBARAD_ORGRIMMAR_PORTAL = string.format(X_Y_PORTAL, BZ["Tol Barad Peninsula"], BZ["Orgrimmar"])
	local STORMWIND_TWILIGHTHIGHLANDS_PORTAL = string.format(X_Y_PORTAL, BZ["Stormwind City"], BZ["Twilight Highlands"])
	local STORMWIND_MOUNTHYJAL_PORTAL = string.format(X_Y_PORTAL, BZ["Stormwind City"], BZ["Mount Hyjal"])
	local STORMWIND_DEEPHOLM_PORTAL = string.format(X_Y_PORTAL, BZ["Stormwind City"], BZ["Deepholm"])
	local DEEPHOLM_STORMWIND_PORTAL = string.format(X_Y_PORTAL, BZ["Deepholm"], BZ["Stormwind City"])
	local STORMWIND_ULDUM_PORTAL = string.format(X_Y_PORTAL, BZ["Stormwind City"], BZ["Uldum"])
	local STORMWIND_VASHJIR_PORTAL = string.format(X_Y_PORTAL, BZ["Stormwind City"], BZ["Vashj'ir"])
	local STORMWIND_TOLBARAD_PORTAL = string.format(X_Y_PORTAL, BZ["Stormwind City"], BZ["Tol Barad Peninsula"])
	local TOLBARAD_STORMWIND_PORTAL = string.format(X_Y_PORTAL, BZ["Tol Barad Peninsula"], BZ["Stormwind City"])
	local HELLFIRE_ORGRIMMAR_PORTAL = string.format(X_Y_PORTAL, BZ["Hellfire Peninsula"], BZ["Orgrimmar"])
	local HELLFIRE_STORMWIND_PORTAL = string.format(X_Y_PORTAL, BZ["Hellfire Peninsula"], BZ["Stormwind City"])
	local DALARAN_ORGRIMMAR_PORTAL = string.format(X_Y_PORTAL, BZ["Dalaran"], BZ["Orgrimmar"])
	local DALARAN_STORMWIND_PORTAL = string.format(X_Y_PORTAL, BZ["Dalaran"], BZ["Stormwind City"])

	local zones = {}

	zones[BZ["Eastern Kingdoms"]] = {
		type = "Continent",
--		yards = 47714.278579261,
		yards = 40741.17907,
		x_offset = 0,
		y_offset = 0,
		continent = Eastern_Kingdoms,
	}

	zones[BZ["Kalimdor"]] = {
		type = "Continent",
		yards = 36800.210572494,
		x_offset = 0,
		y_offset = 0,
		continent = Kalimdor,
	}

	zones[BZ["Outland"]] = {
		type = "Continent",
		yards = 17463.5328406368,
		x_offset = 0,
		y_offset = 0,
		continent = Outland,
	}

	zones[BZ["Northrend"]] = {
		type = "Continent",
		yards = 17751.3962441049,
		x_offset = 0,
		y_offset = 0,
		continent = Northrend,
	}

	zones[BZ["The Maelstrom"]] = {
		type = "Continent",
		yards = 0.0,   -- TODO
		x_offset = 0,
		y_offset = 0,
		continent = The_Maelstrom,
	}

	zones[BZ["Azeroth"]] = {
		type = "Continent",
		yards = 44531.82907938571,
		x_offset = 0,
		y_offset = 0,
	}

	zones[STORMWIND_BOREANTUNDRA_BOAT] = {
		paths = {
			[BZ["Stormwind City"]] = true,
			[BZ["Borean Tundra"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[ORGRIMMAR_BOREANTUNDRA_ZEPPELIN] = {
		paths = {
			[BZ["Orgrimmar"]] = true,
			[BZ["Borean Tundra"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[UNDERCITY_HOWLINGFJORD_ZEPPELIN] = {
		paths = {
			[BZ["Tirisfal Glades"]] = true,
			[BZ["Howling Fjord"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[ORGRIMMAR_BLASTEDLANDS_PORTAL] = {
		paths = {
			[BZ["Blasted Lands"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[HELLFIRE_ORGRIMMAR_PORTAL] = {
		paths = {
			[BZ["Orgrimmar"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[UNDERCITY_BLASTEDLANDS_PORTAL] = {
		paths = {
			[BZ["Blasted Lands"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[THUNDERBLUFF_BLASTEDLANDS_PORTAL] = {
		paths = {
			[BZ["Blasted Lands"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[SILVERMOON_BLASTEDLANDS_PORTAL] = {
		paths = {
			[BZ["Blasted Lands"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[STORMWIND_BLASTEDLANDS_PORTAL] = {
		paths = {
			[BZ["Blasted Lands"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[HELLFIRE_STORMWIND_PORTAL] = {
		paths = {
			[BZ["Stormwind City"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[DALARAN_STORMWIND_PORTAL] = {
		paths = BZ["Stormwind City"],
		faction = "Alliance",
		type = "Transport",
	}

	zones[DALARAN_ORGRIMMAR_PORTAL] = {
		paths = BZ["Orgrimmar"],
		faction = "Horde",
		type = "Transport",
	}

	zones[DARNASSUS_BLASTEDLANDS_PORTAL] = {
		paths = {
			[BZ["Blasted Lands"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[EXODAR_BLASTEDLANDS_PORTAL] = {
		paths = {
			[BZ["Blasted Lands"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[DARNASSUS_EXODAR_PORTAL] = {
		paths = {
			[BZ["The Exodar"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}
	
	zones[EXODAR_DARNASSUS_PORTAL] = {
		paths = {
			[BZ["Darnassus"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}





	zones[IRONFORGE_BLASTEDLANDS_PORTAL] = {
		paths = {
			[BZ["Blasted Lands"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[TELDRASSIL_STORMWIND_BOAT] = {
		paths = {
			[BZ["Teldrassil"]] = true,
			[BZ["Stormwind City"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[TELDRASSIL_AZUREMYST_BOAT] = {
		paths = {
			[BZ["Teldrassil"]] = true,
			[BZ["Azuremyst Isle"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[BOOTYBAY_RATCHET_BOAT] = {
		paths = {
			[BZ["The Cape of Stranglethorn"]] = true,
			[BZ["Northern Barrens"]] = true,
		},
		type = "Transport",
	}

	zones[MENETHIL_HOWLINGFJORD_BOAT] = {
		paths = {
			[BZ["Wetlands"]] = true,
			[BZ["Howling Fjord"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[MENETHIL_THERAMORE_BOAT] = {
		paths = {
			[BZ["Wetlands"]] = true,
			[BZ["Dustwallow Marsh"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[ORGRIMMAR_GROMGOL_ZEPPELIN] = {
		paths = {
			[BZ["Orgrimmar"]] = true,
			[BZ["Northern Stranglethorn"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[ORGRIMMAR_UNDERCITY_ZEPPELIN] = {
		paths = {
			[BZ["Orgrimmar"]] = true,
			[BZ["Tirisfal Glades"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[ORGRIMMAR_THUNDERBLUFF_ZEPPELIN] = {
		paths = {
			[BZ["Orgrimmar"]] = true,
			[BZ["Thunder Bluff"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[SHATTRATH_QUELDANAS_PORTAL] = {
		paths = BZ["Isle of Quel'Danas"],
		type = "Transport",
	}

	zones[SHATTRATH_COT_PORTAL] = {
		paths = BZ["Caverns of Time"],
		type = "Transport",
	}

	zones[MOAKI_UNUPE_BOAT] = {
		paths = {
			[BZ["Dragonblight"]] = true,
			[BZ["Borean Tundra"]] = true,
		},
		type = "Transport",
	}

	zones[MOAKI_KAMAGUA_BOAT] = {
		paths = {
			[BZ["Dragonblight"]] = true,
			[BZ["Howling Fjord"]] = true,
		},
		type = "Transport",
	}

	zones[BZ["The Dark Portal"]] = {
		paths = {
			[BZ["Blasted Lands"]] = true,
			[BZ["Hellfire Peninsula"]] = true,
		},
		type = "Transport",
	}

	zones[BZ["Deeprun Tram"]] = {
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Stormwind City"]] = true,
			[BZ["Ironforge"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[UNDERCITY_GROMGOL_ZEPPELIN] = {
		paths = {
			[BZ["Northern Stranglethorn"]] = true,
			[BZ["Tirisfal Glades"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[SILVERMOON_UNDERCITY_TELEPORT] = {
		paths = {
			[BZ["Silvermoon City"]] = true,
			[BZ["Undercity"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[DALARAN_CRYSTALSONG_TELEPORT] = {
		paths = {
			[BZ["Dalaran"]] = true,
			[BZ["Crystalsong Forest"]] = true,
		},
		type = "Transport",
	}

	zones[DALARAN_COT_PORTAL] = {
		paths = BZ["Caverns of Time"],
		type = "Transport",
	}


	zones[STORMWIND_TWILIGHTHIGHLANDS_PORTAL] = {
		paths = {
			[BZ["Twilight Highlands"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[STORMWIND_MOUNTHYJAL_PORTAL] = {
		paths = {
			[BZ["Mount Hyjal"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[STORMWIND_DEEPHOLM_PORTAL] = {
		paths = {
			[BZ["Deepholm"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[DEEPHOLM_STORMWIND_PORTAL] = {
		paths = {
			[BZ["Stormwind City"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[TOLBARAD_STORMWIND_PORTAL] = {
		paths = {
			[BZ["Stormwind City"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[STORMWIND_ULDUM_PORTAL] = {
		paths = {
			[BZ["Uldum"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[STORMWIND_VASHJIR_PORTAL] = {
		paths = {
			[BZ["Vashj'ir"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[STORMWIND_TOLBARAD_PORTAL] = {
		paths = {
			[BZ["Tol Barad Peninsula"]] = true,
		},
		faction = "Alliance",
		type = "Transport",
	}

	zones[ORGRIMMAR_TWILIGHTHIGHLANDS_PORTAL] = {
		paths = {
			[BZ["Twilight Highlands"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[ORGRIMMAR_MOUNTHYJAL_PORTAL] = {
		paths = {
			[BZ["Mount Hyjal"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[ORGRIMMAR_DEEPHOLM_PORTAL] = {
		paths = {
			[BZ["Deepholm"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}
	
	zones[DEEPHOLM_ORGRIMMAR_PORTAL] = {
		paths = {
			[BZ["Orgrimmar"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[TOLBARAD_ORGRIMMAR_PORTAL] = {
		paths = {
			[BZ["Orgrimmar"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[ORGRIMMAR_ULDUM_PORTAL] = {
		paths = {
			[BZ["Uldum"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[ORGRIMMAR_VASHJIR_PORTAL] = {
		paths = {
			[BZ["Vashj'ir"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}
	
	zones[ORGRIMMAR_TOLBARAD_PORTAL] = {
		paths = {
			[BZ["Tol Barad Peninsula"]] = true,
		},
		faction = "Horde",
		type = "Transport",
	}

	zones[BZ["Alterac Valley"]] = {
		low = 45,
		high = 85,
		continent = Eastern_Kingdoms,
		paths = BZ["Hillsbrad Foothills"],
		groupSize = 40,
		type = "Battleground",
		texture = "AlteracValley",
	}

	zones[BZ["Arathi Basin"]] = {
		low = 10,
		high = 85,
		continent = Eastern_Kingdoms,
		paths = BZ["Arathi Highlands"],
		groupSize = 15,
		type = "Battleground",
		texture = "ArathiBasin",
	}

	zones[BZ["Warsong Gulch"]] = {
		low = 10,
		high = 85,
		continent = Kalimdor,
		paths = isHorde and BZ["Northern Barrens"] or BZ["Ashenvale"],
		groupSize = 10,
		type = "Battleground",
		texture = "WarsongGulch",
	}

	zones[BZ["Ironforge"]] = {
		continent = Eastern_Kingdoms,
		instances = BZ["Gnomeregan"],
		paths = {
			[BZ["Dun Morogh"]] = true,
			[BZ["Deeprun Tram"]] = true,
			[IRONFORGE_BLASTEDLANDS_PORTAL] = true,
		},
		faction = "Alliance",
		type = "City",
		fishing_min = 75,
	}

	zones[BZ["Silvermoon City"]] = {
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Eversong Woods"]] = true,
			[SILVERMOON_UNDERCITY_TELEPORT] = true,
			[SILVERMOON_BLASTEDLANDS_PORTAL] = true,
		},
		faction = "Horde",
		type = "City",
	}

	zones[BZ["Stormwind City"]] = {
		continent = Eastern_Kingdoms,
		instances = BZ["The Stockade"],
		paths = {
			[BZ["Deeprun Tram"]] = true,
			[BZ["The Stockade"]] = true,
			[BZ["Elwynn Forest"]] = true,
			[TELDRASSIL_STORMWIND_BOAT] = true,
			[STORMWIND_BOREANTUNDRA_BOAT] = true,
			[STORMWIND_BLASTEDLANDS_PORTAL] = true,
			[STORMWIND_TWILIGHTHIGHLANDS_PORTAL] = true,
			[STORMWIND_MOUNTHYJAL_PORTAL] = true,
			[STORMWIND_DEEPHOLM_PORTAL] = true,
			[STORMWIND_ULDUM_PORTAL] = true,
			[STORMWIND_VASHJIR_PORTAL] = true,
			[STORMWIND_TOLBARAD_PORTAL] = true,
		},
		faction = "Alliance",
		type = "City",
		fishing_min = 75,
	}

	zones[BZ["Undercity"]] = {
		continent = Eastern_Kingdoms,
		instances = BZ["Ruins of Lordaeron"],
		paths = {
			[BZ["Tirisfal Glades"]] = true,
			[SILVERMOON_UNDERCITY_TELEPORT] = true,
			[UNDERCITY_BLASTEDLANDS_PORTAL] = true,
		},
		faction = "Horde",
		type = "City",
		fishing_min = 75,
	}

	zones[BZ["Dun Morogh"]] = {
		low = 1,
		high = 10,
		continent = Eastern_Kingdoms,
		instances = BZ["Gnomeregan"],
		paths = {
			[BZ["Wetlands"]] = true,
			[BZ["Gnomeregan"]] = true,
			[BZ["Ironforge"]] = true,
			[BZ["Loch Modan"]] = true,
		},
		faction = "Alliance",
		fishing_min = 25,
	}

	zones[BZ["Elwynn Forest"]] = {
		low = 1,
		high = 10,
		continent = Eastern_Kingdoms,
		instances = BZ["The Stockade"],
		paths = {
			[BZ["Westfall"]] = true,
			[BZ["Redridge Mountains"]] = true,
			[BZ["Stormwind City"]] = true,
			[BZ["Duskwood"]] = true,
			[BZ["Burning Steppes"]] = true,
		},
		faction = "Alliance",
		fishing_min = 25,
	}

	zones[BZ["Eversong Woods"]] = {
		low = 1,
		high = 10,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Silvermoon City"]] = true,
			[BZ["Ghostlands"]] = true,
		},
		faction = "Horde",
		fishing_min = 25,
	}

	zones[BZ["Tirisfal Glades"]] = {
		low = 1,
		high = 10,
		continent = Eastern_Kingdoms,
		instances = {
			[BZ["Armory"]] = true,
			[BZ["Library"]] = true,
			[BZ["Graveyard"]] = true,
			[BZ["Cathedral"]] = true,
		},
		paths = {
			[BZ["Western Plaguelands"]] = true,
			[BZ["Undercity"]] = true,
			[BZ["Scarlet Monastery"]] = true,
			[UNDERCITY_GROMGOL_ZEPPELIN] = true,
			[ORGRIMMAR_UNDERCITY_ZEPPELIN] = true,
			[UNDERCITY_HOWLINGFJORD_ZEPPELIN] = true,
			[BZ["Silverpine Forest"]] = true,
		},
		complexes = {
			[BZ["Scarlet Monastery"]] = true,
		},
		faction = "Horde",
		fishing_min = 25,
	}

	zones[BZ["Amani Pass"]] = {
		continent = Eastern_Kingdoms,
	}

	zones[BZ["Ghostlands"]] = {
		low = 10,
		high = 20,
		continent = Eastern_Kingdoms,
		instances = BZ["Zul'Aman"],
		paths = {
			[BZ["Eastern Plaguelands"]] = true,
			[BZ["Zul'Aman"]] = true,
			[BZ["Eversong Woods"]] = true,
		},
		faction = "Horde",
		fishing_min = 75,
	}

	zones[BZ["Loch Modan"]] = {
		low = 10,
		high = 20,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Wetlands"]] = true,
			[BZ["Badlands"]] = true,
			[BZ["Dun Morogh"]] = true,
			[BZ["Searing Gorge"]] = not isHorde and true or nil,
		},
		faction = "Alliance",
		fishing_min = 75,
	}

	zones[BZ["Silverpine Forest"]] = {
		low = 10,
		high = 20,
		continent = Eastern_Kingdoms,
		instances = BZ["Shadowfang Keep"],
		paths = {
			[BZ["Tirisfal Glades"]] = true,
			[BZ["Hillsbrad Foothills"]] = true,
			[BZ["Shadowfang Keep"]] = true,
			[BZ["Ruins of Gilneas"]] = true,
		},
		faction = "Horde",
		fishing_min = 75,
	}

	zones[BZ["Westfall"]] = {
		low = 10,
		high = 15,
		continent = Eastern_Kingdoms,
		instances = BZ["The Deadmines"],
		paths = {
			[BZ["Duskwood"]] = true,
			[BZ["Elwynn Forest"]] = true,
			[BZ["The Deadmines"]] = true,
		},
		faction = "Alliance",
		fishing_min = 75,
	}

	zones[BZ["Redridge Mountains"]] = {
		low = 15,
		high = 20,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Burning Steppes"]] = true,
			[BZ["Elwynn Forest"]] = true,
			[BZ["Duskwood"]] = true,
			[BZ["Swamp of Sorrows"]] = true,
		},
		fishing_min = 75,
	}

	zones[BZ["Duskwood"]] = {
		low = 20,
		high = 25,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Redridge Mountains"]] = true,
			[BZ["Northern Stranglethorn"]] = true,
			[BZ["Westfall"]] = true,
			[BZ["Deadwind Pass"]] = true,
			[BZ["Elwynn Forest"]] = true,
		},
		fishing_min = 150,
	}

	zones[BZ["Hillsbrad Foothills"]] = {
		low = 20,
		high = 25,
		continent = Eastern_Kingdoms,
		instances = BZ["Alterac Valley"],
		paths = {
			[BZ["Alterac Valley"]] = true,
			[BZ["The Hinterlands"]] = true,
			[BZ["Arathi Highlands"]] = true,
			[BZ["Silverpine Forest"]] = true,
			[BZ["Western Plaguelands"]] = true,
		},
		faction = "Horde",
		fishing_min = 150,
	}

	zones[BZ["Wetlands"]] = {
		low = 20,
		high = 25,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Arathi Highlands"]] = true,
			[MENETHIL_THERAMORE_BOAT] = true,
			[MENETHIL_HOWLINGFJORD_BOAT] = true,
			[BZ["Dun Morogh"]] = true,
			[BZ["Loch Modan"]] = true,
		},
		fishing_min = 150,
	}

	zones[BZ["Arathi Highlands"]] = {
		low = 25,
		high = 30,
		continent = Eastern_Kingdoms,
		instances = BZ["Arathi Basin"],
		paths = {
			[BZ["Wetlands"]] = true,
			[BZ["Hillsbrad Foothills"]] = true,
			[BZ["Arathi Basin"]] = true,
			[BZ["The Hinterlands"]] = true,
		},
		fishing_min = 150,
	}

	zones[BZ["Stranglethorn Vale"]] = {
		low = 25,
		high = 35,
		continent = Eastern_Kingdoms,
		instances = BZ["Zul'Gurub"],
		paths = {
			[BZ["Duskwood"]] = true,
			[BZ["Zul'Gurub"]] = true,
			[ORGRIMMAR_GROMGOL_ZEPPELIN] = true,
			[UNDERCITY_GROMGOL_ZEPPELIN] = true,
			[BOOTYBAY_RATCHET_BOAT] = true,
		},
		fishing_min = 150,
	}

	zones[BZ["Northern Stranglethorn"]] = {
		low = 25,
		high = 30,
		continent = Eastern_Kingdoms,
		instances = BZ["Zul'Gurub"],
		paths = {
			[BZ["The Cape of Stranglethorn"]] = true,
			[BZ["Duskwood"]] = true,
			[BZ["Zul'Gurub"]] = true,
			[ORGRIMMAR_GROMGOL_ZEPPELIN] = true,
			[UNDERCITY_GROMGOL_ZEPPELIN] = true,
		},
		fishing_min = 150,
	}

	zones[BZ["The Cape of Stranglethorn"]] = {
		low = 30,
		high = 35,
		continent = Eastern_Kingdoms,
		paths = {
			[BOOTYBAY_RATCHET_BOAT] = true,
			["Northern Stranglethorn"] = true,
		},
		fishing_min = 225,
	}

	zones[BZ["Badlands"]] = {
		low = 44,
		high = 48,
		continent = Eastern_Kingdoms,
		instances = BZ["Uldaman"],
		paths = {
			[BZ["Uldaman"]] = true,
			[BZ["Searing Gorge"]] = true,
			[BZ["Loch Modan"]] = true,
		},
		fishing_min = 300,
	}

	zones[BZ["Swamp of Sorrows"]] = {
		low = 52,
		high = 54,
		continent = Eastern_Kingdoms,
		instances = BZ["The Temple of Atal'Hakkar"],
		paths = {
			[BZ["Blasted Lands"]] = true,
			[BZ["Deadwind Pass"]] = true,
			[BZ["The Temple of Atal'Hakkar"]] = true,
			[BZ["Redridge Mountains"]] = true,
		},
		fishing_min = 425,
	}

	zones[BZ["The Hinterlands"]] = {
		low = 30,
		high = 35,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Hillsbrad Foothills"]] = true,
			[BZ["Western Plaguelands"]] = true,
			[BZ["Arathi Highlands"]] = true,
		},
		fishing_min = 225,
	}

	zones[BZ["Searing Gorge"]] = {
		low = 47,
		high = 51,
		continent = Eastern_Kingdoms,
		instances = {
			[BZ["Blackrock Depths"]] = true,
			[BZ["Blackrock Caverns"]] = true,
			[BZ["Blackwing Lair"]] = true,
			[BZ["Blackwing Descent"]] = true,
			[BZ["Molten Core"]] = true,
			[BZ["Blackrock Spire"]] = true,
		},
		paths = {
			[BZ["Blackrock Mountain"]] = true,
			[BZ["Badlands"]] = true,
			[BZ["Loch Modan"]] = not isHorde and true or nil,
		},
		complexes = {
			[BZ["Blackrock Mountain"]] = true,
		},
		fishing_min = 425,
	}

	zones[BZ["Blackrock Mountain"]] = {
		low = 47,
		high = 65,
		continent = Eastern_Kingdoms,
		instances = {
			[BZ["Blackrock Depths"]] = true,
			[BZ["Blackrock Caverns"]] = true,
			[BZ["Blackwing Lair"]] = true,
			[BZ["Blackwing Descent"]] = true,
			[BZ["Molten Core"]] = true,
			[BZ["Blackrock Spire"]] = true,
		},
		paths = {
			[BZ["Burning Steppes"]] = true,
			[BZ["Searing Gorge"]] = true,
			[BZ["Blackwing Lair"]] = true,
			[BZ["Blackwing Descent"]] = true,
			[BZ["Molten Core"]] = true,
			[BZ["Blackrock Depths"]] = true,
			[BZ["Blackrock Caverns"]] = true,
			[BZ["Blackrock Spire"]] = true,
		},
		type = "Complex",
		fishing_min = 1, -- lava
	}

	zones[BZ["Deadwind Pass"]] = {
		low = 55,
		high = 60,
		continent = Eastern_Kingdoms,
		instances = BZ["Karazhan"],
		paths = {
			[BZ["Duskwood"]] = true,
			[BZ["Swamp of Sorrows"]] = true,
			[BZ["Karazhan"]] = true,
		},
		fishing_min = 425,
	}

	zones[BZ["Blasted Lands"]] = {
		low = 54,
		high = 60,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["The Dark Portal"]] = true,
			[BZ["Swamp of Sorrows"]] = true,
		},
		fishing_min = 425
	}

	zones[BZ["Burning Steppes"]] = {
		low = 49,
		high = 52,
		continent = Eastern_Kingdoms,
		instances = {
			[BZ["Blackrock Depths"]] = true,
			[BZ["Blackrock Caverns"]] = true,
			[BZ["Blackwing Lair"]] = true,
			[BZ["Blackwing Descent"]] = true,
			[BZ["Molten Core"]] = true,
			[BZ["Blackrock Spire"]] = true,
		},
		paths = {
			[BZ["Blackrock Mountain"]] = true,
			[BZ["Redridge Mountains"]] = true,
			[BZ["Elwynn Forest"]] = true,
		},
		complexes = {
			[BZ["Blackrock Mountain"]] = true,
		},
		fishing_min = 425,
	}

	zones[BZ["Western Plaguelands"]] = {
		low = 35,
		high = 40,
		continent = Eastern_Kingdoms,
		instances = BZ["Scholomance"],
		paths = {
			[BZ["The Hinterlands"]] = true,
			[BZ["Eastern Plaguelands"]] = true,
			[BZ["Tirisfal Glades"]] = true,
			[BZ["Scholomance"]] = true,
			[BZ["Hillsbrad Foothills"]] = true,
		},
		fishing_min = 225,
	}

	zones[BZ["Eastern Plaguelands"]] = {
		low = 40,
		high = 45,
		continent = Eastern_Kingdoms,
		instances = BZ["Stratholme"],
		paths = {
			[BZ["Western Plaguelands"]] = true,
			[BZ["Stratholme"]] = true,
			[BZ["Ghostlands"]] = true,
		},
		type = "PvP Zone",
		fishing_min = 300,
	}

	zones[BZ["The Deadmines"]] = {
		low = 15,
		high = 21,
		continent = Eastern_Kingdoms,
		paths = BZ["Westfall"],
		groupSize = 5,
		faction = "Alliance",
		type = "Instance",
		fishing_min = 75,
		entrancePortal = { BZ["Westfall"], 42.6, 72.2 },
	}

	zones[BZ["Shadowfang Keep"]] = {
		low = 16,
		high = 26,
		continent = Eastern_Kingdoms,
		paths = BZ["Silverpine Forest"],
		groupSize = 5,
		faction = "Horde",
		type = "Instance",
		entrancePortal = { BZ["Silverpine Forest"], 44.80, 67.83 },
	}

	zones[BZ["The Stockade"]] = {
		low = 20,
		high = 30,
		continent = Eastern_Kingdoms,
		paths = BZ["Stormwind City"],
		groupSize = 5,
		faction = "Alliance",
		type = "Instance",
		entrancePortal = { BZ["Stormwind City"], 50.5, 66.3 },
	}

	zones[BZ["Gnomeregan"]] = {
		low = 24,
		high = 34,
		continent = Eastern_Kingdoms,
		paths = BZ["Dun Morogh"],
		groupSize = 5,
		faction = "Alliance",
		type = "Instance",
		entrancePortal = { BZ["Dun Morogh"], 24, 38.9 },
	}

	zones[BZ["Scarlet Monastery"]] = {
		low = 26,
		high = 45,
		continent = Eastern_Kingdoms,
		instances = {
			[BZ["Armory"]] = true,
			[BZ["Library"]] = true,
			[BZ["Graveyard"]] = true,
			[BZ["Cathedral"]] = true,
		},
		paths = {
			[BZ["Tirisfal Glades"]] = true,
			[BZ["Armory"]] = true,
			[BZ["Library"]] = true,
			[BZ["Graveyard"]] = true,
			[BZ["Cathedral"]] = true,
		},
		faction = "Horde",
		fishing_min = 225,
		type = "Complex",
	}

	zones[BZ["Graveyard"]] = {
		low = 26,
		high = 36,
		continent = Eastern_Kingdoms,
		paths = BZ["Scarlet Monastery"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Scarlet Monastery"],
		entrancePortal = { BZ["Tirisfal Glades"], 84.88, 30.63 },
	}

	zones[BZ["Library"]] = {
		low = 29,
		high = 39,
		continent = Eastern_Kingdoms,
		paths = BZ["Scarlet Monastery"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Scarlet Monastery"],
		entrancePortal = { BZ["Tirisfal Glades"], 85.30, 32.17 },
	}

	zones[BZ["Armory"]] = {
		low = 32,
		high = 42,
		continent = Eastern_Kingdoms,
		paths = BZ["Scarlet Monastery"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Scarlet Monastery"],
		entrancePortal = { BZ["Tirisfal Glades"], 85.63, 31.62 },
	}

	zones[BZ["Cathedral"]] = {
		low = 35,
		high = 45,
		continent = Eastern_Kingdoms,
		paths = BZ["Scarlet Monastery"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Scarlet Monastery"],
		entrancePortal = { BZ["Tirisfal Glades"], 85.35, 30.57 },
	}

	zones[BZ["Uldaman"]] = {
		low = 35,
		high = 45,
		continent = Eastern_Kingdoms,
		paths = BZ["Badlands"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Badlands"], 42.4, 18.6 },
	}

	zones[BZ["The Temple of Atal'Hakkar"]] = {
		low = 50,
		high = 60,
		continent = Eastern_Kingdoms,
		paths = BZ["Swamp of Sorrows"],
		groupSize = 5,
		type = "Instance",
		fishing_min = 300,
		entrancePortal = { BZ["Swamp of Sorrows"], 70, 54 },
	}

	zones[BZ["Blackrock Depths"]] = {
		low = 47,
		high = 61,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Molten Core"]] = true,
			[BZ["Blackrock Mountain"]] = true,
		},
		groupSize = 5,
		type = "Instance",
		complex = BZ["Blackrock Mountain"],
		entrancePortal = { BZ["Searing Gorge"], 35.4, 84.4 },
	}

	zones[BZ["Blackrock Spire"]] = {
		low = 55,
		high = 65,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Blackrock Mountain"]] = true,
			[BZ["Blackwing Lair"]] = true,
			[BZ["Blackwing Descent"]] = true,
		},
		groupSize = 5,
		altGroupSize = 10,
		type = "Instance",
		complex = BZ["Blackrock Mountain"],
		entrancePortal = { BZ["Burning Steppes"], 29.7, 37.5 },
	}

	zones[BZ["Scholomance"]] = {
		low = 38,
		high = 48,
		continent = Eastern_Kingdoms,
		paths = BZ["Western Plaguelands"],
		groupSize = 5,
		type = "Instance",
		fishing_min = 425,
		entrancePortal = { BZ["Western Plaguelands"], 69.4, 72.8 },
	}

	zones[BZ["Stratholme"]] = {
		low = 42,
		high = 56,
		continent = Eastern_Kingdoms,
		paths = BZ["Eastern Plaguelands"],
		groupSize = 5,
		type = "Instance",
		fishing_min = 425,
		entrancePortal = { BZ["Eastern Plaguelands"], 30.8, 14.4 },
	}

	zones[BZ["Blackwing Lair"]] = {
		low = 60,
		high = 62,
		continent = Eastern_Kingdoms,
		paths = BZ["Blackrock Mountain"],
		groupSize = 40,
		type = "Instance",
		complex = BZ["Blackrock Mountain"],
		entrancePortal = { BZ["Burning Steppes"], 29.7, 37.5 },
	}

	zones[BZ["Molten Core"]] = {
		low = 60,
		high = 62,
		continent = Eastern_Kingdoms,
		paths = BZ["Blackrock Mountain"],
		groupSize = 40,
		type = "Instance",
		complex = BZ["Blackrock Mountain"],
		fishing_min = 1,  -- lava
		entrancePortal = { BZ["Searing Gorge"], 35.4, 84.4 },
	}

	zones[BZ["Karazhan"]] = {
		low = 70,
		high = 72,
		continent = Eastern_Kingdoms,
		paths = BZ["Deadwind Pass"],
		groupSize = 10,
		type = "Instance",
		entrancePortal = { BZ["Deadwind Pass"], 40.9, 73.2 },
	}

	zones[BZ["Zul'Aman"]] = {
		low = 85,
		high = 85,
		continent = Eastern_Kingdoms,
		paths = BZ["Ghostlands"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Ghostlands"], 77.7, 63.2 },
		fishing_min = 425,
	}

	zones[BZ["Zul'Gurub"]] = {
		low = 85,
		high = 85,
		continent = Eastern_Kingdoms,
		paths = BZ["Northern Stranglethorn"],
		groupSize = 5,
		type = "Instance",
--		fishing_min = 330,
		entrancePortal = { BZ["Northern Stranglethorn"], 52.2, 17.1 },
	}

	zones[BZ["Darnassus"]] = {
		continent = Kalimdor,
		paths = {
			[BZ["Teldrassil"]] = true,
			[DARNASSUS_BLASTEDLANDS_PORTAL] = true,
			[DARNASSUS_EXODAR_PORTAL] = true,
		},
		faction = "Alliance",
		type = "City",
		fishing_min = 75,
	}

	zones[BZ["Moonglade"]] = {
		continent = Kalimdor,
		low = 55,
		high = 60,
		paths = {
			[BZ["Felwood"]] = true,
			[BZ["Winterspring"]] = true,
		},
		fishing_min = 300,
	}

	zones[BZ["Orgrimmar"]] = {
		continent = Kalimdor,
		instances = {
			[BZ["Ragefire Chasm"]] = true,
			[BZ["The Ring of Valor"]] = true,
		},
		paths = {
			[BZ["Durotar"]] = true,
			[BZ["Ragefire Chasm"]] = true,
			[BZ["Azshara"]] = true,
			[ORGRIMMAR_UNDERCITY_ZEPPELIN] = true,
			[ORGRIMMAR_GROMGOL_ZEPPELIN] = true,
			[ORGRIMMAR_BOREANTUNDRA_ZEPPELIN] = true,
			[ORGRIMMAR_THUNDERBLUFF_ZEPPELIN] = true,
			[ORGRIMMAR_BLASTEDLANDS_PORTAL] = true,
			[ORGRIMMAR_TWILIGHTHIGHLANDS_PORTAL] = true,
			[ORGRIMMAR_MOUNTHYJAL_PORTAL] = true,
			[ORGRIMMAR_DEEPHOLM_PORTAL] = true,
			[ORGRIMMAR_ULDUM_PORTAL] = true,
			[ORGRIMMAR_VASHJIR_PORTAL] = true,
			[ORGRIMMAR_TOLBARAD_PORTAL] = true,
		},
		faction = "Horde",
		type = "City",
		fishing_min = 75,
	}

	zones[BZ["The Exodar"]] = {
		continent = Kalimdor,
		paths = {
			[BZ["Azuremyst Isle"]] = true,
			[EXODAR_BLASTEDLANDS_PORTAL] = true,
			[EXODAR_DARNASSUS_PORTAL] = true,
		},
		faction = "Alliance",
		type = "City",
	}

	zones[BZ["Thunder Bluff"]] = {
		continent = Kalimdor,
		paths = {
			[BZ["Mulgore"]] = true,
			[ORGRIMMAR_THUNDERBLUFF_ZEPPELIN] = true,
			[THUNDERBLUFF_BLASTEDLANDS_PORTAL] = true,
		},
		faction = "Horde",
		type = "City",
		fishing_min = 75,
	}

	zones[BZ["Azuremyst Isle"]] = {
		low = 1,
		high = 10,
		continent = Kalimdor,
		paths = {
			[BZ["The Exodar"]] = true,
			[BZ["Bloodmyst Isle"]] = true,
			[TELDRASSIL_AZUREMYST_BOAT] = true,
		},
		faction = "Alliance",
		fishing_min = 25,
	}

	zones[BZ["Durotar"]] = {
		low = 1,
		high = 10,
		continent = Kalimdor,
		instances = BZ["Ragefire Chasm"],
		paths = {
			[BZ["Northern Barrens"]] = true,
			[BZ["Orgrimmar"]] = true,
		},
		faction = "Horde",
		fishing_min = 25,
	}

	zones[BZ["Mulgore"]] = {
		low = 1,
		high = 10,
		continent = Kalimdor,
		paths = {
			[BZ["Thunder Bluff"]] = true,
			[BZ["Southern Barrens"]] = true,
		},
		faction = "Horde",
		fishing_min = 25,
	}

	zones[BZ["Teldrassil"]] = {
		low = 1,
		high = 10,
		continent = Kalimdor,
		paths = {
			[BZ["Darnassus"]] = true,
			[TELDRASSIL_AZUREMYST_BOAT] = true,
			[TELDRASSIL_STORMWIND_BOAT] = true,
		},
		faction = "Alliance",
		fishing_min = 25,
	}

	zones[BZ["Bloodmyst Isle"]] = {
		low = 10,
		high = 20,
		continent = Kalimdor,
		paths = BZ["Azuremyst Isle"],
		faction = "Alliance",
		fishing_min = 75,
	}

	zones[BZ["Darkshore"]] = {
		low = 10,
		high = 20,
		continent = Kalimdor,
		paths = {
			[BZ["Ashenvale"]] = true,
		},
		faction = "Alliance",
		fishing_min = 75,
	}

	zones[BZ["Northern Barrens"]] = {
		low = 10,
		high = 20,
		continent = Kalimdor,
		instances = {
			[BZ["Wailing Caverns"]] = true,
			[BZ["Warsong Gulch"]] = isHorde and true or nil,
		},
		paths = {
			[BZ["Southern Barrens"]] = true,
			[BZ["Ashenvale"]] = true,
			[BZ["Durotar"]] = true,
			[BZ["Wailing Caverns"]] = true,
			[BOOTYBAY_RATCHET_BOAT] = true,
			[BZ["Warsong Gulch"]] = isHorde and true or nil,
			[BZ["Stonetalon Mountains"]] = true,
		},
		faction = "Horde",
		fishing_min = 75,
	}

	zones[BZ["Southern Barrens"]] = {
		low = 30,
		high = 35,
		continent = Kalimdor,
		instances = {
			[BZ["Razorfen Kraul"]] = true,
		},
		paths = {
			[BZ["Northern Barrens"]] = true,
			[BZ["Thousand Needles"]] = true,
			[BZ["Razorfen Kraul"]] = true,
			[BZ["Dustwallow Marsh"]] = true,
			[BZ["Stonetalon Mountains"]] = true,
			[BZ["Mulgore"]] = true,
		},
		fishing_min = 225,
	}

	zones[BZ["Stonetalon Mountains"]] = {
		low = 25,
		high = 30,
		continent = Kalimdor,
		paths = {
			[BZ["Desolace"]] = true,
			[BZ["Northern Barrens"]] = true,
			[BZ["Southern Barrens"]] = true,
			[BZ["Ashenvale"]] = true,
		},
		fishing_min = 150,
	}

	zones[BZ["Ashenvale"]] = {
		low = 20,
		high = 25,
		continent = Kalimdor,
		instances = {
			[BZ["Blackfathom Deeps"]] = true,
			[BZ["Warsong Gulch"]] = not isHorde and true or nil,
		},
		paths = {
			[BZ["Azshara"]] = true,
			[BZ["Northern Barrens"]] = true,
			[BZ["Blackfathom Deeps"]] = true,
			[BZ["Warsong Gulch"]] = not isHorde and true or nil,
			[BZ["Felwood"]] = true,
			[BZ["Darkshore"]] = true,
			[BZ["Stonetalon Mountains"]] = true,
		},
		fishing_min = 150,
	}

	zones[BZ["Thousand Needles"]] = {
		low = 40,
		high = 45,
		continent = Kalimdor,
		instances = {
			[BZ["Razorfen Downs"]] = true,
		},
		paths = {
			[BZ["Feralas"]] = true,
			[BZ["Southern Barrens"]] = true,
			[BZ["Tanaris"]] = true,
			[BZ["Dustwallow Marsh"]] = true,
			[BZ["Razorfen Downs"]] = true,
		},
		fishing_min = 300,
	}

	zones[BZ["Desolace"]] = {
		low = 30,
		high = 35,
		continent = Kalimdor,
		instances = BZ["Maraudon"],
		paths = {
			[BZ["Feralas"]] = true,
			[BZ["Stonetalon Mountains"]] = true,
			[BZ["Maraudon"]] = true,
		},
		fishing_min = 225,
	}

	zones[BZ["Dustwallow Marsh"]] = {
		low = 35,
		high = 40,
		continent = Kalimdor,
		instances = BZ["Onyxia's Lair"],
		paths = {
			[BZ["Onyxia's Lair"]] = true,
			[BZ["Southern Barrens"]] = true,
			[BZ["Thousand Needles"]] = true,
			[MENETHIL_THERAMORE_BOAT] = true,
		},
		fishing_min = 225,
	}

	zones[BZ["Feralas"]] = {
		low = 35,
		high = 40,
		continent = Kalimdor,
		instances = BZ["Dire Maul"],
		paths = {
			[BZ["Thousand Needles"]] = true,
			[BZ["Desolace"]] = true,
			[BZ["Dire Maul"]] = true,
		},
		fishing_min = 225,
	}

	zones[BZ["Tanaris"]] = {
		low = 45,
		high = 50,
		continent = Kalimdor,
		instances = {
			[BZ["Zul'Farrak"]] = true,
			[BZ["Old Hillsbrad Foothills"]] = true,
			[BZ["The Black Morass"]] = true,
			[BZ["Hyjal Summit"]] = true,
			[BZ["The Culling of Stratholme"]] = true,
			[BZ["End Time"]] = true,
			[BZ["Hour of Twilight"]] = true,
			[BZ["Well of Eternity"]] = true,
			[BZ["Dragon Soul"]] = true,
		},
		paths = {
			[BZ["Thousand Needles"]] = true,
			[BZ["Un'Goro Crater"]] = true,
			[BZ["Zul'Farrak"]] = true,
			[BZ["Caverns of Time"]] = true,
			[BZ["Uldum"]] = true,
		},
		complexes = {
			[BZ["Caverns of Time"]] = true,
		},
		fishing_min = 300,
	}

	zones[BZ["Azshara"]] = {
		low = 10,
		high = 20,
		continent = Kalimdor,
		paths = BZ["Ashenvale"],
		paths = BZ["Orgrimmar"],
		fishing_min = 75,
		faction = "Horde",
	}

	zones[BZ["Felwood"]] = {
		low = 45,
		high = 50,
		continent = Kalimdor,
		paths = {
			[BZ["Winterspring"]] = true,
			[BZ["Moonglade"]] = true,
			[BZ["Ashenvale"]] = true,
		},
		fishing_min = 300,
	}

	zones[BZ["Un'Goro Crater"]] = {
		low = 50,
		high = 55,
		continent = Kalimdor,
		paths = {
			[BZ["Silithus"]] = true,
			[BZ["Tanaris"]] = true,
		},
		fishing_min = 375,
	}

	zones[BZ["Silithus"]] = {
		low = 55,
		high = 60,
		continent = Kalimdor,
		paths = {
			[BZ["Ruins of Ahn'Qiraj"]] = true,
			[BZ["Un'Goro Crater"]] = true,
			[BZ["Ahn'Qiraj: The Fallen Kingdom"]] = true,
		},
		instances = {
			[BZ["Temple of Ahn'Qiraj"]] = true,
			[BZ["Ruins of Ahn'Qiraj"]] = true,
		},
		complexes = {
			[BZ["Ahn'Qiraj: The Fallen Kingdom"]] = true,
		},
		type = "PvP Zone",
		fishing_min = 425,
	}

	zones[BZ["Winterspring"]] = {
		low = 50,
		high = 55,
		continent = Kalimdor,
		paths = {
			[BZ["Felwood"]] = true,
			[BZ["Moonglade"]] = true,
			[BZ["Mount Hyjal"]] = true,
		},
		fishing_min = 425,
	}

	zones[BZ["Ragefire Chasm"]] = {
		low = 15,
		high = 21,
		continent = Kalimdor,
		paths = BZ["Orgrimmar"],
		groupSize = 5,
		faction = "Horde",
		type = "Instance",
		entrancePortal = { BZ["Orgrimmar"], 52.8, 49 },
	}

	zones[BZ["Wailing Caverns"]] = {
		low = 15,
		high = 25,
		continent = Kalimdor,
		paths = BZ["Northern Barrens"],
		groupSize = 5,
		faction = "Horde",
		type = "Instance",
		fishing_min = 75,
		entrancePortal = { BZ["Northern Barrens"], 42.1, 66.5 },
	}

	zones[BZ["Blackfathom Deeps"]] = {
		low = 20,
		high = 30,
		continent = Kalimdor,
		paths = BZ["Ashenvale"],
		groupSize = 5,
		type = "Instance",
		fishing_min = 75,
		entrancePortal = { BZ["Ashenvale"], 14.6, 15.3 },
	}

	zones[BZ["Razorfen Kraul"]] = {
		low = 30,
		high = 40,
		continent = Kalimdor,
		paths = BZ["Southern Barrens"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Southern Barrens"], 40.8, 94.5 },
	}

	zones[BZ["Razorfen Downs"]] = {
		low = 40,
		high = 50,
		continent = Kalimdor,
		paths = BZ["Thousand Needles"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Thousand Needles"], 47.5, 23.7 },
	}

	zones[BZ["Zul'Farrak"]] = {
		low = 44,
		high = 54,
		continent = Kalimdor,
		paths = BZ["Tanaris"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Tanaris"], 36, 11.7 },
	}

	zones[BZ["Maraudon"]] = {
		low = 30,
		high = 44,
		continent = Kalimdor,
		paths = BZ["Desolace"],
		groupSize = 5,
		type = "Instance",
		fishing_min = 300,
		entrancePortal = { BZ["Desolace"], 29, 62.4 },
	}

	zones[BZ["Dire Maul"]] = {
		low = 36,
		high = 52,
		continent = Kalimdor,
		paths = BZ["Feralas"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Feralas"], 58.5, 44.1 },
	}

	zones[BZ["Onyxia's Lair"]] = {
		low = 80,
		high = 80,
		continent = Kalimdor,
		paths = BZ["Dustwallow Marsh"],
		groupSize = 10,
		altGroupSize = 25,
		type = "Instance",
		entrancePortal = { BZ["Dustwallow Marsh"], 52, 76 },
	}

	zones[BZ["Temple of Ahn'Qiraj"]] = {
		low = 60,
		high = 63,
		continent = Kalimdor,
		paths = BZ["Ahn'Qiraj: The Fallen Kingdom"],
		groupSize = 40,
		type = "Instance",
		complex = BZ["Ahn'Qiraj: The Fallen Kingdom"],
		entrancePortal = { BZ["Ahn'Qiraj: The Fallen Kingdom"], 46.6, 7.4 },
	}

	zones[BZ["Ruins of Ahn'Qiraj"]] = {
		low = 60,
		high = 63,
		continent = Kalimdor,
		paths = BZ["Ahn'Qiraj: The Fallen Kingdom"],
		groupSize = 20,
		type = "Instance",
		complex = BZ["Ahn'Qiraj: The Fallen Kingdom"],
		entrancePortal = { BZ["Ahn'Qiraj: The Fallen Kingdom"], 58.9, 14.3 },
	}

	zones[BZ["Caverns of Time"]] = {
		low = 64,
		high = 85,
		continent = Kalimdor,
		instances = {
			[BZ["Old Hillsbrad Foothills"]] = true,
			[BZ["The Black Morass"]] = true,
			[BZ["Hyjal Summit"]] = true,
			[BZ["The Culling of Stratholme"]] = true,
			[BZ["End Time"]] = true,
			[BZ["Hour of Twilight"]] = true,
			[BZ["Well of Eternity"]] = true,
			[BZ["Dragon Soul"]] = true,
		},
		paths = {
			[BZ["Tanaris"]] = true,
			[BZ["Old Hillsbrad Foothills"]] = true,
			[BZ["The Black Morass"]] = true,
			[BZ["Hyjal Summit"]] = true,
			[BZ["The Culling of Stratholme"]] = true,
		},
		type = "Complex",
	}

	zones[BZ["Old Hillsbrad Foothills"]] = {
		low = 64,
		high = 73,
		continent = Kalimdor,
		paths = BZ["Caverns of Time"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Caverns of Time"],
		entrancePortal = { BZ["Tanaris"], 66.2, 49.3 },
	}

	zones[BZ["The Black Morass"]] = {
		low = 68,
		high = 75,
		continent = Kalimdor,
		paths = BZ["Caverns of Time"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Caverns of Time"],
		entrancePortal = { BZ["Tanaris"], 66.2, 49.3 },
	}

	zones[BZ["The Culling of Stratholme"]] = {
		low = 77,
		high = 82,
		continent = Kalimdor,
		paths = BZ["Caverns of Time"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Caverns of Time"],
		entrancePortal = { BZ["Tanaris"], 66.2, 49.3 },
	}

	zones[BZ["Hyjal Summit"]] = {
		low = 70,
		high = 72,
		continent = Kalimdor,
		paths = BZ["Caverns of Time"],
		groupSize = 25,
		type = "Instance",
		complex = BZ["Caverns of Time"],
		entrancePortal = { BZ["Tanaris"], 66.2, 49.3 },
	}

	zones[BZ["Shattrath City"]] = {
		continent = Outland,
		paths = {
			[BZ["Terokkar Forest"]] = true,
			[BZ["Nagrand"]] = true,
			[SHATTRATH_QUELDANAS_PORTAL] = true,
			--[SHATTRATH_COT_PORTAL] = true,
		},
		faction = "Sanctuary",
		type = "City",
	}

	zones[BZ["Hellfire Citadel"]] = {
		low = 57,
		high = 75,
		continent = Outland,
		instances = {
			[BZ["The Blood Furnace"]] = true,
			[BZ["Hellfire Ramparts"]] = true,
			[BZ["Magtheridon's Lair"]] = true,
			[BZ["The Shattered Halls"]] = true,
		},
		paths = {
			[BZ["Hellfire Peninsula"]] = true,
			[BZ["The Blood Furnace"]] = true,
			[BZ["Hellfire Ramparts"]] = true,
			[BZ["Magtheridon's Lair"]] = true,
			[BZ["The Shattered Halls"]] = true,
		},
		type = "Complex",
	}

	zones[BZ["Hellfire Peninsula"]] = {
		low = 58,
		high = 63,
		continent = Outland,
		instances = {
			[BZ["The Blood Furnace"]] = true,
			[BZ["Hellfire Ramparts"]] = true,
			[BZ["Magtheridon's Lair"]] = true,
			[BZ["The Shattered Halls"]] = true,
		},
		paths = {
			[BZ["Zangarmarsh"]] = true,
			[BZ["The Dark Portal"]] = true,
			[BZ["Terokkar Forest"]] = true,
			[BZ["Hellfire Citadel"]] = true,
			[HELLFIRE_ORGRIMMAR_PORTAL] = true,
			[HELLFIRE_STORMWIND_PORTAL] = true,
		},
		complexes = {
			[BZ["Hellfire Citadel"]] = true,
		},
		type = "PvP Zone",
		fishing_min = 375,
	}

	zones[BZ["Coilfang Reservoir"]] = {
		low = 60,
		high = 75,
		continent = Outland,
		instances = {
			[BZ["The Underbog"]] = true,
			[BZ["Serpentshrine Cavern"]] = true,
			[BZ["The Steamvault"]] = true,
			[BZ["The Slave Pens"]] = true,
		},
		paths = {
			[BZ["Zangarmarsh"]] = true,
			[BZ["The Underbog"]] = true,
			[BZ["Serpentshrine Cavern"]] = true,
			[BZ["The Steamvault"]] = true,
			[BZ["The Slave Pens"]] = true,
		},
		fishing_min = 400,
		type = "Complex",
	}

	zones[BZ["Zangarmarsh"]] = {
		low = 60,
		high = 64,
		continent = Outland,
		instances = {
			[BZ["The Underbog"]] = true,
			[BZ["Serpentshrine Cavern"]] = true,
			[BZ["The Steamvault"]] = true,
			[BZ["The Slave Pens"]] = true,
		},
		paths = {
			[BZ["Coilfang Reservoir"]] = true,
			[BZ["Blade's Edge Mountains"]] = true,
			[BZ["Terokkar Forest"]] = true,
			[BZ["Nagrand"]] = true,
			[BZ["Hellfire Peninsula"]] = true,
		},
		complexes = {
			[BZ["Coilfang Reservoir"]] = true,
		},
		type = "PvP Zone",
		fishing_min = 400,
	}

	zones[BZ["Ring of Observance"]] = {
		low = 62,
		high = 75,
		continent = Outland,
		instances = {
			[BZ["Mana-Tombs"]] = true,
			[BZ["Sethekk Halls"]] = true,
			[BZ["Shadow Labyrinth"]] = true,
			[BZ["Auchenai Crypts"]] = true,
		},
		paths = {
			[BZ["Terokkar Forest"]] = true,
			[BZ["Mana-Tombs"]] = true,
			[BZ["Sethekk Halls"]] = true,
			[BZ["Shadow Labyrinth"]] = true,
			[BZ["Auchenai Crypts"]] = true,
		},
		type = "Complex",
	}

	zones[BZ["Terokkar Forest"]] = {
		low = 62,
		high = 65,
		continent = Outland,
		instances = {
			[BZ["Mana-Tombs"]] = true,
			[BZ["Sethekk Halls"]] = true,
			[BZ["Shadow Labyrinth"]] = true,
			[BZ["Auchenai Crypts"]] = true,
		},
		paths = {
			[BZ["Ring of Observance"]] = true,
			[BZ["Shadowmoon Valley"]] = true,
			[BZ["Zangarmarsh"]] = true,
			[BZ["Shattrath City"]] = true,
			[BZ["Hellfire Peninsula"]] = true,
			[BZ["Nagrand"]] = true,
		},
		complexes = {
			[BZ["Ring of Observance"]] = true,
		},
		type = "PvP Zone",
		fishing_min = 450,
	}

	zones[BZ["Nagrand"]] = {
		low = 64,
		high = 67,
		continent = Outland,
		instances = {
			[BZ["Nagrand Arena"]] = true,
		},
		paths = {
			[BZ["Zangarmarsh"]] = true,
			[BZ["Shattrath City"]] = true,
			[BZ["Terokkar Forest"]] = true,
		},
		type = "PvP Zone",
		fishing_min = 475,
	}

	zones[BZ["Blade's Edge Mountains"]] = {
		low = 65,
		high = 68,
		continent = Outland,
		instances = 
		{
			[BZ["Gruul's Lair"]] = true,
			[BZ["Blade's Edge Arena"]] = true,
		},
		paths = {
			[BZ["Netherstorm"]] = true,
			[BZ["Zangarmarsh"]] = true,
			[BZ["Gruul's Lair"]] = true,
		},
	}

	zones[BZ["Tempest Keep"]] = {
		low = 67,
		high = 75,
		continent = Outland,
		instances = {
			[BZ["The Mechanar"]] = true,
			[BZ["The Eye"]] = true,
			[BZ["The Botanica"]] = true,
			[BZ["The Arcatraz"]] = true,
		},
		paths = {
			[BZ["Netherstorm"]] = true,
			[BZ["The Mechanar"]] = true,
			[BZ["The Eye"]] = true,
			[BZ["The Botanica"]] = true,
			[BZ["The Arcatraz"]] = true,
		},
		type = "Complex",
	}

	zones[BZ["Netherstorm"]] = {
		low = 67,
		high = 70,
		continent = Outland,
		instances = {
			[BZ["The Mechanar"]] = true,
			[BZ["The Botanica"]] = true,
			[BZ["The Arcatraz"]] = true,
			[BZ["The Eye"]] = true,
			[BZ["Eye of the Storm"]] = true,
		},
		paths = {
			[BZ["Tempest Keep"]] = true,
			[BZ["Blade's Edge Mountains"]] = true,
		},
		complexes = {
			[BZ["Tempest Keep"]] = true,
		},
		fishing_min = 475,
	}

	zones[BZ["Shadowmoon Valley"]] = {
		low = 67,
		high = 70,
		continent = Outland,
		instances = BZ["Black Temple"],
		paths = {
			[BZ["Terokkar Forest"]] = true,
			[BZ["Black Temple"]] = true,
		},
		fishing_min = 375,
	}

	zones[BZ["Black Temple"]] = {
		low = 70,
		high = 72,
		continent = Outland,
		paths = BZ["Shadowmoon Valley"],
		groupSize = 25,
		type = "Instance",
		entrancePortal = { BZ["Shadowmoon Valley"], 77.7, 43.7 },
	}

	zones[BZ["Auchenai Crypts"]] = {
		low = 63,
		high = 72,
		continent = Outland,
		paths = BZ["Ring of Observance"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Ring of Observance"],
		entrancePortal = { BZ["Terokkar Forest"], 39.6, 65.5 },
	}

	zones[BZ["Shadow Labyrinth"]] = {
		low = 67,
		high = 75,
		continent = Outland,
		paths = BZ["Ring of Observance"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Ring of Observance"],
		entrancePortal = { BZ["Terokkar Forest"], 39.6, 65.5 },
	}

	zones[BZ["Sethekk Halls"]] = {
		low = 65,
		high = 73,
		continent = Outland,
		paths = BZ["Ring of Observance"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Ring of Observance"],
		entrancePortal = { BZ["Terokkar Forest"], 39.6, 65.5 },
	}

	zones[BZ["Mana-Tombs"]] = {
		low = 62,
		high = 71,
		continent = Outland,
		paths = BZ["Ring of Observance"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Ring of Observance"],
		entrancePortal = { BZ["Terokkar Forest"], 39.6, 65.5 },
	}

	zones[BZ["Hellfire Ramparts"]] = {
		low = 57,
		high = 67,
		continent = Outland,
		paths = BZ["Hellfire Citadel"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Hellfire Citadel"],
		entrancePortal = { BZ["Hellfire Peninsula"], 46.8, 54.9 },
	}

	zones[BZ["The Blood Furnace"]] = {
		low = 59,
		high = 68,
		continent = Outland,
		paths = BZ["Hellfire Citadel"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Hellfire Citadel"],
		entrancePortal = { BZ["Hellfire Peninsula"], 46.8, 54.9 },
	}

	zones[BZ["The Shattered Halls"]] = {
		low = 67,
		high = 75,
		continent = Outland,
		paths = BZ["Hellfire Citadel"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Hellfire Citadel"],
		entrancePortal = { BZ["Hellfire Peninsula"], 46.8, 54.9 },
	}

	zones[BZ["Magtheridon's Lair"]] = {
		low = 70,
		high = 72,
		continent = Outland,
		paths = BZ["Hellfire Citadel"],
		groupSize = 25,
		type = "Instance",
		complex = BZ["Hellfire Citadel"],
		entrancePortal = { BZ["Hellfire Peninsula"], 46.8, 54.9 },
	}

	zones[BZ["The Slave Pens"]] = {
		low = 60,
		high = 69,
		continent = Outland,
		paths = BZ["Coilfang Reservoir"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Coilfang Reservoir"],
		entrancePortal = { BZ["Zangarmarsh"], 50.2, 40.8 },
	}

	zones[BZ["The Underbog"]] = {
		low = 61,
		high = 70,
		continent = Outland,
		paths = BZ["Coilfang Reservoir"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Coilfang Reservoir"],
		entrancePortal = { BZ["Zangarmarsh"], 50.2, 40.8 },
	}

	zones[BZ["The Steamvault"]] = {
		low = 67,
		high = 75,
		continent = Outland,
		paths = BZ["Coilfang Reservoir"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Coilfang Reservoir"],
		entrancePortal = { BZ["Zangarmarsh"], 50.2, 40.8 },
	}

	zones[BZ["Serpentshrine Cavern"]] = {
		low = 70,
		high = 72,
		continent = Outland,
		paths = BZ["Coilfang Reservoir"],
		groupSize = 25,
		type = "Instance",
		complex = BZ["Coilfang Reservoir"],
		entrancePortal = { BZ["Zangarmarsh"], 50.2, 40.8 },
	}

	zones[BZ["Gruul's Lair"]] = {
		low = 70,
		high = 72,
		continent = Outland,
		paths = BZ["Blade's Edge Mountains"],
		groupSize = 25,
		type = "Instance",
		entrancePortal = { BZ["Blade's Edge Mountains"], 68, 24 },
	}

	zones[BZ["The Mechanar"]] = {
		low = 67,
		high = 75,
		continent = Outland,
		paths = BZ["Tempest Keep"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Tempest Keep"],
		entrancePortal = { BZ["Netherstorm"], 76.5, 65.1 },
	}

	zones[BZ["The Botanica"]] = {
		low = 67,
		high = 75,
		continent = Outland,
		paths = BZ["Tempest Keep"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Tempest Keep"],
		entrancePortal = { BZ["Netherstorm"], 76.5, 65.1 },
	}

	zones[BZ["The Arcatraz"]] = {
		low = 68,
		high = 75,
		continent = Outland,
		paths = BZ["Tempest Keep"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Tempest Keep"],
		entrancePortal = { BZ["Netherstorm"], 76.5, 65.1 },
	}

	zones[BZ["The Eye"]] = {
		low = 70,
		high = 72,
		continent = Outland,
		paths = BZ["Tempest Keep"],
		groupSize = 25,
		type = "Instance",
		complex = BZ["Tempest Keep"],
		entrancePortal = { BZ["Netherstorm"], 76.5, 65.1 },
	}

	zones[BZ["Eye of the Storm"]] = {
		low = 35,
		high = 85,
		continent = Outland,
		groupSize = 15,
		type = "Battleground",
		texture = "NetherstormArena",
	}

	-- arenas
	zones[BZ["Blade's Edge Arena"]] = {
		low = 70,
		high = 70,
		continent = Outland,
		type = "Arena",
	}

	zones[BZ["Nagrand Arena"]] = {
		low = 70,
		high = 70,
		continent = Outland,
		type = "Arena",
	}

	zones[BZ["Ruins of Lordaeron"]] = {
		low = 70,
		high = 70,
		continent = Kalimdor,
		type = "Arena",
	}

	-- 2.4 zones
	zones[BZ["Isle of Quel'Danas"]] = {
		continent = Eastern_Kingdoms,
		low = 70,
		high = 70,
		paths = {
			[BZ["Magisters' Terrace"]] = true,
			[BZ["Sunwell Plateau"]] = true,
		},
		instances = {
			[BZ["Magisters' Terrace"]] = true,
			[BZ["Sunwell Plateau"]] = true,
		},
		fishing_min = 450,
	}

	zones[BZ["Magisters' Terrace"]] = {
		low = 68,
		high = 75,
		continent = Eastern_Kingdoms,
		paths = BZ["Isle of Quel'Danas"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Isle of Quel'Danas"], 61.3, 30.9 },
	}

	zones[BZ["Sunwell Plateau"]] = {
		low = 70,
		high = 72,
		continent = Eastern_Kingdoms,
		paths = BZ["Isle of Quel'Danas"],
		groupSize = 25,
		type = "Instance",
		entrancePortal = { BZ["Isle of Quel'Danas"], 44.3, 45.7 },
	}

	-- WOTLK Zones

	zones[BZ["Dalaran"]] = {
		continent = Northrend,
		paths = {
			[BZ["The Violet Hold"]] = true,
			[DALARAN_CRYSTALSONG_TELEPORT] = true,
			[DALARAN_COT_PORTAL] = true,
			[DALARAN_STORMWIND_PORTAL] = true,
			[DALARAN_ORGRIMMAR_PORTAL] = true,
		},
		instances = {
			[BZ["The Violet Hold"]] = true,
			[BZ["Dalaran Arena"]] = true,
		},
		type = "City",
		texture = "Dalaran",
		faction = "Sanctuary",
		fishing_min = 525,
	}



	zones[BZ["Plaguelands: The Scarlet Enclave"]] = {
		low = 55,
		high = 58,
		continent = Eastern_Kingdoms,
		yards = 3162.5,
		x_offset = 0,
		y_offset = 0,
		texture = "ScarletEnclave",
	}

	zones[BZ["Borean Tundra"]] = {
		low = 68,
		high = 72,
		continent = Northrend,
		paths = {
			[BZ["Coldarra"]] = true,
			[BZ["Dragonblight"]] = true,
			[BZ["Sholazar Basin"]] = true,
			[STORMWIND_BOREANTUNDRA_BOAT] = true,
			[ORGRIMMAR_BOREANTUNDRA_ZEPPELIN] = true,
			[MOAKI_UNUPE_BOAT] = true,
		},
		instances = {
			[BZ["The Nexus"]] = true,
			[BZ["The Oculus"]] = true,
			[BZ["The Eye of Eternity"]] = true,
		},
		complexes = {
			[BZ["Coldarra"]] = true,
		},
		fishing_min = 475,
	}

	zones[BZ["Coldarra"]] = {
		low = 69,
		high = 82,
		continent = Northrend,
		paths = {
			[BZ["Borean Tundra"]] = true,
			[BZ["The Nexus"]] = true,
			[BZ["The Oculus"]] = true,
			[BZ["The Eye of Eternity"]] = true,
		},
		instances = {
			[BZ["The Nexus"]] = true,
			[BZ["The Oculus"]] = true,
			[BZ["The Eye of Eternity"]] = true,
		},
		type = "Complex",
	}

	zones[BZ["Howling Fjord"]] = {
		low = 68,
		high = 72,
		continent = Northrend,
		paths = {
			[BZ["Grizzly Hills"]] = true,
			[MENETHIL_HOWLINGFJORD_BOAT] = true,
			[UNDERCITY_HOWLINGFJORD_ZEPPELIN] = true,
			[MOAKI_KAMAGUA_BOAT] = true,
			[BZ["Utgarde Keep"]] = true,
			[BZ["Utgarde Pinnacle"]] = true,
		},
		instances = {
			[BZ["Utgarde Keep"]] = true,
			[BZ["Utgarde Pinnacle"]] = true,
		},
		fishing_min = 475,
	}

	zones[BZ["Dragonblight"]] = {
		low = 71,
		high = 75,
		continent = Northrend,
		paths = {
			[BZ["Borean Tundra"]] = true,
			[BZ["Grizzly Hills"]] = true,
			[BZ["Zul'Drak"]] = true,
			[BZ["Crystalsong Forest"]] = true,
			[MOAKI_UNUPE_BOAT] = true,
			[MOAKI_KAMAGUA_BOAT] = true,
			[BZ["Azjol-Nerub"]] = true,
			[BZ["Ahn'kahet: The Old Kingdom"]] = true,
			[BZ["Naxxramas"]] = true,
			[BZ["The Obsidian Sanctum"]] = true,
		},
		instances = {
			[BZ["Azjol-Nerub"]] = true,
			[BZ["Ahn'kahet: The Old Kingdom"]] = true,
			[BZ["Naxxramas"]] = true,
			[BZ["The Obsidian Sanctum"]] = true,
			[BZ["Strand of the Ancients"]] = true,
		},
		fishing_min = 475,
	}

	zones[BZ["Grizzly Hills"]] = {
		low = 73,
		high = 75,
		continent = Northrend,
		paths = {
			[BZ["Howling Fjord"]] = true,
			[BZ["Dragonblight"]] = true,
			[BZ["Zul'Drak"]] = true,
			[BZ["Drak'Tharon Keep"]] = true,
		},
		instances = BZ["Drak'Tharon Keep"],
		fishing_min = 475,
	}

	zones[BZ["Zul'Drak"]] = {
		low = 74,
		high = 76,
		continent = Northrend,
		paths = {
			[BZ["Dragonblight"]] = true,
			[BZ["Grizzly Hills"]] = true,
			[BZ["Crystalsong Forest"]] = true,
			[BZ["Gundrak"]] = true,
			[BZ["Drak'Tharon Keep"]] = true,
		},
		instances = {
			[BZ["Gundrak"]] = true,
			[BZ["Drak'Tharon Keep"]] = true,
		},
		fishing_min = 475,
	}

	zones[BZ["Sholazar Basin"]] = {
		low = 76,
		high = 78,
		continent = Northrend,
		paths = BZ["Borean Tundra"],
		fishing_min = 525,
	}

	zones[BZ["Crystalsong Forest"]] = {
		low = 77,
		high = 80,
		continent = Northrend,
		paths = {
			[DALARAN_CRYSTALSONG_TELEPORT] = true,
			[BZ["Dragonblight"]] = true,
			[BZ["Zul'Drak"]] = true,
			[BZ["The Storm Peaks"]] = true,
		},
		fishing_min = 500,
	}

	zones[BZ["The Storm Peaks"]] = {
		low = 77,
		high = 80,
		continent = Northrend,
		paths = {
			[BZ["Crystalsong Forest"]] = true,
			[BZ["Halls of Stone"]] = true,
			[BZ["Halls of Lightning"]] = true,
			[BZ["Ulduar"]] = true,
		},
		instances = {
			[BZ["Halls of Stone"]] = true,
			[BZ["Halls of Lightning"]] = true,
			[BZ["Ulduar"]] = true,
		},
		fishing_min = 550,
	}

	zones[BZ["Icecrown"]] = {
		low = 77,
		high = 80,
		continent = Northrend,
		paths = {
			[BZ["Trial of the Champion"]] = true,
			[BZ["Trial of the Crusader"]] = true,
			[BZ["The Forge of Souls"]] = true,
			[BZ["Pit of Saron"]] = true,
			[BZ["Halls of Reflection"]] = true,
			[BZ["Icecrown Citadel"]] = true,
			[BZ["Hrothgar's Landing"]] = true,
		},
		instances = {
			[BZ["Trial of the Champion"]] = true,
			[BZ["Trial of the Crusader"]] = true,
			[BZ["The Forge of Souls"]] = true,
			[BZ["Pit of Saron"]] = true,
			[BZ["Halls of Reflection"]] = true,
			[BZ["Icecrown Citadel"]] = true,
			[BZ["Isle of Conquest"]] = true,
		},
		fishing_min = 550,
	}

	zones[BZ["Hrothgar's Landing"]] = { 
		low = 77,
		high = 80,
		paths = BZ["Icecrown"],
		continent = Northrend,
		fishing_min = 550
	}

	zones[BZ["Wintergrasp"]] = {
		low = 77,
		high = 80,
		continent = Northrend,
		paths = BZ["Vault of Archavon"],
		instances = BZ["Vault of Archavon"],
		type = "PvP Zone",
		fishing_min = 525,
	}

	-- WOTLK Dungeons
	zones[BZ["Utgarde Keep"]] = {
		low = 68,
		high = 78,
		continent = Northrend,
		paths = BZ["Howling Fjord"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Howling Fjord"], 57.30, 46.84 },
	}

	zones[BZ["Utgarde Pinnacle"]] = {
		low = 77,
		high = 82,
		continent = Northrend,
		paths = BZ["Howling Fjord"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Howling Fjord"], 57.25, 46.60 },
	}

	zones[BZ["The Nexus"]] = {
		low = 69,
		high = 79,
		continent = Northrend,
		paths = BZ["Coldarra"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Coldarra"],
		entrancePortal = { BZ["Borean Tundra"], 27.50, 26.03 },
	}

	zones[BZ["The Oculus"]] = {
		low = 77,
		high = 82,
		continent = Northrend,
		paths = BZ["Coldarra"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Coldarra"],
		entrancePortal = { BZ["Borean Tundra"], 27.52, 26.67 },
	}

	zones[BZ["The Eye of Eternity"]] = {
		low = 80,
		high = 80,
		continent = Northrend,
		paths = BZ["Coldarra"],
		groupSize = 10,
		altGroupSize = 25,
		type = "Instance",
		complex = BZ["Coldarra"],
		entrancePortal = { BZ["Borean Tundra"], 27.54, 26.68 },
	}

	zones[BZ["Azjol-Nerub"]] = {
		low = 70,
		high = 80,
		continent = Northrend,
		paths = BZ["Dragonblight"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Dragonblight"], 26.01, 50.83 },
	}

	zones[BZ["Ahn'kahet: The Old Kingdom"]] = {
		low = 71,
		high = 81,
		continent = Northrend,
		paths = BZ["Dragonblight"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Dragonblight"], 28.49, 51.73 },
	}

	zones[BZ["Naxxramas"]] = {
		low = 80,
		high = 80,
		continent = Northrend,
		paths = BZ["Dragonblight"],
		groupSize = 10,
		altGroupSize = 25,
		type = "Instance",
		fishing_min = 1,  -- acid
		entrancePortal = { BZ["Dragonblight"], 87.30, 51.00 },
	}

	zones[BZ["The Obsidian Sanctum"]] = {
		low = 80,
		high = 80,
		continent = Northrend,
		paths = BZ["Dragonblight"],
		groupSize = 10,
		altGroupSize = 25,
		type = "Instance",
		fishing_min = 1,  -- lava
		entrancePortal = { BZ["Dragonblight"], 60.00, 57.00 },
	}

	zones[BZ["Drak'Tharon Keep"]] = {
		low = 72,
		high = 82,
		continent = Northrend,
		paths = {
			[BZ["Grizzly Hills"]] = true,
			[BZ["Zul'Drak"]] = true,
		},
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Zul'Drak"], 28.53, 86.93 },
	}

	zones[BZ["Gundrak"]] = {
		low = 74,
		high = 82,
		continent = Northrend,
		paths = BZ["Zul'Drak"],
		groupSize = 5,
		type = "Instance",
		fishing_min = 475,
		entrancePortal = { BZ["Zul'Drak"], 76.14, 21.00 },
	}

	zones[BZ["Halls of Stone"]] = {
		low = 75,
		high = 82,
		continent = Northrend,
		paths = BZ["The Storm Peaks"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["The Storm Peaks"], 39.52, 26.91 },
	}

	zones[BZ["Halls of Lightning"]] = {
		low = 77,
		high = 82,
		continent = Northrend,
		paths = BZ["The Storm Peaks"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["The Storm Peaks"], 45.38, 21.37 },
	}

	zones[BZ["Ulduar"]] = {
		low = 80,
		high = 80,
		continent = Northrend,
		paths = BZ["The Storm Peaks"],
		groupSize = 10,
		altGroupSize = 25,
		type = "Instance",
		entrancePortal = { BZ["The Storm Peaks"], 41.56, 17.76 },
		fishing_min = 550,
	}

	zones[BZ["The Violet Hold"]] = {
		low = 73,
		high = 82,
		continent = Northrend,
		paths = BZ["Dalaran"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Dalaran"], 66.78, 68.19 },
	}

	zones[BZ["Trial of the Champion"]] = {
		low = 80,
		high = 82,
		continent = Northrend,
		paths = BZ["Icecrown"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Icecrown"], 74.18, 20.45 },
	}

	zones[BZ["Trial of the Crusader"]] = {
		low = 80,
		high = 80,
		continent = Northrend,
		paths = BZ["Icecrown"],
		groupSize = 10,
		altGroupSize = 25,
		type = "Instance",
		entrancePortal = { BZ["Icecrown"], 75.07, 21.80 },
	}

	zones[BZ["The Forge of Souls"]] = {
		low = 80,
		high = 82,
		continent = Northrend,
		paths = BZ["Icecrown"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Icecrown"], 52.60, 89.35 },
	}

	zones[BZ["Pit of Saron"]] = {
		low = 80,
		high = 82,
		continent = Northrend,
		paths = BZ["Icecrown"],
		groupSize = 5,
		type = "Instance",
		fishing_min = 550,
		entrancePortal = { BZ["Icecrown"], 52.60, 89.35 },
	}

	zones[BZ["Halls of Reflection"]] = {
		low = 80,
		high = 82,
		continent = Northrend,
		paths = BZ["Icecrown"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Icecrown"], 52.60, 89.35 },
	}

	zones[BZ["Icecrown Citadel"]] = {
		low = 80,
		high = 80,
		continent = Northrend,
		paths = BZ["Icecrown"],
		groupSize = 10,
		altGroupSize = 25,
		type = "Instance",
		entrancePortal = { BZ["Icecrown"], 53.86, 87.27 },
	}

	zones[BZ["Vault of Archavon"]] = {
		low = 80,
		high = 80,
		continent = Northrend,
		paths = BZ["Wintergrasp"],
		groupSize = 10,
		altGroupSize = 25,
		type = "Instance",
		entrancePortal = { BZ["Wintergrasp"], 50, 11.2 }, 
	}

	zones[BZ["The Ruby Sanctum"]] = {
		low = 80,
		high = 80,
		continent = Northrend,
		paths = BZ["Dragonblight"],
		groupSize = 10,
		altGroupSize = 25,
		type = "Instance",
		fishing_min = 650,
		entrancePortal = { BZ["Dragonblight"], 61.00, 53.00 },
	}


	zones[BZ["The Frozen Sea"]] = {
		continent = Northrend,
		fishing_min = 575,
	}

	zones[BZ["Strand of the Ancients"]] = {
		low = 65,
		high = 85,
		continent = Northrend,
		groupSize = 15,
		type = "Battleground",
		texture = "StrandoftheAncients",
	}
	
	zones[BZ["Isle of Conquest"]] = {
		low = 75,
		high = 85,
		continent = Northrend,
		groupSize = 40,
		type = "Battleground",
		texture = "IsleofConquest",
	}

	zones[BZ["Dalaran Arena"]] = {
		low = 80,
		high = 80,
		continent = Northrend,
		type = "Arena",
	}

	zones[BZ["The Ring of Valor"]] = {
		low = 80,
		high = 80,
		continent = Kalimdor,
		type = "Arena",
	}

	-- Cataclysm zones
	
	zones[BZ["Mount Hyjal"]] = {
		low = 80,
		high = 82,
		continent = Kalimdor,
		paths = {
			[BZ["Winterspring"]] = true,
		},
		instances = {
			[BZ["Firelands"]] = true,
		},
		fishing_min = 575,
	}
	
	zones[BZ["Uldum"]] = {
		low = 83,
		high = 84,
		continent = Kalimdor,
		paths = {
			[BZ["Tanaris"]] = true,
		},
		instances = {
			[BZ["Halls of Origination"]] = true,
			[BZ["Lost City of the Tol'vir"]] = true,
			[BZ["The Vortex Pinnacle"]] = true,
			[BZ["Throne of the Four Winds"]] = true,
		},
		fishing_min = 650,
	}
	
	zones[BZ["Ahn'Qiraj: The Fallen Kingdom"]] = {
		low = 60,
		high = 63,
		continent = Kalimdor,
		paths = {
			[BZ["Silithus"]] = true,
		},
		instances = {
			[BZ["Temple of Ahn'Qiraj"]] = true,
			[BZ["Ruins of Ahn'Qiraj"]] = true,
		},
		type = "Complex",
	}
	
	zones[BZ["Gilneas"]] = {
		low = 1,
		high = 12,
		continent = Eastern_Kingdoms,
		paths = {},  -- phased instance
		faction = "Alliance",
		fishing_min = 25,
	}

	zones[BZ["Gilneas City"]] = {
		low = 1,
		high = 12,
		continent = Eastern_Kingdoms,
		paths = {},  -- phased instance
		faction = "Alliance",
	}

	zones[BZ["Ruins of Gilneas"]] = {
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Silverpine Forest"]] = true,
			[BZ["Ruins of Gilneas City"]] = true,
		},
		fishing_min = 75,
	}

	zones[BZ["Ruins of Gilneas City"]] = {
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Silverpine Forest"]] = true,
			[BZ["Ruins of Gilneas"]] = true,
		},
		fishing_min = 75,
	}

	zones[BZ["Twilight Highlands"]] = {
		low = 84,
		high = 85,
		continent = Eastern_Kingdoms,
		instances = {
			[BZ["Grim Batol"]] = true,
			[BZ["The Bastion of Twilight"]] = true,
			[BZ["Twin Peaks"]] = true,
		},
		paths = {
			[BZ["Wetlands"]] = true,
			[BZ["Grim Batol"]] = true,
			[BZ["Twin Peaks"]] = true,
		},
		fishing_min = 650,
	}

	zones[BZ["Tol Barad"]] = {
		low = 84,
		high = 85,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Tol Barad Peninsula"]] = true,
		},
		type = "PvP Zone",
		fishing_min = 675,
	}

	zones[BZ["Tol Barad Peninsula"]] = {
		low = 84,
		high = 85,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Tol Barad"]] = true,
			[TOLBARAD_ORGRIMMAR_PORTAL] = true,
			[TOLBARAD_STORMWIND_PORTAL] = true,
		},
		fishing_min = 675,
	}


	zones[BZ["Vashj'ir"]] = {
		low = 80,
		high = 82,
		continent = Eastern_Kingdoms,
		instances = {
			[BZ["Throne of the Tides"]] = true,
		},
		fishing_min = 575,
	}

	zones[BZ["Kelp'thar Forest"]] = {
		low = 80,
		high = 81,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Shimmering Expanse"]] = true,
		},
		fishing_min = 575,
	}

	zones[BZ["Shimmering Expanse"]] = {
		low = 80,
		high = 82,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Kelp'thar Forest"]] = true,
			[BZ["Abyssal Depths"]] = true,
		},
		fishing_min = 575,
	}

	zones[BZ["Abyssal Depths"]] = {
		low = 81,
		high = 82,
		continent = Eastern_Kingdoms,
		instances = {
			[BZ["Throne of the Tides"]] = true,
		},
		paths = {
			[BZ["Shimmering Expanse"]] = true,
			[BZ["Throne of the Tides"]] = true,
		},
		fishing_min = 575,
	}

--	! Conflict with continent
--	zones[BZ["The Maelstrom"]] = {
--		low = ?,
--		high = ?,
--		continent = The_Maelstrom,
--		paths = {
--		},
--		faction = "Sanctuary",
--		fishing_min = 0,
--	}

	zones[BZ["Deepholm"]] = {
		low = 82,
		high = 83,
		continent = The_Maelstrom,
		instances = {
			[BZ["The Stonecore"]] = true,
		},
		paths = {
			[BZ["The Stonecore"]] = true,
			[DEEPHOLM_ORGRIMMAR_PORTAL] = true,
			[DEEPHOLM_STORMWIND_PORTAL] = true,
		},
		fishing_min = 550,
	}

	zones[BZ["Kezan"]] = {
		low = 1,
		high = 5,
		continent = The_Maelstrom,
		faction = "Horde",
		fishing_min = 25,
	}

	zones[BZ["The Lost Isles"]] = {
		low = 6,
		high = 12,
		continent = The_Maelstrom,
		faction = "Horde",
		fishing_min = 25,
	}






--	Cataclysm instances


	zones[BZ["Firelands"]] = {
		low = 85,
		high = 85,
		continent = Kalimdor,
		paths = BZ["Mount Hyjal"],
		groupSize = 10,
		altGroupSize = 25,
		type = "Instance",
		entrancePortal = { BZ["Mount Hyjal"], 47.3, 78.3 }, 
	}

	zones[BZ["Lost City of the Tol'vir"]] = {
		low = 85,
		high = 85,
		continent = Kalimdor,
		paths = BZ["Uldum"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Uldum"], 60.53, 64.24 },
	}

	zones[BZ["Halls of Origination"]] = {
		low = 85,
		high = 85,
		continent = Kalimdor,
		paths = BZ["Uldum"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Uldum"], 69.09, 52.95 },
	}

	zones[BZ["The Vortex Pinnacle"]] = {
		low = 82,
		high = 84,
		continent = Kalimdor,
		paths = BZ["Uldum"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Uldum"], 76.79, 84.51 },
	}

	zones[BZ["Throne of the Four Winds"]] = {
		low = 85,
		high = 85,
		continent = Kalimdor,
		paths = BZ["Uldum"],
		groupSize = 10,
		altGroupSize = 25,
		type = "Instance",
		entrancePortal = { BZ["Uldum"], 38.26, 80.66 },
	}


	zones[BZ["Blackrock Caverns"]] = {
		low = 80,
		high = 81,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Blackrock Mountain"]] = true,
		},
		groupSize = 5,
		type = "Instance",
		complex = BZ["Blackrock Mountain"],
		entrancePortal = { BZ["Searing Gorge"], 47.8, 69.1 },
	}

	zones[BZ["Blackwing Descent"]] = {
		low = 85,
		high = 85,
		continent = Eastern_Kingdoms,
		paths = {
			[BZ["Burning Steppes"]] = true,
			[BZ["Blackrock Mountain"]] = true,
			[BZ["Blackrock Spire"]] = true,
			[BZ["Blackrock Spire"]] = true,
		},
		groupSize = 10,
		altGroupSize = 25,
		type = "Instance",
		complex = BZ["Blackrock Mountain"],
--		entrancePortal = { BZ["Burning Steppes"], 29.7, 37.5 },  -- TODO: coordinates
	}

	zones[BZ["Grim Batol"]] = {
		low = 85,
		high = 85,
		continent = Eastern_Kingdoms,
		paths = BZ["Twilight Highlands"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Twilight Highlands"], 19, 53.5 },
	}

	zones[BZ["The Bastion of Twilight"]] = {
		low = 85,
		high = 85,
		continent = Eastern_Kingdoms,
		paths = BZ["Twilight Highlands"],
		groupSize = 10,
		altGroupSize = 25,
		type = "Instance",
		entrancePortal = { BZ["Twilight Highlands"], 33.8, 78.2 },
	}

	zones[BZ["Throne of the Tides"]] = {
		low = 80,
		high = 81,
		continent = Eastern_Kingdoms,
		paths = BZ["Abyssal Depths"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Abyssal Depths"], 69.3, 25.2 },
	}


	zones[BZ["The Stonecore"]] = {
		low = 82,
		high = 84,
		continent = The_Maelstrom,
		paths = BZ["Deepholm"],
		groupSize = 5,
		type = "Instance",
		entrancePortal = { BZ["Deepholm"], 47.70, 51.96 },
	}


--	4.3 Dungeons

	zones[BZ["End Time"]] = {
		low = 85,
		high = 85,
		continent = Kalimdor,
		paths = BZ["Caverns of Time"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Caverns of Time"],
		entrancePortal = { BZ["Tanaris"], 66.2, 49.3 },  -- TODO: check
	}

	zones[BZ["Hour of Twilight"]] = {
		low = 85,
		high = 85,
		continent = Kalimdor,
		paths = BZ["Caverns of Time"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Caverns of Time"],
		entrancePortal = { BZ["Tanaris"], 66.2, 49.3 },  -- TODO: check
	}

	zones[BZ["Well of Eternity"]] = {
		low = 85,
		high = 85,
		continent = Kalimdor,
		paths = BZ["Caverns of Time"],
		groupSize = 5,
		type = "Instance",
		complex = BZ["Caverns of Time"],
		entrancePortal = { BZ["Tanaris"], 66.2, 49.3 },  -- TODO: check
	}

	zones[BZ["Dragon Soul"]] = {
		low = 85,
		high = 85,
		continent = Kalimdor,
		paths = BZ["Caverns of Time"],
		groupSize = 10,
		altGroupSize = 25,
		type = "Instance",
		complex = BZ["Caverns of Time"],
		entrancePortal = { BZ["Tanaris"], 66.2, 49.3 },  -- TODO: check
	}


--	Cataclysm Battlegrounds

	zones[BZ["The Battle for Gilneas"]] = {
		low = 85,
		high = 85,
		continent = Eastern_Kingdoms,
		groupSize = 10,
		type = "Battleground",
		texture = "TheBattleforGilneas",
	}

	zones[BZ["Twin Peaks"]] = {
		low = 85,
		high = 85,
		continent = Eastern_Kingdoms,
		paths = BZ["Twilight Highlands"],
		groupSize = 10,
		type = "Battleground",
		texture = "TwinPeaks",  -- TODO: verify
	}








	local continentNames = { GetMapContinents() }
	local doneZones = {}
	local zoneIDs = {}
	
	-- Lookup for zones that are on a sub-continent map and therefore have no own highlight on the continent map
	-- Value is the name of the sub-continent map that will be searched instead of the continent map
	local searchMaps = {}
	searchMaps[BZ["Northern Stranglethorn"]] = BZ["Stranglethorn Vale"]
	searchMaps[BZ["The Cape of Stranglethorn"]] = BZ["Stranglethorn Vale"]
	searchMaps[BZ["Abyssal Depths"]] = BZ["Vashj'ir"]
	searchMaps[BZ["Kelp'thar Forest"]] = BZ["Vashj'ir"]
	searchMaps[BZ["Shimmering Expanse"]] = BZ["Vashj'ir"]
	
	-- The submaps have different sizes than the continent maps -> use (measured) value
	-- in order to get a porpoer yards value for the zone maps.
	local submapContinentYards = {}
	submapContinentYards[BZ["Stranglethorn Vale"]] = 6600
	submapContinentYards[BZ["Vashj'ir"]] = 6975
	
	-- Hack:
	-- For the zones below, UpdateMapHighlight() does not return name and map data for the city icon on the continent map
	-- Use hardcoded values as default; will be overwritten once the UpdateMapHighlight bug has been fixed - if ever
	-- Note: the city highlights/icons on the zone maps can't be used because these return the name but no map data
	-- TODO: determine values!
	
	local kalimdorYards = zones[BZ["Kalimdor"]].yards
	local eastkingYards = zones[BZ["Eastern Kingdoms"]].yards
	local northrendYards = zones[BZ["Northrend"]].yards
	local maelstromYards = zones[BZ["The Maelstrom"]].yards
	
	zones[BZ["Orgrimmar"]].yards = 1739.375
	zones[BZ["Orgrimmar"]].x_offset = 0 * kalimdorYards
	zones[BZ["Orgrimmar"]].y_offset = 0 * kalimdorYards * 2/3
	zones[BZ["Orgrimmar"]].texture = "Orgrimmar"

	zones[BZ["Darnassus"]].yards = 1539.58337402344
	zones[BZ["Darnassus"]].x_offset = 0 * kalimdorYards
	zones[BZ["Darnassus"]].y_offset = 0 * kalimdorYards * 2/3
	zones[BZ["Darnassus"]].texture = "Darnassus"

	zones[BZ["Stormwind City"]].yards = 1737.499958992
	zones[BZ["Stormwind City"]].x_offset = 0 * eastkingYards
	zones[BZ["Stormwind City"]].y_offset = 0 * eastkingYards * 2/3
	zones[BZ["Stormwind City"]].texture = "StormwindCity"

	zones[BZ["Dalaran"]].yards = 830.015014648438
	zones[BZ["Dalaran"]].x_offset = 0 * northrendYards
	zones[BZ["Dalaran"]].y_offset = 0 * northrendYards * 2/3
	zones[BZ["Dalaran"]].texture = "Dalaran"

	zones[BZ["Ruins of Gilneas City"]].yards = 889.583251953125
	zones[BZ["Ruins of Gilneas City"]].x_offset = 0 * eastkingYards
	zones[BZ["Ruins of Gilneas City"]].y_offset = 0 * eastkingYards * 2/3
	zones[BZ["Ruins of Gilneas City"]].texture = "RuinsofGilneasCity"

	zones[BZ["Kezan"]].yards = 1352.08319091797
	zones[BZ["Kezan"]].x_offset = 0 * maelstromYards
	zones[BZ["Kezan"]].y_offset = 0 * maelstromYards * 2/3
	zones[BZ["Kezan"]].texture = "Kezan"

	zones[BZ["The Lost Isles"]].yards = 4514.5830078125
	zones[BZ["The Lost Isles"]].x_offset = 0 * maelstromYards
	zones[BZ["The Lost Isles"]].y_offset = 0 * maelstromYards * 2/3
	zones[BZ["The Lost Isles"]].texture = "TheLostIsles"

	zones[BZ["Deepholm"]].yards = 5099.99987792969
	zones[BZ["Deepholm"]].x_offset = 0 * maelstromYards
	zones[BZ["Deepholm"]].y_offset = 0 * maelstromYards * 2/3
	zones[BZ["Deepholm"]].texture = "Deepholm"
	
	zones[BZ["Gilneas"]].yards = 3145.83325195312
	zones[BZ["Gilneas"]].x_offset = 0 * eastkingYards
	zones[BZ["Gilneas"]].y_offset = 0 * eastkingYards * 2/3
	zones[BZ["Gilneas"]].texture = "Gilneas"
	
	-- end hack


	
	trace("Tourist: Initializing zones...")
	
	for continentID, continentName in ipairs(continentNames) do
		SetMapZoom(continentID)
		if zones[continentName] then
			zones[continentName].texture = GetMapInfo()
		end
		local zoneNames = { GetMapZones(continentID) }
		local continentYards = zones[continentName].yards
		
		-- First, build a collection of zone IDs to be able to lookup a zone ID for SetMapZoom() in case we need to 'dig deeper'
		for _ = 1, #zoneNames do
			zoneIDs[zoneNames[_]] = _
		end
		
		
		for _ = 1, #zoneNames do
			local x, y
			local name, fileName, texPctX, texPctY, texX, texY, scrollX, scrollY
			
			-- Some zones are not directly accessible from the continent map and have to be searched for on a zone map
			local searchMap, zoneID
			searchMap = searchMaps[zoneNames[_]]
			if searchMap then
				-- Get the zone ID from the lookup
				zoneID = zoneIDs[searchMap]
				if zoneID then
					-- Set map to zone map
					SetMapZoom(continentID, zoneID)
					-- Get searchMap 'continent' size
					continentYards = submapContinentYards[searchMap]
					--trace( "continentYards for "..tostring(searchMap).." = "..tostring(continentYards) )
				end
			end
			
			local scansDone = 0	
			repeat
				scansDone = scansDone + 1
				if scansDone >= 10000 then
					-- Timeout
					name = nil
					break
				end
				x, y = math.random(), math.random()
				name, fileName, texPctX, texPctY, texX, texY, scrollX, scrollY = UpdateMapHighlight(x, y)
			until name and not doneZones[name] and name == zoneNames[_]  -- do not stop searching until we have a match on zonename

			if name then
				if fileName then
					-- UpdateMapHighlight() returned the zone name and data for the texture
					doneZones[name] = true

					-- TODO: expand for new zones?
					if fileName == "EversongWoods" or fileName == "Ghostlands" or fileName == "Sunwell" or fileName == "SilvermoonCity" then
						scrollX = scrollX - 0.00168
						scrollY = scrollY + 0.01
					end

					if zones[name] then
						zones[name].yards = texX * continentYards
						zones[name].x_offset = scrollX * continentYards
						zones[name].y_offset = scrollY * continentYards * 2/3
						zones[name].texture = fileName
					else
						trace("! Tourist: TODO: "..tostring(name))
					end
				else
					-- UpdateMapHighlight() returned the zone name but did NOT return data for the texture
					trace("! Tourist: No texture data from UpdateMapHighlight for "..tostring(name))
				end
			else
				-- UpdateMapHighlight did not return anything
				-- See hack, above					
				trace("! Tourist: Highlight not found for "..tostring(continentName).."["..tostring(_).."] = "..tostring(zoneNames[_]))
			end 
			
			if zoneID then
				-- Revert map to current continent map for next zoneName lookup
				SetMapZoom(continentID)
				continentYards = zones[continentName].yards
			end
		end
	end
	
	SetMapToCurrentZone()

	for k,v in pairs(zones) do	
		lows[k] = v.low or 0
		highs[k] = v.high or 0
		continents[k] = v.continent or UNKNOWN
		instances[k] = v.instances
		paths[k] = v.paths or false
		types[k] = v.type or "Zone"
		groupSizes[k] = v.groupSize
		groupAltSizes[k] = v.altGroupSize
		factions[k] = v.faction
		yardWidths[k] = v.yards
		yardHeights[k] = v.yards and v.yards * 2/3 or nil
		yardXOffsets[k] = v.x_offset
		yardYOffsets[k] = v.y_offset
		fishing[k] = v.fishing_min
		textures[k] = v.texture
		complexOfInstance[k] = v.complex
		zoneComplexes[k] = v.complexes
		if v.texture then
			textures_rev[v.texture] = k
		end
		if v.entrancePortal then
			entrancePortals_zone[k] = v.entrancePortal[1]
			entrancePortals_x[k] = v.entrancePortal[2]
			entrancePortals_y[k] = v.entrancePortal[3]
		end
	end
	zones = nil

	trace("Tourist: Zones initialized.")

	PLAYER_LEVEL_UP(Tourist)
end
