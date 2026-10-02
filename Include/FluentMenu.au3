#include-once
#include <EditConstants.au3>
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <WinAPIGdi.au3>
#include <WinAPIIcons.au3>
#include <WinAPIRes.au3>
#include <WinAPIShellEx.au3>
#include <WinAPISysWin.au3>
#include <Math.au3>

#include "FluentCore.au3"

; ============================================================
; FluentMenu – окно выбора в духе контекстного меню
; ============================================================
; Список пунктов с иконками, выбор в один клик. Окно закрывается выбором,
; Esc или кликом в любое другое место.
;
; У пункта может быть кнопка-переключатель справа (_FluentMenu_SetButton): булавка
; «закрепить» или «открепить». Контур булавки виден у строки под курсором, её клик окно
; не закрывает. Включённый пункт и без наведения несёт залитую булавку цвета акцента,
; под курсором кнопки она перечёркнута. Булавка нарисована векторно.
; Левее булавки может появляться крестик «убрать из списка»: только у строки под курсором,
; на месте пояснения справа: пояснение у такой строки прячется. Места под крестик строка не держит
; и без наведения выглядит как обычно. Клик по нему убирает пункт сразу (_FluentMenu_SetRemove).
; Высота окна меняется от вставки и удаления пунктов, нижний край при этом стоит на месте:
; панель и живые пункты не прыгают.
; Группы пунктов разделяет черта (_FluentMenu_SetDividers).
; Список можно сортировать (_FluentMenu_SetSort): у строки под курсором левее крестика
; стрелки «вверх» и «вниз», пункт меняется местами с соседом в своей группе. Курсор
; едет вместе с пунктом, и следующий клик двигает его дальше. Стрелка, которой некуда
; вести, видна недоступной.
; У последнего живого пункта вместо булавки может стоять стрелка «добавить в список»
; (_FluentMenu_SetAdd): пункт поднимается в список, закрепляют его уже там. Пункт вставляет
; приложение (_FluentMenu_InsertItem). Такой пункт в списке уже есть – стрелка недоступна.
; У подсвеченной строки кнопки в рамках с лёгкой заливкой, у кнопки под курсором заливка ярче,
; недоступная кнопка - в рамке без заливки.
; Клавиши: стрелки, Home, End, Enter – выбрать, пробел – переключить кнопку.
; Строка под нажатой кнопкой мыши заливается тусклее наведения: клик виден, пока кнопка нажата.
; Пункт можно выбрать, не закрывая окна (_FluentMenu_SetPick): клик или Enter с Ctrl.
; Пункт уходит приложению, окно остаётся, и так выбирают несколько пунктов подряд. Приложение
; помечает выбранные (_FluentMenu_SetMarked): подпись пункта тускнеет.
; Окно, которое выбор поднял (запущенная программа), активность у меню не отнимает.
; Shift и левая кнопка мыши в любом месте окна, кроме контролов панели, тащат окно.
;
; Шрифт – системный шрифт меню (lfMenuFont из NONCLIENTMETRICS): гарнитура, размер,
; жирность и курсив те же, что у контекстного меню проводника.
;
; Вид рисуется одной картинкой в Pic: пунктов немного, и наведение
; перерисовывает один битмап без мерцания отдельных контролов. Pic выключен,
; поэтому мышь достаётся самому окну (WM_MOUSEMOVE и клики).
;
; Пункты – массив [n][3], [n][4] или [n][5]: подпись, файл иконки (.ico, exe или dll) либо '',
; индекс иконки в exe/dll, состояние кнопки (True/False; '' или нет колонки – без кнопки),
; крестик (True/False; '' или нет колонки – без крестика). После сортировки, вставки
; и удаления _FluentMenu_Show возвращает пункты в нынешнем порядке, без убранных.
; Подпись как у пункта меню Win32: «название<Tab>пояснение», пояснение стоит
; приглушённым столбцом у правого края.
;
; Пока окно открыто, его обработчики WM_MOUSEMOVE, WM_*BUTTON* и WM_ACTIVATE стоят
; в маршрутизаторе ядра рядом с обработчиками приложения. Приложение регистрирует свои
; через _FluentMsg_Register: прямой GUIRegisterMsg на эти сообщения меню бы перебило.
;
; Под пунктами может стоять панель приложения (_FluentMenu_SetPanel): поле ввода, сегменты,
; кнопки, отделённые чертой. Контролы панели приложение создаёт само в окне меню, под ними
; лежит картинка меню с WS_CLIPSIBLINGS, и перерисовка строк их не затирает. Рисованные
; контролы панели заливают углы фоном окна, поэтому на время показа фон окна – цвет карточки.
; Home, End и пробел в поле ввода панели работают как в поле; Enter уходит панели,
; если пункт не подсвечен стрелками. Ввод в поле гасит подсветку стрелками.
; Последние пункты могут быть живыми – результатом панели: приложение меняет их на лету
; (_FluentMenu_SetItem). Пока курсор не над другими пунктами (над панелью, вне окна),
; последний живой пункт подсвечен, как под курсором: его и собирают полями панели,
; клик по нему или Enter его выбирают. Его кнопка видна и без наведения.
; Недоступный пункт серый, не подсвечивается и не выбирается.

; Метрика меню Windows 11: поле вокруг пунктов, пункт 28, иконка 16; зазор до столбца пояснений
Global Const $gc_iFluentMenuPad = 4, $gc_iFluentMenuItemH = 28, $gc_iFluentMenuIcon = 16
Global Const $gc_iFluentMenuHintGap = 24
Global Const $gc_iFluentMenuIconX = 12, $gc_iFluentMenuTextX = 40, $gc_iFluentMenuTextPadR = 24, $gc_iFluentMenuMinW = 180
; Кнопка пункта: сторона, поле до края строки, зазор до подписи; булавка в ней
Global Const $gc_iFluentMenuBtn = 24, $gc_iFluentMenuBtnPad = 2, $gc_iFluentMenuBtnGap = 12, $gc_iFluentMenuGlyph = 16
; Поле панели слева и справа: по иконкам пунктов
Global Const $gc_iFluentMenuPanelX = 12
; Промежуток между группами пунктов, черта посередине
Global Const $gc_iFluentMenuDividerH = 9

Global $__g_hFluentMenuGui = 0, $__g_iFluentMenuPic = 0, $__g_hFluentMenuPicBmp = 0
; Системный шрифт меню и его семейство: семейство живёт, пока жив шрифт. 0 – шрифт ядра
Global $__g_hFluentMenuSysFont = 0, $__g_hFluentMenuSysFamily = 0
Global $__g_aFluentMenuTexts[0], $__g_aFluentMenuHints[0], $__g_aFluentMenuIcons[0], $__g_aFluentMenuStates[0], $__g_iFluentMenuHintW = 0
Global $__g_iFluentMenuW = 0, $__g_iFluentMenuH = 0, $__g_bFluentMenuHasBtn = False
; Крестики пунктов и есть ли он хоть у одного пункта
Global $__g_aFluentMenuRemovable[0], $__g_bFluentMenuHasRemove = False
; Верх каждой строки; перед какими пунктами черта ('|1|4|'); связанная пара пунктов (-1 – нет)
Global $__g_aFluentMenuRowY[0], $__g_sFluentMenuDividers = ''
; Подпись, файл и индекс иконки пунктов как в $aItems: с ними пункты уходят обратно в новом порядке
Global $__g_aFluentMenuSrc[0][3]
; Обработчики сортировки, крестика и кнопки «добавить», доступна ли она сейчас
Global $__g_sFluentMenuOnMove = '', $__g_sFluentMenuOnRemove = '', $__g_sFluentMenuOnAdd = '', $__g_bFluentMenuAddable = False
; Обработчик переключения кнопки пункта
Global $__g_sFluentMenuOnToggle = ''
; Выбор без закрытия: обработчик, помеченные пункты, когда выбрали последний раз
; и надо ли вернуть окну активность
Global $__g_sFluentMenuOnPick = '', $__g_aFluentMenuMarked[0], $__g_hFluentMenuPickTimer = 0, $__g_bFluentMenuRefocus = False
; Панель приложения: обработчики создания, Enter, закрытия и сдвига; верх панели в окне, 0 – без черты
Global $__g_sFluentMenuPanelCreate = '', $__g_sFluentMenuPanelEnter = '', $__g_sFluentMenuPanelClose = ''
Global $__g_sFluentMenuPanelShift = ''
; Папка PNG-иконок контролов панели, когда ядро поднимает само меню
Global $__g_sFluentMenuIconDir = ''
Global $__g_iFluentMenuPanelY = 0
; Сколько последних пунктов живые, высота панели
Global $__g_iFluentMenuLive = 0, $__g_iFluentMenuPanelH = 0
; Доступность пунктов
Global $__g_aFluentMenuEnabled[0]
; Подсвеченная строка, кто её подсветил, какая её кнопка под курсором; что нажато в окне.
; Кнопки: 0 – нет, 1 – булавка, 2 – крестик, 3 – вверх, 4 – вниз, 5 – добавить
Global $__g_iFluentMenuHot = -1, $__g_bFluentMenuHotMouse = False, $__g_iFluentMenuBtnHot = 0
Global $__g_iFluentMenuPressRow = -1, $__g_iFluentMenuPressBtn = 0, $__g_bFluentMenuPressed = False
; Клик по кнопке ждёт главного цикла окна: обработчик сообщения не двигает окно и строки.
; Выбор без закрытия ждёт так же, как кнопка 6, перетаскивание окна - как 7
Global $__g_iFluentMenuPendingRow = -1, $__g_iFluentMenuPendingBtn = 0
; Где курсор стоял на экране при последнем WM_MOUSEMOVE. Система шлёт его и без
; движения мыши (окно появилось под курсором, перерисовка), причём с разными
; координатами в lParam, и такой повтор не должен сбивать подсветку клавиш
Global $__g_iFluentMenuLastX = -1, $__g_iFluentMenuLastY = -1
Global $__g_iFluentMenuResult = -1, $__g_bFluentMenuDone = False, $__g_bFluentMenuWasActive = False
; Windows 11 скругляет окно и рисует рамку сама, на Windows 10 рамку рисуем мы
Global $__g_bFluentMenuDwmFrame = False
; Пустышки для клавиш: [ControlID, клавиша]
Global $__g_aFluentMenuKeys[7][2] = [[0, '{UP}'], [0, '{DOWN}'], [0, '{HOME}'], [0, '{END}'], [0, '{ENTER}'], [0, '{SPACE}'], _
		[0, '^{ENTER}']]


; Черта перед пунктами $aRows (индексы) на один _FluentMenu_Show: группы в списке
Func _FluentMenu_SetDividers($aRows)
	$__g_sFluentMenuDividers = '|'
	For $iRow In $aRows
		$__g_sFluentMenuDividers &= $iRow & '|'
	Next
EndFunc   ;==>_FluentMenu_SetDividers


; Кнопка у пунктов с состоянием. $sOnToggle получает индекс пункта и новое состояние
Func _FluentMenu_SetButton($sOnToggle)
	$__g_sFluentMenuOnToggle = $sOnToggle
