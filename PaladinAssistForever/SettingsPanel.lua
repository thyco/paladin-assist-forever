local _, addon = ...
local panel = { controls = {}, sections = {} }
addon.SettingsPanel = panel

local function registerSetting(key, variable, label, valueType)
    return Settings.RegisterProxySetting(
        panel.category, variable, valueType, label, addon.Config.GetDefault(key),
        function()
            return addon.Config.Get(key)
        end,
        function(value)
            addon.Config.Set(key, value)
        end
    )
end

local function checkbox(section, key, variable, label, y, tooltip)
    local setting = registerSetting(key, variable, label, Settings.VarType.Boolean)
    panel.controls[key] = addon.SettingsWidgets.Checkbox(section, label, y, setting, tooltip)
end

local function color(section, key, variable, label, y, tooltip)
    local setting = registerSetting(key, variable, label, Settings.VarType.String)
    panel.controls[key] = addon.SettingsWidgets.Color(section, label, y, setting, tooltip)
end

local function buttonSelector(section, keyPrefix, variablePrefix, name)
    local bars = { { value = 0, label = "Not selected" } }
    for index, label in ipairs(addon.Buttons.Bars()) do
        bars[#bars + 1] = { value = index, label = label }
    end

    local buttons = {}
    for index = 1, 12 do
        buttons[#buttons + 1] = { value = index, label = "Button " .. index }
    end

    local bar = registerSetting(keyPrefix .. "Bar", "PaladinAssistForever_" .. variablePrefix .. "Bar",
        name .. " action bar", Settings.VarType.Number)
    panel.controls[keyPrefix .. "Bar"] = addon.SettingsWidgets.Dropdown(section, "Action bar", -100, bar, bars,
        "Choose a default action bar. No glow appears until a bar is selected.")

    local button = registerSetting(keyPrefix .. "Button", "PaladinAssistForever_" .. variablePrefix .. "Button",
        name .. " button", Settings.VarType.Number)
    panel.controls[keyPrefix .. "Button"] = addon.SettingsWidgets.Dropdown(section, "Button", -136, button, buttons,
        "Uses a fixed position, including when the bar changes pages. Hidden buttons do not glow.")
end

function panel:Refresh()
    for _, control in pairs(self.controls) do
        control.refresh()
    end
end

function panel:Initialize()
    if self.category then
        return
    end

    local widgets = addon.SettingsWidgets
    local canvas = CreateFrame("Frame")
    self.canvas = canvas
    canvas:Hide()
    self.category = Settings.RegisterCanvasLayoutCategory(canvas, "Paladin Assist Forever")

    local scroll = CreateFrame("ScrollFrame", nil, canvas, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", canvas, "TOPLEFT", 0, -8)
    scroll:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMRIGHT", -28, 8)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(580, 1020)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function(_, width)
        content:SetWidth(math.max(1, width))
    end)

    local icon = content:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", content, "TOPLEFT", 8, -8)
    icon:SetSize(36, 36)
    icon:SetTexture("Interface\\AddOns\\PaladinAssistForever\\Media\\Icon.tga")
    widgets.Text(content, "Paladin Assist Forever", 52, -8, "GameFontNormalLarge")
    widgets.Text(content, "Choose one button for each reminder. Changes apply immediately.", 52, -34)
    local holy = widgets.Section(content, "Holy Strike / Judgement", "Combat only · Judgement color takes priority", -64, 386)
    local seal = widgets.Section(content, "Seal reminder", "Combat or a living attackable target / mouseover", -466, 256)
    local exorcism = widgets.Section(content, "Exorcism", "Combat only · living attackable undead or demon", -738, 256)

    self.sections = { holy, seal, exorcism }

    checkbox(holy, "cooldownGlowEnabled", "PaladinAssistForever_CooldownGlowEnabled",
        "Holy strike glow on Holy strike and judgement", -62,
        "Glow only in combat when Judgement is off cooldown, or Holy Strike if its check is enabled. Applies to paladins only; saved for all characters.")
    buttonSelector(holy, "holyStrike", "HolyStrike", "Holy Strike/Judgement")
    checkbox(holy, "holyStrikeCheckEnabled", "PaladinAssistForever_HolyStrikeCheckEnabled", "Check Holy Strike", -172,
        "Uncheck to glow only when Judgement is ready. Judgement always takes priority when both spells are ready.")
    checkbox(holy, "glowNativeColor", "PaladinAssistForever_GlowNativeColor", "Holy Strike: Blizzard native glow", -208,
        "Uncheck to use the Holy Strike color below. Applies only when Check Holy Strike is enabled.")
    color(holy, "glowColor", "PaladinAssistForever_GlowColor", "Holy Strike color", -248,
        "Used when Holy Strike is ready and Judgement is not, with Holy Strike native mode unchecked.")
    checkbox(holy, "judgementNativeColor", "PaladinAssistForever_JudgementNativeColor", "Judgement: Blizzard native glow", -288,
        "Uncheck to use the Judgement color below. Judgement's appearance wins when both spells are ready.")
    color(holy, "judgementGlowColor", "PaladinAssistForever_JudgementGlowColor", "Judgement color", -328,
        "Used whenever Judgement is ready, with Judgement native mode unchecked. Cancel restores the previous color.")

    checkbox(seal, "sealGlowEnabled", "PaladinAssistForever_SealGlowEnabled", "Enable seal reminder", -62,
        "Reminds after your selected delay. After reload it assumes a refresh is due until a seal cast is observed. Does not detect dispels.")
    buttonSelector(seal, "seal", "Seal", "Seal reminder")
    local delays = {}
    for seconds = 1, 30 do
        delays[#delays + 1] = { value = seconds, label = seconds .. (seconds == 1 and " second" or " seconds") }
    end

    local delay = registerSetting("sealReminderSeconds", "PaladinAssistForever_SealReminderSeconds",
        "Remind after", Settings.VarType.Number)
    self.controls.sealReminderSeconds = widgets.Dropdown(seal, "Remind after", -172, delay, delays,
        "Seconds after a successful seal cast (1–30). Default: 26, giving 4 seconds before the assumed 30-second expiry. Changes also apply to your current timer.")

    color(seal, "sealGlowColor", "PaladinAssistForever_SealGlowColor", "Glow color", -216,
        "Red by default, independent of Holy Strike. Seal color takes priority if both reminders share a button.")

    checkbox(exorcism, "exorcismGlowEnabled", "PaladinAssistForever_ExorcismGlowEnabled",
        "Enable Exorcism glow", -62,
        "Glow in combat when Exorcism is off cooldown and your target or mouseover is a living attackable undead or demon.")
    buttonSelector(exorcism, "exorcism", "Exorcism", "Exorcism")
    checkbox(exorcism, "exorcismNativeColor", "PaladinAssistForever_ExorcismNativeColor",
        "Use Blizzard native glow", -172,
        "Uncheck to use your custom Exorcism color. Native glow is the default.")
    color(exorcism, "exorcismGlowColor", "PaladinAssistForever_ExorcismGlowColor",
        "Custom glow color", -216,
        "Applies when Blizzard native glow is unchecked. Cancel restores the previous color.")

    canvas:SetScript("OnShow", function()
        content:SetWidth(math.max(1, scroll:GetWidth()))
        self:Refresh()
    end)
    addon.Config.Subscribe(function()
        self:Refresh()
    end)
    self:Refresh()
    Settings.RegisterAddOnCategory(self.category)
end

function panel:Open()
    if self.category then
        Settings.OpenToCategory(self.category:GetID())
    end
end
