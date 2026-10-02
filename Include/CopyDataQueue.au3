#include-once

#include <APISysConstants.au3>
#include <Misc.au3>
#include <StringConstants.au3>
#include <WindowsConstants.au3>

; ============================================================
; CopyDataQueue – очередь строк между процессами через WM_COPYDATA
; ============================================================
; Приёмник – единственный экземпляр программы со скрытым окном; отправители (другие
; процессы) шлют ему строки. Сообщение - текст UTF-16: первая строка - id отправки,
; дальше строки через @LF. Приёмник кладёт текст в очередь и только тогда отвечает
; $gc_iCopyDataQueueAck. Любой другой ответ, таймаут или отсутствие окна - повтор.
; Повтор с тем же id приёмник подтверждает, но второй раз не ставит: подтверждение
; могло потеряться уже после приёма. Приёмник занимает GUIRegisterMsg(WM_COPYDATA).
;
; Приёмник: _CopyDataQueue_Singleton (или _Listen) → _Take из основного цикла → _Close.
; Отправитель: _CopyDataQueue_Send(заголовок, строки, команда запуска приёмника).
; Заголовок окна-приёмника задаёт приложение: он должен быть уникальным.

; dwData 'CDQ1' и ответ «принято» 'cdqk': чужое окно с тем же заголовком их не вернёт
Global Const $gc_iCopyDataQueueMagic = 0x43445131
Global Const $gc_iCopyDataQueueAck = 0x6364716B
; Символов в одном сообщении (пачка режется по строкам) и предел приёма в байтах
Global Const $gc_iCopyDataQueueChunk = 32768
Global Const $gc_iCopyDataQueueMaxBytes = 4194304
; Сколько отправитель пытается доставить и сколько ждёт окно запущенного приёмника, мс
Global Const $gc_iCopyDataQueueSendMs = 60000
Global Const $gc_iCopyDataQueueStartMs = 20000
Global Const $__tagCOPYDATAQUEUE_CDS = 'ulong_ptr dwData;dword cbData;ptr lpData'

; Приёмник. Обработчик WM_COPYDATA вклинивается между любыми строками основного кода,
; поэтому очередь без блокировок: обработчик пишет с $__g_iCopyDataQueueIn,
; _CopyDataQueue_Take читает с $__g_iCopyDataQueueOut
Global $__g_hCopyDataQueueWnd = 0, $__g_bCopyDataQueueOpen = False
Global $__g_aCopyDataQueueInbox[256], $__g_iCopyDataQueueIn = 0, $__g_iCopyDataQueueOut = 0
; id принятых сообщений
Global $__g_oCopyDataQueueSeen[]
; Отправитель: метка процесса для id и номер сообщения
Global $__g_sCopyDataQueueSender = '', $__g_iCopyDataQueueSeq = 0


; ============================================================
; Приёмник
; ============================================================

; Становится единственным экземпляром и открывает окно-приёмник. False - другой экземпляр
; принимает сам. Экземпляр без окна (ещё запускается или уже закрывается) дожидается:
; иначе строки ушли бы процессу, который вот-вот выйдет
Func _CopyDataQueue_Singleton($sMutex, $sTitle)
	Local $hTimer = TimerInit()
	While Not _Singleton($sMutex, 1)
		If _CopyDataQueue_Window($sTitle) Or TimerDiff($hTimer) > $gc_iCopyDataQueueStartMs Then Return False
		Sleep(50)
	WEnd
	_CopyDataQueue_Listen($sTitle)
	Return True
EndFunc   ;==>_CopyDataQueue_Singleton


; Скрытое окно-приёмник. Текущим GUI становится оно: основное окно создавать после
Func _CopyDataQueue_Listen($sTitle)
	$__g_hCopyDataQueueWnd = GUICreate($sTitle)
	; MSGFLT_ALLOW = 1: WM_COPYDATA и от процесса с меньшими правами (UIPI)
	DllCall('user32.dll', 'bool', 'ChangeWindowMessageFilterEx', 'hwnd', $__g_hCopyDataQueueWnd, 'uint', $WM_COPYDATA, 'dword', 1, 'ptr', 0)
	GUIRegisterMsg($WM_COPYDATA, '__CopyDataQueue_WmCopyData')
	$__g_bCopyDataQueueOpen = True
EndFunc   ;==>_CopyDataQueue_Listen


; Закрывает приём: новые сообщения получают отказ, окно исчезает, и отправители запускают
; новый экземпляр, а не ждут этот. $bIfIdle - не закрывать, если в очереди есть непрочитанное.
; True - закрыто
Func _CopyDataQueue_Close($bIfIdle = False)
	; Сначала отказ, потом проверка: сообщение, принятое между ними, иначе пропало бы
	$__g_bCopyDataQueueOpen = False
	If $bIfIdle And _CopyDataQueue_Pending() Then
		$__g_bCopyDataQueueOpen = True
		Return False
	EndIf
	If $__g_hCopyDataQueueWnd Then GUIDelete($__g_hCopyDataQueueWnd)
	$__g_hCopyDataQueueWnd = 0
	Return True