EndFunc   ;==>_FluentMenu_SetButton


; Стрелки сортировки у пунктов до живых на один _FluentMenu_Show. Пункт уже передвинут,
; когда $sOnMove получает его прежний и новый индексы
Func _FluentMenu_SetSort($sOnMove)
	$__g_sFluentMenuOnMove = $sOnMove
EndFunc   ;==>_FluentMenu_SetSort


; Крестик убирает пункт сразу. $sOnRemove на один _FluentMenu_Show получает прежний
; индекс уже убранного пункта
Func _FluentMenu_SetRemove($sOnRemove)
	$__g_sFluentMenuOnRemove = $sOnRemove
EndFunc   ;==>_FluentMenu_SetRemove


; Стрелка «добавить в список» у последнего живого пункта на один _FluentMenu_Show.
; $sOnAdd получает индекс пункта и сам вставляет его копию (_FluentMenu_InsertItem).
; Доступна стрелка, пока приложение не скажет иначе (_FluentMenu_SetAddable)
Func _FluentMenu_SetAdd($sOnAdd)
	$__g_sFluentMenuOnAdd = $sOnAdd
	$__g_bFluentMenuAddable = True
EndFunc   ;==>_FluentMenu_SetAdd


; Выбор без закрытия окна на один _FluentMenu_Show: клик или Enter с Ctrl.
; $sOnPick получает индекс пункта, окно остаётся открытым
Func _FluentMenu_SetPick($sOnPick)
	$__g_sFluentMenuOnPick = $sOnPick
EndFunc   ;==>_FluentMenu_SetPick


; Метка выбранного пункта открытого окна: подпись тусклее, между обычной и недоступной
Func _FluentMenu_SetMarked($iRow, $bMarked)
	If Not $__g_hFluentMenuGui Or $iRow < 0 Or $iRow >= UBound($__g_aFluentMenuMarked) Then Return
	If $__g_aFluentMenuMarked[$iRow] = $bMarked Then Return
	$__g_aFluentMenuMarked[$iRow] = $bMarked
	__FluentMenu_Render()
EndFunc   ;==>_FluentMenu_SetMarked


; Доступна ли стрелка «добавить»: такой пункт уже есть в списке – недоступна
Func _FluentMenu_SetAddable($bAddable)
	If $bAddable = $__g_bFluentMenuAddable Then Return
	$__g_bFluentMenuAddable = $bAddable
	If $__g_hFluentMenuGui Then __FluentMenu_Render()
EndFunc   ;==>_FluentMenu_SetAddable


; Панель приложения под пунктами на один _FluentMenu_Show. $sOnCreate($hGui, $iX, $iY, $iW)
; создаёт контролы в окне меню до показа и возвращает [ширина, высота, контрол с фокусом]:
; ширина не меньше $iW, окно подстроится под неё; фокус 0 – не ставить.
; $sOnEnter – Enter в окне, пока пункт не подсвечен стрелками. $sOnClose – перед удалением
; окна: здесь приложение удаляет рисованные контролы панели. $iLive последних пунктов –
; живые, результат панели. $sOnShift($iDY) – вставка пункта сдвинула панель вниз на $iDY:
; приложение двигает её контролы
Func _FluentMenu_SetPanel($sOnCreate, $sOnEnter = '', $sOnClose = '', $iLive = 0, $sOnShift = '')
	$__g_sFluentMenuPanelCreate = $sOnCreate
	$__g_sFluentMenuPanelEnter = $sOnEnter
	$__g_sFluentMenuPanelClose = $sOnClose
	$__g_sFluentMenuPanelShift = $sOnShift
	$__g_iFluentMenuLive = $iLive
EndFunc   ;==>_FluentMenu_SetPanel


; Папка PNG-иконок для контролов панели (сегменты, подписи полей). Нужна, когда ядро
; поднимает само меню: у приложения без своего окна _FluentInit не было
Func _FluentMenu_SetIconDir($sDir)
	$__g_sFluentMenuIconDir = $sDir
EndFunc   ;==>_FluentMenu_SetIconDir


; Меняет пункт открытого окна: подпись «название<Tab>пояснение», иконка как в $aItems,
; состояние кнопки (True/False, '' – без кнопки; место под кнопку есть, только если при показе
; она была хоть у одного пункта). Недоступный пункт серый и не выбирается
Func _FluentMenu_SetItem($iRow, $sText, $sIcon = '', $iIconIndex = 0, $vState = '', $bEnabled = True)
	If Not $__g_hFluentMenuGui Or $iRow < 0 Or $iRow >= UBound($__g_aFluentMenuTexts) Then Return
	Local $aText = StringSplit($sText, @TAB, 2)
	$__g_aFluentMenuTexts[$iRow] = $aText[0]
	$__g_aFluentMenuHints[$iRow] = UBound($aText) > 1 ? StringStripWS($aText[1], 3) : ''
	If $__g_aFluentMenuIcons[$iRow] Then _GDIPlus_BitmapDispose($__g_aFluentMenuIcons[$iRow])
	$__g_aFluentMenuIcons[$iRow] = __FluentMenu_LoadIcon($sIcon, $iIconIndex)
	$__g_aFluentMenuSrc[$iRow][0] = $sText
	$__g_aFluentMenuSrc[$iRow][1] = $sIcon
	$__g_aFluentMenuSrc[$iRow][2] = $iIconIndex
	$__g_aFluentMenuStates[$iRow] = IsBool($vState) ? $vState : ''
	$__g_aFluentMenuEnabled[$iRow] = $bEnabled
	If Not $bEnabled And $__g_iFluentMenuHot = $iRow Then $__g_iFluentMenuHot = -1
	__FluentMenu_Render()
EndFunc   ;==>_FluentMenu_SetItem


; Состояние кнопки пункта открытого окна без смены подписи
Func _FluentMenu_SetState($iRow, $bState)
	If Not $__g_hFluentMenuGui Or $iRow < 0 Or $iRow >= UBound($__g_aFluentMenuStates) Then Return
	If Not IsBool($__g_aFluentMenuStates[$iRow]) Or $__g_aFluentMenuStates[$iRow] = $bState Then Return
	$__g_aFluentMenuStates[$iRow] = $bState
	__FluentMenu_Render()
EndFunc   ;==>_FluentMenu_SetState


; Вставляет пункт перед $iRow открытого окна. Подпись, иконка и состояние – как
; у _FluentMenu_SetItem, $vRemovable – крестик (True/False, '' – без крестика).
; Кнопки ложатся на места, что окно отвело при показе. Пункт продолжает группу выше:
; черта перед $iRow встаёт перед следующим. Живые пункты остаются последними.
; Окно растёт вверх, нижний край на месте (__FluentMenu_Resize)
Func _FluentMenu_InsertItem($iRow, $sText, $sIcon = '', $iIconIndex = 0, $vState = '', $vRemovable = '')
	Local $iCount = UBound($__g_aFluentMenuTexts)
	If Not $__g_hFluentMenuGui Or $iRow < 0 Or $iRow > $iCount - $__g_iFluentMenuLive Then Return

	Local $aText = StringSplit($sText, @TAB, 2)
	__FluentMenu_InsertIn($__g_aFluentMenuTexts, $iRow, $aText[0])
	__FluentMenu_InsertIn($__g_aFluentMenuHints, $iRow, UBound($aText) > 1 ? StringStripWS($aText[1], 3) : '')
	__FluentMenu_InsertIn($__g_aFluentMenuIcons, $iRow, __FluentMenu_LoadIcon($sIcon, $iIconIndex))
	__FluentMenu_InsertIn($__g_aFluentMenuStates, $iRow, IsBool($vState) ? $vState : '')
	__FluentMenu_InsertIn($__g_aFluentMenuEnabled, $iRow, True)
	__FluentMenu_InsertIn($__g_aFluentMenuRemovable, $iRow, IsBool($vRemovable) ? $vRemovable : '')
	__FluentMenu_InsertIn($__g_aFluentMenuMarked, $iRow, False)
	ReDim $__g_aFluentMenuSrc[$iCount + 1][3]
	For $i = $iCount To $iRow + 1 Step -1
		For $j = 0 To 2
			$__g_aFluentMenuSrc[$i][$j] = $__g_aFluentMenuSrc[$i - 1][$j]
		Next
	Next
	$__g_aFluentMenuSrc[$iRow][0] = $sText
	$__g_aFluentMenuSrc[$iRow][1] = $sIcon
	$__g_aFluentMenuSrc[$iRow][2] = $iIconIndex

	; Индексы от $iRow и ниже съезжают на строку
	Local $sDividers = $__g_sFluentMenuDividers
	If $sDividers <> '' Then
		$__g_sFluentMenuDividers = '|'
		For $sIndex In StringSplit($sDividers, '|', 2)
			If $sIndex <> '' Then $__g_sFluentMenuDividers &= (Int($sIndex) >= $iRow ? Int($sIndex) + 1 : $sIndex) & '|'
		Next
	EndIf
	If $__g_iFluentMenuHot >= $iRow Then $__g_iFluentMenuHot += 1

	__FluentMenu_RowsLayout()
	__FluentMenu_Resize()
EndFunc   ;==>_FluentMenu_InsertItem


; Убирает пункт $iRow открытого окна, живые пункты не убираются. Черта перед ним
; остаётся перед следующим. Окно становится ниже, нижний край на месте
Func _FluentMenu_DeleteItem($iRow)
	Local $iCount = UBound($__g_aFluentMenuTexts)
	If Not $__g_hFluentMenuGui Or $iRow < 0 Or $iRow >= $iCount - $__g_iFluentMenuLive Then Return

	If $__g_aFluentMenuIcons[$iRow] Then _GDIPlus_BitmapDispose($__g_aFluentMenuIcons[$iRow])
	__FluentMenu_DeleteIn($__g_aFluentMenuTexts, $iRow)
	__FluentMenu_DeleteIn($__g_aFluentMenuHints, $iRow)
	__FluentMenu_DeleteIn($__g_aFluentMenuIcons, $iRow)
	__FluentMenu_DeleteIn($__g_aFluentMenuStates, $iRow)
	__FluentMenu_DeleteIn($__g_aFluentMenuEnabled, $iRow)
	__FluentMenu_DeleteIn($__g_aFluentMenuRemovable, $iRow)
	__FluentMenu_DeleteIn($__g_aFluentMenuMarked, $iRow)
	For $i = $iRow To $iCount - 2
		For $j = 0 To 2
			$__g_aFluentMenuSrc[$i][$j] = $__g_aFluentMenuSrc[$i + 1][$j]
		Next
	Next
	ReDim $__g_aFluentMenuSrc[$iCount - 1][3]

	; Индексы ниже $iRow поднимаются на строку
	Local $sDividers = $__g_sFluentMenuDividers
	If $sDividers <> '' Then
		$__g_sFluentMenuDividers = '|'
		For $sIndex In StringSplit($sDividers, '|', 2)
			If $sIndex <> '' Then $__g_sFluentMenuDividers &= (Int($sIndex) > $iRow ? Int($sIndex) - 1 : $sIndex) & '|'
		Next
	EndIf
	If $__g_iFluentMenuHot = $iRow Then
		$__g_iFluentMenuHot = -1
	ElseIf $__g_iFluentMenuHot > $iRow Then
		$__g_iFluentMenuHot -= 1
	EndIf

	__FluentMenu_RowsLayout()
	__FluentMenu_Resize()
