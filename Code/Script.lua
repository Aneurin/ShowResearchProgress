function AddResearchProgressBar()
    local dlg = GetXDialog("HUD")
    if dlg['idResearchProgress'] then
        -- The progress bar is already there, so this must have been called more
        -- than once
        return
    end
    local this_mod_dir = debug.getinfo(2, "S").source:sub(2, -16)
    local left_buttons = dlg['idLeftButtons']
    XFrameProgress:new({
        Id = "idResearchProgress",
        Image = "UI/HUD/day_pad.tga",
        Margins = box(0, 0, 0, 1),
        FrameBox = box(5, 0, 5, 0),
        VAlign = "bottom",
        HandleMouse = true,
        RolloverTemplate = "Rollover",
        ProgressImage = this_mod_dir.."UI/progress_bar.tga",
        MinWidth = 146,
        MaxWidth = 146,
        MaxProgress = 100,
        SeparatorImage = "UI/HUD/day_shine.tga",
        SeparatorOffset = 4;
    }, left_buttons)

    local progress_bar = dlg['idResearchProgress']
    -- This appears to be needed for FrameBox to take effect, otherwise the
    -- progress bar isn't correctly inset into the frame
    progress_bar.idProgress:SetTileFrame(true)
    progress_bar:SetRolloverTitle(T{
        T{311, "Research"},
        UICity
    })
    progress_bar:SetRolloverText(T{
        T{
            "Manage the research of new Technologies.<newline><newline>Current Research: <em><name></em><newline><left>Research progress: <em><percent(progress)></em>",
            name = function()
                local current_research = UICity and UICity:GetResearchInfo()
                if not current_research or not TechDef[current_research].display_name then
                    return (T({6868, "None"}))
                end
                return TechDef[current_research].display_name
            end,
            progress = function()
                return UICity:GetResearchProgress()
            end
        },
        UICity
    })
    progress_bar:SetRolloverHint(T{
        T{
            4005,
            "<em><ShortcutName('actionResearchScreen')></em> - open Research Screen"
        },
        UICity
    })
    return progress_bar
end

function UpdateResearchProgressBar()
    if not UICity then
        return
    end
    local dlg = GetXDialog("HUD")
    local progress_bar = dlg['idResearchProgress']

    -- This shouldn't ever happen, but it can't hurt to check
    if not progress_bar then
        progress_bar = AddResearchProgressBar()
    end

    -- When you mouse over an element, its tooltip ('rollover') is updated
    -- automatically, but to have it update while it's open, it needs to be
    -- triggered
    XUpdateRolloverWindow(progress_bar)
    local this_mod_dir = debug.getinfo(2, "S").source:sub(2, -16)
    local current_research = UICity:GetResearchInfo()
    if current_research and TechDef[current_research].display_name then
        progress_bar:SetProgress(UICity:GetResearchProgress())
        progress_bar:SetProgressImage(this_mod_dir.."UI/progress_bar.tga")
        progress_bar:SetSeparatorImage("UI/HUD/day_shine.tga")
    else
        progress_bar:SetProgress(100)
        progress_bar:SetProgressImage(this_mod_dir.."UI/progress_bar_none.tga")
        progress_bar:SetSeparatorImage("")
    end
end

function OnMsg.UIReady()
    AddResearchProgressBar()
    UpdateResearchProgressBar()
end
function OnMsg.NewHour()
    UpdateResearchProgressBar()
end
function OnMsg.TechResearched()
    UpdateResearchProgressBar()
end
function OnMsg.ResearchQueueChange()
    UpdateResearchProgressBar()
end

function OnMsg.LoadGame()
    -- This seems a little ridiculous, but it's the only way I've found to
    -- trigger when the UI is ready after loading a game
    CreateGameTimeThread(function()
        while true do
            WaitMsg("OnRender")
            if GetXDialog("HUD") then
                Msg("UIReady")
                break
            end
        end
    end)
end
function OnMsg.NewMapLoaded()
    Msg("UIReady")
end
