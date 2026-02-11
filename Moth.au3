#pragma compile(Out, ..\MothPortable\Moth.exe)
#pragma compile(Icon, ..\MothPortable\themes\Moth.ico)
#pragma compile(LegalCopyright, © MarkovTrue)
#pragma compile(Comments, Program made by MarkovTrue)

#NoTrayIcon
#RequireAdmin
Opt("GUIOnEventMode", 1) ; Включаем режим OnEvent

#include <FileOperations.au3>
#include <GUIConstants.au3>
#include <GUIConstantsEx.au3>
#include <GuiImageList.au3>
#include <GuiListView.au3>
#include <ListviewConstants.au3>
#include <Misc.au3>
#include <WinAPI.au3>
#include <WindowsConstants.au3>

#include <Include\GUIDarkMode.au3>
#include <Include\ImageGetInfo.au3>

#include <Common\ExplorerIcon.au3>
#include <Common\MothCommon.au3>


; Костанты статуса обработки файла
Global Const $STATUS_SKIPPED = 1
Global Const $STATUS_NOT_SUPPORTED = 2
Global Const $STATUS_SAVE_ERROR = 3
Global Const $STATUS_SKIPPED_FOLDER = 4
Global Const $STATUS_APP_ERROR = 5

; Константы для оптимизации
Global Const $GUI_UPDATE_INTERVAL = 250 ; Интервал обновления GUI в мс
Global Const $INITIAL_ARRAY_SIZE = 1000 ; Начальный размер чанка файлов

; Константы минимальных размеров окна
Global Const $GUI_MIN_WIDTH = 440
Global Const $GUI_MIN_HEIGHT = 157 ; Ровно на 3 строки в высоту

; Оптимизированный массив файлов: [индекс][0-источник, 1-путь, 2-действие, 3-команда, 4-результат, 5-вGUI]
Global $aFileListData[$INITIAL_ARRAY_SIZE][6]
Global $iCurrentFileCount = 0


If @OSArch = 'X86' Then
	MsgBox(48, $sAppName, 'Поддерживаются только 64-битные ОС.' & @CR & 'Приложение будет закрыто.')
	Exit
EndIf

; Проверка на множественный запуск
_CheckSingleInstance()


Global $bShowLog = False


Global $sGlobalLogs = '', $nLogDirSize, $aDropList, $sAllWinnerSize = 0, $sAllFileSize = 0, _
		$hGui, $hListView, $nInx = 1, $nCurrProgressMaxValue, $iLastProcessPid

Global $ContextMenuItem1, $ContextMenuItem2, $hOkButton, $hDropDummy, $ContextMenu, $hGraphic, $hProgress, $Info
Global $Timer, $Secs, $Mins, $Hour, $bTimerState = True, $hImageIcons
Global $iGuiWidth = 527, $iGuiHeight = 167, $nItemFileColumnWidth, $isComplete = False
Global $nLastUpdatedIndex = 0 ; Индекс последнего успешно обновленного элемента
Global $bStarting = False
Global $aIconMap[0][2]

Global $nProcCount = 1
If EnvGet("NUMBER_OF_PROCESSORS") > 0 Then $nProcCount = EnvGet("NUMBER_OF_PROCESSORS")


If Not FileExists($sImgPath) Then DirCreate($sImgPath)

_MainGUI()
_DefineEvents()
_SetPositionOnDesktop()


Func _MainGUI()

	$hGui = GUICreate($sAppName, $iGuiWidth, $iGuiHeight, 0, 0, $WS_CAPTION + $WS_THICKFRAME, $WS_EX_ACCEPTFILES)

	; Создадим ListView
	$hListView = GUICtrlCreateListView("", 6, 2, $iGuiWidth - 13, 122, _
			BitOR($LVS_NOSORTHEADER, $LVS_SINGLESEL, $LVS_REPORT), _
			BitOR($LVS_EX_INFOTIP, $LVS_EX_FULLROWSELECT))
	GUICtrlSetResizing($hListView, $GUI_DOCKBORDERS)
	GUICtrlSetState($hListView, $GUI_DROPACCEPTED)

	Global $aListviewColumNames = ["Файл", "Размер", "Новый", "Процент", "Сжатие", "Задача"]
	_GUICtrlListView_InsertColumn($hListView, 0, $aListviewColumNames[0], 172)
	_GUICtrlListView_InsertColumn($hListView, 1, $aListviewColumNames[1], 70, $LVCFMT_RIGHT)
	_GUICtrlListView_InsertColumn($hListView, 2, $aListviewColumNames[2], 70)
	_GUICtrlListView_InsertColumn($hListView, 3, $aListviewColumNames[3], 65, $LVCFMT_RIGHT)
	_GUICtrlListView_InsertColumn($hListView, 4, $aListviewColumNames[4], 65)
	_GUICtrlListView_InsertColumn($hListView, 5, $aListviewColumNames[5], 65)

	$hImageIcons = _GUIImageList_Create(16, 16, 5, 3)
	_GUICtrlListView_SetImageList($hListView, $hImageIcons, 1)

	; Контекстное меню ListView
	$DummyMenu = GUICtrlCreateDummy()
	$ContextMenu = GUICtrlCreateContextMenu($DummyMenu)
	$ContextMenuItem1 = GUICtrlCreateMenuItem("Показать в проводнике", $ContextMenu)
	$ContextMenuItem2 = GUICtrlCreateMenuItem("Копировать как путь", $ContextMenu)

;~ $hGraphic = GUICtrlCreateLabel('', 0, 2 + 124, $iGuiWidth, 40)
;~ GUICtrlSetState($hGraphic, $GUI_DISABLE)
;~ GUICtrlSetResizing($hGraphic, $GUI_DOCKLEFT + $GUI_DOCKBOTTOM + $GUI_DOCKRIGHT + $GUI_DOCKHEIGHT)

	$hGraphic = GUICtrlCreateLabel('', 0, 1, $iGuiWidth, 124)
	GUICtrlSetState($hGraphic, $GUI_DISABLE)
	GUICtrlSetResizing($hGraphic, $GUI_DOCKBORDERS)

	$hProgress = GUICtrlCreateProgress(6, 125, $iGuiWidth - 13, 5)
	GUICtrlSetResizing($hProgress, $GUI_DOCKLEFT + $GUI_DOCKBOTTOM + $GUI_DOCKRIGHT + $GUI_DOCKHEIGHT)

	$Info = GUICtrlCreateLabel('', 10, 142, $iGuiWidth - 110, 17, $SS_LEFT)
	GUICtrlSetResizing($Info, $GUI_DOCKLEFT + $GUI_DOCKBOTTOM + $GUI_DOCKRIGHT + $GUI_DOCKHEIGHT)
;~ GUICtrlSetBkColor(-1, 0x191919)

	$hOkButton = GUICtrlCreateButton("OK (10)", $iGuiWidth - 68, 137, 60, 22)
	GUICtrlSetResizing($hOkButton, $GUI_DOCKRIGHT + $GUI_DOCKBOTTOM + $GUI_DOCKWIDTH + $GUI_DOCKHEIGHT)
	GUICtrlSetState($hOkButton, $GUI_DISABLE)

;~ $Icon = GUICtrlCreateIcon('', -1, 398, 137, 16, 16)
;~ GUICtrlSetResizing(-1, $GUI_DOCKRIGHT + $GUI_DOCKBOTTOM + $GUI_DOCKWIDTH + $GUI_DOCKHEIGHT)
;~ GUICtrlSetTip(-1, 'Open Settings')
;~ GUICtrlSetCursor(-1, 0)
;~ GUICtrlSetImage(-1, _GetThemePath() & '\gear.ico')
;~ GUICtrlSetOnEvent(-1, "_OnEventSettingsButton")

;~ $hSettingsButton = GUICtrlCreateButton(" ", 356, 134, 22, 22)
;~ GUICtrlSetResizing($hSettingsButton, $GUI_DOCKRIGHT + $GUI_DOCKBOTTOM + $GUI_DOCKWIDTH + $GUI_DOCKHEIGHT)
;~ GUICtrlSetOnEvent($hSettingsButton, "_OnEventSettingsButton")
;~ GUICtrlSetImage($hSettingsButton, _GetThemePath() & '\gear.ico')

	$hDropDummy = GUICtrlCreateDummy()

	_SetTheme()
EndFunc   ;==>_MainGUI


Func _DefineEvents()
	GUICtrlSetOnEvent($ContextMenuItem1, "_OnEventContextMenuItem1")
	GUICtrlSetOnEvent($ContextMenuItem2, "_OnEventContextMenuItem2")
	GUICtrlSetOnEvent($hOkButton, "_OnEventOkButton")
	GUICtrlSetOnEvent($hDropDummy, "_OnEventDropped")
	GUISetOnEvent($GUI_EVENT_CLOSE, "_OnEventClose")
	GUISetOnEvent($GUI_EVENT_PRIMARYDOWN, "_OnEventClickDown")
	GUISetOnEvent($GUI_EVENT_SECONDARYDOWN, "_OnEventClickDown")
	GUIRegisterMsg($WM_DROPFILES, "_OnEvent_DROPFILES")

	; Функция WM_GETMINMAXINFO выполняется при перемещении окна, сворачивании и изменении размеров.
	; Позволяет установить пределы увеличения и уменьшения окна, как по горизонтали, так и по вертикали индивидуально.
	; А также позицию и размеры развёрнутого состояния. Установочные параметры можно игнорировать указав только необходимые параметры
	GUIRegisterMsg($WM_GETMINMAXINFO, "_OnEvent_GETMINMAXINFO")

;~ GUIRegisterMsg($WM_WINDOWPOSCHANGING, "_OnEvent_SIZE")

	AdlibRegister("_CheckFileListUpdate", 200)
	GUIRegisterMsg($WM_NOTIFY, "WM_NOTIFY")
EndFunc   ;==>_DefineEvents


Func _SetTheme()

	If _IsDarkTheme() == True Then

		_GUISetDarkTheme($hGui)
		_GUICtrlAllSetDarkTheme($hGui)

		; Фон гуишки
;~ GUISetBkColor(0x2a2a2a, $hGui)
		; цвет текста
;~ GUICtrlSetColor($Info, 0xffffff)

		; Цвет таблицы
		_GUICtrlListView_SetBkColor($hListView, 0x202020)
		_GUICtrlListView_SetTextBkColor($hListView, 0x202020)

;~ _GUICtrlListView_SetTextColor($hListView, 0xffffff)
;~ ; Цвет подложки, которая ниже ListView
;~ GUICtrlSetBkColor($hGraphic, 0x202020)

		; Цвет подложки под таблицу
		GUICtrlSetBkColor($hGraphic, 0x202020)

;~ ; Кнопка ОК
;~ GUICtrlSetBkColor($hOkButton, 0x2a2a2a)
;~ GUICtrlSetColor($hOkButton, 0xffffff)
;~ ; Кнопка Настройки
;~ GUICtrlSetBkColor($hSettingsButton, 0x2a2a2a)
;~ GUICtrlSetColor($hSettingsButton, 0xffffff)
;~ ; Цвет фона текста
;~ GUICtrlSetBkColor($hProgress, 0x202020)
;~ GUICtrlSetBkColor($Info, 0x202020)

	Else
;~ ; Фон гуишки
;~ GUISetBkColor(0xffffff, $hGui)

		; Цвет подложки, которая ниже ListView
		GUICtrlSetBkColor($hGraphic, 0xffffff)

