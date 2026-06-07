-- [Startup Sound Injector Code Start]
pcall(function()
    local File = luajava.bindClass("java.io.File")
    local sound_path = "/sdcard/解说/Plugins/Smart TV Created By A Brothers/Smart TV Created By A Brothers created by A brothers.mp3"
    if luajava.new(File, sound_path).exists() then
        if startup_sound_mp ~= nil then
            pcall(function() startup_sound_mp.release() end)
        end
        local MediaPlayer = luajava.bindClass("android.media.MediaPlayer")
        startup_sound_mp = luajava.new(MediaPlayer)
        startup_sound_mp.setDataSource(sound_path)
        startup_sound_mp.setOnCompletionListener(luajava.createProxy("android.media.MediaPlayer$OnCompletionListener", {
            onCompletion = function(mediaPlayer)
                pcall(function() 
                    mediaPlayer.release() 
                    startup_sound_mp = nil
                end)
            end
        }))
        startup_sound_mp.prepare()
        startup_sound_mp.start()
    end
end)
-- [Startup Sound Injector Code End]\nrequire "import"
import "android.widget.*"
import "android.view.*"
import "android.view.accessibility.AccessibilityEvent"
import "android.webkit.WebView"
import "android.webkit.WebViewClient"
import "android.webkit.WebChromeClient"
import "android.webkit.WebSettings"
import "android.app.*"
import "android.os.*"
import "java.lang.Long"
import "android.content.pm.ActivityInfo"
import "android.content.Intent"
import "android.net.Uri"
import "android.widget.FrameLayout"
import "android.graphics.drawable.ColorDrawable"
import "android.content.DialogInterface" 

local mainDialog = nil
local settingsDialog = nil
local channelsDialog = nil 
local newsDialog = nil     
local aryNewsDialog = nil  
local geoNewsDialog = nil  
local religiousDialog = nil
local sportsDialog = nil
local kidsDialog = nil
local favoritesDialog = nil 
local aboutDialog = nil

-- لوڈنگ اسکرین کے تصادم کو روکنے کے لیے ٹریکر
local currentLoadId = 0
_G.isChannelLoading = false 

local playerDialog = _G.SmartTV_PlayerDialog
local playerMainContainer = nil 
local myWebView = _G.SmartTV_MyWebView
local isFullScreen = _G.SmartTV_IsFullScreen or false 
if _G.SmartTV_IsPlayerMinimized == nil then _G.SmartTV_IsPlayerMinimized = false end

local txtNowPlaying = _G.SmartTV_TxtNowPlaying
local controlsParent = _G.SmartTV_ControlsParent
local webContainer = _G.SmartTV_WebContainer
local portraitHeight = _G.SmartTV_PortraitHeight or 0

local customViewContainer = nil
local customViewCallback = nil
local mCustomView = nil

-- Preferences Configuration
local pref = service.getSharedPreferences("SmartTV_Prefs", 0)
local audioModeSaved = pref.getInt("isAudioMode", 0)
_G.isAudioOnlyMode = (audioModeSaved == 1)

local bgPlaySaved = pref.getInt("isBackgroundPlayMode", 1) 
_G.isBackgroundPlayEnabled = (bgPlaySaved == 1)

_G.currentVolumeMultiplier = 1.0 
_G.volIdx = 1
_G.qualityIdx = 1
_G.selectedQuality = "Auto"

-- فیورٹ لسٹ لاجک
if not _G.favoritesList then
  _G.favoritesList = {}
  local count = pref.getInt("favorites_count", 0)
  for i = 1, count do
    local name = pref.getString("fav_name_" .. i, "")
    local url = pref.getString("fav_url_" .. i, "")
    if name ~= "" and url ~= "" then
      table.insert(_G.favoritesList, {name = name, url = url})
    end
  end
end

