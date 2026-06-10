require "import"
-- STARTUP_SOUND_INJECTOR_START
pcall(function()
    if startup_sound_mp ~= nil then
        pcall(function() startup_sound_mp.release() end)
    end
    local MediaPlayer = luajava.bindClass("android.media.MediaPlayer")
    local File = luajava.bindClass("java.io.File")
    startup_sound_mp = luajava.new(MediaPlayer)
    
    local sound_path = ""
    local roots = {"/storage/emulated/0/解说/Plugins/", "/sdcard/解说/Plugins/"}
    local target_name = "Smart TV Created By A Brothers"
    local exts = {".mp3", ".aac", ".wav", ".ogg", ".m4a"}
    
    for _, r in ipairs(roots) do
        for _, e in ipairs(exts) do
            local path_to_test = r .. target_name .. "/" .. target_name .. e
            if luajava.new(File, path_to_test).exists() then
                sound_path = path_to_test
                break
            end
        end
        if sound_path ~= "" then break end
    end
    
    if sound_path == "" then
        pcall(function()
            local d_path = debug.getinfo(1).source:match("@?(.*)")
            if d_path and d_path:find("/") then
                local s_dir = d_path:match("(.+)/[^/]+")
                for _, e in ipairs(exts) do
                    local path_to_test = s_dir .. "/" .. target_name .. e
                    if luajava.new(File, path_to_test).exists() then 
                        sound_path = path_to_test 
                        break
                    end
                end
            end
        end)
    end
    
    if sound_path ~= "" then
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
-- STARTUP_SOUND_INJECTOR_END
import "android.widget.*"
import "android.view.*"
import "android.view.accessibility.AccessibilityEvent"
import "android.webkit.WebView"
import "android.webkit.WebViewClient"
import "android.webkit.WebChromeClient"
import "android.webkit.WebSettings"
import "android.webkit.CookieManager" 
import "android.app.*"
import "android.os.*"
import "java.lang.Long"
import "android.content.pm.ActivityInfo"
import "android.content.Intent"
import "android.net.Uri"
import "android.widget.FrameLayout"
import "android.graphics.drawable.ColorDrawable"
import "android.content.DialogInterface" 
import "java.util.HashMap"

-- گلوبل جاوا ایرر فکس کرنے کے لیے
java = { util = { HashMap = HashMap } }

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
local addChannelDialog = nil
local deleteChannelDialog = nil
local customCatDialog = nil

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

customViewContainer = nil
customViewCallback = nil
mCustomView = nil

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

-- کسٹم کیٹیگریز ڈیٹا لوڈر لاجک (پابندی ختم کر دی گئی ہے)
if not _G.customCategoriesList then
  _G.customCategoriesList = {}
  local catCount = pref.getInt("custom_cats_count", 0)
  for i = 1, catCount do
    local cName = pref.getString("custom_cat_name_" .. i, "")
    local cParent = pref.getString("custom_cat_parent_" .. i, "")
    if cName ~= "" and cParent ~= "" then
      -- اب "Live music" یا کوئی بھی نام فلٹر نہیں ہوگا، سب لوڈ ہوں گے
      table.insert(_G.customCategoriesList, {name = cName, parent = cParent})
    end
  end
end

local function saveCustomCategories()
  local editor = pref.edit()
  local oldCount = pref.getInt("custom_cats_count", 0)
  for i = 1, oldCount do
    editor.remove("custom_cat_name_" .. i)
    editor.remove("custom_cat_parent_" .. i)
  end
  editor.putInt("custom_cats_count", #_G.customCategoriesList)
  for i, c in ipairs(_G.customCategoriesList) do
    editor.putString("custom_cat_name_" .. i, c.name)
    editor.putString("custom_cat_parent_" .. i, c.parent)
  end
  editor.commit()
end

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
  editor.commit()
end

local volLevels = {"Normal", "2.0x", "3.0x", "4.0x", "5.0x", "6.0x"}
local volMultipliers = {1.0, 2.0, 3.0, 4.0, 5.0, 6.0}
local qualityLevels = {"Auto", "1080p", "720p", "480p", "360p"}

-- الفابیٹیکل آرڈر میں ترتیب دینے کا فنکشن
local function sortChannelsAlphabetically(channelList)
  table.sort(channelList, function(a, b)
    return a.name:lower() < b.name:lower()
  end)
end

-- بنیادی ہارڈکوڈڈ چینل لسٹیں (بیس ڈیٹا)
local baseEntertainmentChannels = {
  { name = "ARY Digital", url = "https://tamashaweb.com/ary-digital-live" },
  { name = "ARY Zindagi", url = "https://www.tamashaweb.com/ary-zindagi-live" },
  { name = "Geo Entertainment", url = "https://harpalgeo.tv/live" },
  { name = "Green Entertainment", url = "https://tamashaweb.com/green-entertainment" },
  { name = "Hum Masala", url = "https://www.tamashaweb.com/hum-masala-live" },
  { name = "Hum Sitaray", url = "https://tamashaweb.com/hum-sitaray-live" },
  { name = "HUM TV", url = "https://tamashaweb.com/hum-tv-live" },
  { name = "KTN Entertainment", url = "https://tamashaweb.com/ktn-entertainment-live" },
  { name = "PTV Home", url = "https://tamashaweb.com/ptv-home" }
}

local baseNewsChannels = {
  { name = "Aaj News", url = "https://www.tamashaweb.com/aaj-news-live" },
  { name = "Al Jazeera", url = "https://tamashaweb.com/al-jazeera" }, 
  { name = "City 42", url = "https://www.tamashaweb.com/city-42-live" },
  { name = "Dunya News", url = "https://dunyanews.tv/live/" },
  { name = "KTN News", url = "https://tamashaweb.com/ktn-news-live" },
  { name = "PTV News", url = "https://tamashaweb.com/ptv-news" },
  { name = "Samaa TV", url = "https://tamashaweb.com/samaa-tv-live" }
}

-- کسٹم چینلز کو لوڈ کرنا (یہاں سے بھی پابندی ختم)
if not _G.customChannelsList then
  _G.customChannelsList = {}
  local cCount = pref.getInt("custom_channels_count", 0)
  local seenNames = {}
  for i = 1, cCount do
    local name = pref.getString("custom_ch_name_" .. i, "")
    local url = pref.getString("custom_ch_url_" .. i, "")
    local cat = pref.getString("custom_ch_cat_" .. i, "")
    if name ~= "" and url ~= "" and cat ~= "" then
      -- اب "Live music" کیٹیگری کا کوئی بھی چینل بلاک نہیں ہوگا
      seenNames[name:lower()] = {name = name, url = url, category = cat}
    end
  end
  for _, item in pairs(seenNames) do
    table.insert(_G.customChannelsList, item)
  end
end

local baseAryNewsChannels = {
  { name = "ARY News 1", url = "https://tamashaweb.com/ary-news" },
  { name = "ARY News 2", url = "http://live.arynews.tv/pk/" }
}

local baseGeoNewsChannels = {
  { name = "Geo News 1", url = "https://tamashaweb.com/geo-news-live" },
  { name = "Geo News 2", url = "https://live.geo.tv/" },
  { name = "Geo News 3", url = "https://live.geo.tv/stream2" }
}

local baseReligiousChannels = {
  { name = "ARY QTV", url = "https://live.aryqtv.tv/" },
  { name = "Madani Channel", url = "https://tamashaweb.com/madani-channel-live" },
  { name = "Paigham TV", url = "https://tamashaweb.com/paigham-tv" },
  { name = "Saudi Quran Makkah TV", url = "https://tamashaweb.com/saudi-quran-makk/ah-tv-hd-live" }
}

local baseSportsChannels = {
  { name = "Geo Super", url = "https://www.geosuper.tv/live" },
  { name = "PTV Sports", url = "https://tamashaweb.com/ptv-sports" }
}

local baseKidsChannels = {
  { name = "Baby TV", url = "https://tamashaweb.com/baby-tv-live" },
  { name = "Cartoon Network", url = "https://pakistan-tv.vercel.app/channels/cartoon-network-live" }
}

-- ایکٹو رن ٹائم لسٹیں جو مینو استعمال کریں گے
local entertainmentChannels = {}
local newsChannels = {}
local aryNewsChannels = {}
local geoNewsChannels = {}
local religiousChannels = {}
local sportsChannels = {}
local kidsChannels = {}
_G.customCategoryChannels = {}

local function saveCustomChannels()
  local editor = pref.edit()
  local oldCCount = pref.getInt("custom_channels_count", 0)
  for i = 1, oldCCount do
    editor.remove("custom_ch_name_" .. i)
    editor.remove("custom_ch_url_" .. i)
    editor.remove("custom_ch_cat_" .. i)
  end
  editor.putInt("custom_channels_count", #_G.customChannelsList)
  for i, c in ipairs(_G.customChannelsList) do
    editor.putString("custom_ch_name_" .. i, c.name)
    editor.putString("custom_ch_url_" .. i, c.url)
    editor.putString("custom_ch_cat_" .. i, c.category)
  end
  editor.commit()
end

-- تمام چینلز کو رینڈر کرنے اور لسٹیں سنک کرنے کا مین فنکشن
local function rebuildActiveChannels()
  entertainmentChannels = {}
  for _, v in ipairs(baseEntertainmentChannels) do table.insert(entertainmentChannels, {name=v.name, url=v.url}) end
  newsChannels = {}
  for _, v in ipairs(baseNewsChannels) do table.insert(newsChannels, {name=v.name, url=v.url}) end
  aryNewsChannels = {}
  for _, v in ipairs(baseAryNewsChannels) do table.insert(aryNewsChannels, {name=v.name, url=v.url}) end
  geoNewsChannels = {}
  for _, v in ipairs(baseGeoNewsChannels) do table.insert(geoNewsChannels, {name=v.name, url=v.url}) end
  religiousChannels = {}
  for _, v in ipairs(baseReligiousChannels) do table.insert(religiousChannels, {name=v.name, url=v.url}) end
  sportsChannels = {}
  for _, v in ipairs(baseSportsChannels) do table.insert(sportsChannels, {name=v.name, url=v.url}) end
  kidsChannels = {}
  for _, v in ipairs(baseKidsChannels) do table.insert(kidsChannels, {name=v.name, url=v.url}) end

  _G.customCategoryChannels = {}
  for _, cat in ipairs(_G.customCategoriesList) do
    _G.customCategoryChannels[cat.name] = {}
  end

  local function removeNameFromAllLists(name)
    local lists = {entertainmentChannels, newsChannels, aryNewsChannels, geoNewsChannels, religiousChannels, sportsChannels, kidsChannels}
    for _, list in ipairs(lists) do
      for i = #list, 1, -1 do
        if list[i].name:lower() == name:lower() then table.remove(list, i) end
      end
    end
    for catName, list in pairs(_G.customCategoryChannels) do
      for i = #list, 1, -1 do
        if list[i].name:lower() == name:lower() then table.remove(list, i) end
      end
    end
  end

  for _, c in ipairs(_G.customChannelsList) do
    removeNameFromAllLists(c.name) 
    
    local newChannel = {name = c.name, url = c.url}
    if c.category == "Entertainment" then
      table.insert(entertainmentChannels, newChannel)
    elseif c.category == "News (Main)" then
      table.insert(newsChannels, newChannel)
    elseif c.category == "ARY News" then
      table.insert(aryNewsChannels, newChannel)
    elseif c.category == "Geo News" then
      table.insert(geoNewsChannels, newChannel)
    elseif c.category == "Religious" then
      table.insert(religiousChannels, newChannel)
    elseif c.category == "Sports" then
      table.insert(sportsChannels, newChannel)
    elseif c.category == "Kids" then
      table.insert(kidsChannels, newChannel)
    else
      if _G.customCategoryChannels[c.category] then
        table.insert(_G.customCategoryChannels[c.category], newChannel)
      end
    end
  end

  sortChannelsAlphabetically(entertainmentChannels)
  sortChannelsAlphabetically(newsChannels)
  sortChannelsAlphabetically(aryNewsChannels)
  sortChannelsAlphabetically(geoNewsChannels)
  sortChannelsAlphabetically(religiousChannels)
  sortChannelsAlphabetically(sportsChannels)
  sortChannelsAlphabetically(kidsChannels)
  for catName, chList in pairs(_G.customCategoryChannels) do
    sortChannelsAlphabetically(chList)
  end
end

saveCustomChannels()
rebuildActiveChannels()

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
  if addChannelDialog then pcall(function() addChannelDialog.dismiss() end) addChannelDialog = nil end
  if deleteChannelDialog then pcall(function() deleteChannelDialog.dismiss() end) deleteChannelDialog = nil end
  if customCatDialog then pcall(function() customCatDialog.dismiss() end) customCatDialog = nil end
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

  local isCustomCat = false
  if categoryType and type(categoryType) == "string" and #categoryType >= 7 and categoryType:sub(1, 7) == "custom_" then
    isCustomCat = true
  end

  if categoryType == "news" or categoryType == "news_ary" or categoryType == "news_geo" or isCustomCat then
    local flatNews = {}
    for _, c in ipairs(list) do table.insert(flatNews, c) end
    list = flatNews
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

  pcall(function() WebView.enableSlowWholeDocumentDraw() end)
  
  myWebView = WebView(service)
  myWebView.setLayoutParams(FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT))
  myWebView.setBackgroundColor(0xFF000000)
  myWebView.setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS)
  myWebView.setLayerType(View.LAYER_TYPE_HARDWARE, nil)
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
  row1.setLayoutParams(LinearLayout.LayoutParams(WindowManager.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT))
  
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
  btnFullScreen.setVisibility(_G.isAudioOnlyMode and View.GONE or View.VISIBLE)

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
    btnFav.setText(checkIsFav() and "Remove from Favorites" or "Add to Favorites")
  end
  syncFavText()

  btnFav.setOnClickListener(View.OnClickListener({
    onClick = function(v)
      local favIdx = checkIsFav()
      if favIdx then
        table.remove(_G.favoritesList, favIdx)
        speakText("Removed from favorites")
      else
        table.insert(_G.favoritesList, {name = channel.name, url = channel.url})
        speakText("Added to favorites")
      end
      saveFavorites() 
      syncFavText()
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
        webContainer.setLayoutParams(LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.MATCH_PARENT))
        isFullScreen = true
        _G.SmartTV_IsFullScreen = true
        btnFullScreen.setText("Exit Full Screen")
      else
        lp.screenOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
        win.setAttributes(lp)
        win.clearFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN)
        win.getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_VISIBLE)
        txtNowPlaying.setVisibility(View.VISIBLE)
        controlsParent.setVisibility(View.VISIBLE)
        webContainer.setLayoutParams(LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, portraitHeight))
        isFullScreen = false
        _G.SmartTV_IsFullScreen = false
        btnFullScreen.setText("Full Screen")
      end
    end)
  end

  -- یونیورسل منیمائز لوجک
  local handleMinimizeAction = function()
    if not _G.isBackgroundPlayEnabled then
      speakText("Background play is turned off in settings")
      return
    end
    _G.SmartTV_IsPlayerMinimized = true
    speakText("Player minimized to background")
    dismissAllDialogs() 
    pcall(function()
      if playerDialog then
        local win = playerDialog.getWindow()
        win.addFlags(WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE | WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE)
        win.setBackgroundDrawable(ColorDrawable(0x00000000)) 
        mainContainer.setBackgroundColor(0x00000000)
        layout.setBackgroundColor(0x00000000)
        webContainer.setBackgroundColor(0x00000000)
        myWebView.setBackgroundColor(0x00000000)
        txtNowPlaying.setVisibility(View.GONE)
        controlsParent.setVisibility(View.GONE)
      end
    end)
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
    if myWebView then pcall(function() myWebView.stopLoading() myWebView.loadUrl("about:blank") end) end
    pcall(function()
      local win = playerDialog.getWindow()
      local lp = win.getAttributes()
      lp.screenOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
      win.setAttributes(lp)
    end)
    isFullScreen = false
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
    elseif isCustomCat then showCustomCategoryMenu(categoryType:sub(8))
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
  btnExitPlayer.setOnClickListener(View.OnClickListener({ onClick = function(v) closeExtension() end }))
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
        if _G.isBackgroundPlayEnabled then handleMinimizeAction() else goBackToMenu() end
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
  webSettings.setUserAgentString("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")

  myWebView.setWebChromeClient(luajava.override(WebChromeClient, {
    onShowCustomView = function(super, view, callback)
      if mCustomView then callback.onCustomViewHidden() return end
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
          style.innerHTML = `video { display: block !important; visibility: visible !important; position: fixed !important; top: 0 !important; left: 0 !important; width: 100% !important; height: 100% !important; z-index: 2147483647 !important; object-fit: contain !important; background: #000000 !important; }`;
      };
      forcePureVideoIsolation();
      if (!window.cleanTvIndestructibleInterval) { window.cleanTvIndestructibleInterval = setInterval(forcePureVideoIsolation, 150); }
  })();]]

  local function startVideoPollingCheck(overlayView, webInstance, boundLoadId)
    local attempts = 0
    local function loop()
      if (not webInstance or not overlayView or boundLoadId ~= currentLoadId) then return end
      attempts = attempts + 1
      webInstance.evaluateJavascript([[(function() { var v = document.querySelector('video'); return (v && (v.currentTime > 0 || v.readyState >= 2)) ? "READY" : "LOADING"; })();]], luajava.createProxy("android.webkit.ValueCallback", {
        onReceiveValue = function(res)
          if boundLoadId ~= currentLoadId then return end
          if res and (res:find("READY") or res == '"READY"') or attempts >= 50 then
            webInstance.evaluateJavascript(cleanJS, nil)
            overlayView.setVisibility(View.GONE)
            _G.isChannelLoading = false
          else
            webInstance.evaluateJavascript(cleanJS, nil)
            service.handler.postDelayed(Runnable({run = loop}), Long(200))
          end
        end
      }))
    end
    loop()
  end

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
    overlay.setText("Channel Loading...")
    overlay.setVisibility(View.VISIBLE)
    
    local extraHeaders = java.util.HashMap()
    extraHeaders.put("Referer", "https://tamashaweb.com/")
    myWebView.loadUrl(channel.url, extraHeaders)
    startVideoPollingCheck(overlay, myWebView, currentLoadId)
  end

  currentLoadId = currentLoadId + 1
  _G.isChannelLoading = true
  local extraHeaders = java.util.HashMap()
  extraHeaders.put("Referer", "https://tamashaweb.com/")
  myWebView.loadUrl(channel.url, extraHeaders)
  startVideoPollingCheck(overlay, myWebView, currentLoadId)
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

