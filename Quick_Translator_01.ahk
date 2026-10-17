#Requires AutoHotkey v2.0
#SingleInstance Off

; IMPORTANT: Mouse positions used by the idle/wake monitor are compared with
; screen-coordinate window rectangles. Keep MouseGetPos in screen coordinates
; so behavior is consistent for windowed/maximized Roblox clients and other apps.
CoordMode("Mouse", "Screen")

; ============================================================
; Quick Translator - Roblox Edition
; OCR activity guard: pause auto-idle until OCR text is copied/timeout
; Dropdown popup coordinate/hit-test fix + stable hover wake detection across Roblox windows.
;
; Source editor Enter:
;   1. Translate immediately if needed.
;   2. Wait for the current translation to finish.
;   3. Activate the selected Roblox window.
;   4. Open chat, replace the existing draft and paste (no auto-send).
; Paste to Chat button:
;   Open chat, replace the draft, paste the translation, and press Enter.
;
; Other features:
; - Separate source and target language selectors
; - Auto-translate after a typing pause
; - Dark edit fields and dark clickable buttons
; - Adjustable font size and resizable window
; - Remembers window size and Roblox-relative position
; - Follows the Roblox window under the mouse
; - Follows normal foreground stacking; emoji pin suppresses automatic idle mode only
; - Selectable/copyable read-only status text styled like a plain label
; - Double-click blank/non-edit surfaces to toggle full/idle display
; - Remains visible behind other apps instead of hiding
; - Automatic line wrapping and triple-click Select All
; - Google unofficial translation endpoint
; ============================================================


; ============================================================
; USER-EDITABLE SETTINGS
; Change only these values to adjust idle timing and opacity.
; Opacity is the visible/opaque percentage: 100 = fully opaque.
; ============================================================
global IdleModeDelaySeconds := 5        ; Seconds without use before title-bar-only mode
global ActiveWindowOpacityPercent := 80 ; Whole translator window while active
global IdleTitleBarOpacityPercent := 50 ; Remaining title bar while idle
global LanguageDropdownPopupWidth := 280 ; Fixed width for source/target language menus (px)

; OCR button shortcut. AutoHotkey Send notation examples:
;   "!t" = Alt+T, "#+t" = Win+Shift+T, "^!o" = Ctrl+Alt+O.
; Change this single value to alter the system-wide OCR shortcut.
global OCRShortcutSend := "#+t" ; Win+Shift+T
global OCRClipboardWaitSeconds := 30 ; Maximum wait for OCR text after region selection
global OCRClipboardStablePollsRequired := 3 ; Require stable clipboard text across polls

; OCR clipboard watcher state. It is enabled only by clicking the OCR button.
global OCRCaptureActive := false
global OCRCaptureStartSequence := 0
global OCRCaptureDeadlineTick := 0
global OCRCaptureCandidateText := ""
global OCRCaptureStablePolls := 0
; Z-order / visibility state to restore when OCR selection and clipboard capture end.
; OCR's fullscreen selector may cover the translator while active; after capture,
; bring the translator back before writing the recognized text into its edit control.
global OCRRestoreZMode := "normal"
global OCRRestoreWindowPending := false

; Instance ID is needed to give each spawned translator a unique native title.
global TranslatorInstanceId := RegExReplace(GetLaunchArgument("instance", "main"), "[^A-Za-z0-9_-]", "")
if (TranslatorInstanceId = "")
    TranslatorInstanceId := "main"

; ============================================================
; GLOBAL VARIABLES
; ============================================================

; Use a custom client-area title bar instead of the native Windows caption.
; This lets the dark bar remain dark while the idle region is clipped/translucent.
global MainGui := Gui(
    "+Resize +MinSize344x350 -Caption +E0x40000",
    "Quick Translator [" . TranslatorInstanceId . "]"
)

global TitleBar
global TitleText
global MinimizeButton
global AlwaysOnTopButton
global FontLabel
global LanguageLabel

global SourceDrop
global TargetDrop
global FontDrop
global SourceSelectorFace
global TargetSelectorFace
global FontSelectorFace
global SelectorPopupGui := 0
global SelectorPopupList := 0
global SelectorPopupKind := ""
global SelectorPopupFace := 0
global SelectorPopupOpenedTick := 0
global SelectorPopupLastLeftDown := false

global SourceEdit
global ResultEdit

global CopyButton
global ClearButton
global TargetClearButton
global SourceEmojiButton
global ChatEmojiButton
global AddTranslatorButton
global RemoveTranslatorButton
global OCRButton
global PasteInputButton
global StatusText

global SourceLanguages := [
    "Auto detect",
    "Korean",
    "English",
    "Japanese",
    "Chinese (Simplified)",
    "Chinese (Traditional)",
    "Spanish",
    "French",
    "German",
    "Portuguese",
    "Italian",
    "Russian",
    "Thai",
    "Vietnamese"
]

global SourceCodes := [
    "auto",
    "ko",
    "en",
    "ja",
    "zh-CN",
    "zh-TW",
    "es",
    "fr",
    "de",
    "pt",
    "it",
    "ru",
    "th",
    "vi"
]

global TargetLanguages := [
    "English",
    "Japanese",
    "Chinese (Simplified)",
    "Chinese (Traditional)",
    "Spanish",
    "French",
    "German",
    "Portuguese",
    "Italian",
    "Russian",
    "Thai",
    "Vietnamese",
    "Korean",
    "Indonesian"
]

global TargetCodes := [
    "en",
    "ja",
    "zh-CN",
    "zh-TW",
    "es",
    "fr",
    "de",
    "pt",
    "it",
    "ru",
    "th",
    "vi",
    "ko",
    "id"
]

global FontSizes := [
    "9", "10", "11", "12", "14",
    "16", "18", "20", "24"
]

global ScriptPID := DllCall(
    "kernel32\GetCurrentProcessId",
    "UInt"
)

; A fresh primary launch may close a previous primary/legacy translator, but
; secondary instances spawned by + must never close their parent or siblings.
if (TranslatorInstanceId = "main")
    CloseStaleQuickTranslatorInstances()

; Each additional translator is a separate process so its input, translation,
; dropdowns, and buttons remain independent from every other translator.
global StartupPositionXArg := GetLaunchArgument("startx", "")
global StartupPositionYArg := GetLaunchArgument("starty", "")
global StartupPositionPending := (StartupPositionXArg != "" && StartupPositionYArg != "")
global StartupPositionX := (StartupPositionXArg = "" ? 0 : StartupPositionXArg + 0)
global StartupPositionY := (StartupPositionYArg = "" ? 0 : StartupPositionYArg + 0)
global StartupTargetRobloxHwnd := GetLaunchArgument("targethwnd", "0") + 0
global StartupWidthArg := GetLaunchArgument("width", "0") + 0
global StartupHeightArg := GetLaunchArgument("height", "0") + 0
global StartupSourceIndexArg := GetLaunchArgument("source", "0") + 0
global StartupTargetIndexArg := GetLaunchArgument("target", "0") + 0
global StartupFontIndexArg := GetLaunchArgument("font", "0") + 0

; Keep one stable profile for the primary window and a separate profile for
; each spawned window, preventing their positions/preferences from overwriting
; each other. All INI files remain under the user's writable LocalAppData folder.
global SettingsRoot := EnvGet("LOCALAPPDATA")
if (SettingsRoot = "")
    SettingsRoot := A_ScriptDir
global SettingsDirectory := SettingsRoot . "\QuickTranslator"
global LegacySettingsPath := A_ScriptDir . "\Quick_Translator_RobloxOnly.ini"
global SettingsFileName := "Quick_Translator_RobloxOnly" . (TranslatorInstanceId = "main" ? "" : "_" . TranslatorInstanceId) . ".ini"
global SettingsPath := SettingsDirectory . "\" . SettingsFileName
try DirCreate(SettingsDirectory)
try {
    if (TranslatorInstanceId = "main" && !FileExist(SettingsPath) && FileExist(LegacySettingsPath))
        FileCopy(LegacySettingsPath, SettingsPath)
}

; On a fresh primary launch, remove INI profiles left behind by additional
; translator instances that are no longer running. Live additional windows keep
; their individual profiles so their active settings are not deleted.
if (TranslatorInstanceId = "main")
    CleanupUnusedAdditionalProfiles(SettingsDirectory)

global TargetRobloxHwnd := 0
global TranslatorVisible := false
global OverlayZMode := "normal"
global KeepActivePinned := false

; While this translator is foreground, temporarily remove TOPMOST only from
; Roblox windows physically underneath the separate "Roblox Game Status" panel.
; This lets the selector's unchanged normal-band Z-order logic keep the panel
; above its Roblox client without fighting the translator's own TOPMOST overlay.
; Each original TOPMOST state is recorded and restored when translator focus ends.
global TranslatorDemotedRobloxTopmostByHwnd := Map()

global TranslateRevision := 0
global TranslationReady := false
global TranslationInProgress := false

; Active HTTP request state. Translation runs asynchronously so the
; editor remains responsive while the server is preparing a response.
global ActiveTranslationRequest := 0
global ActiveTranslationRevision := 0
global ActiveTranslationSource := ""
global ActiveTranslationSourceLang := ""
global ActiveTranslationTarget := ""
global LastInputChangeTick := 0

; Fallback language detection request. The translation request remains the
; primary result; this second request is used only when its response omits
; the detected source-language metadata.
global ActiveDetectionRequest := 0
global ActiveDetectionRevision := 0
global ActiveDetectionSource := ""
global ActiveDetectionTarget := ""

; When Enter is pressed before translation finishes.
global PendingChatPaste := false
global PendingChatRevision := 0
global PendingChatAutoSend := false
global ChatPasteInProgress := false

global LastTranslatedSource := ""
global LastTranslatedSourceLang := ""
global LastTranslatedTarget := ""

global OverlayOffsetX := 12
global OverlayOffsetY := 0
global HasSavedPosition := false

; Client dimensions, excluding the outer window frame.
global WindowWidth := 344
global WindowHeight := 350

global InitialSourceIndex := 1
global InitialTargetIndex := 1
global InitialFontIndex := 4

global ExpectedX := -100000
global ExpectedY := -100000

global LastTargetX := -100000
global LastTargetY := -100000
global LastTargetW := -1
global LastTargetH := -1

global LastRobloxSearchTick := 0

; HTTP request throttling / 429 cooldown.
global NextRequestAllowedTick := 0
global RateLimitUntilTick := 0

; Triple-click selection tracking.
global EditLastClickTick := 0
global EditLastClickHwnd := 0
global EditLastClickX := 0
global EditLastClickY := 0
global EditClickCount := 0
global EditWheelRemainder := 0

; Active mode and idle title-bar opacity are set in USER-EDITABLE SETTINGS above.
; After IdleModeDelaySeconds, hide the main window and show a separate
; borderless dark title strip containing ONLY the application name. Hovering
; the name strip restores the full window; clicks outside it reach the app behind it.
global TranslatorFaded := false
global TranslatorMinimized := false
; Prevent activation/focus messages raised by Hide/Show itself from undoing
; an idle transition while Windows is processing the same UI operation.
global IdleTransitionInProgress := false
global IdleTransitionStartedTick := 0
global LastTranslatorActivityTick := 0
global LastIdleMouseX := -999999
global LastIdleMouseY := -999999
; Manual double-click idle can be used even while Pin is enabled. Keep the
; cursor from instantly waking the strip when it is already underneath it.
global IdleStripWakeArmed := false
global LastManualIdleToggleTick := 0
; Prevent duplicate scheduling while the physical double-click is still completing.
global ManualDoubleClickPending := false
; Reliable manual idle-toggle detection is based on two completed mouse-up events,
; rather than WM_LBUTTONDBLCLK, which may not be delivered consistently by every control.
global IdleToggleLastClickTick := 0
global IdleToggleLastClickRoot := 0
global IdleToggleLastClickX := -999999
global IdleToggleLastClickY := -999999
; Physical mouse-up hook replaces child-window WM_LBUTTONUP tracking.
; It observes the actual screen click sequence once, independent of which
; AHK Static/Edit child HWND receives a mouse message.
global IdleToggleMouseHookHandle := 0
global IdleToggleMouseHookCallback := 0

; A slash press in Roblox opens its chat and wakes the translator without
; taking focus. A second slash within this window moves keyboard focus to SourceEdit.
global SlashWorkflowArmed := false
global SlashWorkflowTargetHwnd := 0
global SlashWorkflowTick := 0
global SlashWorkflowWindowMs := 8000

; Height of the custom dark title band, measured in client coordinates.
global CustomTitleBarHeight := 36
; In idle mode, show only the application name in a compact strip.
; The underlying GUI/window dimensions are not changed.
global IdleCompactClientWidth := 136 ; just enough width for "Quick Translator"
global IdleTitleStripHeight := 36 ; same height as the normal custom title bar

global DarkBrush := 0
global TitleBarBrush := 0

; Expand the bottom status area into multiple lines when a message is long.
; The outer window stays the same size; editor space is adjusted to make room.
global StatusDisplayHeight := 20 ; one compact line by default
global StatusDisplayWidth := 52
global LastRenderedStatusText := ""

; Saved native frame/DWM states toggled only while the idle title strip is shown.
global IdleResizeFrameRemoved := false
global IdleDwmNcRenderingDisabled := false


CleanupUnusedAdditionalProfiles(settingsDirectory) {
    if (!DirExist(settingsDirectory))
        return

    activeTokens := Map()
    DetectHiddenWindows(true)
    try {
        for hwnd in WinGetList("ahk_class AutoHotkeyGUI") {
            try {
                title := Trim(WinGetTitle("ahk_id " . hwnd))
            } catch {
                continue
            }

            ; Both the main GUI and its companion idle strip include the same
            ; instance token in their titles, so either one protects that profile.
            if (RegExMatch(title, "i)^Quick Translator \[([^\]]+)\](?: idle)?$", &match)) {
                token := match[1]
                if (token != "main" && token != "")
                    activeTokens[token] := true
            }
        }
    } finally {
        DetectHiddenWindows(false)
    }

    ; Additional profiles use Quick_Translator_RobloxOnly_<instance>.ini.
    ; Do not touch the main profile or any profile owned by a live window.
    Loop Files, settingsDirectory . "\Quick_Translator_RobloxOnly_*.ini", "F" {
        if (!RegExMatch(A_LoopFileName, "^Quick_Translator_RobloxOnly_(.+)\.ini$", &match))
            continue

        token := match[1]
        if (!activeTokens.Has(token)) {
            try FileDelete(A_LoopFileFullPath)
        }
    }
}


CloseStaleQuickTranslatorInstances() {
    global ScriptPID

    DetectHiddenWindows(true)
    try {
        staleWindows := []
        for hwnd in WinGetList("ahk_class AutoHotkeyGUI") {
            try {
                if (WinGetPID("ahk_id " . hwnd) = ScriptPID)
                    continue
                staleTitle := Trim(WinGetTitle("ahk_id " . hwnd))
                if (staleTitle = "Quick Translator"
                    || staleTitle = "Quick Translator [main]")
                    staleWindows.Push(hwnd)
            }
        }

        ; Ask old versions to exit through their normal GUI close handler.
        for hwnd in staleWindows {
            try PostMessage(0x0010, 0, 0, , "ahk_id " . hwnd) ; WM_CLOSE
        }

        ; Give the previous script instances a short opportunity to save settings
        ; and destroy their matching idle-strip windows before this GUI is shown.
        if (staleWindows.Length) {
            Loop 8 {
                pending := false
                for hwnd in staleWindows {
                    if (DllCall("user32\IsWindow", "Ptr", hwnd, "Int")) {
                        pending := true
                        try PostMessage(0x0010, 0, 0, , "ahk_id " . hwnd)
                    }
                }
                if (!pending)
                    break
                Sleep(50)
            }
        }
    } finally {
        DetectHiddenWindows(false)
    }
}

; ============================================================
; GUI CREATION
; ============================================================

MainGui.BackColor := "202124"
MainGui.SetFont("s10 cF2F2F2", "Segoe UI")

; This dark client-area strip replaces the native Windows caption.
; Because it is a real control, its background stays dark while translucent.
TitleBar := MainGui.AddText(
    "x0 y0 w490 h36 Background202124",
    ""
)

TitleText := MainGui.AddText(
    "x12 y8 w125 h22 Background202124 cF2F2F2",
    "Quick Translator"
)

; Source language selector.
SourceDrop := MainGui.AddDropDownList(
    "x12 y42 w285 r14 AltSubmit Choose1",
    SourceLanguages
)
SourceDrop.Visible := false ; hidden value model; its white native arrow is never shown
SourceSelectorFace := MainGui.AddText(
    "x12 y42 w285 h28 Left 0x200 Background262626 cF2F2F2 +Border",
    "Auto detect"
)
SourceSelectorFace.OnEvent("Click", IgnoreSelectorFaceClick)

; Font-size selector.
FontLabel := MainGui.AddText(
    "x310 y47 w36 h20",
    "Font"
)

FontDrop := MainGui.AddDropDownList(
    "x350 y42 w110 r9 AltSubmit Choose4",
    FontSizes
)
FontDrop.Visible := false ; hidden value model; use the custom dark selector face
FontSelectorFace := MainGui.AddText(
    "x350 y42 w110 h28 Left 0x200 Background262626 cF2F2F2 +Border",
    "12"
)
FontSelectorFace.OnEvent("Click", IgnoreSelectorFaceClick)

; Source editor. Multi-line wrapping is enabled; scrollbar is hidden.
SourceEdit := MainGui.AddEdit(
    "x12 y80 w466 h130 Multi -VScroll"
)
SourceEdit.OnEvent("Change", InputChanged)

; Target selector between the input and result areas.
LanguageLabel := MainGui.AddText(
    "x12 y232 w72 h28 0x200",
    "Target"
)

TargetDrop := MainGui.AddDropDownList(
    "x90 y232 w368 r13 AltSubmit Choose1",
    TargetLanguages
)
TargetDrop.Visible := false ; hidden value model; arrowless face shown instead
TargetSelectorFace := MainGui.AddText(
    "x90 y232 w186 h28 Left 0x200 Background262626 cF2F2F2 +Border",
    "English"
)
TargetSelectorFace.OnEvent("Click", IgnoreSelectorFaceClick)

; Quick clear button beside the target-language selector. It shares the
; existing ClearText action so both source and translated text are cleared.
SourceEmojiButton := MainGui.AddText(
    "x282 y232 w36 h30 Center 0x200 Background303030 cF2F2F2 +Border",
    "😝"
)
SourceEmojiButton.SetFont("s12 cF2F2F2", "Segoe UI Emoji")
SourceEmojiButton.OnEvent("Click", OpenSourceEmojiPicker)

TargetClearButton := MainGui.AddText(
    "x324 y232 w100 h30 Center 0x200 Background303030 cF2F2F2 +Border",
    "Clear"
)
TargetClearButton.OnEvent("Click", ClearText)

; Translation result editor with automatic line wrapping; scrollbar is hidden.
ResultEdit := MainGui.AddEdit(
    "x12 y270 w466 h130 ReadOnly Multi -VScroll"
)

; Dark clickable text controls, replacing standard white buttons.
MainGui.SetFont("s9 cF2F2F2", "Segoe UI")

OCRButton := MainGui.AddText(
    "x145 y8 w60 h28 Center 0x200 Background303030 cF2F2F2 +Border",
    "OCR"
)
OCRButton.OnEvent("Click", SendOCRHotkey)

PasteInputButton := MainGui.AddText(
    "x213 y8 w122 h28 Center 0x200 Background303030 cF2F2F2 +Border",
    "Paste to Input"
)
PasteInputButton.OnEvent("Click", PasteClipboardToInput)

AlwaysOnTopButton := MainGui.AddText(
    "x414 y5 w30 h26 Center 0x200 Background303030 cF2F2F2 +Border",
    "📍"
)
AlwaysOnTopButton.SetFont("s10 cF2F2F2", "Segoe UI Emoji")
AlwaysOnTopButton.OnEvent("Click", ToggleKeepActivePinned)

MinimizeButton := MainGui.AddText(
    "x450 y5 w30 h26 Center 0x200 Background303030 cF2F2F2 +Border",
    "—"
)
MinimizeButton.OnEvent("Click", MinimizeTranslatorWindow)

; Separate compact idle strip. It deliberately contains only the title/name;
; the normal Pin and Minimize buttons are not shown while idle.
IdleStripGui := Gui("-Caption +ToolWindow", "Quick Translator [" . TranslatorInstanceId . "] idle")
IdleStripGui.BackColor := "202124"
IdleStripGui.SetFont("s10 cF2F2F2", "Segoe UI")
IdleStripTitleBar := IdleStripGui.AddText(
    "x0 y0 w136 h36 Background202124", ""
)
IdleStripTitleText := IdleStripGui.AddText(
    "x12 y8 w112 h22 Background202124 cF2F2F2", "Quick Translator"
)
IdleStripTitleText.SetFont("s10 cF2F2F2", "Segoe UI")
; Wake is hover-only via TranslatorIdleFadeMonitor. Do not bind Click here:
; the mouse-up from the double-click that enters idle can be delivered to this new strip,
; which would immediately restore the window and look like a flash.
IdleStripGui.Show("Hide w" . IdleCompactClientWidth . " h" . IdleTitleStripHeight)
; The mini strip is custom-drawn and borderless; disable DWM non-client
; rendering on it to avoid a native shadow/outline around the idle strip.
try {
    idleNcPolicy := 1 ; DWMNCRP_DISABLED
    DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", IdleStripGui.Hwnd,
        "UInt", 2, "Int*", idleNcPolicy, "UInt", 4, "Int")
}

CopyButton := MainGui.AddText(
    "x12 y534 w120 h30 Center 0x200 Background303030 cF2F2F2 +Border",
    "Paste to Chat"
)
CopyButton.OnEvent("Click", PasteChatButtonClick)

