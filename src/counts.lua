local g = love.graphics

local s = require("src.styles")
local images = require("src.images")
local bar = require("src.bar")

--[[ MODULE ]]--
local counts = {
    counts = {},
    index = {},

    steps = {},
}

--[[ ANIMATIONS ]]--
local NO_FN = function() return 0 end

local anims = {
    ["ok" ] = {
        ["x"] = NO_FN,
        ["y"] = function(t)
            return -s.border * math.sin(t * math.pi)
        end,

        colors = {
            images.colors["image"],
            s.setAlpha(
                images.colors["image"], 0.25
            ),
        },
        max_t = 0.15,
    },
    ["bad"] = {
        ["x"] = function(t)
            return s.border * (t - 1) * math.sin(t * 6 * math.pi)
        end,
        ["y"] = NO_FN,

        colors = {
            images.colors["image"],
            images.colors[3][
                images.colors.by_name["bad"]
            ],
        },
        max_t = 0.4
    },
    ["ok-bad"] = {
        ["x"] = function(t)
            return s.border * (t - 1) * math.sin(t * 6 * math.pi)
        end,
        ["y"] = NO_FN,

        colors = {
            images.colors["image"],
            s.setAlpha(
                images.colors["image"], 0.25
            ),
        },
        max_t = 0.4
    },
}

--[[ METHODS ]]--
function counts:getBounds(i)
    local outer_x = math.floor(s.xrule * s.width  - 1.5 * s.margin)
        + 2 * s.margin
    local outer_y = math.floor(s.yrule[2] * s.height - 1.5 * s.margin)
        + 2 * s.margin
    local outer_width  = s.width  - outer_x - s.margin
    local outer_height = s.height - outer_y - s.margin
    
    local block_width = (outer_width + s.margin) / #self.index
    local inner_x = outer_x + (i - 1) * block_width

    if counts.index[i].next == nil then
        return inner_x,
            outer_y,
            outer_x + outer_width - inner_x,
            outer_height
    else
        return inner_x,
            outer_y,
            block_width - s.margin,
            outer_height
    end
end

function counts:clear()
    for _, count in ipairs(self.index) do
        if count.type == "count" then
            count.value = 0
        end

        count.max = 0
        count:setAnim("ok")
    end

    counts.steps = {}
end

