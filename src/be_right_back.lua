function plugindef()
    finaleplugin.Author = "Michael McClennan"
    finaleplugin.Version = 1.0
    finaleplugin.Copyright = "2022/01/03"
    finaleplugin.HandlesUndo = false
    finaleplugin.NoStore = true
end

local str = finale.FCString()
str.LuaString = "BRB v1.0"
BRB_dialog = finale.FCCustomLuaWindow()
BRB_dialog:SetTitle(str)
BRB_dialog:SetClientWidth(90)

local button_go_back = BRB_dialog:CreateButton(0, 0)
str.LuaString = "Go Back"
button_go_back:SetWidth(60)
button_go_back:SetText(str)
local button_set = BRB_dialog:CreateButton(65, 0)
str.LuaString = "Set"
button_set:SetWidth(40)
button_set:SetText(str)
local buttonCancel = BRB_dialog:CreateCancelButton()
str.LuaString = "Close"
buttonCancel:SetWidth(50)
buttonCancel:SetText(str)

BRB_table = {}    
trigger = {}
function trigger.buttonGo()
    local part = finale.FCPart(BRB_table.part)
    part:ViewInDocument()

    --VIEWPAGE/SCROLL
    if BRB_table.page_view == true then       --PAGE VIEW
        local ui = finenv.UI()
        ui:MenuCommand(finale.MENUCMD_VIEWSCROLLVIEW )
        finenv.UI():MoveToMeasure(BRB_table.measure_num, 1)
        ui:MenuCommand(finale.MENUCMD_VIEWPAGEVIEW )
        --insert a Zoom Level call when PDK allows

    else                  --SCROLL VIEW
        local ui = finenv.UI()
        ui:MenuCommand(finale.MENUCMD_VIEWSCROLLVIEW )
        --insert a Zoom Level call when PDK allows
        finenv.UI():MoveToMeasure(BRB_table.measure_num, 1)
    end

    local ui = finenv.UI()
    ui:RedrawDocument()  
end

function trigger.button_set()

 --   local selected_region = finenv.Region()
  --  BRB_table.region = selected_region:GetStartMeasure()
    BRB_table.page_view = finenv.UI():IsPageView()    
    local p = finale.FCPart(finale.PARTID_CURRENT)
    BRB_table.part = p:GetID()
    BRB_table.zoom = finenv.UI():GetZoomLevel()
    cur_docID = finale.FCDocument(-1)
    BRB_table.document = cur_docID:GetID()
    if is_page_view == true then      --PAGE VIEW
        local ui = finenv.UI()
        BRB_table.page_num =  finenv.UI():GetCurrentPage()
        ui:MenuCommand(finale.MENUCMD_VIEWSCROLLVIEW )
        BRB_table.measure_num = finenv.UI():GetCurrentMeasure()
        ui:MenuCommand(finale.MENUCMD_VIEWPAGEVIEW )
    else
        BRB_table.measure_num = finenv.UI():GetCurrentMeasure()  --SCROLL VIEW
    end 
end

BRB_dialog:RegisterHandleControlEvent (
    button_go_back,
    function(control)
        trigger.buttonGo()
    end
)
BRB_dialog:RegisterHandleControlEvent (
    button_set,
    function(control)
        trigger.button_set()
    end
)

finenv.RegisterModelessDialog(BRB_dialog) 
BRB_dialog:ShowModeless()

