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
; Только в строке результата: файл сконвертирован или изменён в размере, это не сжатие
Global Const $STATUS_CONVERTED = 7

; Колонки таблицы
Global Const $COL_STATUS = 0, $COL_FILE = 1, $COL_BEFORE = 2, $COL_AFTER = 3, $COL_SAVED = 4, $COL_TASK = 5
Global Const $gc_iColStatusW = 24, $gc_iColSizeW = 70, $gc_iColSavedW = 125
; Колонка таблицы для поля строки результата (размер|новый|процент|разница|задача|статус), -1 - поле
; рисует NM_CUSTOMDRAW: разница стоит в колонке экономии рядом с процентом
Global Const $gc_aResultCol[6] = [-1, $COL_BEFORE, $COL_AFTER, $COL_SAVED, -1, $COL_TASK]
; Вид строки для отрисовки, он же индекс значка в $g_hStatusImageList. Очередь и работа последние:
; у них ещё нет результата (>= $ROW_QUEUE)
Global Const $ROW_DONE = 0, $ROW_ERROR = 1, $ROW_SKIP = 2, $ROW_QUEUE = 3, $ROW_WORK = 4

; Таблица обновляется не чаще раза в столько мс и получает за раз не больше столько новых строк.
; Очередь растёт порциями по столько строк и считается собранной, если столько мс в неё ничего не приходило
Global Const $gc_iGuiUpdateMs = 250
Global Const $gc_iGuiRowsPerUpdate = 300
Global Const $gc_iFileListChunk = 1000
Global Const $gc_iQueueQuietMs = 800

; Наименьшее окно: таблица ровно на 3 строки
Global Const $gc_iGuiMinW = 520
Global Const $gc_iGuiMinH = 164
Global Const $gc_iGuiW = 555, $gc_iGuiH = 175
; Перерисовка подвала после докинга: WM_SIZE приходит раньше, чем AutoIt подгонит контролы
Global Const $gc_iWmInfoSync = 0x8001 ; WM_APP + 1

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
		$g_iDropDummy, $g_iContextMenu, $g_iProgress, $g_iPicInfo, $g_aListBack[3]
Global $g_aColumnNames[6]
; Подвал: HBITMAP картинки, состояние (0 - пусто, 1 - в работе, 2 - готово), файлов с ошибкой
Global $g_hInfoBitmap = 0, $g_iInfoState = 0, $g_iErrorCount = 0, $g_bInfoSyncPosted = False
; Когда подвал рисовался в последний раз (TimerInit) и ждёт ли отложенное обновление
Global $g_hInfoUpdate = 0, $g_bInfoPending = False
; Значки статуса строки и ширина полосы процентов в колонке экономии
Global $g_hStatusImageList, $g_iPctZoneW = 50
; Строка таблицы, которую сейчас рисует NM_CUSTOMDRAW: фон, вид и поля результата
Global $g_iDrawRowBk, $g_iDrawRowKind, $g_aDrawRow, $g_sDrawAction, $g_sDrawCommand, $g_iDrawRowLeft
; Высота шапки таблицы: строки таблицы всегда ниже неё
Global $g_iHeaderH = 0
; Отсчёт до автозакрытия и идёт ли он
Global $g_hCloseTimer, $g_bCloseTimer = True
; Таблица следует за обрабатываемым файлом, пока окно не тронули мышью
Global $g_bAutoScroll = True
; Строка, к которой таблица прокручена последней, её подсвечивает отрисовка (-1 - автопрокрутка выключена)
Global $g_iScrollRow = -1
; Через сколько секунд после обработки окно закрывается само, 0 - не закрывается
Global $g_iCloseSec = 10
Global $g_bComplete = False
; Строк в таблице и последняя из них, уже получившая результат
Global $g_iRowsShown = 0, $g_iLastUpdated = 0

; Цвета тёмной таблицы. Оттенки серого одинаковы в RGB и BGR (COLORREF)
Global Const $gc_iLvHeaderBk   = 0x2D2D2D ; фон заголовка, светлее строк
Global Const $gc_iLvHeaderText = 0xD4D4D4
Global Const $gc_iLvRowBk      = 0x212121 ; чётные строки и пустая область
Global Const $gc_iLvRowBkAlt   = 0x262626 ; нечётные строки, чуть светлее: чередование без пестроты
Global Const $gc_iLvRowText    = 0xE0E0E0
Global Const $gc_iLvRowSel     = 0x4D4D4D
Global Const $gc_iLvGridLine   = 0x191919 ; сетка и рамка заголовка
Global Const $gc_iLvRowBkAltLight = 0xF4F4F4 ; светлая тема: нечётные строки

; Цвета строк и подвала по теме, RGB. Заполняет _SetPalette: размеры до сжатия и пропуски приглушены,
; уменьшение файла зелёное, рост оранжевый, ошибки красные
Global $g_iClrRowBk, $g_iClrRowBkAlt, $g_iClrRowSel, $g_iClrText, $g_iClrMuted, $g_iClrGood, $g_iClrBad, $g_iClrGrow

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
; Индекс иконки действия в $g_hTaskImageList по имени действия, -1 - иконки нет
Global $g_oTaskIcon[], $g_hTaskImageList
; Ширина названия задачи по имени действия: по самому широкому подгоняется колонка задачи
Global $g_oTaskTextW[], $g_iTaskTextW = 0
; Потоки для jpegoptim
Global $g_iProcCount = _Max(1, Int(EnvGet('NUMBER_OF_PROCESSORS')))


If Not FileExists($gc_sImgPath) Then DirCreate($gc_sImgPath)

_MainGUI()
_DefineEvents()
_SetPositionOnDesktop()
_UpdateCheckOnStart()