;~ ; Цвет фона текста
;~ GUICtrlSetBkColor($hProgress, 0xf0f0f0)
;~ GUICtrlSetBkColor($Info, 0xf0f0f0)
	EndIf

EndFunc   ;==>_SetTheme

While 1
	Sleep(100)
WEnd


Func _OnEventClose()
	ProcessClose($iLastProcessPid)
	DirRemove($sLogPathDir, 1)
	DirRemove($sImgPath, 1)

	If $bShowLog = True Then
		$sLogPathFile = $sTmpPath & '\' & @HOUR & @MIN & @SEC & @MSEC & '.txt'
		FileWriteLine($sLogPathFile, $sGlobalLogs)
		ShellExecute($sLogPathFile)
	EndIf

	Exit
EndFunc   ;==>_OnEventClose


Func _SetPositionOnDesktop()
	Local $aPosGui, $tRect, $nGuiX, $nGuiY, $nMargin = 6
	$aPosGui = WinGetPos($hGui)
	$tRect = _WinAPI_GetWorkArea()
	$nGuiX = DllStructGetData($tRect, 'Right') - $nMargin - $aPosGui[2]
	$nGuiY = DllStructGetData($tRect, 'Bottom') - $nMargin - $aPosGui[3]
	WinMove($hGui, "", $nGuiX, $nGuiY)
EndFunc   ;==>_SetPositionOnDesktop


Func _OnEvent_DROPFILES($hWnd, $iMsg, $wParam, $lParam)
	#forceref $hWnd, $iMsg, $lParam
	Local $iSize, $pFileName
	; Get number of files dropped
	Local $aRet = DllCall("shell32.dll", "int", "DragQueryFileW", "hwnd", $wParam, "int", 0xFFFFFFFF, "ptr", 0, "int", 0)
	; Reset array to correct size
	Dim $aDropList[$aRet[0] + 1] = [$aRet[0]]
	; And add item names
	For $i = 0 To $aRet[0] - 1
		$aRet = DllCall("shell32.dll", "int", "DragQueryFileW", "hwnd", $wParam, "int", $i, "ptr", 0, "int", 0)
		$iSize = $aRet[0] + 1
		$pFileName = DllStructCreate("wchar[" & $iSize & "]")
		DllCall("shell32.dll", "int", "DragQueryFileW", "hwnd", $wParam, "int", $i, "ptr", DllStructGetPtr($pFileName), "int", $iSize)
		$aDropList[$i + 1] = DllStructGetData($pFileName, 1)
		$pFileName = 0
	Next
	; Send the count to trigger the drop function in the main loop
	GUICtrlSendToDummy($hDropDummy, $aDropList[0])
EndFunc   ;==>_OnEvent_DROPFILES


Func _OnEventDropped()
	Local $sActionName = '', $aActionList

	$aActionList = _IniString_ReadSection($sMothINI, 'Action.DragAndDrop')
	If @error Then Return

	For $i = 1 To $aActionList[0][0]
		; Пропустим, если значение не равно единице
		If $aActionList[$i][1] <> 1 Then ContinueLoop
		; Пропустим, если название команды не соответствует шаблону
		If StringLeft($aActionList[$i][0], 5) <> 'Moth.' Then ContinueLoop
		; Moth.CompressionLossless
		$sActionName = $aActionList[$i][0]
	Next

	If $sActionName = '' Then
		MsgBox(48, $sAppName, 'Действие при перетаскивании отсутствует в настройках или не корректно настроено')
		Return
	EndIf

	For $i = 1 To $aDropList[0]
		_AddToFileListData($aDropList[$i], $sActionName, 'Action.DragAndDrop ' & @HOUR & ':' & @MIN & ':' & @SEC)
	Next

EndFunc   ;==>_OnEventDropped



Func WM_NOTIFY($hWnd, $iMsg, $iwParam, $ilParam)
	#forceref $hWnd, $iMsg, $iwParam

	Local $hDCBrush = _WinAPI_GetStockObject($DC_BRUSH)
	Local $hDCPen = _WinAPI_GetStockObject($DC_PEN)
	Local $tagNMCUSTOMDRAW = "struct;" & $tagNMHDR & ";dword dwDrawStage;handle hdc;" & _
			$tagRECT & ";dword_ptr dwItemSpec;uint uItemState;lparam lItemlParam;endstruct"
	Local $iLastCol
	Local $iIndex

	Local $tNMHDR = DllStructCreate($tagNMHDR, $ilParam)
	Local $hWndFrom = HWnd(DllStructGetData($tNMHDR, "hWndFrom"))
	Local $iCode = DllStructGetData($tNMHDR, "Code")
	Local $hWndListView = IsHWnd($hListView) ? $hListView : GUICtrlGetHandle($hListView)
	Local $hHeader = _GUICtrlListView_GetHeader($hWndListView)

	Switch $hWndFrom
		Case $hHeader
			If $iCode = $NM_CUSTOMDRAW Then
				Local $tNMCD = DllStructCreate($tagNMCUSTOMDRAW, $ilParam)
				Local $dwStage = DllStructGetData($tNMCD, "dwDrawStage")

				Switch $dwStage
					Case $CDDS_PREPAINT
						$iLastCol = _GUICtrlHeader_GetItemCount($hHeader) - 2
						Return $CDRF_NOTIFYITEMDRAW

					Case $CDDS_ITEMPREPAINT
						$iIndex = DllStructGetData($tNMCD, "dwItemSpec")
						Local $hDC = DllStructGetData($tNMCD, "hdc")
						Local $tRect = DllStructCreate($tagRECT)
						For $i = 0 To 3
							DllStructSetData($tRect, $i + 1, DllStructGetData($tNMCD, 6 + $i))
						Next

						_WinAPI_SelectObject($hDC, $hDCBrush)
						_WinAPI_SelectObject($hDC, $hDCPen)
						_WinAPI_SetBkMode($hDC, 1)

						If _IsDarkTheme() Then
							_WinAPI_SetDCBrushColor($hDC, 0x191919)
							_WinAPI_SetDCPenColor($hDC, 0x191919)
							_WinAPI_Rectangle($hDC, $tRect)
							_WinAPI_SetDCPenColor($hDC, 0x434343)
							_WinAPI_SetTextColor($hDC, _WinAPI_SwitchColor(0xFDFDFD))
						Else
							_WinAPI_SetDCPenColor($hDC, 0xE5E5E5)
						EndIf

						If $iIndex <= $iLastCol Then
							_WinAPI_DrawLine($hDC, $tRect.Right - 2, $tRect.Top + 1, $tRect.Right - 2, $tRect.Bottom)
						EndIf

						If $iIndex = 1 Or $iIndex = 3 Then
							$tRect.Right -= 9
							_WinAPI_DrawText($hDC, $aListviewColumNames[$iIndex], $tRect, $DT_SINGLELINE + $DT_VCENTER + $DT_RIGHT)
						Else
							$tRect.Left += 6
							_WinAPI_DrawText($hDC, $aListviewColumNames[$iIndex], $tRect, $DT_SINGLELINE + $DT_VCENTER)
						EndIf

						Return $CDRF_SKIPDEFAULT
				EndSwitch
			EndIf

		Case $hWndListView
			If $iCode = $NM_RCLICK Then
				Local $tInfo = DllStructCreate($tagNMITEMACTIVATE, $ilParam)
				$iIndex = DllStructGetData($tInfo, "Index")
				If $iIndex <> -1 Then
					; $iLast_LV_Index = $iIndex
					ShowMenu($hWnd, $ContextMenu, $hListView, 1)
				EndIf
			ElseIf $iCode = $NM_DBLCLK Then
				Local $tInfo = DllStructCreate($tagNMITEMACTIVATE, $ilParam)
				$iIndex = DllStructGetData($tInfo, "Index")
				If $iIndex <> -1 Then
					Local $iInx = _GUICtrlListView_GetSelectedIndices($hListView) + 1
					Local $sImgPath = $aFileListData[$iInx][1]
					If FileExists($sImgPath) Then
						ShellExecute($sImgPath)
					EndIf
				EndIf
			EndIf
	EndSwitch

	Return $GUI_RUNDEFMSG
EndFunc   ;==>WM_NOTIFY



Func _OnEventContextMenuItem1()
	Local $iInx, $sImgPath, $sImgName
;~ 	MsgBox(4160, "Информация", "Индексы выделенных: " & _GUICtrlListView_GetSelectedIndices($hListView))

	$iInx = _GUICtrlListView_GetSelectedIndices($hListView) + 1
	$sImgPath = $aFileListData[$iInx][1]
	$sImgName = _GetFileName($sImgPath)
	Local $aList[1] = [$sImgName] ; массив с файлом, который будем выделять
	_WinAPI_ShellOpenFolderAndSelectItems(StringTrimRight($sImgPath, StringLen($sImgName)), $aList, 0)

EndFunc   ;==>_OnEventContextMenuItem1


Func _OnEventContextMenuItem2()
	Local $iInx, $sImgPath

	$iInx = _GUICtrlListView_GetSelectedIndices($hListView) + 1
	$sImgPath = $aFileListData[$iInx][1]
	ClipPut($sImgPath)

EndFunc   ;==>_OnEventContextMenuItem2


Func _OnEventOkButton()
	_OnEventClose()
EndFunc   ;==>_OnEventOkButton


Func _OnEventSettingsButton()
	ShellExecute(@ScriptDir & '\Settings.exe')
EndFunc   ;==>_OnEventSettingsButton

Func _OnEventClickDown()
	$bTimerState = False
	GUICtrlSetData($hOkButton, "OK")
EndFunc   ;==>_OnEventClickDown


