#pragma compile(Out, ..\MothPortable\Moth.exe)
#pragma compile(Icon, Assets\Icons\Icon.ico)
#pragma compile(x64, True)
#pragma compile(ProductName, Moth)
#pragma compile(ProductVersion, 1.40)
#pragma compile(FileVersion, 1.40)
#pragma compile(FileDescription, Moth - сжатие изображений без потерь)
#pragma compile(CompanyName, MarkovTrue)
#pragma compile(LegalCopyright, © MarkovTrue)
#pragma compile(Comments, Program made by MarkovTrue)

#NoTrayIcon
#RequireAdmin

#include <FileOperations.au3>
#include <GUIConstants.au3>
#include <GUIConstantsEx.au3>
#include <GuiImageList.au3>
#include <GuiListView.au3>
#include <ListviewConstants.au3>
#include <Misc.au3>
#include <WinAPI.au3>
#include <WinAPIProc.au3>
#include <WindowsConstants.au3>

#include "Include\ExplorerIcon.au3"
#include "Include\FluentButton.au3"
#include "Include\FluentNativeList.au3"
#include "Include\FluentNativeStatic.au3"
#include "Include\FluentTheme.au3"
#include "Include\IccProfile.au3"
#include "Include\ImageGetInfo.au3"

#include "Common\MothCommon.au3"

Opt("GUIOnEventMode", 1)


; Статус обработки файла для _ShowResult
Global Const $STATUS_SKIPPED = 1
Global Const $STATUS_NOT_SUPPORTED = 2
Global Const $STATUS_SAVE_ERROR = 3
Global Const $STATUS_SKIPPED_FOLDER = 4
Global Const $STATUS_APP_ERROR = 5
Global Const $STATUS_PALETTE_LARGER = 6

; Таблица обновляется не чаще раза в столько мс и получает за раз не больше столько новых строк.
; Очередь растёт порциями по столько строк и считается собранной, если столько мс в неё ничего не приходило
Global Const $gc_iGuiUpdateMs = 250
Global Const $gc_iGuiRowsPerUpdate = 300
Global Const $gc_iFileListChunk = 1000
Global Const $gc_iQueueQuietMs = 800

; Наименьшее окно: таблица ровно на 3 строки
Global Const $gc_iGuiMinW = 440
Global Const $gc_iGuiMinH = 158
Global Const $gc_iGuiW = 527, $gc_iGuiH = 168

; Очередь файлов с 1: [0-источник, 1-путь, 2-действие, 3-команда, 4-результат]. [0][0] - число файлов
Global $g_aFileList[$gc_iFileListChunk][5]
Global $g_iFileCount = 0


_MothIniRequire()
_MothLangInit()
_MothRequireX64()

_CheckSingleInstance()


; Журнал обработки для разбора ошибок: [Config] Log=1 дописывает его в %TEMP%\Moth\Moth.log при закрытии
Global $g_bLog = _IniString_Read($gc_sMothIni, 'Config', 'Log', '0') = 1


; Журнал, файлы перетаскивания, итог сжатия в байтах, текущий файл очереди, потолок прогресса
; на этот файл и PID работающей утилиты
Global $g_sLog = '', $g_aDropList, $g_iAllWinnerSize = 0, $g_iAllFileSize = 0, _
		$g_iFileIndex = 1, $g_iProgressMax, $g_iUtilPid

; GUI handles / ControlIDs
Global $g_hGui, $g_iListView, $g_hImageList, $g_iMenuShowInExplorer, $g_iMenuCopyPath, $g_iBtnOk, $g_iBtnSettings, _
		$g_iDropDummy, $g_iContextMenu, $g_iListBack, $g_iProgress, $g_iLblInfo
Global $g_aColumnNames[6]
; Отсчёт до автозакрытия и идёт ли он
Global $g_hCloseTimer, $g_bCloseTimer = True
; Таблица следует за обрабатываемым файлом, пока окно не тронули мышью
Global $g_bAutoScroll = True
; Строка последнего обработанного файла, её подсвечивает отрисовка таблицы (-1 - нет подсветки)
Global $g_iDoneRow = -1
; Через сколько секунд после обработки окно закрывается само, 0 - не закрывается
Global $g_iCloseSec = 10
Global $g_bComplete = False
; Строк в таблице и последняя из них, уже получившая результат
Global $g_iRowsShown = 0, $g_iLastUpdated = 0

