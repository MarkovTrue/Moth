#include-once

#include <FileConstants.au3>
#include <StringConstants.au3>

; #INDEX# =======================================================================================================================
; Title .........: LangFile
; AutoIt Version : 3.3.18.0
; Language ......: Русский
; Description ...: Языковые файлы программ MarkovTrue (Moth, VCLauncher).
;                  Формат INI: [Секция] и строки Ключ=Текст, файл в UTF-8 с BOM или без.
;                  Весь файл читается один раз в Map: IniRead на каждую строку медленный
;                  и портит кириллицу в файлах без BOM.
;                  В тексте \n превращается в перевод строки, %1..%3 - места для подстановки.
; Author(s) .....: MarkovTrue
; ===============================================================================================================================

; #CURRENT# =====================================================================================================================
; _LangFile_Load
; _LangFile_Get
; _LangFile_Format
; _LangFile_Resolve
; _LangFile_SystemLanguage
; _LangFile_List
; _LangFile_Current
; ===============================================================================================================================

Global $__g_mLangFile[]
Global $__g_sLangFileName = ''


; Загружает языковой файл целиком. Прежние строки сбрасываются.
; @error: 1 - файла нет, 2 - файл не открылся.
Func _LangFile_Load($sPath)
	Local $mEmpty[]
	$__g_mLangFile = $mEmpty
	$__g_sLangFileName = ''
	If Not FileExists($sPath) Then Return SetError(1, 0, False)

	; FO_UTF8_NOBOM при чтении пропускает BOM, если он есть
	Local $hFile = FileOpen($sPath, $FO_UTF8_NOBOM)
	If $hFile = -1 Then Return SetError(2, 0, False)
	Local $sContent = FileRead($hFile)
	FileClose($hFile)

	Local $aLines = StringSplit(StringStripCR($sContent), @LF)
	Local $sSection = '', $sLine, $iEq
	For $i = 1 To $aLines[0]
		$sLine = StringStripWS($aLines[$i], $STR_STRIPLEADING + $STR_STRIPTRAILING)
		If $sLine = '' Or StringLeft($sLine, 1) = ';' Then ContinueLoop
		If StringLeft($sLine, 1) = '[' And StringRight($sLine, 1) = ']' Then
			$sSection = StringMid($sLine, 2, StringLen($sLine) - 2)
			ContinueLoop
		EndIf
		$iEq = StringInStr($sLine, '=')
		If $iEq = 0 Or $sSection = '' Then ContinueLoop
		$__g_mLangFile[$sSection & '.' & StringStripWS(StringLeft($sLine, $iEq - 1), $STR_STRIPTRAILING)] = _
				StringReplace(StringMid($sLine, $iEq + 1), '\n', @CRLF)
	Next

	$__g_sLangFileName = StringRegExpReplace($sPath, '^.*\\|\.[^.]*$', '')
	Return True
EndFunc   ;==>_LangFile_Load


; Строка из загруженного файла или $sDefault, если ключа нет
Func _LangFile_Get($sSection, $sKey, $sDefault = '')
	Local $sFullKey = $sSection & '.' & $sKey
	If MapExists($__g_mLangFile, $sFullKey) Then Return $__g_mLangFile[$sFullKey]
	Return $sDefault
EndFunc   ;==>_LangFile_Get


; Строка с подстановкой: %1..%3 заменяются аргументами по порядку
Func _LangFile_Format($sSection, $sKey, $sDefault, $v1 = '', $v2 = '', $v3 = '')
	Local $sText = _LangFile_Get($sSection, $sKey, $sDefault)
	Local $aArgs[3] = [$v1, $v2, $v3]
	For $i = @NumParams - 3 To 1 Step -1
		$sText = StringReplace($sText, '%' & $i, $aArgs[$i - 1])
	Next
	Return $sText
EndFunc   ;==>_LangFile_Format


; Путь к языковому файлу: выбранный язык, иначе язык системы, иначе English.
; Пустой $sLanguage - язык системы.
Func _LangFile_Resolve($sDir, $sLanguage = '')
	If $sLanguage = '' Then $sLanguage = _LangFile_SystemLanguage()
	Local $sPath = $sDir & '\' & $sLanguage & '.lng'
	If FileExists($sPath) Then Return $sPath
	Return $sDir & '\English.lng'
EndFunc   ;==>_LangFile_Resolve


; Язык интерфейса Windows: русский и украинский получают Russian, остальные English
Func _LangFile_SystemLanguage()
	Switch @OSLang
		Case '0419', '0422'
			Return 'Russian'
	EndSwitch
	Return 'English'
EndFunc   ;==>_LangFile_SystemLanguage


; Имена доступных языков (по файлам *.lng), нулевой элемент - количество
Func _LangFile_List($sDir)
	Local $aList[1] = [0]
	Local $hSearch = FileFindFirstFile($sDir & '\*.lng')
	If $hSearch = -1 Then Return $aList
	Local $sFile
	While 1
		$sFile = FileFindNextFile($hSearch)
		If @error Then ExitLoop
		ReDim $aList[$aList[0] + 2]
		$aList[0] += 1
		$aList[$aList[0]] = StringTrimRight($sFile, 4)
	WEnd
	FileClose($hSearch)
	Return $aList
EndFunc   ;==>_LangFile_List


; Имя загруженного языка (имя файла без расширения) или ''
Func _LangFile_Current()
	Return $__g_sLangFileName
EndFunc   ;==>_LangFile_Current
