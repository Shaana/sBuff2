--[[
Copyright (c) 2008-2013 Shaana <shaana@student.ethz.ch>
This file is part of sBuff2.

sBuff2 is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

sBuff2 is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with sBuff2.  If not, see <http://www.gnu.org/licenses/>.
--]]

local addon, namespace = ...

local core = {}
namespace.core = core

local class = {}
namespace.class = class

local header = {}
class.header = header

local button = {}
class.button = button

--Note:	'button' is always refering to an object created by the class.button:new(...) method, 
--		while 'button_frame' is refering to object returned by header:GetAttributed("child"..i)


--TODO	add multi unit support (currently only player is supported)
--TODO	add predefined configs in config.lua for 32px, 48px
--TODO	make sure tooltips are in sync with time_remaining and whatever blizzard displays (we floor in format_time(), blizzard ceils time_remaining)
--TODO	Test pixel perfection properly (fix if needed)
--		change pp to properly scale fonts (--> don't use pp atm)
--TODO	write proper github wiki (with nice pics)
--TODO	checkout this option from the Template
--		groupBy = [nil, auraFilter] -- if present, a series of comma-separated filters, appended to the base filter to separate auras into groups within a single stream
--[[
consolidateTo = [nil, NUMBER] -- The aura sub-stream before which to place a proxy for the consolidated header. If nil or 0, consolidation is ignored.
consolidateDuration = [nil, NUMBER] -- the minimum total duration an aura should have to be considered for consolidation (Default: 30)
consolidateThreshold = [nil, NUMBER] -- buffs with less remaining duration than this many seconds should not be consolidated (Default: 10)
consolidateFraction = [nil, NUMBER] -- The fraction of remaining duration a buff should still have to be eligible for consolidation (Default: .10)

consolidateProxy = [STRING|Frame] -- Either the button which represents consolidated buffs, or the name of the template used to construct one.
consolidateHeader = [STRING|Frame] -- Either the aura header which contains consolidated buffs, or the name of the template used to construct one.
-->for the proxy we just make a normal button that looks a bit fancy ?
-->and for the header we can just use the same template as for buffs
--]]

--upvalue lua api
local assert, error, type, select, pairs, ipairs, print, unpack = assert, error, type, select, pairs, ipairs, print, unpack

--upvalue wow api
local IsAddOnLoaded, CreateFrame, UnitAura, UnitName, UnitClass = IsAddOnLoaded, CreateFrame, UnitAura, UnitName, UnitClass
local GetTime, GetWeaponEnchantInfo, GetInventoryItemTexture = GetTime, GetWeaponEnchantInfo, GetInventoryItemTexture
local UIParent, GameTooltip, RAID_CLASS_COLORS  = UIParent, GameTooltip, RAID_CLASS_COLORS

--load pixel perfection (pp)
local pp, pp_loaded = nil, false

if IsAddOnLoaded("sCore") and sCore.pp._object then
	pp = sCore.pp
	pp_loaded = true
end


local function si_value(value)
	if value >= 1e6 then
		return ("%.0f m"):format(value*1e-6)
	elseif value >= 1e3 then
		return ("%.0f k"):format(value*1e-3)
	else
		return value
	end
end

local function format_time(time, show_msec, show_sec, show_min, show_hour)
	if time < (show_msec or 2) then
		return ("%.1f s"):format(time)
	elseif time < (show_sec or 60) then
		return ("%.0f s"):format(time)
	elseif time < (show_min or 3600) then --60*60
		return ("%.0f m"):format(time/60)
	elseif time < (show_hour or 86400) then --60*60*24
		return ("%.0f h"):format(time/3600)
	else
		return ("%.0f d"):format(time/86400)
	end
end

local function _inherit(object, class)	
	assert(type(class) == "table")
	for k,v in pairs(class) do
		object[k] = v
	end
end

--only needed in _set_attribute(header, attribute)
local pp_attributes = {"xOffset", "yOffset", "wrapXOffset", "wrapYOffset"}

local function _set_attribute(header, attribute)
	assert(type(attribute) == "table")
	
	--inheritance
	if type(attribute.__index) == "table" then
		_set_attribute(header, attribute.__index)
	end
	for k,v in pairs(attribute) do
		if k ~= "__index" then
			--TODO check if scalling really works
			--pixel perfection
			if pp_loaded then
				for _,b in ipairs(pp_attributes) do
					if b == k then
						print("scalling", k, v)
						v = pp.scale(v)
						print(v, pp._scale_factor)
						break
					end
				end
			end
			header:SetAttribute(k,v)
		end
	end
end

local function set_attribute(header,attribute)
	--temporary disable SecureAuraHeader_OnAttributeChanged
	local old_ignore = header:GetAttribute("_ignore")
	
	header:SetAttribute("_ignore", "attributeChanges")
	_set_attribute(header, attribute)
	header:SetAttribute("_ignore", old_ignore)
end


--[[-- header class --]]
function header.new(self, name, config, attribute)
	local object = CreateFrame("Frame", name, UIParent, "SecureAuraHeaderTemplate")
	
	--[[
	--inherit functions from two objects (listed in parent table)
	local parent = {self, getmetatable(object).__index}
	setmetatable(object, self)
	self.__index = function(t,k)
		for i=1, #parent do
			local v = parent[i][k]
			if v then
				return v
			end
		end
	end
	--]]
	
	--Note:	Tempering with the metatable causes the the secure template to break
	--		Therefore we inherit the options with a function. (basically creating links to each of the class functions)
	_inherit(object, header)
	
	--add pixel perfection, if sCore is loaded
	if pp_loaded then
		pp.add_all(object)
	end
	
	object.config = config
	object.button = {} --here we put the list of buttons created by the button class
	
	--for temporary variables
	object._temp = {}
	object._temp.button = {} --buttons for the TempEnchant workaround in header.update_temp_enchant() (see below)

	set_attribute(object, attribute) --here happens the inheritance, too
	
	--Note: the maximum number buffs/debuffs a unit can have is 40
	local max_aura_with_wrap = object:GetAttribute("wrapAfter")*object:GetAttribute("maxWraps")
	object.max_aura = max_aura_with_wrap > 40 and 40 or max_aura_with_wrap
	
	--set anchor
	object:SetPoint(unpack(config["anchor"]))
	
	--this will run SecureAuraHeader_Update(header)
	object:Show()

	--Note: UNIT_AURA will be added by Blizzard's code
	object:RegisterEvent("PLAYER_ENTERING_WORLD")

	--vehicle support
	if object.config["display_vehicle_aura"] then
		object:RegisterEvent("UNIT_ENTERED_VEHICLE")
		object:RegisterEvent("UNIT_EXITED_VEHICLE")
	end
	
	--pet battle support (hide frames during a battle)
	object:RegisterEvent("PET_BATTLE_CLOSE")
	object:RegisterEvent("PET_BATTLE_OPENING_START")

	--Note:	The UNIT_INVENTORY_CHANGED event is necessary for buff headers, because when a new TempEnchant is applied/weapon are being switched UNIT_AURA is fired and immediately afterwards UNIT_INVENTORY_CHANGED,
	--		but only after UNIT_INVENTORY_CHANGED was fired the new icon returned by GetInventoryItemTexture() is available
	--		For some reason button.update_temp_enchant(self) is only called once! (some smart blizzard code?)
	if object.config["helpful"] and object:GetAttribute("includeWeapons") == 1 then
		--TODO During the first login UNIT_INVENTORY_CHANGED is fired 30+ times (caching of inventory?) - might wanna do something about that
		object:RegisterEvent("UNIT_INVENTORY_CHANGED")
	end

	object:HookScript("OnEvent", self.update)

	return object
end

function header.update(self, event, unit)
	--Note:	TempEnchant update is only necessary for buff headers, the check happens in header.update_temp_enchant(self)
	if event == "PET_BATTLE_CLOSE" then
		self:Show()
		self:update_aura()
		self:update_temp_enchant()
	elseif event == "PET_BATTLE_OPENING_START" then
		self:Hide()
	elseif event == "PLAYER_ENTERING_WORLD" then
		self:update_aura()
		self:update_temp_enchant()
	elseif event == "UNIT_AURA" then
		if unit == self:GetAttribute("unit") then
			self:update_aura()
			self:update_temp_enchant()
		end
	elseif event == "UNIT_INVENTORY_CHANGED" then
		if unit == self:GetAttribute("unit") then
			self:update_temp_enchant()
		end
	elseif event == "UNIT_ENTERED_VEHICLE" then
		if unit == self:GetAttribute("unit") then
			self._temp.attribute_unit = unit -- same as self:GetAttribute("unit")
			self:SetAttribute("unit", "vehicle")
			self:update_aura()
			--Note:	To my knowledge vehicles can't have TempEnchants
		end	
	elseif event == "UNIT_EXITED_VEHICLE" then
		if unit == self._temp.attribute_unit then
			self:SetAttribute("unit", self._temp.attribute_unit)
			--Note:	UNIT_AURA fires shortly after, therefore a forced update is not required
		end
	else
		print("Error, don't know what to do with this event: ", event)
	end
end

function header.update_aura(self)
	--Note:	we keep the first two slots for TempEnchants, same for debuffs,
	--		even though they don't have TempEnchants
	for i=1, self.max_aura do
		local child = self:GetAttribute("child"..i)
		if child  then
			if child:IsShown() then
				--create button object if needed
				if not self.button[i+2] then 
					self.button[i+2] = class.button:new(self, child)
				end
				--update
				self.button[i+2]:update_aura()
			else
				--We can stop, if we found the first child that is not shown
				break
			end
		end
	end
end

function header.update_temp_enchant(self)
	--only update, if it's a buff header
	if self.config["helpful"] then
		for i=1, 2 do
			local child = self:GetAttribute("tempEnchant"..i)

			--Note:	This is a little workaround, because for some unknown reason GetWeaponEnchantInfo() indicates correctly that there is a TempEnchant applied, 
			--		however header:GetAttribute("tempEnchant"..i) still returns nil. (This problem only seams to occur before the first time a TempEnchant is applied)
			--		We add a OnUpdate script to a frame and wait for the information to become available. (usually the information is available after one update cycle; next frame)
			--		GetWeaponEnchantInfo() returns six values, first 3 for the MainHandSlot and 4-6 for the SecondaryHandSlot
			if not child and select(1 + (i-1)*3, GetWeaponEnchantInfo()) then
				if not self._temp.button[i] then
					self._temp.button[i] = CreateFrame("Frame", nil, UIParent)
				end
				self._temp.button[i].header = self
				self._temp.button[i].index = i
				self._temp.button[i].child = nil
				
				self._temp.button[i]:SetScript("OnUpdate", function(self, elapsed) 
					self.child = self.header:GetAttribute("tempEnchant"..self.index)
					if self.child then
						self:SetScript("OnUpdate", nil)
						self.header:update_temp_enchant()
					end
				end)
			end

			--Note:	child:IsShown() for TempEnchants is slow for some reason and sometimes returns nil even though the frame is already shown
			--		We'll check if there is really a TempEnchant with has_enchant,_,_ = GetWeaponEnchantInfo() in button.udpate_temp_enchant(self)
			if child then
				--create button object if needed
				if not self.button[i] then 
					self.button[i] = class.button:new(self, child)
				end
				--update
				self.button[i]:update_temp_enchant()
			end
		end
	end
end
--[[-- header class end --]]


--[[-- button class --]]
function button.new(self, header, child) --child given by iterating over children from the header
	local object = child

	--Note:	Tempering with the metatable causes the the secure template to break. (Lots of errors while in combat due to protected functions,
	--		unable to remove certain buffs (e.g Shadowform)
	--		Therefore we inherit the options with a function. (basically creating links to each of the class functions)
	_inherit(object, button)
	
	object.header = header

	--create objects
	object.icon = CreateFrame("Frame", nil, child)
	object.icon.texture = object.icon:CreateTexture(nil, "BACKGROUND")
	object.border = CreateFrame("Frame", nil, child)
	object.border.texture = object.border:CreateTexture(nil, "BORDER")
	object.gloss = CreateFrame("Frame", nil, child)
	object.gloss.texture = object.gloss:CreateTexture(nil, "BORDER")
	object.count = object:CreateFontString(nil, "OVERLAY")
	object.expiration = object:CreateFontString(nil, "OVERLAY")
	
	--add pixel perfection, if sCore is loaded
	if pp_loaded then
		pp.add_all(object)
		pp.add_all(object.icon)
		pp.add_all(object.icon.texture)
		pp.add_all(object.border)
		--pp.add_all(object.border.texture)
		pp.add_all(object.gloss)
		--pp.add_all(object.gloss.texture)
		pp.add_all(object.count) 
		pp.add_all(object.expiration)
	end
	
	--Note: This is the actual size. (area you can mouseover for the tooltip and right-click to cancel a buff)
	--		Furthermore if pp is turned on, SetSize will set the resized values.
	object:SetSize(unpack(header.config["size"]))
	
	--icon
	object.icon:SetAllPoints(child)
	object.icon:SetFrameLevel(1)
	
	--TODO, something aint working here as intended ... (the scaling)
	--some more pixel perfection
	local i = pp_loaded and pp.scale(header.config["border_inset"]) or header.config["border_inset"]
	--local i = header.config["border_inset"]
	--print("printing i here :D  ", i)
	--print(header.config["border_inset"], pp.scale(header.config["border_inset"]))
	--Note: if pp is loaded child:GetWidth() will already return the SCALED value, but i will be scalled too, therefor it's all good :D
	--print(child:GetWidth())
	local j = i/child:GetWidth() --asuming it's a square button
	object.icon.texture:SetPoint("TOPLEFT", i, -i)
	object.icon.texture:SetPoint("BOTTOMRIGHT", -i, i)
	object.icon.texture:SetTexCoord(j, 1-j, j, 1-j)
	
	--border
	object.border:SetPoint("CENTER", child, "CENTER")
	object.border:SetSize(unpack(header.config["border_texture_size"]))
	object.border:SetFrameLevel(2)

	object.border.texture:SetAllPoints(object.border)
	object.border.texture:SetTexture(header.config["border_texture"])
	object.border.texture:SetVertexColor(unpack(header.config["border_color"]))

	--gloss
	object.gloss:SetPoint("CENTER", child, "CENTER")
	object.gloss:SetSize(unpack(header.config["gloss_texture_size"]))
	object.gloss:SetFrameLevel(3)
	
	object.gloss.texture:SetAllPoints(object.gloss)
	object.gloss.texture:SetTexture(header.config["gloss_texture"])
	object.gloss.texture:SetVertexColor(unpack(header.config["gloss_color"]))

	--count text
	object.count:SetTextColor(unpack(header.config["count_color"]))
	object.count:SetFont(unpack(header.config["count_font"]))
	object.count:SetPoint("BOTTOMRIGHT", object, "BOTTOMRIGHT", header.config["count_x_offset"], header.config["count_y_offset"])
	
	--expiration text
	object.expiration:SetTextColor(unpack(header.config["expiration_color"]))
	object.expiration:SetFont(unpack(header.config["expiration_font"]))
	object.expiration:SetPoint("TOP", object, "BOTTOM", header.config["expiration_x_offset"], header.config["expiration_y_offset"])
	
	
	object.aura = {} --here we put the aura information, in button.update_aura(self)

	object.last_update = 0
	object.update_frequency = 0 --current update frequency (depends on time_remaining), set by button.update_aura_expiration(self, elapsed)
	
	object.active_tooltip = false --OnEnter this value is set to true and OnLeave to false
	
	--buffer for updating the aura information (avoid overwriting values)
	object.buffer = {}
	object.buffer.aura = {}
	
	return object
end

--Note:	There are more keys, however we don't need them
--		This table is only needed in button.update_aura(self)
local aura_keys = {"name", "rank", "icon", "count", "dispel_type", "duration", "expire", "caster", "is_stealable", "should_consolidate", "spell_id", "can_apply_aura", "is_boss_debuff", "value_1", "value_2"}
local num_aura_keys = #aura_keys

function button.update_aura(self)
	--Note:	Only in this function UnitAura() is called to avoid collision and inconsistencies due to client-server delay
	
	--wipe previous table
	self.buffer.aura = {}

	--Note:	self:GetID() returns the aura index
	local t = {UnitAura(self.header:GetAttribute("unit"), self:GetID(), self.header:GetAttribute("filter"))}
	local num_t = #t
	
	--Note:	UnitAura() sometimes returns nil when changing zones (e.g teleporting)
	--		just ignore this update, the UnitAura event will be called again immediately after
	if not t[1] then
		return
	end
	
	--take the smaller table
	for i=1, ((num_aura_keys > num_t) and num_t or num_aura_keys ) do
		self.buffer.aura[aura_keys[i]] = t[i]
	end

	--information needed for the tooltip
	--Note:	there is auras that do not have a caster (e.g Jade Spirit).
	--		button.update_aura_tooltip(self) checks if there is a valid ["caster_name"]
	if self.buffer.aura["caster"] then
		self.buffer.aura["caster_name"] = UnitName(self.buffer.aura["caster"])
		--it's possible that UnitName(unit) returns nil, if the unit is no longer available (e.g buff from target)
		if self.buffer.aura["caster_name"] then
			self.buffer.aura["caster_class"] = select(2, UnitClass(self.buffer.aura["caster"]))
			self.buffer.aura["caster_class_color"] = RAID_CLASS_COLORS[self.buffer.aura["caster_class"]]
		end
	end
		
	--expiration
	if self.buffer.aura["duration"] > 0 then
		--Note:	 we force an update if self.last_update > self.update_frequency
		--randomly picked numbers to force an update
		self.last_update = 2
		self.update_frequency = 1
		self:SetScript("OnUpdate", self.update_aura_expiration)
	else
		--Note:	if a button gets hidden (by blizzard's code) the OnUpdate script will not get removed,
		--		however this doesn't matter, because a hidden frame is not getting updated anyway!
		self:SetScript("OnUpdate", nil) 
		self.expiration:SetText("")
	end
	
	--apply the buffer
	self.aura = self.buffer.aura
	
	--icon
	self.icon.texture:SetTexture(self.aura["icon"])

	--count
	if self.aura["count"] > 0 then
		self.count:SetText(self.aura["count"])
		
	 --handle special spells 
	elseif self.aura["spell_id"] == 73975 and self.aura["value_2"] then --Necrotic Strike
		--use the stack count to display the amount healing absorbed by Necrotic Strike
		self.count:SetText(si_value(self.aura["value_2"]))
	
	else
		--usually we just "hide" it, by setting it to ""
		self.count:SetText("")
	end

end

function button.update_temp_enchant(self)
	--Note:	self:GetID() returns the InventoryId and will either be 16 (MainHandSlot) or 17 (SecondaryHandSlot)
	local has_enchant, time_remaining, count = select(1 + (self:GetID()-16)*3, GetWeaponEnchantInfo())
	
	if not has_enchant then
		--Note:	This happens when a TempEnchant is removed or
		--		when switching weapons (no_enchant -> enchant)
		--		switching weapons (main -> off) or (main <- off)
		return
	end 
	
	--icon
	self.icon.texture:SetTexture(GetInventoryItemTexture(self.header:GetAttribute("unit"), self:GetID()))
		
	--count
	if count > 0 then
		self.count:SetText(count)
	else
		self.count:SetText("")
	end

	--expiration
	if time_remaining > 0 then
		--Note:	 we force an update if self.last_update > self.update_frequency
		--randomly picked numbers to force an update
		self.last_update = 2
		self.update_frequency = 1
		self:SetScript("OnUpdate", self.update_temp_enchant_expiration)
	else
		--Note:	if a button gets hidden (by blizzard's code) the OnUpdate script will not get removed,
		--		however this doesn't matter, because a hidden frame is not getting updated anyway!
		self:SetScript("OnUpdate", nil)
		self.expiration:SetText("")
	end

end

--Note:	The update_..._expiration(self, elapsed) functions are called by an OnUpdate script
--		We throttle the update with self.update_frequency
function button.update_aura_expiration(self, elapsed)
	if self.last_update < self.update_frequency then 
		self.last_update = self.last_update + elapsed
		return
	end
	
	self.last_update = 0
	
	local time_remaining = self.aura["expire"] - GetTime()

	--change the update_frequency depending on the remaining time from the aura and the update_format
	self.update_frequency = self.header.config["update_frequency"][5] --asume worst case
	
	--Note: #self.header.config["update_format"] is 4
	for i=1, 4 do 
		--Note: 1.2 is just a saftiy factor
		if time_remaining - 1.2*self.header.config["update_frequency"][i+1] <= self.header.config["update_format"][i] then
			self.update_frequency = self.header.config["update_frequency"][i]
			break
		end
	end
	
	--Note: GetTime() is a "local" function and therefore doesn't actually ask the server for time.
	self.expiration:SetText(format_time(time_remaining, unpack(self.header.config["update_format"])))

	--update tooltip (if the mouse over the frame)
	if self.active_tooltip then
		self:update_aura_tooltip()
	end
end

function button.update_temp_enchant_expiration(self, elapsed)
	if self.last_update < self.update_frequency then
		self.last_update = self.last_update + elapsed
		return
	end

	self.last_update = 0

	--Note:	self:GetID() returns the InventoryId and will either be 16 (MainHandSlot) or 17 (SecondaryHandSlot)
	local time_remaining = select(2 + (self:GetID()-16)*3, GetWeaponEnchantInfo())
	
	if not time_remaining then
		--TODO is it even possible that we get no time_remaining ?
		print("error in update_temp_enchant_expiration, no time_remaining - please report this error", time_remaining)
		return
	end

	--Note:	for some reason the time returnd by GetWeaponEnchantInfo() needs to be divided by 1000 in order to get seconds
	time_remaining = time_remaining*0.001

	--change the update_frequency depending on the remaining time from the aura and the update_format
	self.update_frequency = self.header.config["update_frequency"][5] --asume worst case
	
	--Note: #self.header.config["update_format"] is 4
	for i=1, 4 do 
		--Note: 1.2 is just a saftiy factor
		if time_remaining - 1.2*self.header.config["update_frequency"][i+1] <= self.header.config["update_format"][i] then
			self.update_frequency = self.header.config["update_frequency"][i]
			break
		end
	end

	--update text
	self.expiration:SetText(format_time(time_remaining, unpack(self.header.config["update_format"])))
	
	--update tooltip (if the mouse over the frame)
	if self.active_tooltip then
		self:update_temp_enchant_tooltip()
	end

end

function button.update_aura_tooltip(self)
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
	GameTooltip:SetFrameLevel(self:GetFrameLevel() + 3)
	GameTooltip:SetUnitAura(self.header:GetAttribute("unit"), self:GetID(), self.header:GetAttribute("filter"))
	if self.aura["caster_name"] and self.aura["caster_class_color"] then
		GameTooltip:AddLine(self.aura["caster_name"], self.aura["caster_class_color"].r, self.aura["caster_class_color"].g, self.aura["caster_class_color"].b, true)
	end
	GameTooltip:Show()
end

function button.update_temp_enchant_tooltip(self)
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
	GameTooltip:SetFrameLevel(self:GetFrameLevel() + 3)
	GameTooltip:SetInventoryItem(self.header:GetAttribute("unit"), self:GetID())
	GameTooltip:Show()
end
--[[-- button class end --]]