ChatEmojiButton := MainGui.AddText(
    "x140 y534 w34 h30 Center 0x200 Background303030 cF2F2F2 +Border",
    "💛"
)
ChatEmojiButton.SetFont("s12 cF2F2F2", "Segoe UI Emoji")
ChatEmojiButton.OnEvent("Click", OpenRobloxChatEmojiPicker)

ClearButton := MainGui.AddText(
    "x180 y534 w80 h30 Center 0x200 Background303030 cF2F2F2 +Border",
    "Clear"
)
ClearButton.OnEvent("Click", ClearTextAndRobloxChat)

; Each + starts a new independent translator immediately to the right.
; Each - exits only the instance whose button was clicked.
AddTranslatorButton := MainGui.AddText(
    "x248 y534 w32 h30 Center 0x200 Background303030 cF2F2F2 +Border",
    "+"
)
AddTranslatorButton.SetFont("s14 cF2F2F2", "Segoe UI")
AddTranslatorButton.OnEvent("Click", CreateAdditionalTranslator)

RemoveTranslatorButton := MainGui.AddText(
    "x284 y534 w32 h30 Center 0x200 Background303030 cF2F2F2 +Border",
    "−"
)
RemoveTranslatorButton.SetFont("s14 cF2F2F2", "Segoe UI")
RemoveTranslatorButton.OnEvent("Click", RemoveCurrentTranslator)

; Read-only multiline edit: status text stays selectable/copyable but visually blends into the GUI.
; No border/client-edge or contrasting field background; long messages grow its layout area.
StatusText := MainGui.AddEdit(
    "x12 y572 w466 h20 ReadOnly Multi -VScroll -Border -E0x200 cB6B6B6",
    "Ready"
)
StatusText.SetFont("s9 cB6B6B6", "Segoe UI")

; Native ComboBox arrow controls are hidden value models. The visible
; arrowless text faces open dark popup lists instead.

; ============================================================
; LOAD SETTINGS
; ============================================================

LoadSavedSettings()

; A newly created child has a unique, empty INI. Seed it with the launching
; window's current size and language selections, without overwriting a profile
; if this instance ID is later relaunched with an existing INI.
if (TranslatorInstanceId != "main" && !FileExist(SettingsPath)) {
    if (StartupWidthArg >= 344 && StartupWidthArg <= 3000)
        WindowWidth := StartupWidthArg
    if (StartupHeightArg >= 350 && StartupHeightArg <= 2000)
        WindowHeight := StartupHeightArg
    if (StartupSourceIndexArg >= 1 && StartupSourceIndexArg <= SourceLanguages.Length)
        InitialSourceIndex := StartupSourceIndexArg
    if (StartupTargetIndexArg >= 1 && StartupTargetIndexArg <= TargetLanguages.Length)
        InitialTargetIndex := StartupTargetIndexArg
    if (StartupFontIndexArg >= 1 && StartupFontIndexArg <= FontSizes.Length)
        InitialFontIndex := StartupFontIndexArg
}

if (InitialSourceIndex < 1
    || InitialSourceIndex > SourceLanguages.Length)
    InitialSourceIndex := 1

if (InitialTargetIndex < 1
    || InitialTargetIndex > TargetLanguages.Length)
    InitialTargetIndex := 1

if (InitialFontIndex < 1
    || InitialFontIndex > FontSizes.Length)
    InitialFontIndex := 4

SourceDrop.Value := InitialSourceIndex
TargetDrop.Value := InitialTargetIndex
FontDrop.Value := InitialFontIndex
SourceSelectorFace.Text := SourceLanguages[InitialSourceIndex]
TargetSelectorFace.Text := TargetLanguages[InitialTargetIndex]
FontSelectorFace.Text := FontSizes[InitialFontIndex]

ApplySelectedFont()


; ============================================================
; DARK CONTROLS AND GUI EVENTS
; ============================================================

DarkBrush := DllCall(
    "gdi32\CreateSolidBrush",
    "UInt", 0x00262626,
    "Ptr"
)

; COLORREF for the custom title-bar background #202124.
TitleBarBrush := DllCall(
    "gdi32\CreateSolidBrush",
    "UInt", 0x00242120,
    "Ptr"
)

OnMessage(0x0133, ControlColor)          ; WM_CTLCOLOREDIT
OnMessage(0x0134, ControlColor)          ; WM_CTLCOLORLISTBOX
OnMessage(0x0138, ControlColor)          ; WM_CTLCOLORSTATIC
OnMessage(0x0202, HandleEditMouseUp)     ; WM_LBUTTONUP
OnMessage(0x020A, HandleEditMouseWheel)  ; WM_MOUSEWHEEL

; Track interaction with this GUI and its child controls. The handlers do
; not consume the original messages, so normal control behavior is retained.
; WM_MOUSEMOVE is sampled by TranslatorIdleFadeMonitor using screen coordinates.
OnMessage(0x0201, MarkTranslatorActivity) ; WM_LBUTTONDOWN
OnMessage(0x0204, MarkTranslatorActivity) ; WM_RBUTTONDOWN
OnMessage(0x0207, MarkTranslatorActivity) ; WM_MBUTTONDOWN
; Manual idle toggle is detected from completed WM_LBUTTONUP click pairs below.
OnMessage(0x00A0, MarkTranslatorActivity) ; WM_NCMOUSEMOVE
OnMessage(0x00A1, MarkTranslatorActivity) ; WM_NCLBUTTONDOWN
OnMessage(0x0100, MarkTranslatorActivity) ; WM_KEYDOWN
OnMessage(0x0102, MarkTranslatorActivity) ; WM_CHAR
OnMessage(0x0104, MarkTranslatorActivity) ; WM_SYSKEYDOWN
OnMessage(0x0006, MarkTranslatorActivity) ; WM_ACTIVATE
OnMessage(0x0007, MarkTranslatorActivity) ; WM_SETFOCUS

MainGui.OnEvent("Size", GuiSize)
MainGui.OnEvent("Close", (*) => ExitApp())

OnExit(ShutdownScript)
InstallIdleToggleMouseHook()

; Create the GUI hidden with the saved client dimensions.
; Do not restore dimensions from WinGetPos outer dimensions.
MainGui.Show(
    "Hide w" . WindowWidth . " h" . WindowHeight
)

LayoutControls(WindowWidth, WindowHeight)

ApplyWindowsDarkMode()
ApplyDarkControlThemes()
UpdateArrowlessSelectors()
SaveSettings()

InitializeRobloxTarget()

LastTranslatorActivityTick := A_TickCount
SetTimer(TrackRobloxUnderMouse, 100)
SetTimer(TranslatorIdleFadeMonitor, 50)
SetTimer(StatusLayoutMonitor, 150)
SetTimer(StatusLayoutMonitor, -1)


; Convert user-facing opacity percent (0-100) to WinSetTransparent's 0-255 value.
SetWindowOpacityPercent(hwnd, percent) {
    if (!hwnd)
        return
    safePercent := Max(0, Min(100, percent))
    alpha := Round(255 * safePercent / 100)
    WinSetTransparent(alpha, "ahk_id " . hwnd)
}

SetTranslatorOpacityPercent(percent) {
    global MainGui
    SetWindowOpacityPercent(MainGui.Hwnd, percent)
}


; ============================================================
; ADD / REMOVE TRANSLATOR WINDOW
; ============================================================

CreateAdditionalTranslator(*) {
    global MainGui, StatusText, TargetRobloxHwnd
    global SourceDrop, TargetDrop, FontDrop
    global WindowWidth, WindowHeight, ScriptPID, TranslatorFaded

    if (TranslatorFaded)
        RestoreTranslatorFromIdleFade()

    if (!GetWindowPos(MainGui.Hwnd, &winX, &winY, &winW, &winH)) {
        StatusText.Value := "Cannot determine current translator position"
        return
    }

    ; Open the new window immediately to the right of this one.
    startX := winX + winW + 8
    startY := winY
    instanceToken := "i" . Format("{:X}", A_TickCount) . "_" . ScriptPID

    argText := "--instance=" . instanceToken
        . " --startx=" . startX
        . " --starty=" . startY
        . " --targethwnd=" . TargetRobloxHwnd
        . " --width=" . WindowWidth
        . " --height=" . WindowHeight
        . " --source=" . SourceDrop.Value
        . " --target=" . TargetDrop.Value
        . " --font=" . FontDrop.Value

    if (A_IsCompiled) {
        command := Chr(34) . A_ScriptFullPath . Chr(34) . " " . argText
    } else {
        command := Chr(34) . A_AhkPath . Chr(34) . " "
            . Chr(34) . A_ScriptFullPath . Chr(34) . " " . argText
    }

    try {
        Run(command)
        StatusText.Value := "Additional translator window launching..."
    } catch as err {
        StatusText.Value := "Could not create translator window: " . err.Message
    }
}

RemoveCurrentTranslator(*) {
    ; ExitApp runs ShutdownScript for this process only. Other translator
    ; instances remain open and keep their own settings and translation state.
    ExitApp()
}

GetLaunchArgument(name, defaultValue := "") {
    prefix := "--" . name . "="
    for arg in A_Args {
        if (SubStr(arg, 1, StrLen(prefix)) = prefix)
            return SubStr(arg, StrLen(prefix) + 1)
    }
    return defaultValue
}

IsQuickTranslatorWindow(hwnd) {
    if (!hwnd)
        return false
    try {
        title := WinGetTitle("ahk_id " . hwnd)
        lowerTitle := StrLower(title)
        return InStr(lowerTitle, "quick translator [") = 1
            || InStr(lowerTitle, "quick_translator_robloxonly") = 1
    } catch {
        return false
    }
}

CanHandleGlobalSlashHotkey() {
    global ScriptPID

    lowestPid := ScriptPID
    DetectHiddenWindows(true)
    try {
        for hwnd in WinGetList("ahk_class AutoHotkeyGUI") {
            if (!IsQuickTranslatorWindow(hwnd))
                continue
            try {
                pid := WinGetPID("ahk_id " . hwnd)
            } catch {
                continue
            }
            if (pid < lowestPid)
                lowestPid := pid
        }
    } finally {
        DetectHiddenWindows(false)
    }
    return ScriptPID = lowestPid
}

; ============================================================
; MINIMIZE BUTTON
; ============================================================

MinimizeTranslatorWindow(*) {
    global MainGui, TranslatorMinimized, TranslatorFaded

    if (TranslatorFaded)
        RestoreTranslatorFromIdleFade()
    TranslatorMinimized := true
    try WinMinimize("ahk_id " . MainGui.Hwnd)
}

ToggleKeepActivePinned(*) {
    global MainGui, AlwaysOnTopButton, KeepActivePinned, StatusText
    global TranslatorFaded, LastTranslatorActivityTick

    KeepActivePinned := !KeepActivePinned
    LastTranslatorActivityTick := A_TickCount

    if (KeepActivePinned) {
        ; Pin means keep the full translator interactive. It does NOT mean
        ; always-on-top: normal foreground-based z-order rules remain in force.
        if (TranslatorFaded)
            RestoreTranslatorFromIdleFade()
        AlwaysOnTopButton.Text := "📌"
        StatusText.Value := "Pinned active: automatic idle mode disabled"
    } else {
        AlwaysOnTopButton.Text := "📍"
        StatusText.Value := "Pin released: automatic idle mode resumed"
    }
}

; ============================================================
; IDLE STATE RECONCILIATION
; ============================================================

RepairIdleLifecycleState(force := false) {
    global MainGui, IdleStripGui, TranslatorMinimized, TranslatorVisible
    global TranslatorFaded, IdleTransitionInProgress, IdleTransitionStartedTick
    global ActiveWindowOpacityPercent, LastTranslatorActivityTick, IdleStripWakeArmed

    try {
        mainExists := DllCall("user32\IsWindow", "Ptr", MainGui.Hwnd, "Int")
        mainVisible := mainExists && DllCall("user32\IsWindowVisible", "Ptr", MainGui.Hwnd, "Int")
        mainIconic := mainExists && DllCall("user32\IsIconic", "Ptr", MainGui.Hwnd, "Int")
        stripExists := DllCall("user32\IsWindow", "Ptr", IdleStripGui.Hwnd, "Int")
        stripVisible := stripExists && DllCall("user32\IsWindowVisible", "Ptr", IdleStripGui.Hwnd, "Int")
    } catch {
        return
    }

    ; AHK Size events can leave a cached minimized flag stale after the main
    ; HWND was hidden/restored programmatically. Use IsIconic as the authority.
    TranslatorMinimized := !!mainIconic

    if (mainVisible || stripVisible)
        TranslatorVisible := true

    if (!IdleTransitionInProgress) {
        ; Also recover a stale Faded flag after a completed transition. The state
        ; machine must match what Windows is actually displaying, not only its
        ; cached AHK booleans.
        if (mainVisible) {
            wasFaded := TranslatorFaded
            TranslatorFaded := false
            IdleStripWakeArmed := false
            if (stripVisible) {
                try WinHide("ahk_id " . IdleStripGui.Hwnd)
            }
            if (wasFaded) {
                try WinSetExStyle("-0x20", "ahk_id " . MainGui.Hwnd)
                try SetTranslatorOpacityPercent(ActiveWindowOpacityPercent)
                LastTranslatorActivityTick := A_TickCount
            }
        } else if (stripVisible && !mainIconic) {
            TranslatorFaded := true
        } else if (!mainVisible && !stripVisible && !mainIconic && TranslatorVisible) {
            ; Both surfaces vanished outside a transition: recover the full GUI
            ; rather than leaving the inactivity and double-click handlers stuck.
            TranslatorFaded := false
            try MainGui.Show("NA")
            try WinSetExStyle("-0x20", "ahk_id " . MainGui.Hwnd)
            try SetTranslatorOpacityPercent(ActiveWindowOpacityPercent)
            LastTranslatorActivityTick := A_TickCount
            IdleStripWakeArmed := false
        }
        return
    }

    elapsed := IdleTransitionStartedTick ? A_TickCount - IdleTransitionStartedTick : 999999
    if (!force && elapsed < 1500)
        return

    ; Clear a transition lock only after reconciling which window is actually
    ; on screen. This prevents one interrupted transition from disabling every
    ; later idle/wake/double-click operation.
    if (stripVisible && !mainVisible) {
        TranslatorFaded := true
    } else if (mainVisible) {
        TranslatorFaded := false
        if (stripVisible) {
            try WinHide("ahk_id " . IdleStripGui.Hwnd)
        }
    } else if (!stripVisible && !mainVisible && !mainIconic) {
        TranslatorFaded := false
        try MainGui.Show("NA")
        try WinSetExStyle("-0x20", "ahk_id " . MainGui.Hwnd)
        try SetTranslatorOpacityPercent(ActiveWindowOpacityPercent)
        LastTranslatorActivityTick := A_TickCount
        IdleStripWakeArmed := false
    }

    IdleTransitionInProgress := false
    IdleTransitionStartedTick := 0
}

SelectorPopupIsLive() {
    global SelectorPopupGui, SelectorPopupOpenedTick

    if (!SelectorPopupGui)
        return false

    try {
        hwnd := SelectorPopupGui.Hwnd
        if (hwnd && DllCall("user32\IsWindow", "Ptr", hwnd, "Int")
            && DllCall("user32\IsWindowVisible", "Ptr", hwnd, "Int"))
            return true

        ; Allow a short construction/Show interval; if the popup stays hidden
        ; longer than that, release the stale reference and its timer.
        if (A_TickCount - SelectorPopupOpenedTick < 500)
            return true
    }

    try CloseSelectorPopup()
    return false
}

; ============================================================
; IDLE FADE / CLICK-THROUGH
; ============================================================

MarkTranslatorActivity(wParam, lParam, msg, hwnd) {
    global MainGui, TitleBar, TitleText, CustomTitleBarHeight
    global SourceDrop, TargetDrop, FontDrop
    global LastTranslatorActivityTick, TranslatorFaded, SelectorPopupList, SelectorPopupGui, SelectorPopupFace
    global IdleTransitionInProgress

    ; Hide/show operations can generate WM_ACTIVATE, WM_SETFOCUS, and related
    ; messages. They are not user activity and must not immediately wake the
    ; mini title strip or reverse a double-click transition.
    if (IdleTransitionInProgress)
        return
    if (msg = 0x0006 && (wParam & 0xFFFF) = 0) ; WM_ACTIVATE / WA_INACTIVE
        return

    if (SelectorPopupGui && msg = 0x0201) {
        ; Keep the current popup alive for clicks on its own list, and let a
        ; click on the same selector face toggle it closed in OpenSelectorPopup.
        ; Other clicks inside this translator dismiss the popup before normal
        ; control processing continues.
        clickedRoot := GetRootWindow(hwnd)
        clickedActiveFace := (SelectorPopupFace && hwnd = SelectorPopupFace.Hwnd)
        if (clickedRoot != SelectorPopupGui.Hwnd && !clickedActiveFace)
            CloseSelectorPopup()
    }

    if (SelectorPopupList && hwnd = SelectorPopupList.Hwnd && msg = 0x0100) {
        if (wParam = 0x0D) { ; VK_RETURN
            SetTimer(CommitSelectorPopupSelection, -20)
            return 0
        }
        if (wParam = 0x1B) { ; VK_ESCAPE
            SetTimer(CloseSelectorPopup, -10)
            return 0
        }
    }

    if (!IsTranslatorOwnedWindow(hwnd))
        return

    ; Ignore late messages delivered to the now-hidden main window after idle
    ; mode has started. The separate idle strip is the only surface allowed to
    ; wake the translator while faded.
    if (TranslatorFaded
        && !DllCall("user32\IsWindowVisible", "Ptr", MainGui.Hwnd, "Int"))
        return

    LastTranslatorActivityTick := A_TickCount

    ; If genuine user input reaches a visible editor while dimmed, restore it.
    if (TranslatorFaded)
        RestoreTranslatorFromIdleFade()

    ; The visible selector faces launch separate dark list popups. The native
    ; DropDownList controls are hidden value holders only, so they do not handle
    ; pointer messages or display their native white arrow buttons.

    ; Drag the window when the user presses the custom title strip or its text.
    ; Utility buttons are separate controls and therefore never start a drag.
    if (msg = 0x0201) { ; WM_LBUTTONDOWN
        onCustomTitle := (hwnd = TitleBar.Hwnd || hwnd = TitleText.Hwnd)

        ; Empty portions of the client window in the title strip are routed
        ; to the top-level GUI rather than to the static title-strip control.
        if (hwnd = MainGui.Hwnd) {
            clickY := (lParam >> 16) & 0xFFFF
            if (clickY < CustomTitleBarHeight)
                onCustomTitle := true
        }

        if (onCustomTitle) {
            DllCall("user32\ReleaseCapture")
            PostMessage(0x00A1, 2, 0, , "ahk_id " . MainGui.Hwnd) ; WM_NCLBUTTONDOWN / HTCAPTION
            return 0
        }
    }

    ; No return value otherwise: preserve normal control behavior.
}

IsTranslatorOwnedWindow(hwnd) {
    global MainGui

    if (!hwnd)
        return false

    if (hwnd = MainGui.Hwnd)
        return true

    try {
        root := DllCall(
            "user32\GetAncestor",
            "Ptr", hwnd,
            "UInt", 2, ; GA_ROOT
            "Ptr"
        )
        if (root = MainGui.Hwnd)
            return true

        ; Dropdown popup lists can be separate top-level owned windows.
        ; GA_ROOTOWNER keeps their user interaction counted as GUI activity.
        rootOwner := DllCall(
            "user32\GetAncestor",
            "Ptr", hwnd,
            "UInt", 3, ; GA_ROOTOWNER
            "Ptr"
        )
        return rootOwner = MainGui.Hwnd
    } catch {
        return false
    }
}

