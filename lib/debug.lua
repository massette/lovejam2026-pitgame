function indent(str)
    -- (private) indent every line in a string.
    
    local TABFILL = "    "
    return TABFILL .. str:gsub("\r?\n", "%0" .. TABFILL)
end

local dbg = {}

function dbg.repr(value, depth)
    -- represent value as debug string.
    
    depth = (depth or math.huge) - 1
    local value_t = type(value)

    if     value_t == "table" then
        if next(value) == nil then
            return "{}"
        elseif depth < 0 then
            return "{ ... }"
        else
            local lines = {}

            for k, v in pairs(value) do
                lines[#lines + 1] = string.format(
                    "[%s] = %s,",
                    dbg.repr(k),
                    dbg.repr(v)
                )
            end

            local inner = table.concat(lines, "\n")
            return "{\n" .. indent(inner) .. "\n}"
        end
    elseif value_t == "number" then
        return value
    elseif value_t == "string" then
        return "\"" .. value .. "\""
    elseif value_t == "nil" then
        return "!NIL!"
    else
        return "(" .. tostring(value) .. ")"
    end

end

function dbg.print(value)
    -- print value as debug string. shorthand for print(db.repr(value)).
    
    print(dbg.repr(value))
end

function dbg.lpad(str, n, template)
    str = (template or "%s"):format(str)
    return string.rep(" ", n - #str) .. str
end

function dbg.bar(r, n)
    result = ""
    n = n or 10

    for i = 1, n do
        if r >= (i / n) then
            result = result .. "█"
        else
            result = result .. "_"
        end
    end

    return result
end

-- export debug functions
return dbg