-- کسٹم رن ٹائم کیٹیگری مینو بنانے کا ڈائنامک فنکشن
function showCustomCategoryMenu(catName)
  dismissAllDialogs()
  local sv = ScrollView(service)
  local layout = LinearLayout(service)
  layout.setOrientation(LinearLayout.VERTICAL)
  layout.setPadding(60, 40, 60, 40)
  sv.addView(layout)
  
  local title = TextView(service)
  title.setText(catName)
  title.setTextSize(18)
  title.setGravity(Gravity.CENTER)
  title.setPadding(0, 10, 0, 30)
  layout.addView(title)
  
  local chList = _G.customCategoryChannels[catName] or {}
  for i, ch in ipairs(chList) do 
    layout.addView(createChannelButton(ch, chList, i, "custom_" .. catName)) 
  end
  
  local parentMenu = "Main Menu"
  for _, cat in ipairs(_G.customCategoriesList) do
    if cat.name == catName then parentMenu = cat.parent break end
  end
  
  local btnBack = Button(service)
  btnBack.setText("Back")
  btnBack.setOnClickListener(View.OnClickListener({ onClick = function(v) 
    dismissAllDialogs() 
    if parentMenu == "News (Main)" then showNewsMenu()
    elseif parentMenu == "Entertainment" then showChannelsMenu()
    elseif parentMenu == "Kids" then showKidsMenu()
    elseif parentMenu == "Religious" then showReligiousMenu()
    elseif parentMenu == "Sports" then showSportsMenu()
    else showTvMenu() end
  end }))
  layout.addView(btnBack)
  
  customCatDialog = AlertDialog.Builder(service).setView(sv).create()
  safeShow(customCatDialog)
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
  
  for i, ch in ipairs(_G.favoritesList) do layout.addView(createChannelButton(ch, _G.favoritesList, i, "favorites")) end
  
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
  
  for i, ch in ipairs(aryNewsChannels) do layout.addView(createChannelButton(ch, aryNewsChannels, i, "news_ary")) end
  
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
  
  for i, ch in ipairs(geoNewsChannels) do layout.addView(createChannelButton(ch, geoNewsChannels, i, "news_geo")) end
  
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
  
  local displayList = {}
  for i, ch in ipairs(newsChannels) do
    table.insert(displayList, { isSub = false, name = ch.name, url = ch.url, idx = i })
  end
  table.insert(displayList, { isSub = true, name = "ARY News", action = showAryNewsMenu })
  table.insert(displayList, { isSub = true, name = "Geo News", action = showGeoNewsMenu })
  
  for _, cat in ipairs(_G.customCategoriesList) do
    if cat.parent == "News (Main)" then
      table.insert(displayList, { isSub = true, name = cat.name, action = function() showCustomCategoryMenu(cat.name) end })
    end
  end
  
  table.sort(displayList, function(a, b) return a.name:lower() < b.name:lower() end)
  
  for _, item in ipairs(displayList) do
    if item.isSub then
      local btnSub = Button(service)
      btnSub.setText(item.name)
      btnSub.setOnClickListener(View.OnClickListener({ onClick = function(v) item.action() end }))
      layout.addView(btnSub)
    else
      layout.addView(createChannelButton({name = item.name, url = item.url}, newsChannels, item.idx, "news"))
    end
  end
  
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
  
  local displayList = {}
  for i, ch in ipairs(entertainmentChannels) do
    table.insert(displayList, { isSub = false, name = ch.name, url = ch.url, idx = i })
  end
  for _, cat in ipairs(_G.customCategoriesList) do
    if cat.parent == "Entertainment" then
      table.insert(displayList, { isSub = true, name = cat.name, action = function() showCustomCategoryMenu(cat.name) end })
    end
  end
  table.sort(displayList, function(a, b) return a.name:lower() < b.name:lower() end)
  
  for _, item in ipairs(displayList) do
    if item.isSub then
      local btnSub = Button(service)
      btnSub.setText(item.name)
      btnSub.setOnClickListener(View.OnClickListener({ onClick = function(v) item.action() end }))
      layout.addView(btnSub)
    else
      layout.addView(createChannelButton({name = item.name, url = item.url}, entertainmentChannels, item.idx, "entertainment"))
    end
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
  
  local displayList = {}
  for i, ch in ipairs(kidsChannels) do
    table.insert(displayList, { isSub = false, name = ch.name, url = ch.url, idx = i })
  end
  for _, cat in ipairs(_G.customCategoriesList) do
    if cat.parent == "Kids" then
      table.insert(displayList, { isSub = true, name = cat.name, action = function() showCustomCategoryMenu(cat.name) end })
    end
  end
  table.sort(displayList, function(a, b) return a.name:lower() < b.name:lower() end)

  for _, item in ipairs(displayList) do
    if item.isSub then
      local btnSub = Button(service)
      btnSub.setText(item.name)
      btnSub.setOnClickListener(View.OnClickListener({ onClick = function(v) item.action() end }))
      layout.addView(btnSub)
    else
      layout.addView(createChannelButton({name = item.name, url = item.url}, kidsChannels, item.idx, "kids"))
    end
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
  
  local displayList = {}
  for i, ch in ipairs(religiousChannels) do
    table.insert(displayList, { isSub = false, name = ch.name, url = ch.url, idx = i })
  end
  for _, cat in ipairs(_G.customCategoriesList) do
    if cat.parent == "Religious" then
      table.insert(displayList, { isSub = true, name = cat.name, action = function() showCustomCategoryMenu(cat.name) end })
    end
  end
  table.sort(displayList, function(a, b) return a.name:lower() < b.name:lower() end)

  for _, item in ipairs(displayList) do
    if item.isSub then
      local btnSub = Button(service)
      btnSub.setText(item.name)
      btnSub.setOnClickListener(View.OnClickListener({ onClick = function(v) item.action() end }))
      layout.addView(btnSub)
    else
      layout.addView(createChannelButton({name = item.name, url = item.url}, religiousChannels, item.idx, "religious"))
    end
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
  
  local displayList = {}
  for i, ch in ipairs(sportsChannels) do
    table.insert(displayList, { isSub = false, name = ch.name, url = ch.url, idx = i })
  end
  for _, cat in ipairs(_G.customCategoriesList) do
    if cat.parent == "Sports" then
      table.insert(displayList, { isSub = true, name = cat.name, action = function() showCustomCategoryMenu(cat.name) end })
    end
  end
  table.sort(displayList, function(a, b) return a.name:lower() < b.name:lower() end)

  for _, item in ipairs(displayList) do
    if item.isSub then
      local btnSub = Button(service)
      btnSub.setText(item.name)
      btnSub.setOnClickListener(View.OnClickListener({ onClick = function(v) item.action() end }))
      layout.addView(btnSub)
    else
      layout.addView(createChannelButton({name = item.name, url = item.url}, sportsChannels, item.idx, "sports"))
    end
  end
  
  local btnBack = Button(service)
  btnBack.setText("Back to Main Menu")
  btnBack.setOnClickListener(View.OnClickListener({ onClick = function(v) dismissAllDialogs() showTvMenu() end }))
  layout.addView(btnBack)
  sportsDialog = AlertDialog.Builder(service).setView(sv).create()
  safeShow(sportsDialog)
