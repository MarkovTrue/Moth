#pragma compile(Out, ..\MothPortable\Settings.exe)
#pragma compile(Icon, Assets\Icons\Icon.ico)
#pragma compile(x64, True)
#pragma compile(ProductName, Moth Settings)
#pragma compile(FileDescription, Moth Settings)
#pragma compile(CompanyName, MarkovTrue)
#pragma compile(LegalCopyright, © MarkovTrue)
#pragma compile(Comments, Program made by MarkovTrue)

#NoTrayIcon
#RequireAdmin

; Упрощённое окно настроек: язык, тема, иконки меню, флажки [Config] и интеграция
; с проводником. Состав контекстного меню по форматам правится в Moth.ini,
; полный редактор меню - Settings.Editor.au3, в релиз пока не входит.

#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <StaticConstants.au3>
#include <ButtonConstants.au3>
#include <Math.au3>
#include <Misc.au3>

#include "Common\MothCommon.au3"
#include "Include\FluentButton.au3"
#include "Include\FluentCheck.au3"
#include "Include\FluentNativeStatic.au3"
#include "Include\FluentSegment.au3"
#include "Include\FluentTheme.au3"

Opt("GUIOnEventMode", 1)

; Метрика окна как в VCLauncher: поле 16, зазор 12, строка 28
Global Const $gc_iPadX = 16, $gc_iGap = 12, $gc_iRowH = 28, $gc_iRowGap = 12
Global Const $gc_iCheckH = 20, $gc_iCheckGap = 8, $gc_iIndent = 22, $gc_iBlockGap = 14
Global Const $gc_iFontSize = 9

; Значения [Config] в порядке сегментов
Global Const $gc_aLanguages[2] = ['English', 'Russian']
Global Const $gc_aThemes[2] = ['Light', 'Dark']
; Автозакрытие окна Moth, секунды: 0 - не закрывать
Global Const $gc_aCloseTimes[4] = [5, 10, 30, 0]

Global $g_hGui, $g_bDark
; Размер окна по содержимому: рамка у окна как у главного, но тянуть её нельзя
Global $g_iWinW = 0, $g_iWinH = 0

; Подписи строк, сегменты, флажки и разделители
Global $g_aRowLabels[4], $g_aSeparators[2], $g_aSeparatorsY[2]
Global $g_iSegLang, $g_iSegTheme, $g_iSegClose, $g_iSegUpdates
; Выбор автозакрытия при открытии: своё значение из ini не затирается, пока его не сменили
Global $g_iCloseSelInit
; Обновления: кнопка «Проверить сейчас», строка под ней, процесс проверки и её итог
Global $g_iBtnCheckNow, $g_iLblUpdate, $g_hCheckProcess = 0, $g_iCheckResult = -1
; Новая версия: за строкой точка и ссылка на архив. Место строки целиком
Global $g_aUpdateLinks[2], $g_iLnkDownload, $g_iUpdateX, $g_iUpdateY, $g_iUpdateW
Global $g_iChkIntegrate, $g_iChkFolders, $g_iChkTop, $g_iChkExtended
Global $g_iBtnGitHub, $g_iBtnIni, $g_iBtnCancel, $g_iBtnOk


_Main()


Func _Main()
	; Своё имя: у главного окна Moth имя $gc_sAppName, и настройки из него бы не открылись
	If _Singleton($gc_sAppName & ' Settings', 1) = 0 Then Exit

	_MothIniRequire()
	_MothLangInit()
	_MothRequireX64()

	_MainGUI()
	_DefineEvents()
	GUISetState(@SW_SHOW, $g_hGui)

	While 1
		Sleep(100)
	WEnd
EndFunc   ;==>_Main


; ============================================================
; GUI построение
; ============================================================

