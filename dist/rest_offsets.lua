function plugindef()
    finaleplugin.RequireSelection = true
    finaleplugin.Copyright = "CC0 https://creativecommons.org/publicdomain/zero/1.0/"
    finaleplugin.AuthorURL = "http://carlvine.com/lua/"
    finaleplugin.Version = "v1.3"
    finaleplugin.Date = "2022/06/19"
    finaleplugin.Notes = [[
    Several situations including cross-staff notation (rests should be centred between the staves) 
    require adjusting the vertical position (offset) of rests. 
    This script duplicates the action of Finale's inbuilt "Move rests..." plug-in but needs no mouse activity. 
    It is also an easy way to reset rest offsets to zero in every layer, the default setting. 
    (Offest zero centres on the middle staff line.)
]]
   return "Rest offsets", "Rest offsets", "Rest vertical offsets"
end

-- RetainLuaState will return global variables:
-- rest_offset and layer_number

function show_error(error_type, actual_value)
    local errors = {
        bad_offset = "Rest offset must be an integer\nbetween, say, 60 and -60\n(not ",
        bad_layer_number = "Layer number must be an\ninteger between zero and 4\n(not ",
    }
    finenv.UI():AlertNeutral("script: " .. plugindef(), errors[error_type] .. actual_value .. ")")
end

function get_user_choices()
    local horizontal = 110
    local mac_offset = finenv.UI():IsOnMac() and 3 or 0 -- extra y-offset for Mac text box
    local answer = {}
    local dialog = finale.FCCustomWindow()
    local str = finale.FCString()
    str.LuaString = plugindef()
    dialog:SetTitle(str)

    local texts = { -- text, default value, vertical_position
        { "Vertical offset:", rest_offset or 0, 15 },
        { "Layer 1-4 (0 = all):", layer_number or 0, 50  },
    }
    for i, v in ipairs(texts) do -- create labels and edit boxes
        str.LuaString = v[1]
        local static = dialog:CreateStatic(0, v[3])
        static:SetText(str)
        static:SetWidth(horizontal)
        answer[i] = dialog:CreateEdit(horizontal, v[3] - mac_offset)
        answer[i]:SetInteger(v[2])
        answer[i]:SetWidth(50)
    end

    texts = { -- offset number / horizontal offset / description /  vertical position
        { "4", 5, "= top staff line", 0},
        { "0", 5, "= middle staff line", 15 },
        { "-4", 0, "= bottom staff line", 30 },
    }
    for i, v in ipairs(texts) do -- static text information lines
        str.LuaString = v[1]
        dialog:CreateStatic(horizontal + 60 + v[2], v[4]):SetText(str)
        local static = dialog:CreateStatic(horizontal + 75, v[4])
        str.LuaString = v[3]
        static:SetText(str)
        static:SetWidth(horizontal)
    end

    dialog:CreateOkButton()
    dialog:CreateCancelButton()
    return (dialog:ExecuteModal(nil) == finale.EXECMODAL_OK), answer[1]:GetInteger(), answer[2]:GetInteger()
end

function change_rest_offset()
    local base_offset = 6 -- default rest ZERO vertical position
    local is_ok = false -- (rest_offset and layer_number are global vars)
    is_ok, rest_offset, layer_number = get_user_choices()
    if not is_ok then
        return
    end -- user cancelled

    if rest_offset < -60 or rest_offset > 60 then
        show_error("bad_offset", rest_offset)
        return
    end
    if layer_number < 0 or layer_number > 4 then
        show_error("bad_layer_number", layer_number)
        return
    end
    if finenv.RetainLuaState ~= nil then
        finenv.RetainLuaState = true
    end

    for entry in eachentrysaved(finenv.Region(), layer_number) do
        if entry:IsRest() then
            entry:SetRestDisplacement(rest_offset + base_offset)
         end
	end
end

change_rest_offset()
