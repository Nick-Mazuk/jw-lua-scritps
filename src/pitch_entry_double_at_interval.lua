function plugindef()
    finaleplugin.RequireSelection = true
    finaleplugin.Author = "Nick Mazuk"
    finaleplugin.Copyright = "CC0 https://creativecommons.org/publicdomain/zero/1.0/"
    finaleplugin.Version = "2.0"
    finaleplugin.Date = "May 5, 2022"
    finaleplugin.CategoryTags = "Pitch"
    finaleplugin.AuthorURL = "https://nickmazuk.com"
    finaleplugin.MinJWLuaVersion = 0.62
    finaleplugin.AdditionalMenuOptions = [[
        Octave Doubling Down
        Double third up
        Double third down
    ]]
    finaleplugin.AdditionalDescriptions = [[
        Doubles the current note an octave lower
        Doubles the current note a diatonic third higher
        Doubles the current note a diatonic third lower
    ]]
    finaleplugin.AdditionalPrefixes = [[
        input_interval = -7
        input_interval = 2
        input_interval = -2
    ]]
    finaleplugin.Notes = [[
        This script doubles selected entries at a specified diatonic interval above or below.
        By default, it creates menu options to double an octave up and down as well as options
        to double a third up and down. RGP Lua allows you to add further menu options by creating
        additional instances of the script file and setting Optional Menu Text and Optional Prefix.
        To avoid confusion, you should also set the Optional Description. If you omit Optional Undo Text,
        the undo text will be the same as the menu option.

        Here is an example that creates a "Double Fifth Up" menu option.

        - Optional Menu Text: `Double Fifth Up`
        - Optional Description: `Doubles the current note a diatonic fifth higher`
        - Optional Prefix: `input_interval = 4`

        Intervals are defined as 0=unison, 1=second, 2=third, etc. Positive values transpose up and
        negative values transpose down. See the "AdditionalPrefixes" above for examples.
    ]]
    return "Octave Doubling Up", "Octave Doubling Up", "Doubles the current note an octave higher"
end

local transposition = require("library.transposition")
local note_entry = require("library.note_entry")

function pitch_entry_double_at_interval(interval)
    for entry in eachentrysaved(finenv.Region()) do
        local note_count = entry.Count
        local note_index = 0
        for note in each(entry) do
            note_index = note_index + 1
            if note_index > note_count then
                break
            end
            local new_note = note_entry.duplicate_note(note)
            if new_note then
                transposition.diatonic_transpose(new_note, interval)
            end
        end
    end
end

input_interval = input_interval or 7
pitch_entry_double_at_interval(input_interval)