end

function showAddChannelMenu()
  dismissAllDialogs()
  local sv = ScrollView(service)
  local layout = LinearLayout(service)
  layout.setOrientation(LinearLayout.VERTICAL)
  layout.setPadding(60, 40, 60, 40)
  sv.addView(layout)
  
  local heading = TextView(service)
  heading.setText("Add Channel")
  heading.setTextSize(20)
  heading.setGravity(Gravity.CENTER)
  heading.setPadding(0, 10, 0, 30)
  layout.addView(heading)
  
  local lblName = TextView(service)
  lblName.setText("Enter Your Channel Name:")
  lblName.setTextSize(14)
  lblName.setPadding(0, 20, 0, 0)
  layout.addView(lblName)
  
  local etName = EditText(service)
  layout.addView(etName)
  
  local lblUrl = TextView(service)
  lblUrl.setText("Enter Your Channel URL:")
  lblUrl.setTextSize(14)
  lblUrl.setPadding(0, 20, 0, 0)
  layout.addView(lblUrl)
  
  local etUrl = EditText(service)
  layout.addView(etUrl)
  
  local lblCategory = TextView(service)
  lblCategory.setText("Choose Your Category:")
  lblCategory.setTextSize(14)
  lblCategory.setPadding(0, 20, 0, 10)
  layout.addView(lblCategory)
  
  local categories = {"Entertainment", "News (Main)", "ARY News", "Geo News", "Religious", "Sports", "Kids"}
  for _, cat in ipairs(_G.customCategoriesList) do
    table.insert(categories, cat.name)
  end
  table.insert(categories, "Create a New Category...")
  
  local adapter = ArrayAdapter(service, android.R.layout.simple_spinner_item, categories)
  adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
  
  local spinner = Spinner(service)
  spinner.setAdapter(adapter)
  layout.addView(spinner)
  
  local customCatContainer = LinearLayout(service)
  customCatContainer.setOrientation(LinearLayout.VERTICAL)
  customCatContainer.setVisibility(View.GONE)
  
  local lblNewCatName = TextView(service)
  lblNewCatName.setText("Enter New Category Name:")
  lblNewCatName.setTextSize(14)
  lblNewCatName.setPadding(0, 20, 0, 0)
  customCatContainer.addView(lblNewCatName)
  
  local etNewCatName = EditText(service)
  customCatContainer.addView(etNewCatName)
  
  local lblPlacement = TextView(service)
  lblPlacement.setText("Select Category Placement (Parent):")
  lblPlacement.setTextSize(14)
  lblPlacement.setPadding(0, 20, 0, 10)
  customCatContainer.addView(lblPlacement)
  
  local placements = {"Main Menu", "Entertainment", "News (Main)", "Religious", "Sports", "Kids"}
  local placementAdapter = ArrayAdapter(service, android.R.layout.simple_spinner_item, placements)
  placementAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
  
  local placementSpinner = Spinner(service)
  placementSpinner.setAdapter(placementAdapter)
  customCatContainer.addView(placementSpinner)
  
  layout.addView(customCatContainer)
  
  local btnAdd = Button(service)
  btnAdd.setText("Add Channel")
  btnAdd.setPadding(0, 30, 0, 10)
  layout.addView(btnAdd)
  
  local selectedCatPosition = 0
  local selectedPlacementPosition = 0
  
  spinner.setOnItemSelectedListener(luajava.createProxy("android.widget.AdapterView$OnItemSelectedListener", {
    onItemSelected = function(parent, view, position, id)
      selectedCatPosition = position
      if categories[position + 1] == "Create a New Category..." then
        lblName.setVisibility(View.VISIBLE)
        etName.setVisibility(View.VISIBLE)
        lblUrl.setVisibility(View.VISIBLE)
        etUrl.setVisibility(View.VISIBLE)
        customCatContainer.setVisibility(View.VISIBLE)
        heading.setText("Create New Category & Add Channel")
        btnAdd.setText("Create & Add Live")
      else
        lblName.setVisibility(View.VISIBLE)
        etName.setVisibility(View.VISIBLE)
        lblUrl.setVisibility(View.VISIBLE)
        etUrl.setVisibility(View.VISIBLE)
        customCatContainer.setVisibility(View.GONE)
        heading.setText("Add Channel")
        btnAdd.setText("Add Channel")
      end
    end,
    onNothingSelected = function(parent) end
  }))
  
  placementSpinner.setOnItemSelectedListener(luajava.createProxy("android.widget.AdapterView$OnItemSelectedListener", {
    onItemSelected = function(parent, view, position, id)
      selectedPlacementPosition = position
    end,
    onNothingSelected = function(parent) end
  }))
  
  btnAdd.setOnClickListener(View.OnClickListener({
    onClick = function(v)
      local selectedCat = tostring(spinner.getSelectedItem())
      
      if selectedCat == "Create a New Category..." then
        local newCatName = tostring(etNewCatName.getText())
        local parentMenu = tostring(placementSpinner.getSelectedItem())
        
        if newCatName == "" then
          Toast.makeText(service, "Please enter a category name", Toast.LENGTH_SHORT).show()
          return
        end
        
        local catExists = false
        for _, cat in ipairs(_G.customCategoriesList) do
          if cat.name:lower() == newCatName:lower() then
            catExists = true
            break
          end
        end
        
        if not catExists then
          table.insert(_G.customCategoriesList, {name = newCatName, parent = parentMenu})
          saveCustomCategories()
          rebuildActiveChannels()
          Toast.makeText(service, "Category '" .. newCatName .. "' created successfully", Toast.LENGTH_SHORT).show()
          speakText(newCatName .. " category successfully created")
        else
          Toast.makeText(service, "Category already exists", Toast.LENGTH_SHORT).show()
        end
        
        local name = tostring(etName.getText())
        local url = tostring(etUrl.getText())
        
        if name ~= "" and url ~= "" then
          local existingIndex = nil
          for idx, c in ipairs(_G.customChannelsList) do
            if c.name:lower() == name:lower() then existingIndex = idx break end
          end
          
          if existingIndex then
            _G.customChannelsList[existingIndex].url = url
            _G.customChannelsList[existingIndex].category = newCatName
            Toast.makeText(service, name .. " replaced in " .. newCatName, Toast.LENGTH_SHORT).show()
            speakText(name .. " successfully updated")
          else
            table.insert(_G.customChannelsList, {name = name, url = url, category = newCatName})
            Toast.makeText(service, name .. " added to " .. newCatName, Toast.LENGTH_SHORT).show()
            speakText(name .. " successfully added")
          end
          
          saveCustomChannels()
          rebuildActiveChannels()
          dismissAllDialogs()
          showSettingsMenu()
        else
          dismissAllDialogs()
          showAddChannelMenu()
        end
      else
        local name = tostring(etName.getText())
        local url = tostring(etUrl.getText())
        
        if name == "" or url == "" then
          Toast.makeText(service, "Please fill all fields", Toast.LENGTH_SHORT).show()
          return
        end
        
        local existingIndex = nil
        for idx, c in ipairs(_G.customChannelsList) do
          if c.name:lower() == name:lower() then existingIndex = idx break end
        end
        
        if existingIndex then
          _G.customChannelsList[existingIndex].url = url
          _G.customChannelsList[existingIndex].category = selectedCat
          Toast.makeText(service, name .. " replaced in " .. selectedCat, Toast.LENGTH_SHORT).show()
          speakText(name .. " successfully updated")
        else
          table.insert(_G.customChannelsList, {name = name, url = url, category = selectedCat})
          Toast.makeText(service, name .. " added to " .. selectedCat, Toast.LENGTH_SHORT).show()
          speakText(name .. " successfully added")
        end
        
        saveCustomChannels()
        rebuildActiveChannels()
        dismissAllDialogs()
        showSettingsMenu()
      end
    end
  }))
  
  local btnBack = Button(service)
  btnBack.setText("Back to Settings")
  btnBack.setOnClickListener(View.OnClickListener({ onClick = function(v) dismissAllDialogs() showSettingsMenu() end }))
  layout.addView(btnBack)
  
  addChannelDialog = AlertDialog.Builder(service).setView(sv).create()
  safeShow(addChannelDialog)
