function plugindef()
    finaleplugin.RequireSelection = false
    finaleplugin.HandlesUndo = true
    finaleplugin.Author = "Carl Vine"
    finaleplugin.AuthorURL = "https://carlvine.com/lua/"
    finaleplugin.Copyright = "CC0 https://creativecommons.org/publicdomain/zero/1.0/"
    finaleplugin.Version = "0.36"
    finaleplugin.Date = "2024/06/30"
    finaleplugin.CategoryTags = "Rests, Selection"
    finaleplugin.MinJWLuaVersion = 0.72
    finaleplugin.Notes = [[
        Slide rests up and down on the nominated layer with continuous visual feedback. 
        This was designed especially to help align rests midway 
        between staves with cross-staff notes. 
        The __Mid-Staff Above__ and __Mid-Staff Below__ buttons achieve this with one click. 
        (Note that the midpoint is measured in __Page View__ and may look different 
        in __Scroll View__). Cancel the script to leave rests unchanged. 

        _Reset Zero_ sets nil offset. 
        On transposing instruments this is __not__ the middle 
        of the staff if _Display in Concert Pitch_ is selected. 
        In those cases use _Floating Rests_ to return them to 
        their virgin state where the offset is determined by  
        _Document_ → _Document Options_ → _Layers_ → _Adjust Floating Rests by..._

        At startup all rests in the chosen layer are moved to the 
        same offset as the first rest on that layer in the selection. 
        Layer numbers can be changed "on the fly" to help 
        balance rests across multiple layers. 
        Select __Modeless Dialog__ if you want the dialog window to persist 
        on-screen for repeated use until you click _Cancel_ [_Escape_]. 
        Cancelling __Modeless__ will apply the _next_ time you use the script.

        > If __Layer Number__ is highlighted these __Key Commands__ are available: 

        > - __a__ (__-__): move rests down one step 
        > - __s__ (__+__): move rests up one step 
        > - __d__: move to mid-staff above (if one staff selected) 
        > - __f__: move to mid-staff below (if one staff selected) 
        > - __z__: reset to "zero" shift (not floating) 
        > - __x__: floating rests 
        > - __c__: invert shift direction 
        > - __q__: show these script notes 
        > - __m__: toggle "Modeless" 
        > - __0-4__: layer number (delete key not needed) 
    ]]
    return "Rest Slider...", "Rest Slider", "Slide rests up and down with continuous visual feedback"
end

local config = {
    layer_num = 0,
    timer_id = 1,
    modeless = false, -- false = modal / true = modeless
    window_pos_x = false,
    window_pos_y = false
}
local mixin = require("library.mixin")
local layer = require("library.layer")
local configuration = require("library.configuration")
local utils = require("library.utils")
local library = require("library.general_library")
local script_name = library.calc_script_name()

local first_offset = 0 -- set to real offset of first rest in selection
local refocus_document = false
local save_displacement, adjacent_offsets, saved_bounds = {}, {}, {}
local name = plugindef():gsub("%.%.%.", "")
local mouse_tracking = false
local selection

local function dialog_set_position(dialog)
    if config.window_pos_x and config.window_pos_y then
        dialog:StorePosition()
        dialog:SetRestorePositionOnlyData(config.window_pos_x, config.window_pos_y)
        dialog:RestorePosition()
    end
end

local function dialog_save_position(dialog)
    dialog:StorePosition()
    config.window_pos_x = dialog.StoredX
    config.window_pos_y = dialog.StoredY
    configuration.save_user_settings(script_name, config)
end

local function get_staff_name(staff_num)
    local staff = finale.FCStaff()
    staff:Load(staff_num)
    local str = staff:CreateDisplayAbbreviatedNameString().LuaString
    if not str or str == "" then
        str = "Staff" .. staff_num
    end
    return str
end

