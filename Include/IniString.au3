#include-once

#include <StringConstants.au3>

; #INDEX# =======================================================================================================================
; Title .........: IniString
; AutoIt Version : 3.3.18.0
; Language ......: Русский
; Description ...: INI-текст в строке: файл читает и пишет вызывающий код. Штатные IniRead/IniWrite
;                  читают UTF-8 как ANSI и портят кириллицу.
;                  Разбор как у IniRead: секции и ключи без учёта регистра, пробелы вокруг имён
;                  и значений отбрасываются, строки с ; - комментарии. Из повторов виден первый.
;                  Чтение идёт по индексу (Map), он строится один раз на текст. Кеш держит индексы
;                  двух последних текстов: программа обычно читает загруженный при старте ini
;                  и свежую копию с диска.
;                  Запись меняет одну строку, остальной текст с комментариями остаётся как был.
; Author(s) .....: MarkovTrue
; ===============================================================================================================================

; #CURRENT# =====================================================================================================================
; _IniString_Read
; _IniString_ReadSection
; _IniString_Write
; _IniString_Delete
; ===============================================================================================================================

; Кеш индексов: текст и его индекс в двух ячейках, $__g_iIniStringLast - ячейка последнего чтения
Global $__g_sIniStringText0 = '', $__g_sIniStringText1 = ''
Global $__g_mIniStringIndex0[], $__g_mIniStringIndex1[]
Global $__g_iIniStringLast = 0


; Значение ключа или $sDefault, если ключа или секции нет
Func _IniString_Read($sIni, $sSection, $sKey, $sDefault = '')
	Local $sId = StringLower(StringStripWS($sSection, $STR_STRIPLEADING + $STR_STRIPTRAILING)) & @LF & _
			StringLower(StringStripWS($sKey, $STR_STRIPLEADING + $STR_STRIPTRAILING))
	If __IniString_Slot($sIni) = 0 Then
		If MapExists($__g_mIniStringIndex0, $sId) Then Return $__g_mIniStringIndex0[$sId]
	ElseIf MapExists($__g_mIniStringIndex1, $sId) Then
		Return $__g_mIniStringIndex1[$sId]
	EndIf
	Return $sDefault
EndFunc   ;==>_IniString_Read


; Секция как у IniReadSection: [0][0] - число ключей, дальше [ключ, значение].
; Нет секции - тот же массив без ключей и @error = 1, так перебор не падает
Func _IniString_ReadSection($sIni, $sSection)
	Local $sId = Chr(1) & StringLower(StringStripWS($sSection, $STR_STRIPLEADING + $STR_STRIPTRAILING))
	If __IniString_Slot($sIni) = 0 Then
		If MapExists($__g_mIniStringIndex0, $sId) Then Return $__g_mIniStringIndex0[$sId]
	ElseIf MapExists($__g_mIniStringIndex1, $sId) Then
		Return $__g_mIniStringIndex1[$sId]
	EndIf
	Local $aEmpty[1][2] = [[0, '']]
	Return SetError(1, 0, $aEmpty)
EndFunc   ;==>_IniString_ReadSection


; Строка ключа меняется на месте: имя и пробелы до = остаются. Новый ключ встаёт после
; последнего ключа секции, а не перед комментарием следующей. Новая секция - в конец
Func _IniString_Write(ByRef $sIni, $sSection, $sKey, $sValue)
	$sSection = StringStripWS($sSection, $STR_STRIPLEADING + $STR_STRIPTRAILING)
	$sKey = StringStripWS($sKey, $STR_STRIPLEADING + $STR_STRIPTRAILING)
	Local $sEol = __IniString_Eol($sIni)
	Local $aLines = StringSplit($sIni, @LF)
	Local $aPos = __IniString_Find($aLines, $sSection, $sKey)
	Local $sLine

	If $aPos[1] Then
		$sLine = $aLines[$aPos[1]]
		$aLines[$aPos[1]] = StringLeft($sLine, StringInStr($sLine, '=')) & $sValue & (StringRight($sLine, 1) = @CR ? @CR : '')
	ElseIf $aPos[0] Then
		$sLine = $sKey & '=' & $sValue
		; Строка в середине текста уже кончается своим переводом строки, у последней его нет
		If $aPos[2] = $aLines[0] Then
			$aLines[$aPos[2]] &= $sEol & $sLine
		Else
			$aLines[$aPos[2]] &= @LF & $sLine & (StringRight($aLines[$aPos[2]], 1) = @CR ? @CR : '')
		EndIf
	Else
		$sIni = StringStripWS($sIni, $STR_STRIPTRAILING)
		If $sIni <> '' Then $sIni &= $sEol & $sEol
		$sIni &= '[' & $sSection & ']' & $sEol & $sKey & '=' & $sValue & $sEol
		Return 1
	EndIf

	$sIni = __IniString_Join($aLines)
	Return 1