Func _CompressFile()
	Local $sListLength = $aFileListData[0][0], _
			$sPathFile, _
			$sExtensionFile, _
			$sFileSize, _
			$sActionName, $sActionCommand, $sLogLine

	If Not $sListLength Then Return

	For $i = $nInx To $aFileListData[0][0]
		; Чек, надо ли конвертить
		If Not StringLen($aFileListData[$i][4]) Then ; 456 КБ|456 КБ|1 %|losless
			$sPathFile = $aFileListData[$i][1] ; C:\Users\STEEL\Desktop\photo_2023-05-03_05-42-57.jpg
			$sActionName = $aFileListData[$i][2] ; Moth.CompressionLossless
			$sActionCommand = $aFileListData[$i][3] ; losless
			$sExtensionFile = _GetFileExtension($sPathFile)
			$sFileSize = FileGetSize($sPathFile)
			$nInx = $i
			_SetLabel('Прогресс')
			$nCurrProgressMaxValue = Round($nInx / $aFileListData[0][0] * 100)
			If $nInx > 1 Then
				_SetProcess(Round(Int($nInx - 1) / $aFileListData[0][0] * 100))
			EndIf

			; Логирование
			$sLogLine = _StringCompare($sActionCommand, 'loss') ? $sExtensionFile : $sActionCommand
			_AddLogLine(@CR & StringFormat("%03s", $nInx) & ' ' & $sActionName & ' (' & $sLogLine & ')')
			_AddLogLine('    ' & $sPathFile)

			Switch $sActionCommand
				Case 'loss' ; Сжатие без потерь
					Switch $sExtensionFile
						Case 'avif'
							_CompressionAvif($sPathFile, $sFileSize, $sExtensionFile, $sActionName)
						Case 'bmp'
							_CompressionBmp($sPathFile, $sFileSize, $sExtensionFile, $sActionName)
						Case 'gif'
							_CompressionGif($sPathFile, $sFileSize, $sExtensionFile, $sActionName)
						Case 'jfif'
							_CompressionJfif($sPathFile, $sFileSize, $sExtensionFile, $sActionName)
						Case 'jpg', 'jpe', 'jpeg'
							_CompressionJpg($sPathFile, $sFileSize, $sExtensionFile, $sActionName)
						Case 'png'
							_CompressionPng($sPathFile, $sFileSize, $sExtensionFile, $sActionName)
						Case 'webp'
							_CompressionWebP($sPathFile, $sFileSize, $sExtensionFile, $sActionName)
						;~ Case 'heic'
						;~ 	_CompressionHeic($sPathFile, $sFileSize, $sExtensionFile, $sActionName)
						Case Else
							_UpdateGUI()
							_ShowResult($sPathFile, $sFileSize, 0, _IsDir($sPathFile) ? $STATUS_SKIPPED_FOLDER : $STATUS_SKIPPED)
					EndSwitch
				Case 'lossy' ; Сжатие с потерями
					_CompressionLossy($sPathFile, $sFileSize, $sExtensionFile, $sActionName)
				Case 'web' ; Сжатие для WEB
					_CompressionForWeb($sPathFile, $sFileSize, $sExtensionFile, $sActionName)
				Case 'toPng' ; -> png
					_ConvertToPng($sPathFile, $sFileSize, $sExtensionFile, $sActionName)
				Case 'toWebp' ; -> webp
					_ConvertToWebp($sPathFile, $sFileSize, $sExtensionFile, $sActionName)
				Case 'toJpg' ; -> jpg
					_ConvertToJpg($sPathFile, $sFileSize, $sExtensionFile, $sActionName)
				Case Else
					If StringInStr($sActionCommand, 'cq') Then ; изменение палитры, например cq256
						_ColorQuantization($sPathFile, $sFileSize, $sExtensionFile, $sActionName)
					ElseIf StringInStr($sActionCommand, 'percent') Then ; percent50
						_ResizePercent($sPathFile, $sFileSize, $sExtensionFile, $sActionName)
					ElseIf StringInStr($sActionCommand, 'resize') Then ; resize1000x1000x0
						_ResizePixel($sPathFile, $sFileSize, $sExtensionFile, $sActionName)
					Else
						_UpdateGUI()
						_ShowResult($sPathFile, $sFileSize, 0, _IsDir($sPathFile) ? $STATUS_SKIPPED_FOLDER : $STATUS_SKIPPED)
					EndIf
			EndSwitch

			; Логирование
			If $nInx = $sListLength Then

				_UpdateGUI()

				$isComplete = True

				_SetProcess(100)

				_StartTimerState()

				_SetLabel('Завершено')

;~ _ArrayDisplay($aFileListData)
;~ _ArrayDisplay($aIconMap)
			EndIf
		EndIf
	Next

EndFunc   ;==>_CompressFile

Func _SetLabel($sLabel)
	Local $nCompressingPrecent = _GetCompressingPrecent($sAllWinnerSize, $sAllFileSize)
	Local $sFileSize = _GetFileSizeStr($sAllFileSize - $sAllWinnerSize)
	GUICtrlSetData($Info, _
			$sLabel & ': ' & $nInx & '/' & $aFileListData[0][0] & _
			($nCompressingPrecent <> '' ? '    Сжатие: ' & $nCompressingPrecent : '') & _
			($sFileSize <> '' ? '    Размер: -' & $sFileSize : ''))

	If $sLabel = 'Завершено' Then
		WinSetTitle($hGui, '', $sAppName & '  [100%]')
	Else
		WinSetTitle($hGui, '', $sAppName & '  [' & Round(Int($nInx - 1) / $aFileListData[0][0] * 100) & '%]')
	EndIf

EndFunc   ;==>_SetLabel

Func _GetFileSize($sPathFile)
	Local $sFileSize = FileGetSize($sPathFile)
	Return _GetFileSizeStr($sFileSize)
EndFunc   ;==>_GetFileSize

Func _GetFilePatch($sPathFile)
	Return StringStripWS($sPathFile, 3)
EndFunc   ;==>_GetFilePatch

Func _GetFilePerePatch($sPathFile) ; Путь до файла, исключив его название и '/'
	Return StringTrimRight($sPathFile, StringLen(StringRegExpReplace($sPathFile, '^.*\\', '')) + 1)
EndFunc   ;==>_GetFilePerePatch

Func _SetProcess($i)
	GUICtrlSetData($hProgress, $i)
EndFunc   ;==>_SetProcess

Func _SetStepProcess($nStep)
	Local $nCurrProgress = GUICtrlRead($hProgress)
	If $nCurrProgress < Int($nCurrProgressMaxValue - 2) Then
		GUICtrlSetData($hProgress, $nCurrProgress + $nStep)
	EndIf
EndFunc   ;==>_SetStepProcess


Func _UpdateGUI()
	If $isComplete Then Return

	Static $lastUpdate = 0
	If TimerDiff($lastUpdate) < $GUI_UPDATE_INTERVAL And Not ($nInx = $aFileListData[0][0]) Then Return
	$lastUpdate = TimerInit()

	Local $aLineSplit, $sPathFile, $sFileName
	Local $sFileSizeCurrent, $sFileSizeNew, $sFileCompressingSize, $sFileCompressingPercent, $sPathFileStatus
	Local $bNeedUpdate = False

	If Not $aFileListData[$aFileListData[0][0]][5] Then
		_GUICtrlListView_BeginUpdate($hListView)
		$bNeedUpdate = True
	EndIf

	; Начинаем с последнего обновленного индекса
	For $i = $nLastUpdatedIndex + 1 To $aFileListData[0][0]
		$sPathFile = $aFileListData[$i][1]
		$sFileName = ' ' & _GetFileName($sPathFile)
		$aLineSplit = StringSplit($aFileListData[$i][4], "|")

		If $aLineSplit[0] > 1 Then
			$sFileSizeCurrent = $aLineSplit[1]
			$sFileSizeNew = $aLineSplit[2]
			$sFileCompressingPercent = $aLineSplit[3]
			$sFileCompressingSize = $aLineSplit[4]
			$sPathFileStatus = $aLineSplit[5]

			; Обновляем индекс последнего обработанного элемента
			$nLastUpdatedIndex = $i
		Else
			$sPathFileStatus = _GetActionStr($aFileListData[$i][2])
			$sFileSizeCurrent = ""
			$sFileSizeNew = ""
			$sFileCompressingPercent = ""
			$sFileCompressingSize = ""

			If $aFileListData[$i][5] And $aFileListData[$aFileListData[0][0]][5] Then
				ExitLoop
			EndIf
		EndIf

		Local $listViewIndex = $i - 1

		If Not $aFileListData[$i][5] Then
			; Создадим строку таблицы, если еще не создана
			$aFileListData[$i][5] = True
			_GUICtrlListView_AddItem($hListView, $sFileName, _GetIconIndexByPathFile($sPathFile))
			_GUICtrlListView_AddSubItem($hListView, $listViewIndex, $sFileSizeCurrent, 1)
			_GUICtrlListView_AddSubItem($hListView, $listViewIndex, $sFileSizeNew, 2)
			_GUICtrlListView_AddSubItem($hListView, $listViewIndex, $sFileCompressingPercent, 3)
			_GUICtrlListView_AddSubItem($hListView, $listViewIndex, $sFileCompressingSize, 4)
			_GUICtrlListView_AddSubItem($hListView, $listViewIndex, $sPathFileStatus, 5)
		Else
			_UpdateListViewItemIfChanged($listViewIndex, 1, $sFileSizeCurrent)
			_UpdateListViewItemIfChanged($listViewIndex, 2, $sFileSizeNew)
			_UpdateListViewItemIfChanged($listViewIndex, 3, $sFileCompressingPercent)
			_UpdateListViewItemIfChanged($listViewIndex, 4, $sFileCompressingSize)
			_UpdateListViewItemIfChanged($listViewIndex, 5, $sPathFileStatus)

		EndIf

	Next

	If $bNeedUpdate Then
		_GUICtrlListView_EndUpdate($hListView)
		_ListViewResize()
	EndIf
EndFunc   ;==>_UpdateGUI


Func _UpdateListViewItemIfChanged($iIndex, $iSubItem, $sNewText)
	If _GUICtrlListView_GetItemText($hListView, $iIndex, $iSubItem) <> $sNewText Then
		_GUICtrlListView_SetItemText($hListView, $iIndex, $sNewText, $iSubItem)
	EndIf
EndFunc   ;==>_UpdateListViewItemIfChanged


;===============================================================================
; Показать результат
;===============================================================================
; Параметры:
;     $sPathFile - путь к обрабатываемому файлу
;     $sFileSize - исходный размер файла
;     $sWinnerSize - результирующий размер файла после сжатия
;     Специальные значения $sWinnerSize:
;         1: формат не поддерживается
;         2: ошибка сохранения
;         3: пропуск папки
;         4: пропуск (файл не изменился)
;		0: по умолчанию
;===============================================================================
Func _ShowResult($sPathFile, $sFileSize, $sWinnerSize, $iStatusError = 0)
	Local $sActionName, $sActionCommand, $sCompressingSize, $sCompressingPrecent, $sPathFileStatus
	Local $sParams = ''

	; Проверяем, что путь файла соответствует текущему обрабатываемому элементу
	If $aFileListData[$nInx][1] = $sPathFile Then
		$sActionName = $aFileListData[$nInx][2] ; Название действия (например, Moth.CompressionLossless)
		$sActionCommand = $aFileListData[$nInx][3] ; Команда действия (например, loss, lossy, web)

		Switch $iStatusError
			Case $STATUS_APP_ERROR
				$sCompressingSize = ''
				$sCompressingPrecent = 'ошибка'
				$sWinnerSize = 0
			Case $STATUS_NOT_SUPPORTED
				$sCompressingSize = ''
				$sCompressingPrecent = 'не поддерживается'
				$sWinnerSize = 0
			Case $STATUS_SAVE_ERROR
				$sCompressingSize = ''
				$sCompressingPrecent = 'ошибка сохранения'
				$sWinnerSize = $sFileSize
			Case $STATUS_SKIPPED_FOLDER
				$sCompressingSize = ''
				$sCompressingPrecent = 'пропуск'
				$sWinnerSize = 0
			Case $STATUS_SKIPPED
				$sCompressingSize = ''
				$sCompressingPrecent = 'пропуск'
				$sWinnerSize = $sFileSize
			Case Else
				; Вычисляем размер и процент сжатия
				$sCompressingSize = _GetCompressingSize($sWinnerSize, $sFileSize)
				$sCompressingPrecent = _GetCompressingPrecent($sWinnerSize, $sFileSize)

				; Обновляем общую статистику только для определенных типов сжатия
				If StringInStr($sActionCommand, 'cq') Or $sActionCommand = 'lossy' Or $sActionCommand = 'web' Or $sActionCommand = 'loss' Then
					$sAllWinnerSize += $sWinnerSize
					$sAllFileSize += $sFileSize
				EndIf
		EndSwitch

		; Добавляем информацию в лог
		_AddLogLine($sCompressingPrecent & ', ' & $sCompressingSize)

		; Получаем статус операции для отображения
		$sPathFileStatus = _GetActionStr($sActionName)

		; Формируем строку параметров для обновления GUI
		$sParams &= _GetFileSizeStr($sFileSize) ; Исходный размер
		$sParams &= "|" & _GetFileSizeStr($sWinnerSize) ; Новый размер
		$sParams &= "|" & $sCompressingPrecent ; Процент сжатия
		$sParams &= "|" & $sCompressingSize ; Размер сжатия
		$sParams &= "|" & $sPathFileStatus ; Статус операции
		; Сохраняем результат дляпоследующего обновления GUI
		$aFileListData[$nInx][4] = $sParams
	EndIf