Func _MainGUI()
	$g_bDark = _IsDarkTheme()

	; Размер черновой: окончательный по содержимому ставит _FitGuiToClient.
	; WS_THICKFRAME - ради заголовка: без рамки Windows 10 рисует его ниже, чем у главного окна
	$g_hGui = GUICreate($gc_sAppName, 400, 300, -1, -1, _
			$WS_CAPTION + $WS_SYSMENU + $WS_THICKFRAME)
	Local $sFont = _FluentFontApply($g_hGui, $gc_iFontSize)

	_FluentInit($g_hGui, $sFont, $gc_iFontSize, @ScriptDir & '\Themes\Icons')
	_FluentSetTheme($g_bDark)

	Local $hFont = _FluentFont()

	; --- Колонка подписей: по самой длинной, но не уже 76, как в VCLauncher ---
	Local $aRowTexts[4] = [_Lang('Settings', 'Language', 'Language'), _Lang('Settings', 'Theme', 'Theme'), _
			_Lang('Settings', 'AutoClose', 'Auto close'), _Lang('Settings', 'Updates', 'Updates')]
	Local $iLabelW = 76
	For $sText In $aRowTexts
		$iLabelW = _Max($iLabelW, _FluentTextW($sText, $hFont) + 4)
	Next
	Local $iCtrlX = $gc_iPadX + $iLabelW + $gc_iGap
	Local $iY = $gc_iPadX

	; --- Язык: самоназвания языков не переводятся ---
	$g_aRowLabels[0] = _RowLabel($aRowTexts[0], $iY, $iLabelW)
	$g_iSegLang = _FluentSegment_Create('English|Русский', '', $iCtrlX, $iY, $gc_iRowH, _
			(_LangFile_Current() = 'Russian') ? 1 : 0)
	$iY += $gc_iRowH + $gc_iRowGap

	; --- Тема окна: иконки как у селектора темы VCLauncher. Пока тему не выбрали, стоит тема Windows ---
	$g_aRowLabels[1] = _RowLabel($aRowTexts[1], $iY, $iLabelW)
	$g_iSegTheme = _FluentSegment_Create(_Lang('Settings', 'ThemeLight', 'Light') & '|' & _Lang('Settings', 'ThemeDark', 'Dark'), _
			'SegLight|SegDark', $iCtrlX, $iY, $gc_iRowH, $g_bDark ? 1 : 0)
	$iY += $gc_iRowH + $gc_iRowGap

	; --- Автозакрытие окна Moth после обработки ---
	$g_aRowLabels[2] = _RowLabel($aRowTexts[2], $iY, $iLabelW)
	Local $sSec = _Lang('Settings', 'Seconds', 's')
	$g_iCloseSelInit = _CloseIndex(Int(_IniString_Read($gc_sMothIni, 'Config', 'CloseTimer', '10')))
	$g_iSegClose = _FluentSegment_Create('5 ' & $sSec & '|10 ' & $sSec & '|30 ' & $sSec & '|' & _Lang('Settings', 'AutoCloseOff', 'Off'), _
			'', $iCtrlX, $iY, $gc_iRowH, $g_iCloseSelInit)
	Local $sCloseTip = _Lang('Settings', 'AutoCloseTip', 'Close the Moth window this long after processing. A click on the window cancels closing')
	_FluentSegment_SetTips($g_iSegClose, $sCloseTip & '|' & $sCloseTip & '|' & $sCloseTip & '|' & $sCloseTip)
	$iY += $gc_iRowH + $gc_iRowGap

	; --- Обновления: раз в неделю, справа проверка сейчас, под строкой итог ---
	$g_aRowLabels[3] = _RowLabel($aRowTexts[3], $iY, $iLabelW)
	$g_iSegUpdates = _FluentSegment_Create(_Lang('Settings', 'UpdatesOn', 'Check') & '|' & _Lang('Settings', 'UpdatesOff', 'Do not check'), _
			'', $iCtrlX, $iY, $gc_iRowH, _IniString_Read($gc_sMothIni, 'Config', 'UpdateCheck', '1') = '0' ? 1 : 0)
	Local $sUpdatesTip = _Lang('Settings', 'UpdatesTip', 'Once a week, a single request to GitHub releases, nothing is downloaded')
	_FluentSegment_SetTips($g_iSegUpdates, $sUpdatesTip & '|' & $sUpdatesTip)
	$g_iBtnCheckNow = _FluentButton_Create('', 'Refresh', 18, $iCtrlX, $iY, $gc_iRowH, $gc_iRowH, $FLUENTBUTTON_ICON)
	GUICtrlSetTip($g_iBtnCheckNow, _Lang('Settings', 'CheckNow', 'Check now'))
	Local $iUpdatesY = $iY
	$iY += $gc_iRowH + 4
	$g_iLblUpdate = _UpdateLabel('', $iY, False)
	$g_iLnkDownload = _UpdateLabel(_Lang('Updates', 'Download', 'Download'), $iY, True)
	$g_aUpdateLinks[0] = _UpdateLabel('·', $iY, False)
	$g_aUpdateLinks[1] = $g_iLnkDownload
	$iY += 17

	; Сегменты одной ширины: правые края строк на одной линии
	Local $iRowW = _Max(_Max(_FluentSegment_Width($g_iSegLang), _FluentSegment_Width($g_iSegTheme)), _FluentSegment_Width($g_iSegClose))
	$iRowW = _Max($iRowW, _FluentSegment_Width($g_iSegUpdates) + $gc_iGap + $gc_iRowH)
	; Строка о новой версии со ссылками тоже влезает: версия ещё неизвестна, место берётся на «00.00»
	$iRowW = _Max($iRowW, _UpdateLinksW(_LangFile_Format('Updates', 'AvailableLink', 'New version %1', '00.00')) + 1)

	; --- Контекстное меню проводника ---
	$iY += $gc_iBlockGap
	$g_aSeparators[0] = _Separator($iY)
	$g_aSeparatorsY[0] = $iY
	$iY += 1 + $gc_iBlockGap

	; Фигурные скобки в подписи - клавиши, их рисует FluentCheck
	Local $aChecks[4][4] = [ _
			[_Lang('Settings', 'Integrate', 'Add to the Explorer context menu'), 0, _IsIntegrated(), 0], _
			[_Lang('Settings', 'TopPosition', 'Show Moth at the top of the list'), $gc_iIndent, _ConfigOn('ContextMenuTopPosition', 0), 0], _
			[_Lang('Settings', 'Folders', 'Show in the folder menu'), $gc_iIndent, _ConfigOn('ContextMenuFolders', 1), 0], _
			[_Lang('Settings', 'Extended', 'Show only on {SHIFT} + Right click'), $gc_iIndent, _ConfigOn('ContextMenuExtended', 0), 0]]

	Local $iContentW = $iLabelW + $gc_iGap + $iRowW
	For $i = 0 To UBound($aChecks) - 1
		; Ширина флажка: квадрат, отступ и подпись. Смена главного флажка включает остальные
		Local $iW = _FluentCheck_Width($aChecks[$i][0])
		$aChecks[$i][3] = _FluentCheck_Create($aChecks[$i][0], $gc_iPadX + $aChecks[$i][1], $iY, $iW, $gc_iCheckH, _
				$aChecks[$i][2], ($i = 0) ? '_OnEvent_Integrate' : '')
		$iContentW = _Max($iContentW, $aChecks[$i][1] + $iW)
		$iY += $gc_iCheckH + $gc_iCheckGap
	Next
	$g_iChkIntegrate = $aChecks[0][3]
	$g_iChkTop = $aChecks[1][3]
	$g_iChkFolders = $aChecks[2][3]
	$g_iChkExtended = $aChecks[3][3]
	$iY -= $gc_iCheckGap

	; --- Полоса над кнопками: ниже действия, а не настройки ---
	$iY += $gc_iBlockGap
	$g_aSeparators[1] = _Separator($iY)
	$g_aSeparatorsY[1] = $iY
	$iY += 1 + $gc_iBlockGap

	; --- Кнопки: слева описание на GitHub, дальше файл настроек, Отмена и ОК одной ширины.
	; Ряд тянется на всю ширину, зазоры между кнопками одинаковые ---
	Local $sOk = _Lang('Settings', 'OK', 'OK'), $sCancel = _Lang('Settings', 'Cancel', 'Cancel')
	Local $sIni = _Lang('Settings', 'OpenIni', 'Moth.ini')
	Local $iBtnW = _Max(_Max(_BtnW($sOk, True), _BtnW($sCancel, False)), _BtnW($sIni, False))
	$iContentW = _Max($iContentW, $gc_iRowH + ($gc_iGap + $iBtnW) * 3)
	$iBtnW = Int(($iContentW - $gc_iRowH - $gc_iGap * 3) / 3)

	Local $iClientW = $gc_iPadX * 2 + $iContentW
	; Сегменты тянутся до правого края кнопок
	$iRowW = $iContentW - $iLabelW - $gc_iGap
	_FluentSegment_SetWidth($g_iSegLang, $iRowW)
	_FluentSegment_SetWidth($g_iSegTheme, $iRowW)
	_FluentSegment_SetWidth($g_iSegClose, $iRowW)
	_FluentSegment_SetWidth($g_iSegUpdates, $iRowW - $gc_iGap - $gc_iRowH)
	_FluentButton_SetPos($g_iBtnCheckNow, $iCtrlX + $iRowW - $gc_iRowH, $iUpdatesY)
	$g_iUpdateX = $iCtrlX + 1
	$g_iUpdateY = $iUpdatesY + $gc_iRowH + 4
	$g_iUpdateW = $iRowW - 1
	For $i = 0 To UBound($g_aSeparators) - 1
		GUICtrlSetPos($g_aSeparators[$i], $gc_iPadX, $g_aSeparatorsY[$i], $iContentW, 1)
	Next

	$g_iBtnGitHub = _FluentButton_Create('', 'GitHub', 18, $gc_iPadX, $iY, $gc_iRowH, $gc_iRowH, $FLUENTBUTTON_ICON)
	GUICtrlSetTip($g_iBtnGitHub, _Lang('Settings', 'GitHubTip', 'Moth on GitHub: description and releases'))
	; Остаток от деления на три забирает Moth.ini: правый край ОК ровно по краю ряда
	Local $iOkX = $iClientW - $gc_iPadX - $iBtnW, $iCancelX = $iOkX - $gc_iGap - $iBtnW
	Local $iIniX = $gc_iPadX + $gc_iRowH + $gc_iGap
	$g_iBtnIni = _FluentButton_Create($sIni, '', 0, $iIniX, $iY, $iCancelX - $gc_iGap - $iIniX, $gc_iRowH, $FLUENTBUTTON_TEXT)
	GUICtrlSetTip($g_iBtnIni, _Lang('Settings', 'OpenIniTip', 'Open the settings file'))
	$g_iBtnOk = _FluentButton_Create($sOk, '', 0, $iOkX, $iY, $iBtnW, $gc_iRowH, $FLUENTBUTTON_ACCENT)
	$g_iBtnCancel = _FluentButton_Create($sCancel, '', 0, $iCancelX, $iY, $iBtnW, $gc_iRowH, $FLUENTBUTTON_TEXT)

	_FitGuiToClient($g_hGui, $iClientW, $iY + $gc_iRowH + $gc_iPadX)
	Local $aWin = WinGetPos($g_hGui)
	If IsArray($aWin) Then
		$g_iWinW = $aWin[2]
		$g_iWinH = $aWin[3]
	EndIf
	_ApplyTheme()
	_UpdateMenuChecks()
	_UpdateInfoText()
