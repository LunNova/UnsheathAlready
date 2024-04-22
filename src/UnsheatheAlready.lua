UnsheatheAlready = LibStub("AceAddon-3.0"):NewAddon("UnsheatheAlready", "AceTimer-3.0", "AceConsole-3.0")

local addonName = "UnsheatheAlready"
local eventFrame
local unsheathTimer
local backoffMultiplier = 1
local maxBackoff = 5

-- Table of sheath blocking conditions
local sheathBlockers = {
	inCombat = InCombatLockdown,
	isSwimming = IsSwimming,
	isSubmerged = IsSubmerged,
	isResting = IsResting,
	isMounted = IsMounted,
	isStealthed = IsStealthed,
	isFlying = IsFlying,
}

local function shouldToggleSheath()
	local targetSheath = UnsheatheAlready.db.profile.targetSheath
	if GetSheathState() == targetSheath or GetUnitSpeed("player") >= UnsheatheAlready.db.profile.maxSpeed then
		return false
	end
	for setting, func in pairs(sheathBlockers) do
		if UnsheatheAlready.db.profile[setting] and func() then
			return false
		end
	end
	for _, condition in ipairs(UnsheatheAlready.db.profile.customConditions) do
		local func, err = loadstring("return " .. condition)
		if func then
			if func() then
				return false
			end
		else
			print("UnsheatheAlready: Invalid custom condition: " .. err)
		end
	end
	return true
end

function UnsheatheAlready:UnsheathIfNeeded()
	if shouldToggleSheath() then
		for i = 1, self.db.profile.targetSheath - GetSheathState() do
			ToggleSheath()
		end
	end
	backoffMultiplier = math.min(backoffMultiplier * 2, maxBackoff)

	self:Reschedule()
end

local function registerEvents()
	for _, event in ipairs({
		"PLAYER_REGEN_ENABLED",
		"LOOT_CLOSED",
		"PLAYER_ENTERING_WORLD",
		"PLAYER_LEAVING_WORLD",
	}) do
		eventFrame:RegisterEvent(event)
	end
end

function UnsheatheAlready:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New(addonName .. "DB", {
		profile = {
			enabled = true,
			inCombat = true,
			isSwimming = true,
			isSubmerged = true,
			isResting = true,
			isMounted = true,
			isStealthed = true,
			isFlying = true,
			customConditions = {},
			targetSheath = 2,
			minDelay = 0.75,
			maxSpeed = 10,
		},
	})

	eventFrame = CreateFrame("FRAME", "UnsheatheAlreadyEventFrame")
	registerEvents()
	eventFrame:SetScript("OnEvent", function(frame, event)
		backoffMultiplier = 1
		self:Reschedule()
	end)

	self:SetupOptions()
end

function UnsheatheAlready:Reschedule()
	if unsheathTimer then
		self:CancelTimer(unsheathTimer)
	end
	unsheathTimer = self:ScheduleTimer("UnsheathIfNeeded", self.db.profile.minDelay * backoffMultiplier)
end

function UnsheatheAlready:OnEnable()
	backoffMultiplier = 1
	self:Reschedule()
end

function UnsheatheAlready:OnDisable()
	if unsheathTimer then
		self:CancelTimer(unsheathTimer)
		unsheathTimer = nil
	end
end

function UnsheatheAlready:RefreshCustomConditions()
	self.options.args.customConditions.args = {
		desc = {
			order = 1,
			type = "description",
			name = "Enter custom Lua conditions that prevent unsheathing when true. If any custom condition evaluates to true, the addon will not unsheath your weapon.",
		},
		add = {
			order = 2,
			type = "input",
			name = "Add Condition",
			desc = "Enter a custom Lua condition",
			get = function()
				return ""
			end,
			set = function(info, value)
				local func, err = loadstring("return " .. value)
				if func then
					table.insert(self.db.profile.customConditions, value)
					self:RefreshCustomConditions()
				else
					print("UnsheatheAlready: Invalid custom condition: " .. err)
				end
			end,
		},
	}

	for i, condition in ipairs(self.db.profile.customConditions) do
		self.options.args.customConditions.args["condition" .. i] = {
			order = i + 2,
			type = "group",
			name = "Condition " .. i,
			inline = true,
			args = {
				condition = {
					order = 1,
					type = "input",
					name = "Condition",
					desc = "Custom Lua condition",
					width = "full",
					get = function()
						return condition
					end,
					set = function(info, value)
						local func, err = loadstring("return " .. value)
						if func then
							self.db.profile.customConditions[i] = value
						else
							print("UnsheatheAlready: Invalid custom condition: " .. err)
						end
					end,
				},
				status = {
					order = 2,
					type = "description",
					name = function()
						local func, err = loadstring("return " .. condition)
						if func then
							return func() and "|cFFFF0000Blocking|r" or "|cFF00FF00Allowing|r"
						else
							return "|cFFFF0000Invalid|r"
						end
					end,
				},
				remove = {
					order = 3,
					type = "execute",
					name = "Remove",
					confirm = true,
					confirmText = "Are you sure you want to remove this condition?",
					func = function()
						table.remove(self.db.profile.customConditions, i)
						self:RefreshCustomConditions()
					end,
				},
			},
		}
	end

	LibStub("AceConfigRegistry-3.0"):NotifyChange(addonName)
