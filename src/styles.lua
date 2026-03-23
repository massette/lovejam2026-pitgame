local g = love.graphics

local fonts = {
    ["default"] = g.newFont(
        "fonts/cascadia-regular.ttf",
        15, "mono"
    ),
    ["bold"   ] = g.newFont(
        "fonts/cascadia-bold.ttf"   ,
        15, "mono"
    ),
    ["digit"  ] = g.newFont(
        "fonts/markazi-regular.ttf" ,
        26, "mono"
    ),
    ["head"   ] = g.newFont(
        "fonts/markazi-regular.ttf" ,
        26, "mono"
    ),
}

local function blend(c1, c2, r)
    if type(c1) == "number" then
        return c1 + (c2 - c1) * r
    elseif type(c1[1]) == "number" then
        return {
            blend(c1[1] or 0.00, c2[1] or 0.00, r * (c2[4] or 1.00)),
            blend(c1[2] or 0.00, c2[2] or 0.00, r * (c2[4] or 1.00)),
            blend(c1[3] or 0.00, c2[3] or 0.00, r * (c2[4] or 1.00)),
            c1[4]
        }
    else
        local result = {}

        for k, _ in pairs(c1) do
            if c2[k] then
                result[k] = blend(c1[k], c2[k], r)
            end
        end

        return result
    end

    return result
end

local function set_alpha(color, a)
    return { color[1], color[2], color[3], a }
end

return {
    width  = g.getWidth(),
    height = g.getHeight(),

    fonts  = fonts,
    blend  = blend,
    setAlpha = set_alpha,

    xrule = 0.60,
    yrule = { 0.15, 0.60 },

    scroll = 3,
    margin = 4,
    border = 3,
}