TranslatorIdleFadeMonitor() {
    global MainGui, IdleStripGui, TranslatorVisible, TranslatorFaded, TranslatorMinimized
    global CustomTitleBarHeight, IdleTitleStripHeight, IdleModeDelaySeconds, IdleCompactClientWidth
    global LastTranslatorActivityTick, LastIdleMouseX, LastIdleMouseY, KeepActivePinned
    global IdleStripWakeArmed, OCRCaptureActive
    global SourceSelectorFace, TargetSelectorFace, FontSelectorFace, SelectorPopupGui
    global TargetRobloxHwnd
    global SlashWorkflowArmed, SlashWorkflowTick, SlashWorkflowWindowMs, SlashWorkflowTargetHwnd

    ; Reconcile cached flags with actual HWND state on every monitor pass.
    ; Stale minimized/transition/popup flags used to permanently disable both
    ; auto-idle and the manual double-click toggle after the first hide/show.
    RepairIdleLifecycleState()
    if (TranslatorMinimized)
        return

    ; Keep the translator fully available while OCR selection/recognition is in
    ; progress. PowerToys/Windows OCR temporarily owns the screen and may take
    ; longer than the normal idle timeout; without this guard the translator
    ; can collapse before the recognized text is copied into SourceEdit.
    if (OCRCaptureActive) {
        LastTranslatorActivityTick := A_TickCount
        try {
            CoordMode("Mouse", "Screen")
            MouseGetPos(&ocrMouseX, &ocrMouseY)
            LastIdleMouseX := ocrMouseX
            LastIdleMouseY := ocrMouseY
        } catch {
            ; OCR is still active even if a cursor sample briefly fails.
        }
        return
    }

    if (SelectorPopupIsLive()) {
        LastTranslatorActivityTick := A_TickCount
        return
    }

    ; Pin blocks inactivity-triggered fading while the full translator is shown.
    ; If the user manually entered idle by double-click, still monitor the strip
    ; so hovering can restore the GUI even when Pin remains enabled.
    if (KeepActivePinned && !TranslatorFaded) {
        LastTranslatorActivityTick := A_TickCount
        return
    }

    if (!TranslatorVisible)
        return

    try {
        CoordMode("Mouse", "Screen")
        MouseGetPos(&mouseX, &mouseY)
        now := A_TickCount
    } catch {
        return
    }

    ; Keep the translator in its ready state during the slash-to-focus sequence.
    ; Once the second press window expires, normal idle timing resumes.
    if (SlashWorkflowArmed) {
        if (now - SlashWorkflowTick <= SlashWorkflowWindowMs)
            return
        SlashWorkflowArmed := false
        SlashWorkflowTargetHwnd := 0
    }

    ; Idle mode is a separate tiny GUI, not a clipped parent. It keeps only
    ; the application name visible at the normal 36px title-bar height.
    if (TranslatorFaded) {
        ; Use the raw Win32 rectangle here because MouseGetPos is in screen
        ; coordinates. Do not compare logical GUI dimensions to physical pixels.
        if (!GetWindowPos(IdleStripGui.Hwnd, &stripX, &stripY, &stripW, &stripH))
            return

        onStrip := mouseX >= stripX && mouseX < stripX + stripW
            && mouseY >= stripY && mouseY < stripY + stripH
        if (onStrip) {
            ; If the same double-click that entered idle happened over the
            ; title strip, do not immediately restore and cause a blink. Wake
            ; becomes armed only after the mouse leaves the strip once.
            if (IdleStripWakeArmed) {
                underlyingRoblox := FindRobloxWindowUnderMouse(mouseX, mouseY)
                targetChanged := false
                if (underlyingRoblox && IsRobloxWindow(underlyingRoblox)
                    && underlyingRoblox != TargetRobloxHwnd) {
                    TargetRobloxHwnd := underlyingRoblox
                    targetChanged := true
                }

                RestoreTranslatorFromIdleFade()
                if (targetChanged)
                    ShowOnTargetRoblox()
                LastTranslatorActivityTick := now
            }
        } else {
            ; A later hover over the strip may now wake the translator.
            IdleStripWakeArmed := true
        }
        LastIdleMouseX := mouseX
        LastIdleMouseY := mouseY
        return
    }

    if (!DllCall("user32\IsWindowVisible", "Ptr", MainGui.Hwnd, "Int"))
        return

    try {
        WinGetPos(&winX, &winY, &winW, &winH, "ahk_id " . MainGui.Hwnd)
        WinGetClientPos(&clientX, &clientY, &clientW, &clientH, "ahk_id " . MainGui.Hwnd)
    } catch {
        return
    }

    if (winW <= 0 || winH <= 0)
        return

    insideWindow := mouseX >= winX && mouseX < winX + winW
        && mouseY >= winY && mouseY < winY + winH

    mouseMoved := mouseX != LastIdleMouseX || mouseY != LastIdleMouseY
    if (insideWindow && mouseMoved)
        LastTranslatorActivityTick := now

    ; Actual WM_MOUSEMOVE and input messages update the activity timestamp.
    ; Merely leaving the pointer parked over the titlebar is not ongoing activity;
    ; otherwise automatic idle can never occur after waking the strip by hover.
    if (now - LastTranslatorActivityTick >= Max(0, IdleModeDelaySeconds) * 1000)
        FadeTranslatorForIdle()

    LastIdleMouseX := mouseX
    LastIdleMouseY := mouseY
}

IsRobloxOrTranslatorUnderMouse(mouseX, mouseY) {
    global MainGui

    try {
        point := Buffer(8, 0)
        NumPut("Int", mouseX, point, 0)
        NumPut("Int", mouseY, point, 4)
        pointValue := NumGet(point, 0, "Int64")
        underHwnd := DllCall("user32\WindowFromPoint", "Int64", pointValue, "Ptr")
        if (!underHwnd)
            return false

        root := DllCall("user32\GetAncestor", "Ptr", underHwnd, "UInt", 2, "Ptr") ; GA_ROOT
        if (!root)
            root := underHwnd

        if (root = MainGui.Hwnd)
            return true

        processName := StrLower(WinGetProcessName("ahk_id " . root))
        return processName = "robloxplayerbeta.exe"
    } catch {
        return false
    }
}

FadeTranslatorForIdle(manual := false) {
    global MainGui, TitleText, IdleStripGui, IdleStripTitleText
    global TranslatorFaded, KeepActivePinned, OverlayZMode, IdleStripWakeArmed
    global IdleCompactClientWidth, IdleTitleStripHeight, IdleTitleBarOpacityPercent, ActiveWindowOpacityPercent
    global IdleTransitionInProgress, IdleTransitionStartedTick
    global TranslatorVisible, TranslatorMinimized

    RepairIdleLifecycleState()
    ; Pin suppresses only automatic idle caused by inactivity. A double-click
    ; explicitly requested by the user is still allowed to enter idle mode.
    if (TranslatorFaded || IdleTransitionInProgress || (KeepActivePinned && !manual))
        return

    IdleTransitionInProgress := true
    IdleTransitionStartedTick := A_TickCount
    try {
        ; Align the independent mini strip to the full GUI's client-area origin.
        WinGetClientPos(&clientX, &clientY, &clientW, &clientH, "ahk_id " . MainGui.Hwnd)
        IdleStripTitleText.Text := TitleText.Text
        ; Rebuild the compact strip geometry on every transition. This prevents
        ; stale dimensions from a prior show/resize or another version from leaving
        ; a tiny duplicate-looking title bar.
        IdleStripGui.Show("Hide w" . IdleCompactClientWidth . " h" . IdleTitleStripHeight)
        SetIdleStripGeometry(clientX, clientY, true)
        SetWindowOpacityPercent(IdleStripGui.Hwnd, IdleTitleBarOpacityPercent)
        ; Don't wake at the same point that initiated a manual fade. Wake is armed
        ; only after the cursor leaves this strip and later re-enters it.
        IdleStripWakeArmed := false
        TranslatorFaded := true
        TranslatorVisible := true
        TranslatorMinimized := false
        WinHide("ahk_id " . MainGui.Hwnd)
        ApplyIdleStripZOrder(OverlayZMode)
        IdleTransitionInProgress := false
        IdleTransitionStartedTick := 0
        SetTimer(TranslatorIdleFadeMonitor, 50)
    } catch {
        TranslatorFaded := false
        TranslatorMinimized := false
        IdleTransitionInProgress := false
        IdleTransitionStartedTick := 0
        try WinHide("ahk_id " . IdleStripGui.Hwnd)
        try MainGui.Show("NA")
        try SetTranslatorOpacityPercent(ActiveWindowOpacityPercent)
        LastTranslatorActivityTick := A_TickCount
        SetTimer(TranslatorIdleFadeMonitor, 50)
    }
}

RestoreTranslatorFromIdleFade() {
    global MainGui, IdleStripGui, TranslatorFaded, LastTranslatorActivityTick
    global ActiveWindowOpacityPercent, OverlayZMode, IdleStripWakeArmed
    global IdleTransitionInProgress, IdleTransitionStartedTick
    global TranslatorVisible, TranslatorMinimized
    global ManualDoubleClickPending, IdleToggleLastClickTick, IdleToggleLastClickRoot
    global LastIdleMouseX, LastIdleMouseY

    if (!TranslatorFaded || IdleTransitionInProgress)
        return

    IdleTransitionInProgress := true
    IdleTransitionStartedTick := A_TickCount
    try {
        ; Hide the idle strip and clear the faded state before showing the main
        ; GUI. Showing a window can synchronously emit activation/focus messages;
        ; those messages must not recursively start another restore.
        WinHide("ahk_id " . IdleStripGui.Hwnd)
        WinSetRegion("", "ahk_id " . MainGui.Hwnd)
        IdleStripWakeArmed := false
        TranslatorFaded := false
        TranslatorVisible := true
        TranslatorMinimized := false
        if (DllCall("user32\IsIconic", "Ptr", MainGui.Hwnd, "Int"))
            WinRestore("ahk_id " . MainGui.Hwnd)
        WinSetExStyle("-0x20", "ahk_id " . MainGui.Hwnd)
        MainGui.Show("NA")
        SetTranslatorOpacityPercent(ActiveWindowOpacityPercent)
        UpdateArrowlessSelectors()
        MainGui.GetClientPos(&restoreX, &restoreY, &restoreW, &restoreH)
        LayoutControls(restoreW, restoreH)
        LastTranslatorActivityTick := A_TickCount
        SetTranslatorZMode(OverlayZMode)
        IdleTransitionInProgress := false
        IdleTransitionStartedTick := 0
        ManualDoubleClickPending := false
        IdleToggleLastClickTick := 0
        IdleToggleLastClickRoot := 0
        LastIdleMouseX := -999999
        LastIdleMouseY := -999999
        SetTimer(TranslatorIdleFadeMonitor, 50)
    } catch {
        TranslatorFaded := false
        TranslatorVisible := true
        TranslatorMinimized := false
        IdleTransitionInProgress := false
        IdleTransitionStartedTick := 0
        ; Leave the main window available if a transient restore step fails.
        try WinHide("ahk_id " . IdleStripGui.Hwnd)
        try MainGui.Show("NA")
        try SetTranslatorOpacityPercent(ActiveWindowOpacityPercent)
        LastTranslatorActivityTick := A_TickCount
        SetTimer(TranslatorIdleFadeMonitor, 50)
    }
}

; ============================================================
; WINDOWS DARK MODE
; ============================================================

ApplyWindowsDarkMode() {
    global MainGui

    darkMode := 1

    ; DWMWA_USE_IMMERSIVE_DARK_MODE.
    try {
        result := DllCall(
            "dwmapi\DwmSetWindowAttribute",
            "Ptr", MainGui.Hwnd,
            "UInt", 20,
            "Int*", darkMode,
            "UInt", 4,
            "Int"
        )

        ; Compatibility fallback.
        if (result != 0) {
            DllCall(
                "dwmapi\DwmSetWindowAttribute",
                "Ptr", MainGui.Hwnd,
                "UInt", 19,
                "Int*", darkMode,
                "UInt", 4,
                "Int"
            )
        }
    }
}

; Keep edit fields and dropdowns in dark mode, independently from the custom title strip.
ApplyDarkControlThemes() {
    global SourceDrop, TargetDrop, FontDrop
    global SourceSelectorFace, TargetSelectorFace, FontSelectorFace
    global SourceEdit, ResultEdit, StatusText

    controls := [
        SourceDrop,
        TargetDrop,
        FontDrop,
        SourceSelectorFace,
        TargetSelectorFace,
        FontSelectorFace,
        SourceEdit,
        ResultEdit,
        StatusText
    ]

    for _, ctrl in controls {
        try {
            DllCall(
                "uxtheme\SetWindowTheme",
                "Ptr", ctrl.Hwnd,
                "Str", "DarkMode_Explorer",
                "Str", ""
            )
        }
    }
}

ControlColor(wParam, lParam, msg, hwnd) {
    global DarkBrush, TitleBarBrush, TitleBar, TitleText
    global CopyButton, ClearButton, TargetClearButton, SourceEmojiButton, ChatEmojiButton
    global OCRButton, PasteInputButton
    global AddTranslatorButton, RemoveTranslatorButton
    global MinimizeButton, AlwaysOnTopButton, StatusText
    global IdleStripTitleBar, IdleStripTitleText
    global SourceSelectorFace, TargetSelectorFace, FontSelectorFace

    if (!DarkBrush)
        return

    if (msg != 0x0133
        && msg != 0x0134
        && msg != 0x0138)
        return

    ; Keep the status text selectable, but paint it with the exact GUI
    ; background and remove the client-edge so it looks like the old plain label.
    if ((msg = 0x0133 || msg = 0x0138) && lParam = StatusText.Hwnd) {
        DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", 0x00B6B6B6)
        DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", 0x00242120)
        return TitleBarBrush
    }

    ; Give the custom title band and its caption text the same stable dark
    ; brush; native DWM caption painting is not used by this GUI anymore.
    if (msg = 0x0138
        && (lParam = TitleBar.Hwnd || lParam = TitleText.Hwnd
            || lParam = IdleStripTitleBar.Hwnd || lParam = IdleStripTitleText.Hwnd)) {
        DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", 0x00F2F2F2)
        DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", 0x00242120)
        return TitleBarBrush
    }

    ; Let the clickable dark text controls keep their own Background303030 color.
    if (msg = 0x0138
        && (lParam = CopyButton.Hwnd
            || lParam = ClearButton.Hwnd
            || lParam = TargetClearButton.Hwnd
            || lParam = SourceEmojiButton.Hwnd
            || lParam = ChatEmojiButton.Hwnd
            || lParam = OCRButton.Hwnd
            || lParam = PasteInputButton.Hwnd
            || lParam = MinimizeButton.Hwnd
            || lParam = AlwaysOnTopButton.Hwnd
            || lParam = AddTranslatorButton.Hwnd
            || lParam = RemoveTranslatorButton.Hwnd
            || lParam = SourceSelectorFace.Hwnd
            || lParam = TargetSelectorFace.Hwnd
            || lParam = FontSelectorFace.Hwnd))
        return

    DllCall(
        "gdi32\SetTextColor",
        "Ptr", wParam,
        "UInt", 0x00F2F2F2
    )

    DllCall(
        "gdi32\SetBkColor",
        "Ptr", wParam,
        "UInt", 0x00262626
    )

    return DarkBrush
}


; ============================================================
; RESIZABLE GUI LAYOUT
; ============================================================

GuiSize(thisGui, MinMax, Width, Height) {
    global WindowWidth, WindowHeight, TranslatorMinimized
    global MainGui, LastTranslatorActivityTick, TranslatorFaded
    global ActiveWindowOpacityPercent, IdleResizeFrameRemoved, LastRenderedStatusText

    if (MinMax = -1) {
        TranslatorMinimized := true
        return
    }

    if (TranslatorMinimized) {
        TranslatorMinimized := false
        if (TranslatorFaded)
            RestoreTranslatorFromIdleFade()
        try SetTranslatorOpacityPercent(ActiveWindowOpacityPercent)
        LastTranslatorActivityTick := A_TickCount
        SetTimer(ShowOnTargetRoblox, -50)
    }

    ; A frame-change notification can fire while idle mode is clipping the
    ; window. Do not run the full normal layout then: it would move the pin and
    ; minimize buttons out of the narrow visible title strip.
    if (TranslatorFaded || IdleResizeFrameRemoved)
        return

    LayoutControls(Width, Height)

    ; Do not save maximized dimensions.
    if (MinMax = 1)
        return

    if (Width >= 344 && Height >= 350) {
        ; These event dimensions are client dimensions.
        WindowWidth := Width
        WindowHeight := Height
        LastRenderedStatusText := ""
        SetTimer(StatusLayoutMonitor, -1)

        ; Save after the user finishes resizing.
        SetTimer(SaveSettings, -400)
    }
}

LayoutControls(Width, Height) {
    global TitleBar, TitleText, MinimizeButton, AlwaysOnTopButton, CustomTitleBarHeight
    global StatusDisplayHeight
    global FontLabel, LanguageLabel
    global SourceDrop, TargetDrop, FontDrop
    global SourceSelectorFace, TargetSelectorFace, FontSelectorFace
    global SourceEdit, ResultEdit
    global StatusText, StatusDisplayWidth, CopyButton, ClearButton
    global TargetClearButton, SourceEmojiButton, ChatEmojiButton
    global AddTranslatorButton, RemoveTranslatorButton
    global OCRButton, PasteInputButton

    controlW := Max(280, Width - 24)

    ; Top row.
    sourceW := Max(150, Width - 225)
    fontLabelX := Width - 180
    fontDropX := Width - 140

    ; Custom dark title strip sits in the client area and can be dragged.
    TitleBar.Move(
        0, 0, Width, CustomTitleBarHeight
    )

    TitleText.Move(
        12, 8, 105, 22
    )

    OCRButton.Move(
        123, 5, 48, 26
    )

    pasteInputW := Min(104, Max(88, Width - 256))
    PasteInputButton.Move(
        177, 5, pasteInputW, 26
    )

    ; Right-aligned emoji pin and minimize controls: identical dimensions.
    AlwaysOnTopButton.Move(
        Width - 76, 5, 30, 26
    )

    MinimizeButton.Move(
        Width - 40, 5, 30, 26
    )

    ; Set dropdown popup rows with R above; do not pass H in Move(),
    ; because H limits the combined control + list height.
    SourceDrop.Move(
        12, 42, sourceW
    )
    SourceSelectorFace.Move(12, 42, sourceW, 28)

    FontLabel.Move(
        fontLabelX, 47, 36, 20
    )

    FontDrop.Move(
        fontDropX, 42, 110
    )
    FontSelectorFace.Move(fontDropX, 42, 110, 28)

    ; Reserve enough height for one or more status lines.
    statusH := Max(20, StatusDisplayHeight)
    buttonY := Height - statusH - 52
    sourceY := 80

    ; Share available space between source and result editors.
    sourceH := Max(
        36,
        Floor((buttonY - sourceY - 58) / 2)
    )

    SourceEdit.Move(
        12, sourceY, controlW, sourceH
    )

    ; Target selector row.
    languageY := sourceY + sourceH + 10

    LanguageLabel.Move(
        12, languageY, 72, 28
    )

    ; Keep the emoji button between the target selector and Clear.
    ; The row remains inside the GUI at its minimum width.
    clearButtonW := 100
    clearButtonGap := 6
    emojiButtonW := 36
    targetDropW := Max(100, controlW - 78 - clearButtonW - emojiButtonW - 2 * clearButtonGap)
    TargetDrop.Move(
        90,
        languageY,
        targetDropW
    )
    TargetSelectorFace.Move(90, languageY, targetDropW, 30)
    SourceEmojiButton.Move(
        90 + targetDropW + clearButtonGap,
        languageY,
        emojiButtonW,
        30
    )
    TargetClearButton.Move(
        90 + targetDropW + clearButtonGap + emojiButtonW + clearButtonGap,
        languageY,
        clearButtonW,
        30
    )

    ; Result editor.
    resultY := languageY + 38
    resultH := Max(
        36,
        buttonY - 10 - resultY
    )

    ResultEdit.Move(
        12, resultY, controlW, resultH
    )

    CopyButton.Move(
        12, buttonY, 120, 30
    )

    ChatEmojiButton.Move(
        140, buttonY, 34, 30
    )

    ClearButton.Move(
        180, buttonY, 80, 30
    )

    ; Keep + and - at the far right, aligned to the same row with a 6px gap.
    RemoveTranslatorButton.Move(
        Width - 44, buttonY, 32, 30
    )
    AddTranslatorButton.Move(
        Width - 82, buttonY, 32, 30
    )

    statusW := Max(52, Min(controlW, StatusDisplayWidth))
    StatusText.Move(
        12, Height - statusH - 10, statusW, statusH
    )

    UpdateArrowlessSelectors()
}


UpdateArrowlessSelectors() {
    global SourceDrop, TargetDrop, FontDrop
    global SourceSelectorFace, TargetSelectorFace, FontSelectorFace
    global TranslatorFaded

    ; These native dropdowns are retained only as selection-value models.
    ; They are never visible, so their bright native arrow buttons are removed
    ; from the UI rather than covered by another control.
    try SourceDrop.Visible := false
    try TargetDrop.Visible := false
    try FontDrop.Visible := false

    if (!TranslatorFaded) {
        try SourceSelectorFace.Visible := true
        try TargetSelectorFace.Visible := true
        try FontSelectorFace.Visible := true
    }
}

ApplySelectedFont() {
    global FontDrop, FontSizes
    global SourceEdit, ResultEdit

    index := FontDrop.Value

    if (index < 1 || index > FontSizes.Length)
        index := 4

    size := FontSizes[index] + 0

    SourceEdit.SetFont(
        "s" . size,
        "Segoe UI"
    )

    ResultEdit.SetFont(
        "s" . size,
        "Segoe UI"
    )
}

FontSizeChanged(*) {
    global FontDrop, FontSizes, StatusText

    ApplySelectedFont()

    index := FontDrop.Value

    if (index < 1 || index > FontSizes.Length)
        return

    StatusText.Value :=
        "Font size: " . FontSizes[index] . " px"

    SaveSettings()
}


; ============================================================
; MOUSE WHEEL SCROLLING FOR EDITORS WITHOUT VISIBLE SCROLLBARS
; ============================================================

HandleEditMouseWheel(wParam, lParam, msg, hwnd) {
    global MainGui, SourceEdit, ResultEdit
    global EditWheelRemainder

    ; Wheel activity inside a dropdown/editor should also postpone idle fade.
    MarkTranslatorActivity(wParam, lParam, msg, hwnd)

    ; Select the control actually under the pointer. Windows can route the
    ; wheel message to the focused control instead of the hovered control.
    ; Use screen coordinates to match GetWindowRect geometry.
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mouseX, &mouseY, &mouseWindow, &mouseControl, 2)
    targetHwnd := mouseControl ? mouseControl : mouseWindow

    isEditorUnderPointer :=
        (targetHwnd = SourceEdit.Hwnd)
        || (targetHwnd = ResultEdit.Hwnd)

    isEditorReceiver :=
        (hwnd = SourceEdit.Hwnd)
        || (hwnd = ResultEdit.Hwnd)

    if (!isEditorUnderPointer) {
        if (isEditorReceiver) {
            ; The message reached an edit while the pointer is over another
            ; control (e.g. a language dropdown). Forward it to that control
            ; only when it belongs to this script, then consume the original
            ; message so the edit does not scroll accidentally.
            if (targetHwnd && targetHwnd != hwnd) {
                targetPid := 0
                DllCall(
                    "user32\GetWindowThreadProcessId",
                    "Ptr", targetHwnd,
                    "UInt*", &targetPid,
                    "UInt"
                )
                currentPid := DllCall(
                    "kernel32\GetCurrentProcessId",
                    "UInt"
                )
                if (targetPid = currentPid) {
                    DllCall(
                        "user32\SendMessageW",
                        "Ptr", targetHwnd,
                        "UInt", 0x020A, ; WM_MOUSEWHEEL
                        "UPtr", wParam,
                        "Ptr", lParam,
                        "Ptr"
                    )
                }
            }
            return 1
        }

        ; Important: return no value, not 0. This lets the normal Windows
        ; control procedure handle wheel messages for dropdowns and other
        ; non-editor controls.
        return
    }

    ; Decode the high word of wParam as a signed wheel delta.
    wheelDelta := (wParam >> 16) & 0xFFFF
    if (wheelDelta >= 0x8000)
        wheelDelta -= 0x10000

    ; Keep partial high-resolution wheel deltas until a full notch arrives.
    EditWheelRemainder += wheelDelta
    notches := 0

    if (EditWheelRemainder >= 120) {
        notches := Floor(EditWheelRemainder / 120)
        EditWheelRemainder := Mod(EditWheelRemainder, 120)
    } else if (EditWheelRemainder <= -120) {
        notches := Ceil(EditWheelRemainder / 120)
        EditWheelRemainder := Mod(EditWheelRemainder, 120)
    }

    if (notches != 0) {
        ; EM_LINESCROLL (0x00B6): scroll 3 text lines per wheel notch.
        linesToScroll := -notches * 3
        DllCall(
            "user32\SendMessageW",
            "Ptr", targetHwnd,
            "UInt", 0x00B6,
            "Ptr", 0,
            "Ptr", linesToScroll,
            "Ptr"
        )
    }

    ; The custom edit scroll has already handled this wheel message.
    return 1
}