EndFunc   ;==>_FluentMenu_DeleteItem


; Закрывает окно из обработчика панели: _FluentMenu_Show вернёт $iResult
Func _FluentMenu_End($iResult = -1)
	If Not $__g_hFluentMenuGui Then Return
	$__g_iFluentMenuResult = $iResult
	GUISetState(@SW_HIDE, $__g_hFluentMenuGui)
	$__g_bFluentMenuDone = True
EndFunc   ;==>_FluentMenu_End


; Показывает окно в точке ($iX, $iY) и ждёт выбора. По умолчанию у курсора:
; курсор в середине первой строки, окно по центру от него по горизонтали.
; Состояния кнопок возвращаются в $aItems. $bDark – тёмная тема;
; Default – палитра как есть (приложение уже вызвало _FluentInit и _FluentSetTheme).
; Возвращает индекс выбранного пункта, -1 – окно закрыли без выбора. С панелью пунктов
; может не быть совсем
Func _FluentMenu_Show(ByRef $aItems, $bDark = Default, $iX = Default, $iY = Default)
	Local $iCount = UBound($aItems), $bPanel = $__g_sFluentMenuPanelCreate <> ''
	If $iCount = 0 And Not $bPanel Then Return -1
	If Not $bPanel Then $__g_iFluentMenuLive = 0
	$__g_iFluentMenuLive = _Min($__g_iFluentMenuLive, $iCount)
	$__g_iFluentMenuPanelH = 0

	Local $iOldMode = Opt('GUIOnEventMode', 1)
	$__g_iFluentMenuHot = -1
	$__g_bFluentMenuHotMouse = False
	$__g_iFluentMenuBtnHot = 0
	$__g_bFluentMenuPressed = False
	$__g_iFluentMenuPendingBtn = 0
	$__g_iFluentMenuLastX = -1
	$__g_iFluentMenuLastY = -1
	$__g_iFluentMenuResult = -1
	$__g_bFluentMenuDone = False
	$__g_bFluentMenuWasActive = False
	$__g_hFluentMenuPickTimer = 0
	$__g_bFluentMenuRefocus = False

	; Окно создаётся за экраном: размер известен только после замера текста
	$__g_hFluentMenuGui = GUICreate('', 100, 100, -32000, -32000, $WS_POPUP, BitOR($WS_EX_TOPMOST, $WS_EX_TOOLWINDOW))
	Local $sFont = _FluentFontApply($__g_hFluentMenuGui, 9)
	; Приложение без своего окна (меню Проводника) ядро не поднимало: меню поднимает его само
	Local $bOwnInit = Not $__g_hFluentMeasureGfx
	If $bOwnInit Then
		_FluentInit($__g_hFluentMenuGui, $sFont, 9, $__g_sFluentMenuIconDir)
		; Наведение окно ловит само, по WM_MOUSEMOVE: общий опрос нужен только контролам панели
		If Not $bPanel Then AdlibUnRegister('__FluentHoverTick')
	EndIf
	If Not IsKeyword($bDark) Then _FluentSetTheme($bDark)
	Local $iOldBg = $g_iFluentBg
	If $bPanel Then $g_iFluentBg = $g_iFluentCard

	__FluentMenu_FontCreate()
	__FluentMenu_LoadItems($aItems)
	__FluentMenu_Measure()

	; Картинка лежит под контролами панели и не рисует поверх них
	$__g_iFluentMenuPic = GUICtrlCreatePic('', 0, 0, $__g_iFluentMenuW, $__g_iFluentMenuH, $WS_CLIPSIBLINGS)
	GUICtrlSetState($__g_iFluentMenuPic, $GUI_DISABLE)
	Local $iFocus = $bPanel ? __FluentMenu_PanelCreate() : 0

	Local $bAtCursor = IsKeyword($iX) Or IsKeyword($iY)
	If $bAtCursor Then
		Local $tPoint = DllStructCreate($tagPOINT)
		DllCall('user32.dll', 'bool', 'GetCursorPos', 'struct*', $tPoint)
		$iX = $tPoint.X
		$iY = $tPoint.Y
	EndIf
	__FluentMenu_Place($iX, $iY, $bAtCursor)
	WinMove($__g_hFluentMenuGui, '', $iX, $iY, $__g_iFluentMenuW, $__g_iFluentMenuH)
	GUICtrlSetPos($__g_iFluentMenuPic, 0, 0, $__g_iFluentMenuW, $__g_iFluentMenuH)
	If $bPanel Then _FluentSendToBack($__g_iFluentMenuPic)

	__FluentMenu_Frame()
	__FluentMenu_Render()
	__FluentMenu_Events(True)

	GUISetState(@SW_SHOW, $__g_hFluentMenuGui)
	WinActivate($__g_hFluentMenuGui)
	If $iFocus Then GUICtrlSetState($iFocus, $GUI_FOCUS)

	While Not $__g_bFluentMenuDone
		Sleep(10)
		__FluentMenu_Poll()
	WEnd

	__FluentMenu_Events(False)
	If $bPanel And $__g_sFluentMenuPanelClose <> '' Then Call($__g_sFluentMenuPanelClose)
	GUIDelete($__g_hFluentMenuGui)
	$__g_hFluentMenuGui = 0
	__FluentMenu_Free()
	If $bOwnInit Then _FluentShutdown()
	$g_iFluentBg = $iOldBg
	$__g_iFluentMenuPanelY = 0
	$__g_iFluentMenuPanelH = 0
	$__g_sFluentMenuDividers = ''
	$__g_sFluentMenuOnMove = ''
	$__g_sFluentMenuOnRemove = ''
	$__g_sFluentMenuOnAdd = ''
	$__g_bFluentMenuAddable = False
	$__g_sFluentMenuOnPick = ''
	_FluentMenu_SetPanel('')
	Opt('GUIOnEventMode', $iOldMode)

	; Пункты в нынешнем порядке, со вставленными
	Local $iCols = UBound($aItems, 2)
	$iCount = UBound($__g_aFluentMenuTexts)
	ReDim $aItems[$iCount][$iCols]
	For $i = 0 To $iCount - 1
		For $j = 0 To 2
			$aItems[$i][$j] = $__g_aFluentMenuSrc[$i][$j]
		Next
		If $iCols > 3 Then $aItems[$i][3] = $__g_aFluentMenuStates[$i]
		If $iCols > 4 Then $aItems[$i][4] = $__g_aFluentMenuRemovable[$i]
	Next
	Return $__g_iFluentMenuResult
EndFunc   ;==>_FluentMenu_Show


; ============================================================
; Внутреннее
; ============================================================

Func __FluentMenu_LoadItems(Const ByRef $aItems)
	Local $iCount = UBound($aItems), $bStates = UBound($aItems, 2) > 3, $bRemove = UBound($aItems, 2) > 4
	ReDim $__g_aFluentMenuTexts[$iCount]
	ReDim $__g_aFluentMenuHints[$iCount]
	ReDim $__g_aFluentMenuIcons[$iCount]
	ReDim $__g_aFluentMenuStates[$iCount]
	ReDim $__g_aFluentMenuEnabled[$iCount]
	ReDim $__g_aFluentMenuRemovable[$iCount]
	ReDim $__g_aFluentMenuMarked[$iCount]
	ReDim $__g_aFluentMenuSrc[$iCount][3]
	$__g_bFluentMenuHasBtn = False
	$__g_bFluentMenuHasRemove = False
	For $i = 0 To $iCount - 1
		$__g_aFluentMenuEnabled[$i] = True
		$__g_aFluentMenuMarked[$i] = False
		For $j = 0 To 2
			$__g_aFluentMenuSrc[$i][$j] = $aItems[$i][$j]
		Next
		Local $aText = StringSplit($aItems[$i][0], @TAB, 2)
		$__g_aFluentMenuTexts[$i] = $aText[0]
		$__g_aFluentMenuHints[$i] = UBound($aText) > 1 ? StringStripWS($aText[1], 3) : ''
		$__g_aFluentMenuIcons[$i] = __FluentMenu_LoadIcon($aItems[$i][1], $aItems[$i][2])
		; Кнопка только у пункта с состоянием
		$__g_aFluentMenuStates[$i] = ($bStates And IsBool($aItems[$i][3])) ? $aItems[$i][3] : ''
		If IsBool($__g_aFluentMenuStates[$i]) Then $__g_bFluentMenuHasBtn = True
		$__g_aFluentMenuRemovable[$i] = ($bRemove And IsBool($aItems[$i][4])) ? $aItems[$i][4] : ''
		If IsBool($__g_aFluentMenuRemovable[$i]) Then $__g_bFluentMenuHasRemove = True
	Next
	__FluentMenu_RowsLayout()
EndFunc   ;==>__FluentMenu_LoadItems


; Верх каждой строки: черты между группами раздвигают строки
Func __FluentMenu_RowsLayout()
	Local $iCount = UBound($__g_aFluentMenuTexts), $iY = $gc_iFluentMenuPad
	ReDim $__g_aFluentMenuRowY[$iCount]
	For $i = 0 To $iCount - 1
		If $i > 0 And StringInStr($__g_sFluentMenuDividers, '|' & $i & '|') Then $iY += $gc_iFluentMenuDividerH
		$__g_aFluentMenuRowY[$i] = $iY
		$iY += $gc_iFluentMenuItemH
	Next
EndFunc   ;==>__FluentMenu_RowsLayout


Func __FluentMenu_InsertIn(ByRef $aList, $iRow, $vValue)
	ReDim $aList[UBound($aList) + 1]
	For $i = UBound($aList) - 1 To $iRow + 1 Step -1
		$aList[$i] = $aList[$i - 1]
	Next
	$aList[$iRow] = $vValue
EndFunc   ;==>__FluentMenu_InsertIn


Func __FluentMenu_DeleteIn(ByRef $aList, $iRow)
	For $i = $iRow To UBound($aList) - 2
		$aList[$i] = $aList[$i + 1]
	Next
	ReDim $aList[UBound($aList) - 1]
EndFunc   ;==>__FluentMenu_DeleteIn


Func __FluentMenu_SwapIn(ByRef $aList, $iA, $iB)
	Local $vValue = $aList[$iA]
	$aList[$iA] = $aList[$iB]
	$aList[$iB] = $vValue
EndFunc   ;==>__FluentMenu_SwapIn


; Иконка 16x16 как GDI+ bitmap с альфой, 0 – нет иконки
Func __FluentMenu_LoadIcon($sFile, $iIndex)
	If $sFile = '' Or Not FileExists($sFile) Then Return 0
	Local $hIcon
	If StringRight($sFile, 4) = '.ico' Then
		$hIcon = _WinAPI_LoadImage(0, $sFile, $IMAGE_ICON, $gc_iFluentMenuIcon, $gc_iFluentMenuIcon, $LR_LOADFROMFILE)
	Else
		$hIcon = _WinAPI_ShellExtractIcon($sFile, $iIndex, $gc_iFluentMenuIcon, $gc_iFluentMenuIcon)
	EndIf
	If Not $hIcon Then Return 0
	Local $hBitmap = _GDIPlus_BitmapCreateFromHICON32($hIcon)
	_WinAPI_DestroyIcon($hIcon)
	Return $hBitmap
