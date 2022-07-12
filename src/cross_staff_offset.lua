function plugindef()
    finaleplugin.RequireSelection = true
    finaleplugin.HandlesUndo = true
    finaleplugin.Copyright = "CC0 https://creativecommons.org/publicdomain/zero/1.0/"
    finaleplugin.Author = "Carl Vine"
    finaleplugin.AuthorURL = "http://carlvine.com/lua/"
    finaleplugin.Version = "v1.29"
    finaleplugin.Date = "2022/07/11"
	finaleplugin.MinJWLuaVersion = 0.62
    finaleplugin.AdditionalMenuOptions = [[  CrossStaff Offset No Dialog  ]]
    finaleplugin.AdditionalUndoText = [[     CrossStaff Offset No Dialog  ]]
    finaleplugin.AdditionalPrefixes = [[     no_user_dialog = true  ]]
    finaleplugin.AdditionalDescriptions = [[ Offset horizontal position of cross-staff note entries - NO DIALOG ]]
    finaleplugin.Notes = [[
        When creating cross-staff notes using the option-downarrow shortcut, the stems of 
        'crossed' notes are reversed (on the wrong side of the notehead) and appear too far 
        to the right (if shifting downwards) by the width of one notehead, typically 24EVPU. 
        This script lets you set a horizontal offset for all cross-staff notes in the 
        selected region, with a different offset for non-crossed notes.  
        For crossing to the staff below use (-24,0) or (-12,12).  
        For crossing to the staff above use (24,0) or (12,-12).  
        Also specify which layer number to act upon (1-4) or "all layers" (0). 
        (This also offers a simple way to reset the horizontal offset of all notes in the selection to zero).
    
        This script adds an extra `NO DIALOG` menu item to rapidly duplicate the last action
        without using a confirmation dialog.
]]
   return "CrossStaff Offset…", "CrossStaff Offset", "Offset horizontal position of cross-staff note entries"
end

no_user_dialog = no_user_dialog or false

-- other global variables for modeless operation
global_dialog = nil
global_dialog_options = { -- words, key value in config, edit control holder
    { "Cross-staff offset:", "cross_staff_offset", nil },
    { "Non-crossed offset:", "non_cross_offset", nil },
    { "Layer 1-4 (0 = all):", "layer_number", nil }
}
config = {
    cross_staff_offset  = 0,
    non_cross_offset = 0,
    layer_number = 0,
    window_pos_x = 700,
    window_pos_y = 200
}
local configuration = require("library.configuration")

function is_out_of_range(horiz_offset)
    return ( math.abs(horiz_offset) > 999 ) -- some unreasonable EVPU offset
end

function no_submission_errors()
    local error = ""
    if config.layer_number < 0 or config.layer_number > 4  then 
        error = "The layer number must\nbe between 0 and 4\n(not " .. config.layer_number .. ")"
    elseif is_out_of_range(config.cross_staff_offset) or is_out_of_range(config.non_cross_offset) then
        error = "Choose realistic offset\nvalues (say from -999 to 999)\n(not "
            .. config.cross_staff_offset .. " / " .. config.non_cross_offset .. ")"
    end
    if error ~= "" then  -- error dialog and exit
        finenv.UI():AlertNeutral("script: " .. plugindef(), error)
        return false
    end
    return true
end

function create_user_dialog() -- attempting MODELESS operation
    local current_vert = 10
    local vertical_step = 25
    local mac_offset = finenv.UI():IsOnMac() and 3 or 0 -- extra y-offset for Mac text box
    local edit_box_horiz = 120

    local dialog = finale.FCCustomLuaWindow()
    local str = finale.FCString()
    str.LuaString = plugindef()
    dialog:SetTitle(str)

    function make_static(msg, horiz, vert, width, color)
        local static = dialog:CreateStatic(horiz, vert)
        str.LuaString = msg
        static:SetText(str)
        static:SetWidth(width)
        if color == "red" then
            static:SetTextColor(204, 51, 0)
        end
    end

    for i, v in ipairs(global_dialog_options) do
        make_static(v[1], 0, current_vert, edit_box_horiz, "")
        v[3] = dialog:CreateEdit(edit_box_horiz, current_vert - mac_offset)
        v[3]:SetInteger(config[v[2]]) -- display the saved config value
        v[3]:SetWidth(75)
        if i < 3 then
            make_static("EVPUs", edit_box_horiz + 80, current_vert, 75, "")
        end
        current_vert = current_vert + vertical_step
    end
    make_static("cross to staff below = [ -24, 0 ] or [ -12, 12 ]", 0, current_vert + 8, 290, "red")
    make_static("cross to staff above = [ 24, 0 ] or [ 12, -12 ]", 0, current_vert + vertical_step, 290, "red")
    dialog:CreateOkButton()
    dialog:CreateCancelButton()
    return dialog
end

function change_the_offsets() -- change entry offsets in the chosen layer (0 = all layers)
    finenv.StartNewUndoBlock("CrossStaff Offset", false)
    for entry in eachentrysaved(finenv.Region(), config.layer_number) do
        if entry:IsNote() then
            entry.ManualPosition = entry.CrossStaff and config.cross_staff_offset or config.non_cross_offset
        end
    end
    if finenv.EndUndoBlock then
        finenv.EndUndoBlock(true)
        finenv.Region():Redraw()
    else
        finenv.StartNewUndoBlock("CrossStaff Offset", true)
    end
end

function on_ok()
    for i, v in ipairs(global_dialog_options) do -- save the 3 integer values
        config[v[2]] = v[3]:GetInteger()
    end
    if no_submission_errors() then
        change_the_offsets()
    end
end

function on_close()
    global_dialog:StorePosition()
    config.window_pos_x = global_dialog.StoredX
    config.window_pos_y = global_dialog.StoredY
    configuration.save_user_settings("cross_staff_offset", config)
end

function cross_staff_offset()
    configuration.get_user_settings("cross_staff_offset", config)
    if no_user_dialog then
        change_the_offsets()
        return
    end
    global_dialog = create_user_dialog()
    if config.window_pos_x ~= nil and config.window_pos_y ~= nil then
        global_dialog:StorePosition()
        global_dialog:SetRestorePositionOnlyData(config.window_pos_x, config.window_pos_y)
        global_dialog:RestorePosition()
    end
    global_dialog:RegisterHandleOkButtonPressed(on_ok)
    if global_dialog.RegisterCloseWindow then
        global_dialog:RegisterCloseWindow(on_close)
    end
    finenv.RegisterModelessDialog(global_dialog)
    global_dialog:ShowModeless()
end

cross_staff_offset()