Func _MainGUI()

	$g_hGui = GUICreate($gc_sAppName, $gc_iGuiW, $gc_iGuiH, 0, 0, $WS_CAPTION + $WS_THICKFRAME, $WS_EX_ACCEPTFILES)

	$g_iListView = GUICtrlCreateListView("", 6, 2, $gc_iGuiW - 12, 129, _
			BitOR($LVS_NOSORTHEADER, $LVS_SINGLESEL, $LVS_REPORT), _
			BitOR($LVS_EX_INFOTIP, $LVS_EX_FULLROWSELECT, $LVS_EX_DOUBLEBUFFER))
	GUICtrlSetResizing($g_iListView, $GUI_DOCKBORDERS)
	GUICtrlSetState($g_iListView, $GUI_DROPACCEPTED)

	; Подписи колонок нужны и заголовку тёмной темы, который рисуется вручную.
	; Статус и экономию рисует NM_CUSTOMDRAW, иконка файла - картинка подэлемента колонки файла
	Local $aNames = ['', _Lang('Main', 'ColFile', 'File'), _Lang('Main', 'ColBefore', 'Before'), _
			_Lang('Main', 'ColAfter', 'After'), _Lang('Main', 'ColSaved', 'Saved'), _Lang('Main', 'ColTask', 'Task')]
	$g_aColumnNames = $aNames
	_GUICtrlListView_InsertColumn($g_iListView, $COL_STATUS, '', $gc_iColStatusW)
	_GUICtrlListView_InsertColumn($g_iListView, $COL_FILE, $g_aColumnNames[$COL_FILE], 172)
	_GUICtrlListView_InsertColumn($g_iListView, $COL_BEFORE, $g_aColumnNames[$COL_BEFORE], $gc_iColSizeW, $LVCFMT_RIGHT)
	_GUICtrlListView_InsertColumn($g_iListView, $COL_AFTER, $g_aColumnNames[$COL_AFTER], $gc_iColSizeW)
	_GUICtrlListView_InsertColumn($g_iListView, $COL_SAVED, $g_aColumnNames[$COL_SAVED], $gc_iColSavedW, $LVCFMT_RIGHT)
	_GUICtrlListView_InsertColumn($g_iListView, $COL_TASK, $g_aColumnNames[$COL_TASK], 60)

	; Иконки файлов рисует _DrawFileCell из $g_hImageList. У ListView пустой список состояний
	; шириной 1: строка на 1 px выше его картинки, 21 px, как в проводнике
	$g_hImageList = _GUIImageList_Create(16, 16, 5, 3)
	_GUICtrlListView_SetImageList($g_iListView, _GUIImageList_Create(1, 20, 5, 1), 2)
	$g_iPctZoneW = _ListTextWidth('-88.88%')
	$g_iHeaderH = _WinAPI_GetWindowHeight(_GUICtrlListView_GetHeader($g_iListView))
	; Пока задач нет - по подписи в шапке, дальше _FitTaskColumn расширяет под названия
	_GUICtrlListView_SetColumnWidth($g_iListView, $COL_TASK, _ListTextWidth($g_aColumnNames[$COL_TASK]) + 16)

	; Контекстное меню строки: висит на пустышке и открывается из WM_NOTIFY по NM_RCLICK
	$g_iContextMenu = GUICtrlCreateContextMenu(GUICtrlCreateDummy())
	$g_iMenuShowInExplorer = GUICtrlCreateMenuItem(_Lang('Main', 'ShowInExplorer', 'Show in Explorer'), $g_iContextMenu)
	$g_iMenuCopyPath = GUICtrlCreateMenuItem(_Lang('Main', 'CopyAsPath', 'Copy as path'), $g_iContextMenu)

	; Подложка вокруг таблицы в цвет строк: полоски слева, справа и сверху. Под таблицей её нет:
	; одна подложка во всю ширину после докинга оказывалась над таблицей и закрашивала шапку
	$g_aListBack[0] = GUICtrlCreateLabel('', 0, 1, 6, 131)
	GUICtrlSetResizing($g_aListBack[0], $GUI_DOCKLEFT + $GUI_DOCKTOP + $GUI_DOCKBOTTOM + $GUI_DOCKWIDTH)
	$g_aListBack[1] = GUICtrlCreateLabel('', $gc_iGuiW - 6, 1, 6, 131)
	GUICtrlSetResizing($g_aListBack[1], $GUI_DOCKRIGHT + $GUI_DOCKTOP + $GUI_DOCKBOTTOM + $GUI_DOCKWIDTH)
	$g_aListBack[2] = GUICtrlCreateLabel('', 0, 1, $gc_iGuiW, 1)
	GUICtrlSetResizing($g_aListBack[2], $GUI_DOCKLEFT + $GUI_DOCKRIGHT + $GUI_DOCKTOP + $GUI_DOCKHEIGHT)
	For $iBack In $g_aListBack
		GUICtrlSetState($iBack, $GUI_DISABLE)
	Next

	$g_iProgress = GUICtrlCreateProgress(6, 132, $gc_iGuiW - 12, 5)
	GUICtrlSetResizing($g_iProgress, $GUI_DOCKLEFT + $GUI_DOCKBOTTOM + $GUI_DOCKRIGHT + $GUI_DOCKHEIGHT)

	; Подвал рисуется картинкой (_DrawInfo): у частей строки свои цвета и жирность. По высоте - как кнопки
	$g_iPicInfo = GUICtrlCreatePic('', 9, 144, $gc_iGuiW - 116, 24)
	GUICtrlSetResizing($g_iPicInfo, $GUI_DOCKLEFT + $GUI_DOCKBOTTOM + $GUI_DOCKRIGHT + $GUI_DOCKHEIGHT)

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
	_SetPalette()
	_DrawInfo()

	$g_iCloseSec = Int(_IniString_Read($gc_sMothIni, 'Config', 'CloseTimer', '10'))
	If $g_iCloseSec <= 0 Then
		$g_iCloseSec = 0
		$g_bCloseTimer = False
	EndIf
	; Подвал: кнопки 24 px с отступом 7 сверху (от прогресс-бара), снизу и между собой.
	; Правый край OK совпадает с краем списка и прогресс-бара: 6 от края окна, как слева
	$g_iBtnOk = _FluentButton_Create(_OkCountdownText(), '', 0, $gc_iGuiW - 70, 144, 64, 24, $FLUENTBUTTON_TEXT)
	GUICtrlSetResizing($g_iBtnOk, $GUI_DOCKRIGHT + $GUI_DOCKBOTTOM + $GUI_DOCKWIDTH + $GUI_DOCKHEIGHT)
	_SetOkEnabled(False)

	; Шестерёнка слева от OK открывает окно настроек и мигает, если вышла новая версия.
	; Кнопка квадратная по высоте OK. Иконка рисуется в родном размере PNG: Fluent её не сглаживает
	$g_iBtnSettings = _FluentButton_Create('', 'Settings', 16, $gc_iGuiW - 101, 144, 24, 24, $FLUENTBUTTON_ICON)
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
	_FluentMsg_Register($WM_SIZE, "_OnEvent_WM_SIZE")
	_FluentMsg_Register($gc_iWmInfoSync, "_OnEvent_WM_INFOSYNC")
EndFunc   ;==>_DefineEvents