EndFunc   ;==>_ShowResult


Func _GetActionStr($sActionName)
	Return _IniString_Read($sMothINI, $sActionName, 'ShortGuiTitle')
;~ 	Return _IniString_Read($sMothINI, $sActionName, 'ContextMenuTitle')
EndFunc   ;==>_GetActionStr


Func _GetIconIndexByPathFile($sPathFile)
	Local $sExtension = _IsDir($sPathFile) ? "folder" : _GetFileExtension($sPathFile)

	For $i = 0 To UBound($aIconMap) - 1
		If $aIconMap[$i][0] = $sExtension Then
			Return $aIconMap[$i][1]
		EndIf
	Next

	Local $aIconInfo = _FileGetIcon($sPathFile)
	Local $nIndex = _GUIImageList_AddIcon($hImageIcons, $aIconInfo[1], $aIconInfo[2])
	ReDim $aIconMap[$nIndex + 1][2]
	$aIconMap[$nIndex][0] = $sExtension
	$aIconMap[$nIndex][1] = $nIndex
	Return $nIndex
EndFunc   ;==>_GetIconIndexByPathFile


Func _OnEvent_GETMINMAXINFO($hWnd, $iMsg, $wParam, $lParam)
	#forceref $iMsg, $wParam
	If $hWnd = $hGui Then
		Local $tMINMAXINFO = DllStructCreate("int;int;" & _
				"int MaxSizeX; int MaxSizeY;" & _
				"int MaxPositionX;int MaxPositionY;" & _
				"int MinTrackSizeX; int MinTrackSizeY;" & _
				"int MaxTrackSizeX; int MaxTrackSizeY", _
				$lParam)
		DllStructSetData($tMINMAXINFO, "MinTrackSizeX", $GUI_MIN_WIDTH)
		DllStructSetData($tMINMAXINFO, "MinTrackSizeY", $GUI_MIN_HEIGHT)

		_ListViewResize()
	EndIf
	Return $GUI_RUNDEFMSG
EndFunc   ;==>_OnEvent_GETMINMAXINFO



Func _OnEvent_SIZE($hWnd, $iMsg, $wParam, $lParam)
	#forceref $hWnd, $iMsg, $wParam, $lParam
	_ListViewResize()
	Return $GUI_RUNDEFMSG
EndFunc   ;==>_OnEvent_SIZE


Func _ListViewResize()
	Local $nCurrGuiWidth, $nCurrGuiHeight, $iListViewHeight

	$iListViewHeight = _GUICtrlListView_ApproximateViewHeight($hListView) - 18

	; Если изменилась ширина окна
	$aPosGui = ControlGetPos($hGui, 'SysListView32', '[CLASS:SysListView32; INSTANCE:1]')

	If @error Then Return

	$nCurrGuiWidth = $aPosGui[2]
	$nCurrGuiHeight = $aPosGui[3]

	If $iListViewHeight > $nCurrGuiHeight Then
		$nDefMargin = $nCurrGuiWidth - 17
	Else
		$nDefMargin = $nCurrGuiWidth
	EndIf

	_GUICtrlListView_SetColumnWidth($hListView, 0, $nDefMargin - _  ; $nCurrGuiWidth - 46
			_GUICtrlListView_GetColumnWidth($hListView, 1) - _
			_GUICtrlListView_GetColumnWidth($hListView, 2) - _
			_GUICtrlListView_GetColumnWidth($hListView, 3) - _
			_GUICtrlListView_GetColumnWidth($hListView, 4) - _
			_GUICtrlListView_GetColumnWidth($hListView, 5))

	Return $GUI_RUNDEFMSG
EndFunc   ;==>_ListViewResize


Func _CheckFileListUpdate()

	If Not $bStarting Then
		$bStarting = True
		GUISetState(@SW_SHOW, $hGui)

		_GetFileList()
		_CompressFile()
		Return
	EndIf

	_GetFileList()

	If _IsFileListUpdated() And $isComplete Then
		$isComplete = False
		_ResetTimerState()
		_CompressFile()
	EndIf

;~ 	_ArrayDisplay($aFileListData, '$aFileListData')
EndFunc   ;==>_CheckFileListUpdate


Func _IsFileListUpdated()
	Return $nInx < $aFileListData[0][0]
EndFunc   ;==>_IsFileListUpdated


Func _StartTimerState()
	If $bTimerState Then
		$Timer = TimerInit()
		AdlibRegister("_TimerUpdate", 200)
	Else
		_SetOkButtonText("OK")
	EndIf
	GUICtrlSetState($hOkButton, $GUI_ENABLE)
EndFunc   ;==>_StartTimerState


Func _ResetTimerState()
	AdlibUnRegister("_TimerUpdate")

	_SetOkButtonText($bTimerState ? "OK (10)" : "OK")
	GUICtrlSetState($hOkButton, $GUI_DISABLE)
EndFunc   ;==>_ResetTimerState


Func _TimerUpdate()
	Local $s = 11000 - Int(TimerDiff($Timer))
	_TicksToTime($s, $Hour, $Mins, $Secs)

	If $s <= 1000 And $bTimerState Then
		_OnEventClose()
		Return
	EndIf

	If $bTimerState Then
		_SetOkButtonText("OK (" & $Secs & ")")
	Else
		_SetOkButtonText("OK")
		AdlibUnRegister("_TimerUpdate")
	EndIf
EndFunc   ;==>_TimerUpdate


Func _SetOkButtonText($sText)
	If GUICtrlRead($hOkButton) <> $sText Then
		GUICtrlSetData($hOkButton, $sText)
	EndIf
EndFunc   ;==>_SetOkButtonText


Func _GetFileList()
	Local $aFileList, $aStringSplit, $sPathFile, $sActionName, $sFileReadLine

	$aFileList = _FO_FileSearch($sLogPathDir, 'txt', True, 125, 1, 1, 2)
	If @error Then Return

	For $i = 1 To $aFileList[0]
		$sFileReadLine = FileReadLine($aFileList[$i])
		$aStringSplit = StringSplit($sFileReadLine, "|")
		If $aStringSplit[0] > 1 Then
			$sPathFile = $aStringSplit[1] ; C:\Users\STEEL\Desktop\photo_2023-05-03_05-42-57.jpg
			$sActionName = $aStringSplit[2] ; Moth.CompressionLossless
		Else
			$sPathFile = $sFileReadLine
			$sActionName = '' ; Сбрасываем действие для строк без разделителя
		EndIf

		If $sActionName <> '' Then
			_AddToFileListData($sPathFile, $sActionName, $aFileList[$i])
		EndIf

		FileDelete($aFileList[$i])
	Next

	If _IniString_Read($sMothINI, 'Config', 'SetOnTopWhenAddFiles') = 1 Then
		; Сделаем окно видимым
		WinSetOnTop($hGui, '', 1)
		WinSetOnTop($hGui, '', 0)
	EndIf

EndFunc   ;==>_GetFileList


Func _AddToFileListData($sPathFile, $sActionName, $sAddSource)
	Local $aFileList, $sActionCommand

	$sPathFile = _GetFilePatch($sPathFile)
	$sActionCommand = _IniString_Read($sMothINI, $sActionName, 'Command')

	If _IsDir($sPathFile) Then
		$aFileList = _FO_FileSearch($sPathFile, _ArrayToString(_GetExtensionListExpanded(), '|'), True, 125, 1, 1, 2)
		If Not @error Then
			; Проверяем, достаточно ли места в массиве
			Local $iNeededSize = $iCurrentFileCount + $aFileList[0]
			If $iNeededSize >= UBound($aFileListData) Then
				ReDim $aFileListData[$iNeededSize + $INITIAL_ARRAY_SIZE][6]
			EndIf

			; Пакетное добавление файлов
			For $i = 1 To $aFileList[0]
				$iCurrentFileCount += 1
				$aFileListData[$iCurrentFileCount][0] = $sAddSource
				$aFileListData[$iCurrentFileCount][1] = $aFileList[$i]
				$aFileListData[$iCurrentFileCount][2] = $sActionName
				$aFileListData[$iCurrentFileCount][3] = $sActionCommand
			Next

			$aFileListData[0][0] = $iCurrentFileCount
			Return
		EndIf
	EndIf

	; Проверяем, достаточно ли места в массиве для одного элемента
	If $iCurrentFileCount + 1 >= UBound($aFileListData) Then
		ReDim $aFileListData[$iCurrentFileCount + $INITIAL_ARRAY_SIZE][6]
	EndIf

	$iCurrentFileCount += 1
	$aFileListData[$iCurrentFileCount][0] = $sAddSource
	$aFileListData[$iCurrentFileCount][1] = $sPathFile
	$aFileListData[$iCurrentFileCount][2] = $sActionName
	$aFileListData[$iCurrentFileCount][3] = $sActionCommand
	$aFileListData[0][0] = $iCurrentFileCount
EndFunc   ;==>_AddToFileListData

;===================
; ColorQuantization
;===================

Func _ColorQuantization($sPathFile, $sFileSize, $sExtensionFile, $sActionName)
	; Проверка поддержки формата
	If Not _IsFormatSupported($sExtensionFile, $sActionName) Then
		_UpdateGUI()
		_ShowResult($sPathFile, $sFileSize, 0, $STATUS_NOT_SUPPORTED)
		Return
	EndIf

	Local $sWinnerPath, $sWinnerSize, $sTempPath, $sActionCommand, $sSourceFile
	$sActionCommand = _IniString_Read($sMothINI, $sActionName, 'Command')

	; Определение исходного файла
	Switch $sExtensionFile
		Case $FORMAT_JPG, $FORMAT_JPE, $FORMAT_JPEG, $FORMAT_JFIF
			$sSourceFile = _AutorotateJpg($sPathFile, $sExtensionFile, False, False)

		Case $FORMAT_PNG, $FORMAT_AVIF, $FORMAT_BMP, $FORMAT_GIF, $FORMAT_WEBP
			$sSourceFile = $sPathFile

		Case Else
			_UpdateGUI()
			_ShowResult($sPathFile, $sFileSize, 0, $STATUS_SKIPPED)
			Return
	EndSwitch

	; Квантизация цвета
	$sTempPath = _CompressionRun('magick', '{patchFile} -quiet -dither FloydSteinberg -colors ' & _GetNumberFromString($sActionCommand) & ' {patchFile}', $sSourceFile, $sExtensionFile)
	If @error Then
		_ShowResult($sPathFile, $sFileSize, 0, $STATUS_APP_ERROR)
		Return
	EndIf

	; Оптимизация (только для форматов поддерживаемых pingo)
	;~ Switch $sExtensionFile
	;~ 	Case $FORMAT_JPG, $FORMAT_JPE, $FORMAT_JPEG, $FORMAT_PNG, $FORMAT_WEBP
	;~ 		$sWinnerPath = _CompressionRun('pingo', '-s3 {patchFile}', $sTempPath, $sExtensionFile)
	;~ 		If @error Then
	;~ 			_ShowResult($sPathFile, $sFileSize, 0, $STATUS_APP_ERROR)
	;~ 			Return
	;~ 		EndIf

	;~ 	Case Else
			; Для остальных форматов используем результат magick
			$sWinnerPath = $sTempPath
	;~ EndSwitch

	$sWinnerSize = FileGetSize($sWinnerPath)
	If $sWinnerSize <= 0 Then
		_ShowResult($sPathFile, $sFileSize, 0, $STATUS_APP_ERROR)
		Return
	EndIf

	; Сохранение результата
	Local $bSaved = _FileSave($sWinnerPath, $sPathFile, $sExtensionFile, $sActionName)
	_ShowResult($sPathFile, $sFileSize, $sWinnerSize, $bSaved ? 0 : $STATUS_SAVE_ERROR)
