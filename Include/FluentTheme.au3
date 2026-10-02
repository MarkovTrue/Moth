#include-once
#include <WinAPIGdi.au3>
#include <WinAPIGdiDC.au3>
#include <WinAPIProc.au3>
#include <WinAPISysWin.au3>
#include <WinAPITheme.au3>
#include <WindowsConstants.au3>

#include "FluentCore.au3"
#include "FluentWinApi.au3"

; ============================================================
; FluentTheme – тёмная и светлая тема окна и штатных контролов
; ============================================================
; Цвета - из палитры FluentCore: _FluentSetTheme, затем _FluentTheme_Apply.
; Каждый штатный класс контрола обслуживает свой модуль FluentNative*: при подключении
; он регистрирует функцию темизации (__FluentTheme_RegisterClass). Класс без модуля
; получает системную тему Explorer в тёмном варианте.
; Не совместимо с WS_EX_COMPOSITED. Хуки модулей: 'theme-reset' перед темой окна,
; 'theme-window' после контролов (меню окна), 'theme-cleanup' при снятии темы.

; Угол окна Windows 11 для _FluentTheme_SetCorners
Global Const $FLUENT_CORNER_DEFAULT = 0
Global Const $FLUENT_CORNER_SQUARE = 1
Global Const $FLUENT_CORNER_ROUND = 2
Global Const $FLUENT_CORNER_ROUNDSMALL = 3

; Классы (в нижнем регистре) → функция темизации ($hGui, $hCtrl). Контролы вне темы
Global $__g_oFluentClasses[], $__g_oFluentExclude[]
; Окно, которое сейчас темизируется, для хуков 'theme-window'
Global $__g_hFluentThemeGui = 0
; Рамка у Edit, ListBox, ListView, TreeView и акцентная линия под Edit
Global $__g_bFluentFrame = True, $__g_bFluentEditLine = True
; -1 - ещё не определено: есть ли тема DarkMode_DarkTheme (Windows 11 24H2+)
Global $__g_iFluent24H2 = -1
Global $__g_bFluentThemeStarted = False
; Окна, которые следуют за темой системы
Global $__g_aFluentFollow[0]
; GroupBox на вкладках: вкладка рисует их поверх себя (FluentNativeButton, FluentNativeTab)
Global $__g_aFluentGroupInTab[0]
; NMCUSTOMDRAW: заголовок, дорожка ползунка, календарь
Global Const $__tagFLUENT_NMCUSTOMDRAW = $tagNMHDR & ";dword dwDrawStage;handle hdc;long left;long top;long right;long bottom;" & _
		"dword_ptr dwItemSpec;uint uItemState;lparam lItemlParam"

; Кисти и перья GDI из палитры: пересоздаются при каждом _FluentTheme_Apply
Global $__g_hFluentBrGui = 0, $__g_hFluentBrCtrl = 0, $__g_hFluentBrTabBk = 0, $__g_hFluentBrTab = 0
Global $__g_hFluentBrBtn = 0, $__g_hFluentBrBtnHot = 0, $__g_hFluentBrBtnPressed = 0
Global $__g_hFluentBrMenuBk = 0, $__g_hFluentBrMenuSel = 0, $__g_hFluentBrMenuHot = 0
Global $__g_hFluentBrAccent = 0, $__g_hFluentBrAccentHot = 0, $__g_hFluentBrChannel = 0
Global $__g_hFluentBrScrollCorner = 0, $__g_hFluentBrFrame = 0
Global $__g_hFluentBrMsgTop = 0, $__g_hFluentBrMsgBottom = 0
Global $__g_hFluentPenGui = 0, $__g_hFluentPenBtnBorder = 0, $__g_hFluentPenFrame = 0, $__g_hFluentPenFrameHot = 0
Global $__g_hFluentPenAccent = 0, $__g_hFluentPen2Accent = 0, $__g_hFluentPen2Frame = 0, $__g_hFluentPen2FrameHot = 0

; Тёмные меню и системные цвета доступны приложению только после этого вызова
_FluentWinApi_SetPreferredAppMode($FLUENT_APPMODE_ALLOWDARK)


; ============================================================
; Публичное
; ============================================================