; ============================================================
; DOUBLE-CLICK TO TOGGLE FULL / IDLE DISPLAY
; Use a low-level physical mouse hook so click-up is recognized consistently
; whether Windows routes the event to the parent GUI or any child control.
; ============================================================

InstallIdleToggleMouseHook() {
    global IdleToggleMouseHookHandle, IdleToggleMouseHookCallback

    if (IdleToggleMouseHookHandle)
        return true

    try {
        IdleToggleMouseHookCallback := CallbackCreate(IdleToggleMouseHookProc, "", 3)
        moduleHandle := DllCall("kernel32\GetModuleHandleW", "Ptr", 0, "Ptr")
        IdleToggleMouseHookHandle := DllCall(
            "user32\SetWindowsHookExW",
            "Int", 14, ; WH_MOUSE_LL
            "Ptr", IdleToggleMouseHookCallback,
            "Ptr", moduleHandle,
            "UInt", 0,
            "Ptr"
        )
        if (!IdleToggleMouseHookHandle) {
            CallbackFree(IdleToggleMouseHookCallback)
            IdleToggleMouseHookCallback := 0
            return false
        }
        return true
    } catch {
        if (IdleToggleMouseHookCallback) {
            try CallbackFree(IdleToggleMouseHookCallback)
            IdleToggleMouseHookCallback := 0
        }
        IdleToggleMouseHookHandle := 0
        return false
    }
}

UninstallIdleToggleMouseHook() {
    global IdleToggleMouseHookHandle, IdleToggleMouseHookCallback

    if (IdleToggleMouseHookHandle) {
        try DllCall("user32\UnhookWindowsHookEx", "Ptr", IdleToggleMouseHookHandle, "Int")
        IdleToggleMouseHookHandle := 0
    }
    if (IdleToggleMouseHookCallback) {
        try CallbackFree(IdleToggleMouseHookCallback)
        IdleToggleMouseHookCallback := 0
    }
}

IdleToggleMouseHookProc(nCode, wParam, lParam) {
    global IdleToggleMouseHookHandle

    ; HC_ACTION (0) + WM_LBUTTONUP. Do not consume the mouse message.
    if (nCode >= 0 && wParam = 0x0202) {
        try {
            x := NumGet(lParam, 0, "Int")
            y := NumGet(lParam, 4, "Int")
            ProcessIdleToggleMouseUp(x, y)
        } catch {
            ; Never let a callback exception block normal OS mouse processing.
        }
    }

    return DllCall(
        "user32\CallNextHookEx",
        "Ptr", IdleToggleMouseHookHandle,
        "Int", nCode,
        "UPtr", wParam,
        "Ptr", lParam,
        "Ptr"
    )
}

ProcessIdleToggleMouseUp(x, y) {
    global MainGui, SelectorPopupGui, TranslatorFaded, TranslatorMinimized, TranslatorVisible
    global SourceEdit, ResultEdit, StatusText, TitleBar, TitleText
    global SourceDrop, TargetDrop, FontDrop, SourceSelectorFace, TargetSelectorFace, FontSelectorFace
    global AlwaysOnTopButton, MinimizeButton, OCRButton, PasteInputButton
    global TargetClearButton, SourceEmojiButton, ChatEmojiButton
    global CopyButton, ClearButton, AddTranslatorButton, RemoveTranslatorButton
    global IdleToggleLastClickTick, IdleToggleLastClickRoot, IdleToggleLastClickX, IdleToggleLastClickY
    global ManualDoubleClickPending

    RepairIdleLifecycleState()
    ; Only a genuinely visible selector blocks this action. A destroyed or
    ; hidden popup reference must not lock out double-click detection forever.
    if (SelectorPopupIsLive() || TranslatorFaded || TranslatorMinimized || !TranslatorVisible
        || !DllCall("user32\IsWindowVisible", "Ptr", MainGui.Hwnd, "Int")) {
        IdleToggleLastClickTick := 0
        IdleToggleLastClickRoot := 0
        return
    }

    if (!GetWindowPos(MainGui.Hwnd, &wx, &wy, &ww, &wh)
        || x < wx || x >= wx + ww || y < wy || y >= wy + wh) {
        IdleToggleLastClickTick := 0
        IdleToggleLastClickRoot := 0
        return
    }

    ; WindowFromPoint resolves the actual child HWND at the physical release point.
    point := Buffer(8, 0)
    NumPut("Int", x, point, 0)
    NumPut("Int", y, point, 4)
    hit := DllCall("user32\WindowFromPoint", "Int64", NumGet(point, 0, "Int64"), "Ptr")
    if (!hit || GetRootWindow(hit) != MainGui.Hwnd) {
        IdleToggleLastClickTick := 0
        IdleToggleLastClickRoot := 0
        return
    }

    ; Preserve native behavior for input fields, selectors, buttons and the
    ; selectable status line. Everything else in the client area can toggle idle.
    excludedControls := [
        SourceEdit, ResultEdit, StatusText, TitleBar, TitleText,
        SourceDrop, TargetDrop, FontDrop,
        SourceSelectorFace, TargetSelectorFace, FontSelectorFace,
        AlwaysOnTopButton, MinimizeButton, OCRButton, PasteInputButton,
        TargetClearButton, SourceEmojiButton, ChatEmojiButton,
        CopyButton, ClearButton, AddTranslatorButton, RemoveTranslatorButton
    ]
    for control in excludedControls {
        if (!control || !control.Hwnd)
            continue
        if (hit = control.Hwnd) {
            IdleToggleLastClickTick := 0
            IdleToggleLastClickRoot := 0
            return
        }
        if (GetWindowPos(control.Hwnd, &cx, &cy, &cw, &ch)
            && x >= cx && x < cx + cw && y >= cy && y < cy + ch) {
            IdleToggleLastClickTick := 0
            IdleToggleLastClickRoot := 0
            return
        }
    }

    now := A_TickCount
    doubleMs := DllCall("user32\GetDoubleClickTime", "UInt")
    maxX := DllCall("user32\GetSystemMetrics", "Int", 36, "Int") ; SM_CXDOUBLECLK
    maxY := DllCall("user32\GetSystemMetrics", "Int", 37, "Int") ; SM_CYDOUBLECLK

    isSecondClick := IdleToggleLastClickTick > 0
        && IdleToggleLastClickRoot = MainGui.Hwnd
        && now - IdleToggleLastClickTick <= doubleMs
        && Abs(x - IdleToggleLastClickX) <= maxX
        && Abs(y - IdleToggleLastClickY) <= maxY

    if (isSecondClick) {
        IdleToggleLastClickTick := 0
        IdleToggleLastClickRoot := 0
        if (!ManualDoubleClickPending) {
            ManualDoubleClickPending := true
            SetTimer(ToggleTranslatorIdleByDoubleClick, -60)
        }
    } else {
        IdleToggleLastClickTick := now
        IdleToggleLastClickRoot := MainGui.Hwnd
        IdleToggleLastClickX := x
        IdleToggleLastClickY := y
        SetTimer(ClearStaleIdleToggleClick, -Max(250, doubleMs + 50))
    }
}

ClearStaleIdleToggleClick(*) {
    global IdleToggleLastClickTick, IdleToggleLastClickRoot
    global IdleToggleLastClickX, IdleToggleLastClickY

    IdleToggleLastClickTick := 0
    IdleToggleLastClickRoot := 0
    IdleToggleLastClickX := -999999
    IdleToggleLastClickY := -999999
}

ToggleTranslatorIdleByDoubleClick(*) {
    global TranslatorFaded, TranslatorMinimized, TranslatorVisible
    global LastTranslatorActivityTick, StatusText
    global ManualDoubleClickPending, IdleTransitionInProgress, IdleTransitionStartedTick
    global IdleToggleLastClickTick, IdleToggleLastClickRoot
    global LastIdleMouseX, LastIdleMouseY

    ; Do not drop the request if a hide/show transition is still settling.
    RepairIdleLifecycleState()
    if (IdleTransitionInProgress) {
        if (!IdleTransitionStartedTick || A_TickCount - IdleTransitionStartedTick < 1500) {
            SetTimer(ToggleTranslatorIdleByDoubleClick, -50)
            return
        }
        RepairIdleLifecycleState(true)
    }

    if (GetKeyState("LButton", "P")) {
        SetTimer(ToggleTranslatorIdleByDoubleClick, -25)
        return
    }

    if (TranslatorMinimized || !TranslatorVisible) {
        ManualDoubleClickPending := false
        return
    }
    ManualDoubleClickPending := false

    ; Reset the click sequence before changing visibility so any follow-up mouse
    ; messages generated by Hide/Show cannot be counted as another click.
    IdleToggleLastClickTick := 0
    IdleToggleLastClickRoot := 0

    if (TranslatorFaded) {
        RestoreTranslatorFromIdleFade()
        try StatusText.Value := "Translator restored by double-click"
    } else {
        FadeTranslatorForIdle(true)
        try StatusText.Value := "Translator set to idle by double-click"
    }

    ; Start a fresh inactivity interval and sync the position sample so the
    ; next monitor cycle does not interpret the visibility transition as input.
    CoordMode("Mouse", "Screen")
    MouseGetPos(&LastIdleMouseX, &LastIdleMouseY)
    LastTranslatorActivityTick := A_TickCount
    SetTimer(TranslatorIdleFadeMonitor, 50)
}

; ============================================================
; TRIPLE-CLICK TO SELECT ALL
; ============================================================

HandleEditMouseUp(wParam, lParam, msg, hwnd) {
    global SourceEdit, ResultEdit, SelectorPopupList
    global SourceSelectorFace, TargetSelectorFace, FontSelectorFace
    global EditLastClickTick, EditLastClickHwnd
    global EditLastClickX, EditLastClickY, EditClickCount
    global LastTranslatorActivityTick, IdleTransitionInProgress

    ; Double-click idle toggling is handled by the low-level physical mouse hook.
    ; This handler remains responsible only for selector popup and editor-click logic.
    if (!IdleTransitionInProgress && IsTranslatorOwnedWindow(hwnd))
        LastTranslatorActivityTick := A_TickCount

    ; Important: open a selector after the initiating mouse button is released.
    ; Opening it on the Click/down phase lets the release reach the new ListBox,
    ; which commits the old selection immediately and makes the popup look like
    ; it only exists while the mouse button is held.
    if (hwnd = SourceSelectorFace.Hwnd) {
        SetTimer(OpenSelectorPopup.Bind("source"), -40)
        return
    }
    if (hwnd = TargetSelectorFace.Hwnd) {
        SetTimer(OpenSelectorPopup.Bind("target"), -40)
        return
    }
    if (hwnd = FontSelectorFace.Hwnd) {
        SetTimer(OpenSelectorPopup.Bind("font"), -40)
        return
    }

    ; Preserve the actual click coordinates and resolve the item under the
    ; cursor with LB_ITEMFROMPOINT after Windows finishes its normal ListBox
    ; processing. This makes the committed option match the visible row clicked.
    if (SelectorPopupList && hwnd = SelectorPopupList.Hwnd) {
        popupClickX := lParam & 0xFFFF
        popupClickY := (lParam >> 16) & 0xFFFF
        SetTimer(CommitSelectorPopupSelectionAtPoint.Bind(hwnd, popupClickX, popupClickY), -20)
        return
    }

    if (hwnd != SourceEdit.Hwnd
        && hwnd != ResultEdit.Hwnd)
        return

    x := lParam & 0xFFFF
    y := (lParam >> 16) & 0xFFFF
    now := A_TickCount

    doubleMs := DllCall(
        "user32\GetDoubleClickTime",
        "UInt"
    )

    maxX := DllCall(
        "user32\GetSystemMetrics",
        "Int", 36,
        "Int"
    )

    maxY := DllCall(
        "user32\GetSystemMetrics",
        "Int", 37,
        "Int"
    )

    sameClickArea :=
        (hwnd = EditLastClickHwnd)
        && (now - EditLastClickTick <= doubleMs)
        && (Abs(x - EditLastClickX) <= maxX)
        && (Abs(y - EditLastClickY) <= maxY)

    if (sameClickArea)
        EditClickCount += 1
    else
        EditClickCount := 1

    EditLastClickTick := now
    EditLastClickHwnd := hwnd
    EditLastClickX := x
    EditLastClickY := y

    if (EditClickCount >= 3) {
        EditClickCount := 0
        SetTimer(SelectAllInEdit.Bind(hwnd), -30)
    }
}

SelectAllInEdit(hwnd) {
    if (!DllCall(
        "user32\IsWindow",
        "Ptr", hwnd,
        "Int"
    ))
        return

    ; EM_SETSEL: select the entire text.
    DllCall(
        "user32\SendMessageW",
        "Ptr", hwnd,
        "UInt", 0x00B1,
        "Ptr", 0,
        "Ptr", -1,
        "Ptr"
    )
}


; ============================================================
; ARROWLESS DARK LANGUAGE / FONT SELECTORS
; ============================================================

; Keeps SS_NOTIFY enabled on the static selector faces. Opening is coordinated
; exclusively from WM_LBUTTONUP by HandleEditMouseUp to avoid using the opening
; mouse-down/up cycle as a click on the newly created ListBox.
IgnoreSelectorFaceClick(*) {
    return
}

OpenSelectorPopup(kind, *) {
    global MainGui, TranslatorFaded, LastTranslatorActivityTick
    global SourceDrop, TargetDrop, FontDrop
    global SourceSelectorFace, TargetSelectorFace, FontSelectorFace
    global SourceLanguages, TargetLanguages, FontSizes
    global SelectorPopupGui, SelectorPopupList, SelectorPopupKind, SelectorPopupFace, SelectorPopupOpenedTick
    global SelectorPopupLastLeftDown

    LastTranslatorActivityTick := A_TickCount
    if (TranslatorFaded)
        RestoreTranslatorFromIdleFade()

    if (SelectorPopupGui) {
        if (SelectorPopupKind = kind) {
            CloseSelectorPopup()
            return
        }
        CloseSelectorPopup()
    }

    switch kind {
        case "source":
            face := SourceSelectorFace
            items := SourceLanguages
            selectedIndex := SourceDrop.Value
            rowCount := items.Length
        case "target":
            face := TargetSelectorFace
            items := TargetLanguages
            selectedIndex := TargetDrop.Value
            rowCount := items.Length
        case "font":
            face := FontSelectorFace
            items := FontSizes
            selectedIndex := FontDrop.Value
            rowCount := items.Length
        default:
            return
    }

    if (selectedIndex < 1 || selectedIndex > items.Length)
        selectedIndex := 1

    face.GetPos(&faceX, &faceY, &faceW, &faceH)
    ; Use the selector's actual native screen rectangle for popup placement.
    ; Mixing AHK-scaled GetPos coordinates with raw ClientToScreen coordinates
    ; can offset the popup on scaled / mixed-DPI displays.
    if (!GetWindowPos(face.Hwnd, &faceScreenX, &faceScreenY, &faceScreenW, &faceScreenH))
        return

    ; Source/target language popup menus use a fixed width regardless of the
    ; main window size. The font-size popup retains its compact selector width.
    if (kind = "source" || kind = "target")
        popupW := Min(LanguageDropdownPopupWidth, Max(160, A_ScreenWidth - 16))
    else
        popupW := faceW

    rowHeight := 22
    popupH := rowCount * rowHeight + 4

    popupGui := Gui("+Owner" . MainGui.Hwnd . " -Caption +ToolWindow +AlwaysOnTop")
    popupGui.BackColor := "262626"
    popupGui.SetFont("s10 cF2F2F2", "Segoe UI")
    popupList := popupGui.AddListBox(
        "x0 y0 w" . popupW . " h" . popupH . " AltSubmit Background262626 cF2F2F2",
        items
    )
    popupList.Value := selectedIndex

    SelectorPopupGui := popupGui
    SelectorPopupList := popupList
    SelectorPopupKind := kind
    SelectorPopupFace := face

    popupGui.OnEvent("Escape", CloseSelectorPopup)
    popupGui.OnEvent("Close", CloseSelectorPopup)
    popupList.OnEvent("DoubleClick", CommitSelectorPopupSelection)

    try DllCall("uxtheme\SetWindowTheme", "Ptr", popupList.Hwnd,
        "Str", "DarkMode_Explorer", "Str", "")

    ; Create the popup hidden first, then place it using native screen pixels.
    ; This avoids mixing logical AHK control coordinates with physical cursor
    ; coordinates on displays using non-100% scaling.
    popupGui.Show("Hide w" . popupW . " h" . popupH)
    if (!GetWindowPos(popupGui.Hwnd, &popupNativeX, &popupNativeY, &popupNativeW, &popupNativeH)) {
        CloseSelectorPopup()
        return
    }

    ; Obtain the work area of the monitor containing the selector, in the same
    ; Win32 screen-coordinate system used by GetWindowPos and the mouse hook.
    workLeft := 0
    workTop := 0
    workRight := A_ScreenWidth
    workBottom := A_ScreenHeight
    hMonitor := DllCall("user32\MonitorFromWindow", "Ptr", MainGui.Hwnd, "UInt", 2, "Ptr")
    if (hMonitor) {
        monitorInfo := Buffer(40, 0)
        NumPut("UInt", 40, monitorInfo, 0)
        if (DllCall("user32\GetMonitorInfoW", "Ptr", hMonitor, "Ptr", monitorInfo, "Int")) {
            workLeft := NumGet(monitorInfo, 20, "Int")
            workTop := NumGet(monitorInfo, 24, "Int")
            workRight := NumGet(monitorInfo, 28, "Int")
            workBottom := NumGet(monitorInfo, 32, "Int")
        }
    }

    popupX := Min(Max(workLeft + 4, faceScreenX), Max(workLeft + 4, workRight - popupNativeW - 4))
    popupY := faceScreenY + faceScreenH
    if (popupY + popupNativeH > workBottom - 4)
        popupY := faceScreenY - popupNativeH
    popupY := Min(Max(workTop + 4, popupY), Max(workTop + 4, workBottom - popupNativeH - 4))

    ; Capture the actual native ListBox window handle for row hit testing after
    ; WM_LBUTTONUP; the popup's visible row and selected index must agree.
    SelectorPopupOpenedTick := A_TickCount
    SelectorPopupLastLeftDown := false
    positioned := DllCall("user32\SetWindowPos", "Ptr", popupGui.Hwnd, "Ptr", -1
        , "Int", popupX, "Int", popupY, "Int", 0, "Int", 0
        , "UInt", 0x0001 | 0x0010 | 0x0040, "Int") ; NOSIZE|NOACTIVATE|SHOWWINDOW
    if (!positioned) {
        ; Fallback to AHK's own coordinate system if native placement fails.
        popupGui.Show("NA x" . faceX . " y" . (faceY + faceH) . " w" . popupW . " h" . popupH)
    }
    try WinSetAlwaysOnTop(true, "ahk_id " . popupGui.Hwnd)
    SetTimer(MonitorSelectorPopup, 25)
}

CommitSelectorPopupSelectionAtPoint(listHwnd, clickX, clickY) {
    global SelectorPopupList, SelectorPopupKind
    global SourceLanguages, TargetLanguages, FontSizes

    if (!SelectorPopupList || SelectorPopupList.Hwnd != listHwnd
        || !DllCall("user32\IsWindow", "Ptr", listHwnd, "Int"))
        return

    ; LB_ITEMFROMPOINT (0x01A9): low word = zero-based item index; high word
    ; is nonzero when the point is outside the ListBox client area.
    packedPoint := (clickX & 0xFFFF) | ((clickY & 0xFFFF) << 16)
    hitInfo := DllCall("user32\SendMessageW", "Ptr", listHwnd, "UInt", 0x01A9
        , "UPtr", 0, "Ptr", packedPoint, "UInt")
    itemIndex := hitInfo & 0xFFFF
    outside := (hitInfo >> 16) & 0xFFFF

    switch SelectorPopupKind {
        case "source": itemCount := SourceLanguages.Length
        case "target": itemCount := TargetLanguages.Length
        case "font": itemCount := FontSizes.Length
        default: return
    }
    if (outside || itemIndex >= itemCount)
        return

    ; AHK ListBox.Value is one-based. Force it to match the row directly under
    ; the mouse, rather than relying on any stale selection notification.
    SelectorPopupList.Value := itemIndex + 1
    CommitSelectorPopupSelection()
}

CommitSelectorPopupSelection(*) {
    global SelectorPopupList, SelectorPopupKind
    global SourceDrop, TargetDrop, FontDrop
    global SourceSelectorFace, TargetSelectorFace, FontSelectorFace
    global SourceLanguages, TargetLanguages, FontSizes

    if (!SelectorPopupList)
        return

    index := SelectorPopupList.Value
    kind := SelectorPopupKind
    if (index < 1) {
        CloseSelectorPopup()
        return
    }

    CloseSelectorPopup()

    switch kind {
        case "source":
            if (index > SourceLanguages.Length)
                return
            SourceDrop.Value := index
            SourceSelectorFace.Text := SourceLanguages[index]
            LanguageChanged()
        case "target":
            if (index > TargetLanguages.Length)
                return
            TargetDrop.Value := index
            TargetSelectorFace.Text := TargetLanguages[index]
            LanguageChanged()
        case "font":
            if (index > FontSizes.Length)
                return
            FontDrop.Value := index
            FontSelectorFace.Text := FontSizes[index]
            FontSizeChanged()
    }
    SetTimer(StatusLayoutMonitor, -1)
}