local function initialise_parameters()
    local bounds = { -- primary region selection boundaries
        "StartStaff", "StartMeasure", "StartMeasurePos",
        "EndStaff",   "EndMeasure",   "EndMeasurePos",
    }
    local rgn = finenv.Region()
    selection = { staff = "no staff", region = "no selection"} -- default
    adjacent_offsets = {} -- start with blank collection
    -- set_saved_bounds
    for _, prop in ipairs(bounds) do
        saved_bounds[prop] = rgn:IsEmpty() and 0 or rgn[prop]
    end
    if rgn:IsEmpty() then return end -- nothing else to initialise

    -- measures
    selection.region = "m." .. rgn.StartMeasure
    if rgn.StartMeasure ~= rgn.EndMeasure then
        selection.region = selection.region .. "-" .. rgn.EndMeasure
    end
    -- staves
    selection.staff = get_staff_name(rgn.StartStaff)
    if rgn.StartStaff ~= rgn.EndStaff then
        selection.staff = selection.staff .. "-" .. get_staff_name(rgn.EndStaff)
        return
    end
    -- set_adjacent_offsets (single staff required)
    local start_slot = rgn:CalcSlotNumber(rgn.StartStaff)
    local next_staff = {} -- locate staff above/below
    local stack = mixin.FCMMusicRegion()
    stack:SetRegion(rgn):SetFullMeasureStack()
    if start_slot > 1 then
        next_staff.above = stack:CalcStaffNumber(start_slot - 1)
    end
    if start_slot < stack.EndSlot then
        next_staff.below = stack:CalcStaffNumber(start_slot + 1)
    end
    local system_staves = finale.FCSystemStaves()
    system_staves:LoadAllForRegion(stack)
    local sys_staff = system_staves:FindStaff(rgn.StartStaff)
    if sys_staff then
        local start_position = sys_staff.Distance
        for key, staff_num in pairs(next_staff) do -- find 0, 1 or 2 adjacent_offsets
            sys_staff = system_staves:FindStaff(staff_num)
            local n = start_position - sys_staff.Distance
            adjacent_offsets[key] = math.floor(n / 24) -- convert EVPU to HALF steps
        end
    end
end

local function start_undo_block(layer_num, shift)
    local id = string.format("Rests %s %s L%d pos%d", selection.staff, selection.region, layer_num, shift)
    finenv.StartNewUndoBlock(id, false)
end

local function get_rest_offset(entry)
    if entry:IsNote() then return 0 end -- only rests wanted
    local spec = finale.FCCurrentStaffSpec()
    spec:LoadForEntry(entry)
    local rest_pos = spec.OtherRestPosition
    if entry.Duration >= finale.BREVE then
        rest_pos = spec.DoubleWholeRestPosition
    elseif entry.Duration >= finale.WHOLE_NOTE then
        rest_pos = spec.WholeRestPosition
    elseif entry.Duration >= finale.HALF_NOTE then
        rest_pos = spec.HalfRestPosition
    end
    entry:MakeMovableRest()
    local rest = entry:GetItemAt(0)
    return rest:CalcStaffPosition() - rest_pos
end

local function first_rest_offset(layer_num)
    local offset = 0
    for entry in eachentry(finenv.Region(), layer_num) do
        if entry:IsRest() then
            if not entry.FloatingRest then
                offset = entry:GetRestDisplacement() + get_rest_offset(entry)
            end
            break -- only need the first rest within layer_num
        end
    end
    return offset
end

local function save_rest_positions()
    first_offset = first_rest_offset(config.layer_num)
    for entry in eachentry(finenv.Region()) do
        if entry:IsRest() then
            save_displacement[entry.EntryNumber] = {
                entry:GetRestDisplacement(), entry.FloatingRest
            }
        end
    end
end

local function restore_rest_positions()
    if config.modeless then
        finenv.StartNewUndoBlock("Rests " .. selection.region .. " reset", false)
    end
    for entry in eachentrysaved(finenv.Region()) do
        local v = save_displacement[entry.EntryNumber]
        if entry:IsRest() and v ~= nil then
            entry:SetRestDisplacement(v[1])
            entry:SetFloatingRest(v[2])
        end
    end
    if config.modeless then finenv.EndUndoBlock(true) end
    finenv.Region():Redraw()
end