EndFunc   ;==>_MainGUI


Func _DefineEvents()
	GUISetOnEvent($GUI_EVENT_CLOSE, '_OnEvent_Close', $g_hGui)
	GUICtrlSetOnEvent($g_iBtnGitHub, '_OnEvent_Readme')
	GUICtrlSetOnEvent($g_iBtnIni, '_OnEvent_OpenIni')
	GUICtrlSetOnEvent($g_iBtnCancel, '_OnEvent_Close')
	GUICtrlSetOnEvent($g_iBtnOk, '_OnEvent_Ok')
	GUICtrlSetOnEvent($g_iBtnCheckNow, '_OnEvent_CheckNow')
	GUICtrlSetOnEvent($g_iLnkDownload, '_OnEvent_Download')
	_FluentMsg_Register($WM_GETMINMAXINFO, '_OnEvent_WM_GETMINMAXINFO')
	_FluentMsg_Register($WM_NCHITTEST, '_OnEvent_WM_NCHITTEST')
	OnAutoItExitRegister('_Cleanup')
EndFunc   ;==>_DefineEvents


; ============================================================
; События
; ============================================================

Func _OnEvent_Close()
	Exit
EndFunc   ;==>_OnEvent_Close


; Размер окна не меняется ни рамкой, ни прилипанием к краю экрана
Func _OnEvent_WM_GETMINMAXINFO($hWnd, $iMsg, $wParam, $lParam)
	#forceref $iMsg, $wParam
	If $hWnd <> $g_hGui Or Not $g_iWinW Then Return $GUI_RUNDEFMSG
	Local $tMINMAXINFO = DllStructCreate("int;int;" & _
			"int MaxSizeX; int MaxSizeY;" & _
			"int MaxPositionX;int MaxPositionY;" & _
			"int MinTrackSizeX; int MinTrackSizeY;" & _
			"int MaxTrackSizeX; int MaxTrackSizeY", _
			$lParam)
	Local $aKeys = ['MaxSize', 'MinTrackSize', 'MaxTrackSize']
	For $sKey In $aKeys
		DllStructSetData($tMINMAXINFO, $sKey & 'X', $g_iWinW)
		DllStructSetData($tMINMAXINFO, $sKey & 'Y', $g_iWinH)
	Next
	Return $GUI_RUNDEFMSG
