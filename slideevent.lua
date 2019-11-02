local SlideEvent = {}
SlideEvent.__index = SlideEvent

--[[
local BOX = {}
BOX.__index = BOX

function BOX.new(x, y, w, h)
    local yborder = 0.01 * HEIGHT
    local xborder = 0.02 * HEIGHT -- intentionally HEIGHT, not a typo
    local self = { x-xborder, y-yborder, x+w+xborder, y+sz+yborder }
    return setmetatable(self, BOX)
end

function BOX:draw(col) -- abs. coords/size
    local bgtex = tools.getColorTex(bgcol)
    bgtex:draw(unpack(self))
end
]]


-- an event-to-display is a timestamp with a title and subtitle
-- track is not handled here.

--[[
things added:
  .width -- total width in relative coords
  .height -- total height in relative coords
]]
local config =
{
    fontscale1 = 0.07, -- fontscale is in total screen height
    fontscale2 = 0.045,
    font = CONFIG.font,
}




-- returns w, h, colonOffset as relative sizes (center of colon = w + colonOffs)
local function layouttime(self, mul)
    local h, m = self.start:match("(%d+):(%d+)")
    if not h then h = '--' end
    if not m then m = '--' end
    local relscale = config.fontscale1 * mul
    local font, scale = config.font, fg.RelSizeToScreen(self.fontscale)
    local wh = font:width(h, scale)
    local wc = font:width(":", scale)
    local wm = font:width(m, scale)
    local offs = -wh - (wc * 0.5)
    self.tw = fg.ScreenPosToRel(wh + wc + wm)
    self.tco = offs / FAKEWIDTH
end

local function layout(self, cfg)
    local mul = assert(cfg.sizemult)
    self.fontscale = assert(config.fontscale1) * mul
    self.fontscale2 = assert(config.fontscale2) * mul
    self.linespacing = assert(cfg.linespacing)
    self.ypadding = assert(cfg.ypadding)
    self.timexoffs = assert(cfg.timexoffs)
    self.titlexoffs = assert(cfg.titlexoffs)
    layouttime(self, mul)
end

-- final alignment step for all events generated for a single slide
-- align to relative screen size (w, h) (w == 0.9 means fill up to 90% of the screen width)
-- linewrapping must happen here
function SlideEvent.Align(evs, w, h)
    local maxtw = 0
    local maxtend = 0
    local ybegin = 0
    local totalAvailW, totalAvailH = fg.RelPosToScreen(w, h)
    local font = config.font

    for i, ev in ipairs(evs) do
        maxtw = math.max(maxtw, ev.tw)
        maxtend = math.max(maxtend, ev.tw + math.abs(ev.tco))
        --ev.subtitle = "Suppress normal output; instead print the name of each input file from which no output would normally have been printed. The scanning will stop on the first match."
    end

    local absTimeW = fg.RelPosToScreen(maxtend)
    local textAvailW = totalAvailW - absTimeW

    for i, ev in ipairs(evs) do
        local fontsize = fg.RelSizeToScreen(ev.fontscale)
        local subfontsize = fg.RelSizeToScreen(ev.fontscale2)

        ev.maxtw = maxtw
        ev.textx = 0

        ev.titleparts = ev.title:fwrap(font, fontsize, 0, textAvailW)
        local subh = 0
        if ev.subtitle and #ev.subtitle > 0 then
            ev.subtitleparts = ev.subtitle:fwrap(font, subfontsize, 0, textAvailW)
            subh = #ev.subtitleparts * ev.fontscale2
        end
        ev.heightNoPadding = (ev.fontscale + ev.linespacing) * #ev.titleparts
            + subh

        ev.height = ev.heightNoPadding  + ev.ypadding
        ev.maxwidth = w
        ev.maxheight = h
        ev.ybegin = ybegin
        ybegin = ybegin + ev.height

        -- remove events that don't fit
        local endY = ev.ybegin + ev.heightNoPadding - ev.linespacing
        if endY >= ev.maxheight then
            for k = i, #evs do
                evs[k] = nil
            end
            return
        end
    end
end

function SlideEvent.new(proto, cfg) -- proto is an event def from json
    local self = table.shallowcopy(proto)
    setmetatable(self, SlideEvent)

    layout(self, cfg)
    return self
end

local RED = resource.create_colored_texture(1, 0, 0, 0.2)
local GREEN = resource.create_colored_texture(0, 1, 0, 0.2)
local BLUE = resource.create_colored_texture(0, 0, 1, 0.2)

function SlideEvent:drawtick(fgcol, sx, sy)
    local fgtex = tools.getColorTex(fgcol)
    local gxo = 0.04 * WIDTH
    local gyo = HEIGHT * 0.004
    local ystart = fg.RelSizeToScreen(self.ybegin)
    local scale = fg.RelSizeToScreen(self.fontscale)
    local x, y = sx, sy + ystart + (scale*0.5)
    fgtex:draw(x-gxo*0.5, y-gyo, x+gxo*0.5, y+gyo)
end


-- this ensures that all colons are aligned
function SlideEvent:draw(fgcol, bgcol)

    local scale = fg.RelSizeToScreen(self.fontscale)
    local subscale = fg.RelSizeToScreen(self.fontscale2)
    local timex, ystart = fg.RelPosToScreen(self.tco + self.timexoffs, self.ybegin)
    local font = config.font
    local textx = fg.RelPosToScreen(self.maxtw + self.titlexoffs)
    local absLineDist = fg.RelSizeToScreen(self.linespacing) + scale
    local absSubLineDist = subscale
    local bgtex = tools.getColorTex(bgcol)

    -- debug: total size of drawing area
    if DEBUG_THINGS then
        local xend, yend = fg.RelPosToScreen(self.tco + self.maxwidth, self.ybegin + self.heightNoPadding)
        RED:draw(textx, ystart, xend, yend)
    end

    -- TODO: time BG

    -- time text
    font:write(timex, ystart, self.start, scale, fgcol:rgba())



    -- title
    local ty = ystart

    -- TODO: bg box for title
    -- TODO: bg box for subtitle

    for _, s in ipairs(self.titleparts) do
        font:write(textx, ty, s, scale, fgcol:rgba())
        ty = ty + absLineDist
    end

    if self.subtitleparts then
        for _, s in ipairs(self.subtitleparts) do
            font:write(textx, ty, s, subscale, fgcol:rgba())
            ty = ty + absSubLineDist
        end
    end
end



print("slideevent.lua loaded completely")
return SlideEvent