Func _SetTheme()
	If _IsDarkTheme() Then
		; Рамки полей тема не рисует: у списка своя отрисовка, он вне темы окна
		_FluentTheme_SetBorders(False, False)
		_FluentTheme_Exclude($g_iListView)
		_FluentTheme_Apply($g_hGui)
		; Тема красит прогресс цветом акцента и обводит рамкой, в 5 px от полосы оставался 1.
		; Полоса Moth сплошная зелёная без рамки, как системная в светлой теме
		Local $hProgress = GUICtrlGetHandle($g_iProgress)
		GUICtrlSetStyle($g_iProgress, $PBS_SMOOTH)
		_WinAPI_SetWindowPos($hProgress, 0, 0, 0, 0, 0, BitOR($SWP_NOMOVE, $SWP_NOSIZE, $SWP_NOZORDER, $SWP_FRAMECHANGED))
		_SendMessage($hProgress, $PBM_SETBARCOLOR, 0, _WinAPI_SwitchColor(0x06B025))
		_SendMessage($hProgress, $PBM_SETBKCOLOR, 0, _WinAPI_SwitchColor(0x383838))
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
	EndIf
	For $iBack In $g_aListBack
		GUICtrlSetBkColor($iBack, _IsDarkTheme() ? $gc_iLvRowBk : 0xFFFFFF)
	Next
EndFunc   ;==>_SetTheme


; Цвета таблицы и подвала по теме и значки статуса в этих цветах
Func _SetPalette()
	If _IsDarkTheme() Then
		$g_iClrRowBk = $gc_iLvRowBk
		$g_iClrRowBkAlt = $gc_iLvRowBkAlt
		$g_iClrRowSel = $gc_iLvRowSel
		$g_iClrText = $gc_iLvRowText
		$g_iClrMuted = 0x8F8F8F
		$g_iClrGood = 0x6CCB5F
		$g_iClrBad = 0xFF8A8A
		$g_iClrGrow = 0xF59E0B
	Else
		$g_iClrRowBk = 0xFFFFFF
		$g_iClrRowBkAlt = $gc_iLvRowBkAltLight
		$g_iClrRowSel = 0xCCE8FF
		$g_iClrText = 0x1A1A1A
		$g_iClrMuted = 0x707070
		$g_iClrGood = 0x0F7B0F
		$g_iClrBad = 0xC42B1C
		$g_iClrGrow = 0xD97706
	EndIf

	; Порядок значков - $ROW_*. PNG из Lucide перекрашивает Fluent, иконка 14 по центру клетки 16
	Local $aIcons[5][2] = [['StatusDone', $g_iClrGood], ['StatusError', $g_iClrBad], ['StatusSkip', $g_iClrMuted], _
			['StatusQueue', $g_iClrMuted], ['StatusWork', $g_iClrMuted]]
	Local $hGfx, $hCanvas, $hIcon
	; Иконки задач добавляет _GetTaskIconIndex, когда задача впервые попадает в таблицу
	$g_hTaskImageList = _GUIImageList_Create(16, 16, 5, 4)
	$g_hStatusImageList = _GUIImageList_Create(16, 16, 5, 1)
	For $i = 0 To UBound($aIcons) - 1
		$hCanvas = _FluentCanvas(16, 16, 0, $hGfx)
		_FluentDrawIcon($hGfx, $aIcons[$i][0], 14, $aIcons[$i][1], 1, 1)
		$hIcon = _GDIPlus_HICONCreateFromBitmap($hCanvas)
		_GDIPlus_GraphicsDispose($hGfx)
		_GDIPlus_BitmapDispose($hCanvas)
		_GUIImageList_ReplaceIcon($g_hStatusImageList, -1, $hIcon)
		_WinAPI_DestroyIcon($hIcon)
	Next
EndFunc   ;==>_SetPalette


; Ширина текста шрифтом таблицы
Func _ListTextWidth($sText)
	Local $hLV = GUICtrlGetHandle($g_iListView)
	Local $hFont = _SendMessage($hLV, $WM_GETFONT)
	If Not $hFont Then $hFont = _WinAPI_GetStockObject($DEFAULT_GUI_FONT)
	Local $hDC = _WinAPI_GetDC($hLV)
	Local $hOld = _WinAPI_SelectObject($hDC, $hFont)
	Local $tSize = _WinAPI_GetTextExtentPoint32($hDC, $sText)
	_WinAPI_SelectObject($hDC, $hOld)
	_WinAPI_ReleaseDC($hLV, $hDC)
	Return DllStructGetData($tSize, "X")
EndFunc   ;==>_ListTextWidth


; Запоминает ширину названия задачи новой строки. True - название шире всех прежних,
; колонку задачи пора расширить (_FitTaskColumn)
Func _NoteTaskWidth($sActionName)
	If MapExists($g_oTaskTextW, $sActionName) Then Return False
	$g_oTaskTextW[$sActionName] = _ListTextWidth(_GetActionStr($sActionName))
	If $g_oTaskTextW[$sActionName] <= $g_iTaskTextW Then Return False
	$g_iTaskTextW = $g_oTaskTextW[$sActionName]
	Return True
EndFunc   ;==>_NoteTaskWidth


; Колонка задачи по самому широкому названию: отступ, иконка, зазор, текст и запас. Не уже подписи
Func _FitTaskColumn()
	Local $iWidth = _Max(4 + 21 + $g_iTaskTextW + 8, _ListTextWidth($g_aColumnNames[$COL_TASK]) + 16)
	_GUICtrlListView_SetColumnWidth($g_iListView, $COL_TASK, $iWidth)
EndFunc   ;==>_FitTaskColumn


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
	If $g_hInfoBitmap Then _WinAPI_DeleteObject($g_hInfoBitmap)
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
			Return _ListViewCustomDraw($ilParam)

		Case $LVN_GETINFOTIPW
			; Колонка файла не первая, и система не показывает подсказку к обрезанному имени: даём полный путь
			Local $tTip = DllStructCreate($tagNMLVGETINFOTIP, $ilParam)
			$iIndex = DllStructGetData($tTip, "Item")
			If $iIndex >= 0 And $iIndex < $g_aFileList[0][0] And DllStructGetData($tTip, "TextMax") > 0 Then
				Local $sTip = StringLeft($g_aFileList[$iIndex + 1][1], DllStructGetData($tTip, "TextMax") - 1)
				DllStructSetData(DllStructCreate("wchar[" & StringLen($sTip) + 1 & "]", DllStructGetData($tTip, "Text")), 1, $sTip)
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


