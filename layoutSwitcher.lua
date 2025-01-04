local trayMenu
local defaultLayout
local configFile = hs.configdir .. "/defaultLayout.conf"

local layoutMappings = {
  { systemName = "U.S.", abbreviation = "US" },
  { systemName = "U.S. International – PC", abbreviation = "US-PC" },
  { systemName = "British – PC", abbreviation = "EN-PC" },
  { systemName = "Russian – PC", abbreviation = "RU-PC" },
  { systemName = "Ukrainian", abbreviation = "UA" },
  { systemName = "French", abbreviation = "FR" },
  { systemName = "German", abbreviation = "DE" },
  { systemName = "Spanish", abbreviation = "ES" },
  { systemName = "Italian", abbreviation = "IT" },
  { systemName = "Portuguese", abbreviation = "PT" },
}

local function getSystemLanguage()
  local handle = io.popen("defaults read -g AppleLanguages")
  local result = handle:read("*a")
  handle:close()
  local language = result:match('"(.-)"')
  return language:sub(1, 2) or "en"
end

local function getDialogTexts()
  local lang = getSystemLanguage()
  if lang == "ru" then
    return {
      prompt = "Выберите раскладку по умолчанию:",
      cancel = "Выбор отменён.",
    }
  else
    return {
      prompt = "Select the default keyboard layout:",
      cancel = "Selection cancelled.",
    }
  end
end

local function getLayoutAbbreviation(layout)
  for _, mapping in ipairs(layoutMappings) do
    if mapping.systemName == layout then
      return mapping.abbreviation
    end
  end
  return layout:match("^(%S+) (%S+)") or layout:match("^(%S+)"):sub(1, 2):upper()
end

local function determineDefaultLayout()
  if hs.fs.attributes(configFile) then
    for line in io.lines(configFile) do
      return line
    end
  end

  local layouts = hs.keycodes.layouts()
  for _, mapping in ipairs(layoutMappings) do
    for _, systemLayout in ipairs(layouts) do
      if mapping.systemName == systemLayout then
        return mapping.systemName
      end
    end
  end
  return layouts[1] or "U.S."
end

local function saveDefaultLayout(layout)
  local file = io.open(configFile, "w")
  if file then
    file:write(layout)
    file:close()
  end
end

local function switchLayoutForApp(appName)
  local currentLayout = hs.keycodes.currentLayout()
  if currentLayout ~= defaultLayout then
    hs.keycodes.setLayout(defaultLayout)
  end
end

local function showLayoutSelector()
  local layouts = hs.keycodes.layouts()
  local escapedLayouts = {}
  for _, layout in ipairs(layouts) do
    table.insert(escapedLayouts, "\"" .. layout .. "\"")
  end
  local layoutsString = table.concat(escapedLayouts, ", ")

  local texts = getDialogTexts()

  local appleScript = [[
    set layouts to {]] .. layoutsString .. [[}
    set chosenLayout to (choose from list layouts with prompt "]] .. texts.prompt .. [[" default items {"]] .. defaultLayout:gsub("\"", "\\\"") .. [["} without multiple selections allowed)
    if chosenLayout is false then
        return "]] .. texts.cancel .. [["
    else
        return chosenLayout as text
    end if
  ]]

  local success, result = hs.osascript.applescript(appleScript)
  if success and result ~= texts.cancel then
    defaultLayout = result
    trayMenu:setTitle(getLayoutAbbreviation(defaultLayout))
    saveDefaultLayout(defaultLayout)
  end
end

local function createTrayMenu()
  trayMenu = hs.menubar.new()
  trayMenu:setTitle(getLayoutAbbreviation(defaultLayout))
  trayMenu:setClickCallback(function()
    showLayoutSelector()
  end)
end

defaultLayout = determineDefaultLayout()

hs.application.watcher.new(function(appName, eventType)
  if eventType == hs.application.watcher.launched then
    switchLayoutForApp(appName)
  end
end):start()

createTrayMenu()