EndFunc   ;==>__FluentMenu_LoadIcon


; Ширина по самой длинной подписи и месту под кнопку, высота по пунктам
Func __FluentMenu_Measure()
	Local $hFont = __FluentMenu_Font(), $iTextW = 0
	$__g_iFluentMenuHintW = 0
	For $i = 0 To UBound($__g_aFluentMenuTexts) - 1
		$iTextW = _Max($iTextW, _FluentTextW($__g_aFluentMenuTexts[$i], $hFont))
		If $__g_aFluentMenuHints[$i] <> '' Then $__g_iFluentMenuHintW = _Max($__g_iFluentMenuHintW, _FluentTextW($__g_aFluentMenuHints[$i], $hFont))
	Next
	If $__g_iFluentMenuHintW Then $iTextW += $gc_iFluentMenuHintGap + $__g_iFluentMenuHintW
	$__g_iFluentMenuW = _Max($gc_iFluentMenuMinW, $gc_iFluentMenuTextX + $iTextW + __FluentMenu_TextPadR())
	Local $iCount = UBound($__g_aFluentMenuTexts)
	$__g_iFluentMenuH = ($iCount ? __FluentMenu_RowY($iCount - 1) + $gc_iFluentMenuItemH : $gc_iFluentMenuPad) + $gc_iFluentMenuPad
EndFunc   ;==>__FluentMenu_Measure


; Панель приложения под пунктами, над ней черта. Окно растёт под размер панели.
; Возвращает контрол, которому панель отдаёт фокус
Func __FluentMenu_PanelCreate()
	; Без пунктов нет и черты: панель с самого верха
	$__g_iFluentMenuPanelY = UBound($__g_aFluentMenuTexts) ? $__g_iFluentMenuH + 1 : 0
	Local $aPanel = Call($__g_sFluentMenuPanelCreate, $__g_hFluentMenuGui, $gc_iFluentMenuPanelX, $__g_iFluentMenuPanelY, _
			$__g_iFluentMenuW - $gc_iFluentMenuPanelX * 2)
	If Not IsArray($aPanel) Or UBound($aPanel) < 2 Then Return 0
	$__g_iFluentMenuW = _Max($__g_iFluentMenuW, $aPanel[0] + $gc_iFluentMenuPanelX * 2)
	$__g_iFluentMenuPanelH = $aPanel[1]
	$__g_iFluentMenuH = $__g_iFluentMenuPanelY + $__g_iFluentMenuPanelH
	Return UBound($aPanel) > 2 ? $aPanel[2] : 0
EndFunc   ;==>__FluentMenu_PanelCreate


; Поле справа от подписи: с кнопками в нём живёт кнопка
Func __FluentMenu_TextPadR()
	; Крестик ложится на пояснение: место держится только под одну кнопку
	If Not $__g_bFluentMenuHasBtn And Not $__g_bFluentMenuHasRemove And $__g_sFluentMenuOnAdd = '' Then _
			Return $gc_iFluentMenuTextPadR
	Return $gc_iFluentMenuBtnGap + $gc_iFluentMenuBtn + $gc_iFluentMenuBtnPad + $gc_iFluentMenuPad
EndFunc   ;==>__FluentMenu_TextPadR


; Как у меню: не влезает вправо – открывается влево от точки, вниз – вверх;
; и в любом случае в рабочей области монитора, где стоит точка. У курсора окно
; по центру от него по горизонтали, курсор над первой строкой, при развороте – над последней
Func __FluentMenu_Place(ByRef $iX, ByRef $iY, $bAtCursor = False)
	Local $tPoint = DllStructCreate($tagPOINT)
	$tPoint.X = $iX
	$tPoint.Y = $iY
	Local $aInfo = _WinAPI_GetMonitorInfo(_WinAPI_MonitorFromPoint($tPoint))
	If Not IsArray($aInfo) Then Return
	Local $tWork = $aInfo[1]
	Local $iL = DllStructGetData($tWork, 1), $iT = DllStructGetData($tWork, 2)
	Local $iR = DllStructGetData($tWork, 3), $iB = DllStructGetData($tWork, 4)

	Local $iDY = 0
	If $bAtCursor Then
		$iX -= Int($__g_iFluentMenuW / 2)
		$iDY = $gc_iFluentMenuPad + Int($gc_iFluentMenuItemH / 2)
	ElseIf $iX + $__g_iFluentMenuW > $iR Then
		$iX -= $__g_iFluentMenuW
	EndIf
	$iY += ($iY - $iDY + $__g_iFluentMenuH > $iB) ? $iDY - $__g_iFluentMenuH : -$iDY
	$iX = _Max($iL, _Min($iX, $iR - $__g_iFluentMenuW))
	$iY = _Max($iT, _Min($iY, $iB - $__g_iFluentMenuH))
EndFunc   ;==>__FluentMenu_Place


; Высота окна по строкам; панель с чертой встаёт под них, её контролы двигает
; приложение. Нижний край окна стоит на месте, у края рабочей области окно сдвигается.
; Строки под курсором сменились без движения мыши - подсветка встаёт по курсору
Func __FluentMenu_Resize()
	Local $iCount = UBound($__g_aFluentMenuTexts)
	Local $iRowsH = ($iCount ? __FluentMenu_RowY($iCount - 1) + $gc_iFluentMenuItemH : $gc_iFluentMenuPad) + $gc_iFluentMenuPad
	Local $iShift = 0
	If $__g_sFluentMenuPanelCreate <> '' Then
		Local $iPanelY = $iCount ? $iRowsH + 1 : 0
		$iShift = $iPanelY - $__g_iFluentMenuPanelY
		$__g_iFluentMenuPanelY = $iPanelY
		$__g_iFluentMenuH = $iPanelY + $__g_iFluentMenuPanelH
	Else
		$__g_iFluentMenuH = $iRowsH
	EndIf

	Local $aPos = WinGetPos($__g_hFluentMenuGui)
	If Not IsArray($aPos) Then Return
	Local $iY = $aPos[1] + $aPos[3] - $__g_iFluentMenuH
	Local $aInfo = _WinAPI_GetMonitorInfo(_WinAPI_MonitorFromWindow($__g_hFluentMenuGui))
	If IsArray($aInfo) Then $iY = _Max(DllStructGetData($aInfo[1], 2), _Min($iY, DllStructGetData($aInfo[1], 4) - $__g_iFluentMenuH))

	; Окно рисуется один раз, когда всё на местах: иначе мелькают старая картинка
	; на новом месте и панель до сдвига. Старое содержимое не копируется: верх окна
	; уехал, и оно встало бы не туда
	_SendMessage($__g_hFluentMenuGui, $WM_SETREDRAW, False)
	_WinAPI_SetWindowPos($__g_hFluentMenuGui, 0, $aPos[0], $iY, $__g_iFluentMenuW, $__g_iFluentMenuH, _
			BitOR($SWP_NOZORDER, $SWP_NOACTIVATE, $SWP_NOCOPYBITS))
	GUICtrlSetPos($__g_iFluentMenuPic, 0, 0, $__g_iFluentMenuW, $__g_iFluentMenuH)
	If $iShift And $__g_sFluentMenuPanelShift <> '' Then Call($__g_sFluentMenuPanelShift, $iShift)
	__FluentMenu_Render()
	_SendMessage($__g_hFluentMenuGui, $WM_SETREDRAW, True)
	_WinAPI_RedrawWindow($__g_hFluentMenuGui, 0, 0, BitOR($RDW_INVALIDATE, $RDW_ALLCHILDREN, $RDW_UPDATENOW, $RDW_FRAME))

	If Not $__g_bFluentMenuHotMouse Then Return
	Local $tPoint = DllStructCreate($tagPOINT)
	DllCall('user32.dll', 'bool', 'GetCursorPos', 'struct*', $tPoint)
	_WinAPI_ScreenToClient($__g_hFluentMenuGui, $tPoint)
	Local $iRow = __FluentMenu_HitTest($tPoint.X, $tPoint.Y)
	__FluentMenu_SetHot($iRow, True, __FluentMenu_HitBtn($iRow, $tPoint.X, $tPoint.Y))
EndFunc   ;==>__FluentMenu_Resize


; Верх строки на экране
Func __FluentMenu_RowScreenY($iRow)
	Local $aPos = WinGetPos($__g_hFluentMenuGui)
	Return (IsArray($aPos) ? $aPos[1] : 0) + __FluentMenu_RowY($iRow)
EndFunc   ;==>__FluentMenu_RowScreenY


; Строка $iRow была на экране на высоте $iOldY: курсор над окном едет за ней,
; подсветка встаёт на неё
Func __FluentMenu_Follow($iRow, $iOldY)
	Local $iDY = __FluentMenu_RowScreenY($iRow) - $iOldY
	If $__g_bFluentMenuHotMouse And $iDY Then
		Local $tPoint = DllStructCreate($tagPOINT)
		DllCall('user32.dll', 'bool', 'GetCursorPos', 'struct*', $tPoint)
		DllCall('user32.dll', 'bool', 'SetCursorPos', 'int', $tPoint.X, 'int', $tPoint.Y + $iDY)
	EndIf
	$__g_iFluentMenuHot = $iRow
	__FluentMenu_Render()
EndFunc   ;==>__FluentMenu_Follow


; Тень как у меню. На Windows 11 ещё скругление и рамка от DWM
Func __FluentMenu_Frame()
	Local $aStyle = DllCall('user32.dll', 'ulong_ptr', 'GetClassLongPtrW', 'hwnd', $__g_hFluentMenuGui, 'int', -26) ; GCL_STYLE
	If Not @error Then DllCall('user32.dll', 'ulong_ptr', 'SetClassLongPtrW', 'hwnd', $__g_hFluentMenuGui, 'int', -26, _
			'ulong_ptr', BitOR($aStyle[0], 0x00020000)) ; CS_DROPSHADOW

	$__g_bFluentMenuDwmFrame = @OSBuild >= 22000
	If Not $__g_bFluentMenuDwmFrame Then Return
	Local $tValue = DllStructCreate('int')
	DllStructSetData($tValue, 1, 3) ; DWMWCP_ROUNDSMALL
	DllCall('dwmapi.dll', 'long', 'DwmSetWindowAttribute', 'hwnd', $__g_hFluentMenuGui, 'dword', 33, _
			'struct*', $tValue, 'dword', 4) ; DWMWA_WINDOW_CORNER_PREFERENCE
	; COLORREF: байты в обратном порядке
	Local $iRgb = $g_iFluentCardBorder
	DllStructSetData($tValue, 1, BitOR(BitShift(BitAND($iRgb, 0xFF), -16), BitAND($iRgb, 0xFF00), BitShift($iRgb, 16)))
	DllCall('dwmapi.dll', 'long', 'DwmSetWindowAttribute', 'hwnd', $__g_hFluentMenuGui, 'dword', 34, _
			'struct*', $tValue, 'dword', 4) ; DWMWA_BORDER_COLOR
