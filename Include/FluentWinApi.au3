#include-once
#include <SendMessage.au3>
#include <WinAPIGdiDC.au3>
#include <WinAPISysWin.au3>

; ============================================================
; FluentWinApi – системные вызовы для семейства Fluent
; ============================================================
; Тёмный режим в Windows 10/11 не документирован: функции uxtheme.dll доступны только по
; номеру (ordinal), поэтому здесь и обёртки. Имена со своим префиксом, чтобы не столкнуться
; со штатными _WinAPI_* будущих версий AutoIt. Обёртки uxtheme – UEZ.

; Режим приложения для _FluentWinApi_SetPreferredAppMode
Global Const $FLUENT_APPMODE_DEFAULT = 0
Global Const $FLUENT_APPMODE_ALLOWDARK = 1
Global Const $FLUENT_APPMODE_FORCEDARK = 2
Global Const $FLUENT_APPMODE_FORCELIGHT = 3

; Кэш высокой контрастности для _FluentWinApi_IsHighContrast
Global Const $FLUENT_IHCM_USE_CACHED_VALUE = 0
Global Const $FLUENT_IHCM_REFRESH = 1


; ============================================================
; uxtheme: тёмный режим
; ============================================================

Func _FluentWinApi_ShouldAppsUseDarkMode()
	Local $aRet = DllCall("uxtheme.dll", "bool", 132)
	If @error Then Return SetError(1, 0, False)
	Return $aRet[0] <> 0
EndFunc   ;==>_FluentWinApi_ShouldAppsUseDarkMode


Func _FluentWinApi_ShouldSystemUseDarkMode()
	Local $aRet = DllCall("uxtheme.dll", "bool", 138)
	If @error Then Return SetError(1, 0, False)
	Return $aRet[0] <> 0
EndFunc   ;==>_FluentWinApi_ShouldSystemUseDarkMode


Func _FluentWinApi_AllowDarkModeForWindow($hWnd, $bAllow = True)
	Local $aRet = DllCall("uxtheme.dll", "bool", 133, "hwnd", $hWnd, "bool", $bAllow)
	If @error Then Return SetError(1, 0, False)
	Return $aRet[0] <> 0
EndFunc   ;==>_FluentWinApi_AllowDarkModeForWindow


Func _FluentWinApi_IsDarkModeAllowedForWindow($hWnd)
	Local $aRet = DllCall("uxtheme.dll", "bool", 137, "hwnd", $hWnd)
	If @error Then Return SetError(1, 0, False)
	Return $aRet[0] <> 0
EndFunc   ;==>_FluentWinApi_IsDarkModeAllowedForWindow


Func _FluentWinApi_IsDarkModeAllowedForApp()
	Local $aRet = DllCall("uxtheme.dll", "bool", 139)
	If @error Then Return SetError(1, 0, False)
	Return $aRet[0] <> 0
EndFunc   ;==>_FluentWinApi_IsDarkModeAllowedForApp


; Windows 10 1903+. Режим - $FLUENT_APPMODE_*
Func _FluentWinApi_SetPreferredAppMode($iMode)
	Local $aRet = DllCall("uxtheme.dll", "long", 135, "long", $iMode)
	If @error Then Return SetError(1, 0, False)
	Return $aRet[0]
EndFunc   ;==>_FluentWinApi_SetPreferredAppMode


Func _FluentWinApi_AllowDarkModeForApp($bAllow = True)
	Return _FluentWinApi_SetPreferredAppMode($bAllow ? $FLUENT_APPMODE_ALLOWDARK : $FLUENT_APPMODE_DEFAULT)
EndFunc   ;==>_FluentWinApi_AllowDarkModeForApp


; Меню и системные цвета перечитывают тему только после этих двух вызовов
Func _FluentWinApi_FlushMenuThemes()
	DllCall("uxtheme.dll", "none", 136)
	If @error Then Return SetError(1, 0, False)
	Return True
EndFunc   ;==>_FluentWinApi_FlushMenuThemes


Func _FluentWinApi_RefreshImmersiveColorPolicyState()
	DllCall("uxtheme.dll", "none", 104)
	If @error Then Return SetError(1, 0, False)
	Return True
EndFunc   ;==>_FluentWinApi_RefreshImmersiveColorPolicyState


