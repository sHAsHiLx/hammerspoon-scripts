-- Принудительная загрузка модулей
hs.keycodes.currentLayout()
hs.application.watcher.new(function() end):stop()
hs.osascript.applescript("return \"test\"")
hs.timer.doAfter(1, function() end)
hs.menubar.new():delete()

-- Настройки
local debugMode = false  -- Установите true, чтобы включить отладочные сообщения

-- Переменные
local trayMenu
local defaultLayout
local configFile = hs.configdir .. "/defaultLayout.conf"
local watcher
local monitorTimer

-- Маппинг раскладок
local layoutMappings = {
  { systemName = "U.S.", abbreviation = "US" },
  { systemName = "U.S. International – PC", abbreviation = "US-PC" },
  { systemName = "British", abbreviation = "GB" },
  { systemName = "British – PC", abbreviation = "GB-PC" },
  { systemName = "Russian – PC", abbreviation = "RU-PC" },
  { systemName = "Ukrainian", abbreviation = "UA" },
  { systemName = "French", abbreviation = "FR" },
  { systemName = "German", abbreviation = "DE" },
  { systemName = "Spanish", abbreviation = "ES" },
  { systemName = "Italian", abbreviation = "IT" },
  { systemName = "Portuguese", abbreviation = "PT" },
  { systemName = "Dutch", abbreviation = "NL" },
  { systemName = "Polish", abbreviation = "PL" },
  { systemName = "Turkish", abbreviation = "TR" },
  { systemName = "Chinese – Simplified", abbreviation = "CN-ZH" },
  { systemName = "Chinese – Traditional", abbreviation = "CN-TR" },
  { systemName = "Japanese", abbreviation = "JA" },
  { systemName = "Korean", abbreviation = "KO" },
  { systemName = "Arabic", abbreviation = "AR" },
  { systemName = "Hebrew", abbreviation = "HE" },
}

-- Вспомогательные функции
local function debugPrint(message)
  if debugMode then
    print(message)
  end
end

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
    local message = getSystemLanguage() == "ru"
        and ("Приложение запущено: " .. appName .. ", установлена раскладка: " .. defaultLayout)
        or ("Application launched: " .. appName .. ", layout set to: " .. defaultLayout)
    print(message)  -- Гарантированный вывод сообщения в консоль
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
    activate
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
    debugPrint(getSystemLanguage() == "ru" and ("Раскладка по умолчанию обновлена: " .. defaultLayout) or ("Default layout updated to: " .. defaultLayout))
  else
    debugPrint(getSystemLanguage() == "ru" and "Выбор отменён или произошла ошибка." or "Selection cancelled or an error occurred.")
  end
end

local function createTrayMenu()
  trayMenu = hs.menubar.new()
  trayMenu:setTitle(getLayoutAbbreviation(defaultLayout))
  trayMenu:setClickCallback(function()
    showLayoutSelector()
  end)
end

local function restartWatcher()
  if watcher then watcher:stop() end
  watcher = hs.application.watcher.new(function(appName, eventType)
    if eventType == hs.application.watcher.launched then
      switchLayoutForApp(appName)
    end
  end)
  watcher:start()
  debugPrint(getSystemLanguage() == "ru" and "Наблюдатель приложений перезапущен." or "Application watcher restarted.")
end

local function monitorHealth()
  if not watcher or type(watcher.isRunning) ~= "function" or not watcher:isRunning() then
    debugPrint(getSystemLanguage() == "ru" and "Перезапуск наблюдателя приложений." or "Restarting application watcher.")
    restartWatcher()
  end
  if not monitorTimer or type(monitorTimer.running) ~= "function" or not monitorTimer:running() then
    debugPrint(getSystemLanguage() == "ru" and "Таймер мониторинга мёртв. Перезапуск." or "Monitor timer is dead. Restarting.")
    monitorTimer = hs.timer.doEvery(60, monitorHealth)
  end
end

-- Инициализация
defaultLayout = determineDefaultLayout()
createTrayMenu()
restartWatcher()

monitorTimer = hs.timer.doEvery(60, monitorHealth)
