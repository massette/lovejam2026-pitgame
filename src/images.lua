local bit = require("bit")
local s = require("src.styles")

local g = love.graphics
local im = love.image

local function to_index(r, g, b)
    if type(r) == "table" then
        r, g, b = r[1], r[2], r[3]
    end

    local r = math.floor(r * 255 + 0.5)
    local g = math.floor(g * 255 + 0.5)
    local b = math.floor(b * 255 + 0.5)

    -- return bit.bor(
    --     r,
    --     bit.lshift(g, 8),
    --     bit.lshift(b, 16)
    -- )

    local result = 0

    for i = 0, 7 do
        local mask = bit.lshift(1, i)

        result = bit.bor(
            result,
            bit.lshift(
                bit.band(r, mask),
                2 * i
            ),
            bit.lshift(
                bit.band(g, mask),
                2 * i + 1
            ),
            bit.lshift(
                bit.band(b, mask),
                2 * i + 2
            )
        )
    end

    return result
end

function load_palette(path)
    local colors = {}
    local invert = {}

    local raw = im.newImageData(path)
    
    for y = 0, raw:getHeight() - 1 do
        for x = 0, raw:getWidth() - 1 do
            local r, g, b, a = raw:getPixel(x, y)
            local color = { r, g, b, 1.00 }
            local n = to_index(color)

            if a > 0 then
                local i = #colors + 1
                colors[i] = color
                invert[#invert + 1] = i
            end
        end
    end

    return {
        colors = colors,
        invert = invert,
        map = function(x, y, r, g, b, a)
            local n = to_index(r, g, b)
            local i

            if invert[n] then
                i = invert[n]
            else
                local min = nil

                for j, color in ipairs(colors) do
                    local dist = math.abs(n - to_index(color))

                    if (min == nil) or (dist < min) then
                        i = j
                        min = dist
                    end
                end
            end

            local b = math.ceil((i - 1) * 255 / (#colors - 1)) / 255
            return b, b, b, a
        end
    }
end

local p0 = load_palette("images/colors/p0.png")
local p1 = load_palette("images/colors/p1.png")
local p2 = load_palette("images/colors/p2.png")

local images = {
    load   = load_image,
    shader = g.newShader("shaders/colors.glsl"),

    colors = {
        p0.colors,
        p1.colors,
        p2.colors,
    },
}

images.colors["image"] = { 1.00, 1.00, 1.00, 1.00 }

images.colors.nth = {}
for i = 1, #images.colors[1] do
    images.colors.nth[i] = {
        (i - 1) / (#images.colors[1] - 1),
        (i - 1) / (#images.colors[1] - 1),
        (i - 1) / (#images.colors[1] - 1),
    }
end

images.colors.by_name = {
    ["black"    ] = 1,
    ["white"    ] = 5,
    ["good"     ] = 7,
    ["bad"      ] = 8,
    ["highlight"] = 4,
}

images.shader:send("colors", unpack(images.colors[1]))
images.shader:send("n_colors", #images.colors[1])

function images:load_image(path)
    local raw = im.newImageData("images/" .. path .. ".png")

    -- posterize image
    raw:mapPixel(p0.map)
    images[path] = g.newImage(raw)

    return images[path]
end

images["fail"] = g.newText(
    s.fonts["default"],
    {
        images.colors.nth[
            images.colors.by_name["black"]
        ],
        "-- SALVAGE DESTROYED --",
    }
)

images["done"] = g.newText(
    s.fonts["default"],
    {
        images.colors.nth[
            images.colors.by_name["black"]
        ],
        "-- SALVAGE COMPLETE --",
    }
)

images["ui/marker"] = g.newText(
    s.fonts["default"],
    {
        images.colors.nth[
            images.colors.by_name["white"]
        ],
        "#",
    }
)

return setmetatable(
    images,
    { __index = images.load_image }
)