EndFunc   ;==>__FluentMenu_Frame


Func __FluentMenu_RowY($iRow)
	Return $__g_aFluentMenuRowY[$iRow]
EndFunc   ;==>__FluentMenu_RowY


Func __FluentMenu_IsLive($iRow)
	Return $iRow >= UBound($__g_aFluentMenuTexts) - $__g_iFluentMenuLive
EndFunc   ;==>__FluentMenu_IsLive


; Левый край кнопки $iBtn: булавка или «добавить» у правого края строки, крестик левее -
; на пояснении, ещё левее «вверх» и «вниз». Места кнопок одни на все строки
Func __FluentMenu_BtnX($iBtn = 1)
	Local $iSlot = 0
	If $iBtn <> 1 And $iBtn <> 5 And $__g_bFluentMenuHasBtn Then $iSlot += 1
	If ($iBtn = 3 Or $iBtn = 4) And $__g_bFluentMenuHasRemove Then $iSlot += 1
	If $iBtn = 3 Then $iSlot += 1
	Return $__g_iFluentMenuW - $gc_iFluentMenuPad - $gc_iFluentMenuBtnPad - $gc_iFluentMenuBtn - _
			$iSlot * ($gc_iFluentMenuBtn + $gc_iFluentMenuBtnPad)
EndFunc   ;==>__FluentMenu_BtnX


; Есть ли у строки кнопка $iBtn, доступная или нет. Крестик и стрелки сортировки видны
; только у строки под курсором
Func __FluentMenu_RowHasBtn($iRow, $iBtn)
	Switch $iBtn
		Case 1
			Return IsBool($__g_aFluentMenuStates[$iRow]) And Not __FluentMenu_IsAddRow($iRow)
		Case 2
			Return IsBool($__g_aFluentMenuRemovable[$iRow])
		Case 3, 4
			Return $__g_sFluentMenuOnMove <> '' And $iRow >= 0 And $iRow < UBound($__g_aFluentMenuTexts) - $__g_iFluentMenuLive
		Case 5
			Return __FluentMenu_IsAddRow($iRow)
	EndSwitch
	Return False
EndFunc   ;==>__FluentMenu_RowHasBtn


; Кнопка $iBtn строки работает: стрелке есть куда вести, пункта ещё нет в списке
Func __FluentMenu_BtnEnabled($iRow, $iBtn)
	Switch $iBtn
		Case 3
			Return __FluentMenu_CanMove($iRow, -1)
		Case 4
			Return __FluentMenu_CanMove($iRow, 1)
		Case 5
			Return $__g_bFluentMenuAddable And $__g_aFluentMenuEnabled[$iRow]
	EndSwitch
	Return True
EndFunc   ;==>__FluentMenu_BtnEnabled


; Строка под стрелкой «добавить» – последний живой пункт; место под стрелку у неё есть всегда
Func __FluentMenu_IsAddRow($iRow)
	Return $__g_sFluentMenuOnAdd <> '' And $__g_iFluentMenuLive > 0 And $iRow = UBound($__g_aFluentMenuTexts) - 1
EndFunc   ;==>__FluentMenu_IsAddRow


; Пункт $iRow встаёт на шаг $iStep, если оба места до живых пунктов и в одной группе,
; а пункты доступны
Func __FluentMenu_CanMove($iRow, $iStep)
	If $__g_sFluentMenuOnMove = '' Or $iRow < 0 Then Return False
	Local $iTo = $iRow + $iStep, $iSorted = UBound($__g_aFluentMenuTexts) - $__g_iFluentMenuLive
	If $iRow >= $iSorted Or $iTo < 0 Or $iTo >= $iSorted Then Return False
	If Not $__g_aFluentMenuEnabled[$iRow] Or Not $__g_aFluentMenuEnabled[$iTo] Then Return False
	; Черта перед нижним из двух – граница групп
	Return Not StringInStr($__g_sFluentMenuDividers, '|' & _Max($iRow, $iTo) & '|')
EndFunc   ;==>__FluentMenu_CanMove


Func __FluentMenu_Render()
	Local $hGfx
	Local $hCanvas = _FluentCanvas($__g_iFluentMenuW, $__g_iFluentMenuH, _FluentArgb($g_iFluentCard), $hGfx)
	Local $hFont = __FluentMenu_Font()
	Local $iRowW = $__g_iFluentMenuW - $gc_iFluentMenuPad * 2
	; Столбец пояснений прижат к правому краю области текста, название – до него
	Local $iRight = $__g_iFluentMenuW - __FluentMenu_TextPadR()

	Local $iIconDY = Int(($gc_iFluentMenuItemH - $gc_iFluentMenuIcon) / 2), $iY, $iHintW, $iTextW

	; Нажатая строка заливается между наведением и фоном: как кнопка под пальцем
	Local $iHot = __FluentMenu_ShownHot()
	Local $bPressed = $__g_bFluentMenuPressed And Not $__g_iFluentMenuPressBtn And $__g_iFluentMenuPressRow = $iHot
	If $iHot >= 0 Then _FluentFill($hGfx, $gc_iFluentMenuPad, __FluentMenu_RowY($iHot), $iRowW, $gc_iFluentMenuItemH, _
			$gc_nFluentRadTrack, _FluentArgb($bPressed ? __FluentMenu_Mix($g_iFluentHover, $g_iFluentCard) : $g_iFluentHover))
	Local $iMarkedText = __FluentMenu_Mix($g_iFluentText1, $g_iFluentText3), $iTextColor

	For $i = 0 To UBound($__g_aFluentMenuTexts) - 1
		$iY = __FluentMenu_RowY($i)
		If $__g_aFluentMenuIcons[$i] Then _GDIPlus_GraphicsDrawImageRect($hGfx, $__g_aFluentMenuIcons[$i], _
				$gc_iFluentMenuIconX, $iY + $iIconDY, $gc_iFluentMenuIcon, $gc_iFluentMenuIcon)
		; Пояснение столбцом; у живого пункта оно меняется и может оказаться шире столбца.
		; Под крестиком и стрелками сортировки его нет: место держится, название не растягивается
		$iHintW = 0
		If $__g_aFluentMenuHints[$i] <> '' Then
			$iHintW = $__g_iFluentMenuHintW
			If __FluentMenu_IsLive($i) Then $iHintW = _Max($iHintW, _FluentTextW($__g_aFluentMenuHints[$i], $hFont))
			If Not __FluentMenu_HasOverlay($i) Then _FluentText($hGfx, $__g_aFluentMenuHints[$i], $iRight - $iHintW, $iY, _
					$iHintW + 4, $gc_iFluentMenuItemH, $hFont, _FluentArgb($g_iFluentText3), 2, 1)
		EndIf
		$iTextW = $iRight - $gc_iFluentMenuTextX - ($iHintW ? $gc_iFluentMenuHintGap + $iHintW : 0)
		; Выбранный без закрытия пункт тускнеет, недоступный - серый
		$iTextColor = $__g_aFluentMenuMarked[$i] ? $iMarkedText : $g_iFluentText1
		_FluentText($hGfx, $__g_aFluentMenuTexts[$i], $gc_iFluentMenuTextX, $iY, $iTextW + 4, $gc_iFluentMenuItemH, $hFont, _
				_FluentArgb($__g_aFluentMenuEnabled[$i] ? $iTextColor : $g_iFluentText3), 0, 1, 3)
		If $__g_aFluentMenuEnabled[$i] Then __FluentMenu_DrawBtn($hGfx, $i, $iY)
	Next

	If $__g_iFluentMenuPanelY Then _FluentLine($hGfx, $gc_iFluentMenuPad, $__g_iFluentMenuPanelY - 1, $__g_iFluentMenuW - $gc_iFluentMenuPad, _
			$__g_iFluentMenuPanelY - 1, _FluentArgb($g_iFluentDivider))
	; Черты между группами - посередине промежутка
	Local $iLineY
	For $i = 1 To UBound($__g_aFluentMenuTexts) - 1
		If Not StringInStr($__g_sFluentMenuDividers, '|' & $i & '|') Then ContinueLoop
		$iLineY = __FluentMenu_RowY($i) - Int(($gc_iFluentMenuDividerH + 1) / 2)
		_FluentLine($hGfx, $gc_iFluentMenuPad, $iLineY, $__g_iFluentMenuW - $gc_iFluentMenuPad, $iLineY, _FluentArgb($g_iFluentDivider))
	Next
	If Not $__g_bFluentMenuDwmFrame Then _FluentStroke($hGfx, 0, 0, $__g_iFluentMenuW, $__g_iFluentMenuH, 0, _FluentArgb($g_iFluentCardBorder))
	_FluentCanvasApply($__g_iFluentMenuPic, $__g_hFluentMenuPicBmp, $hCanvas, $hGfx)
EndFunc   ;==>__FluentMenu_Render


; Строка с подсветкой наведения: под курсором или стрелками, а если такой нет -
; последний живой пункт, пока он доступен. -1 – подсветки нет
Func __FluentMenu_ShownHot()
	If $__g_iFluentMenuHot >= 0 Or Not $__g_iFluentMenuLive Then Return $__g_iFluentMenuHot
	Local $iLast = UBound($__g_aFluentMenuTexts) - 1
	Return $__g_aFluentMenuEnabled[$iLast] ? $iLast : -1
EndFunc   ;==>__FluentMenu_ShownHot


