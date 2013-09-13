--[[
Copyright (c) 2008-2013 Shaana <shaana@student.ethz.ch>
This file is part of sBuff.

sBuff is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

sBuff is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with sBuff.  If not, see <http://www.gnu.org/licenses/>.
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


--TODO implement a good way to change the update_frequency depending on time_remaining on the aura/temp_enchant

--TODO maybe add if not self:IsShown() condition to updating shit.

--TODO maybe change everything, so it would allow headers for different units ?
--TODO test (argent tournement horses) buffs while in a vehicle ? --> maybe remove the unit ~= vehicle confidition in OnEvent ?

--TODO might be worth it to bring most of the wow api we use alot into the local namespace
-- local UnitAura = UnitAura ...


--TODO add textures for 32px and 48px with predefined configs in config.lua (48px will be tricky)

--TODO change to vehicle buffs if we're in a vehicle
--means we have to set the attribute unit of the header to vehicle (prob easiest approach
--"UNIT_ENTERED_VEHICLE"
--"UNIT_ENTERING_VEHICLE"
--"UNIT_EXITED_VEHICLE"
--"UNIT_EXITING_VEHICLE"


--TODO there is more lua api .... and wow api ...
--math.max. math.min
local assert, error, type, select, pairs = assert, error, type, select, pairs

--load pixel perfection (pp)
local pp, pp_loaded = nil, false

if IsAddOnLoaded("sCore") and sCore.pp._object then
	pp = sCore.pp
	pp_loaded = true
end


local function _inherit(object, class)	
	assert(type(class) == "table")
	for k,v in pairs(class) do
		object[k] = v
	end
end

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
	
	--Note:	tempering with the metatable causes the the secure template to break.
	--		Therefore we inherit the options with a function. (basically creating links to each of the class functions)
	_inherit(object, header)
	
	--add pixel perfection, if sCore is loaded
	if pp_loaded then
		pp.add_all(object)
	end
	
	object.config = config
	object.button = {} --here we gonna put the list of buttons created by the button class

	set_attribute(object, attribute) --here happens the inheritance
	
	--Note: the maximum number buffs/debuffs a unit can have is 40
	local max_aura_with_wrap = object:GetAttribute("wrapAfter")*object:GetAttribute("maxWraps")
	object.max_aura = max_aura_with_wrap > 40 and 40 or max_aura_with_wrap
	
	
	object:SetPoint(unpack(config["anchor"]))
	
	--this will run SecureAuraHeader_Update(header)
	object:Show()

	--Note: UNIT_AURA will be added by blizzard's code
	object:RegisterEvent("PLAYER_ENTERING_WORLD")
	
	--TODO do we need this or is UNIT_AURA getting called anyway?
	--object:RegisterEvent("GROUP_ROSTER_UPDATE")
	
	--pet battle support (hiding frames during a battle)
	object:RegisterEvent("PET_BATTLE_CLOSE")
	object:RegisterEvent("PET_BATTLE_OPENING_START")

	--Note:	The UNIT_INVENTORY_CHANGED event is necessary, because when a new temp_enchant is applied/weapon are being switched UNIT_AURA is fired and immediately afterwards UNIT_INVENTORY_CHANGED
	--		but only after UNIT_INVENTORY_CHANGED was fired the new icon returned by GetInventoryItemTexture() is available
	--		for some reason button.update_temp_enchant() is only called once! (some smart blizzard code?)
	if object.config["helpful"] then
		--Note:	During the first login UNIT_INVENTORY_CHANGED is fired 30+ times (caching of inventory?)
		--		UPDATE_WEB_TICKET however is always fired after UNIT_INVENTORY_CHANGED, so we wait for UPDATE_WEB_TICKET and then register UNIT_INVENTORY_CHANGED
		object:RegisterEvent("UPDATE_WEB_TICKET")
	end

	object:HookScript("OnEvent", self.update)

	return object
end

function header.update_aura(self)
	--Note:	we keep the first two slots for temp_enchants, same for debuffs,
	--		even though they don't have temp_enchants
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
				--We can stop if we found the first child that is not shown
				break
			end
		end
	end
end

function header.update_temp_enchant(self)
	if self.config["helpful"] then
		for i=1, 2 do
			local child = self:GetAttribute("tempEnchant"..i)
			--Note:	child:IsShown() for tempEnchants is slow for some reason and sometimes returns nil even though the frame is already shown
			--		We'll check if there is really a temp enchant with hasEnchant,_,_ = GetWeaponEnchantInfo()
			if child then
				if not self.button[i] then 
					self.button[i] = class.button:new(self, child)
				end
				--update
				print(i, self.button[i]:GetID())
				self.button[i]:update_temp_enchant()
			end
		end
	end
end


--more of an event handler ...
function header.update(self, event, unit)

	print(self, event, unit)
	
	--Note:	temp_enchant update is only necessary for buff headers, the check happens in header.update_temp_enchant(self)
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
			--TODO in case we add vehicle support, we might need to change something here 
			self:update_aura()
			self:update_temp_enchant()
		end
	elseif event == "UNIT_INVENTORY_CHANGED" then
		--TODO in header.update. if INVENTORY_CHANGED is called only update temp enchants? prob doesnt work, cause 
		--if a new one is applied, all other buffs have to move. possible that in this case UNIT_AURA is called as well,maybe the frames are just moved
		if unit == self:GetAttribute("unit") then
			--self:update_aura()
			self:update_temp_enchant()
		end
	elseif event == "UPDATE_WEB_TICKET" then
		self:RegisterEvent("UNIT_INVENTORY_CHANGED")
		self:UnregisterEvent("UPDATE_WEB_TICKET")
		self:update_aura()
		self:update_temp_enchant()
	else
		print("error, don't know what to do with this event: ", event)
	end 
	
end

---button class

function button.new(self, header, child) --child given by iterating over children from the header
	local object = child

	--Note:	tempering with the metatable causes the the secure template to break. (Lots of errors while in combat due to protected functions,
	--		unable to remove certain buffs (f.e Shadowform)
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
		--pp.add_all(object.border)
		--pp.add_all(object.border.texture)
		--pp.add_all(object.gloss)
		--pp.add_all(object.gloss.texture)
		pp.add_all(object.count) 
		pp.add_all(object.expiration)
		
		--resize with pp.get_scale_factor()
		object:SetSize(child:GetSize())
	end
	
	--icon
	object.icon:SetAllPoints(child) --TODO this won't work if we create a 48px border texture, cause we'll have to scale the icon to 48px and still have a 64px border texture with bigger border_inset
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
	object.border:SetAllPoints(child)
	object.border:SetFrameLevel(2)

	object.border.texture:SetAllPoints(child)
	object.border.texture:SetTexture(header.config["border_texture"])
	object.border.texture:SetVertexColor(unpack(header.config["border_color"]))

	--gloss
	object.gloss:SetAllPoints(child)
	object.gloss:SetFrameLevel(3)
	
	object.gloss.texture:SetAllPoints(child)
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
	
	
	object.aura = {} --here we put the aura information. done in button.update

	object.last_update = 0
	object.update_frequency = 0 --current update frequency (depends on time_remaining), set by update_aura_expiration()
	
	object.active_tooltip = false
	
	object.buffer = {}
	object.buffer.aura = {}
	
	return object
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


--Note:	there are more keys, however we don't need them
local aura_keys = {"name", "rank", "icon", "count", "dispel_type", "duration", "expire", "caster", "is_stealable", "should_consolidate", "spell_id", "can_apply_aura", "is_boss_debuff", "value_1", "value_2"}
local num_aura_keys = #aura_keys

--update the button, only here UnitAura() is called
function button.update_aura(self)
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
	
	--take smaller table
	for i=1, ((num_aura_keys > num_t) and num_t or num_aura_keys ) do
		self.buffer.aura[aura_keys[i]] = t[i]
	end

	--information needed for the tooltip
	--Note:	there is auras that do not have a caster (e.g Jade Spirit).
	--		update_aura_tooltip() checks if there is a valid ["caster_name"]
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
	elseif self.aura["spell_id"] == 73975 and self.aura["value_2"] then
		--TODO test if it works with spell_id
		--if self.aura["spell_id"] == 73975 and self.aura["value_1"] then
		--if self.aura["name"] == "Necrotic Strike" and self.aura["value_1"] then
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
		--DEBUG
		print("error in button.update_temp_enchant(self,i), this error should never occure")
		--this always happens if a weapon without enchant is equipped after having one with with enchant equipped -->prob no longer the case that we listen to UNIT_INVENTORY_CHANGED
	end 
	
	--icon
	self.icon.texture:SetTexture(GetInventoryItemTexture(self.header:GetAttribute("unit"), self:GetID()))
		
	--count
	if count and count > 0 then
		self.count:SetText(count)
	else
		self.count:SetText("")
	end

	--expiration
	if time_remaining and time_remaining > 0 then
		--Note:	 we force an update if self.last_update > self.update_frequency
		--randomly picked numbers to force an update
		self.last_update = 2
		self.update_frequency = 1
		self:SetScript("OnUpdate", self.update_temp_enchant_expiration)
	else
		--print("removed update:", self.aura["name"])
		--TODO not sure if this works to properly remove the script, cause we wont even enter the function.
		--if there is no enchant
		self:SetScript("OnUpdate", nil)
		self.expiration:SetText("")
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

--[[
function button._update_expiration(self, elapsed)

end

--]]

--OnUpdate, update time remaining ....
function button.update_aura_expiration(self, elapsed)
	if self.last_update < self.update_frequency then 
		self.last_update = self.last_update + elapsed
		return
	end
	
	self.last_update = 0
	
	local time_remaining = self.aura["expire"] - GetTime()

	--change the update_frequency depending on the remaining time from the aura and the update_format
	--asume worst case
	self.update_frequency = self.header.config["update_frequency"][5]
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

	--update tooltip (if the mouse on the frame)
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

	local time_remaining = select(2 + (self:GetID()-16)*3, GetWeaponEnchantInfo())

	if not time_remaining then
		--TODO is it even possible that we get no time_remaining ?
		--DEBUG
		print("error in update_temp_enchant_expiration, no time_remaining", time_remaining)
	end

	--change the update_frequency depending on the remaining time from the aura and the update_format
	--asume worst case
	self.update_frequency = self.header.config["update_frequency"][5]
	--Note: #self.header.config["update_format"] is 4
	for i=1, 4 do 
		--Note: 1.2 is just a saftiy factor
		if time_remaining - 1.2*self.header.config["update_frequency"][i+1] <= self.header.config["update_format"][i] then
			self.update_frequency = self.header.config["update_frequency"][i]
			break
		end
	end
	
	--update text
	--Note:	for some reason the time needs to be divided by 1000
	self.expiration:SetText(format_time(time_remaining*0.001))
	
	if self.active_tooltip then
		self:update_temp_enchant_tooltip()
	end

end


--TODO might wanna call the update_expiration function to make sure the tooltip is in sync with the expiration time
--however this might cause troubles again.
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
	--print("update_tooltip_temp_enchant")
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
	GameTooltip:SetFrameLevel(self:GetFrameLevel() + 3)
	GameTooltip:SetInventoryItem(self.header:GetAttribute("unit"), self:GetID())
	GameTooltip:Show()
end