end

-- ڈیلیٹ آپشنز کا مین مینو
function showDeleteMenu()
  dismissAllDialogs()
  local sv = ScrollView(service)
  local layout = LinearLayout(service)
  layout.setOrientation(LinearLayout.VERTICAL)
  layout.setPadding(60, 40, 60, 40)
  sv.addView(layout)
  
  local heading = TextView(service)
  heading.setText("Delete Channel & Category")
  heading.setTextSize(20)
  heading.setGravity(Gravity.CENTER)
  heading.setPadding(0, 10, 0, 30)
  layout.addView(heading)
  
  local btnDelCh = Button(service)
  btnDelCh.setText("Delete Channel")
  btnDelCh.setOnClickListener(View.OnClickListener({ onClick = function(v) showDeleteChannelSubMenu() end }))
  layout.addView(btnDelCh)
  
  local btnDelCat = Button(service)
  btnDelCat.setText("Delete Category")
  btnDelCat.setOnClickListener(View.OnClickListener({ onClick = function(v) showDeleteCategorySubMenu() end }))
  layout.addView(btnDelCat)
  
  local btnBack = Button(service)
  btnBack.setText("Back to Settings")
  btnBack.setOnClickListener(View.OnClickListener({ onClick = function(v) dismissAllDialogs() showSettingsMenu() end }))
  layout.addView(btnBack)
  
  deleteChannelDialog = AlertDialog.Builder(service).setView(sv).create()
  safeShow(deleteChannelDialog)
