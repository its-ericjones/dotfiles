local localConfig = dofile(hs.configdir .. "/local.lua")
local hyper = {"cmd", "alt", "ctrl", "shift"}

-- Application launchers ------------------------------------------------------
-- Launch or focus an application; hide it when it's already frontmost.
local function bindApp(key, applicationName)
    hs.hotkey.bind(hyper, key, function()
        local application = hs.application.find(applicationName)

        if application and application:isFrontmost() then
            application:hide()
        else
            hs.application.launchOrFocus(applicationName)
        end
    end)
end

-- Hyper + key -> application
bindApp("C", "Calendar")
bindApp("G", "Google Chrome")
bindApp("M", "Messages")
bindApp("O", "Obsidian")
bindApp("R", "Reminders")
bindApp("S", "Safari")
bindApp("T", "Terminal")
bindApp("X", "Visual Studio Code")


-- Window management ---------------------------------------------------------
-- Snap the focused window to a screen half with Hyper + Vim direction keys.
local function bindWindowSnap(key, getFrame)
    hs.hotkey.bind(hyper, key, function()
        local window = hs.window.focusedWindow()
        if not window then
            return
        end

        local screenFrame = window:screen():frame()
        window:setFrame(getFrame(screenFrame))
    end)
end

bindWindowSnap("H", function(screen) -- left half
    return {x = screen.x, y = screen.y, w = screen.w / 2, h = screen.h}
end)

bindWindowSnap("J", function(screen) -- bottom half
    return {x = screen.x, y = screen.y + screen.h / 2, w = screen.w, h = screen.h / 2}
end)

bindWindowSnap("K", function(screen) -- top half
    return {x = screen.x, y = screen.y, w = screen.w, h = screen.h / 2}
end)

bindWindowSnap("L", function(screen) -- right half
    return {x = screen.x + screen.w / 2, y = screen.y, w = screen.w / 2, h = screen.h}
end)

-- Diagonal Vim motions snap windows to screen quarters.
bindWindowSnap("Y", function(screen) -- top-left quarter
    return {x = screen.x, y = screen.y, w = screen.w / 2, h = screen.h / 2}
end)

bindWindowSnap("U", function(screen) -- top-right quarter
    return {x = screen.x + screen.w / 2, y = screen.y, w = screen.w / 2, h = screen.h / 2}
end)

bindWindowSnap("B", function(screen) -- bottom-left quarter
    return {x = screen.x, y = screen.y + screen.h / 2, w = screen.w / 2, h = screen.h / 2}
end)

bindWindowSnap("N", function(screen) -- bottom-right quarter
    return {
        x = screen.x + screen.w / 2,
        y = screen.y + screen.h / 2,
        w = screen.w / 2,
        h = screen.h / 2,
    }
end)

-- Remember each window's frame so Hyper + Return can maximize and restore it.
local restoredFrames = {}

hs.hotkey.bind(hyper, "return", function()
    local window = hs.window.focusedWindow()
    if not window then
        return
    end

    local windowID = window:id()
    if restoredFrames[windowID] then
        window:setFrame(restoredFrames[windowID])
        restoredFrames[windowID] = nil
    else
        restoredFrames[windowID] = window:frame()
        window:maximize()
    end
end)

-- Move the focused window between connected displays.
local function bindMoveToDisplay(key, getDisplay)
    hs.hotkey.bind(hyper, key, function()
        local window = hs.window.focusedWindow()
        if not window then
            return
        end

        local targetDisplay = getDisplay(window:screen())
        window:moveToScreen(targetDisplay)
    end)
end

bindMoveToDisplay(",", function(display) -- previous display
    return display:previous()
end)

bindMoveToDisplay(".", function(display) -- next display
    return display:next()
end)

-- Menu-bar status -----------------------------------------------------------
-- Combine caffeine and Dock badges in one item so they don't compete for
-- limited menu-bar space.
local statusMenu = hs.menubar.new()
local caffeineActive = hs.caffeinate.get("displayIdle")
local dockBadgeCounts = {
    Messages = 0,
    Reminders = 0,
}
local toggleCaffeine

local function refreshStatusMenu()
    local indicators = {}
    if caffeineActive then
        table.insert(indicators, "☕")
    end
    if dockBadgeCounts.Messages > 0 then
        table.insert(indicators, "💬 " .. dockBadgeCounts.Messages)
    end
    if dockBadgeCounts.Reminders > 0 then
        table.insert(indicators, "✓ " .. dockBadgeCounts.Reminders)
    end

    if #indicators == 0 then
        statusMenu:removeFromMenuBar()
        return
    end

    if not statusMenu:isInMenuBar() then
        statusMenu:returnToMenuBar()
    end
    statusMenu:setTitle(table.concat(indicators, "  "))
    statusMenu:setTooltip("Hammerspoon status")
end