EndFunc   ;==>_ColorQuantization

;==============
; Resize Percent
;==============

Func _ResizePercent($sPathFile, $sFileSize, $sExtensionFile, $sActionName)
	If Not _IsFormatSupported($sExtensionFile, $sActionName) Then
		_UpdateGUI()
		_ShowResult($sPathFile, $sFileSize, 0, $STATUS_NOT_SUPPORTED)
		Return
	EndIf

	Local $sWinnerPath, $sWinnerSize, $sActionCommand
	Local $sPercent, $sFilter = 0

	$sActionCommand = _IniString_Read($sMothINI, $sActionName, 'Command') ; percent_50_0
	$aLineSplit = StringSplit($sActionCommand, '_')
	If $aLineSplit[0] <> 3 Then
		_ShowResult($sPathFile, $sFileSize, 0, $STATUS_SKIPPED)
		Return
	EndIf

	$sPercent = $aLineSplit[2]
	$sFilter = $aLineSplit[3]

	$sWinnerPath = _CompressionRun('magick', '{patchFile} -quiet -resize ' & $sPercent & '% -filter ' & _GetFilterNameByIndx($sFilter) & ' {patchFile}', $sPathFile, $sExtensionFile)
	If @error Then
		_ShowResult($sPathFile, $sFileSize, 0, $STATUS_APP_ERROR)
		Return
	EndIf

	$sWinnerSize = FileGetSize($sWinnerPath)
	If $sWinnerSize <= 0 Then
		_ShowResult($sPathFile, $sFileSize, 0, $STATUS_APP_ERROR)
		Return
	EndIf

	Local $bSaved = _FileSave($sWinnerPath, $sPathFile, $sExtensionFile, $sActionName)
	_ShowResult($sPathFile, $sFileSize, $sWinnerSize, $bSaved ? 0 : $STATUS_SAVE_ERROR)
EndFunc   ;==>_ResizePercent

;==============
; Resize Pixel
;==============

Func _ResizePixel($sPathFile, $sFileSize, $sExtensionFile, $sActionName)
	If Not _IsFormatSupported($sExtensionFile, $sActionName) Then
		_UpdateGUI()
		_ShowResult($sPathFile, $sFileSize, 0, $STATUS_NOT_SUPPORTED)
		Return
	EndIf

	Local $sWinnerPath, $sWinnerSize, $sActionCommand, $aLineSplit
	Local $sUtilParams, $sWidth = 1, $sHeight = 1, $sFilter = 0

	$sActionCommand = _IniString_Read($sMothINI, $sActionName, 'Command') ; resize_1000_1000_0_0
	$aLineSplit = StringSplit($sActionCommand, '_')
	If $aLineSplit[0] <> 5 Then
		_ShowResult($sPathFile, $sFileSize, 0, $STATUS_SKIPPED)
		Return
	EndIf

;~ 	Mitchell — мягкий и сбалансированный фильтр, подходит для общего увеличения:
;~ 	magick input.png -filter Mitchell -resize 200% output.png

;~ 	Robidoux / RobidouxSharp — специально оптимизированы для ImageMagick, дают хорошие результаты с минимальным ringing/aliasing:
;~ 	magick input.png -filter RobidouxSharp -resize 200% output.png

;~ 	Catrom (Catmull-Rom) — более резкий фильтр увеличения, хорошо подчёркивает детали:
;~ 	magick input.png -filter Catrom -resize 200% output.png

;~ 	Для простого и очень быстрого увеличения без сглаживания (например, для пиксель-арта):
;~ 	Можно использовать дискретные фильтры увеличения без интерполяции, например: Point или Box

;~ 	magick input.png -filter Point -resize 200% output.png
;~ 	magick input.png -filter Box -resize 200% output.png

;~ 	Выбор:
;~ 	Для фотографий > Lanczos или RobidouxSharp
;~ 	Для иллюстраций, графики > Catrom или Mitchell
;~ 	Для пиксель-арта > Point или Box


	$sWidth = $aLineSplit[2]
	$sHeight = $aLineSplit[3]
	$sFilter = $aLineSplit[5]

	Switch $aLineSplit[4]
		Case 1 ; Заполнить
			$sUtilParams = '{patchFile} -quiet -resize ' & $sWidth & 'x' & $sHeight & '^'
		Case 2 ; Заполнить и обрезать
			$sUtilParams = '{patchFile} -quiet -resize ' & $sWidth & 'x' & $sHeight & '^ -gravity center -extent ' & $sWidth & 'x' & $sHeight
		Case Else ; Вписать по умолчанию
			$sUtilParams = '{patchFile} -quiet -resize ' & $sWidth & 'x' & $sHeight
	EndSwitch

	$sUtilParams &= ' -filter ' & _GetFilterNameByIndx($sFilter) & ' {patchFile}'

	$sWinnerPath = _CompressionRun('magick', $sUtilParams, $sPathFile, $sExtensionFile)
	If @error Then
		_ShowResult($sPathFile, $sFileSize, 0, $STATUS_APP_ERROR)
		Return
	EndIf

	$sWinnerSize = FileGetSize($sWinnerPath)
	If $sWinnerSize <= 0 Then
		_ShowResult($sPathFile, $sFileSize, 0, $STATUS_APP_ERROR)
		Return
	EndIf

	Local $bSaved = _FileSave($sWinnerPath, $sPathFile, $sExtensionFile, $sActionName)
	_ShowResult($sPathFile, $sFileSize, $sWinnerSize, $bSaved ? 0 : $STATUS_SAVE_ERROR)
EndFunc   ;==>_ResizePixel

;==============
; ConvertToPng
;==============

Func _ConvertToPng($sPathFile, $sFileSize, $sExtensionFile, $sActionName)
	If Not _IsFormatSupported($sExtensionFile, $sActionName) Then
		_UpdateGUI()
		_ShowResult($sPathFile, $sFileSize, 0, $sExtensionFile = $FORMAT_PNG ? $STATUS_SKIPPED : $STATUS_NOT_SUPPORTED)
		Return
	EndIf

	Local $sPathFilePng, $sWinnerPath, $sWinnerSize, $sTool, $sCommand, $sSourceFile

	; Определение инструмента и команды конвертации
	Switch $sExtensionFile
		Case $FORMAT_AVIF, $FORMAT_BMP, $FORMAT_JFIF
			$sTool = 'magick'
			$sPathFilePng = _GetTempPathFileForCompression($sTool, $FORMAT_PNG)
			$sCommand = '{patchFile} -quiet {patchFileOut}'
			$sSourceFile = $sPathFile

		Case $FORMAT_GIF
			$sTool = 'magick'
			$sPathFilePng = _GetTempPathFileForCompression($sTool, $FORMAT_PNG)
			$sCommand = '{patchFile}[0] -quiet {patchFileOut}'
			$sSourceFile = $sPathFile

		Case $FORMAT_JPG, $FORMAT_JPE, $FORMAT_JPEG
			$sTool = 'magick'
			$sPathFilePng = _GetTempPathFileForCompression($sTool, $FORMAT_PNG)
			$sCommand = '{patchFile} -quiet {patchFileOut}'
			$sSourceFile = _AutorotateJpg($sPathFile, $sExtensionFile, False, False)

		Case $FORMAT_WEBP
			$sTool = 'dwebp'
			$sPathFilePng = _GetTempPathFileForCompression($sTool, $FORMAT_PNG)
			$sCommand = '-mt {patchFile} -o {patchFileOut}'
			$sSourceFile = $sPathFile

		Case $FORMAT_HEIC
			$sTool = 'magick'
			$sPathFilePng = _GetTempPathFileForCompression($sTool, $FORMAT_PNG)
			$sCommand = '{patchFile} -quiet -profile {sRGB.icc} -strip {patchFileOut}'
			$sSourceFile = $sPathFile

		Case Else
			_UpdateGUI()
			_ShowResult($sPathFile, $sFileSize, 0, $STATUS_SKIPPED)
			Return
	EndSwitch

	; Конвертация
	$sPathFilePng = _ConvertRun($sTool, $sCommand, $sSourceFile, $sPathFilePng)
	; Оптимизация
	$sWinnerPath = _CompressionRun('pingo', '-s3 {patchFile}', $sPathFilePng, $FORMAT_PNG)
	FileDelete($sPathFilePng)

	; Сохранение результата
	$sWinnerSize = FileGetSize($sWinnerPath)
	Local $bSaved = _FileSave($sWinnerPath, $sPathFile, $FORMAT_PNG, $sActionName)
	_ShowResult($sPathFile, $sFileSize, $sWinnerSize, $bSaved ? 0 : $STATUS_SAVE_ERROR)
EndFunc   ;==>_ConvertToPng

;=================
; ConvertToWebp
;=================