; Кнопка у строки под курсором: контур булавки. У подсвеченной строки кнопки в рамках с лёгкой
; заливкой, кнопка под курсором – с заливкой ярче. Закреплённый пункт несёт залитую булавку
; и без наведения, под курсором кнопки она перечёркнута: клик открепит.
; У живого пункта контур виден всегда: этот пункт и собирают, чтобы закрепить. Стрелка
; «добавить» встаёт вместо булавки и тоже видна всегда. Крестик и стрелки сортировки видны
; у строки под курсором. Недоступная кнопка - в рамке без заливки и не подсвечивается
Func __FluentMenu_DrawBtn($hGfx, $iRow, $iY)
	Local $bHot = ($iRow = $__g_iFluentMenuHot), $bLit = ($iRow = __FluentMenu_ShownHot())
	Local $bOn = $__g_aFluentMenuStates[$iRow]
	Local $iBtnY = $iY + Int(($gc_iFluentMenuItemH - $gc_iFluentMenuBtn) / 2)
	Local $iGlyphY = $iBtnY + Int(($gc_iFluentMenuBtn - $gc_iFluentMenuGlyph) / 2)
	Local $iX, $bBtnHot, $bEnabled, $iColor

	For $iBtn = 1 To 5
		If Not __FluentMenu_RowHasBtn($iRow, $iBtn) Then ContinueLoop
		; Булавка не под курсором видна у закреплённого и живого, «добавить» - всегда
		If $iBtn = 1 And Not $bHot And Not $bOn And Not __FluentMenu_IsLive($iRow) Then ContinueLoop
		If $iBtn >= 2 And $iBtn <= 4 And Not $bHot Then ContinueLoop
		$iX = __FluentMenu_BtnX($iBtn)
		$bEnabled = __FluentMenu_BtnEnabled($iRow, $iBtn)
		$bBtnHot = $bHot And $__g_iFluentMenuBtnHot = $iBtn And $bEnabled
		$iColor = $g_iFluentText3
		If $bBtnHot Then
			_FluentBox($hGfx, $iX, $iBtnY, $gc_iFluentMenuBtn, $gc_iFluentMenuBtn, $gc_nFluentRadCtrl, _
					_FluentArgb($g_iFluentSegSelBg), _FluentArgb($g_iFluentSegSelBorder))
			$iColor = $g_iFluentText1
		ElseIf $bLit And $bEnabled Then
			; Доступная кнопка - посередине между недоступной и кнопкой под курсором
			_FluentBox($hGfx, $iX, $iBtnY, $gc_iFluentMenuBtn, $gc_iFluentMenuBtn, $gc_nFluentRadCtrl, _
					_FluentArgb(__FluentMenu_Mix($g_iFluentHover, $g_iFluentSegSelBg)), _
					_FluentArgb(__FluentMenu_Mix($g_iFluentCtrlBorder, $g_iFluentSegSelBorder)))
			$iColor = __FluentMenu_Mix($g_iFluentText3, $g_iFluentText1)
		ElseIf $bLit Then
			_FluentStroke($hGfx, $iX, $iBtnY, $gc_iFluentMenuBtn, $gc_iFluentMenuBtn, $gc_nFluentRadCtrl, _FluentArgb($g_iFluentCtrlBorder))
		EndIf
		$iX += Int(($gc_iFluentMenuBtn - $gc_iFluentMenuGlyph) / 2)
		Switch $iBtn
			Case 1
				If $bOn And Not $bBtnHot Then
					__FluentMenu_DrawPin($hGfx, $iX, $iGlyphY, __FluentMenu_PinColor(), True)
				Else
					__FluentMenu_DrawPin($hGfx, $iX, $iGlyphY, $iColor, False, $bOn ? $g_iFluentSegSelBg : -1)
				EndIf
			Case 2
				__FluentMenu_DrawRemove($hGfx, $iX, $iGlyphY, $iColor)
			Case Else
				__FluentMenu_DrawArrow($hGfx, $iX, $iGlyphY, $iColor, $iBtn <> 4)
		EndSwitch
	Next
EndFunc   ;==>__FluentMenu_DrawBtn


; Крестик «убрать» в квадрате $gc_iFluentMenuGlyph
Func __FluentMenu_DrawRemove($hGfx, $nX, $nY, $iColor)
	Local $hPen = __FluentMenu_PinPen($iColor, 1.2)
	_GDIPlus_GraphicsDrawLine($hGfx, $nX + 4.5, $nY + 4.5, $nX + 11.5, $nY + 11.5, $hPen)
	_GDIPlus_GraphicsDrawLine($hGfx, $nX + 11.5, $nY + 4.5, $nX + 4.5, $nY + 11.5, $hPen)
	_GDIPlus_PenDispose($hPen)
EndFunc   ;==>__FluentMenu_DrawRemove


; Стрелка вверх или вниз в квадрате $gc_iFluentMenuGlyph
Func __FluentMenu_DrawArrow($hGfx, $nX, $nY, $iColor, $bUp)
	Local $hPen = __FluentMenu_PinPen($iColor, 1.2)
	Local $nTip = $bUp ? 3.5 : 12.5, $nWing = $bUp ? 7.5 : 8.5
	_GDIPlus_GraphicsDrawLine($hGfx, $nX + 8, $nY + 3.5, $nX + 8, $nY + 12.5, $hPen)
	_GDIPlus_GraphicsDrawLine($hGfx, $nX + 4, $nY + $nWing, $nX + 8, $nY + $nTip, $hPen)
	_GDIPlus_GraphicsDrawLine($hGfx, $nX + 8, $nY + $nTip, $nX + 12, $nY + $nWing, $hPen)
	_GDIPlus_PenDispose($hPen)
EndFunc   ;==>__FluentMenu_DrawArrow


; У строки под курсором поверх пояснения стоят крестик или стрелки сортировки
Func __FluentMenu_HasOverlay($iRow)
	If $iRow <> $__g_iFluentMenuHot Or Not $__g_aFluentMenuEnabled[$iRow] Then Return False
	For $iBtn = 2 To 4
		If __FluentMenu_RowHasBtn($iRow, $iBtn) Then Return True
	Next
	Return False
EndFunc   ;==>__FluentMenu_HasOverlay


; Цвет посередине между $iA и $iB, по каждому каналу
Func __FluentMenu_Mix($iA, $iB)
	Local $iColor = 0, $iChannel
	For $iShift = 0 To 16 Step 8
		$iChannel = Int((BitAND(BitShift($iA, $iShift), 0xFF) + BitAND(BitShift($iB, $iShift), 0xFF)) / 2)
		$iColor += BitShift($iChannel, -$iShift)
	Next
	Return $iColor
EndFunc   ;==>__FluentMenu_Mix


; Булавка в квадрате $gc_iFluentMenuGlyph: головка вправо-вверх, игла влево-вниз.
; $iSlashBg – перечеркнуть: черта с прорезью цвета фона отделена от контура
Func __FluentMenu_DrawPin($hGfx, $nX, $nY, $iColor, $bFill, $iSlashBg = -1)
	Local $aHead[13][2] = [[12], [9.6, 2.2], [13.8, 6.4], [12.5, 6.9], [10.1, 9.3], [10.4, 12], [9.3, 13.1], _
			[6.9, 10.7], [6.6, 10.4], [4.2, 8], [5.3, 6.9], [8, 7.2], [10.4, 4.8]]
	For $i = 1 To $aHead[0][0]
		$aHead[$i][0] += $nX
		$aHead[$i][1] += $nY
	Next

	Local $hPen = __FluentMenu_PinPen($iColor, 1.2)
	If $bFill Then
		Local $hBrush = _GDIPlus_BrushCreateSolid(_FluentArgb($iColor))
		_GDIPlus_GraphicsFillPolygon($hGfx, $aHead, $hBrush)
		_GDIPlus_BrushDispose($hBrush)
	EndIf
	_GDIPlus_GraphicsDrawPolygon($hGfx, $aHead, $hPen)
	_GDIPlus_GraphicsDrawLine($hGfx, $nX + 6.75, $nY + 10.55, $nX + 2.85, $nY + 14.45, $hPen)

	If $iSlashBg >= 0 Then
		Local $hGap = __FluentMenu_PinPen($iSlashBg, 3.4)
		_GDIPlus_GraphicsDrawLine($hGfx, $nX + 2, $nY + 2, $nX + 14, $nY + 14, $hGap)
		_GDIPlus_PenDispose($hGap)
		_GDIPlus_GraphicsDrawLine($hGfx, $nX + 2, $nY + 2, $nX + 14, $nY + 14, $hPen)
	EndIf
	_GDIPlus_PenDispose($hPen)
EndFunc   ;==>__FluentMenu_DrawPin


; Перо со скруглёнными концами и стыками: на 16 px острые углы булавки рвутся
Func __FluentMenu_PinPen($iColor, $nWidth)
	Local $hPen = _GDIPlus_PenCreate(_FluentArgb($iColor), $nWidth)
	_GDIPlus_PenSetLineJoin($hPen, 2) ; LineJoinRound
	_GDIPlus_PenSetStartCap($hPen, 2) ; LineCapRound
	_GDIPlus_PenSetEndCap($hPen, 2)
	Return $hPen
EndFunc   ;==>__FluentMenu_PinPen


; Акцент закреплённой булавки. В тёмной теме он сдвинут на 30% к белому, иначе тонет в фоне
Func __FluentMenu_PinColor()
	If Not $g_bFluentDark Then Return $g_iFluentAccent
	Local $iColor = 0, $iChannel
	For $iShift = 0 To 16 Step 8
		$iChannel = BitAND(BitShift($g_iFluentAccent, $iShift), 0xFF)
		$iColor += BitShift(Int($iChannel + (255 - $iChannel) * 0.3), -$iShift)
	Next
	Return $iColor
EndFunc   ;==>__FluentMenu_PinColor


; Доступная строка под точкой окна или -1
Func __FluentMenu_HitTest($iX, $iY)
	If $iX < 0 Or $iX >= $__g_iFluentMenuW Then Return -1
	Local $iTop
	For $i = 0 To UBound($__g_aFluentMenuTexts) - 1
		$iTop = __FluentMenu_RowY($i)
		If $iY >= $iTop And $iY < $iTop + $gc_iFluentMenuItemH Then Return $__g_aFluentMenuEnabled[$i] ? $i : -1
	Next
	Return -1
EndFunc   ;==>__FluentMenu_HitTest


; Следующая доступная строка по кругу от $iFrom с шагом $iStep, -1 – доступных нет
Func __FluentMenu_NextRow($iFrom, $iStep)
	Local $iRows = UBound($__g_aFluentMenuTexts), $iRow = $iFrom
	For $i = 1 To $iRows
		$iRow = Mod($iRow + $iStep + $iRows, $iRows)
		If $__g_aFluentMenuEnabled[$iRow] Then Return $iRow
	Next
	Return -1
EndFunc   ;==>__FluentMenu_NextRow


; Кнопка строки $iRow под точкой: 0 – нет, иначе номер кнопки, как у $__g_iFluentMenuBtnHot
Func __FluentMenu_HitBtn($iRow, $iX, $iY)
	If $iRow < 0 Then Return 0
	Local $iBtnY = __FluentMenu_RowY($iRow) + Int(($gc_iFluentMenuItemH - $gc_iFluentMenuBtn) / 2)
	If $iY < $iBtnY Or $iY >= $iBtnY + $gc_iFluentMenuBtn Then Return 0
	Local $iBtnX
	For $iBtn = 1 To 5
		$iBtnX = __FluentMenu_BtnX($iBtn)
		If $iX >= $iBtnX And $iX < $iBtnX + $gc_iFluentMenuBtn And __FluentMenu_RowHasBtn($iRow, $iBtn) Then Return $iBtn
	Next
	Return 0
EndFunc   ;==>__FluentMenu_HitBtn


Func __FluentMenu_SetHot($iRow, $bMouse, $iBtn = 0)
	$__g_bFluentMenuHotMouse = $bMouse
	If $iRow = $__g_iFluentMenuHot And $iBtn = $__g_iFluentMenuBtnHot Then Return
	$__g_iFluentMenuHot = $iRow
	$__g_iFluentMenuBtnHot = $iBtn
	__FluentMenu_Render()
EndFunc   ;==>__FluentMenu_SetHot


; Выбор пункта закрывает окно
Func __FluentMenu_Activate($iRow)
	If $iRow < 0 Or Not $__g_aFluentMenuEnabled[$iRow] Then Return
	$__g_iFluentMenuResult = $iRow
	; Окно прячется сразу, дальше вызывающий спокойно делает своё
	GUISetState(@SW_HIDE, $__g_hFluentMenuGui)
	$__g_bFluentMenuDone = True
