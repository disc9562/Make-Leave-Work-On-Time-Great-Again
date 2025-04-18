-- 整合版工具：倒數計時器 + 上班時間追蹤器 + 下班時間顯示
-- 由 Claude 於 2025-04-16 整合

-- =====================================================
-- 初始化共用變數
-- =====================================================
local tools = {}

-- 工作時間設定 (小時)
tools.workHours = 9  -- 工作時長，可以根據需要修改

-- =====================================================
-- 第一部分：簡單的 60 秒倒數計時器
-- =====================================================

-- 初始化倒數計時器變數
tools.countdownTimer = nil       -- 計時器物件
tools.countdownCanvas = nil      -- 顯示窗口
tools.dragWatcher = nil          -- 拖動事件監聽器
tools.isDragging = false         -- 拖動狀態追蹤
tools.dragStartPos = nil         -- 拖動開始位置
tools.origCanvasPos = nil        -- 原始窗口位置
tools.timeTextIndex = 3          -- 時間文字元素的索引 (第3個元素)
tools.logFolderPath = "logs/" -- 日誌文件夾路徑
local file_path = "times_up.mp3"

-- 啟動倒數計時
function tools.startCountdown(seconds)
    -- 如果未提供時間，預設為60秒
    seconds = seconds or 60
    
    -- 如果已有計時器運行，先停止它
    if tools.countdownTimer then
        tools.countdownTimer:stop()
        tools.countdownTimer = nil
    end
    
    -- 如果已有窗口，先刪除它
    if tools.countdownCanvas then
        tools.countdownCanvas:delete()
        tools.countdownCanvas = nil
    end
    
    -- 如果有舊的拖動事件監聽器，先停止它
    if tools.dragWatcher then
        tools.dragWatcher:stop()
        tools.dragWatcher = nil
    end
    
    -- 創建新的顯示窗口
    tools.createCountdownDisplay()
    
    -- 設置初始時間
    local remainingSeconds = seconds
    tools.updateDisplay(remainingSeconds)
    
    -- 創建計時器，每秒更新一次
    tools.countdownTimer = hs.timer.doEvery(1, function()
        remainingSeconds = remainingSeconds - 1
        
        -- 更新顯示
        tools.updateDisplay(remainingSeconds)
        
        -- 當倒數結束時
        if remainingSeconds <= 0 then
            -- 停止計時器
            tools.countdownTimer:stop()
            tools.countdownTimer = nil
            
            -- 播放提示音效
            tools.playCompletionSound()
            
            -- 顯示完成訊息
            hs.alert.show("下班啦！！！", 2)
            
            -- 短暫顯示後關閉窗口
            hs.timer.doAfter(3, function()
                if tools.countdownCanvas then
                    tools.countdownCanvas:delete()
                    tools.countdownCanvas = nil
                end
                
                -- 清理拖動事件監聽器
                if tools.dragWatcher then
                    tools.dragWatcher:stop()
                    tools.dragWatcher = nil
                end
            end)
        end
    end)
    
    -- 顯示開始提示
    hs.alert.show("開始倒數 " .. seconds .. " 秒", 1)
end

-- 播放完成提示音效
function tools.playCompletionSound()
    -- 使用系統音效
    hs.sound.getByName("Glass"):play()
end

