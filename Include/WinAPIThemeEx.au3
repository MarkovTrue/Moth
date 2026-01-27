#include-once
#include "APIThemeConstantsEx.au3"


; #INDEX# =======================================================================================================================
; Title .........: WinAPI Extended UDF Library for AutoIt3
; AutoIt Version : 3.3.16.1
; Description ...: Additional variables, constants and functions for the WinAPITheme.au3
; Author(s) .....: NoNameCode
; ===============================================================================================================================

#Region Global Variables and Constants

; #VARIABLES# ===================================================================================================================

; ===============================================================================================================================

; #CONSTANTS# ===================================================================================================================

; ===============================================================================================================================
#EndRegion Global Variables and Constants

#Region Functions list
; #CURRENT# =====================================================================================================================
; _WinAPI_ShouldAppsUseDarkMode
; _WinAPI_AllowDarkModeForWindow
; _WinAPI_AllowDarkModeForApp
; _WinAPI_FlushMenuThemes
; _WinAPI_RefreshImmersiveColorPolicyState
; _WinAPI_IsDarkModeAllowedForWindow
; _WinAPI_GetIsImmersiveColorUsingHighContrast
; _WinAPI_OpenNcThemeData
; ===============================================================================================================================
#EndRegion Functions list

#Region Public Functions


#cs //Auszug aus DarkMode.h (https://github.com/ysc3839/win32-darkmode/blob/master/win32-darkmode/DarkMode.h#L59)

	using fnRtlGetNtVersionNumbers = void (WINAPI *)(LPDWORD major, LPDWORD minor, LPDWORD build);
	using fnSetWindowCompositionAttribute = BOOL (WINAPI *)(HWND hWnd, WINDOWCOMPOSITIONATTRIBDATA*);

	// 1809 17763
	#using fnShouldAppsUseDarkMode = bool (WINAPI *)(); 												// ordinal 132
	#using fnAllowDarkModeForWindow = bool (WINAPI *)(HWND hWnd, bool allow); 						// ordinal 133
	#using fnAllowDarkModeForApp = bool (WINAPI *)(bool allow); 										// ordinal 135, in 1809
	#using fnFlushMenuThemes = void (WINAPI *)(); 													// ordinal 136
	#using fnRefreshImmersiveColorPolicyState = void (WINAPI *)(); 									// ordinal 104
	#using fnIsDarkModeAllowedForWindow = bool (WINAPI *)(HWND hWnd); 								// ordinal 137
	#using fnGetIsImmersiveColorUsingHighContrast = bool (WINAPI *)(IMMERSIVE_HC_CACHE_MODE mode); 	// ordinal 106
	#using fnOpenNcThemeData = HTHEME(WINAPI *)(HWND hWnd, LPCWSTR pszClassList); 					// ordinal 49

	// 1903 18362
	#using fnShouldSystemUseDarkMode = bool (WINAPI *)(); 											// ordinal 138
	#using fnSetPreferredAppMode = PreferredAppMode (WINAPI *)(PreferredAppMode appMode); 			// ordinal 135, in 1903
	using fnIsDarkModeAllowedForApp = bool (WINAPI *)(); // ordinal 13


	// Andere: https://gist.github.com/smourier/d9de36c49e19aa9923d5143965057405
	 [DllImport("uxtheme", EntryPoint = "#100")]
        static extern IntPtr GetImmersiveColorNamedTypeByIndex(int index);

#ce //Auszug aus DarkMode.h (https://github.com/ysc3839/win32-darkmode/blob/master/win32-darkmode/DarkMode.h#L59)

; #FUNCTION# ====================================================================================================================
; Name ..........: _WinAPI_ShouldAppsUseDarkMode
; Description ...: Checks if apps should use the dark mode.
; Syntax ........: _WinAPI_ShouldAppsUseDarkMode()
; Parameters ....: None
; Return values .: Success: Returns True if apps should use dark mode.
;                  Failure: Returns False and sets @error:
;                           -1: Operating system version is earlier than Windows 10 (version 1809, build 17763).
;                           Other values: DllCall error, check @error @extended for more information.
; Author ........: NoNameCode
; Modified ......:
; Remarks .......: Requires Windows 10 (version 1809, build 17763) or later.
; Related .......:
; Link ..........: http://www.opengate.at/blog/2021/08/dark-mode-win32/
; Example .......: No
; ===============================================================================================================================
Func _WinAPI_ShouldAppsUseDarkMode()
	If @OSBuild < 17763 Then Return SetError(-1, 0, False)

	Local $fnShouldAppsUseDarkMode = 132

	Local $aResult = DllCall('uxtheme.dll', 'bool', $fnShouldAppsUseDarkMode)
	If @error Then Return SetError(@error, @extended, False)

	Return $aResult[0]