EndFunc   ;==>__FluentMenu_Activate


; Выбор без закрытия: пункт уходит приложению, окно остаётся. Приложение может запустить
; программу, и её окно отнимет активность у меню: такую потерю окно не считает закрытием
Func __FluentMenu_Pick($iRow)
	If $iRow < 0 Or $iRow >= UBound($__g_aFluentMenuEnabled) Or Not $__g_aFluentMenuEnabled[$iRow] Then Return
	$__g_hFluentMenuPickTimer = TimerInit()
	Call($__g_sFluentMenuOnPick, $iRow)
	$__g_hFluentMenuPickTimer = TimerInit()
EndFunc   ;==>__FluentMenu_Pick


; Кнопка пункта переключает его состояние, окно остаётся открытым
Func __FluentMenu_Toggle($iRow)
	If $iRow < 0 Or Not IsBool($__g_aFluentMenuStates[$iRow]) Or Not $__g_aFluentMenuEnabled[$iRow] Then Return
	$__g_aFluentMenuStates[$iRow] = Not $__g_aFluentMenuStates[$iRow]
	__FluentMenu_Render()
	If $__g_sFluentMenuOnToggle <> '' Then Call($__g_sFluentMenuOnToggle, $iRow, $__g_aFluentMenuStates[$iRow])
EndFunc   ;==>__FluentMenu_Toggle


; Крестик убирает пункт, окно остаётся открытым
Func __FluentMenu_Remove($iRow)
	If $iRow < 0 Or Not IsBool($__g_aFluentMenuRemovable[$iRow]) Then Return
	_FluentMenu_DeleteItem($iRow)
	If $__g_sFluentMenuOnRemove <> '' Then Call($__g_sFluentMenuOnRemove, $iRow)
EndFunc   ;==>__FluentMenu_Remove


; Стрелка сортировки: пункт меняется местами с соседом, курсор едет за ним
Func __FluentMenu_Move($iRow, $iStep)
	If Not __FluentMenu_CanMove($iRow, $iStep) Then Return
	Local $iTo = $iRow + $iStep, $iOldY = __FluentMenu_RowScreenY($iRow)
	__FluentMenu_SwapIn($__g_aFluentMenuTexts, $iRow, $iTo)
	__FluentMenu_SwapIn($__g_aFluentMenuHints, $iRow, $iTo)
	__FluentMenu_SwapIn($__g_aFluentMenuIcons, $iRow, $iTo)
	__FluentMenu_SwapIn($__g_aFluentMenuStates, $iRow, $iTo)
	__FluentMenu_SwapIn($__g_aFluentMenuEnabled, $iRow, $iTo)
	__FluentMenu_SwapIn($__g_aFluentMenuRemovable, $iRow, $iTo)
	__FluentMenu_SwapIn($__g_aFluentMenuMarked, $iRow, $iTo)
	Local $vValue
	For $j = 0 To 2
		$vValue = $__g_aFluentMenuSrc[$iRow][$j]
		$__g_aFluentMenuSrc[$iRow][$j] = $__g_aFluentMenuSrc[$iTo][$j]
		$__g_aFluentMenuSrc[$iTo][$j] = $vValue
	Next
	__FluentMenu_Follow($iTo, $iOldY)
	Call($__g_sFluentMenuOnMove, $iRow, $iTo)
EndFunc   ;==>__FluentMenu_Move


; Стрелка «добавить»: копию пункта вставляет приложение
Func __FluentMenu_Add($iRow)
	If __FluentMenu_RowHasBtn($iRow, 5) And __FluentMenu_BtnEnabled($iRow, 5) Then Call($__g_sFluentMenuOnAdd, $iRow)
EndFunc   ;==>__FluentMenu_Add


Func __FluentMenu_Close()
	$__g_bFluentMenuDone = True
EndFunc   ;==>__FluentMenu_Close


Func __FluentMenu_Events($bOn)
	Local $aMsgs[6] = [$WM_MOUSEMOVE, $WM_LBUTTONDOWN, $WM_LBUTTONUP, $WM_RBUTTONDOWN, $WM_RBUTTONUP, $WM_ACTIVATE]
	Local $aFuncs[6] = ['__FluentMenu_WmMouseMove', '__FluentMenu_WmButtonDown', '__FluentMenu_WmButtonUp', '__FluentMenu_WmButtonDown', _
			'__FluentMenu_WmButtonUp', '__FluentMenu_WmActivate']
	For $i = 0 To UBound($aMsgs) - 1
		If $bOn Then
			_FluentMsg_Register($aMsgs[$i], $aFuncs[$i])
		Else
			_FluentMsg_Unregister($aMsgs[$i], $aFuncs[$i])
		EndIf
	Next
	If $bOn And $__g_sFluentMenuPanelCreate <> '' Then
		_FluentMsg_Register($WM_COMMAND, '__FluentMenu_WmCommand')
	Else
		_FluentMsg_Unregister($WM_COMMAND, '__FluentMenu_WmCommand')
	EndIf
	If Not $bOn Then Return

	GUISetOnEvent($GUI_EVENT_CLOSE, '__FluentMenu_Close', $__g_hFluentMenuGui)
	Local $aAccel[UBound($__g_aFluentMenuKeys)][2]
	For $i = 0 To UBound($__g_aFluentMenuKeys) - 1
		$__g_aFluentMenuKeys[$i][0] = GUICtrlCreateDummy()
		GUICtrlSetOnEvent($__g_aFluentMenuKeys[$i][0], '__FluentMenu_OnKey')
		$aAccel[$i][0] = $__g_aFluentMenuKeys[$i][1]
		$aAccel[$i][1] = $__g_aFluentMenuKeys[$i][0]
	Next
	GUISetAccelerators($aAccel, $__g_hFluentMenuGui)
EndFunc   ;==>__FluentMenu_Events


Func __FluentMenu_OnKey()
	Local $sKey = ''
	For $i = 0 To UBound($__g_aFluentMenuKeys) - 1
		If $__g_aFluentMenuKeys[$i][0] = @GUI_CtrlId Then $sKey = $__g_aFluentMenuKeys[$i][1]
	Next

	If __FluentMenu_EditKey($sKey) Then Return

	; Enter с Ctrl выбирает тот же пункт, что Enter, но окно не закрывает
	If $sKey = '^{ENTER}' Then
		$sKey = '{ENTER}'
		If $__g_sFluentMenuOnPick <> '' Then
			Local $iRow = $__g_iFluentMenuHot
			If $__g_iFluentMenuLive And ($iRow < 0 Or $__g_bFluentMenuHotMouse) Then $iRow = UBound($__g_aFluentMenuTexts) - 1
			$__g_iFluentMenuPendingRow = $iRow
			$__g_iFluentMenuPendingBtn = 6
			Return
		EndIf
	EndIf

	; Строки по кругу, как в меню; недоступные пропускаются
	Local $iRows = UBound($__g_aFluentMenuTexts)
	If $iRows = 0 And $sKey <> '{ENTER}' Then Return
	Switch $sKey
		Case '{UP}'
			__FluentMenu_SetHot(__FluentMenu_NextRow($__g_iFluentMenuHot < 0 ? 0 : $__g_iFluentMenuHot, -1), False)
		Case '{DOWN}'
			__FluentMenu_SetHot(__FluentMenu_NextRow($__g_iFluentMenuHot < 0 ? -1 : $__g_iFluentMenuHot, 1), False)
		Case '{HOME}'
			__FluentMenu_SetHot(__FluentMenu_NextRow(-1, 1), False)
		Case '{END}'
			__FluentMenu_SetHot(__FluentMenu_NextRow($iRows, -1), False)
		Case '{ENTER}'
			; С панелью пункт под мышью Enter не выбирает: мышь просто лежит над списком
			If $__g_sFluentMenuPanelEnter <> '' And ($__g_iFluentMenuHot < 0 Or $__g_bFluentMenuHotMouse) Then
				Call($__g_sFluentMenuPanelEnter)
			Else
				__FluentMenu_Activate($__g_iFluentMenuHot)
			EndIf
		Case '{SPACE}'
			__FluentMenu_Toggle($__g_iFluentMenuHot)
	EndSwitch
EndFunc   ;==>__FluentMenu_OnKey


; Home, End и пробел окно перехватывает клавишами-ускорителями. В поле ввода панели
; они делают то же, что и без окна: каретка в начало, в конец, пробел в текст
Func __FluentMenu_EditKey($sKey)
	If $sKey <> '{HOME}' And $sKey <> '{END}' And $sKey <> '{SPACE}' Then Return False
	Local $hFocus = _WinAPI_GetFocus()
	If Not $hFocus Or _WinAPI_GetClassName($hFocus) <> 'Edit' Then Return False
	; В поле только для цифр пробелу не место
	If $sKey = '{SPACE}' And BitAND(_WinAPI_GetWindowLong($hFocus, $GWL_STYLE), $ES_NUMBER) Then Return True
	Switch $sKey
		Case '{HOME}'
			_SendMessage($hFocus, $EM_SETSEL, 0, 0)
		Case '{END}'
			Local $iLen = _SendMessage($hFocus, $WM_GETTEXTLENGTH)
			_SendMessage($hFocus, $EM_SETSEL, $iLen, $iLen)
		Case '{SPACE}'
			_SendMessage($hFocus, $EM_REPLACESEL, True, ' ', 0, 'wparam', 'wstr')
	EndSwitch
	Return True
EndFunc   ;==>__FluentMenu_EditKey


; Ввод в поле панели гасит подсветку стрелками: Enter после него – панели
Func __FluentMenu_WmCommand($hWnd, $iMsg, $wParam, $lParam)
	#forceref $iMsg, $lParam
	If $hWnd <> $__g_hFluentMenuGui Then Return $GUI_RUNDEFMSG
	If BitAND(BitShift($wParam, 16), 0xFFFF) = $EN_CHANGE And $__g_iFluentMenuHot >= 0 And Not $__g_bFluentMenuHotMouse Then _
			__FluentMenu_SetHot(-1, False)
	Return $GUI_RUNDEFMSG
EndFunc   ;==>__FluentMenu_WmCommand


Func __FluentMenu_WmMouseMove($hWnd, $iMsg, $wParam, $lParam)
	#forceref $iMsg, $wParam, $lParam
	If $hWnd <> $__g_hFluentMenuGui Then Return $GUI_RUNDEFMSG
	Local $tPoint = DllStructCreate($tagPOINT)
	DllCall('user32.dll', 'bool', 'GetCursorPos', 'struct*', $tPoint)
	If $tPoint.X = $__g_iFluentMenuLastX And $tPoint.Y = $__g_iFluentMenuLastY Then Return $GUI_RUNDEFMSG
	$__g_iFluentMenuLastX = $tPoint.X
	$__g_iFluentMenuLastY = $tPoint.Y
	_WinAPI_ScreenToClient($__g_hFluentMenuGui, $tPoint)
	Local $iRow = __FluentMenu_HitTest($tPoint.X, $tPoint.Y)
	__FluentMenu_SetHot($iRow, True, __FluentMenu_HitBtn($iRow, $tPoint.X, $tPoint.Y))
	Return $GUI_RUNDEFMSG
