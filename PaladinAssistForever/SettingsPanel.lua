local _, addon = ...
local panel = {}
addon.SettingsPanel = panel

local function registerSetting(category, key, variable, label, valueType)
    return Settings.RegisterProxySetting(
        category,
        variable,
        valueType,
        label,
        addon.Config.GetDefault(key),
        function()
            return addon.Config.Get(key)
        end,
        function(value)
            addon.Config.Set(key, value)
        end
    )
end

-- Both reminders use the same physical bar/position controls.
local function registerButtonSelector(category, keyPrefix, variablePrefix, label)
    local bar = registerSetting(category, keyPrefix .. "Bar",
        "PaladinAssistForever_" .. variablePrefix .. "Bar", label .. " action bar", Settings.VarType.Number)
    Settings.CreateDropdown(category, bar, function()
        local options = Settings.CreateControlTextContainer()
        options:Add(0, "Not selected")
        for index, name in ipairs(addon.Buttons.Bars()) do
            options:Add(index, name)
        end

        return options:GetData()
    end, "Choose a default action bar. This reminder does not glow until you select a bar.")

    local button = registerSetting(category, keyPrefix .. "Button",
        "PaladinAssistForever_" .. variablePrefix .. "Button", label .. " button", Settings.VarType.Number)
    Settings.CreateDropdown(category, button, function()
        local options = Settings.CreateControlTextContainer()
        for index = 1, 12 do
            options:Add(index, "Button " .. index)
        end

        return options:GetData()
    end, "Choose button 1 through 12 on that bar. This follows the physical position, including when the bar changes pages. Hidden buttons do not glow.")
end

function panel:Initialize()
    if self.category then
        return
    end

    self.category = Settings.RegisterVerticalLayoutCategory("Paladin Assist Forever")
    local enabled = registerSetting(self.category, "cooldownGlowEnabled",
        "PaladinAssistForever_CooldownGlowEnabled",
        "Holy strike glow on Holy strike and judgement", Settings.VarType.Boolean)
    Settings.CreateCheckbox(self.category, enabled,
        "Glow the selected button only in combat, when either Holy Strike or Judgement is off cooldown. Applies to paladins only. Saved for all characters.")

    registerButtonSelector(self.category, "holyStrike", "HolyStrike", "Holy Strike/Judgement")

    local native = registerSetting(self.category, "glowNativeColor",
        "PaladinAssistForever_GlowNativeColor", "Use Blizzard native glow", Settings.VarType.Boolean)
    Settings.CreateCheckbox(self.category, native,
        "Use Blizzard's original proc-glow artwork and colors, as in DK Force. Uncheck to use your custom glow color.")

    local color = registerSetting(self.category, "glowColor",
        "PaladinAssistForever_GlowColor", "Custom glow color", Settings.VarType.String)
    Settings.CreateColorSwatch(self.category, color,
        "Choose a custom glow color. It applies when Use Blizzard native glow is unchecked; your choice is saved while native mode is enabled.")

    local sealEnabled = registerSetting(self.category, "sealGlowEnabled",
        "PaladinAssistForever_SealGlowEnabled", "Seal refresh reminder", Settings.VarType.Boolean)
    Settings.CreateCheckbox(self.category, sealEnabled,
        "Glow one selected button in combat or with an attackable target/mouseover unit, 27 seconds after a successful seal cast. Until a cast is observed after login or reload, a refresh is assumed due. Does not detect dispels.")

    registerButtonSelector(self.category, "seal", "Seal", "Seal reminder")

    local sealColor = registerSetting(self.category, "sealGlowColor",
        "PaladinAssistForever_SealGlowColor", "Seal reminder glow color", Settings.VarType.String)
    Settings.CreateColorSwatch(self.category, sealColor,
        "Independent of the Holy Strike glow; red by default. The seal color takes priority if both reminders use the same button.")

    Settings.RegisterAddOnCategory(self.category)
end

function panel:Open()
    if self.category then
        Settings.OpenToCategory(self.category:GetID())
    end
end