EndFunc   ;==>_WinAPI_ShouldAppsUseDarkMode

; #FUNCTION# ====================================================================================================================
; Name ..........: _WinAPI_AllowDarkModeForWindow
; Description ...: Allows or disallows dark mode for a specific window handle.
; Syntax ........: _WinAPI_AllowDarkModeForWindow($hWnd, $bAllow = True)
; Parameters ....: $hWnd    - Handle to the window.
;                  $bAllow  - [optional] If True, allows dark mode; if False, disallows dark mode. Default is True.
; Return values .: Success: Returns True if the operation succeeded.
;                  Failure: Returns False and sets @error:
;                           -1: Operating system version is earlier than Windows 10 (version 1809, build 17763).
;                           Other values: DllCall error, check @error @extended for more information.
; Author ........: NoNameCode
; Modified ......:
; Remarks .......: Requires Windows 10 (version 1809, build 17763) or later.
; Related .......:
; Link ..........: http://www.opengate.at/blog/2021/08/dark-mode-win32/
; Example .......: No
; ===============================================================================================================================
Func _WinAPI_AllowDarkModeForWindow($hWnd, $bAllow = True)
	If @OSBuild < 17763 Then Return SetError(-1, 0, False)

	Local $fnAllowDarkModeForWindow = 133

	Local $aResult = DllCall('uxtheme.dll', 'bool', $fnAllowDarkModeForWindow, 'hwnd', $hWnd, 'bool', $bAllow)
	If @error Then Return SetError(@error, @extended, False)

	Return $aResult[0]
EndFunc   ;==>_WinAPI_AllowDarkModeForWindow

; #FUNCTION# ====================================================================================================================
; Name ..........: _WinAPI_AllowDarkModeForApp
; Description ...: Allows or disallows dark mode for the entire application.
; Syntax ........: _WinAPI_AllowDarkModeForApp($bAllow = True)
; Parameters ....: $bAllow  - [optional] If True, allows dark mode for the application; if False, disallows dark mode. Default is True.
; Return values .: Success: Returns True if the operation succeeded.
;                  Failure: Returns False and sets @error:
;                           -1: Operating system version is earlier than Windows 10 (version 1809, build 17763).
;                           -2: Operating system version is later than or equal to Windows 10 (version 1903, build 18362). (Use _WinAPI_SetPreferredAppMode instat!)
;                           Other values: DllCall error, check @error @extended for more information.
; Author ........: NoNameCode
; Modified ......:
; Remarks .......: Requires Windows 10 (version 1809, build 17763) and earlier than Windows 10 (version 1903, build 18362).
; Related .......: _WinAPI_SetPreferredAppMode
; Link ..........: http://www.opengate.at/blog/2021/08/dark-mode-win32/
; Example .......: No
; ===============================================================================================================================
Func _WinAPI_AllowDarkModeForApp($bAllow = True)
	If @OSBuild < 17763 Then Return SetError(-1, 0, False)
	If @OSBuild >= 18362 Then Return SetError(-2, 0, False)

	Local $fnAllowDarkModeForApp = 135

	Local $aResult = DllCall('uxtheme.dll', 'bool', $fnAllowDarkModeForApp, 'bool', $bAllow)
	If @error Then Return SetError(@error, @extended, False)

	Return $aResult[0]
EndFunc   ;==>_WinAPI_AllowDarkModeForApp

; #FUNCTION# ====================================================================================================================
; Name ..........: _WinAPI_FlushMenuThemes
; Description ...: Refreshes the system's immersive color policy state, allowing changes to take effect.
; Syntax ........: _WinAPI_FlushMenuThemes()
; Parameters ....: None
; Return values .: Success: True
;                  Failure: False and sets the @error flag:
;                           -1: Operating system version is earlier than Windows 10 (version 17763)
;                           Other values: DllCall error, check @error @extended for more information.
; Author ........: NoNameCode
; Modified ......:
; Remarks .......: This function is applicable for Windows 10 (version 17763) and later.
; Related .......:
; Link ..........: http://www.opengate.at/blog/2021/08/dark-mode-win32/
; Example .......: No
; ===============================================================================================================================
Func _WinAPI_FlushMenuThemes()
	If @OSBuild < 17763 Then Return SetError(-1, 0, False)

	Local $fnFlushMenuThemes = 136

	DllCall('uxtheme.dll', 'none', $fnFlushMenuThemes)
	If @error Then Return SetError(@error, @extended, False)

	Return True