end

-- کسٹم چینلز ڈیلیٹ کرنے کا مینو
function showDeleteChannelSubMenu()
  dismissAllDialogs()
  local sv = ScrollView(service)
  local layout = LinearLayout(service)
  layout.setOrientation(LinearLayout.VERTICAL)
  layout.setPadding(60, 40, 60, 40)
  sv.addView(layout)
  
  local heading = TextView(service)
  heading.setText("Delete Channels")
  heading.setTextSize(20)
  heading.setGravity(Gravity.CENTER)
  heading.setPadding(0, 10, 0, 30)
  layout.addView(heading)
  
  if #_G.customChannelsList == 0 then
    local noChTxt = TextView(service)
    noChTxt.setText("No custom channels found to delete.")
    noChTxt.setTextSize(14)
    noChTxt.setGravity(Gravity.CENTER)
    noChTxt.setPadding(0, 20, 0, 20)
    layout.addView(noChTxt)
  else
    for i, c in ipairs(_G.customChannelsList) do
      local btn = Button(service)
      btn.setText(c.name .. " (" .. c.category .. ")")
      btn.setOnClickListener(View.OnClickListener({
        onClick = function(v)
          local chName = c.name
          local alert = AlertDialog.Builder(service)
          alert.setTitle("Do you want to delete " .. chName .. "?")
          alert.setNegativeButton("No", luajava.createProxy("android.content.DialogInterface$OnClickListener", {
            onClick = function(dialog, which) dialog.dismiss() end
          }))
          alert.setPositiveButton("Yes", luajava.createProxy("android.content.DialogInterface$OnClickListener", {
            onClick = function(dialog, which)
              -- فکس: چینل کو پسندیدہ (Favorites) لسٹ سے بھی حذف کریں
              local chUrl = c.url
              for fIdx = #_G.favoritesList, 1, -1 do
                if _G.favoritesList[fIdx].url == chUrl then
                  table.remove(_G.favoritesList, fIdx)
                end
              end
              saveFavorites()

              table.remove(_G.customChannelsList, i)
              saveCustomChannels()
              rebuildActiveChannels()
              Toast.makeText(service, chName .. " Deleted Permanently", Toast.LENGTH_SHORT).show()
              speakText(chName .. " deleted")
              dialog.dismiss()
              showDeleteChannelSubMenu()
            end
          }))
          local alertDialog = alert.create()
          alertDialog.getWindow().setType(WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY)
          alertDialog.show()
        end
      }))
      layout.addView(btn)
    end
  end
  
  local btnBack = Button(service)
  btnBack.setText("Back")
  btnBack.setOnClickListener(View.OnClickListener({ onClick = function(v) showDeleteMenu() end }))
  layout.addView(btnBack)
  
  deleteChannelDialog = AlertDialog.Builder(service).setView(sv).create()
  safeShow(deleteChannelDialog)