; Тема окна и всех его контролов по текущей палитре. Повторный вызов (смена темы)
; сначала снимает прежнюю: сабклассы окна, подмену процедур, кисти
Func _FluentTheme_Apply($hGui)
	__FluentTheme_Start()
	__FluentTheme_Remove($hGui)
	$__g_hFluentThemeGui = $hGui
	ReDim $__g_aFluentGroupInTab[0]
	__FluentHookRun('theme-reset')

	Local Const $DWMWA_USE_IMMERSIVE_DARK_MODE = 20, $DWMWA_CAPTION_COLOR = 35
	Local $bDark = $g_bFluentDark
	_FluentWinApi_SetPreferredAppMode($bDark ? $FLUENT_APPMODE_FORCEDARK : $FLUENT_APPMODE_FORCELIGHT)
	_FluentWinApi_RefreshImmersiveColorPolicyState()
	_FluentWinApi_FlushMenuThemes()
	_FluentWinApi_AllowDarkModeForWindow($hGui, $bDark)
	_WinAPI_DwmSetWindowAttribute($hGui, $DWMWA_USE_IMMERSIVE_DARK_MODE, $bDark)
	; Windows 11: заголовок в цвет фона окна
	If @OSBuild >= 22000 Then _WinAPI_DwmSetWindowAttribute($hGui, $DWMWA_CAPTION_COLOR, _WinAPI_SwitchColor($g_iFluentBg))

	__FluentTheme_Brushes()
	GUISetBkColor($g_iFluentBg, $hGui)

	Local $aCtrls = _WinAPI_EnumChildWindows($hGui, False)
	If Not @error Then
		For $i = 1 To $aCtrls[0][0]
			_FluentTheme_ApplyCtrl($hGui, $aCtrls[$i][0])
		Next
	EndIf
	; Подсказки - окна верхнего уровня процесса, среди дочерних их нет
	Local $aTips = _WinAPI_EnumProcessWindows(0, False)
	If Not @error Then
		For $i = 1 To $aTips[0][0]
			If $aTips[$i][1] = 'tooltips_class32' Then _FluentTheme_ApplyCtrl($hGui, $aTips[$i][0])
		Next
	EndIf

	__FluentHookRun('theme-window')
	; Тема перекрашивает все Static, в том числе Pic рисованных контролов
	_FluentRenderAll()
EndFunc   ;==>_FluentTheme_Apply


; Тема одного контрола (handle или ControlID) по его классу
Func _FluentTheme_ApplyCtrl($hGui, $hCtrl)
	If Not IsHWnd($hCtrl) Then $hCtrl = GUICtrlGetHandle($hCtrl)
	If Not IsHWnd($hCtrl) Then Return SetError(1, 0, False)
	If MapExists($__g_oFluentExclude, String($hCtrl)) Then Return True
	__FluentTheme_Start()
	_FluentWinApi_AllowDarkModeForWindow($hCtrl, $g_bFluentDark)

	Local $sClass = StringLower(_WinAPI_GetClassName($hCtrl))
	If MapExists($__g_oFluentClasses, $sClass) Then Return Call($__g_oFluentClasses[$sClass], $hGui, $hCtrl)

	; Дочернее окно AutoIt светлым - системное, остальным классам - тёмный Explorer
	If $sClass = 'autoit v3 gui' And Not $g_bFluentDark Then Return __FluentTheme_SetTheme($hCtrl, Null)
	Return __FluentTheme_SetTheme($hCtrl, 'DarkMode_Explorer')
EndFunc   ;==>_FluentTheme_ApplyCtrl


; Контрол со своей отрисовкой: тема окна его не трогает
Func _FluentTheme_Exclude($hCtrl)
	If Not IsHWnd($hCtrl) Then $hCtrl = GUICtrlGetHandle($hCtrl)
	If $hCtrl Then $__g_oFluentExclude[String($hCtrl)] = True
EndFunc   ;==>_FluentTheme_Exclude


; Рамка вокруг Edit, ListBox, ListView, TreeView и акцентная линия под Edit.
; Без рамки поле под неё не резервируется: рисованная рамка приложения ложится вплотную
Func _FluentTheme_SetBorders($bFrame = True, $bEditLine = True)
	$__g_bFluentFrame = $bFrame
	$__g_bFluentEditLine = $bEditLine