EndFunc   ;==>_WinAPI_FlushMenuThemes

; #FUNCTION# ====================================================================================================================
; Name ..........: _WinAPI_RefreshImmersiveColorPolicyState
; Description ...: Refreshes the system's immersive color policy state, allowing changes to take effect.
; Syntax ........: _WinAPI_RefreshImmersiveColorPolicyState()
; Parameters ....: None
; Return values .: Success: True
;                  Failure: False and sets the @error flag:
;                           -1: Operating system version is earlier than Windows 10 (version 17763)
;                           Other values: DllCall error, check @error @extended for more information.
; Author ........: NoNameCode
; Modified ......:
; Remarks .......: This function is applicable for Windows 10 (version 17763) and later.
; Related .......:
; Link ..........: http://www.opengate.at/blog/2021/08/dark-mode-win32/
; Example .......: No
; ===============================================================================================================================
Func _WinAPI_RefreshImmersiveColorPolicyState()
	If @OSBuild < 17763 Then Return SetError(-1, 0, False)

	Local $fnRefreshImmersiveColorPolicyState = 104

	DllCall('uxtheme.dll', 'none', $fnRefreshImmersiveColorPolicyState)
	If @error Then Return SetError(@error, @extended, False)

	Return True
EndFunc   ;==>_WinAPI_RefreshImmersiveColorPolicyState

; #FUNCTION# ====================================================================================================================
; Name ..........: _WinAPI_IsDarkModeAllowedForWindow
; Description ...: Checks if the dark mode is allowed for the specified window.
; Syntax ........: _WinAPI_IsDarkModeAllowedForWindow()
; Parameters ....: None
; Return values .: Success: True if dark mode is allowed for the window, False otherwise.
;                  Failure: False and sets the @error flag:
;                           -1: Operating system version is earlier than Windows 10 (version 17763)
;                           Other values: DllCall error, check @error @extended for more information.
; Author ........: NoNameCode
; Modified ......:
; Remarks .......: This function is applicable for Windows 10 (version 17763) and later.
; Related .......:
; Link ..........: http://www.opengate.at/blog/2021/08/dark-mode-win32/
; Example .......: No
; ===============================================================================================================================
Func _WinAPI_IsDarkModeAllowedForWindow()
	If @OSBuild < 17763 Then Return SetError(-1, 0, False)

	Local $fnIsDarkModeAllowedForWindow = 137

	Local $aResult = DllCall('uxtheme.dll', 'bool', $fnIsDarkModeAllowedForWindow)
	If @error Then Return SetError(@error, @extended, False)

	Return $aResult[0]
EndFunc   ;==>_WinAPI_IsDarkModeAllowedForWindow

; #FUNCTION# ====================================================================================================================
; Name ..........: _WinAPI_GetIsImmersiveColorUsingHighContrast
; Description ...: Retrieves whether immersive color is using high contrast.
; Syntax ........: _WinAPI_GetIsImmersiveColorUsingHighContrast($IMMERSIVE_HC_CACHE_MODE)
; Parameters ....: $IMMERSIVE_HC_CACHE_MODE - The cache mode. Use one of the following values:
;                    $IHCM_USE_CACHED_VALUE (0) - Use the cached value. (Default)
;                    $IHCM_REFRESH (1) - Refresh the value.
; Return values .: Success: True if immersive color is using high contrast.
;                  Failure: False and sets the @error flag:
;                           -1: Operating system version is earlier than Windows 10 (version 17763)
;                           Other values: DllCall error, check @error @extended for more information.
; Author ........: NoNameCode
; Modified ......:
; Remarks .......: This function is applicable for Windows 10 (version 17763) and later.
; Related .......:
; Link ..........: http://www.opengate.at/blog/2021/08/dark-mode-win32/
; Example .......: No
; ===============================================================================================================================
Func _WinAPI_GetIsImmersiveColorUsingHighContrast($IMMERSIVE_HC_CACHE_MODE = $IHCM_USE_CACHED_VALUE)
	If @OSBuild < 17763 Then Return SetError(-1, 0, False)

	Local $fnGetIsImmersiveColorUsingHighContrast = 106

	Local $aResult = DllCall('uxtheme.dll', 'bool', $fnGetIsImmersiveColorUsingHighContrast, 'int', $IMMERSIVE_HC_CACHE_MODE)
	If @error Then Return SetError(@error, @extended, False)

	Return $aResult[0]