local function saveFavorites()
  local editor = pref.edit()
  local oldCount = pref.getInt("favorites_count", 0)
  for i = 1, oldCount do
    editor.remove("fav_name_" .. i)
    editor.remove("fav_url_" .. i)
  end
  editor.putInt("favorites_count", #_G.favoritesList)
  for i, f in ipairs(_G.favoritesList) do
    editor.putString("fav_name_" .. i, f.name)
    editor.putString("fav_url_" .. i, f.url)
  end
  editor.apply()
end

local volLevels = {"Normal", "2.0x", "3.0x", "4.0x", "5.0x", "6.0x"}
local volMultipliers = {1.0, 2.0, 3.0, 4.0, 5.0, 6.0}
local qualityLevels = {"Auto", "1080p", "720p", "480p", "360p"}

local entertainmentChannels = {
  { name = "ARY Digital", url = "https://tamashaweb.com/ary-digital-live" },
  { name = "ARY Zindagi", url = "https://www.tamashaweb.com/ary-zindagi-live" },
  { name = "Geo Entertainment", url = "https://harpalgeo.tv/live" },
  { name = "Green Entertainment", url = "https://tamashaweb.com/green-entertainment" },
  { name = "Hum Masala", url = "https://www.tamashaweb.com/hum-masala-live" },
  { name = "Hum Sitaray", url = "https://tamashaweb.com/hum-sitaray-live" },
  { name = "HUM TV", url = "https://tamashaweb.com/hum-tv-live" },
  { name = "PTV Home", url = "https://tamashaweb.com/ptv-home" }
}

local newsChannels = {
  { name = "Aaj News", url = "https://www.tamashaweb.com/aaj-news-live" },
  { name = "City 42", url = "https://www.tamashaweb.com/city-42-live" },
  { name = "PTV News", url = "https://tamashaweb.com/ptv-news" },
  { name = "Samaa TV", url = "https://tamashaweb.com/samaa-tv-live" }
}

local aryNewsChannels = {
  { name = "ARY News 1", url = "https://tamashaweb.com/ary-news" },
  { name = "ARY News 2", url = "http://live.arynews.tv/pk/" }
}

local geoNewsChannels = {
  { name = "Geo News 1", url = "https://tamashaweb.com/geo-news-live" },
  { name = "Geo News 2", url = "https://live.geo.tv/" },
  { name = "Geo News 3", url = "https://live.geo.tv/stream2" }
}

local religiousChannels = {
  { name = "ARY QTV", url = "https://live.aryqtv.tv/" },
  { name = "Madani Channel", url = "https://tamashaweb.com/madani-channel-live" },
  { name = "Paigham TV", url = "https://tamashaweb.com/paigham-tv" },
  { name = "Saudi Quran Makkah TV", url = "https://tamashaweb.com/saudi-quran-makk/ah-tv-hd-live" }
}

local sportsChannels = {
  { name = "Geo Super", url = "https://www.geosuper.tv/live" },
  { name = "PTV Sports", url = "https://tamashaweb.com/ptv-sports" }
}

local kidsChannels = {
  { name = "Baby TV", url = "https://tamashaweb.com/baby-tv-live" },
  { name = "Cartoon Network", url = "https://pakistan-tv.vercel.app/channels/cartoon-network-live" }
}

function dismissAllDialogs()
  if mainDialog then pcall(function() mainDialog.dismiss() end) mainDialog = nil end
  if settingsDialog then pcall(function() settingsDialog.dismiss() end) settingsDialog = nil end
  if channelsDialog then pcall(function() channelsDialog.dismiss() end) channelsDialog = nil end
  if newsDialog then pcall(function() newsDialog.dismiss() end) newsDialog = nil end
  if aryNewsDialog then pcall(function() aryNewsDialog.dismiss() end) aryNewsDialog = nil end
  if geoNewsDialog then pcall(function() geoNewsDialog.dismiss() end) geoNewsDialog = nil end
  if religiousDialog then pcall(function() religiousDialog.dismiss() end) religiousDialog = nil end
  if sportsDialog then pcall(function() sportsDialog.dismiss() end) sportsDialog = nil end
  if kidsDialog then pcall(function() kidsDialog.dismiss() end) kidsDialog = nil end
  if favoritesDialog then pcall(function() favoritesDialog.dismiss() end) favoritesDialog = nil end
  if aboutDialog then pcall(function() aboutDialog.dismiss() end) aboutDialog = nil end
end

function speakText(text)
  if not text then return end
  service.handler.postDelayed(Runnable({run=function()
    pcall(function()
      if service and service.speak then service.speak(text) elseif speak then speak(text) end
    end)
  end}), Long(400))
end

function closeExtension()
  isFullScreen = false
  _G.SmartTV_IsFullScreen = false
  _G.SmartTV_IsPlayerMinimized = false
  dismissAllDialogs()
  if playerDialog then 
    if myWebView then 
      pcall(function() 
        myWebView.stopLoading()
        myWebView.loadUrl("about:blank")
      end) 
    end
    pcall(function() playerDialog.dismiss() end) 
    playerDialog = nil
    _G.SmartTV_PlayerDialog = nil
  end
  
  pcall(function()
    Toast.makeText(service, "Extension Successfully Closed", Toast.LENGTH_SHORT).show()
  end)
  speakText("Extension Successfully Closed")
  
  pcall(function() service.performGlobalAction(1) end)
end

function safeShow(d)
  service.handler.postDelayed(Runnable({run=function()
    if d then
      d.getWindow().setType(WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY)
      if d == playerDialog then
        pcall(function()
          local win = d.getWindow()
          win.setFlags(WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED, WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED)
          win.addFlags(WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL | WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH)
          win.setBackgroundDrawable(ColorDrawable(0xFF000000)) 
        end)
      end
      d.show()
      if d == playerDialog then
        pcall(function()
          d.getWindow().setLayout(WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT)
        end)
      end
    end
  end}), Long(150))
end

function openMiniPlayer(list, index, categoryType)
  if playerDialog then
    pcall(function()
      myWebView.stopLoading()
      myWebView.loadUrl("about:blank")
      playerDialog.dismiss()
    end)
    playerDialog = nil
    _G.SmartTV_PlayerDialog = nil
    _G.SmartTV_IsPlayerMinimized = false
  end

  local channel = list[index]
  speakText("Now playing " .. channel.name)

  local changeChannel
  local togglePlayPause
  local toggleFullScreenMode

  local dm = service.getResources().getDisplayMetrics()
  portraitHeight = math.floor(dm.heightPixels * 0.40)
  _G.SmartTV_PortraitHeight = portraitHeight

  local mainContainer = FrameLayout(service)
  mainContainer.setLayoutParams(FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT))
  playerMainContainer = mainContainer 

  local layout = LinearLayout(service)
  layout.setOrientation(LinearLayout.VERTICAL)
  layout.setLayoutParams(FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT))

  customViewContainer = FrameLayout(service)
  customViewContainer.setLayoutParams(FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT))
  customViewContainer.setBackgroundColor(0xFF000000)
  customViewContainer.setVisibility(View.GONE)

  txtNowPlaying = TextView(service)
  txtNowPlaying.setText("Now Playing: " .. channel.name)
  txtNowPlaying.setTextSize(16)
  txtNowPlaying.setTextColor(0xFF00AAFF)
  txtNowPlaying.setGravity(Gravity.CENTER)
  txtNowPlaying.setPadding(10, 15, 10, 15)
  layout.addView(txtNowPlaying)
  _G.SmartTV_TxtNowPlaying = txtNowPlaying

  webContainer = FrameLayout(service)
  webContainer.setBackgroundColor(0xFF000000)
  
  local currentHeight = portraitHeight
  local webParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, currentHeight)
  webContainer.setLayoutParams(webParams)

  myWebView = WebView(service)
  myWebView.setLayoutParams(FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT))
  myWebView.setBackgroundColor(0xFF000000)
  myWebView.setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS)
  webContainer.addView(myWebView)
  _G.SmartTV_MyWebView = myWebView
  _G.SmartTV_WebContainer = webContainer

  local overlay = TextView(service)
  overlay.setLayoutParams(FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT))
  overlay.setBackgroundColor(0xFF000000)
  overlay.setGravity(Gravity.CENTER)
  overlay.setTextColor(0xFF00AAFF)
  overlay.setTextSize(18)
  overlay.setText("Channel Loading...")
  webContainer.addView(overlay)

  layout.addView(webContainer)

  controlsParent = LinearLayout(service)
  controlsParent.setOrientation(LinearLayout.VERTICAL)
  controlsParent.setLayoutParams(LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT))
  controlsParent.setPadding(5, 5, 5, 5)
  _G.SmartTV_ControlsParent = controlsParent

  local row1 = LinearLayout(service)
  row1.setOrientation(LinearLayout.HORIZONTAL)
  row1.setLayoutParams(LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT))
  
  local btnParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1.0)
  btnParams.setMargins(2, 4, 2, 4)

  local btnPrev = Button(service)
  btnPrev.setText("Previous")
  btnPrev.setTextSize(12)
  btnPrev.setLayoutParams(btnParams)
  btnPrev.setOnClickListener(View.OnClickListener({
    onClick = function(v)
      if index > 1 then changeChannel(index - 1) else speakText("First channel") end
    end
  }))
  row1.addView(btnPrev)

  local btnPlayPause = Button(service)
  btnPlayPause.setText("Pause")
  btnPlayPause.setTextSize(12)
  btnPlayPause.setLayoutParams(btnParams)

  togglePlayPause = function()
    myWebView.evaluateJavascript([[
      (function() {
        var video = document.querySelector('video');
        if (video) {
          if (video.paused) {
            window.isUserPaused = false;
            video.play();
            return 'playing';
          } else {
            window.isUserPaused = true;
            video.pause();
            return 'paused';
          }
        }
        return 'none';
      })();
    ]], luajava.createProxy("android.webkit.ValueCallback", {
      onReceiveValue = function(value)
        if value and (value:find("playing") or value == '"playing"') then
          btnPlayPause.setText("Pause")
          speakText("Playing")
        elseif value and (value:find("paused") or value == '"paused"') then
          btnPlayPause.setText("Play")
          speakText("Paused")
        end
      end
    }))
  end

  btnPlayPause.setOnClickListener(View.OnClickListener({
    onClick = function(v) togglePlayPause() end
  }))
  row1.addView(btnPlayPause)

  local btnNext = Button(service)
  btnNext.setText("Next")
  btnNext.setTextSize(12)
  btnNext.setLayoutParams(btnParams)
  btnNext.setOnClickListener(View.OnClickListener({
    onClick = function(v)
      if index < #list then changeChannel(index + 1) else speakText("Last channel") end
    end
  }))
  row1.addView(btnNext)

  local btnFullScreen = Button(service)
  btnFullScreen.setText(isFullScreen and "Exit Full Screen" or "Full Screen")
  btnFullScreen.setTextSize(11)
  btnFullScreen.setLayoutParams(btnParams)
  
  if _G.isAudioOnlyMode then
    btnFullScreen.setVisibility(View.GONE)
  else
    btnFullScreen.setVisibility(View.VISIBLE)
  end

  btnFullScreen.setOnClickListener(View.OnClickListener({
    onClick = function(v) toggleFullScreenMode() end
  }))
  row1.addView(btnFullScreen)
  controlsParent.addView(row1)

  local row2 = LinearLayout(service)
  row2.setOrientation(LinearLayout.HORIZONTAL)
  row2.setLayoutParams(LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT))

  local btnVolBoost = Button(service)
  btnVolBoost.setText("Volume: " .. volLevels[_G.volIdx])
  btnVolBoost.setTextSize(11)
  btnVolBoost.setLayoutParams(btnParams)
  btnVolBoost.setOnClickListener(View.OnClickListener({
    onClick = function(v)
      _G.volIdx = _G.volIdx + 1
      if _G.volIdx > #volLevels then _G.volIdx = 1 end
      _G.currentVolumeMultiplier = volMultipliers[_G.volIdx]
      btnVolBoost.setText("Volume: " .. volLevels[_G.volIdx])
      
      local volJS = [[
        (function() {
          var video = document.querySelector('video');
          if (!video) return;
          if (!window.audioCtx) {
            window.audioCtx = new (window.AudioContext || window.webkitAudioContext)();
            window.gainNode = window.audioCtx.createGain();
            window.source = window.audioCtx.createMediaElementSource(video);
            window.source.connect(window.gainNode);
            window.gainNode.connect(window.audioCtx.destination);
          }
          window.gainNode.gain.value = ]] .. tostring(_G.currentVolumeMultiplier) .. [[;
        })();
      ]]
      myWebView.evaluateJavascript(volJS, nil)
      speakText("Volume " .. volLevels[_G.volIdx])
    end
  }))
  row2.addView(btnVolBoost)

  local btnFav = Button(service)
  btnFav.setTextSize(10) 
  btnFav.setLayoutParams(btnParams)
  
  local function checkIsFav()
    for idx, f in ipairs(_G.favoritesList) do
      if f.url == channel.url then return idx end
    end
    return nil
  end

  local function syncFavText()
    if checkIsFav() then 
      btnFav.setText("Remove from Favorites") 
    else 
      btnFav.setText("Add to Favorites") 
    end
  end
  syncFavText()

  btnFav.setOnClickListener(View.OnClickListener({
    onClick = function(v)
      local favIdx = checkIsFav()
      if favIdx then
        table.remove(_G.favoritesList, favIdx)
        saveFavorites() 
        syncFavText()
        speakText("Removed from favorites")
      else
        table.insert(_G.favoritesList, {name = channel.name, url = channel.url})
        saveFavorites() 
        syncFavText()
        speakText("Added to favorites")
      end
    end
  }))
  row2.addView(btnFav)

  toggleFullScreenMode = function()
    pcall(function()
      local win = playerDialog.getWindow()
      local lp = win.getAttributes()
      if not isFullScreen then
        lp.screenOrientation = ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
        win.setAttributes(lp)
        win.addFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN)
        win.getDecorView().setSystemUiVisibility(
          View.SYSTEM_UI_FLAG_LAYOUT_STABLE | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION |
          View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION |
          View.SYSTEM_UI_FLAG_FULLSCREEN | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
        )
        txtNowPlaying.setVisibility(View.GONE)
        controlsParent.setVisibility(View.GONE)
        
        local webParamsFS = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.MATCH_PARENT)
        webContainer.setLayoutParams(webParamsFS)
        isFullScreen = true
        _G.SmartTV_IsFullScreen = true
        btnFullScreen.setText("Exit Full Screen")
        
        local fsJS = [[
          (function() {
            var elements = document.querySelectorAll('button, div, a, i, span');
            for(var i = 0; i < elements.length; i++) {
              var el = elements[i];
              var text = (el.innerText || el.getAttribute('aria-label') || '').toLowerCase();
              if (text.indexOf('enter full screen') !== -1 || text.indexOf('shortcut f') !== -1) {
                try { el.click(); break; } catch(e){}
              }
            }
          })();
        ]]
        myWebView.evaluateJavascript(fsJS, nil)
      else
        lp.screenOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
        win.setAttributes(lp)
        win.clearFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN)
        win.getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_VISIBLE)
        txtNowPlaying.setVisibility(View.VISIBLE)
        controlsParent.setVisibility(View.VISIBLE)
        
        local webParamsPT = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, portraitHeight)
        webContainer.setLayoutParams(webParamsPT)
        isFullScreen = false
        _G.SmartTV_IsFullScreen = false
        btnFullScreen.setText("Full Screen")
        
        local exitJS = [[
          (function() {
            var elements = document.querySelectorAll('button, div, a, i, span');
            for(var i = 0; i < elements.length; i++) {
              var el = elements[i];
              var text = (el.innerText || el.getAttribute('aria-label') || '').toLowerCase();
              if (text.indexOf('exit full screen') !== -1 || text.indexOf('shortcut f') !== -1) {
                try { el.click(); break; } catch(e){}
              }
            }
          })();
        ]]
        myWebView.evaluateJavascript(exitJS, nil)
      end
    end)
  end

  local handleMinimizeAction = function()
    if not _G.isBackgroundPlayEnabled then
      speakText("Background play is turned off in settings")
      Toast.makeText(service, "Background Play is Disabled!", Toast.LENGTH_SHORT).show()
      return
    end

    _G.SmartTV_IsPlayerMinimized = true
    speakText("Player minimized to background")
    
    pcall(function()
      if playerDialog then
        local win = playerDialog.getWindow()
        win.addFlags(WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE | WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE)
        win.setBackgroundDrawable(ColorDrawable(0x00000000)) 
        
        if mainContainer then mainContainer.setBackgroundColor(0x00000000) end
        if layout then layout.setBackgroundColor(0x00000000) end
        if webContainer then webContainer.setBackgroundColor(0x00000000) end
        if myWebView then myWebView.setBackgroundColor(0x00000000) end
        
        if txtNowPlaying then txtNowPlaying.setVisibility(View.GONE) end
        if controlsParent then controlsParent.setVisibility(View.GONE) end
      end
    end)
    
    pcall(function() service.performGlobalAction(2) end) 
  end

  local btnMinimize = Button(service)
  btnMinimize.setText("Minimize")
  btnMinimize.setTextSize(11)
  btnMinimize.setLayoutParams(btnParams)
  btnMinimize.setOnClickListener(View.OnClickListener({
    onClick = function(v) handleMinimizeAction() end
  }))
  row2.addView(btnMinimize)

  local goBackToMenu = function()
    _G.SmartTV_IsPlayerMinimized = false
    if myWebView then 
      pcall(function() 
        myWebView.stopLoading()
        myWebView.loadUrl("about:blank")
      end) 
    end
    pcall(function()
      local win = playerDialog.getWindow()
      local lp = win.getAttributes()
      lp.screenOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
      win.setAttributes(lp)
    end)
    if isFullScreen then isFullScreen = false end
    _G.SmartTV_IsFullScreen = false
    if playerDialog then playerDialog.dismiss() playerDialog = nil end
    _G.SmartTV_PlayerDialog = nil
    
    if categoryType == "entertainment" then showChannelsMenu()
    elseif categoryType == "kids" then showKidsMenu()
    elseif categoryType == "news" then showNewsMenu()
    elseif categoryType == "news_ary" then showAryNewsMenu()
    elseif categoryType == "news_geo" then showGeoNewsMenu()
    elseif categoryType == "religious" then showReligiousMenu()
    elseif categoryType == "sports" then showSportsMenu()
    elseif categoryType == "favorites" then showFavoritesMenu()
    else showTvMenu() end
  end

  local btnBackMenu = Button(service)
  btnBackMenu.setText("Back")
  btnBackMenu.setTextSize(11)
  btnBackMenu.setLayoutParams(btnParams)
  btnBackMenu.setOnClickListener(View.OnClickListener({
    onClick = function(v) goBackToMenu() end
  }))
  row2.addView(btnBackMenu)

  local btnExitPlayer = Button(service)
  btnExitPlayer.setText("Exit")
  btnExitPlayer.setTextSize(11)
  btnExitPlayer.setLayoutParams(btnParams)
  btnExitPlayer.setOnClickListener(View.OnClickListener({
    onClick = function(v)
      closeExtension()
    end
  }))
  row2.addView(btnExitPlayer)

  controlsParent.addView(row2)
  layout.addView(controlsParent)
  mainContainer.addView(layout)
  mainContainer.addView(customViewContainer)

  playerDialog = AlertDialog.Builder(service).setView(mainContainer).create()
  _G.SmartTV_PlayerDialog = playerDialog

  playerDialog.setOnKeyListener(luajava.createProxy("android.content.DialogInterface$OnKeyListener", {
    onKey = function(dialog, keyCode, event)
      if keyCode == KeyEvent.KEYCODE_BACK and event.getAction() == KeyEvent.ACTION_UP then
        if _G.isBackgroundPlayEnabled then
          handleMinimizeAction() 
          return true 
        else
          goBackToMenu()
          return true
        end
      end
      return false
    end
  }))

  local startX, startY = 0, 0
  myWebView.setOnTouchListener(View.OnTouchListener({
    onTouch = function(v, event)
      if not isFullScreen then return false end
      local action = event.getAction()
      if action == MotionEvent.ACTION_DOWN then
        startX = event.getX()
        startY = event.getY()
        return true
      elseif action == MotionEvent.ACTION_UP then
        local endX = event.getX()
        local endY = event.getY()
        local deltaX = endX - startX
        local deltaY = endY - startY

        if math.abs(deltaX) > math.abs(deltaY) then
          if deltaX > 150 then
            if index < #list then changeChannel(index + 1) else speakText("Last channel") end
          elseif deltaX < -150 then
            if index > 1 then changeChannel(index - 1) else speakText("First channel") end
          end
        else
          if deltaY < -150 then
            togglePlayPause()
          elseif deltaY > 150 then
            goBackToMenu()
          end
        end
        return true
      end
      return false
    end
  }))

  local webSettings = myWebView.getSettings()
  webSettings.setJavaScriptEnabled(true)
  webSettings.setDomStorageEnabled(true)
  webSettings.setDatabaseEnabled(true)
  webSettings.setMediaPlaybackRequiresUserGesture(false)
  webSettings.setUserAgentString("Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Mobile Safari/537.36")
  
  if Build.VERSION.SDK_INT >= 21 then
    pcall(function() webSettings.setMixedContentMode(WebSettings.MIXED_CONTENT_ALWAYS_ALLOW) end)
  end

  myWebView.setWebChromeClient(luajava.override(WebChromeClient, {
    onShowCustomView = function(super, view, callback)
      if mCustomView then
        callback.onCustomViewHidden()
        return
      end
      mCustomView = view
      customViewContainer.addView(mCustomView)
      customViewContainer.setVisibility(View.VISIBLE)
      customViewCallback = callback
    end,
    onHideCustomView = function(super)
      if not mCustomView then return end
      customViewContainer.removeView(mCustomView)
      mCustomView = nil
      customViewContainer.setVisibility(View.GONE)
      if customViewCallback then customViewCallback.onCustomViewHidden() end
    end
  }))

  local cleanJS = [[(function(){ 
      var forcePureVideoIsolation = function() {
          var video = document.querySelector('video');
          if (!video) {
              var iframes = document.querySelectorAll('iframe');
              for (var i = 0; i < iframes.length; i++) {
                  try {
                      var doc = iframes[i].contentDocument || iframes[i].contentWindow.document;
                      video = doc.querySelector('video');
                      if (video) break;
                  } catch(e) {}
              }
          }
          if (!video) return;

          if(document.title !== "TV") { document.title = "TV"; }

          var styleId = 'indestructible-tv-isolation';
          var style = document.getElementById(styleId);
          if (!style) {
              style = document.createElement('style');
              style.id = styleId;
              document.head.appendChild(style);
          }
          style.innerHTML = `
              video {
                  display: block !important;
                  visibility: visible !important;
                  position: fixed !important;
                  top: 0 !important;
                  left: 0 !important;
                  width: 100% !important;
                  height: 100% !important;
                  z-index: 2147483647 !important;
                  object-fit: contain !important;
                  background: #000000 !important;
              }
          `;
          
          var curr = video.parentElement;
          while (curr && curr !== document.body) {
              curr.style.setProperty('overflow', 'visible', 'important');
              curr.style.setProperty('transform', 'none', 'important');
              curr.style.setProperty('filter', 'none', 'important');
              curr.style.setProperty('clip', 'auto', 'important');
              curr = curr.parentElement;
          }

          if (video.muted) {
              video.muted = false;
              var elements = document.querySelectorAll('button, div, a, i, span');
              for(var i = 0; i < elements.length; i++) {
                  var text = (elements[i].innerText || elements[i].getAttribute('aria-label') || '').toLowerCase();
                  if (text.indexOf('unmute') !== -1) {
                      try { elements[i].click(); } catch(e){}
                  }
              }
          }
          if (video.paused && !window.isUserPaused) {
              try { video.play(); } catch(e){}
          }
      };

      forcePureVideoIsolation();
      if (!window.cleanTvIndestructibleInterval) {
          window.cleanTvIndestructibleInterval = setInterval(forcePureVideoIsolation, 150);
      }
  })();]]

  local function startVideoPollingCheck(overlayView, webInstance, boundLoadId, channelUrl)
    local attempts = 0
    local maxAttempts = 50 
    
    local targetClean = channelUrl:gsub("https?://", ""):gsub("www%.", "")
    if targetClean:sub(-1) == "/" then targetClean = targetClean:sub(1, -2) end
    
    local function loop()
      if not webInstance or not overlayView then return end
      if boundLoadId ~= currentLoadId then return end 
      
      attempts = attempts + 1
      
      local jsCheck = [[
        (function() {
          var current = window.location.href.replace(/^https?:\/\//, '').replace(/^www\./, '');
          var target = "]] .. targetClean .. [[";
          if (current.indexOf(target) === -1 && target !== "about:blank") {
            return "WRONG_PAGE";
          }
          var v = document.querySelector('video');
          if (!v) {
            var iframes = document.querySelectorAll('iframe');
            for (var i = 0; i < iframes.length; i++) {
              try {
                var doc = iframes[i].contentDocument || iframes[i].contentWindow.document;
                v = doc.querySelector('video');
                if (v) break;
              } catch(e) {}
            }
          }
          if (v) {
            if (v.paused && !window.isUserPaused) { try { v.play(); } catch(e){} }
            if (v.currentTime > 0 || v.readyState >= 2) {
              return "READY_PLAYING";
            }
          }
          return "STILL_LOADING";
        })();
      ]]

      webInstance.evaluateJavascript(jsCheck, luajava.createProxy("android.webkit.ValueCallback", {
        onReceiveValue = function(res)
          if boundLoadId ~= currentLoadId then return end 
          
          local isReady = (res and (res:find("READY_PLAYING") or res == '"READY_PLAYING"'))
          
          if isReady or attempts >= maxAttempts then
            webInstance.evaluateJavascript(cleanJS, nil)
            pcall(function() overlayView.setVisibility(View.GONE) end) 
            
            if _G.isChannelLoading then
              _G.isChannelLoading = false
            end
          else
            webInstance.evaluateJavascript(cleanJS, nil) 
            service.handler.postDelayed(Runnable({run = loop}), Long(200)) 
          end
        end
      }))
    end
    loop()
  end

  myWebView.setWebViewClient(luajava.override(WebViewClient, {
    onPageStarted = function(super, view, url, favicon) end,
    onPageFinished = function(super, view, url)
      view.evaluateJavascript(cleanJS, nil)
    end
  }))

  changeChannel = function(newIndex)
    pcall(function() myWebView.stopLoading() end) 
    currentLoadId = currentLoadId + 1 
    _G.isChannelLoading = true 
    
    index = newIndex
    channel = list[index]
    txtNowPlaying.setText("Now Playing: " .. channel.name)
    btnPlayPause.setText("Pause")
    syncFavText()
    
    speakText("Now playing " .. channel.name)
    pcall(function() 
      overlay.setText("Channel Loading...")
      overlay.setVisibility(View.VISIBLE) 
    end) 
    myWebView.loadUrl(channel.url)
    
    startVideoPollingCheck(overlay, myWebView, currentLoadId, channel.url)
  end

  currentLoadId = currentLoadId + 1
  _G.isChannelLoading = true 
  pcall(function() 
    overlay.setText("Channel Loading...")
    overlay.setVisibility(View.VISIBLE) 
  end) 
  myWebView.loadUrl(channel.url)
  
  startVideoPollingCheck(overlay, myWebView, currentLoadId, channel.url)
  safeShow(playerDialog)
end

function createChannelButton(ch, list, i, categoryType)
  local btn = Button(service)
  btn.setText(ch.name)
  btn.setOnClickListener(View.OnClickListener({
    onClick = function(v) dismissAllDialogs() openMiniPlayer(list, i, categoryType) end
  }))
  return btn
end

function showFavoritesMenu()
  dismissAllDialogs()
  local sv = ScrollView(service)
  local layout = LinearLayout(service)
  layout.setOrientation(LinearLayout.VERTICAL)
  layout.setPadding(60, 40, 60, 40)
  sv.addView(layout)
  
  local title = TextView(service)
  title.setText("Favorites")
  title.setTextSize(18)
  title.setGravity(Gravity.CENTER)
  title.setPadding(0, 10, 0, 30)
  layout.addView(title)
  
  for i, ch in ipairs(_G.favoritesList) do 
    layout.addView(createChannelButton(ch, _G.favoritesList, i, "favorites")) 
  end
  
  local btnBack = Button(service)
  btnBack.setText("Back to Main Menu")
  btnBack.setOnClickListener(View.OnClickListener({ onClick = function(v) dismissAllDialogs() showTvMenu() end }))
  layout.addView(btnBack)
  favoritesDialog = AlertDialog.Builder(service).setView(sv).create()
  safeShow(favoritesDialog)
end

function showAryNewsMenu()
  dismissAllDialogs()
  local sv = ScrollView(service)
  local layout = LinearLayout(service)
  layout.setOrientation(LinearLayout.VERTICAL)
  layout.setPadding(60, 40, 60, 40)
  sv.addView(layout)
  
  local title = TextView(service)
  title.setText("ARY News")
  title.setTextSize(18)
  title.setGravity(Gravity.CENTER)
  title.setPadding(0, 10, 0, 30)
  layout.addView(title)
  
  for i, ch in ipairs(aryNewsChannels) do 
    layout.addView(createChannelButton(ch, aryNewsChannels, i, "news_ary")) 
  end
  
  local btnBack = Button(service)
  btnBack.setText("Back to News Menu")
  btnBack.setOnClickListener(View.OnClickListener({ onClick = function(v) dismissAllDialogs() showNewsMenu() end }))
  layout.addView(btnBack)
  aryNewsDialog = AlertDialog.Builder(service).setView(sv).create()
  safeShow(aryNewsDialog)
end

function showGeoNewsMenu()
  dismissAllDialogs()
  local sv = ScrollView(service)
  local layout = LinearLayout(service)
  layout.setOrientation(LinearLayout.VERTICAL)
  layout.setPadding(60, 40, 60, 40)
  sv.addView(layout)
  
  local title = TextView(service)
  title.setText("Geo News")
  title.setTextSize(18)
  title.setGravity(Gravity.CENTER)
  title.setPadding(0, 10, 0, 30)
  layout.addView(title)
  
  for i, ch in ipairs(geoNewsChannels) do 
    layout.addView(createChannelButton(ch, geoNewsChannels, i, "news_geo")) 
  end
  
  local btnBack = Button(service)
  btnBack.setText("Back to News Menu")
  btnBack.setOnClickListener(View.OnClickListener({ onClick = function(v) dismissAllDialogs() showNewsMenu() end }))
  layout.addView(btnBack)
  geoNewsDialog = AlertDialog.Builder(service).setView(sv).create()
  safeShow(geoNewsDialog)
end

function showNewsMenu()
  dismissAllDialogs()
  local sv = ScrollView(service)
  local layout = LinearLayout(service)
  layout.setOrientation(LinearLayout.VERTICAL)
  layout.setPadding(60, 40, 60, 40)
  sv.addView(layout)
  
  local title = TextView(service)
  title.setText("Live News")
  title.setTextSize(18)
  title.setGravity(Gravity.CENTER)
  title.setPadding(0, 10, 0, 30)
  layout.addView(title)
  
  -- Aaj News
  layout.addView(createChannelButton(newsChannels[1], newsChannels, 1, "news"))
  
  -- ARY News Sub-category Button
  local btnAryCat = Button(service)
  btnAryCat.setText("ARY News")
  btnAryCat.setOnClickListener(View.OnClickListener({ onClick = function(v) showAryNewsMenu() end }))
  layout.addView(btnAryCat)
  
  -- City 42
  layout.addView(createChannelButton(newsChannels[2], newsChannels, 2, "news"))
  
  -- Geo News Sub-category Button
  local btnGeoCat = Button(service)
  btnGeoCat.setText("Geo News")
  btnGeoCat.setOnClickListener(View.OnClickListener({ onClick = function(v) showGeoNewsMenu() end }))
  layout.addView(btnGeoCat)
  
  -- PTV News & Samaa TV
  layout.addView(createChannelButton(newsChannels[3], newsChannels, 3, "news"))
  layout.addView(createChannelButton(newsChannels[4], newsChannels, 4, "news"))
  
  local btnBack = Button(service)
  btnBack.setText("Back to Main Menu")
  btnBack.setOnClickListener(View.OnClickListener({ onClick = function(v) dismissAllDialogs() showTvMenu() end }))
  layout.addView(btnBack)
  newsDialog = AlertDialog.Builder(service).setView(sv).create()
  safeShow(newsDialog)
end

function showChannelsMenu()
  dismissAllDialogs()
  local sv = ScrollView(service)
  local layout = LinearLayout(service)
  layout.setOrientation(LinearLayout.VERTICAL)
  layout.setPadding(60, 40, 60, 40)
  sv.addView(layout)
  
  local title = TextView(service)
  title.setText("Live Entertainment")
  title.setTextSize(18)
  title.setGravity(Gravity.CENTER)
  title.setPadding(0, 10, 0, 30)
  layout.addView(title)
  
  for i, ch in ipairs(entertainmentChannels) do 
    layout.addView(createChannelButton(ch, entertainmentChannels, i, "entertainment")) 
  end
  
  local btnBack = Button(service)
  btnBack.setText("Back to Main Menu")
  btnBack.setOnClickListener(View.OnClickListener({ onClick = function(v) dismissAllDialogs() showTvMenu() end }))
  layout.addView(btnBack)
  channelsDialog = AlertDialog.Builder(service).setView(sv).create()
  safeShow(channelsDialog)
end

function showKidsMenu()
  dismissAllDialogs()
  local sv = ScrollView(service)
  local layout = LinearLayout(service)
  layout.setOrientation(LinearLayout.VERTICAL)
  layout.setPadding(60, 40, 60, 40)
  sv.addView(layout)
  
  local title = TextView(service)
  title.setText("Live Kids")
  title.setTextSize(18)
  title.setGravity(Gravity.CENTER)
  title.setPadding(0, 10, 0, 30)
  layout.addView(title)
  
  for i, ch in ipairs(kidsChannels) do 
    layout.addView(createChannelButton(ch, kidsChannels, i, "kids")) 
  end
  
  local btnBack = Button(service)
  btnBack.setText("Back to Main Menu")
  btnBack.setOnClickListener(View.OnClickListener({ onClick = function(v) dismissAllDialogs() showTvMenu() end }))
  layout.addView(btnBack)
  kidsDialog = AlertDialog.Builder(service).setView(sv).create()
  safeShow(kidsDialog)
end

function showReligiousMenu()
  dismissAllDialogs()
  local sv = ScrollView(service)
  local layout = LinearLayout(service)
  layout.setOrientation(LinearLayout.VERTICAL)
  layout.setPadding(60, 40, 60, 40)
  sv.addView(layout)
  
  local title = TextView(service)
  title.setText("Live Religious")
  title.setTextSize(18)
  title.setGravity(Gravity.CENTER)
  title.setPadding(0, 10, 0, 30)
  layout.addView(title)
  
  for i, ch in ipairs(religiousChannels) do 
    layout.addView(createChannelButton(ch, religiousChannels, i, "religious")) 
  end
  
  local btnBack = Button(service)
  btnBack.setText("Back to Main Menu")
  btnBack.setOnClickListener(View.OnClickListener({ onClick = function(v) dismissAllDialogs() showTvMenu() end }))
  layout.addView(btnBack)
  religiousDialog = AlertDialog.Builder(service).setView(sv).create()
  safeShow(religiousDialog)
end

function showSportsMenu()
  dismissAllDialogs()
  local sv = ScrollView(service)
  local layout = LinearLayout(service)
  layout.setOrientation(LinearLayout.VERTICAL)
  layout.setPadding(60, 40, 60, 40)
  sv.addView(layout)
  
  local title = TextView(service)
  title.setText("Live Sports")
  title.setTextSize(18)
  title.setGravity(Gravity.CENTER)
  title.setPadding(0, 10, 0, 30)
  layout.addView(title)
  
  for i, ch in ipairs(sportsChannels) do 
    layout.addView(createChannelButton(ch, sportsChannels, i, "sports")) 
  end
  
  local btnBack = Button(service)
  btnBack.setText("Back to Main Menu")
  btnBack.setOnClickListener(View.OnClickListener({ onClick = function(v) dismissAllDialogs() showTvMenu() end }))
  layout.addView(btnBack)
  sportsDialog = AlertDialog.Builder(service).setView(sv).create()
  safeShow(sportsDialog)
end

function showAboutMenu()
  dismissAllDialogs()
  local sv = ScrollView(service)
  local layout = LinearLayout(service)
  layout.setOrientation(LinearLayout.VERTICAL)
  layout.setPadding(60, 40, 60, 40)
  sv.addView(layout)
  
  local title = TextView(service)
  title.setText("About Smart TV Extension")
  title.setTextSize(18)
  title.setGravity(Gravity.CENTER)
  title.setPadding(0, 10, 0, 20)
  layout.addView(title)
  
  local infoTxt = TextView(service)
  infoTxt.setTextSize(14)
  infoTxt.setText("This extension is designed to provide seamless live television access categorization-wise:\n\n" ..
                 "1. Entertainment: Top standard entertainment dramas and shows.\n" ..
                 "2. Live News: Mainstream news networks directly streamed.\n" ..
                 "3. Religious: Holy streams including Makkah Live and spiritual content.\n" ..
                 "4. Live Sports: Realtime action of your favorite matches.\n" ..
                 "5. Live Kids: Fun and educational content for children.\n\n" ..
                 "Developed with accessibility compliance for effortless control.")
  infoTxt.setPadding(0, 10, 0, 30)
  layout.addView(infoTxt)
  
  local btnHelp = Button(service)
  btnHelp.setText("Help & Feedback")
  btnHelp.setOnClickListener(View.OnClickListener({
    onClick = function(v)
      pcall(function()
        local rawMsg = "Hello! I need help regarding the Smart TV Extension or want to give feedback."
        local url = "https://api.whatsapp.com/send?phone=923477583735&text=" .. Uri.encode(rawMsg)
        local intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
        
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK)
        service.startActivity(intent)
        
        isFullScreen = false
        _G.SmartTV_IsFullScreen = false
        _G.SmartTV_IsPlayerMinimized = false
        dismissAllDialogs()
        if playerDialog then 
          if myWebView then 
            pcall(function() 
              myWebView.stopLoading()
              myWebView.loadUrl("about:blank")
            end) 
          end
          pcall(function() playerDialog.dismiss() end) 
          playerDialog = nil
          _G.SmartTV_PlayerDialog = nil
        end
      end)
    end
  }))
  layout.addView(btnHelp)
  
  local btnBack = Button(service)
  btnBack.setText("Back to Settings")
  btnBack.setOnClickListener(View.OnClickListener({ onClick = function(v) dismissAllDialogs() showSettingsMenu() end }))
  layout.addView(btnBack)
  
  aboutDialog = AlertDialog.Builder(service).setView(sv).create()
  safeShow(aboutDialog)
