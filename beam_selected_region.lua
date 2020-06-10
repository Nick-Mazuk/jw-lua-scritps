function plugindef()
   -- This function and the 'finaleplugin' namespace
   -- are both reserved for the plug-in definition.
   finaleplugin.RequireSelection = true
   finaleplugin.Author = "Robert Patterson"
    finaleplugin.Copyright = "CC0 https://creativecommons.org/publicdomain/zero/1.0/"
   finaleplugin.Version = "1.0"
   finaleplugin.Date = "June 8, 2020"
   finaleplugin.CategoryTags = "Note"
   return "Beam Selected Region", "Beam Selected Region", "Beam Selected Region"
end

function entry_get_next_same_v (entry)
    local next_entry = entry:Next()
    if entry:GetVoice2() then
        if (nil ~= next_entry) and next_entry:GetVoice2() then
            return next_entry
        end
        return nil
    end
    if entry:GetVoice2Launch() then
        while (nil ~= next_entry) and  next_entry:GetVoice2() do
            next_entry = next_entry:Next()
        end
    end
    return next_entry
end

function beam_selected_region()

    local first_in_beam = true
    local first_in_beam_v2 = false
    local curr_staff = 0
    local curr_layer = -1

    for note_entry in eachentrysaved(finenv.Region()) do
        if (curr_staff ~= note_entry:GetStaff()) or (curr_layer ~= note_entry:GetLayerNumber()) then
            first_in_beam = true
            first_in_beam_v2 = true
            curr_staff = note_entry:GetStaff()
            curr_layer = note_entry:GetLayerNumber()
        end
        local isV2 = note_entry:GetVoice2()
        if not isV2 then
            first_in_beam_v2 = true
        end
        if note_entry:GetDuration() < 1024 then   -- less than quarter note duration
            if (not isV2 and first_in_beam) or (isV2 and first_in_beam_v2) then
                note_entry:SetBeamBeat(true)
                if not isV2 then
                    first_in_beam = false
                else
                    first_in_beam_v2 = false
                end
            else
                note_entry:SetBeamBeat(false)
            end
            local next_entry = entry_get_next_same_v (note_entry)
            if (nil ~= next_entry) and (next_entry:GetDuration() < 1024) and not finenv.Region():IsEntryPosWithin(next_entry) then
                next_entry:SetBeamBeat(true)
            end
        end
    end
end

beam_selected_region()