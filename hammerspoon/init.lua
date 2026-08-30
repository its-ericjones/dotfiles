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

-- Caffeine ------------------------------------------------------------------
-- Hyper + P toggles sleep prevention. The menu-bar indicator isn't visible
-- unless caffeine is active.
local caffeineMenu = nil

local function updateCaffeineMenu(isActive)
    if isActive then
        caffeineMenu = caffeineMenu or hs.menubar.new()
        caffeineMenu:setTitle("☕")
        caffeineMenu:setTooltip("Caffeine is active")
    elseif caffeineMenu then
        caffeineMenu:delete()
        caffeineMenu = nil
    end
end

local function toggleCaffeine()
    local isActive = hs.caffeinate.toggle("displayIdle")
    updateCaffeineMenu(isActive)
end

hs.hotkey.bind(hyper, "P", toggleCaffeine)
updateCaffeineMenu(hs.caffeinate.get("displayIdle"))

-- Dock badge indicators -----------------------------------------------------
-- Mirror an application's Dock badge in the menu bar. The item isn't shown when
-- its badge is empty or zero.
local function monitorDockBadge(applicationName, icon)
    local menu = nil
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

        if badgeCount > 0 then
            if not menu then
                menu = hs.menubar.new()
                menu:setClickCallback(function()
                    hs.application.launchOrFocus(applicationName)
                end)
            end

            menu:setTitle(icon .. " " .. badgeCount)
            menu:setTooltip(applicationName .. ": " .. badgeCount)
        elseif menu then
            menu:delete()
            menu = nil
        end
    end

    updateMenu()
    return hs.timer.doEvery(5, updateMenu)
end

-- Keep references to the timers so they continue running.
dockBadgeTimers = {
    monitorDockBadge("Messages", "💬"),
    monitorDockBadge("Reminders", "✓"),
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