CloseSelectorPopup(*) {
    global SelectorPopupGui, SelectorPopupList, SelectorPopupKind, SelectorPopupFace, SelectorPopupOpenedTick
    global SelectorPopupLastLeftDown

    SetTimer(MonitorSelectorPopup, 0)
    oldPopup := SelectorPopupGui
    SelectorPopupGui := 0
    SelectorPopupList := 0
    SelectorPopupKind := ""
    SelectorPopupFace := 0
    SelectorPopupOpenedTick := 0
    SelectorPopupLastLeftDown := false
    if (oldPopup) {
        try oldPopup.Destroy()
    }
}

MonitorSelectorPopup() {
    global SelectorPopupGui, SelectorPopupFace, SelectorPopupOpenedTick, MainGui
    global SelectorPopupLastLeftDown

    if (!SelectorPopupGui)
        return

    ; Detect a NEW left-button press, not the mouse press that originally opened
    ; the selector. The old level-trigger check closed language popups when the
    ; initiating click was still physically held, which looked like a one-frame menu.
    leftDown := (DllCall("user32\GetAsyncKeyState", "Int", 0x01, "Short") & 0x8000) != 0
    newLeftPress := leftDown && !SelectorPopupLastLeftDown
    SelectorPopupLastLeftDown := leftDown

    ; Let the selector face's original click and activation settle while still
    ; updating button state above, so held opening clicks are not re-detected.
    if (A_TickCount - SelectorPopupOpenedTick < 250)
        return

    try {
        CoordMode("Mouse", "Screen")
        MouseGetPos(&mouseX, &mouseY)
        if (!GetWindowPos(SelectorPopupGui.Hwnd, &popupX, &popupY, &popupW, &popupH))
            return

        ; Keep the popup alive while the pointer is over its native screen rect.
        if (mouseX >= popupX - 8 && mouseX < popupX + popupW + 8
            && mouseY >= popupY - 8 && mouseY < popupY + popupH + 8)
            return

        ; The selector face is a valid region while moving from anchor into list.
        if (SelectorPopupFace) {
            if (GetWindowPos(SelectorPopupFace.Hwnd, &anchorX, &anchorY, &anchorW, &anchorH)) {
                if (mouseX >= anchorX - 10 && mouseX < anchorX + anchorW + 10
                    && mouseY >= anchorY - 10 && mouseY < anchorY + anchorH + 10)
                    return
            }
        }

        ; Dismiss only on a fresh click outside both the popup and anchor.
        if (newLeftPress)
            CloseSelectorPopup()
    } catch {
        ; Transient geometry errors should not hide a visible popup.
        return
    }
}

; ============================================================
; LANGUAGE SELECTION
; ============================================================

GetSourceCode() {
    global SourceDrop, SourceCodes

    index := SourceDrop.Value

    if (index < 1 || index > SourceCodes.Length)
        index := 1

    return SourceCodes[index]
}

GetTargetCode() {
    global TargetDrop, TargetCodes

    index := TargetDrop.Value

    if (index < 1 || index > TargetCodes.Length)
        index := 1

    return TargetCodes[index]
}

LanguageChanged(*) {
    global TranslateRevision, TranslationReady
    global PendingChatPaste, PendingChatAutoSend, TranslationInProgress
    global SourceEdit, ResultEdit, StatusText
    global LastInputChangeTick

    TranslateRevision += 1
    LastInputChangeTick := A_TickCount
    TranslationReady := false

    ; If the user changes a language after pressing Enter,
    ; cancel the old queued paste to avoid sending stale text.
    PendingChatPaste := false
    PendingChatAutoSend := false

    SetTimer(DoTranslate, 0)
    SaveSettings()

    if (Trim(SourceEdit.Value, " `t`r`n") = "") {
        ResultEdit.Value := ""
        StatusText.Value := "Language changed"
        return
    }

    ResultEdit.Value := ""
    StatusText.Value := "Waiting for language selection..."

    ; Debounce language changes.
    SetTimer(DoTranslate, -350)
}


; ============================================================
; AUTOMATIC TRANSLATION
; ============================================================

InputChanged(*) {
    global TranslateRevision, TranslationReady
    global PendingChatPaste, PendingChatAutoSend
    global SourceEdit, ResultEdit, StatusText
    global LastInputChangeTick

    TranslateRevision += 1
    LastInputChangeTick := A_TickCount
    TranslationReady := false

    ; If the source changes after an Enter request was queued,
    ; cancel that old action rather than paste the wrong sentence.
    PendingChatPaste := false
    PendingChatAutoSend := false

    SetTimer(DoTranslate, 0)

    source := Trim(SourceEdit.Value, " `t`r`n")

    if (source = "") {
        ResultEdit.Value := ""
        StatusText.Value := "Ready"
        return
    }

    ResultEdit.Value := ""
    StatusText.Value := "Waiting to translate..."

    ; Wait until typing has been idle for 350 ms. HTTP itself is
    ; asynchronous below, so a later pause cannot freeze the editor.
    SetTimer(DoTranslate, -350)
}

DoTranslate() {
    global TranslateRevision, TranslationReady
    global TranslationInProgress, PendingChatPaste, PendingChatAutoSend
    global SourceEdit, StatusText
    global NextRequestAllowedTick, RateLimitUntilTick
    global ActiveTranslationRequest, ActiveTranslationRevision
    global ActiveTranslationSource, ActiveTranslationSourceLang
    global ActiveTranslationTarget, LastInputChangeTick

    source := Trim(SourceEdit.Value, " `t`r`n")

    if (source = "")
        return

    ; One active HTTP request at a time. PollTranslation will queue
    ; the latest editor revision after an older request finishes.
    if (TranslationInProgress)
        return

    revision := TranslateRevision
    sourceLang := GetSourceCode()
    target := GetTargetCode()
    now := A_TickCount

    ; Respect the temporary 429 cooldown.
    if (now < RateLimitUntilTick) {
        remaining := Ceil((RateLimitUntilTick - now) / 1000)
        TranslationReady := false
        PendingChatPaste := false
        PendingChatAutoSend := false
        StatusText.Value := "HTTP 429 - wait " . remaining . " sec"
        return
    }

    ; Keep at least 1 second between started requests.
    if (now < NextRequestAllowedTick) {
        SetTimer(DoTranslate, -Max(10, NextRequestAllowedTick - now))
        return
    }

    url := "https://clients5.google.com/translate_a/t"
        . "?client=dict-chrome-ex"
        . "&sl=" . sourceLang
        . "&tl=" . target
        . "&q=" . UrlEncode(source)

    TranslationInProgress := true
    TranslationReady := false
    NextRequestAllowedTick := A_TickCount + 1000
    StatusText.Value := "Translating..."

    try {
        req := ComObject("WinHttp.WinHttpRequest.5.1")
        req.SetTimeouts(3000, 3000, 5000, 8000)

        ; TRUE is critical: Open/Send no longer wait synchronously
        ; for the remote server, so keyboard and GUI events continue.
        req.Open("GET", url, true)
        req.SetRequestHeader(
            "User-Agent",
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
            . "AppleWebKit/537.36 (KHTML, like Gecko) "
            . "Chrome/155.0.0.0 Safari/537.36"
        )
        req.SetRequestHeader(
            "Accept",
            "application/json, text/plain, */*"
        )
        req.SetRequestHeader(
            "Referer",
            "https://translate.google.com/"
        )

        ActiveTranslationRequest := req
        ActiveTranslationRevision := revision
        ActiveTranslationSource := source
        ActiveTranslationSourceLang := sourceLang
        ActiveTranslationTarget := target

        req.Send()
        SetTimer(PollTranslation, -50)

    } catch as err {
        ActiveTranslationRequest := 0
        TranslationInProgress := false

        if (revision != TranslateRevision) {
            idleMs := A_TickCount - LastInputChangeTick
            waitMs := Max(50, 350 - idleMs)
            SetTimer(DoTranslate, -waitMs)
            return
        }

        TranslationReady := false
        PendingChatPaste := false
        PendingChatAutoSend := false
        StatusText.Value := "Translation failed: " . err.Message
    }
}

PollTranslation() {
    global TranslateRevision, TranslationReady
    global TranslationInProgress, PendingChatPaste, PendingChatAutoSend
    global PendingChatRevision
    global ResultEdit, StatusText
    global LastTranslatedSource, LastTranslatedSourceLang
    global LastTranslatedTarget
    global NextRequestAllowedTick, RateLimitUntilTick
    global ActiveTranslationRequest, ActiveTranslationRevision
    global ActiveTranslationSource, ActiveTranslationSourceLang
    global ActiveTranslationTarget, LastInputChangeTick

    if (!TranslationInProgress || !IsObject(ActiveTranslationRequest))
        return

    req := ActiveTranslationRequest
    revision := ActiveTranslationRevision
    source := ActiveTranslationSource
    sourceLang := ActiveTranslationSourceLang
    target := ActiveTranslationTarget

    try {
        ; Zero-second wait is a non-blocking readiness check. If the
        ; response is not ready, return to the GUI and check again later.
        if (!req.WaitForResponse(0)) {
            SetTimer(PollTranslation, -50)
            return
        }

        status := req.Status
        response := req.ResponseText

        ActiveTranslationRequest := 0
        TranslationInProgress := false

        if (status = 429) {
            RateLimitUntilTick := A_TickCount + 60000
            NextRequestAllowedTick := RateLimitUntilTick
            TranslationReady := false
            PendingChatPaste := false
            PendingChatAutoSend := false

            StatusText.Value := "HTTP 429 - wait 60 sec"
            return
        }

        if (status != 200) {
            throw Error(
                "HTTP " . status . ": "
                . SubStr(response, 1, 100)
            )
        }

        translated := ParseGoogleTranslation(response, source)
        detectedSourceCode := ParseGoogleDetectedSource(response)

        ; A response for old text must never overwrite newer input.
        if (revision != TranslateRevision) {
            ; Respect the latest typing pause even when the old request
            ; finishes after the current input's debounce timer fired.
            idleMs := A_TickCount - LastInputChangeTick
            waitMs := Max(50, 350 - idleMs)
            SetTimer(DoTranslate, -waitMs)
            return
        }

        if (translated = "") {
            debugPath := A_Temp . "\QuickTranslator_DebugResponse.txt"
            try FileDelete(debugPath)
            FileAppend(
                "HTTP Status: " . status . "`n"
                . "Selected source: " . sourceLang . "`n"
                . "Target: " . target . "`n"
                . "Response length: " . StrLen(response) . "`n"
                . "Response body:`n" . response,
                debugPath,
                "UTF-8"
            )
            throw Error(
                "No translation found; response saved to " . debugPath
            )
        }

        ResultEdit.Value := translated
        LastTranslatedSource := source
        LastTranslatedSourceLang := sourceLang
        LastTranslatedTarget := target
        TranslationReady := true

        if (PendingChatPaste && PendingChatRevision = revision) {
            PendingChatPaste := false
            StatusText.Value := "Translation ready - opening Roblox chat"
            SetTimer(PerformRobloxChatPaste, -50)
        } else if (sourceLang = "auto") {
            ; Some compact endpoint responses contain only the translated
            ; string and omit language metadata. Prefer server metadata, then
            ; use only high-confidence script checks, then request a fallback.
            if (detectedSourceCode = "")
                detectedSourceCode := DetectSourceByScript(source)

            if (detectedSourceCode != "") {
                detectedName := LanguageNameFromCode(detectedSourceCode)
                StatusText.Value := "Detected " . detectedName . " - translation ready"
            } else {
                StatusText.Value := "Translation ready - checking source language..."
                StartFallbackLanguageDetection(source, target, revision)
            }
        } else {
            StatusText.Value := "Translation ready - press Enter to paste"
        }

    } catch as err {
        ActiveTranslationRequest := 0
        TranslationInProgress := false

        ; Ignore failures from an obsolete request. Retry only the latest text.
        if (revision != TranslateRevision) {
            idleMs := A_TickCount - LastInputChangeTick
            waitMs := Max(50, 350 - idleMs)
            SetTimer(DoTranslate, -waitMs)
            return
        }

        TranslationReady := false
        PendingChatPaste := false
        PendingChatAutoSend := false
        StatusText.Value := "Translation failed: " . err.Message
    }
}


; ============================================================
; DYNAMIC STATUS MESSAGE LAYOUT
; ============================================================

StatusLayoutMonitor() {
    global StatusText, LastRenderedStatusText, StatusDisplayHeight, StatusDisplayWidth
    global MainGui, WindowWidth, WindowHeight, TranslatorFaded, TranslatorMinimized

    if (TranslatorMinimized)
        return

    try {
        currentText := StatusText.Value
    } catch {
        return
    }

    guiW := WindowWidth
    guiH := WindowHeight
    try MainGui.GetClientPos(&guiX, &guiY, &guiW, &guiH)
    availableWidth := Max(180, guiW - 24)

    ; Size to the widest original paragraph, not a pre-wrapped approximation.
    ; That keeps ordinary sentences on one line until the window width is used.
    naturalWidth := 52
    paragraphs := StrSplit(StrReplace(currentText, "`r", ""), "`n")
    for _, paragraph in paragraphs
        naturalWidth := Max(naturalWidth, EstimateStatusTextWidth(paragraph) + 18)

    desiredWidth := Min(availableWidth, naturalWidth)
    if (desiredWidth < 52)
        desiredWidth := 52

    ; Wrap only for height estimation; the actual StatusText.Value remains the
    ; original sentence so native word-wrapping and Ctrl+C preserve its content.
    wrapWidth := Max(80, desiredWidth - 18)
    wrappedForMeasure := WrapStatusMessage(currentText, wrapWidth)
    lines := StrSplit(wrappedForMeasure, "`n")
    desiredHeight := Max(20, lines.Length * 18 + 2)
    ; At most four display lines; this is enough for long status/error messages
    ; without letting the status control collide with editor/buttons at minimum size.
    desiredHeight := Min(80, desiredHeight)

    layoutChanged := (desiredHeight != StatusDisplayHeight
        || desiredWidth != StatusDisplayWidth)
    LastRenderedStatusText := currentText
    StatusDisplayHeight := desiredHeight
    StatusDisplayWidth := desiredWidth

    if (layoutChanged && !TranslatorFaded) {
        try LayoutControls(guiW, guiH)
    }
}

WrapStatusMessage(message, maxWidth) {
    output := ""
    paragraphs := StrSplit(StrReplace(message, "`r", ""), "`n")

    for paraIndex, paragraph in paragraphs {
        line := ""
        words := StrSplit(paragraph, " ")

        for _, word in words {
            if (word = "")
                continue

            candidate := (line = "") ? word : line . " " . word
            if (line != "" && EstimateStatusTextWidth(candidate) > maxWidth) {
                output .= line . "`n"
                line := ""
            }

            if (EstimateStatusTextWidth(word) <= maxWidth) {
                if (line != "")
                    line .= " "
                line .= word
            } else {
                ; A single long token (e.g. a Windows path) wraps by characters;
                ; ordinary text continues to wrap at word boundaries.
                for _, ch in StrSplit(word) {
                    candidateChar := line . ch
                    if (line != "" && EstimateStatusTextWidth(candidateChar) > maxWidth) {
                        output .= line . "`n"
                        line := ""
                    }
                    line .= ch
                }
            }
        }

        output .= line
        if (paraIndex < paragraphs.Length)
            output .= "`n"
    }
    return output
}

EstimateStatusTextWidth(text) {
    width := 0
    for _, ch in StrSplit(text) {
        cp := Ord(ch)
        if (ch = "`n" || ch = "`r")
            continue
        else if (ch = " ")
            width += 5
        else if (cp >= 0x1100)
            width += 12
        else if (InStr("il.,:;!'|", ch))
            width += 4
        else if (InStr("MW@%&", ch))
            width += 10
        else
            width += 8
    }
    return width
}


; ============================================================
; GOOGLE RESPONSE PARSING
; ============================================================

NormalizeGoogleResponse(response) {
    ; WinHTTP/Google responses may contain a BOM or an anti-XSSI prefix.
    response := StrReplace(response, Chr(0xFEFF), "")
    response := Trim(response, " `t`r`n")
    response := RegExReplace(response, "^\)\]\}'\s*,?\s*")
    response := RegExReplace(response, "^while\s*\(\s*1\s*\)\s*;\s*")
    return Trim(response, " `t`r`n")
}

ParseGoogleTranslation(response, sourceText := "") {
    response := NormalizeGoogleResponse(response)
    if (response = "")
        return ""

    sourceCandidate := ""
    sourceTrimmed := Trim(sourceText, " `t`r`n")

    ; JSON encoded as a single string. Some gateways wrap the JSON payload
    ; once more as a JSON string, so parse that inner array/object too.
    if (RegExMatch(response, '^"((?:\\.|[^"\\])*)"\s*$', &match)) {
        value := JsonUnescape(match[1])
        if (value != "") {
            trimmedValue := Trim(value)
            first := SubStr(trimmedValue, 1, 1)
            last := SubStr(trimmedValue, -1)
            if ((first = "[" && last = "]") || (first = "{" && last = "}"))
                return ParseGoogleTranslation(value, sourceText)
            if (sourceTrimmed = "" || Trim(value, " `t`r`n") != sourceTrimmed)
                return value
            sourceCandidate := value
        }
    }

    ; The Chrome dictionary endpoint often returns a simple one-item array.
    if (RegExMatch(response, '^\[\s*"((?:\\.|[^"\\])*)"', &match)) {
        value := JsonUnescape(match[1])
        if (value != "") {
            if (sourceTrimmed = "" || Trim(value, " `t`r`n") != sourceTrimmed)
                return value
            sourceCandidate := value
        }
    }

    ; Object-style responses from multiple Translate endpoints. Prefer explicit
    ; translation keys, not generic metadata fields.
    for _, keyPattern in [
        'i)"translatedText"\s*:\s*"((?:\\.|[^"\\])*)"',
        'i)"translated_text"\s*:\s*"((?:\\.|[^"\\])*)"',
        'i)"translationText"\s*:\s*"((?:\\.|[^"\\])*)"',
        'i)"translationResult"\s*:\s*"((?:\\.|[^"\\])*)"',
        'i)"translation_result"\s*:\s*"((?:\\.|[^"\\])*)"',
        'i)"translatedContent"\s*:\s*"((?:\\.|[^"\\])*)"',
        'i)"translated_content"\s*:\s*"((?:\\.|[^"\\])*)"',
        'i)"translation"\s*:\s*"((?:\\.|[^"\\])*)"',
        'i)"translated"\s*:\s*"((?:\\.|[^"\\])*)"',
        'i)"result"\s*:\s*"((?:\\.|[^"\\])*)"',
        'i)"output"\s*:\s*"((?:\\.|[^"\\])*)"'
    ] {
        if (RegExMatch(response, keyPattern, &match)) {
            value := JsonUnescape(match[1])
            if (value != "") {
                if (sourceTrimmed = "" || Trim(value, " `t`r`n") != sourceTrimmed)
                    return value
                sourceCandidate := value
            }
        }
    }

    ; Chrome dictionary endpoint may split translations into several "trans"
    ; sentence segments. Concatenate all segments, preserving JSON spaces.
    pattern := 'i)"trans"\s*:\s*"((?:\\.|[^"\\])*)"'
    pos := 1
    output := ""
    while RegExMatch(response, pattern, &match, pos) {
        output .= JsonUnescape(match[1])
        pos := match.Pos + match.Len
    }
    if (output != "") {
        if (sourceTrimmed = "" || Trim(output, " `t`r`n") != sourceTrimmed)
            return output
        sourceCandidate := output
    }

    ; Legacy translate_a/single nested arrays have translation first in each
    ; [translated, source, ...] tuple. Collect all translated tuple heads.
    if (RegExMatch(response, '^\s*\[\s*\[\s*\[', &legacyStart)) {
        pattern := '\[\s*"((?:\\.|[^"\\])*)"\s*,\s*"(?:\\.|[^"\\])*"'
        pos := legacyStart.Pos
        output := ""
        while RegExMatch(response, pattern, &match, pos) {
            output .= JsonUnescape(match[1])
            pos := match.Pos + match.Len
        }
        if (output != "") {
            if (sourceTrimmed = "" || Trim(output, " `t`r`n") != sourceTrimmed)
                return output
            sourceCandidate := output
        }
    }

    ; Some lightweight APIs use a "text" property for the translation even
    ; when a separate "source" language-code property is also present.
    if (RegExMatch(response, 'i)"text"\s*:\s*"((?:\\.|[^"\\])*)"', &match)) {
        value := JsonUnescape(match[1])
        if (value != "") {
            if (sourceTrimmed = "" || Trim(value, " `t`r`n") != sourceTrimmed)
                return value
            sourceCandidate := value
        }
    }

    ; Last-resort JSON scanner: ignore object keys, empty strings, booleans,
    ; language-code metadata, and the original input text. This handles wrappers
    ; which nest the translated text under an unexpected property name.
    firstChar := SubStr(response, 1, 1)
    if (firstChar = "[" || firstChar = "{") {
        pos := 1
        while RegExMatch(response, '"((?:\\.|[^"\\])*)"', &match, pos) {
            nextPos := match.Pos + match.Len
            tail := SubStr(response, nextPos)
            if (RegExMatch(tail, "^\s*:")) {
                pos := nextPos
                continue
            }

            value := JsonUnescape(match[1])
            pos := nextPos
            if (Trim(value, " `t`r`n") = "")
                continue
            if (RegExMatch(value, "i)^(null|true|false|auto|und|[a-z]{2,3}(?:-[a-z]{2})?)$"))
                continue
            if (sourceTrimmed != "" && Trim(value, " `t`r`n") = sourceTrimmed) {
                sourceCandidate := value
                continue
            }
            if (RegExMatch(value, "i)^(dict-chrome-ex|gtx|translate_a|sentences|ld_result)$"))
                continue
            return value
        }
    }

    ; An identical translation is valid for names, short terms and same-script
    ; words, but only return it after looking for a more specific output value.
    if (sourceCandidate != "")
        return sourceCandidate

    ; Last-resort plain-text body. Never display an HTML error page or an
    ; unrecognized JSON object/array as if it were a translated sentence.
    if (firstChar != "{" && firstChar != "[" && firstChar != "<"
        && !RegExMatch(response, 'i)^(?:error|failed|unauthorized)\b'))
        return response

    return ""
}