EndFunc   ;==>_OnEvent_WM_GETMINMAXINFO


; Края рамки - просто граница: курсор над ними не меняется на стрелки растягивания
Func _OnEvent_WM_NCHITTEST($hWnd, $iMsg, $wParam, $lParam)
	If $hWnd <> $g_hGui Then Return $GUI_RUNDEFMSG
	Local Const $HTLEFT = 10, $HTBOTTOMRIGHT = 17, $HTBORDER = 18
	Local $iHit = _WinAPI_DefWindowProcW($hWnd, $iMsg, $wParam, $lParam)
	If $iHit >= $HTLEFT And $iHit <= $HTBOTTOMRIGHT Then Return $HTBORDER
	Return $GUI_RUNDEFMSG
EndFunc   ;==>_OnEvent_WM_NCHITTEST


Func _OnEvent_Integrate($iCtrl)
	#forceref $iCtrl
	_UpdateMenuChecks()
EndFunc   ;==>_OnEvent_Integrate


Func _OnEvent_OpenIni()
	ShellExecute(@ScriptDir & '\Moth.ini')
EndFunc   ;==>_OnEvent_OpenIni


; Сохраняет [Config] и приводит контекстное меню к выбранному состоянию. Окно прячется сразу:
; пересборка меню идёт ещё пару секунд, ждать её на экране незачем
Func _OnEvent_Ok()
	GUISetState(@SW_HIDE, $g_hGui)

	; Ini перечитывается с диска: его могли поправить руками, пока окно открыто
	Local $sIniPath = @ScriptDir & '\Moth.ini'
	Local $sIni = _ReadFileUTF8($sIniPath)
	_IniString_Write($sIni, 'Config', 'Language', $gc_aLanguages[_FluentSegment_GetSel($g_iSegLang)])
	_IniString_Write($sIni, 'Config', 'ThemeGUI', $gc_aThemes[_FluentSegment_GetSel($g_iSegTheme)])
	_IniString_Write($sIni, 'Config', 'ContextMenuFolders', _IsChecked($g_iChkFolders) ? '1' : '0')
	_IniString_Write($sIni, 'Config', 'ContextMenuTopPosition', _IsChecked($g_iChkTop) ? '1' : '0')
	_IniString_Write($sIni, 'Config', 'ContextMenuExtended', _IsChecked($g_iChkExtended) ? '1' : '0')
	_IniString_Write($sIni, 'Config', 'UpdateCheck', _FluentSegment_GetSel($g_iSegUpdates) = 0 ? '1' : '0')
	If _FluentSegment_GetSel($g_iSegClose) <> $g_iCloseSelInit Then _
			_IniString_Write($sIni, 'Config', 'CloseTimer', $gc_aCloseTimes[_FluentSegment_GetSel($g_iSegClose)])

	If Not _WriteFileUTF8($sIniPath, $sIni) Then
		; Настройки не сохранились: окно возвращается с выбором пользователя
		GUISetState(@SW_SHOW, $g_hGui)
		MsgBox(16, $gc_sAppName, _LangFile_Format('Errors', 'SaveFailed', 'Failed to save the settings file:' & @CRLF & '%1', $sIniPath), 0, $g_hGui)
		Return
	EndIf

	; Меню пересобирается всегда: язык и флажки меняют записи в реестре.
	; Ошибки реестра показывает сам Launcher.
	If _IsChecked($g_iChkIntegrate) Then
		RunWait('"' & @ScriptDir & '\Launcher.exe" addToContextMenu', @ScriptDir)
	ElseIf _IsIntegrated(False) Then
		RunWait('"' & @ScriptDir & '\Launcher.exe" removeFromContextMenu', @ScriptDir)
	EndIf
	Exit