EndFunc   ;==>_CopyDataQueue_Close


Func _CopyDataQueue_Pending()
	Return $__g_iCopyDataQueueOut < $__g_iCopyDataQueueIn
EndFunc   ;==>_CopyDataQueue_Pending


; Строки принятых сообщений без id, пустые отброшены. Вызывать из основного кода
Func _CopyDataQueue_Take()
	; Только пришедшее к вызову: при сплошном потоке цикл иначе не отпустил бы вызывающего.
	; Число, а не индекс конца: обработчик сдвигает очередь
	Local $sText, $sAll = '', $iTake = $__g_iCopyDataQueueIn - $__g_iCopyDataQueueOut
	While $iTake > 0 And $__g_iCopyDataQueueOut < $__g_iCopyDataQueueIn
		$iTake -= 1
		$sText = $__g_aCopyDataQueueInbox[$__g_iCopyDataQueueOut]
		$__g_aCopyDataQueueInbox[$__g_iCopyDataQueueOut] = ''
		; Слот освобождается последней строкой: до неё обработчик его не перепишет
		$__g_iCopyDataQueueOut += 1
		$sAll &= StringMid($sText, StringInStr($sText, @LF) + 1) & @LF
	WEnd
	Local $aLines = StringRegExp($sAll, '[^\n]+', $STR_REGEXPARRAYGLOBALMATCH)
	If @error Then
		Local $aNone[0]
		Return $aNone
	EndIf
	Return $aLines
EndFunc   ;==>_CopyDataQueue_Take


; Только копирует текст в очередь: разбор долгий, и отправитель ждал бы его
Func __CopyDataQueue_WmCopyData($hWnd, $iMsg, $wParam, $lParam)
	#forceref $iMsg, $wParam
	If $hWnd <> $__g_hCopyDataQueueWnd Or Not $__g_bCopyDataQueueOpen Then Return 0
	Local $tCDS = DllStructCreate($__tagCOPYDATAQUEUE_CDS, $lParam)
	Local $iBytes = $tCDS.cbData
	If $tCDS.dwData <> $gc_iCopyDataQueueMagic Or $iBytes < 4 Or $iBytes > $gc_iCopyDataQueueMaxBytes Or Mod($iBytes, 2) Then Return 0
	Local $sText = DllStructGetData(DllStructCreate('wchar[' & $iBytes / 2 & ']', $tCDS.lpData), 1)
	Local $iEol = StringInStr($sText, @LF)
	If $iEol < 2 Then Return 0

	Local $sId = StringLeft($sText, $iEol - 1)
	If MapExists($__g_oCopyDataQueueSeen, $sId) Then Return $gc_iCopyDataQueueAck
	$__g_oCopyDataQueueSeen[$sId] = True

	; Очередь не растёт при непрерывном потоке: прочитанное в начале освобождается.
	; _CopyDataQueue_Take держит только глобальный индекс, поэтому сдвиг ему не мешает
	If $__g_iCopyDataQueueOut = $__g_iCopyDataQueueIn Then
		$__g_iCopyDataQueueOut = 0
		$__g_iCopyDataQueueIn = 0
	ElseIf $__g_iCopyDataQueueIn >= UBound($__g_aCopyDataQueueInbox) And $__g_iCopyDataQueueOut >= UBound($__g_aCopyDataQueueInbox) / 2 Then
		For $i = $__g_iCopyDataQueueOut To $__g_iCopyDataQueueIn - 1
			$__g_aCopyDataQueueInbox[$i - $__g_iCopyDataQueueOut] = $__g_aCopyDataQueueInbox[$i]
			$__g_aCopyDataQueueInbox[$i] = ''
		Next
		$__g_iCopyDataQueueIn -= $__g_iCopyDataQueueOut
		$__g_iCopyDataQueueOut = 0
	EndIf
	If $__g_iCopyDataQueueIn >= UBound($__g_aCopyDataQueueInbox) Then ReDim $__g_aCopyDataQueueInbox[$__g_iCopyDataQueueIn * 2]
	$__g_aCopyDataQueueInbox[$__g_iCopyDataQueueIn] = $sText
	$__g_iCopyDataQueueIn += 1
	Return $gc_iCopyDataQueueAck
EndFunc   ;==>__CopyDataQueue_WmCopyData


; ============================================================
; Отправитель
; ============================================================

; Окно-приёмник или 0. FindWindow сравнивает заголовок целиком, в отличие от WinGetHandle
Func _CopyDataQueue_Window($sTitle)
	Local $aRet = DllCall('user32.dll', 'hwnd', 'FindWindowW', 'wstr', 'AutoIt v3 GUI', 'wstr', $sTitle)
	If @error Then Return 0
	Return $aRet[0]
EndFunc   ;==>_CopyDataQueue_Window


