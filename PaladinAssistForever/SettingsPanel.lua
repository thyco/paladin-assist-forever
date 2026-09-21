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

    Settings.RegisterAddOnCategory(self.category)
end

function panel:Open()
    if self.category then
        Settings.OpenToCategory(self.category:GetID())
    end
end
