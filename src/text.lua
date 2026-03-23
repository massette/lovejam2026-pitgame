local g = love.graphics

local s = require("src.styles")
local images = require("src.images")

--[[ MODULE ]]--
local text = {
    title = g.newTextBatch(s.fonts["head"], "Intro.txt"),
    blocks = {},
    max_height = 0,

    sections = {},
    sections_index = {},
    highlight_section = 0,

    scroll = 0,
    delta = 0,

    has_focus = false,
    has_mouse = false,
    focus_t = 0
}

--[[ METHODS ]]--
function text:clear()
    self.blocks = {}
    self.max_height = 0

    self.sections = {}
    self.sections_index = {}
    self.highlight_section = 0

    self.scroll_mode = nil
    self.scroll = 0
    self.delta = 0
end

function text:setTitle(title)
    self.title = g.newTextBatch(s.fonts["head"], title)
end

function text:addText(text, font, color)
    font = font or s.fonts["default"]
    color = color or images.colors.nth[
        images.colors.by_name["black"]
    ]

    local width = select(3, self:inner())

    -- split text into lines
    local lines = select(
        2, font:getWrap(text, width - s.scroll - s.margin)
    )
    local height = font:getHeight() * math.max(#lines, 1)
    text = table.concat(lines, "\n") or text

    -- start new block on font change
    if (#self.blocks == 0)
    or (font ~= self.blocks[#self.blocks]:getFont()) then
        self.blocks[#self.blocks + 1] = g.newTextBatch(font)
    end

    -- append text to last block
    self.blocks[#self.blocks]:add({ color, text }, 0, self.max_height)
    self.max_height = self.max_height + height
end

function text:setStep(i)
    self.highlight_section = i
end

function text:outer()
    local x = s.margin
    local y = math.floor(s.yrule[1] * s.height - 1.5 * s.margin)
        + 2 * s.margin
    local width  = math.floor(s.xrule * s.width - 1.5 * s.margin)
    local height = s.height - y - s.margin

    return x, y, width, height
end

function text:inner()
    local x, y, width, height = self:outer()

    return x + s.margin + s.border,
        y + s.margin + s.border + self.title:getHeight(),
        width - 2 * s.border - 3 * s.margin - s.scroll,
        height - 2 * (s.border + s.margin) - self.title:getHeight()
end

--[[ CALLBACKS ]]--
local ACCEL = 120
local DECEL = 5
function text:wheelmoved(sx, sy)
    self.delta = self.delta - sy * ACCEL / self.max_height
end

local old_x, old_y
function text:click(mx, my)
    local x, y, width, height = self:inner()

    if mx > x + width then
        self.scroll_mode = "set"
    end
end

function text:unclick(mx, my)
    self.scroll_mode = nil
end

function text:mousemoved(mx, my)
    local ox, oy, owidth, oheight = self:outer()
    local ix, iy, iwidth, iheight = self:inner()

    if self.scroll_mode == "set" then
        local scroll_height = math.ceil(
            iheight * iheight / self.max_height
        )

        self.scroll = math.min(
            1, math.max(
                0, (my - scroll_height / 2 - iy) / (iheight - scroll_height)
            )
        )
    end

    if (mx >= ox) and (mx < ox + owidth)
    and (my >= oy) and (my < oy + oheight) then
        return self
    end
end

function text:keypressed(k)
    if k == "up" then
        self:wheelmoved(0, 3)
    elseif k == "down" then
        self:wheelmoved(0, -3)
    end
end

function text:update(dt)
    -- update focus
    if self.has_focus or self.has_mouse then
        self.focus_t = math.min(1, self.focus_t + dt / 0.2)
    else
        self.focus_t = math.max(0, self.focus_t - dt / 0.2)
    end

    -- update highlight
    for i, section in ipairs(self.sections_index) do
        if section == self.sections[self.highlight_section] then
            section.alpha = math.min(
                1, section.alpha + dt / 0.2
            )
        else
            section.alpha = math.max(
                0, section.alpha - dt / 0.2
            )
        end
    end

    -- update scroll
    local height = select(4, self:inner())

    self.scroll = math.max(
        0, math.min(
            1,
            self.max_height / (self.max_height - height),
            self.scroll + self.delta * dt
        )
    )

    -- apply acceleration
    if (self.scroll == 0) or (self.scroll == 1) then
        self.delta = 0
    elseif self.delta > 0 then
        self.delta = math.max(0, self.delta - DECEL * dt)
    elseif self.delta < 0 then
        self.delta = math.min(0, self.delta + DECEL * dt)
    end
end

function text:draw()
    -- calculate rect
    local ox, oy, owidth, oheight = self:outer()
    local ix, iy, iwidth, iheight = self:inner()

    -- fill background
    local colors = s.blend(
        images.colors[2],
        images.colors[3],
        self.focus_t
    )

    g.setColor(colors[
        images.colors.by_name["white"]
    ])
    g.rectangle("fill", ox, oy, owidth, oheight)

    -- draw debug rect
    -- g.setColor(1, 0, 0, 1)
    -- g.rectangle("fill", inner_x, inner_y, inner_width, inner_height)

    g.push()
    g.translate(
        0,
        -math.ceil(self.scroll * (self.max_height - iheight))
    )
    g.setScissor(ox, oy, owidth, oheight)

    -- draw highlight
    for _, section in ipairs(self.sections_index) do
        g.setColor(
            s.setAlpha(
                colors[
                    images.colors.by_name["highlight"]
                ],
                section.alpha
            )
        )

        g.rectangle(
            "fill",
            ox + s.border,
            iy + section.y - s.margin,
            owidth - s.border * 2,
            section.height + 2 * s.margin
        )
    end
    
    -- draw text
    g.setColor(images.colors["image"])
    g.setShader(images.shader)
    images.shader:send(
        "colors",
        unpack(colors)
    )

    for _, block in ipairs(self.blocks) do
        g.draw(block, ix, iy)
    end

    g.setShader()
    g.setScissor()
    g.pop()

    -- draw scroll bar
    local scroll_height = math.ceil(
        iheight * iheight / self.max_height
    )

    if self.max_height > iheight then
        g.setColor(colors[
            images.colors.by_name["black"]
        ])
        g.rectangle(
            "fill",
            ix + iwidth + s.margin,
            iy + math.floor(
                self.scroll * (iheight - scroll_height)
            ),
            s.scroll,
            scroll_height
        )
    end

    -- draw header
    g.setColor(colors[
        images.colors.by_name["black"]
    ])
    g.rectangle(
        "fill",
        ox + s.border,
        oy + s.border,
        owidth - 2 * s.border,
        self.title:getHeight()
    )

    g.setColor(colors[
        images.colors.by_name["white"]
    ])
    g.draw(self.title, ix, oy + s.border)

    -- draw outer border
    g.setColor(colors[
        images.colors.by_name["black"]
    ])
    g.rectangle(
        "line",
        ox + s.border / 2,
        oy + s.border / 2,
        owidth  - s.border,
        oheight - s.border
    )

end

return text
