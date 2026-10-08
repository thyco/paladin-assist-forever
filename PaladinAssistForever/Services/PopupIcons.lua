local _, addon = ...
local PopupIcons = {}
addon.PopupIcons = PopupIcons

local placeholder = 'Interface\\Icons\\INV_Misc_QuestionMark'

local function round(value)
    return math.floor(value + 0.5)
end

local function clamp(value, limit)
    return math.max(-limit, math.min(limit, value))
end

function PopupIcons.New(owner, onMoved)
    local frame = CreateFrame('Frame', nil, UIParent)
    local icon = frame:CreateTexture(nil, 'ARTWORK')
    local popup = setmetatable({ frame = frame, texture = icon, owner = owner, onMoved = onMoved, size = 64 },
        { __index = PopupIcons })

    icon:SetAllPoints(frame)
    icon:SetTexture(placeholder)
    frame:SetSize(64, 64)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag('LeftButton')

    frame:SetScript('OnDragStart', function(self)
        self:StartMoving()
    end)
    frame:SetScript('OnDragStop', function(self)
        self:StopMovingOrSizing()

        local x, y = self:GetCenter()
        local parentX, parentY = UIParent:GetCenter()
        local scale = self:GetEffectiveScale() / UIParent:GetEffectiveScale()
        local offsetX = round(x * scale - parentX)
        local offsetY = round(y * scale - parentY)

        popup:SetPosition(offsetX, offsetY)
        onMoved(popup.x, popup.y)
    end)

    popup:SetPosition(0, 0)
    addon.Glow.Prepare(frame, true)
    frame:Hide()

    return popup
end

function PopupIcons:SetIcon(texture)
    self.texture:SetTexture(texture or placeholder)
end

function PopupIcons:SetSize(pixels)
    self.size = pixels
    self.frame:SetSize(pixels, pixels)
    self:SetPosition(self.x or 0, self.y or 0)
end

function PopupIcons:SetPosition(x, y)
    local limitX = math.max(0, (UIParent:GetWidth() - self.size) / 2)
    local limitY = math.max(0, (UIParent:GetHeight() - self.size) / 2)

    self.x = round(clamp(x, limitX))
    self.y = round(clamp(y, limitY))

    self.frame:ClearAllPoints()
    self.frame:SetPoint('CENTER', UIParent, 'CENTER', self.x, self.y)
end

function PopupIcons:SetVisible(reminder, preview, flash)
    if reminder then
        self.frame:Show()
        addon.Glow.Set(self.frame, self.owner, true, { startAnim = flash and not self.active })
    else
        addon.Glow.Set(self.frame, self.owner, false)
        self.frame:SetShown(not not preview)
    end

    self.active = not not reminder
end
