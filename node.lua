util.init_hosted()

-- this is only supported on the Raspi....
--util.noglobals()

node.set_flag("no_clear")

gl.setup(NATIVE_WIDTH, NATIVE_HEIGHT)

local TOP_TITLE = "ELEVATE INFOSCREEN"
local SPONSORS_TITLE = "SPONSORS"

local SCREEN_ASPECT = 16 / 9
FAKEWIDTH = HEIGHT * SCREEN_ASPECT

rawset(_G, "DEBUG_THINGS", true)


-- persistent state, survives file reloads
local state = rawget(_G, "._state")
if not state then
    state = {}
    rawset(_G, "._state", state)
end

local tqnew = require "tq"

local function ResetState()
    state.slideiter = nil
    state.slide = nil
    state.tq = tqnew()
end
rawset(_G, "ResetState", ResetState)


local json = require "json"
local fg = require "fg"
local res = util.auto_loader()

local Slide = require "slide"
Slide.res = res

local fancy = require "fancy"
fancy.res = res

if not state.tq then
    state.tq = tqnew()
end

util.file_watch("fg.lua", function(content)
    print("Reload fg.lua...")
    local x = assert(loadstring(content, "fg.lua"))()
    fg = x
    ResetState()
end)

util.file_watch("slide.lua", function(content)
    print("Reload slide.lua...")
    local x = assert(loadstring(content, "slide.lua"))()
    Slide = x
    Slide.res = res
    rawset(_G, "Slide", x)
    ResetState()
end)

node.event("config_update", function()
    fg.onUpdateConfig()
    table.clear(_tmptex)
end)

util.file_watch("schedule.json", function(content)
    local schedule = json.decode(content)
    fg.onUpdateSchedule(schedule)
end)

util.data_mapper{
    ["clock/set"] = function(tm)
        fg.onUpdateTime(tm)
    end,
}


local function nextslide()
    local it = state.slideiter
    if it then
        state.slide = it()
        if not state.slide then
            print("Slide iterator finished")
            it = nil
        end
    end
    if not it then
        local n
        it, n = fg.newSlideIter()
        state.slideiter = it
        print("Reloaded slide iter, to show:  " .. n)
    end
    if not state.slide then
        state.slide = it()
    end

    local t = 1
    if state.slide then
        t = state.slide.time or t
    end

    -- schedule next slide
    state.tq:push(t, nextslide)
end

-- takes x, y, sz in resolution-independent coords
-- (0, 0) = upper left corner, (1, 1) = lower right corner
-- sz == 0.5 -> half as high as the screen
local function drawfont(font, x, y, text, sz, fgcol, bgcol)
    local xx = x * FAKEWIDTH
    local yy = y * HEIGHT
    local zz = sz * HEIGHT
    local yborder = 0.01 * HEIGHT
    local xborder = 0.02 * HEIGHT -- intentionally HEIGHT, not a typo
    local w = font:write(xx, yy, text, zz, fgcol:rgba())
    local bgtex = fg.getcolortex(bgcol)
    bgtex:draw(xx-xborder, yy-yborder, xx+w+xborder, yy+zz+yborder)
    font:write(xx, yy, text, zz, fgcol:rgba())
    return xx, yy+zz, w
end

local function drawheader(slide) -- slide possibly nil (unlikely)
    local font = CONFIG.font
    local fontbold = CONFIG.font_bold
    local fgcol = CONFIG.foreground_color
    local bgcol = CONFIG.background_color
    local hy = 0.05

    local timesize = 0.08
    local timestr = fg.gettimestr()
    local timew = fontbold:width(timestr .. "     ", timesize*HEIGHT) / FAKEWIDTH
    local timex = 1.0 - timew

    -- time
    drawfont(fontbold, timex, hy, timestr, timesize, fgcol, bgcol)

    local xpos = 0.15
    local titlesize = 0.06
    drawfont(font, xpos, hy, TOP_TITLE, titlesize, fgcol, bgcol)

    hy = hy + titlesize + 0.02


    local wheresize
    if slide then
        local font = CONFIG.font_bold
        local where
        local fgcol2 = fgcol
        local bgcol2 = bgcol
        if slide.sponsor then
            where = SPONSORS_TITLE
            wheresize = 0.1

        elseif slide.here then
            where = slide.location.name
            wheresize = 0.1
        else
            wheresize = 0.08
            where = ("%s / %s"):format(slide.location.name, slide.track.name)
            fgcol2 = slide.track.foreground_color
            bgcol2 = slide.track.background_color
        end
        drawfont(font, xpos, hy, where, wheresize, fgcol2, bgcol2)
    end

    return FAKEWIDTH*xpos, hy + wheresize + HEIGHT*0.25
end

local function drawslide(slide, sx, sy)
    -- start positions after header
    gl.pushMatrix()
        slide:drawAbs(sx, sy)
        gl.translate(sx, sy)
        slide:draw()
    gl.popMatrix()
end

local function fixaspect(aspect)
    gl.scale(1 / (SCREEN_ASPECT / aspect), 1)
end
fancy.fixaspect = fixaspect

local function drawbgstatic()
    gl.pushMatrix()
        gl.scale(WIDTH, HEIGHT)
        CONFIG.background.ensure_loaded():draw(0, 0, 1, 1)
    gl.popMatrix()
end

local function drawlogo(aspect)
    gl.pushMatrix()
        gl.scale(WIDTH, HEIGHT)
        local logosz = 0.23
        CONFIG.logo.ensure_loaded():draw(-0.01, 0.01, logosz/aspect, logosz)
    gl.popMatrix()
end


function node.render()
    local aspect = WIDTH / HEIGHT
    local bgstyle = fg.getbgstyle()

    FAKEWIDTH = HEIGHT * SCREEN_ASPECT

    gl.ortho()

    if bgstyle == "static" then
        drawbgstatic()
    else
        fancy.render(bgstyle, aspect) -- resets the matrix
        gl.ortho()
    end

    fixaspect(aspect)
    drawlogo(aspect)



    local now = sys.now()
    local dt = (state.lastnow and now - state.lastnow) or 0
    state.lastnow = now

    state.tq:update(dt)

    if not state.slide then
        nextslide()
    end

    local hx, hy = drawheader(state.slide) -- returns where header ends
    if state.slide then
        drawslide(state.slide, hx, hy)
    end
end
