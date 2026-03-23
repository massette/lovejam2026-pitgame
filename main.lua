d = require("lib.debug")

local g = love.graphics
g.setDefaultFilter("linear", "nearest")
g.setLineStyle("rough")

local fs = love.filesystem

local s = require("src.styles")
local images = require("src.images")
g.setLineWidth(s.border)
g.setBackgroundColor(
    images.colors[2][
        images.colors.by_name["white"]
    ]
)

--[[ SCALING ]]--
local screen = g.newCanvas(s.width, s.height)
local scale = 1
local ox, oy = 0, 0

--[[ CONTENT ]]--
local bar = require("src.bar")
local text = require("src.text")
local model = require("src.model")
local counts = require("src.counts")

--[[ LOCAL FUNCTIONS ]]--
local focus
local current_step = 1

local function set_focus(element)
    if focus then
        focus.has_focus = false
    end

    if element then
        element.has_focus = true
    end

    focus = element
end

local function load_file(path)
    text:clear()
    counts:clear()

    current_step = 1

    local i = 1
    local color, font
    local section = nil
 
    for line in fs.lines(path) do
        local action, params = line:match("^=%s*(%w+)%s*(.*)")

        if action then
            action = action:upper()
            
            local param = {}
            for word in params:gmatch("[^ ]+") do
                param[#param + 1] = word
            end

            if     action == "FONT" then
                font = s.fonts[params]
            elseif action == "COLOR" then
                local n = tonumber(params)

                if n then
                    color = images.colors.nth[n]
                else
                    color = images.colors.nth[
                        images.colors.by_name[params]
                    ]
                end
            elseif action == "TITLE" then
                text:setTitle(params)
            elseif action == "HEALTH" then
                local n = tonumber(params)
                bar:setMax(n)
            elseif action == "BEGIN" then
                section = {
                    y = text.max_height,
                    alpha = 0,
                }

                text.sections_index[#text.sections_index + 1] = section
            elseif action == "END" then
                section.height = text.max_height - section.y
                section = nil
            elseif action == "IMAGE" then
                local path = param[1]
                local stage = tonumber(param[2])

                model:setImage(path, stage)
            elseif action == "NEXT" then
                model:nextImage(#counts.steps + 1)
            elseif action == "AWAIT" then
                local label_counts = {}

                for i = 1, #param / 2 do
                    local label = param[2 * i - 1]:upper()
                    label_counts[label] = tonumber(param[2 * i])
                end

                counts:addStep(label_counts)
                text.sections[#counts.steps] = section
            else
                error(
                    "Failed to load file '" .. path .. "'. "
                    .. "Invalid action '" .. action .. "' at line "
                    .. i .. "."
                )
            end
        else
            text:addText(line, font, color)

            color = nil
            font = nil
        end

        i = i + 1
    end

    if section then
        section.height = text.max_height - section.y
    end
end


local groups = {
    { 
        "text/salvage/worm.txt",
        "text/salvage/lighter.txt",
        "text/salvage/eye.txt",
        "text/salvage/clock.txt",
        "text/salvage/butterfly.txt",
        "text/salvage/finger.txt",

        seen_n = 0,
        seen = {},
        repeats = 0,
        count = 0,
        max = 4,
    },
    {
        "text/salvage/bird.txt",
        "text/salvage/head.txt",
        "text/salvage/hand.txt",

        seen_n = 0,
        seen = {},
        repeats = 0,
        count = 0,
        max = 2,
    },
    {
        "text/salvage/fish.txt",
        "text/salvage/arm.txt",

        seen_n = 0,
        seen = {},
        repeats = 0,
    },
}

-- 1-4 from group 1 for each group 2
-- 1-2 from group 2 for each group 3
-- (guarantee new item every other choose)

-- min 2 group 3s, 3 group 2s, 5 group 1s
-- total 10

-- max 3 group 3s, 6 group 2s, 24 group 1s to see everything
-- total 33

local function choose(group)
    local n
    if (group.repeats < 1) or (group.seen_n >= #group) then
        n = love.math.random(#group)
    else
        group.repeats = 0

        n = love.math.random(#group - group.seen_n)
        for i = 1, #group do
            if i > n then
                break
            elseif group.seen[i] then
                n = n + 1
            end
        end
    end

    if group.seen[n] then
        group.repeats = group.repeats + 1
    else
        group.seen[n] = true
        group.seen_n = group.seen_n + 1
    end

    return group[n]
end

local function pick_next()
    for _, group in ipairs(groups) do
        if (group.count == nil) then
            load_file(choose(group))
            break
        elseif (group.count > 0) then
            group.count = group.count - 1
            load_file(choose(group))
            break
        else
            group.count = love.math.random(group.max)
        end
    end
end

--[[ INIT ]]--
text.next = counts.index[1]
text.next.prev = text

counts.counts["CONFIRM"].on_click = pick_next
load_file("text/intro.txt")

local is_done = false
local done_timer = 3

--[[ CALLBACKS ]]--
function love.load()
    groups[1].count = groups[1].max
    groups[2].count = groups[2].max
end

function love.resize(width, height)
    scale = math.min(
        width  / s.width,
        height / s.height
    )

    if scale > 1 then
        scale = math.floor(scale)
    end

    ox = math.floor((width  - s.width  * scale) / 2)
    oy = math.floor((height - s.height * scale) / 2)
end

function love.mousemoved(x, y)
    x = (x - ox) / scale
    y = (y - oy) / scale

    local ma = bar:mousemoved(x, y)
    local mb = text:mousemoved(x, y)
    local mc = model:mousemoved(x, y)
    local md = counts:mousemoved(x, y)

    set_focus(ma or mb or mc or md)
end

function love.mousepressed(x, y, button)
    x = (x - ox) / scale
    y = (y - oy) / scale

    if focus then
        if (button == 1) and focus.click then
            focus:click(x, y)
        end
    end
end

function love.mousereleased(x, y, button)
    if (button == 1) then
        text:unclick(x, y)
    end
end

function love.wheelmoved(...)
    if focus and focus.wheelmoved then
        focus:wheelmoved(...)
    end
end

local key_held = {}
function love.keypressed(key)
    key_held[key] = key_held[key] or 0

    -- update focussed element
    if focus then
        if (key == "right") and focus.next then
            set_focus(focus.next)
        elseif (key == "left") and focus.prev then
            set_focus(focus.prev)
        elseif focus == text then
            focus:keypressed(key)
        elseif (key == "up") or (key == "return") or (key == "space") then
            if focus.click then
                focus:click(0, 0)
            end
        elseif (key == "down") then
            if focus.setAnim then
                focus:setAnim("bad")
            end
        end
    else
        set_focus(text)
    end
end

function love.keyreleased(key)
    key_held[key] = nil
end

function love.update(dt)
    is_done = groups[1].seen_n == #groups[1]
        and groups[2].seen_n == #groups[2]
        and groups[3].seen_n == #groups[3]

    if is_done and done_timer > 0 then
        done_timer = done_timer - dt
    end

    -- check held keys
    for key, timer in pairs(key_held) do
        key_held[key] = timer + dt

        while key_held[key] > 0.6 do
            key_held[key] = timer - 0.1
            
            -- repeat key event
            if focus and focus.keypressed then
                focus:keypressed(key)
            end
        end
    end

    -- update elements
    bar:update(dt)
    text:update(dt)
    model:update(dt)
    counts:update(dt)

    -- update counts
    model:setStep(current_step)
    text:setStep(current_step)
    current_step = counts:setStep(current_step)

    if not counts.counts["CONFIRM"].is_disabled then
        bar.is_disabled = true
    else
        bar.is_disabled = false

        if bar.value <= 0 then
            counts.steps = {}
            model.image = images["fail"]
            
            for _, count in ipairs(counts.index) do
                count.max = 0
            end
        end
    end
end

function love.draw()
    g.setCanvas(screen)
    g.clear()

    bar:draw()
    text:draw()
    model:draw()
    counts:draw()

    if is_done and done_timer > 0 then
        print(done_timer)
        g.clear()

        local done = "-- 11 / 11 SALVAGES COMPLETE --"
        local done_width = s.fonts["default"]:getWidth(done)
        local done_height = s.fonts["default"]:getHeight()

        g.setColor(
            images.colors[2][
                images.colors.by_name["black"]
            ]
        )
        g.rectangle(
            "fill",
            math.floor((s.width  - done_width ) / 2),
            math.floor((s.height - done_height) / 2),
            done_width,
            done_height
        )

        g.setColor(
            images.colors[2][
                images.colors.by_name["white"]
            ]
        )
        g.print(
            done,
            math.floor((s.width  - done_width ) / 2),
            math.floor((s.height - done_height) / 2)
        )
    end

    g.setCanvas()
    g.setColor(images.colors["image"])
    g.draw(screen, ox, oy, 0, scale)
end
