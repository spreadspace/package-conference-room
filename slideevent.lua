-------------------------------------------------------------------------------
--- Classes

local SlideEvent = {}
SlideEvent.__index = SlideEvent


-------------------------------------------------------------------------------
--- Helper Functions

-- timex means center of time, textx means start of text
-- linewrapping must happen here
function SlideEvent.Arrange(evs, timex, textx, textW, maxH)
    local sumH = 0
    local sumPadding = 0
    local lastPadding = 0
    for i, ev in ipairs(evs) do
        ev.timex = timex
        ev.textx = textx
        ev.titleparts = ev.title:fwrap(ev.font, ev.fontsize, textW)
        local subh = 0
        if ev.subtitle and #ev.subtitle > 0 then
            ev.subtitleparts = ev.subtitle:fwrap(ev.fontSub, ev.fontsizeSub, textW)
            subh = #ev.subtitleparts * (ev.fontsizeSub + ev.linespacingSub) - ev.linespacingSub
        end
        ev.height = #ev.titleparts * (ev.fontsize + ev.linespacing) - ev.linespacing + subh

        if (sumH + ev.height) >= maxH then
            for k = i, #evs do
                evs[k] = nil
            end
            break
        end
        sumH = sumH + ev.height + ev.ypadding
        sumPadding = sumPadding + ev.ypadding
        lastPadding = ev.ypadding
    end

    return sumH - lastPadding, sumPadding - lastPadding
end

local function _calcTimeCenterOffset(self)
    local h, m = self.start:match("(%d+):(%d+)")
    if not h then h = '--' end
    if not m then m = '--' end

    local font, sz = self.font, self.fontsize
    local wh = tools.textWidth(font, h, sz)
    local wc = tools.textWidth(font, ":", sz)
    -- local wm = tools.textWidth(font, m, sz)
    self.timeCenterOffset = - wh - (wc * 0.5)
end


-------------------------------------------------------------------------------
--- Constructors

function SlideEvent.new(proto, cfg) -- proto is an event def from json
    local self = table.shallowcopy(proto)
    setmetatable(self, SlideEvent)

    self.font = assert(cfg.font)
    self.fontsize = assert(cfg.fontsize)
    self.linespacing = assert(cfg.linespacing)

    self.fontSub = assert(cfg.fontSub)
    self.fontsizeSub = assert(cfg.fontsizeSub)
    self.linespacingSub = assert(cfg.linespacingSub)

    self.ypadding = assert(cfg.ypadding)
    _calcTimeCenterOffset(self)
    return self
end


-------------------------------------------------------------------------------
--- Member Functions

function SlideEvent:draw(y, fgcol, bgcol)
    local timex = self.timex + self.timeCenterOffset
    local textx = self.textx
    local lineh = self.fontsize + self.linespacing
    local linehSub = self.fontsizeSub + self.linespacingSub

    -- time text
    tools.drawText(self.font, timex, y, self.start, self.fontsize, fgcol, bgcol)

    -- title
    for _, s in ipairs(self.titleparts) do
        tools.drawText(self.font, textx, y, s, self.fontsize, fgcol, bgcol)
        y = y + lineh
    end

    -- subtitle
    if self.subtitleparts then
        for _, s in ipairs(self.subtitleparts) do
            tools.drawText(self.fontSub, textx, y, s, self.fontsizeSub, fgcol, bgcol)
            y = y + linehSub
        end
    end
end


-------------------------------------------------------------------------------

print("slideevent.lua loaded completely")
return SlideEvent