Func _ConvertToWebp($sPathFile, $sFileSize, $sExtensionFile, $sActionName)
	If Not _IsFormatSupported($sExtensionFile, $sActionName) Then
		_UpdateGUI()
		_ShowResult($sPathFile, $sFileSize, 0, $sExtensionFile = $FORMAT_WEBP ? $STATUS_SKIPPED : $STATUS_NOT_SUPPORTED)
		Return
	EndIf

	Local $sPathFileWebp, $sWinnerPath, $sWinnerSize, $sTool, $sCommand, $sSourceFile

	; Определение инструмента и команды конвертации
	Switch $sExtensionFile
		Case $FORMAT_AVIF, $FORMAT_BMP, $FORMAT_JFIF
			$sTool = 'magick'
			$sPathFileWebp = _GetTempPathFileForCompression($sTool, $FORMAT_WEBP)
			$sCommand = '{patchFile} -quiet {patchFileOut}'
			$sSourceFile = $sPathFile

		Case $FORMAT_GIF
			$sTool = 'magick'
			$sPathFileWebp = _GetTempPathFileForCompression($sTool, $FORMAT_WEBP)
			$sCommand = '{patchFile}[0] -quiet {patchFileOut}'
			$sSourceFile = $sPathFile

		Case $FORMAT_JPG, $FORMAT_JPE, $FORMAT_JPEG
			$sTool = 'cwebp'
			$sPathFileWebp = _GetTempPathFileForCompression($sTool, $FORMAT_WEBP)
			$sCommand = '-lossless -mt {patchFile} -o {patchFileOut}'
			$sSourceFile = _AutorotateJpg($sPathFile, $sExtensionFile, False, False)

		Case $FORMAT_PNG
			$sTool = 'cwebp'
			$sPathFileWebp = _GetTempPathFileForCompression($sTool, $FORMAT_WEBP)
			$sCommand = '-lossless -mt {patchFile} -o {patchFileOut}'
			$sSourceFile = $sPathFile

		Case $FORMAT_HEIC
			$sTool = 'magick'
			$sPathFileWebp = _GetTempPathFileForCompression($sTool, $FORMAT_WEBP)
			$sCommand = '{patchFile} -quiet -profile {sRGB.icc} -strip {patchFileOut}'
			$sSourceFile = $sPathFile

		Case Else
			_UpdateGUI()
			_ShowResult($sPathFile, $sFileSize, 0, $STATUS_SKIPPED)
			Return
	EndSwitch

	; Конвертация
	$sPathFileWebp = _ConvertRun($sTool, $sCommand, $sSourceFile, $sPathFileWebp)
	; Оптимизация
	$sWinnerPath = _CompressionRun('pingo', '-webp {patchFile}', $sPathFileWebp, $FORMAT_WEBP)
	FileDelete($sPathFileWebp)

	; Сохранение результата
	$sWinnerSize = FileGetSize($sWinnerPath)
	Local $bSaved = _FileSave($sWinnerPath, $sPathFile, $FORMAT_WEBP, $sActionName)
	_ShowResult($sPathFile, $sFileSize, $sWinnerSize, $bSaved ? 0 : $STATUS_SAVE_ERROR)
EndFunc   ;==>_ConvertToWebp

;================
; ConvertToJpg
;================

Func _ConvertToJpg($sPathFile, $sFileSize, $sExtensionFile, $sActionName)
	; Проверка поддержки формата
	If Not _IsFormatSupported($sExtensionFile, $sActionName) Then
		Local $bStatus = $STATUS_NOT_SUPPORTED
		If $sExtensionFile = $FORMAT_JPG Or $sExtensionFile = $FORMAT_JPE Or $sExtensionFile = $FORMAT_JPEG Then $bStatus = $STATUS_SKIPPED
		_UpdateGUI()
		_ShowResult($sPathFile, $sFileSize, 0, $bStatus)
		Return
	EndIf

	Local $sPathFileJpg, $sWinnerPath, $sWinnerSize, $sTool, $sCommand

	; Определение инструмента и команды конвертации
	Switch $sExtensionFile
		Case $FORMAT_AVIF, $FORMAT_BMP, $FORMAT_JFIF, $FORMAT_PNG
			$sTool = 'magick'
			$sPathFileJpg = _GetTempPathFileForCompression($sTool, $FORMAT_JPG)
			$sCommand = '{patchFile} -quiet -background white -alpha remove -alpha off {patchFileOut}'

		Case $FORMAT_GIF
			$sTool = 'magick'
			$sPathFileJpg = _GetTempPathFileForCompression($sTool, $FORMAT_JPG)
			$sCommand = '{patchFile}[0] -quiet {patchFileOut}'

		Case $FORMAT_WEBP
			$sTool = 'dwebp'
			$sPathFileJpg = _GetTempPathFileForCompression($sTool, $FORMAT_JPG)
			$sCommand = '-mt {patchFile} -o {patchFileOut}'

		Case $FORMAT_HEIC
			$sTool = 'magick'
			$sPathFileJpg = _GetTempPathFileForCompression($sTool, $FORMAT_JPG)
			$sCommand = '{patchFile} -quiet -profile {sRGB.icc} -strip {patchFileOut}'

		Case Else
			_UpdateGUI()
			_ShowResult($sPathFile, $sFileSize, 0, $STATUS_SKIPPED)
			Return
	EndSwitch

	; Конвертация
	$sPathFileJpg = _ConvertRun($sTool, $sCommand, $sPathFile, $sPathFileJpg)
	; Оптимизация
	$sWinnerPath = _CompressionRun('pingo', '-lossless -s3 {patchFile}', $sPathFileJpg, $FORMAT_JPG)
	FileDelete($sPathFileJpg)

	; Сохранение результата
	$sWinnerSize = FileGetSize($sWinnerPath)
	Local $bSaved = _FileSave($sWinnerPath, $sPathFile, $FORMAT_JPG, $sActionName)
	_ShowResult($sPathFile, $sFileSize, $sWinnerSize, $bSaved ? 0 : $STATUS_SAVE_ERROR)
EndFunc   ;==>_ConvertToJpg


Func _GetOrientationInfo($sPathFile)
	Local $sImageGetInfo = _ImageGetInfo($sPathFile)
	$sImageGetInfo = StringStripWS(StringReplace($sImageGetInfo, @LF, ";", 0, 2), 7)
	Return _ImageGetParam($sImageGetInfo, "Orientation")
EndFunc   ;==>_GetOrientationInfo


Func _StringCompare($sString, $sSubstring)
	Return StringCompare($sString, $sSubstring) = 0
EndFunc   ;==>_StringCompare


Func _GetJpegtranRunKey($sOrientation)
	Switch $sOrientation
		Case 'Mirrored'
			Return '-flip horizontal' ; 2
		Case '180'
			Return '-rotate 180' ; 3
		Case '180 and mirrored'
			Return '-flip vertical' ; 4
		Case '90 left and mirrored'
			Return '-transpose' ; 5
		Case '90 right'
			Return '-rotate 90' ; 6
		Case '90 right and mirrored'
			Return '-transverse' ; 7
		Case '90 left'
			Return '-rotate 270' ; 8
	EndSwitch
	Return ''
EndFunc   ;==>_GetJpegtranRunKey


; Удалит Exif-данные и автоматически повернёт изображение, если в мете была инфа об ориентации
Func _AutorotateJpg($sPathFile, $sExtensionFile, $bProgressive, $bSaveExif)

	; Если Exif-данные не удаляем, то нет смысла а автоповороте
	If $bSaveExif = True Then Return $sPathFile

	Local $sRunKey = _GetJpegtranRunKey(_GetOrientationInfo($sPathFile))
	If $sRunKey <> '' Then
		If $bProgressive = True Then $sRunKey &= ' -progressive'
		$sRunKey &= ' -copy none -optimize {patchFile} {patchFile}'
		Return _CompressionRun('jpegtran', $sRunKey, $sPathFile, $sExtensionFile)
	EndIf
	Return $sPathFile
EndFunc   ;==>_AutorotateJpg


;=======
; JPG
;=======

Func _CompressionJpg($sPathFile, $sFileSize, $sExtensionFile, $sActionName)
	Local $sWinnerPath, $sWinnerSize, $sRunKey, $sPathFileJpg
	Local $bSaveExif = _IniString_Read($sMothINI, $sActionName, 'SaveExif') = 1
	Local $bToProgressive = _IniString_Read($sMothINI, $sActionName, 'ToProgressive') = 1

	; Если будем чистить Exif инфу, надо убедиться, что изображение не требует поворота
	$sPathFileJpg = _AutorotateJpg($sPathFile, $sExtensionFile, $bToProgressive, $bSaveExif)

	; Первый вариант: jpegoptim
	$sRunKey = '{patchFile} --quiet --force -w ' & $nProcCount
	If Not $bSaveExif Then $sRunKey &= ' --strip-all'
	If $bToProgressive Then $sRunKey &= ' --all-progressive'
	Local $sPath1 = _CompressionRun('jpegoptim', $sRunKey, $sPathFileJpg, $sExtensionFile)
	Local $nSize1 = @error ? 0 : FileGetSize($sPath1)

	; Второй вариант: Pingo (если не нужны Exif и Progressive) или ect
	Local $sPath2, $nSize2
	If Not $bSaveExif And Not $bToProgressive Then
		$sPath2 = _CompressionRun('pingo', '-lossless -s3 {patchFile}', $sPathFileJpg, $sExtensionFile)
	Else
		$sRunKey = '-9 -quiet --strict --mt-deflate --mt-file'
		If Not $bSaveExif Then $sRunKey &= ' -strip'
		If $bToProgressive Then $sRunKey &= ' -progressive'
		$sRunKey &= ' {patchFile}'
		$sPath2 = _CompressionRun('ect', $sRunKey, $sPathFileJpg, $sExtensionFile)
	EndIf
	$nSize2 = @error ? 0 : FileGetSize($sPath2)

	; Проверяем результаты компрессии
	If $nSize1 = 0 And $nSize2 = 0 Then
		; Оба варианта завершились с ошибкой
		_ShowResult($sPathFile, $sFileSize, 0, $STATUS_APP_ERROR)
		Return
	EndIf

	; Выбираем лучший результат
	If $nSize1 > 0 And $nSize2 > 0 Then
		; Оба работают - выбираем меньший
		If $nSize1 < $nSize2 Then
			$sWinnerPath = $sPath1
			$sWinnerSize = $nSize1
			FileDelete($sPath2)
		Else
			$sWinnerPath = $sPath2
			$sWinnerSize = $nSize2
			FileDelete($sPath1)
		EndIf
	ElseIf $nSize1 > 0 Then
		; Только первый вариант работает
		$sWinnerPath = $sPath1
		$sWinnerSize = $nSize1
	Else
		; Только второй вариант работает
		$sWinnerPath = $sPath2
		$sWinnerSize = $nSize2
	EndIf

	; Если сжатие не дало улучшения
	If $sWinnerSize >= $sFileSize Then
		FileDelete($sWinnerPath)
		_ShowResult($sPathFile, $sFileSize, 0, $STATUS_SKIPPED)
		Return
	EndIf

	; Сохраняем улучшенный файл
	Local $bSaved = _FileSave($sWinnerPath, $sPathFile, $sExtensionFile, $sActionName)
	_ShowResult($sPathFile, $sFileSize, $sWinnerSize, $bSaved ? 0 : $STATUS_SAVE_ERROR)
EndFunc   ;==>_CompressionJpg


;=======
; JFIF
;=======

Func _CompressionJfif($sPathFile, $sFileSize, $sExtensionFile, $sActionName)
	Local $sWinnerPath, $sWinnerSize, $bToProgressive = False

	$bToProgressive = _IniString_Read($sMothINI, $sActionName, 'ToProgressive') = 1

	$sPathFileJpg = _AutorotateJpg($sPathFile, $sExtensionFile, $bToProgressive, False)

	$sRunKey = '{patchFile} --quiet --force -w ' & $nProcCount & ' --strip-all'
	If $bToProgressive = True Then $sRunKey &= ' --all-progressive'
	$sWinnerPath = _CompressionRun('jpegoptim', $sRunKey, $sPathFileJpg, $sExtensionFile)
	$sWinnerSize = FileGetSize($sWinnerPath)

	If $sWinnerSize < $sFileSize Then
		Local $bSaved = _FileSave($sWinnerPath, $sPathFile, $sExtensionFile, $sActionName)
		_ShowResult($sPathFile, $sFileSize, $sWinnerSize, $bSaved ? 0 : $STATUS_SAVE_ERROR)
		Return
	EndIf

	FileDelete($sWinnerPath)
	_ShowResult($sPathFile, $sFileSize, $sWinnerSize, $STATUS_SKIPPED)

EndFunc   ;==>_CompressionJfif


;=======
; AVIF
;=======

