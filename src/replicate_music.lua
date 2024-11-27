function plugindef()
    finaleplugin.Author = "Michael McClennan"
    finaleplugin.Version = 1.0
    finaleplugin.Copyright = "2022/01/03"
    finaleplugin.HandlesUndo = true
return "Replicate Music", "Replicate Music", "Inspired by the 'r' key in Sibelius, this script copies the selected music, and pastes it directly to the right"
end

--[[
Inspired by the 'r' key in Sibelius, this script copies the selected music, and pastes it directly to the right.
Works with a single or multiple measures.
When activated with a shortcut or hotkey, ultra fast replication is possible.
--]]


local function replicate_music()
    local region = finenv.Region()
    local start_measure = finenv.Region().StartMeasure
    local end_measure = finenv.Region().EndMeasure
    local sum_measures = end_measure - start_measure
    local start_paste_region = end_measure + 1
    
    region:CopyMusic()
    finenv.Region():SetStartMeasure(start_paste_region) 
    finenv.Region():SetEndMeasure(start_paste_region + sum_measures) 
    region:PasteMusic()
    region:ReleaseMusic()
end

replicate_music()