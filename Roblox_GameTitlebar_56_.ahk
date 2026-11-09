; V65: Centralize shortcut-help GUI HWND access and guard destroyed Gui wrappers.
; V64: Restrict F3/F4/F5/F6/F8 shortcuts to foreground Roblox; keep Ctrl+F1/Ctrl+F2/F7/F9 global.
; V63: Reduce only the game selector top/bottom padding in F11 fullscreen (28px -> 24px); keep text size and regular-window geometry unchanged.
; V61: Rebuild the entire shortcut help in actual hotkey order with five labeled sections.
; V60: Add titlebar button color inversion on hover/press; preserve transparent idle state.
; V59: Restore and Split Layout send F11 once to fullscreen clients before operating; never re-enter fullscreen.
; V57: Preserve existing titlebar button position in fullscreen; do not destroy the overlay on caption loss.
; V56: Keep the Roblox game selector English-only; localize other system messages by Windows UI language.
; V54: Add FHD/QHD-aware Roblox auto layout; preserve non-layout features.
; V53: Remove the periodic-input feature while preserving shortcut-help layout spacing.
; V51: Fix IN_GAME cache field mismatch; strengthen log-to-PID association and restart-state parsing.
; V50: Log/PID-only disconnect confirmation with game-managed restart grace period.
; V49: Event-driven hover selection with a pointer-locked selector.
; V37: 실제 Z-order 기반 Roblox 가림 판정 / 비활성 상태창을 Roblox 바로 위에 배치
#Requires AutoHotkey >=2.0
; 🛡️ [V33 Active-Aware Z-Order] Owner-free status layering
#SingleInstance Force
#Warn

; v21: game selector uses Windows SC_MAXIMIZE / SC_RESTORE for title-bar-equivalent toggling.

; 관리자 권한이 없으면 자동으로 관리자 권한 재실행을 요청합니다.
; UAC에서 사용자가 [취소]한 경우에는 오류를 표시하지 않고 조용히 종료합니다.
if (!A_IsAdmin) {
    try {
        Run('*RunAs "' A_ScriptFullPath '"')
    } catch {
        ExitApp()
    }
    ExitApp()
}


; AHK v2: 물리 입력 감지를 위해 마우스/키보드 훅을 함수로 설치합니다.
InstallMouseHook()
InstallKeybdHook()

CoordMode("Mouse", "Screen")
CoordMode("Pixel", "Screen")

; ==========================================================
; 🎯 [Click Coordinates Settings]
; ==========================================================
; 💡 Tip: Writing coordinates based on 4K resolution (3840x2160) will scale automatically down to your current screen size.


; ==========================================================
; ⏱️ [Screen Transition & Click Delay Settings];   
; ==========================================================  
WAIT_BEFORE_CLICK := 20     ; 🖱️ 포커스 안정성을 위한 짧은 클릭 전 대기; 👈
WAIT_AFTER_CLICK  := 20     ; 🖱️ 클릭 직후 UI 반영을 위한 짧은 대기; 👈

; ==========================================================
; 🔄 [Roblox Connection Recovery] Conservative reconnect watchdog
; Normal monitoring is intentionally slow; recovery becomes focused
; only after a real 277 signal is observed in newly written logs.
; ==========================================================
CONNECTION_WATCH_INTERVAL_MS := 10000     ; Recovery/screen watchdog interval (10s)
CONNECTION_LOG_WATCH_INTERVAL_MS := 30000  ; Dedicated log monitor (30s)
CONNECTION_LOG_LOOKBACK_MIN := 20           ; Only recently active logs are considered
CONNECTION_LOG_OVERLAP_CHARS := 512         ; Re-read the tail so split log writes cannot hide a signal
CONNECTION_LOG_NEW_FILE_TAIL_BYTES := 65536 ; Tail size for newly-created log files
CONNECTION_RECOVERY_TRIGGER_DELAY_MS := 1500
CONNECTION_DISCONNECT_RESTART_GRACE_MS := 12000 ; Initial grace for game-managed Roblox restarts
CONNECTION_DISCONNECT_RESTART_MAX_GRACE_MS := 30000 ; Extend only while a replacement PID is actively joining
CONNECTION_DISCONNECT_RESTART_POLL_MS := 1000   ; Check process/log evidence during the grace period
CONNECTION_RECONNECT_CONFIRM_WAIT_MS := 2000
CONNECTION_RECONNECT_STABLE_CHECKS := 1   ; A single clean post-click modal check is enough
CONNECTION_RECONNECT_MAX_ATTEMPTS := 3
CONNECTION_RECOVERY_PENDING_TIMEOUT_MS := 120000
CONNECTION_DEEP_SCAN_INTERVAL_MS := 30000    ; Deep scan covered/minimized clients every 30s
CONNECTION_DEEP_SCAN_SETTLE_MS := 1000        ; Allow Roblox UI to fully render before pixel probing
CONNECTION_PASSIVE_SCAN_INTERVAL_MS := 10000 ; Passive visible-client fallback scan (no focus/mouse movement)
CONNECTION_HIDDEN_VERIFY_INTERVAL_MS := 1000    ; During reconnect confirmation, hidden target is focus-verified promptly when user is idle
CONNECTION_HIDDEN_SCAN_COOLDOWN_MS := 0        ; Do not auto-repeat a completed scan
CONNECTION_LOG_AUTO_REJOIN_ENABLE := false       ; Do not terminate/relaunch the client by Place ID; use the existing modal recovery flow
CONNECTION_MODAL_AUTO_RECOVERY_ENABLE := true    ; After the alert, use the existing modal recovery only after user idle
CONNECTION_LOG_REJOIN_CLOSE_WAIT_MS := 5000      ; Wait for the old Roblox PID to disappear
CONNECTION_LOG_REJOIN_SPAWN_WAIT_MS := 90000     ; Wait for a new RobloxPlayerBeta.exe PID
CONNECTION_LOG_REJOIN_JOIN_WAIT_MS := 90000      ; Wait for actual game-join evidence in the new PID/log
CONNECTION_LOG_REJOIN_STEP_MS := 1000            ; Recovery-only polling while a reconnect transaction is active
CONNECTION_LOG_REJOIN_LOG_TAIL_BYTES := 131072   ; Tail size for post-launch join verification
CONNECTION_LOG_REJOIN_LAUNCH_RETRY_INTERVAL_MS := 10000 ; Retry launch dispatch every 10s if no new Roblox PID appears
CONNECTION_LOG_REJOIN_MAX_LAUNCH_ATTEMPTS := 4       ; Maximum launch dispatch attempts per reconnect incident
CONNECTION_LOG_REJOIN_WINDOW_WIDTH := 1920        ; Width for a newly launched Roblox reconnect window; height is preserved
TRAY_ALERT_ENABLE := true                    ; Enable transient tray notifications for connection recovery
USER_ACTIVITY_TIMEOUT_MS := 5000               ; Physical-user activity window for deciding whether Roblox is actively being used
AUTO_HIDDEN_SCAN_DELAY_SEC := 10                ; Automatic hidden scan delay after physical user input stops (seconds)
CONNECTION_MODAL_REFERENCE_4K_SCALE := 1.00    ; Measured from the supplied 4K modal image
CONNECTION_MODAL_REFERENCE_FHD_SCALE := 0.665  ; F6 showed the prior FHD coordinate footprint was about 2x too large
CONNECTION_MODAL_REFERENCE_4K_HEIGHT := 2160
CONNECTION_MODAL_REFERENCE_FHD_HEIGHT := 1080
CONNECTION_MODAL_REFERENCE_WIDTH := 600        ; Approximate 4K modal width; used for bounds sanity checks only
CONNECTION_MODAL_REFERENCE_HEIGHT := 375       ; Approximate 4K modal height; used for bounds sanity checks only
CONNECTION_MODAL_GATE_X_RATIO := 0.36          ; Symmetric interior samples, inset from left/right edges
CONNECTION_MODAL_GATE_TOP_Y_RATIO := 0.14      ; Upper samples sit above the divider
CONNECTION_MODAL_GATE_BOTTOM_Y_RATIO := 0.70   ; Lower samples stay clear of buttons
CONNECTION_MODAL_OUTSIDE_MARGIN_RATIO := 0.10   ; Precision samples just beyond each measured edge
DISCONNECT_ALERT_WIDTH := 560                  ; Recalculated from status-window scale; fixed while text wraps
DISCONNECT_ALERT_HEIGHT := 520                 ; 277 diagnostic window height - expanded for full diagnostics

; ==========================================================
; 🎮 [Roblox Game Identity]
; Roblox 로그에서 HWND + Place ID/Universe ID를 찾고,
; Roblox 공개 API에서 실제 게임 이름을 자동 조회합니다.
; Heroes RNG도 별도 ID를 하드코딩하지 않고 조회된 게임 이름으로 판별합니다.
; ==========================================================
GAME_IDENTITY_LOG_LOOKBACK_MIN := 30

ROBLOX_TITLEBAR_CONTROLS_ENABLE := true

gameIdentityByPid := Map()
gameIdentityLogState := Map()
robloxAccountDisplayNameByUserId := Map()
robloxAccountUsernameByUserId := Map()
robloxAccountLookupTickByUserId := Map()
gameNameByUniverseId := Map()
gameUniverseByPlaceId := Map()
gameIdentityInitialScanComplete := false
gameIdentityScanPending := false
gameIdentityScanActive := false
gameIdentityScanQueue := []
gameIdentityScanIndex := 0


robloxTitlebarControlsByHwnd := Map()
robloxTaskbarAppIdByHwnd := Map()
robloxTitlebarTooltipText := ""
robloxTitlebarTooltipGui := ""
robloxTitlebarTooltipCtrl := ""
robloxTitlebarTooltipX := -1
robloxTitlebarTooltipY := -1
robloxTitlebarTooltipWidth := 0
robloxTitlebarLocationChangeHook := 0
robloxTitlebarLocationChangeCallback := 0
robloxTitlebarForegroundHook := 0
robloxTitlebarForegroundCallback := 0
robloxTitlebarForegroundRepairPending := false
robloxTitlebarLastForegroundWasRoblox := false
robloxTitlebarRefreshPending := false
robloxTitlebarTransparentMouseHook := 0
robloxTitlebarTransparentMouseCallback := 0
robloxTitlebarTransparentMouseDownTargetHwnd := 0
robloxTitlebarTransparentMouseDownButtonIndex := -1
robloxTitlebarTransparentMouseActionTargetHwnd := 0
robloxTitlebarTransparentMouseActionButtonIndex := -1
robloxTitlebarPressedVisualTargetHwnd := 0
robloxTitlebarPressedVisualButtonIndex := -1
robloxTitlebarPointerTargetHwnd := 0
shortcutHelpGui := ""
shortcutHelpVisible := false
shortcutHelpTargetHwnd := 0
; Runtime size is calculated from the actual help text and row spacing.
shortcutHelpWidth := 0
shortcutHelpHeight := 0
shortcutHelpBaseDpi := 144
shortcutHelpCurrentDpi := 0
shortcutHelpLastX := -2147483648
shortcutHelpLastY := -2147483648
shortcutHelpLastRobloxActive := false
shortcutHelpStateControls := Map()
shortcutHelpModeControl := ""
shortcutHelpModeLast := ""
shortcutHelpRapidIntervalControl := ""
shortcutHelpRapidDecreaseHwnd := 0
shortcutHelpRapidIncreaseHwnd := 0


gameStatusGui := ""
gameStatusText := ""
gameStatusBackgroundCtrl := ""
gameStatusLoadingText := ""
gameStatusRows := []
gameStatusSeparators := []
gameStatusAllMiniCtrl := ""
gameStatusRowTargets := []
gameStatusRenderedRowTargets := [] ; HWNDs captured by the currently bound row click handlers
gameStatusClickSnapshotRow := 0
gameStatusClickSnapshotHwnd := 0
gameStatusClickSnapshotWasAutoHoverActivated := false
gameStatusClickSnapshotWasLastActive := false
gameStatusLastText := ""
gameStatusVisible := true
gameStatusDisplayOrder := []
gameStatusRobloxWasActive := false
gameStatusClickFocusHandoffPending := false
gameStatusTrackedHwnd := 0
gameStatusTrackedX := 0
gameStatusTrackedY := 0
gameStatusTrackedW := 0
gameStatusTrackedH := 0
gameStatusLastActiveRobloxHwnd := 0
gameStatusClickTraceEnabled := false
gameStatusPreMaxPlacements := Map()
gameStatusLastLayoutKey := ""
gameStatusLastGuiWidth := 0
gameStatusLastGuiHeight := 0
; Stable identity/row signatures used to trigger one hard repaint only after
; a completed scan confirms a game change or the Roblox window set changes.
gameStatusLastStableIdentityKey := ""
gameStatusLastStableRowTargetsKey := ""
; Latest rendered signatures. Stable values are committed only after the
; one-time game-status-toggle interaction/surface reset completes.
gameStatusCurrentIdentityKey := ""
gameStatusCurrentRowTargetsKey := ""
gameStatusMoveSizeEndHook := 0
gameStatusLocationChangeHook := 0
gameStatusForegroundHook := 0
gameStatusMouseMoveHook := 0
gameStatusReorderHook := 0
gameStatusMouseMoveEventCallback := 0
gameStatusMouseMovePending := false
gameStatusForegroundEventCallback := 0
gameStatusLastForegroundWasRoblox := false
gameStatusAwaitingRobloxClick := false
gameStatusReturnClickPending := false
gameStatusReturnClickHwnd := 0
gameStatusReorderEventCallback := 0
gameStatusReorderRepairPending := false
gameStatusWindowRepairPending := false
gameStatusMoveSizeEndEventCallback := 0
gameStatusMoveSizeEndPending := false
gameStatusHoveredRowIndex := 0
gameStatusAllMiniHovered := false
; Hovering a row selects its Roblox client once per row transition.
; These fields preserve click-to-maximize/restore behavior after hover activation.
gameStatusAutoHoverHwnd := 0
gameStatusHoverSessionOriginHwnd := 0
gameStatusHoverSessionActive := false
; Selector position lock is independent from hover activation. It stays latched
; while the pointer is over the selector and releases when the pointer leaves.
gameStatusPointerLockActive := false
gameStatusPointerLockX := 0
gameStatusPointerLockY := 0
gameStatusPointerLockW := 0
gameStatusPointerLockH := 0
gameStatusTooltipText := ""
gameStatusTooltipRowIndex := 0
gameStatusTooltipX := -1
gameStatusTooltipY := -1


; ==========================================================
; Global Variables Initialization
; ==========================================================
lastActiveRobloxHwnd := 0
isToggle := false
; Script-owned LButton hold state. User physical holds are never released by the scheduler.
autoMouseHoldActive := false
mouseMacroMasterOn := true
mouseMacroMode := "HOLD"
mouseMacroActive := false
mouseMacroSuspendedByWindow := false
mouseMacroHeld := false
mouseMacroReleasing := false
mouseMacroPrevX := 0
mouseMacroPrevY := 0
mouseMacroIdleCounter := 0
mouseMacroResetCounter := 0
mouseMacroRapidToggle := false
mouseMacroRapidIntervalMs := 50 ; 10-1000 ms, 10 ms steps
mouseMacroRapidIntervalHoldDirection := 0
mouseMacroRapidIntervalHoldHwnd := 0
mouseMacroRapidIntervalClickHandledHwnd := 0
mouseMacroIndicatorGui := ""
mouseMacroIndicatorState := "OFF"

SendMode("Event")             ; Enforce mouse signal standard to Event mode


; ==========================================================
; 🔄 Roblox Connection Recovery State
; ==========================================================
connectionLogState := Map()
connectionRecoveryEnabled := false   ; F5 master switch for connection recovery
connectionLogWatchRunning := false
connectionRecoveryPending := false
connectionRecoveryPendingSince := 0
connectionRecoveryBusy := false
connectionRecoveryHwnd := 0
connectionRecoveryAttempts := 0
connectionRecoveryStableChecks := 0
connectionRecoveryNextTick := 0
connectionRecoveryStage := ""
connectionRecoveryOriginalForeground := 0
connectionRecoveryOriginalMinMax := 0
connectionRecoveryDiscoveredMinMax := 0
connectionRecoveryDetectedHwnd := 0
connectionRecoveryDetectedPid := 0
connectionRecoveryDetectedVerified := false
connectionRecoveryTargetPid := 0
; Capture the game title before reconnect changes the client/log identity.
connectionRecoveryGameName := ""
connectionRecoveryQueue := []
; Automatic modal recovery uses an HWND+PID queue and drains it sequentially.
connectionRecoveryAutoBatch := false
connectionRecoveryStartFailureCounts := Map()
connectionRecoveryNextDeepScanTick := 0

; Log-based automatic rejoin transaction. This is separate from the legacy
; modal/button recovery state so the existing detector can remain intact and
; be used by manual inspection/F6 without being part of automatic recovery.
logAutoRejoinBusy := false
logAutoRejoinStage := ""
logAutoRejoinTargetHwnd := 0
logAutoRejoinTargetPid := 0
logAutoRejoinPlaceId := ""
logAutoRejoinCode := ""
logAutoRejoinOriginalMinMax := 0
logAutoRejoinOriginalForeground := 0
logAutoRejoinOldPids := Map()
logAutoRejoinNewPid := 0
logAutoRejoinStartTick := 0
logAutoRejoinCloseDeadlineTick := 0
logAutoRejoinSpawnDeadlineTick := 0
logAutoRejoinJoinDeadlineTick := 0
logAutoRejoinPendingSince := 0
logAutoRejoinLastStepTick := 0
logAutoRejoinLaunchAttempts := 0
logAutoRejoinNextLaunchTick := 0
logAutoRejoinLastMessage := ""

; ==========================================================
; 🚨 277 Manual Confirmation Alert State
;    Detection never activates a hidden Roblox client automatically.
;    The user decides when to inspect and when to reconnect.
; ==========================================================
disconnectAlertGui := ""
disconnectAlertTitle := ""
disconnectAlertBody := ""
disconnectAlertPrimaryButton := ""
disconnectAlertDismissButton := ""
disconnectAlertF6Diag := ""
fixedPointModalDebugEnabled := false
fixedPointModalDebugTargetHwnd := 0
fixedPointModalDebugMarkers := []
fixedPointModalAutoHideTimerByIndex := Map()
fixedPointModalDebugForegroundHook := 0
fixedPointModalDebugLocationHook := 0
fixedPointModalDebugEventCallback := 0
fixedPointModalDebugOwnsAlert := false
fixedPointModalDebugLastHwnd := 0
fixedPointModalDebugPinned := false
fixedPointModalDebugPinnedHwnd := 0
fixedPointModalDebugPinnedResult := Map()
fixedPointModalDebugReconnectPending := false
fixedPointModalDebugReconnectHwnd := 0
fixedPointModalDebugLastConfirmedResult := Map()
fixedPointModalDebugRefreshPending := false
fixedPointModalDebugRefreshNeedsProbe := false
fixedPointModalDebugRefreshNeedsAlert := false
fixedPointModalDebugRefreshRunning := false
fixedPointModalDebugProbeTargetHwnd := 0
fixedPointModalDebugProbeRunning := false
fixedPointModalDebugProbeBusyHwnd := 0
fixedPointModalDebugAlertTargetHwnd := 0
fixedPointModalDebugAlertDeadline := 0
disconnectModalScaleCache := Map()
disconnectModalGeometryCache := Map()
disconnectModalProfileCache := Map()
disconnectModalDebugGeometry := ""
disconnectModalDiagScale := 0.0
disconnectModalDiagScaleAttempts := 0
disconnectModalDiagReadCount := 0
disconnectModalDiagElapsedMs := 0
disconnectAlertActive := false
disconnectAlertStage := ""
disconnectAlertLastTick := 0
disconnectAlertDetectedHwnd := 0
disconnectAlertReason := ""
disconnectAlertOriginalForeground := 0
; True only for the one-shot raise caused by a fresh alert update.
disconnectAlertRaisePending := false
; Hover/Z-order tracking state.  Reposition only when the Roblox target changes.
disconnectAlertHoverHwnd := 0
disconnectAlertHoverFullscreen := false
disconnectAlertHoverVisible := false
disconnectAlertPositionTargetHwnd := 0
disconnectAlertLastGeometryHwnd := 0
disconnectAlertLastGeometryKey := ""
disconnectAlertLastPaintKey := ""
disconnectAlertLastRecoveryAttempts := 0
disconnectAlertLastSuccessTime := ""
; Snapshot and timeline for the current disconnect -> modal -> reconnect transaction.
; These are in-memory only and do not change scanning/recovery timers.
disconnectIncidentStartTick := 0
disconnectIncidentDetectedTime := ""
disconnectIncidentReasonText := ""
disconnectIncidentCode := ""
disconnectIncidentLogPattern := ""
disconnectIncidentTimeline := []
; Manual inspection can start every confirmed client sequentially without extra clicks.
disconnectManualBatchReconnect := false
disconnectHiddenScanActive := false
disconnectHiddenScanIndex := 0
disconnectHiddenScanTotal := 0
disconnectHiddenScanCooldownUntil := 0
disconnectHiddenScanPending := false
disconnectHiddenScanLastMiss := false
disconnectLogSignalFiles := []
; Per-path generation lets scans consume only the log signal they actually inspected.
; A newer event from the same log remains queued if it arrives during a scan.
disconnectLogSignalVersions := Map()
disconnectLogSignalSequence := 0
; A log signal is provisional until we have waited for the game-managed restart
; and verified an actual same-Place-ID join in the new Roblox process.
disconnectGracePending := false
disconnectGraceStartTick := 0
disconnectGraceDeadlineTick := 0
disconnectGraceMaxDeadlineTick := 0
disconnectGracePlaceId := ""
disconnectGraceUserId := ""
disconnectGraceOriginalPid := 0
disconnectGraceOriginalPids := Map()
disconnectGraceTargetHwnd := 0
disconnectGraceTargetPid := 0
disconnectGraceSignalPath := ""
disconnectGraceCode := ""
; Snapshot of an already-visible reconnect-complete alert. A newly detected
; disconnect temporarily reuses that same GUI; restore this snapshot only if
; the log signal later proves to be a game-managed successful restart.
disconnectGracePreviousCompletedAlertState := Map()
; Per-PID one-shot latch for a current DISCONNECTED state discovered by the
; game-identity parser when the incremental recovery scanner missed/baselined it.
disconnectIdentitySignalHandledByPid := Map()
connectionPassiveScanNextTick := 0
disconnectHiddenScanCountdownRunning := false

; ==========================================================
; 🔎 277 detection diagnostics
; These values describe exactly what the current detector observed.
; They are display-only for now; detection thresholds remain unchanged.
; ==========================================================
disconnectAlertDetectionSource := ""
disconnectScreenDiagValid := false
disconnectScreenDiagPassed := false
disconnectScreenDarkCount := 0
disconnectScreenDarkTotal := 6
disconnectButtonDiagValid := false
disconnectButtonDiagPassed := false
disconnectButtonWhiteCount := 0
disconnectButtonWhiteTotal := 9
disconnectButtonDarkAroundCount := 0
disconnectButtonDarkAroundTotal := 4
disconnectButtonBandHits := 0
disconnectPrecisionPassed := false
disconnectPrecisionDifferentCount := 0
disconnectPrecisionDifferentTotal := 4
disconnectDiagTargetHwnd := 0
disconnectDiagTargetPid := 0
disconnectLogDiagSignal := false
disconnectLogDiagFreshSignal := false
disconnectLogDiagFile := ""
disconnectLogDiagPattern := ""
disconnectLogDiagCode := ""
disconnectDiagScanTime := ""
disconnectLogDiagFilesScanned := 0
disconnectLogDiagFilesChanged := 0
disconnectLogDiagFilesRead := 0
disconnectLogDiagReadErrors := 0
disconnectLogDiagBytesRead := 0
disconnectLogDiagNewFiles := 0
disconnectLogDiagOverlapChars := 0
disconnectLogDiagLastSignalTime := ""
; Log -> Roblox mapping / focus-probe diagnostics
disconnectLogDiagMappingState := ""
disconnectLogDiagMappedPids := ""
disconnectLogDiagMappedHwnds := ""
disconnectLogDiagFocusState := ""
disconnectLogDiagFocusHwnd := 0
disconnectLogDiagFocusPid := 0
disconnectLogDiagFocusTime := ""
; Reconnect click diagnostics (displayed inside the existing alert window)
disconnectClickAttempt := 0
disconnectClickTargetHwnd := 0
disconnectClickHitRoot := 0
disconnectClickHitProcess := ""
disconnectClickLastResult := ""

; Cumulative reconnect statistics (memory only; no external log file)
disconnectRecoveryTotalAttempts := 0
disconnectRecoveryTotalSuccesses := 0
disconnectRecoveryHistory := []
; Per-game history retains the current completion plus five previous timestamps.
disconnectRecoveryHistoryByGame := Map()
; Fallback recent history indexed by the exact Roblox HWND when the game title is unavailable.
disconnectRecoveryHistoryByHwnd := Map()
; Successful recoveries whose game identity is not resolved yet are held until
; the matching Roblox HWND can be identified when the monitor displays that game.
disconnectRecoveryPendingGameHistory := []
disconnectAlertLastSizeKey := ""

disconnectManualCheckBusy := false
disconnectManualCheckPending := false


; ==========================================================
; Status Window - Resolution Adaptive Settings
; ==========================================================
STATUS_BASE_W := 3840
STATUS_BASE_H := 2160
STATUS_BASE_WIDTH := 475
STATUS_BASE_HEIGHT := 60
STATUS_BASE_TOP_OFFSET := 0
STATUS_BASE_LEFT_OFFSET := 10

; Runtime status dimensions: safe defaults before any Roblox window exists.
STATUS_SCALE := 1.0
STATUS_W := STATUS_BASE_WIDTH
STATUS_H := STATUS_BASE_HEIGHT
STATUS_TOP_OFFSET := STATUS_BASE_TOP_OFFSET
STATUS_LEFT_OFFSET := STATUS_BASE_LEFT_OFFSET


; ==========================================================
; [Roblox Multi-Instance Guard]
;
; 정상적인 시작:
;   Roblox가 아직 없으면 ROBLOX_singletonEvent 이름을 Mutex로 선점합니다.
;
; Roblox가 이미 실행 중인 상태에서 AHK를 시작하거나 F7로 재로드한 경우:
;   1) 기존 Roblox가 가진 ROBLOX_singletonEvent 핸들을 먼저 닫고
;   2) 잠시 후 같은 이름을 Mutex로 선점합니다.
;
; IMPORTANT:
;   ROBLOX_singletonMutex는 만들지 않습니다.
;   이 가드는 ROBLOX_singletonEvent 이름 하나만 사용합니다.
; ==========================================================
robloxSingletonEventGuard := 0
robloxSingletonGuardLastError := 0
robloxSingletonGuardRetryCount := 0
robloxSingletonStartupNoticeMessage := ""
robloxSingletonStartupNoticeTitle := (Macro_GetWindowsUILanguage() = "ko") ? "Roblox 싱글톤" : "Roblox singleton protection"
robloxSingletonStartupNoticeIcon := 1

; [SingletonEvent Handle Release]
; Exact handle-closing method imported from Roblox_Web_MultiInstance_Test_v4_new.ahk.
F3_SINGLETON_PROCESS_DUP_HANDLE := 0x0040
F3_SINGLETON_DUPLICATE_CLOSE_SOURCE := 0x00000001
F3_SINGLETON_DUPLICATE_SAME_ACCESS := 0x00000002
F3_SINGLETON_SYSTEM_EXTENDED_HANDLE_INFORMATION := 0x40
F3_SINGLETON_OBJECT_NAME_INFORMATION := 1
F3_SINGLETON_STATUS_SUCCESS := 0x00000000
F3_SINGLETON_STATUS_INFO_LENGTH_MISMATCH := 0xC0000004
F3_SINGLETON_SELF_PROCESS := -1
F3_SINGLETON_BUSY := false

; If Roblox is already running, clear its real singletonEvent first.
; If not, claim the singletonEvent name immediately.
Roblox_InitializeSingletonGuard()
OnExit(Roblox_ReleaseSingletonGuards)
OnExit(Macro_CloseShortcutHelpOnExit)
OnExit(Macro_StopRobloxTitlebarLocationHook)
OnExit(Macro_StopRobloxTitlebarForegroundHook)
OnExit(Macro_DestroyRobloxTitlebarTooltip)
OnExit(MouseMacro_CloseIndicator)



; ==========================================================
; Original Mouse Position Storage
; ==========================================================
savedMouseX := 0, savedMouseY := 0, savedMouseValid := false
savedActiveRobloxHwnd := 0
statusRenderDirty := true

; ==========================================================
; ==========================================================
; F4/F5/F6/F8 belong to this script only while a Roblox client is foreground.
; F7 (reload) is intentionally global and is registered outside this context.
#HotIf WinActive("ahk_exe RobloxPlayerBeta.exe")
F4::MouseMacro_ToggleMaster()
~$F5::Macro_ToggleConnectionRecovery()
$F6:: {
    KeyWait("F6")
    Macro_ToggleFixedPointModalDebug()
}
~$F8::Macro_ToggleGameStatusGUI()
#HotIf

; F3 retains its original additional master-switch condition.
#HotIf mouseMacroMasterOn && MouseMacro_IsRobloxActive()
F3::MouseMacro_ToggleMode()
MButton::MouseMacro_ToggleActive()
#HotIf

#HotIf (mouseMacroMasterOn && mouseMacroActive && mouseMacroMode = "HOLD") || (mouseMacroReleasing && mouseMacroHeld)
$~LButton::MouseMacro_PhysicalLButton()
$~LButton Up::MouseMacro_PhysicalLButton()
#HotIf

; F7 intentionally remains global so the script can be reloaded from any app.
F7::Reload  ; F7 키를 누르면 스크립트가 다시 로드됩니다.
OnMessage(0x0021, Macro_OverlayMouseActivate)
OnMessage(0x0200, Macro_GameStatusMouseMove)
OnMessage(0x0084, Macro_OverlayHitTest)
; Restore the Roblox titlebar controls once after a settled foreground change.
; Keep the existing 100 ms tick temporarily as a safety net while validating
; the event-driven activation repair; geometry/DPI changes remain event-based.
OnMessage(0x007E, Macro_RobloxDisplayChange)  ; WM_DISPLAYCHANGE
OnMessage(0x02E0, Macro_RobloxDpiChanged)     ; WM_DPICHANGED
OnMessage(0x001A, Macro_RobloxSettingChange)  ; WM_SETTINGCHANGE
if (ROBLOX_TITLEBAR_CONTROLS_ENABLE) {
    SetTimer(Macro_RobloxTitlebarControlsTick, 100)
    Macro_StartRobloxTitlebarLocationHook()
    Macro_StartRobloxTitlebarForegroundHook()
}

; Keep only Roblox multi-instance windows out of the normal taskbar group.
; Other applications are not affected by this setting.
Macro_ApplyRobloxTaskbarGrouping()
SetTimer(Macro_ApplyRobloxTaskbarGrouping, 500)
; Keep the historical 1920px width for newly created Roblox windows, independent
; of whether the optional log-based reconnect path is enabled.
SetTimer(Macro_WatchNewRobloxWindows, 500)
Macro_WatchNewRobloxWindows()

; Start periodic maintenance for this script's diagnostic log only.
; Runs independently of F5, without touching Roblox/game logs.
Macro_CleanupDisconnectGraceLogs("", true)
SetTimer(Macro_CleanupDisconnectGraceLogsTimer, 6 * 60 * 60 * 1000)

; Start independent systems automatically at script launch.
Macro_ToggleConnectionRecovery()
Macro_ToggleGameStatusGUI()
MouseMacro_Initialize()
; Restart the pending singleton notice delay after the remaining startup alerts.
Roblox_DeferSingletonStartupNotice()

Roblox_InitializeSingletonGuard() {
    global robloxSingletonEventGuard, robloxSingletonGuardRetryCount
    global robloxSingletonGuardLastError

    ; Enumerate processes, not only visible top-level windows. A client can hold
    ; ROBLOX_singletonEvent before its window has appeared.
    robloxPids := Macro_GetRobloxPidsForSingleton()
    closedCount := Macro_ReleaseRobloxSingletonEvents(robloxPids)
    if (robloxPids.Length > 0 || closedCount > 0)
        Sleep(150)

    ; A successful handle is the definitive check. A zero close count alone is
    ; not failure: the object may already be absent or held by no Roblox client.
    if (Roblox_InstallSingletonGuards()) {
        isKorean := (Macro_GetWindowsUILanguage() = "ko")
        Roblox_QueueSingletonStartupNotice(isKorean
            ? "다중 실행 보호 확보 완료`nRoblox 프로세스: " . robloxPids.Length . "`n정리한 싱글톤 핸들: " . closedCount
            : "Multi-instance protection is active.`nRoblox processes: " . robloxPids.Length . "`nSingleton handles released: " . closedCount,
            isKorean ? "Roblox 싱글톤" : "Roblox singleton protection", 1)
        return true
    }

    ; Refresh the process list and repeat handle cleanup before each bounded retry.
    Loop 3 {
        retryNo := A_Index
        Sleep(150)
        robloxPids := Macro_GetRobloxPidsForSingleton()
        closedCount := Macro_ReleaseRobloxSingletonEvents(robloxPids)
        if (closedCount > 0)
            Sleep(100)

        if (Roblox_InstallSingletonGuards()) {
            robloxSingletonGuardRetryCount := retryNo
            isKorean := (Macro_GetWindowsUILanguage() = "ko")
            Roblox_QueueSingletonStartupNotice(isKorean
                ? "다중 실행 보호 확보 완료 (초기 재시도 " . retryNo . "/3)`nRoblox 프로세스: " . robloxPids.Length . "`n정리한 싱글톤 핸들: " . closedCount
                : "Multi-instance protection is active (startup retry " . retryNo . "/3).`nRoblox processes: " . robloxPids.Length . "`nSingleton handles released: " . closedCount,
                isKorean ? "Roblox 싱글톤" : "Roblox singleton protection", 1)
            return true
        }
    }

    isKorean := (Macro_GetWindowsUILanguage() = "ko")
    Roblox_QueueSingletonStartupNotice(isKorean
        ? "보호 확보 실패 · 재시도 중`nWin32 오류 코드: " . robloxSingletonGuardLastError . "`n2초 간격으로 재시도합니다."
        : "Could not activate multi-instance protection. Retrying...`nWin32 error code: " . robloxSingletonGuardLastError . "`nRetrying every 2 seconds.",
        isKorean ? "Roblox 싱글톤 경고" : "Roblox singleton protection warning", 3)
    SetTimer(Roblox_RetrySingletonGuard, 2000)
    return false
}

; Delay the initial result so later startup TrayTips (for example F5 recovery)
; do not immediately overwrite it. Any later retry success cancels this notice.
Roblox_QueueSingletonStartupNotice(message, title := "", icon := 1) {
    global robloxSingletonStartupNoticeMessage, robloxSingletonStartupNoticeTitle
    global robloxSingletonStartupNoticeIcon

    if (title = "")
        title := (Macro_GetWindowsUILanguage() = "ko") ? "Roblox 싱글톤" : "Roblox singleton protection"
    robloxSingletonStartupNoticeMessage := message
    robloxSingletonStartupNoticeTitle := title
    robloxSingletonStartupNoticeIcon := icon
    SetTimer(Roblox_ShowQueuedSingletonStartupNotice, -1800)
}

Roblox_DeferSingletonStartupNotice(*) {
    global robloxSingletonStartupNoticeMessage
    if (robloxSingletonStartupNoticeMessage != "")
        SetTimer(Roblox_ShowQueuedSingletonStartupNotice, -1800)
}

Roblox_ShowQueuedSingletonStartupNotice(*) {
    global robloxSingletonStartupNoticeMessage, robloxSingletonStartupNoticeTitle
    global robloxSingletonStartupNoticeIcon

    if (robloxSingletonStartupNoticeMessage = "")
        return
    TrayTip(robloxSingletonStartupNoticeMessage, robloxSingletonStartupNoticeTitle,
        robloxSingletonStartupNoticeIcon)
    robloxSingletonStartupNoticeMessage := ""
}

Roblox_InstallSingletonGuards() {
    global robloxSingletonEventGuard, robloxSingletonGuardLastError

    ; If this script already owns a valid handle, keep it instead of opening
    ; another handle to the same named object.
    if (robloxSingletonEventGuard)
        return true

    ; IMPORTANT: ROBLOX_singletonMutex is intentionally NOT used.
    ; A Mutex with this exact name intentionally conflicts with Roblox's Event.
    try {
        DllCall("kernel32\SetLastError", "UInt", 0)
        h := DllCall("kernel32\CreateMutexW"
            , "Ptr", 0
            , "Int", 1
            , "WStr", "ROBLOX_singletonEvent"
            , "Ptr")
        createError := A_LastError

        if (h) {
            robloxSingletonEventGuard := h
            robloxSingletonGuardLastError := createError
            return true
        }

        robloxSingletonGuardLastError := createError
    } catch {
        robloxSingletonGuardLastError := A_LastError
    }

    robloxSingletonEventGuard := 0
    return false
}

Roblox_RetrySingletonGuard(*) {
    global robloxSingletonEventGuard, robloxSingletonGuardRetryCount
    global robloxSingletonGuardLastError
    global robloxSingletonStartupNoticeMessage

    if (Roblox_IsSingletonGuardHandleValid()) {
        SetTimer(Roblox_RetrySingletonGuard, 0)
        return
    }

    robloxSingletonGuardRetryCount += 1
    pids := Macro_GetRobloxPidsForSingleton()
    closedCount := Macro_ReleaseRobloxSingletonEvents(pids)
    if (closedCount > 0)
        Sleep(100)

    if (Roblox_InstallSingletonGuards()) {
        SetTimer(Roblox_RetrySingletonGuard, 0)
        isKorean := (Macro_GetWindowsUILanguage() = "ko")
        Roblox_QueueSingletonStartupNotice(isKorean
            ? "백그라운드 재시도로 다중 실행 보호 확보 완료`n재시도 횟수: " . robloxSingletonGuardRetryCount . "`nRoblox 프로세스: " . pids.Length . "`n정리한 싱글톤 핸들: " . closedCount
            : "Multi-instance protection is active after a background retry.`nRetry count: " . robloxSingletonGuardRetryCount . "`nRoblox processes: " . pids.Length . "`nSingleton handles released: " . closedCount,
            isKorean ? "Roblox 싱글톤" : "Roblox singleton protection", 1)
        return
    }

    ; Keep the user informed through TrayTip without creating any log file.
    ; Notify once every five background retries (normally every 10 seconds).
    if (Mod(robloxSingletonGuardRetryCount, 5) = 0) {
        isKorean := (Macro_GetWindowsUILanguage() = "ko")
        TrayTip(isKorean
            ? "오류: 싱글톤 보호 확보 실패, 계속 재시도 중입니다.`n재시도 횟수: " . robloxSingletonGuardRetryCount . "`nWin32 오류 코드: " . robloxSingletonGuardLastError
            : "Could not activate multi-instance protection. Retrying...`nRetry count: " . robloxSingletonGuardRetryCount . "`nWin32 error code: " . robloxSingletonGuardLastError,
            isKorean ? "Roblox 싱글톤 경고" : "Roblox singleton protection warning", 3)
    }
}

Roblox_IsSingletonGuardHandleValid() {
    global robloxSingletonEventGuard, robloxSingletonGuardLastError

    if (!robloxSingletonEventGuard)
        return false

    flags := 0
    try {
        valid := DllCall("kernel32\GetHandleInformation", "Ptr", robloxSingletonEventGuard,
            "UInt*", &flags, "Int")
    } catch {
        valid := false
    }

    if (valid)
        return true

    ; The stored handle is stale/invalid. Clear it so the retry timer can
    ; recreate the named guard instead of treating a nonzero value as success.
    try DllCall("kernel32\CloseHandle", "Ptr", robloxSingletonEventGuard)
    robloxSingletonEventGuard := 0
    robloxSingletonGuardLastError := A_LastError
    return false
}

Roblox_NotifySingletonOnNewClient(hwnd, pid) {
    static notifiedPids := Map()

    if (pid <= 0 || notifiedPids.Has(pid))
        return
    notifiedPids[pid] := true

    isKorean := (Macro_GetWindowsUILanguage() = "ko")
    if (Roblox_IsSingletonGuardHandleValid()) {
        TrayTip(isKorean
            ? "새 Roblox 실행 감지`n싱글톤 보호 핸들이 유지되고 있습니다.`nPID: " . pid
            : "New Roblox client detected.`nMulti-instance protection is active.`nPID: " . pid,
            isKorean ? "Roblox 싱글톤 상태" : "Roblox singleton status", 1)
        return
    }

    ; Do not claim the guard is active merely because its variable was nonzero.
    ; Restart retry attempts if the handle has become invalid after startup.
    SetTimer(Roblox_RetrySingletonGuard, 2000)
    TrayTip(isKorean
        ? "새 Roblox 실행 감지`n보호 핸들 없음 · 다시 확보를 시도합니다.`nPID: " . pid
        : "New Roblox client detected.`nProtection handle is missing. Attempting to restore it.`nPID: " . pid,
        isKorean ? "Roblox 싱글톤 경고" : "Roblox singleton protection warning", 3)
}

Roblox_ReleaseSingletonGuards(*) {
    global robloxSingletonEventGuard

    SetTimer(Roblox_RetrySingletonGuard, 0)
    try {
        if (robloxSingletonEventGuard)
            DllCall("kernel32\CloseHandle", "Ptr", robloxSingletonEventGuard)
    } catch {
    }

    robloxSingletonEventGuard := 0
}

; Return the native HWND only while the Gui wrapper still owns a live window.
; IsObject() alone is insufficient because a destroyed Gui wrapper can remain
; assigned while reading its .Hwnd property raises "Gui has no window".
Macro_GetShortcutHelpHwnd() {
    global shortcutHelpGui

    if (!IsObject(shortcutHelpGui))
        return 0

    try {
        helpHwnd := shortcutHelpGui.Hwnd
    } catch {
        return 0
    }

    if (!helpHwnd)
        return 0

    try {
        if (!DllCall("user32\IsWindow", "Ptr", helpHwnd, "Int"))
            return 0
    } catch {
        return 0
    }

    return helpHwnd
}

Macro_CloseShortcutHelpOnExit(*) {
    global shortcutHelpGui
    helpHwnd := Macro_GetShortcutHelpHwnd()
    try {
        if (helpHwnd)
            shortcutHelpGui.Destroy()
    } catch {
    }
    shortcutHelpGui := ""
}

#HotIf WinActive("ahk_exe RobloxPlayerBeta.exe")

~*Esc::Macro_HandleShortcutHelpEscape()
#HotIf

; =====================================================================
; 🚨 [Emergency Reset] 매크로가 심하게 꼬였을 때 컴퓨터 재부팅 없이 1초 만에 푸는 구급 단축키
; =====================================================================
F9::Macro_EmergencyResetReload()

Macro_EmergencyResetReload() {
    BlockInput("MouseMoveOff")      ; 1) 마우스 강제 고정 락 풀기
    DllCall("ClipCursor", "Ptr", 0) ; 2) 화면 가장자리 마우스 갇힘 락 풀기

    ; 3) 기존 F9과 동일하게 물리/합성 마우스 버튼의 홀드 상태를 해제합니다.
    Click("Up"), Click("Up Right"), Click("Up Middle")
    DllCall("user32\mouse_event", "UInt", 0x0004, "UInt", 0, "UInt", 0, "UInt", 0, "Ptr", 0) ; 왼쪽 해제
    DllCall("user32\mouse_event", "UInt", 0x0010, "UInt", 0, "UInt", 0, "UInt", 0, "Ptr", 0) ; 오른쪽 해제
    DllCall("user32\mouse_event", "UInt", 0x0040, "UInt", 0, "UInt", 0, "UInt", 0, "Ptr", 0) ; 휠 해제

    isKorean := (Macro_GetWindowsUILanguage() = "ko")
    TrayTip(isKorean ? "매크로와 메모리를 완전히 초기화했습니다." : "The macro and memory have been completely cleared.",
        isKorean ? "🛡️ 시스템 초기화 완료 🛡️" : "🛡️ System Cleared 🛡️", 1)
    Sleep(300)
    Reload()
}

; =====================================================================
; Ctrl+F1 를 누르면 실행 중인 모든 로블록스 창을 차례대로 활성화
; =====================================================================

^F1::
{
    ; "Roblox" 제목을 가진 모든 창의 ID를 배열로 가져옵니다.
    roblox_windows := WinGetList("Roblox")
    
    ; 찾은 모든 창을 하나씩 순서대로 돌립니다.
    for this_id in roblox_windows
    {
        ; 각 창을 활성화합니다.
        WinActivate("ahk_id " this_id)
        ; 창이 완전히 켜질 수 있도록 0.05초 대기
        Sleep(50)
    }
}

; =====================================================================
; 🖥️ [Ctrl+F2 최종 정돈 마스터피스] 파일 선택 시 매크로 핫키 자체를 완벽히 마비시키는 차단막
; =====================================================================
; 🚨 [사용자님 대원칙 100% 강제 구현 - HotIf 커널단 제어막]
; 바탕화면(Progman/WorkerW)이나 파일 탐색기(CabinetWClass) 내부에서 
; 파일/폴더가 마우스로 선택되어 포커스가 잡혀 있는 상태일 때는 매크로의 Ctrl+F2 가동 권한을 아예 박살내어 마비시킵니다.
; 이 조건에 걸리면 매크로의 Ctrl+F2는 없는 키가 되므로, 물결(~) 기호와 함께 윈도우 이름 바꾸기가 100% 칼같이 구동됩니다.
#HotIf !WinActive("ahk_class CabinetWClass") && !WinActive("ahk_class Progman") && !WinActive("ahk_class WorkerW")
~^F2::
{
    targetHwnd := 0
    MouseGetPos(,, &mouseOverHwnd)

    ; 🚨 [안전장치 1순위 - 마우스 밑 최우선 가로채기 원칙]
    if (mouseOverHwnd && WinExist("ahk_id " . mouseOverHwnd)) {
        try {
            if (WinGetProcessName("ahk_id " . mouseOverHwnd) = "RobloxPlayerBeta.exe") {
                targetHwnd := mouseOverHwnd
            }
        } catch {
        }
    }

    ; 🚨 [안전장치 2순위 - 마우스가 다른 데 있다면: 마지막 활성화되었던 로블록스 고유 ID 호출]
    if (targetHwnd = 0) {
        global lastActiveRobloxHwnd
        targetHwnd := lastActiveRobloxHwnd
    }

    ; 만약 매크로를 방금 켜서 아직 아무런 기록이 없다면, 현재 존재하는 로블록스 창 중 하나를 백업으로 잡습니다.
    if (targetHwnd = 0 || !WinExist("ahk_id " . targetHwnd)) {
        try {
            robloxList := WinGetList("ahk_exe RobloxPlayerBeta.exe")
            for hwnd in robloxList {
                if (WinExist("ahk_id " . hwnd) && WinGetMinMax("ahk_id " . hwnd) != -1) {
                    targetHwnd := hwnd
                    break 
                }
            }
        } catch {
            targetHwnd := 0
        }
    }

    ; 🎯 최종 마스터 타겟팅 로블록스 윈도우 최대화 ↔ 복원 토글 실행
    if (targetHwnd && WinExist("ahk_id " . targetHwnd)) {
        try {
            minMaxState := WinGetMinMax("ahk_id " . targetHwnd)
            if (minMaxState = 1) {
                DllCall("user32\PostMessage", "Ptr", targetHwnd, "UInt", 0x0112, "Ptr", 0xF120, "Ptr", 0)
            } else if (minMaxState = 0) {
                DllCall("user32\PostMessage", "Ptr", targetHwnd, "UInt", 0x0112, "Ptr", 0xF030, "Ptr", 0)
                WinActivate("ahk_id " . targetHwnd)
            }
        } catch {
        }
    }
}
#HotIf ; 💡 핫키 조건 영역을 안전하게 닫아 다른 단축키에 간섭하지 않도록 방어막 마감


; =====================================================================
; 🖱️ Global click helpers
; =====================================================================
~*LButton::Macro_GlobalLButton()
~*LButton Up::Macro_GlobalLButtonUp()

Macro_GlobalLButton() {
    MouseMacro_RapidIntervalPhysicalDown()
    Macro_BeginGameStatusClick()

    ; Close shortcut help only when the actual Roblox window is clicked.
    ; Moving/hovering over the help panel never closes it.
    if (Macro_HandleShortcutHelpRobloxClick())
        return

    Macro_HandleDisconnectAlertUserClick()
}

Macro_GlobalLButtonUp() {
    MouseMacro_RapidIntervalPhysicalUp()
    Macro_EndGameStatusClick()
}

; =====================================================================



Macro_GetMonitorFromWindow(hwnd) {
    if (!WinExist("ahk_id " . hwnd))
        return 0
    try
        WinGetPos(&winX, &winY, &winW, &winH, "ahk_id " . hwnd)
    catch
        return 0

    centerX := winX + (winW // 2)
    centerY := winY + (winH // 2)
    Loop MonitorGetCount() {
        monitorIndex := A_Index
        try MonitorGet(monitorIndex, &monitorLeft, &monitorTop, &monitorRight, &monitorBottom)
        catch
            continue
        if (centerX >= monitorLeft && centerX < monitorRight && centerY >= monitorTop && centerY < monitorBottom)
            return monitorIndex
    }
    return 0
}

Macro_GetRobloxWindowMode(hwnd) {
    if (!WinExist("ahk_id " . hwnd))
        return 0

    ; Respect Windows' explicit state before using monitor coverage to detect
    ; borderless fullscreen. A maximized Roblox window can cover the whole
    ; monitor (especially when the taskbar is on another display); classifying
    ; it as fullscreen bypasses the selector's maximize/restore click rules.
    try minMax := WinGetMinMax("ahk_id " . hwnd)
    catch
        return 1
    if (minMax = -1)
        return 0
    if (minMax = 1)
        return 2

    try WinGetPos(&winX, &winY, &winW, &winH, "ahk_id " . hwnd)
    catch
        return 1

    monitorIndex := Macro_GetMonitorFromWindow(hwnd)
    if (monitorIndex) {
        try {
            MonitorGet(monitorIndex, &monLeft, &monTop, &monRight, &monBottom)
            monW := monRight - monLeft
            monH := monBottom - monTop
            ; True/borderless fullscreen can report a few pixels differently
            ; depending on the Roblox renderer, DPI and display driver.
            ; Require near-complete monitor coverage so a normal maximized window
            ; is not mistaken for fullscreen.
            if (winW >= Round(monW * 0.985)
                && winH >= Round(monH * 0.985)
                && Abs(winX - monLeft) <= 15
                && Abs(winY - monTop) <= 15)
                return 3
        } catch {
        }
    }

    return 1
}













; =====================================================================
; 🕒 [Current time formatter] Used by connection/recovery diagnostics.
; =====================================================================
Macro_Format12HourCurrentTime(dateTime) {
    hour := Integer(SubStr(dateTime, 9, 2))
    minute := Integer(SubStr(dateTime, 11, 2))
    ampm := (hour >= 12) ? "pm" : "am"
    displayH := Mod(hour, 12)
    if (displayH = 0)
        displayH := 12
    return ampm . " " . Format("{:02}", displayH) . ":" . Format("{:02}", minute)
}

; ===========================================================================================
; 🎨 [최종 마감] 상태창 실시간 호버 감지 및 딜레이 중 분홍색 배경 유지 가로채기 엔진
; ===========================================================================================



Macro_IsRobloxActuallyOccluded(hwnd, robloxX, robloxY, robloxW, robloxH, excludeHwnd1 := 0, excludeHwnd2 := 0) {
    ; ---------------------------------------------------------------
    ; 실제 화면 hit-test 기반 Roblox 가림 판정
    ;
    ; 비활성 Roblox에 대해서만 호출된다.
    ; Roblox보다 Z-order가 앞선 창 중 실제 화면에서 Roblox 영역과
    ; 교차하는 창이 있는지를 확인한다. 단순 bounding-box 교차만으로
    ; 판정하지 않고 교차 영역의 실제 WindowFromPoint 결과를 확인한다.
    ; ---------------------------------------------------------------
    if (!hwnd || robloxW <= 0 || robloxH <= 0)
        return false

    try {
        if (WinActive("ahk_id " . hwnd) = hwnd)
            return false
    } catch {
    }

    try {
        if (WinGetMinMax("ahk_id " . hwnd) = -1)
            return false
    } catch {
        return false
    }

    robloxRight := robloxX + robloxW
    robloxBottom := robloxY + robloxH
    myPid := DllCall("GetCurrentProcessId", "UInt")

    try {
        otherHwnd := DllCall("user32\GetTopWindow", "Ptr", 0, "Ptr")
    } catch {
        return false
    }

    while (otherHwnd) {
        if (otherHwnd = hwnd)
            break

        skipWindow := (otherHwnd = excludeHwnd1 || otherHwnd = excludeHwnd2)

        ; AHK 자체 창은 가림 창에서 제외.
        if (!skipWindow) {
            otherPid := 0
            try {
                DllCall(
                    "user32\GetWindowThreadProcessId",
                    "Ptr", otherHwnd,
                    "UInt*", &otherPid
                )
            } catch {
                otherPid := 0
            }
            if (otherPid && otherPid = myPid)
                skipWindow := true
        }

        ; 다른 Roblox 창도 실제 화면에서 대상 Roblox를 가리고 있다면
        ; 가림 창으로 취급한다. 직접 확인에서는 이 경우 대상 창을
        ; 활성화하여 실제 화면을 만든 뒤 검사해야 한다.

        ; 작업표시줄/바탕화면 shell 창은 응용 프로그램 가림으로 취급하지 않는다.
        if (!skipWindow) {
            try {
                cls := WinGetClass("ahk_id " . otherHwnd)
                if (cls = "Shell_TrayWnd" || cls = "Shell_SecondaryTrayWnd"
                    || cls = "Progman" || cls = "WorkerW")
                    skipWindow := true
            } catch {
            }
        }

        if (!skipWindow) {
            visible := false
            try {
                visible := !!DllCall("user32\IsWindowVisible", "Ptr", otherHwnd)
            } catch {
                visible := false
            }

            if (visible) {
                minimized := false
                try {
                    minimized := (WinGetMinMax("ahk_id " . otherHwnd) = -1)
                } catch {
                    minimized := false
                }

                if (!minimized) {
                    cloaked := false
                    try {
                        cloakState := 0
                        hr := DllCall(
                            "dwmapi\\DwmGetWindowAttribute",
                            "Ptr", otherHwnd,
                            "UInt", 14, ; DWMWA_CLOAKED
                            "UInt*", &cloakState,
                            "UInt", 4,
                            "Int"
                        )
                        if (hr = 0 && cloakState != 0)
                            cloaked := true
                    } catch {
                        cloaked := false
                    }

                    if (!cloaked) {
                        ox := 0, oy := 0, ow := 0, oh := 0
                        try {
                            WinGetPos(&ox, &oy, &ow, &oh, "ahk_id " . otherHwnd)
                        } catch {
                            ow := 0
                            oh := 0
                        }

                        if (ow > 0 && oh > 0) {
                            otherRight := ox + ow
                            otherBottom := oy + oh

                            left := Max(ox, robloxX)
                            top := Max(oy, robloxY)
                            right := Min(otherRight, robloxRight)
                            bottom := Min(otherBottom, robloxBottom)

                            if (left < right && top < bottom) {
                                ; 교차 영역에서 실제 화면에 존재하는 점을 확인한다.
                                midX := (left + right) // 2
                                midY := (top + bottom) // 2

                                pointsX := [
                                    midX,
                                    left,
                                    right - 1,
                                    midX,
                                    midX,
                                    left,
                                    right - 1,
                                    left,
                                    right - 1
                                ]
                                pointsY := [
                                    midY,
                                    top,
                                    top,
                                    top,
                                    bottom - 1,
                                    bottom - 1,
                                    bottom - 1,
                                    midY,
                                    midY
                                ]

                                Loop 9 {
                                    px := pointsX[A_Index]
                                    py := pointsY[A_Index]

                                    hitHwnd := 0
                                    try {
                                        ; POINT 구조체는 x/y 두 32-bit 값으로 전달한다.
                                        point := Buffer(8, 0)
                                        NumPut("Int", px, point, 0)
                                        NumPut("Int", py, point, 4)
                                        hitHwnd := DllCall(
                                            "user32\WindowFromPoint",
                                            "Ptr", point.Ptr,
                                            "Ptr"
                                        )
                                    } catch {
                                        hitHwnd := 0
                                    }

                                    if (!hitHwnd)
                                        continue

                                    rootHwnd := hitHwnd
                                    try {
                                        rootCandidate := DllCall(
                                            "user32\GetAncestor",
                                            "Ptr", hitHwnd,
                                            "UInt", 2, ; GA_ROOT
                                            "Ptr"
                                        )
                                        if (rootCandidate)
                                            rootHwnd := rootCandidate
                                    } catch {
                                    }

                                    if (rootHwnd = hwnd)
                                        continue
                                    if (rootHwnd = excludeHwnd1 || rootHwnd = excludeHwnd2)
                                        continue

                                    rootPid := 0
                                    try {
                                        DllCall(
                                            "user32\GetWindowThreadProcessId",
                                            "Ptr", rootHwnd,
                                            "UInt*", &rootPid
                                        )
                                    } catch {
                                        rootPid := 0
                                    }

                                    if (rootPid && rootPid = myPid)
                                        continue

                                    try {
                                        if (WinGetProcessName("ahk_id " . rootHwnd) = "RobloxPlayerBeta.exe")
                                            continue
                                    } catch {
                                    }

                                    ; 실제 화면에서 대상 Roblox가 아닌 외부 창이 반환되었다.
                                    return true
                                }
                            }
                        }
                    }
                }
            }
        }

        try {
            otherHwnd := DllCall(
                "user32\GetWindow",
                "Ptr", otherHwnd,
                "UInt", 2, ; GW_HWNDNEXT
                "Ptr"
            )
        } catch {
            otherHwnd := 0
        }
    }

    return false
}



; =====================================================================
; 🎮 [RNG Heroes Game Identity Engine]
; Roblox 로그 안의 실제 window/HWND와 Joining game의 Place ID를 연결합니다.
; 이 시스템은 기존 connectionLogState / reconnect 시스템과 분리되어 있습니다.
; =====================================================================
Macro_CreateGameStatusGUI(showNow := true) {
    global gameStatusGui, gameStatusText, gameStatusBackgroundCtrl, gameStatusRows, gameStatusRowTargets, gameStatusLastText, gameStatusVisible
    global gameStatusRenderedRowTargets
    global gameStatusLoadingText, gameStatusAllMiniCtrl, gameStatusSeparators
    global gameStatusLastLayoutKey, gameStatusLastGuiWidth, gameStatusLastGuiHeight
    global gameStatusLastStableIdentityKey, gameStatusLastStableRowTargetsKey
    global gameStatusCurrentIdentityKey, gameStatusCurrentRowTargetsKey

    if (IsObject(gameStatusGui)) {
        try {
            if (gameStatusGui.Hwnd && WinExist("ahk_id " . gameStatusGui.Hwnd)) {
                gameStatusVisible := showNow
                if (showNow) {
                    gameStatusGui.Show("NoActivate")
                    Macro_StartGameStatusZOrderWatch()
                } else {
                    gameStatusGui.Hide()
                    Macro_StopGameStatusZOrderWatch()
                }
                return
            }
        } catch {
        }
    }

    try {
        ; foreground, then back in the regular band when focus leaves Roblox.
        gameStatusGui := Gui("-Caption +ToolWindow", "Roblox Game Status")
        gameStatusGui.BackColor := "1D1D1D"
        gameStatusGui.SetFont("s10 cFFFFFF", "Segoe UI")

        ; Give the layered GUI an explicit solid client surface. Text controls
        ; are transparent, so repainting this surface prevents stale glyphs
        ; when a game name changes length.
        gameStatusBackgroundCtrl := gameStatusGui.AddText("x0 y0 w1 h1 Background1D1D1D", "")
        ; SS_NOTIFY (0x100) makes the full panel surface send WM_COMMAND/STN_CLICKED,
        ; so blank padding remains a real, reliable click target.
        gameStatusBackgroundCtrl.Opt("+0x100")

        ; This tiny control is retained for the existing display/validity checks.
        gameStatusText := gameStatusGui.AddText("x0 y0 w1 h1 cFFFFFF", "")
        gameStatusText.Opt("-0x200")
        gameStatusLoadingText := gameStatusGui.AddText("x8 y5 w214 h20 cFFFFFF +0x200", "")
        gameStatusLoadingText.Opt("+0x100")
        gameStatusLoadingText.Visible := false
        gameStatusRows := []
        gameStatusSeparators := []
        gameStatusAllMiniCtrl := gameStatusGui.AddText("x0 y5 w1 h20 cFFFFFF", Macro_GetGameSelectorUIText("restoreAll"))
        gameStatusAllMiniCtrl.Opt("+0x100")
        gameStatusAllMiniCtrl.Visible := false
        gameStatusRowTargets := []
        gameStatusRenderedRowTargets := []
        OnMessage(0x0021, Macro_GameStatusMouseActivate)
        gameStatusVisible := showNow
        if (showNow)
            gameStatusGui.Show("x10 y10 w180 h32 NoActivate")
        else
            gameStatusGui.Hide()
        if (showNow)
            Macro_StartGameStatusZOrderWatch()
        else
            Macro_StopGameStatusZOrderWatch()
        ; Keep the original lightly translucent appearance while the selector
        ; recovery path is diagnosed.
        try WinSetTransparent(225, "ahk_id " . gameStatusGui.Hwnd)
        gameStatusLastText := ""
        gameStatusLastLayoutKey := ""
        gameStatusLastGuiWidth := 0
        gameStatusLastGuiHeight := 0
        gameStatusLastStableIdentityKey := ""
        gameStatusLastStableRowTargetsKey := ""
        gameStatusCurrentIdentityKey := ""
        gameStatusCurrentRowTargetsKey := ""
    } catch {
        gameStatusGui := ""
        gameStatusText := ""
        gameStatusBackgroundCtrl := ""
        gameStatusLoadingText := ""
        gameStatusRows := []
        gameStatusSeparators := []
        gameStatusAllMiniCtrl := ""
        gameStatusRowTargets := []
        gameStatusRenderedRowTargets := []
    }
}

Macro_ShowGameStatusLoading() {
    global gameStatusGui, gameStatusLoadingText, gameStatusVisible
    global gameStatusTrackedHwnd, gameStatusLastActiveRobloxHwnd
    global gameStatusLastGuiHeight

    if (!IsObject(gameStatusGui) || !gameStatusGui.Hwnd)
        Macro_CreateGameStatusGUI(false)
    if (!IsObject(gameStatusGui) || !gameStatusGui.Hwnd || !IsObject(gameStatusLoadingText))
        return

    loadingActiveRobloxHwnd := 0
    try loadingActiveRobloxHwnd := Macro_GetGameStatusForegroundRobloxHwnd()
    catch
        loadingActiveRobloxHwnd := 0

    if (loadingActiveRobloxHwnd && WinExist("ahk_id " . loadingActiveRobloxHwnd)) {
        gameStatusTrackedHwnd := loadingActiveRobloxHwnd
        gameStatusLastActiveRobloxHwnd := loadingActiveRobloxHwnd
    } else if (gameStatusLastActiveRobloxHwnd && WinExist("ahk_id " . gameStatusLastActiveRobloxHwnd)) {
        gameStatusTrackedHwnd := gameStatusLastActiveRobloxHwnd
    } else if (gameStatusTrackedHwnd && WinExist("ahk_id " . gameStatusTrackedHwnd)) {
        ; Keep the already selected Roblox window.
    } else {
        gameStatusTrackedHwnd := 0
        try {
            robloxList := WinGetList("ahk_exe RobloxPlayerBeta.exe")
            if (robloxList.Length) {
                gameStatusTrackedHwnd := robloxList[1]
                gameStatusLastActiveRobloxHwnd := gameStatusTrackedHwnd
            }
        } catch {
            gameStatusTrackedHwnd := 0
        }
    }

    ; Match the initial loading frame to the active client's mode as well,
    ; instead of briefly showing a 32px strip before the compact row layout.
    loadingFullscreen := false
    if (gameStatusTrackedHwnd && WinExist("ahk_id " . gameStatusTrackedHwnd)) {
        try loadingFullscreen := (Macro_GetRobloxWindowMode(gameStatusTrackedHwnd) = 3)
        catch
            loadingFullscreen := false
    }
    if (loadingFullscreen) {
        loadingHeight := 24
        loadingTextY := 0
        loadingTextH := 24
    } else {
        loadingHeight := 32
        loadingTextY := 5
        loadingTextH := 20
    }

    gameStatusVisible := true
    gameStatusLoadingText.Text := Macro_GetGameSelectorUIText("searchingLogs")
    gameStatusLoadingText.Visible := true
    gameStatusLoadingText.Move(8, loadingTextY, 214, loadingTextH)
    gameStatusGui.Show("w230 h" . loadingHeight . " NoActivate")
    Macro_StartGameStatusZOrderWatch()
    ; Replace the temporary card with one Checking... row per Roblox window
    ; immediately. The asynchronous log pass fills in the game names as it runs.
    Macro_UpdateGameStatusDisplay()
    if (gameStatusTrackedHwnd)
        Macro_SyncGameStatusPosition()
}

Macro_HideGameStatusGUI() {
    global gameStatusGui, gameStatusVisible
    global gameStatusClickFocusHandoffPending
    Macro_ResetGameStatusHoverSession()
    Macro_ResetGameStatusPointerLock()
    gameStatusClickFocusHandoffPending := false
    gameStatusVisible := false
    Macro_StopGameStatusZOrderWatch()
    try {
        if (IsObject(gameStatusGui))
            gameStatusGui.Hide()
    } catch {
    }
}

Macro_ReleaseRobloxSingletonEvents(pids := 0) {
    global F3_SINGLETON_BUSY

    if (F3_SINGLETON_BUSY)
        return 0

    if (!IsObject(pids))
        pids := Macro_GetRobloxPidsForSingleton()

    F3_SINGLETON_BUSY := true
    totalClosed := 0
    try {
        for pid in pids {
            try {
                closedForPid := Macro_CloseSingletonEventHandles(pid)
                totalClosed += closedForPid
            } catch {
            }
        }
    } catch {
    } finally {
        F3_SINGLETON_BUSY := false
    }

    return totalClosed
}

Macro_GetRobloxPidsForSingleton() {
    result := []
    seen := Map()

    ; WMI includes Roblox processes that have started but do not yet own a
    ; visible top-level window. Fall back/merge with WinGetList if WMI is unavailable.
    try {
        wmi := ComObjGet("winmgmts:")
        processSet := wmi.ExecQuery("SELECT ProcessId FROM Win32_Process WHERE Name = 'RobloxPlayerBeta.exe'")
        for proc in processSet {
            try {
                pid := proc.ProcessId + 0
                if (pid > 0 && !seen.Has(pid)) {
                    seen[pid] := true
                    result.Push(pid)
                }
            } catch {
            }
        }
    } catch {
    }

    ; Merge visible windows as a fallback and to cover any temporary WMI omissions.
    try list := WinGetList("ahk_exe RobloxPlayerBeta.exe")
    catch
        list := []

    for hwnd in list {
        try {
            pid := WinGetPID("ahk_id " . hwnd)
            if (pid > 0 && !seen.Has(pid)) {
                seen[pid] := true
                result.Push(pid)
            }
        } catch {
        }
    }

    return result
}

Macro_CloseSingletonEventHandles(pid) {
    global F3_SINGLETON_PROCESS_DUP_HANDLE, F3_SINGLETON_DUPLICATE_CLOSE_SOURCE
    global F3_SINGLETON_DUPLICATE_SAME_ACCESS
    global F3_SINGLETON_SYSTEM_EXTENDED_HANDLE_INFORMATION
    global F3_SINGLETON_OBJECT_NAME_INFORMATION
    global F3_SINGLETON_STATUS_SUCCESS, F3_SINGLETON_STATUS_INFO_LENGTH_MISMATCH
    global F3_SINGLETON_SELF_PROCESS

    sourceProcess := 0
    queryBuffer := 0
    closedCount := 0

    try {
        sourceProcess := DllCall(
            "kernel32\OpenProcess",
            "UInt", F3_SINGLETON_PROCESS_DUP_HANDLE,
            "Int", false,
            "UInt", pid,
            "Ptr"
        )

        if !sourceProcess
            return 0

        queryBufferSize := 0x200000

        Loop 8 {
            queryBuffer := Buffer(queryBufferSize, 0)
            returnLength := 0

            status := DllCall(
                "ntdll\NtQuerySystemInformation",
                "Int", F3_SINGLETON_SYSTEM_EXTENDED_HANDLE_INFORMATION,
                "Ptr", queryBuffer.Ptr,
                "UInt", queryBuffer.Size,
                "UInt*", &returnLength,
                "Int"
            )

            statusUnsigned := status & 0xFFFFFFFF

            if (statusUnsigned = F3_SINGLETON_STATUS_SUCCESS)
                break

            if (statusUnsigned = F3_SINGLETON_STATUS_INFO_LENGTH_MISMATCH) {
                queryBufferSize := Max(queryBufferSize * 2, returnLength + 0x10000)
                queryBuffer := 0
                continue
            }

            queryBuffer := 0
            return 0
        }

        if !IsObject(queryBuffer)
            return 0

        ptrSize := A_PtrSize
        entrySize := (ptrSize = 8) ? 40 : 24
        headerSize := ptrSize * 2

        handleCount := NumGet(queryBuffer, 0, "Ptr")
        if (handleCount <= 0 || handleCount > 5000000)
            return 0

        Loop handleCount {
            entryOffset := headerSize + ((A_Index - 1) * entrySize)

            ownerPid := NumGet(queryBuffer, entryOffset + ptrSize, "Ptr")
            if (ownerPid != pid)
                continue

            sourceHandleValue := NumGet(queryBuffer, entryOffset + (ptrSize * 2), "Ptr")
            if !sourceHandleValue
                continue

            duplicateHandle := 0

            if !DllCall(
                "kernel32\DuplicateHandle",
                "Ptr", sourceProcess,
                "Ptr", sourceHandleValue,
                "Ptr", F3_SINGLETON_SELF_PROCESS,
                "Ptr*", &duplicateHandle,
                "UInt", 0,
                "Int", false,
                "UInt", F3_SINGLETON_DUPLICATE_SAME_ACCESS,
                "Int"
            )
                continue

            try {
                name := Macro_QuerySingletonObjectName(duplicateHandle)

                if (name && InStr(StrLower(name), "roblox_singletonevent")) {
                    closeResult := DllCall(
                        "kernel32\DuplicateHandle",
                        "Ptr", sourceProcess,
                        "Ptr", sourceHandleValue,
                        "Ptr", 0,
                        "Ptr", 0,
                        "UInt", 0,
                        "Int", false,
                        "UInt", F3_SINGLETON_DUPLICATE_CLOSE_SOURCE,
                        "Int"
                    )

                    if closeResult
                        closedCount += 1
                }
            } finally {
                if duplicateHandle
                    DllCall("kernel32\CloseHandle", "Ptr", duplicateHandle)
            }
        }
    } catch {
    } finally {
        if sourceProcess
            DllCall("kernel32\CloseHandle", "Ptr", sourceProcess)
    }

    return closedCount
}

Macro_QuerySingletonObjectName(handle) {
    global F3_SINGLETON_OBJECT_NAME_INFORMATION, F3_SINGLETON_STATUS_SUCCESS
    global F3_SINGLETON_STATUS_INFO_LENGTH_MISMATCH

    if !handle
        return ""

    bufferSize := 0x1000

    Loop 6 {
        objectBuffer := Buffer(bufferSize, 0)
        returnLength := 0

        status := DllCall(
            "ntdll\NtQueryObject",
            "Ptr", handle,
            "Int", F3_SINGLETON_OBJECT_NAME_INFORMATION,
            "Ptr", objectBuffer.Ptr,
            "UInt", objectBuffer.Size,
            "UInt*", &returnLength,
            "Int"
        )

        statusUnsigned := status & 0xFFFFFFFF

        if (statusUnsigned = F3_SINGLETON_STATUS_SUCCESS) {
            nameLength := NumGet(objectBuffer, 0, "UShort")
            namePtr := NumGet(objectBuffer, A_PtrSize = 8 ? 8 : 4, "Ptr")

            if (nameLength > 0 && namePtr)
                return StrGet(namePtr, nameLength // 2, "UTF-16")

            return ""
        }

        if (statusUnsigned = F3_SINGLETON_STATUS_INFO_LENGTH_MISMATCH) {
            bufferSize := Max(bufferSize * 2, returnLength + 0x100)
            continue
        }

        return ""
    }

    return ""
}

Macro_ToggleGameStatusGUI() {
    global gameStatusGui, isToggle, gameStatusVisible, gameIdentityInitialScanComplete
    global gameIdentityScanPending, gameIdentityScanActive, gameIdentityScanQueue, gameIdentityScanIndex
    global gameStatusClickFocusHandoffPending

    createdNow := !IsObject(gameStatusGui) || !gameStatusGui.Hwnd
    if (createdNow)
        Macro_CreateGameStatusGUI(false)

    if (!IsObject(gameStatusGui) || !gameStatusGui.Hwnd)
        return

    if (!createdNow) {
        try {
            if (DllCall("user32\IsWindowVisible", "Ptr", gameStatusGui.Hwnd)) {
                Macro_ResetGameStatusHoverSession()
                Macro_ResetGameStatusPointerLock()
                gameStatusClickFocusHandoffPending := false
                gameStatusVisible := false
                gameStatusGui.Hide()
                Macro_StopGameStatusZOrderWatch()
                if (!isToggle) {
                    SetTimer(Macro_UpdateGameIdentityProgressive, 0)
                    gameIdentityScanPending := false
                    gameIdentityScanActive := false
                    gameIdentityScanQueue := []
                    gameIdentityScanIndex := 0
                }
                return
            }
        } catch {
        }
    }

    gameStatusVisible := true
    Macro_StartGameStatusZOrderWatch()
    if (!gameIdentityInitialScanComplete) {
        Macro_QueueGameIdentityScan(100)
        Macro_ShowGameStatusLoading()
    } else {
        ; Show cached game identities immediately. Reopening does not rescan logs.
        Macro_UpdateGameStatusDisplay()
        try {
            gameStatusGui.Show("NoActivate")
            Macro_SyncGameStatusPosition()
        }
    }
}

Macro_StartGameStatusZOrderWatch() {
    global gameStatusVisible
    if (gameStatusVisible) {
        Macro_StartGameStatusMoveSizeEndHook()
        Macro_StartGameStatusLocationChangeHook()
        Macro_StartGameStatusForegroundHook()
        Macro_StartGameStatusMouseMoveHook()
        Macro_StartGameStatusReorderHook()
        SetTimer(Macro_WatchGameStatusZOrder, -1)
        Macro_LogGameStatusOverlayState("watch-start")
    }
}

Macro_StopGameStatusZOrderWatch() {
    global gameStatusRobloxWasActive
    Macro_LogGameStatusOverlayState("watch-stop")
    SetTimer(Macro_WatchGameStatusZOrder, 0)
    Macro_StopGameStatusMouseMoveHook()
    Macro_StopGameStatusReorderHook()
    Macro_StopGameStatusForegroundHook()
    Macro_StopGameStatusMoveSizeEndHook()
    Macro_StopGameStatusLocationChangeHook()
    gameStatusRobloxWasActive := false
}

; Windows sends EVENT_SYSTEM_MOVESIZEEND once a top-level window has finished
; being moved or resized by the mouse. We use that single event instead of
; polling the Roblox geometry continuously, so the panel snaps into place
; immediately after the drag/resize operation completes.
Macro_StartGameStatusMoveSizeEndHook() {
    global gameStatusMoveSizeEndHook, gameStatusMoveSizeEndEventCallback

    if (gameStatusMoveSizeEndHook)
        return

    try {
        if (!gameStatusMoveSizeEndEventCallback)
            gameStatusMoveSizeEndEventCallback := CallbackCreate(Macro_GameStatusMoveSizeEndWinEventProc)

        gameStatusMoveSizeEndHook := DllCall(
            "user32\SetWinEventHook",
            "UInt", 0x000B, "UInt", 0x000B, ; EVENT_SYSTEM_MOVESIZEEND
            "Ptr", 0, "Ptr", gameStatusMoveSizeEndEventCallback,
            "UInt", 0, "UInt", 0, "UInt", 0, "Ptr"
        )
    } catch {
        gameStatusMoveSizeEndHook := 0
    }
}

Macro_StopGameStatusMoveSizeEndHook() {
    global gameStatusMoveSizeEndHook, gameStatusMoveSizeEndEventCallback
    global gameStatusMoveSizeEndPending

    try {
        if (gameStatusMoveSizeEndHook)
            DllCall("user32\UnhookWinEvent", "Ptr", gameStatusMoveSizeEndHook)
    } catch {
    }

    gameStatusMoveSizeEndHook := 0
    gameStatusMoveSizeEndPending := false
}

Macro_StartGameStatusLocationChangeHook() {
    global gameStatusLocationChangeHook, gameStatusMoveSizeEndEventCallback

    if (gameStatusLocationChangeHook)
        return

    try {
        if (!gameStatusMoveSizeEndEventCallback)
            gameStatusMoveSizeEndEventCallback := CallbackCreate(Macro_GameStatusMoveSizeEndWinEventProc)

        ; EVENT_OBJECT_LOCATIONCHANGE fires when a top-level window's screen
        ; rectangle changes, including maximize/restore and fullscreen transitions.
        gameStatusLocationChangeHook := DllCall(
            "user32\SetWinEventHook",
            "UInt", 0x800B, "UInt", 0x800B, ; EVENT_OBJECT_LOCATIONCHANGE
            "Ptr", 0, "Ptr", gameStatusMoveSizeEndEventCallback,
            "UInt", 0, "UInt", 0, "UInt", 0, "Ptr"
        )
    } catch {
        gameStatusLocationChangeHook := 0
    }
}
Macro_StartGameStatusForegroundHook() {
    global gameStatusForegroundHook, gameStatusForegroundEventCallback
    global gameStatusLastForegroundWasRoblox, gameStatusAwaitingRobloxClick

    if (gameStatusForegroundHook)
        return

    gameStatusLastForegroundWasRoblox := !!Macro_GetGameStatusForegroundRobloxHwnd()
    ; If the selector is enabled while another app is active, wait for a real
    ; click on Roblox before running the F8-equivalent refresh.
    gameStatusAwaitingRobloxClick := !gameStatusLastForegroundWasRoblox

    try {
        if (!gameStatusForegroundEventCallback)
            gameStatusForegroundEventCallback := CallbackCreate(Macro_GameStatusForegroundWinEventProc)

        ; Reconcile the selector as soon as Windows changes the foreground window.
        gameStatusForegroundHook := DllCall(
            "user32\SetWinEventHook",
            "UInt", 0x0003, "UInt", 0x0003, ; EVENT_SYSTEM_FOREGROUND
            "Ptr", 0, "Ptr", gameStatusForegroundEventCallback,
            "UInt", 0, "UInt", 0, "UInt", 0, "Ptr"
        )
    } catch {
        gameStatusForegroundHook := 0
    }
}

Macro_StopGameStatusForegroundHook() {
    global gameStatusForegroundHook, gameStatusWindowRepairPending
    global gameStatusLastForegroundWasRoblox, gameStatusAwaitingRobloxClick

    try {
        if (gameStatusForegroundHook)
            DllCall("user32\UnhookWinEvent", "Ptr", gameStatusForegroundHook)
    } catch {
    }
    gameStatusForegroundHook := 0
    gameStatusWindowRepairPending := false
    gameStatusLastForegroundWasRoblox := false
    gameStatusAwaitingRobloxClick := false
    SetTimer(Macro_RepairGameStatusAfterWindowEvent, 0)
}

Macro_StartGameStatusReorderHook() {
    global gameStatusReorderHook, gameStatusReorderEventCallback

    if (gameStatusReorderHook)
        return

    try {
        if (!gameStatusReorderEventCallback)
            gameStatusReorderEventCallback := CallbackCreate(Macro_GameStatusReorderWinEventProc)

        ; Coalesce global reorder notifications, then inspect the settled
        ; foreground HWND in a one-shot callback. No recurring timer is used.
        gameStatusReorderHook := DllCall(
            "user32\SetWinEventHook",
            "UInt", 0x8004, "UInt", 0x8004, ; EVENT_OBJECT_REORDER
            "Ptr", 0, "Ptr", gameStatusReorderEventCallback,
            "UInt", 0, "UInt", 0, "UInt", 0, "Ptr"
        )
    } catch {
        gameStatusReorderHook := 0
    }
}

Macro_StopGameStatusReorderHook() {
    global gameStatusReorderHook, gameStatusReorderRepairPending
    global gameStatusReorderEventCallback

    try {
        if (gameStatusReorderHook)
            DllCall("user32\UnhookWinEvent", "Ptr", gameStatusReorderHook)
    } catch {
    }
    gameStatusReorderHook := 0
    gameStatusReorderRepairPending := false
    SetTimer(Macro_RepairGameStatusAfterReorderEvent, 0)
}

Macro_GameStatusReorderWinEventProc(hWinEventHook, event, hwnd, idObject, idChild, idEventThread, dwmsEventTime) {
    global gameStatusVisible, gameStatusReorderRepairPending

    if (event != 0x8004 || idObject != 0 || idChild != 0 || !gameStatusVisible)
        return

    ; The reorder notification can arrive before Windows commits the new
    ; foreground HWND. Queue one coalesced pass and decide from the settled
    ; foreground state in the timer callback.
    if (!gameStatusReorderRepairPending) {
        gameStatusReorderRepairPending := true
        ; Let Windows finish committing the reorder, then reconcile once.
        SetTimer(Macro_RepairGameStatusAfterReorderEvent, -40)
    }
}

Macro_RepairGameStatusAfterReorderEvent() {
    global gameStatusVisible, gameStatusReorderRepairPending
    global gameStatusTrackedHwnd, gameStatusLastActiveRobloxHwnd, gameStatusGui

    gameStatusReorderRepairPending := false
    if (!gameStatusVisible)
        return

    activeHwnd := DllCall("user32\GetForegroundWindow", "Ptr")
    try {
        if (!activeHwnd || WinGetProcessName("ahk_id " . activeHwnd) != "RobloxPlayerBeta.exe")
            return
    } catch {
        return
    }

    if (Macro_UpdateGameStatusPointerLock()) {
        Macro_KeepGameStatusWindowAtLockedPosition()
        Macro_KeepGameStatusWindowAboveTrackedRoblox()
    } else {
        gameStatusTrackedHwnd := activeHwnd
        gameStatusLastActiveRobloxHwnd := activeHwnd

        try {
            if (IsObject(gameStatusGui) && gameStatusGui.Hwnd) {
                panelHwnd := gameStatusGui.Hwnd
                if (DllCall("user32\IsIconic", "Ptr", panelHwnd, "Int"))
                    DllCall("user32\ShowWindow", "Ptr", gameStatusGui.Hwnd, "Int", 4) ; SW_SHOWNOACTIVATE
                else if (!DllCall("user32\IsWindowVisible", "Ptr", panelHwnd, "Int"))
                    gameStatusGui.Show("NoActivate")

                panelExStyle := DllCall("user32\GetWindowLongPtrW", "Ptr", panelHwnd, "Int", -20, "Ptr")
                panelIsTopmost := ((panelExStyle & 0x00000008) != 0)
                activeAbovePanel := false
                zHwnd := DllCall("user32\GetWindow", "Ptr", panelHwnd, "UInt", 3, "Ptr")
                while (zHwnd) {
                    if (zHwnd = activeHwnd) {
                        activeAbovePanel := true
                        break
                    }
                    zHwnd := DllCall("user32\GetWindow", "Ptr", zHwnd, "UInt", 3, "Ptr")
                }

                needsRepair := (!panelIsTopmost || activeAbovePanel)
                if (needsRepair) {
                    Macro_SyncGameStatusPosition(activeHwnd)
                    DllCall("user32\RedrawWindow", "Ptr", panelHwnd,
                        "Ptr", 0, "Ptr", 0, "UInt", 0x0585)
                    DllCall("user32\UpdateWindow", "Ptr", panelHwnd)
                }
            }
        } catch {
        }
    }

    ; The titlebar buttons are a separate GUI window with their own target and
    ; stacking rules. Reconcile that surface from the same settled foreground
    ; event so one overlay cannot remain behind after the other is repaired.
    try Macro_RobloxTitlebarControlsTickCore()
    catch {
    }

    Macro_LogGameStatusOverlayState("reorder-repair")
}

Macro_StartGameStatusMouseMoveHook() {
    global gameStatusMouseMoveHook, gameStatusMouseMoveEventCallback

    if (gameStatusMouseMoveHook)
        return

    try {
        if (!gameStatusMouseMoveEventCallback)
            gameStatusMouseMoveEventCallback := CallbackCreate(Macro_GameStatusMouseMoveHookProc)
        moduleHandle := DllCall("kernel32\GetModuleHandleW", "Ptr", 0, "Ptr")
        gameStatusMouseMoveHook := DllCall(
            "user32\SetWindowsHookExW",
            "Int", 14, "Ptr", gameStatusMouseMoveEventCallback, ; WH_MOUSE_LL
            "Ptr", moduleHandle, "UInt", 0, "Ptr"
        )
    } catch {
        gameStatusMouseMoveHook := 0
    }
}

Macro_StopGameStatusMouseMoveHook() {
    global gameStatusMouseMoveHook, gameStatusMouseMovePending
    global gameStatusReturnClickPending, gameStatusReturnClickHwnd

    try {
        if (gameStatusMouseMoveHook)
            DllCall("user32\UnhookWindowsHookEx", "Ptr", gameStatusMouseMoveHook)
    } catch {
    }
    gameStatusMouseMoveHook := 0
    gameStatusMouseMovePending := false
    gameStatusReturnClickPending := false
    gameStatusReturnClickHwnd := 0
    SetTimer(Macro_RepairGameStatusAfterMouseMove, 0)
    SetTimer(Macro_RepairGameStatusAfterReturnClick, 0)
}

Macro_GameStatusMouseMoveHookProc(nCode, wParam, lParam) {
    global gameStatusMouseMoveHook, gameStatusVisible, gameStatusMouseMovePending
    global gameStatusAwaitingRobloxClick, gameStatusReturnClickPending, gameStatusReturnClickHwnd

    if (nCode >= 0 && wParam = 0x0200 && gameStatusVisible && !gameStatusMouseMovePending) {
        gameStatusMouseMovePending := true
        SetTimer(Macro_RepairGameStatusAfterMouseMove, -15)
    }

    ; Ignore hover activation. Only a physical left-button press whose hit-test
    ; target is a Roblox window may request the one-time return refresh.
    if (nCode >= 0 && wParam = 0x0201 && gameStatusVisible
        && !(NumGet(lParam, 12, "UInt") & 0x00000001) ; Ignore injected clicks
        && gameStatusAwaitingRobloxClick && !gameStatusReturnClickPending) {
        clickX := NumGet(lParam, 0, "Int")
        clickY := NumGet(lParam, 4, "Int")
        Macro_GetWindowRootAtPoint(clickX, clickY, &clickedRoot, &clickedProcess)
        if (clickedRoot && clickedProcess = "RobloxPlayerBeta.exe") {
            gameStatusReturnClickHwnd := clickedRoot
            gameStatusReturnClickPending := true
            SetTimer(Macro_RepairGameStatusAfterReturnClick, -80)
        }
    }

    return DllCall("user32\CallNextHookEx", "Ptr", gameStatusMouseMoveHook,
        "Int", nCode, "Ptr", wParam, "Ptr", lParam, "Ptr")
}

Macro_RepairGameStatusAfterMouseMove() {
    global gameStatusVisible, gameStatusMouseMovePending, gameStatusGui
    gameStatusMouseMovePending := false
    if (!gameStatusVisible)
        return
    try Macro_WatchGameStatusZOrder()
    catch {
    }

    panelHwnd := 0
    try {
        if (IsObject(gameStatusGui))
            panelHwnd := gameStatusGui.Hwnd
    } catch {
        panelHwnd := 0
    }
    needsRepaint := false
    if (panelHwnd && WinExist("ahk_id " . panelHwnd)) {
        try {
            if (DllCall("user32\IsIconic", "Ptr", panelHwnd, "Int")) {
                DllCall("user32\ShowWindow", "Ptr", panelHwnd, "Int", 4) ; SW_SHOWNOACTIVATE
                needsRepaint := true
            } else if (!DllCall("user32\IsWindowVisible", "Ptr", panelHwnd)) {
                gameStatusGui.Show("NoActivate")
                needsRepaint := true
            }
        } catch {
        }

        ; Run a direct position/Z-order reconciliation after the watcher. This
        ; is still event-driven: one pass follows a mouse-move burst.
        try Macro_SyncGameStatusPosition()
        catch {
        }

        if (needsRepaint) {
            try {
                DllCall("user32\RedrawWindow", "Ptr", panelHwnd,
                    "Ptr", 0, "Ptr", 0, "UInt", 0x0585)
                DllCall("user32\UpdateWindow", "Ptr", panelHwnd)
            } catch {
            }
        }
    }
    Macro_LogGameStatusOverlayState("mouse-repair")
}

Macro_RepairGameStatusAfterReturnClick() {
    global gameStatusVisible, gameStatusAwaitingRobloxClick
    global gameStatusReturnClickPending, gameStatusReturnClickHwnd
    global gameStatusTrackedHwnd, gameStatusLastActiveRobloxHwnd

    gameStatusReturnClickPending := false
    clickedHwnd := gameStatusReturnClickHwnd
    gameStatusReturnClickHwnd := 0
    if (!gameStatusVisible || !gameStatusAwaitingRobloxClick || !clickedHwnd)
        return

    ; Confirm that the physical click actually activated the Roblox window it
    ; hit. If the focus did not settle there, keep waiting for the next click.
    foregroundHwnd := Macro_GetGameStatusForegroundRobloxHwnd()
    if (!foregroundHwnd || foregroundHwnd != clickedHwnd)
        return

    gameStatusAwaitingRobloxClick := false
    gameStatusTrackedHwnd := foregroundHwnd
    gameStatusLastActiveRobloxHwnd := foregroundHwnd
    Macro_HideGameStatusGUI()
    Macro_ToggleGameStatusGUI()
    Macro_LogGameStatusOverlayState("foreground-click-return-toggle")
}

Macro_LogGameStatusOverlayState(reason) {
    global gameStatusVisible, gameStatusGui, gameStatusTrackedHwnd, gameStatusLastActiveRobloxHwnd
    global gameStatusForegroundHook, gameStatusMouseMoveHook, gameStatusReorderHook
    global robloxTitlebarControlsByHwnd
    static lastSignature := ""

    try {
        panelHwnd := 0
        if (IsObject(gameStatusGui))
            panelHwnd := gameStatusGui.Hwnd
        panelExists := (panelHwnd && WinExist("ahk_id " . panelHwnd))
        panelVisible := panelExists ? !!DllCall("user32\IsWindowVisible", "Ptr", panelHwnd, "Int") : false
        panelIconic := panelExists ? !!DllCall("user32\IsIconic", "Ptr", panelHwnd, "Int") : false
        panelTopmost := false
        panelLayered := false
        panelAboveTarget := false
        if (panelExists) {
            panelExStyle := DllCall("user32\GetWindowLongPtrW", "Ptr", panelHwnd, "Int", -20, "Ptr")
            panelTopmost := ((panelExStyle & 0x00000008) != 0)
            panelLayered := ((panelExStyle & 0x00080000) != 0)
        }

        panelX := 0
        panelY := 0
        panelW := 0
        panelH := 0
        if (panelExists) {
            try WinGetPos(&panelX, &panelY, &panelW, &panelH, "ahk_id " . panelHwnd)
            catch {
                panelX := 0
                panelY := 0
                panelW := 0
                panelH := 0
            }
        }
        foregroundHwnd := DllCall("user32\GetForegroundWindow", "Ptr")
        foregroundRobloxHwnd := Macro_GetGameStatusForegroundRobloxHwnd()
        winActiveRobloxHwnd := WinActive("ahk_exe RobloxPlayerBeta.exe")
        targetHwnd := foregroundRobloxHwnd
        if (!targetHwnd)
            targetHwnd := Macro_GetGameStatusRobloxWindowUnderPointer()
        if (!targetHwnd && gameStatusLastActiveRobloxHwnd
            && WinExist("ahk_id " . gameStatusLastActiveRobloxHwnd))
            targetHwnd := gameStatusLastActiveRobloxHwnd

        targetX := 0
        targetY := 0
        targetW := 0
        targetH := 0
        targetExStyle := 0
        targetTopmost := false
        if (targetHwnd && WinExist("ahk_id " . targetHwnd)) {
            try {
                WinGetPos(&targetX, &targetY, &targetW, &targetH, "ahk_id " . targetHwnd)
                targetExStyle := DllCall("user32\GetWindowLongPtrW", "Ptr", targetHwnd, "Int", -20, "Ptr")
                targetTopmost := ((targetExStyle & 0x00000008) != 0)
            } catch {
                targetX := 0
                targetY := 0
                targetW := 0
                targetH := 0
                targetExStyle := 0
                targetTopmost := false
            }
        }
        if (panelExists && targetHwnd) {
            zHwnd := DllCall("user32\GetWindow", "Ptr", panelHwnd, "UInt", 3, "Ptr")
            while (zHwnd) {
                if (zHwnd = targetHwnd) {
                    panelAboveTarget := false
                    break
                }
                zHwnd := DllCall("user32\GetWindow", "Ptr", zHwnd, "UInt", 3, "Ptr")
            }
            if (!zHwnd)
                panelAboveTarget := true
        }

        controlsHwnd := 0
        controlsVisible := false
        controlsAboveTarget := false
        controlsTopmost := false
        if (targetHwnd && IsObject(robloxTitlebarControlsByHwnd)
            && robloxTitlebarControlsByHwnd.Has(targetHwnd)) {
            controls := robloxTitlebarControlsByHwnd[targetHwnd]
            if (IsObject(controls.gui)) {
                controlsHwnd := controls.gui.Hwnd
                if (controlsHwnd && WinExist("ahk_id " . controlsHwnd)) {
                    controlsVisible := !!DllCall("user32\IsWindowVisible", "Ptr", controlsHwnd, "Int")
                    controlsExStyle := DllCall("user32\GetWindowLongPtrW", "Ptr", controlsHwnd, "Int", -20, "Ptr")
                    controlsTopmost := ((controlsExStyle & 0x00000008) != 0)

                    if (targetHwnd) {
                        controlsZHwnd := DllCall("user32\GetWindow", "Ptr", controlsHwnd, "UInt", 3, "Ptr")
                        while (controlsZHwnd) {
                            if (controlsZHwnd = targetHwnd) {
                                controlsAboveTarget := false
                                break
                            }
                            controlsZHwnd := DllCall("user32\GetWindow", "Ptr", controlsZHwnd, "UInt", 3, "Ptr")
                        }
                        if (!controlsZHwnd)
                            controlsAboveTarget := true
                    }
                }
            }
        }

        signature := reason . "|" . gameStatusVisible . "|" . panelHwnd . "|" . panelExists
            . "|fg=" . foregroundHwnd . "|fgRoblox=" . foregroundRobloxHwnd . "|winActive=" . winActiveRobloxHwnd . "|" . panelVisible . "|" . panelIconic
            . "|panelRect=" . panelX . "," . panelY . "," . panelW . "," . panelH
            . "|targetRect=" . targetX . "," . targetY . "," . targetW . "," . targetH
            . "|targetTopmost=" . targetTopmost
            . "|" . panelTopmost . "|" . panelLayered . "|" . panelAboveTarget
            . "|" . targetHwnd . "|" . controlsHwnd . "|" . controlsVisible . "|" . controlsAboveTarget . "|" . controlsTopmost
            . "|" . gameStatusTrackedHwnd . "|" . gameStatusForegroundHook . "|" . gameStatusMouseMoveHook
            . "|" . gameStatusReorderHook
        if (signature = lastSignature)
            return
        lastSignature := signature

        logPath := A_Temp . "\GameTitlebarFixOverlayDiag.log"
        logLine := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") . " | " . signature . "`n"
        FileAppend(logLine, logPath, "UTF-8")
    } catch {
    }
}
Macro_QueueGameStatusWindowRepair(delayMs := 60) {
    global gameStatusWindowRepairPending

    ; Coalesce a foreground-change burst without restarting the one-shot timer
    ; on every event. This is event-driven repair, not a recurring monitor.
    if (gameStatusWindowRepairPending)
        return

    gameStatusWindowRepairPending := true
    SetTimer(Macro_RepairGameStatusAfterWindowEvent, -delayMs)
}

Macro_GameStatusForegroundWinEventProc(hWinEventHook, event, hwnd, idObject, idChild, idEventThread, dwmsEventTime) {
    global gameStatusVisible, gameStatusLastForegroundWasRoblox
    global gameStatusAwaitingRobloxClick

    if (event != 0x0003 || !hwnd || idObject != 0 || idChild != 0 || !gameStatusVisible)
        return

    isRobloxForeground := Macro_IsGameStatusRobloxHwnd(hwnd)
    if (!isRobloxForeground && gameStatusLastForegroundWasRoblox)
        gameStatusAwaitingRobloxClick := true
    gameStatusLastForegroundWasRoblox := isRobloxForeground

    ; Queue a one-shot repair and read the settled foreground HWND in its callback.
    Macro_QueueGameStatusWindowRepair(60)
}

Macro_RepairGameStatusAfterWindowEvent() {
    global gameStatusVisible, gameStatusWindowRepairPending
    global gameStatusTrackedHwnd, gameStatusLastActiveRobloxHwnd, gameStatusGui
    gameStatusWindowRepairPending := false
    repairHwnd := Macro_GetGameStatusForegroundRobloxHwnd()
    if (!gameStatusVisible)
        return

    isForegroundRoblox := !!repairHwnd

    if (isForegroundRoblox) {
        if (Macro_UpdateGameStatusPointerLock()) {
            Macro_KeepGameStatusWindowAtLockedPosition()
            Macro_KeepGameStatusWindowAboveTrackedRoblox()
            Macro_LogGameStatusOverlayState("foreground-locked")
            return
        }

        gameStatusTrackedHwnd := repairHwnd
        gameStatusLastActiveRobloxHwnd := repairHwnd
        try Macro_UpdateGameStatusDisplay()
        catch {
        }
        try {
            if (IsObject(gameStatusGui) && gameStatusGui.Hwnd) {
                if (DllCall("user32\IsIconic", "Ptr", gameStatusGui.Hwnd, "Int"))
                    DllCall("user32\ShowWindow", "Ptr", gameStatusGui.Hwnd, "Int", 4) ; SW_SHOWNOACTIVATE
                else if (!DllCall("user32\IsWindowVisible", "Ptr", gameStatusGui.Hwnd))
                    gameStatusGui.Show("NoActivate")
            }
        } catch {
        }
        try Macro_SyncGameStatusPosition(repairHwnd)
        catch {
        }
        try {
            DllCall("user32\RedrawWindow", "Ptr", gameStatusGui.Hwnd,
                "Ptr", 0, "Ptr", 0, "UInt", 0x0585)
            DllCall("user32\UpdateWindow", "Ptr", gameStatusGui.Hwnd)
        } catch {
        }
        Macro_LogGameStatusOverlayState("foreground-repair")
        return
    }

    try Macro_WatchGameStatusZOrder()
    catch {
    }
    try Macro_SyncGameStatusPosition()
    catch {
    }
    Macro_LogGameStatusOverlayState("foreground-fallback")
}
Macro_StopGameStatusLocationChangeHook() {
    global gameStatusLocationChangeHook

    try {
        if (gameStatusLocationChangeHook)
            DllCall("user32\UnhookWinEvent", "Ptr", gameStatusLocationChangeHook)
    } catch {
    }

    gameStatusLocationChangeHook := 0
}
Macro_GameStatusMoveSizeEndWinEventProc(hWinEventHook, event, hwnd, idObject, idChild, idEventThread, dwmsEventTime) {
    global gameStatusVisible, gameStatusGui, gameStatusTrackedHwnd
    global gameStatusLastActiveRobloxHwnd
    global gameStatusMoveSizeEndPending

    if (event != 0x000B && event != 0x800B)
        return

    ; WinEvent callbacks can arrive while the GUI globals are not initialized
    ; yet (startup/reload/re-entrant callback). Guard IsObject()/property access
    ; with IsSet() so an unset global cannot abort the script.
    if (!IsSet(gameStatusVisible) || !IsSet(gameStatusGui) || !IsSet(gameStatusTrackedHwnd)
        || !IsSet(gameStatusLastActiveRobloxHwnd))
        return

    if (!gameStatusVisible || !IsObject(gameStatusGui) || !gameStatusGui.Hwnd
        || !hwnd || idObject != 0 || idChild != 0)
        return

    try {
        if (WinGetProcessName("ahk_id " . hwnd) != "RobloxPlayerBeta.exe")
            return
    } catch {
        return
    }

    ; Only a real foreground Roblox window can change the move/resize tracking
    ; target. The hovered-row marker is not used as an alternate tracking authority.
    if (hwnd != gameStatusTrackedHwnd) {
        if (WinActive("ahk_id " . hwnd) != hwnd)
            return
        gameStatusTrackedHwnd := hwnd
        gameStatusLastActiveRobloxHwnd := hwnd
    }

    ; Defer one message-cycle so Windows has committed the final window
    ; rectangle before we read it. This remains effectively immediate while
    ; avoiding re-entrant WinEvent/SetWindowPos interactions.
    if (!gameStatusMoveSizeEndPending) {
        gameStatusMoveSizeEndPending := true
        SetTimer(Macro_GameStatusMoveSizeEndSync, -1)
    }
}
Macro_GameStatusMoveSizeEndSync() {
    global gameStatusMoveSizeEndPending, gameStatusVisible, gameStatusTrackedHwnd
    static lastModeHwnd := 0
    static lastWindowMode := -1

    gameStatusMoveSizeEndPending := false
    if (!gameStatusVisible)
        return

    targetHwnd := gameStatusTrackedHwnd
    currentWindowMode := -1
    if (targetHwnd && WinExist("ahk_id " . targetHwnd)) {
        try currentWindowMode := Macro_GetRobloxWindowMode(targetHwnd)
        catch
            currentWindowMode := -1
    }

    ; F11 can change the window mode without changing the foreground HWND.
    ; Trigger one layout refresh only when that mode actually changes.
    modeChanged := (targetHwnd != lastModeHwnd || currentWindowMode != lastWindowMode)
    lastModeHwnd := targetHwnd
    lastWindowMode := currentWindowMode

    if (modeChanged) {
        try Macro_UpdateGameStatusDisplay()
        catch {
        }
    } else {
        try Macro_SyncGameStatusPosition()
        catch {
        }
    }
}

; Foreground and window events trigger reconciliation; no recurring Z-order timer is used.
; Clicks while focus stays in Roblox do not redraw the selector.
Macro_WatchGameStatusZOrder() {
    global gameStatusGui, gameStatusVisible, gameStatusRobloxWasActive
    global gameStatusClickFocusHandoffPending, gameStatusTrackedHwnd, gameStatusLastActiveRobloxHwnd
    global gameStatusTrackedX, gameStatusTrackedY, gameStatusTrackedW, gameStatusTrackedH
    global gameIdentityScanPending, shortcutHelpVisible
    ; Keep a set of Roblox HWNDs, not WinGetList order. WinGetList follows
    ; Z-order, which may change on clicks even when no client was added/closed.
    static lastRobloxWindowSet := Map()
    static lastTrackedMinMaxState := ""

    ; If the user intentionally turned the selector off, stop monitoring.
    ; A missing/destroyed HWND while the selector is logically enabled is a
    ; recoverable failure: do not stop the watcher permanently (that made F3
    ; off/on or F7 reload the only way to bring the panel back).
    if (!gameStatusVisible) {
        Macro_StopGameStatusZOrderWatch()
        return
    }

    panelHwnd := 0
    try {
        if (IsObject(gameStatusGui))
            panelHwnd := gameStatusGui.Hwnd
    } catch {
        panelHwnd := 0
    }

    if (!panelHwnd || !WinExist("ahk_id " . panelHwnd)) {
        Macro_StopGameStatusZOrderWatch()
        try Macro_CreateGameStatusGUI(false)
        catch {
        }

        panelHwnd := 0
        try {
            if (IsObject(gameStatusGui))
                panelHwnd := gameStatusGui.Hwnd
        } catch {
            panelHwnd := 0
        }
        if (!panelHwnd || !WinExist("ahk_id " . panelHwnd))
            return

        ; Macro_CreateGameStatusGUI(false) sets the requested visibility flag
        ; false while building the HWND. Restore the logical ON state before
        ; rendering so the cached contents can be rebuilt normally.
        gameStatusVisible := true
        try Macro_UpdateGameStatusDisplay()
        catch {
        }
        try gameStatusGui.Show("NoActivate")
        catch {
        }
        Macro_StartGameStatusZOrderWatch()
        try Macro_SyncGameStatusPosition()
        catch {
        }
        return
    }

    try {
        if (!DllCall("user32\IsWindowVisible", "Ptr", panelHwnd))
            gameStatusGui.Show("NoActivate")
    } catch {
        return
    }

    ; Keep the selector fixed while the pointer is over it, even if activating
    ; another Roblox client changes the foreground window.
    statusActiveRobloxHwnd := Macro_GetGameStatusForegroundRobloxHwnd()
    if (Macro_UpdateGameStatusPointerLock()) {
        Macro_KeepGameStatusWindowAtLockedPosition()
        Macro_KeepGameStatusWindowAboveTrackedRoblox()
        return
    }

    if (statusActiveRobloxHwnd && WinExist("ahk_id " . statusActiveRobloxHwnd)) {
        if (statusActiveRobloxHwnd != gameStatusTrackedHwnd) {
            gameStatusTrackedHwnd := statusActiveRobloxHwnd
            gameStatusClickFocusHandoffPending := false
        }
        gameStatusLastActiveRobloxHwnd := statusActiveRobloxHwnd
    }

    ; Refresh rows only when the actual Roblox HWND set changes. WinGetList is
    ; Z-order ordered; comparing its raw sequence mistakes foreground clicks or
    ; window raises for client-list changes and needlessly re-renders the panel.
    try {
        currentRobloxWindowSet := Map()
        for clientHwnd in WinGetList("ahk_exe RobloxPlayerBeta.exe")
            currentRobloxWindowSet[clientHwnd] := true

        clientSetChanged := (currentRobloxWindowSet.Count != lastRobloxWindowSet.Count)
        if (!clientSetChanged) {
            for clientHwnd, _ in currentRobloxWindowSet {
                if (!lastRobloxWindowSet.Has(clientHwnd)) {
                    clientSetChanged := true
                    break
                }
            }
        }

        if (clientSetChanged) {
            lastRobloxWindowSet := currentRobloxWindowSet
            Macro_UpdateGameStatusDisplay()
            try Macro_SyncGameStatusPosition()
            catch {
            }
            if (!gameIdentityScanPending)
                Macro_FinalizeGameStatusIdentityTransaction()
            return
        }
    } catch {
    }

    if (statusActiveRobloxHwnd && gameStatusClickFocusHandoffPending) {
        gameStatusClickFocusHandoffPending := false
        gameStatusTrackedHwnd := statusActiveRobloxHwnd
        gameStatusLastActiveRobloxHwnd := statusActiveRobloxHwnd
        gameStatusRobloxWasActive := true
        Macro_SyncGameStatusPosition()
    }

    ; While Roblox is foreground, follow that exact client. When another app
    ; is foreground, a Roblox client under the pointer remains the hover target.
    pointerRobloxHwnd := Macro_GetGameStatusRobloxWindowUnderPointer()
    if (statusActiveRobloxHwnd && WinExist("ahk_id " . statusActiveRobloxHwnd))
        targetRobloxHwnd := statusActiveRobloxHwnd
    else if (pointerRobloxHwnd && WinExist("ahk_id " . pointerRobloxHwnd))
        targetRobloxHwnd := pointerRobloxHwnd
    else if (gameStatusLastActiveRobloxHwnd && WinExist("ahk_id " . gameStatusLastActiveRobloxHwnd))
        targetRobloxHwnd := gameStatusLastActiveRobloxHwnd
    else if (gameStatusTrackedHwnd && WinExist("ahk_id " . gameStatusTrackedHwnd))
        targetRobloxHwnd := gameStatusTrackedHwnd
    else
        targetRobloxHwnd := 0

    targetChanged := (targetRobloxHwnd && targetRobloxHwnd != gameStatusTrackedHwnd)

    ; An active Roblox client takes priority over the pointer target so the
    ; selector cannot remain docked to a covered Roblox instance.
    if (!statusActiveRobloxHwnd && pointerRobloxHwnd && WinExist("ahk_id " . pointerRobloxHwnd)) {
        try {
            if (!DllCall("user32\IsWindowVisible", "Ptr", gameStatusGui.Hwnd))
                gameStatusGui.Show("NoActivate")
        } catch {
        }
        gameStatusTrackedHwnd := pointerRobloxHwnd
    }
    Macro_KeepGameStatusWindowAboveTrackedRoblox()

    if (shortcutHelpVisible)
        Macro_UpdateShortcutHelpPlacement()

    maxStateHwnd := targetRobloxHwnd ? targetRobloxHwnd : gameStatusTrackedHwnd
    currentTrackedMinMaxState := ""
    if (maxStateHwnd && WinExist("ahk_id " . maxStateHwnd)) {
        try currentTrackedMinMaxState := WinGetMinMax("ahk_id " . maxStateHwnd)
        catch
            currentTrackedMinMaxState := ""
    }
    maxStateChanged := (currentTrackedMinMaxState != lastTrackedMinMaxState)
    lastTrackedMinMaxState := currentTrackedMinMaxState
    trackedRobloxIsActive := (targetRobloxHwnd && statusActiveRobloxHwnd = targetRobloxHwnd)
    activeChanged := (trackedRobloxIsActive != gameStatusRobloxWasActive)

    geometryChanged := false
    geometryHwnd := targetRobloxHwnd ? targetRobloxHwnd : gameStatusTrackedHwnd
    if (geometryHwnd && WinExist("ahk_id " . geometryHwnd)) {
        try {
            WinGetPos(&gx, &gy, &gw, &gh, "ahk_id " . geometryHwnd)
            geometryChanged := (gx != gameStatusTrackedX || gy != gameStatusTrackedY
                || gw != gameStatusTrackedW || gh != gameStatusTrackedH)
        } catch {
            geometryChanged := false
        }
    }

    if (!activeChanged && !targetChanged && !geometryChanged && !maxStateChanged) {
        ; Even when focus/geometry flags are unchanged, validate the live panel
        ; against the current Roblox HWND. This is a no-op when everything is
        ; correct; it repairs stale position/Z-order states that previously
        ; persisted until the user toggled the selector off and on.
        try Macro_SyncGameStatusPosition()
        catch {
        }
        return
    }

    gameStatusRobloxWasActive := trackedRobloxIsActive
    if (targetChanged) {
        gameStatusTrackedHwnd := targetRobloxHwnd
        if (statusActiveRobloxHwnd = targetRobloxHwnd)
            gameStatusLastActiveRobloxHwnd := targetRobloxHwnd
        Macro_EnsureGameIdentityCached(targetRobloxHwnd)
        Macro_UpdateGameStatusDisplay()
    } else if (maxStateChanged) {
        Macro_UpdateGameStatusDisplay()
    } else {
        Macro_SyncGameStatusPosition()
    }
}

Macro_ActivateGameStatusRow(rowIndex, ctrl, info, clickedAutoHoverActivated := false, targetHwnd := 0, clickedWasLastActive := -1) {
    global gameStatusRowTargets, gameStatusPreMaxPlacements, gameStatusLastActiveRobloxHwnd
    global gameStatusAutoHoverHwnd, gameStatusHoverSessionOriginHwnd

    if (!targetHwnd) {
        if (rowIndex < 1 || rowIndex > gameStatusRowTargets.Length)
            return
        targetHwnd := gameStatusRowTargets[rowIndex]
    }
    hwnd := targetHwnd
    if (!hwnd || !WinExist("ahk_id " . hwnd))
        return

    try {
        targetTitle := "ahk_id " . hwnd
        currentMinMaxState := WinGetMinMax(targetTitle)
        isFullscreen := (Macro_GetRobloxWindowMode(hwnd) = 3)

        ; The physical mouse hook captured the active-row relation before
        ; dispatch. Use that snapshot instead of post-click focus.
        clickedOnLastActiveRoblox := (clickedWasLastActive = -1)
            ? (gameStatusLastActiveRobloxHwnd = hwnd)
            : clickedWasLastActive
        Macro_LogGameStatusClickTrace("activate-start", rowIndex, hwnd, 0,
            "clickedAutoHoverActivated=" . clickedAutoHoverActivated . " sameLast=" . clickedOnLastActiveRoblox)

        if (clickedAutoHoverActivated) {
            ; The hovered row is already the selected foreground client. Clear
            ; only the panel lock; the click now applies maximize/restore rules.
            Macro_ResetGameStatusHoverSession()
        } else if (gameStatusAutoHoverHwnd && gameStatusAutoHoverHwnd != hwnd) {
            ; Clicking another row applies its action without briefly returning
            ; focus to the previously selected client.
            Macro_ResetGameStatusHoverSession()
            clickedOnLastActiveRoblox := (gameStatusLastActiveRobloxHwnd = hwnd)
        }

        if (isFullscreen) {
            ; The selector accepts the physical click as the foreground window;
            ; hand focus to the chosen Roblox client immediately.
            activationSucceeded := Macro_EnsureGameStatusWindowActive(hwnd)
            Macro_LogGameStatusClickTrace("activate-action", rowIndex, hwnd, 0,
                "action=fullscreen-activate immediate=" . activationSucceeded)
            Macro_UpdateLastActiveRobloxFromForeground(hwnd)
            Macro_QueueFixedPointModalDebugRefresh(hwnd, true, false)
            return
        }

        if (clickedOnLastActiveRoblox) {
            if (currentMinMaxState = 1) {
                ; Restore the selected maximized game to its saved original size and position.
                restored := Macro_RestoreSingleGameStatusPlacement(hwnd, targetTitle)
                Macro_LogGameStatusClickTrace("restore-result", rowIndex, hwnd, 0,
                    "action=restore-single success=" . restored)
                if (restored)
                    gameStatusPreMaxPlacements.Delete(hwnd)
            } else {
                if (currentMinMaxState = -1)
                    WinRestore(targetTitle)

                if (gameStatusPreMaxPlacements.Has(hwnd))
                    gameStatusPreMaxPlacements.Delete(hwnd)

                Macro_SaveGameStatusRestorePlacement(hwnd)
                WinMaximize(targetTitle)
                Macro_LogGameStatusClickTrace("activate-action", rowIndex, hwnd, 0,
                    "action=maximize-current")
            }

        } else {
            ; Selecting another Roblox window always activates it. A normal or
            ; minimized client is maximized; an already-maximized client is only
            ; activated.
            if (currentMinMaxState != 1) {
                if (currentMinMaxState = -1)
                    WinRestore(targetTitle)

                if (gameStatusPreMaxPlacements.Has(hwnd))
                    gameStatusPreMaxPlacements.Delete(hwnd)
                Macro_SaveGameStatusRestorePlacement(hwnd)
                WinMaximize(targetTitle)
                Macro_LogGameStatusClickTrace("activate-action", rowIndex, hwnd, 0,
                    "action=maximize-other")
            }

        }

        ; The selector takes focus only for this physical click. Always return
        ; it to the chosen client, including the active-row restore/maximize path.
        activationSucceeded := Macro_EnsureGameStatusWindowActive(hwnd)
        if (currentMinMaxState = 1)
            actionName := clickedOnLastActiveRoblox ? "toggle-current-maximized" : "activate-other-maximized"
        else
            actionName := clickedOnLastActiveRoblox ? "toggle-current-normal" : "maximize-and-activate-other"
        Macro_LogGameStatusClickTrace("activate-action", rowIndex, hwnd, 0,
            "action=" . actionName . " immediate=" . activationSucceeded)

        Macro_UpdateLastActiveRobloxFromForeground(hwnd)
        Macro_LogGameStatusClickTrace("activate-complete", rowIndex, hwnd)
        Macro_QueueFixedPointModalDebugRefresh(hwnd, true, false)
    } catch as err {
        Macro_LogGameStatusClickTrace("activate-error", rowIndex, hwnd, 0, err.Message)
    }
}

; The selector is activated by Windows on the physical click. That puts this
; process in the foreground-input chain, so one direct handoff is sufficient.
Macro_EnsureGameStatusWindowActive(hwnd) {
    global gameStatusGui, gameStatusVisible, gameStatusTrackedHwnd, gameStatusRobloxWasActive
    global gameStatusClickFocusHandoffPending

    if (!hwnd || !WinExist("ahk_id " . hwnd))
        return false

    if (WinActive("ahk_id " . hwnd) != hwnd)
        Macro_TryGameStatusWindowActivation(hwnd)

    activated := (WinActive("ahk_id " . hwnd) = hwnd)
    if (activated)
        gameStatusClickFocusHandoffPending := false
    if (activated && gameStatusVisible && IsObject(gameStatusGui) && gameStatusGui.Hwnd) {
        ; MA_ACTIVATE temporarily foregrounds the selector so Windows permits
        ; the click handoff. Re-dock and raise it immediately after Roblox wins
        ; focus instead of waiting for a recurring Z-order scan.
        gameStatusTrackedHwnd := hwnd
        gameStatusRobloxWasActive := true
        try {
            if (!DllCall("user32\IsWindowVisible", "Ptr", gameStatusGui.Hwnd))
                gameStatusGui.Show("NoActivate")
        } catch {
        }
        Macro_SyncGameStatusPosition()
    }
    return activated
}

Macro_TryGameStatusWindowActivation(hwnd) {
    if (!hwnd || !WinExist("ahk_id " . hwnd))
        return false
    if (WinActive("ahk_id " . hwnd) = hwnd)
        return true

    try DllCall("user32\SetForegroundWindow", "Ptr", hwnd, "Int")
    catch as err
        Macro_LogGameStatusClickTrace("activate-error", 0, hwnd, 0, err.Message)

    ; SetForegroundWindow is called from the process that just received the
    ; user's click. Do not queue a delayed retry after the click has returned.
    return (WinActive("ahk_id " . hwnd) = hwnd)
}

; Keep click-toggle classification aligned with Windows' actual foreground
; Roblox client. A failed activation must not mark the requested HWND active.
Macro_UpdateLastActiveRobloxFromForeground(preferredHwnd := 0) {
    global gameStatusLastActiveRobloxHwnd

    try {
        activeRobloxHwnd := Macro_GetGameStatusForegroundRobloxHwnd()
        if (activeRobloxHwnd) {
            gameStatusLastActiveRobloxHwnd := activeRobloxHwnd
            return activeRobloxHwnd
        }
        if (preferredHwnd && WinActive("ahk_id " . preferredHwnd) = preferredHwnd) {
            gameStatusLastActiveRobloxHwnd := preferredHwnd
            return preferredHwnd
        }
    } catch {
    }
    return gameStatusLastActiveRobloxHwnd
}

; Restore one maximized Roblox client using the exact WINDOWPLACEMENT logic
; already proven by All Mini. This avoids depending on WinRestore() for Roblox.
Macro_RestoreSingleGameStatusPlacement(hwnd, targetTitle) {
    global gameStatusPreMaxPlacements

    if (!hwnd || !WinExist("ahk_id " . hwnd))
        return false

    placement := Buffer(44, 0)
    NumPut("UInt", 44, placement, 0)

    if (gameStatusPreMaxPlacements.Has(hwnd)) {
        savedState := gameStatusPreMaxPlacements[hwnd]
        try {
            samePid := (WinGetPID(targetTitle) = savedState.pid)
        } catch {
            samePid := false
        }

        if (samePid) {
            placement := savedState.placement
        } else {
            gameStatusPreMaxPlacements.Delete(hwnd)
            if (!DllCall("user32\GetWindowPlacement", "Ptr", hwnd, "Ptr", placement.Ptr, "Int"))
                return false
        }
    } else {
        if (!DllCall("user32\GetWindowPlacement", "Ptr", hwnd, "Ptr", placement.Ptr, "Int"))
            return false
    }

    NumPut("UInt", 4, placement, 8) ; SW_SHOWNOACTIVATE
    restored := DllCall(
        "user32\SetWindowPlacement",
        "Ptr", hwnd,
        "Ptr", placement.Ptr,
        "Int"
    )

    if (!restored) {
        DllCall("user32\ShowWindow", "Ptr", hwnd, "Int", 4) ; SW_SHOWNOACTIVATE
        restored := (WinGetMinMax(targetTitle) != 1)
    }

    return restored
}

Macro_LogGameStatusClickTrace(stage, rowIndex := 0, targetHwnd := 0, controlHwnd := 0, detail := "") {
    global gameStatusLastActiveRobloxHwnd, gameStatusAutoHoverHwnd, gameStatusClickTraceEnabled

    if (!gameStatusClickTraceEnabled)
        return

    try {
        foregroundHwnd := DllCall("user32\GetForegroundWindow", "Ptr")
        minMaxState := "na"
        windowMode := "na"
        if (targetHwnd && WinExist("ahk_id " . targetHwnd)) {
            try minMaxState := WinGetMinMax("ahk_id " . targetHwnd)
            try windowMode := Macro_GetRobloxWindowMode(targetHwnd)
        }
        line := FormatTime(, "yyyy-MM-dd HH:mm:ss") . " tick=" . A_TickCount
            . " stage=" . stage . " row=" . rowIndex . " target=" . targetHwnd
            . " control=" . controlHwnd . " foreground=" . foregroundHwnd
            . " lastActive=" . gameStatusLastActiveRobloxHwnd
            . " autoHover=" . gameStatusAutoHoverHwnd
            . " minmax=" . minMaxState . " mode=" . windowMode
            . (detail = "" ? "" : " " . detail)
        FileAppend(line . "`r`n", A_ScriptDir . "\GameStatusClickTrace.log", "UTF-8")
    } catch {
    }
}

Macro_SaveGameStatusRestorePlacement(hwnd) {
    global gameStatusPreMaxPlacements
    if (!hwnd || !WinExist("ahk_id " . hwnd) || gameStatusPreMaxPlacements.Has(hwnd))
        return false

    placement := Buffer(44, 0)
    NumPut("UInt", 44, placement, 0)
    if (!DllCall("user32\GetWindowPlacement", "Ptr", hwnd, "Ptr", placement.Ptr, "Int"))
        return false

    savedPlacement := Buffer(44, 0)
    Loop 11 {
        offset := (A_Index - 1) * 4
        NumPut("UInt", NumGet(placement, offset, "UInt"), savedPlacement, offset)
    }
    try
        pid := WinGetPID("ahk_id " . hwnd)
    catch
        return false
    gameStatusPreMaxPlacements[hwnd] := {pid:pid, placement:savedPlacement}
    return true
}

Macro_ExitRobloxFullscreenWindows(hwndList, preferredForegroundHwnd := 0) {
    ; Roblox's supported fullscreen toggle is F11. Use it only for windows
    ; currently identified as F11 fullscreen; never send a second toggle or
    ; automatically restore fullscreen after the requested operation.
    originalForeground := DllCall("user32\GetForegroundWindow", "Ptr")
    exitedCount := 0

    for hwnd in hwndList {
        if (!hwnd || !WinExist("ahk_id " . hwnd))
            continue

        try {
            if (!Macro_IsRobloxF11FullscreenWindow(hwnd))
                continue

            ; F11 must be delivered to the Roblox client itself. The action is
            ; user-initiated, so foreground activation is permitted here.
            if (WinActive("ahk_id " . hwnd) != hwnd) {
                DllCall("user32\SetForegroundWindow", "Ptr", hwnd)
                WinActivate("ahk_id " . hwnd)
                if (!WinWaitActive("ahk_id " . hwnd, , 1.0)
                    || WinActive("ahk_id " . hwnd) != hwnd)
                    continue
            }

            Sleep(80)
            ; Recheck immediately before sending to avoid accidentally turning
            ; fullscreen ON if the user changed the state during the handoff.
            if (!Macro_IsRobloxF11FullscreenWindow(hwnd))
                continue

            SendEvent("{F11}")

            ; Wait for Roblox to return to a normal window. Do not press F11
            ; again if the transition is delayed or cannot be confirmed.
            changedToWindowed := false
            Loop 30 {
                Sleep(50)
                if (!WinExist("ahk_id " . hwnd))
                    break
                if (!Macro_IsRobloxF11FullscreenWindow(hwnd)) {
                    changedToWindowed := true
                    break
                }
            }
            if (changedToWindowed)
                exitedCount += 1
        } catch {
        }
    }

    ; Return focus to the client from which the user invoked the button.
    focusTarget := preferredForegroundHwnd
    if (!focusTarget || !WinExist("ahk_id " . focusTarget)) {
        try {
            if (originalForeground && WinExist("ahk_id " . originalForeground)
                && WinGetProcessName("ahk_id " . originalForeground) = "RobloxPlayerBeta.exe")
                focusTarget := originalForeground
        } catch {
            focusTarget := 0
        }
    }

    if (focusTarget && WinExist("ahk_id " . focusTarget)) {
        try {
            DllCall("user32\SetForegroundWindow", "Ptr", focusTarget)
            WinActivate("ahk_id " . focusTarget)
        } catch {
        }
    }

    return exitedCount
}

Macro_IsRobloxF11FullscreenWindow(hwnd) {
    if (!hwnd || !WinExist("ahk_id " . hwnd))
        return false

    ; Prefer the established window-mode detector, then use the dedicated
    ; two-part F11 fullscreen geometry/style check as a fallback. The fallback
    ; also covers Roblox builds that report a maximized show state while F11 is on.
    try {
        if (Macro_GetRobloxWindowMode(hwnd) = 3)
            return true
    } catch {
    }

    monitorHandle := DllCall("user32\MonitorFromWindow", "Ptr", hwnd, "UInt", 2, "Ptr")
    if (!monitorHandle)
        return false

    monitorInfo := Buffer(40, 0)
    NumPut("UInt", 40, monitorInfo, 0)
    if (!DllCall("user32\GetMonitorInfoW", "Ptr", monitorHandle, "Ptr", monitorInfo.Ptr, "Int"))
        return false

    monitorLeft := NumGet(monitorInfo, 4, "Int")
    monitorTop := NumGet(monitorInfo, 8, "Int")
    monitorRight := NumGet(monitorInfo, 12, "Int")
    monitorBottom := NumGet(monitorInfo, 16, "Int")
    monitorWidth := monitorRight - monitorLeft
    monitorHeight := monitorBottom - monitorTop
    if (monitorWidth <= 0 || monitorHeight <= 0)
        return false

    return Macro_IsTrueFullscreen(hwnd, monitorLeft, monitorTop, monitorWidth, monitorHeight)
}

Macro_RestoreAllMiniRobloxWindows(preferredForegroundHwnd := 0) {
    global gameStatusPreMaxPlacements

    try
        robloxList := WinGetList("ahk_exe RobloxPlayerBeta.exe")
    catch
        return

    ; Restore is an explicit user action: leave F11 fullscreen only for clients
    ; currently in fullscreen, then continue the original minimized-window restore.
    ; No code below this point toggles fullscreen back on.
    Macro_ExitRobloxFullscreenWindows(robloxList, preferredForegroundHwnd)

    ; Discard snapshots for windows that have closed so a recycled HWND cannot
    ; inherit another client's saved geometry.
    staleHwnds := []
    for savedHwnd, savedState in gameStatusPreMaxPlacements {
        hwndIsSameWindow := !!WinExist("ahk_id " . savedHwnd)
        if (hwndIsSameWindow) {
            try hwndIsSameWindow := (WinGetPID("ahk_id " . savedHwnd) = savedState.pid)
            catch
                hwndIsSameWindow := false
        }
        if (!hwndIsSameWindow)
            staleHwnds.Push(savedHwnd)
    }
    for savedHwnd in staleHwnds
        gameStatusPreMaxPlacements.Delete(savedHwnd)

    restoredAny := false
    for hwnd in robloxList {
        if (!WinExist("ahk_id " . hwnd))
            continue

        try {
            ; Fullscreen clients have already received one F11 exit attempt above.
            ; If Roblox did not leave fullscreen, skip it rather than force-resizing it.
            if (Macro_GetRobloxWindowMode(hwnd) = 3)
                continue

            minMaxState := WinGetMinMax("ahk_id " . hwnd)
            if (minMaxState != 1) {
                ; If the user restored or minimized this client manually, do not
                ; overwrite that newer choice with an older saved placement.
                if (gameStatusPreMaxPlacements.Has(hwnd))
                    gameStatusPreMaxPlacements.Delete(hwnd)
                continue
            }

            if (gameStatusPreMaxPlacements.Has(hwnd)) {
                savedState := gameStatusPreMaxPlacements[hwnd]
                if (WinGetPID("ahk_id " . hwnd) != savedState.pid) {
                    gameStatusPreMaxPlacements.Delete(hwnd)
                    placement := Buffer(44, 0)
                    NumPut("UInt", 44, placement, 0)
                    if (!DllCall("user32\GetWindowPlacement", "Ptr", hwnd, "Ptr", placement.Ptr, "Int"))
                        continue
                } else {
                    placement := savedState.placement
                }
            } else {
                placement := Buffer(44, 0)
                NumPut("UInt", 44, placement, 0)
                if (!DllCall("user32\GetWindowPlacement", "Ptr", hwnd, "Ptr", placement.Ptr, "Int"))
                    continue
            }

            ; SW_SHOWNOACTIVATE restores the normal placement and leaves focus alone.
            NumPut("UInt", 4, placement, 8)
            placementApplied := DllCall("user32\SetWindowPlacement", "Ptr", hwnd, "Ptr", placement.Ptr, "Int")
            if (!placementApplied) {
                DllCall("user32\ShowWindow", "Ptr", hwnd, "Int", 4) ; SW_SHOWNOACTIVATE
                placementApplied := (WinGetMinMax("ahk_id " . hwnd) != 1)
            }

            if (placementApplied) {
                restoredAny := true
                if (gameStatusPreMaxPlacements.Has(hwnd))
                    gameStatusPreMaxPlacements.Delete(hwnd)
            }
        } catch {
        }
    }

    if (restoredAny)
        Macro_SyncGameStatusPosition()
}

Macro_GameStatusNcHitTest(wParam, lParam, msg, hwnd) {
    global gameStatusGui
    try {
        if (IsObject(gameStatusGui) && hwnd = gameStatusGui.Hwnd)
            return -1 ; HTTRANSPARENT
    } catch {
    }
}

Macro_GameStatusMouseActivate(wParam, lParam, msg, hwnd) {
    global gameStatusGui, gameStatusClickFocusHandoffPending
    try {
        if (IsObject(gameStatusGui) && hwnd = gameStatusGui.Hwnd) {
            gameStatusClickFocusHandoffPending := true
            ; A physical click must make this process foreground first. Windows
            ; can then hand focus to the selected Roblox client in the same
            ; click-up handler without background activation retries.
            return 1 ; MA_ACTIVATE
        }
    } catch {
    }
}

; Capture selector intent from AutoHotkey's physical mouse hook. This is
; independent of which child control Windows happened to hit in the overlay.
Macro_BeginGameStatusClick() {
    global gameStatusGui, gameStatusVisible, gameStatusRowTargets
    global mouseMacroActive
    global gameStatusLastActiveRobloxHwnd, gameStatusAutoHoverHwnd
    global gameStatusHoverSessionOriginHwnd
    global gameStatusClickSnapshotRow, gameStatusClickSnapshotHwnd
    global gameStatusClickSnapshotWasAutoHoverActivated, gameStatusClickSnapshotWasLastActive
    global gameStatusClickFocusHandoffPending

    gameStatusClickSnapshotRow := 0
    gameStatusClickSnapshotHwnd := 0
    gameStatusClickSnapshotWasAutoHoverActivated := false
    gameStatusClickSnapshotWasLastActive := false
    gameStatusClickFocusHandoffPending := false

    if (!gameStatusVisible || !IsObject(gameStatusGui) || !gameStatusGui.Hwnd
        || !DllCall("user32\IsWindowVisible", "Ptr", gameStatusGui.Hwnd))
        return

    try {
        MouseGetPos(&mouseX, &mouseY, , &controlHwnd, 2)
        WinGetPos(&guiX, &guiY, &guiW, &guiH, "ahk_id " . gameStatusGui.Hwnd)
        if (mouseX < guiX || mouseX >= guiX + guiW
            || mouseY < guiY || mouseY >= guiY + guiH)
            return
        if (!Macro_IsGameStatusPointerActuallyOnPanel())
            return
        Macro_UpdateGameStatusPointerLock()

        targetRow := Macro_GetGameStatusHoverTarget(controlHwnd)
        if (targetRow = 0 || targetRow < -1 || targetRow > gameStatusRowTargets.Length)
            return

        targetHwnd := (targetRow > 0) ? gameStatusRowTargets[targetRow] : 0
        if (targetRow > 0 && (!targetHwnd || !WinExist("ahk_id " . targetHwnd)))
            return

        ; Clicking a valid game row stops the mouse-click macro just like MButton.
        ; Do this on physical button-down so the selector can process its own
        ; click-up action (maximize/restore) without the macro continuing to hold/click.
        if (targetRow > 0 && mouseMacroActive)
            MouseMacro_Stop()

        ; The click handoff is physical-click scoped. Do not promote the panel
        ; to TOPMOST; its regular Z-order is maintained relative to Roblox only.
        gameStatusClickFocusHandoffPending := true

        autoHoverActivatedTarget := (targetHwnd && gameStatusAutoHoverHwnd = targetHwnd)
        foregroundHwnd := DllCall("user32\GetForegroundWindow", "Ptr")
        if (autoHoverActivatedTarget) {
            if (WinActive("ahk_id " . targetHwnd) = targetHwnd)
                gameStatusLastActiveRobloxHwnd := targetHwnd
            ; Preserve whether this target was selected before hover activation,
            ; so clicking it does not accidentally restore an already-maximized game.
            wasLastActive := (gameStatusHoverSessionOriginHwnd = targetHwnd)
        } else if (foregroundHwnd)
            wasLastActive := (foregroundHwnd = targetHwnd)
        else
            wasLastActive := (gameStatusLastActiveRobloxHwnd = targetHwnd)

        gameStatusClickSnapshotRow := targetRow
        gameStatusClickSnapshotHwnd := targetHwnd
        gameStatusClickSnapshotWasAutoHoverActivated := autoHoverActivatedTarget
        gameStatusClickSnapshotWasLastActive := wasLastActive
        Macro_LogGameStatusClickTrace("physical-down", targetRow, targetHwnd, controlHwnd,
            "autoHover=" . autoHoverActivatedTarget . " wasLastActive=" . wasLastActive)
    } catch {
        Macro_ClearGameStatusClickSnapshot()
    }
}

; Commit once on physical button-up. Keep the row chosen on button-down even if
; the pointer drifts across a neighboring row while the button is held.
Macro_EndGameStatusClick() {
    global gameStatusGui, gameStatusVisible, gameStatusRowTargets
    global gameStatusLastActiveRobloxHwnd
    global gameStatusClickFocusHandoffPending
    global gameStatusClickSnapshotRow, gameStatusClickSnapshotHwnd
    global gameStatusClickSnapshotWasAutoHoverActivated, gameStatusClickSnapshotWasLastActive

    if (!gameStatusClickSnapshotRow) {
        gameStatusClickFocusHandoffPending := false
        return
    }

    try {
        if (!gameStatusVisible || !IsObject(gameStatusGui) || !gameStatusGui.Hwnd
            || !DllCall("user32\IsWindowVisible", "Ptr", gameStatusGui.Hwnd)) {
            gameStatusClickFocusHandoffPending := false
            Macro_ClearGameStatusClickSnapshot()
            return
        }

        MouseGetPos(&mouseX, &mouseY, , &controlHwnd, 2)
        WinGetPos(&guiX, &guiY, &guiW, &guiH, "ahk_id " . gameStatusGui.Hwnd)
        if (mouseX < guiX || mouseX >= guiX + guiW
            || mouseY < guiY || mouseY >= guiY + guiH
            || !Macro_IsGameStatusPointerActuallyOnPanel()) {
            gameStatusClickFocusHandoffPending := false
            Macro_ClearGameStatusClickSnapshot()
            return
        }

        clickedRow := gameStatusClickSnapshotRow
        targetHwnd := gameStatusClickSnapshotHwnd
        clickedAutoHoverActivated := gameStatusClickSnapshotWasAutoHoverActivated
        clickedWasLastActive := gameStatusClickSnapshotWasLastActive
        Macro_LogGameStatusClickTrace("physical-up", clickedRow, targetHwnd, controlHwnd)
        Macro_ClearGameStatusClickSnapshot()

        if (clickedRow = -1) {
            previousRobloxHwnd := gameStatusLastActiveRobloxHwnd
            Macro_ResetGameStatusHoverSession()
            Macro_RestoreAllMiniRobloxWindows(previousRobloxHwnd)
            if (previousRobloxHwnd && WinExist("ahk_id " . previousRobloxHwnd))
                Macro_EnsureGameStatusWindowActive(previousRobloxHwnd)
        } else if (targetHwnd && WinExist("ahk_id " . targetHwnd)) {
            Macro_ActivateGameStatusRow(clickedRow, "", "", clickedAutoHoverActivated,
                targetHwnd, clickedWasLastActive)
        } else {
            gameStatusClickFocusHandoffPending := false
        }
    } catch {
        Macro_ClearGameStatusClickSnapshot()
    }
}







Macro_ClearGameStatusClickSnapshot() {
    global gameStatusClickSnapshotRow, gameStatusClickSnapshotHwnd
    global gameStatusClickSnapshotWasAutoHoverActivated, gameStatusClickSnapshotWasLastActive
    gameStatusClickSnapshotRow := 0
    gameStatusClickSnapshotHwnd := 0
    gameStatusClickSnapshotWasAutoHoverActivated := false
    gameStatusClickSnapshotWasLastActive := false
}

Macro_GameStatusMouseMove(wParam, lParam, msg, hwnd) {
    global gameStatusGui

    if (!IsObject(gameStatusGui) || !gameStatusGui.Hwnd)
        return

    pointerLockStillInside := Macro_UpdateGameStatusPointerLock()

    helpGuiHwnd := Macro_GetShortcutHelpHwnd()
    if (helpGuiHwnd && hwnd = helpGuiHwnd)
        return

    ; Keep the current selector state while an app temporarily covers the panel
    ; beneath a stationary pointer. The lock ends only when the pointer leaves.
    if (pointerLockStillInside && !Macro_IsGameStatusPointerActuallyOnPanel())
        return

    target := Macro_GetGameStatusHoverTarget(hwnd)
    if (!target && hwnd = gameStatusGui.Hwnd) {
        MouseGetPos(, , , &controlHwnd, 2)
        target := Macro_GetGameStatusHoverTarget(controlHwnd)
    }

    pointerOnPanel := pointerLockStillInside || Macro_IsGameStatusPointerActuallyOnPanel()
    if (!pointerOnPanel) {
        target := 0
        Macro_ResetGameStatusHoverSession()
    }

    ; Preserve the existing behavior: hovering a game row selects that Roblox
    ; client. The pointer lock keeps the selector itself fixed during activation.
    if (target > 0)
        Macro_ActivateGameStatusRowByHover(target)

    Macro_SetGameStatusHoverTarget(target, false)
    Macro_RefreshGameStatusRowVisuals()
    Macro_UpdateGameStatusUsernameTooltip(target)
}

Macro_ResetGameStatusHoverSession() {
    global gameStatusAutoHoverHwnd, gameStatusHoverSessionOriginHwnd
    global gameStatusHoverSessionActive

    ; Clear the one-activation-per-row session when the pointer leaves the
    ; selector or the selector is hidden.
    gameStatusAutoHoverHwnd := 0
    gameStatusHoverSessionOriginHwnd := 0
    gameStatusHoverSessionActive := false
}

Macro_ActivateGameStatusRowByHover(target) {
    global gameStatusRowTargets, gameStatusAutoHoverHwnd, gameStatusHoverSessionOriginHwnd
    global gameStatusHoverSessionActive
    global gameStatusLastActiveRobloxHwnd, gameStatusTrackedHwnd, gameStatusPointerLockActive

    if (target <= 0 || target > gameStatusRowTargets.Length)
        return
    if (!Macro_IsGameStatusPointerActuallyOnPanel())
        return

    targetHwnd := gameStatusRowTargets[target]
    if (!targetHwnd || !WinExist("ahk_id " . targetHwnd)
        || !Macro_IsGameStatusRobloxHwnd(targetHwnd))
        return

    ; Capture the foreground client once per continuous stay inside the selector.
    ; Moving across blank spaces between rows must not start a new session or
    ; repeatedly send activation to the same Roblox client.
    if (!gameStatusHoverSessionActive) {
        originHwnd := WinActive("ahk_exe RobloxPlayerBeta.exe")
        if (!originHwnd || !WinExist("ahk_id " . originHwnd))
            originHwnd := gameStatusLastActiveRobloxHwnd
        if (!originHwnd || !WinExist("ahk_id " . originHwnd))
            originHwnd := gameStatusTrackedHwnd
        if (originHwnd && !WinExist("ahk_id " . originHwnd))
            originHwnd := 0
        gameStatusHoverSessionOriginHwnd := originHwnd
        gameStatusHoverSessionActive := true
    }

    ; The marker now means only "last row handled in this pointer session".
    ; It has no rollback behavior and never changes the selector to TOPMOST.
    if (gameStatusAutoHoverHwnd = targetHwnd) {
        if (WinActive("ahk_id " . targetHwnd) = targetHwnd) {
            gameStatusLastActiveRobloxHwnd := targetHwnd
            gameStatusTrackedHwnd := targetHwnd
        }
        return
    }

    gameStatusAutoHoverHwnd := targetHwnd

    ; Preserve the existing behavior for minimized Roblox clients: restore only
    ; on a real row transition, then activate the selected client once.
    try {
        if (WinGetMinMax("ahk_id " . targetHwnd) = -1) {
            WinRestore("ahk_id " . targetHwnd)
            try {
                if (WinGetMinMax("ahk_id " . targetHwnd) = 1)
                    Macro_RestoreSingleGameStatusPlacement(targetHwnd, "ahk_id " . targetHwnd)
            } catch {
            }
        }
    } catch {
    }

    try {
        if (WinActive("ahk_id " . targetHwnd) != targetHwnd)
            WinActivate("ahk_id " . targetHwnd)
    } catch {
    }

    if (WinActive("ahk_id " . targetHwnd) = targetHwnd) {
        gameStatusLastActiveRobloxHwnd := targetHwnd
        gameStatusTrackedHwnd := targetHwnd
    }

    ; Dock once when the hovered target changes. The docking helper checks the
    ; existing normal-band order, so repeated hover/timer calls don't reshuffle it.
    if (gameStatusPointerLockActive) {
        Macro_KeepGameStatusWindowAtLockedPosition()
        Macro_KeepGameStatusWindowAboveTrackedRoblox()
    }
}

Macro_UpdateGameStatusUsernameTooltip(target) {
    global gameStatusRowTargets, gameStatusTooltipText, gameStatusTooltipRowIndex
    global gameStatusTooltipX, gameStatusTooltipY
    global gameStatusGui, gameStatusRows, gameIdentityByPid, gameStatusAllMiniCtrl

    if (!IsObject(gameStatusGui) || !gameStatusGui.Hwnd
        || target = 0 || target < -1
        || (target > 0 && (target > gameStatusRowTargets.Length
            || !IsObject(gameStatusRows) || target > gameStatusRows.Length))
        || (target = -1 && !IsObject(gameStatusAllMiniCtrl))) {
        if (gameStatusTooltipText != "")
            ToolTip("",,, 19)
        gameStatusTooltipText := ""
        gameStatusTooltipRowIndex := 0
        gameStatusTooltipX := -1
        gameStatusTooltipY := -1
        return
    }

    tooltipText := ""
    tooltipCtrl := ""
    if (target = -1) {
        ; The compact Restore control explains its action only on hover.
        tooltipText := Macro_GetGameSelectorUIText("restoreAllTooltip")
        tooltipCtrl := gameStatusAllMiniCtrl
    } else {
        targetHwnd := gameStatusRowTargets[target]
        try {
            if (targetHwnd && WinExist("ahk_id " . targetHwnd)) {
                pid := WinGetPID("ahk_id " . targetHwnd)
                if (pid && gameIdentityByPid.Has(pid)) {
                    info := gameIdentityByPid[pid]
                    if (IsObject(info) && info.HasOwnProp("username"))
                        tooltipText := Trim(info.username . "")
                    if (tooltipText = "" && IsObject(info) && info.HasOwnProp("userId"))
                        tooltipText := Macro_ResolveRobloxAccountUsername(info.userId)
                }
            }
        } catch {
            tooltipText := ""
        }
        try tooltipCtrl := gameStatusRows[target].label
    }

    if (tooltipText = "" || !IsObject(tooltipCtrl) || !tooltipCtrl.Hwnd) {
        if (gameStatusTooltipText != "")
            ToolTip("",,, 19)
        gameStatusTooltipText := ""
        gameStatusTooltipRowIndex := 0
        gameStatusTooltipX := -1
        gameStatusTooltipY := -1
        return
    }

    ; Anchor the tooltip to its actual control instead of the mouse pointer.
    ; This also keeps the compact Restore explanation aligned with its button.
    tooltipX := -1
    tooltipY := -1
    tooltipPositionFound := false
    try {
        controlRect := Buffer(16, 0)
        if (DllCall("user32\GetWindowRect", "Ptr", tooltipCtrl.Hwnd,
            "Ptr", controlRect.Ptr, "Int")) {
            controlLeft := NumGet(controlRect, 0, "Int")
            controlBottom := NumGet(controlRect, 12, "Int")
            tooltipX := controlLeft
            tooltipY := controlBottom + 2
            tooltipPositionFound := true
        }
    } catch {
        tooltipX := -1
        tooltipY := -1
    }

    ; If the control rectangle is temporarily unavailable, hide the stale tooltip.
    if (!tooltipPositionFound) {
        if (gameStatusTooltipText != "")
            ToolTip("",,, 19)
        gameStatusTooltipText := ""
        gameStatusTooltipRowIndex := 0
        gameStatusTooltipX := -1
        gameStatusTooltipY := -1
        return
    }

    if (tooltipText = gameStatusTooltipText && target = gameStatusTooltipRowIndex
        && tooltipX = gameStatusTooltipX && tooltipY = gameStatusTooltipY)
        return

    ; ToolTip coordinates are explicitly interpreted in desktop/screen space.
    CoordMode("ToolTip", "Screen")
    ToolTip(tooltipText, tooltipX, tooltipY, 19)
    gameStatusTooltipText := tooltipText
    gameStatusTooltipRowIndex := target
    gameStatusTooltipX := tooltipX
    gameStatusTooltipY := tooltipY
}

Macro_GetGameStatusHoverTarget(controlHwnd) {
    global gameStatusGui, gameStatusBackgroundCtrl, gameStatusText, gameStatusLoadingText
    global gameStatusAllMiniCtrl, gameStatusRows, gameStatusSeparators
    try {
        if (IsObject(gameStatusAllMiniCtrl) && controlHwnd = gameStatusAllMiniCtrl.Hwnd)
            return -1
        for i, rowCtrls in gameStatusRows {
            if (controlHwnd = rowCtrls.label.Hwnd || controlHwnd = rowCtrls.icon.Hwnd)
                return i
        }

        ; Treat every point inside the visible status panel as part of its
        ; selector surface, including the padding above, below, and between
        ; text controls. Blank space resolves to the nearest item's center.
        if (IsObject(gameStatusGui) && gameStatusGui.Hwnd
            && DllCall("user32\IsWindowVisible", "Ptr", gameStatusGui.Hwnd)) {
            MouseGetPos(&mouseX, &mouseY)
            WinGetPos(&guiX, &guiY, &guiW, &guiH, "ahk_id " . gameStatusGui.Hwnd)
            if (mouseX >= guiX && mouseX < guiX + guiW
                && mouseY >= guiY && mouseY < guiY + guiH)
                return Macro_GetGameStatusNearestItem()
        }

        isStatusSurface := (IsObject(gameStatusGui) && controlHwnd = gameStatusGui.Hwnd)
        if (IsObject(gameStatusBackgroundCtrl) && controlHwnd = gameStatusBackgroundCtrl.Hwnd)
            isStatusSurface := true
        if (IsObject(gameStatusText) && controlHwnd = gameStatusText.Hwnd)
            isStatusSurface := true
        if (IsObject(gameStatusLoadingText) && controlHwnd = gameStatusLoadingText.Hwnd)
            isStatusSurface := true
        for separatorCtrl in gameStatusSeparators {
            if (IsObject(separatorCtrl) && controlHwnd = separatorCtrl.Hwnd) {
                isStatusSurface := true
                break
            }
        }
        if (isStatusSurface)
            return Macro_GetGameStatusNearestItem()
    } catch {
    }
    return 0
}

Macro_GetGameStatusNearestItem() {
    global gameStatusGui, gameStatusRows, gameStatusAllMiniCtrl
    if (!IsObject(gameStatusGui) || !gameStatusGui.Hwnd)
        return 0

    try {
        MouseGetPos(&mouseX, &mouseY)
        WinGetPos(&guiX, &guiY, , , "ahk_id " . gameStatusGui.Hwnd)
        dpiScale := 1
        try {
            dpi := DllCall("user32\GetDpiForWindow", "Ptr", gameStatusGui.Hwnd, "UInt")
            if (dpi > 0)
                dpiScale := dpi / 96
        } catch {
        }
        localX := (mouseX - guiX) / dpiScale
        nearestTarget := 0
        nearestDistance := 2147483647

        if (IsObject(gameStatusAllMiniCtrl) && gameStatusAllMiniCtrl.Visible) {
            gameStatusAllMiniCtrl.GetPos(&allMiniX, &allMiniY, &allMiniW, &allMiniH)
            distance := Abs(localX - (allMiniX + allMiniW / 2))
            if (distance < nearestDistance) {
                nearestDistance := distance
                nearestTarget := -1
            }
        }

        for i, rowCtrls in gameStatusRows {
            rowCtrls.label.GetPos(&labelX, &labelY, &labelW, &labelH)
            itemLeft := labelX
            ; Reserve the bold width so hit-zone centers remain stable during hover.
            itemRight := labelX + rowCtrls.boldWidth + rowCtrls.labelPadding
            if (rowCtrls.icon.Visible)
                itemRight += rowCtrls.iconGap + rowCtrls.iconWidth
            distance := Abs(localX - ((itemLeft + itemRight) / 2))
            if (distance < nearestDistance) {
                nearestDistance := distance
                nearestTarget := i
            }
        }
        return nearestTarget
    } catch {
        return 0
    }
}


Macro_RefreshGameStatusHover() {
    global gameStatusGui
    if (!IsObject(gameStatusGui) || !gameStatusGui.Hwnd)
        return

    target := 0
    try {
        if (DllCall("user32\IsWindowVisible", "Ptr", gameStatusGui.Hwnd)) {
            MouseGetPos(, , , &controlHwnd, 2)
            target := Macro_GetGameStatusHoverTarget(controlHwnd)
        }
    } catch {
    }
    Macro_SetGameStatusHoverTarget(target)
    Macro_UpdateGameStatusUsernameTooltip(target)
}

Macro_SetGameStatusRowVisual(rowCtrls, isBold, isHovered := false, isSelected := false) {
    try {
        if (!rowCtrls.HasOwnProp("visualBold") || rowCtrls.visualBold != isBold) {
            rowCtrls.label.SetFont(isBold ? "s10 bold" : "s10 norm", "Segoe UI")
            rowCtrls.visualBold := isBold
        }
        ; The active game stays mint; hovering over another game highlights it white.
        hoverColor := isSelected ? "66FFCC" : (isHovered ? "FFFFFF" : rowCtrls.color)
        if (!rowCtrls.HasOwnProp("visualColor") || rowCtrls.visualColor != hoverColor) {
            rowCtrls.label.Opt("c" . hoverColor)
            rowCtrls.icon.Opt("c" . hoverColor)
            ; Force the text controls to repaint only when their effective color changes.
            ; This prevents stale mint/white glyphs on the layered status surface.
            try rowCtrls.label.Redraw()
            catch {
            }
            try rowCtrls.icon.Redraw()
            catch {
            }
            rowCtrls.visualColor := hoverColor
        }
        rowCtrls.label.GetPos(&labelX, &labelY, &labelW, &labelH)
        ; Keep the label and icon geometry fixed at the reserved bold width.
        ; Hover changes only font/color, avoiding repeated child-window moves.
        labelBoxWidth := rowCtrls.boldWidth + rowCtrls.labelPadding
        if (labelW != labelBoxWidth)
            rowCtrls.label.Move(labelX, labelY, labelBoxWidth, labelH)
        if (rowCtrls.icon.Visible) {
            iconX := labelX + labelBoxWidth + rowCtrls.iconGap
            rowCtrls.icon.GetPos(&currentIconX, &currentIconY, &currentIconW, &currentIconH)
            if (currentIconX != iconX || currentIconY != labelY
                || currentIconW != rowCtrls.iconWidth || currentIconH != labelH)
                rowCtrls.icon.Move(iconX, labelY, rowCtrls.iconWidth, labelH)
        }
        rowCtrls.visualBaseColor := rowCtrls.color
    } catch {
    }
}

Macro_GetGameStatusVisualSelectedHwnd() {
    global gameStatusLastActiveRobloxHwnd, gameStatusTrackedHwnd

    if (Macro_UpdateGameStatusPointerLock()
        && gameStatusTrackedHwnd && WinExist("ahk_id " . gameStatusTrackedHwnd))
        return gameStatusTrackedHwnd

    activeHwnd := 0
    try activeHwnd := Macro_GetGameStatusForegroundRobloxHwnd()
    catch
        activeHwnd := 0
    if (activeHwnd && WinExist("ahk_id " . activeHwnd)) {
        gameStatusLastActiveRobloxHwnd := activeHwnd
        return activeHwnd
    }

    if (gameStatusLastActiveRobloxHwnd && WinExist("ahk_id " . gameStatusLastActiveRobloxHwnd))
        return gameStatusLastActiveRobloxHwnd
    if (gameStatusTrackedHwnd && WinExist("ahk_id " . gameStatusTrackedHwnd))
        return gameStatusTrackedHwnd
    return 0
}

Macro_RefreshGameStatusRowVisuals() {
    global gameStatusRows, gameStatusRowTargets, gameStatusHoveredRowIndex
    static lastSelectedHwnd := -1
    static lastSelectedRow := 0
    static lastHoveredRowIndex := -999
    static lastRowsSignature := ""

    if (!IsObject(gameStatusRows) || !IsObject(gameStatusRowTargets))
        return

    selectedHwnd := Macro_GetGameStatusVisualSelectedHwnd()
    selectedRow := 0
    rowsSignature := ""
    needsInitialVisual := false
    baseColorChanged := false

    ; Detect row/control rebuilds separately from per-row color changes.
    ; Ordinary pointer movement never invalidates the full row set.
    for i, rowCtrls in gameStatusRows {
        rowHwnd := (i <= gameStatusRowTargets.Length) ? gameStatusRowTargets[i] : 0
        if (rowHwnd && rowHwnd = selectedHwnd)
            selectedRow := i

        labelHwnd := 0
        iconHwnd := 0
        try {
            labelHwnd := rowCtrls.label.Hwnd
            iconHwnd := rowCtrls.icon.Hwnd
        } catch {
        }
        rowsSignature .= rowHwnd . ":" . labelHwnd . ":" . iconHwnd . "|"

        if (!rowCtrls.HasOwnProp("visualBold") || !rowCtrls.HasOwnProp("visualColor")
            || !rowCtrls.HasOwnProp("visualBaseColor")) {
            needsInitialVisual := true
        } else if (rowCtrls.visualBaseColor != rowCtrls.color) {
            ; A state-color change affects just this row, unless the controls themselves
            ; were rebuilt (handled below).
            baseColorChanged := true
        }
    }

    controlsChanged := (rowsSignature != lastRowsSignature)
    if (!needsInitialVisual && !controlsChanged && !baseColorChanged
        && selectedHwnd = lastSelectedHwnd
        && gameStatusHoveredRowIndex = lastHoveredRowIndex)
        return

    if (needsInitialVisual || controlsChanged) {
        ; A genuinely new row/control set requires one full initial style pass.
        for i, rowCtrls in gameStatusRows {
            rowHwnd := (i <= gameStatusRowTargets.Length) ? gameStatusRowTargets[i] : 0
            isSelected := (rowHwnd != 0 && rowHwnd = selectedHwnd)
            isHovered := (i = gameStatusHoveredRowIndex)
            Macro_SetGameStatusRowVisual(rowCtrls, (isSelected || isHovered), isHovered, isSelected)
        }
    } else {
        ; With the same controls, update only rows whose selected, hover, or base
        ; color changed. The remaining rows are not re-styled or redrawn.
        for i, rowCtrls in gameStatusRows {
            rowBaseColorChanged := (rowCtrls.visualBaseColor != rowCtrls.color)
            if (i != lastSelectedRow && i != selectedRow
                && i != lastHoveredRowIndex && i != gameStatusHoveredRowIndex
                && !rowBaseColorChanged)
                continue

            rowHwnd := (i <= gameStatusRowTargets.Length) ? gameStatusRowTargets[i] : 0
            isSelected := (rowHwnd != 0 && rowHwnd = selectedHwnd)
            isHovered := (i = gameStatusHoveredRowIndex)
            Macro_SetGameStatusRowVisual(rowCtrls, (isSelected || isHovered), isHovered, isSelected)
        }
    }

    lastSelectedHwnd := selectedHwnd
    lastSelectedRow := selectedRow
    lastHoveredRowIndex := gameStatusHoveredRowIndex
    lastRowsSignature := rowsSignature
}

Macro_SetGameStatusHoverTarget(target, refreshVisuals := true) {
    global gameStatusRows
    global gameStatusHoveredRowIndex, gameStatusAllMiniHovered, gameStatusAllMiniCtrl

    if (target < -1 || target > gameStatusRows.Length)
        target := 0

    desiredHoveredRow := (target > 0) ? target : 0
    desiredAllMiniHovered := (target = -1)
    if (desiredHoveredRow = gameStatusHoveredRowIndex
        && desiredAllMiniHovered = gameStatusAllMiniHovered) {
        ; Selected-client changes are checked by the cached visual refresher;
        ; a repeated same-row hover must not reapply row styles.
        if (refreshVisuals)
            Macro_RefreshGameStatusRowVisuals()
        return false
    }

    previousAllMini := gameStatusAllMiniHovered
    gameStatusHoveredRowIndex := desiredHoveredRow
    gameStatusAllMiniHovered := desiredAllMiniHovered

    try {
        if (previousAllMini && IsObject(gameStatusAllMiniCtrl)) {
            gameStatusAllMiniCtrl.SetFont("s10 norm", "Segoe UI")
            gameStatusAllMiniCtrl.Opt("cFFFFFF")
            try gameStatusAllMiniCtrl.Redraw()
            catch {
            }
        }
        if (gameStatusAllMiniHovered && !previousAllMini && IsObject(gameStatusAllMiniCtrl)) {
            gameStatusAllMiniCtrl.SetFont("s10 bold", "Segoe UI")
            gameStatusAllMiniCtrl.Opt("cFFFFFF")
            try gameStatusAllMiniCtrl.Redraw()
            catch {
            }
        }
    } catch {
    }

    ; Refresh only after an actual hover-state transition. Event handlers can
    ; request one combined refresh after activation settles.
    if (refreshVisuals)
        Macro_RefreshGameStatusRowVisuals()

    ; WM_MOUSEMOVE and the global mouse hook update hover state on demand.
    return true
}

Macro_GetRobloxGameState(hwnd) {
    if (!hwnd || !WinExist("ahk_id " . hwnd))
        return "UNKNOWN"
    identity := Macro_GetGameIdentityForHwnd(hwnd)
    if (IsObject(identity) && identity.HasOwnProp("state"))
        return identity.state
    return "UNKNOWN"
}

Macro_GetRobloxGameNameForHwnd(hwnd) {
    if (!hwnd || !WinExist("ahk_id " . hwnd))
        return ""

    Macro_EnsureGameIdentityCached(hwnd)
    identity := Macro_GetGameIdentityForHwnd(hwnd)
    if (IsObject(identity) && identity.HasOwnProp("name") && identity.name != "")
        return identity.name
    return ""
}

; A PID cache entry is usable only for the exact HWND that produced its log
; record. This prevents a reused PID/HWND from inheriting another client's game.
Macro_GetGameIdentityForHwnd(hwnd) {
    global gameIdentityByPid, gameIdentityLogState

    if (!hwnd || !WinExist("ahk_id " . hwnd))
        return ""
    try {
        if (WinGetProcessName("ahk_id " . hwnd) != "RobloxPlayerBeta.exe")
            return ""
        pid := WinGetPID("ahk_id " . hwnd)
    } catch {
        return ""
    }
    if (!pid || !gameIdentityByPid.Has(pid)) {
        Macro_EnsureGameIdentityCached(hwnd)
        return ""
    }

    identity := gameIdentityByPid[pid]
    if (IsObject(identity) && identity.HasOwnProp("pid") && identity.pid = pid
        && identity.HasOwnProp("hwnd") && identity.hwnd = hwnd)
        return identity

    ; Invalidate a cache/log association that points at a different client and
    ; force that log to be read again for the current window.
    if (IsObject(identity) && identity.HasOwnProp("logPath")
        && gameIdentityLogState.Has(identity.logPath))
        gameIdentityLogState.Delete(identity.logPath)
    gameIdentityByPid.Delete(pid)
    Macro_QueueGameIdentityScan(100)
    return ""
}

Macro_EnsureGameIdentityCached(hwnd) {
    global gameIdentityByPid

    if (!hwnd || !WinExist("ahk_id " . hwnd))
        return

    try {
        pid := WinGetPID("ahk_id " . hwnd)
        if (!pid || gameIdentityByPid.Has(pid))
            return
    } catch {
        return
    }

    ; A new/unknown Roblox PID was encountered. Queue a scan so tracking and
    ; Game-status updates do not block while Roblox logs are read.
    Macro_QueueGameIdentityScan(100)
}

Macro_QueueGameIdentityScan(delayMs := 100) {
    global gameIdentityScanPending
    if (gameIdentityScanPending)
        return
    gameIdentityScanPending := true
    SetTimer(Macro_UpdateGameIdentityProgressive, -Max(1, delayMs))
}

Macro_ResolveRobloxGameName(placeId, universeId := "") {
    global gameNameByUniverseId, gameUniverseByPlaceId

    placeId := Trim(placeId . "")
    universeId := Trim(universeId . "")

    ; Prefer a Universe ID already present in the log. Otherwise resolve
    ; Place ID -> Universe ID through Roblox's public API.
    if (universeId = "" && placeId != "") {
        if (gameUniverseByPlaceId.Has(placeId)) {
            universeId := gameUniverseByPlaceId[placeId]
        } else {
            placeInfo := Macro_RobloxPublicApiGet(
                "https://apis.roblox.com/universes/v1/places/" . placeId . "/universe"
            )
            if (RegExMatch(placeInfo, '"universeId"\s*:\s*(\d+)', &universeMatch)) {
                universeId := universeMatch[1]
                gameUniverseByPlaceId[placeId] := universeId
            }
        }
    }

    if (universeId = "")
        return "Other Game"
    if (gameNameByUniverseId.Has(universeId))
        return gameNameByUniverseId[universeId]

    details := Macro_RobloxPublicApiGet(
        "https://games.roblox.com/v1/games?universeIds=" . universeId
    )
    if (RegExMatch(details, '"name"\s*:\s*"((?:\\.|[^"\\])*)"', &nameMatch)) {
        gameName := Trim(Macro_DecodeJsonString(nameMatch[1]))
        if (gameName != "") {
            gameNameByUniverseId[universeId] := gameName
            return gameName
        }
    }

    return "Other Game"
}

Macro_IsHeroesRngGameName(gameName) {
    ; Heroes RNG is identified from the actual Roblox game title returned by
    ; the API, not from a hard-coded Place ID / Universe ID. Any emoji or other
    ; prefix/suffix in the title is ignored for this internal feature check.
    gameName := Trim(gameName . "")
    if (gameName = "")
        return false
    return !!RegExMatch(StrLower(gameName), "heroes\s*rng")
}

Macro_RobloxPublicApiGet(url) {
    request := ""
    try {
        request := ComObject("WinHttp.WinHttpRequest.5.1")
        ; Keep an unavailable/slow public API from freezing status and modal UI
        ; work for several seconds per lookup. Local game-ID matches remain fast.
        request.SetTimeouts(250, 250, 500, 500)
        request.Open("GET", url, false)
        request.SetRequestHeader("User-Agent", "Mozilla/5.0")
        request.Send()
        if (request.Status != 200)
            return ""
        return request.ResponseText
    } catch {
        return ""
    }
}

Macro_ResolveRobloxAccountDisplayName(userId) {
    global robloxAccountDisplayNameByUserId, robloxAccountUsernameByUserId, robloxAccountLookupTickByUserId

    userId := Trim(userId . "")
    if (!RegExMatch(userId, "^\d+$"))
        return ""
    if (robloxAccountDisplayNameByUserId.Has(userId))
        return robloxAccountDisplayNameByUserId[userId]

    nowTick := A_TickCount
    if (robloxAccountLookupTickByUserId.Has(userId)
        && nowTick - robloxAccountLookupTickByUserId[userId] < 600000)
        return ""
    robloxAccountLookupTickByUserId[userId] := nowTick

    quote := Chr(34)
    payload := "{" . quote . "userIds" . quote . ":[" . userId . "]," . quote . "excludeBannedUsers" . quote . ":false}"
    responseText := Macro_RobloxPublicApiPost("https://users.roblox.com/v1/users", payload)
    displayName := ""
    username := ""
    if (RegExMatch(responseText, '"displayName"\s*:\s*"((?:\\.|[^"\\])*)"', &displayMatch))
        displayName := Trim(Macro_DecodeJsonString(displayMatch[1]))
    if (RegExMatch(responseText, '"name"\s*:\s*"((?:\\.|[^"\\])*)"', &userMatch))
        username := Trim(Macro_DecodeJsonString(userMatch[1]))

    accountName := (displayName != "") ? displayName : username
    if (username != "")
        robloxAccountUsernameByUserId[userId] := username
    if (accountName != "")
        robloxAccountDisplayNameByUserId[userId] := accountName
    return accountName
}

Macro_ResolveRobloxAccountUsername(userId) {
    global robloxAccountUsernameByUserId, robloxAccountLookupTickByUserId, robloxAccountDisplayNameByUserId

    userId := Trim(userId . "")
    if (!RegExMatch(userId, "^\d+$"))
        return ""
    if (robloxAccountUsernameByUserId.Has(userId))
        return robloxAccountUsernameByUserId[userId]

    nowTick := A_TickCount
    if (robloxAccountLookupTickByUserId.Has(userId)
        && nowTick - robloxAccountLookupTickByUserId[userId] < 600000)
        return ""
    robloxAccountLookupTickByUserId[userId] := nowTick

    quote := Chr(34)
    payload := "{" . quote . "userIds" . quote . ":[" . userId . "]," . quote . "excludeBannedUsers" . quote . ":false}"
    responseText := Macro_RobloxPublicApiPost("https://users.roblox.com/v1/users", payload)
    username := ""
    displayName := ""
    if (RegExMatch(responseText, '"name"\s*:\s*"((?:\\.|[^"\\])*)"', &userMatch))
        username := Trim(Macro_DecodeJsonString(userMatch[1]))
    if (RegExMatch(responseText, '"displayName"\s*:\s*"((?:\\.|[^"\\])*)"', &displayMatch))
        displayName := Trim(Macro_DecodeJsonString(displayMatch[1]))
    if (username != "")
        robloxAccountUsernameByUserId[userId] := username
    if (displayName != "" && !robloxAccountDisplayNameByUserId.Has(userId))
        robloxAccountDisplayNameByUserId[userId] := displayName
    return username
}

Macro_RobloxPublicApiPost(url, payload) {
    request := ""
    try {
        request := ComObject("WinHttp.WinHttpRequest.5.1")
        request.SetTimeouts(250, 250, 500, 500)
        request.Open("POST", url, false)
        request.SetRequestHeader("User-Agent", "Mozilla/5.0")
        request.SetRequestHeader("Content-Type", "application/json")
        request.Send(payload)
        if (request.Status != 200)
            return ""
        return request.ResponseText
    } catch {
        return ""
    }
}

Macro_DecodeJsonString(encoded) {
    decoded := ""
    slash := Chr(92)
    quote := Chr(34)
    i := 1
    length := StrLen(encoded)

    while (i <= length) {
        currentChar := SubStr(encoded, i, 1)
        if (currentChar != slash) {
            decoded .= currentChar
            i += 1
            continue
        }

        escapeChar := SubStr(encoded, i + 1, 1)
        consumed := 2
        if (escapeChar = quote)
            decoded .= quote
        else if (escapeChar = slash)
            decoded .= slash
        else if (escapeChar = "/")
            decoded .= "/"
        else if (escapeChar = "n" || escapeChar = "r" || escapeChar = "t")
            decoded .= " "
        else if (escapeChar = "b")
            decoded .= Chr(8)
        else if (escapeChar = "f")
            decoded .= Chr(12)
        else if (escapeChar = "u") {
            hex := SubStr(encoded, i + 2, 4)
            if (RegExMatch(hex, "i)^[0-9a-f]{4}$")) {
                codePoint := Integer("0x" . hex)
                consumed := 6
                ; Join escaped UTF-16 surrogate pairs so emoji in a title survive.
                if (codePoint >= 0xD800 && codePoint <= 0xDBFF
                    && SubStr(encoded, i + 6, 2) = slash . "u") {
                    lowHex := SubStr(encoded, i + 8, 4)
                    if (RegExMatch(lowHex, "i)^[0-9a-f]{4}$")) {
                        lowPoint := Integer("0x" . lowHex)
                        if (lowPoint >= 0xDC00 && lowPoint <= 0xDFFF) {
                            codePoint := 0x10000 + ((codePoint - 0xD800) << 10) + (lowPoint - 0xDC00)
                            consumed := 12
                        }
                    }
                }
                decoded .= Chr(codePoint)
            }
        } else {
            decoded .= escapeChar
        }
        i += consumed
    }

    return decoded
}

Macro_ParseRobloxGameSessionLog(text) {
    lastHwnd := 0
    lastPlaceId := ""
    lastUniverseId := ""
    lastGamePlaceId := ""
    lastGameUniverseId := ""
    lastUserId := ""
    presence := "UNKNOWN"
    hasGameSession := false
    disconnectAfterJoin := false
    voluntaryExitAfterJoin := false

    for line in StrSplit(text, Chr(10), Chr(13)) {
        if (RegExMatch(line, "i)window\s*=\s*0x([0-9a-f]+)", &wm))
            lastHwnd := Integer("0x" . wm[1])
        else if (RegExMatch(line, "i)windowHandle\s*=\s*0x([0-9a-f]+)", &whm))
            lastHwnd := Integer("0x" . whm[1])

        ; Roblox builds may write the local account ID on a line separate from
        ; "Joining game". Keep the latest explicit user ID from the whole log.
        if (RegExMatch(line, "i)\buser(?:[\s_-]*id)?[=\s:]+(\d+)", &usrm))
            lastUserId := usrm[1]

        if (RegExMatch(line, "i)Joining game.*?place\s+(\d+)", &pm)) {
            lastPlaceId := pm[1]
            lastUniverseId := ""
            if (RegExMatch(line, "i)universe(?:Id)?[=\s:]+(\d+)", &um))
                lastUniverseId := um[1]
            lastGamePlaceId := lastPlaceId
            lastGameUniverseId := lastUniverseId
            hasGameSession := true
            disconnectAfterJoin := false
            voluntaryExitAfterJoin := false
            presence := "IN_GAME"
        }

        ; A clean user-initiated leave also writes "Sending disconnect with reason: 285".
        ; Once the log has entered the explicit leave/return-to-app path, that
        ; trailing network teardown must not be labeled as an unexpected drop.
        if (hasGameSession && !voluntaryExitAfterJoin && RegExMatch(line,
            "i)(Error Code:\s*\d+|Disconnect reason received:\s*(?!285\b)\d+|Disconnection Notification\.\s*Reason:\s*(?!285\b)\d+|Sending disconnect with reason:\s*(?!285\b)\d+|Lost connection to the game server|Lost connection with reason\s*:|Client has been disconnected with reason:|Connection lost(?:\s|:|$)|Session Transition FSM: Error Occurred\.)")) {
            disconnectAfterJoin := true
            presence := "DISCONNECTED"
        }

        ; Preserve the last actual game IDs for a disconnect summary, then clear
        ; the active IDs so normal account/status displays still show the app state.
        if (hasGameSession
            && (InStr(line, "leaveUGCGameInternal") || InStr(line, "returnToLuaApp"))) {
            voluntaryExitAfterJoin := true
            disconnectAfterJoin := false
            presence := "ONLINE"
            lastPlaceId := ""
            lastUniverseId := ""
        }

        if (InStr(line, "Entered play session.")) {
            hasGameSession := true
            disconnectAfterJoin := false
            voluntaryExitAfterJoin := false
            presence := "IN_GAME"
        } else if (InStr(line, "Entered app session.")
            && (!hasGameSession || (voluntaryExitAfterJoin && !disconnectAfterJoin))) {
            presence := "ONLINE"
        }
    }

    return {
        hwnd:lastHwnd,
        placeId:lastPlaceId,
        universeId:lastUniverseId,
        lastGamePlaceId:lastGamePlaceId,
        lastGameUniverseId:lastGameUniverseId,
        userId:lastUserId,
        presence:presence,
        voluntaryExit:voluntaryExitAfterJoin
    }
}

Macro_IsRobloxVoluntaryExitLog(path) {
    path := Trim(path . "")
    if (path = "" || !FileExist(path))
        return false

    f := ""
    text := ""
    try {
        f := FileOpen(path, "r", "UTF-8")
        if (!f)
            return false
        text := f.Read()
        f.Close()
    } catch {
        try f.Close()
        catch {
        }
        return false
    }

    if (text = "")
        return false
    parsed := Macro_ParseRobloxGameSessionLog(text)
    return parsed.voluntaryExit && parsed.presence = "ONLINE"
}
Macro_UpdateGameIdentity() {
    global gameIdentityByPid, gameIdentityLogState
    global GAME_IDENTITY_LOG_LOOKBACK_MIN
    global gameIdentityInitialScanComplete, gameIdentityScanPending
    global gameIdentityScanActive, gameIdentityScanQueue, gameIdentityScanIndex
    global disconnectLogDiagSignal, disconnectLogDiagFile

    SetTimer(Macro_UpdateGameIdentityProgressive, 0)
    gameIdentityScanActive := false
    gameIdentityScanQueue := []
    gameIdentityScanIndex := 0
    gameIdentityScanPending := true

    localAppData := EnvGet("LOCALAPPDATA")
    logDir := localAppData . "\\Roblox\\logs"
    if (!DirExist(logDir)) {
        gameIdentityInitialScanComplete := true
        gameIdentityScanPending := false
        Macro_SortGameStatusDisplayOrder()
        Macro_UpdateGameStatusDisplay()
        return
    }

    nowTick := A_TickCount
    currentHwnds := Map()
    try {
        for hwnd in WinGetList("ahk_exe RobloxPlayerBeta.exe")
            currentHwnds[hwnd] := true
    } catch {
    }

    ; 오래된 로그는 판별 후보에서 제외합니다.
    Loop Files, logDir . "\\*_last.log", "F" {
        path := A_LoopFileFullPath
        ; 로그의 파일 수정 시각은 Roblox의 실제 게임 실행 시각과 항상 일치하지
        ; 않을 수 있으므로, 현재 창과 HWND가 일치하는 로그는 시간 제한 없이 확인합니다.

        size := A_LoopFileSize
        modifiedTime := A_LoopFileTimeModified
        oldSize := -1
        oldModifiedTime := ""
        if (gameIdentityLogState.Has(path)) {
            oldSize := gameIdentityLogState[path].size
            if (gameIdentityLogState[path].HasOwnProp("modified"))
                oldModifiedTime := gameIdentityLogState[path].modified
        }

        if (oldSize = size && oldModifiedTime = modifiedTime)
            continue

        text := ""
        try {
            f := FileOpen(path, "r", "UTF-8")
            if (!f)
                continue
            text := f.Read()
            f.Close()
        } catch {
            try f.Close()
            catch {
            }
            continue
        }

        if (text = "")
            continue

        parsedLog := Macro_ParseRobloxGameSessionLog(text)
        lastHwnd := parsedLog.hwnd
        lastPlaceId := parsedLog.placeId
        lastUniverseId := parsedLog.universeId
        lastGamePlaceId := parsedLog.lastGamePlaceId
        lastGameUniverseId := parsedLog.lastGameUniverseId
        lastUserId := parsedLog.userId
        presence := parsedLog.presence
        voluntaryExit := parsedLog.voluntaryExit

        gameIdentityLogState[path] := {size:size, modified:modifiedTime, hwnd:lastHwnd, placeId:lastPlaceId, universeId:lastUniverseId, lastGamePlaceId:lastGamePlaceId, lastGameUniverseId:lastGameUniverseId, userId:lastUserId, presence:presence, voluntaryExit:voluntaryExit, tick:nowTick}

        if (lastHwnd && (lastPlaceId != "" || presence = "ONLINE" || presence = "DISCONNECTED")) {
            try {
                if (WinExist("ahk_id " . lastHwnd)) {
                    pid := WinGetPID("ahk_id " . lastHwnd)
                    if (pid) {
                        accountName := (presence = "ONLINE" && lastUserId != "") ? Macro_ResolveRobloxAccountDisplayName(lastUserId) : ""
                        gameName := (lastPlaceId = "") ? ((accountName != "") ? accountName : "Online") : Macro_ResolveRobloxGameName(lastPlaceId, lastUniverseId)
                        state := (lastPlaceId = "") ? "ONLINE"
                            : (Macro_IsHeroesRngGameName(gameName) ? "RNG_HEROES" : "OTHER_ROBLOX_GAME")
                        if (lastPlaceId = "" && gameName = "")
                            gameName := "Online"
                        username := ""
                        if (lastUserId != "")
                            username := Macro_ResolveRobloxAccountUsername(lastUserId)
                        gameIdentityByPid[pid] := {state:state, presence:presence, name:gameName, accountName:accountName, username:username, hwnd:lastHwnd, pid:pid, placeId:lastPlaceId, universeId:lastUniverseId, lastGamePlaceId:lastGamePlaceId, lastGameUniverseId:lastGameUniverseId, userId:lastUserId, voluntaryExit:voluntaryExit, logPath:path, tick:nowTick}
                        if (disconnectLogDiagSignal && path = disconnectLogDiagFile)
                            SetTimer(Macro_RefreshDisconnectAlertGameName, -1)
                    }
                }
            } catch {
            }
        }
    }

    gameIdentityInitialScanComplete := true
    gameIdentityScanPending := false
    Macro_UpdateGameStatusDisplay()
}

Macro_UpdateGameIdentityProgressive() {
    global gameIdentityScanPending, gameIdentityScanActive, gameIdentityScanQueue, gameIdentityScanIndex
    global gameStatusVisible

    if (!gameIdentityScanPending)
        return

    if (!gameIdentityScanActive) {
        localAppData := EnvGet("LOCALAPPDATA")
        logDir := localAppData . "\Roblox\logs"
        gameIdentityScanQueue := []
        gameIdentityScanIndex := 1
        gameIdentityScanActive := true

        if (DirExist(logDir)) {
            Loop Files, logDir . "\*_last.log", "F"
                gameIdentityScanQueue.Push({
                    path:A_LoopFileFullPath,
                    size:A_LoopFileSize,
                    modified:A_LoopFileTimeModified
                })
        }

        if (gameIdentityScanQueue.Length = 0) {
            Macro_CompleteGameIdentityScan()
            return
        }
    }

    if (gameIdentityScanIndex > gameIdentityScanQueue.Length) {
        Macro_CompleteGameIdentityScan()
        return
    }

    logEntry := gameIdentityScanQueue[gameIdentityScanIndex]
    gameIdentityScanIndex += 1
    if (Macro_ProcessGameIdentityLog(
        logEntry.path, logEntry.size, A_TickCount, logEntry.modified
    ) && gameStatusVisible)
        Macro_UpdateGameStatusDisplay()

    ; Yield between files so the GUI can paint each newly classified row.
    if (gameIdentityScanIndex <= gameIdentityScanQueue.Length)
        SetTimer(Macro_UpdateGameIdentityProgressive, -1)
    else
        Macro_CompleteGameIdentityScan()
}

Macro_ProcessGameIdentityLog(path, size, nowTick, modifiedTime := "") {
    global gameIdentityByPid, gameIdentityLogState
        global disconnectLogDiagSignal, disconnectLogDiagFile

    oldSize := -1
    oldModifiedTime := ""
    if (gameIdentityLogState.Has(path)) {
        oldSize := gameIdentityLogState[path].size
        if (gameIdentityLogState[path].HasOwnProp("modified"))
            oldModifiedTime := gameIdentityLogState[path].modified
    }
    if (oldSize = size && (modifiedTime = "" || oldModifiedTime = modifiedTime))
        return false

    text := ""
    f := ""
    try {
        f := FileOpen(path, "r", "UTF-8")
        if (!f)
            return false
        text := f.Read()
        f.Close()
    } catch {
        try f.Close()
        catch {
        }
        return false
    }

    if (text = "")
        return false

    parsedLog := Macro_ParseRobloxGameSessionLog(text)
    lastHwnd := parsedLog.hwnd
    lastPlaceId := parsedLog.placeId
    lastUniverseId := parsedLog.universeId
    lastGamePlaceId := parsedLog.lastGamePlaceId
    lastGameUniverseId := parsedLog.lastGameUniverseId
    lastUserId := parsedLog.userId
    presence := parsedLog.presence
    voluntaryExit := parsedLog.voluntaryExit

    gameIdentityLogState[path] := {size:size, modified:modifiedTime, hwnd:lastHwnd, placeId:lastPlaceId, universeId:lastUniverseId, lastGamePlaceId:lastGamePlaceId, lastGameUniverseId:lastGameUniverseId, userId:lastUserId, presence:presence, voluntaryExit:voluntaryExit, tick:nowTick}

    if (lastHwnd && (lastPlaceId != "" || presence = "ONLINE" || presence = "DISCONNECTED")) {
        try {
            if (WinExist("ahk_id " . lastHwnd)) {
                pid := WinGetPID("ahk_id " . lastHwnd)
                if (pid) {
                    accountName := (presence = "ONLINE" && lastUserId != "") ? Macro_ResolveRobloxAccountDisplayName(lastUserId) : ""
                    gameName := (lastPlaceId = "") ? ((accountName != "") ? accountName : "Online") : Macro_ResolveRobloxGameName(lastPlaceId, lastUniverseId)
                    state := (lastPlaceId = "") ? "ONLINE"
                        : (Macro_IsHeroesRngGameName(gameName) ? "RNG_HEROES" : "OTHER_ROBLOX_GAME")
                    if (lastPlaceId = "" && gameName = "")
                        gameName := "Online"
                    username := ""
                    if (lastUserId != "")
                        username := Macro_ResolveRobloxAccountUsername(lastUserId)
                    gameIdentityByPid[pid] := {state:state, presence:presence, name:gameName, accountName:accountName, username:username, hwnd:lastHwnd, pid:pid, placeId:lastPlaceId, universeId:lastUniverseId, lastGamePlaceId:lastGamePlaceId, lastGameUniverseId:lastGameUniverseId, userId:lastUserId, voluntaryExit:voluntaryExit, logPath:path, tick:nowTick}
                    if (disconnectLogDiagSignal && path = disconnectLogDiagFile)
                        SetTimer(Macro_RefreshDisconnectAlertGameName, -1)
                    return true
                }
            }
        } catch {
        }
    }
    return false
}

Macro_CompleteGameIdentityScan() {
    global gameIdentityInitialScanComplete, gameIdentityScanPending
    global gameIdentityScanActive, gameIdentityScanQueue, gameIdentityScanIndex
    global gameStatusVisible, gameStatusGui
    global disconnectAlertActive, disconnectAlertStage, disconnectLogDiagSignal
    global fixedPointModalDebugEnabled

    gameIdentityInitialScanComplete := true
    gameIdentityScanPending := false
    gameIdentityScanActive := false
    gameIdentityScanQueue := []
    gameIdentityScanIndex := 0
    SetTimer(Macro_UpdateGameIdentityProgressive, 0)
    Macro_SortGameStatusDisplayOrder()
    Macro_UpdateGameStatusDisplay()
    Macro_FinalizeGameStatusIdentityTransaction()

    if (disconnectAlertActive && (disconnectAlertStage = "Signal" || disconnectAlertStage = "Confirmed"))
        Macro_RefreshDisconnectAlertGameName()
    if (fixedPointModalDebugEnabled)
        Macro_UpdateFixedPointModalDebugText()

    ; The scan only updates contents. The requested visible state remains owned
    ; by the user toggle, so completion must not leave its panel hidden.
    if (gameStatusVisible && IsObject(gameStatusGui) && gameStatusGui.Hwnd) {
        try {
            if (!DllCall("user32\IsWindowVisible", "Ptr", gameStatusGui.Hwnd))
                gameStatusGui.Show("NoActivate")
        } catch {
        }
        Macro_SyncGameStatusPosition()
    }
}

Macro_SortGameStatusDisplayOrder() {
    global gameStatusDisplayOrder

    ; Add newly opened clients and remove closed ones before stable partitioning.
    try {
        for hwnd in WinGetList("ahk_exe RobloxPlayerBeta.exe") {
            found := false
            for savedHwnd in gameStatusDisplayOrder {
                if (savedHwnd = hwnd) {
                    found := true
                    break
                }
            }
            if (!found)
                gameStatusDisplayOrder.Push(hwnd)
        }
    } catch {
    }

    heroesFirst := []
    remaining := []
    for hwnd in gameStatusDisplayOrder {
        if (!WinExist("ahk_id " . hwnd))
            continue
        if (Macro_GetRobloxGameState(hwnd) = "RNG_HEROES")
            heroesFirst.Push(hwnd)
        else
            remaining.Push(hwnd)
    }

    gameStatusDisplayOrder := []
    for hwnd in heroesFirst
        gameStatusDisplayOrder.Push(hwnd)
    for hwnd in remaining
        gameStatusDisplayOrder.Push(hwnd)
}

Macro_GetRobloxClientIndex(targetHwnd, hwndList := "") {
    if (!targetHwnd)
        return 0

    if (!IsObject(hwndList)) {
        try
            hwndList := WinGetList("ahk_exe RobloxPlayerBeta.exe")
        catch {
            return 0
        }
    }

    index := 0
    for hwnd in hwndList {
        if (!WinExist("ahk_id " . hwnd))
            continue
        index += 1
        if (hwnd = targetHwnd)
            return index
    }
    return 0
}







Macro_GetGameStatusRootWindowHwnd(hwnd) {
    if (!hwnd)
        return 0
    try {
        rootHwnd := DllCall("user32\GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr") ; GA_ROOT
        return rootHwnd ? rootHwnd : hwnd
    } catch {
        return hwnd
    }
}

Macro_GetGameStatusPointerRoots(&mouseX, &mouseY, &rootWindowHwnd, &rootControlHwnd) {
    underWindow := 0
    underControl := 0
    mouseX := 0
    mouseY := 0
    rootWindowHwnd := 0
    rootControlHwnd := 0
    try MouseGetPos(&mouseX, &mouseY, &underWindow, &underControl, 2)
    catch {
        return
    }
    rootWindowHwnd := Macro_GetGameStatusRootWindowHwnd(underWindow)
    rootControlHwnd := Macro_GetGameStatusRootWindowHwnd(underControl)
}

Macro_IsGameStatusRobloxHwnd(hwnd) {
    if (!hwnd || !WinExist("ahk_id " . hwnd))
        return false
    try return (WinGetProcessName("ahk_id " . hwnd) = "RobloxPlayerBeta.exe")
    catch
        return false
}

Macro_IsGameStatusOwnProcessHwnd(hwnd) {
    if (!hwnd || !WinExist("ahk_id " . hwnd))
        return false
    try return (WinGetPID("ahk_id " . hwnd) = WinGetPID("ahk_id " . A_ScriptHwnd))
    catch
        return false
}

Macro_IsGameStatusPointerActuallyOnPanel() {
    global gameStatusGui
    if (!IsObject(gameStatusGui) || !gameStatusGui.Hwnd
        || !DllCall("user32\IsWindowVisible", "Ptr", gameStatusGui.Hwnd))
        return false
    Macro_GetGameStatusPointerRoots(&mouseX, &mouseY, &rootWindow, &rootControl)
    return (rootWindow = gameStatusGui.Hwnd || rootControl = gameStatusGui.Hwnd)
}

Macro_GetGameStatusRobloxWindowUnderPointer() {
    global gameStatusGui
    Macro_GetGameStatusPointerRoots(&mouseX, &mouseY, &rootWindow, &rootControl)
    roots := [rootWindow, rootControl]
    for hwnd in roots {
        if (!hwnd)
            continue
        if (IsObject(gameStatusGui) && gameStatusGui.Hwnd && hwnd = gameStatusGui.Hwnd)
            continue
        if (Macro_IsGameStatusRobloxHwnd(hwnd))
            return hwnd
    }
    return 0
}

Macro_UpdateGameStatusPointerLock() {
    global gameStatusGui, gameStatusVisible
    global gameStatusPointerLockActive, gameStatusPointerLockX, gameStatusPointerLockY
    global gameStatusPointerLockW, gameStatusPointerLockH

    if (!IsObject(gameStatusGui) || !gameStatusGui.Hwnd || !WinExist("ahk_id " . gameStatusGui.Hwnd))
        return false

    ; A short internal Hide/Show during a completed identity refresh must not
    ; clear a lock that was already established by the user's pointer position.
    if (!DllCall("user32\IsWindowVisible", "Ptr", gameStatusGui.Hwnd))
        return gameStatusPointerLockActive

    Macro_GetGameStatusPointerRoots(&mouseX, &mouseY, &rootWindow, &rootControl)
    hitPanel := (rootWindow = gameStatusGui.Hwnd || rootControl = gameStatusGui.Hwnd)
    WinGetPos(&guiX, &guiY, &guiW, &guiH, "ahk_id " . gameStatusGui.Hwnd)
    if (guiW <= 0 || guiH <= 0)
        return gameStatusPointerLockActive

    insidePanelRect := (mouseX >= guiX && mouseX < guiX + guiW
        && mouseY >= guiY && mouseY < guiY + guiH)

    if (!gameStatusPointerLockActive) {
        ; Only a real hit on the visible selector can begin a lock. Merely being
        ; inside the old rectangle while another application covers it is not enough.
        if (hitPanel && insidePanelRect) {
            gameStatusPointerLockActive := true
            gameStatusPointerLockX := guiX
            gameStatusPointerLockY := guiY
            gameStatusPointerLockW := guiW
            gameStatusPointerLockH := guiH
            return true
        }
        return false
    }

    ; Once the pointer entered the selector, keep its screen position locked
    ; until the pointer leaves the original rectangle. Do not unlock merely
    ; because activating/clicking a Roblox window changes the hit-tested HWND.
    ; The selector must not jump away while the user is still interacting with it.
    insideLockedRect := (mouseX >= gameStatusPointerLockX
        && mouseX < gameStatusPointerLockX + gameStatusPointerLockW
        && mouseY >= gameStatusPointerLockY
        && mouseY < gameStatusPointerLockY + gameStatusPointerLockH)

    if (insideLockedRect)
        return true

    ; Pointer has left the selector's latched rectangle. Resume tracking and
    ; allow the same row to activate again after the next hover entry.
    Macro_ResetGameStatusHoverSession()
    gameStatusPointerLockActive := false
    gameStatusPointerLockX := 0
    gameStatusPointerLockY := 0
    gameStatusPointerLockW := 0
    gameStatusPointerLockH := 0
    return false
}

Macro_ResetGameStatusPointerLock() {
    global gameStatusPointerLockActive, gameStatusPointerLockX, gameStatusPointerLockY
    global gameStatusPointerLockW, gameStatusPointerLockH
    gameStatusPointerLockActive := false
    gameStatusPointerLockX := 0
    gameStatusPointerLockY := 0
    gameStatusPointerLockW := 0
    gameStatusPointerLockH := 0
}

Macro_KeepGameStatusWindowAtLockedPosition() {
    global gameStatusGui, gameStatusPointerLockActive, gameStatusPointerLockX, gameStatusPointerLockY
    if (!gameStatusPointerLockActive || !IsObject(gameStatusGui) || !gameStatusGui.Hwnd)
        return
    try {
        WinGetPos(&x, &y, &w, &h, "ahk_id " . gameStatusGui.Hwnd)
        if (w > 0 && h > 0 && (x != gameStatusPointerLockX || y != gameStatusPointerLockY)) {
            DllCall("user32\SetWindowPos", "Ptr", gameStatusGui.Hwnd, "Ptr", 0,
                "Int", gameStatusPointerLockX, "Int", gameStatusPointerLockY,
                "Int", 0, "Int", 0, "UInt", 0x0015) ; NOSIZE | NOZORDER | NOACTIVATE
        }
    } catch {
    }
}

Macro_GetGameStatusForegroundRobloxHwnd() {
    foregroundHwnd := DllCall("user32\GetForegroundWindow", "Ptr")
    if (!foregroundHwnd)
        return 0
    try {
        if (WinGetProcessName("ahk_id " . foregroundHwnd) = "RobloxPlayerBeta.exe")
            return foregroundHwnd
    } catch {
    }
    return 0
}

Macro_KeepGameStatusWindowAboveTrackedRoblox() {
    global gameStatusGui, gameStatusTrackedHwnd
    global gameStatusPointerLockActive, gameStatusClickFocusHandoffPending
    if (!IsObject(gameStatusGui) || !gameStatusGui.Hwnd
        || !WinExist("ahk_id " . gameStatusGui.Hwnd))
        return

    try {
        activeRobloxHwnd := Macro_GetGameStatusForegroundRobloxHwnd()
        pointerRobloxHwnd := Macro_GetGameStatusRobloxWindowUnderPointer()
        keepTopmost := (activeRobloxHwnd
            || (pointerRobloxHwnd && WinExist("ahk_id " . pointerRobloxHwnd))
            || gameStatusPointerLockActive || gameStatusClickFocusHandoffPending)

        panelExStyle := DllCall("user32\GetWindowLongPtrW", "Ptr", gameStatusGui.Hwnd, "Int", -20, "Ptr")
        panelIsTopmost := (panelExStyle & 0x00000008) != 0

        if (keepTopmost) {
            robloxWindowSet := Map()
            for candidateHwnd in WinGetList("ahk_exe RobloxPlayerBeta.exe")
                robloxWindowSet[candidateHwnd] := true

            robloxWindowAbovePanel := false
            zHwnd := DllCall("user32\GetWindow", "Ptr", gameStatusGui.Hwnd, "UInt", 3, "Ptr")
            while (zHwnd) {
                if (robloxWindowSet.Has(zHwnd)) {
                    robloxWindowAbovePanel := true
                    break
                }
                zHwnd := DllCall("user32\GetWindow", "Ptr", zHwnd, "UInt", 3, "Ptr")
            }

            if (!panelIsTopmost || robloxWindowAbovePanel) {
                DllCall("user32\SetWindowPos", "Ptr", gameStatusGui.Hwnd, "Ptr", -1,
                    "Int", 0, "Int", 0, "Int", 0, "Int", 0,
                    "UInt", 0x0013) ; HWND_TOPMOST | NOSIZE | NOMOVE | NOACTIVATE
            }
            return
        }

        if (panelIsTopmost) {
            DllCall("user32\SetWindowPos", "Ptr", gameStatusGui.Hwnd, "Ptr", -2,
                "Int", 0, "Int", 0, "Int", 0, "Int", 0,
                "UInt", 0x0013) ; HWND_NOTOPMOST | NOSIZE | NOMOVE | NOACTIVATE
        }

        if (!gameStatusTrackedHwnd || !WinExist("ahk_id " . gameStatusTrackedHwnd))
            return

        targetExStyle := DllCall("user32\GetWindowLongPtrW", "Ptr", gameStatusTrackedHwnd, "Int", -20, "Ptr")
        if ((targetExStyle & 0x00000008) != 0)
            return

        anchor := Macro_GetGameStatusZOrderAnchor(gameStatusTrackedHwnd)
        currentNormalAbove := Macro_GetGameStatusPreviousNormalZOrderWindow(gameStatusGui.Hwnd)
        if (currentNormalAbove != anchor) {
            DllCall("user32\SetWindowPos", "Ptr", gameStatusGui.Hwnd, "Ptr", anchor,
                "Int", 0, "Int", 0, "Int", 0, "Int", 0,
                "UInt", 0x001B) ; NOSIZE | NOMOVE | NOREDRAW | NOACTIVATE
        }
    } catch {
    }
}
Macro_GetGameStatusPreviousNormalZOrderWindow(hwnd) {
    global gameStatusGui
    if (!hwnd)
        return 0

    try {
        sibling := DllCall("user32\GetWindow", "Ptr", hwnd, "UInt", 3, "Ptr") ; GW_HWNDPREV
        while (sibling) {
            if (IsObject(gameStatusGui) && gameStatusGui.Hwnd && sibling = gameStatusGui.Hwnd) {
                sibling := DllCall("user32\GetWindow", "Ptr", sibling, "UInt", 3, "Ptr")
                continue
            }
            exStyle := DllCall("user32\GetWindowLongPtrW", "Ptr", sibling, "Int", -20, "Ptr")
            if ((exStyle & 0x00000008) = 0)
                return sibling
            sibling := DllCall("user32\GetWindow", "Ptr", sibling, "UInt", 3, "Ptr")
        }
    } catch {
    }
    return 0
}

Macro_SyncGameStatusPosition(foregroundTargetHwnd := 0) {
    global gameStatusGui, gameStatusVisible, gameStatusTrackedHwnd
    global gameStatusLastActiveRobloxHwnd, gameStatusClickFocusHandoffPending
    global gameStatusPointerLockActive
    global gameStatusTrackedX, gameStatusTrackedY, gameStatusTrackedW, gameStatusTrackedH

    GAME_STATUS_TOP_OFFSET := 0
    panelHwnd := 0
    try {
        if (IsObject(gameStatusGui))
            panelHwnd := gameStatusGui.Hwnd
    } catch {
        panelHwnd := 0
    }
    if (!panelHwnd || !WinExist("ahk_id " . panelHwnd))
        return

    ; A direct Sync can be triggered by focus/WinEvent callbacks without a
    ; preceding watcher pass. If the selector is logically enabled but its
    ; HWND is hidden, restore it here before testing position/Z-order.
    if (gameStatusVisible) {
        try {
            if (DllCall("user32\IsIconic", "Ptr", panelHwnd, "Int"))
                DllCall("user32\ShowWindow", "Ptr", panelHwnd, "Int", 4) ; SW_SHOWNOACTIVATE
            else if (!DllCall("user32\IsWindowVisible", "Ptr", panelHwnd))
                gameStatusGui.Show("NoActivate")
        } catch {
        }
    }

    try {
        activeRobloxHwnd := Macro_GetGameStatusForegroundRobloxHwnd()
        if (foregroundTargetHwnd && WinExist("ahk_id " . foregroundTargetHwnd))
            activeRobloxHwnd := foregroundTargetHwnd

        ; Do not retarget or reposition the selector until the pointer leaves it.
        if (Macro_UpdateGameStatusPointerLock()) {
            Macro_KeepGameStatusWindowAtLockedPosition()
            Macro_KeepGameStatusWindowAboveTrackedRoblox()
            return
        }

        if (activeRobloxHwnd && WinExist("ahk_id " . activeRobloxHwnd)) {
            if (activeRobloxHwnd != gameStatusTrackedHwnd)
                gameStatusClickFocusHandoffPending := false
            gameStatusTrackedHwnd := activeRobloxHwnd
            gameStatusLastActiveRobloxHwnd := activeRobloxHwnd
        }

        pointerRobloxHwnd := Macro_GetGameStatusRobloxWindowUnderPointer()
        if (activeRobloxHwnd && WinExist("ahk_id " . activeRobloxHwnd)) {
            gameStatusTrackedHwnd := activeRobloxHwnd
            gameStatusLastActiveRobloxHwnd := activeRobloxHwnd
        } else if (pointerRobloxHwnd && WinExist("ahk_id " . pointerRobloxHwnd)) {
            gameStatusTrackedHwnd := pointerRobloxHwnd
        } else {
            if ((!gameStatusTrackedHwnd || !WinExist("ahk_id " . gameStatusTrackedHwnd))
                && gameStatusLastActiveRobloxHwnd && WinExist("ahk_id " . gameStatusLastActiveRobloxHwnd)) {
                gameStatusTrackedHwnd := gameStatusLastActiveRobloxHwnd
            }
        }

        if (!gameStatusTrackedHwnd || !WinExist("ahk_id " . gameStatusTrackedHwnd)) {
            replacementHwnd := Macro_GetGameStatusForegroundRobloxHwnd()
            if (!replacementHwnd && gameStatusLastActiveRobloxHwnd
                && WinExist("ahk_id " . gameStatusLastActiveRobloxHwnd))
                replacementHwnd := gameStatusLastActiveRobloxHwnd
            if (!replacementHwnd) {
                robloxWindows := WinGetList("ahk_exe RobloxPlayerBeta.exe")
                if (robloxWindows.Length)
                    replacementHwnd := robloxWindows[1]
            }
            if (!replacementHwnd || !WinExist("ahk_id " . replacementHwnd))
                return
            gameStatusTrackedHwnd := replacementHwnd
            gameStatusLastActiveRobloxHwnd := replacementHwnd
        }

        WinGetPos(&gx, &gy, &gw, &gh, "ahk_id " . gameStatusGui.Hwnd)
        if (gw <= 0 || gh <= 0)
            return
        WinGetPos(&rx, &ry, &rw, &rh, "ahk_id " . gameStatusTrackedHwnd)
        if (rw <= 0 || rh <= 0)
            return

        gameStatusTrackedX := rx
        gameStatusTrackedY := ry
        gameStatusTrackedW := rw
        gameStatusTrackedH := rh
        targetX := rx + Round((rw - gw) / 2)
        targetY := ry + GAME_STATUS_TOP_OFFSET
        needsMove := (gx != targetX || gy != targetY)

        currentTopmost := false
        panelExStyle := DllCall("user32\GetWindowLongPtrW", "Ptr", gameStatusGui.Hwnd, "Int", -20, "Ptr")
        currentTopmost := (panelExStyle & 0x00000008) != 0

        keepTopmost := (activeRobloxHwnd
            || (pointerRobloxHwnd && WinExist("ahk_id " . pointerRobloxHwnd))
            || gameStatusPointerLockActive || gameStatusClickFocusHandoffPending)

        if (keepTopmost) {
            robloxWindowSet := Map()
            for candidateHwnd in WinGetList("ahk_exe RobloxPlayerBeta.exe")
                robloxWindowSet[candidateHwnd] := true

            robloxWindowAbovePanel := false
            zHwnd := DllCall("user32\GetWindow", "Ptr", gameStatusGui.Hwnd, "UInt", 3, "Ptr")
            while (zHwnd) {
                if (robloxWindowSet.Has(zHwnd)) {
                    robloxWindowAbovePanel := true
                    break
                }
                zHwnd := DllCall("user32\GetWindow", "Ptr", zHwnd, "UInt", 3, "Ptr")
            }

            if (foregroundTargetHwnd || !currentTopmost || robloxWindowAbovePanel) {
                DllCall("user32\SetWindowPos", "Ptr", gameStatusGui.Hwnd, "Ptr", -1,
                    "Int", targetX, "Int", targetY, "Int", gw, "Int", gh,
                    "UInt", 0x0010) ; HWND_TOPMOST | NOACTIVATE
            } else if (needsMove) {
                DllCall("user32\SetWindowPos", "Ptr", gameStatusGui.Hwnd, "Ptr", 0,
                    "Int", targetX, "Int", targetY, "Int", gw, "Int", gh,
                    "UInt", 0x0014) ; NOZORDER | NOACTIVATE
            }
            return
        }

        if (currentTopmost) {
            DllCall("user32\SetWindowPos", "Ptr", gameStatusGui.Hwnd, "Ptr", -2,
                "Int", 0, "Int", 0, "Int", 0, "Int", 0,
                "UInt", 0x0013) ; HWND_NOTOPMOST | NOSIZE | NOMOVE | NOACTIVATE
            currentTopmost := false
        }

        targetExStyle := DllCall("user32\GetWindowLongPtrW", "Ptr", gameStatusTrackedHwnd, "Int", -20, "Ptr")
        if ((targetExStyle & 0x00000008) != 0) {
            if (needsMove) {
                DllCall("user32\SetWindowPos", "Ptr", gameStatusGui.Hwnd, "Ptr", 0,
                    "Int", targetX, "Int", targetY, "Int", gw, "Int", gh,
                    "UInt", 0x0014) ; NOZORDER | NOACTIVATE
            }
            return
        }

        isAboveRoblox := false
        zHwnd := DllCall("user32\GetWindow", "Ptr", gameStatusTrackedHwnd, "UInt", 3, "Ptr")
        while (zHwnd) {
            if (zHwnd = gameStatusGui.Hwnd) {
                isAboveRoblox := true
                break
            }
            zHwnd := DllCall("user32\GetWindow", "Ptr", zHwnd, "UInt", 3, "Ptr")
        }

        anchor := Macro_GetGameStatusZOrderAnchor(gameStatusTrackedHwnd)
        if (isAboveRoblox) {
            if (needsMove) {
                DllCall("user32\SetWindowPos", "Ptr", gameStatusGui.Hwnd, "Ptr", 0,
                    "Int", targetX, "Int", targetY, "Int", gw, "Int", gh,
                    "UInt", 0x0014) ; NOZORDER | NOACTIVATE
            }
        } else if (!needsMove) {
            DllCall("user32\SetWindowPos", "Ptr", gameStatusGui.Hwnd, "Ptr", anchor,
                "Int", 0, "Int", 0, "Int", 0, "Int", 0,
                "UInt", 0x001B) ; NOSIZE | NOMOVE | NOREDRAW | NOACTIVATE
        } else {
            DllCall("user32\SetWindowPos", "Ptr", gameStatusGui.Hwnd, "Ptr", anchor,
                "Int", targetX, "Int", targetY, "Int", gw, "Int", gh,
                "UInt", 0x0010) ; NOACTIVATE
        }
    } catch {
    }
}

Macro_GetGameStatusZOrderAnchor(targetHwnd) {
    global gameStatusGui, robloxTitlebarControlsByHwnd
    if (!targetHwnd)
        return 0

    targetEx := 0
    try targetEx := DllCall("user32\GetWindowLongPtrW", "Ptr", targetHwnd, "Int", -20, "Ptr")
    catch
        targetEx := 0
    ; For normal-band placement, do not anchor to a TOPMOST target window.
    if ((targetEx & 0x00000008) != 0)
        return 0

    anchor := 0
    try anchor := DllCall("user32\GetWindow", "Ptr", targetHwnd, "UInt", 3, "Ptr")
    catch
        anchor := 0

    while (anchor) {
        skipAnchor := false
        if (IsObject(gameStatusGui) && gameStatusGui.Hwnd && anchor = gameStatusGui.Hwnd)
            skipAnchor := true
        if (!skipAnchor && IsObject(robloxTitlebarControlsByHwnd)) {
            for controlTargetHwnd, titlebarControls in robloxTitlebarControlsByHwnd {
                try {
                    if (IsObject(titlebarControls.gui) && titlebarControls.gui.Hwnd = anchor) {
                        skipAnchor := true
                        break
                    }
                } catch {
                }
            }
        }
        if (skipAnchor) {
            try anchor := DllCall("user32\GetWindow", "Ptr", anchor, "UInt", 3, "Ptr")
            catch
                anchor := 0
            continue
        }

        ex := 0
        try ex := DllCall("user32\GetWindowLongPtrW", "Ptr", anchor, "Int", -20, "Ptr")
        catch
            ex := 0
        if ((ex & 0x00000008) = 0)
            return anchor

        try anchor := DllCall("user32\GetWindow", "Ptr", anchor, "UInt", 3, "Ptr")
        catch
            anchor := 0
    }
    return 0
}

Macro_UpdateGameStatusDisplay() {
    global gameStatusDisplayOrder
    global gameStatusGui, gameStatusText, gameStatusBackgroundCtrl, gameStatusRows, gameStatusSeparators, gameStatusAllMiniCtrl
    global gameStatusRowTargets, gameStatusRenderedRowTargets
    global gameStatusLastText, gameStatusVisible
    global gameIdentityByPid, gameStatusTrackedHwnd, gameStatusLastActiveRobloxHwnd, disconnectAlertGui
    global gameStatusLoadingText, gameIdentityScanPending
    global gameStatusLastLayoutKey, gameStatusLastGuiWidth, gameStatusLastGuiHeight
    global gameStatusLastStableIdentityKey, gameStatusLastStableRowTargetsKey
    global gameStatusCurrentIdentityKey, gameStatusCurrentRowTargetsKey
    global gameStatusPreMaxPlacements

    if (!gameStatusVisible || !IsObject(gameStatusGui) || !IsObject(gameStatusText))
        return

    try {
        if (!WinExist("ahk_id " . gameStatusGui.Hwnd)) {
            Macro_CreateGameStatusGUI()
            if (!IsObject(gameStatusGui) || !IsObject(gameStatusText))
                return
        }
    } catch {
        return
    }

    try {
        if (IsObject(gameStatusLoadingText))
            gameStatusLoadingText.Visible := false
    } catch {
    }

    hwndList := []
    try {
        hwndList := WinGetList("ahk_exe RobloxPlayerBeta.exe")
    } catch {
        hwndList := []
    }

    ; Remove saved maximized placements for closed clients and recycled HWNDs.
    stalePlacementHwnds := []
    for savedHwnd, savedState in gameStatusPreMaxPlacements {
        sameClient := !!WinExist("ahk_id " . savedHwnd)
        if (sameClient) {
            try sameClient := (WinGetPID("ahk_id " . savedHwnd) = savedState.pid)
            catch
                sameClient := false
        }
        if (!sameClient)
            stalePlacementHwnds.Push(savedHwnd)
    }
    for savedHwnd in stalePlacementHwnds
        gameStatusPreMaxPlacements.Delete(savedHwnd)

    ; WinGetList follows Z-order, so freeze first-seen row order and append
    ; newly detected clients. Raising a client must not move its row.
    orderIndex := gameStatusDisplayOrder.Length
    while (orderIndex >= 1) {
        if (!WinExist("ahk_id " . gameStatusDisplayOrder[orderIndex]))
            gameStatusDisplayOrder.RemoveAt(orderIndex)
        orderIndex -= 1
    }
    for hwnd in hwndList {
        if (!WinExist("ahk_id " . hwnd))
            continue
        found := false
        for savedHwnd in gameStatusDisplayOrder {
            if (savedHwnd = hwnd) {
                found := true
                break
            }
        }
        if (!found)
            gameStatusDisplayOrder.Push(hwnd)
    }
    hwndList := gameStatusDisplayOrder.Clone()

    ; Preserve the displayed target while the selector is under the pointer,
    ; even if a deliberate click changes which Roblox client is foreground.
    displayActiveRobloxHwnd := Macro_GetGameStatusForegroundRobloxHwnd()
    pointerLockActive := Macro_UpdateGameStatusPointerLock()
    pointerRobloxHwnd := 0
    if (!pointerLockActive && !displayActiveRobloxHwnd)
        pointerRobloxHwnd := Macro_GetGameStatusRobloxWindowUnderPointer()

    currentRobloxHwnd := 0
    if (pointerLockActive && gameStatusTrackedHwnd && WinExist("ahk_id " . gameStatusTrackedHwnd)) {
        currentRobloxHwnd := gameStatusTrackedHwnd
    } else if (displayActiveRobloxHwnd && WinExist("ahk_id " . displayActiveRobloxHwnd)) {
        currentRobloxHwnd := displayActiveRobloxHwnd
        gameStatusLastActiveRobloxHwnd := displayActiveRobloxHwnd

    } else if (pointerRobloxHwnd && WinExist("ahk_id " . pointerRobloxHwnd)) {
        currentRobloxHwnd := pointerRobloxHwnd
    } else if (gameStatusLastActiveRobloxHwnd && WinExist("ahk_id " . gameStatusLastActiveRobloxHwnd)) {
        currentRobloxHwnd := gameStatusLastActiveRobloxHwnd
    } else if (gameStatusTrackedHwnd && WinExist("ahk_id " . gameStatusTrackedHwnd)) {
        currentRobloxHwnd := gameStatusTrackedHwnd
    }
    gameStatusTrackedHwnd := currentRobloxHwnd
    statusWindowMaximized := false
    try statusWindowMaximized := (WinGetMinMax("ahk_id " . currentRobloxHwnd) = 1)
    catch
        statusWindowMaximized := false

    ; Compact only the selector panel when the currently tracked Roblox client
    ; is in F11 fullscreen mode. Normal and maximized window layouts keep their
    ; existing 32px geometry.
    statusWindowFullscreen := false
    if (currentRobloxHwnd && WinExist("ahk_id " . currentRobloxHwnd)) {
        try statusWindowFullscreen := (Macro_GetRobloxWindowMode(currentRobloxHwnd) = 3)
        catch
            statusWindowFullscreen := false
    }

    ; Keep the client rows in their existing order. Only exchange the displayed
    ; A-number so the currently selected client is labeled A1.
    currentDisplayIndex := 0
    probeIndex := 0
    for candidate in hwndList {
        if (!WinExist("ahk_id " . candidate))
            continue
        probeIndex += 1
        if (candidate = currentRobloxHwnd)
            currentDisplayIndex := probeIndex
    }

    rows := []
    if (hwndList.Length = 0) {
        noClientsText := Macro_GetGameSelectorUIText("noClients")
        rows.Push({hwnd:0, text:noClientsText, labelText:noClientsText, identityText:noClientsText, icon:"", iconGap:0, color:"FFFFFF", selected:false})
    } else {
        index := 0
        for hwnd in hwndList {
            if (!WinExist("ahk_id " . hwnd))
                continue

            index += 1
            pid := 0
            try {
                pid := WinGetPID("ahk_id " . hwnd)
            } catch {
                pid := 0
            }

            name := Macro_GetGameSelectorUIText("checking")
            gameIcon := ""
            stateIcon := "🟡"
            color := "FFFFFF"
            presence := "UNKNOWN"

            info := Macro_GetGameIdentityForHwnd(hwnd)
            if (IsObject(info)) {
                if (info.HasOwnProp("presence"))
                    presence := info.presence
                if (info.state = "RNG_HEROES" || info.state = "OTHER_ROBLOX_GAME") {
                    ; Display the exact game title returned by Roblox.
                    ; Existing emoji in that title is preserved; no extra
                    ; game-specific emoji is added by the macro.
                    name := (info.HasOwnProp("name") && info.name != "") ? info.name : "Other Game"
                    stateIcon := ""
                    gameIcon := ""
                    color := "FFFFFF"
                }
            }

            ; Session status takes precedence over the last experience name.
            ; Voluntary leave returns to the app as Online; a network/error
            ; disconnect remains visible until a later Joining game event.
            if (presence = "DISCONNECTED") {
                name := "Disconnected"
                gameIcon := ""
                stateIcon := ""
            } else if (presence = "ONLINE") {
                ; Online is the safe default after leaving a game. Replace it
                ; only when Roblox account lookup supplied a display name or username.
                name := "Online"
                onlineInfo := Macro_GetGameIdentityForHwnd(hwnd)
                if (IsObject(onlineInfo)) {
                    if (onlineInfo.HasOwnProp("accountName") && onlineInfo.accountName != "")
                        name := onlineInfo.accountName
                }
                gameIcon := ""
                stateIcon := ""
            }

            displayIndex := index
            if (currentDisplayIndex) {
                if (hwnd = currentRobloxHwnd)
                    displayIndex := 1
                else if (index = 1)
                    displayIndex := currentDisplayIndex
            }

            if (name = "Other Game")
                name := Macro_GetGameSelectorUIText("otherGame")
            else if (name = "Disconnected")
                name := Macro_GetGameSelectorUIText("disconnected")
            else if (name = "Online")
                name := Macro_GetGameSelectorUIText("online")
            else if (name = "Checking...")
                name := Macro_GetGameSelectorUIText("checking")

            labelText := "A" . displayIndex . "  " . name
            rowIcon := (gameIcon != "") ? gameIcon : stateIcon
            iconGap := (gameIcon != "") ? 4 : (stateIcon != "" ? 12 : 0)
            rowText := labelText . (rowIcon != "" ? " " . rowIcon : "")
            isSelected := (hwnd = currentRobloxHwnd)
            rows.Push({
                hwnd: hwnd,
                text: rowText,
                labelText: labelText,
                identityText: name,
                icon: rowIcon,
                iconGap: iconGap,
                color: color,
                selected: isSelected
            })
        }
    }

    ; Layout/size is recalculated only when the visible row set/text or DPI changes.
    ; Mouse movement, clicks, and pure position changes reuse the previous size.
    currentDpi := 96
    try currentDpi := DllCall("user32\GetDpiForWindow", "Ptr", gameStatusGui.Hwnd, "UInt")
    catch {
        try currentDpi := A_ScreenDPI
        catch
            currentDpi := 96
    }
    if (currentDpi < 1)
        currentDpi := 96

    allMiniVisible := (hwndList.Length > 0)
    try gameStatusAllMiniCtrl.Visible := allMiniVisible

    ; Stable signatures intentionally ignore A-number/selection changes.
    ; They represent only the actual Roblox client set and confirmed identity text.
    rowTargetsKey := ""
    identityKey := ""
    for row in rows {
        rowTargetsKey .= row.hwnd . "|"
        identityKey .= row.hwnd . ":" . row.identityText . "|"
    }
    ; Record what is currently rendered. Do not perform the game-status-equivalent
    ; reset from inside this renderer; callers perform it only after a
    ; completed identity/layout transaction.
    gameStatusCurrentIdentityKey := identityKey
    gameStatusCurrentRowTargetsKey := rowTargetsKey

    ; Layout key intentionally excludes the currently selected row and its A-number.
    ; Hovering another Roblox row changes selection styling and at most two label
    ; strings; it must not trigger the layout measurement/control-update path.
    ; Maximized-state text offset is handled as a small positional adjustment below.
    layoutKey := currentDpi . "|AllMini=" . (allMiniVisible ? "1" : "0")
        . "|LogScan=" . (gameIdentityScanPending ? "1" : "0")
        . "|FullscreenCompact=" . (statusWindowFullscreen ? "1" : "0") . "|"
    for row in rows
        layoutKey .= row.hwnd . ":" . row.identityText . ":" . row.icon . ":" . row.iconGap
            . ":" . row.color . "|"

    gameStatusRowTargets := []
    for row in rows
        gameStatusRowTargets.Push(row.hwnd)

    layoutChanged := (layoutKey != gameStatusLastLayoutKey)
    if (layoutKey = gameStatusLastLayoutKey) {
        ; No structural/content layout change: update only dynamic A-numbers, if any.
        ; This is the common path while hovering between already-known Roblox clients.
        topPadding := statusWindowFullscreen ? 0 : 4
        textTopPadding := statusWindowFullscreen ? 0 : (topPadding + (statusWindowMaximized ? 4 : 0))

        for rowIndex, row in rows {
            if (rowIndex > gameStatusRows.Length)
                break
            rowCtrls := gameStatusRows[rowIndex]
            try {
                if (rowCtrls.label.Text != row.labelText) {
                    rowCtrls.label.Text := row.labelText
                    rowCtrls.label.Redraw()
                }
                rowCtrls.label.GetPos(&labelX, &labelY, &labelW, &labelH)
                if (labelY != textTopPadding)
                    rowCtrls.label.Move(labelX, textTopPadding, labelW, labelH)
                if (rowCtrls.icon.Visible) {
                    rowCtrls.icon.GetPos(&iconX, &iconY, &iconW, &iconH)
                    if (iconY != textTopPadding)
                        rowCtrls.icon.Move(iconX, textTopPadding, iconW, iconH)
                }
            } catch {
            }
        }

        ; Keep the vertical offset used by maximized clients without rerunning layout.
        try {
            if (IsObject(gameStatusAllMiniCtrl)) {
                gameStatusAllMiniCtrl.GetPos(&allX, &allY, &allW, &allH)
                if (allY != textTopPadding)
                    gameStatusAllMiniCtrl.Move(allX, textTopPadding, allW, allH)
            }
        } catch {
        }
        for sep in gameStatusSeparators {
            try {
                sep.GetPos(&sepX, &sepY, &sepW, &sepH)
                if (sepY != textTopPadding)
                    sep.Move(sepX, textTopPadding, sepW, sepH)
            } catch {
            }
        }

        display := ""
        for row in rows
            display .= (display = "" ? "" : "`n") . row.text
        gameStatusLastText := display

        try {
            if (!DllCall("user32\IsWindowVisible", "Ptr", gameStatusGui.Hwnd))
                gameStatusGui.Show("NoActivate")
        } catch {
        }
        Macro_SyncGameStatusPosition()
        Macro_RefreshGameStatusHover()
        return
    }

    ; The visible A-number/selection text can change when focus moves, without
    ; changing which Roblox rows exist. Preserve hover state in that case; only
    ; invalidate it later if the actual row-target list changed.

    ; Measure labels in both weights; layout reserves bold width and icons follow
    ; each label's active weight so their visual gap stays constant.
    measuredWidth := 0
    rowLabelWidths := []
    rowBoldWidths := []
    rowNormalWidths := []
    rowWidths := []
    labelPadding := 2
    emojiWidth := 28
    for row in rows {
        measureCtrl := ""
        lineWidth := 0
        ; Reserve width using the largest possible A-number for this row count.
        ; A1/A2 selection swaps then never alter the row's control geometry.
        measureLabelText := row.hwnd ? ("A" . rows.Length . "  " . row.identityText) : row.labelText
        try {
            ; Allocate every label at its hover-bold width so no trailing word
            ; or glyph is clipped when the whole row changes weight.
            gameStatusGui.SetFont("s10 bold", "Segoe UI")
            measureCtrl := gameStatusGui.AddText("x0 y0 Hidden", measureLabelText)
            gameStatusGui.SetFont("s10 norm", "Segoe UI")
            measureCtrl.GetPos(&measureX, &measureY, &lineWidth, &measureH)
            measuredWidth := Max(measuredWidth, lineWidth)
        } catch {
        }
        if (lineWidth <= 0)
            lineWidth := Max(1, StrLen(row.labelText) * 10)
        boldTextWidth := lineWidth
        normalCtrl := ""
        normalWidth := 0
        try {
            gameStatusGui.SetFont("s10 norm", "Segoe UI")
            normalCtrl := gameStatusGui.AddText("x0 y0 Hidden", measureLabelText)
            normalCtrl.GetPos(&measureX, &measureY, &normalWidth, &measureH)
        } catch {
        }
        if (IsObject(normalCtrl)) {
            try normalCtrl.Destroy()
            catch {
            }
        }
        if (normalWidth <= 0)
            normalWidth := boldTextWidth
        rowBoldWidths.Push(boldTextWidth)
        rowNormalWidths.Push(normalWidth)

        ; Reserve the bold pending label width while log results arrive.
        if (gameIdentityScanPending && row.hwnd) {
            prefixEnd := InStr(row.labelText, "  ")
            if (prefixEnd > 0) {
                checkingText := "A" . rows.Length . "  " . Macro_GetGameSelectorUIText("checking")
                reserveCtrl := ""
                reserveWidth := 0
                try {
                    gameStatusGui.SetFont("s10 bold", "Segoe UI")
                    reserveCtrl := gameStatusGui.AddText("x0 y0 Hidden", checkingText)
                    gameStatusGui.SetFont("s10 norm", "Segoe UI")
                    reserveCtrl.GetPos(&measureX, &measureY, &reserveWidth, &measureH)
                    lineWidth := Max(lineWidth, reserveWidth)
                } catch {
                }
                try {
                    if (IsObject(reserveCtrl))
                        reserveCtrl.Destroy()
                } catch {
                }
            }
        }
        rowLabelWidths.Push(lineWidth + labelPadding)
        rowWidths.Push(lineWidth + labelPadding + (row.icon != "" ? row.iconGap + emojiWidth : 0))
        try {
            if (IsObject(measureCtrl))
                measureCtrl.Destroy()
        } catch {
        }
    }

    if (measuredWidth <= 0)
        measuredWidth := 1

    allMiniWidth := 0
    if (allMiniVisible) {
        measureCtrl := ""
        try {
            gameStatusGui.SetFont("s10 bold", "Segoe UI")
            measureCtrl := gameStatusGui.AddText("x0 y0 Hidden", Macro_GetGameSelectorUIText("restoreAll"))
            gameStatusGui.SetFont("s10 norm", "Segoe UI")
            measureCtrl.GetPos(&measureX, &measureY, &allMiniWidth, &measureH)
        } catch {
        }
        allMiniWidth := Max(48, allMiniWidth + 2)
        try {
            if (IsObject(measureCtrl))
                measureCtrl.Destroy()
        } catch {
        }
    }

    measureCtrl := ""
    separatorWidth := 0
    try {
        measureCtrl := gameStatusGui.AddText("x0 y0 Hidden", "/")
        measureCtrl.GetPos(&measureX, &measureY, &separatorWidth, &measureH)
    } catch {
    }
    if (separatorWidth <= 0)
        separatorWidth := 8
    try {
        if (IsObject(measureCtrl))
            measureCtrl.Destroy()
    } catch {
    }

    ; GetPos returns GUI coordinates, so convert only when comparing against
    ; WinGetPos's physical-pixel dimensions.
    dpi := 96
    try dpi := DllCall("user32\GetDpiForWindow", "Ptr", gameStatusGui.Hwnd, "UInt")
    catch {
        try dpi := A_ScreenDPI
        catch
            dpi := 96
    }
    if (dpi < 1)
        dpi := 96
    dpiScale := dpi / 96

    ; Give every game label equal outer padding. Each slash has matching fixed
    ; margins on both sides, including the separator after All Mini.
    gameItemPadding := 6
    separatorPadding := 8
    guiWidth := 6 + (allMiniVisible ? 6 + allMiniWidth + separatorWidth + (separatorPadding * 2) : 0)
    for i, width in rowWidths {
        guiWidth += width + (gameItemPadding * 2)
        if (i < rows.Length)
            guiWidth += separatorWidth + (separatorPadding * 2)
    }
    ; Use a 32-unit target at 96 DPI with a little extra space below the text.
    lineHeight := 24
    topPadding := statusWindowFullscreen ? 0 : 4
    ; Fullscreen uses the 24px text line itself; maximized-window offset remains unchanged elsewhere.
    textTopPadding := statusWindowFullscreen ? 0 : (topPadding + (statusWindowMaximized ? 4 : 0))
    bottomPadding := statusWindowFullscreen ? 0 : 4
    ; Fullscreen selector: 0px top + unchanged 24px text + 0px bottom = 24px.
    ; All other modes preserve the original 4px + 24px + 4px = 32px height.
    guiHeight := Max(statusWindowFullscreen ? 24 : 32, topPadding + lineHeight + bottomPadding)

    ; Keep one persistent background surface exactly the size of the client area.
    try {
        if (IsObject(gameStatusBackgroundCtrl))
            gameStatusBackgroundCtrl.Move(0, 0, guiWidth, guiHeight)
    } catch {
    }

    ; 행 수가 달라지면 컨트롤을 다시 만들고, 같으면 위치/색/문자열만 갱신합니다.
    try {
        separatorCount := Max(0, rows.Length - 1) + (allMiniVisible ? 1 : 0)
        rowTargetsChanged := (gameStatusRenderedRowTargets.Length != rows.Length)
        if (!rowTargetsChanged) {
            for rowIndex, row in rows {
                if (gameStatusRenderedRowTargets[rowIndex] != row.hwnd) {
                    rowTargetsChanged := true
                    break
                }
            }
        }
        if (rowTargetsChanged)
            Macro_SetGameStatusHoverTarget(0)

        if (gameStatusRows.Length != rows.Length || gameStatusSeparators.Length != separatorCount || rowTargetsChanged) {
            for rowCtrls in gameStatusRows {
                try rowCtrls.label.Destroy()
                catch {
                }
                try rowCtrls.icon.Destroy()
                catch {
                }
            }
            for ctrl in gameStatusSeparators {
                try ctrl.Destroy()
                catch {
                }
            }
            gameStatusRows := []
            gameStatusSeparators := []

            x := allMiniVisible ? 9 : 3
            if (allMiniVisible) {
                gameStatusAllMiniCtrl.Move(x, textTopPadding, allMiniWidth, lineHeight)
                x += allMiniWidth + separatorPadding
                separatorCtrl := gameStatusGui.AddText("x" . x . " y" . textTopPadding . " w" . separatorWidth . " h" . lineHeight . " cFFFFFF", "/")
                separatorCtrl.Opt("+0x100")
                gameStatusSeparators.Push(separatorCtrl)
                x += separatorWidth + separatorPadding
            }
            i := 0
            for row in rows {
                i += 1
                x += gameItemPadding
                labelCtrl := gameStatusGui.AddText("x" . x . " y" . textTopPadding . " w" . rowLabelWidths[i] . " h" . lineHeight . " c" . row.color, row.labelText)
                labelCtrl.SetFont(row.selected ? "s10 bold" : "s10 norm", "Segoe UI")
                labelCtrl.Opt("+0x100")
                iconCtrl := gameStatusGui.AddText("x0 y0 w" . emojiWidth . " h" . lineHeight . " c" . row.color, row.icon)
                iconCtrl.SetFont("s12", "Segoe UI Emoji")
                iconCtrl.Opt("+0x100")
                iconCtrl.Visible := (row.icon != "")
                rowCtrls := {
                    label:labelCtrl,
                    icon:iconCtrl,
                    color:row.color,
                    normalWidth:rowNormalWidths[i],
                    boldWidth:rowBoldWidths[i],
                    iconGap:row.iconGap,
                    iconWidth:emojiWidth,
                    labelPadding:labelPadding
                }
                gameStatusRows.Push(rowCtrls)
                Macro_SetGameStatusRowVisual(rowCtrls, row.selected, false, row.selected)
                x += rowWidths[i] + gameItemPadding
                if (i < rows.Length) {
                    x += separatorPadding
                    separatorCtrl := gameStatusGui.AddText("x" . x . " y" . textTopPadding . " w" . separatorWidth . " h" . lineHeight . " cFFFFFF", "/")
                    separatorCtrl.Opt("+0x100")
                    gameStatusSeparators.Push(separatorCtrl)
                    x += separatorWidth + separatorPadding
                }
            }
        } else {
            x := allMiniVisible ? 9 : 3
            if (allMiniVisible) {
                gameStatusAllMiniCtrl.Move(x, textTopPadding, allMiniWidth, lineHeight)
                x += allMiniWidth + separatorPadding
                separatorCtrl := gameStatusSeparators[1]
                separatorCtrl.Move(x, textTopPadding, separatorWidth, lineHeight)
                x += separatorWidth + separatorPadding
                separatorIndex := 1
            } else {
                separatorIndex := 0
            }
            i := 0
            for row in rows {
                i += 1
                rowCtrls := gameStatusRows[i]
                targetLabelX := x + gameItemPadding
                targetLabelY := textTopPadding
                targetLabelW := rowLabelWidths[i]
                targetLabelH := lineHeight

                ; Text controls repaint themselves when their text changes. Avoid
                ; Redraw() on every row for every selection update, which flashes
                ; the complete strip while the pointer is moving across it.
                if (rowCtrls.label.Text != row.labelText) {
                    rowCtrls.label.Text := row.labelText
                    try rowCtrls.label.Redraw()
                    catch {
                    }
                }
                try {
                    rowCtrls.label.GetPos(&oldLabelX, &oldLabelY, &oldLabelW, &oldLabelH)
                    if (oldLabelX != targetLabelX || oldLabelY != targetLabelY
                        || oldLabelW != targetLabelW || oldLabelH != targetLabelH)
                        rowCtrls.label.Move(targetLabelX, targetLabelY, targetLabelW, targetLabelH)
                } catch {
                    rowCtrls.label.Move(targetLabelX, targetLabelY, targetLabelW, targetLabelH)
                }

                rowCtrls.color := row.color
                if (rowCtrls.icon.Text != row.icon) {
                    rowCtrls.icon.Text := row.icon
                    try rowCtrls.icon.Redraw()
                    catch {
                    }
                }
                wantIconVisible := (row.icon != "")
                if (rowCtrls.icon.Visible != wantIconVisible)
                    rowCtrls.icon.Visible := wantIconVisible

                rowCtrls.normalWidth := rowNormalWidths[i]
                rowCtrls.boldWidth := rowBoldWidths[i]
                rowCtrls.iconGap := row.iconGap
                rowCtrls.iconWidth := emojiWidth
                rowCtrls.labelPadding := labelPadding
                x += gameItemPadding
                Macro_SetGameStatusRowVisual(rowCtrls, row.selected, false, row.selected)
                x += rowWidths[i] + gameItemPadding
                if (i < rows.Length) {
                    x += separatorPadding
                    separatorIndex += 1
                    separatorCtrl := gameStatusSeparators[separatorIndex]
                    separatorCtrl.Move(x, textTopPadding, separatorWidth, lineHeight)
                    x += separatorWidth + separatorPadding
                }
            }
        }

        gameStatusText.Move(0, 0, 1, 1)
        gameStatusRenderedRowTargets := gameStatusRowTargets.Clone()
        gameStatusLastLayoutKey := layoutKey
        gameStatusLastGuiWidth := guiWidth
        gameStatusLastGuiHeight := guiHeight
    } catch {
        return
    }

    display := ""
    for row in rows
        display .= (display = "" ? "" : "`n") . row.text
    displayChanged := (display != gameStatusLastText)
    gameStatusLastText := display

    ; 반복 Show()를 하지 않습니다. 크기만 맞춘 뒤 실제 Roblox 위치로 이동합니다.
    try {
        WinGetPos(&curX, &curY, &curW, &curH, "ahk_id " . gameStatusGui.Hwnd)
        isCurrentlyVisible := false
        try isCurrentlyVisible := !!DllCall("user32\IsWindowVisible", "Ptr", gameStatusGui.Hwnd)
        sizeChanged := (curW != Round(guiWidth * dpiScale) || curH != Round(guiHeight * dpiScale))
        ; Do not hide/show for ordinary text changes. On the layered GUI this
        ; can preserve stale pixels and also creates unnecessary flicker.
        ; Only show/resize when the window size or visibility actually changes.
        if (sizeChanged || !isCurrentlyVisible)
            gameStatusGui.Show("w" . guiWidth . " h" . guiHeight . " NoActivate")

        Macro_SyncGameStatusPosition()
        Macro_RefreshGameStatusHover()

        ; A full-surface repaint is needed after a real resize or row-target
        ; rebuild, but not when only A-numbers/selection text changed. The latter
        ; is painted by the specific controls above; repainting every child on
        ; every focus change is a visible source of flicker on the layered GUI.
        if (sizeChanged || rowTargetsChanged) {
            try {
                if (IsObject(gameStatusBackgroundCtrl))
                    gameStatusBackgroundCtrl.Redraw()
            } catch {
            }
            DllCall("user32\RedrawWindow", "Ptr", gameStatusGui.Hwnd
                , "Ptr", 0, "Ptr", 0, "UInt", 0x01A1) ; INVALIDATE | NOERASE | ALLCHILDREN | UPDATENOW
            DllCall("user32\UpdateWindow", "Ptr", gameStatusGui.Hwnd)
        }

    } catch {
    }
}

; Finish a settled identity/layout transaction without hiding the selector.
; Hiding here created a window where an interrupted redraw could leave the
; selector invisible until F8 was toggled manually.
Macro_FinalizeGameStatusIdentityTransaction() {
    global gameStatusGui, gameStatusVisible
    global gameStatusCurrentIdentityKey, gameStatusCurrentRowTargetsKey
    global gameStatusLastStableIdentityKey, gameStatusLastStableRowTargetsKey

    if (!gameStatusVisible || !IsObject(gameStatusGui) || !gameStatusGui.Hwnd)
        return

    if (gameStatusCurrentIdentityKey = gameStatusLastStableIdentityKey
        && gameStatusCurrentRowTargetsKey = gameStatusLastStableRowTargetsKey)
        return

    ; Clear hover tracking before refreshing the selector without undoing the
    ; game selected by hovering.
    try Macro_ResetGameStatusHoverSession()
    try Macro_UpdateGameStatusDisplay()
    catch {
    }

    try {
        if (DllCall("user32\IsIconic", "Ptr", gameStatusGui.Hwnd, "Int"))
            DllCall("user32\ShowWindow", "Ptr", gameStatusGui.Hwnd, "Int", 4) ; SW_SHOWNOACTIVATE
        else if (!DllCall("user32\IsWindowVisible", "Ptr", gameStatusGui.Hwnd))
            gameStatusGui.Show("NoActivate")
    } catch {
    }
    try Macro_SyncGameStatusPosition()
    catch {
    }
    try Macro_RefreshGameStatusHover()
    catch {
    }

    ; Repaint the complete GUI surface, including every child, while keeping
    ; the top-level window visible throughout the identity update.
    try {
        DllCall("user32\RedrawWindow", "Ptr", gameStatusGui.Hwnd
            , "Ptr", 0, "Ptr", 0, "UInt", 0x0585)
        DllCall("user32\UpdateWindow", "Ptr", gameStatusGui.Hwnd)
    } catch {
    }

    gameStatusLastStableIdentityKey := gameStatusCurrentIdentityKey
    gameStatusLastStableRowTargetsKey := gameStatusCurrentRowTargetsKey
}

; =====================================================================
; 🪟 [Roblox-only Taskbar Separation]
; Give each Roblox top-level window a unique System.AppUserModel.ID.
; Windows taskbar grouping is then separated per Roblox HWND, without
; changing the user's global Windows taskbar-combine setting or other apps.
; =====================================================================
Macro_ApplyRobloxTaskbarGrouping() {
    global robloxTaskbarAppIdByHwnd

    hwndList := []
    try {
        hwndList := WinGetList("ahk_exe RobloxPlayerBeta.exe")
    } catch {
        hwndList := []
    }

    liveHwnds := Map()
    for hwnd in hwndList {
        if (!WinExist("ahk_id " . hwnd))
            continue
        liveHwnds[hwnd] := true

        if (robloxTaskbarAppIdByHwnd.Has(hwnd))
            continue

        if (Macro_SetRobloxWindowAppUserModelId(hwnd))
            robloxTaskbarAppIdByHwnd[hwnd] := true
    }

    staleHwnds := []
    for hwnd, applied in robloxTaskbarAppIdByHwnd {
        if (!liveHwnds.Has(hwnd))
            staleHwnds.Push(hwnd)
    }
    for hwnd in staleHwnds
        robloxTaskbarAppIdByHwnd.Delete(hwnd)
}

Macro_SetRobloxWindowAppUserModelId(hwnd) {
    if (!hwnd || !WinExist("ahk_id " . hwnd))
        return false

    propertyStore := 0
    iid := Buffer(16, 0)
    pkey := Buffer(20, 0)
    propVariant := Buffer(16, 0)
    idBuffer := ""

    try {
        ; IPropertyStore IID: {886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99}
        iidResult := DllCall("ole32\CLSIDFromString"
            , "Str", "{886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99}"
            , "Ptr", iid.Ptr
            , "Int")
        if (iidResult != 0)
            return false

        hr := DllCall("shell32\SHGetPropertyStoreForWindow"
            , "Ptr", hwnd
            , "Ptr", iid.Ptr
            , "Ptr*", &propertyStore
            , "Int")
        if (hr != 0 || !propertyStore)
            return false

        ; PKEY_AppUserModel_ID
        ; fmtid = {9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3}, pid = 5
        pkeyResult := DllCall("ole32\CLSIDFromString"
            , "Str", "{9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3}"
            , "Ptr", pkey.Ptr
            , "Int")
        if (pkeyResult != 0)
            return false
        NumPut("UInt", 5, pkey, 16)

        ; PROPVARIANT with VT_LPWSTR. On 64-bit Windows the string pointer
        ; occupies the union at offset 8.
        appId := "Roblox.AHK.Instance." . Format("{:X}", hwnd)
        idBuffer := Buffer((StrLen(appId) + 1) * 2, 0)
        StrPut(appId, idBuffer, "UTF-16")
        NumPut("UShort", 31, propVariant, 0) ; VT_LPWSTR
        NumPut("Ptr", idBuffer.Ptr, propVariant, 8)

        hr := ComCall(6, propertyStore
            , "Ptr", pkey.Ptr
            , "Ptr", propVariant.Ptr
            , "Int") ; IPropertyStore::SetValue
        if (hr != 0)
            return false

        hr := ComCall(7, propertyStore, "Int") ; IPropertyStore::Commit
        if (hr != 0)
            return false

        return true
    } catch {
        return false
    } finally {
        if (propertyStore)
            ObjRelease(propertyStore)
    }
}

; ----------------------------------------------------------
; Immediate Roblox titlebar-control refresh on window geometry changes.
; This is independent of the game-status hook so F3/ⓘ placement is
; refreshed even when the game-status display is toggled off.
; ----------------------------------------------------------
Macro_StartRobloxTitlebarLocationHook() {
    global robloxTitlebarLocationChangeHook, robloxTitlebarLocationChangeCallback

    if (robloxTitlebarLocationChangeHook)
        return

    try {
        if (!robloxTitlebarLocationChangeCallback)
            robloxTitlebarLocationChangeCallback := CallbackCreate(Macro_RobloxTitlebarLocationWinEventProc)

        robloxTitlebarLocationChangeHook := DllCall(
            "user32\SetWinEventHook",
            "UInt", 0x800B, "UInt", 0x800B, ; EVENT_OBJECT_LOCATIONCHANGE
            "Ptr", 0, "Ptr", robloxTitlebarLocationChangeCallback,
            "UInt", 0, "UInt", 0, "UInt", 0, "Ptr"
        )
    } catch {
        robloxTitlebarLocationChangeHook := 0
    }
}

Macro_StopRobloxTitlebarLocationHook(*) {
    global robloxTitlebarLocationChangeHook, robloxTitlebarLocationChangeCallback

    try {
        if (robloxTitlebarLocationChangeHook)
            DllCall("user32\UnhookWinEvent", "Ptr", robloxTitlebarLocationChangeHook)
    } catch {
    }

    robloxTitlebarLocationChangeHook := 0
    ; Keep the callback alive until script exit.
}

; Foreground transitions use the same settled, one-shot restoration pattern as
; the game selector. This hook is independent of the selector's visibility so
; the titlebar buttons recover even when the game selector is turned off.
Macro_StartRobloxTitlebarForegroundHook() {
    global robloxTitlebarForegroundHook, robloxTitlebarForegroundCallback
    global robloxTitlebarLastForegroundWasRoblox

    if (robloxTitlebarForegroundHook)
        return

    robloxTitlebarLastForegroundWasRoblox := !!Macro_GetGameStatusForegroundRobloxHwnd()

    try {
        if (!robloxTitlebarForegroundCallback)
            robloxTitlebarForegroundCallback := CallbackCreate(Macro_RobloxTitlebarForegroundWinEventProc)

        robloxTitlebarForegroundHook := DllCall(
            "user32\SetWinEventHook",
            "UInt", 0x0003, "UInt", 0x0003, ; EVENT_SYSTEM_FOREGROUND
            "Ptr", 0, "Ptr", robloxTitlebarForegroundCallback,
            "UInt", 0, "UInt", 0, "UInt", 0, "Ptr"
        )
    } catch {
        robloxTitlebarForegroundHook := 0
    }
}

Macro_StopRobloxTitlebarForegroundHook(*) {
    global robloxTitlebarForegroundHook, robloxTitlebarForegroundRepairPending

    try {
        if (robloxTitlebarForegroundHook)
            DllCall("user32\UnhookWinEvent", "Ptr", robloxTitlebarForegroundHook)
    } catch {
    }

    robloxTitlebarForegroundHook := 0
    robloxTitlebarForegroundRepairPending := false
    SetTimer(Macro_RepairRobloxTitlebarAfterForegroundChange, 0)
}

Macro_RobloxTitlebarForegroundWinEventProc(hWinEventHook, event, hwnd, idObject, idChild, idEventThread, dwmsEventTime) {
    global robloxTitlebarLastForegroundWasRoblox

    if (event != 0x0003 || idObject != 0 || idChild != 0)
        return

    isRobloxForeground := false
    if (hwnd) {
        try isRobloxForeground := (WinGetProcessName("ahk_id " . hwnd) = "RobloxPlayerBeta.exe")
        catch
            isRobloxForeground := false
    }

    ; Queue only when entering Roblox or leaving Roblox. Other application-to-
    ; application switches do not need to touch the titlebar overlay.
    shouldRepair := (isRobloxForeground || robloxTitlebarLastForegroundWasRoblox)
    robloxTitlebarLastForegroundWasRoblox := isRobloxForeground
    if (shouldRepair)
        Macro_QueueRobloxTitlebarForegroundRepair()
}

Macro_QueueRobloxTitlebarForegroundRepair() {
    global robloxTitlebarForegroundRepairPending

    ; Coalesce foreground bursts and inspect the final active window once.
    if (robloxTitlebarForegroundRepairPending)
        return

    robloxTitlebarForegroundRepairPending := true
    SetTimer(Macro_RepairRobloxTitlebarAfterForegroundChange, -80)
}

Macro_RepairRobloxTitlebarAfterForegroundChange() {
    global ROBLOX_TITLEBAR_CONTROLS_ENABLE, robloxTitlebarControlsByHwnd
    global robloxTitlebarForegroundRepairPending

    robloxTitlebarForegroundRepairPending := false
    if (!ROBLOX_TITLEBAR_CONTROLS_ENABLE)
        return

    activeRobloxHwnd := Macro_GetGameStatusForegroundRobloxHwnd()

    ; Run the same full reconciliation used by the existing timer, explicitly
    ; preferring the Roblox HWND that is now foreground. This is important when
    ; switching between two fullscreen clients: the pointer may still hit-test
    ; the previous overlay/client, but the newly activated account owns the repair.
    ; The current GUI object is reused; no healthy button surface is recreated.
    try Macro_RobloxTitlebarControlsTick(activeRobloxHwnd)
    catch {
        return
    }

    ; When Roblox has just become foreground, request one explicit repaint of
    ; that window's existing button surface, matching the selector's recovery
    ; behavior without changing the button controls or their click handlers.
    if (!activeRobloxHwnd || !IsObject(robloxTitlebarControlsByHwnd)
        || !robloxTitlebarControlsByHwnd.Has(activeRobloxHwnd))
        return

    try {
        controls := robloxTitlebarControlsByHwnd[activeRobloxHwnd]
        if (!IsObject(controls.gui) || !controls.gui.Hwnd)
            return

        controlsHwnd := controls.gui.Hwnd
        if (!DllCall("user32\IsWindowVisible", "Ptr", controlsHwnd, "Int"))
            DllCall("user32\ShowWindow", "Ptr", controlsHwnd, "Int", 4) ; SW_SHOWNOACTIVATE

        ; A fullscreen transition can leave the overlay's TOPMOST bit set while
        ; the fullscreen surface has moved above it. Reassert TOPMOST once here
        ; on the settled foreground event, without moving or resizing the GUI.
        if (Macro_GetRobloxWindowMode(activeRobloxHwnd) = 3) {
            DllCall("user32\SetWindowPos", "Ptr", controlsHwnd, "Ptr", -1,
                "Int", 0, "Int", 0, "Int", 0, "Int", 0,
                "UInt", 0x0013) ; TOPMOST | NOACTIVATE | NOMOVE | NOSIZE
        }

        DllCall("user32\RedrawWindow", "Ptr", controlsHwnd,
            "Ptr", 0, "Ptr", 0, "UInt", 0x0585)
        DllCall("user32\UpdateWindow", "Ptr", controlsHwnd)
    } catch {
    }
}

Macro_RobloxTitlebarLocationWinEventProc(hWinEventHook, event, hwnd, idObject, idChild, idEventThread, dwmsEventTime) {
    if (event != 0x800B || !hwnd || idObject != 0 || idChild != 0)
        return

    try {
        if (WinGetProcessName("ahk_id " . hwnd) != "RobloxPlayerBeta.exe")
            return
    } catch {
        return
    }

    Macro_QueueRobloxTitlebarControlsRefresh()
}

Macro_RobloxDisplayChange(wParam, lParam, msg, hwnd) {
    Macro_QueueRobloxTitlebarControlsRefresh()
    return 0
}

Macro_RobloxDpiChanged(wParam, lParam, msg, hwnd) {
    Macro_QueueRobloxTitlebarControlsRefresh()
    return 0
}

Macro_RobloxSettingChange(wParam, lParam, msg, hwnd) {
    ; Display scaling and related desktop metrics can be broadcast through
    ; WM_SETTINGCHANGE even when Roblox itself does not receive WM_DPICHANGED.
    Macro_QueueRobloxTitlebarControlsRefresh()
    return 0
}

Macro_QueueRobloxTitlebarControlsRefresh() {
    global robloxTitlebarRefreshPending

    if (robloxTitlebarRefreshPending)
        return

    robloxTitlebarRefreshPending := true
    SetTimer(Macro_RunRobloxTitlebarControlsRefresh, -1)
}

Macro_RunRobloxTitlebarControlsRefresh() {
    global robloxTitlebarRefreshPending, ROBLOX_TITLEBAR_CONTROLS_ENABLE

    robloxTitlebarRefreshPending := false
    if (!ROBLOX_TITLEBAR_CONTROLS_ENABLE)
        return

    try Macro_RobloxTitlebarControlsTick()
    catch {
    }
}

Macro_GetRobloxMonitorDpi(hwnd) {
    ; Read the effective DPI from the monitor on which this Roblox window
    ; currently resides. This remains correct when Windows scaling changes
    ; without restarting Roblox.
    hMonitor := 0
    dpiX := 96
    dpiY := 96
    try {
        hMonitor := DllCall("user32\MonitorFromWindow", "Ptr", hwnd, "UInt", 2, "Ptr")
    } catch {
        hMonitor := 0
    }
    if (hMonitor) {
        try {
            hr := DllCall("shcore\GetDpiForMonitor", "Ptr", hMonitor, "Int", 0, "UInt*", &dpiX, "UInt*", &dpiY, "Int")
            if (hr = 0 && dpiX >= 72 && dpiX <= 480)
                return dpiX
        } catch {
        }
    }

    try {
        dpi := DllCall("user32\GetDpiForWindow", "Ptr", hwnd, "UInt")
        if (dpi >= 72 && dpi <= 480)
            return dpi
    } catch {
    }
    return 96
}

; Small, non-activating F3/help controls aligned immediately left of Roblox's
; native minimize button. The native caption buttons remain untouched.
Macro_RobloxTitlebarControlsTick(preferredHwnd := 0) {
    ; A foreground-change repair can nominate the Roblox HWND that was just
    ; activated. The normal 100ms tick keeps its original pointer-first behavior.
    ; Keep button creation, DPI metrics, frame reads and placement in one
    ; per-monitor physical-pixel context. Restore before touching help contents.
    previousDpiContext := 0
    try previousDpiContext := DllCall(
        "user32\SetThreadDpiAwarenessContext", "Ptr", -4, "Ptr"
    ) ; DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2
    catch {
        previousDpiContext := 0
    }

    try {
        Macro_RobloxTitlebarControlsTickCore(preferredHwnd)
    } finally {
        if (previousDpiContext) {
            try DllCall("user32\SetThreadDpiAwarenessContext", "Ptr", previousDpiContext, "Ptr")
            catch {
            }
        }
    }

    ; These were part of the original tick, but must use the original DPI context.
    Macro_UpdateShortcutHelpPlacement()
    Macro_UpdateRobloxTitlebarTooltip()
    Macro_UpdateRobloxTitlebarButtonVisuals()
}
Macro_IsRobloxTitlebarTargetEligible(hwnd) {
    if (!hwnd || !WinExist("ahk_id " . hwnd))
        return false

    try {
        if (WinGetMinMax("ahk_id " . hwnd) = -1)
            return false

        style := WinGetStyle("ahk_id " . hwnd)
        hasCaption := ((style & 0x00C00000) != 0)
        hasSystemMenu := ((style & 0x00080000) != 0)
        hasMinimizeButton := ((style & 0x00020000) != 0)

        if (hasCaption && hasSystemMenu && hasMinimizeButton)
            return true

        ; Any live fullscreen Roblox client is eligible, even when the single
        ; shared overlay is currently associated with a different client HWND.
        ; This allows the overlay to follow the newly activated fullscreen
        ; account instead of rejecting it because it has no Map entry yet.
        return (Macro_GetRobloxWindowMode(hwnd) = 3)
    } catch {
        return false
    }
}

; Keep one titlebar button surface and retarget it to the Roblox window under
; the pointer. If the pointer is elsewhere, prefer the active Roblox window,
; then the current target, then the first eligible client.
Macro_GetRobloxTitlebarTarget(hwndList, preferredHwnd := 0) {
    global robloxTitlebarControlsByHwnd, robloxTitlebarPointerTargetHwnd

    robloxTitlebarPointerTargetHwnd := 0

    ; On a foreground transition, the activated Roblox window must win over
    ; stale pointer/overlay hit-testing. Ordinary periodic ticks pass 0 and
    ; retain the existing pointer-first selection behavior.
    if (preferredHwnd && Macro_IsRobloxTitlebarTargetEligible(preferredHwnd))
        return preferredHwnd
    mouseHwnd := 0
    try MouseGetPos(, , &mouseHwnd)
    catch {
        mouseHwnd := 0
    }

    if (mouseHwnd) {
        for targetHwnd, controls in robloxTitlebarControlsByHwnd {
            try {
                if (IsObject(controls.gui) && controls.gui.Hwnd = mouseHwnd
                    && Macro_IsRobloxTitlebarTargetEligible(targetHwnd)) {
                    robloxTitlebarPointerTargetHwnd := targetHwnd
                    return targetHwnd
                }
            } catch {
            }
        }

        try {
            rootHwnd := DllCall("user32\GetAncestor", "Ptr", mouseHwnd, "UInt", 2, "Ptr") ; GA_ROOT
            if (rootHwnd && WinGetProcessName("ahk_id " . rootHwnd) = "RobloxPlayerBeta.exe"
                && Macro_IsRobloxTitlebarTargetEligible(rootHwnd)) {
                robloxTitlebarPointerTargetHwnd := rootHwnd
                return rootHwnd
            }
        } catch {
        }
    }

    activeHwnd := Macro_GetGameStatusForegroundRobloxHwnd()
    if (activeHwnd && Macro_IsRobloxTitlebarTargetEligible(activeHwnd))
        return activeHwnd

    for targetHwnd, controls in robloxTitlebarControlsByHwnd {
        if (Macro_IsRobloxTitlebarTargetEligible(targetHwnd))
            return targetHwnd
    }

    for hwnd in hwndList {
        if (Macro_IsRobloxTitlebarTargetEligible(hwnd))
            return hwnd
    }
    return 0
}
Macro_RobloxTitlebarControlsTickCore(preferredHwnd := 0) {
    global robloxTitlebarControlsByHwnd
    global robloxTitlebarPointerTargetHwnd
    global gameStatusGui, gameStatusTrackedHwnd
    global shortcutHelpVisible, shortcutHelpTargetHwnd

    hwndList := []
    try {
        hwndList := WinGetList("ahk_exe RobloxPlayerBeta.exe")
    } catch {
        hwndList := []
    }

    ; Only one overlay exists at a time. Moving it with the pointer avoids
    ; stale per-window surfaces when Roblox clients overlap or change size.
    targetHwnd := Macro_GetRobloxTitlebarTarget(hwndList, preferredHwnd)
    if (targetHwnd && !robloxTitlebarControlsByHwnd.Has(targetHwnd)
        && robloxTitlebarControlsByHwnd.Count > 0) {
        oldHwnd := 0
        for existingHwnd, existingControls in robloxTitlebarControlsByHwnd {
            oldHwnd := existingHwnd
            break
        }
        if (oldHwnd) {
            controlsToMove := robloxTitlebarControlsByHwnd[oldHwnd]
            robloxTitlebarControlsByHwnd.Delete(oldHwnd)
            robloxTitlebarControlsByHwnd[targetHwnd] := controlsToMove
        }
    }

    liveHwnds := Map()
    for hwnd in hwndList {
        if (!WinExist("ahk_id " . hwnd))
            continue

        if (hwnd != targetHwnd) {
            if (robloxTitlebarControlsByHwnd.Has(hwnd))
                Macro_RemoveRobloxTitlebarControls(hwnd)
            continue
        }

        try {
            style := WinGetStyle("ahk_id " . hwnd)
        } catch {
            continue
        }

        ; Normal windowed Roblox clients use the native caption geometry.
        ; When Roblox switches to fullscreen, preserve the existing button GUI
        ; at its last titlebar coordinates instead of destroying it. The user
        ; asked to keep the familiar position, so fullscreen does not relocate
        ; the buttons to another screen corner.
        hasCaption := ((style & 0x00C00000) != 0)
        hasSystemMenu := ((style & 0x00080000) != 0)
        hasMinimizeButton := ((style & 0x00020000) != 0)
        if (!hasCaption || !hasSystemMenu || !hasMinimizeButton) {
            if (Macro_GetRobloxWindowMode(hwnd) = 3
                && robloxTitlebarControlsByHwnd.Has(hwnd)) {
                fullscreenControls := robloxTitlebarControlsByHwnd[hwnd]
                fullscreenControlsHwnd := 0
                try {
                    if (IsObject(fullscreenControls.gui) && fullscreenControls.gui.Hwnd)
                        fullscreenControlsHwnd := fullscreenControls.gui.Hwnd
                } catch {
                    fullscreenControlsHwnd := 0
                }

                if (fullscreenControlsHwnd
                    && DllCall("user32\IsWindow", "Ptr", fullscreenControlsHwnd, "Int")) {
                    ; Keep this existing surface alive so stale-window cleanup
                    ; cannot mistake fullscreen's missing caption for a dead target.
                    liveHwnds[hwnd] := true

                    if (!DllCall("user32\IsWindowVisible", "Ptr", fullscreenControlsHwnd, "Int"))
                        DllCall("user32\ShowWindow", "Ptr", fullscreenControlsHwnd, "Int", 4) ; SW_SHOWNOACTIVATE

                    ; Preserve the saved x/y and dimensions. Only repair the
                    ; non-activating Z-order when Roblox actually becomes active.
                    robloxIsActive := (DllCall("user32\GetForegroundWindow", "Ptr") = hwnd)
                    fullscreenExStyle := 0
                    try {
                        fullscreenExStyle := DllCall("user32\GetWindowLongPtrW", "Ptr", fullscreenControlsHwnd, "Int", -20, "Ptr")
                    } catch {
                        fullscreenExStyle := 0
                    }
                    fullscreenIsTopmost := ((fullscreenExStyle & 0x00000008) != 0)

                    if (robloxIsActive && !fullscreenIsTopmost) {
                        DllCall("user32\SetWindowPos", "Ptr", fullscreenControlsHwnd, "Ptr", -1,
                            "Int", 0, "Int", 0, "Int", 0, "Int", 0,
                            "UInt", 0x0013) ; TOPMOST | NOACTIVATE | NOMOVE | NOSIZE
                    } else if (!robloxIsActive && fullscreenIsTopmost) {
                        DllCall("user32\SetWindowPos", "Ptr", fullscreenControlsHwnd, "Ptr", -2,
                            "Int", 0, "Int", 0, "Int", 0, "Int", 0,
                            "UInt", 0x0013) ; NOTOPMOST | NOACTIVATE | NOMOVE | NOSIZE
                    }
                } else {
                    Macro_RemoveRobloxTitlebarControls(hwnd)
                }
                continue
            }

            if (robloxTitlebarControlsByHwnd.Has(hwnd))
                Macro_RemoveRobloxTitlebarControls(hwnd)
            continue
        }

        try {
            if (WinGetMinMax("ahk_id " . hwnd) = -1) {
                if (robloxTitlebarControlsByHwnd.Has(hwnd))
                    Macro_RemoveRobloxTitlebarControls(hwnd)
                continue
            }
        } catch {
            continue
        }

        ; Use the effective DPI of the monitor currently containing the Roblox
        ; window. GetDpiForWindow() may temporarily retain the old value when
        ; Windows display scaling changes while Roblox remains running.
        dpi := Macro_GetRobloxMonitorDpi(hwnd)

        try {
            buttonW := DllCall("user32\GetSystemMetricsForDpi", "Int", 30, "UInt", dpi, "Int")
        } catch {
            buttonW := DllCall("user32\GetSystemMetrics", "Int", 30, "Int")
        }
        try {
            buttonH := DllCall("user32\GetSystemMetricsForDpi", "Int", 31, "UInt", dpi, "Int")
        } catch {
            buttonH := DllCall("user32\GetSystemMetrics", "Int", 31, "Int")
        }
        if (buttonW <= 0)
            buttonW := Max(30, Round(30 * dpi / 96))
        if (buttonH <= 0)
            buttonH := Max(24, Round(24 * dpi / 96))

        showQuadLayoutButton := Macro_IsAutoLayoutRobloxMonitor(hwnd)
        buttonCount := showQuadLayoutButton ? 3 : 2
        totalWidth := buttonW * buttonCount
        if (robloxTitlebarControlsByHwnd.Has(hwnd)) {
            existing := robloxTitlebarControlsByHwnd[hwnd]
            if (existing.width != totalWidth || existing.height != buttonH
                || existing.quadVisible != showQuadLayoutButton)
                Macro_RemoveRobloxTitlebarControls(hwnd)
        }
        if (!robloxTitlebarControlsByHwnd.Has(hwnd))
            Macro_CreateRobloxTitlebarControls(hwnd, buttonW, buttonH)
        if (!robloxTitlebarControlsByHwnd.Has(hwnd))
            continue

        liveHwnds[hwnd] := true
        controls := robloxTitlebarControlsByHwnd[hwnd]
        if (controls.captionTargetHwnd != hwnd) {
            controls.captionTargetHwnd := hwnd
            controls.backgroundColor := ""
            controls.captionActive := -1
            controls.lastBackgroundCheckTick := 0
        }

        try {
            WinGetPos(&windowX, &windowY, &windowW, &windowH, "ahk_id " . hwnd)
            WinGetClientPos(&clientX, &clientY, &clientW, &clientH, "ahk_id " . hwnd)
            if (windowW <= 0 || windowH <= 0 || clientY <= 0)
                continue

            frameLeft := windowX
            frameTop := windowY
            frameRight := windowX + windowW
            frameBounds := Buffer(16, 0)
            frameResult := DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", hwnd,
                "UInt", 9, "Ptr", frameBounds.Ptr, "UInt", 16, "Int")
            if (frameResult = 0) {
                frameLeft := NumGet(frameBounds, 0, "Int")
                frameTop := NumGet(frameBounds, 4, "Int")
                frameRight := NumGet(frameBounds, 8, "Int")
            }

            captionHeight := clientY - frameTop
            if (captionHeight < buttonH)
                captionHeight := buttonH

            nativeButtonCount := 1 ; Close
            if (style & 0x00010000)
                nativeButtonCount += 1 ; Maximize / Restore
            if (style & 0x00020000)
                nativeButtonCount += 1 ; Minimize

            ; Prefer DWM's actual native caption-button rectangle. Style flags
            ; can differ between Roblox clients, which made the quad button
            ; overlap Minimize and placed the row at different vertical centers.
            captionButtonBounds := Buffer(16, 0)
            captionBoundsResult := DllCall("dwmapi\DwmGetWindowAttribute", "Ptr", hwnd,
                "UInt", 5, "Ptr", captionButtonBounds.Ptr, "UInt", 16, "Int") ; DWMWA_CAPTION_BUTTON_BOUNDS
            nativeCaptionLeft := NumGet(captionButtonBounds, 0, "Int")
            nativeCaptionTop := NumGet(captionButtonBounds, 4, "Int")
            nativeCaptionRight := NumGet(captionButtonBounds, 8, "Int")
            nativeCaptionBottom := NumGet(captionButtonBounds, 12, "Int")
            captionBoundsValid := (captionBoundsResult = 0
                && nativeCaptionLeft >= 0 && nativeCaptionTop >= 0
                && nativeCaptionRight > nativeCaptionLeft
                && nativeCaptionBottom > nativeCaptionTop)
            gapPx := Max(3, Round(6 * dpi / 96))

            ; Ask Windows for the native title-bar button rectangles in screen
            ; coordinates. Anchoring to Minimize avoids invisible frame offsets
            ; that GetWindowRect can have when a window is maximized.
            titlebarInfo := Buffer(140, 0) ; TITLEBARINFOEX: 4 + 16 + 24 + (6 * 16)
            NumPut("UInt", 140, titlebarInfo, 0)
            titlebarInfoMessageResult := 0
            titlebarInfoDelivered := DllCall("user32\SendMessageTimeoutW", "Ptr", hwnd,
                "UInt", 0x033F, "Ptr", 0, "Ptr", titlebarInfo.Ptr,
                "UInt", 0x0022, "UInt", 80, "Ptr*", &titlebarInfoMessageResult, "Ptr") ; SMTO_ABORTIFHUNG | SMTO_ERRORONEXIT
            nativeMinimizeLeft := NumGet(titlebarInfo, 76, "Int")
            nativeMinimizeTop := NumGet(titlebarInfo, 80, "Int")
            nativeMinimizeRight := NumGet(titlebarInfo, 84, "Int")
            nativeMinimizeBottom := NumGet(titlebarInfo, 88, "Int")
            nativeMinimizeBoundsValid := (titlebarInfoDelivered
                && nativeMinimizeRight > nativeMinimizeLeft
                && nativeMinimizeBottom > nativeMinimizeTop)

            if (nativeMinimizeBoundsValid) {
                nativeMinimizeHeight := nativeMinimizeBottom - nativeMinimizeTop
                targetX := Max(frameLeft, nativeMinimizeLeft - totalWidth - gapPx)
                targetY := nativeMinimizeTop
                    + Floor((nativeMinimizeHeight - buttonH) / 2)
            } else if (captionBoundsValid) {
                ; DWM fallback if Windows did not return title-bar element bounds.
                captionButtonHeight := nativeCaptionBottom - nativeCaptionTop
                targetX := Max(frameLeft, windowX + nativeCaptionLeft - totalWidth - gapPx)
                targetY := windowY + nativeCaptionTop
                    + Floor((captionButtonHeight - buttonH) / 2)
            } else {
                ; Final fallback to measured frame/client geometry during a
                ; maximize/restore transition.
                targetX := Max(frameLeft,
                    frameRight - ((nativeButtonCount + buttonCount + 1) * buttonW) - gapPx)
                targetY := frameTop + Max(0, Floor((captionHeight - buttonH) / 2))
            }
            robloxIsActive := (DllCall("user32\GetForegroundWindow", "Ptr") = hwnd)
            ; Idle glyphs use a fixed dark color suitable for the light caption.
            ; Hover/pressed inversion is applied separately by
            ; Macro_UpdateRobloxTitlebarButtonVisuals().
            if (controls.textColor != "202020") {
                controls.f3.SetFont("s12 c202020", "Segoe UI Symbol")
                controls.help.SetFont("s12 c202020", "Segoe UI Symbol")
                controls.quad.SetFont("s12 c202020", "Segoe UI Symbol")
                controls.textColor := "202020"
            }

            if (controls.transparentBackground) {
                ; Keep the GUI background on its dedicated color-key value.
                ; The icon glyphs remain visible while the surrounding button
                ; surface shows the Roblox content underneath.
                if (controls.backgroundColor != "1D1D1D") {
                    controls.gui.BackColor := "1D1D1D"
                    controls.backgroundColor := "1D1D1D"
                }
            } else {
                ; Safe visual fallback if Windows rejects the low-level input
                ; hook: retain the original caption-matched background so the
                ; regular GUI controls remain fully clickable.
                if (controls.backgroundColor = ""
                    || controls.captionActive != robloxIsActive
                    || A_TickCount - controls.lastBackgroundCheckTick >= 3000) {
                    fallbackBgRef := DllCall("user32\GetSysColor", "Int", robloxIsActive ? 2 : 3, "UInt")
                    sampleX := Min(frameRight - 1, targetX + totalWidth + Floor(buttonW / 2))
                    sampleY := targetY + Floor(buttonH / 2)
                    backgroundColor := Macro_GetRobloxCaptionBackgroundColor(sampleX, sampleY, fallbackBgRef)
                    if (controls.backgroundColor != backgroundColor) {
                        controls.gui.BackColor := backgroundColor
                        controls.backgroundColor := backgroundColor
                    }
                    controls.captionActive := robloxIsActive
                    controls.lastBackgroundCheckTick := A_TickCount
                }
            }

            if (controls.quadVisible != showQuadLayoutButton) {
                try controls.quad.Visible := showQuadLayoutButton
                catch {
                }
                try controls.backgrounds[3].Visible := showQuadLayoutButton
                catch {
                }
                controls.quadVisible := showQuadLayoutButton
            }

            ; Retry failed moves and detect OS-side repositioning. The old code
            ; cached the requested point even if SetWindowPos failed, which could
            ; leave a button surface missing or stranded until another move.
            positionNeedsUpdate := (controls.x != targetX || controls.y != targetY)
            try {
                WinGetPos(&overlayX, &overlayY, , , "ahk_id " . controls.gui.Hwnd)
                if (overlayX != targetX || overlayY != targetY)
                    positionNeedsUpdate := true
            } catch {
                positionNeedsUpdate := true
            }
            if (positionNeedsUpdate) {
                positionApplied := DllCall("user32\SetWindowPos", "Ptr", controls.gui.Hwnd, "Ptr", 0,
                    "Int", targetX, "Int", targetY, "Int", totalWidth, "Int", buttonH,
                    "UInt", 0x0014, "Int") ; NOZORDER | NOACTIVATE
                if (positionApplied) {
                    controls.x := targetX
                    controls.y := targetY
                } else {
                    controls.x := -1
                    controls.y := -1
                }
            } else {
                controls.x := targetX
                controls.y := targetY
            }
            if (!DllCall("user32\IsWindowVisible", "Ptr", controls.gui.Hwnd))
                controls.gui.Show("NoActivate")

            ; Match the stable overlay behavior without letting hover alone keep
            ; the surface TOPMOST. Promote only while this Roblox window is truly
            ; foreground; when inactive, keep controls in the normal band and
            ; above their Roblox target only when the ordering actually needs
            ; correction. This keeps buttons and tooltips from floating over a
            ; different application that covers Roblox, while avoiding per-tick
            ; SetWindowPos() calls and the associated one-frame blink.
            controlsHwnd := controls.gui.Hwnd
            controlsExStyle := 0
            try {
                controlsExStyle := DllCall("user32\GetWindowLongPtrW", "Ptr", controlsHwnd, "Int", -20, "Ptr")
            } catch {
                controlsExStyle := 0
            }
            controlsIsTopmost := (controlsExStyle & 0x00000008) != 0

            ; TOPMOST is tied to Roblox actually being the foreground window,
            ; not merely to the pointer sitting over this overlay. Otherwise the
            ; overlay can hit-test itself, remain TOPMOST, and float over a different
            ; application that covers Roblox. Inactive Roblox controls stay in the
            ; normal band, ordered above Roblox only when that placement is valid.
            if (robloxIsActive) {
                ; Promote only on the active-state transition; repeated clicks do
                ; not reinsert or repaint the controls.
                if (!controlsIsTopmost) {
                    DllCall("user32\SetWindowPos", "Ptr", controlsHwnd, "Ptr", -1,
                        "Int", 0, "Int", 0, "Int", 0, "Int", 0,
                        "UInt", 0x0013) ; TOPMOST | NOACTIVATE | NOMOVE | NOSIZE
                }
            } else {
                ; Return to the normal Z-order band only when currently TOPMOST.
                if (controlsIsTopmost) {
                    DllCall("user32\SetWindowPos", "Ptr", controlsHwnd, "Ptr", -2,
                        "Int", 0, "Int", 0, "Int", 0, "Int", 0,
                        "UInt", 0x0013) ; NOTOPMOST | NOACTIVATE | NOMOVE | NOSIZE
                    controlsIsTopmost := false
                }

                ; In the normal band, correct Z-order only when the controls are
                ; actually below their Roblox target. Do not touch Z-order when
                ; they are already in the correct position.
                robloxExStyle := 0
                try {
                    robloxExStyle := DllCall("user32\GetWindowLongPtrW", "Ptr", hwnd, "Int", -20, "Ptr")
                } catch {
                    robloxExStyle := 0
                }

                if ((robloxExStyle & 0x00000008) = 0) {
                    isAboveRoblox := false
                    zHwnd := 0
                    try {
                        zHwnd := DllCall("user32\GetWindow", "Ptr", hwnd, "UInt", 3, "Ptr") ; GW_HWNDPREV
                    } catch {
                        zHwnd := 0
                    }
                    while (zHwnd) {
                        if (zHwnd = controlsHwnd) {
                            isAboveRoblox := true
                            break
                        }
                        try {
                            zHwnd := DllCall("user32\GetWindow", "Ptr", zHwnd, "UInt", 3, "Ptr")
                        } catch {
                            zHwnd := 0
                        }
                    }

                    if (!isAboveRoblox) {
                        anchor := Macro_GetRobloxTitlebarControlsZOrderAnchor(hwnd, controlsHwnd)
                        if (anchor) {
                            DllCall("user32\SetWindowPos", "Ptr", controlsHwnd, "Ptr", anchor,
                                "Int", 0, "Int", 0, "Int", 0, "Int", 0,
                                "UInt", 0x0013) ; NOACTIVATE | NOMOVE | NOSIZE
                        } else {
                            ; No safe same-band anchor was found. Leave the current
                            ; normal-band order alone rather than raising the controls
                            ; above unrelated applications. They will be promoted when
                            ; Roblox becomes active or the pointer returns to Roblox.
                        }
                    }
                }
            }

        } catch {
        }
    }
    staleHwnds := []
    for hwnd, controls in robloxTitlebarControlsByHwnd {
        if (!liveHwnds.Has(hwnd))
            staleHwnds.Push(hwnd)
    }
    for hwnd in staleHwnds
        Macro_RemoveRobloxTitlebarControls(hwnd)


}

Macro_CreateRobloxTitlebarControls(hwnd, buttonW, buttonH) {
    global robloxTitlebarControlsByHwnd, robloxTitlebarTransparentMouseHook

    try {
        ; Keep this as an independent top-level, non-activating window.
        ; Do NOT assign an Owner to the Roblox window: the Owner relationship was
        ; the key difference between this control surface and the stable
        ; PowerToys-safe status overlays.
        controlsGui := Gui("-Caption +ToolWindow +E0x08000000 -DPIScale", "Roblox F3/Help/Split Layout controls")
        ; Dedicated color-key background: only this color is transparent.
        controlsGui.BackColor := "1D1D1D"
        controlsGui.SetFont("s12 c202020", "Segoe UI Symbol")

        ; Per-button fill surfaces sit behind the glyphs. They are transparent
        ; at rest (same as the parent color-key surface), then receive a solid
        ; color only for hover/pressed feedback.
        f3BgCtrl := controlsGui.AddText("x0 y0 w" . buttonW . " h" . buttonH . " BackgroundTrans", "")
        helpBgCtrl := controlsGui.AddText("x" . buttonW . " y0 w" . buttonW . " h" . buttonH . " BackgroundTrans", "")
        quadBgCtrl := controlsGui.AddText("x" . (buttonW * 2) . " y0 w" . buttonW . " h" . buttonH . " BackgroundTrans", "")

        f3Ctrl := controlsGui.AddText("x0 y0 w" . buttonW . " h" . buttonH . " Center +0x200 BackgroundTrans", "▤")
        helpCtrl := controlsGui.AddText("x" . buttonW . " y0 w" . buttonW . " h" . buttonH . " Center +0x200 BackgroundTrans", "ⓘ")
        quadCtrl := controlsGui.AddText("x" . (buttonW * 2) . " y0 w" . buttonW . " h" . buttonH . " Center +0x200 BackgroundTrans", "⧉")

        ; The F5 titlebar button is removed. F5 remains available as a keyboard hotkey.
        ; F3 toggles the game selector; Help opens shortcuts; Split Layout arranges Roblox clients.
        f3Ctrl.OnEvent("Click", Macro_RobloxTitlebarF3Click)
        helpCtrl.OnEvent("Click", Macro_RobloxTitlebarHelpClick)
        quadCtrl.OnEvent("Click", Macro_RobloxTitlebarAutoLayoutClick)

        showQuadLayoutButton := Macro_IsAutoLayoutRobloxMonitor(hwnd)
        buttonCount := showQuadLayoutButton ? 3 : 2
        totalWidth := buttonW * buttonCount
        quadCtrl.Visible := showQuadLayoutButton
        quadBgCtrl.Visible := showQuadLayoutButton
        controlsGui.Show("x-32000 y-32000 w" . totalWidth . " h" . buttonH . " NoActivate")

        transparencyApplied := false
        try {
            WinSetTransColor("1D1D1D", controlsGui)
            transparencyApplied := true
        } catch {
            transparencyApplied := false
        }

        robloxTitlebarControlsByHwnd[hwnd] := {
            gui:controlsGui,
            f3:f3Ctrl,
            help:helpCtrl,
            quad:quadCtrl,
            backgrounds:[f3BgCtrl, helpBgCtrl, quadBgCtrl],
            iconVisualStates:["normal", "normal", "normal"],
            backgroundVisualStates:["normal", "normal", "normal"],
            quadVisible:showQuadLayoutButton,
            buttonW:buttonW,
            width:totalWidth,
            height:buttonH,
            x:-1,
            y:-1,
            textColor:"",
            backgroundColor:"1D1D1D",
            transparentBackground:transparencyApplied,
            captionActive:-1,
            lastBackgroundCheckTick:0,
            captionTargetHwnd:hwnd
        }

        ; Retrieve the stored controls object before the fallback branch below.
        ; This is the same object referenced by robloxTitlebarControlsByHwnd[hwnd].
        controls := robloxTitlebarControlsByHwnd[hwnd]

        ; Color-keyed pixels normally pass mouse input through. A small global
        ; hook preserves the rectangular click targets only within this strip.
        if (transparencyApplied) {
            Macro_StartRobloxTitlebarTransparentMouseHook()
            if (!robloxTitlebarTransparentMouseHook) {
                ; Never leave the button surface transparent without its input
                ; handler. Revert to the original opaque/caption-matched mode.
                try WinSetTransColor("Off", controlsGui)
                controls.transparentBackground := false
                controls.backgroundColor := ""
                transparencyApplied := false
            }
        }
    } catch {
        try {
            if (IsObject(controlsGui))
                controlsGui.Destroy()
        } catch {
        }
    }
}

Macro_StartRobloxTitlebarTransparentMouseHook() {
    global robloxTitlebarTransparentMouseHook, robloxTitlebarTransparentMouseCallback

    if (robloxTitlebarTransparentMouseHook)
        return

    try {
        if (!robloxTitlebarTransparentMouseCallback)
            robloxTitlebarTransparentMouseCallback := CallbackCreate(Macro_RobloxTitlebarTransparentMouseHookProc)
        moduleHandle := DllCall("kernel32\GetModuleHandleW", "Ptr", 0, "Ptr")
        robloxTitlebarTransparentMouseHook := DllCall(
            "user32\SetWindowsHookExW",
            "Int", 14, "Ptr", robloxTitlebarTransparentMouseCallback, ; WH_MOUSE_LL
            "Ptr", moduleHandle, "UInt", 0, "Ptr"
        )
    } catch {
        robloxTitlebarTransparentMouseHook := 0
    }
}

Macro_StopRobloxTitlebarTransparentMouseHook() {
    global robloxTitlebarTransparentMouseHook
    global robloxTitlebarTransparentMouseDownTargetHwnd
    global robloxTitlebarTransparentMouseDownButtonIndex
    global robloxTitlebarTransparentMouseActionTargetHwnd
    global robloxTitlebarTransparentMouseActionButtonIndex

    try {
        if (robloxTitlebarTransparentMouseHook)
            DllCall("user32\UnhookWindowsHookEx", "Ptr", robloxTitlebarTransparentMouseHook)
    } catch {
    }
    robloxTitlebarTransparentMouseHook := 0
    robloxTitlebarTransparentMouseDownTargetHwnd := 0
    robloxTitlebarTransparentMouseDownButtonIndex := -1
    robloxTitlebarTransparentMouseActionTargetHwnd := 0
    robloxTitlebarTransparentMouseActionButtonIndex := -1
}

Macro_GetRobloxTitlebarTransparentButtonAtPoint(x, y, &targetHwnd, &buttonIndex) {
    global robloxTitlebarControlsByHwnd

    targetHwnd := 0
    buttonIndex := -1
    for robloxHwnd, controls in robloxTitlebarControlsByHwnd {
        if (!controls.transparentBackground)
            continue
        if (x < controls.x || x >= controls.x + controls.width
            || y < controls.y || y >= controls.y + controls.height)
            continue
        if (!WinExist("ahk_id " . robloxHwnd))
            continue

        index := Floor((x - controls.x) / controls.buttonW)
        if (index < 0 || index > 2)
            continue
        if (index = 2 && !controls.quadVisible)
            continue

        targetHwnd := robloxHwnd
        buttonIndex := index
        return true
    }
    return false
}

Macro_RobloxTitlebarTransparentMouseHookProc(nCode, wParam, lParam) {
    global robloxTitlebarTransparentMouseHook
    global robloxTitlebarTransparentMouseDownTargetHwnd
    global robloxTitlebarTransparentMouseDownButtonIndex
    global robloxTitlebarTransparentMouseActionTargetHwnd
    global robloxTitlebarTransparentMouseActionButtonIndex
    global robloxTitlebarPressedVisualTargetHwnd
    global robloxTitlebarPressedVisualButtonIndex

    if (nCode >= 0) {
        ; WM_LBUTTONDOWN: intercept only physical clicks inside a button cell
        ; while its Roblox client is foreground. Injected clicks pass through.
        if (wParam = 0x0201) {
            flags := NumGet(lParam, 12, "UInt")
            if ((flags & 0x00000003) = 0) {
                clickX := NumGet(lParam, 0, "Int")
                clickY := NumGet(lParam, 4, "Int")
                targetHwnd := 0
                buttonIndex := -1
                if (Macro_GetRobloxTitlebarTransparentButtonAtPoint(clickX, clickY,
                    &targetHwnd, &buttonIndex)) {
                    foregroundHwnd := DllCall("user32\GetForegroundWindow", "Ptr")
                    if (foregroundHwnd = targetHwnd) {
                        robloxTitlebarTransparentMouseDownTargetHwnd := targetHwnd
                        robloxTitlebarTransparentMouseDownButtonIndex := buttonIndex
                        robloxTitlebarPressedVisualTargetHwnd := targetHwnd
                        robloxTitlebarPressedVisualButtonIndex := buttonIndex
                        SetTimer(Macro_ClearRobloxTitlebarPressedVisual, 0)
                        SetTimer(Macro_UpdateRobloxTitlebarButtonVisuals, -1)
                        return 1 ; swallow; invoke on button-up
                    }
                }
            }
        } else if (wParam = 0x0202 && robloxTitlebarTransparentMouseDownTargetHwnd) {
            ; WM_LBUTTONUP: swallow the matching release and invoke only if the
            ; pointer is still inside the same rectangular button target.
            clickX := NumGet(lParam, 0, "Int")
            clickY := NumGet(lParam, 4, "Int")
            targetHwnd := 0
            buttonIndex := -1
            sameButton := Macro_GetRobloxTitlebarTransparentButtonAtPoint(clickX, clickY,
                &targetHwnd, &buttonIndex)
            if (sameButton
                && targetHwnd = robloxTitlebarTransparentMouseDownTargetHwnd
                && buttonIndex = robloxTitlebarTransparentMouseDownButtonIndex
                && DllCall("user32\GetForegroundWindow", "Ptr") = targetHwnd) {
                robloxTitlebarTransparentMouseActionTargetHwnd := targetHwnd
                robloxTitlebarTransparentMouseActionButtonIndex := buttonIndex
                SetTimer(Macro_RunRobloxTitlebarTransparentClick, -1)
            }
            robloxTitlebarTransparentMouseDownTargetHwnd := 0
            robloxTitlebarTransparentMouseDownButtonIndex := -1
            ; Retain the pressed fill briefly so a physical click has visible
            ; feedback even though the underlying click is dispatched async.
            SetTimer(Macro_ClearRobloxTitlebarPressedVisual, -85)
            return 1
        }
    }

    return DllCall("user32\CallNextHookEx", "Ptr", robloxTitlebarTransparentMouseHook,
        "Int", nCode, "Ptr", wParam, "Ptr", lParam, "Ptr")
}

Macro_ClearRobloxTitlebarPressedVisual(*) {
    global robloxTitlebarPressedVisualTargetHwnd
    global robloxTitlebarPressedVisualButtonIndex

    robloxTitlebarPressedVisualTargetHwnd := 0
    robloxTitlebarPressedVisualButtonIndex := -1
    Macro_UpdateRobloxTitlebarButtonVisuals()
}

Macro_UpdateRobloxTitlebarButtonVisuals(*) {
    global robloxTitlebarControlsByHwnd
    global robloxTitlebarPressedVisualTargetHwnd
    global robloxTitlebarPressedVisualButtonIndex

    ; Read cursor coordinates in the same physical-pixel space used by the
    ; titlebar overlay positioning (important when Windows display scaling is on).
    previousDpiContext := 0
    try previousDpiContext := DllCall(
        "user32\SetThreadDpiAwarenessContext", "Ptr", -4, "Ptr"
    ) ; DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2
    catch {
        previousDpiContext := 0
    }
    cursorPoint := Buffer(8, 0)
    if (DllCall("user32\GetCursorPos", "Ptr", cursorPoint.Ptr, "Int")) {
        mouseX := NumGet(cursorPoint, 0, "Int")
        mouseY := NumGet(cursorPoint, 4, "Int")
    } else {
        mouseX := -2147483648
        mouseY := -2147483648
    }
    if (previousDpiContext) {
        try DllCall("user32\SetThreadDpiAwarenessContext", "Ptr", previousDpiContext, "Ptr")
        catch {
        }
    }
    foregroundHwnd := DllCall("user32\GetForegroundWindow", "Ptr")

    hoveredTargetHwnd := 0
    hoveredButtonIndex := -1
    ; Only the currently foreground Roblox client can own the hover state.
    ; This prevents one fullscreen account's buttons from lighting up over
    ; another account or over an unrelated application.
    if (foregroundHwnd && robloxTitlebarControlsByHwnd.Has(foregroundHwnd)) {
        controls := robloxTitlebarControlsByHwnd[foregroundHwnd]
        if (mouseX >= controls.x && mouseX < controls.x + controls.width
            && mouseY >= controls.y && mouseY < controls.y + controls.height) {
            candidateIndex := Floor((mouseX - controls.x) / controls.buttonW)
            if (candidateIndex >= 0 && candidateIndex <= 2
                && (candidateIndex != 2 || controls.quadVisible)) {
                hoveredTargetHwnd := foregroundHwnd
                hoveredButtonIndex := candidateIndex
            }
        }
    }

    for hwnd, controls in robloxTitlebarControlsByHwnd {
        try {
            controlsHwnd := controls.gui.Hwnd
            if (!controlsHwnd || !DllCall("user32\IsWindow", "Ptr", controlsHwnd, "Int"))
                continue

            Loop 3 {
                index := A_Index - 1
                if (index = 2 && !controls.quadVisible)
                    continue

                state := "normal"
                if (robloxTitlebarPressedVisualTargetHwnd = hwnd
                    && robloxTitlebarPressedVisualButtonIndex = index)
                    state := "pressed"
                else if (hoveredTargetHwnd = hwnd && hoveredButtonIndex = index)
                    state := "hover"

                bgColor := (state = "pressed") ? "555555"
                    : (state = "hover") ? "303030" : ""
                iconColor := (state = "normal") ? "202020" : "FFFFFF"

                if (controls.backgroundVisualStates[index + 1] != state) {
                    if (state = "normal")
                        controls.backgrounds[index + 1].Opt("+BackgroundTrans")
                    else
                        controls.backgrounds[index + 1].Opt("+Background" . bgColor)
                    controls.backgroundVisualStates[index + 1] := state
                }

                if (controls.iconVisualStates[index + 1] != state) {
                    iconCtrl := (index = 0) ? controls.f3
                        : (index = 1) ? controls.help : controls.quad
                    iconCtrl.SetFont("s12 c" . iconColor, "Segoe UI Symbol")
                    controls.iconVisualStates[index + 1] := state
                }
            }
        } catch {
            ; A stale GUI object is ignored here; the normal controls tick owns
            ; recreation/cleanup and must remain the only lifecycle authority.
        }
    }
}

Macro_RunRobloxTitlebarTransparentClick() {
    global robloxTitlebarTransparentMouseActionTargetHwnd
    global robloxTitlebarTransparentMouseActionButtonIndex

    targetHwnd := robloxTitlebarTransparentMouseActionTargetHwnd
    buttonIndex := robloxTitlebarTransparentMouseActionButtonIndex
    robloxTitlebarTransparentMouseActionTargetHwnd := 0
    robloxTitlebarTransparentMouseActionButtonIndex := -1

    if (!targetHwnd || !WinExist("ahk_id " . targetHwnd)
        || DllCall("user32\GetForegroundWindow", "Ptr") != targetHwnd)
        return

    if (buttonIndex = 0) {
        Macro_RobloxTitlebarF3Click()
    } else if (buttonIndex = 1) {
        Macro_ToggleShortcutHelp(targetHwnd)
    } else if (buttonIndex = 2 && Macro_IsAutoLayoutRobloxMonitor(targetHwnd)) {
        Macro_LayoutRobloxWindowsAuto(targetHwnd)
    }
}

Macro_GetRobloxCaptionBackgroundColor(x, y, fallbackColorRef) {
    screenDC := DllCall("user32\GetDC", "Ptr", 0, "Ptr")
    if (!screenDC)
        colorRef := fallbackColorRef
    else {
        try colorRef := DllCall("gdi32\GetPixel", "Ptr", screenDC, "Int", x, "Int", y, "UInt")
        catch
            colorRef := 0xFFFFFFFF
        DllCall("user32\ReleaseDC", "Ptr", 0, "Ptr", screenDC, "Int")
        if (colorRef = 0xFFFFFFFF)
            colorRef := fallbackColorRef
    }

    return Format("{:02X}{:02X}{:02X}", colorRef & 0xFF,
        (colorRef >> 8) & 0xFF, (colorRef >> 16) & 0xFF)
}

Macro_RemoveRobloxTitlebarControls(hwnd) {
    global robloxTitlebarControlsByHwnd
    global shortcutHelpVisible, shortcutHelpTargetHwnd, shortcutHelpGui
    global shortcutHelpLastX, shortcutHelpLastY, shortcutHelpLastRobloxActive

    if (!robloxTitlebarControlsByHwnd.Has(hwnd))
        return
    controls := robloxTitlebarControlsByHwnd[hwnd]
    try {
        if (IsObject(controls.gui))
            controls.gui.Destroy()
    } catch {
    }
    robloxTitlebarControlsByHwnd.Delete(hwnd)
    if (robloxTitlebarControlsByHwnd.Count = 0)
        Macro_StopRobloxTitlebarTransparentMouseHook()

    if (shortcutHelpVisible && shortcutHelpTargetHwnd = hwnd) {
        shortcutHelpVisible := false
        shortcutHelpTargetHwnd := 0
        shortcutHelpLastX := -2147483648
        shortcutHelpLastY := -2147483648
        shortcutHelpLastRobloxActive := false
        try {
            if (IsObject(shortcutHelpGui))
                shortcutHelpGui.Hide()
        } catch {
        }
    }
}

Macro_GetRobloxTitlebarControlsZOrderAnchor(targetHwnd, controlsHwnd := 0) {
    if (!targetHwnd)
        return 0

    targetEx := 0
    try {
        targetEx := DllCall("user32\GetWindowLongPtrW", "Ptr", targetHwnd, "Int", -20, "Ptr")
    } catch {
        targetEx := 0
    }
    targetTopmost := (targetEx & 0x00000008) != 0 ; WS_EX_TOPMOST

    anchor := 0
    try {
        anchor := DllCall("user32\GetWindow", "Ptr", targetHwnd, "UInt", 3, "Ptr") ; GW_HWNDPREV
    } catch {
        anchor := 0
    }

    while (anchor) {
        if (controlsHwnd && anchor = controlsHwnd) {
            try {
                anchor := DllCall("user32\GetWindow", "Ptr", anchor, "UInt", 3, "Ptr")
            } catch {
                anchor := 0
            }
            continue
        }

        exStyle := 0
        try {
            exStyle := DllCall("user32\GetWindowLongPtrW", "Ptr", anchor, "Int", -20, "Ptr")
        } catch {
            exStyle := 0
        }

        ; Only use an anchor from the same TOPMOST/non-TOPMOST band as Roblox.
        if (((exStyle & 0x00000008) != 0) = targetTopmost)
            return anchor

        try {
            anchor := DllCall("user32\GetWindow", "Ptr", anchor, "UInt", 3, "Ptr")
        } catch {
            anchor := 0
        }
    }

    return 0
}

; ----------------------------------------------------------
; ⧉ Resolution-aware Roblox Auto Layout
; Read physical monitor pixels (independent of Windows display scaling).
; The titlebar button is available from FHD (1920x1080) upward.
; QHD (2560x1440) and above use the 2x2 / multi-column layout tiers.
; Below QHD, only two clients are arranged, using cells that respect the
; conservative 800x600 minimum window footprint wherever possible.
; ----------------------------------------------------------
Macro_GetRobloxMonitorPhysicalResolution(hwnd, &physicalWidth, &physicalHeight) {
    physicalWidth := 0
    physicalHeight := 0
    if (!hwnd || !WinExist("ahk_id " . hwnd))
        return false

    monitorHandle := DllCall("user32\MonitorFromWindow", "Ptr", hwnd, "UInt", 2, "Ptr") ; MONITOR_DEFAULTTONEAREST
    if (!monitorHandle)
        return false

    ; MONITORINFOEXW provides the display device name. DESKTOPHORZRES /
    ; DESKTOPVERTRES report physical pixels even when Windows scaling is active.
    monitorInfo := Buffer(104, 0)
    NumPut("UInt", 104, monitorInfo, 0)
    if (!DllCall("user32\GetMonitorInfoW", "Ptr", monitorHandle, "Ptr", monitorInfo.Ptr, "Int"))
        return false

    deviceName := StrGet(monitorInfo.Ptr + 40, 32, "UTF-16")
    if (deviceName != "") {
        hdc := 0
        try hdc := DllCall("gdi32\CreateDCW", "WStr", "DISPLAY", "WStr", deviceName, "Ptr", 0, "Ptr", 0, "Ptr")
        catch
            hdc := 0

        if (hdc) {
            try physicalWidth := DllCall("gdi32\GetDeviceCaps", "Ptr", hdc, "Int", 118, "Int") ; DESKTOPHORZRES
            catch
                physicalWidth := 0
            try physicalHeight := DllCall("gdi32\GetDeviceCaps", "Ptr", hdc, "Int", 117, "Int") ; DESKTOPVERTRES
            catch
                physicalHeight := 0
            DllCall("gdi32\DeleteDC", "Ptr", hdc)
        }
    }

    ; Fall back to the monitor rectangle if the display DC is unavailable.
    if (physicalWidth <= 0 || physicalHeight <= 0) {
        physicalWidth := NumGet(monitorInfo, 8, "Int") - NumGet(monitorInfo, 0, "Int")
        physicalHeight := NumGet(monitorInfo, 12, "Int") - NumGet(monitorInfo, 4, "Int")
    }

    return (physicalWidth > 0 && physicalHeight > 0)
}

Macro_IsAutoLayoutRobloxMonitor(hwnd) {
    physicalWidth := 0
    physicalHeight := 0
    if (!Macro_GetRobloxMonitorPhysicalResolution(hwnd, &physicalWidth, &physicalHeight))
        return false

    ; FHD and higher: show the Auto Layout titlebar button.
    return (physicalWidth >= 1920 && physicalHeight >= 1080)
}

Macro_RobloxTitlebarAutoLayoutClick(ctrl, *) {
    global robloxTitlebarControlsByHwnd
    parentHwnd := 0
    try {
        if (IsObject(ctrl) && ctrl.Hwnd) {
            for robloxHwnd, controls in robloxTitlebarControlsByHwnd {
                if (IsObject(controls.quad) && controls.quad.Hwnd = ctrl.Hwnd) {
                    parentHwnd := robloxHwnd
                    break
                }
            }
        }
    } catch {
        parentHwnd := 0
    }

    if (!parentHwnd)
        return
    if (!Macro_IsAutoLayoutRobloxMonitor(parentHwnd))
        return

    Macro_LayoutRobloxWindowsAuto(parentHwnd)
}

Macro_LayoutRobloxWindowsAuto(referenceHwnd) {
    ; GetMonitorInfo / SetWindowPos must use the monitor's physical-pixel
    ; coordinate space, especially when Windows display scaling is enabled.
    previousDpiContext := 0
    try previousDpiContext := DllCall(
        "user32\SetThreadDpiAwarenessContext", "Ptr", -4, "Ptr"
    ) ; DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2
    catch {
        previousDpiContext := 0
    }

    try {
        return Macro_LayoutRobloxWindowsAutoCore(referenceHwnd)
    } finally {
        if (previousDpiContext) {
            try DllCall("user32\SetThreadDpiAwarenessContext", "Ptr", previousDpiContext, "Ptr")
            catch {
            }
        }
    }
}

Macro_LayoutRobloxWindowsAutoCore(referenceHwnd) {
    global gameStatusDisplayOrder, gameStatusPreMaxPlacements

    if (!referenceHwnd || !WinExist("ahk_id " . referenceHwnd))
        return false

    physicalWidth := 0
    physicalHeight := 0
    if (!Macro_GetRobloxMonitorPhysicalResolution(referenceHwnd, &physicalWidth, &physicalHeight))
        return false

    isQHDOrHigher := (physicalWidth >= 2560 && physicalHeight >= 1440)

    monitorHandle := DllCall("user32\MonitorFromWindow", "Ptr", referenceHwnd, "UInt", 2, "Ptr")
    if (!monitorHandle)
        return false

    monitorInfo := Buffer(40, 0)
    NumPut("UInt", 40, monitorInfo, 0)
    if (!DllCall("user32\GetMonitorInfoW", "Ptr", monitorHandle, "Ptr", monitorInfo.Ptr, "Int"))
        return false

    workLeft := NumGet(monitorInfo, 20, "Int")
    workTop := NumGet(monitorInfo, 24, "Int")
    workRight := NumGet(monitorInfo, 28, "Int")
    workBottom := NumGet(monitorInfo, 32, "Int")
    workWidth := workRight - workLeft
    workHeight := workBottom - workTop
    if (workWidth <= 1 || workHeight <= 1)
        return false

    ; Preserve the selector's stable row order. Newly found Roblox clients are
    ; appended in the same order used by the existing game-status display.
    hwndList := []
    try {
        liveList := WinGetList("ahk_exe RobloxPlayerBeta.exe")
    } catch {
        liveList := []
    }

    for hwnd in gameStatusDisplayOrder {
        if (!WinExist("ahk_id " . hwnd))
            continue
        found := false
        for liveHwnd in liveList {
            if (liveHwnd = hwnd) {
                found := true
                break
            }
        }
        if (found)
            hwndList.Push(hwnd)
    }

    for hwnd in liveList {
        if (!WinExist("ahk_id " . hwnd))
            continue
        found := false
        for orderedHwnd in hwndList {
            if (orderedHwnd = hwnd) {
                found := true
                break
            }
        }
        if (!found)
            hwndList.Push(hwnd)
    }

    ; A single client does not need a layout operation.
    if (hwndList.Length < 2)
        return false

    ; Split Layout is also an explicit user action. Exit F11 fullscreen on the
    ; clients being arranged, then continue the existing grid calculation.
    ; The helper never re-enters fullscreen after layout.
    Macro_ExitRobloxFullscreenWindows(hwndList, referenceHwnd)

    ; Conservative practical minimum cell size. The window is never deliberately
    ; assigned a tile smaller than this footprint.
    minWindowWidth := 800
    minWindowHeight := 600

    if (!isQHDOrHigher) {
        ; FHD through sub-QHD: arrange only the first two clients. Prefer a
        ; vertical stack (left-top, then left-bottom) when it fits; standard
        ; 1920x1080 FHD cannot provide two 600px rows, so it uses side-by-side.
        maxColumns := Floor(workWidth / minWindowWidth)
        maxRows := Floor(workHeight / minWindowHeight)
        if (maxRows >= 2) {
            columnCount := 1
            rowCount := 2
        } else if (maxColumns >= 2) {
            columnCount := 2
            rowCount := 1
        } else {
            return false
        }
        layoutCount := Min(hwndList.Length, 2)
    } else {
        ; QHD+: retain a 2x2 base for 2-4 clients, then grow the grid as
        ; account count increases. The physical work area limits the actual
        ; number of tiles, so undersized tiles are never forced onto the screen.
        maxColumns := Floor(workWidth / minWindowWidth)
        maxRows := Floor(workHeight / minWindowHeight)
        if (maxColumns < 2 || maxRows < 2)
            return false

        if (hwndList.Length <= 4) {
            desiredColumns := 2
            desiredRows := 2
        } else if (hwndList.Length <= 6) {
            desiredColumns := 3
            desiredRows := 2
        } else if (hwndList.Length <= 9) {
            desiredColumns := 3
            desiredRows := 3
        } else {
            desiredColumns := 4
            desiredRows := 3
        }

        columnCount := Min(desiredColumns, maxColumns)
        rowCount := Min(desiredRows, maxRows)

        ; On displays larger than 4K, allow more than twelve tiles only while
        ; the measured work area can still maintain the minimum cell footprint.
        while (columnCount * rowCount < hwndList.Length
            && (columnCount < maxColumns || rowCount < maxRows)) {
            if (columnCount < maxColumns)
                columnCount += 1
            else if (rowCount < maxRows)
                rowCount += 1
        }

        layoutCount := Min(hwndList.Length, columnCount * rowCount)
    }

    if (columnCount < 1 || rowCount < 1 || layoutCount < 1)
        return false

    ; Build cells column-first: left-top, left-bottom, next-column top,
    ; next-column bottom, and so on. This preserves the agreed account order.
    cells := []
    Loop columnCount {
        columnIndex := A_Index - 1
        cellLeft := workLeft + Floor(columnIndex * workWidth / columnCount)
        cellRight := workLeft + Floor((columnIndex + 1) * workWidth / columnCount)

        Loop rowCount {
            rowIndex := A_Index - 1
            cellTop := workTop + Floor(rowIndex * workHeight / rowCount)
            cellBottom := workTop + Floor((rowIndex + 1) * workHeight / rowCount)
            cells.Push([cellLeft, cellTop, cellRight - cellLeft, cellBottom - cellTop])
        }
    }

    laidOut := 0
    for index, hwnd in hwndList {
        if (index > layoutCount)
            break
        if (!WinExist("ahk_id " . hwnd))
            continue

        try {
            style := WinGetStyle("ahk_id " . hwnd)
            hasCaption := ((style & 0x00C00000) != 0)
            hasMinimizeButton := ((style & 0x00020000) != 0)
            if (!hasCaption || !hasMinimizeButton)
                continue
        } catch {
            continue
        }

        ; Convert maximized/minimized clients to their normal placement without
        ; activating them, then resize/move directly into the chosen work-area cell.
        try {
            placement := Buffer(44, 0)
            NumPut("UInt", 44, placement, 0)
            if (DllCall("user32\GetWindowPlacement", "Ptr", hwnd, "Ptr", placement.Ptr, "Int")) {
                NumPut("UInt", 4, placement, 8) ; SW_SHOWNOACTIVATE
                DllCall("user32\SetWindowPlacement", "Ptr", hwnd, "Ptr", placement.Ptr, "Int")
            }

            cell := cells[index]
            DllCall("user32\SetWindowPos", "Ptr", hwnd, "Ptr", 0,
                "Int", cell[1], "Int", cell[2], "Int", cell[3], "Int", cell[4],
                "UInt", 0x0014) ; NOZORDER | NOACTIVATE

            ; This window already has a deliberate normal placement. Discard any
            ; older pre-maximize snapshot so a later click restores this layout.
            if (gameStatusPreMaxPlacements.Has(hwnd))
                gameStatusPreMaxPlacements.Delete(hwnd)

            laidOut += 1
        } catch {
        }
    }

    return (laidOut > 0)
}

; Direct click handlers for the titlebar buttons.
; Keep these mapped exactly to the keyboard hotkeys so the GUI buttons and
; keyboard controls cannot drift apart.
Macro_RobloxTitlebarF3Click(*) {
    Macro_ToggleGameStatusGUI()
}

; ============================================================
; ⓘ Shortcut Help
; A single non-activating help panel is shown at the center of the
; Roblox window whose titlebar help button was clicked. It stays on that
; selected target until Esc or a click on the Roblox client closes it.
; ============================================================
Macro_RobloxTitlebarHelpClick(ctrl, *) {
    global robloxTitlebarControlsByHwnd

    parentHwnd := 0
    try {
        if (IsObject(ctrl) && ctrl.Hwnd) {
            for robloxHwnd, controls in robloxTitlebarControlsByHwnd {
                if (IsObject(controls.help) && controls.help.Hwnd = ctrl.Hwnd) {
                    parentHwnd := robloxHwnd
                    break
                }
            }
        }
    } catch {
        parentHwnd := 0
    }

    if (!parentHwnd)
        parentHwnd := WinActive("ahk_exe RobloxPlayerBeta.exe")
    if (!parentHwnd || !WinExist("ahk_id " . parentHwnd))
        return

    Macro_ToggleShortcutHelp(parentHwnd)
}

Macro_ToggleShortcutHelp(targetHwnd := 0) {
    global shortcutHelpGui, shortcutHelpVisible, shortcutHelpTargetHwnd
    global shortcutHelpWidth, shortcutHelpHeight, shortcutHelpBaseDpi, shortcutHelpCurrentDpi
    global shortcutHelpLastX, shortcutHelpLastY, shortcutHelpLastRobloxActive

    if (!targetHwnd)
        targetHwnd := WinActive("ahk_exe RobloxPlayerBeta.exe")
    if (!targetHwnd || !WinExist("ahk_id " . targetHwnd))
        return

    helpGuiHwnd := Macro_GetShortcutHelpHwnd()
    if (shortcutHelpVisible && helpGuiHwnd) {
        try {
            if (DllCall("user32\IsWindowVisible", "Ptr", helpGuiHwnd)) {
                shortcutHelpVisible := false
                shortcutHelpTargetHwnd := 0
                shortcutHelpLastX := -2147483648
                shortcutHelpLastY := -2147483648
                shortcutHelpLastRobloxActive := false
                shortcutHelpGui.Hide()
                return
            }
        } catch {
        }
    }

    shortcutHelpTargetHwnd := targetHwnd
    desiredDpi := Macro_GetShortcutHelpDpi(targetHwnd)
    if (!helpGuiHwnd || shortcutHelpCurrentDpi != desiredDpi) {
        try {
            if (helpGuiHwnd)
                shortcutHelpGui.Destroy()
        } catch {
        }
        shortcutHelpGui := ""
        shortcutHelpCurrentDpi := 0
        Macro_CreateShortcutHelpGui(desiredDpi)
        helpGuiHwnd := Macro_GetShortcutHelpHwnd()
    }
    if (!helpGuiHwnd)
        return

    shortcutHelpVisible := true
    shortcutHelpLastX := -2147483648
    shortcutHelpLastY := -2147483648
    shortcutHelpLastRobloxActive := false
    Macro_UpdateShortcutHelpStateButtons(true)
    Macro_UpdateShortcutHelpPlacement()
    try
        shortcutHelpGui.Show("NoActivate w" . shortcutHelpWidth . " h" . shortcutHelpHeight)
    catch {
        return
    }
    Macro_SetShortcutHelpZOrder()
}

Macro_GetShortcutHelpDpi(targetHwnd) {
    global shortcutHelpBaseDpi

    dpi := Macro_GetRobloxMonitorDpi(targetHwnd)
    if (dpi < 72 || dpi > 480)
        dpi := shortcutHelpBaseDpi
    return dpi
}

Macro_CreateShortcutHelpGui(dpi := 144) {
    global shortcutHelpGui, shortcutHelpWidth, shortcutHelpHeight
    global shortcutHelpBaseDpi, shortcutHelpCurrentDpi, shortcutHelpStateControls
    global shortcutHelpModeControl, shortcutHelpModeLast
    global shortcutHelpRapidIntervalControl, mouseMacroRapidIntervalMs
    global shortcutHelpRapidDecreaseHwnd, shortcutHelpRapidIncreaseHwnd
    shortcutHelpStateControls := Map()
    shortcutHelpModeControl := ""
    shortcutHelpModeLast := ""
    shortcutHelpRapidIntervalControl := ""
    shortcutHelpRapidDecreaseHwnd := 0
    shortcutHelpRapidIncreaseHwnd := 0

    ; Fixed layout based on the user's accepted 150% (144 DPI) appearance.
    ; No text measurement or content-driven auto-sizing is used.
    isKorean := (Macro_GetWindowsUILanguage() = "ko")

    if (isKorean) {
        rows := [
            ; Full help is now ordered by the actual shortcut sequence.
            ["__GROUP__", "창 관리", ""],
            ["Ctrl+F1", "Roblox 창 순환", ""],
            ["Ctrl+F2", "Roblox 창 최대화 / 복원", ""],
            ["__GROUP__", "마우스 조작", ""],
            ["F3", "마우스 모드 전환 (홀드 / 연타)", ""],
            ["F4", "마우스 매크로 실행", "ON / OFF"],
            ["__GROUP__", "연결 및 진단", ""],
            ["F5", "연결 끊김 감시 + 자동 재연결", "ON / OFF"],
            ["F6", "연결 모달 디버그", "ON / OFF"],
            ["__GROUP__", "스크립트 및 상태", ""],
            ["F7", "AHK 스크립트 다시 불러오기", ""],
            ["F8", "게임 상태 표시", "ON / OFF"],
            ["F9", "긴급 초기화 + 다시 불러오기", ""],
            ["__GROUP__", "화면 및 녹화", ""],
            ["F10", "그래픽 품질 증가", ""],
            ["Shift+F10", "그래픽 품질 감소", ""],
            ["F11", "전체화면 전환", ""],
            ["F12", "동영상 녹화", ""]
        ]
        titleText := "ⓘ  단축키"
        footerText := "Esc 또는 Roblox 창을 클릭하면 닫힙니다"
    } else {
        rows := [
            ; Full help is now ordered by the actual shortcut sequence.
            ["__GROUP__", "WINDOW MANAGEMENT", ""],
            ["Ctrl+F1", "Cycle Roblox windows", ""],
            ["Ctrl+F2", "Maximize / restore Roblox window", ""],
            ["__GROUP__", "MOUSE CONTROL", ""],
            ["F3", "Toggle mouse mode (hold / rapid)", ""],
            ["F4", "Mouse macro master", "ON / OFF"],
            ["__GROUP__", "CONNECTION & DIAGNOSTICS", ""],
            ["F5", "Connection monitoring + auto reconnect", "ON / OFF"],
            ["F6", "Connection modal debug", "ON / OFF"],
            ["__GROUP__", "SCRIPT & STATUS", ""],
            ["F7", "Reload AHK script", ""],
            ["F8", "Game status", "ON / OFF"],
            ["F9", "Emergency reset + reload", ""],
            ["__GROUP__", "DISPLAY & RECORDING", ""],
            ["F10", "Increase graphics quality", ""],
            ["Shift+F10", "Decrease graphics quality", ""],
            ["F11", "Toggle fullscreen", ""],
            ["F12", "Video recording", ""]
        ]
        titleText := "ⓘ  Shortcuts"
        footerText := "Press Esc or click the Roblox window to close"
    }

    if (dpi < 72 || dpi > 480)
        dpi := shortcutHelpBaseDpi
    scale := dpi / shortcutHelpBaseDpi

    ; 150% / 144 DPI reference geometry.
    shortcutHelpWidth := Round(710 * scale)
    shortcutHelpHeight := Round(836 * scale)
    shortcutHelpCurrentDpi := dpi

    titleX := Round(0 * scale)
    titleY := Round(16 * scale)
    titleW := shortcutHelpWidth
    titleH := Round(34 * scale)

    keyX := Round(28 * scale)
    keyW := Round(125 * scale)
    descX := Round(170 * scale)
    descW := Round(355 * scale)
    stateX := Round(545 * scale)
    stateW := Round(135 * scale)

    ; Compact, consistent vertical rhythm for the complete five-section help.
    ; The help keeps the same overall window size while adding visible section labels.
    firstRowY := Round(64 * scale)
    rowH := Round(28 * scale)
    rowGap := Round(12 * scale)
    groupHeadingH := Round(18 * scale)
    groupHeadingTopGap := Round(8 * scale)
    groupHeadingBottomGap := Round(2 * scale)

    footerX := Round(30 * scale)
    footerY := Round(803 * scale)
    footerW := shortcutHelpWidth - Round(60 * scale)
    footerH := Round(24 * scale)

    try {
        shortcutHelpGui := Gui("-Caption +ToolWindow +E0x08000000 -DPIScale", "Roblox Shortcuts")
        shortcutHelpGui.BackColor := "1D1D1D"
        shortcutHelpGui.SetFont("s13 cFFFFFF", "Segoe UI")

        title := shortcutHelpGui.AddText("x" . titleX . " y" . titleY . " w" . titleW . " h" . titleH . " Center +0x200 BackgroundTrans", titleText)
        title.SetFont("s15 Bold cFFFFFF", "Segoe UI")

        y := firstRowY
        groupHeadingShown := false
        for index, row in rows {
            ; Section headings are visual only. They do not affect hotkeys,
            ; state bindings, row actions, or the existing control handlers.
            if (row[1] = "__GROUP__") {
                if (groupHeadingShown)
                    y += groupHeadingTopGap
                headingCtrl := shortcutHelpGui.AddText(
                    "x" . keyX . " y" . y . " w" . (stateX + stateW - keyX) . " h" . groupHeadingH
                    . " Left +0x200 BackgroundTrans", row[2]
                )
                headingCtrl.SetFont("s9 Bold c8F9BA8", "Segoe UI")
                y += groupHeadingH + groupHeadingBottomGap
                groupHeadingShown := true
                continue
            }

            keyCtrl := shortcutHelpGui.AddText("x" . keyX . " y" . y . " w" . keyW . " h" . rowH . " Left +0x200 BackgroundTrans", row[1])
            keyCtrl.SetFont("s13 Bold cFFFFFF", "Segoe UI")

            descCtrl := shortcutHelpGui.AddText("x" . descX . " y" . y . " w" . descW . " h" . rowH . " Left +0x200 BackgroundTrans", row[2])
            descCtrl.SetFont("s13 cFFFFFF", "Segoe UI")

            if (row[3] != "") {
                stateAction := ""
                switch row[1] {
                    case "F8":
                        stateAction := "gameStatus"
                    case "F4":
                        stateAction := "mouseF4"
                    case "F5":
                        stateAction := "F5"
                    case "F6":
                        stateAction := "F6"
                }

                if (stateAction != "") {
                    ; Clickable status pill: mint for ON, charcoal for OFF.
                    isOn := Macro_GetShortcutHelpFeatureState(stateAction)
                    stateText := isOn ? "ON" : "OFF"
                    stateBg := isOn ? "66FFCC" : "3A3A3A"
                    stateFg := isOn ? "17382D" : "D6D6D6"
                    stateButtonX := stateX + Round(19 * scale)
                    stateButtonW := Round(96 * scale)
                    stateButtonH := Round(25 * scale)
                    stateButtonY := y + Max(0, Round((rowH - stateButtonH) / 2))
                    stateCtrl := shortcutHelpGui.AddText(
                        "x" . stateButtonX . " y" . stateButtonY . " w" . stateButtonW . " h" . stateButtonH
                        . " Center +0x200 Border Background" . stateBg, stateText
                    )
                    stateCtrl.SetFont("s11 Bold c" . stateFg, "Segoe UI")
                    stateCtrl.OnEvent("Click", Macro_ShortcutHelpToggleFeature.Bind(stateAction))
                    shortcutHelpStateControls[stateAction] := {ctrl: stateCtrl, lastOn: isOn}
                }
            }

            ; F3 is a two-mode selector, not an ON/OFF feature.
            ; Show the current mouse mode as a colored, clickable pill in the state column.
            if (row[1] = "F3") {
                modeText := isKorean ? "홀드" : "HOLD"
                modeX := stateX + Round(19 * scale)
                modeW := Round(96 * scale)
                modeH := Round(25 * scale)
                modeY := y + Max(0, Round((rowH - modeH) / 2))
                shortcutHelpModeControl := shortcutHelpGui.AddText(
                    "x" . modeX . " y" . modeY . " w" . modeW . " h" . modeH
                    . " Center +0x200 Border Background66CCFF", modeText
                )
                shortcutHelpModeControl.SetFont("s11 Bold c102A38", "Segoe UI")
                shortcutHelpModeControl.OnEvent("Click", Macro_ShortcutHelpToggleMouseMode)
                shortcutHelpModeLast := ""
            }

            ; Insert the interval row below F3 with the same vertical gap as other rows.
            if (row[1] = "F3") {
                rapidIntervalRowH := rowH
                rapidIntervalY := y + rowH + rowGap
                rapidIntervalLabel := isKorean ? "연타 간격 (10 ms 단위)" : "Rapid interval (10 ms steps)"
                rapidIntervalLabelCtrl := shortcutHelpGui.AddText(
                    "x" . descX . " y" . rapidIntervalY . " w" . descW . " h" . rapidIntervalRowH
                    . " Left +0x200 BackgroundTrans", rapidIntervalLabel
                )
                rapidIntervalLabelCtrl.SetFont("s12 cFFFFFF", "Segoe UI")

                intervalButtonH := Round(24 * scale)
                intervalButtonY := rapidIntervalY + Max(0, Round((rapidIntervalRowH - intervalButtonH) / 2))
                intervalButtonW := Round(24 * scale)
                intervalValueW := Round(74 * scale)
                intervalGap := Round(3 * scale)
                intervalGroupX := stateX + Round(4 * scale)
                intervalValueX := intervalGroupX + intervalButtonW + intervalGap
                intervalIncreaseX := intervalValueX + intervalValueW + intervalGap

                intervalDecreaseCtrl := shortcutHelpGui.AddText(
                    "x" . intervalGroupX . " y" . intervalButtonY . " w" . intervalButtonW . " h" . intervalButtonH
                    . " Center +0x200 Border Background3A3A3A", "-"
                )
                ; SS_NOTIFY makes this Text control emit the standard Click event.
                intervalDecreaseCtrl.Opt("+0x100")
                intervalDecreaseCtrl.SetFont("s12 Bold cFFFFFF", "Segoe UI")
                shortcutHelpRapidDecreaseHwnd := intervalDecreaseCtrl.Hwnd
                intervalDecreaseCtrl.OnEvent("Click", MouseMacro_AdjustRapidIntervalFromClick.Bind(-10))

                shortcutHelpRapidIntervalControl := shortcutHelpGui.AddText(
                    "x" . intervalValueX . " y" . intervalButtonY . " w" . intervalValueW . " h" . intervalButtonH
                    . " Center +0x200 Border Background2A2A2A", mouseMacroRapidIntervalMs . " ms"
                )
                shortcutHelpRapidIntervalControl.SetFont("s11 Bold cFFFFFF", "Segoe UI")

                intervalIncreaseCtrl := shortcutHelpGui.AddText(
                    "x" . intervalIncreaseX . " y" . intervalButtonY . " w" . intervalButtonW . " h" . intervalButtonH
                    . " Center +0x200 Border Background3A3A3A", "+"
                )
                intervalIncreaseCtrl.Opt("+0x100")
                intervalIncreaseCtrl.SetFont("s12 Bold cFFFFFF", "Segoe UI")
                shortcutHelpRapidIncreaseHwnd := intervalIncreaseCtrl.Hwnd
                intervalIncreaseCtrl.OnEvent("Click", MouseMacro_AdjustRapidIntervalFromClick.Bind(10))
            }

            ; Add direct buttons for the keyboard actions requested by the user.
            ; The help GUI remains non-activating; the handlers below explicitly
            ; target the Roblox client associated with this help panel when needed.
            if (row[1] = "F7" || row[1] = "F9" || row[1] = "F10" || row[1] = "Shift+F10") {
                runButtonText := isKorean ? "실행" : "Run"
                runButtonX := stateX + Round(12 * scale)
                runButtonW := Round(100 * scale)
                runButtonH := Round(26 * scale)
                runButtonY := y + Max(0, Round((rowH - runButtonH) / 2))
                runButton := shortcutHelpGui.AddButton(
                    "x" . runButtonX . " y" . runButtonY . " w" . runButtonW . " h" . runButtonH,
                    runButtonText
                )
                runButton.SetFont("s10 Bold", "Segoe UI")
                runButton.OnEvent("Click", Macro_ShortcutHelpRunAction.Bind(row[1]))
            }

            ; F3 has an additional rapid-interval row directly beneath it.
            ; All other row spacing is controlled by explicit blank group separators.
            if (row[1] = "F3")
                y += rowH + rowGap + rowH + rowGap
            else
                y += rowH + rowGap
        }

        footerCtrl := shortcutHelpGui.AddText("x" . footerX . " y" . footerY . " w" . footerW . " h" . footerH . " Center +0x200 BackgroundTrans", footerText)
        footerCtrl.SetFont("s11 cA8A8A8", "Segoe UI")

        shortcutHelpGui.Show("x-32000 y-32000 w" . shortcutHelpWidth . " h" . shortcutHelpHeight . " NoActivate")
        shortcutHelpGui.Hide()
    } catch {
        try {
            if (IsObject(shortcutHelpGui))
                shortcutHelpGui.Destroy()
        } catch {
        }
        shortcutHelpGui := ""
        shortcutHelpWidth := 0
        shortcutHelpHeight := 0
        shortcutHelpCurrentDpi := 0
    }
}

Macro_GetShortcutHelpFeatureState(featureKey) {
    global gameStatusVisible, mouseMacroMasterOn
    global connectionRecoveryEnabled, fixedPointModalDebugEnabled

    switch featureKey {
        case "gameStatus":
            return !!gameStatusVisible
        case "mouseF4":
            return !!mouseMacroMasterOn
        case "F5":
            return !!connectionRecoveryEnabled
        case "F6":
            return !!fixedPointModalDebugEnabled
    }
    return false
}

Macro_UpdateShortcutHelpStateButtons(force := false) {
    global shortcutHelpStateControls

    ; The F3 mode pill is updated alongside ON/OFF pills.
    Macro_UpdateShortcutHelpModeButton(force)
    Macro_UpdateShortcutHelpRapidIntervalControl(force)

    if (!IsObject(shortcutHelpStateControls))
        return

    for featureKey, entry in shortcutHelpStateControls {
        try {
            isOn := Macro_GetShortcutHelpFeatureState(featureKey)
            if (!force && entry.lastOn = isOn)
                continue

            entry.ctrl.Text := isOn ? "ON" : "OFF"
            if (isOn) {
                entry.ctrl.Opt("+Background66FFCC")
                entry.ctrl.SetFont("s11 Bold c17382D", "Segoe UI")
            } else {
                entry.ctrl.Opt("+Background3A3A3A")
                entry.ctrl.SetFont("s11 Bold cD6D6D6", "Segoe UI")
            }
            entry.lastOn := isOn
            DllCall("user32\InvalidateRect", "Ptr", entry.ctrl.Hwnd, "Ptr", 0, "Int", 1)
            DllCall("user32\UpdateWindow", "Ptr", entry.ctrl.Hwnd)
        } catch {
            ; A control can be destroyed/rebuilt during a DPI transition.
        }
    }
}

Macro_UpdateShortcutHelpModeButton(force := false) {
    global shortcutHelpModeControl, shortcutHelpModeLast, mouseMacroMode

    ; A GUI control object may still be an AHK object after its native control
    ; has been destroyed (for example, during a DPI-driven help-window rebuild).
    ; Accessing .Hwnd in the condition itself can throw, so validate it inside
    ; try/catch and clear stale references before returning.
    if (!IsObject(shortcutHelpModeControl))
        return

    try {
        controlHwnd := shortcutHelpModeControl.Hwnd
        if (!controlHwnd || !DllCall("user32\IsWindow", "Ptr", controlHwnd)) {
            shortcutHelpModeControl := ""
            shortcutHelpModeLast := ""
            return
        }
    } catch {
        shortcutHelpModeControl := ""
        shortcutHelpModeLast := ""
        return
    }

    mode := (mouseMacroMode = "HOLD") ? "HOLD" : "RAPID"
    if (!force && mode = shortcutHelpModeLast)
        return

    isKorean := (Macro_GetWindowsUILanguage() = "ko")
    label := mode = "HOLD" ? (isKorean ? "홀드" : "HOLD") : (isKorean ? "연타" : "RAPID")
    background := mode = "HOLD" ? "66CCFF" : "FFB454"
    foreground := mode = "HOLD" ? "102A38" : "39240C"

    try {
        shortcutHelpModeControl.Text := label
        shortcutHelpModeControl.Opt("+Background" . background)
        shortcutHelpModeControl.SetFont("s11 Bold c" . foreground, "Segoe UI")
        shortcutHelpModeLast := mode
        DllCall("user32\InvalidateRect", "Ptr", controlHwnd, "Ptr", 0, "Int", 1)
        DllCall("user32\UpdateWindow", "Ptr", controlHwnd)
    } catch {
        ; The help panel may be rebuilding after a DPI change. Drop the stale
        ; control reference so the next GUI creation can register a fresh one.
        shortcutHelpModeControl := ""
        shortcutHelpModeLast := ""
    }
}

Macro_UpdateShortcutHelpRapidIntervalControl(force := false) {
    global shortcutHelpRapidIntervalControl, mouseMacroRapidIntervalMs

    if (!IsObject(shortcutHelpRapidIntervalControl))
        return

    try {
        controlHwnd := shortcutHelpRapidIntervalControl.Hwnd
        if (!controlHwnd || !DllCall("user32\IsWindow", "Ptr", controlHwnd)) {
            shortcutHelpRapidIntervalControl := ""
            return
        }

        valueText := mouseMacroRapidIntervalMs . " ms"
        if (!force && shortcutHelpRapidIntervalControl.Text = valueText)
            return

        ; Let Windows repaint after this input callback returns so rapid presses
        ; do not wait for a forced synchronous redraw.
        shortcutHelpRapidIntervalControl.Text := valueText
    } catch {
        shortcutHelpRapidIntervalControl := ""
    }
}

Macro_ShortcutHelpToggleMouseMode(ctrl, *) {
    global mouseMacroMasterOn

    ; Keep the same availability condition as the physical F3 hotkey.
    if (!mouseMacroMasterOn || !MouseMacro_IsRobloxActive())
        return

    MouseMacro_ToggleMode()
}

Macro_ShortcutHelpToggleFeature(featureKey, ctrl, *) {
    ; Use the same feature toggle handlers as the keyboard hotkeys. Refresh all
    ; pills afterward because some toggles (e.g. F4) can also switch F6 off.
    switch featureKey {
        case "gameStatus":
            Macro_ToggleGameStatusGUI()
        case "mouseF4":
            MouseMacro_ToggleMaster()
        case "F5":
            Macro_ToggleConnectionRecovery()
        case "F6":
            Macro_ToggleFixedPointModalDebug()
    }
    Macro_UpdateShortcutHelpStateButtons(true)
}

Macro_ShortcutHelpRunAction(shortcutKey, ctrl, *) {
    ; F7 reloads the script. F9 invokes the exact emergency-reset handler used
    ; by the physical key. F10 variants are forwarded to the selected Roblox.
    switch shortcutKey {
        case "F7":
            Reload()
        case "F9":
            Macro_EmergencyResetReload()
        case "F10":
            Macro_SendShortcutHelpKey("{F10}")
        case "Shift+F10":
            Macro_SendShortcutHelpShiftF10()
    }
}

; Send the original Shift+F10 combination, then tap Shift separately once.
; The second tap is intended to undo Roblox's Shift-toggle change caused by
; the modifier in Shift+F10, while leaving the graphics-quality decrement.
Macro_SendShortcutHelpShiftF10() {
    global shortcutHelpTargetHwnd

    targetHwnd := shortcutHelpTargetHwnd
    if (!targetHwnd || !WinExist("ahk_id " . targetHwnd))
        return

    ; Remember the exact cursor position over the Help button before activating
    ; Roblox. Shift Lock may recenter the cursor while the key sequence runs.
    MouseGetPos(&returnMouseX, &returnMouseY)

    try {
        if (WinActive("ahk_id " . targetHwnd) != targetHwnd) {
            WinActivate("ahk_id " . targetHwnd)
            WinWaitActive("ahk_id " . targetHwnd, , 1)
        }
        if (WinActive("ahk_id " . targetHwnd) = targetHwnd) {
            Sleep(40)
            ; 1) Original key combination: Shift + F10.
            SendEvent("+{F10}")
            ; 2) Minimize the interval so Roblox has less time to remain in
            ;    the transient Shift-toggle state before the corrective tap.
            Sleep(20)
            SendEvent("{Shift down}")
            Sleep(20)
            SendEvent("{Shift up}")
        }
    } catch {
        ; Best-effort safety: never leave a synthetic Shift held down.
        try SendEvent("{Shift up}")
        ; Even if key delivery fails, restore the cursor to the clicked button.
        try MouseMove(returnMouseX, returnMouseY, 0)
        return
    }

    Macro_SetShortcutHelpZOrder()

    ; Roblox may have moved the cursor to the client center during Shift Lock.
    ; Put it back exactly where the user clicked, over the Shift+F10 Help button.
    MouseMove(returnMouseX, returnMouseY, 0)
}

Macro_SendShortcutHelpKey(keySequence) {
    global shortcutHelpTargetHwnd

    targetHwnd := shortcutHelpTargetHwnd
    if (!targetHwnd || !WinExist("ahk_id " . targetHwnd))
        return

    ; Send to the client represented by this help panel, rather than whichever
    ; Roblox window happened to be active most recently.
    try {
        if (WinActive("ahk_id " . targetHwnd) != targetHwnd) {
            WinActivate("ahk_id " . targetHwnd)
            WinWaitActive("ahk_id " . targetHwnd, , 1)
        }
        if (WinActive("ahk_id " . targetHwnd) = targetHwnd) {
            Sleep(40)
            SendEvent(keySequence)
        }
    } catch {
        return
    }

    ; Keep the help panel in its established z-order after sending the key.
    Macro_SetShortcutHelpZOrder()
}

Macro_CloseShortcutHelp() {
    global shortcutHelpGui, shortcutHelpVisible, shortcutHelpTargetHwnd
    global shortcutHelpLastX, shortcutHelpLastY, shortcutHelpLastRobloxActive

    shortcutHelpVisible := false
    shortcutHelpTargetHwnd := 0
    shortcutHelpLastX := -2147483648
    shortcutHelpLastY := -2147483648
    shortcutHelpLastRobloxActive := false
    helpGuiHwnd := Macro_GetShortcutHelpHwnd()
    try {
        if (helpGuiHwnd)
            shortcutHelpGui.Hide()
    } catch {
    }
}

Macro_HandleShortcutHelpEscape() {
    global shortcutHelpVisible

    if (shortcutHelpVisible)
        Macro_CloseShortcutHelp()
}

Macro_HandleShortcutHelpRobloxClick() {
    global shortcutHelpVisible, shortcutHelpGui, shortcutHelpTargetHwnd

    if (!shortcutHelpVisible || !shortcutHelpTargetHwnd)
        return false

    ; Clicking inside the help window must never close it.
    MouseGetPos(,, &mouseHwnd)
    ; Resolve the physical window under the cursor to its top-level owner.
    rootHwnd := mouseHwnd
    try {
        if (mouseHwnd)
            rootHwnd := DllCall("user32\GetAncestor", "Ptr", mouseHwnd, "UInt", 2, "Ptr")
    } catch {
    }

    ; Clicking anywhere inside the help panel itself must never close it.
    ; Guard only this HWND read: the Gui wrapper may remain after its native
    ; window has already been destroyed, in which case .Hwnd raises an error.
    helpGuiHwnd := Macro_GetShortcutHelpHwnd()
    if (helpGuiHwnd && rootHwnd = helpGuiHwnd)
        return false

    ; Only a click on the actual Roblox client closes the help panel.
    if (rootHwnd = shortcutHelpTargetHwnd) {
        Macro_CloseShortcutHelp()
        return false
    }

    return false
}

Macro_UpdateShortcutHelpPlacement() {
    global shortcutHelpGui, shortcutHelpVisible, shortcutHelpTargetHwnd
    global shortcutHelpWidth, shortcutHelpHeight, shortcutHelpCurrentDpi
    global shortcutHelpLastX, shortcutHelpLastY

    if (!shortcutHelpVisible)
        return

    ; Keep help buttons synchronized with real feature flags, even when a
    ; keyboard hotkey changes a feature while this panel remains open.
    Macro_UpdateShortcutHelpStateButtons()

    helpGuiHwnd := Macro_GetShortcutHelpHwnd()
    targetHwnd := shortcutHelpTargetHwnd
    if (!targetHwnd || !WinExist("ahk_id " . targetHwnd)) {
        shortcutHelpVisible := false
        shortcutHelpTargetHwnd := 0
        shortcutHelpLastX := -2147483648
        shortcutHelpLastY := -2147483648
        try {
            if (helpGuiHwnd)
                shortcutHelpGui.Hide()
        } catch {
        }
        return
    }

    desiredDpi := Macro_GetShortcutHelpDpi(targetHwnd)
    if (!helpGuiHwnd || shortcutHelpCurrentDpi != desiredDpi) {
        try {
            if (helpGuiHwnd)
                shortcutHelpGui.Destroy()
        } catch {
        }
        shortcutHelpGui := ""
        shortcutHelpCurrentDpi := 0
        Macro_CreateShortcutHelpGui(desiredDpi)
        helpGuiHwnd := Macro_GetShortcutHelpHwnd()
        if (!helpGuiHwnd)
            return
    }

    if (shortcutHelpWidth <= 0 || shortcutHelpHeight <= 0)
        return

    try {
        clientRect := Buffer(16, 0)
        clientOrigin := Buffer(8, 0)
        if (!DllCall("user32\GetClientRect", "Ptr", targetHwnd, "Ptr", clientRect.Ptr))
            return

        clientW := NumGet(clientRect, 8, "Int")
        clientH := NumGet(clientRect, 12, "Int")
        if (clientW <= 0 || clientH <= 0)
            return

        NumPut("Int", 0, clientOrigin, 0)
        NumPut("Int", 0, clientOrigin, 4)
        if (!DllCall("user32\ClientToScreen", "Ptr", targetHwnd, "Ptr", clientOrigin.Ptr))
            return

        clientX := NumGet(clientOrigin, 0, "Int")
        clientY := NumGet(clientOrigin, 4, "Int")

        ; Dock flush to the top-right corner of the Roblox CLIENT area.
        px := clientX + clientW - shortcutHelpWidth
        py := clientY
        if (clientW < shortcutHelpWidth)
            px := clientX
        geometryChanged := (shortcutHelpLastX != px || shortcutHelpLastY != py)
        if (geometryChanged) {
            DllCall("user32\SetWindowPos", "Ptr", helpGuiHwnd, "Ptr", 0,
                "Int", px, "Int", py, "Int", shortcutHelpWidth, "Int", shortcutHelpHeight,
                "UInt", 0x0014) ; NOZORDER | NOACTIVATE
            shortcutHelpLastX := px
            shortcutHelpLastY := py
        }
        if (!DllCall("user32\IsWindowVisible", "Ptr", helpGuiHwnd))
            shortcutHelpGui.Show("x" . px . " y" . py . " w" . shortcutHelpWidth . " h" . shortcutHelpHeight . " NoActivate")
    } catch {
        return
    }

    Macro_SetShortcutHelpZOrder()
}

Macro_SetShortcutHelpZOrder() {
    global shortcutHelpVisible, shortcutHelpTargetHwnd
    global shortcutHelpLastRobloxActive

    if (!shortcutHelpVisible)
        return
    helpGuiHwnd := Macro_GetShortcutHelpHwnd()
    if (!helpGuiHwnd)
        return

    targetHwnd := shortcutHelpTargetHwnd
    if (!targetHwnd || !WinExist("ahk_id " . targetHwnd))
        return

    try {
        robloxIsActive := (WinActive("ahk_id " . targetHwnd) = targetHwnd)
        if (robloxIsActive = shortcutHelpLastRobloxActive) {
            ; If Roblox remains active, repair the help panel only when it has
            ; actually fallen behind the Roblox window. Hovering the panel must
            ; never make it disappear visually.
            if (robloxIsActive) {
                zHwnd := 0
                try {
                    zHwnd := DllCall("user32\GetWindow", "Ptr", targetHwnd, "UInt", 3, "Ptr")
                } catch {
                    zHwnd := 0
                }
                isAbove := false
                while (zHwnd) {
                    if (zHwnd = helpGuiHwnd) {
                        isAbove := true
                        break
                    }
                    try zHwnd := DllCall("user32\GetWindow", "Ptr", zHwnd, "UInt", 3, "Ptr")
                    catch {
                        zHwnd := 0
                    }
                }
                if (isAbove)
                    return
                DllCall("user32\SetWindowPos", "Ptr", helpGuiHwnd, "Ptr", -1,
                    "Int", 0, "Int", 0, "Int", 0, "Int", 0,
                    "UInt", 0x0013) ; TOPMOST | NOACTIVATE | NOMOVE | NOSIZE
            }
            return
        }

        if (robloxIsActive) {
            DllCall("user32\SetWindowPos", "Ptr", helpGuiHwnd, "Ptr", -1,
                "Int", 0, "Int", 0, "Int", 0, "Int", 0,
                "UInt", 0x0013) ; TOPMOST | NOACTIVATE | NOMOVE | NOSIZE
        } else {
            DllCall("user32\SetWindowPos", "Ptr", helpGuiHwnd, "Ptr", targetHwnd,
                "Int", 0, "Int", 0, "Int", 0, "Int", 0,
                "UInt", 0x0013) ; above Roblox, still below active other apps
        }
        shortcutHelpLastRobloxActive := robloxIsActive
    } catch {
    }
}

; Legacy helper retained for compatibility with any existing message routing.
; The actual GUI controls now use their own Click events above.
Macro_RobloxTitlebarControlsClick(hwnd) {
    global robloxTitlebarControlsByHwnd

    try {
        rootHwnd := DllCall("user32\GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr")
    } catch {
        rootHwnd := hwnd
    }

    try {
        for robloxHwnd, controls in robloxTitlebarControlsByHwnd {
            if (rootHwnd != controls.gui.Hwnd && hwnd != controls.gui.Hwnd)
                continue

            MouseGetPos(&mouseX, &mouseY)
            if (mouseX < controls.x + controls.buttonW)
                Macro_ToggleGameStatusGUI()
            else if (mouseX < controls.x + (controls.buttonW * 2))
                Macro_ToggleConnectionRecovery()
            else if (mouseX < controls.x + (controls.buttonW * 3))
                Macro_ToggleShortcutHelp(robloxHwnd)
            else if (controls.quadVisible)
                Macro_RobloxTitlebarAutoLayoutClick(controls.quad, 0)
            return true
        }
    } catch {
    }
    return false
}

Macro_UpdateRobloxTitlebarTooltip() {
    global robloxTitlebarControlsByHwnd, robloxTitlebarTooltipText
    global robloxTitlebarTooltipGui, robloxTitlebarTooltipCtrl
    global robloxTitlebarTooltipX, robloxTitlebarTooltipY, robloxTitlebarTooltipWidth

    hoverText := ""
    hoverCenterX := 0
    hoverBottomY := 0
    hoverMonitorY := 0
    hoverControlsHwnd := 0
    hoverTargetHwnd := 0
    hoverControlsTransparent := false
    MouseGetPos(&mouseX, &mouseY, &mouseHwnd)
    mouseRootHwnd := 0
    if (mouseHwnd) {
        try mouseRootHwnd := DllCall("user32\GetAncestor", "Ptr", mouseHwnd, "UInt", 2, "Ptr") ; GA_ROOT
        catch
            mouseRootHwnd := mouseHwnd
    }
    for robloxHwnd, controls in robloxTitlebarControlsByHwnd {
        if (mouseX < controls.x || mouseX >= controls.x + controls.width
            || mouseY < controls.y || mouseY >= controls.y + controls.height)
            continue

        if (mouseX < controls.x + controls.buttonW) {
            hoverText := "Game Selector (F8)"
            buttonIndex := 0
        } else if (mouseX < controls.x + (controls.buttonW * 2)) {
            hoverText := (Macro_GetWindowsUILanguage() = "ko") ? "도움말" : "Shortcut Help"
            buttonIndex := 1
        } else if (controls.quadVisible) {
            hoverText := (Macro_GetWindowsUILanguage() = "ko") ? "분할 배치" : "Split Layout"
            buttonIndex := 2
        } else {
            continue
        }
        hoverCenterX := controls.x + Round(controls.buttonW * (buttonIndex + 0.5))
        hoverBottomY := controls.y + controls.height
        hoverMonitorY := controls.y + Round(controls.height / 2)
        hoverControlsHwnd := controls.gui.Hwnd
        hoverTargetHwnd := robloxHwnd
        hoverControlsTransparent := controls.transparentBackground
        break
    }

    if (hoverText = "") {
        Macro_HideRobloxTitlebarTooltip()
        robloxTitlebarTooltipText := ""
        return
    }

    ; Coordinates alone are insufficient: the old implementation showed the
    ; tooltip whenever the cursor overlapped a remembered button rectangle, even
    ; when another application's window was actually underneath the cursor.
    ; Only show it when hit-testing says the titlebar control surface is really
    ; the window receiving the pointer. This prevents the tooltip floating over
    ; unrelated programs that cover Roblox.
    if (!hoverControlsHwnd) {
        Macro_HideRobloxTitlebarTooltip()
        robloxTitlebarTooltipText := ""
        return
    }

    if (hoverControlsTransparent) {
        ; Color-keyed background pixels pass mouse input through to Roblox.
        ; Coordinate hover remains valid only while this exact Roblox client is
        ; foreground, preventing tooltips over unrelated applications.
        if (DllCall("user32\GetForegroundWindow", "Ptr") != hoverTargetHwnd) {
            Macro_HideRobloxTitlebarTooltip()
            robloxTitlebarTooltipText := ""
            return
        }
    } else if (mouseRootHwnd != hoverControlsHwnd) {
        Macro_HideRobloxTitlebarTooltip()
        robloxTitlebarTooltipText := ""
        return
    }

    ; A Gui object can remain assigned after its native window has been
    ; destroyed (for example, when its owner window is recreated). Accessing
    ; .Hwnd in that state throws "Gui has no window". Probe the handle safely
    ; and validate it with IsWindow, which also works while the tooltip is hidden.
    tooltipHwnd := 0
    if (IsObject(robloxTitlebarTooltipGui)) {
        try tooltipHwnd := robloxTitlebarTooltipGui.Hwnd
        catch
            tooltipHwnd := 0
    }
    if (!tooltipHwnd || !DllCall("user32\IsWindow", "Ptr", tooltipHwnd, "Int")) {
        ; Discard any stale Gui/Control object before rebuilding its HWND.
        try {
            if (IsObject(robloxTitlebarTooltipGui))
                robloxTitlebarTooltipGui.Destroy()
        } catch {
        }
        robloxTitlebarTooltipGui := ""
        robloxTitlebarTooltipCtrl := ""
        try {
            ; Make the tooltip an owned popup of the button surface instead of
            ; an independent TOPMOST window. Owned-window Z-order follows the
            ; controls: it can appear above the buttons while Roblox is foreground,
            ; but cannot stay floating over another application's window when the
            ; controls are back in the normal Z-order band.
            robloxTitlebarTooltipGui := Gui(
                "+Owner" . hoverControlsHwnd . " -Caption +ToolWindow +E0x20 +E0x08000000 -DPIScale",
                "Roblox titlebar tooltip"
            )
            robloxTitlebarTooltipGui.BackColor := "FFF4C2"
            robloxTitlebarTooltipGui.SetFont("s10 c202020", "Segoe UI")
            robloxTitlebarTooltipCtrl := robloxTitlebarTooltipGui.AddText(
                "x8 y4 w1 h20 Center +0x200", ""
            )
            tooltipHwnd := robloxTitlebarTooltipGui.Hwnd
        } catch {
            robloxTitlebarTooltipGui := ""
            robloxTitlebarTooltipCtrl := ""
            return
        }
        if (!tooltipHwnd || !DllCall("user32\IsWindow", "Ptr", tooltipHwnd, "Int")) {
            robloxTitlebarTooltipGui := ""
            robloxTitlebarTooltipCtrl := ""
            return
        }
        robloxTitlebarTooltipX := -1
        robloxTitlebarTooltipY := -1
        robloxTitlebarTooltipWidth := 0
        robloxTitlebarTooltipText := ""
    }

    ; Size the background from the rendered text rather than fixed per-button
    ; widths. Fixed widths made short Korean labels (for example, "도움말")
    ; sit inside a disproportionately wide tooltip background.
    measuredTextW := Macro_GetRobloxTitlebarTooltipTextWidth(hoverText, robloxTitlebarTooltipCtrl)
    tooltipW := Max(36, measuredTextW + 20) ; 10 px horizontal breathing room per side
    tooltipH := 28

    textChanged := (hoverText != robloxTitlebarTooltipText)
    widthChanged := (tooltipW != robloxTitlebarTooltipWidth)
    if (textChanged) {
        try robloxTitlebarTooltipCtrl.Text := hoverText
        catch
            return
    }
    if (textChanged || widthChanged) {
        try robloxTitlebarTooltipCtrl.Move(8, 4, tooltipW - 16, 20)
        catch
            return
    }

    tooltipX := Round(hoverCenterX - tooltipW / 2)
    tooltipY := hoverBottomY + 6
    workLeft := -32768, workTop := -32768, workRight := 32768, workBottom := 32768
    try {
        Loop MonitorGetCount() {
            MonitorGet(A_Index, &monitorLeft, &monitorTop, &monitorRight, &monitorBottom)
            if (hoverCenterX >= monitorLeft && hoverCenterX < monitorRight
                && hoverMonitorY >= monitorTop && hoverMonitorY < monitorBottom) {
                MonitorGetWorkArea(A_Index, &workLeft, &workTop, &workRight, &workBottom)
                break
            }
        }
    } catch {
    }
    tooltipX := Max(workLeft, Min(tooltipX, workRight - tooltipW))
    if (tooltipY + tooltipH > workBottom)
        tooltipY := hoverBottomY - tooltipH - 6
    tooltipY := Max(workTop, Min(tooltipY, workBottom - tooltipH))
    tooltipVisible := !!DllCall("user32\IsWindowVisible", "Ptr", tooltipHwnd, "Int")
    if (!tooltipVisible) {
        robloxTitlebarTooltipGui.Show(
            "x" . tooltipX . " y" . tooltipY . " w" . tooltipW . " h" . tooltipH . " NoActivate"
        )
    } else if (tooltipX != robloxTitlebarTooltipX || tooltipY != robloxTitlebarTooltipY
        || textChanged || widthChanged) {
        DllCall("user32\SetWindowPos", "Ptr", tooltipHwnd, "Ptr", 0,
            "Int", tooltipX, "Int", tooltipY, "Int", tooltipW, "Int", tooltipH,
            "UInt", 0x0014) ; NOZORDER | NOACTIVATE
    }
    if (textChanged || widthChanged)
        DllCall("user32\UpdateWindow", "Ptr", tooltipHwnd, "Int")

    robloxTitlebarTooltipX := tooltipX
    robloxTitlebarTooltipY := tooltipY
    robloxTitlebarTooltipWidth := tooltipW
    robloxTitlebarTooltipText := hoverText
}

; Measure the exact label with the font actually assigned to the tooltip control.
; This handles localized labels and avoids relying on hard-coded pixel widths.
Macro_GetRobloxTitlebarTooltipTextWidth(text, ctrl) {
    ctrlHwnd := 0
    try ctrlHwnd := ctrl.Hwnd
    catch
        ctrlHwnd := 0
    if (!ctrlHwnd)
        return Max(16, StrLen(text) * 8)

    hdc := DllCall("user32\GetDC", "Ptr", ctrlHwnd, "Ptr")
    if (!hdc)
        return Max(16, StrLen(text) * 8)

    hFont := 0
    oldFont := 0
    measuredWidth := 0
    try {
        hFont := DllCall("user32\SendMessageW", "Ptr", ctrlHwnd, "UInt", 0x0031,
            "Ptr", 0, "Ptr", 0, "Ptr") ; WM_GETFONT
        if (hFont)
            oldFont := DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", hFont, "Ptr")

        sizeBuffer := Buffer(8, 0)
        ok := DllCall("gdi32\GetTextExtentPoint32W", "Ptr", hdc, "Str", text,
            "Int", StrLen(text), "Ptr", sizeBuffer.Ptr, "Int")
        if (ok)
            measuredWidth := NumGet(sizeBuffer, 0, "Int")
    } catch {
        measuredWidth := 0
    } finally {
        if (oldFont) {
            try DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", oldFont, "Ptr")
        }
        DllCall("user32\ReleaseDC", "Ptr", ctrlHwnd, "Ptr", hdc, "Int")
    }

    return (measuredWidth > 0) ? measuredWidth : Max(16, StrLen(text) * 8)
}

Macro_HideRobloxTitlebarTooltip() {
    global robloxTitlebarTooltipGui
    try {
        if (IsObject(robloxTitlebarTooltipGui) && robloxTitlebarTooltipGui.Hwnd)
            robloxTitlebarTooltipGui.Hide()
    } catch {
    }
}

Macro_DestroyRobloxTitlebarTooltip(*) {
    global robloxTitlebarTooltipGui, robloxTitlebarTooltipCtrl
    global robloxTitlebarTooltipX, robloxTitlebarTooltipY, robloxTitlebarTooltipWidth
    global robloxTitlebarTooltipText
    try {
        if (IsObject(robloxTitlebarTooltipGui))
            robloxTitlebarTooltipGui.Destroy()
    } catch {
    }
    robloxTitlebarTooltipGui := ""
    robloxTitlebarTooltipCtrl := ""
    robloxTitlebarTooltipX := -1
    robloxTitlebarTooltipY := -1
    robloxTitlebarTooltipWidth := 0
    robloxTitlebarTooltipText := ""
}

Macro_IsRobloxTitlebarControlsWindow(hwnd) {
    global robloxTitlebarControlsByHwnd

    try {
        for robloxHwnd, controls in robloxTitlebarControlsByHwnd {
            if (hwnd = controls.gui.Hwnd)
                return true
        }
    } catch {
    }
    return false
}


Macro_OverlayMouseActivate(wParam, lParam, msg, hwnd) {
    ; Keep shortcut help and Roblox titlebar controls non-activating.
    helpGuiHwnd := Macro_GetShortcutHelpHwnd()
    if (helpGuiHwnd && hwnd = helpGuiHwnd)
        return 3 ; MA_NOACTIVATE

    if (Macro_IsRobloxTitlebarControlsWindow(hwnd))
        return 3 ; MA_NOACTIVATE
}

Macro_OverlayHitTest(wParam, lParam, msg, hwnd) {
    if (Macro_IsRobloxTitlebarControlsWindow(hwnd))
        return 1 ; HTCLIENT: receive titlebar button clicks
}

; =====================================================================
; 🛡️ [계정 활성화 재시도 안전장치]
; 일시적인 Windows/Roblox 포커스 지연 때문에 계정이 즉시 건너뛰어지는 것을 방지합니다.
; 최대 retries회까지 실제 활성 창인지 확인하고, 실패 시 waitMs만큼 재시도합니다.
; =====================================================================

; =====================================================================
; 🎯 [2중 교차 검증 엔진 장착] 가짜 타이틀바 창을 걸러내고 진짜 F11 전체화면만 식별하는 루틴
; =====================================================================

Macro_IsTrueFullscreen(hwnd, mLeft, mTop, monitorW, monitorH) {
    if (!WinExist("ahk_id " . hwnd))
        return false

    try {
        style := WinGetStyle("ahk_id " . hwnd)
        if ((style & 0x00C00000) != 0)
            return false

        WinGetPos(&winX, &winY, &winW, &winH, "ahk_id " . hwnd)
        WinGetClientPos(&clientX, &clientY, &clientW, &clientH, "ahk_id " . hwnd)

        return (Abs(winX - mLeft) <= 3)
            && (Abs(winY - mTop) <= 3)
            && (Abs(winW - monitorW) <= 3)
            && (Abs(winH - monitorH) <= 3)
            && (Abs(clientX - mLeft) <= 3)
            && (Abs(clientY - mTop) <= 3)
            && (Abs(clientW - monitorW) <= 3)
            && (Abs(clientH - monitorH) <= 3)
    } catch {
        return false
    }
}

Macro_EnsureRobloxForeground(hwnd, settleMs := 35, retries := 2) {
    global connectionRecoveryEnabled

    if (!connectionRecoveryEnabled || !WinExist("ahk_id " . hwnd))
        return false

    if (WinActive("ahk_id " . hwnd) = hwnd)
        return true

    Loop retries {
        if (!connectionRecoveryEnabled || !WinExist("ahk_id " . hwnd))
            return false
        try {
            DllCall("user32\SetForegroundWindow", "Ptr", hwnd)
            WinActivate("ahk_id " . hwnd)
            if (WinWaitActive("ahk_id " . hwnd, , 0.7) && WinActive("ahk_id " . hwnd) = hwnd) {
                Sleep(settleMs)
                if (WinActive("ahk_id " . hwnd) = hwnd)
                    return true
            }
        } catch {
        }
        if (A_Index < retries)
            Sleep(60)
    }
    return false
}


Macro_ToggleConnectionRecovery() {
    global connectionRecoveryEnabled
    global connectionRecoveryNextDeepScanTick, connectionPassiveScanNextTick
    global fixedPointModalDebugReconnectPending, fixedPointModalDebugReconnectHwnd

    connectionRecoveryEnabled := !connectionRecoveryEnabled

    if (!connectionRecoveryEnabled) {
        ; F5 OFF: stop only connection-recovery timers/state.
        SetTimer(Macro_ConnectionWatchdog, 0)
        SetTimer(Macro_ConnectionLogWatchdog, 0)
        SetTimer(Macro_UpdateHiddenScanCountdown, 0)
        SetTimer(Macro_UpdateF6ModalReconnectCountdown, 0)
        fixedPointModalDebugReconnectPending := false
        fixedPointModalDebugReconnectHwnd := 0
        Macro_ResetConnectionRecoveryState(true)
        Macro_ResetLogAutoRejoinState()
        connectionRecoveryNextDeepScanTick := 0
        connectionPassiveScanNextTick := 0
        isKorean := (Macro_GetWindowsUILanguage() = "ko")
        TrayTip(isKorean ? "꺼짐" : "OFF.",
            isKorean ? "🔄 Roblox 연결 복구" : "🔄 Roblox Connection Recovery", 1)
        return
    }

    ; F5 ON: establish a fresh log baseline so old log contents are not
    ; mistaken for a new 277 event, then start the independent watchdogs.
    Macro_PrimeConnectionLogState()
    connectionRecoveryNextDeepScanTick := A_TickCount + 1000
    connectionPassiveScanNextTick := A_TickCount + CONNECTION_PASSIVE_SCAN_INTERVAL_MS
    SetTimer(Macro_ConnectionLogWatchdog, CONNECTION_LOG_WATCH_INTERVAL_MS)
    SetTimer(Macro_ConnectionWatchdog, CONNECTION_WATCH_INTERVAL_MS)
    isKorean := (Macro_GetWindowsUILanguage() = "ko")
    TrayTip(isKorean ? "켜짐" : "ON.",
        isKorean ? "🔄 Roblox 연결 복구" : "🔄 Roblox Connection Recovery", 1)

    ; One immediate non-blocking inspection.
    SetTimer((*) => Macro_ConnectionWatchdog(true), -50)
}

Macro_ConnectionLogWatchdog(*) {
    global connectionRecoveryEnabled, disconnectHiddenScanLastMiss, disconnectHiddenScanPending
    global disconnectGracePending, disconnectGraceSignalPath, disconnectGraceCode
    global disconnectHiddenScanCountdownRunning
    global CONNECTION_LOG_AUTO_REJOIN_ENABLE, CONNECTION_MODAL_AUTO_RECOVERY_ENABLE
    global AUTO_HIDDEN_SCAN_DELAY_SEC, disconnectLogDiagFocusState
    global disconnectLogDiagFile, disconnectLogDiagCode

    if (!connectionRecoveryEnabled)
        return

    ; Prevent timer re-entry if a previous pass is still in progress.
    static running := false
    if (running)
        return

    running := true
    try {
        ; Recheck game identity on the same periodic log pass. Roblox can keep
        ; the PID/HWND while joining a different experience, so log changes—not
        ; new processes—must trigger a name refresh.
        Macro_QueueGameIdentityScan(100)
        freshSignal := Macro_ScanRobloxLogsForDisconnect()
        if (freshSignal) {
            ; Prevent the same current DISCONNECTED state from being reissued
            ; by the identity-state fallback on the next 30s log pass.
            Macro_MarkDisconnectedIdentitySignalsHandled()
        } else {
            ; The game selector parses the whole session log, while the
            ; incremental scanner only examines newly written text. If that
            ; scanner previously consumed an unrecognized line (or F5 was
            ; enabled after the disconnect), hand off a still-current
            ; DISCONNECTED identity once instead of silently doing nothing.
            freshSignal := Macro_FindUnconsumedDisconnectedIdentitySignal()
        }
        if (!freshSignal)
            return

        ; One in-flight incident owns the grace period. Additional log signals
        ; during that short window are consumed by the scanner but do not spawn
        ; duplicate alerts or reconnect transactions.
        if (disconnectGracePending) {
            ; The scanner has consumed any newly written bytes, but the current
            ; grace transaction keeps ownership of its original log/code/Place ID.
            disconnectLogDiagFile := disconnectGraceSignalPath
            disconnectLogDiagCode := disconnectGraceCode
            return
        }

        ; A visible reconnect-complete alert belongs to the previous incident.
        ; Reuse that same GUI immediately for this new disconnect signal instead
        ; of leaving the old "reconnect complete" message on screen during grace.
        ; If the game-managed restart succeeds, the exact prior completion view is
        ; restored by Macro_DisconnectGraceStep; if grace expires, this becomes the
        ; persistent disconnect alert for the new incident.
        Macro_BeginDisconnectIncidentWithImmediateAlertHandoff(Macro_GetDisconnectLogReasonText())
        disconnectHiddenScanLastMiss := false
        disconnectHiddenScanPending := false
        disconnectHiddenScanCountdownRunning := false
        SetTimer(Macro_UpdateHiddenScanCountdown, 0)

        ; No alert, macro shutoff, screen sampling, or reconnect attempt until
        ; the log/PID watcher has given the game-managed restart time to succeed.
        Macro_BeginDisconnectGracePeriod()
        return
    } finally {
        running := false
    }
}


; Start the new incident and, if the existing reconnect-complete popup is
; currently visible, switch that same GUI to the disconnect-alert state at once.
; The completion snapshot is kept only so a confirmed game-managed restart can
; restore the old completed view without creating/destroying any GUI.
Macro_BeginDisconnectIncidentWithImmediateAlertHandoff(reasonText := "") {
    global disconnectAlertGui, disconnectAlertActive, disconnectAlertStage
    global disconnectAlertTitle, disconnectAlertBody, disconnectAlertPrimaryButton, disconnectAlertDismissButton
    global disconnectAlertDetectedHwnd, disconnectAlertReason, disconnectAlertOriginalForeground
    global disconnectAlertDetectionSource, disconnectAlertLastRecoveryAttempts, disconnectAlertLastSuccessTime
    global disconnectDiagTargetHwnd, disconnectDiagTargetPid, disconnectDiagScanTime
    global disconnectIncidentStartTick, disconnectIncidentDetectedTime, disconnectIncidentReasonText
    global disconnectIncidentCode, disconnectIncidentLogPattern, disconnectIncidentTimeline
    global disconnectGracePreviousCompletedAlertState

    snapshot := 0
    guiHwnd := 0
    isVisible := false
    try {
        if (disconnectAlertActive && disconnectAlertStage = "Reconnected"
            && IsObject(disconnectAlertGui) && disconnectAlertGui.Hwnd) {
            guiHwnd := disconnectAlertGui.Hwnd
            isVisible := !!DllCall("user32\IsWindowVisible", "Ptr", guiHwnd, "Int")
            if (isVisible) {
                snapshot := Map(
                    "guiHwnd", guiHwnd,
                    "titleText", disconnectAlertTitle.Text,
                    "bodyText", disconnectAlertBody.Text,
                    "primaryText", disconnectAlertPrimaryButton.Text,
                    "primaryEnabled", disconnectAlertPrimaryButton.Enabled,
                    "dismissText", disconnectAlertDismissButton.Text,
                    "stage", disconnectAlertStage,
                    "alertReason", disconnectAlertReason,
                    "detectedHwnd", disconnectAlertDetectedHwnd,
                    "originalForeground", disconnectAlertOriginalForeground,
                    "detectionSource", disconnectAlertDetectionSource,
                    "lastRecoveryAttempts", disconnectAlertLastRecoveryAttempts,
                    "lastSuccessTime", disconnectAlertLastSuccessTime,
                    "diagTargetHwnd", disconnectDiagTargetHwnd,
                    "diagTargetPid", disconnectDiagTargetPid,
                    "diagScanTime", disconnectDiagScanTime,
                    "incidentStartTick", disconnectIncidentStartTick,
                    "incidentDetectedTime", disconnectIncidentDetectedTime,
                    "incidentReasonText", disconnectIncidentReasonText,
                    "incidentCode", disconnectIncidentCode,
                    "incidentLogPattern", disconnectIncidentLogPattern,
                    "incidentTimeline", disconnectIncidentTimeline
                )
            }
        }
    } catch {
        snapshot := 0
    }

    ; Capture the previous completion view before BeginDisconnectIncident resets
    ; the timeline for the new incident.
    Macro_BeginDisconnectIncident(reasonText)

    if (!IsObject(snapshot))
        return false

    shown := Macro_ShowDisconnectAlertSafely(reasonText, 0, true)
    visibleAfter := false
    try visibleAfter := IsObject(disconnectAlertGui) && disconnectAlertGui.Hwnd
        && !!DllCall("user32\IsWindowVisible", "Ptr", disconnectAlertGui.Hwnd, "Int")

    if (shown && disconnectAlertActive && disconnectAlertStage = "Signal"
        && IsObject(disconnectAlertGui) && disconnectAlertGui.Hwnd = guiHwnd && visibleAfter) {
        disconnectGracePreviousCompletedAlertState := snapshot
        Macro_DisconnectGraceDebug("COMPLETION_ALERT_HANDOFF sameGui=" . guiHwnd . " result=disconnect_signal")
        return true
    }

    disconnectGracePreviousCompletedAlertState := Map()
    Macro_DisconnectGraceDebug("COMPLETION_ALERT_HANDOFF sameGui=" . guiHwnd . " result=failed_to_switch")
    return false
}

; Restore the prior completed message only when the same GUI is still active in
; the untouched Signal stage. If the user clicked/dismissed it during grace, do
; not override that interaction or reopen a hidden window.
Macro_RestoreCompletedAlertAfterProvisionalDisconnect() {
    global disconnectGracePreviousCompletedAlertState
    global disconnectAlertGui, disconnectAlertActive, disconnectAlertStage
    global disconnectAlertTitle, disconnectAlertBody, disconnectAlertPrimaryButton, disconnectAlertDismissButton
    global disconnectAlertDetectedHwnd, disconnectAlertReason, disconnectAlertOriginalForeground
    global disconnectAlertDetectionSource, disconnectAlertLastRecoveryAttempts, disconnectAlertLastSuccessTime
    global disconnectDiagTargetHwnd, disconnectDiagTargetPid, disconnectDiagScanTime
    global disconnectIncidentStartTick, disconnectIncidentDetectedTime, disconnectIncidentReasonText
    global disconnectIncidentCode, disconnectIncidentLogPattern, disconnectIncidentTimeline

    if (!IsObject(disconnectGracePreviousCompletedAlertState)
        || disconnectGracePreviousCompletedAlertState.Count = 0)
        return false

    snapshot := disconnectGracePreviousCompletedAlertState
    disconnectGracePreviousCompletedAlertState := Map()

    try {
        if (!disconnectAlertActive || disconnectAlertStage != "Signal"
            || !IsObject(disconnectAlertGui) || !disconnectAlertGui.Hwnd
            || disconnectAlertGui.Hwnd != snapshot["guiHwnd"])
            return false

        isVisible := !!DllCall("user32\IsWindowVisible", "Ptr", disconnectAlertGui.Hwnd, "Int")

        disconnectAlertStage := snapshot["stage"]
        disconnectAlertReason := snapshot["alertReason"]
        disconnectAlertDetectedHwnd := snapshot["detectedHwnd"]
        disconnectAlertOriginalForeground := snapshot["originalForeground"]
        disconnectAlertDetectionSource := snapshot["detectionSource"]
        disconnectAlertLastRecoveryAttempts := snapshot["lastRecoveryAttempts"]
        disconnectAlertLastSuccessTime := snapshot["lastSuccessTime"]
        disconnectDiagTargetHwnd := snapshot["diagTargetHwnd"]
        disconnectDiagTargetPid := snapshot["diagTargetPid"]
        disconnectDiagScanTime := snapshot["diagScanTime"]
        disconnectIncidentStartTick := snapshot["incidentStartTick"]
        disconnectIncidentDetectedTime := snapshot["incidentDetectedTime"]
        disconnectIncidentReasonText := snapshot["incidentReasonText"]
        disconnectIncidentCode := snapshot["incidentCode"]
        disconnectIncidentLogPattern := snapshot["incidentLogPattern"]
        disconnectIncidentTimeline := snapshot["incidentTimeline"]

        disconnectAlertTitle.Text := snapshot["titleText"]
        disconnectAlertBody.Text := snapshot["bodyText"]
        disconnectAlertPrimaryButton.Text := snapshot["primaryText"]
        disconnectAlertPrimaryButton.Enabled := snapshot["primaryEnabled"]
        disconnectAlertDismissButton.Text := snapshot["dismissText"]

        if (isVisible)
            Macro_ResizeDisconnectAlert()
        Macro_DisconnectGraceDebug("COMPLETION_ALERT_RESTORED sameGui=" . disconnectAlertGui.Hwnd
            . " reason=game_managed_restart_recovered")
        return true
    } catch {
        Macro_DisconnectGraceDebug("COMPLETION_ALERT_RESTORE_FAILED")
        return false
    }
}

Macro_BeginDisconnectGracePeriod() {
    global disconnectGracePending, disconnectGraceStartTick, disconnectGraceDeadlineTick, disconnectGraceMaxDeadlineTick
    global disconnectGracePlaceId, disconnectGraceUserId, disconnectGraceOriginalPid, disconnectGraceOriginalPids
    global disconnectGraceTargetHwnd, disconnectGraceTargetPid, disconnectGraceSignalPath, disconnectGraceCode
    global disconnectLogDiagFile, disconnectLogDiagCode
    global CONNECTION_DISCONNECT_RESTART_GRACE_MS, CONNECTION_DISCONNECT_RESTART_MAX_GRACE_MS
    global CONNECTION_DISCONNECT_RESTART_POLL_MS

    if (disconnectGracePending)
        return true

    signalPath := disconnectLogDiagFile
    target := 0
    try target := Macro_FindLogDisconnectTarget()
    catch
        target := 0

    placeId := ""
    targetHwnd := 0
    targetPid := 0
    if (target) {
        try placeId := Trim(target["placeId"] . "")
        try targetHwnd := target["hwnd"]
        try targetPid := target["pid"]
    }
    if (placeId = "")
        placeId := Macro_GetDisconnectSignalPlaceId(signalPath)
    userId := Macro_GetDisconnectSignalUserId(signalPath)

    ; First use the identity cache for this exact log path. Restart Manager only
    ; reports processes that currently hold the file; after a game-managed exit,
    ; the old PID is gone and that query commonly returns an empty list.
    originalPid := 0
    if (signalPath != "") {
        try originalPid := Macro_GetCachedPidForLogPath(signalPath)
        catch
            originalPid := 0
    }
    if (!originalPid && signalPath != "") {
        try {
            ownerPids := Macro_GetPidsUsingRobloxLog(signalPath)
            for _, pid in ownerPids {
                if (pid) {
                    originalPid := pid
                    break
                }
            }
        } catch {
        }
    }
    if (!originalPid)
        originalPid := targetPid

    baselinePids := Macro_SnapshotRobloxPids()
    if (originalPid)
        baselinePids[originalPid] := true

    disconnectGracePlaceId := placeId
    disconnectGraceUserId := userId
    disconnectGraceOriginalPid := originalPid
    disconnectGraceOriginalPids := baselinePids
    disconnectGraceTargetHwnd := targetHwnd
    disconnectGraceTargetPid := targetPid ? targetPid : originalPid
    disconnectGraceSignalPath := signalPath
    disconnectGraceCode := disconnectLogDiagCode
    disconnectGraceStartTick := A_TickCount
    disconnectGraceDeadlineTick := disconnectGraceStartTick + CONNECTION_DISCONNECT_RESTART_GRACE_MS
    disconnectGraceMaxDeadlineTick := disconnectGraceStartTick + CONNECTION_DISCONNECT_RESTART_MAX_GRACE_MS
    disconnectGracePending := true
    Macro_DisconnectGraceDebug("BEGIN placeId=" . placeId . " userId=" . userId . " oldPid=" . originalPid
        . " targetPid=" . disconnectGraceTargetPid . " code=" . disconnectGraceCode
        . " signal=" . signalPath)

    ; Keep the recurring poll timer and use a different callback for the one-shot kickoff.
    ; Calling SetTimer() twice with the same callback would overwrite the recurring period
    ; with -50 (one-shot), so the grace deadline would never be checked again.
    SetTimer(Macro_DisconnectGraceStep, 0)
    SetTimer(Macro_DisconnectGraceStep, CONNECTION_DISCONNECT_RESTART_POLL_MS)
    SetTimer(Macro_DisconnectGraceStepInitial, -50)
    return true
}

Macro_DisconnectGraceStepInitial(*) {
    Macro_DisconnectGraceStep()
}

Macro_GetCachedPidForLogPath(signalPath) {
    global gameIdentityByPid, gameIdentityLogState

    signalPath := Trim(signalPath . "")
    if (signalPath = "")
        return 0

    fallbackPid := 0
    ; The DISCONNECTED identity is the strongest exact-path match. Keep this
    ; historical PID even when its HWND no longer exists; it is still useful as
    ; the original process ID during a rapid close/relaunch cycle.
    for pid, identity in gameIdentityByPid {
        try {
            if (!IsObject(identity) || !identity.HasOwnProp("logPath") || identity.logPath != signalPath)
                continue
            if (identity.HasOwnProp("presence") && identity.presence = "DISCONNECTED")
                return pid
            if (!fallbackPid)
                fallbackPid := pid
        } catch {
        }
    }

    ; If a live HWND was cached for this log, resolve it directly to its current PID.
    if (gameIdentityLogState.Has(signalPath)) {
        try {
            state := gameIdentityLogState[signalPath]
            hwnd := state.HasOwnProp("hwnd") ? state.hwnd : 0
            if (hwnd && WinExist("ahk_id " . hwnd)
                && WinGetProcessName("ahk_id " . hwnd) = "RobloxPlayerBeta.exe")
                return WinGetPID("ahk_id " . hwnd)
        } catch {
        }
    }
    return fallbackPid
}

Macro_GetDisconnectSignalPlaceId(signalPath := "") {
    global disconnectLogDiagFile, gameIdentityLogState, gameIdentityByPid

    if (signalPath = "")
        signalPath := disconnectLogDiagFile

    ; First use cached parsed identity, preserving the last game Place ID even
    ; when the parser's current presence has already changed to DISCONNECTED.
    if (signalPath != "") {
        if (gameIdentityLogState.Has(signalPath)) {
            try {
                state := gameIdentityLogState[signalPath]
                if (state.HasOwnProp("lastGamePlaceId") && state.lastGamePlaceId != "")
                    return Trim(state.lastGamePlaceId . "")
                if (state.HasOwnProp("placeId") && state.placeId != "")
                    return Trim(state.placeId . "")
            } catch {
            }
        }
        for pid, identity in gameIdentityByPid {
            try {
                if (!IsObject(identity) || !identity.HasOwnProp("logPath") || identity.logPath != signalPath)
                    continue
                if (identity.HasOwnProp("lastGamePlaceId") && identity.lastGamePlaceId != "")
                    return Trim(identity.lastGamePlaceId . "")
                if (identity.HasOwnProp("placeId") && identity.placeId != "")
                    return Trim(identity.placeId . "")
            } catch {
            }
        }
    }

    ; The incremental disconnect scanner may have seen a regular .log file
    ; which the game-identity scanner does not cache. Parse that exact file once
    ; to recover the session's last Place ID; this uses no pixels or window text.
    if (signalPath != "" && FileExist(signalPath)) {
        f := ""
        try {
            f := FileOpen(signalPath, "r", "UTF-8")
            if (f) {
                contents := f.Read()
                f.Close()
                f := ""
                if (contents != "") {
                    parsed := Macro_ParseRobloxGameSessionLog(contents)
                    if (parsed.lastGamePlaceId != "")
                        return Trim(parsed.lastGamePlaceId . "")
                    if (parsed.placeId != "")
                        return Trim(parsed.placeId . "")
                }
            }
        } catch {
            try {
                if (IsObject(f))
                    f.Close()
            } catch {
            }
        }
    }
    return ""
}

Macro_GetDisconnectSignalUserId(signalPath := "") {
    global disconnectLogDiagFile, gameIdentityLogState, gameIdentityByPid

    if (signalPath = "")
        signalPath := disconnectLogDiagFile

    if (signalPath != "") {
        if (gameIdentityLogState.Has(signalPath)) {
            try {
                state := gameIdentityLogState[signalPath]
                if (state.HasOwnProp("userId") && state.userId != "")
                    return Trim(state.userId . "")
            } catch {
            }
        }
        for pid, identity in gameIdentityByPid {
            try {
                if (!IsObject(identity) || !identity.HasOwnProp("logPath") || identity.logPath != signalPath)
                    continue
                if (identity.HasOwnProp("userId") && identity.userId != "")
                    return Trim(identity.userId . "")
            } catch {
            }
        }
    }

    if (signalPath != "" && FileExist(signalPath)) {
        f := ""
        try {
            f := FileOpen(signalPath, "r", "UTF-8")
            if (f) {
                contents := f.Read()
                f.Close()
                f := ""
                if (contents != "") {
                    parsed := Macro_ParseRobloxGameSessionLog(contents)
                    if (parsed.userId != "")
                        return Trim(parsed.userId . "")
                }
            }
        } catch {
            try {
                if (IsObject(f))
                    f.Close()
            } catch {
            }
        }
    }
    return ""
}

Macro_LogTextMatchesUserId(text, expectedUserId := "") {
    expectedUserId := Trim(expectedUserId . "")
    if (expectedUserId = "")
        return true
    parsed := Macro_ParseRobloxGameSessionLog(text)
    actualUserId := Trim(parsed.userId . "")
    ; Some Roblox builds don't repeat the local account ID in every log. Enforce
    ; the match when it is present, but don't reject solely for a missing field.
    return (actualUserId = "" || actualUserId = expectedUserId)
}

Macro_FindHealthyAutoRestartPid(placeId, originalPid := 0, userId := "") {
    global disconnectGraceOriginalPids

    if (placeId = "")
        return 0

    currentPids := Macro_SnapshotRobloxPids()
    for pid, _ in currentPids {
        isOriginalPid := (originalPid && pid = originalPid)

        ; An already-running other account must not satisfy this incident's recovery.
        ; In-place recovery is allowed only for the PID tied to the detected log.
        if (!isOriginalPid && IsObject(disconnectGraceOriginalPids)
            && disconnectGraceOriginalPids.Has(pid))
            continue

        try {
            if (!Macro_LogAutoRejoinCheckJoin(pid, placeId, userId))
                continue

            ; A replacement PID is only proof of recovery when it can be tied to the
            ; same account explicitly. Missing UserId is not enough in multi-account use.
            if (!isOriginalPid && !Macro_LogAutoRejoinHasExplicitUserId(pid, userId))
                continue

            return pid
        } catch {
        }
    }
    return 0
}

Macro_FindAutoRestartJoinInProgressPid(placeId, originalPid := 0, userId := "") {
    global disconnectGraceOriginalPids

    if (placeId = "")
        return 0

    currentPids := Macro_SnapshotRobloxPids()
    localAppData := EnvGet("LOCALAPPDATA")
    if (!localAppData)
        return 0
    logDir := localAppData . "\\Roblox\\logs"
    if !DirExist(logDir)
        return 0

    for pid, _ in currentPids {
        isOriginalPid := (originalPid && pid = originalPid)
        if (!isOriginalPid && IsObject(disconnectGraceOriginalPids)
            && disconnectGraceOriginalPids.Has(pid))
            continue
        if (!isOriginalPid && !Macro_LogAutoRejoinHasExplicitUserId(pid, userId))
            continue

        for _, path in Macro_GetRecentRobloxLogPaths(logDir, 12) {
            if (!Macro_LogBelongsToPid(path, pid))
                continue
            try size := FileGetSize(path)
            catch
                size := 0
            if (!size)
                continue
            tail := Macro_ReadRobloxLogTail(path, size, 524288, &readOk, &bytesRead)
            if (!readOk || tail = "")
                continue
            state := Macro_GetPlaceJoinStateFromText(tail, placeId)
            if (state = "JOINING" && Macro_LogTextMatchesUserId(tail, userId))
                return pid
        }
    }
    return 0
}

Macro_LogAutoRejoinHasExplicitUserId(pid, expectedUserId) {
    global gameIdentityByPid

    expectedUserId := Trim(expectedUserId . "")
    if (!pid || expectedUserId = "")
        return false

    ; Prefer the identity parser's explicit account association for this PID.
    if (gameIdentityByPid.Has(pid)) {
        try {
            identity := gameIdentityByPid[pid]
            identityUserId := (IsObject(identity) && identity.HasOwnProp("userId"))
                ? Trim(identity.userId . "") : ""
            if (identityUserId != "")
                return (identityUserId = expectedUserId)
        } catch {
        }
    }

    localAppData := EnvGet("LOCALAPPDATA")
    if (!localAppData)
        return false
    logDir := localAppData . "\\Roblox\\logs"
    if !DirExist(logDir)
        return false

    try {
        for _, path in Macro_GetRecentRobloxLogPaths(logDir, 12) {
            if (!Macro_LogBelongsToPid(path, pid))
                continue
            try size := FileGetSize(path)
            catch
                size := 0
            if (!size)
                continue
            tail := Macro_ReadRobloxLogTail(path, size, 524288, &readOk, &bytesRead)
            if (!readOk || tail = "")
                continue
            parsed := Macro_ParseRobloxGameSessionLog(tail)
            actualUserId := Trim(parsed.userId . "")
            if (actualUserId != "")
                return (actualUserId = expectedUserId)
        }
    } catch {
    }
    return false
}

Macro_DisconnectGraceStep(*) {
    global connectionRecoveryEnabled, disconnectGracePending, disconnectGraceDeadlineTick, disconnectGraceMaxDeadlineTick
    global disconnectGracePlaceId, disconnectGraceUserId, disconnectGraceOriginalPid
    global disconnectGraceTargetHwnd, disconnectGraceTargetPid, disconnectGraceSignalPath, disconnectGraceCode
    global disconnectGraceOriginalPids
    global disconnectHiddenScanPending, disconnectHiddenScanCountdownRunning, disconnectHiddenScanLastMiss
    global disconnectLogDiagSignal, disconnectLogDiagFreshSignal, disconnectLogSignalFiles
    global disconnectLogSignalVersions, disconnectLogSignalSequence
    global CONNECTION_LOG_AUTO_REJOIN_ENABLE, CONNECTION_MODAL_AUTO_RECOVERY_ENABLE
    global disconnectAlertGui, disconnectGracePreviousCompletedAlertState

    if (!disconnectGracePending)
        return
    if (!connectionRecoveryEnabled) {
        Macro_ResetDisconnectGraceState()
        return
    }

    recoveredPid := 0
    try recoveredPid := Macro_FindHealthyAutoRestartPid(disconnectGracePlaceId,
        disconnectGraceOriginalPid, disconnectGraceUserId)
    catch
        recoveredPid := 0

    if (recoveredPid) {
        Macro_DisconnectGraceDebug("RECOVERED pid=" . recoveredPid . " placeId=" . disconnectGracePlaceId
            . " userId=" . disconnectGraceUserId)
        ; Game-managed restart completed and the same game was actually joined.
        ; Consume the provisional incident silently: no popup, no reconnect click,
        ; and no synthetic macro shutdown for this transient restart.
        Macro_RecordDisconnectProcessStep("automatic_restart_recovered")
        disconnectGracePending := false
        SetTimer(Macro_DisconnectGraceStep, 0)
        disconnectHiddenScanPending := false
        disconnectHiddenScanCountdownRunning := false
        disconnectHiddenScanLastMiss := false
        SetTimer(Macro_UpdateHiddenScanCountdown, 0)
        disconnectLogDiagSignal := false
        disconnectLogDiagFreshSignal := false
        disconnectLogSignalFiles := []
        disconnectLogSignalVersions.Clear()
        disconnectLogSignalSequence := 0
        Macro_ResetDisconnectGraceState(false)
        Macro_RestoreCompletedAlertAfterProvisionalDisconnect()
        return
    }

    if (A_TickCount < disconnectGraceDeadlineTick)
        return

    ; If a replacement process has logged an attempt to join this same Place ID
    ; but has not yet emitted a success marker, allow that in-progress restart to
    ; finish (up to the hard maximum) instead of launching a duplicate client.
    if (A_TickCount < disconnectGraceMaxDeadlineTick) {
        joiningPid := 0
        try joiningPid := Macro_FindAutoRestartJoinInProgressPid(disconnectGracePlaceId,
            disconnectGraceOriginalPid, disconnectGraceUserId)
        catch
            joiningPid := 0
        if (joiningPid) {
            Macro_DisconnectGraceDebug("JOINING pid=" . joiningPid . " placeId=" . disconnectGracePlaceId . " extend=5s")
            disconnectGraceDeadlineTick := Min(disconnectGraceMaxDeadlineTick, A_TickCount + 5000)
            return
        }
    }

    ; The grace window elapsed without a same-Place-ID successful join. Only now
    ; classify the log event as a real disconnect and expose/act on it.
    Macro_DisconnectGraceDebug("EXPIRED placeId=" . disconnectGracePlaceId
        . " oldPid=" . disconnectGraceOriginalPid . " signal=" . disconnectGraceSignalPath)
    savedPlaceId := disconnectGracePlaceId
    savedOriginalPid := disconnectGraceOriginalPid
    savedTargetHwnd := disconnectGraceTargetHwnd
    savedTargetPid := disconnectGraceTargetPid
    savedSignalPath := disconnectGraceSignalPath
    savedCode := disconnectGraceCode
    savedOriginalPids := disconnectGraceOriginalPids
    disconnectGracePending := false
    SetTimer(Macro_DisconnectGraceStep, 0)

    disconnectHiddenScanPending := false
    disconnectHiddenScanCountdownRunning := false
    disconnectHiddenScanLastMiss := false
    SetTimer(Macro_UpdateHiddenScanCountdown, 0)
    MouseMacro_ForceOffForDisconnect("disconnect confirmed after log grace period")
    ; Grace expired: this is now a real disconnect, so keep the switched alert
    ; and discard any snapshot that would restore the prior completion message.
    disconnectGracePreviousCompletedAlertState := Map()
    alertCallResult := Macro_ShowDisconnectAlertSafely(Macro_GetDisconnectLogReasonText(), 0, true)
    alertVisible := false
    try alertVisible := IsObject(disconnectAlertGui) && disconnectAlertGui.Hwnd
        && !!DllCall("user32\IsWindowVisible", "Ptr", disconnectAlertGui.Hwnd, "Int")
    Macro_DisconnectGraceDebug("ALERT_RESULT call=" . alertCallResult . " visible=" . alertVisible)
    Macro_ShowDisconnectTrayProgress(Macro_GetDisconnectLogReasonText(), Macro_GetDisconnectCodeTitle())

    if (CONNECTION_LOG_AUTO_REJOIN_ENABLE) {
        ; These values also serve as a fallback when the original process has
        ; already exited and Restart Manager can no longer map the old log.
        disconnectGracePlaceId := savedPlaceId
        disconnectGraceOriginalPid := savedOriginalPid
        disconnectGraceTargetHwnd := savedTargetHwnd
        disconnectGraceTargetPid := savedTargetPid
        disconnectGraceSignalPath := savedSignalPath
        disconnectGraceCode := savedCode
        disconnectGraceOriginalPids := savedOriginalPids
        Macro_StartLogAutoRejoin()
    } else if (CONNECTION_MODAL_AUTO_RECOVERY_ENABLE) {
        ; Legacy/manual configuration only. Default configuration is log/PID-only.
        disconnectHiddenScanPending := true
        Macro_StartHiddenScanCountdown()
        Macro_ConnectionWatchdog(true)
    }
}

Macro_ResetDisconnectGraceState(stopTimer := true) {
    global disconnectGracePending, disconnectGraceStartTick, disconnectGraceDeadlineTick, disconnectGraceMaxDeadlineTick
    global disconnectGracePlaceId, disconnectGraceUserId, disconnectGraceOriginalPid, disconnectGraceOriginalPids
    global disconnectGraceTargetHwnd, disconnectGraceTargetPid, disconnectGraceSignalPath, disconnectGraceCode

    if (stopTimer)
        Macro_RestoreCompletedAlertAfterProvisionalDisconnect()
    if (stopTimer)
        SetTimer(Macro_DisconnectGraceStep, 0)
    disconnectGracePending := false
    disconnectGraceStartTick := 0
    disconnectGraceDeadlineTick := 0
    disconnectGraceMaxDeadlineTick := 0
    disconnectGracePlaceId := ""
    disconnectGraceUserId := ""
    disconnectGraceOriginalPid := 0
    disconnectGraceOriginalPids := Map()
    disconnectGraceTargetHwnd := 0
    disconnectGraceTargetPid := 0
    disconnectGraceSignalPath := ""
    disconnectGraceCode := ""
}

Macro_DisconnectGraceDebug(messageText) {
    logPath := A_Temp . "\GameTitlebarFix_DisconnectGrace.log"
    Macro_CleanupDisconnectGraceLogs(logPath, false)
    stamp := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
    try FileAppend(stamp . " | " . messageText . "`r`n", logPath, "UTF-8")
}

; Maintain only this script's diagnostic log:
; - Rotate the active log at 2 MiB.
; - Delete rotated logs older than 7 days.
; - Keep at most 3 rotated logs.
; Roblox source logs and game/account data are never touched.
Macro_CleanupDisconnectGraceLogs(currentLogPath := "", force := false) {
    static lastCleanupTick := 0
    nowTick := A_TickCount
    maxBytes := 2 * 1024 * 1024
    archiveMask := A_Temp . "\GameTitlebarFix_DisconnectGrace_*.log"
    doRetention := force || !lastCleanupTick || (nowTick - lastCleanupTick >= 6 * 60 * 60 * 1000)

    if (currentLogPath != "" && FileExist(currentLogPath)) {
        currentSize := 0
        try currentSize := FileGetSize(currentLogPath)
        catch
            currentSize := 0
        if (currentSize >= maxBytes) {
            archivePath := A_Temp . "\GameTitlebarFix_DisconnectGrace_"
                . FormatTime(A_Now, "yyyyMMdd_HHmmss") . "_" . nowTick . ".log"
            try {
                FileMove(currentLogPath, archivePath, 1)
                doRetention := true
            } catch {
                ; Preserve the active log if rotation fails.
            }
        }
    }

    if (!doRetention)
        return
    lastCleanupTick := nowTick
    cutoff := DateAdd(A_Now, -7, "Days")
    archives := []
    try {
        Loop Files, archiveMask, "F" {
            path := A_LoopFileFullPath
            modified := A_LoopFileTimeModified
            if (modified != "" && modified < cutoff) {
                try FileDelete(path)
                continue
            }
            archives.Push({path: path, modified: modified})
        }
    } catch {
        return
    }

    while (archives.Length > 3) {
        oldestIndex := 1
        for index, item in archives {
            if (item.modified < archives[oldestIndex].modified)
                oldestIndex := index
        }
        try FileDelete(archives[oldestIndex].path)
        archives.RemoveAt(oldestIndex)
    }
}

Macro_CleanupDisconnectGraceLogsTimer(*) {
    Macro_CleanupDisconnectGraceLogs("", true)
}

Macro_MarkDisconnectedIdentitySignalsHandled() {
    global gameIdentityByPid, disconnectIdentitySignalHandledByPid
    global disconnectLogSignalFiles, disconnectLogDiagFile

    signalPaths := Map()
    if (disconnectLogDiagFile != "")
        signalPaths[disconnectLogDiagFile] := true
    for _, path in disconnectLogSignalFiles {
        if (path != "")
            signalPaths[path] := true
    }

    for pid, identity in gameIdentityByPid {
        try {
            if (!IsObject(identity))
                continue
            identityPath := identity.HasOwnProp("logPath") ? identity.logPath : ""
            ; The exact log path is enough to associate the event even if the
            ; identity cache has not yet refreshed its presence field.
            if (identityPath != "" && signalPaths.Has(identityPath))
                disconnectIdentitySignalHandledByPid[pid] := true
        } catch {
        }
    }
}

Macro_FindUnconsumedDisconnectedIdentitySignal() {
    global gameIdentityByPid, gameIdentityLogState
    global disconnectIdentitySignalHandledByPid
    global disconnectLogDiagSignal, disconnectLogDiagFreshSignal
    global disconnectLogDiagFile, disconnectLogDiagPattern, disconnectLogDiagCode
    global disconnectLogDiagScanTime, disconnectLogDiagLastSignalTime
    global disconnectLogDiagFilesScanned, disconnectLogDiagFilesChanged
    global disconnectLogDiagFilesRead, disconnectLogDiagReadErrors
    global disconnectLogDiagBytesRead, disconnectLogDiagNewFiles
    global disconnectLogDiagOverlapChars, disconnectLogDiagMappingState
    global disconnectLogDiagMappedPids, disconnectLogDiagMappedHwnds
    global disconnectLogDiagFocusState, disconnectLogDiagFocusHwnd
    global disconnectLogDiagFocusPid, disconnectLogDiagFocusTime
    global disconnectLogSignalFiles, disconnectLogSignalVersions, disconnectLogSignalSequence

    currentDisconnected := Map()
    for pid, identity in gameIdentityByPid {
        try {
            if (!IsObject(identity) || !identity.HasOwnProp("presence")
                || identity.presence != "DISCONNECTED")
                continue
            path := identity.HasOwnProp("logPath") ? identity.logPath : ""
            if (path != "" && Macro_IsRobloxVoluntaryExitLog(path)) {
                identity.presence := "ONLINE"
                identity.state := "ONLINE"
                identity.placeId := ""
                identity.universeId := ""
                identity.voluntaryExit := true
                identity.name := (identity.HasOwnProp("accountName") && identity.accountName != "")
                    ? identity.accountName : "Online"
                gameIdentityByPid[pid] := identity
                if (gameIdentityLogState.Has(path)) {
                    logState := gameIdentityLogState[path]
                    logState.presence := "ONLINE"
                    logState.placeId := ""
                    logState.universeId := ""
                    logState.voluntaryExit := true
                }
                continue
            }
            hwnd := identity.HasOwnProp("hwnd") ? identity.hwnd : 0
            if (!hwnd || !WinExist("ahk_id " . hwnd))
                continue
            if (WinGetProcessName("ahk_id " . hwnd) != "RobloxPlayerBeta.exe"
                || WinGetPID("ahk_id " . hwnd) != pid)
                continue
            currentDisconnected[pid] := identity
        } catch {
        }
    }

    ; Clear one-shot latches only when that PID is no longer a live disconnected
    ; client. Collect keys first so Map enumeration is never modified in place.
    stalePids := []
    for pid, _ in disconnectIdentitySignalHandledByPid {
        if (!currentDisconnected.Has(pid))
            stalePids.Push(pid)
    }
    for _, stalePid in stalePids
        disconnectIdentitySignalHandledByPid.Delete(stalePid)

    for pid, identity in currentDisconnected {
        if (disconnectIdentitySignalHandledByPid.Has(pid))
            continue

        hwnd := identity.hwnd
        path := identity.HasOwnProp("logPath") ? identity.logPath : ""
        matchedPattern := ""
        bytesRead := 0
        readOk := false
        if (path != "" && FileExist(path)) {
            size := 0
            try size := FileGetSize(path)
            catch
                size := 0
            if (size > 0) {
                tail := Macro_ReadRobloxLogTail(path, size, 262144, &readOk, &bytesRead)
                if (readOk)
                    matchedPattern := Macro_FindLastDisconnectSignalPattern(tail)
            }
        }
        if (matchedPattern = "")
            matchedPattern := "Current game-identity state: DISCONNECTED"

        disconnectIdentitySignalHandledByPid[pid] := true
        disconnectLogDiagSignal := true
        disconnectLogDiagFreshSignal := true
        disconnectLogDiagFile := path
        disconnectLogDiagPattern := matchedPattern
        disconnectLogDiagCode := Macro_GetDisconnectCodeFromPattern(matchedPattern)
        disconnectLogDiagScanTime := Macro_Format12HourCurrentTime(A_Now)
        disconnectLogDiagLastSignalTime := disconnectLogDiagScanTime
        disconnectLogDiagFilesScanned := (path != "") ? 1 : 0
        disconnectLogDiagFilesChanged := 1
        disconnectLogDiagFilesRead := readOk ? 1 : 0
        disconnectLogDiagReadErrors := (path != "" && !readOk) ? 1 : 0
        disconnectLogDiagBytesRead := bytesRead
        disconnectLogDiagNewFiles := 0
        disconnectLogDiagOverlapChars := 0
        disconnectLogDiagMappingState := "GAME_IDENTITY_DISCONNECTED_FALLBACK"
        disconnectLogDiagMappedPids := pid . ""
        disconnectLogDiagMappedHwnds := "0x" . Format("{:X}", hwnd)
        disconnectLogDiagFocusState := "READY"
        disconnectLogDiagFocusHwnd := hwnd
        disconnectLogDiagFocusPid := pid
        disconnectLogDiagFocusTime := disconnectLogDiagScanTime
        if (path != "") {
            alreadyQueued := false
            for _, pendingPath in disconnectLogSignalFiles {
                if (pendingPath = path) {
                    alreadyQueued := true
                    break
                }
            }
            if (!alreadyQueued)
                disconnectLogSignalFiles.Push(path)
            disconnectLogSignalSequence += 1
            disconnectLogSignalVersions[path] := disconnectLogSignalSequence
        }
        return true
    }
    return false
}

Macro_PrimeConnectionLogState() {
    global connectionLogState, CONNECTION_LOG_LOOKBACK_MIN
    global disconnectLogSignalFiles, disconnectLogSignalVersions, disconnectLogSignalSequence
    global disconnectIdentitySignalHandledByPid
    global disconnectLogDiagSignal, disconnectLogDiagFreshSignal
    global disconnectLogDiagFile, disconnectLogDiagPattern, disconnectLogDiagCode, disconnectDiagScanTime
    global disconnectLogDiagFilesScanned, disconnectLogDiagFilesChanged
    global disconnectLogDiagFilesRead, disconnectLogDiagReadErrors
    global disconnectLogDiagBytesRead, disconnectLogDiagNewFiles
    global disconnectLogDiagOverlapChars, disconnectLogDiagLastSignalTime
    global disconnectLogDiagMappingState, disconnectLogDiagMappedPids, disconnectLogDiagMappedHwnds
    global disconnectLogDiagFocusState, disconnectLogDiagFocusHwnd, disconnectLogDiagFocusPid, disconnectLogDiagFocusTime

    localAppData := EnvGet("LOCALAPPDATA")
    if (!localAppData)
        return false
    logDir := localAppData . "\\Roblox\\logs"
    if !DirExist(logDir)
        return false

    try {
        connectionLogState.Clear()
    } catch {
        connectionLogState := Map()
    }

    ; Baseline existing log bytes, but allow a currently disconnected identity
    ; to be handed off once for this newly enabled recovery session.
    disconnectIdentitySignalHandledByPid.Clear()
    disconnectLogSignalFiles := []
    disconnectLogSignalVersions.Clear()
    disconnectLogSignalSequence := 0
    disconnectLogDiagSignal := false
    disconnectLogDiagFreshSignal := false
    disconnectLogDiagFile := ""
    disconnectLogDiagPattern := ""
    disconnectLogDiagCode := ""
    disconnectLogDiagLastSignalTime := ""
    disconnectDiagScanTime := Macro_Format12HourCurrentTime(A_Now)
    disconnectLogDiagFilesScanned := 0
    disconnectLogDiagFilesChanged := 0
    disconnectLogDiagFilesRead := 0
    disconnectLogDiagReadErrors := 0
    disconnectLogDiagBytesRead := 0
    disconnectLogDiagNewFiles := 0
    disconnectLogDiagOverlapChars := 0
    disconnectLogDiagMappingState := "BASELINE"
    disconnectLogDiagMappedPids := ""
    disconnectLogDiagMappedHwnds := ""
    disconnectLogDiagFocusState := "IDLE"
    disconnectLogDiagFocusHwnd := 0
    disconnectLogDiagFocusPid := 0
    disconnectLogDiagFocusTime := ""

    try {
        Loop Files, logDir . "\\*.log", "F" {
            path := A_LoopFileFullPath
            size := A_LoopFileSize
            tail := ""
            if (size > 0) {
                f := 0
                try {
                    f := FileOpen(path, "r")
                    if (IsObject(f)) {
                        start := Max(0, size - 65536)
                        f.Seek(start, 0)
                        tail := f.Read(size - start)
                        f.Close()
                    }
                } catch {
                    try {
                        if (IsObject(f))
                            f.Close()
                    } catch {
                    }
                }
            }
            connectionLogState[path] := Map("size", size, "modified", A_LoopFileTimeModified, "tail", tail)
        }
    } catch {
        return false
    }

    ; Do not discard the last confirmed signal here.  The next scan will
    ; report freshSignal separately.
    return true
}

Macro_ConnectionWatchdog(forceScan := false) {
    ; This watchdog may spend seconds probing several Roblox windows. Timer
    ; callbacks must not start overlapping copies while a probe is in flight.
    static running := false
    if (running)
        return

    running := true
    try {
        Macro_ConnectionWatchdogCore(forceScan)
    } finally {
        running := false
    }
}

Macro_ConnectionWatchdogCore(forceScan := false) {
    global connectionRecoveryEnabled, connectionRecoveryBusy, connectionRecoveryAutoBatch
    global CONNECTION_MODAL_AUTO_RECOVERY_ENABLE
    global fixedPointModalDebugEnabled
    global connectionRecoveryNextTick
    global disconnectAlertActive, disconnectAlertStage
    global disconnectAlertGui, disconnectAlertTitle, disconnectAlertBody, disconnectAlertPrimaryButton, disconnectAlertRaisePending
    global disconnectManualCheckBusy
    global connectionRecoveryDetectedHwnd, connectionRecoveryDetectedPid, connectionRecoveryDetectedVerified
    global disconnectHiddenScanActive, disconnectHiddenScanIndex, disconnectHiddenScanTotal
    global disconnectHiddenScanCooldownUntil, disconnectHiddenScanPending, disconnectHiddenScanCountdownRunning
    global disconnectHiddenScanLastMiss
    global connectionPassiveScanNextTick
    global disconnectLogDiagFreshSignal
    global CONNECTION_HIDDEN_SCAN_COOLDOWN_MS, CONNECTION_PASSIVE_SCAN_INTERVAL_MS
    global USER_ACTIVITY_TIMEOUT_MS, AUTO_HIDDEN_SCAN_DELAY_SEC

    if (!connectionRecoveryEnabled)
        return

    ; Manual inspection owns window activation and pixel probing. Let it finish
    ; before the background watchdog touches the same clients.
    if (disconnectManualCheckBusy)
        return


    nowTick := A_TickCount

    recoveryWasBusy := connectionRecoveryBusy
    if (recoveryWasBusy && nowTick >= connectionRecoveryNextTick)
        Macro_CheckConnectionRecovery()

    ; The dedicated Macro_ConnectionLogWatchdog() owns log scanning now.
    ; Keep log I/O out of this 10s watchdog so it stays focused on recovery/screen state.

    ; An earlier log-confirmed request also blocks all automatic screen
    ; inspection while the user is active.
    if (disconnectHiddenScanPending
        && Macro_IsUserActiveAnywhere(AUTO_HIDDEN_SCAN_DELAY_SEC * 1000)) {
        Macro_StartHiddenScanCountdown()
        return
    }

    ; No periodic passive screen scan here. Screen monitoring runs only while F6 is enabled.
    verifiedTargets := []

    ; -------------------------------------------------------------
    ; 3) Execute the pending hidden/minimized-client inspection only after
    ;    the user has been idle for AUTO_HIDDEN_SCAN_DELAY_SEC.
    ; -------------------------------------------------------------
    if (CONNECTION_MODAL_AUTO_RECOVERY_ENABLE
        && disconnectHiddenScanPending
        && !Macro_IsUserActiveAnywhere(AUTO_HIDDEN_SCAN_DELAY_SEC * 1000)
        && !recoveryWasBusy && !disconnectHiddenScanActive
        && nowTick >= disconnectHiddenScanCooldownUntil) {

        disconnectHiddenScanPending := false
        disconnectHiddenScanCountdownRunning := false
        SetTimer(Macro_UpdateHiddenScanCountdown, 0)

        MouseMacro_ForceOffForDisconnect("automatic modal scan started")
        disconnectHiddenScanActive := true
        Macro_RecordDisconnectProcessStep("modal_scan")
        Macro_ClearFixedPointModalPinnedResult(false)
        if (fixedPointModalDebugEnabled)
            Macro_HideFixedPointModalMarkers()
        disconnectHiddenScanCooldownUntil := nowTick + CONNECTION_HIDDEN_SCAN_COOLDOWN_MS
        disconnectHiddenScanIndex := 0
        disconnectHiddenScanTotal := 0

        Macro_ShowDisconnectAlertSafely(Macro_GetDisconnectLogReasonText(), 0, true)
        Macro_ShowHiddenDisconnectScanProgress(0, 0, 0)

        hiddenTargets := []
        try hiddenTargets := Macro_FindDisconnectAfterLogSignal(true)
        catch
            hiddenTargets := []
        disconnectHiddenScanActive := false

        if (hiddenTargets.Length) {
            ; Collect every confirmed modal in this scan, not just the first one.
            for hiddenTarget in hiddenTargets {
                Macro_RecordDisconnectProcessStep("modal_confirmed")
                verifiedTargets.Push(hiddenTarget)
            }
            connectionRecoveryAutoBatch := true
            disconnectHiddenScanLastMiss := false
        } else if (disconnectHiddenScanPending) {
            ; Physical user input interrupted inspection; resume after the idle delay.
            disconnectHiddenScanLastMiss := false
            ; This pass has stopped, so restore the actionable Signal UI instead
            ; of leaving a disabled "Checking…" button during the idle wait.
            if (disconnectAlertActive) {
                try {
                    disconnectAlertStage := "Signal"
                    disconnectAlertTitle.Text := Macro_GetDisconnectCodeTitle()
                    disconnectAlertPrimaryButton.Enabled := true
                    disconnectAlertPrimaryButton.Text := Macro_GetDisconnectUIText("inspect")
                    ; Resize calls Show(), so never resize a dismissed alert.
                    alertVisible := !!DllCall("user32\IsWindowVisible", "Ptr", disconnectAlertGui.Hwnd)
                    disconnectAlertBody.Text := Macro_GetDisconnectAlertBody(Macro_GetDisconnectLogReasonText())
                    if (alertVisible)
                        Macro_ResizeDisconnectAlert()
                } catch {
                }
            }
            Macro_StartHiddenScanCountdown(false)
        } else {
            ; A complete pass found no modal. Stop automatic retries for this log event.
            Macro_RecordDisconnectProcessStep("modal_not_found")
            disconnectHiddenScanLastMiss := true
            disconnectHiddenScanCountdownRunning := false
            SetTimer(Macro_UpdateHiddenScanCountdown, 0)
            if (disconnectAlertActive) {
                try {
                    disconnectAlertStage := "Signal"
                    disconnectAlertTitle.Text := Macro_GetDisconnectUIText("notFoundTitle")
                    disconnectAlertBody.Text := Macro_GetDisconnectAlertBody(Macro_GetDisconnectLogReasonText())
                    disconnectAlertPrimaryButton.Enabled := true
                    disconnectAlertPrimaryButton.Text := Macro_GetDisconnectUIText("retry")
                    Macro_ResizeDisconnectAlert()
                } catch {
                }
            }
        }
    }

    ; -------------------------------------------------------------
    ; 4) Queue confirmed candidates.
    ; -------------------------------------------------------------
    if (verifiedTargets.Length) {
        for candidate in verifiedTargets
            Macro_QueueReconnectCandidate(candidate["hwnd"], candidate["pid"], candidate["minmax"])

        ; One automatic batch drains all confirmed candidates, including duplicates
        ; already queued by an earlier scan, in strict one-at-a-time order.
        connectionRecoveryAutoBatch := true
        nextCandidate := Macro_PeekReconnectCandidate()
        if (nextCandidate) {
            connectionRecoveryDetectedHwnd := nextCandidate["hwnd"]
            connectionRecoveryDetectedPid := nextCandidate["pid"]
            connectionRecoveryDetectedVerified := true
            alertReasonText := disconnectLogDiagFreshSignal
                ? Macro_GetDisconnectLogReasonText()
                : Macro_GetVisibleReconnectReason()
            Macro_ShowDisconnectAlert(alertReasonText, nextCandidate["hwnd"])
        }
    }

    ; -------------------------------------------------------------
    ; 5) Automatic recovery is also gated by general physical user activity.
    ;    Manual inspection uses a separate path and remains immediate.
    ; -------------------------------------------------------------
    if (CONNECTION_MODAL_AUTO_RECOVERY_ENABLE
        && !recoveryWasBusy
        && disconnectAlertActive
        && disconnectAlertStage = "Signal"
        && !Macro_IsUserActiveAnywhere(AUTO_HIDDEN_SCAN_DELAY_SEC * 1000))
        Macro_StartConnectionRecovery()
}

; =====================================================================
; 👤 Physical-user activity detector
;    Uses A_TimeIdlePhysical so synthetic macro mouse/keyboard events do
;    not count as user presence when the corresponding hooks are installed.
; =====================================================================
Macro_ShowDisconnectTrayProgress(messageText, titleText := "🔄 ROBLOX 연결 상태", gameHwnd := 0) {
    ; Connection/reconnect progress uses the alert window. Only F5 toggle
    ; notices use the Windows tray.
    return
}


Macro_ShowHiddenDisconnectScanProgress(index, total, hwnd := 0) {
    global disconnectAlertGui, disconnectAlertTitle, disconnectAlertBody, disconnectAlertPrimaryButton
    global disconnectAlertActive, disconnectAlertStage
    global disconnectHiddenScanIndex, disconnectHiddenScanTotal

    disconnectHiddenScanIndex := index
    disconnectHiddenScanTotal := total

    if (!disconnectAlertActive || !IsObject(disconnectAlertGui))
        return

    if (total > 0) {
        isKorean := (Macro_GetWindowsUILanguage() = "ko")
        text := Macro_GetDisconnectUIText("hiddenScanChecking") . "`n"
            . (isKorean ? "현재 확인: " : "Current: ") . index . " / " . total . "`n"
            . (isKorean ? "현재: Roblox 창을 활성화하여 검사 중" : "Current: Activating a Roblox window for inspection")
    } else {
        text := Macro_GetDisconnectUIText("hiddenScanPreparing")
    }

    try {
        disconnectAlertStage := "Signal"
        disconnectAlertTitle.Text := Macro_GetDisconnectUIText("checkingTitle")
        disconnectAlertBody.Text := text
        disconnectAlertPrimaryButton.Enabled := false
        disconnectAlertPrimaryButton.Text := Macro_GetDisconnectUIText("checkingButton")
        Macro_ResizeDisconnectAlert()
    } catch {
    }
}

Macro_GetPidsUsingRobloxLog(logPath) {
    pids := []
    if (logPath = "" || !FileExist(logPath))
        return pids

    sessionHandle := 0
    sessionStarted := false
    try {
        sessionKeyBuffer := Buffer(66, 0)
        sessionKey := "AHKRobloxLog" . A_TickCount
        StrPut(sessionKey, sessionKeyBuffer, 33, "UTF-16")

        status := DllCall("rstrtmgr\RmStartSession", "UInt*", &sessionHandle,
            "UInt", 0, "Ptr", sessionKeyBuffer.Ptr, "UInt")
        if (status != 0)
            return pids
        sessionStarted := true

        filePathArray := Buffer(A_PtrSize, 0)
        NumPut("Ptr", StrPtr(logPath), filePathArray, 0)
        status := DllCall("rstrtmgr\RmRegisterResources", "UInt", sessionHandle,
            "UInt", 1, "Ptr", filePathArray.Ptr,
            "UInt", 0, "Ptr", 0, "UInt", 0, "Ptr", 0, "UInt")
        if (status != 0)
            return pids

        needed := 0
        count := 0
        rebootReasons := 0
        status := DllCall("rstrtmgr\RmGetList", "UInt", sessionHandle,
            "UInt*", &needed, "UInt*", &count, "Ptr", 0,
            "UInt*", &rebootReasons, "UInt")
        if (status != 234 || needed = 0)
            return pids

        ; RM_PROCESS_INFO is 668 bytes with the Windows SDK layout.
        processInfoSize := 668
        count := needed
        processInfoBuffer := Buffer(count * processInfoSize, 0)
        status := DllCall("rstrtmgr\RmGetList", "UInt", sessionHandle,
            "UInt*", &needed, "UInt*", &count, "Ptr", processInfoBuffer.Ptr,
            "UInt*", &rebootReasons, "UInt")
        if (status != 0)
            return pids

        Loop count {
            pid := NumGet(processInfoBuffer, (A_Index - 1) * processInfoSize, "UInt")
            if (pid)
                pids.Push(pid)
        }
    } catch {
        pids := []
    } finally {
        if (sessionStarted) {
            try DllCall("rstrtmgr\RmEndSession", "UInt", sessionHandle, "UInt")
        }
    }
    return pids
}

Macro_FindDisconnectAfterLogSignal(returnAll := false) {
    global disconnectLogSignalFiles, disconnectLogSignalVersions, disconnectHiddenScanIndex, disconnectHiddenScanTotal
    global disconnectHiddenScanPending, AUTO_HIDDEN_SCAN_DELAY_SEC
    global connectionRecoveryDiscoveredMinMax, CONNECTION_DEEP_SCAN_SETTLE_MS
    global disconnectLogDiagMappingState, disconnectLogDiagMappedPids, disconnectLogDiagMappedHwnds
    global disconnectLogDiagFocusState, disconnectLogDiagFocusHwnd, disconnectLogDiagFocusPid, disconnectLogDiagFocusTime
    global gameIdentityLogState

    ; Snapshot path generations before probing. Consume only these versions after
    ; a complete pass; newer disconnects appended during this pass remain pending.
    signalVersionSnapshot := Map()
    signalPathsForScan := []
    for logPath, version in disconnectLogSignalVersions {
        signalVersionSnapshot[logPath] := version
        signalPathsForScan.Push(logPath)
    }
    for _, logPath in disconnectLogSignalFiles {
        if (!signalVersionSnapshot.Has(logPath)) {
            signalVersionSnapshot[logPath] := 0
            signalPathsForScan.Push(logPath)
        }
    }
    foundCandidates := []

    CoordMode("Mouse", "Screen")
    CoordMode("Pixel", "Screen")

    originalForeground := WinExist("A")
    try {
        list := WinGetList("ahk_exe RobloxPlayerBeta.exe")
    } catch {
        return returnAll ? foundCandidates : 0
    }
    if (!list.Length)
        return returnAll ? foundCandidates : 0

    ; Prefer the HWND already parsed from the exact signal log. If that is not
    ; available (for example, a CrashHandler log), use the file's current owner PID.
    signalPids := Map()
    mappedHwnds := Map()
    identityHwnds := Map()
    mappingComplete := (signalPathsForScan.Length > 0)
    mappedAny := false
    for _, logPath in signalPathsForScan {
        mappedThisLog := false
        if (gameIdentityLogState.Has(logPath)) {
            try {
                cachedIdentity := gameIdentityLogState[logPath]
                cachedHwnd := cachedIdentity.hwnd
                if (cachedHwnd && WinExist("ahk_id " . cachedHwnd)
                    && WinGetProcessName("ahk_id " . cachedHwnd) = "RobloxPlayerBeta.exe") {
                    cachedPid := WinGetPID("ahk_id " . cachedHwnd)
                    signalPids[cachedPid] := true
                    mappedHwnds[cachedHwnd] := true
                    identityHwnds[cachedHwnd] := true
                    mappedThisLog := true
                    mappedAny := true
                }
            } catch {
            }
        }

        ownerPids := Macro_GetPidsUsingRobloxLog(logPath)
        for _, ownerPid in ownerPids {
            for _, hwnd in list {
                try {
                    if (WinGetPID("ahk_id " . hwnd) = ownerPid) {
                        signalPids[ownerPid] := true
                        mappedHwnds[hwnd] := true
                        mappedThisLog := true
                        mappedAny := true
                    }
                } catch {
                }
            }
        }
        if (!mappedThisLog)
            mappingComplete := false
    }

    disconnectLogDiagMappedPids := ""
    for ownerPid, _ in signalPids
        disconnectLogDiagMappedPids .= (disconnectLogDiagMappedPids = "" ? "" : ",") . ownerPid

    disconnectLogDiagMappedHwnds := ""
    for hwnd, _ in mappedHwnds
        disconnectLogDiagMappedHwnds .= (disconnectLogDiagMappedHwnds = "" ? "" : ",") . ("0x" . Format("{:X}", hwnd))

    ; A signal log can be a CrashHandler file with no session title of its own.
    ; Once its owner PID is mapped, retry the game-name lookup from that PID's
    ; cached Player log identity.
    SetTimer(Macro_RefreshDisconnectAlertGameName, -1)

    if (mappingComplete && mappedAny)
        disconnectLogDiagMappingState := "PID_MATCH"
    else if (mappedAny)
        disconnectLogDiagMappingState := "PARTIAL_MATCH"
    else
        disconnectLogDiagMappingState := "NO_PID_MATCH_FALLBACK"

    scanList := []
    exactHwndScanList := []
    mappedPidScanList := []
    fallbackScanList := []
    for _, hwnd in list {
        if (!WinExist("ahk_id " . hwnd))
            continue
        pid := 0
        try pid := WinGetPID("ahk_id " . hwnd)
        catch
            continue
        if (mappingComplete && !signalPids.Has(pid))
            continue

        oldState := 0
        oldX := 0, oldY := 0, oldW := 0, oldH := 0
        savedPos := false
        try {
            oldState := WinGetMinMax("ahk_id " . hwnd)
            if (oldState != -1) {
                WinGetPos(&oldX, &oldY, &oldW, &oldH, "ahk_id " . hwnd)
                savedPos := (oldW > 0 && oldH > 0)
            }
        } catch {
            continue
        }
        scanItem := Map("hwnd", hwnd, "pid", pid, "minmax", oldState,
            "x", oldX, "y", oldY, "w", oldW, "h", oldH, "savedPos", savedPos)
        if (identityHwnds.Has(hwnd))
            exactHwndScanList.Push(scanItem)
        else if (signalPids.Has(pid))
            mappedPidScanList.Push(scanItem)
        else
            fallbackScanList.Push(scanItem)
    }

    ; Inspect HWNDs resolved directly from the signal log first, then any other
    ; windows owned by a mapped PID. If mapping was incomplete, retain the
    ; remaining Roblox clients as a fallback after those exact matches.
    for _, item in exactHwndScanList
        scanList.Push(item)
    for _, item in mappedPidScanList
        scanList.Push(item)
    if (!mappingComplete) {
        for _, item in fallbackScanList
            scanList.Push(item)
    }

    ; If a mapped PID did not produce a usable HWND, scan all Roblox clients.
    if (!scanList.Length && mappingComplete) {
        mappingComplete := false
        for _, hwnd in list {
            if (!WinExist("ahk_id " . hwnd))
                continue
            try {
                pid := WinGetPID("ahk_id " . hwnd)
                oldState := WinGetMinMax("ahk_id " . hwnd)
                oldX := 0, oldY := 0, oldW := 0, oldH := 0
                savedPos := false
                if (oldState != -1) {
                    WinGetPos(&oldX, &oldY, &oldW, &oldH, "ahk_id " . hwnd)
                    savedPos := (oldW > 0 && oldH > 0)
                }
                scanList.Push(Map("hwnd", hwnd, "pid", pid, "minmax", oldState,
                    "x", oldX, "y", oldY, "w", oldW, "h", oldH, "savedPos", savedPos))
            } catch {
            }
        }
    }

    total := scanList.Length
    disconnectHiddenScanTotal := total
    disconnectHiddenScanIndex := 0
    if (!total)
        return returnAll ? foundCandidates : 0

    userInterrupted := false
    for index, item in scanList {
        hwnd := item["hwnd"]
        pid := item["pid"]
        oldState := item["minmax"]
        oldX := item["x"], oldY := item["y"], oldW := item["w"], oldH := item["h"]
        savedPos := item["savedPos"]

        if (!WinExist("ahk_id " . hwnd))
            continue
        try {
            if (WinGetPID("ahk_id " . hwnd) != pid)
                continue
        } catch {
            continue
        }

        if (Macro_IsUserActiveAnywhere(AUTO_HIDDEN_SCAN_DELAY_SEC * 1000)) {
            disconnectHiddenScanPending := true
            userInterrupted := true
            break
        }

        disconnectHiddenScanIndex := index
        Macro_ShowHiddenDisconnectScanProgress(index, total, hwnd)
        found := false
        abortScan := false
        disconnectLogDiagFocusHwnd := hwnd
        disconnectLogDiagFocusPid := pid
        disconnectLogDiagFocusTime := Macro_Format12HourCurrentTime(A_Now)
        disconnectLogDiagFocusState := "ACTIVATE_TRY"
        try {
            if (oldState = -1)
                WinRestore("ahk_id " . hwnd)
            WinActivate("ahk_id " . hwnd)
            if (WinWaitActive("ahk_id " . hwnd, , 2)) {
                disconnectLogDiagFocusState := "ACTIVE"
                Sleep(CONNECTION_DEEP_SCAN_SETTLE_MS)
                if (Macro_IsUserActiveAnywhere(AUTO_HIDDEN_SCAN_DELAY_SEC * 1000)) {
                    disconnectHiddenScanPending := true
                    abortScan := true
                } else if (WinExist("ahk_id " . hwnd) && WinGetPID("ahk_id " . hwnd) = pid) {
                    found := (Macro_ProbeReconnectDialog(hwnd, false, true) = 1)
                    disconnectLogDiagFocusState := found ? "ACTIVE_277_FOUND" : "ACTIVE_277_NOT_FOUND"
                    if (disconnectHiddenScanPending) {
                        ; Another disconnect arrived while this pass was running.
                        ; Finish restoring this client, preserve its result, then resume later.
                        userInterrupted := true
                        abortScan := true
                    }
                }
            } else {
                disconnectLogDiagFocusState := "ACTIVATE_FAIL"
            }
        } catch {
            disconnectLogDiagFocusState := "ACTIVATE_ERROR"
            found := false
        }

        if (!abortScan && Macro_IsUserActiveAnywhere(AUTO_HIDDEN_SCAN_DELAY_SEC * 1000)) {
            disconnectHiddenScanPending := true
            abortScan := true
        }
        if (abortScan)
            userInterrupted := true

        Macro_RestoreHiddenScanWindow(hwnd, oldState, oldX, oldY, oldW, oldH, savedPos)
        if (found) {
            connectionRecoveryDiscoveredMinMax := oldState
            candidate := Map("hwnd", hwnd, "pid", pid, "minmax", oldState)
            foundCandidates.Push(candidate)
            if (!returnAll) {
                try {
                    if (originalForeground && WinExist("ahk_id " . originalForeground))
                        WinActivate("ahk_id " . originalForeground)
                } catch {
                }
                if (!userInterrupted)
                    Macro_ConsumeDisconnectSignalSnapshot(signalVersionSnapshot)
                return candidate
            }
        }
        if (userInterrupted)
            break
    }

    ; Respect new physical input; otherwise return focus to the pre-scan foreground window.
    if (!userInterrupted) {
        try {
            if (originalForeground && WinExist("ahk_id " . originalForeground))
                WinActivate("ahk_id " . originalForeground)
        } catch {
        }
        Macro_ConsumeDisconnectSignalSnapshot(signalVersionSnapshot)
    }
    if (returnAll)
        return foundCandidates
    return foundCandidates.Length ? foundCandidates[1] : 0
}

Macro_ConsumeDisconnectSignalSnapshot(snapshot) {
    global disconnectLogSignalVersions, disconnectLogSignalFiles

    ; Delete only versions inspected by this pass. A newer generation for the
    ; same path means another disconnect arrived meanwhile and must be retained.
    for logPath, scannedVersion in snapshot {
        if (disconnectLogSignalVersions.Has(logPath)
            && disconnectLogSignalVersions[logPath] = scannedVersion)
            disconnectLogSignalVersions.Delete(logPath)
    }

    disconnectLogSignalFiles := []
    for logPath, _ in disconnectLogSignalVersions
        disconnectLogSignalFiles.Push(logPath)
}
Macro_RestoreHiddenScanWindow(hwnd, oldState, oldX, oldY, oldW, oldH, savedPos := false) {
    if (!hwnd || !WinExist("ahk_id " . hwnd))
        return

    try {
        ; Restore geometry explicitly so a temporary focus/restore operation cannot
        ; leave a covered client at a changed position or size.
        if (savedPos && oldState != -1 && oldState != 1)
            WinMove(oldX, oldY, oldW, oldH, "ahk_id " . hwnd)
    } catch {
    }

    try {
        if (oldState = -1)
            WinMinimize("ahk_id " . hwnd)
        else if (oldState = 1)
            WinMaximize("ahk_id " . hwnd)
    } catch {
    }
}

Macro_VerifyReconnectCandidate(hwnd, pid := 0, minmax := 0) {
    ; A candidate is not considered a real disconnect until the exact HWND is
    ; activated and the reconnect modal is detected again on that actual screen.
    ; This deliberately rechecks even when the first pass already reported a hit.
    if (!hwnd || !WinExist("ahk_id " . hwnd))
        return false

    if (pid) {
        try {
            currentPid := WinGetPID("ahk_id " . hwnd)
            if (currentPid && currentPid != pid)
                return false
        } catch {
            return false
        }
    }

    result := Macro_ProbeReconnectDialog(hwnd, true)
    return (result = 1)
}

Macro_IsUserActiveAnywhere(timeoutMs := 5000) {
    return (A_TimeIdlePhysical <= timeoutMs)
}

Macro_StartHiddenScanCountdown(updateImmediately := true) {
    global disconnectHiddenScanPending, disconnectHiddenScanCountdownRunning

    if (!disconnectHiddenScanPending)
        return

    disconnectHiddenScanCountdownRunning := true
    SetTimer(Macro_UpdateHiddenScanCountdown, 250)
    if (updateImmediately)
        Macro_UpdateHiddenScanCountdown()
}

Macro_UpdateHiddenScanCountdown() {
    global connectionRecoveryEnabled
    global disconnectHiddenScanPending, disconnectHiddenScanCountdownRunning
    global disconnectHiddenScanActive, disconnectAlertActive, disconnectAlertStage
    global disconnectAlertGui, disconnectAlertTitle, disconnectAlertBody, disconnectAlertReason
    global disconnectAlertPrimaryButton, disconnectAlertLastRecoveryAttempts, disconnectAlertLastSuccessTime
    global disconnectAlertDetectionSource, disconnectDiagTargetHwnd, disconnectDiagTargetPid, disconnectDiagScanTime
    global connectionRecoveryBusy, connectionRecoveryPending, disconnectManualCheckBusy
    global fixedPointModalDebugReconnectPending
    global AUTO_HIDDEN_SCAN_DELAY_SEC, disconnectHiddenScanCooldownUntil

    if (!connectionRecoveryEnabled
        || !disconnectHiddenScanPending || disconnectHiddenScanActive
        || !disconnectAlertActive) {
        disconnectHiddenScanCountdownRunning := false
        SetTimer(Macro_UpdateHiddenScanCountdown, 0)
        return
    }

    ; A new log event can arrive while an older alert is in Checking/Confirmed/
    ; Reconnecting/Failed. Do not cancel the pending scan timer: wait until the
    ; existing transaction is no longer running, then restore an actionable Signal.
    if (disconnectAlertStage != "Signal") {
        if (connectionRecoveryBusy || connectionRecoveryPending
            || disconnectManualCheckBusy || fixedPointModalDebugReconnectPending)
            return

        disconnectAlertStage := "Signal"
        disconnectAlertLastRecoveryAttempts := 0
        disconnectAlertLastSuccessTime := ""
        try {
            disconnectAlertDetectionSource := "log"
            disconnectAlertTitle.Text := Macro_GetDisconnectCodeTitle()
            disconnectAlertPrimaryButton.Enabled := true
            disconnectAlertPrimaryButton.Text := Macro_GetDisconnectUIText("inspect")
            disconnectAlertBody.Text := Macro_GetDisconnectAlertBody(disconnectAlertReason)
            if (IsObject(disconnectAlertGui) && disconnectAlertGui.Hwnd
                && DllCall("user32\IsWindowVisible", "Ptr", disconnectAlertGui.Hwnd))
                Macro_ResizeDisconnectAlert()
        } catch {
        }
    }

    delayMs := Max(0, AUTO_HIDDEN_SCAN_DELAY_SEC * 1000)
    idleWaitMs := (delayMs > 0) ? Max(0, delayMs + 1 - A_TimeIdlePhysical) : 0
    cooldownWaitMs := Max(0, disconnectHiddenScanCooldownUntil - A_TickCount)

    if (Max(idleWaitMs, cooldownWaitMs) <= 0) {
        disconnectHiddenScanCountdownRunning := false
        SetTimer(Macro_UpdateHiddenScanCountdown, 0)
        Macro_ConnectionWatchdog(true)
        return
    }

    try {
        nextBody := Macro_GetDisconnectAlertBody(disconnectAlertReason)
        if (disconnectAlertBody.Text != nextBody) {
            disconnectAlertBody.Text := nextBody
            ; Updating the countdown must not reopen an alert the user already
            ; dismissed by clicking another window. Resize only while visible;
            ; the normal alert refresh will lay it out before it is shown again.
            isVisible := false
            try isVisible := IsObject(disconnectAlertGui) && disconnectAlertGui.Hwnd
                && !!DllCall("user32\IsWindowVisible", "Ptr", disconnectAlertGui.Hwnd)
            if (isVisible)
                Macro_ResizeDisconnectAlert()
        }
    } catch {
    }
}

Macro_StartF6ModalReconnectCountdown(hwnd) {
    global connectionRecoveryEnabled, CONNECTION_MODAL_AUTO_RECOVERY_ENABLE
    global connectionRecoveryBusy
    global fixedPointModalDebugReconnectPending, fixedPointModalDebugReconnectHwnd
    global disconnectAlertActive, disconnectAlertStage, disconnectAlertDetectedHwnd
    global disconnectAlertReason, disconnectAlertBody, disconnectAlertPrimaryButton

    if (!connectionRecoveryEnabled || !CONNECTION_MODAL_AUTO_RECOVERY_ENABLE || connectionRecoveryBusy
        || !hwnd || !WinExist("ahk_id " . hwnd))
        return false

    if (fixedPointModalDebugReconnectPending && fixedPointModalDebugReconnectHwnd = hwnd)
        return true

    fixedPointModalDebugReconnectPending := true
    fixedPointModalDebugReconnectHwnd := hwnd
    disconnectAlertDetectedHwnd := hwnd
    if (disconnectAlertStage != "Signal")
        disconnectAlertStage := "Signal"
    disconnectAlertReason := Macro_GetVisibleReconnectReason()
    try {
        disconnectAlertPrimaryButton.Enabled := true
        disconnectAlertPrimaryButton.Text := Macro_GetDisconnectUIText("inspect")
        disconnectAlertBody.Text := Macro_GetDisconnectAlertBody(disconnectAlertReason)
        Macro_ResizeDisconnectAlert()
    } catch {
    }
    SetTimer(Macro_UpdateF6ModalReconnectCountdown, 250)
    Macro_UpdateF6ModalReconnectCountdown()
    return true
}

Macro_UpdateF6ModalReconnectCountdown() {
    global connectionRecoveryEnabled, CONNECTION_MODAL_AUTO_RECOVERY_ENABLE
    global fixedPointModalDebugReconnectPending, fixedPointModalDebugReconnectHwnd
    global disconnectAlertActive, disconnectAlertStage, disconnectAlertDetectedHwnd
    global disconnectAlertReason, disconnectAlertBody, disconnectAlertPrimaryButton, disconnectAlertGui
    global connectionRecoveryDetectedHwnd, connectionRecoveryDetectedPid, connectionRecoveryDetectedVerified
    global AUTO_HIDDEN_SCAN_DELAY_SEC

    hwnd := fixedPointModalDebugReconnectHwnd
    if (!fixedPointModalDebugReconnectPending || !connectionRecoveryEnabled
        || !CONNECTION_MODAL_AUTO_RECOVERY_ENABLE || !WinExist("ahk_id " . hwnd)
        || !disconnectAlertActive || disconnectAlertStage != "Signal") {
        fixedPointModalDebugReconnectPending := false
        fixedPointModalDebugReconnectHwnd := 0
        SetTimer(Macro_UpdateF6ModalReconnectCountdown, 0)
        return
    }

    delayMs := Max(0, AUTO_HIDDEN_SCAN_DELAY_SEC * 1000)
    idleWaitMs := (delayMs > 0) ? Max(0, delayMs + 1 - A_TimeIdlePhysical) : 0
    if (idleWaitMs > 0) {
        try {
            nextBody := Macro_GetDisconnectAlertBody(disconnectAlertReason)
            if (disconnectAlertBody.Text != nextBody) {
                disconnectAlertBody.Text := nextBody
                isVisible := IsObject(disconnectAlertGui) && disconnectAlertGui.Hwnd
                    && !!DllCall("user32\IsWindowVisible", "Ptr", disconnectAlertGui.Hwnd)
                if (isVisible)
                    Macro_ResizeDisconnectAlert()
            }
        } catch {
        }
        return
    }

    fixedPointModalDebugReconnectPending := false
    fixedPointModalDebugReconnectHwnd := 0
    SetTimer(Macro_UpdateF6ModalReconnectCountdown, 0)
    if (!WinExist("ahk_id " . hwnd))
        return

    pid := 0
    try pid := WinGetPID("ahk_id " . hwnd)
    connectionRecoveryDetectedHwnd := hwnd
    connectionRecoveryDetectedPid := pid
    connectionRecoveryDetectedVerified := true
    disconnectAlertDetectedHwnd := hwnd
    ; Use the exact detected HWND through the established click/confirmation
    ; path; another queued Roblox client must not take priority over it.
    Macro_StartManualReconnect(hwnd)
}

Macro_IsUserActivelyPlayingRoblox(timeoutMs := 5000) {
    activeHwnd := WinExist("A")
    if (!activeHwnd)
        return false

    try {
        if (WinGetProcessName("ahk_id " . activeHwnd) != "RobloxPlayerBeta.exe")
            return false
    } catch {
        return false
    }

    ; A_TimeIdlePhysical responds only to physical events when the hooks are installed.
    if (A_TimeIdlePhysical > timeoutMs)
        return false

    return true
}

; =====================================================================
; 🚨 Separate bottom-right 277 notification window
; =====================================================================
Macro_GetWindowsUILanguage() {
    try {
        langId := DllCall("Kernel32\GetUserDefaultUILanguage", "UShort")
        primaryLang := langId & 0x3FF

        ; Korean primary language ID = 0x12
        if (primaryLang = 0x12)
            return "ko"

        ; English primary language ID = 0x09
        if (primaryLang = 0x09)
            return "en"
    } catch {
    }

    ; Unknown / unsupported Windows UI language -> English
    return "en"
}

; The Roblox game selector intentionally remains English-only on every Windows locale.
; Other system notifications continue using Macro_GetGameStatusUIText below.
Macro_GetGameSelectorUIText(key) {
    switch key {
        case "restoreAll":
            return "Restore"
        case "restoreAllTooltip":
            return "Restore all minimized windows"
        case "searchingLogs":
            return "Searching game logs..."
        case "noClients":
            return "No Roblox clients detected"
        case "checking":
            return "Checking..."
        case "otherGame":
            return "Other Game"
        case "disconnected":
            return "Disconnected"
        case "online":
            return "Online"
    }
    return key
}

Macro_GetGameStatusUIText(key) {
    isKorean := (Macro_GetWindowsUILanguage() = "ko")
    switch key {
        case "restoreAll":
            return isKorean ? "전체 복원" : "Restore All"
        case "searchingLogs":
            return isKorean ? "게임 로그 검색 중..." : "Searching game logs..."
        case "noClients":
            return isKorean ? "실행 중인 Roblox 창이 없습니다" : "No Roblox clients detected"
        case "checking":
            return isKorean ? "확인 중..." : "Checking..."
        case "otherGame":
            return isKorean ? "기타 게임" : "Other Game"
        case "disconnected":
            return isKorean ? "연결 끊김" : "Disconnected"
        case "online":
            return isKorean ? "온라인" : "Online"
    }
    return key
}

Macro_GetDisconnectUIText(key) {
    if (Macro_GetWindowsUILanguage() = "ko") {
        switch key {
            case "title":
                return "🚨 ROBLOX 재연결 감지"
            case "checkingTitle":
                return "🔎 ROBLOX 재연결 화면 확인 중"
            case "confirmedTitle":
                return "✅ ROBLOX 재연결 화면 확인"
            case "reconnectingTitle":
                return "🔄 ROBLOX 재연결 중"
            case "notFoundTitle":
                return "🔎 ROBLOX 재연결 화면 미확인"
            case "inspect":
                return "직접 확인"
            case "dismiss":
                return "무시"
            case "playing":
                return "현재: Roblox 사용 중 — 자동 재연결 대기"
            case "notPlaying":
                return "현재: Roblox 사용자 입력 없음 — 자동 재연결"
            case "waiting":
                return "현재: 사용자 결정을 기다리는 중"
            case "autoPaused":
                return "현재: Roblox 사용 감지 — 자동 재연결 일시정지"
            case "completed":
                return "현재: 정상 — 재연결 완료"
            case "failed":
                return "현재: 자동 재연결 실패 — 수동 확인 필요"
            case "thisAttempts":
                return "이번 복구 시도: "
            case "lastAttempts":
                return "마지막 복구 시도: "
            case "totalAttempts":
                return "누적 재연결 시도: "
            case "totalSuccesses":
                return "누적 재연결 성공: "
            case "recentHistory":
                return "최근 복구 기록"
            case "noHistory":
                return "최근 복구 기록: 없음"
            case "successWord":
                return "성공"
            case "attemptWord":
                return "회 시도"
            case "completedTime":
                return "재연결 완료 시각: "
            case "manualGuide":
                return "[직접 확인]을 눌러 어느 계정인지 확인하세요."
            case "visibleReason":
                return "Roblox 재연결 화면이 표시된 클라이언트를 찾았습니다."
            case "logReason277":
                return "Roblox 로그에서 277 연결 끊김 신호를 감지했습니다."
            case "logReason278":
                return "Roblox 로그에서 278 연결 끊김 신호를 감지했습니다."
            case "logReason273":
                return "Roblox 로그에서 273 연결 끊김 신호를 감지했습니다."
            case "logReason":
                return "Roblox 로그에서 연결 끊김 신호를 감지했습니다."
            case "autoScanCountdown":
                return "자동 검사까지: "
            case "autoReconnectCountdown":
                return "자동 재연결까지: "
            case "autoScanNow":
                return "자동 검사를 시작합니다..."
            case "autoReconnectNow":
                return "자동 재연결을 시작합니다..."
            case "defaultReason":
                return "Roblox 연결 끊김 감지."
            case "checking":
                return "Roblox 계정을 하나씩 확인하는 중입니다...`n사용 중인 화면은 원래대로 복원합니다."
            case "checkingButton":
                return "확인 중..."
            case "hiddenScanPreparing":
                return "🔎 새 연결 끊김 신호를 감지했습니다.`nRoblox 창을 하나씩 확인하는 중입니다..."
            case "hiddenScanChecking":
                return "🔎 Roblox 창을 임시로 활성화하여 확인하는 중입니다..."
            case "hiddenScanTarget":
                return "현재 확인 중인 창"
            case "hiddenScanNotFound":
                return "🔎 연결 끊김 신호는 있었지만 재연결 화면을 찾지 못했습니다.`n검사한 Roblox 창은 원래 상태로 복원했습니다.`n필요하면 [다시 확인]을 눌러 다시 검사하세요."
            case "notFound":
                return "확인 결과 Roblox 재연결 화면을 찾지 못했습니다.`n로그 신호가 일시적이었거나 이미 사라졌을 수 있습니다."
            case "targetClosed":
                return "재연결 대상 Roblox 창이 닫혀 복구 완료 여부를 확인하지 못했습니다.`n다시 확인해 주세요."
            case "retry":
                return "다시 확인"
            case "confirmed":
                return "재연결 화면을 확인했습니다."
            case "confirmedTail":
                return "`n아래 버튼을 누르면 이 계정만 재연결합니다."
            case "reconnect":
                return "재연결"
            case "clickFailed":
                return "재연결 버튼 클릭에 실패했습니다.`n대상 Roblox 창을 다시 확인해 주세요."
            case "reconnecting":
                return "재연결을 시도했습니다.`n복구 여부를 확인하는 중입니다..."
            case "close":
                return "닫기"
            case "reconnected":
                return "재연결이 정상적으로 완료되었습니다."
            case "reconnectedTitle":
                return "✅ ROBLOX 재연결 완료"
            case "failedTitle":
                return "⚠️ ROBLOX 재연결 실패"
            case "diagnostics":
                return "판정 정보"
            case "source":
                return "감지 근거"
            case "gameName":
                return "게임 이름"
            case "username":
                return "사용자 이름"
            case "logPhrase":
                return "로그 문구"
            case "screen":
                return "화면 검사"
            case "log":
                return "로그 검사"
            case "screenAndLog":
                return "화면 + 로그"
            case "detected":
                return "감지"
            case "lastDetected":
                return "직전 감지 유지"
            case "notDetected":
                return "미감지"
            case "modalDark":
                return "모달 어두운 샘플"
            case "buttonWhite":
                return "버튼 흰색 패치"
            case "darkAround":
                return "버튼 주변 어두움"
            case "threshold":
                return "기준"
            case "targetWindow":
                return "대상 HWND"
            case "targetPid":
                return "PID"
            case "logSignal":
                return "로그 신호"
            case "logFile":
                return "로그 파일"
            case "logPattern":
                return "일치 문자열"
            case "scanTime":
                return "검사 시각"
            case "screenNoData":
                return "화면 검사 정보 없음"
            case "logNoSignal":
                return "이번 검사에서 새 디스커넥트 로그 신호 없음"
            case "bandHits":
                return "버튼 검색 밴드 적중"
            case "criteriaText":
                return "현재 코드의 기존 판정 기준을 그대로 표시합니다."
        }
    } else {
        switch key {
            case "title":
                return "🚨 ROBLOX RECONNECT DETECTED"
            case "checkingTitle":
                return "🔎 CHECKING RECONNECT SCREEN"
            case "confirmedTitle":
                return "✅ RECONNECT SCREEN CONFIRMED"
            case "reconnectingTitle":
                return "🔄 ROBLOX RECONNECTING"
            case "notFoundTitle":
                return "🔎 RECONNECT SCREEN NOT FOUND"
            case "inspect":
                return "Inspect"
            case "dismiss":
                return "Dismiss"
            case "playing":
                return "Current: Roblox in use — automatic reconnect waiting"
            case "notPlaying":
                return "Current: No Roblox user input — automatic reconnect"
            case "waiting":
                return "Current: Waiting for your decision"
            case "autoPaused":
                return "Current: Roblox use detected — automatic reconnect paused"
            case "completed":
                return "Current: Normal — reconnect completed"
            case "failed":
                return "Current: Automatic reconnect failed — manual check needed"
            case "thisAttempts":
                return "Attempts this recovery: "
            case "lastAttempts":
                return "Last recovery attempts: "
            case "totalAttempts":
                return "Total reconnect attempts: "
            case "totalSuccesses":
                return "Total reconnect successes: "
            case "recentHistory":
                return "Recent recovery history"
            case "noHistory":
                return "Recent recovery history: none"
            case "successWord":
                return "success"
            case "attemptWord":
                return "attempts"
            case "completedTime":
                return "Reconnect completed: "
            case "manualGuide":
                return "Click [Inspect] to identify the affected account."
            case "visibleReason":
                return "A Roblox client is visibly showing a reconnect screen."
            case "logReason277":
                return "A Roblox log reported a 277 disconnect signal."
            case "logReason278":
                return "A Roblox log reported a 278 disconnect signal."
            case "logReason273":
                return "A Roblox log reported a 273 disconnect signal."
            case "logReason":
                return "A Roblox log reported a disconnect signal."
            case "autoScanCountdown":
                return "Automatic scan in: "
            case "autoReconnectCountdown":
                return "Automatic reconnect in: "
            case "autoScanNow":
                return "Starting automatic scan..."
            case "autoReconnectNow":
                return "Starting automatic reconnect..."
            case "defaultReason":
                return "Roblox disconnect detected."
            case "checking":
                return "Checking Roblox clients one by one...`nIn-use screens will be restored afterwards."
            case "checkingButton":
                return "Checking..."
            case "hiddenScanPreparing":
                return "🔎 A new disconnect signal was detected.`nChecking Roblox clients one at a time..."
            case "hiddenScanChecking":
                return "🔎 Temporarily activating a Roblox client for inspection..."
            case "hiddenScanTarget":
                return "Current window"
            case "hiddenScanNotFound":
                return "🔎 A disconnect signal was found, but no reconnect screen was confirmed.`nInspected Roblox clients were restored to their original state.`nSelect [Inspect Again] to run another check if needed."
            case "notFound":
                return "No Roblox reconnect screen was found.`nThe log signal may have been temporary or already cleared."
            case "targetClosed":
                return "The target Roblox window closed before recovery could be verified.`nInspect again to check the remaining clients."
            case "retry":
                return "Inspect Again"
            case "confirmed":
                return "Reconnect screen confirmed."
            case "confirmedTail":
                return "`nPress the button below to reconnect only this account."
            case "reconnect":
                return "Reconnect"
            case "clickFailed":
                return "Failed to click the reconnect button.`nPlease inspect the target Roblox window again."
            case "reconnecting":
                return "Reconnect was attempted.`nChecking whether recovery completed..."
            case "close":
                return "Close"
            case "reconnected":
                return "Reconnect completed successfully."
            case "reconnectedTitle":
                return "✅ ROBLOX RECONNECT COMPLETE"
            case "failedTitle":
                return "⚠️ ROBLOX RECONNECT FAILED"
            case "diagnostics":
                return "Detection details"
            case "source":
                return "Detection source"
            case "gameName":
                return "Game"
            case "username":
                return "Username"
            case "logPhrase":
                return "Log phrase"
            case "screen":
                return "Screen scan"
            case "log":
                return "Log scan"
            case "screenAndLog":
                return "Screen + Log"
            case "detected":
                return "detected"
            case "lastDetected":
                return "last detected (retained)"
            case "notDetected":
                return "not detected"
            case "modalDark":
                return "Dark modal samples"
            case "buttonWhite":
                return "White button patch"
            case "darkAround":
                return "Dark area around button"
            case "threshold":
                return "threshold"
            case "targetWindow":
                return "Target HWND"
            case "targetPid":
                return "PID"
            case "logSignal":
                return "Log signal"
            case "logFile":
                return "Log file"
            case "logPattern":
                return "Matched text"
            case "scanTime":
                return "Scan time"
            case "screenNoData":
                return "No screen-scan details available"
            case "logNoSignal":
                return "No new disconnect log signal in this scan"
            case "bandHits":
                return "Button-band hits"
            case "criteriaText":
                return "Existing detector thresholds are shown unchanged."
        }
    }

    return key
}

Macro_GetDisconnectLogReasonText() {
    global disconnectLogDiagCode
    code := disconnectLogDiagCode
    if (code = "277")
        return Macro_GetDisconnectUIText("logReason277")
    if (code = "278")
        return Macro_GetDisconnectUIText("logReason278")
    if (code = "273")
        return Macro_GetDisconnectUIText("logReason273")
    return Macro_GetDisconnectUIText("logReason")
}

Macro_GetDisconnectCodeTitle() {
    code := Macro_GetDisconnectDisplayCode()
    if (code != "")
        return (Macro_GetWindowsUILanguage() = "ko") ? "🚨 ROBLOX " . code . " 감지" : "🚨 ROBLOX " . code . " DETECTED"
    return Macro_GetDisconnectUIText("title")
}

Macro_GetDisconnectDisplayCode() {
    global disconnectLogDiagSignal, disconnectLogDiagCode
    return (disconnectLogDiagSignal && disconnectLogDiagCode != "") ? disconnectLogDiagCode : ""
}

Macro_GetVisibleReconnectReason() {
    code := Macro_GetDisconnectDisplayCode()
    if (code = "")
        return Macro_GetDisconnectUIText("visibleReason")
    if (Macro_GetWindowsUILanguage() = "ko")
        return "Roblox " . code . " 재연결 화면이 표시된 클라이언트를 찾았습니다."
    return "A Roblox client is visibly showing a " . code . " reconnect screen."
}

Macro_BeginDisconnectIncident(reasonText := "") {
    global disconnectIncidentStartTick, disconnectIncidentDetectedTime
    global disconnectIncidentReasonText, disconnectIncidentCode, disconnectIncidentLogPattern
    global disconnectIncidentTimeline, disconnectLogDiagCode, disconnectLogDiagPattern
    global disconnectAlertActive, disconnectAlertStage
    global connectionRecoveryBusy, connectionRecoveryPending
    global disconnectHiddenScanPending, disconnectHiddenScanActive, disconnectManualCheckBusy
    global fixedPointModalDebugReconnectPending

    terminalStage := (disconnectAlertStage = "Reconnected" || disconnectAlertStage = "Failed")
    activeTransaction := (connectionRecoveryBusy || connectionRecoveryPending
        || disconnectHiddenScanActive || disconnectManualCheckBusy || fixedPointModalDebugReconnectPending
        || (disconnectAlertActive && (disconnectAlertStage = "Checking"
            || disconnectAlertStage = "Confirmed" || disconnectAlertStage = "Reconnecting")))

    ; Do not overwrite the timeline for a transaction already being inspected/reconnected.
    if (disconnectIncidentStartTick > 0 && !terminalStage
        && (activeTransaction || disconnectHiddenScanPending))
        return false

    disconnectIncidentStartTick := A_TickCount
    disconnectIncidentDetectedTime := Macro_Format12HourCurrentTime(A_Now)
    disconnectIncidentReasonText := reasonText
    disconnectIncidentCode := disconnectLogDiagCode
    disconnectIncidentLogPattern := disconnectLogDiagPattern
    disconnectIncidentTimeline := []
    Macro_RecordDisconnectProcessStep("detected", disconnectIncidentDetectedTime)
    return true
}

Macro_RecordDisconnectProcessStep(stepKey, eventTime := "") {
    global disconnectIncidentStartTick, disconnectIncidentTimeline

    if (disconnectIncidentStartTick <= 0)
        return false

    if (eventTime = "")
        eventTime := Macro_Format12HourCurrentTime(A_Now)
    stepLabel := Macro_GetDisconnectProcessStepLabel(stepKey)
    if (stepLabel = "")
        return false

    if (disconnectIncidentTimeline.Length > 0) {
        lastStep := disconnectIncidentTimeline[disconnectIncidentTimeline.Length]
        if (lastStep["key"] = stepKey && lastStep["time"] = eventTime)
            return false
    }

    disconnectIncidentTimeline.Push(Map(
        "key", stepKey,
        "label", stepLabel,
        "time", eventTime
    ))
    while (disconnectIncidentTimeline.Length > 12)
        disconnectIncidentTimeline.RemoveAt(1)
    return true
}

Macro_GetDisconnectProcessStepLabel(stepKey) {
    isKorean := (Macro_GetWindowsUILanguage() = "ko")
    switch stepKey {
        case "detected":
            return isKorean ? "디스커넥트 신호 감지" : "Disconnect signal detected"
        case "modal_scan":
            return isKorean ? "자동 모달 검사 시작" : "Automatic modal scan started"
        case "modal_confirmed":
            return isKorean ? "재연결 모달 확인" : "Reconnect modal confirmed"
        case "modal_not_found":
            return isKorean ? "검사 완료: 모달 미발견" : "Scan completed: modal not found"
        case "reconnect_click":
            return isKorean ? "재연결 버튼 클릭" : "Reconnect button clicked"
        case "click_failed":
            return isKorean ? "재연결 버튼 클릭 실패" : "Reconnect button click failed"
        case "complete":
            return isKorean ? "재연결 완료 확인" : "Reconnect completion confirmed"
        case "failed":
            return isKorean ? "재연결 실패 확인" : "Reconnect failure confirmed"
        case "automatic_restart_recovered":
            return isKorean ? "게임 자체 재실행 후 로그 접속 확인 — 디스커넥트 판정 취소" : "Game-managed restart joined successfully — disconnect canceled"
    }
    return ""
}

Macro_GetDisconnectCompletedBody(reasonText := "", extraDetails := "") {
    global disconnectIncidentReasonText
    global fixedPointModalDebugLastConfirmedResult

    isKorean := (Macro_GetWindowsUILanguage() = "ko")
    ; Keep the main cause, game identity, attempt totals and current completion time.
    ; The global numbered "success" history is intentionally omitted; recent
    ; completion times are shown per selected game in the disconnect monitor instead.
    if (disconnectIncidentReasonText != "")
        reasonText := disconnectIncidentReasonText
    else if (reasonText = "")
        reasonText := Macro_GetDisconnectLogReasonText()

    report := Macro_GetDisconnectAlertBody(reasonText)

    modalSection := (isKorean
        ? "모달 검사 결과: 재연결 모달을 확인하고 재연결 완료를 확인했습니다."
        : "Modal inspection result: the reconnect modal was confirmed and reconnection completed.")
    modalDiagnostic := Macro_GetFixedPointModalStoredDiagText(fixedPointModalDebugLastConfirmedResult)
    if (modalDiagnostic != "")
        modalSection .= "`n" . (isKorean ? "모달 진단: " : "Modal diagnostics: ") . modalDiagnostic

    if (extraDetails != "")
        extraDetails := (isKorean ? "추가 정보:`n" : "Additional details:`n") . extraDetails

    ; The original detection section is omitted because its raw log phrase
    ; duplicates the cause/diagnostic information already shown in the report.
    report .= "`n`n" . modalSection
    if (extraDetails != "")
        report .= "`n`n" . extraDetails
    return report
}

Macro_GetConfirmedReconnectBody() {
    global disconnectAlertDetectedHwnd, fixedPointModalDebugLastConfirmedResult
    global disconnectAlertStage

    ; Shared by "Confirmed" (modal found) and "Reconnected" (recovery completed).
    ; The instruction to reconnect belongs only to the pre-reconnect stage.
    isCompleted := (disconnectAlertStage = "Reconnected")
    code := Macro_GetDisconnectDisplayCode()
    if (isCompleted) {
        if (code != "") {
            if (Macro_GetWindowsUILanguage() = "ko")
                statusText := "Roblox " . code . " 재연결이 정상적으로 완료되었습니다."
            else
                statusText := "Roblox " . code . " reconnected successfully."
        } else {
            statusText := Macro_GetDisconnectUIText("reconnected")
        }
    } else if (code != "") {
        if (Macro_GetWindowsUILanguage() = "ko")
            statusText := "Roblox " . code . " 재연결 화면을 확인했습니다."
        else
            statusText := "Roblox " . code . " reconnect screen confirmed."
    } else {
        statusText := Macro_GetDisconnectUIText("confirmed")
    }

    gameName := Macro_GetDisconnectAlertGameName()
    if (gameName = "" && disconnectAlertDetectedHwnd)
        Macro_EnsureGameIdentityCached(disconnectAlertDetectedHwnd)
    if (gameName = "")
        gameName := Macro_GetDisconnectAlertGameName()
    if (gameName = "")
        gameName := Macro_GetGameStatusUIText("otherGame")

    resultText := Macro_GetFixedPointModalStoredDiagText(fixedPointModalDebugLastConfirmedResult)
    if (resultText != "")
        resultText := "`n" . resultText

    tailText := isCompleted ? "" : Macro_GetDisconnectUIText("confirmedTail")
    username := Macro_GetDisconnectAlertUsername()
    usernameLine := Macro_GetDistinctDisconnectUsernameLine(gameName, username, true)
    return statusText . "`n" . Macro_GetDisconnectUIText("gameName") . ": " . gameName
        . usernameLine . resultText . tailText
}
Macro_GetDisconnectAlertGameName() {
    global disconnectAlertDetectedHwnd, disconnectDiagTargetHwnd
    global gameIdentityByPid, gameIdentityLogState
    global disconnectLogDiagFile, disconnectLogSignalFiles, disconnectLogDiagSignal
    global disconnectLogDiagMappedPids

    candidates := []
    targetHwnd := disconnectAlertDetectedHwnd ? disconnectAlertDetectedHwnd : disconnectDiagTargetHwnd
    if (targetHwnd && WinExist("ahk_id " . targetHwnd)) {
        try {
            pid := WinGetPID("ahk_id " . targetHwnd)
            if (pid && gameIdentityByPid.Has(pid))
                candidates.Push(gameIdentityByPid[pid])
        } catch {
        }
    }

    if (disconnectLogDiagSignal) {
        if (disconnectLogDiagMappedPids != "") {
            for _, pidText in StrSplit(disconnectLogDiagMappedPids, ",") {
                try pid := Integer(Trim(pidText))
                catch
                    pid := 0
                if (pid && gameIdentityByPid.Has(pid))
                    candidates.Push(gameIdentityByPid[pid])
            }
        }

        paths := []
        if (disconnectLogDiagFile != "")
            paths.Push(disconnectLogDiagFile)
        for _, path in disconnectLogSignalFiles {
            if (path != disconnectLogDiagFile)
                paths.Push(path)
        }
        for _, path in paths {
            if (gameIdentityLogState.Has(path))
                candidates.Push(gameIdentityLogState[path])
        }
    }

    ; Prefer any active game ID. If unavailable, use the last game IDs preserved
    ; by the session parser before it cleared them on a return to the Roblox app.
    for _, identity in candidates {
        gameName := Macro_GetDisconnectAlertTitleFromIdentity(identity, false)
        if (gameName != "")
            return gameName
    }
    for _, identity in candidates {
        gameName := Macro_GetDisconnectAlertTitleFromIdentity(identity, true)
        if (gameName != "")
            return gameName
    }
    return ""
}

Macro_GetDisconnectAlertTitleFromIdentity(identity, useLastGame := false) {
    if (!IsObject(identity))
        return ""

    if (useLastGame) {
        placeId := identity.HasOwnProp("lastGamePlaceId") ? identity.lastGamePlaceId : ""
        universeId := identity.HasOwnProp("lastGameUniverseId") ? identity.lastGameUniverseId : ""
    } else {
        placeId := identity.HasOwnProp("placeId") ? identity.placeId : ""
        universeId := identity.HasOwnProp("universeId") ? identity.universeId : ""
    }
    if (!useLastGame && placeId != "" && identity.HasOwnProp("name")) {
        cachedName := Trim(identity.name . "")
        if (cachedName != "" && cachedName != "Other Game")
            return cachedName
    }
    return Macro_ResolveDisconnectAlertGameTitle(placeId, universeId)
}

Macro_ResolveDisconnectAlertGameTitle(placeId, universeId := "") {
    global gameNameByUniverseId, gameUniverseByPlaceId

    placeId := Trim(placeId . "")
    universeId := Trim(universeId . "")
    if (placeId = "")
        return ""
    if (universeId = "" && gameUniverseByPlaceId.Has(placeId))
        universeId := gameUniverseByPlaceId[placeId]
    if (universeId != "" && gameNameByUniverseId.Has(universeId))
        return gameNameByUniverseId[universeId]

    gameName := Macro_ResolveRobloxGameName(placeId, universeId)
    return (gameName = "Other Game") ? "" : gameName
}

Macro_GetDisconnectAlertUsername() {
    global disconnectAlertDetectedHwnd, disconnectDiagTargetHwnd
    global gameIdentityByPid, gameIdentityLogState
    global disconnectLogDiagFile, disconnectLogSignalFiles, disconnectLogDiagSignal
    global disconnectLogDiagMappedPids

    candidates := []
    targetHwnd := disconnectAlertDetectedHwnd ? disconnectAlertDetectedHwnd : disconnectDiagTargetHwnd
    if (targetHwnd && WinExist("ahk_id " . targetHwnd)) {
        try {
            pid := WinGetPID("ahk_id " . targetHwnd)
            if (pid && gameIdentityByPid.Has(pid)) {
                identity := gameIdentityByPid[pid]
                if (IsObject(identity) && identity.HasOwnProp("hwnd") && identity.hwnd = targetHwnd)
                    candidates.Push(identity)
            }
        } catch {
        }
    }

    if (disconnectLogDiagSignal) {
        if (disconnectLogDiagMappedPids != "") {
            for _, pidText in StrSplit(disconnectLogDiagMappedPids, ",") {
                try pid := Integer(Trim(pidText))
                catch
                    pid := 0
                if (pid && gameIdentityByPid.Has(pid))
                    candidates.Push(gameIdentityByPid[pid])
            }
        }

        paths := []
        if (disconnectLogDiagFile != "")
            paths.Push(disconnectLogDiagFile)
        for _, path in disconnectLogSignalFiles {
            if (path != disconnectLogDiagFile)
                paths.Push(path)
        }
        for _, path in paths {
            if (gameIdentityLogState.Has(path))
                candidates.Push(gameIdentityLogState[path])
        }
    }

    ; Search every candidate for the actual Roblox username before considering
    ; any cached account/display name as a fallback.
    for _, identity in candidates {
        username := Macro_GetCachedRobloxUsernameFromIdentity(identity, false)
        if (username != "")
            return username
    }
    for _, identity in candidates {
        accountName := Macro_GetCachedRobloxUsernameFromIdentity(identity, true)
        if (accountName != "")
            return accountName
    }
    return ""
}

Macro_GetCachedRobloxUsernameFromIdentity(identity, includeAccountName := true) {
    global robloxAccountUsernameByUserId, robloxAccountDisplayNameByUserId

    if (!IsObject(identity))
        return ""

    if (identity.HasOwnProp("username")) {
        username := Trim(identity.username . "")
        if (username != "")
            return username
    }

    if (identity.HasOwnProp("userId")) {
        userId := Trim(identity.userId . "")
        if (userId != "" && robloxAccountUsernameByUserId.Has(userId)) {
            username := Trim(robloxAccountUsernameByUserId[userId] . "")
            if (username != "")
                return username
        }
    }

    if (!includeAccountName)
        return ""

    if (identity.HasOwnProp("accountName")) {
        accountName := Trim(identity.accountName . "")
        if (accountName != "")
            return accountName
    }

    if (identity.HasOwnProp("userId")) {
        userId := Trim(identity.userId . "")
        if (userId != "" && robloxAccountDisplayNameByUserId.Has(userId))
            return Trim(robloxAccountDisplayNameByUserId[userId] . "")
    }

    return ""
}

Macro_GetDistinctDisconnectUsernameLine(gameName, username, leadingNewline := false) {
    username := Trim(username . "")
    if (username = "")
        return ""

    gameKey := StrLower(Trim(gameName . ""))
    if (gameKey != "" && gameKey = StrLower(username))
        return ""

    line := Macro_GetDisconnectUIText("username") . ": " . username
    return leadingNewline ? "`n" . line : line . "`n"
}

Macro_RefreshDisconnectAlertGameName(*) {
    global disconnectAlertActive, disconnectAlertStage, disconnectLogDiagSignal
    global disconnectAlertDetectedHwnd, disconnectAlertReason
    global disconnectAlertBody, disconnectAlertGui

    if (!disconnectAlertActive || !IsObject(disconnectAlertBody) || !IsObject(disconnectAlertGui))
        return

    try {
        if (disconnectAlertStage = "Signal" && (disconnectLogDiagSignal || disconnectAlertDetectedHwnd)) {
            reasonText := disconnectLogDiagSignal ? Macro_GetDisconnectLogReasonText() : disconnectAlertReason
            disconnectAlertBody.Text := Macro_GetDisconnectAlertBody(reasonText)
        } else if (disconnectAlertStage = "Confirmed") {
            disconnectAlertBody.Text := Macro_GetConfirmedReconnectBody()
        } else
            return
        if (DllCall("user32\IsWindowVisible", "Ptr", disconnectAlertGui.Hwnd))
            Macro_ResizeDisconnectAlert()
    } catch {
    }
}

Macro_ShowDisconnectAlertSafely(reasonText := "Roblox disconnect detected.", detectedHwnd := 0, freshLogSignal := false) {
    global disconnectAlertGui, disconnectAlertActive, disconnectAlertStage
    global disconnectGracePending

    ; Suppress legacy/log-triggered alert callers while the log/PID-only grace
    ; transaction is still deciding whether the game already recovered.
    if (freshLogSignal && disconnectGracePending)
        return false

    try {
        Macro_ShowDisconnectAlert(reasonText, detectedHwnd, freshLogSignal)
        return true
    } catch {
        ; If an old GUI/control became invalid, rebuild the alert once.  The
        ; automatic modal scan must continue even if both display attempts fail.
        try {
            if (IsObject(disconnectAlertGui) && disconnectAlertGui.Hwnd)
                disconnectAlertGui.Destroy()
        } catch {
        }
        disconnectAlertGui := ""
        disconnectAlertActive := false
        disconnectAlertStage := ""
        try {
            Macro_ShowDisconnectAlert(reasonText, detectedHwnd, freshLogSignal)
            return true
        } catch {
            return false
        }
    }
}

Macro_ShowDisconnectAlert(reasonText := "Roblox 277 detected.", detectedHwnd := 0, freshLogSignal := false) {
    global disconnectAlertRaisePending
    global disconnectAlertF6Diag
    global disconnectAlertGui, disconnectAlertTitle, disconnectAlertBody
    global disconnectAlertPrimaryButton, disconnectAlertDismissButton
    global disconnectAlertActive, disconnectAlertStage, disconnectAlertLastTick
    global disconnectAlertDetectedHwnd, disconnectAlertReason, disconnectAlertOriginalForeground
    global disconnectAlertLastRecoveryAttempts, disconnectAlertLastSuccessTime
    global disconnectAlertDetectionSource, disconnectDiagTargetHwnd, disconnectDiagTargetPid
    global disconnectDiagScanTime
    global disconnectAlertHoverHwnd, disconnectAlertHoverFullscreen, disconnectAlertHoverVisible
    global DISCONNECT_ALERT_WIDTH, DISCONNECT_ALERT_HEIGHT, disconnectAlertLastSizeKey
    global disconnectAlertPositionTargetHwnd, disconnectAlertLastGeometryHwnd, disconnectAlertLastGeometryKey
    global disconnectAlertLastPaintKey
    global connectionRecoveryBusy, connectionRecoveryPending
    global disconnectManualCheckBusy, disconnectHiddenScanActive
    global fixedPointModalDebugReconnectPending

    nowTick := A_TickCount
    currentForeground := WinExist("A")

    ; 화면검사/로그검사 어느 경로에서 생성되었든 동일하게, 마우스가 올라간 Roblox 창을
    ; 기준으로 감지창이 따라가도록 추적 타이머를 보장합니다.
    SetTimer(Macro_MaintainDisconnectAlertZOrder, 120)

    ; Localize the default reason before deciding whether an existing alert can be reused.
    if (reasonText = "Roblox 277 detected.")
        reasonText := Macro_GetDisconnectUIText("defaultReason")

    ; Keep genuinely active manual/reconnect work stable. However, a new log signal
    ; must not disappear behind an old Checking/Confirmed/Reconnecting alert stage.
    ; Record its reason and let the queued hidden scan resume after active work ends.
    if (disconnectAlertActive && (disconnectAlertStage = "Checking"
        || disconnectAlertStage = "Confirmed"
        || disconnectAlertStage = "Reconnecting")) {
        if (freshLogSignal) {
            disconnectAlertReason := reasonText
            disconnectAlertDetectedHwnd := detectedHwnd
            disconnectAlertDetectionSource := "log"
            disconnectDiagTargetHwnd := 0
            disconnectDiagTargetPid := 0
            disconnectDiagScanTime := Macro_Format12HourCurrentTime(A_Now)
        }
        if (!freshLogSignal || connectionRecoveryBusy || connectionRecoveryPending
            || disconnectManualCheckBusy || disconnectHiddenScanActive
            || fixedPointModalDebugReconnectPending)
            return

        ; No transaction is currently executing; recover the stale alert into a new signal state.
        disconnectAlertStage := "Signal"
        disconnectAlertLastRecoveryAttempts := 0
        disconnectAlertLastSuccessTime := ""
    }

    ; Detection source is explicit so the alert can show what actually triggered it.
    if (detectedHwnd) {
        if (disconnectLogDiagSignal)
            disconnectAlertDetectionSource := "screen+log"
        else
            disconnectAlertDetectionSource := "screen"
        disconnectDiagTargetHwnd := detectedHwnd
        disconnectDiagTargetPid := 0
        try disconnectDiagTargetPid := WinGetPID("ahk_id " . detectedHwnd)
    } else {
        disconnectAlertDetectionSource := "log"
        disconnectDiagTargetHwnd := 0
        disconnectDiagTargetPid := 0
    }
    disconnectDiagScanTime := Macro_Format12HourCurrentTime(A_Now)

    ; Reconnected means the previous incident is complete. A fresh visible/log
    ; signal is therefore a new incident and starts with zero attempts.
    if (disconnectAlertActive && disconnectAlertStage = "Reconnected") {
        disconnectAlertStage := "Signal"
        disconnectAlertDetectedHwnd := detectedHwnd
        disconnectAlertReason := reasonText
        disconnectAlertLastRecoveryAttempts := 0
        disconnectAlertLastSuccessTime := ""
    } else if (disconnectAlertActive && disconnectAlertStage = "Failed" && !freshLogSignal) {
        ; Keep a failed transaction waiting for the user's decision. Repeated
        ; scans of the same unresolved 277 screen must not restart it. A genuinely
        ; fresh log event is different and is allowed to start a new signal state.
        return
    } else if (disconnectAlertActive && disconnectAlertStage = "Failed" && freshLogSignal) {
        disconnectAlertStage := "Signal"
        disconnectAlertLastRecoveryAttempts := 0
        disconnectAlertLastSuccessTime := ""
        disconnectAlertDetectedHwnd := detectedHwnd
        disconnectAlertReason := reasonText
    } else {
        disconnectAlertDetectedHwnd := detectedHwnd
        disconnectAlertReason := reasonText
        if (!disconnectAlertActive)
            disconnectAlertStage := "Signal"
    }

    if (currentForeground
        && (!IsObject(disconnectAlertGui) || !disconnectAlertGui.Hwnd || currentForeground != disconnectAlertGui.Hwnd)) {
        disconnectAlertOriginalForeground := currentForeground
    }

    if (disconnectAlertActive && IsObject(disconnectAlertGui)) {
        try {
            disconnectAlertTitle.Text := Macro_GetDisconnectCodeTitle()
            disconnectAlertBody.Text := Macro_GetDisconnectAlertBody(disconnectAlertReason)
            Macro_UpdateFixedPointModalDebugText()
            Macro_ResizeDisconnectAlert()
            disconnectAlertPrimaryButton.Enabled := true
            disconnectAlertPrimaryButton.Text := Macro_GetDisconnectUIText("inspect")
            disconnectAlertDismissButton.Text := Macro_GetDisconnectUIText("dismiss")
            disconnectAlertLastTick := nowTick
            SetTimer(Macro_EnsureDisconnectAlertVisible, -80)
            ; A fresh update is a one-shot global raise. It stays raised until
            ; the user actually clicks another window; mouse movement alone
            ; must never demote the alert.
            disconnectAlertRaisePending := true
            disconnectAlertHoverHwnd := 0
            disconnectAlertHoverFullscreen := false
            disconnectAlertHoverVisible := false
            Macro_RaiseDisconnectAlertOnUpdate()
            ; Macro_ResizeDisconnectAlert() already calculates the final height
            ; and positions the alert. Do not overwrite it with the old fixed height.
            return
        } catch {
            disconnectAlertActive := false
            disconnectAlertGui := ""
            disconnectAlertLastSizeKey := ""
            disconnectAlertLastPaintKey := ""
        }
    }

    disconnectAlertGui := Gui("-Caption +ToolWindow +Border -DPIScale")
    disconnectAlertGui.BackColor := "1D1D1D"
    disconnectAlertGui.MarginX := 14
    disconnectAlertGui.MarginY := 10

    disconnectAlertGui.SetFont("s11", "Segoe UI")
    ; F6 진단은 메시지창의 최상단에 고정합니다.
    disconnectAlertF6Diag := disconnectAlertGui.Add("Text", "x16 y10 w528 h78 cFFFF00 +Wrap", "")
    disconnectAlertF6Diag.Visible := false
    disconnectAlertTitle := disconnectAlertGui.Add("Text", "x16 y94 w528 h28 cFFFFFF", Macro_GetDisconnectCodeTitle())

    disconnectAlertGui.SetFont("s9", "Segoe UI")
    disconnectAlertBody := disconnectAlertGui.Add("Text", "x16 y128 w528 h520 cFFFFFF +Wrap", Macro_GetDisconnectAlertBody(disconnectAlertReason))

    disconnectAlertPrimaryButton := disconnectAlertGui.Add("Button", "x145 y530 w115 h34", Macro_GetDisconnectUIText("inspect"))
    disconnectAlertDismissButton := disconnectAlertGui.Add("Button", "x270 y530 w90 h34", Macro_GetDisconnectUIText("dismiss"))

    disconnectAlertPrimaryButton.OnEvent("Click", Macro_DisconnectAlertPrimary)
    disconnectAlertDismissButton.OnEvent("Click", Macro_DisconnectAlertDismiss)
    disconnectAlertGui.OnEvent("Close", Macro_DisconnectAlertDismiss)

    disconnectAlertLastTick := nowTick
    disconnectAlertLastSizeKey := ""
    disconnectAlertLastPaintKey := ""
    disconnectAlertPositionTargetHwnd := 0
    disconnectAlertLastGeometryHwnd := 0
    disconnectAlertLastGeometryKey := ""
    disconnectAlertActive := true
    disconnectAlertRaisePending := true
    disconnectAlertHoverHwnd := 0
    disconnectAlertHoverFullscreen := false
    disconnectAlertHoverVisible := false

    ; Alert는 갱신 순간 한 번 전체 위로 올라갑니다. 이후에는 사용자의
    ; 실제 클릭을 기준으로 Roblox와의 상대 Z-order로 돌아갑니다.
    Macro_ResizeDisconnectAlert()
    Macro_RaiseDisconnectAlertOnUpdate()
    SetTimer(Macro_EnsureDisconnectAlertVisible, -80)
    Macro_SyncGameStatusPosition()
}


; =====================================================================
; 📐 Disconnect alert auto-size
;    The diagnostic body grows/shrinks with its displayed line count.
; =====================================================================
Macro_GetDisconnectAlertStatusWidth() {
    global STATUS_BASE_WIDTH, STATUS_BASE_W
    global disconnectAlertDetectedHwnd, fixedPointModalDebugTargetHwnd

    targetHwnd := disconnectAlertDetectedHwnd
    if (!targetHwnd)
        targetHwnd := fixedPointModalDebugTargetHwnd
    if (!targetHwnd)
        targetHwnd := WinActive("ahk_exe RobloxPlayerBeta.exe")
    if (!targetHwnd)
        targetHwnd := WinExist("ahk_exe RobloxPlayerBeta.exe")

    monitorW := A_ScreenWidth
    if (targetHwnd && WinExist("ahk_id " . targetHwnd)) {
        try {
            monitorIndex := Macro_GetMonitorFromWindow(targetHwnd)
            if (monitorIndex) {
                MonitorGet(monitorIndex, &monitorLeft, &monitorTop, &monitorRight, &monitorBottom)
                monitorW := monitorRight - monitorLeft
            }
        } catch {
        }
    }

    if (monitorW <= 1920)
        scale := 0.60
    else if (monitorW <= 2560)
        scale := 0.67
    else
        scale := monitorW / STATUS_BASE_W
    scale := Max(0.20, Min(scale, 2.50))
    return Round(STATUS_BASE_WIDTH * scale)
}

Macro_MeasureDisconnectAlertText(text, controlHwnd, wrapWidth := 0) {
    if (text = "" || !controlHwnd || wrapWidth <= 0)
        return {width:0, height:0}

    hdc := DllCall("user32\GetDC", "Ptr", controlHwnd, "Ptr")
    if (!hdc)
        return {width:0, height:0}
    hFont := DllCall("user32\SendMessageW", "Ptr", controlHwnd, "UInt", 0x0031, "Ptr", 0, "Ptr", 0, "Ptr")
    oldFont := 0
    if (hFont) {
        try {
            oldFont := DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", hFont, "Ptr")
        } catch {
        }
    }

    rect := Buffer(16, 0)
    NumPut("Int", 0, rect, 0)
    NumPut("Int", 0, rect, 4)
    NumPut("Int", wrapWidth, rect, 8)
    NumPut("Int", 0, rect, 12)
    measureText := StrReplace(StrReplace(text, "`r`n", "`n"), "`n", "`r`n")
    flags := 0x00000400 | 0x00000010 | 0x00000800 | 0x00002000 ; CALCRECT | WORDBREAK | NOPREFIX | EDITCONTROL
    measuredWidth := 0
    measuredHeight := 0
    try {
        DllCall("user32\DrawTextW", "Ptr", hdc, "Str", measureText, "Int", -1, "Ptr", rect.Ptr, "UInt", flags, "Int")
        measuredWidth := Max(0, NumGet(rect, 8, "Int") - NumGet(rect, 0, "Int"))
        measuredHeight := Max(0, NumGet(rect, 12, "Int") - NumGet(rect, 4, "Int"))
    } catch {
        measuredWidth := 0
        measuredHeight := 0
    }
    if (oldFont) {
        try {
            DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", oldFont, "Ptr")
        } catch {
        }
    }
    DllCall("user32\ReleaseDC", "Ptr", controlHwnd, "Ptr", hdc, "Int")
    if (measuredHeight <= 0) {
        estimatedLines := 0
        estimatedColumns := Max(1, Floor(wrapWidth / 12))
        for line in StrSplit(text, "`n")
            estimatedLines += Max(1, Ceil(StrLen(line) / estimatedColumns))
        measuredHeight := estimatedLines * 18
    }
    return {width:measuredWidth, height:measuredHeight}
}

Macro_RedrawDisconnectAlert(force := false) {
    global disconnectAlertGui, disconnectAlertTitle, disconnectAlertBody, disconnectAlertF6Diag
    global disconnectAlertLastPaintKey

    if (!IsObject(disconnectAlertGui) || !disconnectAlertGui.Hwnd)
        return

    try {
        titleText := IsObject(disconnectAlertTitle) ? disconnectAlertTitle.Text : ""
        bodyText := IsObject(disconnectAlertBody) ? disconnectAlertBody.Text : ""
        diagText := IsObject(disconnectAlertF6Diag) ? disconnectAlertF6Diag.Text : ""
        diagVisible := false
        try diagVisible := !!disconnectAlertF6Diag.Visible
        catch
            diagVisible := false
        visible := !!DllCall("user32\IsWindowVisible", "Ptr", disconnectAlertGui.Hwnd)
        x := 0, y := 0, w := 0, h := 0
        try WinGetPos(&x, &y, &w, &h, "ahk_id " . disconnectAlertGui.Hwnd)
        paintKey := visible . "|" . x . "|" . y . "|" . w . "|" . h
            . "|" . diagVisible . "|" . titleText . Chr(30) . bodyText . Chr(30) . diagText
        if (!force && paintKey = disconnectAlertLastPaintKey)
            return

        disconnectAlertLastPaintKey := paintKey
        ; Erase old glyph pixels and repaint child controls only after real changes.
        DllCall("user32\RedrawWindow", "Ptr", disconnectAlertGui.Hwnd,
            "Ptr", 0, "Ptr", 0, "UInt", 0x0185, "Int")
    } catch {
    }
}

Macro_ResizeDisconnectAlert() {
    global disconnectAlertGui, disconnectAlertBody, disconnectAlertF6Diag
    global disconnectAlertTitle, disconnectAlertPrimaryButton, disconnectAlertDismissButton
    global disconnectAlertDetectedHwnd, fixedPointModalDebugTargetHwnd
    global fixedPointModalDebugEnabled
    global DISCONNECT_ALERT_WIDTH, disconnectAlertLastSizeKey

    if (!IsObject(disconnectAlertGui) || !IsObject(disconnectAlertBody))
        return

    try {
        text := disconnectAlertBody.Text
        f6Mode := fixedPointModalDebugEnabled && IsObject(disconnectAlertF6Diag)
        diagText := f6Mode ? disconnectAlertF6Diag.Text : ""

        ; The alert width is fixed to the resolution-adaptive status-window
        ; width. Longer content wraps vertically rather than changing width.
        buttonGroupWidth := 115 + 12 + 90
        DISCONNECT_ALERT_WIDTH := Macro_GetDisconnectAlertStatusWidth()

        targetHwnd := disconnectAlertDetectedHwnd
        if (!targetHwnd)
            targetHwnd := fixedPointModalDebugTargetHwnd
        if (!targetHwnd)
            targetHwnd := WinActive("ahk_exe RobloxPlayerBeta.exe")
        if (!targetHwnd)
            targetHwnd := WinExist("ahk_exe RobloxPlayerBeta.exe")
        monitorIndex := 0
        if (targetHwnd && WinExist("ahk_id " . targetHwnd)) {
            try monitorIndex := Macro_GetMonitorFromWindow(targetHwnd)
        }
        if (!monitorIndex)
            monitorIndex := MonitorGetPrimary()
        try MonitorGetWorkArea(monitorIndex, &wl, &wt, &wr, &wb)
        catch {
            wl := 0, wt := 0, wr := A_ScreenWidth, wb := A_ScreenHeight
        }

        contentWidth := Max(1, DISCONNECT_ALERT_WIDTH - 32)

        ; Measure the actual wrapped control height using the same font/width.
        bodyMeasure := Macro_MeasureDisconnectAlertText(text, disconnectAlertBody.Hwnd, contentWidth)
        bodyH := Max(40, bodyMeasure.height + 16)

        diagH := 0
        if (f6Mode) {
            diagMeasure := Macro_MeasureDisconnectAlertText(diagText, disconnectAlertF6Diag.Hwnd, contentWidth)
            diagLineCount := Max(1, StrSplit(diagText, Chr(10)).Length)
            ; Three F6 rows need room for Windows font leading and the static
            ; control's internal padding, scaled to the actual measured font.
            diagH := Max(84, diagMeasure.height + 16, diagLineCount * 24 + 12)
            disconnectAlertF6Diag.Move(16, 10, contentWidth, diagH)
            disconnectAlertF6Diag.Visible := true
            titleY := 10 + diagH + 8
            bodyY := titleY + 28 + 8
        } else if (IsObject(disconnectAlertF6Diag)) {
            disconnectAlertF6Diag.Visible := false
            titleY := 12
            bodyY := 48
        }

        disconnectAlertTitle.Move(16, titleY, contentWidth, 28)

        ; Keep the complete measured message and controls inside the target
        ; monitor work area. The text normally fits without reaching this cap.
        buttonGapY := 12
        bottomPadding := 14
        maxBodyH := Max(40, (wb - wt - 16) - bodyY - buttonGapY - 34 - bottomPadding)
        if (bodyH > maxBodyH)
            bodyH := maxBodyH
        buttonY := bodyY + bodyH + buttonGapY
        totalH := buttonY + 34 + bottomPadding

        buttonX := Floor((DISCONNECT_ALERT_WIDTH - buttonGroupWidth) / 2)
        dismissX := buttonX + 115 + 12

        sizeKey := (f6Mode ? "F6" : "N6") . "|" . DISCONNECT_ALERT_WIDTH . "|" . bodyH
            . "|" . bodyY . "|" . diagH . "|" . diagText . "|" . totalH
        if (sizeKey = disconnectAlertLastSizeKey) {
            Macro_RedrawDisconnectAlert()
            return
        }
        disconnectAlertLastSizeKey := sizeKey

        disconnectAlertBody.Move(16, bodyY, contentWidth, bodyH)
        disconnectAlertPrimaryButton.Move(buttonX, buttonY, 115, 34)
        disconnectAlertDismissButton.Move(dismissX, buttonY, 90, 34)

        disconnectAlertGui.Show("w" . DISCONNECT_ALERT_WIDTH . " h" . totalH . " NoActivate")
        Macro_PositionDisconnectAlert(disconnectAlertGui, DISCONNECT_ALERT_WIDTH, totalH)
        Macro_SyncGameStatusPosition()
        Macro_RedrawDisconnectAlert(true)
    } catch {
    }
}

Macro_GetSelectedGameReconnectHistoryLine() {
    global gameStatusLastActiveRobloxHwnd, gameStatusTrackedHwnd

    ; Prefer the Roblox client currently in the foreground. If focus has moved
    ; to another app or to this monitor, use the last Roblox client selected.
    targetHwnd := 0
    try targetHwnd := WinActive("ahk_exe RobloxPlayerBeta.exe")
    catch
        targetHwnd := 0
    if (!targetHwnd || !WinExist("ahk_id " . targetHwnd))
        targetHwnd := gameStatusLastActiveRobloxHwnd
    if ((!targetHwnd || !WinExist("ahk_id " . targetHwnd))
        && gameStatusTrackedHwnd && WinExist("ahk_id " . gameStatusTrackedHwnd))
        targetHwnd := gameStatusTrackedHwnd

    if (!targetHwnd || !WinExist("ahk_id " . targetHwnd))
        return ""

    try {
        if (WinGetProcessName("ahk_id " . targetHwnd) != "RobloxPlayerBeta.exe")
            return ""
    } catch {
        return ""
    }

    gameName := ""
    try gameName := Trim(Macro_GetRobloxGameNameForHwnd(targetHwnd) . "")
    catch
        gameName := ""
    if (gameName = "")
        return ""

    ; Reconcile existing pending history only; do not alter game-detection logic.
    Macro_ReconcilePendingGameReconnectHistory(targetHwnd, gameName)
    excludeTime := Macro_GetSelectedGameHistoryExcludeTime(gameName, targetHwnd)
    historyText := Macro_GetRecentGameReconnectTimesText(gameName, excludeTime)
    if (historyText = "")
        return ""

    ; Identify which game's records are being shown, so records from two games
    ; can never appear to be part of the same history list.
    isKorean := (Macro_GetWindowsUILanguage() = "ko")
    gameLabel := isKorean ? "선택된 게임" : "Selected game"
    return gameLabel . ": " . gameName . "`n" . historyText
}

Macro_GetSelectedGameHistoryExcludeTime(gameName, targetHwnd) {
    global disconnectAlertStage, disconnectAlertLastSuccessTime
    global disconnectAlertDetectedHwnd, disconnectDiagTargetHwnd

    if (disconnectAlertStage != "Reconnected" || disconnectAlertLastSuccessTime = "")
        return ""

    completedHwnd := disconnectAlertDetectedHwnd ? disconnectAlertDetectedHwnd : disconnectDiagTargetHwnd
    if (completedHwnd && targetHwnd = completedHwnd)
        return disconnectAlertLastSuccessTime

    completedGameName := Macro_GetDisconnectAlertGameName()
    if (gameName != "" && completedGameName != ""
        && Macro_NormalizeReconnectGameKey(gameName) = Macro_NormalizeReconnectGameKey(completedGameName))
        return disconnectAlertLastSuccessTime
    return ""
}

Macro_RefreshDisconnectHistoryDisplayForSelectedRoblox() {
    global disconnectAlertActive, disconnectAlertGui, disconnectAlertBody
    global disconnectAlertStage, disconnectAlertReason, disconnectAlertLastSuccessTime
    global gameStatusLastActiveRobloxHwnd
    static lastDisplayKey := ""

    if (!disconnectAlertActive || !IsObject(disconnectAlertGui)
        || !IsObject(disconnectAlertBody)) {
        lastDisplayKey := ""
        return
    }

    targetHwnd := 0
    try targetHwnd := WinActive("ahk_exe RobloxPlayerBeta.exe")
    catch
        targetHwnd := 0
    if (!targetHwnd || !WinExist("ahk_id " . targetHwnd))
        targetHwnd := gameStatusLastActiveRobloxHwnd

    gameName := ""
    if (targetHwnd && WinExist("ahk_id " . targetHwnd)) {
        try {
            if (WinGetProcessName("ahk_id " . targetHwnd) = "RobloxPlayerBeta.exe")
                gameName := Trim(Macro_GetRobloxGameNameForHwnd(targetHwnd) . "")
        } catch {
            gameName := ""
        }
    }
    excludeTime := (gameName != "" && targetHwnd)
        ? Macro_GetSelectedGameHistoryExcludeTime(gameName, targetHwnd) : ""
    historyText := (gameName != "") ? Macro_GetRecentGameReconnectTimesText(gameName, excludeTime) : ""
    key := targetHwnd . "|" . Macro_NormalizeReconnectGameKey(gameName)
        . "|" . historyText . "|" . disconnectAlertStage
        . "|" . disconnectAlertLastSuccessTime . "|" . disconnectAlertReason
    if (key = lastDisplayKey)
        return

    reasonText := disconnectAlertReason
    if (reasonText = "")
        reasonText := Macro_GetDisconnectLogReasonText()

    try {
        if (disconnectAlertStage = "Reconnected")
            disconnectAlertBody.Text := Macro_GetDisconnectCompletedBody(reasonText)
        else
            disconnectAlertBody.Text := Macro_GetDisconnectAlertBody(reasonText)
        Macro_ResizeDisconnectAlert()
        lastDisplayKey := key
    } catch {
        lastDisplayKey := ""
    }
}

Macro_GetDisconnectAlertBody(reasonText) {
    global USER_ACTIVITY_TIMEOUT_MS
    global disconnectAlertStage, disconnectAlertActive
    global connectionRecoveryBusy, connectionRecoveryAttempts
    global disconnectAlertLastRecoveryAttempts, disconnectAlertLastSuccessTime
    global disconnectRecoveryTotalAttempts, disconnectRecoveryTotalSuccesses, disconnectRecoveryHistory
    global disconnectAlertDetectionSource
    global disconnectHiddenScanActive, disconnectHiddenScanIndex, disconnectHiddenScanTotal, disconnectHiddenScanPending
    global disconnectHiddenScanCooldownUntil, disconnectHiddenScanLastMiss
    global fixedPointModalDebugReconnectPending
    global disconnectScreenDiagValid, disconnectScreenDiagPassed, disconnectScreenDarkCount, disconnectScreenDarkTotal
    global AUTO_HIDDEN_SCAN_DELAY_SEC
    global disconnectButtonDiagValid, disconnectButtonDiagPassed, disconnectButtonWhiteCount, disconnectButtonWhiteTotal
    global disconnectButtonDarkAroundCount, disconnectButtonDarkAroundTotal, disconnectButtonBandHits
    global disconnectDiagTargetHwnd, disconnectDiagTargetPid
    global disconnectLogDiagSignal, disconnectLogDiagPattern
    global disconnectAlertDetectedHwnd

    userActive := Macro_IsUserActiveAnywhere(AUTO_HIDDEN_SCAN_DELAY_SEC * 1000)

    if (disconnectAlertStage = "Reconnected") {
        stateLine := Macro_GetDisconnectUIText("completed")
    } else if (disconnectAlertStage = "Failed") {
        stateLine := Macro_GetDisconnectUIText("failed")
    } else if (connectionRecoveryBusy) {
        if (userActive)
            stateLine := Macro_GetDisconnectUIText("autoPaused")
        else
            stateLine := Macro_GetDisconnectUIText("notPlaying")
    } else if (userActive) {
        stateLine := Macro_GetDisconnectUIText("playing")
    } else if (disconnectHiddenScanPending) {
        stateLine := Macro_GetDisconnectUIText("notPlaying")
    } else {
        stateLine := Macro_GetDisconnectUIText("waiting")
    }

    currentAttempts := connectionRecoveryAttempts
    if (connectionRecoveryBusy || currentAttempts > 0)
        attemptLine := Macro_GetDisconnectUIText("thisAttempts") . currentAttempts . "`n"
    else if (disconnectAlertLastRecoveryAttempts > 0)
        attemptLine := Macro_GetDisconnectUIText("lastAttempts") . disconnectAlertLastRecoveryAttempts . "`n"
    else
        attemptLine := ""

    totalLine := Macro_GetDisconnectUIText("totalAttempts") . disconnectRecoveryTotalAttempts
        . "`n" . Macro_GetDisconnectUIText("totalSuccesses") . disconnectRecoveryTotalSuccesses

    ; Show recent completion timestamps for the currently selected Roblox game
    ; in this consolidated monitor window. If the current completion time is
    ; already shown above, omit that same timestamp from the recent list.
    historyLine := Macro_GetSelectedGameReconnectHistoryLine()

    if (disconnectAlertStage = "Reconnected" && disconnectAlertLastSuccessTime != "")
        successLine := Macro_GetDisconnectUIText("completedTime") . disconnectAlertLastSuccessTime
    else
        successLine := ""

    ; TrayTip now owns the transient recovery-progress messages.
    ; Do not repeat the same progress text inside this diagnostic window.
    recoveryStatusLine := ""

    ; ---------------------------------------------------------
    ; 🔎 Detection diagnostics
    ; ---------------------------------------------------------
    sourceText := ""
    if (disconnectAlertDetectionSource = "screen+log")
        sourceText := Macro_GetDisconnectUIText("screenAndLog")
    else if (disconnectAlertDetectionSource = "screen")
        sourceText := Macro_GetDisconnectUIText("screen")
    else if (disconnectAlertDetectionSource = "log")
        sourceText := Macro_GetDisconnectUIText("log")
    else
        sourceText := "-"

    diagnosticsLine := Macro_GetDisconnectUIText("source") . ": " . sourceText . "`n"
    if (disconnectAlertStage != "Reconnected" && disconnectLogDiagSignal && disconnectLogDiagPattern != "")
        diagnosticsLine .= Macro_GetDisconnectUIText("logPhrase") . ": " . disconnectLogDiagPattern . "`n"

    ; 화면검사의 개별 검사점/버튼 샘플 결과는 일반 메시지창에서는 표시하지 않습니다.
    ; F6 진단 영역에서만 실시간으로 확인합니다.

    if (disconnectDiagTargetHwnd) {
        diagnosticsLine .= Macro_GetDisconnectUIText("targetWindow") . ": 0x" . Format("{:X}", disconnectDiagTargetHwnd)
        if (disconnectDiagTargetPid)
            diagnosticsLine .= "  /  " . Macro_GetDisconnectUIText("targetPid") . ": " . disconnectDiagTargetPid
        diagnosticsLine .= "`n"
    }

    countdownLine := ""
    retryLine := ""
    if (disconnectAlertStage = "Signal" && (disconnectHiddenScanPending || fixedPointModalDebugReconnectPending)) {
        delayMs := Max(0, AUTO_HIDDEN_SCAN_DELAY_SEC * 1000)
        idleWaitMs := (delayMs > 0) ? Max(0, delayMs + 1 - A_TimeIdlePhysical) : 0
        if (idleWaitMs <= 0) {
            countdownLine := (fixedPointModalDebugReconnectPending
                ? Macro_GetDisconnectUIText("autoReconnectNow")
                : Macro_GetDisconnectUIText("autoScanNow")) . "`n"
        } else {
            remainingSec := Ceil(idleWaitMs / 1000)
            if (remainingSec < 1)
                remainingSec := 1
            countdownLabel := fixedPointModalDebugReconnectPending
                ? Macro_GetDisconnectUIText("autoReconnectCountdown")
                : Macro_GetDisconnectUIText("autoScanCountdown")
            if (Macro_GetWindowsUILanguage() = "ko")
                countdownLine := countdownLabel . remainingSec . "초`n"
            else
                countdownLine := countdownLabel . remainingSec . " sec`n"
        }
    }
    if (disconnectAlertStage = "Signal" && disconnectHiddenScanLastMiss)
        retryLine := Macro_GetDisconnectUIText("hiddenScanNotFound") . "`n"

    gameNameLine := ""
    gameUsernameLine := ""
    if (disconnectLogDiagSignal || disconnectAlertDetectedHwnd || disconnectDiagTargetHwnd) {
        gameName := Macro_GetDisconnectAlertGameName()
        if (gameName = "" && disconnectLogDiagSignal)
            gameName := Macro_GetGameStatusUIText("otherGame")
        if (gameName != "")
            gameNameLine := Macro_GetDisconnectUIText("gameName") . ": " . gameName . "`n"

        username := Macro_GetDisconnectAlertUsername()
        gameUsernameLine := Macro_GetDistinctDisconnectUsernameLine(gameName, username)
    }

    body := reasonText . "`n`n" . gameNameLine . gameUsernameLine . countdownLine . retryLine . stateLine . "`n`n"
        . attemptLine
        . totalLine . "`n`n"
        . diagnosticsLine

    if (successLine != "" && disconnectAlertStage = "Reconnected")
        body .= "`n" . successLine
    if (historyLine != "")
        body .= "`n`n" . historyLine

    if (disconnectAlertStage = "Signal" && userActive)
        body .= "`n`n" . Macro_GetDisconnectUIText("manualGuide")

    return body
}

Macro_EnsureDisconnectAlertVisible(*) {
    global disconnectAlertGui, disconnectAlertActive, disconnectAlertRaisePending

    if (!disconnectAlertActive || !disconnectAlertRaisePending || !IsObject(disconnectAlertGui))
        return

    try {
        hwnd := disconnectAlertGui.Hwnd
        if (!hwnd || !WinExist("ahk_id " . hwnd))
            return
        visible := !!DllCall("user32\IsWindowVisible", "Ptr", hwnd)
        if (!visible)
            disconnectAlertGui.Show("NoActivate")
        DllCall("user32\SetWindowPos", "Ptr", hwnd, "Ptr", -1,
            "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0013)
        DllCall("user32\UpdateWindow", "Ptr", hwnd)
    } catch {
    }
}

Macro_RaiseDisconnectAlertOnUpdate() {
    global disconnectAlertGui, disconnectAlertRaisePending

    if (!IsObject(disconnectAlertGui))
        return

    try {
        hwnd := disconnectAlertGui.Hwnd
        if (!hwnd || !WinExist("ahk_id " . hwnd))
            return

        ; 상태창처럼 표시 상태를 안정적으로 유지한다.
        ; 감지창은 활성 Roblox보다 위에 있어야 하므로 TOPMOST를 유지한다.
        ; 포커스는 절대 가져오지 않는다.
        disconnectAlertRaisePending := true
        DllCall("user32\SetWindowPos"
            , "Ptr", hwnd
            , "Ptr", -1
            , "Int", 0, "Int", 0, "Int", 0, "Int", 0
            , "UInt", 0x0013) ; NOACTIVATE | SHOWWINDOW | NOMOVE | NOSIZE
        DllCall("user32\UpdateWindow", "Ptr", hwnd)
    } catch {
    }
}

; =====================================================================
; 🔝 Disconnect alert Z-order
;    1) Fresh update -> one-shot TOPMOST, without taking focus.
;    2) A Roblox window under the pointer becomes the selected position target.
;    3) The selected Roblox window geometry is followed while the pointer is elsewhere.
;    4) Geometry tracking never activates windows or changes Z-order by itself.
; =====================================================================
Macro_MaintainDisconnectAlertZOrder(*) {
    global disconnectAlertGui, disconnectAlertActive
    global disconnectAlertHoverHwnd, disconnectAlertHoverFullscreen, disconnectAlertHoverVisible
    global disconnectAlertPositionTargetHwnd, disconnectAlertLastGeometryHwnd, disconnectAlertLastGeometryKey
    global DISCONNECT_ALERT_WIDTH

    if (!disconnectAlertActive || !IsObject(disconnectAlertGui))
        return

    ; This timer remains active with the disconnect monitor, even when the game
    ; selector is hidden. Refresh only the display text when the selected Roblox
    ; client or its stored timestamp list changes.
    Macro_RefreshDisconnectHistoryDisplayForSelectedRoblox()

    try {
        alertHwnd := disconnectAlertGui.Hwnd
        if (!alertHwnd || !WinExist("ahk_id " . alertHwnd))
            return

        ; A fresh disconnect raises the alert exactly once. While that one-shot
        ; flag is still pending, make sure the window was not accidentally
        ; hidden by a Show/Resize/repaint operation. A real user click clears
        ; the flag, so this never forces the alert back after dismissal.
        if (disconnectAlertRaisePending) {
            try {
                if (!DllCall("user32\IsWindowVisible", "Ptr", alertHwnd))
                    disconnectAlertGui.Show("NoActivate")
                DllCall("user32\SetWindowPos", "Ptr", alertHwnd, "Ptr", -1,
                    "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0013)
            } catch {
            }
        }

        MouseGetPos(&mouseX, &mouseY, &hitHwnd)
        hoverRoot := 0
        if (hitHwnd) {
            try hoverRoot := DllCall("user32\GetAncestor", "Ptr", hitHwnd, "UInt", 2, "Ptr")
            catch
                hoverRoot := 0
            if (!hoverRoot)
                hoverRoot := hitHwnd
        }

        pointerOverAlert := (hoverRoot = alertHwnd || hitHwnd = alertHwnd)
        hoverIsRoblox := false
        hoverFullscreen := false
        if (!pointerOverAlert && hoverRoot && WinExist("ahk_id " . hoverRoot)) {
            try hoverIsRoblox := (WinGetProcessName("ahk_id " . hoverRoot) = "RobloxPlayerBeta.exe")
            catch
                hoverIsRoblox := false
            if (hoverIsRoblox) {
                try hoverFullscreen := (Macro_GetRobloxWindowMode(hoverRoot) = 3)
                catch
                    hoverFullscreen := false
            }
        }

        ; Keep following the selected Roblox window even while the pointer is
        ; elsewhere. Geometry tracking does not depend on focus or clicks.
        positionTargetHwnd := disconnectAlertPositionTargetHwnd
        targetChanged := false
        if (hoverIsRoblox) {
            targetChanged := (positionTargetHwnd != hoverRoot
                || disconnectAlertHoverHwnd != hoverRoot
                || disconnectAlertHoverFullscreen != hoverFullscreen)
            positionTargetHwnd := hoverRoot
            disconnectAlertPositionTargetHwnd := hoverRoot
            disconnectAlertHoverHwnd := hoverRoot
            disconnectAlertHoverFullscreen := hoverFullscreen
            disconnectAlertHoverVisible := true
        }

        if (positionTargetHwnd && WinExist("ahk_id " . positionTargetHwnd)) {
            targetIsRoblox := false
            try targetIsRoblox := (WinGetProcessName("ahk_id " . positionTargetHwnd) = "RobloxPlayerBeta.exe")
            catch
                targetIsRoblox := false

            if (targetIsRoblox) {
                geometryKey := Macro_GetDisconnectAlertGeometryKey(positionTargetHwnd)
                if (geometryKey != "") {
                    geometryChanged := targetChanged
                        || disconnectAlertLastGeometryHwnd != positionTargetHwnd
                        || geometryKey != disconnectAlertLastGeometryKey
                    if (geometryChanged) {
                        if (SubStr(geometryKey, 1, 4) != "MIN|")
                            Macro_PositionDisconnectAlertForRoblox(disconnectAlertGui, positionTargetHwnd, DISCONNECT_ALERT_WIDTH, 0)
                        else {
                            disconnectAlertLastGeometryHwnd := positionTargetHwnd
                            disconnectAlertLastGeometryKey := geometryKey
                        }
                    }
                }
            } else {
                disconnectAlertPositionTargetHwnd := 0
                disconnectAlertLastGeometryHwnd := 0
                disconnectAlertLastGeometryKey := ""
            }
        }

        ; Geometry tracking above never changes activation or Z-order.
        if (hoverIsRoblox) {
            exStyle := 0
            try exStyle := DllCall("user32\GetWindowLongPtrW", "Ptr", alertHwnd, "Int", -20, "Ptr")
            catch
                exStyle := 0

            if (!(exStyle & 0x00000008)) {
                DllCall("user32\SetWindowPos", "Ptr", alertHwnd, "Ptr", -1,
                    "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0013)
            }
        }
    } catch {
    }
}

Macro_GetDisconnectAlertGeometryKey(robloxHwnd) {
    if (!robloxHwnd || !WinExist("ahk_id " . robloxHwnd))
        return ""

    try {
        if (WinGetMinMax("ahk_id " . robloxHwnd) = -1)
            return "MIN|" . robloxHwnd
        WinGetPos(&x, &y, &w, &h, "ahk_id " . robloxHwnd)
        if (w <= 0 || h <= 0)
            return ""
        mode := Macro_GetRobloxWindowMode(robloxHwnd)
        return robloxHwnd . "|" . x . "|" . y . "|" . w . "|" . h . "|" . mode
    } catch {
        return ""
    }
}

Macro_PositionDisconnectAlertForRoblox(guiObj, robloxHwnd, alertW, alertH := 0) {
    global disconnectAlertPositionTargetHwnd, disconnectAlertLastGeometryHwnd, disconnectAlertLastGeometryKey

    if (!IsObject(guiObj) || !guiObj.Hwnd || !robloxHwnd || !WinExist("ahk_id " . robloxHwnd))
        return

    try {
        if (WinGetMinMax("ahk_id " . robloxHwnd) = -1)
            return

        WinGetPos(&rx, &ry, &rw, &rh, "ahk_id " . robloxHwnd)
        WinGetPos(&alertX, &alertY, &actualAlertW, &actualAlertH, "ahk_id " . guiObj.Hwnd)
        if (rw <= 0 || rh <= 0 || actualAlertW <= 0 || actualAlertH <= 0)
            return

        ; Keep the established right-side/vertical-center placement and current
        ; physical alert size. Only move when the target geometry changes.
        margin := 14
        x := rx + rw - actualAlertW - margin
        y := ry + Floor((rh - actualAlertH) / 2)
        if (x < rx + 8)
            x := rx + 8

        positionChanged := (alertX != x || alertY != y)
        if (positionChanged) {
            DllCall("user32\SetWindowPos", "Ptr", guiObj.Hwnd, "Ptr", 0,
                "Int", x, "Int", y, "Int", 0, "Int", 0, "UInt", 0x0015)
            Macro_RedrawDisconnectAlert()
        }

        disconnectAlertPositionTargetHwnd := robloxHwnd
        disconnectAlertLastGeometryHwnd := robloxHwnd
        disconnectAlertLastGeometryKey := Macro_GetDisconnectAlertGeometryKey(robloxHwnd)
        Macro_SyncGameStatusPosition()
    } catch {
    }
}

; 상태창의 Macro_GetStatusZOrderAnchor와 같은 원리의 감지창 전용 anchor.
; SetWindowPos의 hWndInsertAfter는 지정한 창의 '뒤'에 새 창을 넣으므로,
; Roblox 자체가 아니라 Roblox 바로 위에 있는 같은 Z-order 그룹의 창을 찾는다.
Macro_GetDisconnectAlertZOrderAnchor(targetHwnd, alertHwnd := 0) {
    if (!targetHwnd)
        return 0

    targetEx := 0
    try targetEx := DllCall("user32\GetWindowLongPtrW", "Ptr", targetHwnd, "Int", -20, "Ptr")
    catch
        targetEx := 0
    targetTopmost := (targetEx & 0x00000008) != 0

    anchor := 0
    try anchor := DllCall("user32\GetWindow", "Ptr", targetHwnd, "UInt", 3, "Ptr")
    catch
        anchor := 0

    while (anchor) {
        if (alertHwnd && anchor = alertHwnd) {
            try anchor := DllCall("user32\GetWindow", "Ptr", anchor, "UInt", 3, "Ptr")
            catch
                anchor := 0
            continue
        }

        ex := 0
        try ex := DllCall("user32\GetWindowLongPtrW", "Ptr", anchor, "Int", -20, "Ptr")
        catch
            ex := 0

        if (((ex & 0x00000008) != 0) = targetTopmost)
            return anchor

        try anchor := DllCall("user32\GetWindow", "Ptr", anchor, "UInt", 3, "Ptr")
        catch
            anchor := 0
    }

    return 0
}

; =====================================================================
; 🖱️ A real click ends the one-shot global raise.
;    Mouse movement/hover does nothing.
; =====================================================================
Macro_HandleDisconnectAlertUserClick() {
    global disconnectAlertGui, disconnectAlertActive, disconnectAlertRaisePending
    global disconnectAlertDetectedHwnd, DISCONNECT_ALERT_WIDTH
    global disconnectAlertHoverHwnd, disconnectAlertHoverFullscreen, disconnectAlertHoverVisible
    global disconnectAlertPositionTargetHwnd, disconnectAlertLastGeometryHwnd, disconnectAlertLastGeometryKey

    if (!disconnectAlertActive || !IsObject(disconnectAlertGui))
        return

    try {
        alertHwnd := disconnectAlertGui.Hwnd
        if (!alertHwnd)
            return

        MouseGetPos(&mx, &my, &hitHwnd)
        if (!hitHwnd)
            return

        hitRoot := DllCall("user32\GetAncestor", "Ptr", hitHwnd, "UInt", 2, "Ptr")
        if (!hitRoot)
            hitRoot := hitHwnd

        ; Clicking the alert itself does not change its visibility.
        if (hitRoot = alertHwnd || hitHwnd = alertHwnd)
            return

        isRoblox := false
        try {
            isRoblox := (WinGetProcessName("ahk_id " . hitRoot) = "RobloxPlayerBeta.exe")
        } catch {
            isRoblox := false
        }

        if (!isRoblox) {
            ; Only a real click on a non-Roblox window hides the alert.
            disconnectAlertRaisePending := false
            disconnectAlertHoverHwnd := 0
            disconnectAlertHoverFullscreen := false
            disconnectAlertHoverVisible := false
            disconnectAlertPositionTargetHwnd := 0
            disconnectAlertLastGeometryHwnd := 0
            disconnectAlertLastGeometryKey := ""
            try disconnectAlertGui.Hide()
            catch {
            }
            return
        }

        ; Clicking a Roblox window must NEVER dismiss the diagnostic alert.
        ; The alert may temporarily cover the clicked client during inspection,
        ; but it is restored immediately afterward.
        fullscreenRoblox := false
        try {
            fullscreenRoblox := (Macro_GetRobloxWindowMode(hitRoot) = 3)
        } catch {
            fullscreenRoblox := false
        }

        disconnectAlertRaisePending := false
        disconnectAlertHoverHwnd := hitRoot
        disconnectAlertHoverFullscreen := fullscreenRoblox
        disconnectAlertHoverVisible := true

        try {
            if (!DllCall("user32\IsWindowVisible", "Ptr", alertHwnd))
                disconnectAlertGui.Show("NoActivate")
        } catch {
            try disconnectAlertGui.Show("NoActivate")
            catch {
            }
        }

        ; Do not call Resize here. Resize/Show is one of the sources of the old
        ; flashing behavior. The existing alert size is retained.
        ; 클릭한 Roblox HWND를 직접 기준으로 재배치한다.
        ; 기존 일반 fallback 위치 계산을 사용하면 트레이팁과의 간격이 사라지거나
        ; 감지창이 다른 위치로 튀는 문제가 생길 수 있으므로 여기서는 전용 위치 계산을 사용한다.
        try Macro_PositionDisconnectAlertForRoblox(disconnectAlertGui, hitRoot, DISCONNECT_ALERT_WIDTH, 0)
        catch {
        }

        ; 클릭한 Roblox 위에서도 TOPMOST를 유지한다.
        ; 이전 버전처럼 일반 Z-order로 내리면 다음 타이머에서 Roblox 뒤로
        ; 내려가 감지창이 사라지는 문제가 생긴다.
        DllCall("user32\SetWindowPos", "Ptr", alertHwnd, "Ptr", -1,
            "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0013)
    } catch {
    }
}

Macro_PositionDisconnectAlert(guiObj, alertW, alertH) {
    global disconnectAlertDetectedHwnd, disconnectAlertOriginalForeground
    global disconnectAlertPositionTargetHwnd, disconnectAlertLastGeometryHwnd, disconnectAlertLastGeometryKey

    if (!IsObject(guiObj))
        return

    ; Primary rule:
    ;   - If the exact disconnected Roblox is visible and not occluded, place the
    ;     message inside that Roblox window.
    ;   - If that Roblox is minimized/covered and therefore cannot be inspected,
    ;     keep the message at the Windows work-area bottom until it becomes usable.
    targetRoblox := disconnectAlertDetectedHwnd
    targetVisible := false
    targetFullscreen := false
    targetX := 0, targetY := 0, targetW := 0, targetH := 0

    try {
        if (targetRoblox && WinExist("ahk_id " . targetRoblox)) {
            minmax := WinGetMinMax("ahk_id " . targetRoblox)
            WinGetPos(&targetX, &targetY, &targetW, &targetH, "ahk_id " . targetRoblox)
            targetFullscreen := (Macro_GetRobloxWindowMode(targetRoblox) = 3)
            if (minmax != -1 && targetW > 0 && targetH > 0) {
                if (targetFullscreen || WinActive("ahk_id " . targetRoblox) = targetRoblox)
                    targetVisible := true
                else
                    targetVisible := !Macro_IsRobloxActuallyOccluded(targetRoblox, targetX, targetY, targetW, targetH, guiObj.Hwnd)
            }
        }
    } catch {
        targetVisible := false
    }

    try {
        ; When the exact target is visible, attach the message to that client.
        if (targetVisible) {
            margin := 14
            x := targetX + targetW - alertW - margin
            ; Center the alert vertically within the Roblox window; keep its existing right-side placement.
            y := targetY + Floor((targetH - alertH) / 2)

            ; Keep the right-side placement within the Roblox window when it is narrow.
            if (x < targetX + 8)
                x := targetX + 8

            guiObj.Show("x" . x . " y" . y . " w" . alertW . " h" . alertH . " NoActivate")
            disconnectAlertPositionTargetHwnd := targetRoblox
            disconnectAlertLastGeometryHwnd := targetRoblox
            disconnectAlertLastGeometryKey := Macro_GetDisconnectAlertGeometryKey(targetRoblox)
            Macro_SyncGameStatusPosition()
            return
        }

        disconnectAlertPositionTargetHwnd := 0
        disconnectAlertLastGeometryHwnd := 0
        disconnectAlertLastGeometryKey := ""

        ; No usable target: bottom-right work-area fallback. This is intentionally
        ; used only while the detected Roblox is hidden/covered/minimized or while
        ; no exact HWND has been identified yet.
        monitorIndex := MonitorGetPrimary()
        if (targetRoblox && targetW > 0 && targetH > 0) {
            centerX := targetX + Round(targetW / 2)
            centerY := targetY + Round(targetH / 2)
            Loop MonitorGetCount() {
                idx := A_Index
                try MonitorGet(idx, &ml, &mt, &mr, &mb)
                catch
                    continue
                if (centerX >= ml && centerX < mr && centerY >= mt && centerY < mb) {
                    monitorIndex := idx
                    break
                }
            }
        } else {
            try {
                active := WinExist("A")
                if (active && WinGetProcessName("ahk_id " . active) = "RobloxPlayerBeta.exe")
                    monitorIndex := Macro_GetMonitorFromWindow(active)
            } catch {
            }
        }

        try MonitorGetWorkArea(monitorIndex, &wl, &wt, &wr, &wb)
        catch {
            wl := 0, wt := 0, wr := A_ScreenWidth, wb := A_ScreenHeight
        }

        rightMargin := 12
        bottomMargin := 12
        liftAboveTray := 150
        x := wr - alertW - rightMargin
        y := wb - alertH - bottomMargin - liftAboveTray
        if (x < wl)
            x := wl
        if (y < wt)
            y := wt

        guiObj.Show("x" . x . " y" . y . " w" . alertW . " h" . alertH . " NoActivate")
        Macro_SyncGameStatusPosition()
    } catch {
        try guiObj.Show("NoActivate")
        try Macro_SyncGameStatusPosition()
    }
}


Macro_DisconnectAlertPrimary(*) {
    global disconnectAlertGui, disconnectAlertStage, disconnectAlertDetectedHwnd
    global disconnectManualCheckBusy, disconnectManualCheckPending, disconnectHiddenScanActive
    global connectionRecoveryBusy

    if (!IsObject(disconnectAlertGui))
        return

    ; A recovery transaction already owns an exact HWND/PID. Never start a new
    ; inspection while that transaction is running.
    if (connectionRecoveryBusy)
        return

    if (disconnectAlertStage = "Signal") {
        if (disconnectHiddenScanActive)
            return
        if (disconnectManualCheckBusy)
            return

        Macro_ManualInspectDisconnect()
        return
    }

    if (disconnectAlertStage = "Confirmed") {
        if (disconnectAlertDetectedHwnd)
            Macro_StartManualReconnect(disconnectAlertDetectedHwnd)
        return
    }

    if (disconnectAlertStage = "Failed") {
        if (!disconnectManualCheckBusy)
            Macro_ManualInspectDisconnect()
        return
    }

    if (disconnectAlertStage = "Reconnected") {
        Macro_DisconnectAlertDismiss()
    }
}

Macro_DisconnectAlertDismiss(*) {
    global disconnectAlertRaisePending
    global disconnectHiddenScanPending, disconnectHiddenScanCountdownRunning
    global disconnectAlertGui, disconnectAlertActive, disconnectAlertStage
    global disconnectAlertHoverHwnd, disconnectAlertHoverFullscreen, disconnectAlertHoverVisible
    global disconnectAlertDetectedHwnd, disconnectAlertReason, disconnectAlertOriginalForeground
    global fixedPointModalDebugEnabled

    Macro_ClearFixedPointModalPinnedResult(true)
    if (fixedPointModalDebugEnabled)
        Macro_HideFixedPointModalMarkers()

    disconnectAlertActive := false
    disconnectAlertStage := ""
    disconnectAlertDetectedHwnd := 0
    disconnectAlertReason := ""
    disconnectAlertOriginalForeground := 0
    disconnectAlertRaisePending := false
    disconnectAlertHoverHwnd := 0
    disconnectAlertHoverFullscreen := false
    disconnectAlertHoverVisible := false
    disconnectHiddenScanPending := false
    disconnectHiddenScanCountdownRunning := false
    SetTimer(Macro_UpdateHiddenScanCountdown, 0)

    try {
        if (IsObject(disconnectAlertGui))
            disconnectAlertGui.Hide()
    } catch {
    }
}

; =====================================================================
; 🔎 Manual inspection: only starts after the user clicks the alert.
; =====================================================================
Macro_ManualInspectDisconnect() {
    global disconnectManualCheckBusy, disconnectManualCheckPending
    global disconnectHiddenScanPending, disconnectHiddenScanCountdownRunning
    global disconnectAlertGui, disconnectAlertTitle, disconnectAlertBody, disconnectAlertPrimaryButton
    global disconnectAlertStage, disconnectAlertDetectedHwnd, disconnectAlertOriginalForeground
    global disconnectHiddenScanActive
    global connectionRecoveryBusy
    global connectionRecoveryOriginalForeground, connectionRecoveryHwnd
    global connectionRecoveryOriginalMinMax, connectionRecoveryDiscoveredMinMax
    global connectionRecoveryDetectedHwnd, connectionRecoveryDetectedPid, connectionRecoveryDetectedVerified
    global connectionRecoveryTargetPid
    global fixedPointModalDebugEnabled
    global disconnectManualBatchReconnect
    global connectionRecoveryQueue

    if (disconnectManualCheckBusy || connectionRecoveryBusy || disconnectHiddenScanActive)
        return

    Macro_ClearFixedPointModalPinnedResult(false)
    if (fixedPointModalDebugEnabled)
        Macro_HideFixedPointModalMarkers()

    disconnectManualCheckBusy := true
    disconnectManualCheckPending := false
    disconnectHiddenScanPending := false
    disconnectHiddenScanCountdownRunning := false
    SetTimer(Macro_UpdateHiddenScanCountdown, 0)
    disconnectAlertStage := "Checking"

    ; The diagnostic window is hidden only while the actual Roblox inspection
    ; is running. It is restored by the normal result/update path afterward.
    try {
        if (IsObject(disconnectAlertGui) && disconnectAlertGui.Hwnd)
            disconnectAlertGui.Hide()
    } catch {
    }
    try {
        disconnectAlertTitle.Text := Macro_GetDisconnectUIText("checkingTitle")
        disconnectAlertBody.Text := Macro_GetDisconnectUIText("checking")
        disconnectAlertPrimaryButton.Text := Macro_GetDisconnectUIText("checkingButton")
        disconnectAlertPrimaryButton.Enabled := false
    } catch {
    }

    currentForeground := WinExist("A")
    originalForeground := currentForeground
    try {
        if (IsObject(disconnectAlertGui) && disconnectAlertGui.Hwnd
            && currentForeground = disconnectAlertGui.Hwnd
            && disconnectAlertOriginalForeground
            && WinExist("ahk_id " . disconnectAlertOriginalForeground)) {
            originalForeground := disconnectAlertOriginalForeground
        }
    } catch {
    }
    connectionRecoveryOriginalForeground := originalForeground

    targetHwnd := 0
    targetPid := 0
    targetMinMax := 0
    try {
        ; IMPORTANT: [확인] is an explicit user request for a full inspection.
        ; Do NOT trust/consume an existing watchdog candidate first.
        ; Each Roblox client is inspected only once in this pass: visible clients
        ; are checked in the first pass, while only actually covered/minimized
        ; clients are activated in the second pass.
        ; Each Roblox HWND is inspected exactly once in Macro_CollectReconnectCandidates().
        ; There is no second full-list pass and no duplicate occlusion probe.
        candidates := Macro_CollectReconnectCandidates(true, false)

        ; This inspection is a fresh census. Remove candidates left by an older
        ; scan, because the Roblox window may still exist after its modal vanished.
        connectionRecoveryQueue := []
        for item in candidates
            Macro_QueueReconnectCandidate(item["hwnd"], item["pid"], item["minmax"])

        candidate := Macro_PeekReconnectCandidate()
        if (candidate) {
            targetHwnd := candidate["hwnd"]
            targetPid := candidate["pid"]
            targetMinMax := candidate["minmax"]
        }
    } catch {
        targetHwnd := 0
        targetPid := 0
        targetMinMax := 0
    }

    ; Restore the original foreground after the focus-changing inspection.
    ; The inspection itself does not move the mouse, so mouse position is untouched.
    try {
        if (originalForeground && WinExist("ahk_id " . originalForeground))
            WinActivate("ahk_id " . originalForeground)
    } catch {
    }
    disconnectManualCheckBusy := false

    if (!targetHwnd) {
        displayCode := Macro_GetDisconnectDisplayCode()
        codeText := (displayCode != "") ? displayCode . " " : ""
        Macro_ShowDisconnectTrayProgress("비활성/가림 Roblox까지 확인했지만 " . codeText . "재연결 화면을 찾지 못했습니다.", "🔎 ROBLOX 검사 완료")
        disconnectAlertStage := "Signal"
        disconnectAlertDetectedHwnd := 0
        try {
            disconnectAlertTitle.Text := Macro_GetDisconnectUIText("notFoundTitle")
            disconnectAlertBody.Text := Macro_GetDisconnectUIText("notFound")
            Macro_ResizeDisconnectAlert()
            disconnectAlertPrimaryButton.Enabled := true
            disconnectAlertPrimaryButton.Text := Macro_GetDisconnectUIText("retry")
        } catch {
        }
        return
    }

    displayCode := Macro_GetDisconnectDisplayCode()
    codeText := (displayCode != "") ? " " . displayCode : ""
    Macro_ShowDisconnectTrayProgress("Roblox" . codeText . " 재연결 화면을 확인했습니다.`n대상 HWND: 0x" . Format("{:X}", targetHwnd), "🚨 ROBLOX" . codeText . " 확인 완료", targetHwnd)

    connectionRecoveryHwnd := targetHwnd
    connectionRecoveryTargetPid := targetPid
    connectionRecoveryDetectedHwnd := targetHwnd
    connectionRecoveryDetectedPid := targetPid
    connectionRecoveryDetectedVerified := true
    connectionRecoveryOriginalMinMax := targetMinMax
    disconnectAlertDetectedHwnd := targetHwnd
    disconnectAlertStage := "Confirmed"
    Macro_RecordDisconnectProcessStep("modal_confirmed")

    ; All verified modals found by this inspection are already queued. Start the
    ; first exact HWND+PID now; after each account completes (or fails), the next
    ; queued account is attempted automatically without another button press.
    disconnectManualBatchReconnect := true
    Macro_StartManualReconnect(targetHwnd)
}

Macro_StartManualReconnect(targetHwnd) {
    global connectionRecoveryBusy, connectionRecoveryHwnd, connectionRecoveryAttempts
    global connectionRecoveryTargetPid, connectionRecoveryDetectedPid, connectionRecoveryQueue
    global connectionRecoveryStableChecks, connectionRecoveryNextTick, connectionRecoveryStage
    global connectionRecoveryOriginalForeground, connectionRecoveryOriginalMinMax
    global connectionRecoveryLastFocusVerifyTick, connectionRecoveryGameName
    global connectionRecoveryPending
    global disconnectAlertGui, disconnectAlertTitle, disconnectAlertBody, disconnectAlertPrimaryButton, disconnectAlertStage
    global disconnectAlertLastRecoveryAttempts, disconnectAlertReason
    global disconnectRecoveryTotalAttempts
    global CONNECTION_RECONNECT_CONFIRM_WAIT_MS
    global fixedPointModalDebugEnabled
    global disconnectManualBatchReconnect

    Macro_ClearFixedPointModalPinnedResult(false)
    if (fixedPointModalDebugEnabled)
        Macro_HideFixedPointModalMarkers()

    if (!targetHwnd || !WinExist("ahk_id " . targetHwnd) || connectionRecoveryBusy) {
        if (disconnectManualBatchReconnect && !connectionRecoveryBusy) {
            Macro_RemoveReconnectCandidate(targetHwnd)
            connectionRecoveryHwnd := 0
            connectionRecoveryTargetPid := 0
            connectionRecoveryOriginalMinMax := 0
            SetTimer(Macro_StartNextManualBatchReconnect, -50)
        }
        return
    }

    targetPid := 0
    try targetPid := WinGetPID("ahk_id " . targetHwnd)
    catch
        targetPid := 0

    if (connectionRecoveryDetectedPid && targetPid && targetPid != connectionRecoveryDetectedPid) {
        try {
            disconnectAlertTitle.Text := Macro_GetDisconnectUIText("notFoundTitle")
            disconnectAlertBody.Text := Macro_GetDisconnectUIText("notFound")
            Macro_ResizeDisconnectAlert()
            disconnectAlertPrimaryButton.Enabled := true
            disconnectAlertPrimaryButton.Text := Macro_GetDisconnectUIText("retry")
        } catch {
        }
        disconnectAlertStage := "Signal"
        if (disconnectManualBatchReconnect) {
            Macro_RemoveReconnectCandidate(targetHwnd)
            connectionRecoveryHwnd := 0
            connectionRecoveryTargetPid := 0
            connectionRecoveryOriginalMinMax := 0
            SetTimer(Macro_StartNextManualBatchReconnect, -50)
        }
        return
    }

    Macro_RemoveReconnectCandidate(targetHwnd, targetPid)
    connectionRecoveryHwnd := targetHwnd
    connectionRecoveryTargetPid := targetPid
    ; Save the title while the original experience identity is still available.
    connectionRecoveryGameName := ""
    try connectionRecoveryGameName := Trim(Macro_GetRobloxGameNameForHwnd(targetHwnd) . "")
    catch
        connectionRecoveryGameName := ""
    MouseMacro_ForceOffForDisconnect("reconnection started")
    connectionRecoveryBusy := true
    connectionRecoveryAttempts := 0
    connectionRecoveryStableChecks := 0
    connectionRecoveryLastFocusVerifyTick := 0
    connectionRecoveryStage := "NeedClick"

    if (!Macro_ClickReconnectForWindow(targetHwnd)) {
        Macro_RecordDisconnectProcessStep("click_failed")
        connectionRecoveryBusy := false
        connectionRecoveryStage := ""
        try {
            disconnectAlertTitle.Text := Macro_GetDisconnectUIText("failedTitle")
            disconnectAlertBody.Text := Macro_GetDisconnectUIText("clickFailed") . "`n`n"
                . "Attempt: " . disconnectClickAttempt . "/2`n"
                . "Target HWND: 0x" . Format("{:X}", disconnectClickTargetHwnd) . "`n"
                . "Hit HWND: 0x" . Format("{:X}", disconnectClickHitRoot) . "`n"
                . "Hit process: " . disconnectClickHitProcess . "`n"
                . "Result: " . disconnectClickLastResult
            Macro_ResizeDisconnectAlert()
        }
        disconnectAlertStage := "Failed"
        try {
            disconnectAlertPrimaryButton.Enabled := true
            disconnectAlertPrimaryButton.Text := Macro_GetDisconnectUIText("retry")
        }
        if (disconnectManualBatchReconnect) {
            connectionRecoveryHwnd := 0
            connectionRecoveryTargetPid := 0
            connectionRecoveryOriginalMinMax := 0
            SetTimer(Macro_StartNextManualBatchReconnect, -150)
        }
        return
    }

    Macro_RecordDisconnectProcessStep("reconnect_click")
    connectionRecoveryAttempts := 1
    disconnectRecoveryTotalAttempts += 1
    disconnectAlertLastRecoveryAttempts := connectionRecoveryAttempts
    connectionRecoveryStage := "Confirm"
    connectionRecoveryNextTick := A_TickCount + CONNECTION_RECONNECT_CONFIRM_WAIT_MS
    connectionRecoveryPending := true

    try {
        disconnectAlertStage := "Reconnecting"
        disconnectAlertTitle.Text := Macro_GetDisconnectUIText("reconnectingTitle")
        disconnectAlertBody.Text := Macro_GetDisconnectUIText("reconnecting")
        Macro_ResizeDisconnectAlert()
        disconnectAlertPrimaryButton.Text := Macro_GetDisconnectUIText("checkingButton")
        disconnectAlertPrimaryButton.Enabled := false
    } catch {
    }
}

Macro_ScanRobloxLogsForDisconnect() {
    global connectionLogState
    global CONNECTION_LOG_OVERLAP_CHARS, CONNECTION_LOG_NEW_FILE_TAIL_BYTES
    global disconnectLogDiagSignal, disconnectLogDiagFreshSignal
    global disconnectLogDiagFile, disconnectLogDiagPattern, disconnectLogDiagCode, disconnectLogDiagScanTime
    global disconnectLogDiagFilesScanned, disconnectLogDiagFilesChanged
    global disconnectLogDiagFilesRead, disconnectLogDiagReadErrors
    global disconnectLogDiagBytesRead, disconnectLogDiagNewFiles
    global disconnectLogDiagOverlapChars, disconnectLogDiagLastSignalTime
    global disconnectLogDiagMappingState, disconnectLogDiagMappedPids, disconnectLogDiagMappedHwnds
    global disconnectLogDiagFocusState, disconnectLogDiagFocusHwnd, disconnectLogDiagFocusPid, disconnectLogDiagFocusTime
    global disconnectLogSignalFiles, disconnectLogSignalVersions, disconnectLogSignalSequence

    localAppData := EnvGet("LOCALAPPDATA")
    if (!localAppData) {
        disconnectLogDiagFreshSignal := false
        disconnectLogDiagScanTime := Macro_Format12HourCurrentTime(A_Now)
        disconnectLogDiagReadErrors := 1
        return false
    }

    logDir := localAppData . "\\Roblox\\logs"
    if !DirExist(logDir) {
        disconnectLogDiagFreshSignal := false
        disconnectLogDiagScanTime := Macro_Format12HourCurrentTime(A_Now)
        disconnectLogDiagReadErrors := 1
        return false
    }

    disconnectLogDiagFreshSignal := false
    disconnectLogDiagScanTime := Macro_Format12HourCurrentTime(A_Now)
    disconnectLogDiagFilesScanned := 0
    disconnectLogDiagFilesChanged := 0
    disconnectLogDiagFilesRead := 0
    disconnectLogDiagReadErrors := 0
    disconnectLogDiagBytesRead := 0
    disconnectLogDiagNewFiles := 0
    disconnectLogDiagOverlapChars := 0

    currentSignalFiles := []
    activeFiles := Map()
    signalFound := false

    try {
        Loop Files, logDir . "\\*.log", "F" {
            path := A_LoopFileFullPath
            activeFiles[path] := true
            disconnectLogDiagFilesScanned += 1

            size := A_LoopFileSize
            modified := A_LoopFileTimeModified
            stateExists := connectionLogState.Has(path)
            oldSize := 0
            oldModified := ""
            previousTail := ""
            isNewFile := !stateExists

            if (stateExists) {
                state := connectionLogState[path]
                if (IsObject(state)) {
                    try {
                        oldSize := state["size"]
                    } catch {
                        oldSize := 0
                    }
                    try {
                        oldModified := state["modified"]
                    } catch {
                        oldModified := ""
                    }
                    try {
                        previousTail := state["tail"]
                    } catch {
                        previousTail := ""
                    }
                } else {
                    oldSize := state
                }
            }

            if (isNewFile)
                disconnectLogDiagNewFiles += 1

            ; ---------------------------------------------------------
            ; Detect real file activity using BOTH file metadata and content.
            ; Do not exclude an older log merely because its timestamp is old:
            ; Roblox can keep appending to the same file for a long time.
            ; ---------------------------------------------------------
            appendChange := (isNewFile || size > oldSize)
            shrinkChange := (!isNewFile && size < oldSize)
            modifiedChange := (!isNewFile && modified != oldModified)

            if (!isNewFile && !appendChange && !shrinkChange && !modifiedChange)
                continue

            disconnectLogDiagFilesChanged += 1
            matchedPattern := ""
            currentTail := ""

            if (isNewFile) {
                ; A genuinely new file can be inspected from its newest tail.
                currentTail := Macro_ReadRobloxLogTail(path, size, CONNECTION_LOG_NEW_FILE_TAIL_BYTES, &readOk, &bytesRead)
                if (!readOk) {
                    disconnectLogDiagReadErrors += 1
                    continue
                }
                disconnectLogDiagFilesRead += 1
                disconnectLogDiagBytesRead += bytesRead
                matchedPattern := Macro_FindFreshDisconnectPattern(currentTail, 0)
            } else if (appendChange) {
                ; Read ONLY the bytes added since the previous scan, while using
                ; the remembered tail as overlap. This catches a pattern split
                ; across two physical writes without rereading the whole log.
                overlap := Min(CONNECTION_LOG_OVERLAP_CHARS, StrLen(previousTail))
                prefix := ""
                if (overlap > 0)
                    prefix := SubStr(previousTail, StrLen(previousTail) - overlap + 1)
                disconnectLogDiagOverlapChars += StrLen(prefix)

                bytesToRead := Max(0, size - oldSize)
                chunk := ""
                f := 0
                try {
                    f := FileOpen(path, "r")
                    if (!IsObject(f))
                        throw Error("FileOpen failed")
                    f.Seek(oldSize, 0)
                    chunk := f.Read(bytesToRead)
                    f.Close()
                    f := 0
                    disconnectLogDiagFilesRead += 1
                    disconnectLogDiagBytesRead += StrLen(chunk)
                } catch {
                    disconnectLogDiagReadErrors += 1
                    try {
                        if (IsObject(f))
                            f.Close()
                    } catch {
                    }
                    continue
                }

                combined := prefix . chunk
                boundary := StrLen(prefix)
                matchedPattern := Macro_FindFreshDisconnectPattern(combined, boundary)
                combinedTail := previousTail . chunk
                tailKeep := Max(CONNECTION_LOG_OVERLAP_CHARS, 65536)
                currentTail := (StrLen(combinedTail) > tailKeep) ? SubStr(combinedTail, -tailKeep) : combinedTail
            } else {
                ; Same-size rewrites, truncation/rotation, and metadata-only changes
                ; are checked by rereading the newest tail. A count increase means
                ; a new disconnect marker appeared in that changed tail.
                currentTail := Macro_ReadRobloxLogTail(path, size, CONNECTION_LOG_NEW_FILE_TAIL_BYTES, &readOk, &bytesRead)
                if (!readOk) {
                    disconnectLogDiagReadErrors += 1
                    continue
                }
                disconnectLogDiagFilesRead += 1
                disconnectLogDiagBytesRead += bytesRead
                matchedPattern := Macro_FindFreshDisconnectPatternTailChange(currentTail, previousTail)
            }

            ; Advance the state after a successful inspection.
            tailKeep := Max(CONNECTION_LOG_OVERLAP_CHARS, 65536)
            if (currentTail = "" && size = 0)
                currentTail := ""
            else if (StrLen(currentTail) > tailKeep)
                currentTail := SubStr(currentTail, -tailKeep)
            connectionLogState[path] := Map("size", size, "modified", modified, "tail", currentTail)
            ; A clean leave can emit generic teardown phrases. Check final session
            ; state before turning one of those phrases into a disconnect alert.
            if (matchedPattern != "" && Macro_IsRobloxVoluntaryExitLog(path))
                matchedPattern := ""

            if (matchedPattern != "") {
                signalFound := true
                disconnectLogDiagFreshSignal := true
                currentSignalFiles.Push(path)
                disconnectLogDiagSignal := true
                disconnectLogDiagFile := path
                disconnectLogDiagPattern := matchedPattern
                disconnectLogDiagCode := Macro_GetDisconnectCodeFromPattern(matchedPattern)
                disconnectLogDiagLastSignalTime := disconnectLogDiagScanTime
                disconnectLogDiagMappingState := "PENDING"
                disconnectLogDiagMappedPids := ""
                disconnectLogDiagMappedHwnds := ""
                disconnectLogDiagFocusHwnd := 0
                disconnectLogDiagFocusPid := 0
                disconnectLogDiagFocusTime := disconnectLogDiagScanTime
            }
        }
    } catch {
        ; Keep signals gathered before a later directory/file error.
    }

    if (signalFound) {
        seenCurrent := Map()
        seenPending := Map()
        for _, pendingPath in disconnectLogSignalFiles
            seenPending[pendingPath] := true

        for _, path in currentSignalFiles {
            if (seenCurrent.Has(path))
                continue
            seenCurrent[path] := true
            if (!seenPending.Has(path)) {
                disconnectLogSignalFiles.Push(path)
                seenPending[path] := true
            }
            disconnectLogSignalSequence += 1
            disconnectLogSignalVersions[path] := disconnectLogSignalSequence
        }
    }

    try {
        for path, state in connectionLogState {
            if (!activeFiles.Has(path))
                connectionLogState.Delete(path)
        }
    } catch {
    }

    return signalFound
}

Macro_ReadRobloxLogTail(path, size, maxChars, &readOk, &bytesRead) {
    readOk := false
    bytesRead := 0
    if (path = "" || size <= 0)
        return ""

    readSize := Min(size, maxChars)
    start := Max(0, size - readSize)
    data := ""
    f := 0
    try {
        f := FileOpen(path, "r")
        if (!IsObject(f))
            throw Error("FileOpen failed")
        f.Seek(start, 0)
        data := f.Read(readSize)
        f.Close()
        f := 0
        readOk := true
        bytesRead := StrLen(data)
    } catch {
        try {
            if (IsObject(f))
                f.Close()
        } catch {
        }
    }
    return data
}

; Keep the automatic disconnect scanner aligned with the broader wording
; accepted by Macro_ParseRobloxGameSessionLog().  These are regex patterns,
; not exact phrases, so spacing/capitalization variations are accepted.
; Reason 285 is excluded from explicit disconnect-reason variants because
; Roblox also writes it during a clean user-initiated leave.
Macro_GetDisconnectSignalRegexPatterns() {
    return [
        "i)Error Code\s*:\s*\d+",
        "i)Sending disconnect with reason\s*:\s*(?!285\b)\d+",
        "i)Disconnect reason received\s*:\s*(?!285\b)\d+",
        "i)Disconnection Notification\.\s*Reason\s*:\s*(?!285\b)\d+",
        "i)Lost connection to the game server",
        "i)Lost connection with reason\s*:",
        "i)Client has been disconnected with reason\s*:",
        "i)Connection lost(?:\s|:|$)",
        "i)Session Transition FSM:\s*Error Occurred\."
    ]
}

Macro_FindFreshDisconnectPatternTailChange(newText, oldText) {
    oldMatches := Macro_CollectDisconnectSignalMatches(oldText)
    newMatches := Macro_CollectDisconnectSignalMatches(newText)
    oldCounts := Map()

    for _, item in oldMatches {
        key := StrLower(item.text)
        oldCounts[key] := oldCounts.Has(key) ? oldCounts[key] + 1 : 1
    }

    bestPos := 0
    bestPattern := ""
    for _, item in newMatches {
        key := StrLower(item.text)
        if (oldCounts.Has(key) && oldCounts[key] > 0) {
            oldCounts[key] -= 1
            continue
        }
        if (!bestPos || item.pos < bestPos) {
            bestPos := item.pos
            bestPattern := item.text
        }
    }
    return bestPattern
}

Macro_CollectDisconnectSignalMatches(text) {
    matches := []
    if (text = "")
        return matches

    patterns := Macro_GetDisconnectSignalRegexPatterns()
    for _, pattern in patterns {
        searchPos := 1
        while (searchPos <= StrLen(text)) {
            if (!RegExMatch(text, pattern, &match, searchPos))
                break
            matchPos := match.Pos[0]
            matchLen := match.Len[0]
            matches.Push({pos:matchPos, text:match[0]})
            searchPos := matchPos + Max(1, matchLen)
        }
    }
    return matches
}

Macro_GetDisconnectCodeFromPattern(pattern) {
    if RegExMatch(pattern, "i)Error Code\s*:\s*(\d+)", &codeMatch)
        return codeMatch[1]
    if RegExMatch(pattern,
        "i)(?:Sending disconnect with reason|Disconnect reason received|Disconnection Notification\.\s*Reason|Lost connection with reason|Client has been disconnected with reason|Connection lost)\s*:\s*(\d+)",
        &codeMatch)
        return codeMatch[1]
    return ""
}

Macro_FindLastDisconnectSignalPattern(text) {
    if (text = "")
        return ""
    patterns := Macro_GetDisconnectSignalRegexPatterns()
    bestPos := 0
    bestPattern := ""
    for _, pattern in patterns {
        searchPos := 1
        while (searchPos <= StrLen(text)) {
            if (!RegExMatch(text, pattern, &match, searchPos))
                break
            pos := match.Pos[0]
            matchLen := match.Len[0]
            if (pos >= bestPos) {
                bestPos := pos
                bestPattern := match[0]
            }
            searchPos := pos + Max(1, matchLen)
        }
    }
    return bestPattern
}

Macro_FindFreshDisconnectPattern(text, boundaryLen := 0) {
    patterns := Macro_GetDisconnectSignalRegexPatterns()

    bestPos := 0
    bestPattern := ""
    for _, pattern in patterns {
        searchPos := 1
        while (searchPos <= StrLen(text)) {
            if (!RegExMatch(text, pattern, &match, searchPos))
                break
            pos := match.Pos[0]
            matchLen := match.Len[0]
            endPos := pos + matchLen - 1
            if (endPos > boundaryLen) {
                if (!bestPos || pos < bestPos) {
                    bestPos := pos
                    bestPattern := match[0]
                }
                break
            }
            searchPos := pos + Max(1, matchLen)
        }
    }
    return bestPattern
}

Macro_StartLogAutoRejoin() {
    global connectionRecoveryEnabled
    global CONNECTION_LOG_AUTO_REJOIN_ENABLE, AUTO_HIDDEN_SCAN_DELAY_SEC
    global disconnectLogDiagCode
    global logAutoRejoinBusy, logAutoRejoinStage
    global logAutoRejoinTargetHwnd, logAutoRejoinTargetPid, logAutoRejoinPlaceId
    global logAutoRejoinCode, logAutoRejoinOriginalMinMax, logAutoRejoinOriginalForeground
    global logAutoRejoinOldPids, logAutoRejoinNewPid
    global logAutoRejoinStartTick, logAutoRejoinCloseDeadlineTick
    global logAutoRejoinSpawnDeadlineTick, logAutoRejoinJoinDeadlineTick
    global logAutoRejoinPendingSince, logAutoRejoinLastStepTick, logAutoRejoinLastMessage
    global logAutoRejoinLaunchAttempts, logAutoRejoinNextLaunchTick
    global disconnectLogSignalFiles, disconnectLogDiagFile, disconnectLogDiagMappedPids, disconnectLogDiagMappedHwnds
    global gameIdentityLogState, gameIdentityByPid
    global disconnectAlertBody, disconnectAlertTitle, disconnectAlertStage
    global disconnectGracePlaceId, disconnectGraceUserId, disconnectGraceOriginalPid, disconnectGraceOriginalPids
    global disconnectGraceTargetHwnd, disconnectGraceTargetPid, disconnectGraceCode
    global CONNECTION_LOG_REJOIN_STEP_MS
    global CONNECTION_LOG_REJOIN_CLOSE_WAIT_MS, CONNECTION_LOG_REJOIN_SPAWN_WAIT_MS, CONNECTION_LOG_REJOIN_JOIN_WAIT_MS
    global CONNECTION_LOG_REJOIN_LAUNCH_RETRY_INTERVAL_MS, CONNECTION_LOG_REJOIN_MAX_LAUNCH_ATTEMPTS

    if (!connectionRecoveryEnabled || !CONNECTION_LOG_AUTO_REJOIN_ENABLE || logAutoRejoinBusy)
        return false

    target := 0
    if (disconnectGracePlaceId != "") {
        ; Use the exact incident captured before the grace period. The latest
        ; scanner pass can see other log events while waiting, so rerunning the
        ; general target finder here could accidentally select a different client.
        target := Map("hwnd", disconnectGraceTargetHwnd,
            "pid", disconnectGraceTargetPid,
            "placeId", disconnectGracePlaceId,
            "code", disconnectGraceCode)
    } else {
        target := Macro_FindLogDisconnectTarget()
    }
    if (!target) {
        Macro_LogAutoRejoinFailed(Macro_GetLogAutoRejoinUIText("missingPlaceId", disconnectLogDiagCode))
        return false
    }

    targetHwnd := target["hwnd"]
    targetPid := target["pid"]
    placeId := target["placeId"]
    code := target["code"]

    if (!placeId)
        return false

    logAutoRejoinTargetHwnd := targetHwnd
    logAutoRejoinTargetPid := targetPid
    logAutoRejoinPlaceId := placeId
    logAutoRejoinCode := code
    logAutoRejoinOriginalMinMax := 0
    try logAutoRejoinOriginalMinMax := WinGetMinMax("ahk_id " . targetHwnd)
    catch
        logAutoRejoinOriginalMinMax := 0
    logAutoRejoinOriginalForeground := WinExist("A")
    ; Keep the PID baseline from the moment the disconnect signal was first
    ; observed; a game-managed replacement PID born during the grace window must
    ; not be mistaken for an old process by the subsequent rejoin worker.
    logAutoRejoinOldPids := IsObject(disconnectGraceOriginalPids)
        ? disconnectGraceOriginalPids : Macro_SnapshotRobloxPids()
    if (targetPid)
        logAutoRejoinOldPids[targetPid] := true
    logAutoRejoinNewPid := 0
    logAutoRejoinStartTick := A_TickCount
    logAutoRejoinCloseDeadlineTick := A_TickCount + CONNECTION_LOG_REJOIN_CLOSE_WAIT_MS
    logAutoRejoinSpawnDeadlineTick := 0
    logAutoRejoinJoinDeadlineTick := 0
    logAutoRejoinPendingSince := A_TickCount
    logAutoRejoinLastStepTick := 0
    logAutoRejoinLaunchAttempts := 0
    logAutoRejoinNextLaunchTick := 0
    logAutoRejoinLastMessage := ""
    MouseMacro_ForceOffForDisconnect("automatic rejoin started")
    logAutoRejoinBusy := true

    ; Automatic log rejoin is intentionally not blocked by user-idle state.
    ; The affected Roblox instance is already identified by log/PID/Place ID,
    ; so recovery can proceed immediately after the disconnect signal.
    if (targetPid) {
        logAutoRejoinStage := "CLOSE_TARGET"
    } else {
        ; No old process remains to close. Start in the spawn/launch stage.
        logAutoRejoinStage := "WAIT_SPAWN"
        logAutoRejoinSpawnDeadlineTick := A_TickCount + CONNECTION_LOG_REJOIN_SPAWN_WAIT_MS
        logAutoRejoinLaunchAttempts := 0
        logAutoRejoinNextLaunchTick := A_TickCount
    }

    Macro_UpdateLogAutoRejoinAlert(Macro_GetLogAutoRejoinUIText("starting", code))
    SetTimer(Macro_LogAutoRejoinStep, CONNECTION_LOG_REJOIN_STEP_MS)
    SetTimer(Macro_LogAutoRejoinStep, -50)
    return true
}

Macro_FindLogDisconnectTarget() {
    global disconnectLogSignalFiles, disconnectLogDiagFile, disconnectLogDiagCode
    global gameIdentityLogState, gameIdentityByPid
    global disconnectLogDiagMappedPids, disconnectLogDiagMappedHwnds

    paths := []
    seenPaths := Map()
    if (disconnectLogDiagFile != "") {
        paths.Push(disconnectLogDiagFile)
        seenPaths[disconnectLogDiagFile] := true
    }
    for _, path in disconnectLogSignalFiles {
        if (path != "" && !seenPaths.Has(path)) {
            paths.Push(path)
            seenPaths[path] := true
        }
    }

    mappedPids := Map()
    mappedHwnds := Map()

    ; First preference: the existing game-identity parser already attached the
    ; exact HWND and Place ID to the signal log. Reuse it without screen probing.
    for _, path in paths {
        if (!gameIdentityLogState.Has(path))
            continue
        try {
            identity := gameIdentityLogState[path]
            hwnd := identity.hwnd
            placeId := identity.placeId
            if (!hwnd || !WinExist("ahk_id " . hwnd))
                continue
            if (WinGetProcessName("ahk_id " . hwnd) != "RobloxPlayerBeta.exe")
                continue

            pid := WinGetPID("ahk_id " . hwnd)
            if (!pid)
                continue

            if (placeId = "" && gameIdentityByPid.Has(pid)) {
                cached := gameIdentityByPid[pid]
                try placeId := cached.placeId
                catch
                    placeId := ""
            }

            if (placeId = "")
                continue

            mappedPids[pid] := true
            mappedHwnds[hwnd] := true
            disconnectLogDiagMappedPids := pid
            disconnectLogDiagMappedHwnds := "0x" . Format("{:X}", hwnd)
            return Map("hwnd", hwnd, "pid", pid, "placeId", placeId, "code", disconnectLogDiagCode)
        } catch {
        }
    }

    ; Second preference: Windows Restart Manager can tell us which Roblox PID
    ; currently owns the exact signal log. Then recover Place ID from the existing
    ; per-PID identity cache.
    for _, path in paths {
        for _, pid in Macro_GetPidsUsingRobloxLog(path) {
            for _, hwnd in WinGetList("ahk_exe RobloxPlayerBeta.exe") {
                try {
                    if (WinGetPID("ahk_id " . hwnd) != pid)
                        continue
                    if (!gameIdentityByPid.Has(pid))
                        continue
                    identity := gameIdentityByPid[pid]
                    placeId := ""
                    try placeId := identity.placeId
                    catch
                        placeId := ""
                    if (placeId = "")
                        continue
                    mappedPids[pid] := true
                    mappedHwnds[hwnd] := true
                    disconnectLogDiagMappedPids := pid
                    disconnectLogDiagMappedHwnds := "0x" . Format("{:X}", hwnd)
                    return Map("hwnd", hwnd, "pid", pid, "placeId", placeId, "code", disconnectLogDiagCode)
                } catch {
                }
            }
        }
    }

    disconnectLogDiagMappedPids := ""
    for pid, _ in mappedPids
        disconnectLogDiagMappedPids .= (disconnectLogDiagMappedPids = "" ? "" : ",") . pid
    disconnectLogDiagMappedHwnds := ""
    for hwnd, _ in mappedHwnds
        disconnectLogDiagMappedHwnds .= (disconnectLogDiagMappedHwnds = "" ? "" : ",") . ("0x" . Format("{:X}", hwnd))
    return 0
}

Macro_SnapshotRobloxPids() {
    pids := Map()
    ; AHK v2 has no ProcessGetList() built-in. Enumerate the existing
    ; Roblox windows and collect their owning PIDs instead.
    try {
        for hwnd in WinGetList("ahk_exe RobloxPlayerBeta.exe") {
            try {
                pid := WinGetPID("ahk_id " . hwnd)
                if (pid)
                    pids[pid] := true
            } catch {
            }
        }
    } catch {
    }
    return pids
}

Macro_FindNewRobloxPid(oldPids, excludedPid := 0) {
    ; AHK v2 has no ProcessGetList() built-in. Use the same window->PID
    ; mapping that the rest of this script already uses for Roblox clients.
    try {
        for hwnd in WinGetList("ahk_exe RobloxPlayerBeta.exe") {
            try {
                pid := WinGetPID("ahk_id " . hwnd)
                if (!pid || pid = excludedPid || oldPids.Has(pid))
                    continue
                return pid
            } catch {
            }
        }
    } catch {
    }
    return 0
}

Macro_LogAutoRejoinStep(*) {
    global connectionRecoveryEnabled, logAutoRejoinBusy, logAutoRejoinStage
    global CONNECTION_LOG_AUTO_REJOIN_ENABLE
    global logAutoRejoinTargetHwnd, logAutoRejoinTargetPid, logAutoRejoinPlaceId
    global logAutoRejoinCode, logAutoRejoinOriginalMinMax, logAutoRejoinOriginalForeground
    global logAutoRejoinOldPids, logAutoRejoinNewPid
    global logAutoRejoinCloseDeadlineTick, logAutoRejoinSpawnDeadlineTick, logAutoRejoinJoinDeadlineTick
    global logAutoRejoinLaunchAttempts, logAutoRejoinNextLaunchTick
    global logAutoRejoinLastStepTick, logAutoRejoinLastMessage
    global disconnectAlertStage, disconnectAlertPrimaryButton
    global CONNECTION_LOG_REJOIN_STEP_MS, CONNECTION_LOG_REJOIN_CLOSE_WAIT_MS
    global CONNECTION_LOG_REJOIN_SPAWN_WAIT_MS, CONNECTION_LOG_REJOIN_JOIN_WAIT_MS
    global CONNECTION_LOG_REJOIN_LAUNCH_RETRY_INTERVAL_MS, CONNECTION_LOG_REJOIN_MAX_LAUNCH_ATTEMPTS
    global AUTO_HIDDEN_SCAN_DELAY_SEC

    if (!connectionRecoveryEnabled || !CONNECTION_LOG_AUTO_REJOIN_ENABLE) {
        Macro_ResetLogAutoRejoinState()
        return
    }
    if (!logAutoRejoinBusy)
        return

    now := A_TickCount
    if (now - logAutoRejoinLastStepTick < Max(250, CONNECTION_LOG_REJOIN_STEP_MS - 50))
        return
    logAutoRejoinLastStepTick := now

    if (logAutoRejoinStage = "CLOSE_TARGET") {
        if (!logAutoRejoinTargetPid) {
            ; A no-target transaction should enter WAIT_SPAWN at setup; keep this
            ; guard as a safe fallback in case state was partially initialized.
            logAutoRejoinStage := "WAIT_SPAWN"
            logAutoRejoinSpawnDeadlineTick := now + CONNECTION_LOG_REJOIN_SPAWN_WAIT_MS
            logAutoRejoinLaunchAttempts := 0
            logAutoRejoinNextLaunchTick := now
            return
        }

        try {
            if (ProcessExist(logAutoRejoinTargetPid))
                ProcessClose(logAutoRejoinTargetPid)
        } catch {
            Macro_LogAutoRejoinFailed(Macro_GetLogAutoRejoinUIText("closeProcessFailed"))
            return
        }
        logAutoRejoinStage := "WAIT_CLOSED"
        logAutoRejoinCloseDeadlineTick := now + CONNECTION_LOG_REJOIN_CLOSE_WAIT_MS
        Macro_UpdateLogAutoRejoinAlert(Macro_GetLogAutoRejoinUIText("closingTarget", logAutoRejoinCode))
        return
    }

    if (logAutoRejoinStage = "WAIT_CLOSED") {
        if (ProcessExist(logAutoRejoinTargetPid)) {
            if (now >= logAutoRejoinCloseDeadlineTick) {
                try ProcessClose(logAutoRejoinTargetPid)
                catch {
                }
                logAutoRejoinCloseDeadlineTick := now + 2000
            }
            return
        }

        logAutoRejoinStage := "WAIT_SPAWN"
        logAutoRejoinSpawnDeadlineTick := now + CONNECTION_LOG_REJOIN_SPAWN_WAIT_MS
        logAutoRejoinLaunchAttempts := 0
        logAutoRejoinNextLaunchTick := now
        Macro_UpdateLogAutoRejoinAlert(Macro_GetLogAutoRejoinUIText("targetClosed", logAutoRejoinCode))
        return
    }

    if (logAutoRejoinStage = "WAIT_SPAWN") {
        newPid := Macro_FindNewRobloxPid(logAutoRejoinOldPids, logAutoRejoinTargetPid)
        if (newPid) {
            logAutoRejoinNewPid := newPid
            Macro_SizeLogAutoRejoinWindow(newPid)
            logAutoRejoinStage := "WAIT_JOIN"
            logAutoRejoinJoinDeadlineTick := now + CONNECTION_LOG_REJOIN_JOIN_WAIT_MS
            Macro_UpdateLogAutoRejoinAlert(Macro_GetLogAutoRejoinUIText("newPid", logAutoRejoinCode, newPid))
            return
        }

        ; The previous version dispatched roblox:// only once and then waited
        ; silently. Retry the launch dispatch while requiring a real new
        ; RobloxPlayerBeta.exe PID to appear before progressing.
        if (now >= logAutoRejoinNextLaunchTick && now < logAutoRejoinSpawnDeadlineTick) {
            if (logAutoRejoinLaunchAttempts < CONNECTION_LOG_REJOIN_MAX_LAUNCH_ATTEMPTS) {
                attemptNo := logAutoRejoinLaunchAttempts + 1
                if (!Macro_DispatchLogAutoRejoinLaunch(logAutoRejoinPlaceId, attemptNo)) {
                    Macro_LogAutoRejoinFailed(Macro_GetLogAutoRejoinUIText("launchDispatchFailed", "", attemptNo, CONNECTION_LOG_REJOIN_MAX_LAUNCH_ATTEMPTS))
                    return
                }
                logAutoRejoinLaunchAttempts := attemptNo
                logAutoRejoinNextLaunchTick := now + CONNECTION_LOG_REJOIN_LAUNCH_RETRY_INTERVAL_MS
                Macro_UpdateLogAutoRejoinAlert(Macro_GetLogAutoRejoinUIText("launchAttempt", logAutoRejoinCode, attemptNo, CONNECTION_LOG_REJOIN_MAX_LAUNCH_ATTEMPTS))
            }
        }

        if (now >= logAutoRejoinSpawnDeadlineTick) {
            Macro_LogAutoRejoinFailed(Macro_GetLogAutoRejoinUIText("spawnTimeout", "", CONNECTION_LOG_REJOIN_MAX_LAUNCH_ATTEMPTS))
            return
        }
        return
    }

    if (logAutoRejoinStage = "WAIT_JOIN") {
        if (Macro_LogAutoRejoinCheckJoin(logAutoRejoinNewPid, logAutoRejoinPlaceId)) {
            Macro_FinishLogAutoRejoin(true)
            return
        }
        if (now >= logAutoRejoinJoinDeadlineTick) {
            Macro_LogAutoRejoinFailed(Macro_GetLogAutoRejoinUIText("joinNotConfirmed"))
            return
        }
    }
}

Macro_SizeLogAutoRejoinWindow(pid) {
    global CONNECTION_LOG_REJOIN_WINDOW_WIDTH

    if (!pid || !CONNECTION_LOG_REJOIN_WINDOW_WIDTH)
        return false

    try {
        for hwnd in WinGetList("ahk_pid " . pid) {
            try {
                if (WinGetProcessName("ahk_id " . hwnd) != "RobloxPlayerBeta.exe")
                    continue

                minMax := 0
                try minMax := WinGetMinMax("ahk_id " . hwnd)
                catch
                    minMax := 0

                if (minMax != 0) {
                    try WinRestore("ahk_id " . hwnd)
                    catch
                        continue
                    Sleep(100)
                }

                WinGetPos(&x, &y, &w, &h, "ahk_id " . hwnd)
                if (h <= 0)
                    h := 1080

                ; Keep the new window's current position and height; change only width.
                WinMove(x, y, CONNECTION_LOG_REJOIN_WINDOW_WIDTH, h, "ahk_id " . hwnd)
                return true
            } catch {
            }
        }
    } catch {
    }
    return false
}

; Apply the same 1920px launch width to ordinary Roblox client launches. The
; watcher only acts on HWND/PID pairs that appear after script startup.
Macro_WatchNewRobloxWindows() {
    static knownClients := Map()
    static initialized := false
    global CONNECTION_LOG_REJOIN_WINDOW_WIDTH

    currentClients := Map()
    try {
        for hwnd in WinGetList("ahk_exe RobloxPlayerBeta.exe") {
            try {
                if (WinGetProcessName("ahk_id " . hwnd) != "RobloxPlayerBeta.exe")
                    continue
                pid := WinGetPID("ahk_id " . hwnd)
                currentClients[hwnd] := pid
            } catch {
            }
        }
    } catch {
        return
    }

    ; Existing clients keep their chosen size when the script starts.
    if (!initialized) {
        for hwnd, pid in currentClients
            knownClients[hwnd] := pid
        initialized := true
        return
    }

    staleHwnds := []
    for hwnd, pid in knownClients {
        if (!currentClients.Has(hwnd) || currentClients[hwnd] != pid)
            staleHwnds.Push(hwnd)
    }
    for hwnd in staleHwnds
        knownClients.Delete(hwnd)

    for hwnd, pid in currentClients {
        if (knownClients.Has(hwnd) && knownClients[hwnd] = pid)
            continue

        ; A new Roblox client is also a useful moment to expose singleton
        ; protection status. This notification is deduplicated by process PID.
        Roblox_NotifySingletonOnNewClient(hwnd, pid)

        if (Macro_SizeNewRobloxWindow(hwnd, CONNECTION_LOG_REJOIN_WINDOW_WIDTH))
            knownClients[hwnd] := pid
    }
}

Macro_SizeNewRobloxWindow(hwnd, targetWidth) {
    if (!hwnd || !targetWidth || !WinExist("ahk_id " . hwnd))
        return false
    try {
        if (WinGetProcessName("ahk_id " . hwnd) != "RobloxPlayerBeta.exe")
            return false
        minMax := WinGetMinMax("ahk_id " . hwnd)
        if (minMax != 0) {
            WinRestore("ahk_id " . hwnd)
            Sleep(100)
        }
        WinGetPos(&x, &y, &w, &h, "ahk_id " . hwnd)
        if (h <= 0)
            return false
        ; Keep the launch position and height, changing only its width.
        WinMove(x, y, targetWidth, h, "ahk_id " . hwnd)
        Sleep(80)
        WinGetPos(&actualX, &actualY, &actualW, &actualH, "ahk_id " . hwnd)
        return (actualW > 0 && Abs(actualW - targetWidth) <= 8)
    } catch {
        return false
    }
}

Macro_DispatchLogAutoRejoinLaunch(placeId, attemptNo) {
    if (!placeId)
        return false

    ; Modern Roblox desktop launches games through this experience-start
    ; deep-link. Keep the older placeId form as a compatibility fallback.
    modernUri := "roblox://experiences/start?placeId=" . placeId
    legacyUri := "roblox://placeId=" . placeId
    webUri := "https://www.roblox.com/games/start?placeId=" . placeId

    ; This script runs elevated. Hand protocol URLs to the normal Windows
    ; Explorer shell instead of asking the elevated AHK process to own the
    ; protocol dispatch. This avoids HKCU/protocol-handler context issues.
    try {
        if (attemptNo = 1) {
            Run('explorer.exe "' . modernUri . '"')
            return true
        }

        if (attemptNo = 2) {
            Run('explorer.exe "' . legacyUri . '"')
            return true
        }

        if (attemptNo = 3) {
            Run('explorer.exe "' . webUri . '"')
            return true
        }

        ; Final fallback: simulate double-clicking a Windows Internet Shortcut
        ; using the modern Roblox experience-start URI.
        tempUrl := A_Temp . "\RobloxReconnect_" . A_TickCount . "_" . attemptNo . ".url"
        FileAppend("[InternetShortcut]`r`nURL=" . modernUri . "`r`n", tempUrl, "UTF-8")
        Run('explorer.exe "' . tempUrl . '"')
        SetTimer((*) => FileDeleteSafe(tempUrl), -30000)
        return true
    } catch {
        return false
    }
}

FileDeleteSafe(path) {
    try FileDelete(path)
}

Macro_LogAutoRejoinCheckJoin(pid, placeId, expectedUserId := "") {
    global gameIdentityByPid
    global CONNECTION_LOG_REJOIN_LOG_TAIL_BYTES

    if (!pid || !placeId)
        return false

    ; The identity record stores game category in .state (RNG_HEROES / OTHER_ROBLOX_GAME)
    ; and connection presence in .presence (IN_GAME / DISCONNECTED / ONLINE). The old
    ; check used identity.state = "IN_GAME", which can never be true in this script.
    if (gameIdentityByPid.Has(pid)) {
        try {
            identity := gameIdentityByPid[pid]
            identityPlaceId := identity.HasOwnProp("placeId") ? Trim(identity.placeId . "") : ""
            identityUserId := identity.HasOwnProp("userId") ? Trim(identity.userId . "") : ""
            identityPresence := identity.HasOwnProp("presence") ? identity.presence : ""
            if (expectedUserId != "" && identityUserId != "" && identityUserId != expectedUserId)
                return false
            identityHwnd := identity.HasOwnProp("hwnd") ? identity.hwnd : 0
            identityPath := identity.HasOwnProp("logPath") ? identity.logPath : ""
            liveForPid := !!identityHwnd && WinExist("ahk_id " . identityHwnd)
                && WinGetProcessName("ahk_id " . identityHwnd) = "RobloxPlayerBeta.exe"
                && WinGetPID("ahk_id " . identityHwnd) = pid

            if (identityPlaceId = placeId && identityPresence = "IN_GAME" && liveForPid
                && identityPath != "" && FileExist(identityPath)) {
                try size := FileGetSize(identityPath)
                catch
                    size := 0
                if (size > 0) {
                    text := Macro_ReadRobloxLogTail(identityPath, size,
                        Max(CONNECTION_LOG_REJOIN_LOG_TAIL_BYTES, 524288), &readOk, &bytesRead)
                    if (readOk && Macro_GetPlaceJoinStateFromText(text, placeId) = "IN_GAME"
                        && Macro_LogTextMatchesUserId(text, expectedUserId))
                        return true
                }
            }
        } catch {
        }
    }

    localAppData := EnvGet("LOCALAPPDATA")
    if (!localAppData)
        return false
    logDir := localAppData . "\\Roblox\\logs"
    if !DirExist(logDir)
        return false

    try {
        for _, path in Macro_GetRecentRobloxLogPaths(logDir, 12) {
            if (!Macro_LogBelongsToPid(path, pid))
                continue
            try size := FileGetSize(path)
            catch
                size := 0
            if (!size)
                continue
            tail := Macro_ReadRobloxLogTail(path, size,
                Max(CONNECTION_LOG_REJOIN_LOG_TAIL_BYTES, 524288), &readOk, &bytesRead)
            if (!readOk || tail = "")
                continue

            ; Only treat the most recent session as recovered. A stale historical
            ; "Joining game" or success marker before a later error is not enough.
            if (Macro_GetPlaceJoinStateFromText(tail, placeId) = "IN_GAME"
                && Macro_LogTextMatchesUserId(tail, expectedUserId))
                return true
        }
    } catch {
    }
    return false
}

; Parse the latest session in a log in order. Results are UNKNOWN, JOINING,
; IN_GAME, DISCONNECTED, ONLINE, or OTHER_GAME. A join succeeds only after a
; success marker, and any later disconnect invalidates that success until a new
; Joining game line appears. This avoids matching an old successful session.
Macro_GetPlaceJoinStateFromText(text, targetPlaceId) {
    currentPlaceId := ""
    state := "UNKNOWN"

    if (text = "")
        return state

    for line in StrSplit(text, Chr(10), Chr(13)) {
        if (RegExMatch(line, "i)Joining game.*?place\s+(\d+)", &pm)) {
            currentPlaceId := pm[1]
            state := (currentPlaceId = targetPlaceId) ? "JOINING" : "OTHER_GAME"
            continue
        }

        if (currentPlaceId = "")
            continue

        if (RegExMatch(line,
            "i)(Error Code\s*:\s*\d+|Disconnect reason received\s*:\s*(?!285\b)\d+|Disconnection Notification\.\s*Reason\s*:\s*(?!285\b)\d+|Sending disconnect with reason\s*:\s*(?!285\b)\d+|Lost connection to the game server|Lost connection with reason\s*:|Client has been disconnected with reason\s*:|Connection lost(?:\s|:|$)|Session Transition FSM:\s*Error Occurred\.)")) {
            state := "DISCONNECTED"
            continue
        }

        if (InStr(line, "leaveUGCGameInternal") || InStr(line, "returnToLuaApp")) {
            state := "ONLINE"
            continue
        }

        if (state = "JOINING" || state = "IN_GAME") {
            if (RegExMatch(line, "i)Connection accepted from")
                || RegExMatch(line, "i)DataModelLoadingPhase::OnAfterLoadingComplete")
                || RegExMatch(line, "i)joinGamePostStandard finished")
                || InStr(line, "Entered play session."))
                state := "IN_GAME"
        }
    }

    if (currentPlaceId != targetPlaceId)
        return "OTHER_GAME"
    return state
}

Macro_GetRecentRobloxLogPaths(logDir, maxCount := 8) {
    entries := []
    try {
        Loop Files, logDir . "\\*.log", "F" {
            entries.Push(Map("path", A_LoopFileFullPath, "modified", A_LoopFileTimeModified))
        }
    } catch {
        return []
    }

    ; Sort newest first without relying on object comparisons.
    Loop entries.Length {
        changed := false
        maxIndex := entries.Length - A_Index
        Loop maxIndex {
            i := A_Index
            a := entries[i]["modified"]
            b := entries[i + 1]["modified"]
            if (a < b) {
                temp := entries[i]
                entries[i] := entries[i + 1]
                entries[i + 1] := temp
                changed := true
            }
        }
        if (!changed)
            break
    }

    paths := []
    limit := Min(maxCount, entries.Length)
    Loop limit
        paths.Push(entries[A_Index]["path"])
    return paths
}

Macro_LogBelongsToPid(path, pid) {
    global gameIdentityByPid

    if (!path || !pid)
        return false

    ; The game-identity cache explicitly binds a live PID to the exact log path.
    if (gameIdentityByPid.Has(pid)) {
        try {
            identity := gameIdentityByPid[pid]
            if (identity.HasOwnProp("logPath") && identity.logPath = path)
                return true
        } catch {
        }
    }

    ; Restart Manager is useful while the file is open, but it is not a reliable
    ; only source for Roblox's short-lived/replaced log handles.
    try {
        for _, ownerPid in Macro_GetPidsUsingRobloxLog(path) {
            if (ownerPid = pid)
                return true
        }
    } catch {
    }

    ; Finally, map the HWND recorded near the start/end of the log to its current
    ; live Roblox process. This uses log text and process metadata only—no pixels.
    try {
        ownerPid := Macro_GetRobloxLogWindowPid(path)
        if (ownerPid && ownerPid = pid)
            return true
    } catch {
    }
    return false
}

Macro_GetRobloxLogWindowPid(path) {
    if (path = "" || !FileExist(path))
        return 0

    size := 0
    try size := FileGetSize(path)
    catch
        size := 0
    if (!size)
        return 0

    sample := ""
    f := ""
    try {
        f := FileOpen(path, "r", "UTF-8")
        if (!f)
            return 0
        headSize := Min(size, 65536)
        sample := f.Read(headSize)
        if (size > 65536) {
            f.Seek(Max(0, size - 65536), 0)
            sample .= "`n" . f.Read(65536)
        }
        f.Close()
        f := ""
    } catch {
        try {
            if (IsObject(f))
                f.Close()
        } catch {
        }
        return 0
    }

    searchPos := 1
    while (searchPos <= StrLen(sample)) {
        if (!RegExMatch(sample, "i)(?:window|windowHandle)\s*=\s*0x([0-9a-f]+)", &m, searchPos))
            break
        searchPos := m.Pos[0] + Max(1, m.Len[0])
        hwnd := 0
        try hwnd := Integer("0x" . m[1])
        catch
            hwnd := 0
        if (!hwnd || !WinExist("ahk_id " . hwnd))
            continue
        try {
            if (WinGetProcessName("ahk_id " . hwnd) != "RobloxPlayerBeta.exe")
                continue
            pid := WinGetPID("ahk_id " . hwnd)
            if (pid)
                return pid
        } catch {
        }
    }
    return 0
}

Macro_GetLogAutoRejoinUIText(key, code := "", value1 := 0, value2 := 0) {
    isKorean := (Macro_GetWindowsUILanguage() = "ko")
    codeLabel := (code != "") ? (isKorean ? "Roblox " . code : "Roblox error " . code) : "Roblox"
    switch key {
        case "missingPlaceId":
            return isKorean
                ? codeLabel . " 연결 해제는 확인했지만 로그에서 게임 Place ID를 찾지 못해 자동 재접속을 시작할 수 없습니다."
                : codeLabel . " disconnect was detected, but the game Place ID could not be found in the logs. Automatic rejoin cannot start."
        case "closeProcessFailed":
            return isKorean ? "대상 Roblox 프로세스를 종료하지 못했습니다." : "Could not close the target Roblox process."
        case "starting":
            return isKorean
                ? codeLabel . " 연결 해제 확인 → 로그 기반 자동 재접속 준비 중..."
                : codeLabel . " disconnect confirmed → preparing log-based automatic rejoin..."
        case "closingTarget":
            return isKorean
                ? codeLabel . " 연결 해제 감지`n대상 Roblox 종료 → 재접속 준비 중..."
                : codeLabel . " disconnect detected`nClosing the target Roblox client → preparing to rejoin..."
        case "targetClosed":
            return isKorean
                ? codeLabel . " 연결 해제 감지`n대상 Roblox 종료 확인 → 재실행 명령 준비..."
                : codeLabel . " disconnect detected`nTarget Roblox client closed → preparing relaunch..."
        case "newPid":
            return isKorean
                ? codeLabel . " 연결 해제 감지`n새 Roblox PID " . value1 . " 생성됨`n게임 입장 확인 중..."
                : codeLabel . " disconnect detected`nNew Roblox PID " . value1 . " created`nChecking whether the game was joined..."
        case "launchDispatchFailed":
            return isKorean
                ? "Roblox 재실행 명령 전달에 실패했습니다. 시도 " . value1 . "/" . value2
                : "Failed to dispatch the Roblox relaunch command. Attempt " . value1 . "/" . value2
        case "launchAttempt":
            return isKorean
                ? codeLabel . " 연결 해제 감지`nRoblox 재실행 시도 " . value1 . "/" . value2 . "..."
                : codeLabel . " disconnect detected`nRelaunching Roblox, attempt " . value1 . "/" . value2 . "..."
        case "spawnTimeout":
            return isKorean
                ? "Roblox 재실행을 " . value1 . "회 시도했지만 새 RobloxPlayerBeta.exe가 생성되지 않았습니다."
                : "Roblox was relaunched " . value1 . " times, but no new RobloxPlayerBeta.exe process appeared."
        case "joinNotConfirmed":
            return isKorean
                ? "새 Roblox는 실행됐지만 같은 게임의 실제 입장을 로그에서 확인하지 못했습니다."
                : "A new Roblox client started, but the logs did not confirm that it joined the same game."
        case "failed":
            return isKorean ? "자동 재접속에 실패했습니다." : "Automatic rejoin failed."
    }
    return key
}

Macro_UpdateLogAutoRejoinAlert(messageText) {
    global logAutoRejoinLastMessage
    global disconnectAlertActive, disconnectAlertTitle, disconnectAlertBody, disconnectAlertStage
    global disconnectAlertPrimaryButton

    if (messageText = logAutoRejoinLastMessage)
        return
    logAutoRejoinLastMessage := messageText

    if (!disconnectAlertActive || !IsObject(disconnectAlertBody))
        return
    try {
        disconnectAlertStage := "Reconnecting"
        disconnectAlertTitle.Text := Macro_GetDisconnectUIText("reconnectingTitle")
        disconnectAlertBody.Text := messageText
        disconnectAlertPrimaryButton.Enabled := false
        Macro_ResizeDisconnectAlert()
    } catch {
    }
}

Macro_LogAutoRejoinFailed(messageText) {
    global logAutoRejoinBusy, logAutoRejoinStage
    global disconnectAlertActive, disconnectAlertStage, disconnectAlertBody
    global disconnectAlertPrimaryButton, disconnectAlertTitle
    global disconnectAlertLastRecoveryAttempts

    logAutoRejoinBusy := false
    logAutoRejoinStage := "Failed"
    SetTimer(Macro_LogAutoRejoinStep, 0)
    try {
        disconnectAlertStage := "Failed"
        disconnectAlertTitle.Text := Macro_GetDisconnectUIText("failedTitle")
        disconnectAlertBody.Text := messageText
        disconnectAlertPrimaryButton.Enabled := true
        disconnectAlertPrimaryButton.Text := Macro_GetDisconnectUIText("inspect")
        Macro_ResizeDisconnectAlert()
    } catch {
    }
}

Macro_FinishLogAutoRejoin(success := false) {
    global logAutoRejoinBusy, logAutoRejoinStage
    global logAutoRejoinTargetHwnd, logAutoRejoinTargetPid, logAutoRejoinPlaceId
    global logAutoRejoinNewPid, logAutoRejoinLastMessage
    global logAutoRejoinCode, logAutoRejoinStartTick, logAutoRejoinCloseDeadlineTick
    global logAutoRejoinSpawnDeadlineTick, logAutoRejoinJoinDeadlineTick, logAutoRejoinLastStepTick
    global logAutoRejoinLaunchAttempts, logAutoRejoinNextLaunchTick
    global disconnectAlertActive, disconnectAlertStage, disconnectAlertBody, disconnectAlertReason
    global disconnectAlertPrimaryButton, disconnectAlertTitle
    global disconnectRecoveryTotalSuccesses, disconnectAlertLastRecoveryAttempts, disconnectAlertLastSuccessTime

    if (!logAutoRejoinBusy)
        return

    if (success) {
        disconnectRecoveryTotalSuccesses += 1
        disconnectAlertLastRecoveryAttempts := 1
        disconnectAlertLastSuccessTime := Macro_Format12HourCurrentTime(A_Now)
        ; Keep game-specific completion history consistent even if log-based
        ; auto-rejoin is enabled later; the normal modal-click route uses the same recorder.
        Macro_RecordSuccessfulRecovery(1, disconnectAlertLastSuccessTime,
            logAutoRejoinTargetHwnd, logAutoRejoinNewPid ? logAutoRejoinNewPid : logAutoRejoinTargetPid,
            Macro_GetRobloxGameNameForHwnd(logAutoRejoinTargetHwnd))
        try {
            disconnectAlertStage := "Reconnected"
            disconnectAlertTitle.Text := Macro_GetDisconnectUIText("reconnectedTitle")
            Macro_RecordDisconnectProcessStep("complete", disconnectAlertLastSuccessTime)
            disconnectAlertBody.Text := Macro_GetDisconnectCompletedBody(disconnectAlertReason,
                "PID: " . logAutoRejoinNewPid . "`nPlace ID: " . logAutoRejoinPlaceId)
            disconnectAlertPrimaryButton.Enabled := true
            disconnectAlertPrimaryButton.Text := Macro_GetDisconnectUIText("close")
            Macro_ResizeDisconnectAlert()
        } catch {
        }
    } else {
        Macro_LogAutoRejoinFailed(Macro_GetLogAutoRejoinUIText("failed"))
        return
    }

    logAutoRejoinBusy := false
    logAutoRejoinStage := ""
    logAutoRejoinTargetHwnd := 0
    logAutoRejoinTargetPid := 0
    logAutoRejoinPlaceId := ""
    logAutoRejoinCode := ""
    logAutoRejoinNewPid := 0
    logAutoRejoinStartTick := 0
    logAutoRejoinCloseDeadlineTick := 0
    logAutoRejoinSpawnDeadlineTick := 0
    logAutoRejoinJoinDeadlineTick := 0
    logAutoRejoinLastStepTick := 0
    logAutoRejoinLaunchAttempts := 0
    logAutoRejoinNextLaunchTick := 0
    logAutoRejoinLastMessage := ""
    SetTimer(Macro_LogAutoRejoinStep, 0)
}

Macro_ResetLogAutoRejoinState() {
    global logAutoRejoinBusy, logAutoRejoinStage
    global logAutoRejoinTargetHwnd, logAutoRejoinTargetPid, logAutoRejoinPlaceId
    global logAutoRejoinCode, logAutoRejoinOriginalMinMax, logAutoRejoinOriginalForeground
    global logAutoRejoinOldPids, logAutoRejoinNewPid
    global logAutoRejoinStartTick, logAutoRejoinCloseDeadlineTick
    global logAutoRejoinSpawnDeadlineTick, logAutoRejoinJoinDeadlineTick
    global logAutoRejoinLaunchAttempts, logAutoRejoinNextLaunchTick
    global logAutoRejoinPendingSince, logAutoRejoinLastStepTick, logAutoRejoinLastMessage

    SetTimer(Macro_LogAutoRejoinStep, 0)
    logAutoRejoinBusy := false
    logAutoRejoinStage := ""
    logAutoRejoinTargetHwnd := 0
    logAutoRejoinTargetPid := 0
    logAutoRejoinPlaceId := ""
    logAutoRejoinCode := ""
    logAutoRejoinOriginalMinMax := 0
    logAutoRejoinOriginalForeground := 0
    logAutoRejoinOldPids := Map()
    logAutoRejoinNewPid := 0
    logAutoRejoinStartTick := 0
    logAutoRejoinCloseDeadlineTick := 0
    logAutoRejoinSpawnDeadlineTick := 0
    logAutoRejoinJoinDeadlineTick := 0
    logAutoRejoinPendingSince := 0
    logAutoRejoinLastStepTick := 0
    logAutoRejoinLaunchAttempts := 0
    logAutoRejoinNextLaunchTick := 0
    logAutoRejoinLastMessage := ""
}

Macro_StartConnectionRecovery() {
    global connectionRecoveryBusy, connectionRecoveryHwnd, connectionRecoveryAttempts
    global connectionRecoveryStableChecks, connectionRecoveryNextTick, connectionRecoveryStage
    global connectionRecoveryOriginalForeground
    global connectionRecoveryOriginalMinMax, connectionRecoveryDiscoveredMinMax
    global connectionRecoveryDetectedHwnd, connectionRecoveryDetectedPid, connectionRecoveryDetectedVerified
    global connectionRecoveryTargetPid, connectionRecoveryQueue, connectionRecoveryPending, connectionRecoveryPendingSince, connectionRecoveryNextDeepScanTick
    global connectionRecoveryGameName
    global connectionRecoveryLastFocusVerifyTick
    global CONNECTION_RECONNECT_CONFIRM_WAIT_MS, CONNECTION_DEEP_SCAN_INTERVAL_MS
    global USER_ACTIVITY_TIMEOUT_MS
    global disconnectAlertGui, disconnectAlertTitle, disconnectAlertBody, disconnectAlertPrimaryButton, disconnectAlertStage
    global disconnectAlertActive
    global disconnectAlertLastRecoveryAttempts, disconnectAlertReason
    global disconnectRecoveryTotalAttempts
    global connectionRecoveryAutoBatch, connectionRecoveryStartFailureCounts
    global AUTO_HIDDEN_SCAN_DELAY_SEC

    if (connectionRecoveryBusy)
        return

    ; Automatic recovery is allowed only while the user is physically idle.
    ; Do not focus/activate another Roblox client while the user is using Roblox,
    ; Chrome, or any other application. Manual inspection uses a separate path.
    if (Macro_IsUserActiveAnywhere(AUTO_HIDDEN_SCAN_DELAY_SEC * 1000)) {
        ; A tiny user-activity race between the batch worker and this guard must
        ; postpone, not strand, the remaining automatic candidates.
        if (connectionRecoveryAutoBatch)
            SetTimer(Macro_StartNextAutomaticBatchReconnect, -1000)
        return
    }

    connectionRecoveryOriginalForeground := WinExist("A")
    connectionRecoveryOriginalMinMax := 0
    connectionRecoveryDiscoveredMinMax := 0
    connectionRecoveryLastFocusVerifyTick := 0

    ; Prefer the oldest candidate already identified. This is the key change for
    ; simultaneous disconnects: one recovery transaction owns one exact HWND+PID,
    ; while the other disconnected clients remain queued.
    candidate := Macro_PeekReconnectCandidate()
    if (!candidate) {
        if (connectionRecoveryDetectedHwnd && WinExist("ahk_id " . connectionRecoveryDetectedHwnd)) {
            detectedPid := 0
            try detectedPid := WinGetPID("ahk_id " . connectionRecoveryDetectedHwnd)
            catch
                detectedPid := 0
            if (!connectionRecoveryDetectedPid || !detectedPid || detectedPid = connectionRecoveryDetectedPid)
                candidate := Map("hwnd", connectionRecoveryDetectedHwnd, "pid", detectedPid, "minmax", connectionRecoveryDiscoveredMinMax)
        }
    }

    ; Automatic recovery must use the candidates already found by the current
    ; watchdog cycle. Do not perform another full Roblox scan here.
    if (!candidate) {
        connectionRecoveryNextDeepScanTick := A_TickCount + CONNECTION_DEEP_SCAN_INTERVAL_MS
        return
    }

    ; The candidate was already confirmed by the visible or hidden scan in this
    ; watchdog cycle. Do not probe the same Roblox screen again before clicking.
    targetHwnd := candidate["hwnd"]
    targetPid := candidate["pid"]
    ; Capture game identity before the modal click can change/recycle the client.
    connectionRecoveryGameName := ""
    try connectionRecoveryGameName := Trim(Macro_GetRobloxGameNameForHwnd(targetHwnd) . "")
    catch
        connectionRecoveryGameName := ""
    Macro_RemoveReconnectCandidate(targetHwnd, targetPid)
    connectionRecoveryNextDeepScanTick := 0
    connectionRecoveryHwnd := targetHwnd
    connectionRecoveryTargetPid := targetPid
    connectionRecoveryAttempts := 0
    connectionRecoveryStableChecks := 0
    MouseMacro_ForceOffForDisconnect("reconnection started")
    connectionRecoveryBusy := true
    connectionRecoveryStage := "NeedClick"

    connectionRecoveryOriginalMinMax := candidate["minmax"]
    connectionRecoveryDetectedHwnd := targetHwnd
    connectionRecoveryDetectedPid := targetPid
    connectionRecoveryDetectedVerified := true

    if (!Macro_ClickReconnectForWindow(targetHwnd)) {
        Macro_RecordDisconnectProcessStep("click_failed")
        ; Requeue a click failure at the tail, but bound immediate retries so one
        ; unclickable/closed modal cannot monopolize the queue forever.
        failureKey := targetHwnd . "|" . targetPid
        startFailures := connectionRecoveryStartFailureCounts.Has(failureKey)
            ? connectionRecoveryStartFailureCounts[failureKey] + 1 : 1
        if (startFailures < 2) {
            connectionRecoveryStartFailureCounts[failureKey] := startFailures
            Macro_QueueReconnectCandidate(targetHwnd, targetPid, candidate["minmax"])
        } else {
            connectionRecoveryStartFailureCounts.Delete(failureKey)
        }
        connectionRecoveryBusy := false
        connectionRecoveryHwnd := 0
        connectionRecoveryTargetPid := 0
        connectionRecoveryAttempts := 0
        connectionRecoveryStableChecks := 0
        connectionRecoveryNextTick := 0
        connectionRecoveryStage := ""
        connectionRecoveryPending := false
        connectionRecoveryPendingSince := 0
        ; Clicking failed: show a truthful failure message rather than leaving stale progress copy.
        try {
            if (disconnectAlertActive && IsObject(disconnectAlertGui) && disconnectAlertGui.Hwnd) {
                disconnectAlertStage := "Failed"
                disconnectAlertTitle.Text := Macro_GetDisconnectUIText("failedTitle")
                disconnectAlertBody.Text := Macro_GetDisconnectUIText("clickFailed")
                disconnectAlertPrimaryButton.Enabled := true
                disconnectAlertPrimaryButton.Text := Macro_GetDisconnectUIText("retry")
                Macro_ResizeDisconnectAlert()
            }
        } catch {
        }
        if (connectionRecoveryAutoBatch) {
            nextAfterClickFail := Macro_PeekReconnectCandidate()
            if (nextAfterClickFail
                && (nextAfterClickFail["hwnd"] != targetHwnd
                    || nextAfterClickFail["pid"] != targetPid)) {
                SetTimer(Macro_StartNextAutomaticBatchReconnect, -250)
            } else {
                ; Leave a lone failed item queued for explicit retry instead of
                ; spinning continuously on a modal that could not be clicked.
                connectionRecoveryAutoBatch := false
            }
        }
        return
    }

    successKey := targetHwnd . "|" . targetPid
    if (connectionRecoveryStartFailureCounts.Has(successKey))
        connectionRecoveryStartFailureCounts.Delete(successKey)
    Macro_RecordDisconnectProcessStep("reconnect_click")
    connectionRecoveryAttempts := 1
    disconnectRecoveryTotalAttempts += 1
    disconnectAlertLastRecoveryAttempts := connectionRecoveryAttempts
    connectionRecoveryStage := "Confirm"
    connectionRecoveryNextTick := A_TickCount + CONNECTION_RECONNECT_CONFIRM_WAIT_MS
    connectionRecoveryPending := true

    Macro_ShowDisconnectTrayProgress("재연결 버튼을 클릭했습니다.`n복구 여부를 확인하는 중입니다...", "🔄 ROBLOX 재연결 중")

    try {
        disconnectAlertStage := "Reconnecting"
        disconnectAlertTitle.Text := Macro_GetDisconnectUIText("reconnectingTitle")
        disconnectAlertBody.Text := Macro_GetDisconnectAlertBody(disconnectAlertReason)
        Macro_ResizeDisconnectAlert()
        disconnectAlertPrimaryButton.Text := Macro_GetDisconnectUIText("checkingButton")
        disconnectAlertPrimaryButton.Enabled := false
    } catch {
    }

    ; Reconnect status stays inside the existing diagnostic window; no separate
    ; Windows toast is created for the recovery transaction.
}

Macro_CheckConnectionRecovery() {
    global connectionRecoveryBusy, connectionRecoveryHwnd, connectionRecoveryAttempts, connectionRecoveryAutoBatch
    global AUTO_HIDDEN_SCAN_DELAY_SEC
    global connectionRecoveryTargetPid, connectionRecoveryDetectedHwnd, connectionRecoveryDetectedPid, connectionRecoveryDetectedVerified
    global connectionRecoveryStableChecks, connectionRecoveryNextTick, connectionRecoveryStage
    global connectionRecoveryOriginalForeground, connectionRecoveryLastFocusVerifyTick
    global connectionRecoveryOriginalMinMax, connectionRecoveryPending, connectionRecoveryPendingSince
    global disconnectAlertGui, disconnectAlertTitle, disconnectAlertBody, disconnectAlertPrimaryButton, disconnectAlertStage
    global disconnectAlertActive
    global disconnectAlertLastRecoveryAttempts, disconnectAlertReason
    global disconnectRecoveryTotalAttempts
    global CONNECTION_RECONNECT_CONFIRM_WAIT_MS, CONNECTION_RECONNECT_STABLE_CHECKS
    global CONNECTION_RECONNECT_MAX_ATTEMPTS, CONNECTION_HIDDEN_VERIFY_INTERVAL_MS, USER_ACTIVITY_TIMEOUT_MS
    global fixedPointModalDebugProbeRunning, fixedPointModalDebugProbeBusyHwnd

    hwnd := connectionRecoveryHwnd
    if (!hwnd || !WinExist("ahk_id " . hwnd)) {
        ; The active client disappeared. Preserve every other queued candidate.
        Macro_RemoveReconnectCandidate(hwnd, connectionRecoveryTargetPid)
        connectionRecoveryBusy := false
        connectionRecoveryHwnd := 0
        connectionRecoveryTargetPid := 0
        connectionRecoveryAttempts := 0
        connectionRecoveryStableChecks := 0
        connectionRecoveryNextTick := 0
        connectionRecoveryStage := ""
        connectionRecoveryPending := false
        connectionRecoveryPendingSince := 0
        nextCandidate := Macro_PeekReconnectCandidate()
        if (nextCandidate) {
            connectionRecoveryDetectedHwnd := nextCandidate["hwnd"]
            connectionRecoveryDetectedPid := nextCandidate["pid"]
            connectionRecoveryDetectedVerified := true
            try {
                if (disconnectAlertActive && IsObject(disconnectAlertGui) && disconnectAlertGui.Hwnd) {
                    disconnectAlertStage := "Signal"
                    disconnectAlertTitle.Text := Macro_GetDisconnectCodeTitle()
                    disconnectAlertBody.Text := Macro_GetVisibleReconnectReason()
                    Macro_ResizeDisconnectAlert()
                    disconnectAlertPrimaryButton.Enabled := true
                    disconnectAlertPrimaryButton.Text := Macro_GetDisconnectUIText("inspect")
                }
            } catch {
            }
        } else {
            ; The old client vanished; without another target, recovery cannot be verified.
            try {
                if (disconnectAlertActive && IsObject(disconnectAlertGui) && disconnectAlertGui.Hwnd) {
                    disconnectAlertStage := "Failed"
                    disconnectAlertTitle.Text := Macro_GetDisconnectUIText("failedTitle")
                    disconnectAlertBody.Text := Macro_GetDisconnectUIText("targetClosed")
                    Macro_ResizeDisconnectAlert()
                    disconnectAlertPrimaryButton.Enabled := true
                    disconnectAlertPrimaryButton.Text := Macro_GetDisconnectUIText("retry")
                }
            } catch {
            }
        }
        ; If the active client closed during recovery, do not strand the other
        ; accounts that were already confirmed and queued behind it.
        if (connectionRecoveryAutoBatch) {
            if (nextCandidate)
                SetTimer(Macro_StartNextAutomaticBatchReconnect, -150)
            else
                connectionRecoveryAutoBatch := false
        }
        return
    }

    if (fixedPointModalDebugProbeRunning && fixedPointModalDebugProbeBusyHwnd = hwnd) {
        connectionRecoveryNextTick := A_TickCount + 500
        return
    }

    nowTick := A_TickCount
    userActive := Macro_IsUserActiveAnywhere(AUTO_HIDDEN_SCAN_DELAY_SEC * 1000)

    ; First try a completely non-invasive visual check. A clean result here means
    ; the reconnect modal is already gone, so recovery is complete immediately.
    result := Macro_ProbeReconnectDialog(hwnd, false)

    if (result = 0) {
        Macro_FinishConnectionRecovery(true)
        return
    }

    if (userActive) {
        ; Never steal focus or send another reconnect click while the user is active.
        ; Keep the SAME confirmed HWND pending and re-check shortly.
        connectionRecoveryNextTick := nowTick + 1000
        return
    }

    if (result = -1) {
        ; The target is hidden/minimized/occluded, so screen pixels cannot be read safely
        ; without activating it. Once the user is idle, activate THIS SAME HWND promptly.
        if (nowTick - connectionRecoveryLastFocusVerifyTick < CONNECTION_HIDDEN_VERIFY_INTERVAL_MS) {
            connectionRecoveryNextTick := nowTick + 500
            return
        }

        connectionRecoveryLastFocusVerifyTick := nowTick
        result := Macro_ProbeReconnectDialog(hwnd, true)
        if (result = -1) {
            connectionRecoveryNextTick := nowTick + 1000
            return
        }

        ; The focus probe itself is a full confirmation of this exact target.
        if (result = 0) {
            Macro_FinishConnectionRecovery(true)
            return
        }
    }

    connectionRecoveryStableChecks := 0

    if (connectionRecoveryAttempts >= CONNECTION_RECONNECT_MAX_ATTEMPTS) {
        try {
            disconnectAlertStage := "Failed"
            disconnectAlertTitle.Text := Macro_GetDisconnectUIText("failedTitle")
            disconnectAlertBody.Text := Macro_GetDisconnectAlertBody(disconnectAlertReason)
            Macro_ResizeDisconnectAlert()
            disconnectAlertPrimaryButton.Enabled := true
            disconnectAlertPrimaryButton.Text := Macro_GetDisconnectUIText("inspect")
        } catch {
        }
        Macro_FinishConnectionRecovery(false)
        return
    }

    if (!Macro_ClickReconnectForWindow(hwnd)) {
        Macro_RecordDisconnectProcessStep("click_failed")
        ; Keep the same client as the target and retry after a quiet delay.
        connectionRecoveryNextTick := A_TickCount + 5000
        return
    }

    Macro_RecordDisconnectProcessStep("reconnect_click")
    connectionRecoveryAttempts += 1
    disconnectRecoveryTotalAttempts += 1
    disconnectAlertLastRecoveryAttempts := connectionRecoveryAttempts
    connectionRecoveryStage := "Confirm"
    connectionRecoveryNextTick := A_TickCount + CONNECTION_RECONNECT_CONFIRM_WAIT_MS
    try {
        disconnectAlertStage := "Reconnecting"
        disconnectAlertTitle.Text := Macro_GetDisconnectUIText("reconnectingTitle")
        disconnectAlertBody.Text := Macro_GetDisconnectAlertBody(disconnectAlertReason)
        Macro_ResizeDisconnectAlert()
        disconnectAlertPrimaryButton.Text := Macro_GetDisconnectUIText("checkingButton")
        disconnectAlertPrimaryButton.Enabled := false
    } catch {
    }
    ; Keep attempt progress in the main diagnostic window instead of a
    ; separate Windows notification.
}

; =====================================================================
; 🔗 Simultaneous-disconnect candidate queue
;    Each candidate is bound to BOTH HWND and PID. Once a recovery starts,
;    that exact pair remains locked until the transaction finishes.
; =====================================================================
Macro_QueueReconnectCandidate(hwnd, pid := 0, minmax := 0) {
    global connectionRecoveryQueue, connectionRecoveryHwnd, connectionRecoveryTargetPid

    if (!hwnd || !WinExist("ahk_id " . hwnd))
        return false

    if (!pid) {
        try pid := WinGetPID("ahk_id " . hwnd)
        catch
            pid := 0
    }

    for candidate in connectionRecoveryQueue {
        if (candidate["hwnd"] = hwnd || (pid && candidate["pid"] = pid))
            return false
    }

    if (connectionRecoveryHwnd = hwnd || (connectionRecoveryTargetPid && pid && connectionRecoveryTargetPid = pid))
        return false

    connectionRecoveryQueue.Push(Map("hwnd", hwnd, "pid", pid, "minmax", minmax))
    return true
}

Macro_PeekReconnectCandidate() {
    global connectionRecoveryQueue

    while (connectionRecoveryQueue.Length) {
        candidate := connectionRecoveryQueue[1]
        hwnd := candidate["hwnd"]
        pid := candidate["pid"]
        if (WinExist("ahk_id " . hwnd)) {
            currentPid := 0
            try currentPid := WinGetPID("ahk_id " . hwnd)
            catch
                currentPid := 0
            if (!pid || !currentPid || pid = currentPid)
                return candidate
        }
        connectionRecoveryQueue.RemoveAt(1)
    }
    return 0
}

Macro_RemoveReconnectCandidate(hwnd, pid := 0) {
    global connectionRecoveryQueue

    for index, candidate in connectionRecoveryQueue {
        if (candidate["hwnd"] = hwnd && (!pid || !candidate["pid"] || candidate["pid"] = pid)) {
            connectionRecoveryQueue.RemoveAt(index)
            return true
        }
    }
    return false
}

Macro_IsReconnectCandidateValid(candidate) {
    if (!candidate)
        return false
    hwnd := candidate["hwnd"]
    pid := candidate["pid"]
    if (!hwnd || !WinExist("ahk_id " . hwnd))
        return false
    if (pid) {
        currentPid := 0
        try currentPid := WinGetPID("ahk_id " . hwnd)
        catch
            return false
        if (currentPid && currentPid != pid)
            return false
    }
    return true
}

Macro_CollectReconnectCandidates(allowFocusScan := true, forceFocusScanAll := false) {
    global connectionRecoveryDiscoveredMinMax, CONNECTION_DEEP_SCAN_SETTLE_MS
    global disconnectAlertGui
    global fixedPointModalDebugEnabled
    global fixedPointModalDebugProbeRunning, fixedPointModalDebugProbeBusyHwnd

    results := []
    excludeAlertHwnd := 0
    try {
        if (IsObject(disconnectAlertGui) && disconnectAlertGui.Hwnd)
            excludeAlertHwnd := disconnectAlertGui.Hwnd
    } catch {
        excludeAlertHwnd := 0
    }
    CoordMode("Mouse", "Screen")
    CoordMode("Pixel", "Screen")

    try {
        list := WinGetList("ahk_exe RobloxPlayerBeta.exe")
    } catch {
        return results
    }

    ; Direct Check is a true one-pass scan.
    ; Each HWND is classified and inspected immediately, then never revisited.
    originalForeground := WinExist("A")

    total := list.Length
    for scanIndex, hwnd in list {
        if (!WinExist("ahk_id " . hwnd))
            continue
        if (!allowFocusScan && fixedPointModalDebugProbeRunning
            && hwnd = fixedPointModalDebugProbeBusyHwnd)
            continue

        oldState := 0
        rx := 0, ry := 0, rw := 0, rh := 0
        isHidden := false
        try {
            oldState := WinGetMinMax("ahk_id " . hwnd)
            if (oldState = -1) {
                isHidden := true
            } else if (allowFocusScan) {
                ; Direct Check intentionally does not try to infer occlusion.
                ; Every non-minimized Roblox client is activated and inspected one by one.
                isHidden := true
            } else {
                ; Automatic/background scans keep the existing non-invasive occlusion test.
                WinGetPos(&rx, &ry, &rw, &rh, "ahk_id " . hwnd)
                isHidden := Macro_IsRobloxActuallyOccluded(hwnd, rx, ry, rw, rh, excludeAlertHwnd)
            }
        } catch {
            isHidden := true
        }

        if (!allowFocusScan && isHidden)
            continue

        if (!allowFocusScan) {
            try {
                if (Macro_FindReconnectButton(hwnd, &buttonX, &buttonY, !fixedPointModalDebugEnabled)) {
                    pid := 0
                    try pid := WinGetPID("ahk_id " . hwnd)
                    catch
                        pid := 0
                    results.Push(Map("hwnd", hwnd, "pid", pid, "minmax", oldState))
                }
            } catch {
            }
            continue
        }

        ; Direct Check: activate every Roblox HWND one by one and inspect it.
        ; This deliberately avoids any occlusion guess.
        try {
            if (oldState = -1)
                WinRestore("ahk_id " . hwnd)
            WinActivate("ahk_id " . hwnd)
            if (!WinWaitActive("ahk_id " . hwnd, , 0.8))
                continue

            ; Allow the activated Roblox client to finish rendering before pixel checks.
            ; The previous 80 ms wait could inspect a partially refreshed frame and
            ; report "modal not found" even though the dialog was visible.
            Sleep(CONNECTION_DEEP_SCAN_SETTLE_MS)

            ; The window is now active, so no occlusion re-check is necessary.
            buttonFound := false
            try {
                buttonFound := Macro_FindReconnectButton(hwnd, &buttonX, &buttonY, !fixedPointModalDebugEnabled)
                if (!buttonFound) {
                    ; One bounded retry catches delayed modal/button rendering without
                    ; re-scanning every pixel indefinitely.
                    Sleep(250)
                    if (WinActive("ahk_id " . hwnd) = hwnd)
                        buttonFound := Macro_FindReconnectButton(hwnd, &buttonX, &buttonY, !fixedPointModalDebugEnabled)
                }
                if (buttonFound) {
                    pid := 0
                    try pid := WinGetPID("ahk_id " . hwnd)
                    catch
                        pid := 0
                    results.Push(Map("hwnd", hwnd, "pid", pid, "minmax", oldState))
                }
            } catch {
            }
        } catch {
        }

        if (oldState = -1) {
            try WinMinimize("ahk_id " . hwnd)
            catch {
            }
        }
    }

    ; Restore the window that was active before Direct Check began.
    try {
        if (originalForeground && WinExist("ahk_id " . originalForeground))
            WinActivate("ahk_id " . originalForeground)
    } catch {
    }

    return results
}

Macro_FindReconnectDialogAcrossRoblox(allowFocusScan := true) {
    global connectionRecoveryDiscoveredMinMax, CONNECTION_DEEP_SCAN_SETTLE_MS
    global disconnectAlertGui
    fastManualScan := false

    excludeAlertHwnd := 0
    try {
        if (IsObject(disconnectAlertGui) && disconnectAlertGui.Hwnd)
            excludeAlertHwnd := disconnectAlertGui.Hwnd
    } catch {
        excludeAlertHwnd := 0
    }

    CoordMode("Mouse", "Screen")
    CoordMode("Pixel", "Screen")

    try {
        list := WinGetList("ahk_exe RobloxPlayerBeta.exe")
    } catch {
        return 0
    }

    ; -------------------------------------------------------------
    ; First pass: visible/non-occluded windows only. No focus changes.
    ; -------------------------------------------------------------
    for hwnd in list {
        if (!WinExist("ahk_id " . hwnd))
            continue

        try {
            if (WinGetMinMax("ahk_id " . hwnd) = -1)
                continue
            WinGetPos(&rx, &ry, &rw, &rh, "ahk_id " . hwnd)
        } catch {
            continue
        }

        if (!Macro_IsRobloxActuallyOccluded(hwnd, rx, ry, rw, rh)) {
            if (Macro_ProbeReconnectDialog(hwnd, false) = 1) {
                connectionRecoveryDiscoveredMinMax := 0
                return hwnd
            }
        }
    }

    if (!allowFocusScan)
        return 0

    ; -------------------------------------------------------------
    ; Second pass: activate one client at a time. This is deliberately slow
    ; because reliability is more important than response time.
    ; -------------------------------------------------------------
    originalForeground := WinExist("A")

    for hwnd in list {
        ; Never focus-probe the Roblox window the user is currently playing.
        ; It was already checked during the non-invasive first pass.
        if (originalForeground && hwnd = originalForeground)
            continue
        if (!WinExist("ahk_id " . hwnd))
            continue

        oldState := 0
        try {
            oldState := WinGetMinMax("ahk_id " . hwnd)
        } catch {
            oldState := 0
        }

        ; Only covered/minimized clients require a focus-changing probe.
        ; Clients already visible and unobstructed were checked in the first pass.
        needsFocusProbe := (oldState = -1)
        if (!needsFocusProbe) {
            try {
                WinGetPos(&rx2, &ry2, &rw2, &rh2, "ahk_id " . hwnd)
                needsFocusProbe := Macro_IsRobloxActuallyOccluded(hwnd, rx2, ry2, rw2, rh2, excludeAlertHwnd)
            } catch {
                needsFocusProbe := true
            }
        }
        if (!needsFocusProbe)
            continue

        try {
            if (oldState = -1)
                WinRestore("ahk_id " . hwnd)
            WinActivate("ahk_id " . hwnd)
            if (!WinWaitActive("ahk_id " . hwnd, , fastManualScan ? 0.6 : 2))
                continue
            ; Manual [다시검색]은 화면이 이미 떠 있는 상태를 빠르게 재검사한다.
            ; 자동/심층 검사는 기존 렌더링 대기 시간을 그대로 사용한다.
            if (fastManualScan)
                Sleep(80)
            else
                Sleep(CONNECTION_DEEP_SCAN_SETTLE_MS)
            if (Macro_ProbeReconnectDialog(hwnd, false) = 1) {
                connectionRecoveryDiscoveredMinMax := oldState
                if (oldState = -1) {
                    try {
                        WinMinimize("ahk_id " . hwnd)
                    } catch {
                    }
                }
                try {
                    if (originalForeground && WinExist("ahk_id " . originalForeground))
                        WinActivate("ahk_id " . originalForeground)
                } catch {
                }
                return hwnd
            }
        } catch {
        }

        if (oldState = -1) {
            try {
                WinMinimize("ahk_id " . hwnd)
            } catch {
            }
        }
    }

    try {
        if (originalForeground && WinExist("ahk_id " . originalForeground))
            WinActivate("ahk_id " . originalForeground)
    } catch {
    }
    return 0
}

Macro_ProbeReconnectDialog(hwnd, activateWindow := false, showAutoDebugMarkers := false, isF6Probe := false) {
    global fixedPointModalDebugProbeRunning, fixedPointModalDebugProbeBusyHwnd
    global disconnectHiddenScanActive, disconnectHiddenScanPending
    global disconnectAlertGui

    if (!hwnd || !WinExist("ahk_id " . hwnd))
        return -1

    if (fixedPointModalDebugProbeRunning && fixedPointModalDebugProbeBusyHwnd = hwnd && !isF6Probe) {
        if (disconnectHiddenScanActive)
            disconnectHiddenScanPending := true
        return -1
    }

    ; A screen-pixel probe is only meaningful when the target is actually visible.
    ; When another window covers it, reading screen pixels would inspect the covering
    ; window instead and could falsely look like a healthy Roblox client.
    if (!activateWindow) {
        try {
            if (WinGetMinMax("ahk_id " . hwnd) = -1)
                return -1
            WinGetPos(&probeX, &probeY, &probeW, &probeH, "ahk_id " . hwnd)
            excludeAlertHwnd := 0
            try {
                if (IsObject(disconnectAlertGui) && disconnectAlertGui.Hwnd)
                    excludeAlertHwnd := disconnectAlertGui.Hwnd
            } catch {
                excludeAlertHwnd := 0
            }
            if (Macro_IsRobloxActuallyOccluded(hwnd, probeX, probeY, probeW, probeH, excludeAlertHwnd))
                return -1
        } catch {
            return -1
        }
    }

    originalForeground := 0
    oldState := 0
    savedStateValid := false
    activationSucceeded := !activateWindow
    probeCompleted := false
    result := 0

    if (activateWindow) {
        originalForeground := WinExist("A")
        try {
            oldState := WinGetMinMax("ahk_id " . hwnd)
            savedStateValid := true
            if (oldState = -1)
                WinRestore("ahk_id " . hwnd)
            WinActivate("ahk_id " . hwnd)
            if (WinWaitActive("ahk_id " . hwnd, , 2)) {
                Sleep(500)
                activationSucceeded := true
            }
        } catch {
            activationSucceeded := false
        }
    }

    if (!activationSucceeded) {
        if (activateWindow) {
            try {
                if (originalForeground && WinExist("ahk_id " . originalForeground))
                    WinActivate("ahk_id " . originalForeground)
            } catch {
            }
        }
        return -1
    }

    if (!WinExist("ahk_id " . hwnd)) {
        if (activateWindow) {
            try {
                if (originalForeground && WinExist("ahk_id " . originalForeground))
                    WinActivate("ahk_id " . originalForeground)
            } catch {
            }
        }
        return -1
    }

    try {
        if (WinGetMinMax("ahk_id " . hwnd) = -1)
            result := -1
        else {
            result := Macro_FindReconnectButton(
                hwnd, &buttonX, &buttonY, showAutoDebugMarkers, isF6Probe
            ) ? 1 : 0
            probeCompleted := true
        }
    } catch {
        result := -1
    }

    ; Never leave a confirmation probe with focus stolen from the user's window.
    if (activateWindow) {
        try {
            if (savedStateValid && oldState = -1 && WinExist("ahk_id " . hwnd))
                WinMinimize("ahk_id " . hwnd)
        } catch {
        }
        try {
            if (originalForeground && WinExist("ahk_id " . originalForeground))
                WinActivate("ahk_id " . originalForeground)
        } catch {
        }
    }

    return probeCompleted ? result : -1
}

; Retained as an inactive reference only; all recovery paths use the adaptive detector below.
Macro_FindReconnectButton_LegacyFixedPoint(hwnd, &outX, &outY) {
    global disconnectScreenDiagValid, disconnectScreenDiagPassed, disconnectScreenDarkCount, disconnectScreenDarkTotal
    global disconnectButtonDiagValid, disconnectButtonDiagPassed, disconnectButtonWhiteCount, disconnectButtonWhiteTotal
    global disconnectButtonDarkAroundCount, disconnectButtonDarkAroundTotal, disconnectButtonBandHits
    global disconnectPrecisionPassed, disconnectPrecisionDifferentCount, disconnectPrecisionDifferentTotal

    CoordMode("Pixel", "Screen")

    disconnectScreenDiagValid := false
    disconnectScreenDiagPassed := false
    disconnectScreenDarkCount := 0
    disconnectScreenDarkTotal := 4

    disconnectButtonDiagValid := false
    disconnectButtonDiagPassed := false
    disconnectButtonWhiteCount := 0
    disconnectButtonWhiteTotal := 2
    disconnectButtonDarkAroundCount := 0
    disconnectButtonDarkAroundTotal := 0
    disconnectButtonBandHits := 0

    disconnectPrecisionPassed := false
    disconnectPrecisionDifferentCount := 0
    disconnectPrecisionDifferentTotal := 4

    try {
        WinGetClientPos(&cx, &cy, &cw, &ch, "ahk_id " . hwnd)
    } catch {
        return false
    }

    if (cw < 700 || ch < 400)
        return false

    centerX := cx + Round(cw / 2)
    centerY := cy + Round(ch / 2)

    ; -------------------------------------------------------------
    ; FIXED-POINT DETECTOR
    ; The Roblox 277 modal is a fixed pixel size and is always centered
    ; in the Roblox client. Nothing below is scaled from client size.
    ;
    ; Modal background: #393B3D
    ; Modal points: 4
    ; Reconnect button points: 2
    ; Outside points: diagnostic precision check only
    ; -------------------------------------------------------------
    modalPts := [[-240,-148],[219,-146],[-235,77],[224,84]]
    buttonPts := [[36,134],[234,134]]
    outsidePts := [[-11,-244],[-389,-2],[378,-6],[14,244]]

    ; Initial modal check: exactly one pixel at each fixed point.
    ; This is deliberately the fastest possible gate: if any of the four
    ; pixels is not the modal background, abandon this Roblox window
    ; immediately and continue with the next candidate.
    darkCount := 0
    for _, pt in modalPts {
        try color := PixelGetColor(centerX + pt[1], centerY + pt[2])
        catch
            return false
        if (Macro_IsModalBackgroundColor(color))
            darkCount += 1
    }

    disconnectScreenDiagValid := true
    disconnectScreenDarkCount := darkCount
    disconnectScreenDiagPassed := (darkCount = 4)

    if (!disconnectScreenDiagPassed)
        return false

    ; Button check: only after Modal 4/4, inspect one pixel at each
    ; fixed button point. If either point fails, abandon this window.
    whiteCount := 0
    for _, pt in buttonPts {
        try color := PixelGetColor(centerX + pt[1], centerY + pt[2])
        catch
            return false
        if (Macro_IsNearWhite(color))
            whiteCount += 1
    }

    disconnectButtonDiagValid := true
    disconnectButtonWhiteCount := whiteCount
    disconnectButtonDiagPassed := (whiteCount = 2)

    if (!disconnectButtonDiagPassed)
        return false

    ; Outside points are not required for initial detection.
    ; They are a precision guard: at least 3/4 must differ from the
    ; modal background.
    differentCount := 0
    for _, pt in outsidePts {
        try color := PixelGetColor(centerX + pt[1], centerY + pt[2])
        catch
            continue
        if (!Macro_IsModalBackgroundColor(color))
            differentCount += 1
    }

    disconnectPrecisionDifferentCount := differentCount
    disconnectPrecisionPassed := (differentCount >= 3)

    if (!disconnectPrecisionPassed)
        return false

    ; The two button points lie on the same horizontal button centerline.
    ; Their midpoint is the fixed Reconnect click point.
    outX := centerX + Round((buttonPts[1][1] + buttonPts[2][1]) / 2)
    outY := centerY + Round((buttonPts[1][2] + buttonPts[2][2]) / 2)

    disconnectButtonBandHits := 2
    return true
}

Macro_FindReconnectButton(hwnd, &outX, &outY, showAutoDebugMarkers := false, isF6Probe := false) {
    global CONNECTION_MODAL_REFERENCE_WIDTH, CONNECTION_MODAL_REFERENCE_HEIGHT
    global disconnectScreenDiagValid, disconnectScreenDiagPassed, disconnectScreenDarkCount, disconnectScreenDarkTotal
    global disconnectButtonDiagValid, disconnectButtonDiagPassed, disconnectButtonWhiteCount, disconnectButtonWhiteTotal
    global disconnectButtonDarkAroundCount, disconnectButtonDarkAroundTotal, disconnectButtonBandHits
    global disconnectPrecisionPassed, disconnectPrecisionDifferentCount, disconnectPrecisionDifferentTotal
    global disconnectModalDebugGeometry, disconnectModalDiagScale, disconnectModalDiagScaleAttempts
    global disconnectModalDiagReadCount, disconnectModalDiagElapsedMs
    global disconnectModalScaleCache, disconnectModalGeometryCache, disconnectModalProfileCache
    global fixedPointModalDebugEnabled
    global fixedPointModalDebugProbeRunning, fixedPointModalDebugProbeBusyHwnd

    if (fixedPointModalDebugProbeRunning && fixedPointModalDebugProbeBusyHwnd = hwnd && !isF6Probe)
        return false

    ; F6 owns the live diagnostic frame. Automatic modal checks still run, but
    ; while F6 is enabled they must not overwrite F6's diagnostic values/geometry.
    preserveF6Diag := fixedPointModalDebugEnabled && !isF6Probe
    if (preserveF6Diag) {
        savedScreenDiagValid := disconnectScreenDiagValid
        savedScreenDiagPassed := disconnectScreenDiagPassed
        savedScreenDarkCount := disconnectScreenDarkCount
        savedScreenDarkTotal := disconnectScreenDarkTotal
        savedButtonDiagValid := disconnectButtonDiagValid
        savedButtonDiagPassed := disconnectButtonDiagPassed
        savedButtonWhiteCount := disconnectButtonWhiteCount
        savedButtonWhiteTotal := disconnectButtonWhiteTotal
        savedButtonDarkAroundCount := disconnectButtonDarkAroundCount
        savedButtonDarkAroundTotal := disconnectButtonDarkAroundTotal
        savedButtonBandHits := disconnectButtonBandHits
        savedPrecisionPassed := disconnectPrecisionPassed
        savedPrecisionDifferentCount := disconnectPrecisionDifferentCount
        savedPrecisionDifferentTotal := disconnectPrecisionDifferentTotal
        savedModalDebugGeometry := disconnectModalDebugGeometry
        savedModalDiagScale := disconnectModalDiagScale
        savedModalDiagScaleAttempts := disconnectModalDiagScaleAttempts
        savedModalDiagReadCount := disconnectModalDiagReadCount
        savedModalDiagElapsedMs := disconnectModalDiagElapsedMs
    }

    ; F6 owns the marker layer while it is enabled. Automatic checks must not
    ; hide or redraw those markers; they are visualized only by the F6 probe.
    if (!preserveF6Diag)
        Macro_HidePinnedFixedPointModalMarkers()

    CoordMode("Pixel", "Screen")
    startedAt := A_TickCount
    disconnectScreenDiagValid := false
    disconnectScreenDiagPassed := false
    disconnectScreenDarkCount := 0
    disconnectScreenDarkTotal := 4
    disconnectButtonDiagValid := false
    disconnectButtonDiagPassed := false
    disconnectButtonWhiteCount := 0
    disconnectButtonWhiteTotal := 2
    disconnectButtonDarkAroundCount := 0
    disconnectButtonDarkAroundTotal := 0
    disconnectButtonBandHits := 0
    disconnectPrecisionPassed := false
    disconnectPrecisionDifferentCount := 0
    disconnectPrecisionDifferentTotal := 4
    disconnectModalDiagScale := 0.0
    disconnectModalDiagScaleAttempts := 0
    disconnectModalDiagReadCount := 0
    disconnectModalDiagElapsedMs := 0
    showActualProbeMarkers := showAutoDebugMarkers

    try {
        WinGetClientPos(&cx, &cy, &cw, &ch, "ahk_id " . hwnd)
        if (cw < 700 || ch < 400)
            return false

        centerX := cx + Round(cw / 2)
        centerY := cy + Round(ch / 2)
        scaleInfo := Macro_GetReconnectModalScaleCandidates(centerX, centerY)
        preferredScale := scaleInfo["preferred"]
        scales := scaleInfo["scales"]
        windowDpi := Macro_GetReconnectWindowDpi(hwnd)
        profileKey := scaleInfo["cacheKey"] . "|dpi" . windowDpi

        ; Reuse the confirmed monitor/DPI modal size across Roblox HWNDs.
        ; Geometry is recentered for this client, then checked at fixed pixels.
        if (Macro_TryVerifyCachedReconnectGeometry(
            hwnd, cx, cy, cw, ch, centerX, centerY, scaleInfo["cacheKey"],
            windowDpi, profileKey, showActualProbeMarkers, &outX, &outY
        )) {
            disconnectModalDiagElapsedMs := A_TickCount - startedAt
            return true
        }

        ; F6 previews this same resolution profile until a real modal is found.
        disconnectModalDebugGeometry := Macro_BuildReconnectModalDebugGeometry(
            centerX, centerY, preferredScale, "", false, hwnd
        )
        disconnectModalDiagScale := preferredScale

        bestDarkCount := 0
        gateMatched := false
        modalOffsets := Macro_GetReconnectModalGateOffsets()

        ; Cached size first, then the monitor profile and bounded tolerance
        ; variants. Ordinary windows exit each hypothesis at its first miss.
        for _, scale in scales {
            disconnectModalDiagScaleAttempts += 1
            samplePoints := []
            darkCount := 0
            for pointIndex, offset in modalOffsets {
                px := centerX + Round(offset[1] * scale)
                py := centerY + Round(offset[2] * scale)
                samplePoints.Push([px, py])
                if (showActualProbeMarkers)
                    Macro_ShowFixedPointModalProbeMarker(pointIndex, px, py)
                color := Macro_ReadReconnectModalPixel(px, py, &readOk)
                pointPassed := (readOk && Macro_IsModalBackgroundColor(color))
                if (!pointPassed)
                    break
                darkCount += 1
            }

            if (darkCount > bestDarkCount)
                bestDarkCount := darkCount
            disconnectScreenDiagValid := true
            disconnectScreenDarkCount := bestDarkCount
            disconnectScreenDiagPassed := (darkCount = 4)
            if (darkCount != 4)
                continue

            gateMatched := true
            disconnectModalDiagScale := scale

            ; Only a passing color gate triggers short, directed edge traces.
            if (!Macro_FindReconnectModalBoundsFromSeeds(
                scale, samplePoints, &left, &top, &right, &bottom, showActualProbeMarkers
            ))
                continue

            width := right - left + 1
            height := bottom - top + 1
            expectedW := CONNECTION_MODAL_REFERENCE_WIDTH * scale
            expectedH := CONNECTION_MODAL_REFERENCE_HEIGHT * scale
            if (width < Round(expectedW * 0.50) || width > Round(expectedW * 1.50))
                continue
            if (height < Round(expectedH * 0.50) || height > Round(expectedH * 1.50))
                continue
            if (Abs((left + right) / 2 - centerX) > Max(24, Round(60 * scale)))
                continue
            if (Abs((top + bottom) / 2 - centerY) > Max(24, Round(45 * scale)))
                continue
            if (!Macro_ValidateReconnectModalInterior(
                left, top, right, bottom, &interiorDarkCount, showActualProbeMarkers
            ))
                continue

            bounds := [left, top, right, bottom]
            geometry := Macro_BuildReconnectModalDebugGeometry(
                centerX, centerY, scale, bounds, true, hwnd
            )
            geometry["clientRect"] := [cx, cy, cw, ch]
            geometry["pid"] := WinGetPID("ahk_id " . hwnd)
            geometry["dpi"] := windowDpi
            geometry["displayKey"] := scaleInfo["cacheKey"]
            disconnectModalDebugGeometry := geometry

            whiteCount := 0
            for pointIndex, point in geometry["buttonPoints"] {
                if (showActualProbeMarkers)
                    Macro_ShowFixedPointModalProbeMarker(4 + pointIndex, point[1], point[2])
                color := Macro_ReadReconnectModalPixel(point[1], point[2], &readOk)
                pointPassed := (readOk && Macro_IsNearWhite(color))
                if (!pointPassed)
                    break
                whiteCount += 1
            }
            disconnectButtonDiagValid := true
            disconnectButtonWhiteCount := whiteCount
            disconnectButtonDiagPassed := (whiteCount = 2)
            if (!disconnectButtonDiagPassed)
                continue

            differentCount := 0
            for pointIndex, point in geometry["outsidePoints"] {
                if (showActualProbeMarkers)
                    Macro_ShowFixedPointModalProbeMarker(6 + pointIndex, point[1], point[2])
                color := Macro_ReadReconnectModalPixel(point[1], point[2], &readOk)
                pointPassed := (readOk && !Macro_IsModalBackgroundColor(color))
                if (pointPassed)
                    differentCount += 1
            }
            disconnectPrecisionDifferentCount := differentCount
            disconnectPrecisionPassed := (differentCount >= 3)
            if (!disconnectPrecisionPassed)
                continue

            ; Once every modal check passes, pin all final verified markers:
            ; gate, button, exterior, measured corners, and click target.
            if (showActualProbeMarkers) {
                for pointIndex, point in geometry["markers"]
                    Macro_ShowFixedPointModalProbeMarker(pointIndex, point[1], point[2], 0)
            }

            clickPoint := geometry["clickPoint"]
            outX := clickPoint[1]
            outY := clickPoint[2]
            disconnectButtonBandHits := 2
            disconnectModalScaleCache[scaleInfo["cacheKey"]] := scale
            disconnectModalGeometryCache[hwnd] := geometry
            disconnectModalProfileCache[profileKey] := Map(
                "scale", scale,
                "boundsOffset", [left - centerX, top - centerY, right - centerX, bottom - centerY]
            )
            return true
        }

        disconnectScreenDiagValid := (disconnectModalDiagScaleAttempts > 0)
        disconnectScreenDarkCount := bestDarkCount
        disconnectScreenDiagPassed := gateMatched
        return false
    } catch {
        return false
    } finally {
        measuredElapsedMs := A_TickCount - startedAt
        if (preserveF6Diag) {
            disconnectScreenDiagValid := savedScreenDiagValid
            disconnectScreenDiagPassed := savedScreenDiagPassed
            disconnectScreenDarkCount := savedScreenDarkCount
            disconnectScreenDarkTotal := savedScreenDarkTotal
            disconnectButtonDiagValid := savedButtonDiagValid
            disconnectButtonDiagPassed := savedButtonDiagPassed
            disconnectButtonWhiteCount := savedButtonWhiteCount
            disconnectButtonWhiteTotal := savedButtonWhiteTotal
            disconnectButtonDarkAroundCount := savedButtonDarkAroundCount
            disconnectButtonDarkAroundTotal := savedButtonDarkAroundTotal
            disconnectButtonBandHits := savedButtonBandHits
            disconnectPrecisionPassed := savedPrecisionPassed
            disconnectPrecisionDifferentCount := savedPrecisionDifferentCount
            disconnectPrecisionDifferentTotal := savedPrecisionDifferentTotal
            disconnectModalDebugGeometry := savedModalDebugGeometry
            disconnectModalDiagScale := savedModalDiagScale
            disconnectModalDiagScaleAttempts := savedModalDiagScaleAttempts
            disconnectModalDiagReadCount := savedModalDiagReadCount
            disconnectModalDiagElapsedMs := savedModalDiagElapsedMs
        } else {
            disconnectModalDiagElapsedMs := measuredElapsedMs
        }
        ; Ordinary probe points expire 500 ms after their last sample. A fully
        ; confirmed modal pins all verified markers until the reconnect click.
    }
}

Macro_GetReconnectModalScaleCandidates(centerX, centerY) {
    global CONNECTION_MODAL_REFERENCE_4K_SCALE, CONNECTION_MODAL_REFERENCE_FHD_SCALE
    global CONNECTION_MODAL_REFERENCE_4K_HEIGHT, CONNECTION_MODAL_REFERENCE_FHD_HEIGHT
    global disconnectModalScaleCache

    displayW := A_ScreenWidth
    displayH := A_ScreenHeight
    try {
        Loop MonitorGetCount() {
            MonitorGet(A_Index, &ml, &mt, &mr, &mb)
            if (centerX >= ml && centerX < mr && centerY >= mt && centerY < mb) {
                displayW := mr - ml
                displayH := mb - mt
                break
            }
        }
    } catch {
    }

    ; These factors are detector-coordinate scales, not raw visual-size ratios.
    ; F6 showed that the FHD screen-coordinate footprint needs a 0.5 correction;
    ; intermediate monitor heights interpolate between the calibrated anchors.
    ; Roblox client size is intentionally ignored.
    if (displayH <= CONNECTION_MODAL_REFERENCE_FHD_HEIGHT) {
        preferred := CONNECTION_MODAL_REFERENCE_FHD_SCALE
    } else if (displayH >= CONNECTION_MODAL_REFERENCE_4K_HEIGHT) {
        preferred := CONNECTION_MODAL_REFERENCE_4K_SCALE
    } else {
        ratio := (displayH - CONNECTION_MODAL_REFERENCE_FHD_HEIGHT)
            / (CONNECTION_MODAL_REFERENCE_4K_HEIGHT - CONNECTION_MODAL_REFERENCE_FHD_HEIGHT)
        preferred := CONNECTION_MODAL_REFERENCE_FHD_SCALE
            + (CONNECTION_MODAL_REFERENCE_4K_SCALE - CONNECTION_MODAL_REFERENCE_FHD_SCALE) * ratio
    }

    cacheKey := displayW . "x" . displayH
    scales := []
    if (disconnectModalScaleCache.Has(cacheKey))
        Macro_PushUniqueReconnectScale(scales, disconnectModalScaleCache[cacheKey])
    Macro_PushUniqueReconnectScale(scales, preferred)
    for _, factor in [0.85, 1.15, 0.70, 1.30]
        Macro_PushUniqueReconnectScale(scales, preferred * factor)

    return Map("preferred", preferred, "scales", scales, "cacheKey", cacheKey,
        "displayW", displayW, "displayH", displayH)
}

Macro_PushUniqueReconnectScale(scales, scale) {
    scale := Max(0.50, Min(2.00, scale))
    for _, existing in scales {
        if (Abs(existing - scale) < 0.025)
            return
    }
    scales.Push(scale)
}

Macro_ReadReconnectModalPixel(x, y, &readOk) {
    global disconnectModalDiagReadCount
    try {
        color := PixelGetColor(x, y)
        disconnectModalDiagReadCount += 1
        readOk := true
        return color
    } catch {
        readOk := false
        return 0
    }
}

Macro_FindReconnectModalBoundsFromSeeds(scale, seedPoints, &outL, &outT, &outR, &outB, showMarkers := false) {
    leftSeed := seedPoints[1]
    rightSeed := seedPoints[2]
    ; The upper-left gate point is already close to the top edge, so reuse it
    ; for a short upward trace instead of scanning from the lower-left point.
    topSeed := seedPoints[1]
    ; The matching left-side x coordinate keeps the downward scan away from the
    ; white Reconnect button; the lower gate point supplies its y coordinate.
    bottomSeed := [seedPoints[1][1], seedPoints[4][2]]

    if (!Macro_TraceReconnectModalEdge(leftSeed[1], leftSeed[2], -1, 0, scale, &outL, &discardY, 11, showMarkers))
        return false
    if (!Macro_TraceReconnectModalEdge(rightSeed[1], rightSeed[2], 1, 0, scale, &outR, &discardY, 12, showMarkers))
        return false
    if (!Macro_TraceReconnectModalEdge(topSeed[1], topSeed[2], 0, -1, scale, &discardX, &outT, 13, showMarkers))
        return false
    if (!Macro_TraceReconnectModalEdge(bottomSeed[1], bottomSeed[2], 0, 1, scale, &discardX, &outB, 14, showMarkers))
        return false

    return (outL < outR && outT < outB)
}

Macro_TraceReconnectModalEdge(seedX, seedY, dirX, dirY, scale, &edgeX, &edgeY, markerIndex := 0, showMarkers := false) {
    step := Max(3, Round(6 * scale))
    maxDistance := Max(step * 5, Round(220 * scale))
    lastDarkDistance := 0
    firstFailureDistance := 0
    failureRun := 0
    distance := step

    if (showMarkers && markerIndex)
        Macro_ShowFixedPointModalProbeMarker(markerIndex, seedX, seedY)
    seedColor := Macro_ReadReconnectModalPixel(seedX, seedY, &readOk)
    if (!readOk || !Macro_IsModalBackgroundColor(seedColor))
        return false

    while (distance <= maxDistance) {
        px := seedX + dirX * distance
        py := seedY + dirY * distance
        if (showMarkers && markerIndex)
            Macro_ShowFixedPointModalProbeMarker(markerIndex, px, py)
        color := Macro_ReadReconnectModalPixel(px, py, &readOk)
        if (!readOk)
            return false

        if (Macro_IsModalBackgroundColor(color)) {
            lastDarkDistance := distance
            failureRun := 0
        } else {
            failureRun += 1
            if (failureRun >= 2) {
                firstFailureDistance := distance - step
                break
            }
        }
        distance += step
    }

    if (!firstFailureDistance)
        return false

    ; Refine just the short edge bracket at single-pixel resolution.
    refineDistance := Max(1, lastDarkDistance + 1)
    refineLimit := Min(maxDistance, firstFailureDistance + step)
    while (refineDistance <= refineLimit) {
        px := seedX + dirX * refineDistance
        py := seedY + dirY * refineDistance
        if (showMarkers && markerIndex)
            Macro_ShowFixedPointModalProbeMarker(markerIndex, px, py)
        color := Macro_ReadReconnectModalPixel(px, py, &readOk)
        if (!readOk || !Macro_IsModalBackgroundColor(color))
            break
        lastDarkDistance := refineDistance
        refineDistance += 1
    }

    edgeX := seedX + dirX * lastDarkDistance
    edgeY := seedY + dirY * lastDarkDistance
    return (lastDarkDistance > 0)
}

Macro_ValidateReconnectModalInterior(left, top, right, bottom, &darkCount, showMarkers := false) {
    width := right - left
    height := bottom - top
    points := [
        [left + Round(width * 0.14), top + Round(height * 0.14)],
        [right - Round(width * 0.14), top + Round(height * 0.14)],
        [left + Round(width * 0.14), top + Round(height * 0.70)],
        [right - Round(width * 0.14), top + Round(height * 0.70)]
    ]

    darkCount := 0
    for pointIndex, point in points {
        if (showMarkers)
            Macro_ShowFixedPointModalProbeMarker(10 + pointIndex, point[1], point[2])
        color := Macro_ReadReconnectModalPixel(point[1], point[2], &readOk)
        if (!readOk)
            return false
        if (Macro_IsModalBackgroundColor(color))
            darkCount += 1
    }
    return (darkCount >= 3)
}

Macro_BuildReconnectModalDebugGeometry(centerX, centerY, scale, bounds := "", measured := false, hwnd := 0) {
    global CONNECTION_MODAL_REFERENCE_WIDTH, CONNECTION_MODAL_REFERENCE_HEIGHT
    global CONNECTION_MODAL_OUTSIDE_MARGIN_RATIO

    gateOffsets := Macro_GetReconnectModalGateOffsets()
    gatePoints := []
    for _, offset in gateOffsets
        gatePoints.Push([centerX + Round(offset[1] * scale), centerY + Round(offset[2] * scale)])

    if (IsObject(bounds) && bounds.Length = 4) {
        left := bounds[1], top := bounds[2], right := bounds[3], bottom := bounds[4]
    } else {
        halfW := Round(CONNECTION_MODAL_REFERENCE_WIDTH * scale / 2)
        halfH := Round(CONNECTION_MODAL_REFERENCE_HEIGHT * scale / 2)
        left := centerX - halfW, right := centerX + halfW
        top := centerY - halfH, bottom := centerY + halfH
    }

    width := right - left
    height := bottom - top
    buttonY := top + Round(height * 0.86)
    buttonPoints := [
        [left + Round(width * 0.61), buttonY],
        [left + Round(width * 0.84), buttonY]
    ]
    ; Keep exterior probes evenly aligned to the measured panel, just outside its edges.
    outsideMarginRatio := CONNECTION_MODAL_OUTSIDE_MARGIN_RATIO
    outsideX := Max(12, Round(width * outsideMarginRatio))
    outsideY := Max(12, Round(height * outsideMarginRatio))
    modalMidX := Round((left + right) / 2)
    modalMidY := Round((top + bottom) / 2)
    outsidePoints := [
        [modalMidX, top - outsideY],
        [left - outsideX, modalMidY],
        [right + outsideX, modalMidY],
        [modalMidX, bottom + outsideY]
    ]
    corners := [[left,top],[right,top],[left,bottom],[right,bottom]]
    clickPoint := [
        Round((buttonPoints[1][1] + buttonPoints[2][1]) / 2),
        Round((buttonPoints[1][2] + buttonPoints[2][2]) / 2)
    ]

    markers := []
    for _, point in gatePoints
        markers.Push(point)
    for _, point in buttonPoints
        markers.Push(point)
    for _, point in outsidePoints
        markers.Push(point)
    for _, point in corners
        markers.Push(point)
    markers.Push(clickPoint)

    return Map("hwnd", hwnd, "centerX", centerX, "centerY", centerY,
        "scale", scale, "measured", measured, "bounds", [left,top,right,bottom],
        "gatePoints", gatePoints, "buttonPoints", buttonPoints,
        "outsidePoints", outsidePoints, "corners", corners,
        "clickPoint", clickPoint, "markers", markers,
        "width", width, "height", height)
}

Macro_GetReconnectModalGateOffsets() {
    global CONNECTION_MODAL_REFERENCE_WIDTH, CONNECTION_MODAL_REFERENCE_HEIGHT
    global CONNECTION_MODAL_GATE_X_RATIO
    global CONNECTION_MODAL_GATE_TOP_Y_RATIO, CONNECTION_MODAL_GATE_BOTTOM_Y_RATIO

    xInset := Round(CONNECTION_MODAL_REFERENCE_WIDTH * CONNECTION_MODAL_GATE_X_RATIO)
    topOffset := Round(CONNECTION_MODAL_REFERENCE_HEIGHT * (0.5 - CONNECTION_MODAL_GATE_TOP_Y_RATIO))
    bottomOffset := Round(CONNECTION_MODAL_REFERENCE_HEIGHT * (CONNECTION_MODAL_GATE_BOTTOM_Y_RATIO - 0.5))
    return [[-xInset,-topOffset],[xInset,-topOffset],[-xInset,bottomOffset],[xInset,bottomOffset]]
}

Macro_GetReconnectWindowDpi(hwnd) {
    try {
        dpi := DllCall("user32\GetDpiForWindow", "Ptr", hwnd, "UInt")
        if (dpi)
            return dpi
    } catch {
    }
    return A_ScreenDPI
}

Macro_TryVerifyCachedReconnectGeometry(hwnd, clientX, clientY, clientW, clientH,
    centerX, centerY, displayKey, windowDpi, profileKey, showMarkers, &outX, &outY) {
    global disconnectModalGeometryCache, disconnectModalProfileCache, disconnectModalDebugGeometry
    global disconnectModalDiagScale, disconnectModalDiagScaleAttempts
    global disconnectModalDiagReadCount
    global disconnectScreenDiagValid, disconnectScreenDiagPassed, disconnectScreenDarkCount
    global disconnectButtonDiagValid, disconnectButtonDiagPassed, disconnectButtonWhiteCount
    global disconnectPrecisionPassed, disconnectPrecisionDifferentCount
    global disconnectButtonBandHits

    pid := 0
    try pid := WinGetPID("ahk_id " . hwnd)
    catch {
        if (IsObject(disconnectModalGeometryCache) && disconnectModalGeometryCache.Has(hwnd))
            disconnectModalGeometryCache.Delete(hwnd)
        return false
    }

    geometry := ""
    if (IsObject(disconnectModalGeometryCache) && disconnectModalGeometryCache.Has(hwnd)) {
        cachedGeometry := disconnectModalGeometryCache[hwnd]
        if (IsObject(cachedGeometry) && cachedGeometry["measured"]
            && cachedGeometry["hwnd"] = hwnd
            && cachedGeometry.Has("pid") && cachedGeometry["pid"] = pid
            && cachedGeometry.Has("dpi") && cachedGeometry["dpi"] = windowDpi
            && cachedGeometry.Has("displayKey") && cachedGeometry["displayKey"] = displayKey) {
            oldCenterX := cachedGeometry["centerX"]
            oldCenterY := cachedGeometry["centerY"]
            oldBounds := cachedGeometry["bounds"]
            bounds := [
                centerX + oldBounds[1] - oldCenterX,
                centerY + oldBounds[2] - oldCenterY,
                centerX + oldBounds[3] - oldCenterX,
                centerY + oldBounds[4] - oldCenterY
            ]
            geometry := Macro_BuildReconnectModalDebugGeometry(
                centerX, centerY, cachedGeometry["scale"], bounds, true, hwnd
            )
        } else {
            disconnectModalGeometryCache.Delete(hwnd)
        }
    }

    if (!IsObject(geometry)) {
        if (!IsObject(disconnectModalProfileCache)
            || !disconnectModalProfileCache.Has(profileKey))
            return false
        profile := disconnectModalProfileCache[profileKey]
        offsets := profile["boundsOffset"]
        bounds := [
            centerX + offsets[1], centerY + offsets[2],
            centerX + offsets[3], centerY + offsets[4]
        ]
        geometry := Macro_BuildReconnectModalDebugGeometry(
            centerX, centerY, profile["scale"], bounds, true, hwnd
        )
    }

    geometry["clientRect"] := [clientX, clientY, clientW, clientH]
    geometry["pid"] := pid
    geometry["dpi"] := windowDpi
    geometry["displayKey"] := displayKey

    gateCount := 0
    gatePassed := true
    for pointIndex, point in geometry["gatePoints"] {
        if (showMarkers)
            Macro_ShowFixedPointModalProbeMarker(pointIndex, point[1], point[2])
        color := Macro_ReadReconnectModalPixel(point[1], point[2], &readOk)
        if (!readOk || !Macro_IsModalBackgroundColor(color)) {
            gatePassed := false
            break
        }
        gateCount += 1
    }

    disconnectScreenDiagValid := true
    disconnectScreenDarkCount := gateCount
    disconnectScreenDiagPassed := gatePassed && (gateCount = 4)
    if (!disconnectScreenDiagPassed) {
        if (IsObject(disconnectModalGeometryCache) && disconnectModalGeometryCache.Has(hwnd))
            disconnectModalGeometryCache.Delete(hwnd)
        return false
    }

    whiteCount := 0
    for pointIndex, point in geometry["buttonPoints"] {
        if (showMarkers)
            Macro_ShowFixedPointModalProbeMarker(4 + pointIndex, point[1], point[2])
        color := Macro_ReadReconnectModalPixel(point[1], point[2], &readOk)
        if (!readOk || !Macro_IsNearWhite(color))
            break
        whiteCount += 1
    }

    disconnectButtonDiagValid := true
    disconnectButtonWhiteCount := whiteCount
    disconnectButtonDiagPassed := (whiteCount = 2)
    if (!disconnectButtonDiagPassed) {
        if (IsObject(disconnectModalGeometryCache) && disconnectModalGeometryCache.Has(hwnd))
            disconnectModalGeometryCache.Delete(hwnd)
        return false
    }

    differentCount := 0
    for pointIndex, point in geometry["outsidePoints"] {
        if (showMarkers)
            Macro_ShowFixedPointModalProbeMarker(6 + pointIndex, point[1], point[2])
        color := Macro_ReadReconnectModalPixel(point[1], point[2], &readOk)
        if (readOk && !Macro_IsModalBackgroundColor(color))
            differentCount += 1
    }

    disconnectPrecisionDifferentCount := differentCount
    disconnectPrecisionPassed := (differentCount >= 3)
    if (gateCount != 4 || whiteCount != 2 || differentCount < 3) {
        if (IsObject(disconnectModalGeometryCache) && disconnectModalGeometryCache.Has(hwnd))
            disconnectModalGeometryCache.Delete(hwnd)
        return false
    }

    disconnectModalGeometryCache[hwnd] := geometry
    disconnectModalDebugGeometry := geometry
    disconnectModalDiagScale := geometry["scale"]
    disconnectModalDiagScaleAttempts := 0
    disconnectButtonBandHits := 2
    outX := geometry["clickPoint"][1]
    outY := geometry["clickPoint"][2]
    if (showMarkers) {
        for pointIndex, point in geometry["markers"]
            Macro_ShowFixedPointModalProbeMarker(pointIndex, point[1], point[2], 0)
    }
    return true
}

Macro_VerifyReconnectButtonAtLastGeometry(hwnd) {
    global disconnectModalDebugGeometry
    if (!IsObject(disconnectModalDebugGeometry)
        || disconnectModalDebugGeometry["hwnd"] != hwnd
        || !disconnectModalDebugGeometry["measured"])
        return false

    for _, point in disconnectModalDebugGeometry["buttonPoints"] {
        color := Macro_ReadReconnectModalPixel(point[1], point[2], &readOk)
        if (!readOk || !Macro_IsNearWhite(color))
            return false
    }
    gatePoint := disconnectModalDebugGeometry["gatePoints"][1]
    color := Macro_ReadReconnectModalPixel(gatePoint[1], gatePoint[2], &readOk)
    return (readOk && Macro_IsModalBackgroundColor(color))
}

Macro_Find277ModalBounds(clientX, clientY, clientW, clientH, &outL, &outT, &outR, &outB) {
    ; Legacy unused helper. The active detector no longer calls this stale
    ; color-search implementation; it traces the measured dark panel instead.
    ; Modal color reference: #9DFF00 (RGB 157,255,0), tolerance 15.
    CoordMode("Pixel", "Screen")

    centerX := clientX + Round(clientW / 2)
    centerY := clientY + Round(clientH / 2)

    ; Search a generous central region.  The modal is centered, but its size
    ; is allowed to vary with 1080p/4K resolution, DPI and Roblox UI scale.
    scanL := clientX + Round(clientW * 0.22)
    scanR := clientX + Round(clientW * 0.78)
    scanT := clientY + Round(clientH * 0.25)
    scanB := clientY + Round(clientH * 0.75)

    ; First locate a pixel close to the measured modal color.
    ; Reference measurement: RGB 157,255,0 (#9DFF00).
    ; Use a small per-channel tolerance to allow rendering/compositor variation.
    modalTargetColor := 0x9DFF00
    modalTolerance := 15

    found := false
    hitX := 0
    hitY := 0
    try {
        found := PixelSearch(&hitX, &hitY, scanL, scanT, scanR, scanB, modalTargetColor, modalTolerance)
    } catch {
        return false
    }
    if (!found)
        return false

    ; Move from the hit toward the center and identify the largest contiguous
    ; dark run.  This gives us the actual modal rectangle rather than assuming
    ; a fixed size.
    seedX := centerX
    seedY := centerY

    ; The center pixel should be modal background. If text happens to occupy
    ; it, probe a few nearby points until a dark modal pixel is found.
    seedFound := false
    seedOffsets := [[0,0],[-30,0],[30,0],[0,-25],[0,25],[-60,0],[60,0]]
    for _, off in seedOffsets {
        px := centerX + off[1]
        py := centerY + off[2]
        try {
            color := PixelGetColor(px, py)
        } catch {
            continue
        }
        if (Macro_IsModalColorPixel(color, modalTolerance)) {
            seedX := px
            seedY := py
            seedFound := true
            break
        }
    }
    if (!seedFound)
        return false

    ; Estimate horizontal bounds from the seed row.  A small gap tolerance
    ; prevents title/line rendering from prematurely splitting the rectangle.
    left := seedX
    right := seedX
    gap := 0
    while (left > scanL) {
        left -= 1
        try c := PixelGetColor(left, seedY)
        catch {
            break
        }
        if (Macro_IsModalColorPixel(c, modalTolerance))
            gap := 0
        else {
            gap += 1
            if (gap >= 5) {
                left += gap
                break
            }
        }
    }

    gap := 0
    while (right < scanR) {
        right += 1
        try c := PixelGetColor(right, seedY)
        catch {
            break
        }
        if (Macro_IsModalColorPixel(c, modalTolerance))
            gap := 0
        else {
            gap += 1
            if (gap >= 5) {
                right -= gap
                break
            }
        }
    }

    ; Estimate vertical bounds using the midpoint of the detected width.
    midX := Round((left + right) / 2)
    top := seedY
    bottom := seedY

    gap := 0
    while (top > scanT) {
        top -= 1
        try c := PixelGetColor(midX, top)
        catch {
            break
        }
        if (Macro_IsModalColorPixel(c, modalTolerance))
            gap := 0
        else {
            gap += 1
            if (gap >= 5) {
                top += gap
                break
            }
        }
    }

    gap := 0
    while (bottom < scanB) {
        bottom += 1
        try c := PixelGetColor(midX, bottom)
        catch {
            break
        }
        if (Macro_IsModalColorPixel(c, modalTolerance))
            gap := 0
        else {
            gap += 1
            if (gap >= 5) {
                bottom -= gap
                break
            }
        }
    }

    width := right - left + 1
    height := bottom - top + 1

    ; Plausibility limits.  These are ratios, not fixed 4K pixel dimensions.
    if (width < Round(clientW * 0.08) || width > Round(clientW * 0.40))
        return false
    if (height < Round(clientH * 0.07) || height > Round(clientH * 0.35))
        return false
    if (Abs((left + right) / 2 - centerX) > Round(clientW * 0.12))
        return false

    ; Confirm several interior points still look like the same dark modal.
    checkPts := [
        [0.10,0.10], [0.50,0.10], [0.90,0.10],
        [0.10,0.50], [0.90,0.50],
        [0.10,0.90], [0.50,0.90], [0.90,0.90]
    ]
    darkCount := 0
    for _, pt in checkPts {
        px := left + Round((width - 1) * pt[1])
        py := top + Round((height - 1) * pt[2])
        try c := PixelGetColor(px, py)
        catch {
        return false
    }
        if (Macro_IsModalColorPixel(c, modalTolerance))
            darkCount += 1
    }
    if (darkCount < 5)
        return false

    outL := left
    outT := top
    outR := right
    outB := bottom
    return true
}

Macro_RefineWhiteButtonBounds(seedX, seedY, minX, maxX, minY, maxY, &outL, &outT, &outR, &outB) {
    ; Search a horizontal row around the seed and choose the longest contiguous
    ; near-white run.  The Reconnect button background is white; its text is
    ; dark, so we use a tolerant gap rule around the seed.
    bestL := seedX
    bestR := seedX

    left := seedX
    misses := 0
    while (left > minX) {
        left -= 1
        try c := PixelGetColor(left, seedY)
        catch {
            break
        }
        if (Macro_IsNearWhite(c))
            misses := 0
        else {
            misses += 1
            if (misses >= 4) {
                left += misses
                break
            }
        }
    }

    right := seedX
    misses := 0
    while (right < maxX) {
        right += 1
        try c := PixelGetColor(right, seedY)
        catch {
            break
        }
        if (Macro_IsNearWhite(c))
            misses := 0
        else {
            misses += 1
            if (misses >= 4) {
                right -= misses
                break
            }
        }
    }

    if (right - left + 1 < 20)
        return false

    ; Determine top/bottom at the midpoint of the white run.
    midX := Round((left + right) / 2)
    top := seedY
    misses := 0
    while (top > minY) {
        top -= 1
        try c := PixelGetColor(midX, top)
        catch {
            break
        }
        if (Macro_IsNearWhite(c))
            misses := 0
        else {
            misses += 1
            if (misses >= 4) {
                top += misses
                break
            }
        }
    }

    bottom := seedY
    misses := 0
    while (bottom < maxY) {
        bottom += 1
        try c := PixelGetColor(midX, bottom)
        catch {
            break
        }
        if (Macro_IsNearWhite(c))
            misses := 0
        else {
            misses += 1
            if (misses >= 4) {
                bottom -= misses
                break
            }
        }
    }

    if (right - left + 1 < 20 || bottom - top + 1 < 8)
        return false

    outL := left
    outT := top
    outR := right
    outB := bottom
    return true
}

Macro_Is277ModalBackground(centerX, centerY, &darkCount) {
    ; Kept as a compatibility helper for any older diagnostic callers.
    ; The active Macro_FindReconnectButton() uses adaptive scale candidates,
    ; measured bounds, and resolution-independent button proportions.
    pts := [[-240,-148],[219,-146],[-235,77],[224,84]]
    darkCount := 0
    for _, pt in pts {
        if (Macro_CountModalPatchMatches(centerX + pt[1], centerY + pt[2]) >= 13)
            darkCount += 1
    }
    return (darkCount = 4)
}

Macro_CountModalPatchMatches(x, y) {
    matches := 0
    try {
        Loop 5 {
            dy := A_Index - 3
            Loop 5 {
                dx := A_Index - 3
                if (Macro_IsModalBackgroundColor(PixelGetColor(x + dx, y + dy)))
                    matches += 1
            }
        }
    } catch {
        return 0
    }
    return matches
}

Macro_CountWhitePatchMatches(x, y) {
    matches := 0
    try {
        Loop 5 {
            dy := A_Index - 3
            Loop 5 {
                dx := A_Index - 3
                if (Macro_IsNearWhite(PixelGetColor(x + dx, y + dy)))
                    matches += 1
            }
        }
    } catch {
        return 0
    }
    return matches
}

Macro_IsModalBackgroundColor(color) {
    r := (color >> 16) & 0xFF
    g := (color >> 8) & 0xFF
    b := color & 0xFF

    ; Reference modal background = #393B3D (57,59,61).
    ; Keep a modest allowance for rendering variation while separating
    ; the panel from nearby colors.
    return (Abs(r - 57) <= 6
        && Abs(g - 59) <= 6
        && Abs(b - 61) <= 6)
}

Macro_IsWhiteButtonPatch(x, y, &whiteCount, &darkAround) {
    ; Fixed-size button patch.  Do not scale this from the Roblox client.
    patchW := 32
    patchH := 12

    offsetsX := [-patchW, 0, patchW]
    offsetsY := [-patchH, 0, patchH]
    whiteCount := 0

    for _, dx in offsetsX {
        for _, dy in offsetsY {
            try {
                color := PixelGetColor(x + dx, y + dy)
            } catch {
                darkAround := 0
                return false
            }
            if (Macro_IsNearWhite(color))
                whiteCount += 1
        }
    }

    if (whiteCount < 6) {
        darkAround := 0
        return false
    }

    ; Fixed surrounding offsets remain identical in 1080p, 4K, maximized
    ; and fullscreen Roblox modes.
    try {
        sideOffset := 52
        sideLeft := PixelGetColor(x - sideOffset, y)
        sideRight := PixelGetColor(x + sideOffset, y)
        above := PixelGetColor(x, y - 30)
        below := PixelGetColor(x, y + 24)
    } catch {
        darkAround := 0
        return false
    }

    darkAround := 0
    if (Macro_IsDarkModalPixel(sideLeft))
        darkAround += 1
    if (Macro_IsDarkModalPixel(sideRight))
        darkAround += 1
    if (Macro_IsDarkModalPixel(above))
        darkAround += 1
    if (Macro_IsDarkModalPixel(below))
        darkAround += 1

    return (darkAround >= 2)
}

Macro_IsNearWhite(color) {
    r := (color >> 16) & 0xFF
    g := (color >> 8) & 0xFF
    b := color & 0xFF
    return (r >= 220 && g >= 220 && b >= 220)
}

Macro_IsModalColorPixel(color, tolerance := 12) {
    ; Compatibility name retained. The current detector's modal background
    ; is the fixed dark #393B3D.
    return Macro_IsModalBackgroundColor(color)
}

Macro_IsDarkModalPixel(color) {
    r := (color >> 16) & 0xFF
    g := (color >> 8) & 0xFF
    b := color & 0xFF
    maxC := Max(r, g, b)
    minC := Min(r, g, b)
    return (maxC <= 125 && (maxC - minC) <= 45)
}

Macro_GetWindowRootAtPoint(x, y, &rootHwnd, &processName) {
    rootHwnd := 0
    processName := ""

    try {
        pt := Buffer(8, 0)
        NumPut("Int", x, pt, 0)
        NumPut("Int", y, pt, 4)
        packed := NumGet(pt, 0, "Int64")
        hit := DllCall("user32\WindowFromPoint", "Int64", packed, "Ptr")
        if (!hit)
            return 0

        rootHwnd := DllCall("user32\GetAncestor", "Ptr", hit, "UInt", 2, "Ptr")
        if (!rootHwnd)
            rootHwnd := hit

        if (WinExist("ahk_id " . rootHwnd))
            processName := WinGetProcessName("ahk_id " . rootHwnd)
    } catch {
        rootHwnd := 0
        processName := ""
    }

    return rootHwnd
}

Macro_ClickReconnectForWindow(hwnd) {
    global connectionRecoveryEnabled, connectionRecoveryOriginalForeground
    global disconnectAlertBody, disconnectAlertStage, disconnectClickAttempt
    global disconnectClickTargetHwnd, disconnectClickHitRoot, disconnectClickHitProcess, disconnectClickLastResult
    global autoMouseHoldActive, WAIT_BEFORE_CLICK, WAIT_AFTER_CLICK
    global fixedPointModalDebugEnabled

    CoordMode("Mouse", "Screen")
    CoordMode("Pixel", "Screen")

    if (!hwnd || !WinExist("ahk_id " . hwnd))
        return false

    ; The diagnostic alert deliberately remains visible. We do not hide or lower it.
    ; Instead, the click is made only after the exact Roblox HWND is foreground,
    ; and the button's actual hit-test window is checked before each attempt.
    originalForeground := connectionRecoveryOriginalForeground
    if (!originalForeground || !WinExist("ahk_id " . originalForeground))
        originalForeground := WinExist("A")

    MouseGetPos(&savedX, &savedY)
    clicked := false

    try {
        if (WinGetMinMax("ahk_id " . hwnd) = -1)
            WinRestore("ahk_id " . hwnd)

        ; Use the same foreground/input discipline as the normal Roblox input flow.
        Click("Up")
        Sleep(20)
        WinActivate("ahk_id " . hwnd)
        if (!WinWaitActive("ahk_id " . hwnd, , 3))
            return false

        ; Two-pass click: a second click is attempted only if the first click
        ; demonstrably failed (the same HWND still contains the reconnect button).
        Loop 2 {
            attemptNo := A_Index
            disconnectClickAttempt := attemptNo
            disconnectClickTargetHwnd := hwnd
            disconnectClickLastResult := ""

            ; Re-check the exact target is still foreground immediately before
            ; searching/clicking. This prevents a different Roblox/client window
            ; from receiving the input.
            if (WinActive("ahk_id " . hwnd) != hwnd) {
                WinActivate("ahk_id " . hwnd)
                if (!WinWaitActive("ahk_id " . hwnd, , 1))
                    return false
            }

            Sleep(150)

            if (!Macro_FindReconnectButton(hwnd, &buttonX, &buttonY)) {
                disconnectClickLastResult := "button-not-found"
                break
            }

            hitRoot := Macro_GetWindowRootAtPoint(buttonX, buttonY, &hitRootTmp, &hitProcess)
            disconnectClickHitRoot := hitRoot
            disconnectClickHitProcess := hitProcess

            ; If another top-level window owns the exact button pixel, the click
            ; cannot reliably reach Roblox. Do not pretend the click succeeded.
            ; Keep the alert visible and try once more after re-activating Roblox.
            if (hitRoot && hitRoot != hwnd) {
                disconnectClickLastResult := "blocked-by-" . hitProcess
                if (attemptNo = 1) {
                    WinActivate("ahk_id " . hwnd)
                    Sleep(250)
                    continue
                }
                return false
            }

            ; Mirror the normal Roblox input cleanup and simple Click() call.
            Click("Up")
            autoMouseHoldActive := false
            Sleep(20)

            if (!Macro_EnsureRobloxForeground(hwnd, 35, 2) || !connectionRecoveryEnabled)
                return false

            ; Verify the fresh detector geometry before moving the pointer. Hovering can
            ; change button pixels or cover a sample point with the cursor.
            if (!Macro_VerifyReconnectButtonAtLastGeometry(hwnd)) {
                disconnectClickLastResult := "button-changed-before-click"
                if (attemptNo = 1)
                    continue
                return false
            }

            MouseMove(buttonX, buttonY, 2)
            Sleep(WAIT_BEFORE_CLICK)

            if (!connectionRecoveryEnabled || WinActive("ahk_id " . hwnd) != hwnd)
                return false

            ; Verify the cursor is still over the same target window before input.
            hitRoot := Macro_GetWindowRootAtPoint(buttonX, buttonY, &hitRootTmp2, &hitProcess2)
            disconnectClickHitRoot := hitRoot
            disconnectClickHitProcess := hitProcess2
            if (hitRoot && hitRoot != hwnd) {
                disconnectClickLastResult := "target-changed-to-" . hitProcess2
                if (attemptNo = 1)
                    continue
                return false
            }


            Click()
            Macro_HideFixedPointModalMarkers()
            Sleep(WAIT_AFTER_CLICK)

            ; Roblox may take longer than a single 450 ms sample to transition.
            ; Wait for the modal to disappear for up to 1.5 seconds, checking the
            ; same HWND repeatedly instead of declaring failure on one early frame.
            verifyDeadline := A_TickCount + 1500
            buttonStillPresent := true
            while (A_TickCount < verifyDeadline) {
                Sleep(150)
                if (!WinExist("ahk_id " . hwnd)
                    || !Macro_FindReconnectButton(hwnd, &verifyX, &verifyY)) {
                    buttonStillPresent := false
                    break
                }
            }

            ; The SAME HWND must no longer show the reconnect button. A physical
            ; mouse click alone is not enough to claim that reconnect started.
            if (!buttonStillPresent) {
                clicked := true
                disconnectClickLastResult := "clicked"
                break
            }

            disconnectClickLastResult := "button-still-present-after-wait"

            ; First click failed: re-activate the exact target and re-search the
            ; button. The second click is therefore not a blind double-click.
            if (attemptNo = 1) {
                WinActivate("ahk_id " . hwnd)
                if (!WinWaitActive("ahk_id " . hwnd, , 1))
                    return false
                Sleep(250)
            }
        }
    } catch {
        clicked := false
        disconnectClickLastResult := "exception"
    } finally {
        try {
            MouseMove(savedX, savedY, 0)
        } catch {
        }
        try {
            if (originalForeground && WinExist("ahk_id " . originalForeground) && originalForeground != hwnd)
                WinActivate("ahk_id " . originalForeground)
        } catch {
        }
    }

    return clicked
}

Macro_RecordSuccessfulRecovery(attempts, successTime, targetHwnd := 0, targetPid := 0, targetGameName := "") {
    global disconnectRecoveryHistory
    global disconnectRecoveryPendingGameHistory

    ; Keep the compact session-wide aggregate for existing diagnostics.
    disconnectRecoveryHistory.Push(Map("time", successTime, "attempts", attempts))
    while (disconnectRecoveryHistory.Length > 5)
        disconnectRecoveryHistory.RemoveAt(1)

    ; Keep a client-local copy immediately, even if game title parsing is delayed.
    Macro_AddClientReconnectHistoryRecord(targetHwnd, targetPid, successTime, attempts)

    gameName := Trim(targetGameName . "")
    ; Validate identity against this exact HWND first. A PID-only cache read can
    ; accidentally attribute a reconnect to an older/reused Roblox client.
    try {
        if (gameName = "" && targetHwnd && WinExist("ahk_id " . targetHwnd)) {
            identity := Macro_GetGameIdentityForHwnd(targetHwnd)
            if (IsObject(identity) && identity.HasOwnProp("name"))
                gameName := Trim(identity.name . "")
        }
    } catch {
        if (gameName = "")
            gameName := ""
    }

    if (gameName = "" && targetHwnd) {
        try gameName := Trim(Macro_GetRobloxGameNameForHwnd(targetHwnd) . "")
        catch
            gameName := ""
    }

    if (gameName = "") {
        ; Do not silently drop the timestamp just because the game-identity log
        ; parser has not populated the title yet. The selector can reconcile it
        ; when the same client is selected and its identity becomes available.
        disconnectRecoveryPendingGameHistory.Push(Map(
            "time", successTime, "attempts", attempts,
            "hwnd", targetHwnd, "pid", targetPid))
        while (disconnectRecoveryPendingGameHistory.Length > 20)
            disconnectRecoveryPendingGameHistory.RemoveAt(1)
        return
    }

    Macro_AddGameReconnectHistoryRecord(gameName, successTime, attempts)
    Macro_ReconcilePendingGameReconnectHistory(targetHwnd, gameName)
    Macro_RefreshGameStatusTooltipForHwnd(targetHwnd)
}

Macro_NormalizeReconnectGameKey(gameName) {
    return StrLower(Trim(RegExReplace(gameName . "", "\s+", " ")))
}

Macro_AddGameReconnectHistoryRecord(gameName, successTime, attempts := 1) {
    global disconnectRecoveryHistoryByGame
    gameName := Trim(gameName . "")
    gameKey := Macro_NormalizeReconnectGameKey(gameName)
    if (gameKey = "" || successTime = "")
        return false

    if (!disconnectRecoveryHistoryByGame.Has(gameKey))
        disconnectRecoveryHistoryByGame[gameKey] := []
    gameHistory := disconnectRecoveryHistoryByGame[gameKey]
    gameHistory.Push(Map("time", successTime, "attempts", attempts, "gameName", gameName))
    ; Retain the current completion plus five older timestamps, because the
    ; current completion is shown separately and filtered from the recent list.
    while (gameHistory.Length > 6)
        gameHistory.RemoveAt(1)
    return true
}

Macro_AddClientReconnectHistoryRecord(targetHwnd, targetPid, successTime, attempts := 1) {
    global disconnectRecoveryHistoryByHwnd
    if ((!targetHwnd && !targetPid) || successTime = "")
        return false
    ; PID is more stable than HWND across a recreated Roblox window. Retain an
    ; HWND fallback for cases where the process ID is unavailable.
    key := targetPid ? ("pid:" . targetPid) : ("hwnd:" . targetHwnd)
    if (!disconnectRecoveryHistoryByHwnd.Has(key))
        disconnectRecoveryHistoryByHwnd[key] := []
    clientHistory := disconnectRecoveryHistoryByHwnd[key]
    clientHistory.Push(Map("time", successTime, "attempts", attempts))
    while (clientHistory.Length > 5)
        clientHistory.RemoveAt(1)
    return true
}

Macro_GetRecentClientReconnectTimesText(targetHwnd) {
    global disconnectRecoveryHistoryByHwnd
    isKorean := (Macro_GetWindowsUILanguage() = "ko")
    if (!targetHwnd || !IsObject(disconnectRecoveryHistoryByHwnd))
        return ""
    targetPid := 0
    try targetPid := WinGetPID("ahk_id " . targetHwnd)
    catch
        targetPid := 0
    key := targetPid ? ("pid:" . targetPid) : ("hwnd:" . targetHwnd)
    if (!disconnectRecoveryHistoryByHwnd.Has(key)) {
        hwndKey := "hwnd:" . targetHwnd
        if (!disconnectRecoveryHistoryByHwnd.Has(hwndKey))
            return ""
        key := hwndKey
    }
    clientHistory := disconnectRecoveryHistoryByHwnd[key]
    if (!IsObject(clientHistory) || clientHistory.Length = 0)
        return ""
    textOut := isKorean ? "최근 재연결 완료 시각" : "Recent reconnect completion times"
    i := clientHistory.Length
    shown := 0
    while (i >= 1 && shown < 5) {
        rec := clientHistory[i]
        if (rec.Has("time") && rec["time"] != "") {
            textOut .= "`n" . rec["time"]
            shown += 1
        }
        i -= 1
    }
    return textOut
}

Macro_ReconcilePendingGameReconnectHistory(targetHwnd, gameName) {
    global disconnectRecoveryPendingGameHistory
    if (!IsObject(disconnectRecoveryPendingGameHistory)
        || !disconnectRecoveryPendingGameHistory.Length || Trim(gameName . "") = "")
        return

    targetPid := 0
    if (targetHwnd && WinExist("ahk_id " . targetHwnd)) {
        try targetPid := WinGetPID("ahk_id " . targetHwnd)
        catch
            targetPid := 0
    }

    matchedRecords := []
    removeIndices := []
    for index, rec in disconnectRecoveryPendingGameHistory {
        recordHwnd := rec.Has("hwnd") ? rec["hwnd"] : 0
        recordPid := rec.Has("pid") ? rec["pid"] : 0
        if ((targetHwnd && recordHwnd = targetHwnd)
            || (targetPid && recordPid && recordPid = targetPid)) {
            matchedRecords.Push(rec)
            removeIndices.Push(index)
        }
    }

    ; Remove newest indices first, then re-add matched timestamps in their
    ; original chronological order so the tooltip still lists newest first.
    index := removeIndices.Length
    while (index >= 1) {
        disconnectRecoveryPendingGameHistory.RemoveAt(removeIndices[index])
        index -= 1
    }
    for _, rec in matchedRecords
        Macro_AddGameReconnectHistoryRecord(gameName, rec["time"], rec.Has("attempts") ? rec["attempts"] : 1)
}

Macro_RefreshGameStatusTooltipForHwnd(targetHwnd) {
    global gameStatusRowTargets, gameStatusTooltipRowIndex, gameStatusTooltipText
    ; Refresh only if this client's tooltip is already being shown. Do not cause
    ; an unexpected tooltip to pop up over a row the user is not inspecting.
    if (!targetHwnd || !IsObject(gameStatusRowTargets) || gameStatusTooltipText = "")
        return
    for rowIndex, rowHwnd in gameStatusRowTargets {
        if (rowHwnd = targetHwnd && gameStatusTooltipRowIndex = rowIndex) {
            Macro_UpdateGameStatusUsernameTooltip(rowIndex)
            return
        }
    }
}

Macro_GetRecentGameReconnectTimesText(gameName, excludeTime := "") {
    global disconnectRecoveryHistoryByGame
    isKorean := (Macro_GetWindowsUILanguage() = "ko")
    gameKey := Macro_NormalizeReconnectGameKey(gameName)
    if (gameKey = "" || !IsObject(disconnectRecoveryHistoryByGame)
        || !disconnectRecoveryHistoryByGame.Has(gameKey))
        return ""

    gameHistory := disconnectRecoveryHistoryByGame[gameKey]
    if (!IsObject(gameHistory) || gameHistory.Length = 0)
        return ""

    textOut := isKorean ? "최근 재연결 완료 시각" : "Recent reconnect completion times"
    i := gameHistory.Length
    shown := 0
    while (i >= 1 && shown < 5) {
        rec := gameHistory[i]
        if (rec.Has("time") && rec["time"] != "") {
            recordTime := rec["time"] . ""
            ; Skip the current successful-reconnect timestamp because it is
            ; already shown as the completion time above.
            if (excludeTime != "" && recordTime = (excludeTime . "")) {
                i -= 1
                continue
            }
            textOut .= "`n" . recordTime
            shown += 1
        }
        i -= 1
    }
    if (shown = 0)
        return ""
    return textOut
}

Macro_FinishConnectionRecovery(success := false) {
    global connectionRecoveryBusy, connectionRecoveryHwnd, connectionRecoveryAttempts
    global connectionRecoveryTargetPid, connectionRecoveryDetectedPid, connectionRecoveryDetectedVerified, connectionRecoveryQueue
    global connectionRecoveryStableChecks, connectionRecoveryNextTick, connectionRecoveryStage
    global connectionRecoveryPending, connectionRecoveryPendingSince
    global connectionRecoveryOriginalMinMax, connectionRecoveryDiscoveredMinMax
    global connectionRecoveryDetectedHwnd, connectionRecoveryLastFocusVerifyTick
    global connectionRecoveryGameName
    global disconnectAlertStage, disconnectAlertTitle, disconnectAlertBody, disconnectAlertPrimaryButton
    global disconnectAlertReason
    global disconnectAlertLastRecoveryAttempts, disconnectAlertLastSuccessTime
    global disconnectRecoveryTotalSuccesses
    global disconnectManualBatchReconnect, connectionRecoveryAutoBatch
    global connectionRecoveryStartFailureCounts

    attemptsForRecord := connectionRecoveryAttempts

    if (success) {
        successTime := Macro_Format12HourCurrentTime(A_Now)
        disconnectRecoveryTotalSuccesses += 1
        disconnectAlertLastRecoveryAttempts := attemptsForRecord
        disconnectAlertLastSuccessTime := successTime
        Macro_RecordSuccessfulRecovery(attemptsForRecord, successTime, connectionRecoveryHwnd, connectionRecoveryTargetPid, connectionRecoveryGameName)

        ; Preserve the full disconnect cause, inspection path, attempts, history,
        ; and timing in the final report rather than replacing it with a short status.
        try {
            disconnectAlertStage := "Reconnected"
            Macro_RecordDisconnectProcessStep("complete", successTime)
            Macro_ShowDisconnectTrayProgress("ROBLOX 재연결이 정상적으로 확인되었습니다.", "✅ ROBLOX 재연결 완료")
            disconnectAlertTitle.Text := Macro_GetDisconnectUIText("reconnectedTitle")
            disconnectAlertBody.Text := Macro_GetDisconnectCompletedBody(disconnectAlertReason)
            Macro_UpdateFixedPointModalDebugText()
            Macro_ResizeDisconnectAlert()
            disconnectAlertPrimaryButton.Enabled := true
            disconnectAlertPrimaryButton.Text := Macro_GetDisconnectUIText("close")
        } catch {
        }
    } else {
        disconnectAlertLastRecoveryAttempts := attemptsForRecord
        Macro_RecordDisconnectProcessStep("failed")
        try {
            disconnectAlertStage := "Failed"
            disconnectAlertTitle.Text := Macro_GetDisconnectUIText("failedTitle")
            disconnectAlertBody.Text := Macro_GetDisconnectAlertBody(disconnectAlertReason)
            Macro_ResizeDisconnectAlert()
            disconnectAlertPrimaryButton.Enabled := true
            disconnectAlertPrimaryButton.Text := Macro_GetDisconnectUIText("inspect")
        } catch {
        }
    }

    ; Restore the original minimized state when possible.
    hwnd := connectionRecoveryHwnd
    finishedPid := connectionRecoveryTargetPid
    Macro_RemoveReconnectCandidate(hwnd, finishedPid)
    try connectionRecoveryStartFailureCounts.Delete(hwnd . "|" . finishedPid)
    if (hwnd && WinExist("ahk_id " . hwnd) && connectionRecoveryOriginalMinMax = -1) {
        try {
            WinMinimize("ahk_id " . hwnd)
        } catch {
        }
    }

    connectionRecoveryBusy := false
    connectionRecoveryHwnd := 0
    connectionRecoveryTargetPid := 0
    connectionRecoveryGameName := ""
    connectionRecoveryAttempts := 0
    connectionRecoveryStableChecks := 0
    connectionRecoveryNextTick := 0
    connectionRecoveryStage := ""
    connectionRecoveryOriginalMinMax := 0
    connectionRecoveryDiscoveredMinMax := 0
    connectionRecoveryDetectedHwnd := 0
    connectionRecoveryDetectedPid := 0
    connectionRecoveryDetectedVerified := false
    connectionRecoveryLastFocusVerifyTick := 0

    connectionRecoveryPending := false
    connectionRecoveryPendingSince := 0

    ; A user-initiated full inspection forms a batch: once this client finishes,
    ; start the next verified client automatically. Leave the final result visible
    ; when the queue has been drained.
    nextCandidate := Macro_PeekReconnectCandidate()
    if (disconnectManualBatchReconnect) {
        if (nextCandidate) {
            connectionRecoveryDetectedHwnd := nextCandidate["hwnd"]
            connectionRecoveryDetectedPid := nextCandidate["pid"]
            connectionRecoveryDetectedVerified := true
            SetTimer(Macro_StartNextManualBatchReconnect, -150)
        } else {
            disconnectManualBatchReconnect := false
        }
    } else if (connectionRecoveryAutoBatch) {
        if (nextCandidate) {
            SetTimer(Macro_StartNextAutomaticBatchReconnect, -150)
        } else {
            connectionRecoveryAutoBatch := false
        }
    } else if (nextCandidate) {
        ; For the ordinary watchdog path, keep the existing inspect-first behavior.
        connectionRecoveryDetectedHwnd := nextCandidate["hwnd"]
        connectionRecoveryDetectedPid := nextCandidate["pid"]
        connectionRecoveryDetectedVerified := true
        try {
            disconnectAlertStage := "Signal"
            disconnectAlertTitle.Text := Macro_GetDisconnectCodeTitle()
            disconnectAlertBody.Text := Macro_GetVisibleReconnectReason()
            Macro_ResizeDisconnectAlert()
            disconnectAlertPrimaryButton.Enabled := true
            disconnectAlertPrimaryButton.Text := Macro_GetDisconnectUIText("inspect")
        } catch {
        }
    }
}

Macro_StartNextAutomaticBatchReconnect(*) {
    global connectionRecoveryAutoBatch, connectionRecoveryBusy
    global connectionRecoveryDetectedHwnd, connectionRecoveryDetectedPid, connectionRecoveryDetectedVerified
    global connectionRecoveryOriginalMinMax, disconnectAlertDetectedHwnd
    global AUTO_HIDDEN_SCAN_DELAY_SEC, disconnectAlertActive, disconnectAlertStage
    global disconnectAlertGui, disconnectAlertTitle, disconnectAlertBody, disconnectAlertPrimaryButton

    if (!connectionRecoveryAutoBatch || connectionRecoveryBusy)
        return

    candidate := Macro_PeekReconnectCandidate()
    if (!candidate) {
        connectionRecoveryAutoBatch := false
        return
    }

    if (!Macro_IsReconnectCandidateValid(candidate)) {
        Macro_RemoveReconnectCandidate(candidate["hwnd"], candidate["pid"])
        SetTimer(Macro_StartNextAutomaticBatchReconnect, -50)
        return
    }

    ; Respect the same user-idle safety gate as the main automatic path.
    if (Macro_IsUserActiveAnywhere(AUTO_HIDDEN_SCAN_DELAY_SEC * 1000)) {
        SetTimer(Macro_StartNextAutomaticBatchReconnect, -1000)
        return
    }

    connectionRecoveryDetectedHwnd := candidate["hwnd"]
    connectionRecoveryDetectedPid := candidate["pid"]
    connectionRecoveryDetectedVerified := true
    connectionRecoveryOriginalMinMax := candidate["minmax"]
    disconnectAlertDetectedHwnd := candidate["hwnd"]

    try {
        if (disconnectAlertActive && IsObject(disconnectAlertGui) && disconnectAlertGui.Hwnd) {
            disconnectAlertStage := "Signal"
            disconnectAlertTitle.Text := Macro_GetDisconnectCodeTitle()
            disconnectAlertBody.Text := Macro_GetVisibleReconnectReason()
            disconnectAlertPrimaryButton.Enabled := true
            disconnectAlertPrimaryButton.Text := Macro_GetDisconnectUIText("inspect")
            Macro_ResizeDisconnectAlert()
        }
    } catch {
    }

    Macro_StartConnectionRecovery()
}

Macro_StartNextManualBatchReconnect() {
    global disconnectManualBatchReconnect, connectionRecoveryBusy
    global connectionRecoveryDetectedHwnd, connectionRecoveryDetectedPid, connectionRecoveryDetectedVerified
    global connectionRecoveryOriginalMinMax, disconnectAlertDetectedHwnd

    if (!disconnectManualBatchReconnect || connectionRecoveryBusy)
        return

    candidate := Macro_PeekReconnectCandidate()
    if (!candidate) {
        disconnectManualBatchReconnect := false
        return
    }

    ; Bind validation to this candidate's HWND and PID before starting it.
    if (!Macro_IsReconnectCandidateValid(candidate)) {
        Macro_RemoveReconnectCandidate(candidate["hwnd"], candidate["pid"])
        SetTimer(Macro_StartNextManualBatchReconnect, -50)
        return
    }

    targetHwnd := candidate["hwnd"]
    connectionRecoveryDetectedHwnd := targetHwnd
    connectionRecoveryDetectedPid := candidate["pid"]
    connectionRecoveryDetectedVerified := true
    connectionRecoveryOriginalMinMax := candidate["minmax"]
    disconnectAlertDetectedHwnd := targetHwnd
    Macro_StartManualReconnect(targetHwnd)
}

Macro_ResetConnectionRecoveryState(stopTimer := false) {
    global connectionRecoveryBusy, connectionRecoveryHwnd, connectionRecoveryAttempts
    global connectionRecoveryStableChecks, connectionRecoveryNextTick, connectionRecoveryStage
    global connectionRecoveryPending, connectionRecoveryPendingSince
    global connectionRecoveryOriginalForeground, connectionRecoveryOriginalMinMax
    global connectionRecoveryDiscoveredMinMax, connectionRecoveryDetectedHwnd, connectionRecoveryDetectedPid
    global connectionRecoveryDetectedVerified, connectionRecoveryTargetPid, connectionRecoveryQueue
    global connectionRecoveryLastFocusVerifyTick
    global connectionRecoveryGameName
    global connectionLogState
    global disconnectManualBatchReconnect, connectionRecoveryAutoBatch
    global connectionRecoveryStartFailureCounts
    global disconnectLogSignalFiles, disconnectLogSignalVersions, disconnectLogSignalSequence

    if (stopTimer) {
        SetTimer(Macro_ConnectionWatchdog, 0)
        SetTimer(Macro_ConnectionLogWatchdog, 0)
        SetTimer(Macro_StartNextAutomaticBatchReconnect, 0)
        Macro_ResetLogAutoRejoinState()
        Macro_ResetDisconnectGraceState()
    }

    connectionRecoveryBusy := false
    connectionRecoveryHwnd := 0
    connectionRecoveryAttempts := 0
    connectionRecoveryStableChecks := 0
    connectionRecoveryNextTick := 0
    connectionRecoveryStage := ""
    connectionRecoveryPending := false
    connectionRecoveryPendingSince := 0
    connectionRecoveryOriginalForeground := 0
    connectionRecoveryOriginalMinMax := 0
    connectionRecoveryDiscoveredMinMax := 0
    connectionRecoveryDetectedHwnd := 0
    connectionRecoveryDetectedPid := 0
    connectionRecoveryDetectedVerified := false
    connectionRecoveryTargetPid := 0
    connectionRecoveryGameName := ""
    connectionRecoveryQueue := []
    connectionRecoveryLastFocusVerifyTick := 0
    disconnectManualBatchReconnect := false
    connectionRecoveryAutoBatch := false
    connectionRecoveryStartFailureCounts.Clear()
    disconnectLogSignalFiles := []
    disconnectLogSignalVersions.Clear()
    disconnectLogSignalSequence := 0

    try {
        connectionLogState.Clear()
    } catch {
        connectionLogState := Map()
    }
}

; =====================================================================
; 🧠 [System Clean Engine] 윈도우 커널을 직접 타격하여 누수된 빈 메모리를 RAM에서 강제로 회수합니다.
; =====================================================================
Macro_EmptyWorkingSet() {
    try {
        ; 현재 매크로 프로세스가 붙잡고 있는 물리 메모리(Working Set)를 즉시 최소화하여 방출합니다.
        DllCall("SetProcessWorkingSetSize", "Ptr", DllCall("GetCurrentProcess"), "Ptr", -1, "Ptr", -1)
    }
}


; =====================================================================
; 🔎 F6 Multi-Resolution Modal Diagnostic
;     - Uses the same adaptive gate, measured bounds, and button points.
;     - Markers: yellow=gate, green=button samples, red=outside,
;       cyan=modal bounds, white=click point.
;     - Marker positions follow only Roblox foreground/location changes.
;     - No mouse movement is used.
; =====================================================================

Macro_EnsureFixedPointModalDebugAlert(targetHwnd := 0) {
    global fixedPointModalDebugOwnsAlert
    global disconnectAlertGui, disconnectAlertActive

    alertGuiValid := false
    try alertGuiValid := IsObject(disconnectAlertGui) && disconnectAlertGui.Hwnd
        && WinExist("ahk_id " . disconnectAlertGui.Hwnd)

    if (!alertGuiValid || !disconnectAlertActive) {
        try {
            if (IsObject(disconnectAlertGui) && disconnectAlertGui.Hwnd)
                disconnectAlertGui.Destroy()
        } catch {
        }
        disconnectAlertGui := ""
        disconnectAlertActive := false
        fixedPointModalDebugOwnsAlert := true
        Macro_ShowDisconnectAlert("F6 modal diagnostic.", targetHwnd)
    } else {
        fixedPointModalDebugOwnsAlert := false
    }
}

Macro_ToggleFixedPointModalDebug() {
    global fixedPointModalDebugEnabled
    global fixedPointModalDebugTargetHwnd, fixedPointModalDebugLastHwnd
    global disconnectAlertLastSizeKey, disconnectAlertLastPaintKey
    global fixedPointModalDebugForegroundHook, fixedPointModalDebugLocationHook
    global fixedPointModalDebugEventCallback, fixedPointModalDebugOwnsAlert
    global fixedPointModalDebugRefreshPending, fixedPointModalDebugRefreshNeedsProbe
    global fixedPointModalDebugRefreshNeedsAlert
    global fixedPointModalDebugProbeTargetHwnd
    global fixedPointModalDebugAlertTargetHwnd, fixedPointModalDebugAlertDeadline
    global fixedPointModalDebugProbeRunning, fixedPointModalDebugProbeBusyHwnd
    global fixedPointModalDebugReconnectPending, fixedPointModalDebugReconnectHwnd

    Macro_EnsureFixedPointModalDebugMarkers()
    fixedPointModalDebugEnabled := !fixedPointModalDebugEnabled

    if (fixedPointModalDebugEnabled) {
        ; Capture Roblox BEFORE creating/updating the diagnostic alert.
        target := 0
        try {
            active := WinExist("A")
            if (active && WinGetProcessName("ahk_id " . active) = "RobloxPlayerBeta.exe")
                target := active
        } catch {
            target := 0
        }

        fixedPointModalDebugTargetHwnd := target
        fixedPointModalDebugLastHwnd := target
        Macro_CreateFixedPointModalMarkers()
        Macro_HideFixedPointModalMarkers()
        Macro_ClearFixedPointModalPinnedResult(true)

        ; Reuse a live recovery alert, but recreate a dismissed/stale GUI so F6
        ; always has a valid diagnostic window to restore after row selection.
        Macro_EnsureFixedPointModalDebugAlert(target)


        ; WinEvent hooks: foreground changes + top-level Roblox location changes.
        try {
            fixedPointModalDebugEventCallback := CallbackCreate(Macro_FixedPointModalWinEventProc)
            fixedPointModalDebugForegroundHook := DllCall(
                "user32\SetWinEventHook",
                "UInt", 0x0003, "UInt", 0x0003,
                "Ptr", 0, "Ptr", fixedPointModalDebugEventCallback,
                "UInt", 0, "UInt", 0, "UInt", 0, "Ptr"
            )
            fixedPointModalDebugLocationHook := DllCall(
                "user32\SetWinEventHook",
                "UInt", 0x800B, "UInt", 0x800B,
                "Ptr", 0, "Ptr", fixedPointModalDebugEventCallback,
                "UInt", 0, "UInt", 0, "UInt", 0, "Ptr"
            )
        } catch {
            fixedPointModalDebugForegroundHook := 0
            fixedPointModalDebugLocationHook := 0
        }

        Macro_FixedPointModalDebugRefresh(target)
        Macro_QueueFixedPointModalDebugRefresh(target, true, false)
        Macro_FixedPointModalDebugProbeTick()
        SetTimer(Macro_FixedPointModalDebugProbeTick, 5000)
    } else {
        Macro_StopFixedPointModalDebugHooks()
        SetTimer(Macro_RunFixedPointModalDebugRefresh, 0)
        SetTimer(Macro_FixedPointModalDebugProbeTick, 0)
        SetTimer(Macro_UpdateF6ModalReconnectCountdown, 0)
        fixedPointModalDebugReconnectPending := false
        fixedPointModalDebugReconnectHwnd := 0
        fixedPointModalDebugRefreshPending := false
        fixedPointModalDebugRefreshNeedsProbe := false
        fixedPointModalDebugRefreshNeedsAlert := false
        fixedPointModalDebugProbeTargetHwnd := 0
        fixedPointModalDebugProbeRunning := false
        fixedPointModalDebugProbeBusyHwnd := 0
        fixedPointModalDebugAlertTargetHwnd := 0
        fixedPointModalDebugAlertDeadline := 0
        Macro_DestroyFixedPointModalMarkers()
        Macro_ClearFixedPointModalPinnedResult(true)

        global disconnectAlertF6Diag, disconnectAlertGui, disconnectAlertActive
        global fixedPointModalDebugOwnsAlert

        if (IsObject(disconnectAlertF6Diag))
            disconnectAlertF6Diag.Visible := false

        ; If F6 created the diagnostic window itself, remove only that
        ; diagnostic-owned alert. A pre-existing real recovery alert is kept.
        if (fixedPointModalDebugOwnsAlert) {
            try {
                if (IsObject(disconnectAlertGui))
                    disconnectAlertGui.Destroy()
            } catch {
            }
            disconnectAlertGui := ""
            disconnectAlertActive := false
            disconnectAlertLastSizeKey := ""
            disconnectAlertLastPaintKey := ""
        }
        fixedPointModalDebugOwnsAlert := false

        Macro_ResizeDisconnectAlert()
    }
}

Macro_CreateFixedPointModalMarkers() {
    global fixedPointModalDebugMarkers

    Macro_EnsureFixedPointModalDebugMarkers()
    Macro_DestroyFixedPointModalMarkers()
    fixedPointModalDebugMarkers := []

    colors := ["FFFF00", "00FF66", "FF3030", "35D9FF", "FFFFFF"]
    Loop 15 {
        if (A_Index <= 4)
            group := 1
        else if (A_Index <= 6)
            group := 2
        else if (A_Index <= 10)
            group := 3
        else if (A_Index <= 14)
            group := 4
        else
            group := 5
        c := colors[group]

        try {
            g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 -DPIScale")
            g.BackColor := c
            g.Show("x0 y0 w18 h18 Hide NoActivate")

            ; True hollow square: window region = outer rectangle minus inner.
            outer := DllCall("gdi32\CreateRectRgn", "Int", 0, "Int", 0, "Int", 18, "Int", 18, "Ptr")
            inner := DllCall("gdi32\CreateRectRgn", "Int", 2, "Int", 2, "Int", 16, "Int", 16, "Ptr")
            DllCall("gdi32\CombineRgn", "Ptr", outer, "Ptr", outer, "Ptr", inner, "Int", 4, "Int")
            DllCall("user32\SetWindowRgn", "Ptr", g.Hwnd, "Ptr", outer, "Int", 1)
            DllCall("gdi32\DeleteObject", "Ptr", inner)

            fixedPointModalDebugMarkers.Push(g)
        } catch {
            try {
                if (IsObject(g))
                    g.Destroy()
            } catch {
            }
        }
    }
}

Macro_DestroyFixedPointModalMarkers() {
    global fixedPointModalDebugMarkers, fixedPointModalAutoHideTimerByIndex

    Macro_EnsureFixedPointModalDebugMarkers()
    for _, hideTimer in fixedPointModalAutoHideTimerByIndex {
        try SetTimer(hideTimer, 0)
        catch {
        }
    }
    fixedPointModalAutoHideTimerByIndex := Map()

    for _, g in fixedPointModalDebugMarkers {
        try g.Destroy()
        catch {
        }
    }
    fixedPointModalDebugMarkers := []
}

Macro_ShowFixedPointModalProbeMarker(markerIndex, x, y, autoHideMs := 500) {
    global fixedPointModalDebugMarkers, fixedPointModalAutoHideTimerByIndex

    ; Automatic and F6 probes share the same sampled-point markers.
    if (markerIndex < 1 || markerIndex > 15)
        return

    Macro_EnsureFixedPointModalDebugMarkers()
    if (fixedPointModalDebugMarkers.Length != 15)
        Macro_CreateFixedPointModalMarkers()
    if (fixedPointModalDebugMarkers.Length < markerIndex)
        return

    try {
        marker := fixedPointModalDebugMarkers[markerIndex]
        marker.Show("x" . (x - 9) . " y" . (y - 9) . " w18 h18 NoActivate")
        DllCall("user32\UpdateWindow", "Ptr", marker.Hwnd, "Int")
    } catch {
        return
    }

    ; Refresh each sampled marker's short timer; confirmed detections pin all
    ; final markers with autoHideMs = 0.
    if (fixedPointModalAutoHideTimerByIndex.Has(markerIndex)) {
        try SetTimer(fixedPointModalAutoHideTimerByIndex[markerIndex], 0)
        catch {
        }
        fixedPointModalAutoHideTimerByIndex.Delete(markerIndex)
    }

    if (autoHideMs > 0) {
        hideTimer := (*) => Macro_HideFixedPointModalProbeMarker(markerIndex)
        fixedPointModalAutoHideTimerByIndex[markerIndex] := hideTimer
        SetTimer(hideTimer, -autoHideMs)
    }
}

Macro_HideFixedPointModalProbeMarker(markerIndex) {
    global fixedPointModalDebugMarkers
    global fixedPointModalAutoHideTimerByIndex

    if (!IsObject(fixedPointModalDebugMarkers)
        || fixedPointModalDebugMarkers.Length < markerIndex)
        return
    if (fixedPointModalAutoHideTimerByIndex.Has(markerIndex)) {
        try SetTimer(fixedPointModalAutoHideTimerByIndex[markerIndex], 0)
        catch {
        }
        fixedPointModalAutoHideTimerByIndex.Delete(markerIndex)
    }
    try fixedPointModalDebugMarkers[markerIndex].Hide()
    catch {
    }
}

Macro_ShowFixedPointModalMarkers(hwnd) {
    global fixedPointModalDebugMarkers, disconnectModalDebugGeometry

    Macro_EnsureFixedPointModalDebugMarkers()
    if (!hwnd || !WinExist("ahk_id " . hwnd)) {
        Macro_HideFixedPointModalMarkers()
        return
    }

    if (fixedPointModalDebugMarkers.Length != 15) {
        Macro_HideFixedPointModalMarkers()
        return
    }

    try {
        WinGetClientPos(&cx, &cy, &cw, &ch, "ahk_id " . hwnd)
        centerX := cx + Round(cw / 2)
        centerY := cy + Round(ch / 2)
        geometryMatches := IsObject(disconnectModalDebugGeometry)
            && disconnectModalDebugGeometry["hwnd"] = hwnd
            && disconnectModalDebugGeometry["centerX"] = centerX
            && disconnectModalDebugGeometry["centerY"] = centerY
        if (!geometryMatches) {
            scaleInfo := Macro_GetReconnectModalScaleCandidates(centerX, centerY)
            oldGeometry := disconnectModalDebugGeometry
            if (IsObject(oldGeometry) && oldGeometry["hwnd"] = hwnd && oldGeometry["measured"]) {
                oldBounds := oldGeometry["bounds"]
                dx := centerX - oldGeometry["centerX"]
                dy := centerY - oldGeometry["centerY"]
                shiftedBounds := [oldBounds[1] + dx, oldBounds[2] + dy,
                    oldBounds[3] + dx, oldBounds[4] + dy]
                disconnectModalDebugGeometry := Macro_BuildReconnectModalDebugGeometry(
                    centerX, centerY, oldGeometry["scale"], shiftedBounds, true, hwnd
                )
            } else {
                disconnectModalDebugGeometry := Macro_BuildReconnectModalDebugGeometry(
                    centerX, centerY, scaleInfo["preferred"], "", false, hwnd
                )
            }
        }
    } catch {
        Macro_HideFixedPointModalMarkers()
        return
    }

    pts := disconnectModalDebugGeometry["markers"]
    if (pts.Length != 15) {
        Macro_HideFixedPointModalMarkers()
        return
    }

    for i, pt in pts {
        try {
            g := fixedPointModalDebugMarkers[i]
            g.Show("x" . (pt[1] - 9) . " y" . (pt[2] - 9) . " w18 h18 NoActivate")
        } catch {
        }
    }
}

Macro_HidePinnedFixedPointModalMarkers() {
    global fixedPointModalDebugMarkers, fixedPointModalAutoHideTimerByIndex

    Macro_EnsureFixedPointModalDebugMarkers()
    for markerIndex, marker in fixedPointModalDebugMarkers {
        ; A marker with an active timer belongs to an unfinished/failed probe.
        if (fixedPointModalAutoHideTimerByIndex.Has(markerIndex))
            continue
        try marker.Hide()
        catch {
        }
    }
}
Macro_HideFixedPointModalMarkers() {
    global fixedPointModalDebugMarkers, fixedPointModalAutoHideTimerByIndex
    Macro_EnsureFixedPointModalDebugMarkers()
    for _, hideTimer in fixedPointModalAutoHideTimerByIndex {
        try SetTimer(hideTimer, 0)
        catch {
        }
    }
    fixedPointModalAutoHideTimerByIndex := Map()
    for _, g in fixedPointModalDebugMarkers {
        try g.Hide()
        catch {
        }
    }
}

Macro_EnsureFixedPointModalDebugMarkers() {
    global fixedPointModalDebugMarkers, fixedPointModalAutoHideTimerByIndex
    if (!IsSet(fixedPointModalDebugMarkers) || !IsObject(fixedPointModalDebugMarkers))
        fixedPointModalDebugMarkers := []
    if (!IsSet(fixedPointModalAutoHideTimerByIndex) || !IsObject(fixedPointModalAutoHideTimerByIndex))
        fixedPointModalAutoHideTimerByIndex := Map()
}
Macro_FixedPointModalDebugRefresh(hwnd := 0) {
    global fixedPointModalDebugEnabled, fixedPointModalDebugTargetHwnd, fixedPointModalDebugLastHwnd
    global fixedPointModalDebugPinned, fixedPointModalDebugPinnedHwnd
    if (!fixedPointModalDebugEnabled)
        return

    if (fixedPointModalDebugPinned && fixedPointModalDebugPinnedHwnd
        && WinExist("ahk_id " . fixedPointModalDebugPinnedHwnd))
        hwnd := fixedPointModalDebugPinnedHwnd
    else if (!hwnd)
        hwnd := fixedPointModalDebugTargetHwnd

    if (!hwnd || !WinExist("ahk_id " . hwnd)) {
        Macro_HideFixedPointModalMarkers()
        Macro_UpdateFixedPointModalDebugText()
        return
    }

    try {
        if (WinGetProcessName("ahk_id " . hwnd) != "RobloxPlayerBeta.exe") {
            Macro_HideFixedPointModalMarkers()
            Macro_UpdateFixedPointModalDebugText()
            return
        }
    } catch {
        Macro_HideFixedPointModalMarkers()
        return
    }

    fixedPointModalDebugTargetHwnd := hwnd
    if (fixedPointModalDebugLastHwnd != hwnd) {
        Macro_HideFixedPointModalMarkers()
        fixedPointModalDebugLastHwnd := hwnd
    }
    Macro_UpdateFixedPointModalDebugText()
}

Macro_CaptureFixedPointModalDiagSnapshot() {
    global disconnectScreenDiagValid, disconnectScreenDiagPassed, disconnectScreenDarkCount, disconnectScreenDarkTotal
    global disconnectButtonDiagValid, disconnectButtonDiagPassed, disconnectButtonWhiteCount, disconnectButtonWhiteTotal
    global disconnectButtonDarkAroundCount, disconnectButtonDarkAroundTotal, disconnectButtonBandHits
    global disconnectPrecisionPassed, disconnectPrecisionDifferentCount, disconnectPrecisionDifferentTotal
    global disconnectModalDebugGeometry, disconnectModalDiagScale, disconnectModalDiagScaleAttempts
    global disconnectModalDiagReadCount, disconnectModalDiagElapsedMs

    return Map(
        "screenValid", disconnectScreenDiagValid,
        "screenPassed", disconnectScreenDiagPassed,
        "screenDarkCount", disconnectScreenDarkCount,
        "screenDarkTotal", disconnectScreenDarkTotal,
        "buttonValid", disconnectButtonDiagValid,
        "buttonPassed", disconnectButtonDiagPassed,
        "buttonWhiteCount", disconnectButtonWhiteCount,
        "buttonWhiteTotal", disconnectButtonWhiteTotal,
        "buttonDarkAroundCount", disconnectButtonDarkAroundCount,
        "buttonDarkAroundTotal", disconnectButtonDarkAroundTotal,
        "buttonBandHits", disconnectButtonBandHits,
        "precisionPassed", disconnectPrecisionPassed,
        "precisionDifferentCount", disconnectPrecisionDifferentCount,
        "precisionDifferentTotal", disconnectPrecisionDifferentTotal,
        "geometry", disconnectModalDebugGeometry,
        "scale", disconnectModalDiagScale,
        "scaleAttempts", disconnectModalDiagScaleAttempts,
        "readCount", disconnectModalDiagReadCount,
        "elapsedMs", disconnectModalDiagElapsedMs
    )
}

Macro_RestoreFixedPointModalDiagSnapshot(snapshot) {
    global disconnectScreenDiagValid, disconnectScreenDiagPassed, disconnectScreenDarkCount, disconnectScreenDarkTotal
    global disconnectButtonDiagValid, disconnectButtonDiagPassed, disconnectButtonWhiteCount, disconnectButtonWhiteTotal
    global disconnectButtonDarkAroundCount, disconnectButtonDarkAroundTotal, disconnectButtonBandHits
    global disconnectPrecisionPassed, disconnectPrecisionDifferentCount, disconnectPrecisionDifferentTotal
    global disconnectModalDebugGeometry, disconnectModalDiagScale, disconnectModalDiagScaleAttempts
    global disconnectModalDiagReadCount, disconnectModalDiagElapsedMs

    if (!IsObject(snapshot) || !snapshot.Has("screenValid"))
        return false

    disconnectScreenDiagValid := snapshot["screenValid"]
    disconnectScreenDiagPassed := snapshot["screenPassed"]
    disconnectScreenDarkCount := snapshot["screenDarkCount"]
    disconnectScreenDarkTotal := snapshot["screenDarkTotal"]
    disconnectButtonDiagValid := snapshot["buttonValid"]
    disconnectButtonDiagPassed := snapshot["buttonPassed"]
    disconnectButtonWhiteCount := snapshot["buttonWhiteCount"]
    disconnectButtonWhiteTotal := snapshot["buttonWhiteTotal"]
    disconnectButtonDarkAroundCount := snapshot["buttonDarkAroundCount"]
    disconnectButtonDarkAroundTotal := snapshot["buttonDarkAroundTotal"]
    disconnectButtonBandHits := snapshot["buttonBandHits"]
    disconnectPrecisionPassed := snapshot["precisionPassed"]
    disconnectPrecisionDifferentCount := snapshot["precisionDifferentCount"]
    disconnectPrecisionDifferentTotal := snapshot["precisionDifferentTotal"]
    disconnectModalDebugGeometry := snapshot["geometry"]
    disconnectModalDiagScale := snapshot["scale"]
    disconnectModalDiagScaleAttempts := snapshot["scaleAttempts"]
    disconnectModalDiagReadCount := snapshot["readCount"]
    disconnectModalDiagElapsedMs := snapshot["elapsedMs"]
    return true
}

Macro_ClearFixedPointModalPinnedResult(clearLast := false) {
    global fixedPointModalDebugPinned, fixedPointModalDebugPinnedHwnd
    global fixedPointModalDebugPinnedResult, fixedPointModalDebugLastConfirmedResult

    fixedPointModalDebugPinned := false
    fixedPointModalDebugPinnedHwnd := 0
    fixedPointModalDebugPinnedResult := Map()
    if (clearLast)
        fixedPointModalDebugLastConfirmedResult := Map()
}

Macro_FixedPointModalDebugProbeTick(*) {
    global fixedPointModalDebugEnabled, fixedPointModalDebugTargetHwnd, fixedPointModalDebugLastHwnd
    global fixedPointModalDebugPinned, fixedPointModalDebugPinnedHwnd
    global fixedPointModalDebugPinnedResult, fixedPointModalDebugLastConfirmedResult
    global fixedPointModalDebugProbeRunning, fixedPointModalDebugProbeBusyHwnd
    global disconnectAlertGui, disconnectModalDebugGeometry

    if (!fixedPointModalDebugEnabled || fixedPointModalDebugProbeRunning)
        return

    try list := WinGetList("ahk_exe RobloxPlayerBeta.exe")
    catch
        return

    excludeAlertHwnd := 0
    try {
        if (IsObject(disconnectAlertGui) && disconnectAlertGui.Hwnd)
            excludeAlertHwnd := disconnectAlertGui.Hwnd
    } catch {
        excludeAlertHwnd := 0
    }

    ; A confirmed F6 modal owns the diagnostic target until reconnect starts or
    ; the user dismisses/inspects the alert. Do not switch to another Roblox
    ; window merely because foreground selection changed.
    probeOnlyHwnd := fixedPointModalDebugPinned && fixedPointModalDebugPinnedHwnd
        && WinExist("ahk_id " . fixedPointModalDebugPinnedHwnd)
        ? fixedPointModalDebugPinnedHwnd : 0

    ; Do not erase a confirmed marker frame. Transient probe points still expire
    ; independently after 500 ms.
    if (!fixedPointModalDebugPinned)
        Macro_HideFixedPointModalMarkers()

    fixedPointModalDebugProbeRunning := true
    successfulHwnd := 0
    successfulGeometry := ""
    successfulDiag := Map()
    lastProbeHwnd := 0
    lastProbeDiag := Map()
    firstVisibleHwnd := 0
    try {
        scanList := []
        if (probeOnlyHwnd)
            scanList.Push(probeOnlyHwnd)
        else
            scanList := list

        for hwnd in scanList {
            if (!WinExist("ahk_id " . hwnd))
                continue
            try {
                if (WinGetMinMax("ahk_id " . hwnd) = -1)
                    continue
                WinGetPos(&x, &y, &w, &h, "ahk_id " . hwnd)
            } catch {
                continue
            }
            if (w < 1 || h < 1
                || Macro_IsRobloxActuallyOccluded(hwnd, x, y, w, h, excludeAlertHwnd))
                continue

            if (!firstVisibleHwnd)
                firstVisibleHwnd := hwnd
            lastProbeHwnd := hwnd
            fixedPointModalDebugProbeBusyHwnd := hwnd
            try {
                result := Macro_FindReconnectButton(hwnd, &buttonX, &buttonY, true, true)
                lastProbeDiag := Macro_CaptureFixedPointModalDiagSnapshot()
                if (result) {
                    successfulHwnd := hwnd
                    successfulGeometry := disconnectModalDebugGeometry
                    successfulDiag := lastProbeDiag
                    ; The first confirmed modal is the priority result. Do not
                    ; let another Roblox client overwrite it in the same sweep.
                    break
                }
            } catch {
            }
            fixedPointModalDebugProbeBusyHwnd := 0
        }
    } finally {
        fixedPointModalDebugProbeBusyHwnd := 0
        fixedPointModalDebugProbeRunning := false
    }

    if (successfulHwnd) {
        fixedPointModalDebugTargetHwnd := successfulHwnd
        fixedPointModalDebugPinned := true
        fixedPointModalDebugPinnedHwnd := successfulHwnd
        fixedPointModalDebugLastHwnd := successfulHwnd
        fixedPointModalDebugPinnedResult := successfulDiag
        fixedPointModalDebugLastConfirmedResult := successfulDiag
        if (IsObject(successfulGeometry))
            disconnectModalDebugGeometry := successfulGeometry
        Macro_RestoreFixedPointModalDiagSnapshot(successfulDiag)
        ; Final confirmed markers are intentionally pinned until the reconnect
        ; button is processed. This is the only place F6 turns 500 ms probes into
        ; persistent markers.
        Macro_HideFixedPointModalMarkers()
        Macro_ShowFixedPointModalMarkers(successfulHwnd)
        Macro_StartF6ModalReconnectCountdown(successfulHwnd)
    } else if (fixedPointModalDebugPinned && fixedPointModalDebugPinnedHwnd
        && WinExist("ahk_id " . fixedPointModalDebugPinnedHwnd)) {
        ; A failed refresh must never erase the last confirmed modal result.
        Macro_RestoreFixedPointModalDiagSnapshot(fixedPointModalDebugPinnedResult)
        fixedPointModalDebugTargetHwnd := fixedPointModalDebugPinnedHwnd
        fixedPointModalDebugLastHwnd := fixedPointModalDebugPinnedHwnd
        Macro_HideFixedPointModalMarkers()
        Macro_ShowFixedPointModalMarkers(fixedPointModalDebugPinnedHwnd)
    } else {
        fixedPointModalDebugPinned := false
        fixedPointModalDebugPinnedHwnd := 0
        fixedPointModalDebugPinnedResult := Map()
        if (lastProbeHwnd) {
            fixedPointModalDebugTargetHwnd := lastProbeHwnd
            Macro_RestoreFixedPointModalDiagSnapshot(lastProbeDiag)
        } else if (!fixedPointModalDebugTargetHwnd || !WinExist("ahk_id " . fixedPointModalDebugTargetHwnd)) {
            fixedPointModalDebugTargetHwnd := firstVisibleHwnd
        }
    }

    ; The diagnostic text is committed once, only after the complete fast probe
    ; has finished. Gate/Button/Outside therefore belong to the same inspection
    ; frame and cannot be mixed with a later automatic scan.
    Macro_UpdateFixedPointModalDebugText()

    ; F6 screen inspection is a strict 5-second recurring check. The elapsed time
    ; shown above is only the duration of the completed inspection; it never
    ; becomes the next inspection interval.
    if (fixedPointModalDebugEnabled)
        SetTimer(Macro_FixedPointModalDebugProbeTick, 5000)
}

Macro_RunFixedPointModalDebugProbe(hwnd) {
    global fixedPointModalDebugEnabled, fixedPointModalDebugProbeRunning
    global fixedPointModalDebugProbeBusyHwnd

    if (!fixedPointModalDebugEnabled || !hwnd || !WinExist("ahk_id " . hwnd)
        || fixedPointModalDebugProbeRunning)
        return -1

    ; F6 uses the same detector and marker lifecycle as automatic inspection.
    ; Clear the previous frame first so failed probes cannot leave old points.
    Macro_HideFixedPointModalMarkers()
    fixedPointModalDebugProbeRunning := true
    fixedPointModalDebugProbeBusyHwnd := hwnd
    try {
        result := Macro_ProbeReconnectDialog(hwnd, false, true, true)
    } catch {
        result := -1
    } finally {
        fixedPointModalDebugProbeRunning := false
        fixedPointModalDebugProbeBusyHwnd := 0
    }

    Macro_UpdateFixedPointModalDebugText()
    return result
}

Macro_QueueFixedPointModalDebugRefresh(hwnd := 0, restoreAlert := false, runProbe := false) {
    global fixedPointModalDebugEnabled, fixedPointModalDebugTargetHwnd
    global fixedPointModalDebugRefreshPending
    global fixedPointModalDebugRefreshNeedsProbe
    global fixedPointModalDebugRefreshNeedsAlert
    global fixedPointModalDebugRefreshRunning
    global fixedPointModalDebugProbeTargetHwnd
    global fixedPointModalDebugAlertTargetHwnd, fixedPointModalDebugAlertDeadline

    if (!fixedPointModalDebugEnabled)
        return

    fixedPointModalDebugTargetHwnd := hwnd
    if (runProbe && hwnd) {
        fixedPointModalDebugRefreshNeedsProbe := true
        fixedPointModalDebugProbeTargetHwnd := hwnd
    }
    if (restoreAlert && hwnd) {
        fixedPointModalDebugRefreshNeedsAlert := true
        fixedPointModalDebugAlertTargetHwnd := hwnd
        fixedPointModalDebugAlertDeadline := A_TickCount + 2000
    }
    if ((restoreAlert || runProbe) && hwnd)
        fixedPointModalDebugAlertDeadline := A_TickCount + 2000

    ; Coalesce overlay refresh events. F6's fixed 5-second probe timer owns
    ; targeted pixel inspection, while the regular watchdog handles automation.
    if (fixedPointModalDebugRefreshPending)
        return

    fixedPointModalDebugRefreshPending := true
    if (fixedPointModalDebugRefreshRunning)
        return
    delay := 50
    SetTimer(Macro_RunFixedPointModalDebugRefresh, -delay)
}

Macro_RunFixedPointModalDebugRefresh() {
    global fixedPointModalDebugEnabled, fixedPointModalDebugTargetHwnd
    global fixedPointModalDebugRefreshPending
    global fixedPointModalDebugRefreshNeedsProbe
    global fixedPointModalDebugRefreshNeedsAlert
    global fixedPointModalDebugRefreshRunning
    global fixedPointModalDebugProbeTargetHwnd
    global fixedPointModalDebugAlertTargetHwnd, fixedPointModalDebugAlertDeadline
    global disconnectAlertGui, disconnectAlertActive

    fixedPointModalDebugRefreshPending := false
    if (!fixedPointModalDebugEnabled) {
        fixedPointModalDebugRefreshNeedsProbe := false
        fixedPointModalDebugRefreshNeedsAlert := false
        fixedPointModalDebugProbeTargetHwnd := 0
        return
    }
    if (fixedPointModalDebugRefreshRunning)
        return

    fixedPointModalDebugRefreshRunning := true
    try {
        hwnd := fixedPointModalDebugTargetHwnd
        runProbe := fixedPointModalDebugRefreshNeedsProbe
        fixedPointModalDebugRefreshNeedsProbe := false
        restoreAlert := fixedPointModalDebugRefreshNeedsAlert
        fixedPointModalDebugRefreshNeedsAlert := false
        probeTargetHwnd := fixedPointModalDebugProbeTargetHwnd
        alertTargetHwnd := fixedPointModalDebugAlertTargetHwnd

        if (probeTargetHwnd)
            hwnd := probeTargetHwnd
        Macro_FixedPointModalDebugRefresh(hwnd)

        ; Run a one-shot live analysis only for F6 startup or an explicit game-row
        ; selection. Generic focus/location events update geometry only; the
        ; duration-driven probe timer owns the recurring pixel inspection.
        if (runProbe && probeTargetHwnd && WinExist("ahk_id " . probeTargetHwnd)) {
            if (WinActive("ahk_id " . probeTargetHwnd) = probeTargetHwnd) {
                Macro_RunFixedPointModalDebugProbe(probeTargetHwnd)
                fixedPointModalDebugProbeTargetHwnd := 0
                if (!restoreAlert)
                    fixedPointModalDebugAlertDeadline := 0
                Macro_UpdateFixedPointModalDebugText()
                if (disconnectAlertActive && IsObject(disconnectAlertGui))
                    Macro_ResizeDisconnectAlert()
            } else if (A_TickCount < fixedPointModalDebugAlertDeadline) {
                fixedPointModalDebugRefreshNeedsProbe := true
            } else {
                fixedPointModalDebugProbeTargetHwnd := 0
                fixedPointModalDebugAlertDeadline := 0
            }
        }

        ; Restore only after an explicit status-row selection, never for generic
        ; pointer movement, foreground changes, or Roblox window repositioning.
        ; Do the pixel probe first so raising the alert cannot steal foreground
        ; before the selected Roblox window's analysis is refreshed.
        if (restoreAlert && alertTargetHwnd && WinExist("ahk_id " . alertTargetHwnd)) {
            if (WinActive("ahk_id " . alertTargetHwnd) = alertTargetHwnd) {
                Macro_EnsureFixedPointModalDebugAlert(alertTargetHwnd)
                Macro_ResizeDisconnectAlert()
                Macro_RaiseDisconnectAlertOnUpdate()
                fixedPointModalDebugAlertTargetHwnd := 0
                fixedPointModalDebugAlertDeadline := 0
            } else if (A_TickCount < fixedPointModalDebugAlertDeadline) {
                ; Row activation is queued after mouse-up; wait briefly for
                ; Roblox to become foreground before consuming the show request.
                fixedPointModalDebugRefreshNeedsAlert := true
            } else {
                fixedPointModalDebugAlertTargetHwnd := 0
                fixedPointModalDebugAlertDeadline := 0
            }
        }
    } finally {
        fixedPointModalDebugRefreshRunning := false
        if (fixedPointModalDebugRefreshPending || fixedPointModalDebugRefreshNeedsProbe
            || fixedPointModalDebugRefreshNeedsAlert) {
            fixedPointModalDebugRefreshPending := true
            SetTimer(Macro_RunFixedPointModalDebugRefresh, -150)
        }
    }
}

Macro_FixedPointModalWinEventProc(hWinEventHook, event, hwnd, idObject, idChild, idEventThread, dwmsEventTime) {
    global fixedPointModalDebugEnabled, fixedPointModalDebugTargetHwnd
    global fixedPointModalDebugPinned, fixedPointModalDebugPinnedHwnd

    if (!fixedPointModalDebugEnabled)
        return

    ; Foreground event.
    if (event = 0x0003) {
        ; A confirmed modal stays the priority target even when the user switches
        ; Roblox clients or moves focus to another application.
        if (fixedPointModalDebugPinned && fixedPointModalDebugPinnedHwnd)
            return
        try {
            if (hwnd && WinGetProcessName("ahk_id " . hwnd) = "RobloxPlayerBeta.exe") {
                fixedPointModalDebugTargetHwnd := hwnd
                Macro_QueueFixedPointModalDebugRefresh(hwnd)
            } else {
                fixedPointModalDebugTargetHwnd := 0
                Macro_QueueFixedPointModalDebugRefresh(0)
            }
        } catch {
            fixedPointModalDebugTargetHwnd := 0
            Macro_QueueFixedPointModalDebugRefresh(0)
        }
        return
    }

    ; Object location-change event: only top-level windows.
    if (event = 0x800B && idObject = 0 && idChild = 0) {
        if (hwnd = fixedPointModalDebugTargetHwnd
            || (fixedPointModalDebugPinned && hwnd = fixedPointModalDebugPinnedHwnd))
            Macro_QueueFixedPointModalDebugRefresh(hwnd)
    }
}

Macro_StopFixedPointModalDebugHooks() {
    global fixedPointModalDebugForegroundHook, fixedPointModalDebugLocationHook
    global fixedPointModalDebugEventCallback, fixedPointModalDebugTargetHwnd

    try {
        if (fixedPointModalDebugForegroundHook)
            DllCall("user32\UnhookWinEvent", "Ptr", fixedPointModalDebugForegroundHook)
    } catch {
    }
    try {
        if (fixedPointModalDebugLocationHook)
            DllCall("user32\UnhookWinEvent", "Ptr", fixedPointModalDebugLocationHook)
    } catch {
    }

    fixedPointModalDebugForegroundHook := 0
    fixedPointModalDebugLocationHook := 0

    try {
        if (fixedPointModalDebugEventCallback)
            CallbackFree(fixedPointModalDebugEventCallback)
    } catch {
    }
    fixedPointModalDebugEventCallback := 0
    fixedPointModalDebugTargetHwnd := 0
}

Macro_GetCurrentSelectedRobloxHwnd() {
    global gameStatusTrackedHwnd, gameStatusLastActiveRobloxHwnd

    try {
        active := WinActive("ahk_exe RobloxPlayerBeta.exe")
        if (active && WinExist("ahk_id " . active))
            return active
    } catch {
    }
    if (gameStatusTrackedHwnd && WinExist("ahk_id " . gameStatusTrackedHwnd))
        return gameStatusTrackedHwnd
    if (gameStatusLastActiveRobloxHwnd && WinExist("ahk_id " . gameStatusLastActiveRobloxHwnd))
        return gameStatusLastActiveRobloxHwnd
    return 0
}

Macro_GetFixedPointModalStoredDiagText(snapshot := "") {
    if (!IsObject(snapshot) || !snapshot.Has("screenValid"))
        return ""

    gateText := snapshot["screenDarkCount"] . "/" . snapshot["screenDarkTotal"]
    buttonText := snapshot["buttonValid"] ? snapshot["buttonWhiteCount"] . "/" . snapshot["buttonWhiteTotal"] : "- /" . snapshot["buttonWhiteTotal"]
    outsideText := snapshot["precisionDifferentCount"] . "/" . snapshot["precisionDifferentTotal"]
    return "Gate " . gateText . " | Button " . buttonText . " | Outside " . outsideText
        . " | " . snapshot["scaleAttempts"] . " scales / " . snapshot["readCount"] . " reads / " . snapshot["elapsedMs"] . " ms"
}

Macro_UpdateFixedPointModalDebugText() {
    global fixedPointModalDebugEnabled, fixedPointModalDebugTargetHwnd
    global fixedPointModalDebugPinned, fixedPointModalDebugPinnedHwnd, fixedPointModalDebugPinnedResult
    global fixedPointModalDebugLastConfirmedResult
    global disconnectAlertF6Diag, disconnectAlertGui, disconnectAlertStage

    if (!fixedPointModalDebugEnabled)
        return
    if (!IsObject(disconnectAlertF6Diag))
        return

    snapshot := fixedPointModalDebugPinned ? fixedPointModalDebugPinnedResult : fixedPointModalDebugLastConfirmedResult
    if (!IsObject(snapshot) || !snapshot.Has("screenValid"))
        snapshot := Macro_CaptureFixedPointModalDiagSnapshot()

    if (snapshot["screenPassed"] && snapshot["buttonPassed"] && snapshot["precisionPassed"])
        status := "PASS"
    else if (snapshot["screenPassed"])
        status := "REFINE"
    else
        status := "SEARCH"

    scaleText := Round(snapshot["scale"] * 100) . "%"
    buttonText := snapshot["buttonValid"] ? snapshot["buttonWhiteCount"] . "/" . snapshot["buttonWhiteTotal"] : "- /" . snapshot["buttonWhiteTotal"]
    outsideText := snapshot["precisionDifferentCount"] . "/" . snapshot["precisionDifferentTotal"]

    targetGameHwnd := fixedPointModalDebugPinned
        ? fixedPointModalDebugPinnedHwnd : fixedPointModalDebugTargetHwnd
    if (!targetGameHwnd && IsObject(snapshot["geometry"]))
        targetGameHwnd := snapshot["geometry"]["hwnd"]

    gameName := Macro_GetRobloxGameNameForHwnd(targetGameHwnd)
    if (targetGameHwnd && gameName = "") {
        Macro_EnsureGameIdentityCached(targetGameHwnd)
        gameName := Macro_GetRobloxGameNameForHwnd(targetGameHwnd)
    }
    if (targetGameHwnd && gameName = "")
        gameName := "Checking..."
    gameLine := (gameName != "")
        ? Macro_GetDisconnectUIText("gameName") . ": " . gameName . "`n"
        : ""

    text := "F6 MODAL [" . status . "]  Scale " . scaleText . "`n"
        . "Gate " . snapshot["screenDarkCount"] . "/" . snapshot["screenDarkTotal"]
        . " | Button " . buttonText
        . " | Outside " . outsideText . " | " . snapshot["scaleAttempts"] . " scales / "
        . snapshot["readCount"] . " reads / " . snapshot["elapsedMs"] . " ms`n"
        . gameLine

    geometry := snapshot["geometry"]
    if (IsObject(geometry)) {
        modeText := geometry["measured"] ? "Measured" : "Preview"
        clickPoint := geometry["clickPoint"]
        text .= modeText . " " . geometry["width"] . "x" . geometry["height"]
            . " | Click " . clickPoint[1] . "," . clickPoint[2]
    } else {
        text .= "Waiting for a Roblox client"
    }

    try {
        disconnectAlertF6Diag.Text := text
        disconnectAlertF6Diag.Visible := true
    } catch {
    }
}






; =====================================================================
; Mouse hold / rapid-click feature imported from Heroes_Mouse_hold_Rapid_Click_fixed_v2.
; F1 termination and global runtime-setting changes are intentionally omitted.
; =====================================================================
MouseMacro_Initialize() {
    global mouseMacroIndicatorGui, mouseMacroPrevX, mouseMacroPrevY

    mouseMacroIndicatorGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
    mouseMacroIndicatorGui.BackColor := "66FF66"
    mouseMacroIndicatorGui.Show("x-32000 y-32000 w4 h4 NA")
    mouseMacroIndicatorGui.Hide()

    CoordMode("Mouse", "Screen")
    MouseGetPos(&mouseMacroPrevX, &mouseMacroPrevY)
    ; Track cursor position more often; rapid-click flashes are also refreshed
    ; directly by each click in MouseMacro_RapidClickLoop().
    SetTimer(MouseMacro_UpdateIndicator, 30)
    SetTimer(MouseMacro_CheckMouse, 0)
}

MouseMacro_CloseIndicator(*) {
    global mouseMacroIndicatorGui
    SetTimer(MouseMacro_UpdateIndicator, 0)
    SetTimer(MouseMacro_CheckMouse, 0)
    SetTimer(MouseMacro_RapidClickLoop, 0)
    SetTimer(MouseMacro_ApplyRapidInterval, 0)
    MouseMacro_StopRapidIntervalHold()
    try {
        if (IsObject(mouseMacroIndicatorGui) && mouseMacroIndicatorGui.Hwnd)
            mouseMacroIndicatorGui.Destroy()
    } catch {
    }
    mouseMacroIndicatorGui := ""
}

MouseMacro_ToggleMaster(*) {
    global mouseMacroMasterOn, mouseMacroActive, mouseMacroSuspendedByWindow

    ; F6 diagnostics are independent. Disconnect/recovery turns the macro
    ; master OFF through MouseMacro_ForceOffForDisconnect(), without disabling F6.
    if (mouseMacroMasterOn) {
        mouseMacroMasterOn := false
        MouseMacro_Stop()
        MouseMacro_ShowTrayTip(false)
        return
    }

    mouseMacroMasterOn := true
    if (MouseMacro_IsRobloxActive()) {
        mouseMacroActive := true
        mouseMacroSuspendedByWindow := false
        MouseMacro_StartPhysics()
    }
    MouseMacro_ShowTrayTip(true)
}

MouseMacro_ForceOffForDisconnect(reason := "disconnect detected") {
    global mouseMacroMasterOn, mouseMacroActive, mouseMacroSuspendedByWindow
    global mouseMacroHeld, mouseMacroReleasing

    ; Treat disconnect/automatic inspection as a real F4 OFF. This function is
    ; idempotent and deliberately does NOT toggle F6 off: modal probes and their
    ; reconnect countdown must continue independently of the mouse macro.
    wasMasterOn := mouseMacroMasterOn
    mouseMacroMasterOn := false

    try {
        MouseMacro_Stop()
    } catch {
        ; A macro cleanup problem must never abort disconnect alert/modal handling.
        mouseMacroActive := false
        mouseMacroSuspendedByWindow := false
        mouseMacroReleasing := true
        try SetTimer(MouseMacro_RapidClickLoop, 0)
        try SetTimer(MouseMacro_CheckMouse, 0)
        if (mouseMacroHeld && !GetKeyState("LButton", "P")) {
            try Send("{LButton up}")
            mouseMacroHeld := false
        }
    }

    if (wasMasterOn) {
        try MouseMacro_ShowTrayTip(false, reason)
    }
    return wasMasterOn
}

MouseMacro_ShowTrayTip(isOn, reason := "") {
    global mouseMacroActive

    isKorean := (Macro_GetWindowsUILanguage() = "ko")
    if (isOn) {
        if (mouseMacroActive)
            message := isKorean ? "마우스 매크로 ON" : "Mouse macro ON"
        else
            message := isKorean ? "마우스 매크로 ON · Roblox 안에서 가운데 버튼으로 시작" : "Mouse macro ON · Click the middle button in Roblox to start"
    } else if (reason != "") {
        message := isKorean ? "연결 끊김 감지 · 마우스 매크로 OFF" : "Disconnect detected · Mouse macro OFF"
    } else {
        message := isKorean ? "마우스 매크로 OFF" : "Mouse macro OFF"
    }
    TrayTip(message, isKorean ? "🖱️ 마우스 매크로" : "🖱️ Mouse macro", 1)
}

MouseMacro_RapidIntervalPhysicalDown(*) {
    global shortcutHelpRapidDecreaseHwnd, shortcutHelpRapidIncreaseHwnd
    global mouseMacroRapidIntervalHoldDirection, mouseMacroRapidIntervalHoldHwnd
    global mouseMacroRapidIntervalClickHandledHwnd

    if (!GetKeyState("LButton", "P"))
        return

    mouseMacroRapidIntervalClickHandledHwnd := 0
    MouseGetPos(,,, &underMouseHwnd, 2)

    direction := 0
    if (underMouseHwnd = shortcutHelpRapidDecreaseHwnd)
        direction := -10
    else if (underMouseHwnd = shortcutHelpRapidIncreaseHwnd)
        direction := 10
    else
        return

    mouseMacroRapidIntervalHoldDirection := direction
    mouseMacroRapidIntervalHoldHwnd := underMouseHwnd
    mouseMacroRapidIntervalClickHandledHwnd := underMouseHwnd
    if (MouseMacro_AdjustRapidInterval(direction))
        SetTimer(MouseMacro_RapidIntervalHoldTick, -400)
}

MouseMacro_RapidIntervalPhysicalUp(*) {
    global mouseMacroRapidIntervalHoldDirection

    if (mouseMacroRapidIntervalHoldDirection)
        MouseMacro_StopRapidIntervalHold()
}

MouseMacro_AdjustRapidIntervalFromClick(delta, ctrl, *) {
    global mouseMacroRapidIntervalClickHandledHwnd

    try
        ctrlHwnd := ctrl.Hwnd
    catch
        ctrlHwnd := 0

    if (ctrlHwnd && ctrlHwnd = mouseMacroRapidIntervalClickHandledHwnd) {
        mouseMacroRapidIntervalClickHandledHwnd := 0
        return
    }

    MouseMacro_AdjustRapidInterval(delta)
}

MouseMacro_RapidIntervalHoldTick(*) {
    global mouseMacroRapidIntervalHoldDirection, mouseMacroRapidIntervalHoldHwnd

    if (!mouseMacroRapidIntervalHoldDirection)
        return
    if (!GetKeyState("LButton", "P")
        || !mouseMacroRapidIntervalHoldHwnd
        || !DllCall("user32\IsWindow", "Ptr", mouseMacroRapidIntervalHoldHwnd)) {
        MouseMacro_StopRapidIntervalHold()
        return
    }

    MouseGetPos(,,, &underMouseHwnd, 2)
    if (underMouseHwnd != mouseMacroRapidIntervalHoldHwnd) {
        MouseMacro_StopRapidIntervalHold()
        return
    }

    if (!MouseMacro_AdjustRapidInterval(mouseMacroRapidIntervalHoldDirection)) {
        MouseMacro_StopRapidIntervalHold()
        return
    }
    SetTimer(MouseMacro_RapidIntervalHoldTick, -100)
}

MouseMacro_StopRapidIntervalHold() {
    global mouseMacroRapidIntervalHoldDirection, mouseMacroRapidIntervalHoldHwnd

    mouseMacroRapidIntervalHoldDirection := 0
    mouseMacroRapidIntervalHoldHwnd := 0
    SetTimer(MouseMacro_RapidIntervalHoldTick, 0)
}

MouseMacro_AdjustRapidInterval(delta, ctrl := "", *) {
    global mouseMacroRapidIntervalMs

    newInterval := Min(1000, Max(10, mouseMacroRapidIntervalMs + delta))
    if (newInterval = mouseMacroRapidIntervalMs)
        return false

    mouseMacroRapidIntervalMs := newInterval
    Macro_UpdateShortcutHelpRapidIntervalControl(true)
    ; Coalesce rapid input: apply only after the user pauses for 80 ms.
    SetTimer(MouseMacro_ApplyRapidInterval, -80)
    return true
}

MouseMacro_ApplyRapidInterval(*) {
    global mouseMacroRapidIntervalMs, mouseMacroMasterOn, mouseMacroActive
    global mouseMacroMode, mouseMacroSuspendedByWindow, mouseMacroReleasing

    if (mouseMacroMasterOn && mouseMacroActive && mouseMacroMode = "RAPID"
        && !mouseMacroSuspendedByWindow && !mouseMacroReleasing)
        SetTimer(MouseMacro_RapidClickLoop, mouseMacroRapidIntervalMs)
}

MouseMacro_ToggleMode(*) {
    global mouseMacroMode, mouseMacroActive

    if (mouseMacroActive)
        MouseMacro_Stop()

    mouseMacroMode := (mouseMacroMode = "HOLD") ? "RAPID" : "HOLD"
    ; Update the Help F3 mode pill immediately for both keyboard and GUI clicks.
    Macro_UpdateShortcutHelpModeButton(true)
}

MouseMacro_ToggleActive(*) {
    global mouseMacroActive, mouseMacroSuspendedByWindow

    if (mouseMacroActive) {
        MouseMacro_Stop()
        return
    }

    mouseMacroActive := true
    mouseMacroSuspendedByWindow := false
    MouseMacro_StartPhysics()
}

MouseMacro_PhysicalLButton(*) {
    global mouseMacroMasterOn, mouseMacroActive, mouseMacroSuspendedByWindow
    global mouseMacroMode, mouseMacroHeld, mouseMacroReleasing

    ; Give the game selector priority over the HOLD click hook. This check runs
    ; before the hook can reassert a synthetic LButton-down during a selector click.
    if (GetKeyState("LButton", "P") && MouseMacro_IsGameStatusGameRowUnderMouse()) {
        if (mouseMacroActive)
            MouseMacro_Stop()
        return
    }

    ; If shutdown/pause happened during a physical hold, release our synthetic
    ; down only after the user's physical button is up.
    if (mouseMacroReleasing) {
        if (mouseMacroHeld && !GetKeyState("LButton", "P")) {
            Send("{LButton up}")
            mouseMacroHeld := false
        }
        return
    }

    if (!mouseMacroMasterOn || !mouseMacroActive || mouseMacroSuspendedByWindow
        || mouseMacroMode != "HOLD" || MouseMacro_RecoveryBlocksInput())
        return

    Sleep(10)
    if (mouseMacroReleasing || !mouseMacroMasterOn || !mouseMacroActive
        || mouseMacroSuspendedByWindow || MouseMacro_RecoveryBlocksInput())
        return

    Send("{LButton down}")
    mouseMacroHeld := true
}

MouseMacro_IsGameStatusGameRowUnderMouse() {
    global gameStatusGui, gameStatusVisible, gameStatusRowTargets

    if (!gameStatusVisible || !IsObject(gameStatusGui) || !gameStatusGui.Hwnd
        || !DllCall("user32\IsWindowVisible", "Ptr", gameStatusGui.Hwnd))
        return false

    try {
        MouseGetPos(&mouseX, &mouseY, , &controlHwnd, 2)
        WinGetPos(&guiX, &guiY, &guiW, &guiH, "ahk_id " . gameStatusGui.Hwnd)
        if (mouseX < guiX || mouseX >= guiX + guiW
            || mouseY < guiY || mouseY >= guiY + guiH)
            return false

        targetRow := Macro_GetGameStatusHoverTarget(controlHwnd)
        if (targetRow <= 0 || targetRow > gameStatusRowTargets.Length)
            return false

        targetHwnd := gameStatusRowTargets[targetRow]
        return (targetHwnd && WinExist("ahk_id " . targetHwnd)) ? true : false
    } catch {
        return false
    }
}

MouseMacro_RapidClickLoop() {
    global mouseMacroMasterOn, mouseMacroActive, mouseMacroMode
    global mouseMacroSuspendedByWindow, mouseMacroRapidToggle, mouseMacroReleasing

    if (mouseMacroReleasing || !mouseMacroMasterOn || !mouseMacroActive
        || mouseMacroSuspendedByWindow || mouseMacroMode != "RAPID")
        return

    if (MouseMacro_RecoveryBlocksInput() || !MouseMacro_IsMouseInsideRoblox()) {
        mouseMacroSuspendedByWindow := true
        MouseMacro_SuspendPhysics()
        return
    }

    Click()
    mouseMacroRapidToggle := !mouseMacroRapidToggle
    ; Make each color phase follow the actual click interval, even when it is
    ; shorter than the cursor-position timer.
    MouseMacro_UpdateIndicator()
}

MouseMacro_StartPhysics() {
    global mouseMacroMasterOn, mouseMacroActive, mouseMacroMode
    global mouseMacroHeld, mouseMacroIdleCounter, mouseMacroResetCounter
    global mouseMacroPrevX, mouseMacroPrevY, mouseMacroRapidToggle, mouseMacroReleasing
    global mouseMacroSuspendedByWindow, mouseMacroRapidIntervalMs

    mouseMacroReleasing := false
    if (!mouseMacroMasterOn || !mouseMacroActive) {
        SetTimer(MouseMacro_CheckMouse, 0)
        return
    }
    SetTimer(MouseMacro_CheckMouse, 30)

    if (MouseMacro_RecoveryBlocksInput()) {
        mouseMacroSuspendedByWindow := true
        MouseMacro_SuspendPhysics()
        return
    }

    if (mouseMacroMode = "HOLD") {
        if (!mouseMacroHeld) {
            Send("{LButton down}")
            mouseMacroHeld := true
        }
    } else {
        mouseMacroRapidToggle := false
        SetTimer(MouseMacro_RapidClickLoop, mouseMacroRapidIntervalMs)
    }

    mouseMacroIdleCounter := 0
    mouseMacroResetCounter := 0
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mouseMacroPrevX, &mouseMacroPrevY)
}

MouseMacro_SuspendPhysics() {
    global mouseMacroHeld, mouseMacroRapidToggle, mouseMacroReleasing

    mouseMacroReleasing := true
    SetTimer(MouseMacro_RapidClickLoop, 0)
    mouseMacroRapidToggle := false

    ; Avoid releasing a physical click the user is still holding.
    if (mouseMacroHeld && !GetKeyState("LButton", "P")) {
        Send("{LButton up}")
        mouseMacroHeld := false
    }
}

MouseMacro_Stop() {
    global mouseMacroActive, mouseMacroSuspendedByWindow

    mouseMacroActive := false
    mouseMacroSuspendedByWindow := false
    MouseMacro_SuspendPhysics()
    SetTimer(MouseMacro_CheckMouse, 0)
}

MouseMacro_RecoveryBlocksInput() {
    global disconnectAlertActive, disconnectAlertReason
    global disconnectHiddenScanActive, disconnectHiddenScanPending
    global connectionRecoveryBusy, connectionRecoveryPending, logAutoRejoinBusy
    global disconnectManualCheckBusy, disconnectManualCheckPending
    global fixedPointModalDebugEnabled, fixedPointModalDebugOwnsAlert
    global fixedPointModalDebugReconnectPending

    ; F6 may create its own diagnostic-only alert. Do not treat that panel as
    ; a real disconnect alert; otherwise enabling F6 blocks HOLD/RAPID input.
    ; If a real disconnect is detected, its reason changes and/or the recovery
    ; flags below become active, so normal input blocking remains in force.
    diagnosticOnlyAlert := (fixedPointModalDebugEnabled
        && fixedPointModalDebugOwnsAlert
        && disconnectAlertReason = "F6 modal diagnostic.")

    return ((disconnectAlertActive && !diagnosticOnlyAlert)
        || disconnectHiddenScanActive || disconnectHiddenScanPending
        || connectionRecoveryBusy || connectionRecoveryPending || logAutoRejoinBusy
        || disconnectManualCheckBusy || disconnectManualCheckPending
        || fixedPointModalDebugReconnectPending)
}

MouseMacro_CheckMouse() {
    global mouseMacroMasterOn, mouseMacroActive, mouseMacroSuspendedByWindow
    global mouseMacroHeld, mouseMacroMode, mouseMacroPrevX, mouseMacroPrevY
    global mouseMacroIdleCounter, mouseMacroResetCounter, mouseMacroReleasing

    if (!mouseMacroMasterOn || !mouseMacroActive) {
        SetTimer(MouseMacro_CheckMouse, 0)
        return
    }

    if (MouseMacro_RecoveryBlocksInput()) {
        if (mouseMacroActive && !mouseMacroSuspendedByWindow) {
            mouseMacroSuspendedByWindow := true
            MouseMacro_SuspendPhysics()
        }
        return
    }

    targetHwnd := WinExist("ahk_exe RobloxPlayerBeta.exe")
    if (!targetHwnd) {
        if (mouseMacroActive)
            MouseMacro_Stop()
        return
    }

    CoordMode("Mouse", "Screen")
    MouseGetPos(&screenX, &screenY, &mouseHwnd)
    if (!mouseHwnd || !IsInteger(mouseHwnd))
        return

    try mouseRootHwnd := DllCall("user32\GetAncestor", "Ptr", mouseHwnd, "UInt", 2, "Ptr")
    catch
        return

    isFullscreen := MouseMacro_IsRobloxFullscreen(targetHwnd)
    isInValidArea := false
    if (mouseRootHwnd = targetHwnd) {
        if (isFullscreen) {
            monitorNum := MouseMacro_GetMonitorFromWindow(targetHwnd)
            if (monitorNum > 0) {
                try {
                    MonitorGet(monitorNum, &monitorLeft, &monitorTop, &monitorRight, &monitorBottom)
                    isInValidArea := (screenX >= monitorLeft && screenX < monitorRight
                        && screenY >= monitorTop && screenY < monitorBottom)
                } catch {
                    isInValidArea := false
                }
            }
        } else {
            try {
                pointLParam := (screenX & 0xFFFF) | ((screenY & 0xFFFF) << 16)
                hitTest := DllCall("user32\SendMessageW", "Ptr", targetHwnd, "UInt", 0x0084
                    , "Ptr", 0, "Ptr", pointLParam, "Ptr")
                isInValidArea := (hitTest = 1)
                if (isInValidArea) {
                    WinGetClientPos(&clientLeft, &clientTop, &clientWidth, &clientHeight, "ahk_id " . targetHwnd)
                    isInValidArea := (screenX >= clientLeft && screenX < clientLeft + clientWidth
                        && screenY >= clientTop && screenY < clientTop + clientHeight)
                }
            } catch {
                isInValidArea := false
            }
        }
    }

    if (mouseMacroActive) {
        if (!isInValidArea) {
            if (!mouseMacroSuspendedByWindow) {
                mouseMacroSuspendedByWindow := true
                MouseMacro_SuspendPhysics()
            }
        } else if (mouseMacroSuspendedByWindow) {
            mouseMacroSuspendedByWindow := false
            mouseMacroReleasing := false
            if (mouseMacroMode = "HOLD") {
                if (!WinActive("ahk_id " . targetHwnd))
                    WinActivate("ahk_id " . targetHwnd)
                Sleep(200)
                if (MouseMacro_RecoveryBlocksInput()) {
                    mouseMacroSuspendedByWindow := true
                    MouseMacro_SuspendPhysics()
                    return
                }
                Send("{LButton up}")
                Sleep(20)
                Send("{LButton down}")
                mouseMacroHeld := true
            } else {
                MouseMacro_StartPhysics()
            }
        }
    }

    if (mouseMacroActive && !mouseMacroSuspendedByWindow && mouseMacroMode = "HOLD") {
        MouseGetPos(&currX, &currY)
        if (mouseMacroPrevX != currX || mouseMacroPrevY != currY) {
            mouseMacroIdleCounter := 0
            mouseMacroResetCounter := 0
            mouseMacroPrevX := currX
            mouseMacroPrevY := currY
            return
        }

        if (!mouseMacroHeld) {
            mouseMacroIdleCounter++
            if (mouseMacroIdleCounter >= 5) {
                Send("{LButton down}")
                mouseMacroHeld := true
                mouseMacroIdleCounter := 0
                mouseMacroResetCounter := 0
            }
        } else {
            mouseMacroResetCounter++
            if (mouseMacroResetCounter >= 300) {
                mouseMacroResetCounter := 0
                mouseMacroPrevX := currX
                mouseMacroPrevY := currY
            }
        }
    }
}

MouseMacro_IsMouseInsideRoblox() {
    targetHwnd := WinExist("ahk_exe RobloxPlayerBeta.exe")
    if (!targetHwnd || !MouseMacro_IsRobloxActive())
        return false

    CoordMode("Mouse", "Screen")
    MouseGetPos(&screenX, &screenY, &mouseHwnd)
    if (!mouseHwnd || !IsInteger(mouseHwnd))
        return false

    try mouseRootHwnd := DllCall("user32\GetAncestor", "Ptr", mouseHwnd, "UInt", 2, "Ptr")
    catch
        return false
    if (mouseRootHwnd != targetHwnd)
        return false

    if (MouseMacro_IsRobloxFullscreen(targetHwnd)) {
        monitorNum := MouseMacro_GetMonitorFromWindow(targetHwnd)
        if (monitorNum <= 0)
            return false
        try {
            MonitorGet(monitorNum, &monitorLeft, &monitorTop, &monitorRight, &monitorBottom)
            return (screenX >= monitorLeft && screenX < monitorRight
                && screenY >= monitorTop && screenY < monitorBottom)
        } catch {
            return false
        }
    }

    try {
        WinGetClientPos(&clientLeft, &clientTop, &clientWidth, &clientHeight, "ahk_id " . targetHwnd)
        return (screenX >= clientLeft && screenX < clientLeft + clientWidth
            && screenY >= clientTop && screenY < clientTop + clientHeight)
    } catch {
        return false
    }
}

MouseMacro_GetMonitorFromWindow(targetHwnd) {
    try {
        WinGetPos(&winX, &winY, &winW, &winH, "ahk_id " . targetHwnd)
        centerX := winX + (winW / 2)
        centerY := winY + (winH / 2)
        Loop MonitorGetCount() {
            monitorNum := A_Index
            MonitorGet(monitorNum, &monitorLeft, &monitorTop, &monitorRight, &monitorBottom)
            if (centerX >= monitorLeft && centerX < monitorRight
                && centerY >= monitorTop && centerY < monitorBottom)
                return monitorNum
        }
    } catch {
        return 0
    }
    return 0
}

MouseMacro_IsRobloxFullscreen(targetHwnd) {
    try {
        WinGetPos(&winX, &winY, &winW, &winH, "ahk_id " . targetHwnd)
        monitorNum := MouseMacro_GetMonitorFromWindow(targetHwnd)
        if (monitorNum <= 0)
            return false
        MonitorGet(monitorNum, &monitorLeft, &monitorTop, &monitorRight, &monitorBottom)
        return (Abs(winX - monitorLeft) <= 2 && Abs(winY - monitorTop) <= 2
            && Abs(winW - (monitorRight - monitorLeft)) <= 2
            && Abs(winH - (monitorBottom - monitorTop)) <= 2)
    } catch {
        return false
    }
}

MouseMacro_IsRobloxActive() {
    return WinActive("ahk_exe RobloxPlayerBeta.exe")
}

MouseMacro_UpdateIndicator() {
    global mouseMacroMasterOn, mouseMacroActive, mouseMacroSuspendedByWindow
    global mouseMacroMode, mouseMacroIndicatorGui, mouseMacroIndicatorState, mouseMacroRapidToggle

    if (!IsObject(mouseMacroIndicatorGui) || !mouseMacroIndicatorGui.Hwnd)
        return
    if (!mouseMacroMasterOn) {
        if (mouseMacroIndicatorState != "OFF") {
            mouseMacroIndicatorState := "OFF"
            mouseMacroIndicatorGui.Hide()
        }
        return
    }

    CoordMode("Mouse", "Screen")
    MouseGetPos(&mouseX, &mouseY)
    indicatorX := mouseX + 15
    indicatorY := mouseY + 40

    if (!mouseMacroActive || mouseMacroSuspendedByWindow) {
        newState := "RELEASED"
        newColor := "66FF66"
    } else if (mouseMacroMode = "HOLD") {
        newState := "HOLDING"
        newColor := "FF0000"
    } else {
        newState := "RAPID_" . (mouseMacroRapidToggle ? "A" : "B")
        newColor := mouseMacroRapidToggle ? "FF0000" : "FF9900"
    }

    if (newState != mouseMacroIndicatorState) {
        mouseMacroIndicatorState := newState
        mouseMacroIndicatorGui.BackColor := newColor
        try WinSetTransparent(204, "ahk_id " . mouseMacroIndicatorGui.Hwnd)
    }
    mouseMacroIndicatorGui.Show("x" . indicatorX . " y" . indicatorY . " w4 h4 NA")
}