-- 創建倒數計時顯示窗口
function tools.createCountdownDisplay()
    -- 創建新的 canvas
    tools.countdownCanvas = hs.canvas.new({x=0, y=0, w=200, h=100})
    
    -- 設置窗口層級和行為
    tools.countdownCanvas:level(hs.canvas.windowLevels.overlay)
    tools.countdownCanvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces)
    
    -- 添加背景
    tools.countdownCanvas:appendElements({
        type = "rectangle",
        action = "fill",
        fillColor = {alpha = 0.8, red = 0.2, green = 0.2, blue = 0.3},
        roundedRectRadii = {xRadius = 10, yRadius = 10},
    })
    
    -- 添加標題
    tools.countdownCanvas:appendElements({
        type = "text",
        text = "倒數計時",
        textSize = 16,
        textColor = {white = 1},
        textAlignment = "center",
        frame = {x = 0, y = 15, w = 200, h = 20}
    })
    
    -- 添加時間顯示 (這是第3個元素，索引為3)
    tools.countdownCanvas:appendElements({
        id = "timeText",
        type = "text",
        text = "60",
        textSize = 36,
        textColor = {red = 1, green = 1, blue = 0.3},
        textAlignment = "center",
        frame = {x = 0, y = 40, w = 200, h = 50}
    })
    
    -- 置於屏幕中央
    local screen = hs.screen.primaryScreen()
    local screenFrame = screen:frame()
    tools.countdownCanvas:frame({
        x = screenFrame.x + (screenFrame.w - 200) / 2,
        y = screenFrame.y + (screenFrame.h - 100) / 2,
        w = 200,
        h = 100
    })
    
    -- 啟用鼠標事件消費而不透過滑鼠
    tools.countdownCanvas:wantsLayer(true)
    tools.countdownCanvas:canvasMouseEvents(true, true, false, false)
    tools.countdownCanvas:mouseCallback(function(canvas, message, point)
        return true -- 僅消費事件，不透過
    end)
    
    -- 設置拖動功能 (使用全局事件監聽)
    tools.setupDragging()
    
    -- 顯示窗口
    tools.countdownCanvas:show()
end

-- 設置拖動功能
function tools.setupDragging()
    -- 清理現有的拖動監聽器
    if tools.dragWatcher then
        tools.dragWatcher:stop()
        tools.dragWatcher = nil
    end
    
    -- 設置全局事件捕獲
    tools.dragWatcher = hs.eventtap.new({
        hs.eventtap.event.types.leftMouseDown,
        hs.eventtap.event.types.leftMouseDragged,
        hs.eventtap.event.types.leftMouseUp
    }, function(event)
        if not tools.countdownCanvas then return false end
        
        local type = event:getType()
        local location = event:location()
        local canvasFrame = tools.countdownCanvas:frame()
        
        -- 檢查滑鼠是否在窗口內
        local isInside = (location.x >= canvasFrame.x and
                         location.x <= canvasFrame.x + canvasFrame.w and
                         location.y >= canvasFrame.y and
                         location.y <= canvasFrame.y + canvasFrame.h)
        
        -- 滑鼠按下時記錄初始位置
        if type == hs.eventtap.event.types.leftMouseDown and isInside then
            tools.isDragging = true
            tools.dragStartPos = location
            tools.origCanvasPos = canvasFrame
            return true  -- 消費事件，阻止穿透
            
        -- 拖動時移動窗口
        elseif type == hs.eventtap.event.types.leftMouseDragged and tools.isDragging then
            local dx = location.x - tools.dragStartPos.x
            local dy = location.y - tools.dragStartPos.y
            
            tools.countdownCanvas:frame({
                x = tools.origCanvasPos.x + dx,
                y = tools.origCanvasPos.y + dy,
                w = tools.origCanvasPos.w,
                h = tools.origCanvasPos.h
            })
            return true  -- 消費事件，阻止穿透
            
        -- 滑鼠釋放時結束拖動
        elseif type == hs.eventtap.event.types.leftMouseUp and tools.isDragging then
            tools.isDragging = false
            return true  -- 消費事件，阻止穿透
        end
        
        -- 只消費窗口内的事件
        return isInside
    end)
    
    -- 啟動事件監聽
    tools.dragWatcher:start()
end

-- 更新倒數計時顯示
function tools.updateDisplay(seconds)
    if not tools.countdownCanvas then return end
    
    -- 更新時間文本
    local color
    if seconds <= 10 then
        -- 最後 10 秒使用紅色
        color = {red = 1, green = 0, blue = 0}
    elseif seconds <= 30 then
        -- 30-10 秒使用橙色
        color = {red = 1, green = 0.6, blue = 0}
    else
        -- 其他時間使用黃色
        color = {red = 1, green = 1, blue = 0.3}
    end
    
    -- 格式化時間顯示
    local displayText
    if seconds >= 60 then
        local minutes = math.floor(seconds / 60)
        local remainingSeconds = seconds % 60
        displayText = string.format("%d:%02d", minutes, remainingSeconds)
    else
        displayText = tostring(seconds)
    end
    
    -- 直接使用已知的元素索引
    tools.countdownCanvas:elementAttribute(tools.timeTextIndex, "text", displayText)
    tools.countdownCanvas:elementAttribute(tools.timeTextIndex, "textColor", color)