EndFunc   ;==>__FluentMenu_WmMouseMove


; Выбор по отпусканию кнопки, как в меню, и только если нажали в окне:
; отпускание от клика, который открыл окно, не считается. Нажатая строка видна сразу.
; Левая кнопка с Shift тащит окно: перетаскивание ждёт главного цикла
Func __FluentMenu_WmButtonDown($hWnd, $iMsg, $wParam, $lParam)
	Local Const $MK_SHIFT = 0x0004
	If $hWnd <> $__g_hFluentMenuGui Then Return $GUI_RUNDEFMSG
	If $iMsg = $WM_LBUTTONDOWN And BitAND($wParam, $MK_SHIFT) Then
		$__g_iFluentMenuPendingBtn = 7
		Return $GUI_RUNDEFMSG
	EndIf
	Local $iX = __FluentMenu_LoWord($lParam), $iY = __FluentMenu_LoWord(BitShift($lParam, 16))
	$__g_bFluentMenuPressed = True
	$__g_iFluentMenuPressRow = __FluentMenu_HitTest($iX, $iY)
	$__g_iFluentMenuPressBtn = __FluentMenu_HitBtn($__g_iFluentMenuPressRow, $iX, $iY)
	If $__g_iFluentMenuPressRow >= 0 And Not $__g_iFluentMenuPressBtn Then __FluentMenu_Render()
	Return $GUI_RUNDEFMSG
EndFunc   ;==>__FluentMenu_WmButtonDown


; Кнопка срабатывает, только если на ней и нажали, и отпустили;
; остальная строка выбирает пункт, как в меню. С Ctrl - без закрытия окна
Func __FluentMenu_WmButtonUp($hWnd, $iMsg, $wParam, $lParam)
	#forceref $iMsg
	Local Const $MK_CONTROL = 0x0008
	If $hWnd <> $__g_hFluentMenuGui Or Not $__g_bFluentMenuPressed Then Return $GUI_RUNDEFMSG
	$__g_bFluentMenuPressed = False
	; Нажатая строка снова как под курсором
	If $__g_iFluentMenuPressRow >= 0 And Not $__g_iFluentMenuPressBtn Then __FluentMenu_Render()
	Local $iX = __FluentMenu_LoWord($lParam), $iY = __FluentMenu_LoWord(BitShift($lParam, 16))
	Local $iRow = __FluentMenu_HitTest($iX, $iY), $iBtn = __FluentMenu_HitBtn($iRow, $iX, $iY)
	If $__g_iFluentMenuPressBtn Then
		If $iBtn = $__g_iFluentMenuPressBtn And $iRow = $__g_iFluentMenuPressRow Then
			$__g_iFluentMenuPendingRow = $iRow
			$__g_iFluentMenuPendingBtn = $iBtn
		EndIf
	ElseIf Not $iBtn Then
		If $__g_sFluentMenuOnPick <> '' And BitAND($wParam, $MK_CONTROL) Then
			; Обработчик приложения ждёт главного цикла, как и кнопки
			$__g_iFluentMenuPendingRow = $iRow
			$__g_iFluentMenuPendingBtn = 6
		Else
			__FluentMenu_Activate($iRow)
		EndIf
	EndIf
	Return $GUI_RUNDEFMSG
EndFunc   ;==>__FluentMenu_WmButtonUp


; Клик в любое другое место забирает у окна активность – окно закрывается. Активность
; без нажатой кнопки мыши вскоре после выбора без закрытия забрало окно, которое выбор
; поднял: меню возвращает её себе
Func __FluentMenu_WmActivate($hWnd, $iMsg, $wParam, $lParam)
	#forceref $iMsg, $lParam
	If $hWnd <> $__g_hFluentMenuGui Then Return $GUI_RUNDEFMSG
	If BitAND($wParam, 0xFFFF) = 0 Then ; WA_INACTIVE
		If $__g_hFluentMenuPickTimer And TimerDiff($__g_hFluentMenuPickTimer) < 5000 And Not __FluentMenu_MouseDown() Then
			$__g_bFluentMenuRefocus = True
		Else
			$__g_bFluentMenuDone = True
		EndIf
	Else
		$__g_bFluentMenuWasActive = True
	EndIf
	Return $GUI_RUNDEFMSG
EndFunc   ;==>__FluentMenu_WmActivate


; Опрос между сообщениями: здесь срабатывают нажатые кнопки пунктов. Курсор ушёл
; из окна – подсветка мыши гаснет. Если система не дала окну стать активным,
; WM_ACTIVATE не придёт, и клик мимо окна ловится по состоянию кнопок
Func __FluentMenu_Poll()
	Local $iBtn = $__g_iFluentMenuPendingBtn
	$__g_iFluentMenuPendingBtn = 0
	Switch $iBtn
		Case 1
			__FluentMenu_Toggle($__g_iFluentMenuPendingRow)
		Case 2
			__FluentMenu_Remove($__g_iFluentMenuPendingRow)

		Case 3, 4
			__FluentMenu_Move($__g_iFluentMenuPendingRow, $iBtn = 3 ? -1 : 1)
		Case 5
			__FluentMenu_Add($__g_iFluentMenuPendingRow)
		Case 6
			__FluentMenu_Pick($__g_iFluentMenuPendingRow)
		Case 7
			__FluentMenu_Drag()
	EndSwitch
	If $__g_bFluentMenuRefocus And Not $__g_bFluentMenuDone Then
		$__g_bFluentMenuRefocus = False
		WinActivate($__g_hFluentMenuGui)
	EndIf


	Local $tPoint = DllStructCreate($tagPOINT)
	DllCall('user32.dll', 'bool', 'GetCursorPos', 'struct*', $tPoint)
	Local $aPos = WinGetPos($__g_hFluentMenuGui)
	If Not IsArray($aPos) Then Return
	Local $bInside = $tPoint.X >= $aPos[0] And $tPoint.X < $aPos[0] + $aPos[2] And _
			$tPoint.Y >= $aPos[1] And $tPoint.Y < $aPos[1] + $aPos[3]

	If Not $bInside And $__g_bFluentMenuHotMouse And $__g_iFluentMenuHot >= 0 Then __FluentMenu_SetHot(-1, True)
	If $__g_bFluentMenuWasActive Or $bInside Then Return
	If __FluentMenu_MouseDown() Then $__g_bFluentMenuDone = True
EndFunc   ;==>__FluentMenu_Poll


; Shift и кнопка мыши: окно тащит система, как за заголовок. SC_MOVE | HTCAPTION -
; модальный цикл перетаскивания, он кончается, когда кнопку отпустили
Func __FluentMenu_Drag()
	If Not __FluentMenu_MouseDown() Then Return
	DllCall('user32.dll', 'bool', 'ReleaseCapture')
	_SendMessage($__g_hFluentMenuGui, $WM_SYSCOMMAND, 0xF012, 0) ; SC_MOVE | HTCAPTION
	; Курсор после перетаскивания над другой строкой
	$__g_iFluentMenuLastX = -1
	$__g_iFluentMenuLastY = -1
EndFunc   ;==>__FluentMenu_Drag


; Нажата ли сейчас кнопка мыши: левая, правая или средняя
Func __FluentMenu_MouseDown()
	Local Static $aButtons[3] = [1, 2, 4] ; VK_LBUTTON, VK_RBUTTON, VK_MBUTTON
	Local $aState
	For $iKey In $aButtons
		$aState = DllCall('user32.dll', 'short', 'GetAsyncKeyState', 'int', $iKey)
		If Not @error And BitAND($aState[0], 0x8000) Then Return True
	Next
	Return False
EndFunc   ;==>__FluentMenu_MouseDown


; Знаковая координата из младших 16 бит lParam
Func __FluentMenu_LoWord($iValue)
	$iValue = BitAND($iValue, 0xFFFF)
	Return $iValue > 0x7FFF ? $iValue - 0x10000 : $iValue
EndFunc   ;==>__FluentMenu_LoWord


Func __FluentMenu_Free()
	For $hIcon In $__g_aFluentMenuIcons
		If $hIcon Then _GDIPlus_BitmapDispose($hIcon)
	Next
	ReDim $__g_aFluentMenuIcons[0]
	If $__g_hFluentMenuPicBmp Then _WinAPI_DeleteObject($__g_hFluentMenuPicBmp)
	$__g_hFluentMenuPicBmp = 0
	If $__g_hFluentMenuSysFont Then _GDIPlus_FontDispose($__g_hFluentMenuSysFont)
	If $__g_hFluentMenuSysFamily Then _GDIPlus_FontFamilyDispose($__g_hFluentMenuSysFamily)
	$__g_hFluentMenuSysFont = 0
	$__g_hFluentMenuSysFamily = 0
EndFunc   ;==>__FluentMenu_Free


; Шрифт меню из системы: NONCLIENTMETRICSW.lfMenuFont. Размер в пикселях как у GDI,
; поэтому масштаб и настройки шрифта Windows переходят в окно без пересчёта
Func __FluentMenu_FontCreate()
	; LOGFONTW занимает 92 байта, до lfMenuFont пять полей, два шрифта и две пары метрик
	Local $tNcm = DllStructCreate('uint Size;int Metrics[5];byte CaptionFont[92];int SmCaption[2];byte SmCaptionFont[92];' & _
			'int Menu[2];long Height;long Width;long Escapement;long Orientation;long Weight;byte Italic;byte Underline;' & _
			'byte StrikeOut;byte CharSet;byte OutPrecision;byte ClipPrecision;byte Quality;byte Pitch;wchar Face[32];' & _
			'byte StatusFont[92];byte MessageFont[92];int PaddedBorder')
	$tNcm.Size = DllStructGetSize($tNcm)
	Local $aRet = DllCall('user32.dll', 'bool', 'SystemParametersInfoW', 'uint', 0x0029, 'uint', $tNcm.Size, _
			'struct*', $tNcm, 'uint', 0) ; SPI_GETNONCLIENTMETRICS
	If @error Or Not $aRet[0] Or $tNcm.Face = '' Or $tNcm.Height = 0 Then Return

	$__g_hFluentMenuSysFamily = _GDIPlus_FontFamilyCreate($tNcm.Face)
	If @error Or Not $__g_hFluentMenuSysFamily Then
		$__g_hFluentMenuSysFamily = 0
		Return
	EndIf
	; Стиль GDI+: 1 – жирный, 2 – курсив. Единица 2 – пиксель: lfHeight < 0 и есть кегль в пикселях
	Local $iStyle = ($tNcm.Weight >= 600 ? 1 : 0) + ($tNcm.Italic ? 2 : 0)
	$__g_hFluentMenuSysFont = _GDIPlus_FontCreate($__g_hFluentMenuSysFamily, Abs($tNcm.Height), $iStyle, 2)
EndFunc   ;==>__FluentMenu_FontCreate


Func __FluentMenu_Font()
	Return $__g_hFluentMenuSysFont ? $__g_hFluentMenuSysFont : _FluentFont()
EndFunc   ;==>__FluentMenu_Font