; Тело таблицы в обеих темах: чередование строк, выделение, цвета колонок. Статус и экономию
; система не рисует, их рисует _DrawCell
Func _ListViewCustomDraw($ilParam)
	Local $tLVCD = DllStructCreate($tagNMLVCUSTOMDRAW, $ilParam)
	Local $iStage = DllStructGetData($tLVCD, "dwDrawStage")
	If $iStage = $CDDS_PREPAINT Then Return $CDRF_NOTIFYITEMDRAW

	; Без флагов выделения система рисует строку как обычную, с нашим фоном, а иконку
	; и текст ставит на родные места. Подэлементы получают флаги заново, сброс в каждом
	Local $iRow = DllStructGetData($tLVCD, "dwItemSpec")
	Local $iState = DllStructGetData($tLVCD, "uItemState")
	DllStructSetData($tLVCD, "uItemState", BitAND($iState, BitNOT($CDIS_SELECTED), BitNOT($CDIS_FOCUS)))

	; Всплывающая подпись обрезанной строки рисуется тем же NM_CUSTOMDRAW, но в прямоугольнике
	; от нуля: своя отрисовка клала иконку в шапку. Настоящие строки всегда ниже шапки
	If $tLVCD.Top < $g_iHeaderH Then Return $CDRF_DODEFAULT

	Switch $iStage
		Case $CDDS_ITEMPREPAINT
			; У подэлемента 0 система отдаёт прямоугольник без места под картинку состояния,
			; левый край строки - только здесь
			$g_iDrawRowLeft = $tLVCD.Left
			If BitAND($iState, $CDIS_SELECTED) Or $iRow = $g_iScrollRow Then
				$g_iDrawRowBk = _WinAPI_SwitchColor($g_iClrRowSel)
			Else
				$g_iDrawRowBk = _WinAPI_SwitchColor(BitAND($iRow, 1) ? $g_iClrRowBkAlt : $g_iClrRowBk)
			EndIf
			_RowKind($iRow)
			Return $CDRF_NOTIFYSUBITEMDRAW

		Case BitOR($CDDS_ITEMPREPAINT, $CDDS_SUBITEM)
			Local $iCol = DllStructGetData($tLVCD, "iSubItem")
			DllStructSetData($tLVCD, "clrTextBk", $g_iDrawRowBk)
			; «Было» и «Стало» серые, если файл не обработан или не изменился (очередь, ошибка, пропуск)
			DllStructSetData($tLVCD, "clrText", _WinAPI_SwitchColor((($iCol = $COL_BEFORE Or $iCol = $COL_AFTER) And _
					$g_iDrawRowKind <> $ROW_DONE) ? $g_iClrMuted : $g_iClrText))
			; «Стало» у файла без результата пустая: поверх неё текст статуса из колонки экономии
			If $iCol = $COL_STATUS Or $iCol = $COL_FILE Or $iCol = $COL_SAVED Or $iCol = $COL_TASK Or _
					($iCol = $COL_AFTER And $g_iDrawRowKind >= $ROW_QUEUE) Then
				_DrawCell($tLVCD, $iCol)
				Return $CDRF_SKIPDEFAULT
			EndIf
			Return $CDRF_NEWFONT
	EndSwitch
	Return $CDRF_DODEFAULT
EndFunc   ;==>_ListViewCustomDraw


; Вид строки и поля её результата для отрисовки. Результат виден строкам до $g_iLastUpdated
; включительно: дальше таблица ещё не обновлялась, и файл пока в очереди или в работе
Func _RowKind($iRow)
	Local $iFile = $iRow + 1
	$g_sDrawAction = $g_aFileList[$iFile][2]
	$g_sDrawCommand = $g_aFileList[$iFile][3]
	If $iFile <= $g_iLastUpdated Then
		; Поля как у _ShowResult: размер|новый|процент|разница|задача|статус
		$g_aDrawRow = StringSplit($g_aFileList[$iFile][4], '|')
		If $g_aDrawRow[0] >= 6 Then
			Switch Int($g_aDrawRow[6])
				Case 0, $STATUS_CONVERTED
					$g_iDrawRowKind = $ROW_DONE
				Case $STATUS_APP_ERROR, $STATUS_SAVE_ERROR
					$g_iDrawRowKind = $ROW_ERROR
				Case Else
					$g_iDrawRowKind = $ROW_SKIP
			EndSwitch
			Return
		EndIf
	EndIf
	$g_iDrawRowKind = (Not $g_bComplete And $iFile = $g_iFileIndex) ? $ROW_WORK : $ROW_QUEUE
EndFunc   ;==>_RowKind


; Ячейка, которую система не рисует: статус, файл, экономия, задача и пустая «Стало» под текстом статуса
Func _DrawCell($tLVCD, $iCol)
	Local $hDC = DllStructGetData($tLVCD, "hdc")
	Local $tRect = _WinAPI_CreateRect($tLVCD.Left, $tLVCD.Top, $tLVCD.Right, $tLVCD.Bottom)
	; У первой колонки система отдаёт свой прямоугольник: край строки и ширина колонки - свои
	If $iCol = $COL_STATUS Then
		$tRect.Left = $g_iDrawRowLeft
		$tRect.Right = $tRect.Left + _GUICtrlListView_GetColumnWidth($g_iListView, $COL_STATUS)
	EndIf

	; Фон строки хранится в COLORREF для clrTextBk, а кисть UDF принимает RGB
	_WinAPI_SetDCBrushColor($hDC, _WinAPI_SwitchColor($g_iDrawRowBk))
	_WinAPI_FillRect($hDC, $tRect, _WinAPI_GetStockObject($DC_BRUSH))

	Switch $iCol
		Case $COL_STATUS
			; Значок у левого края: справа от него остаётся зазор до иконки файла
			_GUIImageList_Draw($g_hStatusImageList, $g_iDrawRowKind, $hDC, $tRect.Left + 4, _
					$tRect.Top + Int(($tRect.Bottom - $tRect.Top - 16) / 2), $ILD_TRANSPARENT)
		Case $COL_SAVED
			_DrawSavedCell($hDC, $tRect)
		Case $COL_FILE
			_DrawFileCell($hDC, $tRect, DllStructGetData($tLVCD, "dwItemSpec"))
		Case $COL_TASK
			_DrawTaskCell($hDC, $tRect)
	EndSwitch
EndFunc   ;==>_DrawCell


; Задача: иконка действия и короткое название, как иконка и имя в колонке файла
Func _DrawTaskCell($hDC, $tRect)
	_DrawIconText($hDC, $tRect, $g_hTaskImageList, _GetTaskIconIndex($g_sDrawAction), _GetActionStr($g_sDrawAction))
EndFunc   ;==>_DrawTaskCell


Func _DrawFileCell($hDC, $tRect, $iRow)
	Local $sPath = $g_aFileList[$iRow + 1][1]
	_DrawIconText($hDC, $tRect, $g_hImageList, _GetIconIndexByPathFile($sPath), _GetFileName($sPath))