EndFunc   ;==>_FluentTheme_SetBorders


; Угол окна Windows 11: $FLUENT_CORNER_*
Func _FluentTheme_SetCorners($hWnd, $iPref)
	Local Const $DWMWA_WINDOW_CORNER_PREFERENCE = 33
	If @OSBuild >= 22000 Then _WinAPI_DwmSetWindowAttribute($hWnd, $DWMWA_WINDOW_CORNER_PREFERENCE, $iPref)
EndFunc   ;==>_FluentTheme_SetCorners


; Смена темы на лету: новая палитра и повторная тема окна без мерцания
Func _FluentTheme_Switch($hGui, $bDark)
	_WinAPI_LockWindowUpdate($hGui)
	_FluentSetTheme($bDark, $g_iFluentAccent)
	_FluentTheme_Apply($hGui)
	_WinAPI_RedrawWindow($hGui, 0, 0, BitOR($RDW_INVALIDATE, $RDW_UPDATENOW, $RDW_ALLCHILDREN))
	_WinAPI_LockWindowUpdate(0)
	_WinAPI_SetWindowPos($hGui, 0, 0, 0, 0, 0, BitOR($SWP_NOMOVE, $SWP_NOSIZE, $SWP_NOZORDER, $SWP_FRAMECHANGED))
EndFunc   ;==>_FluentTheme_Switch


; Окно следует за темой приложений в настройках Windows
Func _FluentTheme_Follow($hGui, $bOn = True)
	Local $aKeep[0]
	For $hItem In $__g_aFluentFollow
		If $hItem = $hGui Then ContinueLoop
		ReDim $aKeep[UBound($aKeep) + 1]
		$aKeep[UBound($aKeep) - 1] = $hItem
	Next
	If $bOn Then
		ReDim $aKeep[UBound($aKeep) + 1]
		$aKeep[UBound($aKeep) - 1] = $hGui
	EndIf
	$__g_aFluentFollow = $aKeep
	If UBound($aKeep) Then
		_FluentMsg_Register($WM_SETTINGCHANGE, '__FluentTheme_SettingChange')
	Else
		_FluentMsg_Unregister($WM_SETTINGCHANGE, '__FluentTheme_SettingChange')
	EndIf
EndFunc   ;==>_FluentTheme_Follow


; ============================================================
; Для модулей FluentNative*
; ============================================================

Func __FluentTheme_RegisterClass($sClass, $sFunc)
	$__g_oFluentClasses[StringLower($sClass)] = $sFunc
EndFunc   ;==>__FluentTheme_RegisterClass


; Тема оформления контрола. Null - системная по умолчанию
Func __FluentTheme_SetTheme($hCtrl, $sName, $sList = Null)
	_WinAPI_SetWindowTheme($hCtrl, $sName, $sList)
	If @error Then Return SetError(3, @error, False)
	_SendMessage($hCtrl, $WM_THEMECHANGED, 0, 0)
	Return True
EndFunc   ;==>__FluentTheme_SetTheme


; Тёмная тема контролов: DarkMode_DarkTheme (Windows 11 24H2+) рисует их ближе к системе
Func __FluentTheme_DarkName()
	Return __FluentTheme_Is24H2() ? 'DarkMode_DarkTheme' : 'DarkMode_Explorer'
EndFunc   ;==>__FluentTheme_DarkName


Func __FluentTheme_Is24H2()
	If $__g_iFluent24H2 = -1 Then $__g_iFluent24H2 = __FluentTheme_Detect24H2() ? 1 : 0
	Return $__g_iFluent24H2 = 1
EndFunc   ;==>__FluentTheme_Is24H2


; Лежит ли контрол на вкладке окна: тогда его фон - фон страницы вкладки
Func __FluentTheme_InTab($hGui, $hCtrl)
	Local $hTab = _FluentWinApi_FindWindowEx($hGui, "SysTabControl32")
	If Not $hTab Then Return False
	Local $tIntersect = _WinAPI_IntersectRect(_WinAPI_GetWindowRect($hTab), _WinAPI_GetWindowRect($hCtrl))
	Return DllStructGetData($tIntersect, "Left") <> 0 Or DllStructGetData($tIntersect, "Right") <> 0
EndFunc   ;==>__FluentTheme_InTab


