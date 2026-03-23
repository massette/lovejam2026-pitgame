local s = require("src.styles")
local images = require("src.images")

local g = love.graphics

--[[ TRANSITIONS ]]--
local function ZERO(t) return 0 end
local function ONE (t) return 1 end

local function y_out(t)
    return -20 * (1 - math.cos(t * math.pi / 2))
end

local function y_in(t)
    return -20 * (1 - math.sin(t * math.pi / 2))
end

local function alpha_in(t)
    return t
end

local function alpha_out(t)
    return (1 - t)
end

--[[ IMAGES ]]--
function load_model(path, n)
    local stages = {}
    local width, height = images[path .. "-00"]:getDimensions()

    for i = 1, n + 1 do
        local stage = {
            layers = {
                {
                    image = nil,
                    anims = {
                        ["y"    ] = ZERO,
                        ["alpha"] = ONE,
                    },
                }
            },
            t     = 0.00,
            max_t = 0.30,
        }

        -- draw main layer
        if i <= n then
            stage.layers[1].image = g.newCanvas(width, height)
            g.setCanvas(stage.layers[1].image)
            
            -- composite image
            for j = 0, n - i do
                local jj = tostring(j)
                jj = "-" .. ("0"):rep(2 - #jj) .. jj

                g.draw(images[path .. jj])
            end

            g.setCanvas()
        else
            -- last frame; draw end screen
            stage.layers[1].image = images["done"]
            stage.layers[1].anims["alpha"] = alpha_in
        end

        -- draw transition layer
        if i == 1 then
            stage.layers[1].anims["y"] = y_in
            stage.layers[1].anims["alpha"] = alpha_in
        else
            local ii = tostring(n - i + 1)
            ii = "-" .. ("0"):rep(2 - #ii) .. ii

            stage.layers[2] = {
                image = images[path .. ii],
                anims = {
                    ["y"    ] = y_out,
                    ["alpha"] = alpha_out,
                },
            }
        end

        stages[i] = stage
    end

    return stages
end

--[[ LOAD MODELS ]]--
local models = {
    ["salvage/worm"     ] = 1,
    ["salvage/lighter"  ] = 3,
    ["salvage/eye"      ] = 1,
    ["salvage/finger"   ] = 3,
    ["salvage/clock"    ] = 4,
    ["salvage/butterfly"] = 3,
    ["salvage/head"     ] = 5,
    ["salvage/bird"     ] = 4,
    ["salvage/hand"     ] = 6,
    ["salvage/fish"     ] = 5,
    ["salvage/arm"      ] = 9,
}

for key, n in pairs(models) do
    models[key] = load_model(key, n)
end

--[[ MODULE ]]--
local model = {
    image = images["salvage/intro"],
    steps = {},
    stage = 1,
    t = 0,

    has_focus = false,
    focus_t = 0,
}

function model:setImage(path)
    -- ("IMG (\"%s\" , %d) @ %d"):format(path, stage, step)

    self.image = models[path]
    self.steps = {}
    self.stage = 1
    self.t = 0
end

function model:nextImage(step)
    self.steps[#self.steps + 1] = step
end

function model:setStep(i)
    if self.steps[self.stage] then
        if i >= self.steps[self.stage] then
            self.stage = self.stage + 1
            self.t = 0
        end
    end
end

function model:getBounds()
    local x = math.floor(s.xrule * s.width - 1.5 * s.margin) + 2 * s.margin
    local y = s.margin
    local width  = s.width  - x - s.margin
    local height = math.floor(s.yrule[2] * s.height - 1.5 * s.margin)

    return x, y, width, height   
end

--[[ CALLBACKS ]]--
function model:mousemoved(mx, my)
    local x, y, width, height = self:getBounds()

    self.has_focus = (mx >= x) and (mx < x + width)
        and (my >= y) and (my < y + height)

    return nil
end

function model:update(dt)
    -- update focus
    if self.has_focus then
        self.focus_t = math.min(1, self.focus_t + dt / 0.2)
    else
        self.focus_t = math.max(0, self.focus_t - dt / 0.2)
    end

    if type(self.image) == "table" then
        self.t = math.min(
            1, self.t + dt / self.image[self.stage].max_t
        )
    end
end

function model:draw()
    local x, y, width, height = self:getBounds()

    -- fill background
    local colors = s.blend(
        images.colors[2],
        images.colors[3],
        self.focus_t
    )

    g.setColor(colors[
        images.colors.by_name["white"]
    ])
    g.rectangle("fill", x, y, width, height)

    -- draw outer border
    g.setColor(colors[
        images.colors.by_name["black"]
    ])
    g.rectangle(
        "line",
        x + s.border / 2,
        y + s.border / 2,
        width  - s.border,
        height - s.border
    )

    -- draw model
    if type(self.image) == "table" then
        for _, layer in ipairs(self.image[self.stage].layers) do
            if type(layer.image) == "string" then
                g.setFont(s.fonts["default"])
                g.setColor(colors[
                    images.colors.by_name["black"]
                ])
                g.print(
                    layer.image,
                    x + (width 
                        - s.fonts["default"]:getWidth(layer.image)) / 2,
                    y + (height - s.fonts["default"]:getHeight()) / 2
                )
            else
                g.setColor(
                    s.setAlpha(
                        images.colors["image"],
                        layer.anims["alpha"](self.t)
                    )
                )

                g.setShader(images.shader)
                images.shader:send(
                    "colors",
                    unpack(colors)
                )

                g.draw(
                    layer.image,
                    x + (width  - layer.image:getWidth() ) / 2,
                    y + (height - layer.image:getHeight()) / 2
                        + layer.anims["y"](self.t)
                )

                g.setShader()
            end
        end
    else
        g.setColor(images.colors["image"])
        g.setShader(images.shader)
        images.shader:send(
            "colors",
            unpack(colors)
        )

        g.draw(
            self.image,
            x + (width  - self.image:getWidth() ) / 2,
            y + (height - self.image:getHeight()) / 2
        )

        g.setShader()
    end
end

--EXPORT--
return model