EndFunc   ;==>_DrawFileCell


; Иконка 16 и текст после неё с зазором 5 px. Без иконки текст на её месте
Func _DrawIconText($hDC, $tRect, $hImageList, $iIcon, $sText)
	Local $iX = $tRect.Left + 4
	If $iIcon >= 0 Then
		_GUIImageList_Draw($hImageList, $iIcon, $hDC, $iX, $tRect.Top + Int(($tRect.Bottom - $tRect.Top - 16) / 2), $ILD_TRANSPARENT)
		$iX += 20
	EndIf
	Local $tText = _WinAPI_CreateRect($iX, $tRect.Top, $tRect.Right - 4, $tRect.Bottom)
	_WinAPI_SetBkMode($hDC, $TRANSPARENT)
	_WinAPI_SetTextColor($hDC, _WinAPI_SwitchColor($g_iClrText))
	_WinAPI_DrawText($hDC, $sText, $tText, BitOR($DT_SINGLELINE, $DT_VCENTER, $DT_NOPREFIX, $DT_END_ELLIPSIS))
EndFunc   ;==>_DrawIconText


; Экономия. У обработанного файла разница серым и процент цветом: зелёным, если файл уменьшился, оранжевым - вырос.
; Иначе текст статуса его цветом, прижат вправо. У файла без результата он занимает и пустую «Стало»
Func _DrawSavedCell($hDC, $tRect)
	; Справа запас больше обычного: экономия не липнет к иконке задачи
	Local Const $iPad = 6, $iPadRight = 11
	Local $iFlags = BitOR($DT_SINGLELINE, $DT_VCENTER, $DT_RIGHT, $DT_NOPREFIX, $DT_END_ELLIPSIS)
	Local $tText = _WinAPI_CreateRect($tRect.Left + $iPad, $tRect.Top, $tRect.Right - $iPadRight, $tRect.Bottom)
	_WinAPI_SetBkMode($hDC, $TRANSPARENT)

	If $g_iDrawRowKind = $ROW_DONE Then
		; Цвет по знаку: файл уменьшился - зелёный, вырос (конвертация, увеличение) - оранжевый
		_WinAPI_SetTextColor($hDC, _WinAPI_SwitchColor(StringLeft($g_aDrawRow[3], 1) = '+' ? $g_iClrGrow : $g_iClrGood))
		_WinAPI_DrawText($hDC, $g_aDrawRow[3], $tText, $iFlags)
		; Процент в полосе постоянной ширины: проценты строк стоят ровно друг под другом.
		; Длинный процент конвертации (+1550.9%) шире полосы: разница отступает от него, а не налезает
		Local $tSize = _WinAPI_GetTextExtentPoint32($hDC, $g_aDrawRow[3])
		$tText.Right -= _Max($g_iPctZoneW, DllStructGetData($tSize, "X")) + $iPad
		_WinAPI_SetTextColor($hDC, _WinAPI_SwitchColor($g_iClrMuted))
		_WinAPI_DrawText($hDC, $g_aDrawRow[4], $tText, $iFlags)
		Return
	EndIf

	; Поля результата есть только у ошибки и пропуска
	Local $sText, $iColor = $g_iClrMuted
	Switch $g_iDrawRowKind
		Case $ROW_ERROR
			$sText = $g_aDrawRow[3]
			$iColor = $g_iClrBad
		Case $ROW_SKIP
			$sText = $g_aDrawRow[3]
		Case $ROW_WORK
			$sText = _Lang('Status', 'Working', 'processing')
		Case Else
			$sText = _Lang('Status', 'Queued', 'queued')
	EndSwitch
	; Текст статуса длиннее цифр: ему обычный отступ справа, запас нужен только цифрам
	$tText.Right = $tRect.Right - $iPad
	If $g_iDrawRowKind >= $ROW_QUEUE Then $tText.Left -= _GUICtrlListView_GetColumnWidth($g_iListView, $COL_AFTER)
	_WinAPI_SetTextColor($hDC, _WinAPI_SwitchColor($iColor))
	_WinAPI_DrawText($hDC, $sText, $tText, $iFlags)
EndFunc   ;==>_DrawSavedCell


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
					If $iCol = $COL_BEFORE Or $iCol = $COL_SAVED Then
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
	_AutoScrollToCurrent()
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
				; Без паузы обновления: результат предыдущего файла и статус «в работе» нового появляются
				; вместе, иначе строка перед ним какое-то время выглядела пропущенной
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
				; Что умеет формат, решает только таблица $SUPPORT_FORMATS_*. Анимированный WEBP
				; сверх неё: cwebp не читает анимацию, сжатие давало случайный пропуск, а палитра -
				; один первый кадр
				Local $sDispatch = $sActionCommand
				If Not _IsFormatSupported($sExtensionFile, $sActionName) Then
					$sDispatch = 'unsupported'
				ElseIf $sExtensionFile = $FORMAT_WEBP And StringRegExp($sActionCommand, '^(loss|lossy|web|cq\d+)$') Then
					If _WebpIsAnimated($sPathFile) Then $sDispatch = 'unsupported'
				EndIf
				Switch $sDispatch
					Case 'unsupported'
						_UpdateGUI()
						_ShowResult($sPathFile, $iFileSize, 0, _UnsupportedStatus($sPathFile, $sExtensionFile, $sActionCommand))
					Case 'loss' ; Сжатие без потерь
						Switch $sExtensionFile
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
	_AutoScrollToCurrent() ; прокрутка к последнему файлу

	_SetProcess(100)

	_StartTimerState()

	_SetLabel(True)
EndFunc   ;==>_CompressFile


; Статус файла, который действие не берёт. Пропуск - папка, конвертация в тот же формат
; (JPEG в JPG, HEIF в HEIC) и неизвестная команда, остальное - формат не поддерживается
Func _UnsupportedStatus($sPathFile, $sExtensionFile, $sActionCommand)
	If _IsDir($sPathFile) Then Return $STATUS_SKIPPED_FOLDER
	If Not IsArray(_GetCommandSupportedFormats($sActionCommand)) Then Return $STATUS_SKIPPED
	If StringLeft($sActionCommand, 2) = 'to' And _FormatGroup($sExtensionFile) = _FormatGroup(StringTrimLeft($sActionCommand, 2)) Then _
			Return $STATUS_SKIPPED
	Return $STATUS_NOT_SUPPORTED