Func __FluentTheme_IsResizable($hWnd)
	Return BitAND(_WinAPI_GetWindowLong($hWnd, $GWL_STYLE), $WS_SIZEBOX) <> 0
EndFunc   ;==>__FluentTheme_IsResizable


; Общий сабкласс полей: рамка, цвета, уголок между полосами прокрутки. $bNoEdge убирает
; рамку WS_EX_CLIENTEDGE, её место займёт рамка темы. Порядок важен: пересчёт рамки
; (SWP_FRAMECHANGED) должен прийти уже в сабкласс
Func __FluentTheme_Frame($hCtrl, $bNoEdge = False, $bRecalc = False)
	If $bNoEdge Then _WinAPI_SetWindowLong($hCtrl, $GWL_EXSTYLE, _
			BitAND(_WinAPI_GetWindowLong($hCtrl, $GWL_EXSTYLE), BitNOT($WS_EX_CLIENTEDGE)))
	_FluentSubclass_Set($hCtrl, '__FluentTheme_FrameProc')
	If $bNoEdge Or $bRecalc Then _
			_WinAPI_SetWindowPos($hCtrl, 0, 0, 0, 0, 0, BitOR($SWP_NOMOVE, $SWP_NOSIZE, $SWP_NOZORDER, $SWP_FRAMECHANGED))
EndFunc   ;==>__FluentTheme_Frame


; Обработчик WM_CTLCOLOR* темы для сообщения $iMsg
Func __FluentTheme_UseCtlColor($iMsg, $bOn = True)
	If $bOn Then
		_FluentMsg_Register($iMsg, '__FluentTheme_CtlColor')
	Else
		_FluentMsg_Unregister($iMsg, '__FluentTheme_CtlColor')
	EndIf
EndFunc   ;==>__FluentTheme_UseCtlColor


; ============================================================
; Внутреннее
; ============================================================

Func __FluentTheme_Start()
	If $__g_bFluentThemeStarted Then Return
	$__g_bFluentThemeStarted = True
	__FluentGdipStart()
	OnAutoItExitRegister("__FluentTheme_OnExit")
EndFunc   ;==>__FluentTheme_Start


Func __FluentTheme_OnExit()
	__FluentHookRun('theme-cleanup')
	_FluentSubclass_RemoveAll()
	__FluentTheme_Free()
EndFunc   ;==>__FluentTheme_OnExit


; Снимает тему, повешенную на окно прежним _FluentTheme_Apply
Func __FluentTheme_Remove($hGui)
	__FluentHookRun('theme-cleanup')
	Local $aKeep[0][3], $hWnd, $iKeep = 0
	For $i = 0 To UBound($__g_aFluentSubclass) - 1
		$hWnd = $__g_aFluentSubclass[$i][0]
		If $hWnd = $hGui Or _WinAPI_IsChild($hWnd, $hGui) Then
			_WinAPI_RemoveWindowSubclass($hWnd, $__g_aFluentSubclass[$i][1], $__g_aFluentSubclass[$i][2])
			ContinueLoop
		EndIf
		ReDim $aKeep[$iKeep + 1][3]
		For $j = 0 To 2
			$aKeep[$iKeep][$j] = $__g_aFluentSubclass[$i][$j]
		Next
		$iKeep += 1
	Next
	$__g_aFluentSubclass = $aKeep
EndFunc   ;==>__FluentTheme_Remove


; Есть ли DarkMode_DarkTheme: у неё поле ввода тёмное, у отсутствующей темы - системное светлое
Func __FluentTheme_Detect24H2()
	If Not _WinAPI_IsThemeActive() Then Return False
	Local $iWindow = _WinAPI_SwitchColor(_WinAPI_GetSysColor($COLOR_WINDOW))
	Local $iColor = __FluentTheme_QueryColor("DarkMode_DarkTheme::Edit")
	Return Not @error And Hex($iColor, 6) <> Hex($iWindow, 6)
EndFunc   ;==>__FluentTheme_Detect24H2