end

function showSettingsMenu()
  dismissAllDialogs()
  local sv = ScrollView(service)
  local layout = LinearLayout(service)
  layout.setOrientation(LinearLayout.VERTICAL)
  layout.setPadding(60, 40, 60, 40)
  sv.addView(layout)
  
  local btnAudioToggle = Button(service)
  btnAudioToggle.setText("Play TV in Audio Mode: " .. (_G.isAudioOnlyMode and "ON" or "OFF"))
  btnAudioToggle.setOnClickListener(View.OnClickListener({
    onClick = function(v)
      _G.isAudioOnlyMode = not _G.isAudioOnlyMode
      local editor = pref.edit()
      editor.putInt("isAudioMode", _G.isAudioOnlyMode and 1 or 0)
      editor.apply()
      btnAudioToggle.setText("Play TV in Audio Mode: " .. (_G.isAudioOnlyMode and "ON" or "OFF"))
      speakText("Audio Mode " .. (_G.isAudioOnlyMode and "ON" or "OFF"))
    end
  }))
  layout.addView(btnAudioToggle)

  local btnBackgroundToggle = Button(service)
  btnBackgroundToggle.setText("Background Play: " .. (_G.isBackgroundPlayEnabled and "ON" or "OFF"))
  btnBackgroundToggle.setOnClickListener(View.OnClickListener({
    onClick = function(v)
      _G.isBackgroundPlayEnabled = not _G.isBackgroundPlayEnabled
      local editor = pref.edit()
      editor.putInt("isBackgroundPlayMode", _G.isBackgroundPlayEnabled and 1 or 0)
      editor.apply()
      btnBackgroundToggle.setText("Background Play: " .. (_G.isBackgroundPlayEnabled and "ON" or "OFF"))
      speakText("Background Play " .. (_G.isBackgroundPlayEnabled and "ON" or "OFF"))
    end
  }))
  layout.addView(btnBackgroundToggle)

  local btnQuality = Button(service)
  btnQuality.setText("Video Quality: " .. _G.selectedQuality)
  btnQuality.setOnClickListener(View.OnClickListener({
    onClick = function(v)
      _G.qualityIdx = _G.qualityIdx + 1
      if _G.qualityIdx > #qualityLevels then _G.qualityIdx = 1 end
      _G.selectedQuality = qualityLevels[_G.qualityIdx]
      btnQuality.setText("Video Quality: " .. _G.selectedQuality)
      speakText("Quality set to " .. _G.selectedQuality)
      
      if myWebView then
        local activeQJS = [[
          (function() {
            var q = "]].._G.selectedQuality..[[";
            var elements = document.querySelectorAll('button, li, span, a, div');
            for(var i=0; i<elements.length; i++){
              var txt = (elements[i].innerText || elements[i].getAttribute('aria-label') || '').toLowerCase();
              if(txt === 'quality' || txt.indexOf('quality') !== -1){
                 try { elements[i].click(); break; } catch(e){}
              }
            }
            setTimeout(function() {
              var el2 = document.querySelectorAll('button, li, span, a, div');
              for(var j=0; j<el2.length; j++){
                var txt2 = (el2[j].innerText || el2[j].getAttribute('aria-label') || '').toLowerCase();
                if(txt2.indexOf(q.toLowerCase()) !== -1){
                  try { el2[j].click(); break; } catch(e){}
                }
              }
            }, 300);
          })();
        ]]
        myWebView.evaluateJavascript(activeQJS, nil)
      end
    end
  }))
  layout.addView(btnQuality)

  local btnAbout = Button(service)
  btnAbout.setText("About")
  btnAbout.setOnClickListener(View.OnClickListener({ onClick = function(v) showAboutMenu() end }))
  layout.addView(btnAbout)

  local btnBack = Button(service)
  btnBack.setText("Back to Main Menu")
  btnBack.setOnClickListener(View.OnClickListener({ onClick = function(v) dismissAllDialogs() showTvMenu() end }))
  layout.addView(btnBack)
  settingsDialog = AlertDialog.Builder(service).setView(sv).create()
  safeShow(settingsDialog)