; The dict-chrome-ex response contains the server's detected source code
; in ld_result.srclangs[0] and/or the top-level src field. Read this only
; for reporting/verification; keep SourceDrop's selected value as "auto"
; for cache matching and later requests.
ParseGoogleDetectedSource(response) {
    response := NormalizeGoogleResponse(response)
    ; Chrome Dictionary endpoint JSON object:
    ; {"src":"fr", "ld_result":{"srclangs":["fr"], ...}}
    if (RegExMatch(
        response,
        'i)"srclangs"\s*:\s*\[\s*"([^"\\]+)"',
        &match
    )) {
        code := match[1]
        if (code != "auto" && code != "und")
            return code
    }

    if (RegExMatch(response, 'i)"src"\s*:\s*"([^"\\]+)"', &match)) {
        code := match[1]
        if (code != "auto" && code != "und")
            return code
    }

    ; Legacy translate_a/single layout:
    ; [[["Bonjour","Hello",null,null,1]],null,"fr",...]
    ; Close both nested arrays before looking for the top-level source code.
    if (RegExMatch(
        response,
        'is)^\s*\[\s*\[\s*\[.*?\]\s*\]\s*,\s*null\s*,\s*"([A-Za-z-]+)"',
        &match
    )) {
        code := match[1]
        if (code != "auto" && code != "und")
            return code
    }

    ; Alternate legacy responses can put the language after a nested array.
    if (RegExMatch(
        response,
        'is)^\s*\[.*?\]\s*,\s*null\s*,\s*"([A-Za-z-]+)"',
        &match
    )) {
        code := match[1]
        if (code != "auto" && code != "und")
            return code
    }

    return ""
}

; Return a language only when its writing system is a strong indicator.
; Latin-script languages are left to Google's server-side detection.
DetectSourceByScript(source) {
    if (RegExMatch(source, "[가-힣ㄱ-ㅎㅏ-ㅣ]"))
        return "ko"

    if (RegExMatch(source, "[ぁ-ゖァ-ヺー]"))
        return "ja"

    if (RegExMatch(source, "[ก-๛]"))
        return "th"

    if (RegExMatch(source, "[А-Яа-яЁё]"))
        return "ru"

    ; Traditional Chinese markers. If no marker is present, leave Han-only
    ; text ambiguous because it can be Chinese or Japanese Kanji.
    if (RegExMatch(source, "[體學習國與為這個們會說話聽書買賣車開關門雲龍臺灣後發現時點廣東傳統]"))
        return "zh-TW"

    if (RegExMatch(source, "[这国为后发里们会说话听书买卖车开关门云龙台湾学习与时点广东传统]"))
        return "zh-CN"

    return ""
}

StartFallbackLanguageDetection(source, target, revision) {
    global ActiveDetectionRequest, ActiveDetectionRevision
    global ActiveDetectionSource, ActiveDetectionTarget
    global SourceEdit, StatusText, TranslateRevision

    ; Discard any older detection attempt. It must not overwrite the current
    ; message's status after the user has changed the source text.
    if (IsObject(ActiveDetectionRequest)) {
        try ActiveDetectionRequest.Abort()
    }
    ActiveDetectionRequest := 0

    try {
        req := ComObject("WinHttp.WinHttpRequest.5.1")
        req.SetTimeouts(2500, 2500, 4000, 6000)

        ; Separate fallback endpoint used only when the main response lacks
        ; source metadata. Translation itself is already complete and visible.
        url := "https://translate.google.com/translate_a/single"
            . "?client=gtx&sl=auto&tl=" . target
            . "&dt=t&q=" . UrlEncode(source)

        req.Open("GET", url, true)
        req.SetRequestHeader(
            "User-Agent",
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
            . "AppleWebKit/537.36 (KHTML, like Gecko) "
            . "Chrome/155.0.0.0 Safari/537.36"
        )
        req.SetRequestHeader("Accept", "application/json, text/plain, */*")
        req.SetRequestHeader("Referer", "https://translate.google.com/")

        ActiveDetectionRequest := req
        ActiveDetectionRevision := revision
        ActiveDetectionSource := source
        ActiveDetectionTarget := target

        req.Send()
        SetTimer(PollFallbackLanguageDetection, -50)
    } catch {
        ActiveDetectionRequest := 0
        if (revision = TranslateRevision
            && Trim(SourceEdit.Value, " `t`r`n") = source) {
            StatusText.Value := "Translation ready - source language unavailable"
        }
    }
}

PollFallbackLanguageDetection() {
    global ActiveDetectionRequest, ActiveDetectionRevision
    global ActiveDetectionSource, ActiveDetectionTarget
    global TranslateRevision, SourceEdit, StatusText

    if (!IsObject(ActiveDetectionRequest))
        return

    req := ActiveDetectionRequest
    revision := ActiveDetectionRevision
    source := ActiveDetectionSource
    target := ActiveDetectionTarget

    try {
        if (!req.WaitForResponse(0)) {
            SetTimer(PollFallbackLanguageDetection, -50)
            return
        }

        httpStatus := req.Status
        response := req.ResponseText
        ActiveDetectionRequest := 0

        if (httpStatus = 200)
            detectedCode := ParseGoogleDetectedSource(response)
        else
            detectedCode := ""

        ; Do not let a previous sentence or a later fixed source language be
        ; overwritten by this delayed fallback result.
        if (revision != TranslateRevision
            || GetSourceCode() != "auto"
            || Trim(SourceEdit.Value, " `t`r`n") != source
            || GetTargetCode() != target)
            return

        if (detectedCode != "") {
            detectedName := LanguageNameFromCode(detectedCode)
            StatusText.Value := "Detected " . detectedName . " - translation ready"
        } else {
            StatusText.Value := "Translation ready - source language unavailable"
        }
    } catch {
        ActiveDetectionRequest := 0
        if (revision = TranslateRevision
            && GetSourceCode() = "auto"
            && Trim(SourceEdit.Value, " `t`r`n") = source
            && GetTargetCode() = target) {
            StatusText.Value := "Translation ready - source language unavailable"
        }
    }
}

LanguageNameFromCode(code) {
    code := StrLower(code)
    switch code {
        case "ko": return "Korean"
        case "en": return "English"
        case "ja": return "Japanese"
        case "zh", "zh-cn", "cmn": return "Chinese (Simplified)"
        case "zh-tw", "zh-hant": return "Chinese (Traditional)"
        case "es": return "Spanish"
        case "fr": return "French"
        case "de": return "German"
        case "pt", "pt-br", "pt-pt": return "Portuguese"
        case "it": return "Italian"
        case "ru": return "Russian"
        case "th": return "Thai"
        case "vi": return "Vietnamese"
        case "und": return "Undetermined"
        default: return code
    }
}

JsonUnescape(value) {
    slash := Chr(92)
    quote := Chr(34)

    output := ""
    i := 1
    length := StrLen(value)

    while (i <= length) {
        ch := SubStr(value, i, 1)

        if (ch != slash) {
            output .= ch
            i += 1
            continue
        }

        esc := SubStr(value, i + 1, 1)

        if (esc = "") {
            output .= slash
            break
        }

        if (esc = quote) {
            output .= quote
            i += 2
        } else if (esc = slash) {
            output .= slash
            i += 2
        } else if (esc = "/") {
            output .= "/"
            i += 2
        } else if (esc = "n") {
            output .= "`n"
            i += 2
        } else if (esc = "r") {
            output .= "`r"
            i += 2
        } else if (esc = "t") {
            output .= "`t"
            i += 2
        } else if (esc = "b") {
            output .= Chr(8)
            i += 2
        } else if (esc = "f") {
            output .= Chr(12)
            i += 2
        } else if (esc = "u") {
            hex := SubStr(value, i + 2, 4)

            if (RegExMatch(hex, "i)^[0-9a-f]{4}$")) {
                output .= Chr(("0x" . hex) + 0)
                i += 6
            } else {
                output .= slash . esc
                i += 2
            }
        } else {
            output .= slash . esc
            i += 2
        }
    }

    return output
}

UrlEncode(str) {
    buf := Buffer(
        StrPut(str, "UTF-8")
    )

    size := StrPut(
        str,
        buf,
        "UTF-8"
    ) - 1

    out := ""

    Loop size {
        b := NumGet(
            buf,
            A_Index - 1,
            "UChar"
        )

        if ((b >= 0x41 && b <= 0x5A)
         || (b >= 0x61 && b <= 0x7A)
         || (b >= 0x30 && b <= 0x39)
         || b = 0x2D
         || b = 0x2E
         || b = 0x5F
         || b = 0x7E) {

            out .= Chr(b)

        } else {
            out .= "%" . Format("{:02X}", b)
        }
    }

    return out
}


; ============================================================
; TOP-ROW UTILITY BUTTONS
; ============================================================

SendOCRHotkey(*) {
    global StatusText, MainGui, OverlayZMode, OCRShortcutSend, LastTranslatorActivityTick
    global OCRRestoreZMode, OCRRestoreWindowPending

    ; IMPORTANT:
    ; Do NOT activate Roblox before sending this shortcut. The configured default
    ; Win+Shift+T includes a real Shift keystroke and can toggle Roblox Shift Lock
    ; if Roblox is the foreground recipient. Keep the translator as the foreground
    ; window instead; PowerToys/Text Extractor receives its registered global hotkey
    ; regardless of which ordinary application is foreground.
    try {
        ; Treat starting OCR as activity so the idle countdown begins afresh.
        LastTranslatorActivityTick := A_TickCount

        ; Restart only this OCR button's clipboard watch. Clipboard monitoring is
        ; intentionally inactive at all other times, so normal copying is unaffected.
        StopOCRClipboardCapture(false)

        ; Remember the translator's stacking mode before allowing the OCR selection
        ; overlay to cover it. The translation GUI can otherwise remain behind Roblox
        ; after the selector closes. Restore it when clipboard capture completes.
        OCRRestoreZMode := OverlayZMode
        if (OCRRestoreZMode != "topmost" && OCRRestoreZMode != "normal")
            OCRRestoreZMode := "normal"
        OCRRestoreWindowPending := true

        ; Let the OCR selection overlay appear above the translator, without
        ; activating or sending keystrokes to a Roblox client.
        try WinSetAlwaysOnTop(false, "ahk_id " . MainGui.Hwnd)
        OverlayZMode := "normal"

        if (WinGetMinMax("ahk_id " . MainGui.Hwnd) = -1)
            WinRestore("ahk_id " . MainGui.Hwnd)

        WinActivate("ahk_id " . MainGui.Hwnd)
        if (!WinWaitActive("ahk_id " . MainGui.Hwnd, , 2)) {
            RestoreTranslatorAfterOCR()
            StatusText.Value := "OCR: translator could not take focus; shortcut not sent"
            return
        }

        ; Begin watching BEFORE sending the global hotkey, so a fast OCR copy
        ; cannot be missed. A new clipboard sequence plus stable non-empty text
        ; is required before replacing the source editor.
        BeginOCRClipboardCapture()
        SendEvent(OCRShortcutSend)
        StatusText.Value := "OCR: select a region; waiting for recognized text..."
    } catch as err {
        StopOCRClipboardCapture(false)
        RestoreTranslatorAfterOCR()
        StatusText.Value := "OCR shortcut failed: " . err.Message
    }
}

; Re-show the translator after the OCR selection overlay closes. This is distinct
; from idle/title-strip restoration: OCR temporarily changes Z-order, not idle state.
RestoreTranslatorAfterOCR() {
    global MainGui, OCRRestoreZMode, OCRRestoreWindowPending, OverlayZMode
    global TranslatorVisible, TranslatorFaded, TranslatorMinimized
    global ActiveWindowOpacityPercent

    if (!OCRRestoreWindowPending)
        return

    OCRRestoreWindowPending := false

    try {
        ; OCR can only be launched from the full translator. If stale flags say
        ; otherwise, reconcile them and make the existing window visible again.
        if (TranslatorFaded)
            RestoreTranslatorFromIdleFade()

        if (DllCall("user32\IsIconic", "Ptr", MainGui.Hwnd, "Int"))
            WinRestore("ahk_id " . MainGui.Hwnd)

        if (!DllCall("user32\IsWindowVisible", "Ptr", MainGui.Hwnd, "Int"))
            MainGui.Show("NA")

        TranslatorVisible := true
        TranslatorMinimized := false
        SetTranslatorOpacityPercent(ActiveWindowOpacityPercent)

        ; If Roblox or the translator is again foreground, topmost is the usual
        ; working mode. Otherwise restore the previous mode without forcing the
        ; translator above unrelated applications.
        foreground := DllCall("user32\GetForegroundWindow", "Ptr")
        foregroundRoot := GetRootWindow(foreground)
        restoreMode := OCRRestoreZMode
        if (IsRobloxWindow(foregroundRoot) || IsOwnProcessWindow(foregroundRoot))
            restoreMode := "topmost"

        ; Ensure SetTranslatorZMode sees the temporary normal mode used by OCR.
        OverlayZMode := "normal"
        SetTranslatorZMode(restoreMode)
        WinActivate("ahk_id " . MainGui.Hwnd)
    } catch {
        ; Best-effort recovery: do not leave the main translation window hidden.
        try MainGui.Show("NA")
        try SetTranslatorOpacityPercent(ActiveWindowOpacityPercent)
        TranslatorVisible := true
        TranslatorMinimized := false
        OverlayZMode := "normal"
    }
}

BeginOCRClipboardCapture() {
    global OCRCaptureActive, OCRCaptureStartSequence
    global OCRCaptureDeadlineTick, OCRCaptureCandidateText
    global OCRCaptureStablePolls, OCRClipboardWaitSeconds, StatusText
    global LastTranslatorActivityTick

    try {
        OCRCaptureStartSequence := DllCall("user32\GetClipboardSequenceNumber", "UInt")
    } catch {
        OCRCaptureStartSequence := 0
    }

    OCRCaptureCandidateText := ""
    OCRCaptureStablePolls := 0
    OCRCaptureDeadlineTick := A_TickCount + (OCRClipboardWaitSeconds * 1000)
    OCRCaptureActive := true
    LastTranslatorActivityTick := A_TickCount
    SetTimer(PollOCRClipboardForResult, 100)
    StatusText.Value := "OCR: waiting for a new text result..."
}

PollOCRClipboardForResult() {
    global OCRCaptureActive, OCRCaptureStartSequence
    global OCRCaptureDeadlineTick, OCRCaptureCandidateText
    global OCRCaptureStablePolls, OCRClipboardStablePollsRequired
    global OCRClipboardWaitSeconds, StatusText, SourceEdit

    if (!OCRCaptureActive) {
        SetTimer(PollOCRClipboardForResult, 0)
        return
    }

    if (A_TickCount >= OCRCaptureDeadlineTick) {
        StopOCRClipboardCapture(false)
        RestoreTranslatorAfterOCR()
        StatusText.Value := "OCR: no new recognized text copied within "
            . OCRClipboardWaitSeconds . " seconds"
        return
    }

    try {
        sequenceNow := DllCall("user32\GetClipboardSequenceNumber", "UInt")
        ; Do not accept the old clipboard contents from before OCR was launched.
        if (sequenceNow = OCRCaptureStartSequence)
            return

        candidate := A_Clipboard
    } catch {
        ; The clipboard may be temporarily locked while the OCR app writes it.
        return
    }

    if (Trim(candidate, " `t`r`n") = "") {
        OCRCaptureCandidateText := ""
        OCRCaptureStablePolls := 0
        return
    }

    ; Wait for the text to stop changing for several polls. This avoids reading a
    ; partial clipboard write or a transient format conversion by the OCR app.
    if (candidate = OCRCaptureCandidateText) {
        OCRCaptureStablePolls += 1
    } else {
        OCRCaptureCandidateText := candidate
        OCRCaptureStablePolls := 1
    }

    if (OCRCaptureStablePolls < OCRClipboardStablePollsRequired)
        return

    resultText := OCRCaptureCandidateText

    ; Stop clipboard polling now, but restore the main translator before touching
    ; SourceEdit. OCR's fullscreen overlay can have caused the translator to drop
    ; behind Roblox; the user should see it again when the OCR result is ready.
    SetTimer(PollOCRClipboardForResult, 0)
    RestoreTranslatorAfterOCR()

    ; Fill the source editor, put focus there, and invoke the same debounce/translation
    ; path as typed text. Do not simulate Ctrl+V, so OCR text is not pasted into Roblox.
    SourceEdit.Value := resultText
    SourceEdit.Focus()
    InputChanged()
    StatusText.Value := "OCR text inserted into source; translation queued"
    StopOCRClipboardCapture(false)
}

StopOCRClipboardCapture(clearStatus := false) {
    global OCRCaptureActive, OCRCaptureCandidateText, OCRCaptureStablePolls
    global StatusText, LastTranslatorActivityTick

    OCRCaptureActive := false
    ; After success, timeout or cancellation, restart the idle countdown from
    ; this moment rather than inheriting time elapsed during OCR recognition.
    LastTranslatorActivityTick := A_TickCount
    OCRCaptureCandidateText := ""
    OCRCaptureStablePolls := 0
    SetTimer(PollOCRClipboardForResult, 0)

    if (clearStatus) {
        RestoreTranslatorAfterOCR()
        StatusText.Value := "OCR capture cancelled"
    }
}

PasteClipboardToInput(*) {
    global SourceEdit, StatusText

    ; Insert the current clipboard text without changing the clipboard.
    pastedText := A_Clipboard
    if (pastedText = "") {
        StatusText.Value := "Paste to Input: clipboard is empty"
        return
    }

    SourceEdit.Value := pastedText
    SourceEdit.Focus()

    ; Programmatic Value assignment may not raise the edit Change event,
    ; so explicitly run the same debounce/translation path as typed input.
    InputChanged()
}


; ============================================================
; ENTER / PASTE TO CHAT
; ============================================================

OpenSourceEmojiPicker(*) {
    global SourceEdit, StatusText

    ; Open the Windows emoji picker with SourceEdit as the real input target.
    ; Preserve the current selection/caret and place the mouse at the caret so
    ; Windows positions the picker near the text rather than near the button.
    try {
        editHwnd := SourceEdit.Hwnd

        selStartBuf := Buffer(4, 0)
        selEndBuf := Buffer(4, 0)
        DllCall("user32\SendMessageW", "Ptr", editHwnd, "UInt", 0x00B0,
            "Ptr", selStartBuf.Ptr, "Ptr", selEndBuf.Ptr, "Ptr") ; EM_GETSEL
        selStart := NumGet(selStartBuf, 0, "UInt")
        selEnd := NumGet(selEndBuf, 0, "UInt")

        ; Remember the user's pointer position before temporarily positioning it.
        MouseGetPos(&oldMouseX, &oldMouseY)

        SourceEdit.Focus()
        DllCall("user32\SendMessageW", "Ptr", editHwnd, "UInt", 0x00B1,
            "Ptr", selStart, "Ptr", selEnd, "Ptr") ; EM_SETSEL

        ; GetCaretPos returns coordinates relative to the edit's client area.
        caret := Buffer(8, 0)
        if DllCall("user32\GetCaretPos", "Ptr", caret.Ptr, "Int") {
            caretX := NumGet(caret, 0, "Int")
            caretY := NumGet(caret, 4, "Int")
            point := Buffer(8, 0)
            NumPut("Int", caretX, point, 0)
            NumPut("Int", caretY, point, 4)
            if DllCall("user32\ClientToScreen", "Ptr", editHwnd, "Ptr", point.Ptr, "Int") {
                pickerX := NumGet(point, 0, "Int")
                pickerY := NumGet(point, 4, "Int")
                ; Keep the pointer inside the source editor, near the caret.
                MouseMove(pickerX, pickerY, 0)
            }
        }

        ; Reassert focus and selection immediately before opening the picker.
        SourceEdit.Focus()
        DllCall("user32\SendMessageW", "Ptr", editHwnd, "UInt", 0x00B1,
            "Ptr", selStart, "Ptr", selEnd, "Ptr") ; EM_SETSEL
        Sleep(120)
        SendEvent("#.")
        Sleep(250)
        MouseMove(oldMouseX, oldMouseY, 0)
        StatusText.Value := "Emoji picker opened at source caret"
    } catch as err {
        try MouseMove(oldMouseX, oldMouseY, 0)
        StatusText.Value := "Could not open source emoji picker: " . err.Message
    }
}