; Цвет заливки поля в теме $sClass. Окно для темы - рабочий стол: своего может ещё не быть
Func __FluentTheme_QueryColor($sClass)
	Local Const $TMT_FILLCOLOR = 3802, $EP_BACKGROUND = 3, $EBS_NORMAL = 1
	Local $hTheme = _WinAPI_OpenThemeData(_WinAPI_GetDesktopWindow(), $sClass)
	If @error Or Not $hTheme Then Return SetError(1, 0, 0)
	Local $iColor = _WinAPI_GetThemeColor($hTheme, $EP_BACKGROUND, $EBS_NORMAL, $TMT_FILLCOLOR)
	Local $iError = @error
	_WinAPI_CloseThemeData($hTheme)
	If $iError Then Return SetError(2, 0, 0)
	Return $iColor
EndFunc   ;==>__FluentTheme_QueryColor


Func __FluentTheme_Brushes()
	__FluentTheme_Free()
	$__g_hFluentBrGui = __FluentTheme_Brush($g_iFluentBg)
	$__g_hFluentBrCtrl = __FluentTheme_Brush($g_iFluentCtrlBg)
	$__g_hFluentBrTabBk = __FluentTheme_Brush($g_iFluentBg)
	$__g_hFluentBrTab = __FluentTheme_Brush($g_iFluentTab)
	$__g_hFluentBrBtn = __FluentTheme_Brush($g_iFluentBtnBg)
	$__g_hFluentBrBtnHot = __FluentTheme_Brush($g_iFluentBtnHot)
	$__g_hFluentBrBtnPressed = __FluentTheme_Brush($g_iFluentBtnPressed)
	$__g_hFluentBrMenuBk = __FluentTheme_Brush($g_iFluentBg)
	$__g_hFluentBrMenuSel = __FluentTheme_Brush($g_iFluentMenuSel)
	$__g_hFluentBrMenuHot = __FluentTheme_Brush($g_iFluentMenuHot)
	$__g_hFluentBrAccent = __FluentTheme_Brush($g_iFluentAccent)
	$__g_hFluentBrAccentHot = __FluentTheme_Brush($g_iFluentAccentHot)
	$__g_hFluentBrChannel = __FluentTheme_Brush($g_iFluentChannel)
	$__g_hFluentBrScrollCorner = __FluentTheme_Brush($g_iFluentScrollCorner)
	$__g_hFluentBrFrame = __FluentTheme_Brush($g_iFluentFrame)
	$__g_hFluentBrMsgTop = __FluentTheme_Brush($g_iFluentMsgTop)
	$__g_hFluentBrMsgBottom = __FluentTheme_Brush($g_iFluentMsgBottom)

	$__g_hFluentPenGui = __FluentTheme_Pen($g_iFluentBg)
	$__g_hFluentPenBtnBorder = __FluentTheme_Pen($g_iFluentBtnBorder)
	$__g_hFluentPenFrame = __FluentTheme_Pen($g_iFluentFrame)
	$__g_hFluentPenFrameHot = __FluentTheme_Pen($g_iFluentFrameHot)
	$__g_hFluentPenAccent = __FluentTheme_Pen($g_iFluentAccent)
	$__g_hFluentPen2Accent = __FluentTheme_Pen($g_iFluentAccent, 2)
	$__g_hFluentPen2Frame = __FluentTheme_Pen($g_iFluentFrame, 2)
	$__g_hFluentPen2FrameHot = __FluentTheme_Pen($g_iFluentFrameHot, 2)
EndFunc   ;==>__FluentTheme_Brushes


Func __FluentTheme_Brush($iRgb)
	Return _WinAPI_CreateSolidBrush(_WinAPI_SwitchColor($iRgb))
EndFunc   ;==>__FluentTheme_Brush


Func __FluentTheme_Pen($iRgb, $iWidth = 1)
	Return _WinAPI_CreatePen($PS_SOLID, $iWidth, _WinAPI_SwitchColor($iRgb))
EndFunc   ;==>__FluentTheme_Pen