end

-- =====================================================
-- 第二部分：解鎖螢幕時紀錄上班時間
-- =====================================================

-- 初始化工作時間追蹤器變數
tools.workTimeLogger = nil                                        -- 事件監聽器
tools.isScreenLocked = false                                      -- 螢幕鎖定狀態
tools.offTimeDisplay = nil                                        -- 下班時間顯示窗口
tools.offTimeDragWatcher = nil                                    -- 下班時間窗口拖動監聽器
tools.isOffTimeDragging = false                                   -- 下班時間窗口拖動狀態
tools.offTimeDragStartPos = nil                                   -- 下班時間窗口拖動開始位置
tools.offTimeOrigPos = nil                                        -- 下班時間窗口原始位置
tools.offTimeTimer = nil                                          -- 下班提醒計時器
tools.offTimeReminderMinutes = 5                                  -- 下班前幾分鐘提醒

-- 計算下班時間
function tools.calculateOffTime(startTimeStr)
    -- 解析上班時間
    local hour, min, sec = startTimeStr:match("(%d+):(%d+):(%d+)")
    
    if not hour then 
        return nil 
    end
    
    hour = tonumber(hour)
    min = tonumber(min)
    sec = tonumber(sec)
    
    -- 計算下班時間
    local offHour = hour + tools.workHours
    if offHour >= 24 then
        offHour = offHour - 24
    end
    
    -- 格式化下班時間
    return string.format("%02d:%02d:%02d", offHour, min, sec)
end

-- 播放自定義音效
function tools.playCustomSound(soundFile)
    -- 檢查音效檔案是否存在
    if hs.fs.attributes(soundFile) then
        local sound = hs.sound.getByFile(soundFile)
        if sound then
            sound:play()
        else
            print("無法加載音效檔案: " .. soundFile)
        end
    else
        print("音效檔案不存在: " .. soundFile)
    end
end

-- 設置下班時間提醒
function tools.setupOffTimeReminder(offTimeStr)
    -- 如果已有計時器，先清除
    if tools.offTimeTimer then
        tools.offTimeTimer:stop()
        tools.offTimeTimer = nil
    end
    
    -- 解析下班時間
    local offHour, offMin, offSec = offTimeStr:match("(%d+):(%d+):(%d+)")
    if not offHour then return end
    
    offHour = tonumber(offHour)
    offMin = tonumber(offMin)
    offSec = tonumber(offSec)
    
    -- 獲取當前時間
    local now = os.time()
    local nowDate = os.date("*t", now)
    
    -- 設置下班時間
    local offTime = os.time({
        year = nowDate.year,
        month = nowDate.month,
        day = nowDate.day,
        hour = offHour,
        min = offMin,
        sec = offSec
    })
    
    -- 設置提醒時間（下班前5分鐘）
    local reminderTime = offTime - (tools.offTimeReminderMinutes * 60)
    
    -- 如果提醒時間已經過了，不設置提醒
    if reminderTime <= now then
        print("下班提醒時間已過，不設置提醒")
        return
    end
    
    -- 計算多少秒後提醒
    local secondsUntilReminder = reminderTime - now
    print("下班提醒將在 " .. secondsUntilReminder .. " 秒後觸發")
    
    -- 設置計時器
    tools.offTimeTimer = hs.timer.doAfter(secondsUntilReminder, function()
        -- 播放提示音效
        tools.playCustomSound(file_path)
        -- hs.sound.getByName("Submarine"):play()
        
        -- 顯示提醒對話框
        hs.alert.show("還有 " .. tools.offTimeReminderMinutes .. " 分鐘就下班了！", 5)
        
        -- 開始倒數 300 秒
        tools.startCountdown(300)
    end)
