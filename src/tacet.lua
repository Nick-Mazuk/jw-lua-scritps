function plugindef()
   -- This function and the 'finaleplugin' namespace
   -- are both reserved for the plug-in definition.
   finaleplugin.RequireSelection = false
   finaleplugin.Author = "The JWs: Jacob Winkler & Jari Williamsson"
   finaleplugin.Version = "1.0"
   finaleplugin.Date = "7/27/2020"
   finaleplugin.CategoryTags = "Layout, Measure, Rest"
   return "TACET", "Create Tacet", "Creates a mm-rest and TACET expression"
end
-- USER VARIABLES--
local tacet_text = "TACET" -- The text of any expressions created by the script
local nudge = -24 -- The amount to nudge the expression, in EVPUs. -24 EVPUs = left 1 space
-------------------------------
function tacet_mm()
    local region = finenv.Region()
    -- Load the multimeasure rest prefs
    local mmrestprefs = finale.FCMultiMeasureRestPrefs()
    mmrestprefs:Load(1)
    local ui = finenv.UI()
    local mmupdate = false
    local process_all = 0
    -- Check for selection...
    if region.StartMeasure == 0 then
        process_all = ui:AlertYesNo("There is no active selection. Would you like to process the current part?", "No Selection:")
        if process_all == 3 then
            return
        elseif process_all == 2 then
            region:SetFullDocument()
        end -- if...
    end -- if StartMeasure == 0


    -- Will not continue if auto-update of mm rests is ON
    if mmrestprefs.AutoUpdate then
        mmupdate = ui:AlertYesNo("Automatic Update is ON in the multimeasure preferences. Would you like to turn it OFF and proceed?", "Unable to create tacet:")
        if mmupdate == 3 then
            return
        elseif mmupdate == 2 then
            mmrestprefs.AutoUpdate = false
            mmrestprefs:Save()
        end -- if
    end --  if

    --[[ 
    -- This snippet from Jari felt very cumbersome in practice, so I commented it out -Jake
    if ui:AlertYesNo("Do you want to create a tacet section in this part? All music in the region will be hidden.", 
            "Are you sure?") ~= finale.YESRETURN then
        return
    end -- if ]]

    -- Delete all old mm rests from the region
    -- (In this case, it's safe to delete from the start, since no relocation of data records takes place.)
    
    local mmrests = finale.FCMultiMeasureRests()
    mmrests:LoadAll()
    for mm in each (mmrests) do
        if region:IsMeasureIncluded(mm.StartMeasure) or region:IsMeasureIncluded(mm.EndMeasure) then        
            mm:DeleteData()
        end -- if
    end -- for
 
    local mm = finale.FCMultiMeasureRest()
    mm.StartMeasure = region.StartMeasure
    mm.EndMeasure = region.EndMeasure
    -- Copy from the default MM rest definition
    mm.NumberHorizontalAdjust = mmrestprefs.NumberHorizontalAdjust
    mm.NumberVerticalAdjust = mmrestprefs.NumberVerticalAdjust
    mm.ShapeEndAdjust = mmrestprefs.ShapeEndAdjust
    mm.ShapeID = mmrestprefs.ShapeID
    mm.ShapeStartAdjust = mmrestprefs.ShapeStartAdjust
    mm.StartNumberingAt = 20000 -- A really high value here to hide the number
    mm.SymbolSpace = mmrestprefs.SymbolSpace
    mm.UseSymbols = mmrestprefs.UseSymbols
    mm.UseSymbolsLessThan = mmrestprefs.UseSymbolsLessThan
    mm.Width = mmrestprefs.Width
    mm:Save()
    finale.FCStaffSystems.UpdateFullLayout()
--
    tacet_expr()
end -- end function tacet_mm()

function tacet_expr()
    local region = finenv.Region()
    local font = finale.FCFontInfo()
    local categorydefs = finale.FCCategoryDefs()
    local misc_cat = finale.FCCategoryDef()
    categorydefs:LoadAll()
    local misc = 0
    local tempo = 0 
    for cat in eachbackwards(categorydefs) do
        if cat:CreateName().LuaString == "Miscellaneous" and misc == 0 then
            misc = cat.ID
            misc_cat = cat
        elseif cat:CreateName().LuaString == "Tempo Marks" and tempo == 0 then
            tempo = cat.ID
            font = cat:CreateTextFontInfo()
        end -- if
    end -- for cat
    
    local textexpressiondefs = finale.FCTextExpressionDefs()
    textexpressiondefs:LoadAll()
    local tacet_ted = 0
-- find an existing TACET (with the right parameters!)
    for ted in each(textexpressiondefs) do
        if ted.CategoryID == misc and ted:CreateDescription().LuaString == "TACET for Multimeasure Rests" then
            print ("Tacet found at",ted.ItemNo)
            tacet_ted = ted.ItemNo
        end -- if ted.CategoryID
    end -- for ted...
 -- if there is no existing TACET, create one
    if tacet_ted == 0 then
        local ex_ted = finale.FCTextExpressionDef()
        local ted_descr = finale.FCString()
        ted_descr.LuaString = "TACET for Multimeasure Rests"
        local ted_text = finale.FCString()
        local text_font = "^fontTxt"..font:CreateEnigmaString(finale.FCString()).LuaString
        ted_text.LuaString = text_font..tacet_text
        ex_ted:AssignToCategory(misc_cat)
        ex_ted:SetDescription(ted_descr)
        ex_ted:SaveNewTextBlock(ted_text)
        ex_ted.HorizontalJustification = 1
        ex_ted.HorizontalAlignmentPoint = 5 -- center over/under music
        ex_ted.HorizontalOffset = nudge
        ex_ted.VerticalAlignmentPoint = 3 -- align to staff reference line
        ex_ted.VerticalBaselineOffset = 24
        ex_ted:SaveNew()
        tacet_ted = ex_ted.ItemNo
        print ("New TACET created at",tacet_ted) 
    end -- if tacet_ted == 0

-- Test to see if mark is there already...
    local tacet_assigned = false
    local expressions = finale.FCExpressions()
    expressions:LoadAllForRegion(region)
    --local tacet_assigned = expressions:FindItemNo(tacet_ted, 1)
    for e in each(expressions) do
         local create_def = e:CreateTextExpressionDef()
         if create_def.ItemNo == tacet_ted then
            tacet_assigned = true
            print ("tacet_assigned = ",tacet_assigned)
        end
    end -- for e in expressions...
-- add the TACET mark
    if tacet_assigned == false then
        local sysstaves = finale.FCSystemStaves()
        sysstaves:LoadScrollView()
        local first_staff = 1
        for sys in each(sysstaves) do
            local staff_num = sys.Staff
            if first_staff == 1 then
               region:SetStartStaff(sys.Staff)
                first_staff = 0
            end -- end "if first_staff == 1"
        end -- end "for sys..." 
--
        local sysstaff = finale.FCSystemStaff()
        local measure_num = region.StartMeasure
        local measure_pos = region.StartMeasurePos
        local add_expression = finale.FCExpression()
        local staff_num = region.StartStaff
        add_expression:SetStaff(staff_num)
        add_expression:SetMeasurePos(measure_pos)
        add_expression:SetID(tacet_ted)
        local and_cell = finale.FCCell(measure_num, staff_num)
        add_expression:SaveNewToCell(and_cell)
    end -- if tacet_assigned...
end -- end function tacet_expr() 

----
tacet_mm()