Func _CompressionAvif($sFilePath, $nOriginalSize, $sExtension, $sAction)
	_CompressionHelper($sFilePath, $nOriginalSize, $sExtension, $sAction, 'magick', _
			'{patchFile} -quiet -define heic:lossless=true -define heic:speed=0 {patchFile}')
EndFunc   ;==>_CompressionAvif

;=======
; GIF
;=======

Func _CompressionGif($sFilePath, $nOriginalSize, $sExtension, $sAction)
	_CompressionHelper($sFilePath, $nOriginalSize, $sExtension, $sAction, 'gifsicle', _
			'-w -j --no-conserve-memory -o {patchFile} -O3 --no-comments --no-extensions --no-names {patchFile}')
EndFunc   ;==>_CompressionGif

;=======
; BMP
;=======

Func _CompressionBmp($sFilePath, $nOriginalSize, $sExtension, $sAction)
	_CompressionHelper($sFilePath, $nOriginalSize, $sExtension, $sAction, 'imagew', _
			'-opt bmp:version=auto -noresize -zipcmprlevel 9 -outfmt bmp -compress "rle" {patchFile} {patchFile}')
EndFunc   ;==>_CompressionBmp

;=======
; PNG
;=======

Func _CompressionPng($sFilePath, $nOriginalSize, $sExtension, $sAction)
	_CompressionHelper($sFilePath, $nOriginalSize, $sExtension, $sAction, 'pingo', _
			'-lossless {patchFile}')
EndFunc   ;==>_CompressionPng

;=======
; Helper
;=======

Func _CompressionHelper($sFilePath, $nOriginalSize, $sExtension, $sAction, $sUtilName, $sUtilParams)
	Local $sCompressedPath, $nCompressedSize

	$sCompressedPath = _CompressionRun($sUtilName, $sUtilParams, $sFilePath, $sExtension)
	If @error Then
		_ShowResult($sFilePath, $nOriginalSize, 0, $STATUS_APP_ERROR)
		Return
	EndIf

	$nCompressedSize = FileGetSize($sCompressedPath)
	If $nCompressedSize <= 0 Then
		FileDelete($sCompressedPath)
		_ShowResult($sFilePath, $nOriginalSize, 0, $STATUS_APP_ERROR)
		Return
	EndIf

	; Если сжатие не дало улучшения - пропускаем
	If $nCompressedSize >= $nOriginalSize Then
		FileDelete($sCompressedPath)
		_ShowResult($sFilePath, $nOriginalSize, $nCompressedSize, $STATUS_SKIPPED)
		Return
	EndIf

	; Сохраняем улучшенный файл
	Local $bSaved = _FileSave($sCompressedPath, $sFilePath, $sExtension, $sAction)
	_ShowResult($sFilePath, $nOriginalSize, $nCompressedSize, $bSaved ? 0 : $STATUS_SAVE_ERROR)
EndFunc   ;==>_CompressionHelper

;=======
; WebP
;=======

Func _CompressionWebP($sPathFile, $sFileSize, $sExtensionFile, $sActionName)
	Local $sWinnerPath, $sWinnerSize

	; Сравниваем два варианта сжатия и выбираем лучший
	Local $sPath1 = _CompressionRun('pingo', '-webp -lossless {patchFile}', $sPathFile, $sExtensionFile)
	Local $nSize1 = @error ? 0 : FileGetSize($sPath1)

	Local $sPath2 = _CompressionRun('cwebp', '-lossless -mt {patchFile} -o {patchFile}', $sPathFile, $sExtensionFile)
	Local $nSize2 = @error ? 0 : FileGetSize($sPath2)

	; Выбираем лучший результат (меньший размер)
	If $nSize1 > 0 And ($nSize2 = 0 Or $nSize1 < $nSize2) Then
		$sWinnerPath = $sPath1
		$sWinnerSize = $nSize1
		If $nSize2 > 0 Then FileDelete($sPath2)
	ElseIf $nSize2 > 0 Then
		$sWinnerPath = $sPath2
		$sWinnerSize = $nSize2
		If $nSize1 > 0 Then FileDelete($sPath1)
	Else
		; Оба варианта завершились с ошибкой
		_ShowResult($sPathFile, $sFileSize, 0, $STATUS_APP_ERROR)
		Return
	EndIf

	; Если сжатие не дало улучшения
	If $sWinnerSize >= $sFileSize Then
		FileDelete($sWinnerPath)
		_ShowResult($sPathFile, $sFileSize, 0, $STATUS_SKIPPED)
		Return
	EndIf

	; Сохраняем улучшенный файл
	Local $bSaved = _FileSave($sWinnerPath, $sPathFile, $sExtensionFile, $sActionName)
	_ShowResult($sPathFile, $sFileSize, $sWinnerSize, $bSaved ? 0 : $STATUS_SAVE_ERROR)
EndFunc   ;==>_CompressionWebP

;=============================
; Замена или сохранение файла
;=============================

Func _FileSave($sWinnerPath, $sPathFile, $sExtensionFile, $sActionName)
	Local $hWinnerFile, $hFileRename, $sWinnerFileData, $sActionFilePostfix, $sPathFileRename, $bOkFunc = True

	$sActionFilePostfix = _IniString_Read($sMothINI, $sActionName, 'FilePostfix')
	$sPathFileRename = _GetPathFilePostfix($sPathFile, $sExtensionFile, $sActionFilePostfix)

	; Если файл есть, мягенько его перезаписываем
	If FileExists($sPathFileRename) Then

		$hWinnerFile = FileOpen($sWinnerPath, 0 + 16) ; откроем для чтения
		$hFileRename = FileOpen($sPathFileRename, 2 + 16) ; откроем для записи
		; Проверяет, получилось ли открыть, перед тем как использовать функции чтения/записи в файл
		If $hWinnerFile = -1 Or $hFileRename = -1 Then
			$bOkFunc = False
		EndIf

		; Прочитаем содержимое
		$sWinnerFileData = FileRead($hWinnerFile)
		If @error Then
			$bOkFunc = False
		EndIf

		; Сохраним в нужный файл
		If Not FileWrite($hFileRename, $sWinnerFileData) Then
			$bOkFunc = False
		EndIf

		; Закроем ранее открытые файлы
		FileClose($hWinnerFile)
		FileClose($hFileRename)

		; В любом случае удаляем файл
		FileDelete($sWinnerPath)

	Else
		; Либо просто сохраняем в нужную папку
		If Not FileMove($sWinnerPath, $sPathFileRename, 9) Then
			$bOkFunc = False
		EndIf
	EndIf

	Return $bOkFunc
EndFunc   ;==>_FileSave


Func _GetPathFilePostfix($sPathFile, $sExtensionFile, $sActionFilePostfix)
	Return StringTrimRight($sPathFile, StringLen(_GetFileExtension($sPathFile)) + 1) & $sActionFilePostfix & '.' & $sExtensionFile
EndFunc   ;==>_GetPathFilePostfix


;=======
; Lossy
;=======

Func _CompressionLossy($sPathFile, $sFileSize, $sExtensionFile, $sActionName)
	; Проверка поддержки формата
	If Not _IsFormatSupported($sExtensionFile, $sActionName) Then
		_UpdateGUI()
		_ShowResult($sPathFile, $sFileSize, 0, $STATUS_NOT_SUPPORTED)
		Return
	EndIf

	Local $sWinnerPath = '', $sWinnerSize = 0, $sRunKey, $sPathFileJpg

	; Определяем параметры сжатия для каждого формата
	Switch $sExtensionFile
		;~ Case 'heic'
		;~ 	$sWinnerPath = _CompressionRun('magick', '{patchFile} -quality 92 {patchFile}', $sPathFile, $sExtensionFile)
		Case $FORMAT_AVIF, $FORMAT_BMP
			$sWinnerPath = _CompressionRun('magick', '{patchFile} -quiet -quality 92 {patchFile}', $sPathFile, $sExtensionFile)

		Case $FORMAT_JPG, $FORMAT_JPE, $FORMAT_JPEG, $FORMAT_JFIF
			$sPathFileJpg = _AutorotateJpg($sPathFile, $sExtensionFile, True, False)
			$sRunKey = '{patchFile} --quiet --force --max=92 --all-progressive -w ' & $nProcCount & ' --strip-all'
			$sWinnerPath = _CompressionRun('jpegoptim', $sRunKey, $sPathFileJpg, $sExtensionFile)

		Case $FORMAT_PNG
			$sWinnerPath = _CompressionRun('pingo', '{patchFile}', $sPathFile, $sExtensionFile)

		Case $FORMAT_GIF
			$sWinnerPath = _CompressionRun('gifsicle', '-w -j --no-conserve-memory --lossy=100 -o {patchFile} -O3 --no-comments --no-extensions --no-names {patchFile}', $sPathFile, $sExtensionFile)

		Case $FORMAT_WEBP
			; Для webp сравниваем два варианта сжатия и выбираем лучший
			Local $sPath1 = _CompressionRun('cwebp', '-q 100 -mt {patchFile} -o {patchFile}', $sPathFile, $sExtensionFile)
			Local $nSize1 = @error ? 0 : FileGetSize($sPath1)

			Local $sPath2 = _CompressionRun('cwebp', '-near_lossless 100 -mt {patchFile} -o {patchFile}', $sPathFile, $sExtensionFile)
			Local $nSize2 = @error ? 0 : FileGetSize($sPath2)

			; Выбираем лучший результат (меньший размер)
			If $nSize1 > 0 And ($nSize2 = 0 Or $nSize1 < $nSize2) Then
				$sWinnerPath = $sPath1
				If $nSize2 > 0 Then FileDelete($sPath2)
			ElseIf $nSize2 > 0 Then
				$sWinnerPath = $sPath2
				If $nSize1 > 0 Then FileDelete($sPath1)
			Else
				; Оба варианта завершились с ошибкой
				_ShowResult($sPathFile, $sFileSize, 0, $STATUS_APP_ERROR)
				Return
			EndIf

	EndSwitch

	; Проверка ошибок выполнения
	If @error Then
		_ShowResult($sPathFile, $sFileSize, 0, $STATUS_APP_ERROR)
		Return
	EndIf

	; Проверка размера результата
	$sWinnerSize = FileGetSize($sWinnerPath)
	If $sWinnerSize <= 0 Then
		FileDelete($sWinnerPath)
		_ShowResult($sPathFile, $sFileSize, 0, $STATUS_APP_ERROR)
		Return
	EndIf

	; Если сжатие не дало улучшения
	If $sWinnerSize >= $sFileSize Then
		FileDelete($sWinnerPath)
		_ShowResult($sPathFile, $sFileSize, 0, $STATUS_SKIPPED)
		Return
	EndIf

	; Сохраняем улучшенный файл
	Local $bSaved = _FileSave($sWinnerPath, $sPathFile, $sExtensionFile, $sActionName)
	_ShowResult($sPathFile, $sFileSize, $sWinnerSize, $bSaved ? 0 : $STATUS_SAVE_ERROR)
EndFunc   ;==>_CompressionLossy


;====================
; Compression For Web
;====================

