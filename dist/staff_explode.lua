function plugindef()
    finaleplugin.RequireSelection = true
    finaleplugin.Author = "Carl Vine"
    finaleplugin.AuthorURL = "http://carlvine.com"
    finaleplugin.Copyright = "CC0 https://creativecommons.org/publicdomain/zero/1.0/"
    finaleplugin.Version = "v1.45"
    finaleplugin.Date = "2022/05/16"
    finaleplugin.Notes = [[
        This script explodes a set of chords from layer one on one staff onto single lines on subsequent staves. 
        The number of staves is determined by the largest number of notes in any chord.
        It warns if pre-existing music in the destination will be erased. 
        It duplicates all markings from the original and resets the current clef on each destination staff.

        This script allows for the following configuration:

        ```
        fix_note_spacing = true -- to respace music automatically when the script finishes
        ```
    ]]
    return "Staff Explode", "Staff Explode", "Staff Explode onto consecutive single staves"
end

--  Author: Robert Patterson
--  Date: March 5, 2021
--[[
$module Configuration

This library implements a UTF-8 text file scheme for configuration as follows:

- Comments start with `--`
- Leading, trailing, and extra whitespace is ignored
- Each parameter is named and delimited as follows:
`<parameter-name> = <parameter-value>`

Parameter values may be:

- Strings delimited with either single- or double-quotes
- Tables delimited with `{}` that may contain strings, booleans, or numbers
- Booleans (`true` or `false`)
- Numbers

Currently the following are not supported:

- Tables embedded within tables
- Tables containing strings that contain commas

A sample configuration file might be:

```lua
-- Configuration File for "Hairpin and Dynamic Adjustments" script
--
left_dynamic_cushion 		= 12		--evpus
right_dynamic_cushion		= -6		--evpus
```

Configuration files must be placed in a subfolder called `script_settings` within
the folder of the calling script. Each script that has a configuration file
defines its own configuration file name.
]] --
local configuration = {}

local script_settings_dir = "script_settings" -- the parent of this directory is the running lua path
local comment_marker = "--"
local parameter_delimiter = "="
local path_delimiter = "/"

local file_exists = function(file_path)
    local f = io.open(file_path, "r")
    if nil ~= f then
        io.close(f)
        return true
    end
    return false
end

local strip_leading_trailing_whitespace = function(str)
    return str:match("^%s*(.-)%s*$") -- lua pattern magic taken from the Internet
end

local parse_parameter -- forward function declaration

local parse_table = function(val_string)
    local ret_table = {}
    for element in val_string:gmatch("[^,%s]+") do -- lua pattern magic taken from the Internet
        local parsed_element = parse_parameter(element)
        table.insert(ret_table, parsed_element)
    end
    return ret_table
end

