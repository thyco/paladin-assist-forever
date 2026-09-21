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

function panel:Initialize()
    if self.category then
        return
    end

    self.category = Settings.RegisterVerticalLayoutCategory("Paladin Assist Forever")
    local enabled = registerSetting(self.category, "cooldownGlowEnabled",
        "PaladinAssistForever_CooldownGlowEnabled",
        "Holy strike glow on Holy strike and judgement", Settings.VarType.Boolean)
    Settings.CreateCheckbox(self.category, enabled,
        "Glow the Holy Strike button only in combat, when either Holy Strike or Judgement is off cooldown. Applies to paladins only. Saved for all characters.")

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

    local sealBar = registerSetting(self.category, "sealBar",
        "PaladinAssistForever_SealBar", "Seal reminder action bar", Settings.VarType.Number)
    Settings.CreateDropdown(self.category, sealBar, function()
        local options = Settings.CreateControlTextContainer()
        options:Add(0, "Not selected")
        for index, label in ipairs(addon.Buttons.Bars()) do
            options:Add(index, label)
        end

        return options:GetData()
    end, "Choose the default action bar containing your seal button. No reminder is shown until you select a bar.")

    local sealButton = registerSetting(self.category, "sealButton",
        "PaladinAssistForever_SealButton", "Seal reminder button", Settings.VarType.Number)
    Settings.CreateDropdown(self.category, sealButton, function()
        local options = Settings.CreateControlTextContainer()
        for index = 1, 12 do
            options:Add(index, "Button " .. index)
        end

        return options:GetData()
    end, "Choose button 1 through 12 on that bar. This follows the physical position, including when the bar changes pages. Hidden buttons do not glow.")

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