EndFunc   ;==>_WinAPI_GetIsImmersiveColorUsingHighContrast

; #FUNCTION# ====================================================================================================================
; Name ..........: _WinAPI_OpenNcThemeData
; Description ...: Opens the theme data for a window.
; Syntax ........: _WinAPI_OpenNcThemeData($hWnd, $pClassList)
; Parameters ....: $hWnd - Handle to the window.
;                  $sClassList - String that contains a semicolon-separated list of classes.
; Return values .: Success: A handle to the theme data.
;                  Failure: 0 and sets the @error flag:
;                           -1: Operating system version is earlier than Windows 10 (version 17763)
;                           Other values: DllCall error, check @error @extended for more information.
; Author ........: NoNameCode
; Modified ......:
; Remarks .......:
; Related .......:
; Link ..........: https://github.com/ysc3839/win32-darkmode/blob/master/win32-darkmode/DarkMode.h#L69
; Example .......: No
; ===============================================================================================================================
Func _WinAPI_OpenNcThemeData($hWnd, $sClassList)
	If @OSBuild < 17763 Then Return SetError(-1, 0, False)

	Local $fnOpenNcThemeData = 49

	Local $aResult = DllCall('uxtheme.dll', 'hwnd', $fnOpenNcThemeData, 'hwnd', $hWnd, 'wstr', $sClassList)
	If @error Then Return SetError(@error, @extended, 0)

	Return $aResult[0]
EndFunc   ;==>_WinAPI_OpenNcThemeData

; #FUNCTION# ====================================================================================================================
; Name ..........: _WinAPI_ShouldSystemUseDarkMode
; Description ...: Checks if system should use the dark mode.
; Syntax ........: _WinAPI_ShouldSystemUseDarkMode()
; Parameters ....: None
; Return values .: Success: Returns True if system should use dark mode.
;                  Failure: Returns False and sets @error:
;                           -1: Operating system version is earlier than Windows 10 (version 1903, build 18362).
;                           Other values: DllCall error, check @error @extended for more information.
; Author ........: NoNameCode
; Modified ......:
; Remarks .......: Requires Windows 10 (version 1903, build 18362) or later.
; Related .......:
; Link ..........: http://www.opengate.at/blog/2021/08/dark-mode-win32/
; Example .......: No
; ===============================================================================================================================
Func _WinAPI_ShouldSystemUseDarkMode()
	If @OSBuild < 18362 Then Return SetError(-1, 0, False)

	Local $fnShouldSystemUseDarkMode = 138

	Local $aResult = DllCall('uxtheme.dll', 'bool', $fnShouldSystemUseDarkMode)
	If @error Then Return SetError(@error, @extended, False)

	Return $aResult[0]
EndFunc   ;==>_WinAPI_ShouldSystemUseDarkMode

; #FUNCTION# ====================================================================================================================
; Name ..........: _WinAPI_SetPreferredAppMode
; Description ...: Sets the preferred application mode for Windows 10 (version 1903, build 18362) and later.
; Syntax ........: _WinAPI_SetPreferredAppMode($PREFERREDAPPMODE)
; Parameters ....: $PREFERREDAPPMODE - The preferred application mode. See enum PreferredAppMode for possible values.
;                    $APPMODE_DEFAULT (0)
;                    $APPMODE_ALLOWDARK (1)
;                    $APPMODE_FORCEDARK (2)
;                    $APPMODE_FORCELIGHT (3)
;                    $APPMODE_MAX (4)
; Return values .: Success: The PreferredAppMode retuned by the DllCall
;                  Failure: '' and sets the @error flag:
;                           -1: Operating system version is earlier than Windows 10 (version 18362)
;                           Other values: DllCall error, check @error @extended for more information.
; Author ........: NoNameCode
; Modified ......:
; Remarks .......: This function is applicable for Windows 10 (version 18362) and later.
; Related .......: _WinAPI_AllowDarkModeForApp
; Link ..........: http://www.opengate.at/blog/2021/08/dark-mode-win32/
; Example .......: No
; ===============================================================================================================================
Func _WinAPI_SetPreferredAppMode($PREFERREDAPPMODE)
	If @OSBuild < 18362 Then Return SetError(-1, 0, False)

	Local $fnSetPreferredAppMode = 135

	Local $aResult = DllCall('uxtheme.dll', 'int', $fnSetPreferredAppMode, 'int', $PREFERREDAPPMODE)
	If @error Then Return SetError(@error, @extended, '')

	Return $aResult[0]
EndFunc   ;==>_WinAPI_SetPreferredAppMode



#EndRegion Public Functions