OpenRobloxChatEmojiPicker(*) {
    global TargetRobloxHwnd, StatusText, MainGui, OverlayZMode, ChatPasteInProgress

    ; Reuse the same remembered Roblox target used by Paste to Chat.
    if (!TargetRobloxHwnd || !IsRobloxWindow(TargetRobloxHwnd))
        TargetRobloxHwnd := FindAnyRobloxWindow()

    if (!TargetRobloxHwnd || !IsRobloxWindow(TargetRobloxHwnd)) {
        StatusText.Value := "Roblox window not found"
        return
    }

    ChatPasteInProgress := true
    try {
        if (WinGetMinMax("ahk_id " . TargetRobloxHwnd) = -1)
            WinRestore("ahk_id " . TargetRobloxHwnd)

        WinSetAlwaysOnTop(true, "ahk_id " . MainGui.Hwnd)
        OverlayZMode := "topmost"

        StatusText.Value := "Activating Roblox chat..."
        WinActivate("ahk_id " . TargetRobloxHwnd)
        if (!WinWaitActive("ahk_id " . TargetRobloxHwnd, , 3)
            || !IsTargetRobloxForeground(TargetRobloxHwnd)) {
            StatusText.Value := "Roblox did not activate; emoji picker cancelled"
            return
        }

        Sleep(180)
        if (!IsTargetRobloxForeground(TargetRobloxHwnd)) {
            StatusText.Value := "Roblox lost focus; emoji picker cancelled"
            return
        }

        ; Slash opens Roblox chat. Do not clear, paste, or send a message.
        SendEvent("/")
        Sleep(300)
        if (!IsTargetRobloxForeground(TargetRobloxHwnd)) {
            StatusText.Value := "Roblox lost focus; emoji picker cancelled"
            return
        }

        ; Open the Windows emoji picker while Roblox chat retains keyboard focus.
        SendEvent("#.")
        StatusText.Value := "Choose an emoji; press Enter yourself to send"
    } catch as err {
        StatusText.Value := "Could not open chat emoji picker: " . err.Message
    } finally {
        ChatPasteInProgress := false
    }
}

PasteChatButtonClick(*) {
    ; The button performs the full send workflow, including Enter in Roblox.
    SendTranslationToRobloxChat(true)
}

SendTranslationToRobloxChat(autoSend := false) {
    global SourceEdit, ResultEdit, StatusText
    global TranslationReady, TranslationInProgress
    global PendingChatPaste, PendingChatRevision, PendingChatAutoSend
    global LastTranslatedSource
    global LastTranslatedSourceLang
    global LastTranslatedTarget
    global TargetRobloxHwnd

    PendingChatAutoSend := autoSend
    source := Trim(SourceEdit.Value, " `t`r`n")

    if (source = "") {
        PendingChatPaste := false
        PendingChatAutoSend := false
        StatusText.Value := "Enter text to translate"
        return
    }

    ; Find a Roblox target if the currently remembered window is gone.
    if (!TargetRobloxHwnd
        || !IsRobloxWindow(TargetRobloxHwnd)) {

        TargetRobloxHwnd := FindAnyRobloxWindow()
    }

    if (!TargetRobloxHwnd
        || !IsRobloxWindow(TargetRobloxHwnd)) {

        PendingChatPaste := false
        PendingChatAutoSend := false
        StatusText.Value := "Roblox window not found"
        return
    }

    ; If the current result matches current input and languages,
    ; go directly to the established paste procedure.
    isCurrent :=
        TranslationReady
        && ResultEdit.Value != ""
        && source = LastTranslatedSource
        && GetSourceCode() = LastTranslatedSourceLang
        && GetTargetCode() = LastTranslatedTarget

    if (isCurrent) {
        PendingChatPaste := false
        SetTimer(PerformRobloxChatPaste, -10)
        return
    }

    ; Translation is not ready yet: queue the desired action.
    PendingChatPaste := true
    PendingChatRevision := TranslateRevision

    StatusText.Value := autoSend
        ? "Translation pending - will paste and send when ready"
        : "Translation pending - will paste when ready"

    ; If a request is already in progress, its completion handler
    ; will process the pending action.
    if (!TranslationInProgress) {
        SetTimer(DoTranslate, 0)
        SetTimer(DoTranslate, -10)
    }
}

TranslatorEnter(*) {
    global MainGui, SourceEdit, StatusText

    focusedControl := ""
    focusedHwnd := 0
    try focusedControl := ControlGetFocus("ahk_id " . MainGui.Hwnd)
    if (focusedControl != "") {
        try focusedHwnd := ControlGetHwnd(
            focusedControl,
            "ahk_id " . MainGui.Hwnd
        )
    }

    ; Identify the source editor by its actual HWND rather than assuming its
    ; class name will always be Edit1. This keeps Enter scoped to the source
    ; field even if controls are added/reordered in a later UI revision.
    if (focusedHwnd = SourceEdit.Hwnd) {
        ; Use the exact same translation/target/paste workflow as the button,
        ; but leave auto-send disabled so Roblox Enter is never sent here.
        SendTranslationToRobloxChat(false)
    } else {
        StatusText.Value := "Enter ignored - focus is not the source input"
    }
}
PerformRobloxChatPaste(*) {
    global SourceEdit, ResultEdit, StatusText
    global TranslationReady, PendingChatAutoSend
    global LastTranslatedSource
    global LastTranslatedSourceLang
    global LastTranslatedTarget
    global TargetRobloxHwnd
    global MainGui, OverlayZMode, ChatPasteInProgress

    ; Auto-send is requested only by the Paste to Chat button, not source Enter.
    autoSend := PendingChatAutoSend
    PendingChatAutoSend := false

    ; Check that the displayed translation matches the current input/settings.
    source := Trim(SourceEdit.Value, " `t`r`n")
    if (!TranslationReady
        || ResultEdit.Value = ""
        || source != LastTranslatedSource
        || GetSourceCode() != LastTranslatedSourceLang
        || GetTargetCode() != LastTranslatedTarget) {
        StatusText.Value := "Translation changed; wait and try again"
        return
    }

    if (!TargetRobloxHwnd || !IsRobloxWindow(TargetRobloxHwnd)) {
        StatusText.Value := "Roblox target not found; nothing pasted"
        return
    }

    ChatPasteInProgress := true
    try {
        ; Restore the target if minimized.
        if (WinGetMinMax("ahk_id " . TargetRobloxHwnd) = -1)
            WinRestore("ahk_id " . TargetRobloxHwnd)

        ; Copy the translation before switching focus.
        A_Clipboard := ResultEdit.Value
        if (!ClipWait(1)) {
            StatusText.Value := "Clipboard copy failed"
            return
        }

        ; Keep the translator topmost throughout the chat handoff.
        ; This avoids a visible hide/reappear blink during activation.
        ; The target Roblox window can still be the foreground recipient.
        WinSetAlwaysOnTop(true, "ahk_id " . MainGui.Hwnd)
        OverlayZMode := "topmost"

        StatusText.Value := "Activating target Roblox..."
        WinActivate("ahk_id " . TargetRobloxHwnd)
        if (!WinWaitActive("ahk_id " . TargetRobloxHwnd, , 3)) {
            StatusText.Value := "Roblox did not activate; paste cancelled"
            return
        }

        ; Verify the true foreground window. Never send Ctrl+V to the translator.
        if (!IsTargetRobloxForeground(TargetRobloxHwnd)) {
            WinActivate("ahk_id " . TargetRobloxHwnd)
            Sleep(200)
            if (!IsTargetRobloxForeground(TargetRobloxHwnd)) {
                StatusText.Value := "Roblox is not foreground; paste cancelled safely"
                return
            }
        }

        Sleep(180)
        if (!IsTargetRobloxForeground(TargetRobloxHwnd)) {
            StatusText.Value := "Roblox lost focus; paste cancelled safely"
            return
        }

        ; Keep the same chat-opening input that worked through the button.
        StatusText.Value := "Opening Roblox chat..."
        SendEvent("/")
        Sleep(300)

        ; Check again before destructive select-all/paste keystrokes.
        if (!IsTargetRobloxForeground(TargetRobloxHwnd)) {
            StatusText.Value := "Roblox lost focus before paste; cancelled safely"
            return
        }

        SendEvent("^a")
        Sleep(100)

        if (!IsTargetRobloxForeground(TargetRobloxHwnd)) {
            StatusText.Value := "Roblox lost focus; paste cancelled safely"
            return
        }

        SendEvent("^v")

        if (autoSend) {
            ; Allow the game UI to receive the paste before sending.
            Sleep(300)

            ; Safety check: never send Enter if Roblox lost foreground focus.
            if (!IsTargetRobloxForeground(TargetRobloxHwnd)) {
                StatusText.Value := "Translation pasted, but Roblox lost focus; Enter not sent"
                return
            }

            SendEvent("{Enter}")
            StatusText.Value := "Translation pasted and sent"
        } else {
            StatusText.Value := "Translation pasted - press Enter in Roblox to send"
        }

    } catch as err {
        StatusText.Value := "Chat paste failed: " . err.Message
    } finally {
        ChatPasteInProgress := false
    }
}

IsTargetRobloxForeground(targetHwnd) {
    if (!targetHwnd || !IsRobloxWindow(targetHwnd))
        return false

    foreground := DllCall("user32\GetForegroundWindow", "Ptr")
    foregroundRoot := GetRootWindow(foreground)
    targetRoot := GetRootWindow(targetHwnd)

    return foregroundRoot = targetRoot
}
ClearText(*) {
    global SourceEdit, ResultEdit, StatusText
    global TranslateRevision, TranslationReady
    global TranslationInProgress, PendingChatPaste, PendingChatAutoSend
    global LastTranslatedSource
    global LastTranslatedSourceLang
    global LastTranslatedTarget

    TranslateRevision += 1
    TranslationReady := false
    PendingChatPaste := false
    PendingChatAutoSend := false

    SetTimer(DoTranslate, 0)

    SourceEdit.Value := ""
    ResultEdit.Value := ""

    LastTranslatedSource := ""
    LastTranslatedSourceLang := ""
    LastTranslatedTarget := ""

    StatusText.Value := "Ready"
}


; Bottom Clear button: clear the translator and the selected Roblox chat draft.
; This intentionally does not press Enter, so nothing is sent to the game.
ClearTextAndRobloxChat(*) {
    global TargetRobloxHwnd, MainGui, OverlayZMode, ChatPasteInProgress, StatusText

    ClearText()

    if (!TargetRobloxHwnd || !IsRobloxWindow(TargetRobloxHwnd))
        TargetRobloxHwnd := FindAnyRobloxWindow()

    if (!TargetRobloxHwnd || !IsRobloxWindow(TargetRobloxHwnd)) {
        StatusText.Value := "Translator cleared - Roblox window not found"
        return
    }

    ChatPasteInProgress := true
    try {
        if (WinGetMinMax("ahk_id " . TargetRobloxHwnd) = -1)
            WinRestore("ahk_id " . TargetRobloxHwnd)

        WinSetAlwaysOnTop(true, "ahk_id " . MainGui.Hwnd)
        OverlayZMode := "topmost"

        WinActivate("ahk_id " . TargetRobloxHwnd)
        if (!WinWaitActive("ahk_id " . TargetRobloxHwnd, , 3)
            || !IsTargetRobloxForeground(TargetRobloxHwnd)) {
            StatusText.Value := "Translator cleared - Roblox activation failed"
            return
        }

        Sleep(180)
        if (!IsTargetRobloxForeground(TargetRobloxHwnd)) {
            StatusText.Value := "Translator cleared - Roblox lost focus"
            return
        }

        ; Open/focus chat, select its draft text, and delete it. Never send Enter.
        SendEvent("/")
        Sleep(250)
        if (!IsTargetRobloxForeground(TargetRobloxHwnd)) {
            StatusText.Value := "Translator cleared - Roblox lost focus before chat clear"
            return
        }

        SendEvent("^a")
        Sleep(60)
        if (!IsTargetRobloxForeground(TargetRobloxHwnd)) {
            StatusText.Value := "Translator cleared - Roblox lost focus before deletion"
            return
        }

        SendEvent("{Backspace}")
        StatusText.Value := "Translator and Roblox chat input cleared"
    } catch as err {
        StatusText.Value := "Translator cleared - Roblox chat clear failed: " . err.Message
    } finally {
        ChatPasteInProgress := false
    }
}


; ============================================================
; ROBLOX WINDOW DETECTION
; ============================================================

InitializeRobloxTarget() {
    global TargetRobloxHwnd, StartupTargetRobloxHwnd

    target := 0
    underHwnd := 0

    ; A child created with + should attach to the same Roblox client as its
    ; parent, rather than whichever client happens to be returned by enumeration.
    if (StartupTargetRobloxHwnd && IsRobloxWindow(StartupTargetRobloxHwnd))
        target := GetRootWindow(StartupTargetRobloxHwnd)

    try {
        MouseGetPos(
            &mouseX,
            &mouseY,
            &underHwnd
        )
    }

    root := GetRootWindow(underHwnd)

    if (!target && IsRobloxWindow(root)) {
        target := root
    } else if (!target) {
        foreground := DllCall(
            "user32\GetForegroundWindow",
            "Ptr"
        )

        foregroundRoot := GetRootWindow(foreground)

        if (IsRobloxWindow(foregroundRoot))
            target := foregroundRoot
        else
            target := FindAnyRobloxWindow()
    }

    if (target && IsRobloxWindow(target)) {
        TargetRobloxHwnd := target
        ShowOnTargetRoblox()
        UpdateZOrderFromForeground()
    }
}

FindAnyRobloxWindow() {
    exeNames := [
        "RobloxPlayerBeta.exe",
        "RobloxPlayer.exe",
        "Roblox.exe",
        "Windows10Universal.exe"
    ]

    foreground := DllCall(
        "user32\GetForegroundWindow",
        "Ptr"
    )

    foregroundRoot := GetRootWindow(foreground)

    if (IsRobloxWindow(foregroundRoot))
        return foregroundRoot

    for _, exeName in exeNames {
        try {
            windows := WinGetList(
                "ahk_exe " . exeName
            )
        } catch {
            continue
        }

        for _, hwnd in windows {
            if (!IsRobloxWindow(hwnd))
                continue

            if (!DllCall(
                "user32\IsWindowVisible",
                "Ptr", hwnd,
                "Int"
            ))
                continue

            try {
                if (WinGetMinMax("ahk_id " . hwnd) = -1)
                    continue
            } catch {
                continue
            }

            return GetRootWindow(hwnd)
        }
    }

    return 0
}

IsRobloxWindow(hwnd) {
    if (!hwnd)
        return false

    try {
        root := GetRootWindow(hwnd)

        processName := StrLower(
            WinGetProcessName("ahk_id " . root)
        )
    } catch {
        return false
    }

    return processName = "robloxplayerbeta.exe"
        || processName = "robloxplayer.exe"
        || processName = "roblox.exe"
        || processName = "windows10universal.exe"
}

GetRootWindow(hwnd) {
    if (!hwnd)
        return 0

    root := DllCall(
        "user32\GetAncestor",
        "Ptr", hwnd,
        "UInt", 2,
        "Ptr"
    )

    return root ? root : hwnd
}

IsOwnProcessWindow(hwnd) {
    global ScriptPID

    if (!hwnd)
        return false

    try {
        return WinGetPID("ahk_id " . hwnd) = ScriptPID
    } catch {
        return false
    }
}


; ============================================================
; TRACK ROBLOX AND WINDOW Z-ORDER
; ============================================================

TrackRobloxUnderMouse() {
    global TargetRobloxHwnd, LastRobloxSearchTick, ChatPasteInProgress, TranslatorFaded
    global IdleStripGui

    ; Keep the selected Roblox target and Z-order stable during the chat handoff.
    if (ChatPasteInProgress)
        return

    try {
        CoordMode("Mouse", "Screen")
        MouseGetPos(
            &mouseX,
            &mouseY,
            &underHwnd
        )
    } catch {
        return
    }

    ; Never relocate the name-only idle strip out from under the mouse while it
    ; is being hovered/clicked. The idle monitor wakes on any point of the strip.
    if (TranslatorFaded) {
        try {
            if (GetWindowPos(IdleStripGui.Hwnd, &stripX, &stripY, &stripW, &stripH)
                && stripW > 0 && stripH > 0
                && mouseX >= stripX && mouseX < stripX + stripW
                && mouseY >= stripY && mouseY < stripY + stripH)
                return
        }
    }

    ; In idle mode the compact title strip itself can be the HWND under the
    ; cursor, hiding the Roblox window beneath it. Walk the top-level Z-order
    ; at the pointer and skip our own windows to identify the client underneath.
    if (TranslatorFaded) {
        mouseRoot := FindRobloxWindowUnderMouse(mouseX, mouseY)
        if (!mouseRoot && IsRobloxWindow(GetRootWindow(underHwnd)))
            mouseRoot := GetRootWindow(underHwnd)
    } else {
        mouseRoot := GetRootWindow(underHwnd)
    }

    ; Move to a different Roblox window only when the mouse is
    ; actually over that Roblox window. The translator itself
    ; never becomes a new target.
    if (IsRobloxWindow(mouseRoot)
        && mouseRoot != TargetRobloxHwnd) {

        if (TargetRobloxHwnd
            && IsRobloxWindow(TargetRobloxHwnd)
            && !TargetGeometryChanged()) {
            CaptureManualMove()
        }

        TargetRobloxHwnd := mouseRoot
        ShowOnTargetRoblox()
    }

    ; Search again if the remembered Roblox window closed.
    if (!TargetRobloxHwnd
        || !IsRobloxWindow(TargetRobloxHwnd)) {

        if (A_TickCount - LastRobloxSearchTick >= 1000) {
            LastRobloxSearchTick := A_TickCount

            candidate := 0

            if (IsRobloxWindow(mouseRoot))
                candidate := mouseRoot
            else
                candidate := FindAnyRobloxWindow()

            if (candidate) {
                TargetRobloxHwnd := candidate
                ShowOnTargetRoblox()
            }
        }
    }

    ; Keep visible. Change z-order, never hide the GUI.
    UpdateZOrderFromForeground()

    if (TargetRobloxHwnd
        && IsRobloxWindow(TargetRobloxHwnd)) {

        if (TargetGeometryChanged())
            ShowOnTargetRoblox()
        else
            CaptureManualMove()
    }
}


FindRobloxWindowUnderMouse(mouseX, mouseY) {
    ; WindowFromPoint can return the compact idle strip (or one of its child
    ; controls). Walk downward in Z-order, ignore this script's own windows,
    ; and use the first visible application window intersecting the point.
    try {
        point := Buffer(8, 0)
        NumPut("Int", mouseX, point, 0)
        NumPut("Int", mouseY, point, 4)
        pointValue := NumGet(point, 0, "Int64")
        hit := DllCall("user32\WindowFromPoint", "Int64", pointValue, "Ptr")
        if (!hit)
            return 0

        root := GetRootWindow(hit)
        Loop 96 {
            if (!root)
                break

            if (!IsOwnProcessWindow(root)
                && !IsQuickTranslatorWindow(root)
                && DllCall("user32\IsWindowVisible", "Ptr", root, "Int")) {
                if (GetWindowPos(root, &wx, &wy, &ww, &wh)
                    && mouseX >= wx && mouseX < wx + ww
                    && mouseY >= wy && mouseY < wy + wh) {
                    return IsRobloxWindow(root) ? root : 0
                }
            }

            nextWindow := DllCall("user32\GetWindow", "Ptr", root, "UInt", 2, "Ptr")
            if (!nextWindow || nextWindow = root)
                break
            root := nextWindow
        }
    } catch {
        return 0
    }
    return 0
}

UpdateZOrderFromForeground() {
    global SelectorPopupGui

    foreground := DllCall(
        "user32\GetForegroundWindow",
        "Ptr"
    )
    foregroundRoot := GetRootWindow(foreground)
    translatorHasForeground := (IsOwnProcessWindow(foreground)
        || IsOwnProcessWindow(foregroundRoot)
        || IsQuickTranslatorWindow(foreground)
        || IsQuickTranslatorWindow(foregroundRoot))

    ; The selector is a separate, non-overlapping GUI. When a translator window
    ; is actively used, the selector's own unchanged policy may move the panel
    ; out of TOPMOST because focus/cursor have left Roblox. If that Roblox client
    ; itself is TOPMOST, it can then cover its status panel. Temporarily demote
    ; only Roblox client windows whose rectangles overlap the selector panel, so
    ; the selector's own normal-band positioning can keep it visible. Restore
    ; their previous TOPMOST state as soon as the translator is no longer active.
    ReconcileRobloxTopmostForSelector(translatorHasForeground)

    ; A custom selector popup is a temporary topmost owned window. Keep the
    ; popup itself topmost, but do not directly reorder its owner here.
    if (SelectorPopupGui) {
        try WinSetAlwaysOnTop(true, "ahk_id " . SelectorPopupGui.Hwnd)
        return
    }

    ; The translator remains TOPMOST when Roblox is foreground so the overlay
    ; can still be used over Roblox. It is also kept TOPMOST when the translator
    ; itself is active; the adjustment above affects only the Roblox window
    ; underneath the separate game-status panel, never the translator window.
    if (IsRobloxWindow(foregroundRoot)
        || IsOwnProcessWindow(foreground)
        || IsOwnProcessWindow(foregroundRoot)) {
        SetTranslatorZMode("topmost")
    } else {
        ; For unrelated active apps, remove TOPMOST only and let Windows manage
        ; ordinary Z-order naturally.
        SetTranslatorZMode("normal")
    }
}

FindVisibleRobloxGameStatusSelector() {
    ; Use the known title from the user's stable selector. No selector code is
    ; changed or injected; this translator-side helper only reads its HWND/rect.
    try {
        for hwnd in WinGetList() {
            if (!DllCall("user32\IsWindowVisible", "Ptr", hwnd, "Int"))
                continue
            if (WinGetTitle("ahk_id " . hwnd) = "Roblox Game Status")
                return hwnd
        }
    } catch {
    }
    return 0
}