end

-- کسٹم کیٹیگریز ڈیلیٹ کرنے کا مینو
function showDeleteCategorySubMenu()
  dismissAllDialogs()
  local sv = ScrollView(service)
  local layout = LinearLayout(service)
  layout.setOrientation(LinearLayout.VERTICAL)
  layout.setPadding(60, 40, 60, 40)
  sv.addView(layout)
  
  local heading = TextView(service)
  heading.setText("Delete Categories")
  heading.setTextSize(20)
  heading.setGravity(Gravity.CENTER)
  heading.setPadding(0, 10, 0, 30)
  layout.addView(heading)
  
  if #_G.customCategoriesList == 0 then
    local noCatTxt = TextView(service)
    noCatTxt.setText("No custom categories found to delete.")
    noCatTxt.setTextSize(14)
    noCatTxt.setGravity(Gravity.CENTER)
    noCatTxt.setPadding(0, 20, 0, 20)
    layout.addView(noCatTxt)
  else
    for i, cat in ipairs(_G.customCategoriesList) do
      local btn = Button(service)
      btn.setText(cat.name .. " (" .. cat.parent .. ")")
      btn.setOnClickListener(View.OnClickListener({
        onClick = function(v)
          local catName = cat.name
          local alert = AlertDialog.Builder(service)
          alert.setTitle("Do you want to delete category " .. catName .. "?")
          alert.setNegativeButton("No", luajava.createProxy("android.content.DialogInterface$OnClickListener", {
            onClick = function(dialog, which) dialog.dismiss() end
          }))
          alert.setPositiveButton("Yes", luajava.createProxy("android.content.DialogInterface$OnClickListener", {
            onClick = function(dialog, which)
              table.remove(_G.customCategoriesList, i)
              saveCustomCategories()
              
              for j = #_G.customChannelsList, 1, -1 do
                if _G.customChannelsList[j].category == catName then
                  -- فکس: اس کیٹیگری کے جتنے بھی چینلز ہیں، انہیں پسندیدہ (Favorites) سے بھی ہٹائیں
                  local chUrl = _G.customChannelsList[j].url
                  for fIdx = #_G.favoritesList, 1, -1 do
                    if _G.favoritesList[fIdx].url == chUrl then
                      table.remove(_G.favoritesList, fIdx)
                    end
                  end
                  table.remove(_G.customChannelsList, j)
                end
              end
              saveFavorites()
              saveCustomChannels()
              rebuildActiveChannels()
              
              Toast.makeText(service, catName .. " Category Deleted Permanently", Toast.LENGTH_SHORT).show()
              speakText(catName .. " deleted")
              dialog.dismiss()
              showDeleteCategorySubMenu()
            end
          }))
          local alertDialog = alert.create()
          alertDialog.getWindow().setType(WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY)
          alertDialog.show()
        end
      }))
      layout.addView(btn)
    end
  end
  
  local btnBack = Button(service)
  btnBack.setText("Back")
  btnBack.setOnClickListener(View.OnClickListener({ onClick = function(v) showDeleteMenu() end }))
  layout.addView(btnBack)
  
  deleteChannelDialog = AlertDialog.Builder(service).setView(sv).create()
  safeShow(deleteChannelDialog)