end

-- 設置下班時間窗口的拖動功能
function tools.setupOffTimeDragging()
    -- 如果已經有拖動監聽器，先停止它
    if tools.offTimeDragWatcher then
        tools.offTimeDragWatcher:stop()
        tools.offTimeDragWatcher = nil
    end
    
    -- 啟用事件消費以防穿透
    tools.offTimeDisplay:wantsLayer(true)
    tools.offTimeDisplay:canvasMouseEvents(true, true, false, false)
    tools.offTimeDisplay:mouseCallback(function(canvas, message, point)
        return true -- 僅消費事件，不透過
    end)
    
    -- 創建下班時間窗口的拖動監聽器
    tools.offTimeDragWatcher = hs.eventtap.new({
        hs.eventtap.event.types.leftMouseDown,
        hs.eventtap.event.types.leftMouseDragged,
        hs.eventtap.event.types.leftMouseUp
    }, function(event)
        if not tools.offTimeDisplay then return false end
        
        local type = event:getType()
        local location = event:location()
        local displayFrame = tools.offTimeDisplay:frame()
        
        -- 檢查滑鼠是否在窗口內
        local isInside = (location.x >= displayFrame.x and
                         location.x <= displayFrame.x + displayFrame.w and
                         location.y >= displayFrame.y and
                         location.y <= displayFrame.y + displayFrame.h)
        
        -- 滑鼠按下時記錄初始位置
        if type == hs.eventtap.event.types.leftMouseDown and isInside then
            tools.isOffTimeDragging = true
            tools.offTimeDragStartPos = location
            tools.offTimeOrigPos = displayFrame
            return true
            
        -- 拖動時移動窗口
        elseif type == hs.eventtap.event.types.leftMouseDragged and tools.isOffTimeDragging then
            local dx = location.x - tools.offTimeDragStartPos.x
            local dy = location.y - tools.offTimeDragStartPos.y
            
            tools.offTimeDisplay:frame({
                x = tools.offTimeOrigPos.x + dx,
                y = tools.offTimeOrigPos.y + dy,
                w = displayFrame.w,
                h = displayFrame.h
            })
            return true
            
        -- 滑鼠釋放時結束拖動
        elseif type == hs.eventtap.event.types.leftMouseUp and tools.isOffTimeDragging then
            tools.isOffTimeDragging = false
            return true
        end
        
        -- 只消費窗口内的事件
        return isInside
    end)
    
    -- 啟動事件監聽
    tools.offTimeDragWatcher:start()
end

-- 顯示下班時間在右上角
function tools.showOffTimeDisplay()
    -- 如果已有顯示窗口，先刪除它
    if tools.offTimeDisplay then
        tools.offTimeDisplay:delete()
        tools.offTimeDisplay = nil
    end
    
    -- 如果有拖動監聽器，先停止它
    if tools.offTimeDragWatcher then
        tools.offTimeDragWatcher:stop()
        tools.offTimeDragWatcher = nil
    end
    
    -- 獲取當前日期
    local currentDate = os.date("%Y-%m-%d")
    local todayLogFile = tools.logFolderPath .. currentDate .. ".log"
    
    -- 檢查今天的上班記錄
    local file = io.open(todayLogFile, "r")
    if not file then
        return -- 如果沒有上班記錄，不顯示下班時間
    end
    
    -- 讀取上班時間
    local content = file:read("*all")
    file:close()
    
    local startTime = content:match("上班時間: (%d+:%d+:%d+)")
    if not startTime then
        return -- 如果找不到上班時間，不顯示下班時間
    end
    
    -- 計算下班時間
    local offTime = tools.calculateOffTime(startTime)
    if not offTime then
        return -- 如果計算失敗，不顯示下班時間
    end
    
    -- 創建顯示窗口
    local screen = hs.screen.primaryScreen()
    local screenFrame = screen:frame()
    
    tools.offTimeDisplay = hs.canvas.new({
        x = screenFrame.w - 180, 
        y = 10, 
        w = 170, 
        h = 60
    })
    
    -- 設置窗口層級和行為
    tools.offTimeDisplay:level(hs.canvas.windowLevels.overlay)
    tools.offTimeDisplay:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces)
    
    -- 添加背景
    tools.offTimeDisplay:appendElements({
        type = "rectangle",
        action = "fill",
        fillColor = {alpha = 0.8, red = 0.1, green = 0.2, blue = 0.3},
        roundedRectRadii = {xRadius = 8, yRadius = 8},
    })
    
    -- 添加標題
    tools.offTimeDisplay:appendElements({
        type = "text",
        text = "上班時間: " .. startTime,
        textSize = 12,
        textColor = {white = 0.9},
        textAlignment = "center",
        frame = {x = 0, y = 10, w = 170, h = 20}
    })
    
    -- 添加下班時間
    tools.offTimeDisplay:appendElements({
        type = "text",
        text = "下班時間: " .. offTime,
        textSize = 14,
        textColor = {red = 1, green = 0.8, blue = 0.3},
        textAlignment = "center",
        frame = {x = 0, y = 30, w = 170, h = 25}
    })
    
    -- 設置拖動功能
    tools.setupOffTimeDragging()
    
    -- 顯示窗口
    tools.offTimeDisplay:show()
    
    -- 設置下班提醒
    tools.setupOffTimeReminder(offTime)