EndFunc   ;==>_OnEvent_Ok


; ============================================================
; Тема
; ============================================================

; Тема окна в обеих темах: заголовок, подписи, подсказки. Рисованные контролы тема
; перерисовывает сама
Func _ApplyTheme()
	; Рамки полей тема не рисует: кнопки и сегменты рисует Fluent
	_FluentTheme_SetBorders(False, False)
	_FluentTheme_Apply($g_hGui)

	; Тема делает подписи прозрачными, и текст при перерисовке накладывался бы сам на себя
	For $iLbl In $g_aRowLabels
		GUICtrlSetBkColor($iLbl, $g_iFluentBg)
		GUICtrlSetColor($iLbl, $g_iFluentText2)
	Next
	For $iSep In $g_aSeparators
		GUICtrlSetBkColor($iSep, $g_iFluentDivider)
	Next
	GUICtrlSetBkColor($g_iLblUpdate, $g_iFluentBg)
	For $iLbl In $g_aUpdateLinks
		GUICtrlSetBkColor($iLbl, $g_iFluentBg)
		GUICtrlSetColor($iLbl, ($iLbl = $g_iLnkDownload) ? $g_iFluentAccent : $g_iFluentText3)
	Next
EndFunc   ;==>_ApplyTheme


; ============================================================
; Прочее
; ============================================================

