local _, addon = ...
local panel = {}
addon.SettingsPanel = panel

function panel:Initialize()
    if self.category then
        return
    end

    self.category = Settings.RegisterVerticalLayoutCategory("Paladin Assist Forever")
    local setting = Settings.RegisterProxySetting(
        self.category,
        "PaladinAssistForever_CooldownGlowEnabled",
        Settings.VarType.Boolean,
        "Enable cooldown glow",
        true,
        function()
            return addon.Config.Get("cooldownGlowEnabled")
        end,
        function(value)
            addon.Config.Set("cooldownGlowEnabled", value)
        end
    )

    Settings.CreateCheckbox(self.category, setting,
        "Glow the Holy Strike button only in combat, when Judgement or Holy Strike is off cooldown. Applies to paladins only. Saved for all characters.")
    Settings.RegisterAddOnCategory(self.category)
end

function panel:Open()
    if self.category then
        Settings.OpenToCategory(self.category:GetID())
    end
end