EndFunc   ;==>_IniString_Write


; Удаляет ключ, с $sKey = Default - секцию от заголовка до последнего ключа: комментарий
; после него описывает следующую секцию. 1 - удалено, 0 - удалять нечего
Func _IniString_Delete(ByRef $sIni, $sSection, $sKey = Default)
	Local $aLines = StringSplit($sIni, @LF)
	Local $aPos = __IniString_Find($aLines, StringStripWS($sSection, $STR_STRIPLEADING + $STR_STRIPTRAILING), _
			IsKeyword($sKey) ? Chr(0) : StringStripWS($sKey, $STR_STRIPLEADING + $STR_STRIPTRAILING))
	If IsKeyword($sKey) Then
		If Not $aPos[0] Then Return 0
		$sIni = __IniString_Join($aLines, $aPos[0], $aPos[2])
	Else
		If Not $aPos[1] Then Return 0
		$sIni = __IniString_Join($aLines, $aPos[1], $aPos[1])
	EndIf
	Return 1
EndFunc   ;==>_IniString_Delete


; Ячейка кеша с индексом $sIni. Промах строит индекс в ячейке, которую дольше не читали.
; == сравнивает строки целиком с учётом регистра, на ini в 10 КБ это микросекунды
Func __IniString_Slot(ByRef $sIni)
	If $__g_sIniStringText0 == $sIni Then
		$__g_iIniStringLast = 0
	ElseIf $__g_sIniStringText1 == $sIni Then
		$__g_iIniStringLast = 1
	ElseIf $__g_iIniStringLast = 1 Then
		__IniString_Parse($sIni, $__g_mIniStringIndex0)
		$__g_sIniStringText0 = $sIni
		$__g_iIniStringLast = 0
	Else
		__IniString_Parse($sIni, $__g_mIniStringIndex1)
		$__g_sIniStringText1 = $sIni
		$__g_iIniStringLast = 1
	EndIf
	Return $__g_iIniStringLast
EndFunc   ;==>__IniString_Slot


; Индекс: значение - под 'секция' & @LF & 'ключ', секция массивом _IniString_ReadSection -
; под Chr(1) & 'секция'. Имена в нижнем регистре: Map различает регистр, INI нет
Func __IniString_Parse(ByRef $sIni, ByRef $mIndex)
	Local $mEmpty[]
	$mIndex = $mEmpty
	Local $aLines = StringSplit(StringStripCR($sIni), @LF)
	Local $aSection[16][2], $iCount = 0, $sId = '', $sLine, $sName, $iEq, $sKey, $sValue

	For $i = 1 To $aLines[0]
		$sLine = StringStripWS($aLines[$i], $STR_STRIPLEADING + $STR_STRIPTRAILING)
		If $sLine = '' Or StringLeft($sLine, 1) = ';' Then ContinueLoop

		$sName = __IniString_Header($sLine)
		If Not @error Then
			__IniString_Store($mIndex, $sId, $aSection, $iCount)
			$sId = StringLower($sName)
			; Повтор секции пропускается целиком: '' - строки вне секции
			If MapExists($mIndex, Chr(1) & $sId) Then $sId = ''
			$iCount = 0
			ContinueLoop
		EndIf

		$iEq = StringInStr($sLine, '=')
		If $sId = '' Or $iEq = 0 Then ContinueLoop
		$sKey = StringStripWS(StringLeft($sLine, $iEq - 1), $STR_STRIPTRAILING)
		$sValue = StringStripWS(StringMid($sLine, $iEq + 1), $STR_STRIPLEADING)
		If Not MapExists($mIndex, $sId & @LF & StringLower($sKey)) Then $mIndex[$sId & @LF & StringLower($sKey)] = $sValue

		$iCount += 1
		If $iCount = UBound($aSection) Then ReDim $aSection[$iCount * 2][2]
		$aSection[$iCount][0] = $sKey
		$aSection[$iCount][1] = $sValue
	Next
	__IniString_Store($mIndex, $sId, $aSection, $iCount)