; Подпись строки: по вертикали по центру строки высотой $gc_iRowH
Func _RowLabel($sText, $iY, $iW)
	Local $iLbl = GUICtrlCreateLabel($sText, $gc_iPadX, $iY, $iW, $gc_iRowH, BitOR($SS_CENTERIMAGE, $SS_LEFT))
	_FluentDockFixed($iLbl)
	Return $iLbl
EndFunc   ;==>_RowLabel


; Строка под «Обновлениями» и ссылка за ней. Место ставит _SetUpdateInfo, ссылки до неё скрыты
Func _UpdateLabel($sText, $iY, $bLink)
	Local $iLbl = GUICtrlCreateLabel($sText, $gc_iPadX, $iY, 100, 17, $bLink ? $SS_NOTIFY : 0)
	_FluentDockFixed($iLbl)
	If $sText = '' Then Return $iLbl
	GUICtrlSetState($iLbl, $GUI_HIDE)
	If $bLink Then _FluentHandCursor($iLbl)
	Return $iLbl
EndFunc   ;==>_UpdateLabel


Func _Separator($iY)
	Local $iSep = GUICtrlCreateLabel('', $gc_iPadX, $iY, 100, 1)
	_FluentDockFixed($iSep)
	Return $iSep
EndFunc   ;==>_Separator