Func _FluentWinApi_IsHighContrast($iCacheMode = $FLUENT_IHCM_USE_CACHED_VALUE)
	Local $aRet = DllCall("uxtheme.dll", "bool", 106, "long", $iCacheMode)
	If @error Then Return SetError(1, 0, False)
	Return $aRet[0] <> 0
EndFunc   ;==>_FluentWinApi_IsHighContrast


; Тема неклиентской области окна: $tClassList - wchar-строка классов темы
Func _FluentWinApi_OpenNcThemeData($hWnd, $tClassList)
	Local $aRet = DllCall("uxtheme.dll", "handle", 49, "hwnd", $hWnd, "struct*", $tClassList)
	If @error Then Return SetError(1, 0, 0)
	Return $aRet[0]
EndFunc   ;==>_FluentWinApi_OpenNcThemeData


; ============================================================
; Прочее
; ============================================================

; DPI экрана (0 - рабочий стол) или 0 при ошибке
Func _FluentWinApi_GetDpi($hWnd = 0)
	Local Const $LOGPIXELSX = 88
	If Not $hWnd Then $hWnd = _WinAPI_GetDesktopWindow()
	Local $hDC = _WinAPI_GetDC($hWnd)
	If @error Or Not $hDC Then Return SetError(1, 0, 0)
	Local $iDpi = _WinAPI_GetDeviceCaps($hDC, $LOGPIXELSX)
	_WinAPI_ReleaseDC($hWnd, $hDC)
	If Not $iDpi Then Return SetError(2, 0, 0)
	Return $iDpi
EndFunc   ;==>_FluentWinApi_GetDpi


; DPI окна: Windows 10 1607+
Func _FluentWinApi_GetDpiForWindow($hWnd)
	Local $aRet = DllCall("user32.dll", "uint", "GetDpiForWindow", "hwnd", $hWnd)
	If @error Or Not $aRet[0] Then Return SetError(1, 0, 0)
	Return $aRet[0]
EndFunc   ;==>_FluentWinApi_GetDpiForWindow


; Дочернее окно класса $sClass после $hAfter. $hParent = 0 - среди окон верхнего уровня
Func _FluentWinApi_FindWindowEx($hParent, $sClass, $sTitle = "", $hAfter = 0)
	Local $aRet = DllCall("user32.dll", "hwnd", "FindWindowExW", "hwnd", $hParent, "hwnd", $hAfter, _
			"wstr", $sClass, "wstr", $sTitle)
	If @error Then Return 0
	Return $aRet[0]
EndFunc   ;==>_FluentWinApi_FindWindowEx


Func _FluentWinApi_EndDialog($hWnd, $iReturn)
	Local $aRet = DllCall("user32.dll", "bool", "EndDialog", "hwnd", $hWnd, "int_ptr", $iReturn)
	If @error Then Return SetError(@error, @extended, False)
	Return $aRet[0]
EndFunc   ;==>_FluentWinApi_EndDialog


; Двоичные данные из Base64 (CRYPT_STRING_BASE64 = 1)
Func _FluentWinApi_Base64Decode($sBase64)
	Local $aRet = DllCall("crypt32.dll", "bool", "CryptStringToBinaryA", "str", $sBase64, "dword", 0, "dword", 1, _
			"ptr", 0, "dword*", 0, "ptr", 0, "ptr", 0)
	If @error Or Not $aRet[0] Then Return SetError(1, 0, Binary(""))
	Local $tBuffer = DllStructCreate("byte[" & $aRet[5] & "]")
	$aRet = DllCall("crypt32.dll", "bool", "CryptStringToBinaryA", "str", $sBase64, "dword", 0, "dword", 1, _
			"struct*", $tBuffer, "dword*", $aRet[5], "ptr", 0, "ptr", 0)
	If @error Or Not $aRet[0] Then Return SetError(2, 0, Binary(""))
	Return DllStructGetData($tBuffer, 1)
EndFunc   ;==>_FluentWinApi_Base64Decode


; Расширенный стиль TreeView: TVM_SETEXTENDEDSTYLE, маска - все известные флаги
Func _FluentWinApi_TreeViewSetExStyle($hTreeView, $iExStyle)
	Local Const $TVM_SETEXTENDEDSTYLE = 0x112C
	Return _SendMessage($hTreeView, $TVM_SETEXTENDEDSTYLE, 0x07FD, $iExStyle)
EndFunc   ;==>_FluentWinApi_TreeViewSetExStyle