parse_parameter = function(val_string)
    if "\"" == val_string:sub(1, 1) and "\"" == val_string:sub(#val_string, #val_string) then -- double-quote string
        return string.gsub(val_string, "\"(.+)\"", "%1") -- lua pattern magic: "(.+)" matches all characters between two double-quote marks (no escape chars)
    elseif "'" == val_string:sub(1, 1) and "'" == val_string:sub(#val_string, #val_string) then -- single-quote string
        return string.gsub(val_string, "'(.+)'", "%1") -- lua pattern magic: '(.+)' matches all characters between two single-quote marks (no escape chars)
    elseif "{" == val_string:sub(1, 1) and "}" == val_string:sub(#val_string, #val_string) then
        return parse_table(string.gsub(val_string, "{(.+)}", "%1"))
    elseif "true" == val_string then
        return true
    elseif "false" == val_string then
        return false
    end
    return tonumber(val_string)
end

local get_parameters_from_file = function(file_name)
    local parameters = {}

    local path = finale.FCString()
    path:SetRunningLuaFolderPath()
    local file_path = path.LuaString .. path_delimiter .. file_name
    if not file_exists(file_path) then
        return parameters
    end

    for line in io.lines(file_path) do
        local comment_at = string.find(line, comment_marker, 1, true) -- true means find raw string rather than lua pattern
        if nil ~= comment_at then
            line = string.sub(line, 1, comment_at - 1)
        end
        local delimiter_at = string.find(line, parameter_delimiter, 1, true)
        if nil ~= delimiter_at then
            local name = strip_leading_trailing_whitespace(string.sub(line, 1, delimiter_at - 1))
            local val_string = strip_leading_trailing_whitespace(string.sub(line, delimiter_at + 1))
            parameters[name] = parse_parameter(val_string)
        end
    end

    return parameters
end

--[[
% get_parameters

Searches for a file with the input filename in the `script_settings` directory and replaces the default values in `parameter_list` with any that are found in the config file.

@ file_name (string) the file name of the config file (which will be prepended with the `script_settings` directory)
@ parameter_list (table) a table with the parameter name as key and the default value as value
]]
function configuration.get_parameters(file_name, parameter_list)
    local file_parameters = get_parameters_from_file(script_settings_dir .. path_delimiter .. file_name)
    if nil ~= file_parameters then
        for param_name, def_val in pairs(parameter_list) do
            local param_val = file_parameters[param_name]
            if nil ~= param_val then
                parameter_list[param_name] = param_val
            end
        end
    end
end

--[[
% save_parameters

Saves a config file with the input filename in the `script_settings` directory using values provided in `parameter_list`.

@ file_name (string) the file name of the config file (which will be prepended with the `script_settings` directory)
@ parameter_list (table) a table with the parameter name as key and the default value as value
]]
function configuration.save_parameters(file_name, parameter_list)
    local folder_path = finenv:RunningLuaFolderPath() .. script_settings_dir
    local file_path = folder_path ..  path_delimiter .. file_name
    local file = io.open(file_path, "w")
    if file == nil then -- file not found
        os.execute('mkdir "' .. folder_path ..'"') -- so try to make a folder
        file = io.open(file_path, "w") -- try the file again
        if file == nil then -- still couldn't find file
            return false -- so give up
        end
    end
    for i,v in pairs(parameter_list) do -- only integer or string values
        if type(v) == "string" then
            v = "\"" .. v .."\""
        else
            v = tostring(v)
        end
        file:write(i, " = ", v, "\n")
    end
    file:close()
    return true -- success
end



--[[
$module Clef

A library of general clef utility functions.
]] --
local clef = {}

--[[
% get_cell_clef

Gets the clef for any cell.

@ measure (number) The measure number for the cell
@ staff_number (number) The staff number for the cell
: (number) The clef for the cell
]]
function clef.get_cell_clef(measure, staff_number)
    local cell_clef = -1
    local cell = finale.FCCell(measure, staff_number)
    local cell_frame_hold = finale.FCCellFrameHold()

    cell_frame_hold:ConnectCell(cell)
    if cell_frame_hold:Load() then
        if cell_frame_hold.IsClefList then
            cell_clef = cell_frame_hold:CreateFirstCellClefChange().ClefIndex
        else
            cell_clef = cell_frame_hold.ClefIndex
        end
    end
    return cell_clef
end

--[[
% get_default_clef

Gets the default clef for any staff for a specific region.

@ first_measure (number) The first measure of the region
@ last_measure (number) The last measure of the region
@ staff_number (number) The staff number for the cell
: (number) The default clef for the staff
]]
function clef.get_default_clef(first_measure, last_measure, staff_number)
    local staff = finale.FCStaff()
    local cell_clef = clef.get_cell_clef(first_measure - 1, staff_number)
    if cell_clef < 0 then -- failed, so check clef AFTER insertion
        cell_clef = clef.get_cell_clef(last_measure + 1, staff_number)
        if cell_clef < 0 then -- resort to destination staff default clef
            cell_clef = staff:Load(staff_number) and staff.DefaultClef or 0 -- default treble
        end
    end
    return cell_clef
end

--[[
% can_change_clef

Determine if the current version of the plugin can change clefs.

: (boolean) Whether or not the plugin can change clefs
]]
function clef.can_change_clef()
    -- RGPLua 0.60 or later needed for clef changing
    return finenv.IsRGPLua or finenv.StringVersion >= "0.60"
end

--[[
% restore_default_clef

Restores the default clef for any staff for a specific region.

@ first_measure (number) The first measure of the region
@ last_measure (number) The last measure of the region
@ staff_number (number) The staff number for the cell
]]
function clef.restore_default_clef(first_measure, last_measure, staff_number)
    if not clef.can_change_clef() then
        return
    end

    local default_clef = clef.get_default_clef(first_measure, last_measure, staff_number)

    for measure = first_measure, last_measure do
        local cell = finale.FCCell(measure, staff_number)
        local cell_frame_hold = finale.FCCellFrameHold()
        cell_frame_hold:ConnectCell(cell)
        if cell_frame_hold:Load() then
            cell_frame_hold:MakeCellSingleClef(nil) -- RGPLua v0.60
            cell_frame_hold:SetClefIndex(default_clef)
            cell_frame_hold:Save()
        end
    end
end




local config = {fix_note_spacing = true}

configuration.get_parameters("staff_explode.config.txt", config)

function show_error(error_code)
    local errors = {
        need_more_staves = "There are not enough empty\nstaves to explode onto",
        only_one_staff = "Please select only one staff!",
        empty_region = "Please select a region\nwith some notes in it!",
        require_chords = "Chords must contain\nat least two pitches",
    }
    finenv.UI():AlertNeutral("script: " .. plugindef(), errors[error_code])
    return -1
end

function should_overwrite_existing_music()
    local alert = finenv.UI():AlertOkCancel("script: " .. plugindef(), "Overwrite existing music?")
    local should_overwrite = alert == 0
    return should_overwrite
end

function get_note_count(source_staff_region)
    local note_count = 0
    for entry in eachentry(source_staff_region) do
        if entry.Count > note_count then
            note_count = entry.Count
        end
    end
    if note_count == 0 then
        return show_error("empty_region")
    end
    if note_count < 2 then
        return show_error("require_chords")
    end
    return note_count
end

function ensure_score_has_enough_staves(slot, note_count)
    local staves = finale.FCStaves()
    staves:LoadAll()
    if note_count > staves.Count + 1 - slot then
        return false
    end
    return true
end

function staff_explode()
    local source_staff_region = finale.FCMusicRegion()
    source_staff_region:SetCurrentSelection()
    if source_staff_region:CalcStaffSpan() > 1 then
        return show_error("only_one_staff")
    end
    local start_slot = source_staff_region.StartSlot
    local start_measure = source_staff_region.StartMeasure
    local end_measure = source_staff_region.EndMeasure
    local regions = {}
    regions[1] = source_staff_region

    local max_note_count = get_note_count(source_staff_region)
    if max_note_count <= 0 then
        return
    end

    if not ensure_score_has_enough_staves(start_slot, max_note_count) then
        show_error("need_more_staves")
        return
    end

    -- copy top staff to note_count lower staves (one-based index)
    local destination_is_empty = true
    for slot = 2, max_note_count do
        regions[slot] = finale.FCMusicRegion()
        regions[slot]:SetRegion(regions[1])
        regions[slot]:CopyMusic()
        local this_slot = start_slot + slot - 1 -- "real" slot number, indexed[1]
        regions[slot].StartSlot = this_slot
        regions[slot].EndSlot = this_slot

        if destination_is_empty then
            for entry in eachentry(regions[slot]) do
                if entry.Count > 0 then
                    destination_is_empty = false
                    break
                end
            end
        end
    end

    if destination_is_empty or should_overwrite_existing_music() then
        -- run through all staves deleting requisite notes in each entry
        for slot = 1, max_note_count do
            if slot > 1 then -- finish pasting a copy of the source music
                regions[slot]:PasteMusic()
                clef.restore_default_clef(start_measure, end_measure, regions[slot].StartStaff)
            end

            -- run the ENTRIES loop for current selection on staff copies
            local from_top = slot - 1 -- delete how many notes from the top?
            for entry in eachentrysaved(regions[slot]) do
                if entry:IsNote() then
                    local from_bottom = entry.Count - slot -- how many from the bottom?
                    if from_top > 0 then -- delete TOP notes
                        for i = 1, from_top do
                            entry:DeleteNote(entry:CalcHighestNote(nil))
                        end
                    end
                    if from_bottom > 0 then -- delete BOTTOM notes
                        for i = 1, from_bottom do
                            entry:DeleteNote(entry:CalcLowestNote(nil))
                        end
                    end
                end
            end
        end

        if config.fix_note_spacing then
            regions[1]:SetFullMeasureStack()
            regions[1]:SetInDocument()
            finenv.UI():MenuCommand(finale.MENUCMD_NOTESPACING)
            regions[1].StartSlot = start_slot
            regions[1].EndSlot = start_slot
            regions[1]:SetInDocument()
        end
    end

    -- ALL DONE -- empty out the copied clip files
    for slot = 2, max_note_count do
        regions[slot]:ReleaseMusic()
    end

    finenv:Region():SetInDocument()
end

staff_explode()