; Ширина кнопки: подпись с полями, но не уже 90, как в VCLauncher
Func _BtnW($sText, $bAccent)
	Return _Max(90, _FluentTextW($sText, _FluentFont(0, $bAccent)) + $gc_iPadX * 2)
EndFunc   ;==>_BtnW


; Флажки меню доступны, только когда Moth встраивается в меню
Func _UpdateMenuChecks()
	Local $bOn = _IsChecked($g_iChkIntegrate)
	_FluentCheck_SetEnabled($g_iChkFolders, $bOn)
	_FluentCheck_SetEnabled($g_iChkTop, $bOn)
	_FluentCheck_SetEnabled($g_iChkExtended, $bOn)
EndFunc   ;==>_UpdateMenuChecks


Func _IsChecked($iCtrl)
	Return _FluentCheck_Get($iCtrl)
EndFunc   ;==>_IsChecked


; Сегмент автозакрытия для числа секунд: своё значение из ini - ближайший вариант
Func _CloseIndex($iSec)
	If $iSec <= 0 Then Return 3
	If $iSec < 8 Then Return 0
	If $iSec < 20 Then Return 1
	Return 2
EndFunc   ;==>_CloseIndex


Func _ConfigOn($sKey, $iDefault)
	Return _IniString_Read($gc_sMothIni, 'Config', $sKey, $iDefault) = 1
EndFunc   ;==>_ConfigOn


; Меню Moth уже в проводнике. $bThisCopy - и указывает на эту папку:
; после переноса папки меню считается невстроенным и при ОК пересоберётся.
Func _IsIntegrated($bThisCopy = True)
	Local $sIcon = RegRead('HKEY_CLASSES_ROOT\SystemFileAssociations\.png\shell\moth', 'Icon')
	If @error Then $sIcon = RegRead('HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Directory\shell\moth', 'Icon')
	If @error Or $sIcon = '' Then Return False
	If Not $bThisCopy Then Return True
	Return $sIcon = @ScriptDir & '\Moth.exe'
EndFunc   ;==>_IsIntegrated


; Доводит клиентскую область окна до заданной, сохраняя его центр
Func _FitGuiToClient($hWnd, $iClientW, $iClientH)
	Local $aWin = WinGetPos($hWnd)
	Local $aClient = WinGetClientSize($hWnd)
	If Not IsArray($aWin) Or Not IsArray($aClient) Then Return

	Local $iW = $iClientW + ($aWin[2] - $aClient[0])
	Local $iH = $iClientH + ($aWin[3] - $aClient[1])
	WinMove($hWnd, '', $aWin[0] + Int(($aWin[2] - $iW) / 2), $aWin[1] + Int(($aWin[3] - $iH) / 2), $iW, $iH)
EndFunc   ;==>_FitGuiToClient


; ============================================================
; Обновления
; ============================================================

; Проверка сейчас, даже если автопроверка выключена. Запрос делает Launcher.exe
Func _OnEvent_CheckNow()
	If $g_hCheckProcess Then Return
	$g_hCheckProcess = _MothUpdateCheckStart()
	If Not $g_hCheckProcess Then
		$g_iCheckResult = 1
		_UpdateInfoText()
		Return
	EndIf
	_FluentButton_SetEnabled($g_iBtnCheckNow, False)
	_SetUpdateInfo(_Lang('Updates', 'Checking', 'Checking…'), $g_iFluentText3, False)
	AdlibRegister('_CheckNowTick', 300)
EndFunc   ;==>_OnEvent_CheckNow


Func _CheckNowTick()
	Local $iCode = _MothUpdateCheckPoll($g_hCheckProcess)
	If $iCode = -1 Then Return
	AdlibUnRegister('_CheckNowTick')
	$g_iCheckResult = $iCode
	_FluentButton_SetEnabled($g_iBtnCheckNow, True)
	_UpdateInfoText()