Func __FluentTheme_Free()
	Local $aObjects[25] = [$__g_hFluentBrGui, $__g_hFluentBrCtrl, $__g_hFluentBrTabBk, $__g_hFluentBrTab, _
			$__g_hFluentBrBtn, $__g_hFluentBrBtnHot, $__g_hFluentBrBtnPressed, $__g_hFluentBrMenuBk, _
			$__g_hFluentBrMenuSel, $__g_hFluentBrMenuHot, $__g_hFluentBrAccent, $__g_hFluentBrAccentHot, _
			$__g_hFluentBrChannel, $__g_hFluentBrScrollCorner, $__g_hFluentBrFrame, $__g_hFluentBrMsgTop, _
			$__g_hFluentBrMsgBottom, $__g_hFluentPenGui, $__g_hFluentPenBtnBorder, $__g_hFluentPenFrame, _
			$__g_hFluentPenFrameHot, $__g_hFluentPenAccent, $__g_hFluentPen2Accent, $__g_hFluentPen2Frame, _
			$__g_hFluentPen2FrameHot]
	For $hObject In $aObjects
		If $hObject Then _WinAPI_DeleteObject($hObject)
	Next
	$__g_hFluentBrGui = 0
	$__g_hFluentBrCtrl = 0
	$__g_hFluentBrTabBk = 0
	$__g_hFluentBrTab = 0
	$__g_hFluentBrBtn = 0
	$__g_hFluentBrBtnHot = 0
	$__g_hFluentBrBtnPressed = 0
	$__g_hFluentBrMenuBk = 0
	$__g_hFluentBrMenuSel = 0
	$__g_hFluentBrMenuHot = 0
	$__g_hFluentBrAccent = 0
	$__g_hFluentBrAccentHot = 0
	$__g_hFluentBrChannel = 0
	$__g_hFluentBrScrollCorner = 0
	$__g_hFluentBrFrame = 0
	$__g_hFluentBrMsgTop = 0
	$__g_hFluentBrMsgBottom = 0
	$__g_hFluentPenGui = 0
	$__g_hFluentPenBtnBorder = 0
	$__g_hFluentPenFrame = 0
	$__g_hFluentPenFrameHot = 0
	$__g_hFluentPenAccent = 0
	$__g_hFluentPen2Accent = 0
	$__g_hFluentPen2Frame = 0
	$__g_hFluentPen2FrameHot = 0
EndFunc   ;==>__FluentTheme_Free


; Цвета полей, списков и кнопок на вкладке. Из WM_CTLCOLORSTATIC здесь только Edit
; для чтения и SysLink: подписи красит AutoIt по GUICtrlSetColor
Func __FluentTheme_CtlColor($hWnd, $iMsg, $wParam, $lParam)
	Local $hDC = $wParam, $hCtrl = $lParam
	Switch $iMsg
		Case $WM_CTLCOLORLISTBOX, $WM_CTLCOLOREDIT
			_WinAPI_SetTextColor($hDC, _WinAPI_SwitchColor($g_iFluentText1))
			_WinAPI_SetBkMode($hDC, $TRANSPARENT)
			Return $__g_hFluentBrCtrl

		Case $WM_CTLCOLORBTN
			If __FluentTheme_InTab($hWnd, $hCtrl) Then Return $__g_hFluentBrTabBk

		Case $WM_CTLCOLORSTATIC
			Switch _WinAPI_GetClassName($hCtrl)
				Case "Edit"
					_WinAPI_SetTextColor($hDC, _WinAPI_SwitchColor($g_iFluentText1))
					_WinAPI_SetBkMode($hDC, $TRANSPARENT)
					Return $__g_hFluentBrCtrl
				Case "SysLink"
					_WinAPI_SetBkMode($hDC, $TRANSPARENT)
					Return $__g_hFluentBrGui
			EndSwitch
	EndSwitch
	Return $GUI_RUNDEFMSG
EndFunc   ;==>__FluentTheme_CtlColor