EndFunc   ;==>_UnsupportedStatus


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
	$g_iInfoState = $bComplete ? 2 : 1
	; В работе подвал и заголовок обновляются не чаще таблицы: картинка подвала на каждый файл
	; заметно тормозила очередь из тысяч пропусков. Пропущенное обновление дорисует Adlib
	If Not $bComplete And TimerDiff($g_hInfoUpdate) < $gc_iGuiUpdateMs Then
		If Not $g_bInfoPending Then
			$g_bInfoPending = True
			AdlibRegister('_SetLabelDeferred', $gc_iGuiUpdateMs)
		EndIf
		Return
	EndIf
	If $g_bInfoPending Then
		$g_bInfoPending = False
		AdlibUnRegister('_SetLabelDeferred')
	EndIf
	$g_hInfoUpdate = TimerInit()
	_DrawInfo()

	Local $iPercent = $bComplete ? 100 : Round(($g_iFileIndex - 1) / $g_aFileList[0][0] * 100)
	WinSetTitle($g_hGui, '', $gc_sAppName & '  [' & $g_iFileIndex & '/' & $g_aFileList[0][0] & ' ' & $iPercent & '%]' & _
			_UpdateTitleSuffix())
EndFunc   ;==>_SetLabel


Func _SetLabelDeferred()
	; Завершение уже обновило подвал само и сняло этот вызов
	If $g_bInfoPending Then _SetLabel(False)
EndFunc   ;==>_SetLabelDeferred


; Подвал: значок и счётчик файлов, итог сжатия, число ошибок. У частей свои цвета
; и жирность, поэтому строка рисуется картинкой
Func _DrawInfo()
	Local $aSize = _FluentCtrlSize($g_iPicInfo)
	If $aSize[0] < 1 Or $aSize[1] < 1 Then Return
	Local $nH = $aSize[1], $hGfx
	Local $hCanvas = _FluentCanvas($aSize[0], $nH, _FluentArgb($g_iFluentBg), $hGfx)

	If $g_iInfoState Then
		Local $bDone = $g_iInfoState = 2
		Local $hFont = _FluentFont(), $hSemi = _FluentFont(0, True)
		_FluentDrawIcon($hGfx, $bDone ? 'StatusDone' : 'StatusWork', 14, $bDone ? $g_iClrGood : $g_iClrMuted, 1, Int(($nH - 14) / 2))
		Local $nX = 19
		$nX = _InfoText($hGfx, $bDone ? _Lang('Main', 'Complete', 'Done') : _Lang('Main', 'Progress', 'In progress'), _
				$nX, $nH, $hFont, $g_iClrText)
		$nX = _InfoText($hGfx, $g_iFileIndex & ' / ' & $g_aFileList[0][0], $nX, $nH, $hSemi, $g_iClrText)

		Local $sSavedSize = _GetFileSizeStr($g_iAllFileSize - $g_iAllWinnerSize)
		If $sSavedSize <> '' Then
			$nX = _InfoDot($hGfx, $nX, $nH)
			$nX = _InfoText($hGfx, _Lang('Main', 'Saved', 'Saved'), $nX, $nH, $hFont, $g_iClrText)
			$nX = _InfoText($hGfx, '-' & $sSavedSize, $nX, $nH, $hSemi, $g_iClrGood)
			$nX = _InfoText($hGfx, '(' & _GetCompressingPercent($g_iAllWinnerSize, $g_iAllFileSize) & ')', _
					$nX, $nH, $hFont, $g_iClrMuted)
		EndIf
		If $g_iErrorCount Then
			$nX = _InfoDot($hGfx, $nX, $nH)
			_InfoText($hGfx, _ErrorCountStr($g_iErrorCount), $nX, $nH, $hFont, $g_iClrBad)
		EndIf
	EndIf

	_FluentCanvasApply($g_iPicInfo, $g_hInfoBitmap, $hCanvas, $hGfx)
EndFunc   ;==>_DrawInfo


; Часть строки подвала с $nX. Возвращает, откуда рисовать следующую
Func _InfoText($hGfx, $sText, $nX, $nH, $hFont, $iRgb)
	Local $nW = _FluentTextW($sText, $hFont)
	; Запас по ширине: строка без переноса обрезается по прямоугольнику
	_FluentText($hGfx, $sText, $nX, 0, $nW + 8, $nH, $hFont, _FluentArgb($iRgb))
	Return $nX + $nW + 1
EndFunc   ;==>_InfoText


; Точка-разделитель между частями подвала
Func _InfoDot($hGfx, $nX, $nH)
	_FluentFill($hGfx, $nX + 4, Int($nH / 2) - 1, 3, 3, 1.5, _FluentArgb($g_iClrMuted, 180))
	Return $nX + 12
EndFunc   ;==>_InfoDot


; «3 ошибки»: форма слова по правилу русского языка, сами формы в Lang
Func _ErrorCountStr($iCount)
	Local $sForm = 'Many'
	If Mod($iCount, 10) = 1 And Mod($iCount, 100) <> 11 Then
		$sForm = 'One'
	ElseIf Mod($iCount, 10) >= 2 And Mod($iCount, 10) <= 4 And (Mod($iCount, 100) < 12 Or Mod($iCount, 100) > 14) Then
		$sForm = 'Few'
	EndIf
	Return StringReplace(_Lang('Main', 'Errors' & $sForm, '%1 errors'), '%1', $iCount)
EndFunc   ;==>_ErrorCountStr


; Подвал перерисовывается под новую ширину, когда докинг уже подогнал картинку: WM_SIZE
; приходит раньше. Отложенное сообщение выбирается после докинга, но до WM_PAINT
Func _OnEvent_WM_SIZE($hWnd, $iMsg, $wParam, $lParam)
	#forceref $iMsg, $wParam, $lParam
	If $hWnd <> $g_hGui Or $g_bInfoSyncPosted Then Return $GUI_RUNDEFMSG
	$g_bInfoSyncPosted = True
	_WinAPI_PostMessage($g_hGui, $gc_iWmInfoSync, 0, 0)
	Return $GUI_RUNDEFMSG
EndFunc   ;==>_OnEvent_WM_SIZE


Func _OnEvent_WM_INFOSYNC($hWnd, $iMsg, $wParam, $lParam)
	#forceref $iMsg, $wParam, $lParam
	If $hWnd <> $g_hGui Then Return $GUI_RUNDEFMSG
	$g_bInfoSyncPosted = False
	_DrawInfo()
	Return 0