function counts:addStep(counts, section)
    local step = {
        counts = {},
        section = section,
    }

    for label, count in pairs(self.counts) do
        if count.type == "count" then
            if #self.steps == 0 then
                step.counts[label] = 0
            else
                step.counts[label] = self.steps[#self.steps].counts[label]
            end
        end
    end

    for label, count in pairs(counts) do
        step.counts[label] = step.counts[label] + count
    end

    self.steps[#self.steps + 1] = step

    return step
end

function counts:setStep(i)
    self.counts["CONFIRM"].is_disabled = (i <= #self.steps)

    if self.counts["CONFIRM"].is_disabled then
        local next_step = true

        for label, count in pairs(self.steps[i].counts) do
            self.counts[label].max = count

            next_step = next_step
                and (self.counts[label].value >= count)
        end

        if next_step then
            return i + 1
        end
    end

    return i
end

-- count callbacks
local Count = {}
function counts:addCount(label)
    local count = {
        type = "count",

        label = label or "###",
        value = 0,
        max = 0,

        anim = nil,
        t = 0,

        x = 0,
        y = 0,
        width  = 0,
        height = 0,

        has_focus = false,
        has_mouse = false,
        focus_t = 0,

        prev = self.index[#self.index],
    }

    if #self.index > 0 then
        self.index[#self.index].next = count
    end

    self.counts[label] = setmetatable(count, { __index = Count })
    self.index[#self.index + 1] = count
end

function counts:addButton(label)
    local count = {
        type = "button",

        label = label or "###",
        on_click = NO_FN,

        is_disabled = false,
        disabled_t = 0,

        anim = nil,
        t = 0,

        x = 0,
        y = 0,
        width  = 0,
        height = 0,

        has_focus = false,
        has_mouse = false,
        focus_t = 0,

        prev = self.index[#self.index],
    }

    if #self.index > 0 then
        self.index[#self.index].next = count
    end

    self.counts[label] = setmetatable(count, { __index = Count })
    self.index[#self.index + 1] = count
end

function Count:setAnim(state)
    self.anim = anims[state]
    self.t = 0
end

function Count:mousemoved(x, y)
    if (x >= self.x) and (x < self.x + self.width)
    and (y >= self.y) and (y < self.y + self.height) then
        return self
    end
end

function Count:click(x, y)
    if self.type == "count" then
        if self.value < self.max then
            self.value = self.value + 1
            self:setAnim("ok")
        else
            bar:hurt()
            self:setAnim("bad")
        end
    else
        if self.is_disabled then
            self:setAnim("ok-bad")
        else
            self.on_click(x, y)
            self:setAnim("ok")
        end
    end
end

function Count:update(dt)
    -- update focus
    if self.has_focus or self.has_mouse then
        self.focus_t = math.min(1, self.focus_t + dt / 0.2)
    else
        self.focus_t = math.max(0, self.focus_t - dt / 0.2)
    end

    -- update disabled
    if self.type == "button" then
        if self.is_disabled then
            self.disabled_t = math.min(1, self.disabled_t + dt / 0.2)
        else
            self.disabled_t = math.max(0, self.disabled_t - dt / 0.2)
        end
    end

    -- update animations
    if self.anim then
        if self.t < 1 then
            self.t = self.t + dt / self.anim.max_t
        else
            self.anim = nil
            self.t = 0
        end
    end
end

function Count:draw()
    -- fill background
    local colors = s.blend(
        images.colors[2],
        images.colors[3],
        self.focus_t
    )
    
    local line = colors[
        images.colors.by_name["white"]
    ]

    local fill
    if self.type == "count" then
        fill = colors[
            images.colors.by_name["black"]
        ]
    else
        fill = s.blend(
            colors[
                images.colors.by_name["good"]
            ],
            colors[
                images.colors.by_name["bad"]
            ],
            self.disabled_t
        )
    end

    if self.anim then
        line = s.blend(
            line,
            self.anim.colors[1],
            (1 - self.t)
        )

        fill = s.blend(
            fill,
            self.anim.colors[2],
            (1 - self.t)
        )

        self.x = self.x + self.anim["x"](self.t)
        self.y = self.y + self.anim["y"](self.t)
    end

    g.setColor(fill)
    g.rectangle("fill", self.x, self.y, self.width, self.height)

    -- draw counter
    g.setColor(images.colors["image"])
    if self.type == "count" then
        g.setShader(images.shader)
        -- warn! incredibly jank blending
        images.shader:send(
            "colors",
            line, colors[2], colors[3], colors[4],
            fill, colors[6], colors[7], colors[8]
        )

        -- from top
        g.draw(
            images["ui/count_up"],
            self.x + (self.width - images["ui/count_up"]:getWidth()) / 2,
            self.y + s.border + s.margin
        )

        -- from bottom
        local marker_height = images["ui/marker"]:getHeight()
        g.draw(
            images["ui/marker"],
            self.x + (self.width  - images["ui/marker"]:getWidth() ) / 2,
            self.y + self.height - s.border - marker_height
        )

        g.setShader()

        local digit_height = s.fonts["digit"]:getHeight()
        g.setColor(line)

        g.rectangle(
            "fill",
            self.x + s.border,
            self.y + self.height - s.border - marker_height
                - digit_height,
            self.width - s.border * 2,
            digit_height
        )

        g.setFont(s.fonts["digit"])
        g.setColor(fill)

        g.print(
            self.value,
            self.x + (self.width
                - s.fonts["digit"]:getWidth(tostring(self.value))) / 2,
            self.y + self.height - s.border
                - marker_height - digit_height
        )

        local label_height = s.fonts["default"]:getHeight()
        g.setFont(s.fonts["default"])
        g.setColor(line)

        g.print(
            self.label,
            self.x + math.floor((self.width - label_height) / 2),
            self.y + self.height - 2 * s.border - s.margin
                - marker_height - digit_height,
            -math.pi / 2
        )
    else
        g.setShader(images.shader)
        -- warn! incredibly jank blending
        images.shader:send(
            "colors",
            line, colors[2], colors[3], colors[4],
            fill, colors[6], colors[7], colors[8]
        )

        local icon
        if self.is_disabled then
            icon = images["ui/cancel"]
        else
            icon = images["ui/accept"]
        end
        
        g.draw(
            icon,
            self.x + (self.width  - icon:getWidth ()) / 2,
            self.y + (self.height - icon:getHeight()) / 2
        )

        g.setShader()
    end
end

--[[ CALLBACKS ]]--
function counts:mousemoved(x, y)
    for _, count in ipairs(self.index) do
        local result = count:mousemoved(x, y)

        if result then
            return result
        end
    end
end

function counts:update(dt)
    for i, count in ipairs(self.index) do
        count.x, count.y, count.width, count.height = self:getBounds(i)
        count:update(dt)
    end
end

function counts:draw()
    for i, count in ipairs(self.index) do
        count:draw()
    end
end

--[[ EXPORT ]]--
counts:addCount("ALLOY"  )
counts:addCount("POLYMER")
counts:addCount("DATA" )
counts:addCount("FUEL"   )

counts:addButton("CONFIRM")

return counts