ReconcileRobloxTopmostForSelector(translatorHasForeground) {
    global TranslatorDemotedRobloxTopmostByHwnd

    ; If translator focus ended, restore every Roblox window whose TOPMOST state
    ; this helper changed. Do not touch Roblox windows that were normal already.
    if (!translatorHasForeground) {
        RestoreTranslatorDemotedRobloxTopmost()
        return
    }

    selectorHwnd := FindVisibleRobloxGameStatusSelector()
    if (!selectorHwnd
        || !GetWindowPos(selectorHwnd, &sx, &sy, &sw, &sh)
        || sw <= 0 || sh <= 0) {
        RestoreTranslatorDemotedRobloxTopmost()
        return
    }

    overlappingRoblox := Map()
    try {
        robloxWindows := WinGetList("ahk_exe RobloxPlayerBeta.exe")
    } catch {
        RestoreTranslatorDemotedRobloxTopmost()
        return
    }

    for hwnd in robloxWindows {
        if (!hwnd || !DllCall("user32\IsWindow", "Ptr", hwnd, "Int")
            || !DllCall("user32\IsWindowVisible", "Ptr", hwnd, "Int"))
            continue
        if (!GetWindowPos(hwnd, &rx, &ry, &rw, &rh) || rw <= 0 || rh <= 0)
            continue

        overlapsSelector := (rx < sx + sw && rx + rw > sx
            && ry < sy + sh && ry + rh > sy)
        if (!overlapsSelector)
            continue

        overlappingRoblox[hwnd] := true
        exStyle := 0
        try exStyle := DllCall("user32\GetWindowLongPtrW", "Ptr", hwnd, "Int", -20, "Ptr")
        catch
            exStyle := 0

        if ((exStyle & 0x00000008) != 0) { ; WS_EX_TOPMOST
            if (!TranslatorDemotedRobloxTopmostByHwnd.Has(hwnd))
                TranslatorDemotedRobloxTopmostByHwnd[hwnd] := true
            try WinSetAlwaysOnTop(false, "ahk_id " . hwnd)
        }
    }

    ; If the selector moved away from a Roblox rectangle, restore that client
    ; immediately instead of leaving a stale TOPMOST change behind.
    restoreList := []
    for hwnd, wasTopmost in TranslatorDemotedRobloxTopmostByHwnd {
        if (!overlappingRoblox.Has(hwnd)) {
            if (wasTopmost && DllCall("user32\IsWindow", "Ptr", hwnd, "Int")) {
                exStyle := 0
                try exStyle := DllCall("user32\GetWindowLongPtrW", "Ptr", hwnd, "Int", -20, "Ptr")
                catch
                    exStyle := 0
                if ((exStyle & 0x00000008) = 0) {
                    try WinSetAlwaysOnTop(true, "ahk_id " . hwnd)
                }
            }
            restoreList.Push(hwnd)
        }
    }
    for hwnd in restoreList
        TranslatorDemotedRobloxTopmostByHwnd.Delete(hwnd)
}

RestoreTranslatorDemotedRobloxTopmost() {
    global TranslatorDemotedRobloxTopmostByHwnd

    restoreList := []
    for hwnd, wasTopmost in TranslatorDemotedRobloxTopmostByHwnd {
        try {
            if (wasTopmost && DllCall("user32\IsWindow", "Ptr", hwnd, "Int")) {
                exStyle := DllCall("user32\GetWindowLongPtrW", "Ptr", hwnd, "Int", -20, "Ptr")
                if ((exStyle & 0x00000008) = 0) ; WS_EX_TOPMOST
                    WinSetAlwaysOnTop(true, "ahk_id " . hwnd)
            }
        } catch {
        }
        restoreList.Push(hwnd)
    }

    for hwnd in restoreList
        TranslatorDemotedRobloxTopmostByHwnd.Delete(hwnd)
}

SetTranslatorZMode(mode) {
    global MainGui, TranslatorVisible, OverlayZMode, TranslatorFaded

    if (!TranslatorVisible)
        return

    if (mode != OverlayZMode) {
        try {
            if (mode = "topmost")
                WinSetAlwaysOnTop(true, "ahk_id " . MainGui.Hwnd)
            else
                WinSetAlwaysOnTop(false, "ahk_id " . MainGui.Hwnd)
            OverlayZMode := mode
        } catch {
            ; Retry on a later tracking cycle.
        }
    }

    if (TranslatorFaded)
        ApplyIdleStripZOrder(mode)
}

ApplyIdleStripZOrder(mode := "") {
    global IdleStripGui, OverlayZMode

    if (!mode)
        mode := OverlayZMode

    try {
        if (mode = "topmost") {
            WinSetAlwaysOnTop(true, "ahk_id " . IdleStripGui.Hwnd)
        } else {
            ; Do not force the strip to HWND_TOP or insert it immediately behind
            ; whichever app happens to be foreground. Its existing normal Z-order
            ; is preserved, so repositioning does not make it pop over other apps.
            WinSetAlwaysOnTop(false, "ahk_id " . IdleStripGui.Hwnd)
        }
    }
}

; ============================================================
; OVERLAY POSITIONING
; ============================================================

TargetGeometryChanged() {
    global TargetRobloxHwnd
    global LastTargetX, LastTargetY
    global LastTargetW, LastTargetH

    if (!TargetRobloxHwnd
        || !IsRobloxWindow(TargetRobloxHwnd))
        return false

    try {
        if (WinGetMinMax(
            "ahk_id " . TargetRobloxHwnd
        ) = -1)
            return false
    } catch {
        return false
    }

    if (!GetWindowPos(
        TargetRobloxHwnd,
        &tx, &ty, &tw, &th
    ))
        return false

    return tx != LastTargetX
        || ty != LastTargetY
        || tw != LastTargetW
        || th != LastTargetH
}

ShowOnTargetRoblox() {
    global MainGui, TargetRobloxHwnd
    global StartupPositionPending, StartupPositionX, StartupPositionY
    global TranslatorVisible, TranslatorMinimized, LastTranslatorActivityTick
    global ActiveWindowOpacityPercent
    global WindowWidth, WindowHeight
    global OverlayOffsetX, OverlayOffsetY
    global HasSavedPosition
    global ExpectedX, ExpectedY
    global LastTargetX, LastTargetY
    global LastTargetW, LastTargetH

    hadSavedPosition := HasSavedPosition

    if (TranslatorMinimized)
        return

    if (!TargetRobloxHwnd
        || !IsRobloxWindow(TargetRobloxHwnd))
        return

    try {
        if (WinGetMinMax(
            "ahk_id " . TargetRobloxHwnd
        ) = -1)
            return
    } catch {
        return
    }

    if (!GetWindowPos(
        TargetRobloxHwnd,
        &tx, &ty, &tw, &th
    ))
        return

    ; Approximate outer size before first show.
    ; With -Caption, only the resize frame remains outside the client area.
    overlayW := WindowWidth + 16
    overlayH := WindowHeight + 16

    if (TranslatorVisible) {
        if (!GetWindowPos(
            MainGui.Hwnd,
            &oldX, &oldY,
            &overlayW, &overlayH
        ))
            return
    }

    ; A + button passes a requested screen position to its newly spawned
    ; instance. Apply that position only on the first display, then persist its
    ; Roblox-relative offset as usual. Existing profiles restore their own offset.
    if (!HasSavedPosition && StartupPositionPending) {
        newX := StartupPositionX
        newY := StartupPositionY
    } else if (!HasSavedPosition) {
        newX := tx + 12
        newY := ty + Floor((th - overlayH) / 2)
    } else {
        newX := tx + OverlayOffsetX
        newY := ty + OverlayOffsetY
    }

    newX := ClampOverlayX(
        newX, tx, tw, overlayW
    )

    newY := ClampOverlayY(
        newY, ty, th, overlayH
    )

    if (!TranslatorVisible) {
        ; Show at the new position without changing dimensions.
        MainGui.Show(
            "NA x" . newX . " y" . newY
        )
        ; Apply the configured opacity whenever the translator first appears.
        SetTranslatorOpacityPercent(ActiveWindowOpacityPercent)

        TranslatorVisible := true
        ; A newly shown translator gets a fresh idle-mode grace period.
        LastTranslatorActivityTick := A_TickCount

        ; Correct position using the actual outer window size.
        if (GetWindowPos(
            MainGui.Hwnd,
            &actualX, &actualY,
            &actualW, &actualH
        )) {
            overlayW := actualW
            overlayH := actualH

            newX := ClampOverlayX(
                newX, tx, tw, overlayW
            )

            newY := ClampOverlayY(
                newY, ty, th, overlayH
            )

            if (Abs(actualX - newX) > 2
                || Abs(actualY - newY) > 2) {
                MoveOverlayOnly(newX, newY)
            }
        }

    } else {
        ; Only move. Never resize during tracking.
        if (Abs(oldX - newX) > 2
            || Abs(oldY - newY) > 2) {
            MoveOverlayOnly(newX, newY)
        }
    }

    ExpectedX := newX
    ExpectedY := newY

    ; On the first placement, persist the default offset as well. Without this,
    ; the INI kept Saved=0 forever unless the user manually dragged the window,
    ; so a restart appeared to forget its previous position.
    if (!hadSavedPosition) {
        OverlayOffsetX := newX - tx
        OverlayOffsetY := newY - ty
        HasSavedPosition := true
        StartupPositionPending := false
        SaveSettings()
    }

    LastTargetX := tx
    LastTargetY := ty
    LastTargetW := tw
    LastTargetH := th
}

ClampOverlayX(x, targetX, targetW, overlayW) {
    if (targetW <= overlayW)
        return targetX

    return Max(
        targetX,
        Min(x, targetX + targetW - overlayW)
    )
}

ClampOverlayY(y, targetY, targetH, overlayH) {
    if (targetH <= overlayH)
        return targetY

    return Max(
        targetY,
        Min(y, targetY + targetH - overlayH)
    )
}

MoveOverlayOnly(x, y) {
    global MainGui, IdleStripGui, TranslatorFaded, IdleCompactClientWidth, IdleTitleStripHeight
    global IdleTitleBarOpacityPercent, OverlayZMode

    ; SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE.
    DllCall(
        "user32\SetWindowPos",
        "Ptr", MainGui.Hwnd,
        "Ptr", 0,
        "Int", x,
        "Int", y,
        "Int", 0,
        "Int", 0,
        "UInt", 0x0001 | 0x0004 | 0x0010
    )

    if (TranslatorFaded) {
        try {
            ; Get the hidden main window's client origin through Win32. The same
            ; geometry helper is used for initial fade and every relocation.
            if (!GetClientOriginScreen(MainGui.Hwnd, &cx, &cy))
                return
            MoveIdleStripPhysical(cx, cy)
            SetWindowOpacityPercent(IdleStripGui.Hwnd, IdleTitleBarOpacityPercent)
            ApplyIdleStripZOrder(OverlayZMode)
        }
    }
}

SetIdleStripGeometry(x, y, showStrip := true) {
    global IdleStripGui, IdleStripTitleBar, IdleStripTitleText
    global IdleCompactClientWidth, IdleTitleStripHeight

    ; Lay out the name-only strip in AHK GUI coordinate units.
    IdleStripTitleBar.Move(0, 0, IdleCompactClientWidth, IdleTitleStripHeight)
    IdleStripTitleText.Move(12, 8, IdleCompactClientWidth - 24, 22)

    ; Use Gui.Show for size-setting so AutoHotkey applies the current monitor's
    ; DPI scaling. Do not set width/height with raw SetWindowPos here.
    if (showStrip) {
        IdleStripGui.Show("NA x" . x . " y" . y
            . " w" . IdleCompactClientWidth . " h" . IdleTitleStripHeight)
    } else {
        IdleStripGui.Show("NA x" . x . " y" . y)
    }
}

MoveIdleStripPhysical(x, y) {
    global IdleStripGui

    ; x/y came from ClientToScreen/GetWindowRect and are physical screen pixels.
    ; SWP_NOSIZE is essential: resizing to 190x36 raw pixels shrank the strip
    ; on DPI-scaled displays and caused normal and tiny title strips to alternate.
    DllCall("user32\SetWindowPos", "Ptr", IdleStripGui.Hwnd, "Ptr", 0,
        "Int", x, "Int", y, "Int", 0, "Int", 0,
        "UInt", 0x0001 | 0x0004 | 0x0010, "Int") ; NOSIZE|NOZORDER|NOACTIVATE
}

CaptureManualMove() {
    global MainGui, TargetRobloxHwnd
    global OverlayOffsetX, OverlayOffsetY
    global HasSavedPosition
    global ExpectedX, ExpectedY

    if (!TargetRobloxHwnd
        || !IsRobloxWindow(TargetRobloxHwnd))
        return

    if (!TranslatorVisible)
        return

    if (!GetWindowPos(
        TargetRobloxHwnd,
        &tx, &ty, &tw, &th
    ))
        return

    if (!GetWindowPos(
        MainGui.Hwnd,
        &ox, &oy, &ow, &oh
    ))
        return

    ; Record manual dragging relative to the Roblox window.
    if (Abs(ox - ExpectedX) > 3
        || Abs(oy - ExpectedY) > 3) {

        OverlayOffsetX := ox - tx
        OverlayOffsetY := oy - ty
        HasSavedPosition := true

        ExpectedX := ox
        ExpectedY := oy

        SaveSettings()
    }
}

GetWindowPos(hwnd, &x, &y, &w, &h) {
    ; GetWindowRect works for hidden windows too. WinGetPos can fail to resolve
    ; the hidden translator HWND after idle mode hides MainGui, preventing the
    ; compact title strip from following the mouse to another Roblox client.
    if (!hwnd || !DllCall("user32\IsWindow", "Ptr", hwnd, "Int"))
        return false

    rect := Buffer(16, 0)
    if (!DllCall("user32\GetWindowRect", "Ptr", hwnd, "Ptr", rect, "Int"))
        return false

    left := NumGet(rect, 0, "Int")
    top := NumGet(rect, 4, "Int")
    right := NumGet(rect, 8, "Int")
    bottom := NumGet(rect, 12, "Int")

    x := left
    y := top
    w := right - left
    h := bottom - top
    return w > 0 && h > 0
}

GetClientOriginScreen(hwnd, &x, &y) {
    if (!hwnd || !DllCall("user32\IsWindow", "Ptr", hwnd, "Int"))
        return false
    point := Buffer(8, 0) ; POINT { x:0, y:0 }
    if (!DllCall("user32\ClientToScreen", "Ptr", hwnd, "Ptr", point, "Int"))
        return false
    x := NumGet(point, 0, "Int")
    y := NumGet(point, 4, "Int")
    return true
}


; ============================================================
; SETTINGS
; ============================================================

LoadSavedSettings() {
    global SettingsPath
    global WindowWidth, WindowHeight
    global OverlayOffsetX, OverlayOffsetY
    global HasSavedPosition
    global InitialSourceIndex
    global InitialTargetIndex
    global InitialFontIndex

    version := IniRead(
        SettingsPath,
        "Meta",
        "Version",
        "0"
    ) + 0

    if (version < 3) {
        ; First startup of this layout revision uses the actual minimum size.
        ; Position, language, target-language and font settings are still loaded
        ; from the same INI below. On later launches, version 3 dimensions persist.
        WindowWidth := 344
        WindowHeight := 350
    } else {
        ; Version 3 stores client dimensions at the minimum-size-compatible range.
        WindowWidth := IniRead(
            SettingsPath,
            "Window",
            "Width",
            "344"
        ) + 0

        WindowHeight := IniRead(
            SettingsPath,
            "Window",
            "Height",
            "350"
        ) + 0
    }

    if (WindowWidth < 344 || WindowWidth > 3000)
        WindowWidth := 344

    if (WindowHeight < 350 || WindowHeight > 2000)
        WindowHeight := 350

    HasSavedPosition := (
        IniRead(
            SettingsPath,
            "Position",
            "Saved",
            "0"
        ) + 0
    ) = 1

    OverlayOffsetX := IniRead(
        SettingsPath,
        "Position",
        "OffsetX",
        "12"
    ) + 0

    OverlayOffsetY := IniRead(
        SettingsPath,
        "Position",
        "OffsetY",
        "0"
    ) + 0

    InitialSourceIndex := IniRead(
        SettingsPath,
        "Preferences",
        "SourceIndex",
        "1"
    ) + 0

    InitialTargetIndex := IniRead(
        SettingsPath,
        "Preferences",
        "TargetIndex",
        "1"
    ) + 0

    InitialFontIndex := IniRead(
        SettingsPath,
        "Preferences",
        "FontIndex",
        "4"
    ) + 0
}

SaveSettings(*) {
    global SettingsPath
    global WindowWidth, WindowHeight
    global OverlayOffsetX, OverlayOffsetY
    global HasSavedPosition
    global SourceDrop, TargetDrop, FontDrop

    try {
        IniWrite(
            3,
            SettingsPath,
            "Meta",
            "Version"
        )

        ; Persist client dimensions only.
        ; Never query and re-save outer dimensions here.
        IniWrite(
            WindowWidth,
            SettingsPath,
            "Window",
            "Width"
        )

        IniWrite(
            WindowHeight,
            SettingsPath,
            "Window",
            "Height"
        )

        IniWrite(
            OverlayOffsetX,
            SettingsPath,
            "Position",
            "OffsetX"
        )

        IniWrite(
            OverlayOffsetY,
            SettingsPath,
            "Position",
            "OffsetY"
        )

        IniWrite(
            HasSavedPosition ? 1 : 0,
            SettingsPath,
            "Position",
            "Saved"
        )

        IniWrite(
            SourceDrop.Value,
            SettingsPath,
            "Preferences",
            "SourceIndex"
        )

        IniWrite(
            TargetDrop.Value,
            SettingsPath,
            "Preferences",
            "TargetIndex"
        )

        IniWrite(
            FontDrop.Value,
            SettingsPath,
            "Preferences",
            "FontIndex"
        )
    }
}

ShutdownScript(*) {
    global DarkBrush, TitleBarBrush

    ; Never leave a Roblox client with the temporary Z-order style this
    ; translator applied for selector compatibility.
    RestoreTranslatorDemotedRobloxTopmost()
    UninstallIdleToggleMouseHook()
    SetTimer(SaveSettings, 0)
    SaveSettings()

    if (DarkBrush) {
        DllCall(
            "gdi32\DeleteObject",
            "Ptr", DarkBrush
        )
        DarkBrush := 0
    }

    if (TitleBarBrush) {
        DllCall(
            "gdi32\DeleteObject",
            "Ptr", TitleBarBrush
        )
        TitleBarBrush := 0
    }
}


; ============================================================
; ROBLOX SLASH / TRANSLATOR INPUT WORKFLOW
; First slash: keep Roblox foreground, open Roblox chat, and wake the translator.
; Second slash within the configured window: focus the translator source editor.
; If the translator itself is active, slash is inserted normally into its control.
; ============================================================

HandleSlashWorkflow(*) {
    global MainGui, SourceEdit, StatusText
    global TargetRobloxHwnd, TranslatorFaded, TranslatorVisible, TranslatorMinimized
    global LastTranslatorActivityTick
    global SlashWorkflowArmed, SlashWorkflowTargetHwnd, SlashWorkflowTick, SlashWorkflowWindowMs

    ; Do not treat key-repeat while the physical key is held as the second press.
    KeyWait("SC035")

    foreground := DllCall("user32\GetForegroundWindow", "Ptr")
    foregroundRoot := GetRootWindow(foreground)

    ; When the translator is active, slash should remain a normal typed character.
    if (foregroundRoot = GetRootWindow(MainGui.Hwnd)) {
        SlashWorkflowArmed := false
        SlashWorkflowTargetHwnd := 0
        SendText("/")
        return
    }

    ; Safe pass-through if Windows changes foreground during key release.
    if (!IsRobloxWindow(foregroundRoot)) {
        SlashWorkflowArmed := false
        SlashWorkflowTargetHwnd := 0
        SendText("/")
        return
    }

    now := A_TickCount
    if (SlashWorkflowArmed
        && SlashWorkflowTargetHwnd = foregroundRoot
        && now - SlashWorkflowTick <= SlashWorkflowWindowMs) {
        ; Second press: do not send another slash to Roblox. Bring the translator
        ; forward and focus the source editor so the user can type immediately.
        SlashWorkflowArmed := false
        SlashWorkflowTargetHwnd := 0
        TargetRobloxHwnd := foregroundRoot

        if (TranslatorFaded)
            RestoreTranslatorFromIdleFade()

        if (TranslatorMinimized) {
            TranslatorMinimized := false
            try DllCall("user32\ShowWindow", "Ptr", MainGui.Hwnd, "Int", 4) ; SW_SHOWNOACTIVATE
        }

        ShowOnTargetRoblox()

        try {
            WinActivate("ahk_id " . MainGui.Hwnd)
            if (WinWaitActive("ahk_id " . MainGui.Hwnd, , 1)) {
                SourceEdit.Focus()
                LastTranslatorActivityTick := A_TickCount
                StatusText.Value := "Translator input focused - type your message"
            } else {
                StatusText.Value := "Could not focus translator input"
            }
        } catch as err {
            StatusText.Value := "Could not focus translator input: " . err.Message
        }
        return
    }

    ; First press: remember which Roblox window opened chat and keep the
    ; translator ready, while leaving keyboard focus in Roblox.
    SlashWorkflowArmed := true
    SlashWorkflowTargetHwnd := foregroundRoot
    SlashWorkflowTick := now
    TargetRobloxHwnd := foregroundRoot

    if (TranslatorFaded)
        RestoreTranslatorFromIdleFade()

    if (TranslatorMinimized) {
        TranslatorMinimized := false
        try DllCall("user32\ShowWindow", "Ptr", MainGui.Hwnd, "Int", 4) ; SW_SHOWNOACTIVATE
    }

    ShowOnTargetRoblox()
    LastTranslatorActivityTick := now

    ; The existing chat-paste code uses SendEvent("/") successfully.
    ; The $ prefix stops this synthetic key from recursively invoking this hotkey.
    SendEvent("/")
    StatusText.Value := "Roblox chat ready - press / again to focus translator input"
}

; ============================================================
; ENTER IN SOURCE EDITOR
;
; This hotkey is active only while the source editor has focus.
; Enter in the source editor does not insert a newline: it
; queues translation and then starts the chat-paste operation.
; ============================================================

#HotIf WinActive("ahk_id " . MainGui.Hwnd)

$Enter::TranslatorEnter()
$NumpadEnter::TranslatorEnter()
$SC035::HandleSlashWorkflow()

#HotIf

; Roblox slash workflow is handled by exactly one running translator instance.
; Other instances remain independently usable without injecting duplicate slashes.
#HotIf WinActive("ahk_exe RobloxPlayerBeta.exe") && CanHandleGlobalSlashHotkey()
$SC035::HandleSlashWorkflow()
#HotIf