EndFunc   ;==>__IniString_Parse


; Кладёт в индекс собранную секцию: первые $iCount строк $aSection
Func __IniString_Store(ByRef $mIndex, $sId, ByRef $aSection, $iCount)
	If $sId = '' Then Return
	Local $aOut[$iCount + 1][2]
	$aOut[0][0] = $iCount
	For $i = 1 To $iCount
		$aOut[$i][0] = $aSection[$i][0]
		$aOut[$i][1] = $aSection[$i][1]
	Next
	$mIndex[Chr(1) & $sId] = $aOut
EndFunc   ;==>__IniString_Store


; Имя секции из обрезанной строки '[Имя]', после ] может стоять комментарий. @error - не заголовок
Func __IniString_Header($sLine)
	Local $iEnd = StringInStr($sLine, ']')
	If StringLeft($sLine, 1) <> '[' Or $iEnd = 0 Then Return SetError(1, 0, '')
	Return StringStripWS(StringMid($sLine, 2, $iEnd - 2), $STR_STRIPLEADING + $STR_STRIPTRAILING)
EndFunc   ;==>__IniString_Header


; Номера строк $aLines (StringSplit по @LF): [заголовок секции, ключ, последний ключ секции
; или заголовок, если ключей нет]. 0 - не найдено, из повторов берётся первый
Func __IniString_Find(ByRef $aLines, $sSection, $sKey)
	Local $aPos[3] = [0, 0, 0], $sLine, $sName, $iEq
	For $i = 1 To $aLines[0]
		$sLine = StringStripWS($aLines[$i], $STR_STRIPLEADING + $STR_STRIPTRAILING)
		If $sLine = '' Or StringLeft($sLine, 1) = ';' Then ContinueLoop

		$sName = __IniString_Header($sLine)
		If Not @error Then
			If $aPos[0] Then ExitLoop
			If $sName = $sSection Then
				$aPos[0] = $i
				$aPos[2] = $i
			EndIf
			ContinueLoop
		EndIf

		$iEq = StringInStr($sLine, '=')
		If Not $aPos[0] Or $iEq = 0 Then ContinueLoop
		$aPos[2] = $i
		If Not $aPos[1] And StringStripWS(StringLeft($sLine, $iEq - 1), $STR_STRIPTRAILING) = $sKey Then $aPos[1] = $i
	Next
	Return $aPos
EndFunc   ;==>__IniString_Find


; Склеивает строки обратно, пропуская $iSkipFrom..$iSkipTo. Перевод строки после
; последней оставшейся строки остаётся только там, где он был
Func __IniString_Join(ByRef $aLines, $iSkipFrom = 0, $iSkipTo = -1)
	Local $sOut = '', $bFirst = True
	For $i = 1 To $aLines[0]
		If $i >= $iSkipFrom And $i <= $iSkipTo Then ContinueLoop
		If Not $bFirst Then $sOut &= @LF
		$sOut &= $aLines[$i]
		$bFirst = False
	Next
	; Убраны последние строки: @CR от бывшего CRLF повис в конце
	If $iSkipTo = $aLines[0] And StringRight($sOut, 1) = @CR Then $sOut = StringTrimRight($sOut, 1)
	Return $sOut
EndFunc   ;==>__IniString_Join


; Перевод строки для новых строк: LF, если в тексте только он, иначе CRLF
Func __IniString_Eol(ByRef $sIni)
	If StringInStr($sIni, @LF) And Not StringInStr($sIni, @CRLF) Then Return @LF
	Return @CRLF
EndFunc   ;==>__IniString_Eol
