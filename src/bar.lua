local g = love.graphics

local s = require("src.styles")
local images = require("src.images")

local bar = {
    value = 0,
    max = 0,
    is_disabled = false,

    t = 0,

    fall_t = 0,
    fall_max = 0.4,
    fall_value = 0,

    has_focus = false,
    has_mouse = false,
    focus_t = 0,
}

local anim = {
    ["x"] = function(t)
        return s.border * (t - 1) * math.sin(t * 6 * math.pi)
    end,

    colors = {
        images.colors[3][
            images.colors.by_name["bad"]
        ],
        images.colors["image"],
    },
    max_t = 0.4,
}

function bar:outer()
    local x = s.margin
    local y = s.margin
    local width  = math.floor(s.xrule * s.width - 1.5 * s.margin)
    local height = math.floor(s.yrule[1] * s.height - 1.5 * s.margin)

    return x, y, width, height
end

function bar:setMax(n)
    self.max = n
    self.value = n
end

function bar:hurt()
    if not self.is_disabled then
        self.t = 1

        if self.value > 0 then
            self.value = self.value - 1

            self.fall_value = self.fall_value + 1
            self.fall_t = 1 - (1 - self.fall_t)
                    * (self.fall_value - 1) / self.fall_value
        end
    end
end

function bar:mousemoved(mx, my)
    local x, y, width, height = self:outer()

    if  (mx >= x) and (mx < x + width )
    and (my >= y) and (my < y + height) then
        return self
    end
end

function bar:update(dt)
    -- update focus
    if self.has_focus or self.has_mouse then
        self.focus_t = math.min(1, self.focus_t + dt / 0.2)
    else
        self.focus_t = math.max(0, self.focus_t - dt / 0.2)
    end

    -- update fall
    if self.fall_t > 0 then
        self.fall_t = self.fall_t - dt / self.fall_max 
    elseif self.fall_value > 0 then
        self.fall_value = 0
    end
    
    -- update animations
    if self.t > 0 then
        self.t = self.t - dt / anim.max_t
    end
end

function bar:draw()
    local x, y, width, height = self:outer()

    local colors = s.blend(
        images.colors[2],
        images.colors[3],
        self.focus_t
    )

    -- animate
    local value = self.value + self.fall_value * self.fall_t
    local prev_value = self.value + self.fall_value

    local line = s.blend(
        colors[
            images.colors.by_name["black"]
        ],
        anim.colors[1],
        self.t
    )

    local prev_fill = s.blend(
        colors[
            images.colors.by_name["white"]
        ],
        colors[
            images.colors.by_name["bad"]
        ],
        self.fall_t
    )

    local fill = s.blend(
        colors[
            images.colors.by_name["white"]
        ],
        anim.colors[2],
        self.t
    )

    x = x + anim["x"](1 - self.t)

    -- fill background
    g.setColor(fill)
    g.rectangle(
        "fill",
        x,
        y,
        width ,
        height
    )

    -- fill bar
    if self.max > 0 then
        g.setColor(prev_fill)
        g.rectangle(
            "fill",
            x + s.border + s.margin,
            y + s.border + s.margin,
            math.floor((width  - 2 * (s.border + s.margin))
                * (prev_value / self.max)),
            height - 2 * (s.border + s.margin)
        )

        g.setColor(line)
        g.rectangle(
            "fill",
            x + s.border + s.margin,
            y + s.border + s.margin,
            math.floor((width  - 2 * (s.border + s.margin))
                * (value / self.max)),
            height - 2 * (s.border + s.margin)
        )

        -- draw dividers
        g.setColor(fill)
        local nw = math.floor(
            (width - 2 * (s.border + s.margin)) / self.max
        )
        local overflow = width - 2 * (s.border + s.margin)
            - (self.max * nw)

        for i = 1, prev_value do
            local nx = x + s.border + s.margin + i * nw
                + overflow / 2

            g.rectangle(
                "fill",
                nx - math.floor(s.margin / 2),
                y + s.border + s.margin,
                s.margin,
                height - 2 * (s.border + s.margin)
            )
        end
    end

    -- draw outer border
    g.setColor(line)
    g.rectangle(
        "line",
        x + s.border / 2,
        y + s.border / 2,
        width - s.border,
        height - s.border
    )
end

return bar