local function run_the_dialog_box()
    local y, max_thumb, center = 0, 72, 36
    local x =  { 0, 107, max_thumb * 2.5, max_thumb * 5 }
    local y_off = finenv.UI():IsOnMac() and 3 or 0
    local max, button_wide = layer.max_layers(), 107
    local save_layer = config.layer_num
    local answer = {}
    --
    local dialog = mixin.FCXCustomLuaWindow():SetTitle("Shift Rests")
        -- local functions
        local function show_info()
            utils.show_notes_dialog(dialog, "About " .. name, 500, 455)
            refocus_document = true
        end
        local function yd(diff)
            y = diff and (y + diff) or (y + 25)
        end
        local function shift_rests(shift, float)
            if not mouse_tracking then
                start_undo_block(save_layer, shift)
            end
            for entry in eachentrysaved(finenv.Region(), save_layer) do
                if entry:IsRest() then
                    if float then
                        entry:SetFloatingRest(true)
                    else
                        local offset = get_rest_offset(entry)
                        entry:SetRestDisplacement(entry:GetRestDisplacement() + shift - offset)
                    end
                end
            end
            if not mouse_tracking then
                finenv.EndUndoBlock(true)
            end
            finenv.Region():Redraw()
        end
        local function set_value(thumb, float, set_thumb)
            local pos = thumb - center
            local sign = (pos > 0) and "[ +" or "[ "
            answer.value:SetText(sign .. pos .. " ]")
            shift_rests(pos, float)
            if set_thumb then answer.slider:SetThumbPosition(thumb) end
        end
        local function set_zero(float)
            set_value(center, float, true)
        end
        local function nudge_thumb(add)
            local thumb = answer.slider:GetThumbPosition()
            if (add < 0 and thumb > 0) or (add > 0 and thumb < max_thumb) then
                thumb = thumb + add
                set_value(thumb, false, true)
            end
        end
        local function set_midstaff(direction)
            if adjacent_offsets[direction] then
                local n = adjacent_offsets[direction] + center
                set_value(n, false, true)
            end
        end
        local function invert_shift()
            local n = (answer.slider:GetThumbPosition() - center) * -1
            set_value(n + center, false, true)
        end
        local function key_change() -- key command replacements in layer_num box
            local val = answer.layer_num:GetText():lower()
            if val == "" then
                answer.layer_num:SetText("0")
                save_layer = 0
            else
                if val:find("[^0-" .. max .. "]") then
                    if val:find("[?q]") then show_info()
                    elseif val:find("[-a_%[]") then nudge_thumb(-1)
                    elseif val:find("[+s=%]]") then nudge_thumb(1)
                    elseif val:find("d") then set_midstaff("above")
                    elseif val:find("f") then set_midstaff("below")
                    elseif val:find("z") then set_zero(false)
                    elseif val:find("x") then set_zero(true)
                    elseif val:find("c") then invert_shift()
                    elseif val:find("m") then
                        answer.modeless:SetCheck((answer.modeless:GetCheck() + 1) % 2)
                    end
                else
                    val = val:sub(-1)
                    local n = tonumber(val) or 0
                    if save_layer ~= 0 and save_layer ~= n then
                        save_layer = n
                        first_offset = first_rest_offset(n)
                        set_value(first_offset + center, false, true)
                    end
                    save_layer = n
                end
                answer.layer_num:SetText(save_layer):SetKeyboardFocus()
            end
        end
        local function on_timer() -- look for changes in selected region
            for prop, value in pairs(saved_bounds) do
                if finenv.Region()[prop] ~= value then -- selection changed
                    initialise_parameters() -- reset all selection variables
                    save_rest_positions()
                    set_value(first_offset + center, false, false) -- reset slider and rests
                    dialog:GetControl("info"):SetText(selection.staff .. ": " .. selection.region)
                    dialog:GetControl("above"):SetEnable(adjacent_offsets.above ~= nil)
                    dialog:GetControl("below"):SetEnable(adjacent_offsets.below ~= nil)
                    break -- all done
                end
            end
        end
    -- draw dialog contents
    dialog:CreateStatic(0, y, "info"):SetWidth(x[4]):SetText(selection.staff .. ": " .. selection.region)
    yd()
    answer.slider = dialog:CreateSlider(0, y):SetMinValue(0):SetMaxValue(max_thumb)
        :SetWidth(x[4]):SetThumbPosition(first_offset + center)
        :AddHandleCommand(function(self) set_value(self:GetThumbPosition(), false, false) end)
    yd(32)
    dialog:CreateStatic(0, y):SetWidth(x[2]):SetText("Layer 1-" .. max .. " (0 = all):")
    answer.layer_num = dialog:CreateEdit(x[2], y - y_off):SetWidth(20):SetText(save_layer)
        :AddHandleCommand(function() key_change() end )
    answer.value = dialog:CreateStatic(x[3] - 12, y):SetWidth(75)
    set_value(first_offset + center, false, false) -- preset slider and all selected rests

    dialog:CreateButton(x[4] - 110, y):SetText("Reset Zero (z)"):SetWidth(button_wide)
        :AddHandleCommand(function() set_zero(false) end)
    yd()
    local q = dialog:CreateButton(0, y):SetText("?"):SetWidth(20)
        :AddHandleCommand(function() show_info() end)
    dialog:CreateButton(25, y, "above"):SetText("mid-staff above (d)"):SetWidth(button_wide)
        :SetEnable(adjacent_offsets.above ~= nil)
        :AddHandleCommand(function() set_midstaff("above") end)
    dialog:CreateButton(137, y, "below"):SetText("mid-staff below (f)"):SetWidth(button_wide)
        :SetEnable(adjacent_offsets.below ~= nil)
        :AddHandleCommand(function() set_midstaff("below") end)
    dialog:CreateButton(x[4] - 110, y):SetText("Floating Rests (x)")
        :SetWidth(button_wide):AddHandleCommand(function() set_zero(true) end)
    yd()
    answer.modeless = dialog:CreateCheckbox(0, y):SetWidth(x[4]):SetCheck(config.modeless and 1 or 0)
        :SetText("Modeless Operation (\"floating\" dialog window)")
    -- wrap it up
    dialog:CreateOkButton():SetText(config.modeless and "Apply" or "OK")
    dialog:CreateCancelButton()
    dialog_set_position(dialog)
    if config.modeless then dialog:RegisterHandleTimer(on_timer) end
    dialog:RegisterMouseTrackingStarted(function(cntl)
        mouse_tracking = true
        start_undo_block(save_layer, cntl:GetThumbPosition() - center)
    end)
    dialog:RegisterMouseTrackingStopped(function()
        if mouse_tracking then
            mouse_tracking = false
            finenv.EndUndoBlock(true)
        end
    end)
    dialog:RegisterInitWindow(function(self)
        if config.modeless then self:SetTimer(config.timer_id, 125) end
        q:SetFont(q:CreateFontInfo():SetBold(true))
        answer.layer_num:SetKeyboardFocus()
    end)
    dialog:RegisterHandleOkButtonPressed(function()
        save_rest_positions() -- save rest positions so "Close" leaves correct positions
    end)
    local change_mode = false
    dialog:RegisterCloseWindow(function(self)
        if config.modeless then self:StopTimer(config.timer_id) end
        restore_rest_positions()
        local mode = (answer.modeless:GetCheck() == 1)
        change_mode = (mode and not config.modeless) -- modal -> modeless?
        config.modeless = mode
        config.layer_num = answer.layer_num:GetInteger()
        dialog_save_position(self)
    end)
    if config.modeless then
        dialog:RunModeless()
    else
        dialog:ExecuteModal()
        if refocus_document then finenv.UI():ActivateDocumentWindow() end
    end
    return change_mode
end

local function slide_rests()
    configuration.get_user_settings(script_name, config)
    if not config.modeless and finenv.Region():IsEmpty() then
        finenv.UI():AlertError(
            "Please select some music\nbefore running this script.",
            name
        )
        return
    end
    initialise_parameters()
    save_rest_positions()
    while run_the_dialog_box() do end
end

slide_rests()