; Сабкласс полей и списков. Рамка WS_EX_CLIENTEDGE рисуется в неклиентской области,
; поэтому её место резервирует WM_NCCALCSIZE, а тёмную рамку рисует WM_NCPAINT.
; Уголок между полосами прокрутки Windows закрашивает светлым в обход WM_PAINT
Func __FluentTheme_FrameProc($hWnd, $iMsg, $wParam, $lParam, $iID, $pData)
	#forceref $iID, $pData
	Local $hDC, $iRet
	Switch $iMsg
		Case $WM_CTLCOLORLISTBOX, $WM_CTLCOLOREDIT
			; Дочерние поле и список комбо
			$hDC = $wParam
			_WinAPI_SetTextColor($hDC, _WinAPI_SwitchColor($g_iFluentText1))
			_WinAPI_SetBkColor($hDC, _WinAPI_SwitchColor($g_iFluentCtrlBg))
			_WinAPI_SetBkMode($hDC, $TRANSPARENT)
			Return $__g_hFluentBrCtrl

		Case $WM_NOTIFY
			; Заголовок списка сообщает о рисовании своему списку, а не окну
			If $g_bFluentDark Then
				Local $tNMHDR = DllStructCreate($tagNMHDR, $lParam)
				If $tNMHDR.Code = $NM_CUSTOMDRAW And StringLower(_WinAPI_GetClassName($tNMHDR.hWndFrom)) = "sysheader32" Then
					Local $tNMCD = DllStructCreate($__tagFLUENT_NMCUSTOMDRAW, $lParam)
					Switch $tNMCD.dwDrawStage
						Case $CDDS_PREPAINT
							Return $CDRF_NOTIFYITEMDRAW
						Case $CDDS_ITEMPREPAINT
							_WinAPI_SetTextColor($tNMCD.hdc, _WinAPI_SwitchColor($g_iFluentText1))
							_WinAPI_SetBkColor($tNMCD.hdc, 0)
							Return BitOR($CDRF_NEWFONT, $CDRF_NOTIFYPOSTPAINT)
					EndSwitch
				EndIf
			EndIf

		Case $WM_PAINT
			If __FluentTheme_HasCorner($hWnd) Then
				$iRet = _FluentSubclass_DefProc($hWnd, $iMsg, $wParam, $lParam)
				__FluentTheme_ScrollCorner($hWnd)
				Return $iRet
			EndIf

		Case $WM_NCPAINT
			If __FluentTheme_IsFramed($hWnd) Then
				$iRet = _FluentSubclass_DefProc($hWnd, $iMsg, $wParam, $lParam)
				If $__g_bFluentFrame Then __FluentTheme_DrawFrame($hWnd)
				__FluentTheme_ScrollCorner($hWnd)
				Return $iRet
			EndIf

		Case $WM_NCMOUSEMOVE
			; Подсветка полосы прокрутки анимируется таймером и рисует уголок в обход
			; WM_PAINT и WM_NCPAINT: уголок восстанавливается на каждом движении мыши
			If __FluentTheme_IsFramed($hWnd) Then
				$iRet = _FluentSubclass_DefProc($hWnd, $iMsg, $wParam, $lParam)
				__FluentTheme_ScrollCorner($hWnd)
				Return $iRet
			EndIf

		Case $WM_NCCALCSIZE
			; Поле под рамку. Без рамки не резервируется: WM_NCPAINT его бы не закрасил
			If $wParam And $__g_bFluentFrame And __FluentTheme_IsFramed($hWnd) Then
				$iRet = _FluentSubclass_DefProc($hWnd, $iMsg, $wParam, $lParam)
				Local $sClass = StringLower(_WinAPI_GetClassName($hWnd))
				If $sClass = "listbox" Then Return $iRet
				Local $tRect = DllStructCreate($tagRECT, $lParam)
				$tRect.left += 1
				$tRect.top += 1
				$tRect.right -= 1
				$tRect.bottom -= ($sClass = "edit" And $__g_bFluentEditLine) ? 2 : 1
				Return $iRet
			EndIf
	EndSwitch
	Return _FluentSubclass_DefProc($hWnd, $iMsg, $wParam, $lParam)
EndFunc   ;==>__FluentTheme_FrameProc


Func __FluentTheme_IsFramed($hWnd)
	Switch StringLower(_WinAPI_GetClassName($hWnd))
		Case "edit", "listbox", "syslistview32", "systreeview32", "sysipaddress32"
			Return True
	EndSwitch
	Return False
EndFunc   ;==>__FluentTheme_IsFramed


Func __FluentTheme_HasCorner($hWnd)
	Switch StringLower(_WinAPI_GetClassName($hWnd))
		Case "edit", "syslistview32", "systreeview32"
			Return True
	EndSwitch
	Return False
EndFunc   ;==>__FluentTheme_HasCorner


