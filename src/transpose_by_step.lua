function plugindef()
    finaleplugin.RequireSelection = false
    finaleplugin.HandlesUndo = true     -- not recognized by JW Lua or RGP Lua v0.55
    finaleplugin.Author = "Robert Patterson"
    finaleplugin.Copyright = "CC0 https://creativecommons.org/publicdomain/zero/1.0/"
    finaleplugin.Version = "1.0"
    finaleplugin.Date = "March 25, 2020"
    finaleplugin.CategoryTags = "Note"
    return "Transpose By Steps...", "Transpose By Steps",
           "Transpose by the number of steps given, simplifying spelling as needed."
end

--[[
This function allows you to specify a number of chromatic steps by which to transpose and the script
simplifies the spelling. Chromatic steps are half-steps in 12-tone music, but they are smaller if you are
using a microtone sytem defined in a custom key signature.

For this script to function correctly with custom key signatures, you must create a custom_key_sig.config.txt file in the
the script_settings folder with the following two options for the custom key signature you are using. Unfortunately,
the current version of JW Lua does allow scripts to read this information from the Finale document.

(This example is for 31-EDO.)

number_of_steps = 31
diatonic_steps = {0, 5, 10, 13, 18, 23, 28}
]]

global_dialog = nil
global_number_of_steps_edit = nil

if not finenv.RetainLuaState then
    global_number_of_steps = nil
    global_pos_x = nil
    global_pos_y = nil
end

local path = finale.FCString()
path:SetRunningLuaFolderPath()
package.path = package.path .. ";" .. path.LuaString .. "?.lua"
local transposition = require("library.transposition")

function do_transpose_by_step(global_number_of_steps_edit)
    local undostr = "Transpose By Steps " .. tostring(finenv.Region().StartMeasure)
    if finenv.Region().StartMeasure ~= finenv.Region().EndMeasure then
        undostr = undostr .. " - " .. tostring(finenv.Region().EndMeasure)
    end
    local success = true
    finenv.StartNewUndoBlock(undostr, false) -- this works on both JW Lua and RGP Lua
    for entry in eachentrysaved(finenv.Region()) do
        for note in each(entry) do
            if not transposition.stepwise_transpose(note, global_number_of_steps_edit) then
                success = false
                break
            end
        end
    end
    if finenv.EndUndoBlock then -- EndUndoBlock only exists on RGP Lua 0.56 and higher
        finenv.EndUndoBlock(success)
        if success then
            finenv.Region():Redraw()
        end
    else
        finenv.StartNewUndoBlock(undostr, success) -- JW Lua automatically terminates the final undo block we start here
    end
    return success
end

function create_dialog_box()
    local str = finale.FCString()
    local dialog = finale.FCCustomLuaWindow()
    str.LuaString = "Transpose By Steps"
    dialog:SetTitle(str)
    local current_y = 0
    local x_increment = 105
    -- number of steps
    local static = dialog:CreateStatic(0, current_y+2)
    str.LuaString = "Number Of Steps:"
    static:SetText(str)
    local edit_x = x_increment
    if finenv.UI():IsOnMac() then
        edit_x = edit_x + 4
    end
    global_number_of_steps_edit = dialog:CreateEdit(edit_x, current_y)
    -- ok/cancel
    dialog:CreateOkButton()
    dialog:CreateCancelButton()
    if dialog.OkButtonCanClose then -- OkButtonCanClose will be nil before 0.56 and true (the default) after
        dialog.OkButtonCanClose = false
    end
    return dialog
end
    
function on_ok()
    if not do_transpose_by_step(global_number_of_steps_edit:GetInteger()) then
        finenv.UI():AlertError("Finale is unable to represent some of the transposed pitches. These pitches were left at their original value.", "Transposition Error")
    end
end

function on_close()
    if global_dialog:QueryLastCommandModifierKeys(finale.CMDMODKEY_ALT) or global_dialog:QueryLastCommandModifierKeys(finale.CMDMODKEY_SHIFT) then
        finenv.RetainLuaState = false
    else
        global_number_of_steps = global_number_of_steps_edit:GetInteger()
        global_dialog:StorePosition()
        global_pos_x = global_dialog.StoredX
        global_pos_y = global_dialog.StoredY
    end
end

function transpose_by_step()
    global_dialog = create_dialog_box()
    if nil ~= global_pos_x and nil ~= global_pos_y then
        global_dialog:StorePosition()
        global_dialog:SetRestorePositionOnlyData(global_pos_x, global_pos_y)
        global_dialog:RestorePosition()
    end
    global_dialog:RegisterHandleOkButtonPressed(on_ok)
    if global_dialog.RegisterCloseWindow then
        global_dialog:RegisterCloseWindow(on_close)
    end
    if finenv.IsRGPLua then
        if nil ~= finenv.RetainLuaState then
            finenv.RetainLuaState = true
        end
        finenv.RegisterModelessDialog(global_dialog)
        if nil ~= global_number_of_steps then
            local str = finale.FCString()
            str:AppendInteger(global_number_of_steps)
            global_number_of_steps_edit:SetText(str)
        end
        global_dialog:ShowModeless()
    else
        if finenv.Region():IsEmpty() then
            finenv.UI():AlertInfo("Please select a music region before running this script.", "Selection Required")
            return
        end
        global_dialog:ExecuteModal(nil)
    end
end

transpose_by_step()