end

-- 記錄上班時間
function tools.logWorkTime()
    local success, errorMsg = os.execute("mkdir -p '" .. tools.logFolderPath .. "'")
    if not success then
        hs.alert.show("無法創建日誌資料夾: " .. (errorMsg or ""), 3)
        return
    end
    -- 獲取當前日期和時間
    local currentDate = os.date("%Y-%m-%d")
    local currentTime = os.date("%H:%M:%S")
    
    -- 檢查今天的日誌文件是否已存在
    local todayLogFile = tools.logFolderPath .. currentDate .. ".log"
    local file = io.open(todayLogFile, "r")


    if file then
        -- 文件已存在，說明今天已記錄
        file:close()
        hs.alert.show("今天已記錄上班時間", 2)
        -- 顯示下班時間
        tools.showOffTimeDisplay()
        return
    end
    
    -- 創建今天的日誌文件
    file = io.open(todayLogFile, "w")
    if file then
        file:write("上班時間: " .. currentTime .. "\n記錄方式: 解鎖螢幕\n")
        file:close()
        hs.alert.show("已記錄上班時間: " .. currentTime, 2)
        -- 顯示下班時間
        tools.showOffTimeDisplay()
    else
        hs.alert.show("無法創建日誌文件！", 3)
    end
end

-- 監聽螢幕解鎖事件
function tools.startWorkTimeTracker()
    -- 停止現有的監聽器
    if tools.workTimeLogger then
        tools.workTimeLogger:stop()
        tools.workTimeLogger = nil
    end
    
    -- 創建屏幕鎖定狀態監聽器
    tools.workTimeLogger = hs.caffeinate.watcher.new(function(event)
        if event == hs.caffeinate.watcher.screensDidLock then
            -- 螢幕被鎖定
            tools.isScreenLocked = true
            hs.alert.show("螢幕已鎖定", 1)
        elseif event == hs.caffeinate.watcher.screensDidUnlock then
            -- 螢幕被解鎖
            if tools.isScreenLocked then
                -- 只有之前是鎖定狀態才嘗試記錄
                tools.logWorkTime()
            end
            tools.isScreenLocked = false
        elseif event == hs.caffeinate.watcher.systemDidWake then
            -- 系統喚醒時，可能也需要記錄
            hs.alert.show("系統已喚醒", 1)
            -- 延遲一點記錄，確保系統已完全喚醒
            hs.timer.doAfter(5, function()
                if not tools.isScreenLocked then
                    tools.logWorkTime()
                end
            end)
        end
    end)
    
    -- 啟動監聽器
    tools.workTimeLogger:start()
    hs.alert.show("上班時間追蹤已啟動", 2)
    
    -- 檢查是否已有今天的記錄，如果有則顯示下班時間
    tools.showOffTimeDisplay()
end

