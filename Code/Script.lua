ShowResearchProgressOnHUD = {}
-- Randomly generated number to start counting from, to generate IDs for translatable strings
ShowResearchProgressOnHUD.StringIdBase = 76827246

function AddResearchProgressBar(queue_count)
    local dlg = GetXDialog("HUD")
    if not dlg then return end
    if dlg['idResearchProgressContainer'] then
        -- The progress bar is already there, so this must have been called more than once. This
        -- might be a request to rebuild it, so remove the existing one and start again
        dlg['idResearchProgressContainer']:delete()
    end
    local this_mod_dir = debug.getinfo(2, "S").source:sub(2, -16)
    local left_buttons = dlg['idLeftButtons']
    local progress_bar_container = XWindow:new({
        Id = "idResearchProgressContainer",
        Margins = box(0, 0, 0, 0),
        Background = RGBA(0, 0, 0, 0),
        LayoutMethod = "HList",
    }, left_buttons)
    local progress_bar = XFrameProgress:new({
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
    }, progress_bar_container)

    -- This appears to be needed for FrameBox to take effect, otherwise the
    -- progress bar isn't correctly inset into the frame. I'm not sure why though as I thought it
    -- was about tiling an image - possibly it changes the layout model(?)
    progress_bar.idProgress:SetTileFrame(true)
    progress_bar:SetRolloverTitle(T{
        T{311, "Research"},
        UICity
    })
    progress_bar:SetRolloverText(T{
        T{
            ShowResearchProgressOnHUD.StringIdBase + 10,
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
    XText:new({
        Id = "idQueueCount",
        TextFont = "HexChoice",
        Margins = box(0, 0, 0, 1),
        TextColor = RGB(255, 255, 255),
        RolloverTextColor = RGB(255, 255, 255),
        VAlign = "bottom",
    }, progress_bar_container):SetVisible(queue_count)
    return progress_bar_container
end

function UpdateResearchProgressBar()
    if not UICity then
        return
    end
    local dlg = GetXDialog("HUD")
    local progress_bar = dlg.idResearchProgress

    -- This shouldn't ever happen, but it can't hurt to check
    if not progress_bar then
        return
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
    dlg.idQueueCount:SetText(T{
            ShowResearchProgressOnHUD.StringIdBase + 11,
            "<ResearchPoints(count)> in queue",
            count = #UICity:GetResearchQueue()
    })
end

function OnMsg.UIReady()
    local queue_count = false
    if ModConfig then
        queue_count = ModConfig:Get("ShowResearchProgressOnHUD", "QueueCount")
    end
    AddResearchProgressBar(queue_count)
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

function OnMsg.ModConfigReady()
    ModConfig:RegisterMod("ShowResearchProgressOnHUD",
        T{ShowResearchProgressOnHUD.StringIdBase, "Show Research Progress on HUD"}
    )
    ModConfig:RegisterOption("ShowResearchProgressOnHUD", "QueueCount", {
        name = T{ShowResearchProgressOnHUD.StringIdBase + 1, "Show Number in Queue"},
        desc = T{
            ShowResearchProgressOnHUD.StringIdBase + 2,
            "Show a count of the number of technologies currently in the research queue"
        },
        type = "boolean",
        default = false
    })
    -- Since this mod doesn't require ModConfig, it can't wait about for it and therefore might have
    -- already created the bar with the default settings, so we need to check
    local queue_count = ModConfig:Get("ShowResearchProgressOnHUD", "QueueCount")
    if queue_count then
        AddResearchProgressBar(queue_count)
        UpdateResearchProgressBar()
    end
end

function OnMsg.ModConfigChanged(mod_id, option_id, value)
    if mod_id == "ShowResearchProgressOnHUD" and option_id == "QueueCount" then
        AddResearchProgressBar(value)
        UpdateResearchProgressBar()
    end
end

-- The following three functions are intended to simplify the job of knowing when it's safe to start
-- inserting new items into the UI, by firing a "UIReady" message. They use the "g_UIReady" global
-- to record when this message has been sent, in order to make it possible to include the same code
-- in multiple mods without ending up with the message sent multiple times.
function OnMsg.LoadGame()
    if not UIReady then
        -- This seems a little ridiculous, but it's the only way I've found to
        -- trigger when the UI is ready after loading a game
        CreateGameTimeThread(function()
            while true do
                WaitMsg("OnRender")
                if GetXDialog("HUD") then
                    if not g_UIReady then
                        g_UIReady = true
                        Msg("UIReady")
                    end
                    break
                end
            end
        end)
    end
end
function OnMsg.NewMapLoaded()
    if not g_UIReady then
        g_UIReady = true
        Msg("UIReady")
    end
end
-- If we change maps (via loading or returning to the main menu and stating a new game) then the UI
-- will be rebuilt, so we need to allow UIReady to fire again when the time comes.
function OnMsg.DoneMap()
    g_UIReady = false
end