Func _CompressionForWeb($sPathFile, $sFileSize, $sExtensionFile, $sActionName)
	; Проверка поддержки формата
	If Not _IsFormatSupported($sExtensionFile, $sActionName) Then
		_UpdateGUI()
		_ShowResult($sPathFile, $sFileSize, 0, $STATUS_NOT_SUPPORTED)
		Return
	EndIf

	Local $sWinnerPath = '', $sWinnerSize = 0, $sRunKey, $sPathFileJpg

	; Определяем параметры сжатия для каждого формата
	Switch $sExtensionFile
		Case $FORMAT_AVIF, $FORMAT_BMP
			$sWinnerPath = _CompressionRun('magick', '{patchFile} -quiet -quality 80 {patchFile}', $sPathFile, $sExtensionFile)

		Case $FORMAT_JPG, $FORMAT_JPE, $FORMAT_JPEG, $FORMAT_JFIF
			$sPathFileJpg = _AutorotateJpg($sPathFile, $sExtensionFile, True, False)
			$sRunKey = '{patchFile} --quiet --force --max=75 --all-progressive --strip-all -w ' & $nProcCount
			$sWinnerPath = _CompressionRun('jpegoptim', $sRunKey, $sPathFileJpg, $sExtensionFile)

		Case $FORMAT_PNG
			$sWinnerPath = _CompressionRun('pingo', '-quality=75 -s3 {patchFile}', $sPathFile, $sExtensionFile)

		Case $FORMAT_WEBP
			$sWinnerPath = _CompressionRun('cwebp', '-q 75 -mt {patchFile} -o {patchFile}', $sPathFile, $sExtensionFile)

		Case $FORMAT_GIF
			$sWinnerPath = _CompressionRun('gifsicle', '-w -j --no-conserve-memory --lossy=75 -o {patchFile} -O3 --no-comments --no-extensions --no-names {patchFile}', $sPathFile, $sExtensionFile)
	EndSwitch

	; Проверка ошибок выполнения
	If @error Then
		_ShowResult($sPathFile, $sFileSize, 0, $STATUS_APP_ERROR)
		Return
	EndIf

	; Проверка размера результата
	$sWinnerSize = FileGetSize($sWinnerPath)
	If $sWinnerSize <= 0 Then
		FileDelete($sWinnerPath)
		_ShowResult($sPathFile, $sFileSize, 0, $STATUS_APP_ERROR)
		Return
	EndIf

	; Если сжатие не дало улучшения
	If $sWinnerSize >= $sFileSize Then
		FileDelete($sWinnerPath)
		_ShowResult($sPathFile, $sFileSize, 0, $STATUS_SKIPPED)
		Return
	EndIf

	; Сохраняем улучшенный файл
	Local $bSaved = _FileSave($sWinnerPath, $sPathFile, $sExtensionFile, $sActionName)
	_ShowResult($sPathFile, $sFileSize, $sWinnerSize, $bSaved ? 0 : $STATUS_SAVE_ERROR)
EndFunc   ;==>_CompressionForWeb


Func _GetTempPathFileForCompression($sUtilsName, $sExtensionFile)
	Return $sImgPath & '\' & $sUtilsName & @HOUR & @MIN & @SEC & @MSEC & '.' & $sExtensionFile
EndFunc   ;==>_GetTempPathFileForCompression


;===========================================
; Сжатие с использованием консольных утилит
;===========================================

Func _CompressionRun($sUtilsName, $sUtilsKey, $sPathFile, $sExtensionFile)
	Local $sPatchCompressFile, $iPid

	$sPatchCompressFile = _GetTempPathFileForCompression($sUtilsName, $sExtensionFile)
	$sUtilsKey = StringReplace($sUtilsKey, '{patchFile}', '"' & $sPatchCompressFile & '"', 0)
	_AddLogLine('_CompressionRun ' & $sUtilsName & '.exe ' & $sUtilsKey)

	If Not FileCopy($sPathFile, $sPatchCompressFile, 9) Then
		_AddLogLine('[!] Ошибка копирования ' & $sUtilsName & '.exe ' & $sPathFile & ' -> ' & $sPatchCompressFile)
		Return SetError(1, 0, $sPatchCompressFile)
	EndIf

	$iPid = Run('"' & @ScriptDir & '\apps\' & $sUtilsName & '.exe" ' & $sUtilsKey, _GetFilePerePatch($sPathFile), @SW_HIDE)
	If $iPid = 0 Then
		_AddLogLine('[!] Ошибка запуска ' & $sUtilsName & '.exe')
		Return SetError(2, 0, $sPatchCompressFile)
	EndIf

	$iLastProcessPid = $iPid

	; Ожидаем завершения без рекурсии в очередь
	While ProcessExists($iPid)
		_SetStepProcess(1)
		_UpdateGUI()
		Sleep(50)
	WEnd

	If Not FileExists($sPatchCompressFile) Then
		_AddLogLine('[!] Ошибка ' & $sUtilsName & '.exe, нет итогового файла ' & $sPatchCompressFile)
		Return SetError(3, 0, $sPatchCompressFile)
	EndIf

	Return $sPatchCompressFile
EndFunc   ;==>_CompressionRun


Func _ConvertRun($sUtilsName, $sUtilsKey, $sPathFile, $sPathFileOut)
	_AddLogLine('_ConvertRun ' & $sUtilsName & '.exe ' & $sUtilsKey)
	$sUtilsKey = StringReplace($sUtilsKey, '{patchFile}', '"' & $sPathFile & '"', 0)
	$sUtilsKey = StringReplace($sUtilsKey, '{patchFileOut}', '"' & $sPathFileOut & '"', 0)
	$sUtilsKey = StringReplace($sUtilsKey, '{sRGB.icc}', '"' & @ScriptDir & '\apps\sRGB.icc"', 0)
	_AddLogLine('_ConvertRun ' & $sUtilsName & '.exe ' & $sUtilsKey)
	Local $iPid = Run('"' & @ScriptDir & '\apps\' & $sUtilsName & '.exe" ' & $sUtilsKey, _GetFilePerePatch($sPathFile), @SW_HIDE)
	If $iPid = 0 Then
		_AddLogLine('[!] Ошибка запуска ' & $sUtilsName & '.exe')
		Return SetError(2, 0, $sPathFileOut)
	EndIf

	$iLastProcessPid = $iPid

	; Ожидаем завершения без рекурсии в очередь
	While ProcessExists($iPid)
		_SetStepProcess(1)
		_UpdateGUI()
		Sleep(50)
	WEnd

	If Not FileExists($sPathFileOut) Then
		_AddLogLine('[!] Ошибка ' & $sUtilsName & '.exe, нет итогового файла ' & $sPathFileOut)
		Return SetError(3, 0, $sPathFileOut)
	EndIf

	Return $sPathFileOut
EndFunc   ;==>_ConvertRun


Func _AddLogLine($sTmp)
	$sGlobalLogs &= $sTmp & @CR
EndFunc   ;==>_AddLogLine


Func _GetCompressingSize($nCompressedSize, $nOriginalSize)
	If $nOriginalSize = $nCompressedSize Then Return ''
	; Абсолютная разница размеров
	Local $nDifference = Abs($nCompressedSize - $nOriginalSize)
	; Формат: +/- размер
	Return ($nCompressedSize > $nOriginalSize ? '+' : '-') & _GetFileSizeStr($nDifference)
EndFunc   ;==>_GetCompressingSize


Func _GetCompressingPrecent($nCompressedSize, $nOriginalSize)
	; Нет смысла считать
	If $nOriginalSize = 0 Or $nOriginalSize = $nCompressedSize Then Return ''
	; Процент изменения размера
	Local $nPercent = (($nCompressedSize / $nOriginalSize) - 1) * 100
	Local $nDisplay = Round($nPercent, 2)
	; Если после округления отображается 0, но фактическое значение не равно 0, то увеличиваем точность, чтобы показать реальное изменение
	If $nDisplay = 0 And $nPercent <> 0 Then
		Local $nLog = Log(Abs($nPercent)) / Log(10)
		Local $nDigits = -Int(Floor($nLog)) ; Количество знаков после запятой, достаточное для отображения ненулевого значения
		$nDisplay = Round($nPercent, $nDigits)
	EndIf

	Return StringFormat("%s%s%%", $nDisplay > 0 ? "+" : "", $nDisplay)
EndFunc   ;==>_GetCompressingPrecent


; Функция для извлечения чисел из строки
Func _GetNumberFromString($sText)
	; Оно удаляет все символы, кроме чисел
	Return StringRegExpReplace($sText, '\D', '')
EndFunc   ;==>_GetNumberFromString


; Функция для получения строкового представления размера файла
Func _GetFileSizeStr($iBytes)
	If Not $iBytes Then Return ''

	Switch $iBytes
		Case 10995116277760 To 109951162777600 ; 10 - 100 TB
			$iBytes = Round($iBytes / 1099511627776, 1) & ' ТБ'
		Case 1000000000000 To 10995116277759 ; 1000 GB - 10 TB
			$iBytes = Round($iBytes / 1099511627776, 2) & ' ТБ'
		Case 107374182400 To 999999999999 ; 100 - 999 GB
			$iBytes = Round($iBytes / 1073741824) & ' ГБ'
		Case 10737418240 To 107374182399 ; 10 - 100 GB
			$iBytes = Round($iBytes / 1073741824, 1) & ' ГБ'
		Case 1000000000 To 10737418239 ; 1000 MB - 10 GB
			$iBytes = Round($iBytes / 1073741824, 2) & ' МБ'
		Case 1000000 To 999999999 ; 1000 KB - 999 MB
			$iBytes = Round($iBytes / 1048576, 2) & ' МБ'
		Case 1000 To 999999 ; 1000 B - 999 KB
			$iBytes = Round($iBytes / 1024) & ' КБ'
		Case 0 To 999
			$iBytes &= ' Б'
	EndSwitch
	Return $iBytes
EndFunc   ;==>_GetFileSizeStr


; Show a menu in a given GUI window which belongs to a given GUI ctrl
Func ShowMenu($hWnd, $nContextID, $nContextControlID, $iMouse = 0)
	Local $hMenu = GUICtrlGetHandle($nContextID)
	Local $iCtrlPos = ControlGetPos($hWnd, "", $nContextControlID)

	Local $X = $iCtrlPos[0]
	Local $Y = $iCtrlPos[1] + $iCtrlPos[3]

	ClientToScreen($hWnd, $X, $Y)

	If $iMouse Then
		$X = MouseGetPos(0)
		$Y = MouseGetPos(1)
	EndIf

	DllCall("user32.dll", "int", "TrackPopupMenuEx", "hwnd", $hMenu, "int", 0, "int", $X, "int", $Y, "hwnd", $hWnd, "ptr", 0)
EndFunc   ;==>ShowMenu


; Convert the client (GUI) coordinates to screen (desktop) coordinates
Func ClientToScreen($hWnd, ByRef $X, ByRef $Y)
	Local $stPoint = DllStructCreate("int;int")

	DllStructSetData($stPoint, 1, $X)
	DllStructSetData($stPoint, 2, $Y)

	DllCall("user32.dll", "int", "ClientToScreen", "hwnd", $hWnd, "ptr", DllStructGetPtr($stPoint))

	$X = DllStructGetData($stPoint, 1)
	$Y = DllStructGetData($stPoint, 2)
	; release Struct not really needed as it is a local
	$stPoint = 0
EndFunc   ;==>ClientToScreen


; Проверка на множественный запуск скрипта
Func _CheckSingleInstance()
	If _Singleton($sAppName, 1) = 0 Then
		Exit
	EndIf
EndFunc   ;==>_CheckSingleInstance