EndFunc   ;==>_OnEvent_WM_INFOSYNC


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
	Local $aResult, $iFirstUpdated = $g_iLastUpdated + 1
	For $i = $iFirstUpdated To $g_iRowsShown
		If Not StringLen($g_aFileList[$i][4]) Then ExitLoop
		$aResult = StringSplit($g_aFileList[$i][4], '|')
		For $iField = 1 To 5
			If $gc_aResultCol[$iField] >= 0 Then _UpdateListViewItemIfChanged($i - 1, $gc_aResultCol[$iField], $aResult[$iField])
		Next
		$g_iLastUpdated = $i
	Next
	; Статус и экономию рисует NM_CUSTOMDRAW по очереди, а не по тексту строки: перерисовать явно
	If $g_iLastUpdated >= $iFirstUpdated Then _GUICtrlListView_RedrawItems($g_iListView, $iFirstUpdated - 1, $g_iLastUpdated - 1)

	; Новые строки порциями: десять тысяч строк разом надолго заняли бы окно
	Local $iLast = _Min($g_aFileList[0][0], $g_iRowsShown + $gc_iGuiRowsPerUpdate)
	If $iLast > $g_iRowsShown Then
		Local $sPathFile, $iRow
		Local $bTaskWider = False
		_GUICtrlListView_BeginUpdate($g_iListView)
		For $i = $g_iRowsShown + 1 To $iLast
			$sPathFile = $g_aFileList[$i][1]
			$iRow = $i - 1
			If _NoteTaskWidth($g_aFileList[$i][2]) Then $bTaskWider = True
			_GUICtrlListView_AddItem($g_iListView, '')
			_GUICtrlListView_AddSubItem($g_iListView, $iRow, _GetFileName($sPathFile), $COL_FILE)
			If StringLen($g_aFileList[$i][4]) Then
				$aResult = StringSplit($g_aFileList[$i][4], '|')
				For $iField = 1 To 5
					If $gc_aResultCol[$iField] >= 0 And $aResult[$iField] <> '' Then _
							_GUICtrlListView_AddSubItem($g_iListView, $iRow, $aResult[$iField], $gc_aResultCol[$iField])
				Next
				If $i = $g_iLastUpdated + 1 Then $g_iLastUpdated = $i
			Else
				_GUICtrlListView_AddSubItem($g_iListView, $iRow, _GetActionStr($g_aFileList[$i][2]), $COL_TASK)
			EndIf
		Next
		$g_iRowsShown = $iLast
		_GUICtrlListView_EndUpdate($g_iListView)
		If $bTaskWider Then _FitTaskColumn()
		_ListViewResize()
	EndIf

	; Файл в работе сменился: его строка из очереди становится «в работе». Прежняя строка
	; перерисовалась выше вместе с результатом
	Local Static $iWorkRow = -1
	If $g_iFileIndex - 1 <> $iWorkRow And $g_iFileIndex <= $g_iRowsShown Then
		$iWorkRow = $g_iFileIndex - 1
		_GUICtrlListView_RedrawItems($g_iListView, $iWorkRow, $iWorkRow)
	EndIf

	; Строка нового файла могла появиться только сейчас
	_AutoScrollToCurrent()
EndFunc   ;==>_UpdateGUI


Func _UpdateListViewItemIfChanged($iIndex, $iSubItem, $sNewText)
	If _GUICtrlListView_GetItemText($g_iListView, $iIndex, $iSubItem) <> $sNewText Then
		_GUICtrlListView_SetItemText($g_iListView, $iIndex, $sNewText, $iSubItem)
	EndIf
EndFunc   ;==>_UpdateListViewItemIfChanged