statusMenu:setMenu(function()
    return {
        {
            title = caffeineActive and "Disable caffeine" or "Enable caffeine",
            checked = caffeineActive,
            fn = toggleCaffeine,
        },
        {title = "-"},
        {
            title = "Open Messages (" .. dockBadgeCounts.Messages .. ")",
            disabled = dockBadgeCounts.Messages == 0,
            fn = function()
                hs.application.launchOrFocus("Messages")
            end,
        },
        {
            title = "Open Reminders (" .. dockBadgeCounts.Reminders .. ")",
            disabled = dockBadgeCounts.Reminders == 0,
            fn = function()
                hs.application.launchOrFocus("Reminders")
            end,
        },
    }
end)

-- Caffeine ------------------------------------------------------------------
-- Hyper + P toggles sleep prevention and refreshes the shared status item.
toggleCaffeine = function()
    caffeineActive = hs.caffeinate.toggle("displayIdle")
    refreshStatusMenu()
end

hs.hotkey.bind(hyper, "P", toggleCaffeine)

-- Dock badge indicators -----------------------------------------------------
-- Mirror an application's nonzero Dock badge in the shared status item.
local function monitorDockBadge(applicationName)
    local script = string.format([[
        tell application "System Events"
            tell process "Dock"
                repeat with dockItem in UI elements of list 1
                    if name of dockItem is "%s" then
                        set badgeValue to value of attribute "AXStatusLabel" of dockItem
                        if badgeValue is missing value then return ""
                        return badgeValue as text
                    end if
                end repeat
            end tell
        end tell
        return ""
    ]], applicationName)

    local function updateMenu()
        local success, badgeValue = hs.osascript.applescript(script)
        local badgeCount = success
            and tonumber(tostring(badgeValue):match("%d+")) or 0

        dockBadgeCounts[applicationName] = badgeCount
        refreshStatusMenu()
    end

    updateMenu()
    return hs.timer.doEvery(5, updateMenu)
end

-- Keep references to the timers so they continue running.
dockBadgeTimers = {
    monitorDockBadge("Messages"),
    monitorDockBadge("Reminders"),
}

-- Tailscale exit node -------------------------------------------------------
-- Use the exit node on untrusted Wi-Fi and disable it on trusted networks.
local tailscalePath = "/usr/local/bin/tailscale"
local trustedNetworks = localConfig.trustedNetworks
local tailscaleExitNode = localConfig.tailscaleExitNode
local exitNodeEnabled = nil
local tailscaleTask = nil

local function updateTailscaleExitNode()
    local networkName = hs.wifi.currentNetwork()
    -- Fail closed when macOS doesn't reveal the SSID. A nil network name can
    -- occur when Hammerspoon lacks Location Services permission.
    local shouldEnable = networkName ~= nil and not trustedNetworks[networkName]

    if shouldEnable == exitNodeEnabled then
        return
    end

    exitNodeEnabled = shouldEnable
    local exitNodeArgument = shouldEnable
        and ("--exit-node=" .. tailscaleExitNode) or "--exit-node="

    tailscaleTask = hs.task.new(tailscalePath, function(exitCode, _, errorOutput)
        if exitCode == 0 then
            local status = shouldEnable and "enabled" or "disabled"
            hs.alert.show("Tailscale exit node " .. status)
        else
            exitNodeEnabled = nil -- Retry on the next network change.
            hs.notify.new({
                title = "Tailscale exit node error",
                informativeText = errorOutput,
            }):send()
        end
    end, {"set", exitNodeArgument})

    tailscaleTask:start()
end

wifiWatcher = hs.wifi.watcher.new(updateTailscaleExitNode)
wifiWatcher:start()
updateTailscaleExitNode()

-- Clipboard history ---------------------------------------------------------
-- Keep recent text copies in memory and search them with Hyper + V. History
-- isn't saved and gets cleared whenever Hammerspoon quits or reloads.
local clipboardHistory = {}
local clipboardHistoryLimit = 50

local function addToClipboardHistory(contents)
    if not contents or contents == "" then
        return
    end

    -- Remove an older copy so repeated items appear only once, at the top.
    for index, item in ipairs(clipboardHistory) do
        if item == contents then
            table.remove(clipboardHistory, index)
            break
        end
    end

    table.insert(clipboardHistory, 1, contents)
    if #clipboardHistory > clipboardHistoryLimit then
        table.remove(clipboardHistory)
    end
end

local function clipboardChoices()
    local choices = {}

    for _, contents in ipairs(clipboardHistory) do
        local preview = contents:gsub("%s+", " ")
        if #preview > 120 then
            preview = preview:sub(1, 117) .. "..."
        end

        table.insert(choices, {
            text = preview,
            contents = contents,
        })
    end

    return choices
end

clipboardChooser = hs.chooser.new(function(choice)
    if not choice then
        return
    end

    hs.pasteboard.setContents(choice.contents)
    hs.timer.doAfter(0.1, function()
        hs.eventtap.keyStroke({"cmd"}, "V")
    end)
end)

clipboardChooser:placeholderText("Search clipboard history")
clipboardChooser:rows(10)

hs.hotkey.bind(hyper, "V", function()
    clipboardChooser:choices(clipboardChoices())
    clipboardChooser:show()
end)

addToClipboardHistory(hs.pasteboard.getContents())
clipboardWatcher = hs.pasteboard.watcher.new(addToClipboardHistory)