; Рамка поля. У Edit снизу линия: акцентная в фокусе, иначе цвета фона
Func __FluentTheme_DrawFrame($hWnd)
	Local $hDC = _WinAPI_GetWindowDC($hWnd)
	Local $tRect = _WinAPI_GetWindowRect($hWnd)
	Local $iW = $tRect.Right - $tRect.Left, $iH = $tRect.Bottom - $tRect.Top
	Local $bFocus = _WinAPI_GetFocus() = $hWnd

	Local $hOldPen = _WinAPI_SelectObject($hDC, $g_bFluentDark ? $__g_hFluentPenFrame : $__g_hFluentPenFrameHot)
	Local $hOldBrush = _WinAPI_SelectObject($hDC, _WinAPI_GetStockObject($NULL_BRUSH))
	DllCall("gdi32.dll", "bool", "Rectangle", "handle", $hDC, "int", 0, "int", 0, "int", $iW, "int", $iH)

	If $__g_bFluentEditLine And StringLower(_WinAPI_GetClassName($hWnd)) = "edit" Then
		If $bFocus Then
			_WinAPI_SelectObject($hDC, $__g_hFluentPen2Accent)
		Else
			_WinAPI_SelectObject($hDC, $g_bFluentDark ? $__g_hFluentPen2Frame : $__g_hFluentPen2FrameHot)
			_WinAPI_DrawLine($hDC, 0, $iH - 1, $iW, $iH - 1)
			_WinAPI_SelectObject($hDC, $__g_hFluentPenGui)
		EndIf
		_WinAPI_DrawLine($hDC, 0, $iH - 1, $iW, $iH - 1)
	EndIf

	_WinAPI_SelectObject($hDC, $hOldPen)
	_WinAPI_SelectObject($hDC, $hOldBrush)
	_WinAPI_ReleaseDC($hWnd, $hDC)
EndFunc   ;==>__FluentTheme_DrawFrame


; Уголок между горизонтальной и вертикальной полосами прокрутки - цветом темы
Func __FluentTheme_ScrollCorner($hWnd)
	Local $iStyle = _WinAPI_GetWindowLong($hWnd, $GWL_STYLE)
	If Not (BitAND($iStyle, $WS_HSCROLL) And BitAND($iStyle, $WS_VSCROLL)) Then Return False

	Local $tWindow = _WinAPI_GetWindowRect($hWnd), $tClient = _WinAPI_GetClientRect($hWnd)
	Local $tPoint = DllStructCreate($tagPOINT)
	_WinAPI_ClientToScreen($hWnd, $tPoint)
	; Отступ клиентской области от края окна - ширина рамки
	Local $iOffL = $tPoint.X - $tWindow.Left, $iOffT = $tPoint.Y - $tWindow.Top

	Local $tCorner = DllStructCreate($tagRECT)
	$tCorner.Left = $iOffL + $tClient.Right
	$tCorner.Top = $iOffT + $tClient.Bottom
	$tCorner.Right = $tWindow.Right - $tWindow.Left - $iOffL
	$tCorner.Bottom = $tWindow.Bottom - $tWindow.Top - $iOffT
	If $__g_bFluentEditLine And StringLower(_WinAPI_GetClassName($hWnd)) = "edit" Then $tCorner.Bottom -= 1

	Local $hDC = _WinAPI_GetWindowDC($hWnd)
	_WinAPI_FillRect($hDC, $tCorner, $__g_hFluentBrScrollCorner)
	_WinAPI_ReleaseDC($hWnd, $hDC)
	Return True
EndFunc   ;==>__FluentTheme_ScrollCorner


; Тема приложений в Windows сменилась: окна из _FluentTheme_Follow перекрашиваются
Func __FluentTheme_SettingChange($hWnd, $iMsg, $wParam, $lParam)
	#forceref $hWnd, $iMsg, $wParam
	If Not $lParam Then Return $GUI_RUNDEFMSG
	If DllStructGetData(DllStructCreate("wchar[64]", $lParam), 1) <> "ImmersiveColorSet" Then Return $GUI_RUNDEFMSG
	Local $bDark = _FluentWinApi_ShouldAppsUseDarkMode()
	If $bDark = $g_bFluentDark Then Return $GUI_RUNDEFMSG
	For $hGui In $__g_aFluentFollow
		_FluentTheme_Switch($hGui, $bDark)
	Next
	Return $GUI_RUNDEFMSG
EndFunc   ;==>__FluentTheme_SettingChange