-- 手動記錄當前時間為上班時間（強制覆蓋）
function tools.manualLogWorkTime()
    local success, errorMsg = os.execute("mkdir -p '" .. tools.logFolderPath .. "'")
    if not success then
        hs.alert.show("無法創建日誌資料夾: " .. (errorMsg or ""), 3)
        return
    end
    -- 獲取當前日期和時間
    local currentDate = os.date("%Y-%m-%d")
    local currentTime = os.date("%H:%M:%S")
    
    -- 創建或覆蓋今天的日誌文件
    local todayLogFile = tools.logFolderPath .. currentDate .. ".log"
    local file = io.open(todayLogFile, "w")


    if file then
        file:write("上班時間: " .. currentTime .. "\n記錄方式: 手動記錄\n")
        file:close()
        hs.alert.show("已手動記錄上班時間: " .. currentTime, 2)
        -- 更新下班時間顯示
        tools.showOffTimeDisplay()
    else
        hs.alert.show("無法創建日誌文件！", 3)
    end
end

-- 查看今天的記錄
function tools.checkTodayLog()
    -- 獲取當前日期
    local currentDate = os.date("%Y-%m-%d")
    local todayLogFile = tools.logFolderPath .. currentDate .. ".log"
    
    -- 檢查今天的日誌文件是否存在
    local file = io.open(todayLogFile, "r")
    if not file then
        hs.alert.show("今天尚未記錄上班時間", 2)
        return
    end
    
    -- 讀取文件內容
    local content = file:read("*all")
    file:close()
    
    -- 提取上班時間
    local time = content:match("上班時間: (%d+:%d+:%d+)")
    local method = content:match("記錄方式: (.+)")
    
    if time then
        local offTime = tools.calculateOffTime(time)
        local offTimeText = offTime and ("，預計下班時間: " .. offTime) or ""
        hs.alert.show("今天的上班時間是: " .. time .. offTimeText .. " (" .. (method or "未知") .. ")", 4)
    else
        hs.alert.show("日誌格式錯誤", 2)
    end
    
    -- 確保下班時間顯示正常
    tools.showOffTimeDisplay()
end

-- 修改工作時長並更新下班時間
function tools.changeWorkHours(hours)
    if type(hours) ~= "number" or hours <= 0 then
        hs.alert.show("請提供有效的工作時長（小時）", 2)
        return
    end
    
    tools.workHours = hours
    hs.alert.show("工作時長已更新為 " .. hours .. " 小時", 2)
    
    -- 更新下班時間顯示
    tools.showOffTimeDisplay()
end

-- 設置下班前提醒時間（分鐘）
function tools.setReminderMinutes(minutes)
    if type(minutes) ~= "number" or minutes <= 0 then
        hs.alert.show("請提供有效的提醒時間（分鐘）", 2)
        return
    end
    
    tools.offTimeReminderMinutes = minutes
    hs.alert.show("下班提醒時間已設為下班前 " .. minutes .. " 分鐘", 2)
    
    -- 更新下班時間顯示和提醒
    tools.showOffTimeDisplay()
end

-- =====================================================
-- 綁定快捷鍵與初始化
-- =====================================================

-- 綁定倒數計時器快捷鍵 (Cmd+Alt+C)
hs.hotkey.bind({"cmd", "alt"}, "C", function() tools.startCountdown(60) end)

-- 綁定上班時間追蹤器快捷鍵
-- Cmd+Alt+W: 手動記錄上班時間
-- Cmd+Alt+L: 查看今天的記錄
hs.hotkey.bind({"cmd", "alt"}, "W", tools.manualLogWorkTime)
hs.hotkey.bind({"cmd", "alt"}, "L", tools.checkTodayLog)

-- 初始化上班時間追蹤器
tools.startWorkTimeTracker()

-- 顯示通知
hs.alert.show("工具集已啟動\n\n倒數計時器: Cmd+Alt+C\n手動記錄上班時間: Cmd+Alt+W\n查看今天上班記錄: Cmd+Alt+L\n\n已設置下班前 " .. tools.offTimeReminderMinutes .. " 分鐘提醒", 5)

-- 返回工具集
return tools