; Цвета тёмной таблицы. Оттенки серого одинаковы в RGB и BGR (COLORREF)
Global Const $gc_iLvHeaderBk   = 0x2D2D2D ; фон заголовка, светлее строк
Global Const $gc_iLvHeaderText = 0xD4D4D4
Global Const $gc_iLvRowBk      = 0x212121 ; чётные строки и пустая область
Global Const $gc_iLvRowBkAlt   = 0x292929 ; нечётные строки
Global Const $gc_iLvRowText    = 0xE0E0E0
Global Const $gc_iLvRowSel     = 0x4D4D4D
Global Const $gc_iLvRowCurLight = 0xFFE8CC ; светлая тема: строка обработанного файла (BGR, #CCE8FF)
Global Const $gc_iLvGridLine   = 0x191919 ; сетка и рамка заголовка

; NMCUSTOMDRAW заголовка. У строк таблицы - $tagNMLVCUSTOMDRAW из StructureConstants
Global Const $tagNMCUSTOMDRAWHDR = "struct;" & $tagNMHDR & ";dword dwDrawStage;handle hdc;" & $tagRECT & _
		";dword_ptr dwItemSpec;uint uItemState;lparam lItemlParam;endstruct"

; Сабкласс ListView ради заголовка: его NM_CUSTOMDRAW идёт самому ListView, а не окну
Global $g_hLVHeader = 0, $g_hLVCallback = 0, $g_pLVFilter = 0
; Кнопка OK доступна после обработки очереди: кнопка Fluent - это Pic, клик по ней приходит всегда
Global $g_bOkEnabled = False
; Когда в очередь последний раз пришли файлы (TimerInit). Пока _TakeTasks переносит задания
; из приёмника в очередь, окно не закрывается само: их уже нет в приёмнике и ещё нет в очереди
Global $g_hQueueAddTimer = 0, $g_bTaking = False
; Код ориентации Exif (2..8), который jpegtran не смог применить без потерь: после сжатия
; он возвращается в JPEG отдельной меткой. Сбрасывается перед каждым файлом
Global $g_iOrientPending = 0
; Обновления: найденная версия, процесс фоновой проверки, мигание шестерёнки
Global $g_sUpdateVersion = '', $g_hUpdateProcess = 0, $g_bPulse = False, $g_bPulsePhase = False
Global $g_bShown = False
; Индекс иконки в $g_hImageList по расширению. Команда и подпись действия из ini:
; чтение на каждый файл заметно на тысячах заданий
Global $g_oIconMap[], $g_oActionCommand[], $g_oActionTitle[]
; Потоки для jpegoptim
Global $g_iProcCount = _Max(1, Int(EnvGet('NUMBER_OF_PROCESSORS')))


If Not FileExists($gc_sImgPath) Then DirCreate($gc_sImgPath)

_MainGUI()
_DefineEvents()
_SetPositionOnDesktop()
_UpdateCheckOnStart()


Func _MainGUI()

	$g_hGui = GUICreate($gc_sAppName, $gc_iGuiW, $gc_iGuiH, 0, 0, $WS_CAPTION + $WS_THICKFRAME, $WS_EX_ACCEPTFILES)

	$g_iListView = GUICtrlCreateListView("", 6, 2, $gc_iGuiW - 13, 122, _
			BitOR($LVS_NOSORTHEADER, $LVS_SINGLESEL, $LVS_REPORT), _
			BitOR($LVS_EX_INFOTIP, $LVS_EX_FULLROWSELECT))
	GUICtrlSetResizing($g_iListView, $GUI_DOCKBORDERS)
	GUICtrlSetState($g_iListView, $GUI_DROPACCEPTED)

	; Подписи колонок нужны и заголовку тёмной темы, который рисуется вручную
	Local $aNames = [_Lang('Main', 'ColFile', 'File'), _Lang('Main', 'ColSize', 'Size'), _
			_Lang('Main', 'ColNew', 'New'), _Lang('Main', 'ColPercent', 'Percent'), _
			_Lang('Main', 'ColSaved', 'Saved'), _Lang('Main', 'ColTask', 'Task')]
	$g_aColumnNames = $aNames
	_GUICtrlListView_InsertColumn($g_iListView, 0, $g_aColumnNames[0], 172)
	_GUICtrlListView_InsertColumn($g_iListView, 1, $g_aColumnNames[1], 70, $LVCFMT_RIGHT)
	_GUICtrlListView_InsertColumn($g_iListView, 2, $g_aColumnNames[2], 70)
	_GUICtrlListView_InsertColumn($g_iListView, 3, $g_aColumnNames[3], 65, $LVCFMT_RIGHT)
	_GUICtrlListView_InsertColumn($g_iListView, 4, $g_aColumnNames[4], 65)
	_GUICtrlListView_InsertColumn($g_iListView, 5, $g_aColumnNames[5], 65)

	$g_hImageList = _GUIImageList_Create(16, 16, 5, 3)
	_GUICtrlListView_SetImageList($g_iListView, $g_hImageList, 1)

	; Контекстное меню строки: висит на пустышке и открывается из WM_NOTIFY по NM_RCLICK
	$g_iContextMenu = GUICtrlCreateContextMenu(GUICtrlCreateDummy())
	$g_iMenuShowInExplorer = GUICtrlCreateMenuItem(_Lang('Main', 'ShowInExplorer', 'Show in Explorer'), $g_iContextMenu)
	$g_iMenuCopyPath = GUICtrlCreateMenuItem(_Lang('Main', 'CopyAsPath', 'Copy as path'), $g_iContextMenu)

	; Подложка под таблицей в цвет строк
	$g_iListBack = GUICtrlCreateLabel('', 0, 1, $gc_iGuiW, 124)
	GUICtrlSetState($g_iListBack, $GUI_DISABLE)
	GUICtrlSetResizing($g_iListBack, $GUI_DOCKBORDERS)

	$g_iProgress = GUICtrlCreateProgress(6, 125, $gc_iGuiW - 13, 5)
	GUICtrlSetResizing($g_iProgress, $GUI_DOCKLEFT + $GUI_DOCKBOTTOM + $GUI_DOCKRIGHT + $GUI_DOCKHEIGHT)

	$g_iLblInfo = GUICtrlCreateLabel('', 10, 142, $gc_iGuiW - 119, 17, $SS_LEFT)
	GUICtrlSetResizing($g_iLblInfo, $GUI_DOCKLEFT + $GUI_DOCKBOTTOM + $GUI_DOCKRIGHT + $GUI_DOCKHEIGHT)

	; Кнопки рисует Fluent (GDI+), как в окне настроек и VCLauncher. Скруглённые углы лежат
	; на фоне окна: в светлой теме окно системное, поэтому фон кнопок - BTNFACE
	_FluentInit($g_hGui, 'Segoe UI', 9, @ScriptDir & '\Themes\Icons')
	_FluentSetTheme(_IsDarkTheme())
	If _IsDarkTheme() Then
		; Подписи приглушены, как текст таблицы
		$g_iFluentText1 = $gc_iLvRowText
	Else
		$g_iFluentBg = _WinAPI_SwitchColor(_WinAPI_GetSysColor($COLOR_BTNFACE))
	EndIf

	$g_iCloseSec = Int(_IniString_Read($gc_sMothIni, 'Config', 'CloseTimer', '10'))
	If $g_iCloseSec <= 0 Then
		$g_iCloseSec = 0
		$g_bCloseTimer = False
	EndIf
	; Подвал: кнопки 24 px с одинаковым отступом 7 сверху (от прогресс-бара), снизу, справа и между собой.
	; Правый край OK совпадает с краем списка и прогресс-бара
	$g_iBtnOk = _FluentButton_Create(_OkCountdownText(), '', 0, $gc_iGuiW - 71, 137, 64, 24, $FLUENTBUTTON_TEXT)
	GUICtrlSetResizing($g_iBtnOk, $GUI_DOCKRIGHT + $GUI_DOCKBOTTOM + $GUI_DOCKWIDTH + $GUI_DOCKHEIGHT)
	_SetOkEnabled(False)

	; Шестерёнка слева от OK открывает окно настроек и мигает, если вышла новая версия.
	; Кнопка квадратная по высоте OK. Иконка рисуется в родном размере PNG: Fluent её не сглаживает
	$g_iBtnSettings = _FluentButton_Create('', 'Settings', 16, $gc_iGuiW - 102, 137, 24, 24, $FLUENTBUTTON_ICON)
	GUICtrlSetResizing($g_iBtnSettings, $GUI_DOCKRIGHT + $GUI_DOCKBOTTOM + $GUI_DOCKWIDTH + $GUI_DOCKHEIGHT)
	GUICtrlSetTip($g_iBtnSettings, _Lang('Main', 'Settings', 'Settings'))

	$g_iDropDummy = GUICtrlCreateDummy()

	_SetTheme()
EndFunc   ;==>_MainGUI


Func _DefineEvents()
	GUICtrlSetOnEvent($g_iMenuShowInExplorer, "_OnEvent_ShowInExplorer")
	GUICtrlSetOnEvent($g_iMenuCopyPath, "_OnEvent_CopyPath")
	GUICtrlSetOnEvent($g_iBtnOk, "_OnEvent_Ok")
	GUICtrlSetOnEvent($g_iBtnSettings, "_OnEvent_Settings")
	GUICtrlSetOnEvent($g_iDropDummy, "_OnEvent_Dropped")
	GUISetOnEvent($GUI_EVENT_CLOSE, "_OnEvent_Close")
	GUISetOnEvent($GUI_EVENT_PRIMARYDOWN, "_OnEvent_ClickDown")
	GUISetOnEvent($GUI_EVENT_SECONDARYDOWN, "_OnEvent_ClickDown")
	; Через маршрутизатор Fluent: WM_NOTIFY слушает и тема окна
	_FluentMsg_Register($WM_DROPFILES, "_OnEvent_WM_DROPFILES")
	; Наименьший размер окна, заодно подгонка колонки файла при ресайзе
	_FluentMsg_Register($WM_GETMINMAXINFO, "_OnEvent_WM_GETMINMAXINFO")
	_FluentMsg_Register($WM_NOTIFY, "_OnEvent_WM_NOTIFY")
EndFunc   ;==>_DefineEvents


Func _SetTheme()
	If _IsDarkTheme() Then
		; Рамки полей тема не рисует: у списка своя отрисовка, он вне темы окна
		_FluentTheme_SetBorders(False, False)
		_FluentTheme_Exclude($g_iListView)
		_FluentTheme_Apply($g_hGui)
		_SetDarkListView()

		_GUICtrlListView_SetBkColor($g_iListView, $gc_iLvRowBk)
		_GUICtrlListView_SetTextBkColor($g_iListView, $gc_iLvRowBk)

		; В скрипт пропускается только WM_NOTIFY: через колбэк AutoIt шёл бы и WM_PAINT списка,
		; и быстрая прокрутка большого списка вешала окно (подробно в FluentSubclass.au3)
		If $g_hLVCallback = 0 Then
			$g_hLVHeader = _GUICtrlListView_GetHeader($g_iListView)
			$g_hLVCallback = DllCallbackRegister("_LV_HeaderSubclass", "lresult", "hwnd;uint;wparam;lparam;uint_ptr;dword_ptr")
			$g_pLVFilter = _FluentSubclass_Pass($WM_NOTIFY, DllCallbackGetPtr($g_hLVCallback))
			If $g_pLVFilter Then _WinAPI_SetWindowSubclass(GUICtrlGetHandle($g_iListView), $g_pLVFilter, 1000, 0)
			OnAutoItExitRegister("_LV_SubclassCleanup")
		EndIf

		GUICtrlSetBkColor($g_iListBack, $gc_iLvRowBk)
	Else
		GUICtrlSetBkColor($g_iListBack, 0xFFFFFF)
	EndIf
EndFunc   ;==>_SetTheme


; Очередь обрабатывается в главном цикле, а не в Adlib: пока пользователь тащит
; ползунок списка, Windows крутит свой модальный цикл и отдаёт в него таймеры AutoIt.
; Обработка, запущенная из таймера, оказывалась вложенной в прокрутку, и окно зависало.
; Из главного цикла она просто ждёт, пока пользователь отпустит ползунок.
While 1
	_CheckFileListUpdate()
	Sleep(200)
WEnd


Func _OnEvent_Close()
	; Первым делом закрыть приём: Launcher'ы дальше запустят новый Moth, а не отдадут задания этому
	_CopyDataQueue_Close()
	; Утилиту закрываем, только если она ещё работает: PID завершившейся мог достаться чужому процессу
	If $g_iUtilPid Then ProcessClose($g_iUtilPid)
	DirRemove($gc_sImgPath, 1)

	If $g_bPulse Then AdlibUnRegister('_PulseSettingsButton')
	; Проверка обновлений живёт своим процессом и допишет Moth.ini сама
	If $g_hUpdateProcess Then _WinAPI_CloseHandle($g_hUpdateProcess)
	_FluentShutdown()

	If $g_bLog Then
		Local $hLog = FileOpen($gc_sTmpPath & '\Moth.log', BitOR($FO_APPEND, $FO_UTF8))
		FileWrite($hLog, '=== ' & $gc_sAppName & ' ' & @YEAR & '.' & @MON & '.' & @MDAY & ' ' & @HOUR & ':' & @MIN & ':' & @SEC & _
				StringReplace($g_sLog, @CR, @CRLF) & @CRLF & @CRLF)
		FileClose($hLog)
	EndIf

	Exit
EndFunc   ;==>_OnEvent_Close


; OK и отсчёт закрывают окно, только если после обработки не пришло новых заданий
Func _CloseIfIdle()
	If $g_bTaking Or _HasPendingFiles() Or Not _CopyDataQueue_Close(True) Then Return
	_OnEvent_Close()
EndFunc   ;==>_CloseIfIdle


Func _SetPositionOnDesktop()
	Local $aPosGui, $tRect, $nGuiX, $nGuiY, $nMargin = 6
	$aPosGui = WinGetPos($g_hGui)
	$tRect = _WinAPI_GetWorkArea()
	$nGuiX = DllStructGetData($tRect, 'Right') - $nMargin - $aPosGui[2]
	$nGuiY = DllStructGetData($tRect, 'Bottom') - $nMargin - $aPosGui[3]
	WinMove($g_hGui, "", $nGuiX, $nGuiY)
EndFunc   ;==>_SetPositionOnDesktop


; Пути брошенных файлов в $g_aDropList ([0] - число), дальше работает _OnEvent_Dropped
Func _OnEvent_WM_DROPFILES($hWnd, $iMsg, $wParam, $lParam)
	#forceref $hWnd, $iMsg, $lParam
	; Индекс 0xFFFFFFFF - число файлов, буфер 0 - длина пути без нуля
	Local $aRet = DllCall("shell32.dll", "uint", "DragQueryFileW", "handle", $wParam, "uint", 0xFFFFFFFF, "ptr", 0, "uint", 0)
	If @error Then Return
	Local $iCount = $aRet[0], $tName
	Dim $g_aDropList[$iCount + 1] = [$iCount]
	For $i = 0 To $iCount - 1
		$aRet = DllCall("shell32.dll", "uint", "DragQueryFileW", "handle", $wParam, "uint", $i, "ptr", 0, "uint", 0)
		$tName = DllStructCreate("wchar[" & $aRet[0] + 1 & "]")
		DllCall("shell32.dll", "uint", "DragQueryFileW", "handle", $wParam, "uint", $i, "struct*", $tName, "uint", $aRet[0] + 1)
		$g_aDropList[$i + 1] = DllStructGetData($tName, 1)
	Next
	; HDROP освобождает получатель, иначе память утекает на каждом перетаскивании
	DllCall("shell32.dll", "none", "DragFinish", "handle", $wParam)
	GUICtrlSendToDummy($g_iDropDummy, $iCount)
EndFunc   ;==>_OnEvent_WM_DROPFILES


; Действие перетаскивания - последнее включённое в [Action.DragAndDrop]
Func _OnEvent_Dropped()
	Local $sActionName = '', $aActionList

	$aActionList = _IniString_ReadSection($gc_sMothIni, 'Action.DragAndDrop')
	If @error Then Return

	For $i = 1 To $aActionList[0][0]
		If $aActionList[$i][1] <> 1 Or StringLeft($aActionList[$i][0], 5) <> 'Moth.' Then ContinueLoop
		$sActionName = $aActionList[$i][0]
	Next

	If $sActionName = '' Then
		MsgBox(48, $gc_sAppName, _Lang('Errors', 'NoDropAction', 'The drag-and-drop action is missing or misconfigured in the settings.'))
		Return
	EndIf

	For $i = 1 To $g_aDropList[0]
		_AddToFileListData($g_aDropList[$i], $sActionName, 'Action.DragAndDrop ' & @HOUR & ':' & @MIN & ':' & @SEC)
	Next
EndFunc   ;==>_OnEvent_Dropped


Func _OnEvent_WM_NOTIFY($hWnd, $iMsg, $iwParam, $ilParam)
	#forceref $hWnd, $iMsg, $iwParam

	Local $iIndex
	Local $tNMHDR = DllStructCreate($tagNMHDR, $ilParam)
	If HWnd(DllStructGetData($tNMHDR, "hWndFrom")) <> GUICtrlGetHandle($g_iListView) Then Return $GUI_RUNDEFMSG
	Local $iCode = DllStructGetData($tNMHDR, "Code")

	Switch $iCode
		Case $NM_CUSTOMDRAW
			Local $tLVCD = DllStructCreate($tagNMLVCUSTOMDRAW, $ilParam)
			If _IsDarkTheme() Then
				; Тело таблицы: чередование строк, выделение и подсветка обработанного файла
				Switch DllStructGetData($tLVCD, "dwDrawStage")
					Case $CDDS_PREPAINT
						Return $CDRF_NOTIFYITEMDRAW
					Case $CDDS_ITEMPREPAINT
						Local $iRow = DllStructGetData($tLVCD, "dwItemSpec")
						Local $iState = DllStructGetData($tLVCD, "uItemState")
						If BitAND($iState, $CDIS_SELECTED) Or $iRow = $g_iDoneRow Then
							; Без флагов выделения система рисует строку как обычную, с нашим фоном,
							; а иконку и текст ставит на родные места
							DllStructSetData($tLVCD, "uItemState", BitAND($iState, BitNOT($CDIS_SELECTED), BitNOT($CDIS_FOCUS)))
							DllStructSetData($tLVCD, "clrTextBk", $gc_iLvRowSel)
						Else
							DllStructSetData($tLVCD, "clrTextBk", BitAND($iRow, 1) ? $gc_iLvRowBkAlt : $gc_iLvRowBk)
						EndIf
						DllStructSetData($tLVCD, "clrText", $gc_iLvRowText)
						Return $CDRF_NEWFONT
				EndSwitch
			ElseIf $g_iDoneRow >= 0 Then
				; Светлая тема: остальное рисует система, красим только строку обработанного файла
				Switch DllStructGetData($tLVCD, "dwDrawStage")
					Case $CDDS_PREPAINT
						Return $CDRF_NOTIFYITEMDRAW
					Case $CDDS_ITEMPREPAINT
						If DllStructGetData($tLVCD, "dwItemSpec") <> $g_iDoneRow Then Return $CDRF_DODEFAULT
						DllStructSetData($tLVCD, "clrTextBk", $gc_iLvRowCurLight)
						Return $CDRF_NEWFONT
				EndSwitch
			EndIf

		Case $NM_RCLICK
			$iIndex = DllStructGetData(DllStructCreate($tagNMITEMACTIVATE, $ilParam), "Index")
			If $iIndex <> -1 Then _ShowContextMenu($g_iContextMenu)

		Case $NM_DBLCLK
			; Строка таблицы N - файл очереди N + 1
			$iIndex = DllStructGetData(DllStructCreate($tagNMITEMACTIVATE, $ilParam), "Index")
			If $iIndex <> -1 And FileExists($g_aFileList[$iIndex + 1][1]) Then ShellExecute($g_aFileList[$iIndex + 1][1])
	EndSwitch

	Return $GUI_RUNDEFMSG
EndFunc   ;==>_OnEvent_WM_NOTIFY


; Сабкласс ListView: перехватывает NM_CUSTOMDRAW заголовка (SysHeader32) и рисует его в цветах палитры Fluent
Func _LV_HeaderSubclass($hWnd, $iMsg, $iwParam, $ilParam, $iID, $pData)
	#forceref $iwParam, $iID, $pData
	If $iMsg = $WM_NOTIFY And _IsDarkTheme() Then
		Local $tHdr = DllStructCreate($tagNMHDR, $ilParam)
		If HWnd(DllStructGetData($tHdr, "hWndFrom")) = $g_hLVHeader And DllStructGetData($tHdr, "Code") = $NM_CUSTOMDRAW Then
			Local $tCD = DllStructCreate($tagNMCUSTOMDRAWHDR, $ilParam)
			Switch DllStructGetData($tCD, "dwDrawStage")
				Case $CDDS_PREPAINT
					Return $CDRF_NOTIFYITEMDRAW
				Case $CDDS_ITEMPREPAINT
					Local $iCol = DllStructGetData($tCD, "dwItemSpec")
					Local $hDC = DllStructGetData($tCD, "hdc")
					; Копия прямоугольника: его сужают под отступ текста
					Local $tRect = _WinAPI_CreateRect($tCD.Left, $tCD.Top, $tCD.Right, $tCD.Bottom)

					_WinAPI_SelectObject($hDC, _WinAPI_GetStockObject($DC_BRUSH))
					_WinAPI_SelectObject($hDC, _WinAPI_GetStockObject($DC_PEN))
					_WinAPI_SetBkMode($hDC, $TRANSPARENT)

					_WinAPI_SetDCBrushColor($hDC, $gc_iLvHeaderBk)
					_WinAPI_SetDCPenColor($hDC, $gc_iLvHeaderBk)
					_WinAPI_Rectangle($hDC, $tRect)

					; Разделитель колонок справа и линия снизу
					_WinAPI_SetDCPenColor($hDC, $gc_iLvGridLine)
					_WinAPI_DrawLine($hDC, $tRect.Right - 1, $tRect.Top, $tRect.Right - 1, $tRect.Bottom)
					_WinAPI_DrawLine($hDC, $tRect.Left, $tRect.Bottom - 1, $tRect.Right, $tRect.Bottom - 1)

					_WinAPI_SetTextColor($hDC, _WinAPI_SwitchColor($gc_iLvHeaderText))
					If $iCol = 1 Or $iCol = 3 Then
						$tRect.Right -= 9
						_WinAPI_DrawText($hDC, $g_aColumnNames[$iCol], $tRect, $DT_SINGLELINE + $DT_VCENTER + $DT_RIGHT)
					Else
						$tRect.Left += 6
						_WinAPI_DrawText($hDC, $g_aColumnNames[$iCol], $tRect, $DT_SINGLELINE + $DT_VCENTER)
					EndIf
					Return $CDRF_SKIPDEFAULT
			EndSwitch
		EndIf
	EndIf
	Return _WinAPI_DefSubclassProc($hWnd, $iMsg, $iwParam, $ilParam)
EndFunc   ;==>_LV_HeaderSubclass


Func _LV_SubclassCleanup()
	If $g_pLVFilter Then
		_WinAPI_RemoveWindowSubclass(GUICtrlGetHandle($g_iListView), $g_pLVFilter, 1000)
		_FluentSubclass_Free($g_pLVFilter)
		$g_pLVFilter = 0
	EndIf
	If $g_hLVCallback <> 0 Then
		DllCallbackFree($g_hLVCallback)
		$g_hLVCallback = 0
	EndIf
EndFunc   ;==>_LV_SubclassCleanup


; Тёмная тема списка. Список темизируется вручную: тема окна повесила бы на него свой
; AutoIt-сабкласс, через который шёл бы WM_PAINT (см. FluentSubclass.au3)
Func _SetDarkListView()
	Local $hLV = GUICtrlGetHandle($g_iListView)
	_FluentWinApi_AllowDarkModeForWindow($hLV, True)
	_WinAPI_SetWindowTheme($hLV, 'DarkMode_Explorer')
	_GUICtrlListView_SetExtendedListViewStyle($g_iListView, BitOR(_GUICtrlListView_GetExtendedListViewStyle($g_iListView), $LVS_EX_DOUBLEBUFFER))
	_WinAPI_SetWindowLong($hLV, $GWL_EXSTYLE, BitAND(_WinAPI_GetWindowLong($hLV, $GWL_EXSTYLE), BitNOT($WS_EX_CLIENTEDGE)))
	_WinAPI_SetWindowPos($hLV, 0, 0, 0, 0, 0, BitOR($SWP_NOMOVE, $SWP_NOSIZE, $SWP_NOZORDER, $SWP_FRAMECHANGED))
	GUICtrlSetColor($g_iListView, $gc_iLvRowText)
EndFunc   ;==>_SetDarkListView


Func _OnEvent_ShowInExplorer()
	Local $sPath = _SelectedFilePath()
	If $sPath = '' Then Return
	Local $aList[1] = [_GetFileName($sPath)]
	_WinAPI_ShellOpenFolderAndSelectItems(_GetFileDirPath($sPath), $aList, 0)
EndFunc   ;==>_OnEvent_ShowInExplorer


Func _OnEvent_CopyPath()
	Local $sPath = _SelectedFilePath()
	If $sPath <> '' Then ClipPut($sPath)
EndFunc   ;==>_OnEvent_CopyPath


; Путь файла выделенной строки или ''
Func _SelectedFilePath()
	Local $sRow = _GUICtrlListView_GetSelectedIndices($g_iListView)
	If $sRow = '' Then Return ''
	Return $g_aFileList[Int($sRow) + 1][1]
EndFunc   ;==>_SelectedFilePath


Func _OnEvent_Ok()
	If $g_bOkEnabled Then _CloseIfIdle()
EndFunc   ;==>_OnEvent_Ok


Func _OnEvent_Settings()
	ShellExecute(@ScriptDir & '\Settings.exe')
EndFunc   ;==>_OnEvent_Settings


Func _OnEvent_ClickDown()
	$g_bCloseTimer = False
	$g_bAutoScroll = False
	_AutoScrollToCurrent() ; снимает подсветку: дальше выделяет пользователь
	_SetOkButtonText("OK")
EndFunc   ;==>_OnEvent_ClickDown


Func _CompressFile()
	Local $sPathFile, $sExtensionFile, $iFileSize, $sActionName, $sActionCommand

	If Not $g_aFileList[0][0] Then Return

	; Explorer запускает Launcher на каждый файл, и файлы приходят в очередь постепенно.
	; Работа не завершается на каждой порции: иначе OK на мгновение становилась доступной,
	; а клик по ней закрывал программу вместе с остатком очереди
	Do
		For $i = $g_iFileIndex To $g_aFileList[0][0]
			; Файл без результата ещё не обработан
			If Not StringLen($g_aFileList[$i][4]) Then
				$sPathFile = $g_aFileList[$i][1]
				$sActionName = $g_aFileList[$i][2]
				$sActionCommand = $g_aFileList[$i][3]
				$sExtensionFile = _GetFileExtension($sPathFile)
				$iFileSize = FileGetSize($sPathFile)
				$g_iFileIndex = $i
				; Без паузы обновления: результат предыдущего файла и подсветка нового появляются
				; вместе, иначе строка перед подсвеченной какое-то время выглядела пропущенной
				_UpdateGUI(True)
				_SetLabel(False)
				$g_iProgressMax = Round($g_iFileIndex / $g_aFileList[0][0] * 100)
				If $g_iFileIndex > 1 Then
					_SetProcess(Round(Int($g_iFileIndex - 1) / $g_aFileList[0][0] * 100))
				EndIf

				_AddLogLine(@CR & StringFormat("%03s", $g_iFileIndex) & ' ' & $sActionName & ' (' & _
						($sActionCommand = 'loss' ? $sExtensionFile : $sActionCommand) & ')')
				_AddLogLine('    ' & $sPathFile)

				$g_iOrientPending = 0
				; cwebp не читает анимацию: сжатие давало случайный пропуск, а палитра - один первый кадр
				Local $sDispatch = $sActionCommand
				If $sExtensionFile = $FORMAT_WEBP And StringRegExp($sActionCommand, '^(loss|lossy|web|cq\d+)$') Then
					If _WebpIsAnimated($sPathFile) Then $sDispatch = 'unsupported'
				EndIf
				Switch $sDispatch
					Case 'unsupported'
						_UpdateGUI()
						_ShowResult($sPathFile, $iFileSize, 0, $STATUS_NOT_SUPPORTED)
					Case 'loss' ; Сжатие без потерь
						Switch $sExtensionFile
							Case 'avif', 'heic', 'heif'
								; ImageMagick не умеет AVIF без потерь: ключ heic:lossless он пропускает,
								; и файл пережимался с потерями (PSNR ~39 дБ). HEIC - та же история
								_UpdateGUI()
								_ShowResult($sPathFile, $iFileSize, 0, $STATUS_NOT_SUPPORTED)
							Case 'bmp'
								_CompressionBmp($sPathFile, $iFileSize, $sExtensionFile, $sActionName)
							Case 'gif'
								_CompressionGif($sPathFile, $iFileSize, $sExtensionFile, $sActionName)
							Case 'jfif'
								_CompressionJfif($sPathFile, $iFileSize, $sExtensionFile, $sActionName)
							Case 'jpg', 'jpe', 'jpeg'
								_CompressionJpg($sPathFile, $iFileSize, $sExtensionFile, $sActionName)
							Case 'jxl'
								_CompressionJxl($sPathFile, $iFileSize, $sExtensionFile, $sActionName)
							Case 'png'
								_CompressionPng($sPathFile, $iFileSize, $sExtensionFile, $sActionName)
							Case 'webp'
								_CompressionWebP($sPathFile, $iFileSize, $sExtensionFile, $sActionName)
							Case Else
								_UpdateGUI()
								_ShowResult($sPathFile, $iFileSize, 0, _IsDir($sPathFile) ? $STATUS_SKIPPED_FOLDER : $STATUS_SKIPPED)
						EndSwitch
					Case 'lossy' ; Сжатие с потерями
						_CompressionLossy($sPathFile, $iFileSize, $sExtensionFile, $sActionName)
					Case 'web' ; Сжатие для WEB
						_CompressionForWeb($sPathFile, $iFileSize, $sExtensionFile, $sActionName)
					Case 'toPng' ; -> png
						_ConvertToPng($sPathFile, $iFileSize, $sExtensionFile, $sActionName)
					Case 'toWebp' ; -> webp
						_ConvertToWebp($sPathFile, $iFileSize, $sExtensionFile, $sActionName)
					Case 'toJpg' ; -> jpg
						_ConvertToJpg($sPathFile, $iFileSize, $sExtensionFile, $sActionName)
					Case 'toJfif' ; -> jfif
						_ConvertToJpg($sPathFile, $iFileSize, $sExtensionFile, $sActionName, $FORMAT_JFIF)
					Case 'toJxl' ; -> jxl
						_ConvertToJxl($sPathFile, $iFileSize, $sExtensionFile, $sActionName)
					Case 'toAvif' ; -> avif
						_ConvertToAvif($sPathFile, $iFileSize, $sExtensionFile, $sActionName)
					Case 'toHeic' ; -> heic
						_ConvertToHeic($sPathFile, $iFileSize, $sExtensionFile, $sActionName)
					Case 'toGif' ; -> gif
						_ConvertToGif($sPathFile, $iFileSize, $sExtensionFile, $sActionName)
					Case 'toBmp' ; -> bmp
						_ConvertToBmp($sPathFile, $iFileSize, $sExtensionFile, $sActionName)
					Case Else
						If StringInStr($sActionCommand, 'cq') Then ; изменение палитры, например cq256
							_ColorQuantization($sPathFile, $iFileSize, $sExtensionFile, $sActionName)
						ElseIf StringLeft($sActionCommand, 3) = 'per' Then ; percent_50_0, старый формат per50
							_ResizePercent($sPathFile, $iFileSize, $sExtensionFile, $sActionName)
						ElseIf StringInStr($sActionCommand, 'resize') Then ; resize1000x1000x0
							_ResizePixel($sPathFile, $iFileSize, $sExtensionFile, $sActionName)
						Else
							_UpdateGUI()
							_ShowResult($sPathFile, $iFileSize, 0, _IsDir($sPathFile) ? $STATUS_SKIPPED_FOLDER : $STATUS_SKIPPED)
						EndIf
				EndSwitch

				; Ветка обработки не записала результат: считаем файл пропущенным,
				; иначе он навсегда остался бы в очереди
				If Not StringLen($g_aFileList[$i][4]) Then _ShowResult($sPathFile, $iFileSize, 0, $STATUS_SKIPPED)
			EndIf
		Next
	Until Not _WaitQueueFiles()

	; Таблица целиком: после завершения она больше не обновляется
	Do
		_UpdateGUI(True)
	Until $g_iRowsShown = $g_aFileList[0][0]

	$g_bComplete = True
	_AutoScrollToCurrent() ; подсветка переходит на последний файл

	_SetProcess(100)

	_StartTimerState()

	_SetLabel(True)
EndFunc   ;==>_CompressFile


; Забирает файлы, пришедшие в очередь во время обработки. Если свежие файлы только что
; приходили, ждёт затишья: следующий Launcher может ещё запускаться. True - есть что обрабатывать
Func _WaitQueueFiles()
	While 1
		_TakeTasks()
		If _HasPendingFiles() Then Return True
		If TimerDiff($g_hQueueAddTimer) >= $gc_iQueueQuietMs Then Return False
		Sleep(100)
	WEnd
EndFunc   ;==>_WaitQueueFiles


Func _SetLabel($bComplete)
	Local $sSavedPercent = _GetCompressingPercent($g_iAllWinnerSize, $g_iAllFileSize)
	Local $sSavedSize = _GetFileSizeStr($g_iAllFileSize - $g_iAllWinnerSize)
	GUICtrlSetData($g_iLblInfo, _
			($bComplete ? _Lang('Main', 'Complete', 'Complete') : _Lang('Main', 'Progress', 'Progress')) & _
			': ' & $g_iFileIndex & '/' & $g_aFileList[0][0] & _
			($sSavedPercent <> '' ? '    ' & _Lang('Main', 'Saved', 'Saved') & ': ' & $sSavedPercent : '') & _
			($sSavedSize <> '' ? '    ' & _Lang('Main', 'SizeTotal', 'Size') & ': -' & $sSavedSize : ''))

	Local $iPercent = $bComplete ? 100 : Round(($g_iFileIndex - 1) / $g_aFileList[0][0] * 100)
	WinSetTitle($g_hGui, '', $gc_sAppName & '  [' & $iPercent & '%]' & _UpdateTitleSuffix())
EndFunc   ;==>_SetLabel


; Папка файла без завершающего '\'
Func _GetFileDirPath($sPathFile)
	Return StringLeft($sPathFile, StringInStr($sPathFile, '\', 0, -1) - 1)
EndFunc   ;==>_GetFileDirPath


Func _SetProcess($iPercent)
	GUICtrlSetData($g_iProgress, $iPercent)
EndFunc   ;==>_SetProcess


; Прогресс ползёт, пока работает утилита, но не доходит до доли следующего файла
Func _SetStepProcess($nStep)
	Local $nCurrProgress = GUICtrlRead($g_iProgress)
	If $nCurrProgress < Int($g_iProgressMax - 2) Then
		GUICtrlSetData($g_iProgress, $nCurrProgress + $nStep)
	EndIf
EndFunc   ;==>_SetStepProcess


Func _UpdateGUI($bForce = False)
	If $g_bComplete Then Return

	Local Static $hLastUpdate = 0
	If Not $bForce And TimerDiff($hLastUpdate) < $gc_iGuiUpdateMs And $g_iFileIndex <> $g_aFileList[0][0] Then Return
	$hLastUpdate = TimerInit()

	; Результаты в показанных строках. Файлы обрабатываются по порядку, поэтому после
	; первой строки без результата их нет и дальше
	Local $aResult
	For $i = $g_iLastUpdated + 1 To $g_iRowsShown
		If Not StringLen($g_aFileList[$i][4]) Then ExitLoop
		; Результат: размер|новый|процент|разница|задача - колонки с 1 по 5
		$aResult = StringSplit($g_aFileList[$i][4], '|')
		For $iCol = 1 To 5
			_UpdateListViewItemIfChanged($i - 1, $iCol, $aResult[$iCol])
		Next
		$g_iLastUpdated = $i
	Next

	; Новые строки порциями: десять тысяч строк разом надолго заняли бы окно
	Local $iLast = _Min($g_aFileList[0][0], $g_iRowsShown + $gc_iGuiRowsPerUpdate)
	If $iLast > $g_iRowsShown Then
		Local $sPathFile, $iRow
		_GUICtrlListView_BeginUpdate($g_iListView)
		For $i = $g_iRowsShown + 1 To $iLast
			$sPathFile = $g_aFileList[$i][1]
			$iRow = $i - 1
			_GUICtrlListView_AddItem($g_iListView, ' ' & _GetFileName($sPathFile), _GetIconIndexByPathFile($sPathFile))
			If StringLen($g_aFileList[$i][4]) Then
				$aResult = StringSplit($g_aFileList[$i][4], '|')
				For $iCol = 1 To 5
					If $aResult[$iCol] <> '' Then _GUICtrlListView_AddSubItem($g_iListView, $iRow, $aResult[$iCol], $iCol)
				Next
				If $i = $g_iLastUpdated + 1 Then $g_iLastUpdated = $i
			Else
				_GUICtrlListView_AddSubItem($g_iListView, $iRow, _GetActionStr($g_aFileList[$i][2]), 5)
			EndIf
		Next
		$g_iRowsShown = $iLast
		_GUICtrlListView_EndUpdate($g_iListView)
		_ListViewResize()
	EndIf

	; Строка нового файла могла появиться только сейчас
	_AutoScrollToCurrent()
EndFunc   ;==>_UpdateGUI


Func _UpdateListViewItemIfChanged($iIndex, $iSubItem, $sNewText)
	If _GUICtrlListView_GetItemText($g_iListView, $iIndex, $iSubItem) <> $sNewText Then
		_GUICtrlListView_SetItemText($g_iListView, $iIndex, $sNewText, $iSubItem)
	EndIf
EndFunc   ;==>_UpdateListViewItemIfChanged


; Прокручивает таблицу к обрабатываемому файлу и подсвечивает строку последнего
; обработанного: подсветка файла в работе, ещё без результата, выглядела как сбой.
; Подсветку рисует WM_NOTIFY по $g_iDoneRow, а не системное выделение: оно
; не видно без фокуса и мешало бы выделению пользователя.
; После завершения подсветка остаётся на последнем файле, снимает её клик по окну ($g_bAutoScroll = False)
Func _AutoScrollToCurrent()
	Local $iRow = -1
	If $g_bAutoScroll Then $iRow = $g_bComplete ? $g_iFileIndex - 1 : $g_iFileIndex - 2
	Local $iLastRow = _GUICtrlListView_GetItemCount($g_iListView) - 1
	If $iRow = $g_iDoneRow Or $iRow > $iLastRow Then Return

	Local $iOldRow = $g_iDoneRow
	$g_iDoneRow = $iRow
	If $iOldRow >= 0 Then _GUICtrlListView_RedrawItems($g_iListView, $iOldRow, $iOldRow)
	If $iRow < 0 Then Return

	_GUICtrlListView_RedrawItems($g_iListView, $iRow, $iRow)
	; Подсвеченная строка - по центру видимой части (при 5 строках под ней файл в работе
	; и ещё один), у конца списка ниже центра
	Local $iBelow = $iRow + Int(_GUICtrlListView_GetCounterPage($g_iListView) / 2)
	_GUICtrlListView_EnsureVisible($g_iListView, $iBelow < $iLastRow ? $iBelow : $iLastRow)
	_GUICtrlListView_EnsureVisible($g_iListView, $iRow)
EndFunc   ;==>_AutoScrollToCurrent


; Записывает результат текущего файла очереди в строку для таблицы и журнал.
; $iStatusError - $STATUS_*, 0 - файл сжат или сконвертирован в $iWinnerSize байт
Func _ShowResult($sPathFile, $iFileSize, $iWinnerSize, $iStatusError = 0)
	Local $sActionCommand, $sCompressingSize, $sCompressingPercent

	If $g_aFileList[$g_iFileIndex][1] = $sPathFile Then
		$sActionCommand = $g_aFileList[$g_iFileIndex][3]

		Switch $iStatusError
			Case $STATUS_APP_ERROR
				$sCompressingSize = ''
				$sCompressingPercent = _Lang('Status', 'Error', 'error')
				$iWinnerSize = 0
			Case $STATUS_NOT_SUPPORTED
				$sCompressingSize = ''
				$sCompressingPercent = _Lang('Status', 'NotSupported', 'not supported')
				$iWinnerSize = 0
			Case $STATUS_SAVE_ERROR
				$sCompressingSize = ''
				$sCompressingPercent = _Lang('Status', 'SaveError', 'save error')
				$iWinnerSize = $iFileSize
			Case $STATUS_PALETTE_LARGER
				$sCompressingSize = ''
				$sCompressingPercent = _Lang('Status', 'PaletteLarger', 'few colors')
				$iWinnerSize = 0
			Case $STATUS_SKIPPED_FOLDER
				$sCompressingSize = ''
				$sCompressingPercent = _Lang('Status', 'Skipped', 'skipped')
				$iWinnerSize = 0
			Case $STATUS_SKIPPED
				$sCompressingSize = ''
				$sCompressingPercent = _Lang('Status', 'Skipped', 'skipped')
				$iWinnerSize = $iFileSize
			Case Else
				$sCompressingSize = _GetCompressingSize($iWinnerSize, $iFileSize)
				$sCompressingPercent = _GetCompressingPercent($iWinnerSize, $iFileSize)

				; Итог «сэкономлено» - только у сжатия: у конвертации и ресайза размер меняется по другой причине
				If StringInStr($sActionCommand, 'cq') Or $sActionCommand = 'lossy' Or $sActionCommand = 'web' Or $sActionCommand = 'loss' Then
					$g_iAllWinnerSize += $iWinnerSize
					$g_iAllFileSize += $iFileSize
				EndIf
		EndSwitch

		_AddLogLine($sCompressingPercent & ', ' & $sCompressingSize)

		; Строка таблицы: размер|новый|процент|разница|задача
		$g_aFileList[$g_iFileIndex][4] = _GetFileSizeStr($iFileSize) & '|' & _GetFileSizeStr($iWinnerSize) & '|' & _
				$sCompressingPercent & '|' & $sCompressingSize & '|' & _GetActionStr($g_aFileList[$g_iFileIndex][2])
	EndIf
EndFunc   ;==>_ShowResult


Func _GetActionStr($sActionName)
	If Not MapExists($g_oActionTitle, $sActionName) Then _
			$g_oActionTitle[$sActionName] = _ActionRead($sActionName, 'ShortGuiTitle')
	Return $g_oActionTitle[$sActionName]
EndFunc   ;==>_GetActionStr


; Иконка кешируется по расширению: у всех файлов одного типа она одна
Func _GetIconIndexByPathFile($sPathFile)
	Local $sExtension = _IsDir($sPathFile) ? "folder" : _GetFileExtension($sPathFile)
	If MapExists($g_oIconMap, $sExtension) Then Return $g_oIconMap[$sExtension]

	Local $aIconInfo = _ExplorerIcon_Get($sPathFile)
	; -1 при сбое: строка будет без иконки, а в кеш попадёт, чтобы не пробовать на каждом файле
	Local $iIndex = _GUIImageList_AddIcon($g_hImageList, $aIconInfo[1], $aIconInfo[2])
	$g_oIconMap[$sExtension] = $iIndex
	Return $iIndex
EndFunc   ;==>_GetIconIndexByPathFile


Func _OnEvent_WM_GETMINMAXINFO($hWnd, $iMsg, $wParam, $lParam)
	#forceref $iMsg, $wParam
	If $hWnd = $g_hGui Then
		Local $tMINMAXINFO = DllStructCreate("int;int;" & _
				"int MaxSizeX; int MaxSizeY;" & _
				"int MaxPositionX;int MaxPositionY;" & _
				"int MinTrackSizeX; int MinTrackSizeY;" & _
				"int MaxTrackSizeX; int MaxTrackSizeY", _
				$lParam)
		DllStructSetData($tMINMAXINFO, "MinTrackSizeX", $gc_iGuiMinW)
		DllStructSetData($tMINMAXINFO, "MinTrackSizeY", $gc_iGuiMinH)

		_ListViewResize()
	EndIf
	Return $GUI_RUNDEFMSG
EndFunc   ;==>_OnEvent_WM_GETMINMAXINFO


; Колонка файла забирает всю ширину, свободную от остальных колонок и полосы прокрутки
Func _ListViewResize()
	Local $aPos = ControlGetPos($g_hGui, '', $g_iListView)
	If @error Then Return

	; Строки выше таблицы - справа полоса прокрутки шириной 17. Поправка 18 подобрана
	Local $iWidth = $aPos[2]
	If _GUICtrlListView_ApproximateViewHeight($g_iListView) - 18 > $aPos[3] Then $iWidth -= 17
	For $iCol = 1 To 5
		$iWidth -= _GUICtrlListView_GetColumnWidth($g_iListView, $iCol)
	Next
	_GUICtrlListView_SetColumnWidth($g_iListView, 0, $iWidth)
EndFunc   ;==>_ListViewResize


Func _CheckFileListUpdate()
	If Not $g_bShown Then
		$g_bShown = True
		GUISetState(@SW_SHOW, $g_hGui)
	EndIf

	_TakeTasks()

	; Очередь пополнилась, в том числе у окна, открытого без файлов и уже «завершённого»
	If _HasPendingFiles() Then
		If $g_bComplete Then
			$g_bComplete = False
			_ResetTimerState()
		EndIf
		_CompressFile()
	EndIf
EndFunc   ;==>_CheckFileListUpdate


; Есть файлы, ещё не получившие результата
Func _HasPendingFiles()
	For $i = $g_iFileIndex To $g_aFileList[0][0]
		If $g_aFileList[$i][1] <> '' And Not StringLen($g_aFileList[$i][4]) Then Return True
	Next
	Return False
EndFunc   ;==>_HasPendingFiles


Func _StartTimerState()
	If $g_bCloseTimer Then
		$g_hCloseTimer = TimerInit()
		AdlibRegister("_TimerUpdate", 200)
	Else
		_SetOkButtonText("OK")
	EndIf
	_SetOkEnabled(True)
EndFunc   ;==>_StartTimerState


Func _ResetTimerState()
	AdlibUnRegister("_TimerUpdate")

	_SetOkButtonText(_OkCountdownText())
	_SetOkEnabled(False)
EndFunc   ;==>_ResetTimerState


; Подпись OK с отсчётом до закрытия, пока он идёт
Func _OkCountdownText()
	Return $g_bCloseTimer ? "OK (" & $g_iCloseSec & ")" : "OK"
EndFunc   ;==>_OkCountdownText


Func _TimerUpdate()
	Local $iLeftMs = ($g_iCloseSec + 1) * 1000 - Int(TimerDiff($g_hCloseTimer))

	If $iLeftMs <= 1000 And $g_bCloseTimer Then
		_CloseIfIdle()
		Return
	EndIf

	If $g_bCloseTimer Then
		_SetOkButtonText("OK (" & Int($iLeftMs / 1000) & ")")
	Else
		_SetOkButtonText("OK")
		AdlibUnRegister("_TimerUpdate")
	EndIf
EndFunc   ;==>_TimerUpdate


Func _SetOkButtonText($sText)
	; Скин перерисовывает кнопку, только если подпись изменилась
	_FluentButton_SetText($g_iBtnOk, $sText)
EndFunc   ;==>_SetOkButtonText


Func _SetOkEnabled($bEnabled)
	$g_bOkEnabled = $bEnabled
	_FluentButton_SetEnabled($g_iBtnOk, $bEnabled)
EndFunc   ;==>_SetOkEnabled


; ============================================================
; Обновления
; ============================================================

; Пометка по прошлой проверке сразу, а раз в неделю - новая проверка в фоне.
; Запрос делает Launcher.exe отдельным процессом: окно не ждёт сеть
Func _UpdateCheckOnStart()
	$g_sUpdateVersion = _MothUpdateAvailable()
	If $g_sUpdateVersion <> '' Then _ApplyUpdateNotice()
	If Not _MothUpdateCheckDue() Then Return
	$g_hUpdateProcess = _MothUpdateCheckStart()
	If $g_hUpdateProcess Then AdlibRegister('_UpdateCheckTick', 1000)
EndFunc   ;==>_UpdateCheckOnStart


Func _UpdateCheckTick()
	If _MothUpdateCheckPoll($g_hUpdateProcess) = -1 Then Return
	AdlibUnRegister('_UpdateCheckTick')
	$g_sUpdateVersion = _MothUpdateAvailable()
	If $g_sUpdateVersion <> '' Then _ApplyUpdateNotice()
EndFunc   ;==>_UpdateCheckTick


; Новая версия уже в релизах: пометка в заголовке, подсказка и мигающая шестерёнка
Func _ApplyUpdateNotice()
	GUICtrlSetTip($g_iBtnSettings, _LangFile_Format('Updates', 'Available', 'Version %1 is available', $g_sUpdateVersion))
	Local $sTitle = WinGetTitle($g_hGui)
	If Not StringInStr($sTitle, _UpdateTitleSuffix()) Then WinSetTitle($g_hGui, '', $sTitle & _UpdateTitleSuffix())
	If $g_bPulse Then Return
	$g_bPulse = True
	AdlibRegister('_PulseSettingsButton', 600)
EndFunc   ;==>_ApplyUpdateNotice


Func _UpdateTitleSuffix()
	If $g_sUpdateVersion = '' Then Return ''
	Return '  ' & _Lang('Updates', 'TitleUpdate', '[update available]')
EndFunc   ;==>_UpdateTitleSuffix


Func _PulseSettingsButton()
	_FluentButton_SetOn($g_iBtnSettings, $g_bPulsePhase)
	$g_bPulsePhase = Not $g_bPulsePhase
EndFunc   ;==>_PulseSettingsButton


; Задания, принятые окном-приёмником (Include\CopyDataQueue.au3), в очередь файлов
Func _TakeTasks()
	If Not _CopyDataQueue_Pending() Then Return
	$g_bTaking = True
	Local $aSplit, $bAdded = False
	For $sLine In _CopyDataQueue_Take()
		; Строка «путь|действие», строка без действия отбрасывается
		$aSplit = StringSplit($sLine, '|')
		If $aSplit[0] < 2 Or $aSplit[2] = '' Then ContinueLoop
		_AddToFileListData($aSplit[1], $aSplit[2], 'Launcher')
		$bAdded = True
	Next
	$g_bTaking = False
	If Not $bAdded Then Return
	$g_hQueueAddTimer = TimerInit()

	; Поднять окно над остальными, не оставляя его поверх всех
	WinSetOnTop($g_hGui, '', 1)
	WinSetOnTop($g_hGui, '', 0)
EndFunc   ;==>_TakeTasks


Func _AddToFileListData($sPathFile, $sActionName, $sAddSource)
	Local $aFileList, $sActionCommand

	$sPathFile = StringStripWS($sPathFile, 3)
	If Not MapExists($g_oActionCommand, $sActionName) Then _
			$g_oActionCommand[$sActionName] = _ActionRead($sActionName, 'Command')
	$sActionCommand = $g_oActionCommand[$sActionName]

	; Папка раскрывается в картинки поддерживаемых форматов, пустая - остаётся строкой «пропуск»
	If _IsDir($sPathFile) Then
		$aFileList = _FO_FileSearch($sPathFile, _ArrayToString(_GetExtensionListExpanded(), '|'), True, 125, 1, 1, 2)
		If Not @error Then
			Local $iNeededSize = $g_iFileCount + $aFileList[0]
			If $iNeededSize >= UBound($g_aFileList) Then
				ReDim $g_aFileList[$iNeededSize + $gc_iFileListChunk][5]
			EndIf

			For $i = 1 To $aFileList[0]
				$g_iFileCount += 1
				$g_aFileList[$g_iFileCount][0] = $sAddSource
				$g_aFileList[$g_iFileCount][1] = $aFileList[$i]
				$g_aFileList[$g_iFileCount][2] = $sActionName
				$g_aFileList[$g_iFileCount][3] = $sActionCommand
			Next

			$g_aFileList[0][0] = $g_iFileCount
			Return
		EndIf
	EndIf

	If $g_iFileCount + 1 >= UBound($g_aFileList) Then
		ReDim $g_aFileList[$g_iFileCount + $gc_iFileListChunk][5]
	EndIf

	$g_iFileCount += 1
	$g_aFileList[$g_iFileCount][0] = $sAddSource
	$g_aFileList[$g_iFileCount][1] = $sPathFile
	$g_aFileList[$g_iFileCount][2] = $sActionName
	$g_aFileList[$g_iFileCount][3] = $sActionCommand
	$g_aFileList[0][0] = $g_iFileCount
EndFunc   ;==>_AddToFileListData


; ============================================================
; Палитра
; ============================================================

Func _ColorQuantization($sPathFile, $iFileSize, $sExtensionFile, $sActionName)
	If Not _IsFormatSupported($sExtensionFile, $sActionName) Then
		_UpdateGUI()
		_ShowResult($sPathFile, $iFileSize, 0, $STATUS_NOT_SUPPORTED)
		Return
	EndIf

	Local $sWinnerPath, $sTempPath, $sSourceFile, $iError
	Local $sColors = _GetNumberFromString(_IniString_Read($gc_sMothIni, $sActionName, 'Command'))

	; Квантизация цвета. Дизеринг Riemersma идёт по кривой Гильберта: на градиентах
	; меньше шума, чем у Floyd-Steinberg, и файл на тестовых PNG выходит на 25-40% меньше.
	; WEBP и JXL уходят в PNG, а после палитры упаковываются обратно без потерь
	$sSourceFile = $sPathFile
	If $sExtensionFile <> $FORMAT_PNG Then
		$sSourceFile = _DecodeToPng($sPathFile, $sExtensionFile)
		If @error Then
			_ShowResult($sPathFile, $iFileSize, 0, $STATUS_APP_ERROR)
			Return
		EndIf
	EndIf

	; Палитру можно только уменьшить: заказ больше, чем цветов в картинке, - ошибка
	Local $iColors = _ColorCount($sSourceFile)
	If $iColors > 0 And Int($sColors) > $iColors Then
		_ShowResult($sPathFile, $iFileSize, 0, $STATUS_PALETTE_LARGER)
		Return
	EndIf

	$sTempPath = _CompressionRun('magick', '{pathFile} -quiet -dither Riemersma -colors ' & $sColors & ' {pathFile}', $sSourceFile, $FORMAT_PNG)
	If @error Then
		_ShowResult($sPathFile, $iFileSize, 0, $STATUS_APP_ERROR)
		Return
	EndIf

	Switch $sExtensionFile
		Case $FORMAT_WEBP
			$sWinnerPath = _ConvertRun('cwebp', '-lossless -z 9 -mt' & _WebpMetaArgs(_IccKeep($sPathFile)) & ' {pathFile} -o {pathFileOut}', $sTempPath, _GetTempPathFileForCompression('cwebp', $FORMAT_WEBP))
			$iError = @error
		Case $FORMAT_JXL
			$sWinnerPath = _ConvertRun('cjxl', '{pathFile} {pathFileOut} -d 0 -e 9 --quiet', $sTempPath, _GetTempPathFileForCompression('cjxl', $FORMAT_JXL))
			$iError = @error
		Case Else
			; ImageMagick пишет PNG без оптимизации: без доочистки файл выходил больше исходного
			$sWinnerPath = _CompressionRun('pingo', '-lossless {pathFile}', $sTempPath, $FORMAT_PNG)
			If @error Then $sWinnerPath = $sTempPath
	EndSwitch
	If $sWinnerPath <> $sTempPath Then FileDelete($sTempPath)
	If $iError Then
		_ShowResult($sPathFile, $iFileSize, 0, $STATUS_APP_ERROR)
		Return
	EndIf

	; Палитру заказывают ради числа цветов, поэтому она сохраняется, даже если файл вырос
	Local $nWinnerSize = FileGetSize($sWinnerPath)
	If $nWinnerSize <= 0 Then
		_ShowResult($sPathFile, $iFileSize, 0, $STATUS_APP_ERROR)
		Return
	EndIf
	Local $bSaved = _FileSave($sWinnerPath, $sPathFile, $sExtensionFile, $sActionName)
	_ShowResult($sPathFile, $iFileSize, $nWinnerSize, $bSaved ? 0 : $STATUS_SAVE_ERROR)
EndFunc   ;==>_ColorQuantization


; Сколько разных цветов в картинке (первый кадр), 0 - узнать не удалось
Func _ColorCount($sPathFile)
	Return Int(StringStripWS(_RunReadOutput('magick', 'identify -quiet -format %k "' & $sPathFile & '[0]"'), 3))
EndFunc   ;==>_ColorCount


; Вывод утилиты из Apps целиком, '' - не запустилась. Sleep в цикле не держит окно
Func _RunReadOutput($sUtilName, $sArgs, $iStream = $STDOUT_CHILD)
	Local $iPid = Run('"' & @ScriptDir & '\apps\' & $sUtilName & '.exe" ' & $sArgs, '', @SW_HIDE, $iStream)
	If Not $iPid Then Return ''
	Local $sOut = ''
	While 1
		$sOut &= StdoutRead($iPid)
		If @error Then ExitLoop
		Sleep(10)
	WEnd
	Return $sOut
EndFunc   ;==>_RunReadOutput


; ============================================================
; Ресайз
; ============================================================

Func _ResizePercent($sPathFile, $iFileSize, $sExtensionFile, $sActionName)
	If Not _IsFormatSupported($sExtensionFile, $sActionName) Then
		_UpdateGUI()
		_ShowResult($sPathFile, $iFileSize, 0, $STATUS_NOT_SUPPORTED)
		Return
	EndIf

	Local $sWinnerPath, $iWinnerSize, $sActionCommand, $aLineSplit
	Local $sPercent, $sFilter = 0

	; percent_<проценты>_<фильтр>
	$sActionCommand = _ActionRead($sActionName, 'Command')
	$aLineSplit = StringSplit($sActionCommand, '_')
	If $aLineSplit[0] = 3 Then
		$sPercent = $aLineSplit[2]
		$sFilter = $aLineSplit[3]
	ElseIf StringRegExp($sActionCommand, '^per\d+$') Then
		; Формат 1.36 и раньше: per50, фильтр по умолчанию
		$sPercent = _GetNumberFromString($sActionCommand)
	Else
		_ShowResult($sPathFile, $iFileSize, 0, $STATUS_SKIPPED)
		Return
	EndIf

	; -filter - настройка, она действует на операции после себя, поэтому стоит до -resize
	$sWinnerPath = _CompressionRun('magick', '{pathFile} -quiet -filter ' & _GetFilterNameByIndx($sFilter) & ' -resize ' & $sPercent & '%' & _
			_MagickEncodeArgs($sPathFile, $sExtensionFile) & ' {pathFile}', $sPathFile, $sExtensionFile)
	If @error Then
		_ShowResult($sPathFile, $iFileSize, 0, $STATUS_APP_ERROR)
		Return
	EndIf

	$iWinnerSize = FileGetSize($sWinnerPath)
	If $iWinnerSize <= 0 Then
		_ShowResult($sPathFile, $iFileSize, 0, $STATUS_APP_ERROR)
		Return
	EndIf

	Local $bSaved = _FileSave($sWinnerPath, $sPathFile, $sExtensionFile, $sActionName)
	_ShowResult($sPathFile, $iFileSize, $iWinnerSize, $bSaved ? 0 : $STATUS_SAVE_ERROR)
EndFunc   ;==>_ResizePercent


Func _ResizePixel($sPathFile, $iFileSize, $sExtensionFile, $sActionName)
	If Not _IsFormatSupported($sExtensionFile, $sActionName) Then
		_UpdateGUI()
		_ShowResult($sPathFile, $iFileSize, 0, $STATUS_NOT_SUPPORTED)
		Return
	EndIf

	Local $sWinnerPath, $iWinnerSize, $sActionCommand, $aLineSplit
	Local $sUtilParams, $sSize, $iMode

	; resize_<ширина>_<высота>_<режим>_<фильтр>[_1 - увеличивать]
	$sActionCommand = _ActionRead($sActionName, 'Command')
	$aLineSplit = StringSplit($sActionCommand, '_')
	If $aLineSplit[0] <> 5 And $aLineSplit[0] <> 6 Then
		_ShowResult($sPathFile, $iFileSize, 0, $STATUS_SKIPPED)
		Return
	EndIf

	; Сторона 0 - по пропорции: 1920x задаёт только ширину. Заполнять тогда нечего
	$sSize = (Int($aLineSplit[2]) > 0 ? $aLineSplit[2] : '') & 'x' & (Int($aLineSplit[3]) > 0 ? $aLineSplit[3] : '')
	$iMode = (StringLeft($sSize, 1) = 'x' Or StringRight($sSize, 1) = 'x') ? 0 : Int($aLineSplit[4])

	; Поворот по Exif - до ресайза: сторона размера - сторона картинки, как её видно.
	; -filter - настройка, она действует на операции после себя, поэтому стоит до -resize
	$sUtilParams = '{pathFile} -quiet -auto-orient -filter ' & _GetFilterNameByIndx($aLineSplit[5]) & ' -resize ' & $sSize
	If $iMode > 0 Then $sUtilParams &= '^'
	; > - только уменьшать: картинка меньше размера остаётся как есть
	If $aLineSplit[0] < 6 Or $aLineSplit[6] <> '1' Then $sUtilParams &= '>'
	; Обрезка, а не -extent: у неувеличенной картинки -extent дорисовал бы поля
	If $iMode = 2 Then $sUtilParams &= ' -gravity center -crop ' & $sSize & '+0+0 +repage'

	$sUtilParams &= _MagickEncodeArgs($sPathFile, $sExtensionFile) & ' {pathFile}'

	$sWinnerPath = _CompressionRun('magick', $sUtilParams, $sPathFile, $sExtensionFile)
	If @error Then
		_ShowResult($sPathFile, $iFileSize, 0, $STATUS_APP_ERROR)
		Return
	EndIf

	$iWinnerSize = FileGetSize($sWinnerPath)
	If $iWinnerSize <= 0 Then
		_ShowResult($sPathFile, $iFileSize, 0, $STATUS_APP_ERROR)
		Return
	EndIf

	Local $bSaved = _FileSave($sWinnerPath, $sPathFile, $sExtensionFile, $sActionName)
	_ShowResult($sPathFile, $iFileSize, $iWinnerSize, $bSaved ? 0 : $STATUS_SAVE_ERROR)
EndFunc   ;==>_ResizePixel


; Параметры записи ImageMagick, когда результат остаётся в исходном формате. Без них
; WEBP и JXL без потерь сохранялись бы с потерями, а AVIF - с заниженным качеством
Func _MagickEncodeArgs($sPathFile, $sExtensionFile)
	Switch $sExtensionFile
		Case $FORMAT_WEBP
			Return _WebpIsLossless($sPathFile) ? ' -define webp:lossless=true' : ' -quality 90'
		Case $FORMAT_JXL
			Return _JxlKind($sPathFile) = 'lossless' ? ' -quality 100' : ' -quality 90'
		Case $FORMAT_AVIF
			Return ' -quality 80'
	EndSwitch
	Return ''
EndFunc   ;==>_MagickEncodeArgs


; ============================================================
; Конвертация
; ============================================================

Func _ConvertToPng($sPathFile, $iFileSize, $sExtensionFile, $sActionName)
	If Not _IsFormatSupported($sExtensionFile, $sActionName) Then
		_UpdateGUI()
		_ShowResult($sPathFile, $iFileSize, 0, $sExtensionFile = $FORMAT_PNG ? $STATUS_SKIPPED : $STATUS_NOT_SUPPORTED)
		Return
	EndIf

	; Конвертация: поворот по Exif, у анимации первый кадр, HEIC в sRGB
	Local $sPathFilePng = _DecodeToPng($sPathFile, $sExtensionFile)
	If @error Then
		_ShowResult($sPathFile, $iFileSize, 0, $STATUS_APP_ERROR)
		Return
	EndIf
	; Оптимизация без потерь: pingo без -lossless урезает палитру
	Local $sWinnerPath = _CompressionRun('pingo', '-lossless {pathFile}', $sPathFilePng, $FORMAT_PNG)
	If @error Then $sWinnerPath = $sPathFilePng

	; Сохранение результата
	Local $iWinnerSize = FileGetSize($sWinnerPath)
	Local $bSaved = _FileSave($sWinnerPath, $sPathFile, $FORMAT_PNG, $sActionName)
	_ShowResult($sPathFile, $iFileSize, $iWinnerSize, $bSaved ? 0 : $STATUS_SAVE_ERROR)
EndFunc   ;==>_ConvertToPng


Func _ConvertToWebp($sPathFile, $iFileSize, $sExtensionFile, $sActionName)
	If Not _IsFormatSupported($sExtensionFile, $sActionName) Then
		_UpdateGUI()
		_ShowResult($sPathFile, $iFileSize, 0, $sExtensionFile = $FORMAT_WEBP ? $STATUS_SKIPPED : $STATUS_NOT_SUPPORTED)
		Return
	EndIf

	Local $sPathFileWebp = _GetTempPathFileForCompression('cwebp', $FORMAT_WEBP)
	Local $sSourceFile = $sPathFile, $sParams = '-lossless'

	; Без потерь из JPEG, PNG, BMP, GIF и JXL без потерь. AVIF, HEIC и JXL с потерями уже
	; потеряли детали, без потерь из них вышел бы огромный файл: для них качество 90
	Switch $sExtensionFile
		Case $FORMAT_JPG, $FORMAT_JPE, $FORMAT_JPEG, $FORMAT_JFIF
			$sSourceFile = _AutorotateJpg($sPathFile, $sExtensionFile, False, False)
			; Без потерь повернуть блоки нельзя: поворот по пикселям, тоже без потерь
			If $g_iOrientPending Then $sSourceFile = _DecodeToPng($sPathFile, $sExtensionFile)

		Case $FORMAT_GIF
			; Анимацию сохраняет только ImageMagick, cwebp читает один кадр
			$sPathFileWebp = _ConvertRun('magick', '{pathFile} -quiet -define webp:lossless=true {pathFileOut}', $sPathFile, $sPathFileWebp)
			$sSourceFile = ''

		Case $FORMAT_BMP, $FORMAT_AVIF, $FORMAT_HEIC, $FORMAT_HEIF
			$sSourceFile = _DecodeToPng($sPathFile, $sExtensionFile)
			If $sExtensionFile <> $FORMAT_BMP Then $sParams = '-q 90'

		Case $FORMAT_JXL
			Switch _JxlKind($sPathFile)
				Case 'jpeg'
					; Внутри исходный JPEG: дальше как у JPEG
					$sSourceFile = _ConvertRun('djxl', '{pathFile} {pathFileOut} --quiet', $sPathFile, _GetTempPathFileForCompression('djxl', $FORMAT_JPG))
					If Not @error Then
						Local $sRecJpg = $sSourceFile
						$sSourceFile = _AutorotateJpg($sRecJpg, $FORMAT_JPG, False, False)
						If $g_iOrientPending Then $sSourceFile = _DecodeToPng($sRecJpg, $FORMAT_JPG)
					EndIf
				Case 'lossless'
					$sSourceFile = _DecodeToPng($sPathFile, $sExtensionFile)
				Case Else
					$sSourceFile = _DecodeToPng($sPathFile, $sExtensionFile)
					$sParams = '-q 90'
			EndSwitch
	EndSwitch

	If $sSourceFile <> '' Then $sPathFileWebp = _ConvertRun('cwebp', $sParams & ' -mt' & _WebpMetaArgs(_IccKeep($sPathFile)) & ' {pathFile} -o {pathFileOut}', $sSourceFile, $sPathFileWebp)

	; Сохранение результата
	Local $iWinnerSize = FileGetSize($sPathFileWebp)
	If $iWinnerSize <= 0 Then
		_ShowResult($sPathFile, $iFileSize, 0, $STATUS_APP_ERROR)
		Return
	EndIf
	Local $bSaved = _FileSave($sPathFileWebp, $sPathFile, $FORMAT_WEBP, $sActionName)
	_ShowResult($sPathFile, $iFileSize, $iWinnerSize, $bSaved ? 0 : $STATUS_SAVE_ERROR)
EndFunc   ;==>_ConvertToWebp


; JPG и JFIF - один и тот же JPEG, у JFIF в начале обязателен заголовок APP0 «JFIF»
Func _ConvertToJpg($sPathFile, $iFileSize, $sExtensionFile, $sActionName, $sFormatOut = $FORMAT_JPG)
	If Not _IsFormatSupported($sExtensionFile, $sActionName) Then
		Local $iStatus = $STATUS_NOT_SUPPORTED
		If $sFormatOut = $FORMAT_JFIF Then
			If $sExtensionFile = $FORMAT_JFIF Then $iStatus = $STATUS_SKIPPED
		ElseIf $sExtensionFile = $FORMAT_JPG Or $sExtensionFile = $FORMAT_JPE Or $sExtensionFile = $FORMAT_JPEG Then
			$iStatus = $STATUS_SKIPPED
		EndIf
		_UpdateGUI()
		_ShowResult($sPathFile, $iFileSize, 0, $iStatus)
		Return
	EndIf

	Local $sPathFileJpg = _GetTempPathFileForCompression('magick', $FORMAT_JPG), $sWinnerPath, $iWinnerSize, $sSourceFile = $sPathFile
	; Прозрачность заливается белым: без заливки фон становился чёрным. У анимации первый кадр
	Local $sCommand = '{pathFile} -quiet -background white -alpha remove -alpha off {pathFileOut}'

	Switch $sExtensionFile
		Case $FORMAT_JPG, $FORMAT_JPE, $FORMAT_JPEG, $FORMAT_JFIF
			; Тот же JPEG: перекодировать незачем, только повернуть по Exif и сжать без потерь.
			; JPG в JPG сюда не доходит: его отсеял _IsFormatSupported
			$sPathFileJpg = _AutorotateJpg($sPathFile, $sExtensionFile, False, False)
			$sSourceFile = ''

		Case $FORMAT_JXL
			If _JxlKind($sPathFile) = 'jpeg' Then
				; Внутри исходный JPEG: djxl возвращает его байт в байт, дожимать нечего
				$sWinnerPath = _ConvertRun('djxl', '{pathFile} {pathFileOut} --quiet', $sPathFile, _GetTempPathFileForCompression('djxl', $FORMAT_JPG))
				If $sFormatOut = $FORMAT_JFIF Then _JpegAddJfifHeader($sWinnerPath)
				$iWinnerSize = FileGetSize($sWinnerPath)
				If $iWinnerSize <= 0 Then
					_ShowResult($sPathFile, $iFileSize, 0, $STATUS_APP_ERROR)
					Return
				EndIf
				Local $bSavedJpeg = _FileSave($sWinnerPath, $sPathFile, $sFormatOut, $sActionName)
				_ShowResult($sPathFile, $iFileSize, $iWinnerSize, $bSavedJpeg ? 0 : $STATUS_SAVE_ERROR)
				Return
			EndIf
			$sSourceFile = _DecodeToPng($sPathFile, $sExtensionFile)

		Case $FORMAT_GIF, $FORMAT_WEBP
			$sCommand = '{pathFile}[0] -quiet -background white -alpha remove -alpha off {pathFileOut}'

		Case $FORMAT_HEIC, $FORMAT_HEIF
			$sCommand = '{pathFile} -quiet -profile {sRGB.icc} -strip {pathFileOut}'
	EndSwitch

	; Конвертация
	If $sSourceFile <> '' Then $sPathFileJpg = _ConvertRun('magick', $sCommand, $sSourceFile, $sPathFileJpg)
	; Оптимизация без потерь: JPEG оптимизирует jpegoptim, pingo остаётся для PNG
	$sWinnerPath = _CompressionRun('jpegoptim', '{pathFile} --quiet --force -w ' & $g_iProcCount & _JpegStripArgs(_IccKeep($sPathFileJpg)) & ' --auto-mode', $sPathFileJpg, $FORMAT_JPG)
	If @error Then
		_ShowResult($sPathFile, $iFileSize, 0, $STATUS_APP_ERROR)
		Return
	EndIf
	_JpegRestoreOrientation($sWinnerPath)
	; jpegoptim с --strip-all вырезает и APP0
	If $sFormatOut = $FORMAT_JFIF Then _JpegAddJfifHeader($sWinnerPath)
	; Исходник не трогаем: без поворота _AutorotateJpg возвращает путь к нему самому
	If $sPathFileJpg <> $sPathFile Then FileDelete($sPathFileJpg)

	; Сохранение результата
	$iWinnerSize = FileGetSize($sWinnerPath)
	Local $bSaved = _FileSave($sWinnerPath, $sPathFile, $sFormatOut, $sActionName)
	_ShowResult($sPathFile, $iFileSize, $iWinnerSize, $bSaved ? 0 : $STATUS_SAVE_ERROR)
EndFunc   ;==>_ConvertToJpg


; JPEG упаковывается в JXL без потерь и обратимо: djxl вернёт исходный файл байт в байт,
; поворот по Exif сохраняется в заголовке JXL. PNG, GIF (с анимацией), BMP и WEBP без
; потерь идут в JXL без потерь, AVIF, HEIC и WEBP с потерями - визуально без потерь (-d 1)
Func _ConvertToJxl($sPathFile, $iFileSize, $sExtensionFile, $sActionName)
	If Not _IsFormatSupported($sExtensionFile, $sActionName) Then
		_UpdateGUI()
		_ShowResult($sPathFile, $iFileSize, 0, $sExtensionFile = $FORMAT_JXL ? $STATUS_SKIPPED : $STATUS_NOT_SUPPORTED)
		Return
	EndIf

	Local $sSourceFile = $sPathFile, $sParams
	Switch $sExtensionFile
		Case $FORMAT_JPG, $FORMAT_JPE, $FORMAT_JPEG, $FORMAT_JFIF
			$sParams = '-j 1'
		Case $FORMAT_PNG
			$sParams = '-d 0 -e 9'
		Case $FORMAT_GIF
			$sParams = '-d 0'
		Case Else
			$sParams = _IsLosslessSource($sPathFile, $sExtensionFile) ? '-d 0 -e 9' : '-d 1'
			$sSourceFile = _DecodeToPng($sPathFile, $sExtensionFile)
			If @error Then
				_ShowResult($sPathFile, $iFileSize, 0, $STATUS_APP_ERROR)
				Return
			EndIf
	EndSwitch

	Local $sWinnerPath = _ConvertRun('cjxl', '{pathFile} {pathFileOut} ' & $sParams & ' --quiet', $sSourceFile, _GetTempPathFileForCompression('cjxl', $FORMAT_JXL))
	Local $iWinnerSize = FileGetSize($sWinnerPath)
	If $iWinnerSize <= 0 Then
		_ShowResult($sPathFile, $iFileSize, 0, $STATUS_APP_ERROR)
		Return
	EndIf
	Local $bSaved = _FileSave($sWinnerPath, $sPathFile, $FORMAT_JXL, $sActionName)
	_ShowResult($sPathFile, $iFileSize, $iWinnerSize, $bSaved ? 0 : $STATUS_SAVE_ERROR)
EndFunc   ;==>_ConvertToJxl


; AVIF без потерь ImageMagick не пишет (heic:lossless он пропускает), поэтому качество 85:
; на фото и скриншотах 40-44 дБ, на глаз без потерь, а файл меньше исходного JPEG.
; Цвет без субдискретизации (4:4:4): при 4:2:0 цветной текст скриншотов размывался до ~29 дБ,
; а фото от 4:4:4 прибавляют в размере всего пару процентов.
; Профиль ImageMagick переносит, прозрачность сохраняется, у анимации первый кадр
Func _ConvertToAvif($sPathFile, $iFileSize, $sExtensionFile, $sActionName)
	If Not _IsFormatSupported($sExtensionFile, $sActionName) Then
		_UpdateGUI()
		_ShowResult($sPathFile, $iFileSize, 0, $sExtensionFile = $FORMAT_AVIF ? $STATUS_SKIPPED : $STATUS_NOT_SUPPORTED)
		Return
	EndIf

	Local $sPng = _DecodeToPng($sPathFile, $sExtensionFile)
	If @error Then
		_ShowResult($sPathFile, $iFileSize, 0, $STATUS_APP_ERROR)
		Return
	EndIf
	Local $sWinnerPath = _ConvertRun('magick', '{pathFile} -quiet -quality 85 -define heic:chroma=444 {pathFileOut}', $sPng, _GetTempPathFileForCompression('magick', $FORMAT_AVIF))
	FileDelete($sPng)
	_SaveConverted($sWinnerPath, $sPathFile, $iFileSize, $FORMAT_AVIF, $sActionName)
EndFunc   ;==>_ConvertToAvif


; HEIC пишет heif-enc (libheif и x265): ImageMagick его только читает. Качество 70: на фото
; и скриншотах ~43 дБ, на глаз без потерь, а файл меньше исходного JPEG. Цвет 4:2:0, как у iPhone:
; 4:4:4 чётче на цветном тексте, но его открывает не всякий просмотрщик HEIC.
; Профиль и прозрачность переносятся, у анимации первый кадр
Func _ConvertToHeic($sPathFile, $iFileSize, $sExtensionFile, $sActionName)
	If Not _IsFormatSupported($sExtensionFile, $sActionName) Then
		_UpdateGUI()
		Local $bHeic = $sExtensionFile = $FORMAT_HEIC Or $sExtensionFile = $FORMAT_HEIF
		_ShowResult($sPathFile, $iFileSize, 0, $bHeic ? $STATUS_SKIPPED : $STATUS_NOT_SUPPORTED)
		Return
	EndIf

	Local $sPng = _DecodeToPng($sPathFile, $sExtensionFile)
	If @error Then
		_ShowResult($sPathFile, $iFileSize, 0, $STATUS_APP_ERROR)
		Return
	EndIf
	; Кириллицу в пути heif-enc не понимает и молча ничего не пишет. Оба файла лежат в папке
	; временных, она же рабочая папка утилиты: хватает имён, а они латиницей
	Local $sHeic = _GetTempPathFileForCompression('heif-enc', $FORMAT_HEIC)
	Local $sWinnerPath = _ConvertRun('heif-enc', '-q 70 "' & _GetFileName($sPng) & '" -o "' & _GetFileName($sHeic) & '"', $sPng, $sHeic)
	FileDelete($sPng)
	_SaveConverted($sWinnerPath, $sPathFile, $iFileSize, $FORMAT_HEIC, $sActionName)
EndFunc   ;==>_ConvertToHeic


; GIF - 256 цветов и без профиля: цвет сначала переводится в sRGB, иначе фото
; с профилем P3 поблёкнет, палитра с тем же дизерингом, что у пункта «Палитра».
; Анимированный WEBP переносится с анимацией, у остальных первый кадр. Дожимает gifsicle
Func _ConvertToGif($sPathFile, $iFileSize, $sExtensionFile, $sActionName)
	If Not _IsFormatSupported($sExtensionFile, $sActionName) Then
		_UpdateGUI()
		_ShowResult($sPathFile, $iFileSize, 0, $sExtensionFile = $FORMAT_GIF ? $STATUS_SKIPPED : $STATUS_NOT_SUPPORTED)
		Return
	EndIf

	Local $sSourceFile = $sPathFile, $bTemp = False
	If Not ($sExtensionFile = $FORMAT_WEBP And _WebpIsAnimated($sPathFile)) Then
		$sSourceFile = _DecodeToPng($sPathFile, $sExtensionFile)
		If @error Then
			_ShowResult($sPathFile, $iFileSize, 0, $STATUS_APP_ERROR)
			Return
		EndIf
		$bTemp = True
	EndIf
	Local $sGif = _ConvertRun('magick', '{pathFile} -quiet -profile {sRGB.icc} -strip -dither Riemersma -colors 256 {pathFileOut}', _
			$sSourceFile, _GetTempPathFileForCompression('magick', $FORMAT_GIF))
	If $bTemp Then FileDelete($sSourceFile)
	If FileGetSize($sGif) <= 0 Then
		_ShowResult($sPathFile, $iFileSize, 0, $STATUS_APP_ERROR)
		Return
	EndIf
	Local $sWinnerPath = _CompressionRun('gifsicle', '-w -j --no-conserve-memory -o {pathFile} -O3 --no-comments --no-extensions --no-names {pathFile}', $sGif, $FORMAT_GIF)
	If @error Or FileGetSize($sWinnerPath) <= 0 Then
		$sWinnerPath = $sGif
	Else
		FileDelete($sGif)
	EndIf
	_SaveConverted($sWinnerPath, $sPathFile, $iFileSize, $FORMAT_GIF, $sActionName)
EndFunc   ;==>_ConvertToGif


; BMP без сжатия, профиля и прозрачности: альфу BMP просмотрщики понимают плохо,
; поэтому фон заливается белым, как у JPG, а цвет переводится в sRGB. Дожимает ImageWorsener
Func _ConvertToBmp($sPathFile, $iFileSize, $sExtensionFile, $sActionName)
	If Not _IsFormatSupported($sExtensionFile, $sActionName) Then
		_UpdateGUI()
		_ShowResult($sPathFile, $iFileSize, 0, $sExtensionFile = $FORMAT_BMP ? $STATUS_SKIPPED : $STATUS_NOT_SUPPORTED)
		Return
	EndIf

	Local $sPng = _DecodeToPng($sPathFile, $sExtensionFile)
	If @error Then
		_ShowResult($sPathFile, $iFileSize, 0, $STATUS_APP_ERROR)
		Return
	EndIf
	Local $sBmp = _ConvertRun('magick', '{pathFile} -quiet -profile {sRGB.icc} -strip -background white -alpha remove -alpha off {pathFileOut}', _
			$sPng, _GetTempPathFileForCompression('magick', $FORMAT_BMP))
	FileDelete($sPng)
	If FileGetSize($sBmp) <= 0 Then
		_ShowResult($sPathFile, $iFileSize, 0, $STATUS_APP_ERROR)
		Return
	EndIf
	Local $sWinnerPath = _CompressionRun('imagew', '-opt bmp:version=auto -noresize -zipcmprlevel 9 -outfmt bmp -compress "rle" {pathFile} {pathFile}', $sBmp, $FORMAT_BMP)
	If @error Or FileGetSize($sWinnerPath) <= 0 Or FileGetSize($sWinnerPath) >= FileGetSize($sBmp) Then
		FileDelete($sWinnerPath)
		$sWinnerPath = $sBmp
	Else
		FileDelete($sBmp)
	EndIf
	_SaveConverted($sWinnerPath, $sPathFile, $iFileSize, $FORMAT_BMP, $sActionName)
EndFunc   ;==>_ConvertToBmp


; Сохраняет результат конвертации рядом с исходником. Конвертация выполняется
; при любом размере: пользователь просил другой формат, а не файл поменьше
Func _SaveConverted($sWinnerPath, $sPathFile, $iFileSize, $sFormat, $sActionName)
	Local $iWinnerSize = FileGetSize($sWinnerPath)
	If $iWinnerSize <= 0 Then
		_ShowResult($sPathFile, $iFileSize, 0, $STATUS_APP_ERROR)
		Return
	EndIf
	Local $bSaved = _FileSave($sWinnerPath, $sPathFile, $sFormat, $sActionName)
	_ShowResult($sPathFile, $iFileSize, $iWinnerSize, $bSaved ? 0 : $STATUS_SAVE_ERROR)
EndFunc   ;==>_SaveConverted


Func _GetOrientationInfo($sPathFile)
	Local $sImageGetInfo = _ImageGetInfo($sPathFile)
	$sImageGetInfo = StringStripWS(StringReplace($sImageGetInfo, @LF, ";", 0, 2), 7)
	Return _ImageGetParam($sImageGetInfo, "Orientation")
EndFunc   ;==>_GetOrientationInfo


; Ключ jpegtran, который применяет ориентацию Exif, '' - поворот не нужен
Func _GetJpegtranRunKey($sOrientation)
	Local Static $aKeys = ['', '', '-flip horizontal', '-rotate 180', '-flip vertical', '-transpose', _
			'-rotate 90', '-transverse', '-rotate 270']
	Return $aKeys[_OrientationCode($sOrientation)]
EndFunc   ;==>_GetJpegtranRunKey


; ============================================================
; Цветовой профиль и поворот JPEG
; ============================================================

; Профиль нужно сохранить: он есть, и это не sRGB (Display P3 у снимков iPhone, Adobe RGB,
; CMYK). Без него цвета поблёкнут. Профиль sRGB для просмотрщика равен его отсутствию,
; такой вырезается вместе с остальными метаданными. Решение помнится, пока файл тот же:
; для JPEG его спрашивают по два раза, а это чтение всего файла
Func _IccKeep($sPathFile)
	Local Static $sCacheKey = '', $bCacheKeep = False
	Local $sKey = $sPathFile & '|' & FileGetSize($sPathFile) & '|' & FileGetTime($sPathFile, 0, 1)
	If $sKey = $sCacheKey Then Return $bCacheKeep

	Local $dIcc = _IccProfile_FromFile($sPathFile)
	If @error = 2 Then
		; Не JPEG и не WEBP: профиль достаёт ImageMagick. Нет профиля - нет и файла
		Local $sIcc = _ConvertRun('magick', '{pathFile}[0] -quiet {pathFileOut}', $sPathFile, _GetTempPathFileForCompression('magick', 'icc'))
		If @error Then
			$dIcc = Binary('')
		Else
			Local $hFile = FileOpen($sIcc, $FO_BINARY)
			$dIcc = FileRead($hFile)
			FileClose($hFile)
			FileDelete($sIcc)
		EndIf
	EndIf

	Local $bKeep = BinaryLen($dIcc) > 0 And Not _IccProfile_IsSrgb($dIcc)
	If BinaryLen($dIcc) = 0 Then
		_AddLogLine('    профиля нет')
	Else
		_AddLogLine('    профиль ' & ($bKeep ? 'не sRGB, сохраняется' : 'sRGB, вырезается'))
	EndIf
	$sCacheKey = $sKey
	$bCacheKeep = $bKeep
	Return $bKeep
EndFunc   ;==>_IccKeep


; Ключи jpegoptim: все метаданные прочь, профиль по решению _IccKeep
Func _JpegStripArgs($bKeepIcc)
	Return ' --strip-all' & ($bKeepIcc ? ' --keep-icc' : '')
EndFunc   ;==>_JpegStripArgs


; Ключ cwebp: по умолчанию он не переносит никаких метаданных, профиль переносится по решению _IccKeep
Func _WebpMetaArgs($bKeepIcc)
	Return $bKeepIcc ? ' -metadata icc' : ''
EndFunc   ;==>_WebpMetaArgs


; Поворот по Exif без потерь: jpegtran поворачивает блоки JPEG, не перекодируя их.
; С -perfect он отказывается, если край картинки не кратен блоку: без ключа крайний
; неполный блок остаётся на месте, и картинка сдвигается на несколько пикселей.
; Тогда пиксели не трогаются, а ориентация после сжатия возвращается в файл
; меткой (_JpegRestoreOrientation). Возвращает путь к повёрнутому или исходному файлу
Func _AutorotateJpg($sPathFile, $sExtensionFile, $bProgressive, $bSaveExif)
	$g_iOrientPending = 0

	; Exif остаётся - поворот сделает по нему просмотрщик
	If $bSaveExif Then Return $sPathFile

	Local $sOrientation = _GetOrientationInfo($sPathFile)
	Local $sRunKey = _GetJpegtranRunKey($sOrientation)
	If $sRunKey = '' Then Return $sPathFile
	If $bProgressive Then $sRunKey &= ' -progressive'

	; jpegtran умеет копировать только все метки или ни одной. Профиль не sRGB нужен:
	; без него цвета поблёкнут. Тогда копируются все, а Exif с ориентацией сразу
	; вырезает jpegoptim, иначе просмотрщик повернул бы картинку второй раз
	Local $bKeepIcc = _IccKeep($sPathFile)
	$sRunKey &= ' -perfect -copy ' & ($bKeepIcc ? 'all' : 'none') & ' -optimize {pathFile} {pathFileOut}'
	Local $sRotated = _ConvertRun('jpegtran', $sRunKey, $sPathFile, _GetTempPathFileForCompression('jpegtran', $sExtensionFile))
	If @error Or FileGetSize($sRotated) <= 0 Then
		FileDelete($sRotated)
		$g_iOrientPending = _OrientationCode($sOrientation)
		_AddLogLine('    поворот без потерь невозможен: край не кратен блоку JPEG, ориентация останется меткой')
		Return $sPathFile
	EndIf
	If Not $bKeepIcc Then Return $sRotated

	Local $sStripped = _CompressionRun('jpegoptim', '{pathFile} --quiet --force' & _JpegStripArgs(True), $sRotated, $sExtensionFile)
	If @error Then Return SetError(@error, 0, $sStripped)
	FileDelete($sRotated)
	Return $sStripped
EndFunc   ;==>_AutorotateJpg


; Код ориентации Exif по описанию из _GetOrientationInfo
Func _OrientationCode($sOrientation)
	Switch $sOrientation
		Case 'Mirrored'
			Return 2
		Case '180'
			Return 3
		Case '180 and mirrored'
			Return 4
		Case '90 left and mirrored'
			Return 5
		Case '90 right'
			Return 6
		Case '90 right and mirrored'
			Return 7
		Case '90 left'
			Return 8
	EndSwitch
	Return 0
EndFunc   ;==>_OrientationCode


; Возвращает в готовый JPEG ориентацию, которую не удалось применить без потерь:
; минимальный Exif из одного тега Orientation, без даты, камеры и GPS.
; Метка встаёт сразу после SOI или после APP0 (JFIF). Ничего не делает, если поворот не нужен
Func _JpegRestoreOrientation($sPathFile)
	If Not $g_iOrientPending Then Return
	Local $hFile = FileOpen($sPathFile, $FO_BINARY)
	If $hFile = -1 Then Return
	Local $dData = FileRead($hFile)
	FileClose($hFile)
	If BinaryMid($dData, 1, 2) <> Binary('0xFFD8') Then Return

	Local $iPos = 3 ; после SOI, счёт с единицы
	If BinaryMid($dData, 3, 2) = Binary('0xFFE0') Then
		$iPos = 5 + Int(BinaryMid($dData, 5, 1)) * 256 + Int(BinaryMid($dData, 6, 1))
	EndIf
	; APP1 длиной 34: "Exif\0\0", TIFF big-endian, один тег 0x0112 типа SHORT
	Local $dExif = Binary('0xFFE10022457869660000' & '4D4D002A00000008' & '0001' & _
			'011200030000000100' & Hex($g_iOrientPending, 2) & '0000' & '00000000')
	$hFile = FileOpen($sPathFile, BitOR($FO_OVERWRITE, $FO_BINARY))
	If $hFile = -1 Then Return
	FileWrite($hFile, BinaryMid($dData, 1, $iPos - 1) & $dExif & BinaryMid($dData, $iPos))
	FileClose($hFile)
	_AddLogLine('    ориентация ' & $g_iOrientPending & ' возвращена меткой Exif')
EndFunc   ;==>_JpegRestoreOrientation


; Заголовок APP0 «JFIF» встаёт сразу после SOI, если его нет. Сжатые данные не трогаются
Func _JpegAddJfifHeader($sPathFile)
	Local $hFile = FileOpen($sPathFile, $FO_BINARY)
	If $hFile = -1 Then Return
	Local $dData = FileRead($hFile)
	FileClose($hFile)
	If BinaryMid($dData, 1, 2) <> Binary('0xFFD8') Or BinaryMid($dData, 3, 2) = Binary('0xFFE0') Then Return

	; APP0 длиной 16: "JFIF\0", версия 1.01, плотность без единиц 1:1, без миниатюры
	Local $dJfif = Binary('0xFFE000104A46494600' & '0101' & '00' & '00010001' & '0000')
	$hFile = FileOpen($sPathFile, BitOR($FO_OVERWRITE, $FO_BINARY))
	If $hFile = -1 Then Return
	FileWrite($hFile, BinaryMid($dData, 1, 2) & $dJfif & BinaryMid($dData, 3))
	FileClose($hFile)
EndFunc   ;==>_JpegAddJfifHeader


; ============================================================
; Сжатие без потерь
; ============================================================

; Два варианта без потерь, jpegoptim и ECT, побеждает меньший
Func _CompressionJpg($sPathFile, $iFileSize, $sExtensionFile, $sActionName)
	Local $sWinnerPath, $sRunKey, $sPathFileJpg
	Local $bSaveExif = _IniString_Read($gc_sMothIni, $sActionName, 'SaveExif') = 1
	Local $bToProgressive = _IniString_Read($gc_sMothIni, $sActionName, 'ToProgressive') = 1

	; Без Exif пропал бы и поворот: применяем его заранее
	$sPathFileJpg = _AutorotateJpg($sPathFile, $sExtensionFile, $bToProgressive, $bSaveExif)
	Local $bKeepIcc = Not $bSaveExif And _IccKeep($sPathFile)

	$sRunKey = '{pathFile} --quiet --force -w ' & $g_iProcCount
	If Not $bSaveExif Then $sRunKey &= _JpegStripArgs($bKeepIcc)
	; auto-mode без потерь выбирает обычный или прогрессивный JPEG, что меньше:
	; на фото прогрессивный выходит на 3-8% легче
	$sRunKey &= $bToProgressive ? ' --all-progressive' : ' --auto-mode'
	Local $sPath1 = _CompressionRun('jpegoptim', $sRunKey, $sPathFileJpg, $sExtensionFile)
	Local $nSize1 = @error ? 0 : FileGetSize($sPath1)

	; Pingo для JPEG не годится: метаданные он вырезает по-своему
	$sRunKey = '-9 -quiet --strict --mt-deflate --mt-file'
	If Not $bSaveExif And Not $bKeepIcc Then $sRunKey &= ' -strip'
	If $bToProgressive Then $sRunKey &= ' -progressive'
	$sRunKey &= ' {pathFile}'
	; У ECT один ключ -strip на все метаданные, профиль он тоже вырезает. Когда профиль
	; нужен, ECT дожимает файл после jpegoptim, где кроме профиля уже ничего нет
	Local $sPath2 = '', $nSize2 = 0
	If Not $bKeepIcc Then
		$sPath2 = _CompressionRun('ect', $sRunKey, $sPathFileJpg, $sExtensionFile)
		$nSize2 = @error ? 0 : FileGetSize($sPath2)
	ElseIf $nSize1 > 0 Then
		$sPath2 = _CompressionRun('ect', $sRunKey, $sPath1, $sExtensionFile)
		$nSize2 = @error ? 0 : FileGetSize($sPath2)
	EndIf

	If $nSize1 = 0 And $nSize2 = 0 Then
		_ShowResult($sPathFile, $iFileSize, 0, $STATUS_APP_ERROR)
		Return
	EndIf

	; Меньший из вариантов, что удались
	If $nSize2 = 0 Or ($nSize1 > 0 And $nSize1 < $nSize2) Then
		$sWinnerPath = $sPath1
		If $nSize2 > 0 Then FileDelete($sPath2)
	Else
		$sWinnerPath = $sPath2
		If $nSize1 > 0 Then FileDelete($sPath1)
	EndIf

	; Ориентация, которую не удалось применить без потерь, возвращается меткой
	_JpegRestoreOrientation($sWinnerPath)
	_SaveIfSmaller($sWinnerPath, $sPathFile, $iFileSize, $sExtensionFile, $sActionName)
EndFunc   ;==>_CompressionJpg


Func _CompressionJfif($sPathFile, $iFileSize, $sExtensionFile, $sActionName)
	Local $sWinnerPath, $sPathFileJpg, $sRunKey
	Local $bSaveExif = _IniString_Read($gc_sMothIni, $sActionName, 'SaveExif') = 1
	Local $bToProgressive = _IniString_Read($gc_sMothIni, $sActionName, 'ToProgressive') = 1

	$sPathFileJpg = _AutorotateJpg($sPathFile, $sExtensionFile, $bToProgressive, $bSaveExif)

	$sRunKey = '{pathFile} --quiet --force -w ' & $g_iProcCount
	If Not $bSaveExif Then $sRunKey &= _JpegStripArgs(_IccKeep($sPathFile))
	$sRunKey &= $bToProgressive ? ' --all-progressive' : ' --auto-mode'
	$sWinnerPath = _CompressionRun('jpegoptim', $sRunKey, $sPathFileJpg, $sExtensionFile)
	If @error Then
		_ShowResult($sPathFile, $iFileSize, 0, $STATUS_APP_ERROR)
		Return
	EndIf
	_JpegRestoreOrientation($sWinnerPath)
	_SaveIfSmaller($sWinnerPath, $sPathFile, $iFileSize, $sExtensionFile, $sActionName)
EndFunc   ;==>_CompressionJfif


Func _CompressionGif($sFilePath, $nOriginalSize, $sExtension, $sAction)
	_CompressionHelper($sFilePath, $nOriginalSize, $sExtension, $sAction, 'gifsicle', _
			'-w -j --no-conserve-memory -o {pathFile} -O3 --no-comments --no-extensions --no-names {pathFile}')
EndFunc   ;==>_CompressionGif


Func _CompressionBmp($sFilePath, $nOriginalSize, $sExtension, $sAction)
	_CompressionHelper($sFilePath, $nOriginalSize, $sExtension, $sAction, 'imagew', _
			'-opt bmp:version=auto -noresize -zipcmprlevel 9 -outfmt bmp -compress "rle" {pathFile} {pathFile}')
EndFunc   ;==>_CompressionBmp


; pingo по умолчанию вырезает все метаданные, с -nostrip оставляет eXIf, XMP и текст
Func _CompressionPng($sFilePath, $nOriginalSize, $sExtension, $sAction)
	Local $bSaveExif = _IniString_Read($gc_sMothIni, $sAction, 'SaveExif') = 1
	_CompressionHelper($sFilePath, $nOriginalSize, $sExtension, $sAction, 'pingo', _
			'-lossless' & ($bSaveExif ? ' -nostrip' : '') & ' {pathFile}')
EndFunc   ;==>_CompressionPng


; Сжатие одной утилитой: результат сохраняется, если вышел меньше
Func _CompressionHelper($sFilePath, $nOriginalSize, $sExtension, $sAction, $sUtilName, $sUtilParams)
	Local $sCompressedPath = _CompressionRun($sUtilName, $sUtilParams, $sFilePath, $sExtension)
	If @error Then
		_ShowResult($sFilePath, $nOriginalSize, 0, $STATUS_APP_ERROR)
		Return
	EndIf

	_SaveIfSmaller($sCompressedPath, $sFilePath, $nOriginalSize, $sExtension, $sAction)
EndFunc   ;==>_CompressionHelper


; Сохраняет результат, только если он меньше исходного, иначе файл пропускается
Func _SaveIfSmaller($sCompressedPath, $sFilePath, $nOriginalSize, $sExtension, $sAction)
	; jpegoptim с --strip-all вырезает и APP0. Заголовок до сравнения: размер честный
	If $sExtension = $FORMAT_JFIF Then _JpegAddJfifHeader($sCompressedPath)
	Local $nCompressedSize = FileGetSize($sCompressedPath)
	If $nCompressedSize <= 0 Then
		FileDelete($sCompressedPath)
		_ShowResult($sFilePath, $nOriginalSize, 0, $STATUS_APP_ERROR)
		Return
	EndIf

	If $nCompressedSize >= $nOriginalSize Then
		FileDelete($sCompressedPath)
		_ShowResult($sFilePath, $nOriginalSize, $nCompressedSize, $STATUS_SKIPPED)
		Return
	EndIf

	Local $bSaved = _FileSave($sCompressedPath, $sFilePath, $sExtension, $sAction)
	_ShowResult($sFilePath, $nOriginalSize, $nCompressedSize, $bSaved ? 0 : $STATUS_SAVE_ERROR)
EndFunc   ;==>_SaveIfSmaller


; В сжатии без потерь pingo остаётся только для PNG, WebP пережимает cwebp.
; Из WEBP он переносит только профиль, Exif и XMP возвращает _WebpCopyMeta
Func _CompressionWebP($sFilePath, $nOriginalSize, $sExtension, $sAction)
	Local $bSaveExif = _IniString_Read($gc_sMothIni, $sAction, 'SaveExif') = 1
	Local $sCompressedPath = _CompressionRun('cwebp', '-lossless -mt' & _WebpMetaArgs($bSaveExif Or _IccKeep($sFilePath)) & _
			' {pathFile} -o {pathFile}', $sFilePath, $sExtension)
	If @error Then
		_ShowResult($sFilePath, $nOriginalSize, 0, $STATUS_APP_ERROR)
		Return
	EndIf

	If $bSaveExif Then _WebpCopyMeta($sFilePath, $sCompressedPath)
	_SaveIfSmaller($sCompressedPath, $sFilePath, $nOriginalSize, $sExtension, $sAction)
EndFunc   ;==>_CompressionWebP


; Чанки EXIF и XMP исходного WEBP дописываются в конец результата, их флаги ставятся в VP8X.
; Без профиля cwebp пишет простой WEBP без VP8X: тогда заголовок собирается по VP8L,
; оттуда размер холста и прозрачность. Порядок по спецификации: VP8X, ICCP, картинка, EXIF, XMP
Func _WebpCopyMeta($sSource, $sTarget)
	Local Const $WEBP_FLAG_ALPHA = 0x10, $WEBP_FLAG_EXIF = 0x08, $WEBP_FLAG_XMP = 0x04
	Local $dSource = _WebpReadFile($sSource), $dMeta = Binary(''), $iMetaFlags = 0
	Local $iPos = 12, $iSize, $iChunk, $sType
	While $iPos + 8 <= BinaryLen($dSource)
		$sType = BinaryToString(BinaryMid($dSource, $iPos + 1, 4))
		$iSize = Int(BinaryMid($dSource, $iPos + 5, 4))
		If $iSize < 0 Then Return ; размер больше 2 ГБ - файл битый
		$iChunk = 8 + $iSize + Mod($iSize, 2) ; нечётный чанк дополнен нулём
		If $sType = 'EXIF' Or $sType = 'XMP ' Then
			$dMeta &= BinaryMid($dSource, $iPos + 1, $iChunk)
			$iMetaFlags = BitOR($iMetaFlags, $sType = 'EXIF' ? $WEBP_FLAG_EXIF : $WEBP_FLAG_XMP)
		EndIf
		$iPos += $iChunk
	WEnd
	If Not $iMetaFlags Then Return

	; Результат: заголовок VP8X отдельно, остальные чанки как есть
	Local $dTarget = _WebpReadFile($sTarget), $dHead = Binary(''), $dBody = Binary(''), $iBits
	If BinaryToString(BinaryMid($dTarget, 9, 4)) <> 'WEBP' Then Return
	$iPos = 12
	While $iPos + 8 <= BinaryLen($dTarget)
		$sType = BinaryToString(BinaryMid($dTarget, $iPos + 1, 4))
		$iSize = Int(BinaryMid($dTarget, $iPos + 5, 4))
		If $iSize < 0 Then Return
		$iChunk = 8 + $iSize + Mod($iSize, 2)
		Switch $sType
			Case 'VP8X'
				; Флаги - первый байт данных
				$dHead = BinaryMid(Binary(BitOR(Int(BinaryMid($dTarget, $iPos + 9, 1)), $iMetaFlags)), 1, 1) & _
						BinaryMid($dTarget, $iPos + 10, 9)
			Case 'EXIF', 'XMP ' ; встанут исходные
			Case Else
				; VP8L: байт 0x2F, затем 32 бита: ширина-1 (14), высота-1 (14), прозрачность (1)
				If $sType = 'VP8L' And BinaryLen($dHead) = 0 Then
					$iBits = Int(BinaryMid($dTarget, $iPos + 10, 4))
					$dHead = BinaryMid(Binary(BitOR($iMetaFlags, BitAND(BitShift($iBits, 28), 1) ? $WEBP_FLAG_ALPHA : 0)), 1, 1) & _
							Binary('0x000000') & BinaryMid(Binary(BitAND($iBits, 0x3FFF)), 1, 3) & _
							BinaryMid(Binary(BitAND(BitShift($iBits, 14), 0x3FFF)), 1, 3)
				EndIf
				$dBody &= BinaryMid($dTarget, $iPos + 1, $iChunk)
		EndSwitch
		$iPos += $iChunk
	WEnd
	; VP8 с потерями cwebp -lossless не пишет: без VP8X и VP8L метаданные не переносятся
	If BinaryLen($dHead) <> 10 Then Return

	Local $dRiff = StringToBinary('WEBPVP8X') & Binary(10) & $dHead & $dBody & $dMeta
	Local $hFile = FileOpen($sTarget, BitOR($FO_OVERWRITE, $FO_BINARY))
	If $hFile = -1 Then Return
	FileWrite($hFile, StringToBinary('RIFF') & Binary(BinaryLen($dRiff)) & $dRiff)
	FileClose($hFile)
	_AddLogLine('    метаданные WEBP перенесены')
EndFunc   ;==>_WebpCopyMeta


Func _WebpReadFile($sPathFile)
	Local $hFile = FileOpen($sPathFile, $FO_BINARY)
	If $hFile = -1 Then Return Binary('')
	Local $dData = FileRead($hFile)
	FileClose($hFile)
	Return $dData
EndFunc   ;==>_WebpReadFile


; JXL без потерь. Внутри исходный JPEG: он восстанавливается байт в байт и упаковывается
; заново с большим усилием. Пиксели без потерь пережимаются с тем же усилием.
; JXL с потерями без потерь не пережать: любой перекод меняет пиксели.
; Метаданные cjxl переносит сам. У JPEG внутри они часть восстановления байт в байт,
; поэтому остаются всегда. У пикселей без SaveExif вырезаются, поворот хранит заголовок JXL
Func _CompressionJxl($sFilePath, $nOriginalSize, $sExtension, $sAction)
	Local $sCompressedPath, $sJpg
	Local $bSaveExif = _IniString_Read($gc_sMothIni, $sAction, 'SaveExif') = 1
	Switch _JxlKind($sFilePath)
		Case 'jpeg'
			$sJpg = _ConvertRun('djxl', '{pathFile} {pathFileOut} --quiet', $sFilePath, _GetTempPathFileForCompression('djxl', $FORMAT_JPG))
			If Not @error Then $sCompressedPath = _ConvertRun('cjxl', '{pathFile} {pathFileOut} -j 1 -e 9 --quiet', $sJpg, _GetTempPathFileForCompression('cjxl', $FORMAT_JXL))
			Local $iError = @error
			FileDelete($sJpg)
			If $iError Then
				_ShowResult($sFilePath, $nOriginalSize, 0, $STATUS_APP_ERROR)
				Return
			EndIf
		Case 'lossless'
			$sCompressedPath = _ConvertRun('cjxl', '{pathFile} {pathFileOut} -d 0 -e 9 --quiet' & _
					($bSaveExif ? '' : ' -x strip=exif -x strip=xmp'), $sFilePath, _GetTempPathFileForCompression('cjxl', $FORMAT_JXL))
			If @error Then
				_ShowResult($sFilePath, $nOriginalSize, 0, $STATUS_APP_ERROR)
				Return
			EndIf
		Case Else
			_UpdateGUI()
			_ShowResult($sFilePath, $nOriginalSize, 0, $STATUS_SKIPPED)
			Return
	EndSwitch

	_SaveIfSmaller($sCompressedPath, $sFilePath, $nOriginalSize, $sExtension, $sAction)
EndFunc   ;==>_CompressionJxl


; Что внутри JXL: 'jpeg' - исходный JPEG (djxl восстановит его байт в байт),
; 'lossless' - пиксели без потерь, 'lossy' - с потерями или jxlinfo не ответил.
; Один файл спрашивают по два-три раза за обработку: ответ помнится, пока файл тот же
Func _JxlKind($sPathFile)
	Local Static $sCacheKey = '', $sCacheKind = ''
	Local $sKey = $sPathFile & '|' & FileGetSize($sPathFile) & '|' & FileGetTime($sPathFile, 0, 1)
	If $sKey = $sCacheKey Then Return $sCacheKind

	Local $sOut = _RunReadOutput('jxlinfo', '-v "' & $sPathFile & '"')
	Local $sKind = 'lossless'
	If $sOut = '' Or StringInStr($sOut, ', lossy,') Then $sKind = 'lossy'
	If StringInStr($sOut, 'JPEG bitstream reconstruction data available') Then $sKind = 'jpeg'
	$sCacheKey = $sKey
	$sCacheKind = $sKind
	Return $sKind
EndFunc   ;==>_JxlKind


; PSNR в дБ между двумя картинками (прозрачность учитывается), одинаковые - 100, сбой - 0
Func _PsnrDb($sPathA, $sPathB)
	; magick compare пишет метрику в stderr
	Local $sOut = StringStripWS(_RunReadOutput('magick', 'compare -quiet -metric PSNR "' & $sPathA & '" "' & $sPathB & '" null:', $STDERR_MERGED), 3)
	If StringLeft($sOut, 3) = 'inf' Then Return 100
	Local $aNum = StringRegExp($sOut, '^([0-9.]+)', 1)
	If @error Then Return 0
	Return Number($aNum[0])
EndFunc   ;==>_PsnrDb


; WEBP без потерь (VP8L) или с потерями (VP8). У анимации смотрится первый кадр
Func _WebpIsLossless($sPathFile)
	Local $hFile = FileOpen($sPathFile, $FO_BINARY)
	If $hFile = -1 Then Return False
	Local $sHead = BinaryToString(FileRead($hFile, 65536), $SB_ANSI)
	FileClose($hFile)
	Local $iLossless = StringInStr($sHead, 'VP8L', $STR_CASESENSE)
	Local $iLossy = StringInStr($sHead, 'VP8 ', $STR_CASESENSE)
	Return $iLossless > 0 And ($iLossy = 0 Or $iLossless < $iLossy)
EndFunc   ;==>_WebpIsLossless


; Анимированный WEBP: в заголовке VP8X есть кадры (чанк ANIM)
Func _WebpIsAnimated($sPathFile)
	Local $hFile = FileOpen($sPathFile, $FO_BINARY)
	If $hFile = -1 Then Return False
	Local $sHead = BinaryToString(FileRead($hFile, 4096), $SB_ANSI)
	FileClose($hFile)
	Return StringInStr($sHead, 'ANIM', $STR_CASESENSE) > 0
EndFunc   ;==>_WebpIsAnimated


; Исходник без потерь по пикселям: тогда и результат конвертации должен быть без потерь
Func _IsLosslessSource($sPathFile, $sExtensionFile)
	Switch $sExtensionFile
		Case $FORMAT_PNG, $FORMAT_GIF, $FORMAT_BMP
			Return True
		Case $FORMAT_WEBP
			Return _WebpIsLossless($sPathFile)
		Case $FORMAT_JXL
			Return _JxlKind($sPathFile) = 'lossless'
	EndSwitch
	Return False
EndFunc   ;==>_IsLosslessSource


; Картинка во временный PNG: повёрнутая по Exif, у анимации первый кадр, HEIC в sRGB.
; Путь к PNG или SetError при сбое
Func _DecodeToPng($sPathFile, $sExtensionFile)
	Local $sTool = 'magick', $sCommand = '{pathFile} -quiet {pathFileOut}', $sSourceFile = $sPathFile
	Switch $sExtensionFile
		Case $FORMAT_JXL
			; djxl сам применяет поворот из заголовка JXL
			$sTool = 'djxl'
			$sCommand = '{pathFile} {pathFileOut} --quiet'
		Case $FORMAT_GIF, $FORMAT_WEBP
			$sCommand = '{pathFile}[0] -quiet {pathFileOut}'
		Case $FORMAT_HEIC, $FORMAT_HEIF
			$sCommand = '{pathFile} -quiet -profile {sRGB.icc} -strip {pathFileOut}'
		Case $FORMAT_JPG, $FORMAT_JPE, $FORMAT_JPEG, $FORMAT_JFIF
			; Поворот по Exif прямо по пикселям: декодирование и так уходит от блоков JPEG
			$sCommand = '{pathFile} -quiet -auto-orient {pathFileOut}'
	EndSwitch
	Local $sPng = _ConvertRun($sTool, $sCommand, $sSourceFile, _GetTempPathFileForCompression($sTool, $FORMAT_PNG))
	Return SetError(@error, 0, $sPng)
EndFunc   ;==>_DecodeToPng


; ============================================================
; Сохранение результата
; ============================================================

; Кладёт результат рядом с исходником, имя с постфиксом действия. При конвертации занятое имя
; получает счётчик. Иначе существующий файл переписывается по содержимому: у него остаются
; дата создания, атрибуты и права
Func _FileSave($sWinnerPath, $sPathFile, $sExtensionFile, $sActionName)
	Local $sTarget = _GetPathFilePostfix($sPathFile, $sExtensionFile, _ActionRead($sActionName, 'FilePostfix'))
	; <> без учёта регистра: PNG в png - не конвертация
	If $sExtensionFile <> _GetFileExtension($sPathFile) Then $sTarget = _GetFreePathFile($sTarget)
	If Not FileExists($sTarget) Then Return FileMove($sWinnerPath, $sTarget, $FC_OVERWRITE + $FC_CREATEPATH) = 1

	; Результат читается до того, как открыть цель: открытие на запись её обнуляет,
	; и при сбое чтения исходник был бы потерян
	Local $hFile = FileOpen($sWinnerPath, $FO_BINARY)
	If $hFile = -1 Then Return False
	Local $dData = FileRead($hFile)
	Local $bRead = Not @error And BinaryLen($dData) > 0
	FileClose($hFile)
	If Not $bRead Then Return False

	$hFile = FileOpen($sTarget, BitOR($FO_OVERWRITE, $FO_BINARY))
	If $hFile = -1 Then Return False
	Local $bOk = FileWrite($hFile, $dData) = 1
	FileClose($hFile)
	FileDelete($sWinnerPath)
	Return $bOk
EndFunc   ;==>_FileSave


Func _GetPathFilePostfix($sPathFile, $sExtensionFile, $sActionFilePostfix)
	Return StringTrimRight($sPathFile, StringLen(_GetFileExtension($sPathFile)) + 1) & $sActionFilePostfix & '.' & $sExtensionFile
EndFunc   ;==>_GetPathFilePostfix


; Свободное имя: к занятому дописывается счётчик, xxxx.png -> xxxx (1).png, xxxx (2).png
Func _GetFreePathFile($sPathFile)
	If Not FileExists($sPathFile) Then Return $sPathFile
	Local $sExtension = _GetFileExtension($sPathFile)
	Local $sBase = StringTrimRight($sPathFile, StringLen($sExtension) + 1)
	Local $iCounter = 1
	While FileExists($sBase & ' (' & $iCounter & ').' & $sExtension)
		$iCounter += 1
	WEnd
	Return $sBase & ' (' & $iCounter & ').' & $sExtension
EndFunc   ;==>_GetFreePathFile


; ============================================================
; Сжатие с потерями
; ============================================================

Func _CompressionLossy($sPathFile, $iFileSize, $sExtensionFile, $sActionName)
	If Not _IsFormatSupported($sExtensionFile, $sActionName) Then
		_UpdateGUI()
		_ShowResult($sPathFile, $iFileSize, 0, $STATUS_NOT_SUPPORTED)
		Return
	EndIf

	Local $sWinnerPath = '', $sRunKey, $sPathFileJpg
	Switch $sExtensionFile
		Case $FORMAT_AVIF
			; Качество 80 - около 45 дБ, как у JPEG с --max=92. При 92 файл выходил больше исходного
			$sWinnerPath = _CompressionRun('magick', '{pathFile} -quiet -quality 80 {pathFile}', $sPathFile, $sExtensionFile)

		Case $FORMAT_JXL
			; Дистанция 1 - визуально без потерь (SSIMULACRA2 около 87)
			$sWinnerPath = _ConvertRun('cjxl', '{pathFile} {pathFileOut} -d 1 --quiet', $sPathFile, _GetTempPathFileForCompression('cjxl', $FORMAT_JXL))

		Case $FORMAT_JPG, $FORMAT_JPE, $FORMAT_JPEG, $FORMAT_JFIF
			$sPathFileJpg = _AutorotateJpg($sPathFile, $sExtensionFile, True, False)
			$sRunKey = '{pathFile} --quiet --force --max=92 --all-progressive -w ' & $g_iProcCount & _JpegStripArgs(_IccKeep($sPathFile))
			$sWinnerPath = _CompressionRun('jpegoptim', $sRunKey, $sPathFileJpg, $sExtensionFile)

		Case $FORMAT_PNG
			$sWinnerPath = _CompressionRun('pingo', '-s4 {pathFile}', $sPathFile, $sExtensionFile)

		Case $FORMAT_GIF
			$sWinnerPath = _CompressionRun('gifsicle', '-w -j --no-conserve-memory --lossy=100 -o {pathFile} -O3 --no-comments --no-extensions --no-names {pathFile}', $sPathFile, $sExtensionFile)

		Case $FORMAT_WEBP
			; Для webp сравниваем два варианта сжатия и выбираем лучший.
			; -q 100 кодирует цвет в 4:2:0: на фото это 41-48 дБ, а цветной текст скриншота
			; размывается до ~29 дБ. Тогда он выбывает, и остаётся near-lossless 60 (~52 дБ)
			Local $sMeta = _WebpMetaArgs(_IccKeep($sPathFile))
			Local $sPath1 = _CompressionRun('cwebp', '-q 100 -mt' & $sMeta & ' {pathFile} -o {pathFile}', $sPathFile, $sExtensionFile)
			Local $nSize1 = @error ? 0 : FileGetSize($sPath1)
			If $nSize1 > 0 And _PsnrDb($sPathFile, $sPath1) < 36 Then
				FileDelete($sPath1)
				$nSize1 = 0
			EndIf

			Local $sPath2 = _CompressionRun('cwebp', '-near_lossless 60 -mt' & $sMeta & ' {pathFile} -o {pathFile}', $sPathFile, $sExtensionFile)
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
				_ShowResult($sPathFile, $iFileSize, 0, $STATUS_APP_ERROR)
				Return
			EndIf

	EndSwitch

	; @error последней утилиты ветки
	If @error Then
		_ShowResult($sPathFile, $iFileSize, 0, $STATUS_APP_ERROR)
		Return
	EndIf

	; У JPEG ориентация, которую не удалось применить, возвращается меткой
	_JpegRestoreOrientation($sWinnerPath)
	_SaveIfSmaller($sWinnerPath, $sPathFile, $iFileSize, $sExtensionFile, $sActionName)
EndFunc   ;==>_CompressionLossy


; ============================================================
; Сжатие для веба
; ============================================================

Func _CompressionForWeb($sPathFile, $iFileSize, $sExtensionFile, $sActionName)
	If Not _IsFormatSupported($sExtensionFile, $sActionName) Then
		_UpdateGUI()
		_ShowResult($sPathFile, $iFileSize, 0, $STATUS_NOT_SUPPORTED)
		Return
	EndIf

	Local $sWinnerPath = '', $sRunKey, $sPathFileJpg
	Switch $sExtensionFile
		Case $FORMAT_AVIF
			$sWinnerPath = _CompressionRun('magick', '{pathFile} -quiet -quality 60 {pathFile}', $sPathFile, $sExtensionFile)

		Case $FORMAT_JXL
			$sWinnerPath = _ConvertRun('cjxl', '{pathFile} {pathFileOut} -d 2 --quiet', $sPathFile, _GetTempPathFileForCompression('cjxl', $FORMAT_JXL))

		Case $FORMAT_JPG, $FORMAT_JPE, $FORMAT_JPEG, $FORMAT_JFIF
			$sPathFileJpg = _AutorotateJpg($sPathFile, $sExtensionFile, True, False)
			$sRunKey = '{pathFile} --quiet --force --max=75 --all-progressive -w ' & $g_iProcCount & _JpegStripArgs(_IccKeep($sPathFile))
			$sWinnerPath = _CompressionRun('jpegoptim', $sRunKey, $sPathFileJpg, $sExtensionFile)

		Case $FORMAT_PNG
			$sWinnerPath = _CompressionRun('pingo', '-quality=75 -s4 {pathFile}', $sPathFile, $sExtensionFile)

		Case $FORMAT_WEBP
			$sWinnerPath = _CompressionRun('cwebp', '-q 75 -mt' & _WebpMetaArgs(_IccKeep($sPathFile)) & ' {pathFile} -o {pathFile}', $sPathFile, $sExtensionFile)

		Case $FORMAT_GIF
			$sWinnerPath = _CompressionRun('gifsicle', '-w -j --no-conserve-memory --lossy=75 -o {pathFile} -O3 --no-comments --no-extensions --no-names {pathFile}', $sPathFile, $sExtensionFile)
	EndSwitch

	; @error последней утилиты ветки
	If @error Then
		_ShowResult($sPathFile, $iFileSize, 0, $STATUS_APP_ERROR)
		Return
	EndIf

	; У JPEG ориентация, которую не удалось применить, возвращается меткой
	_JpegRestoreOrientation($sWinnerPath)
	_SaveIfSmaller($sWinnerPath, $sPathFile, $iFileSize, $sExtensionFile, $sActionName)
EndFunc   ;==>_CompressionForWeb


Func _GetTempPathFileForCompression($sUtilsName, $sExtensionFile)
	; PID в имени исключает коллизию, если запущено два экземпляра Moth
	Return $gc_sImgPath & '\' & $sUtilsName & @AutoItPID & '_' & @HOUR & @MIN & @SEC & @MSEC & '.' & $sExtensionFile
EndFunc   ;==>_GetTempPathFileForCompression


; ============================================================
; Запуск утилит
; ============================================================

; Утилита правит копию $sPathFile на месте: {pathFile} в ключах - путь копии.
; Путь копии возвращается и при ошибке (@error 1 - копия, 2 - запуск, 3 - файла нет)
Func _CompressionRun($sUtilsName, $sUtilsKey, $sPathFile, $sExtensionFile)
	Local $sPathCompressFile, $iPid

	$sPathCompressFile = _GetTempPathFileForCompression($sUtilsName, $sExtensionFile)
	$sUtilsKey = StringReplace($sUtilsKey, '{pathFile}', '"' & $sPathCompressFile & '"', 0)
	_AddLogLine('_CompressionRun ' & $sUtilsName & '.exe ' & $sUtilsKey)

	If Not FileCopy($sPathFile, $sPathCompressFile, 9) Then
		_AddLogLine('[!] Ошибка копирования ' & $sUtilsName & '.exe ' & $sPathFile & ' -> ' & $sPathCompressFile)
		Return SetError(1, 0, $sPathCompressFile)
	EndIf

	$iPid = Run('"' & @ScriptDir & '\apps\' & $sUtilsName & '.exe" ' & $sUtilsKey, _GetFileDirPath($sPathFile), @SW_HIDE)
	If $iPid = 0 Then
		_AddLogLine('[!] Ошибка запуска ' & $sUtilsName & '.exe')
		Return SetError(2, 0, $sPathCompressFile)
	EndIf

	_WaitProcess($iPid)

	If Not FileExists($sPathCompressFile) Then
		_AddLogLine('[!] Ошибка ' & $sUtilsName & '.exe, нет итогового файла ' & $sPathCompressFile)
		Return SetError(3, 0, $sPathCompressFile)
	EndIf

	Return $sPathCompressFile
EndFunc   ;==>_CompressionRun


; Утилита читает $sPathFile и пишет $sPathFileOut. {sRGB.icc} - профиль sRGB из Apps
Func _ConvertRun($sUtilsName, $sUtilsKey, $sPathFile, $sPathFileOut)
	$sUtilsKey = StringReplace($sUtilsKey, '{pathFile}', '"' & $sPathFile & '"', 0)
	$sUtilsKey = StringReplace($sUtilsKey, '{pathFileOut}', '"' & $sPathFileOut & '"', 0)
	$sUtilsKey = StringReplace($sUtilsKey, '{sRGB.icc}', '"' & @ScriptDir & '\apps\sRGB.icc"', 0)
	_AddLogLine('_ConvertRun ' & $sUtilsName & '.exe ' & $sUtilsKey)
	Local $iPid = Run('"' & @ScriptDir & '\apps\' & $sUtilsName & '.exe" ' & $sUtilsKey, _GetFileDirPath($sPathFile), @SW_HIDE)
	If $iPid = 0 Then
		_AddLogLine('[!] Ошибка запуска ' & $sUtilsName & '.exe')
		Return SetError(2, 0, $sPathFileOut)
	EndIf

	_WaitProcess($iPid)

	If Not FileExists($sPathFileOut) Then
		_AddLogLine('[!] Ошибка ' & $sUtilsName & '.exe, нет итогового файла ' & $sPathFileOut)
		Return SetError(3, 0, $sPathFileOut)
	EndIf

	Return $sPathFileOut
EndFunc   ;==>_ConvertRun


; Ждёт завершения утилиты, не блокируя окно. Ожидание по дескриптору процесса, а не
; по PID: PID завершившегося процесса Windows может отдать другому, и цикл ждал бы чужой
Func _WaitProcess($iPid)
	Local Const $SYNCHRONIZE = 0x00100000, $WAIT_TIMEOUT = 258
	Local $hProcess = _WinAPI_OpenProcess($SYNCHRONIZE, False, $iPid)
	If Not $hProcess Then Return ; уже завершилась
	$g_iUtilPid = $iPid
	While _WinAPI_WaitForSingleObject($hProcess, 0) = $WAIT_TIMEOUT
		_SetStepProcess(1)
		_TakeTasks()
		_UpdateGUI()
		Sleep(50)
	WEnd
	$g_iUtilPid = 0
	_WinAPI_CloseHandle($hProcess)
EndFunc   ;==>_WaitProcess


Func _AddLogLine($sTmp)
	$g_sLog &= $sTmp & @CR
EndFunc   ;==>_AddLogLine


; Разница размеров со знаком: '-1.2 MB', '' - размер не изменился
Func _GetCompressingSize($nCompressedSize, $nOriginalSize)
	If $nOriginalSize = $nCompressedSize Then Return ''
	Return ($nCompressedSize > $nOriginalSize ? '+' : '-') & _GetFileSizeStr(Abs($nCompressedSize - $nOriginalSize))
EndFunc   ;==>_GetCompressingSize


; Изменение размера в процентах со знаком, '' - не изменился
Func _GetCompressingPercent($nCompressedSize, $nOriginalSize)
	If $nOriginalSize = 0 Or $nOriginalSize = $nCompressedSize Then Return ''
	Local $nPercent = (($nCompressedSize / $nOriginalSize) - 1) * 100
	Local $nDisplay = Round($nPercent, 2)
	; Округлилось до нуля - знаков после запятой столько, чтобы стала видна первая значащая цифра
	If $nDisplay = 0 And $nPercent <> 0 Then $nDisplay = Round($nPercent, -Int(Floor(Log(Abs($nPercent)) / Log(10))))

	Return StringFormat("%s%s%%", $nDisplay > 0 ? "+" : "", $nDisplay)
EndFunc   ;==>_GetCompressingPercent


; Только цифры строки: 'cq512' - '512'
Func _GetNumberFromString($sText)
	Return StringRegExpReplace($sText, '\D', '')
EndFunc   ;==>_GetNumberFromString


; Размер в байтах для таблицы: '456 KB', '1.2 MB'. 0 - ''
Func _GetFileSizeStr($iBytes)
	If Not $iBytes Then Return ''

	Switch $iBytes
		Case 10995116277760 To 109951162777600 ; 10 - 100 TB
			$iBytes = Round($iBytes / 1099511627776, 1) & ' ' & _Lang('Units', 'TB', 'TB')
		Case 1000000000000 To 10995116277759 ; 1000 GB - 10 TB
			$iBytes = Round($iBytes / 1099511627776, 2) & ' ' & _Lang('Units', 'TB', 'TB')
		Case 107374182400 To 999999999999 ; 100 - 999 GB
			$iBytes = Round($iBytes / 1073741824) & ' ' & _Lang('Units', 'GB', 'GB')
		Case 10737418240 To 107374182399 ; 10 - 100 GB
			$iBytes = Round($iBytes / 1073741824, 1) & ' ' & _Lang('Units', 'GB', 'GB')
		Case 1000000000 To 10737418239 ; 1000 MB - 10 GB
			$iBytes = Round($iBytes / 1073741824, 2) & ' ' & _Lang('Units', 'GB', 'GB')
		Case 1000000 To 999999999 ; 1000 KB - 999 MB
			$iBytes = Round($iBytes / 1048576, 2) & ' ' & _Lang('Units', 'MB', 'MB')
		Case 1000 To 999999 ; 1000 B - 999 KB
			$iBytes = Round($iBytes / 1024) & ' ' & _Lang('Units', 'KB', 'KB')
		Case 0 To 999
			$iBytes &= ' ' & _Lang('Units', 'B', 'B')
	EndSwitch
	Return $iBytes
EndFunc   ;==>_GetFileSizeStr


; Контекстное меню у курсора. Выбор придёт событием его пункта
Func _ShowContextMenu($iContextMenu)
	Local $aPos = MouseGetPos()
	DllCall("user32.dll", "bool", "TrackPopupMenuEx", "handle", GUICtrlGetHandle($iContextMenu), "uint", 0, _
			"int", $aPos[0], "int", $aPos[1], "hwnd", $g_hGui, "ptr", 0)
EndFunc   ;==>_ShowContextMenu


; Второй Moth не нужен: файлы идут в очередь первого через Launcher
; Единственный экземпляр с окном-приёмником заданий. Если Moth уже работает, задания
; от Launcher'ов забирает он
Func _CheckSingleInstance()
	If Not _CopyDataQueue_Singleton($gc_sAppName, $gc_sIpcMoth) Then Exit
EndFunc   ;==>_CheckSingleInstance