end

function showTvMenu()
  if _G.SmartTV_IsPlayerMinimized and _G.SmartTV_PlayerDialog then
    _G.SmartTV_IsPlayerMinimized = false
    dismissAllDialogs()
    pcall(function()
      if _G.SmartTV_PlayerDialog then
        local win = _G.SmartTV_PlayerDialog.getWindow()
        win.clearFlags(WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE | WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE) 
        win.setBackgroundDrawable(ColorDrawable(0xFF000000))
        
        if playerMainContainer then playerMainContainer.setBackgroundColor(0xFF000000) end
        if _G.SmartTV_TxtNowPlaying then _G.SmartTV_TxtNowPlaying.setVisibility(View.VISIBLE) end
        if _G.SmartTV_ControlsParent then _G.SmartTV_ControlsParent.setVisibility(View.VISIBLE) end
        if _G.SmartTV_WebContainer then
          _G.SmartTV_WebContainer.setBackgroundColor(0xFF000000)
          local lp = _G.SmartTV_WebContainer.getLayoutParams()
          lp.height = _G.SmartTV_PortraitHeight
          _G.SmartTV_WebContainer.setLayoutParams(lp)
        end
        if _G.SmartTV_MyWebView then _G.SmartTV_MyWebView.setBackgroundColor(0xFF000000) end
        
        _G.SmartTV_PlayerDialog.show()
      end
    end)
    speakText("Player restored to video mode")
    return 
  end

  dismissAllDialogs()
  local sv = ScrollView(service)
  local layout = LinearLayout(service)
  layout.setOrientation(LinearLayout.VERTICAL)
  layout.setPadding(60, 40, 60, 40)
  sv.addView(layout)
  
  local title = TextView(service)
  title.setText("Smart TV\nCreated By A Brothers")
  title.setGravity(Gravity.CENTER)
  title.setPadding(0, 10, 0, 50)
  layout.addView(title)
  
  local buttons = {}
  table.insert(buttons, {text="Live Entertainment", action=showChannelsMenu})
  table.insert(buttons, {text="Live Kids", action=showKidsMenu})
  table.insert(buttons, {text="Live News", action=showNewsMenu})
  table.insert(buttons, {text="Live Religious", action=showReligiousMenu})
  table.insert(buttons, {text="Live Sports", action=showSportsMenu})
  table.insert(buttons, {text="Favorites", action=showFavoritesMenu})
  table.insert(buttons, {text="Settings", action=showSettingsMenu})
  table.insert(buttons, {text="Close Extension", action=closeExtension})
  
  for _, b in ipairs(buttons) do
    local btn = Button(service)
    btn.setText(b.text)
    btn.setOnClickListener(View.OnClickListener({ onClick = function(v) b.action() end }))
    layout.addView(btn)
  end
  
  mainDialog = AlertDialog.Builder(service).setView(sv).create()
  safeShow(mainDialog)
end

showTvMenu()