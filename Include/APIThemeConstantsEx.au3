#include-once

; #INDEX# =======================================================================================================================
; Title .........: WinAPI Extended UDF Library for AutoIt3
; AutoIt Version : 3.3.16.1
; Description ...: Additional variables, constants and functions for the WinAPITheme.au3
; Author(s) .....: NoNameCode
; ===============================================================================================================================

; #CONSTANTS# ===================================================================================================================

; _WinAPI_GetIsImmersiveColorUsingHighContrast($IMMERSIVE_HC_CACHE_MODE)
Global Const $IHCM_USE_CACHED_VALUE = 0
Global Const $IIHCM_REFRESH = 1

; _WinAPI_SetPreferredAppMode($PREFERREDAPPMODE)

Global Const $APPMODE_DEFAULT = 0
Global Const $APPMODE_ALLOWDARK = 1
Global Const $APPMODE_FORCEDARK = 2
Global Const $APPMODE_FORCELIGHT = 3
Global Const $APPMODE_MAX = 4

; ===============================================================================================================================