end

function UnsheatheAlready:SetupOptions()
	local function getDesc(setting)
		return string.format("Prevent unsheathing when %s.", setting:gsub("is", ""))
	end

	self.options = {
		type = "group",
		name = addonName,
		args = {
			general = {
				order = 1,
				type = "group",
				name = "General",
				inline = true,
				args = {
					enabled = {
						order = 0,
						type = "toggle",
						name = "Enabled",
						desc = "Enable or disable the addon.",
						get = function()
							return self.db.profile.enabled
						end,
						set = function(info, value)
							self.db.profile.enabled = value
						end,
					},
					test = {
						order = 1,
						type = "execute",
						name = "Test",
						desc = "Test UnsheathIfNeeded.",
						func = function()
							self:UnsheathIfNeeded()
						end,
						width = 2,
					},
					targetSheath = {
						order = 2,
						type = "select",
						name = "Unsheathe To",
						desc = "Select the desired weapon state to unsheathe to.",
						values = {
							[1] = "Unarmed",
							[2] = "Melee",
							[3] = "Ranged",
						},
						get = function()
							return self.db.profile.targetSheath
						end,
						set = function(info, value)
							self.db.profile.targetSheath = value
						end,
					},
					minDelay = {
						order = 3,
						type = "range",
						name = "Minimum Delay",
						desc = "The minimum time (in seconds) between unsheathing actions.",
						min = 0.5,
						max = 5,
						step = 0.25,
						get = function()
							return self.db.profile.minDelay
						end,
						set = function(info, value)
							self.db.profile.minDelay = value
						end,
					},
					maxSpeed = {
						order = 4,
						type = "range",
						name = "Maximum Speed",
						desc = "The maximum speed (in yards per second) at which to unsheathe.",
						min = 1,
						max = 100,
						step = 1,
						get = function()
							return self.db.profile.maxSpeed
						end,
						set = function(info, value)
							self.db.profile.maxSpeed = value
						end,
					},
				},
			},
			conditions = {
				order = 2,
				type = "group",
				inline = true,
				name = "Unsheathe Blocking Conditions",
				args = {
					desc = {
						order = 0,
						type = "description",
						fontSize = "medium",
						name = "Select the conditions that should prevent unsheathing. If any checked condition is true, the addon will not unsheath your weapon.\n\nConditions in |cFFFF0000red|r are currently preventing unsheathing, while conditions in |cFF00FF00green|r are not.",
					},
				},
			},
			customConditions = {
				order = 3,
				type = "group",
				inline = true,
				name = "Custom Conditions",
				args = {},
			},
		},
	}

	local i = 1
	for setting, func in pairs(sheathBlockers) do
		self.options.args.conditions.args[setting] = {
			order = i,
			type = "toggle",
			name = function()
				local color = func() and "|cFFFF0000" or "|cFF00FF00"
				return string.format("%s%s|r", color, setting:gsub("^%l", string.upper):gsub("is", ""))
			end,
			desc = getDesc(setting),
			width = "normal",
			get = function()
				return self.db.profile[setting]
			end,
			set = function(info, value)
				self.db.profile[setting] = value
			end,
		}
		i = i + 1
	end

	self:RefreshCustomConditions()

	LibStub("AceConfig-3.0"):RegisterOptionsTable(addonName, self.options)
	self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addonName, addonName)
end