EndFunc   ;==>_CheckNowTick


Func _OnEvent_Download()
	ShellExecute(_UpdateCheck_DownloadUrl($gc_sUpdateRepo, $gc_sUpdateAsset))
EndFunc   ;==>_OnEvent_Download


; Описание на языке окна: русское - README репозитория, английское - отдельный файл
Func _OnEvent_Readme()
	ShellExecute((_LangFile_Current() = 'Russian') ? _UpdateCheck_ReadmeUrl($gc_sUpdateRepo) : _
			_UpdateCheck_ReadmeUrl($gc_sUpdateRepo, 'README.EN.md', 'Main'))
EndFunc   ;==>_OnEvent_Readme


; Строка под «Обновлениями»: новая версия со ссылками, итог проверки или дата прошлой
Func _UpdateInfoText()
	Local $sLatest = _MothUpdateAvailable()
	If $sLatest <> '' Then
		_SetUpdateInfo(_LangFile_Format('Updates', 'AvailableLink', 'New version %1', $sLatest), $g_iFluentText3, True)
	ElseIf $g_iCheckResult = 1 Then
		_SetUpdateInfo(_Lang('Updates', 'CheckFailed', 'Could not reach GitHub'), $g_iFluentText3)
	ElseIf $g_iCheckResult = 0 Then
		_SetUpdateInfo(_Lang('Updates', 'UpToDate', 'You have the latest version'), $g_iFluentText3)
	Else
		Local $sLast = _IniString_Read(_ReadFileUTF8(@ScriptDir & '\Moth.ini'), 'Config', 'LastUpdateCheck')
		If $sLast = '' Then
			_SetUpdateInfo(_Lang('Updates', 'LastCheckNever', 'No checks yet'), $g_iFluentText3)
		Else
			_SetUpdateInfo(_LangFile_Format('Updates', 'LastCheck', 'Last check: %1', _
					StringRegExpReplace($sLast, '^(\d{4})\.(\d{2})\.(\d{2})$', '$3.$2.$1')), $g_iFluentText3)
		EndIf
	EndIf
EndFunc   ;==>_UpdateInfoText


; $bLinks - строка сужается по тексту, за ней встаёт ссылка на архив
Func _SetUpdateInfo($sText, $iColor, $bLinks = False)
	GUICtrlSetData($g_iLblUpdate, $sText)
	GUICtrlSetColor($g_iLblUpdate, $iColor)
	Local $iX = $g_iUpdateX, $iW = $bLinks ? _FluentGdiTextW($sText, $g_iLblUpdate) + 1 : $g_iUpdateW
	GUICtrlSetPos($g_iLblUpdate, $iX, $g_iUpdateY, $iW, 17)

	For $iLnk In $g_aUpdateLinks
		If $bLinks Then
			$iX += $iW + 3
			$iW = _FluentGdiTextW(GUICtrlRead($iLnk), $iLnk) + 1
			GUICtrlSetPos($iLnk, $iX, $g_iUpdateY, $iW, 17)
		EndIf
		GUICtrlSetState($iLnk, $bLinks ? $GUI_SHOW : $GUI_HIDE)
	Next
EndFunc   ;==>_SetUpdateInfo


; Ширина строки о новой версии вместе со ссылкой, как её ставит _SetUpdateInfo
Func _UpdateLinksW($sText)
	Local $iW = _FluentGdiTextW($sText, $g_iLblUpdate) + 1
	For $iLnk In $g_aUpdateLinks
		$iW += 3 + _FluentGdiTextW(GUICtrlRead($iLnk), $iLnk) + 1
	Next
	Return $iW
EndFunc   ;==>_UpdateLinksW


Func _Cleanup()
	If $g_hCheckProcess Then
		AdlibUnRegister('_CheckNowTick')
		DllCall('kernel32.dll', 'bool', 'CloseHandle', 'handle', $g_hCheckProcess)
	EndIf
	_FluentShutdown()
EndFunc   ;==>_Cleanup