end

-- اباؤٹ مینو کا مکمل تفصیلی فنکشن (بالکل اسی جگہ فکسڈ تفصیلات کے ساتھ)
function showAboutMenu()
  dismissAllDialogs()
  local sv = ScrollView(service)
  local layout = LinearLayout(service)
  layout.setOrientation(LinearLayout.VERTICAL)
  layout.setPadding(60, 40, 60, 40)
  sv.addView(layout)
  
  -- مینو کا مین ٹائٹل
  local title = TextView(service)
  title.setText("About Smart TV Extension")
  title.setTextSize(18)
  title.setGravity(Gravity.CENTER)
  title.setPadding(0, 10, 0, 20)
  layout.addView(title)
  
  -- ایپ کی تفصیلی گائیڈ بشمول چینل اور کسٹم کیٹیگری مینجمنٹ کی مکمل لاجک
  local infoTxt = TextView(service)
  infoTxt.setTextSize(14)
  infoTxt.setText("This extension is designed to provide seamless live television access categorization-wise:\n\n" ..
                 "1. Entertainment: Top standard entertainment dramas and shows.\n" ..
                 "2. Live News: Mainstream news networks directly streamed.\n" ..
                 "3. Religious: Holy streams including Makkah Live and spiritual content.\n" ..
                 "4. Live Sports: Realtime action of your favorite matches.\n" ..
                 "5. Live Kids: Fun and educational content for children.\n\n" ..
                 "CUSTOM CUSTOMIZATION & MANAGEMENT SYSTEM:\n" ..
                 "--------------------------------------------------\n" ..
                 "• CHANNEL MANAGEMENT:\n" ..
                 "  - Add Channel: This option allows you to manually insert a custom Channel Name and its streaming URL. You can easily link it to any default category or route it inside your own custom categories.\n" ..
                 "  - Delete Channel: This tool allows you to safely view all custom added channels and delete any specific channel permanently to keep your stream list precise.\n\n" ..
                 "• CATEGORY MANAGEMENT:\n" ..
                 "  - Create New Category: This feature gives you full power to build custom categories with a custom Parent Placement (such as Main Menu, Entertainment, Live News, etc.) smoothly.\n" ..
                 "  - Delete Category: This manager lets you permanently delete any custom category you created, which automatically clears and flushes all embedded channels tied to it for a clean user interface layout.\n\n")
  infoTxt.setPadding(0, 10, 0, 10)
  layout.addView(infoTxt)
  
  -- ڈویلپمنٹ کریڈٹس کی ہیڈنگ
  local creditsTitle = TextView(service)
  creditsTitle.setText("DEVELOPMENT CREDITS")
  creditsTitle.setTextSize(16)
  creditsTitle.setPadding(0, 10, 0, 10)
  layout.addView(creditsTitle)
  
  -- ڈویلپرز کے نام اور تفصیلات
  local creditsTxt = TextView(service)
  creditsTxt.setTextSize(14)
  creditsTxt.setText("Lead Conception and Architecture:\n" ..
                     "Ahmad Ali\n" ..
                     "Responsible for the core concept, main structure, and Category/Channel management planning.\n\n" ..
                     "Core Integration and Feature Engineering:\n" ..
                     "Ali Gujjar\n" ..
                     "Responsible for channel source integration, playback features, and core implementation of Category/Channel Add/Delete logic.\n\n" ..
                     "Technical Optimization and Debugging:\n" ..
                     "Azlan Tahir\n" ..
                     "Responsible for fixing system bugs, optimizing code efficiency, and debugging Category/Channel features.\n\n" ..
                     "Proudly developed with advanced accessibility compliance for smooth and intuitive interactions.")
  creditsTxt.setPadding(0, 0, 0, 30)
  layout.addView(creditsTxt)
  
  -- 4. کینسل (Cancel) بٹن کی لاجک
  local btnCancel = Button(service)
  btnCancel.setText("Cancel")
  btnCancel.setOnClickListener(View.OnClickListener({ 
    onClick = function(v) 
      dismissAllDialogs() 
      showSettingsMenu() 
    end 
  }))
  layout.addView(btnCancel)
  
  -- 5. ہیلپ اینڈ فیڈ بیک (Help & Feedback) بٹن کی مکمل لاجک
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
  
  local settingsTitle = TextView(service)
  settingsTitle.setText("Smart TV Settings")
  settingsTitle.setTextSize(18)
  settingsTitle.setGravity(Gravity.CENTER)
  settingsTitle.setPadding(0, 10, 0, 40)
  layout.addView(settingsTitle)
  
  local btnAddChannel = Button(service)
  btnAddChannel.setText("Add Channel")
  btnAddChannel.setOnClickListener(View.OnClickListener({ onClick = function(v) showAddChannelMenu() end }))
  layout.addView(btnAddChannel)
  
  local btnDeleteChannel = Button(service)
  btnDeleteChannel.setText("Delete Channel & Category")
  btnDeleteChannel.setOnClickListener(View.OnClickListener({ onClick = function(v) showDeleteMenu() end }))
  layout.addView(btnDeleteChannel)
  
  local btnAudioToggle = Button(service)
  btnAudioToggle.setText("Play TV in Audio Mode: " .. (_G.isAudioOnlyMode and "ON" or "OFF"))
  btnAudioToggle.setOnClickListener(View.OnClickListener({
    onClick = function(v)
      _G.isAudioOnlyMode = not _G.isAudioOnlyMode
      local editor = pref.edit()
      editor.putInt("isAudioMode", _G.isAudioOnlyMode and 1 or 0)
      editor.commit()
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
      editor.commit()
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
  table.insert(buttons, {text="Live Entertainment", action=showChannelsMenu, sortName="Live Entertainment"})
  table.insert(buttons, {text="Live Kids", action=showKidsMenu, sortName="Live Kids"})
  table.insert(buttons, {text="Live News", action=showNewsMenu, sortName="Live News"})
  table.insert(buttons, {text="Live Religious", action=showReligiousMenu, sortName="Live Religious"})
  table.insert(buttons, {text="Live Sports", action=showSportsMenu, sortName="Live Sports"})
  
  for _, cat in ipairs(_G.customCategoriesList) do
    if cat.parent == "Main Menu" then
      table.insert(buttons, {text=cat.name, action=function() showCustomCategoryMenu(cat.name) end, sortName=cat.name})
    end
  end
  
  table.sort(buttons, function(a, b) return a.sortName:lower() < b.sortName:lower() end)
  
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