; Доставляет строки ($sLines через @LF), режет их на сообщения по $gc_iCopyDataQueueChunk символов.
; $sStartCmd - командная строка приёмника, если его окна нет ('' - без окна сразу отказ).
; False - часть строк не доставлена, @extended - сколько доставлено
Func _CopyDataQueue_Send($sTitle, $sLines, $sStartCmd = '')
	Local $sChunk = '', $iChunk = 0, $iSent = 0
	For $sLine In StringSplit($sLines, @LF, $STR_NOCOUNT)
		If $sLine = '' Then ContinueLoop
		If $iChunk And StringLen($sChunk) + StringLen($sLine) >= $gc_iCopyDataQueueChunk Then
			If Not __CopyDataQueue_Deliver($sTitle, $sChunk, $sStartCmd) Then Return SetExtended($iSent, False)
			$iSent += $iChunk
			$sChunk = ''
			$iChunk = 0
		EndIf
		$sChunk &= $sLine & @LF
		$iChunk += 1
	Next
	If $iChunk And Not __CopyDataQueue_Deliver($sTitle, $sChunk, $sStartCmd) Then Return SetExtended($iSent, False)
	Return SetExtended($iSent + $iChunk, True)
EndFunc   ;==>_CopyDataQueue_Send


; Одно сообщение с повторами до $gc_iCopyDataQueueSendMs
Func __CopyDataQueue_Deliver($sTitle, $sText, $sStartCmd)
	; PID и отметка счётчика при первой отправке: PID освобождается и достаётся другим
	If $__g_sCopyDataQueueSender = '' Then $__g_sCopyDataQueueSender = @AutoItPID & '.' & TimerInit()
	$__g_iCopyDataQueueSeq += 1
	$sText = $__g_sCopyDataQueueSender & '.' & $__g_iCopyDataQueueSeq & @LF & $sText

	Local $tText = DllStructCreate('wchar[' & StringLen($sText) + 1 & ']')
	DllStructSetData($tText, 1, $sText)
	Local $tCDS = DllStructCreate($__tagCOPYDATAQUEUE_CDS)
	$tCDS.dwData = $gc_iCopyDataQueueMagic
	$tCDS.cbData = DllStructGetSize($tText)
	$tCDS.lpData = DllStructGetPtr($tText)

	Local $hTimer = TimerInit(), $hWnd, $aRet
	While TimerDiff($hTimer) < $gc_iCopyDataQueueSendMs
		$hWnd = _CopyDataQueue_Window($sTitle)
		If $hWnd Then
			; Живое окно ждём сколько нужно, зависшее или закрывшееся - нет
			$aRet = DllCall('user32.dll', 'lresult', 'SendMessageTimeoutW', _
					'hwnd',       $hWnd, _
					'uint',       $WM_COPYDATA, _
					'wparam',     0, _
					'struct*',    $tCDS, _
					'uint',       BitOR($SMTO_ABORTIFHUNG, $SMTO_NOTIMEOUTIFNOTHUNG, $SMTO_ERRORONEXIT), _
					'uint',       5000, _
					'dword_ptr*', 0)
			If Not @error And $aRet[0] And $aRet[7] = $gc_iCopyDataQueueAck Then Return True
		ElseIf $sStartCmd <> '' Then
			If Not __CopyDataQueue_Start($sTitle, $sStartCmd) Then Return False
			ContinueLoop
		Else
			; Запускать некому: приёмник закрылся, решает вызывающий
			Return False
		EndIf
		Sleep(50)
	WEnd
	Return False
EndFunc   ;==>__CopyDataQueue_Deliver


; Запускает приёмник, если его окна нет. Мьютекс: из сотен отправителей одного выделения
; запускает один, остальные дожидаются его окна. False - процесс не запустился
; или вышел, так и не открыв окно
Func __CopyDataQueue_Start($sTitle, $sStartCmd)
	Local Const $WAIT_TIMEOUT = 258, $WAIT_FAILED = 0xFFFFFFFF
	Local $aRet = DllCall('kernel32.dll', 'handle', 'CreateMutexW', 'ptr', 0, 'bool', False, 'wstr', $sTitle & '.Start')
	If @error Or Not $aRet[0] Then Return False
	Local $hMutex = $aRet[0]
	; WAIT_ABANDONED тоже отдаёт мьютекс: прежний держатель умер, не отпустив его
	$aRet = DllCall('kernel32.dll', 'dword', 'WaitForSingleObject', 'handle', $hMutex, 'dword', $gc_iCopyDataQueueStartMs + 5000)
	Local $bOwned = Not @error And $aRet[0] <> $WAIT_TIMEOUT And $aRet[0] <> $WAIT_FAILED

	If Not _CopyDataQueue_Window($sTitle) Then
		Local $iPid = Run($sStartCmd), $hTimer = TimerInit()
		While $iPid And Not _CopyDataQueue_Window($sTitle)
			If Not ProcessExists($iPid) Or TimerDiff($hTimer) > $gc_iCopyDataQueueStartMs Then ExitLoop
			Sleep(50)
		WEnd
	EndIf

	If $bOwned Then DllCall('kernel32.dll', 'bool', 'ReleaseMutex', 'handle', $hMutex)
	DllCall('kernel32.dll', 'bool', 'CloseHandle', 'handle', $hMutex)
	Return _CopyDataQueue_Window($sTitle) <> 0
EndFunc   ;==>__CopyDataQueue_Start