; Прокручивает таблицу к последнему обработанному файлу и подсвечивает его строку. Подсветку
; рисует NM_CUSTOMDRAW по $g_iScrollRow, а не системное выделение: оно не видно без фокуса
; и мешало бы выделению пользователя. Клик по окну выключает прокрутку вместе с подсветкой
; ($g_bAutoScroll = False), новые файлы в очереди включают снова (_AddToFileListData)
Func _AutoScrollToCurrent()
	Local $iRow = -1
	If $g_bAutoScroll Then $iRow = $g_bComplete ? $g_iFileIndex - 1 : $g_iFileIndex - 2
	Local $iLastRow = _GUICtrlListView_GetItemCount($g_iListView) - 1
	If $iRow = $g_iScrollRow Or $iRow > $iLastRow Then Return
	Local $iOldRow = $g_iScrollRow
	$g_iScrollRow = $iRow
	If $iOldRow >= 0 Then _GUICtrlListView_RedrawItems($g_iListView, $iOldRow, $iOldRow)
	If $iRow < 0 Then Return
	_GUICtrlListView_RedrawItems($g_iListView, $iRow, $iRow)

	; Строка по центру видимой части (при 5 строках под ней файл в работе
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
			; Файл не изменился: в «Стало» прежний размер
			Case $STATUS_APP_ERROR
				$sCompressingSize = ''
				$sCompressingPercent = _Lang('Status', 'Error', 'error')
				$iWinnerSize = $iFileSize
			Case $STATUS_NOT_SUPPORTED
				$sCompressingSize = ''
				$sCompressingPercent = _Lang('Status', 'NotSupported', 'not supported')
				$iWinnerSize = $iFileSize
			Case $STATUS_SAVE_ERROR
				$sCompressingSize = ''
				$sCompressingPercent = _Lang('Status', 'SaveError', 'save error')
				$iWinnerSize = $iFileSize
			Case $STATUS_PALETTE_LARGER
				$sCompressingSize = ''
				$sCompressingPercent = _Lang('Status', 'PaletteLarger', 'few colors')
				$iWinnerSize = $iFileSize
			Case $STATUS_SKIPPED_FOLDER
				$sCompressingSize = ''
				$sCompressingPercent = _Lang('Status', 'Skipped', 'skipped')
				$iWinnerSize = $iFileSize
			Case $STATUS_SKIPPED
				$sCompressingSize = ''
				$sCompressingPercent = _Lang('Status', 'Skipped', 'skipped')
				$iWinnerSize = $iFileSize
			Case Else
				$sCompressingSize = _GetCompressingSize($iWinnerSize, $iFileSize)
				$sCompressingPercent = _GetCompressingPercent($iWinnerSize, $iFileSize)

				; Итог «сэкономлено» - только у сжатия: у конвертации и ресайза размер меняется по другой причине
				If _IsCompressionCommand($sActionCommand) Then
					$g_iAllWinnerSize += $iWinnerSize
					$g_iAllFileSize += $iFileSize
				Else
					$iStatusError = $STATUS_CONVERTED
				EndIf
		EndSwitch
		If $iStatusError = $STATUS_APP_ERROR Or $iStatusError = $STATUS_SAVE_ERROR Then $g_iErrorCount += 1

		_AddLogLine($sCompressingPercent & ', ' & $sCompressingSize)

		; Строка таблицы: размер|новый|процент|разница|задача|статус
		$g_aFileList[$g_iFileIndex][4] = _GetFileSizeStr($iFileSize) & '|' & _GetFileSizeStr($iWinnerSize) & '|' & _
				$sCompressingPercent & '|' & $sCompressingSize & '|' & _GetActionStr($g_aFileList[$g_iFileIndex][2]) & _
				'|' & $iStatusError
	EndIf
EndFunc   ;==>_ShowResult


; Короткое название задачи для тега: lossless, lossy, web, JPG, resize. Любое сжатие без потерь -
; lossless, с метаданными оно отличается только иконкой. Конвертация - формат без стрелки, ресайз -
; resize без размера. У остальных постфикс (_cq256) без подчёркивания
Func _GetActionStr($sActionName)
	If Not MapExists($g_oActionTitle, $sActionName) Then
		Local $sCommand = _ActionRead($sActionName, 'Command'), $sTitle
		Local $aFormat = StringRegExp($sCommand, '^to(\w+)$', 1)
		Local $bConvert = Not @error
		If $sCommand = 'loss' Then
			$sTitle = 'lossless'
		ElseIf $bConvert Then
			$sTitle = StringUpper($aFormat[0])
		ElseIf StringLeft($sCommand, 3) = 'per' Or StringInStr($sCommand, 'resize') Then
			; Те же признаки ресайза, что у разбора команды в _CompressFile
			$sTitle = 'resize'
		Else
			$sTitle = StringRegExpReplace(_ActionRead($sActionName, 'ShortGuiTitle'), '^_', '')
		EndIf
		$g_oActionTitle[$sActionName] = $sTitle
	EndIf
	Return $g_oActionTitle[$sActionName]
EndFunc   ;==>_GetActionStr


; Иконка действия в теме окна Moth, как у пункта меню проводника. Индекс в $g_hTaskImageList или -1
Func _GetTaskIconIndex($sActionName)
	If MapExists($g_oTaskIcon, $sActionName) Then Return $g_oTaskIcon[$sActionName]

	Local $iIndex = -1, $hIcon = 0
	Local $sIcon = _ActionRead($sActionName, 'Icon')
	If $sIcon <> '' Then
		Local $sPath = _GetThemePath() & '\' & _ThemeIconName($sIcon)
		If FileExists($sPath) Then
			$hIcon = _WinAPI_LoadImage(0, $sPath, $IMAGE_ICON, 16, 16, $LR_LOADFROMFILE)
		Else
			; Не файл темы, а *.jpg и подобное: иконка формата из системы
			Local $aInfo = _ExplorerIcon_Get($sIcon)
			$hIcon = _WinAPI_ShellExtractIcon($aInfo[1], $aInfo[2], 16, 16)
		EndIf
	EndIf
	If $hIcon Then
		$iIndex = _GUIImageList_ReplaceIcon($g_hTaskImageList, -1, $hIcon)
		_WinAPI_DestroyIcon($hIcon)
	EndIf
	$g_oTaskIcon[$sActionName] = $iIndex
	Return $iIndex
EndFunc   ;==>_GetTaskIconIndex


; Сжатие, а не конвертация или ресайз: только у него считается итог «сэкономлено»
Func _IsCompressionCommand($sCommand)
	Return StringInStr($sCommand, 'cq') > 0 Or $sCommand = 'lossy' Or $sCommand = 'web' Or $sCommand = 'loss'
EndFunc   ;==>_IsCompressionCommand


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
	; Клиентская ширина без рамки и без показанной полосы прокрутки. Только что добавленные строки
	; полосу ещё не показали: она нужна, если строки с шапкой выше таблицы. Иначе колонка выходила
	; шире, появлялась горизонтальная прокрутка, а шапка после неё оставалась недорисованной
	Local $hLV = GUICtrlGetHandle($g_iListView)
	Local $iWidth = _WinAPI_GetClientWidth($hLV)
	If $iWidth <= 0 Then Return
	Local $iCount = _GUICtrlListView_GetItemCount($g_iListView)
	If $iCount And Not BitAND(_WinAPI_GetWindowLong($hLV, $GWL_STYLE), $WS_VSCROLL) Then
		Local $aRow = _GUICtrlListView_GetItemRect($g_iListView, 0)
		If _WinAPI_GetWindowHeight(_GUICtrlListView_GetHeader($g_iListView)) + $iCount * ($aRow[3] - $aRow[1]) > _
				_WinAPI_GetClientHeight($hLV) Then $iWidth -= _WinAPI_GetSystemMetrics($SM_CXVSCROLL)
	EndIf
	For $iCol = 0 To 5
		If $iCol <> $COL_FILE Then $iWidth -= _GUICtrlListView_GetColumnWidth($g_iListView, $iCol)
	Next
	_GUICtrlListView_SetColumnWidth($g_iListView, $COL_FILE, $iWidth)
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

	; Новые файлы: таблица снова следует за работой, даже если прокрутку выключил клик
	$g_bAutoScroll = True

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
	Local $sWinnerPath, $sTempPath, $sSourceFile, $iError
	Local $sColors = _GetNumberFromString(_ActionRead($sActionName, 'Command'))

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
	Local $sPathFileJpg = _GetTempPathFileForCompression('magick', $FORMAT_JPG), $sWinnerPath, $iWinnerSize, $sSourceFile = $sPathFile
	; Прозрачность заливается белым: без заливки фон становился чёрным. У анимации первый кадр
	Local $sCommand = '{pathFile} -quiet -background white -alpha remove -alpha off {pathFileOut}'

	Switch $sExtensionFile
		Case $FORMAT_JPG, $FORMAT_JPE, $FORMAT_JPEG, $FORMAT_JFIF
			; Тот же JPEG: перекодировать незачем, только повернуть по Exif и сжать без потерь.
			; JPG в JPG сюда не доходит: его отсеял _CompressFile
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
	Local $bSaveExif = _ActionRead($sActionName, 'SaveExif') = 1
	Local $bToProgressive = _ActionRead($sActionName, 'ToProgressive') = 1

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
	Local $bSaveExif = _ActionRead($sActionName, 'SaveExif') = 1
	Local $bToProgressive = _ActionRead($sActionName, 'ToProgressive') = 1

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
	Local $bSaveExif = _ActionRead($sAction, 'SaveExif') = 1
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
	Local $bSaveExif = _ActionRead($sAction, 'SaveExif') = 1
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
	Local $bSaveExif = _ActionRead($sAction, 'SaveExif') = 1
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
	; Больше 99% по модулю дробная часть не нужна: +1550.78% читается хуже +1551%
	Local $nDisplay = Round($nPercent, Abs($nPercent) > 99 ? 0 : 2)
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

