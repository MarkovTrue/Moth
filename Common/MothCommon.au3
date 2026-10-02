#include-once

#include <Array.au3>
#include <FileConstants.au3>
#include <ProcessConstants.au3>

#include "MothConstants.au3"
#include "..\Include\CopyDataQueue.au3"
#include "..\Include\IniString.au3"
#include "..\Include\LangFile.au3"
#include "..\Include\UpdateCheck.au3"

Global Const _
		$FORMAT_AVIF = 'avif', _
		$FORMAT_BMP = 'bmp', _
		$FORMAT_GIF = 'gif', _
		$FORMAT_HEIC = 'heic', _
		$FORMAT_HEIF = 'heif', _
		$FORMAT_JFIF = 'jfif', _
		$FORMAT_JPE = 'jpe', _
		$FORMAT_JPEG = 'jpeg', _
		$FORMAT_JPG = 'jpg', _
		$FORMAT_JXL = 'jxl', _
		$FORMAT_PNG = 'png', _
		$FORMAT_WEBP = 'webp'

; $gc_sMothIni - содержимое Moth.ini, а не путь
Global Const _
		$gc_sAppVersion = '1.41', _ ; сравнивается с тегом релиза на GitHub
		$gc_sAppName = 'Moth ' & $gc_sAppVersion, _
		$gc_sMothIni = _ReadFileUTF8(@ScriptDir & '\Moth.ini'), _
		$gc_sTmpPath = @TempDir & '\Moth', _
		$gc_sImgPath = @TempDir & '\Moth\images', _
		$gc_bRegDarkTheme = _RegAppsUseDarkTheme()

Global Const $gc_aExtensionWhiteList = [ _
		$FORMAT_AVIF, _
		$FORMAT_BMP, _
		$FORMAT_GIF, _
		$FORMAT_HEIC & '.' & $FORMAT_HEIF, _
		$FORMAT_JFIF, _
		$FORMAT_JPG & '.' & $FORMAT_JPE & '.' & $FORMAT_JPEG, _
		$FORMAT_JXL, _
		$FORMAT_PNG, _
		$FORMAT_WEBP]

; Что с чем работает. Чего здесь нет, того формат не умеет или в этом нет смысла:
; AVIF и HEIC без потерь не пережимаются (утилиты меняют пиксели), у BMP нет сжатия
; с потерями. HEIC пишет только конвертация: heif-enc кодирует лишь с потерями.
; HEIF - тот же HEIC под другим расширением, поэтому в HEIC он не конвертируется.
; Палитра только там, где её можно сохранить без потерь: у JPEG и AVIF шум дизеринга
; раздувает файл, а в GIF и так не больше 256 цветов.
; Exif без потерь - у форматов, где он бывает: в GIF и BMP его нет.
Global Const _
		$SUPPORT_FORMATS_COMPRESSION_LOSSLESS = [$FORMAT_BMP, $FORMAT_GIF, $FORMAT_JFIF, $FORMAT_JPEG, $FORMAT_JPE, $FORMAT_JPG, $FORMAT_JXL, $FORMAT_PNG, $FORMAT_WEBP], _
		$SUPPORT_FORMATS_COMPRESSION_LOSSLESS_EXIF = [$FORMAT_JFIF, $FORMAT_JPEG, $FORMAT_JPE, $FORMAT_JPG, $FORMAT_JXL, $FORMAT_PNG, $FORMAT_WEBP], _
		$SUPPORT_FORMATS_COMPRESSION_LOSSY = [$FORMAT_AVIF, $FORMAT_GIF, $FORMAT_JFIF, $FORMAT_JPEG, $FORMAT_JPE, $FORMAT_JPG, $FORMAT_JXL, $FORMAT_PNG, $FORMAT_WEBP], _
		$SUPPORT_FORMATS_COMPRESSION_FOR_WEB = [$FORMAT_AVIF, $FORMAT_GIF, $FORMAT_JFIF, $FORMAT_JPEG, $FORMAT_JPE, $FORMAT_JPG, $FORMAT_JXL, $FORMAT_PNG, $FORMAT_WEBP], _
		$SUPPORT_FORMATS_COLOR_QUANTIZATION = [$FORMAT_JXL, $FORMAT_PNG, $FORMAT_WEBP], _
		$SUPPORT_FORMATS_RESIZE = [$FORMAT_AVIF, $FORMAT_BMP, $FORMAT_GIF, $FORMAT_JFIF, $FORMAT_JPEG, $FORMAT_JPE, $FORMAT_JPG, $FORMAT_JXL, $FORMAT_PNG, $FORMAT_WEBP], _
		$SUPPORT_FORMATS_CONVERT_TO_PNG = [$FORMAT_AVIF, $FORMAT_BMP, $FORMAT_GIF, $FORMAT_HEIC, $FORMAT_HEIF, $FORMAT_JFIF, $FORMAT_JPEG, $FORMAT_JPE, $FORMAT_JPG, $FORMAT_JXL, $FORMAT_WEBP], _
		$SUPPORT_FORMATS_CONVERT_TO_WEBP = [$FORMAT_AVIF, $FORMAT_BMP, $FORMAT_GIF, $FORMAT_HEIC, $FORMAT_HEIF, $FORMAT_JFIF, $FORMAT_JPEG, $FORMAT_JPE, $FORMAT_JPG, $FORMAT_JXL, $FORMAT_PNG], _
		$SUPPORT_FORMATS_CONVERT_TO_JPG = [$FORMAT_AVIF, $FORMAT_BMP, $FORMAT_GIF, $FORMAT_HEIC, $FORMAT_HEIF, $FORMAT_JFIF, $FORMAT_JXL, $FORMAT_PNG, $FORMAT_WEBP], _
		$SUPPORT_FORMATS_CONVERT_TO_JFIF = [$FORMAT_AVIF, $FORMAT_BMP, $FORMAT_GIF, $FORMAT_HEIC, $FORMAT_HEIF, $FORMAT_JPEG, $FORMAT_JPE, $FORMAT_JPG, $FORMAT_JXL, $FORMAT_PNG, $FORMAT_WEBP], _
		$SUPPORT_FORMATS_CONVERT_TO_JXL = [$FORMAT_AVIF, $FORMAT_BMP, $FORMAT_GIF, $FORMAT_HEIC, $FORMAT_HEIF, $FORMAT_JFIF, $FORMAT_JPEG, $FORMAT_JPE, $FORMAT_JPG, $FORMAT_PNG, $FORMAT_WEBP], _
		$SUPPORT_FORMATS_CONVERT_TO_AVIF = [$FORMAT_BMP, $FORMAT_GIF, $FORMAT_HEIC, $FORMAT_HEIF, $FORMAT_JFIF, $FORMAT_JPEG, $FORMAT_JPE, $FORMAT_JPG, $FORMAT_JXL, $FORMAT_PNG, $FORMAT_WEBP], _
		$SUPPORT_FORMATS_CONVERT_TO_HEIC = [$FORMAT_AVIF, $FORMAT_BMP, $FORMAT_GIF, $FORMAT_JFIF, $FORMAT_JPEG, $FORMAT_JPE, $FORMAT_JPG, $FORMAT_JXL, $FORMAT_PNG, $FORMAT_WEBP], _
		$SUPPORT_FORMATS_CONVERT_TO_GIF = [$FORMAT_AVIF, $FORMAT_BMP, $FORMAT_HEIC, $FORMAT_HEIF, $FORMAT_JFIF, $FORMAT_JPEG, $FORMAT_JPE, $FORMAT_JPG, $FORMAT_JXL, $FORMAT_PNG, $FORMAT_WEBP], _
		$SUPPORT_FORMATS_CONVERT_TO_BMP = [$FORMAT_AVIF, $FORMAT_GIF, $FORMAT_HEIC, $FORMAT_HEIF, $FORMAT_JFIF, $FORMAT_JPEG, $FORMAT_JPE, $FORMAT_JPG, $FORMAT_JXL, $FORMAT_PNG, $FORMAT_WEBP]


; Проверка обновлений: последний релиз GitHub, в котором лежит этот архив
Global Const $gc_sUpdateRepo = 'MarkovTrue/Moth', $gc_sUpdateAsset = 'Moth-win10-11-x64.zip'

Global Const $gc_sRegKey = 'HKEY_LOCAL_MACHINE64\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\CommandStore\shell\'

; Накопитель ошибок реестра для _MothRegWrite/_MothRegDelete
Global $g_sRegErrors = ''


; Тёмная тема приложений Windows. Нет значения в реестре - светлая: RegRead вернул бы '',
; а '' = 0 в AutoIt истинно
Func _RegAppsUseDarkTheme()
	Local $iLight = RegRead('HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize', 'AppsUseLightTheme')
	If @error Then Return False
	Return $iLight = 0
EndFunc   ;==>_RegAppsUseDarkTheme


Func _IsFormatSupported($sExtensionFile, $sActionName)
	Local $aSupportedFormats = _GetActionSupportedFormats($sActionName)
	If Not IsArray($aSupportedFormats) Then Return False

	For $sFormat In $aSupportedFormats
		If $sExtensionFile = $sFormat Then Return True
	Next
	Return False
EndFunc   ;==>_IsFormatSupported


; Форматы по каноническому имени действия, у своих имён ([Moth.MyAction]) - по Command
Func _GetActionSupportedFormats($sActionName)
	; Порядок важен: LosslessJpegExif должен проверяться раньше Lossless
	If StringInStr($sActionName, "CompressionLosslessJpegExif") Then
		Return $SUPPORT_FORMATS_COMPRESSION_LOSSLESS_EXIF
	ElseIf StringInStr($sActionName, "CompressionLossless") Then
		Return $SUPPORT_FORMATS_COMPRESSION_LOSSLESS
	ElseIf StringInStr($sActionName, "CompressionLossy") Then
		Return $SUPPORT_FORMATS_COMPRESSION_LOSSY
	ElseIf StringInStr($sActionName, "CompressionWeb") Then
		Return $SUPPORT_FORMATS_COMPRESSION_FOR_WEB
	ElseIf StringInStr($sActionName, "ColorQuantization") Then
		Return $SUPPORT_FORMATS_COLOR_QUANTIZATION
	ElseIf StringInStr($sActionName, "Resize") Then
		Return $SUPPORT_FORMATS_RESIZE
	ElseIf StringInStr($sActionName, "ConvertToPng") Then
		Return $SUPPORT_FORMATS_CONVERT_TO_PNG
	ElseIf StringInStr($sActionName, "ConvertToWebp") Then
		Return $SUPPORT_FORMATS_CONVERT_TO_WEBP
	ElseIf StringInStr($sActionName, "ConvertToJpg") Then
		Return $SUPPORT_FORMATS_CONVERT_TO_JPG
	ElseIf StringInStr($sActionName, "ConvertToJfif") Then
		Return $SUPPORT_FORMATS_CONVERT_TO_JFIF
	ElseIf StringInStr($sActionName, "ConvertToJxl") Then
		Return $SUPPORT_FORMATS_CONVERT_TO_JXL
	ElseIf StringInStr($sActionName, "ConvertToAvif") Then
		Return $SUPPORT_FORMATS_CONVERT_TO_AVIF
	ElseIf StringInStr($sActionName, "ConvertToHeic") Then
		Return $SUPPORT_FORMATS_CONVERT_TO_HEIC
	ElseIf StringInStr($sActionName, "ConvertToGif") Then
		Return $SUPPORT_FORMATS_CONVERT_TO_GIF
	ElseIf StringInStr($sActionName, "ConvertToBmp") Then
		Return $SUPPORT_FORMATS_CONVERT_TO_BMP
	EndIf

	; Имя не каноническое - определяем по команде действия из настроек
	Return _GetCommandSupportedFormats(_IniString_Read($gc_sMothIni, $sActionName, 'Command'))
EndFunc   ;==>_GetActionSupportedFormats


; Форматы по значению Command. Условия повторяют диспетчер _CompressFile в Moth.au3
Func _GetCommandSupportedFormats($sCommand)
	Switch $sCommand
		Case 'loss'
			Return $SUPPORT_FORMATS_COMPRESSION_LOSSLESS
		Case 'lossy'
			Return $SUPPORT_FORMATS_COMPRESSION_LOSSY
		Case 'web'
			Return $SUPPORT_FORMATS_COMPRESSION_FOR_WEB
		Case 'toPng'
			Return $SUPPORT_FORMATS_CONVERT_TO_PNG
		Case 'toWebp'
			Return $SUPPORT_FORMATS_CONVERT_TO_WEBP
		Case 'toJpg'
			Return $SUPPORT_FORMATS_CONVERT_TO_JPG
		Case 'toJfif'
			Return $SUPPORT_FORMATS_CONVERT_TO_JFIF
		Case 'toJxl'
			Return $SUPPORT_FORMATS_CONVERT_TO_JXL
		Case 'toAvif'
			Return $SUPPORT_FORMATS_CONVERT_TO_AVIF
		Case 'toHeic'
			Return $SUPPORT_FORMATS_CONVERT_TO_HEIC
		Case 'toGif'
			Return $SUPPORT_FORMATS_CONVERT_TO_GIF
		Case 'toBmp'
			Return $SUPPORT_FORMATS_CONVERT_TO_BMP
	EndSwitch

	If StringInStr($sCommand, 'cq') Then Return $SUPPORT_FORMATS_COLOR_QUANTIZATION
	If StringLeft($sCommand, 3) = 'per' Then Return $SUPPORT_FORMATS_RESIZE
	If StringInStr($sCommand, 'resize') Then Return $SUPPORT_FORMATS_RESIZE

	Return Null
EndFunc   ;==>_GetCommandSupportedFormats


Func _GetExtensionListExpanded()
	Return StringSplit(_ArrayToString($gc_aExtensionWhiteList, '.'), '.', 2)
EndFunc   ;==>_GetExtensionListExpanded


; Тема окон Moth. Пока её не выбрали в настройках (пусто или System из ini до 1.40),
; окна следуют режиму приложений Windows
Func _IsDarkTheme()
	Local $sTheme = _IniString_Read($gc_sMothIni, 'Config', 'ThemeGUI')
	If $sTheme = 'Dark' Then Return True
	If $sTheme = 'Light' Then Return False
	Return $gc_bRegDarkTheme
EndFunc   ;==>_IsDarkTheme


Func _GetThemePath()
	Return @ScriptDir & '\Themes\' & (_IsDarkTheme() ? 'Dark' : 'Light')
EndFunc   ;==>_GetThemePath


; Иконки меню проводника. Меню следует режиму приложений Windows, а не теме Moth
Func _GetIconPath()
	Return @ScriptDir & '\Themes\' & ($gc_bRegDarkTheme ? 'Dark' : 'Light')
EndFunc   ;==>_GetIconPath


; Имя файла иконки темы из Icon= в Moth.ini. Старое имя (lossless_exif.ico, до 1.40) даёт
; новое (LosslessExif.ico): рабочий ini переписывать не нужно. Иконку из системы
; (*.jpg, файл с индексом) не трогает
Func _ThemeIconName($sIcon)
	If StringRight($sIcon, 4) <> '.ico' Or StringInStr($sIcon, '\') Then Return $sIcon
	Local $sName = ''
	For $sPart In StringSplit(StringTrimRight($sIcon, 4), '_', $STR_NOCOUNT)
		$sName &= StringUpper(StringLeft($sPart, 1)) & StringMid($sPart, 2)
	Next
	Return $sName & '.ico'
EndFunc   ;==>_ThemeIconName


Func _GetFilterNameByIndx($nIndx)
	If $nIndx >= 0 And $nIndx <= UBound($gc_aResizeFilters) - 1 Then Return $gc_aResizeFilters[$nIndx]
	Return $gc_aResizeFilters[0] ; Lanczos по умолчанию
EndFunc   ;==>_GetFilterNameByIndx


; Расширение файла без точки
Func _GetFileExtension($sPathFile)
	Return StringRegExpReplace($sPathFile, '^.*\.', '')
EndFunc   ;==>_GetFileExtension


; Имя файла с расширением
Func _GetFileName($sPathFile)
	Return StringRegExpReplace($sPathFile, '^.*\\', '')
EndFunc   ;==>_GetFileName


Func _IsDir($sPath)
	Return StringInStr(FileGetAttrib($sPath & '\'), 'D', 2) > 0
EndFunc   ;==>_IsDir


; Строка задания Moth «путь|действие». '' - пути нет или формат файла не поддерживается.
; Папку раскрывает сам Moth
Func _MothTaskLine($sPath, $sAction)
	If $sAction = '' Or Not FileExists($sPath) Then Return ''
	If Not _IsDir($sPath) Then
		_ArraySearch(_GetExtensionListExpanded(), _GetFileExtension($sPath))
		If @error Then Return ''
	EndIf
	Return $sPath & '|' & $sAction
EndFunc   ;==>_MothTaskLine


; Строки заданий (через @LF) в очередь Moth, Moth при необходимости запускается.
; Недоставленное (Moth не принял за $gc_iCopyDataQueueSendMs) дописывается в %TEMP%\Moth\Moth.log
Func _MothSendTasks($sLines)
	If _CopyDataQueue_Send($gc_sIpcMoth, $sLines, '"' & @ScriptDir & '\Moth.exe"') Then Return True
	Local $iSent = @extended, $sLost = ''
	For $sLine In StringSplit($sLines, @LF, $STR_NOCOUNT)
		If $sLine = '' Then ContinueLoop
		If $iSent > 0 Then
			$iSent -= 1
		Else
			$sLost &= @CRLF & '    ' & $sLine
		EndIf
	Next
	DirCreate($gc_sTmpPath)
	Local $hLog = FileOpen($gc_sTmpPath & '\Moth.log', BitOR($FO_APPEND, $FO_UTF8))
	FileWrite($hLog, '=== ' & @YEAR & '.' & @MON & '.' & @MDAY & ' ' & @HOUR & ':' & @MIN & ':' & @SEC & _
			' Moth did not accept the tasks:' & $sLost & @CRLF & @CRLF)
	FileClose($hLog)
	Return False
EndFunc   ;==>_MothSendTasks


; Файл как UTF-8 с BOM и без: FileRead без флага без BOM читает CP1251 и портит кириллицу.
; Переводы строк приводятся к CRLF: ini правят руками в разных редакторах, а Moth пишет его с CRLF
Func _ReadFileUTF8($sPath)
	Local $hFile = FileOpen($sPath, $FO_UTF8)
	If $hFile = -1 Then Return ''
	Local $sContent = FileRead($hFile)
	FileClose($hFile)
	Return StringRegExpReplace($sContent, '\r\n|\r|\n', @CRLF)
EndFunc   ;==>_ReadFileUTF8


; Перезапись файла в UTF-8 с BOM. Для Moth.ini вместо IniWrite: тот пишет кириллицу в CP1251
Func _WriteFileUTF8($sPath, $sContent)
	Local $hFile = FileOpen($sPath, BitOR($FO_OVERWRITE, $FO_UTF8))
	If $hFile = -1 Then Return SetError(1, 0, False)
	FileWrite($hFile, $sContent)
	FileClose($hFile)
	Return True
EndFunc   ;==>_WriteFileUTF8


; Без Moth.ini всё молча работало бы с пустым конфигом. Зовётся из точек входа exe,
; а не при подключении: тесты подключают модуль из папки без Moth.ini
Func _MothIniRequire()
	If FileExists(@ScriptDir & '\Moth.ini') Then Return True
	; Язык берётся из этого самого ini, поэтому здесь язык системы
	_LangFile_Load(_LangFile_Resolve(@ScriptDir & '\Lang'))
	MsgBox(16, $gc_sAppName, _LangFile_Format('Errors', 'IniNotFound', _
			'Settings file not found:' & @CRLF & '%1' & @CRLF & @CRLF & 'Restore the file or reinstall the application.', _
			@ScriptDir & '\Moth.ini'))
	Exit
EndFunc   ;==>_MothIniRequire


; RegWrite/RegDelete, сбойные ключи копятся в $g_sRegErrors до _MothRegReportErrors
Func _MothRegWrite($sKeyName, $sValueName, $sType, $vValue)
	Local $iRet = RegWrite($sKeyName, $sValueName, $sType, $vValue)
	If $iRet = 0 Then $g_sRegErrors &= $sKeyName & @CRLF
	Return $iRet
EndFunc   ;==>_MothRegWrite


Func _MothRegDelete($sKeyName)
	Local $iRet = RegDelete($sKeyName)
	; 1 = удалено, 0 = ключа не было (не ошибка), остальное - сбой
	If $iRet <> 1 And $iRet <> 0 Then $g_sRegErrors &= $sKeyName & @CRLF
	Return $iRet
EndFunc   ;==>_MothRegDelete


; Показывает накопленные ошибки реестра. True, если ошибок не было.
Func _MothRegReportErrors()
	If $g_sRegErrors = '' Then Return True
	MsgBox(16, $gc_sAppName, _LangFile_Format('Errors', 'RegistryFailed', _
			'Failed to update registry keys:' & @CRLF & @CRLF & '%1' & @CRLF & 'The context menu may be displayed incorrectly.', _
			$g_sRegErrors))
	$g_sRegErrors = ''
	Return False
EndFunc   ;==>_MothRegReportErrors


; Загружает язык интерфейса из [Config] Language, пустое значение - язык системы
Func _MothLangInit()
	_LangFile_Load(_LangFile_Resolve(@ScriptDir & '\Lang', _IniString_Read($gc_sMothIni, 'Config', 'Language')))
EndFunc   ;==>_MothLangInit


Func _Lang($sSection, $sKey, $sDefault = '')
	Return _LangFile_Get($sSection, $sKey, $sDefault)
EndFunc   ;==>_Lang


; Заголовок действия в контекстном меню: ContextMenuTitle из Moth.ini перекрывает
; перевод из языкового файла, так пользовательские действия задают свои названия
Func _ActionTitle($sActionName)
	Local $sTitle = StringStripWS(_ActionRead($sActionName, 'ContextMenuTitle'), 3)
	If $sTitle <> '' Then Return $sTitle
	Return _LangFile_Get('Actions', $sActionName, '')
EndFunc   ;==>_ActionTitle


; Проверка разрядности ОС при старте exe: утилиты в Apps только x64
Func _MothRequireX64()
	If @OSArch <> 'X86' Then Return True
	MsgBox(48, $gc_sAppName, _LangFile_Get('Errors', 'OnlyX64', _
			'Only 64-bit Windows is supported.' & @CRLF & 'The application will be closed.'))
	Exit
EndFunc   ;==>_MothRequireX64


; ============================================================
; Обновления
; ============================================================

; Пишет ключи [Config] в Moth.ini. Файл перечитывается с диска: его могли поправить,
; пока программа работала. $aPairs - [ключ, значение, ключ, значение, ...]
Func _MothConfigWrite($aPairs)
	Local $sIniPath = @ScriptDir & '\Moth.ini'
	Local $sIni = _ReadFileUTF8($sIniPath)
	For $i = 0 To UBound($aPairs) - 2 Step 2
		_IniString_Write($sIni, 'Config', $aPairs[$i], $aPairs[$i + 1])
	Next
	Return _WriteFileUTF8($sIniPath, $sIni)
EndFunc   ;==>_MothConfigWrite


; Версия из прошлой проверки, если она новее этой, иначе ''. Ini читается с диска:
; проверку мог только что закончить Launcher
Func _MothUpdateAvailable()
	Local $sLatest = _IniString_Read(_ReadFileUTF8(@ScriptDir & '\Moth.ini'), 'Config', 'LatestVersion')
	If $sLatest = '' Or _UpdateCheck_CompareVersions($gc_sAppVersion, $sLatest) >= 0 Then Return ''
	Return $sLatest
EndFunc   ;==>_MothUpdateAvailable


; Пора ли автопроверке: не выключена и с прошлой прошла неделя
Func _MothUpdateCheckDue()
	Local $sIni = _ReadFileUTF8(@ScriptDir & '\Moth.ini')
	If _IniString_Read($sIni, 'Config', 'UpdateCheck', '1') = '0' Then Return False
	Return _UpdateCheck_IsDue(_IniString_Read($sIni, 'Config', 'LastUpdateCheck'), 7)
EndFunc   ;==>_MothUpdateCheckDue


; Запускает проверку отдельным процессом (Launcher.exe checkUpdate): запрос WinINet
; синхронный, и окно не должно ждать сеть. Дескриптор процесса для _MothUpdateCheckPoll или 0
Func _MothUpdateCheckStart()
	Local $iPid = Run('"' & @ScriptDir & '\Launcher.exe" checkUpdate', @ScriptDir, @SW_HIDE)
	If Not $iPid Then Return 0
	; Права: ждать процесс и узнать код выхода
	Local Const $SYNCHRONIZE = 0x00100000
	Local $aCall = DllCall('kernel32.dll', 'handle', 'OpenProcess', _
			'dword', BitOR($SYNCHRONIZE, $PROCESS_QUERY_LIMITED_INFORMATION), 'bool', False, 'dword', $iPid)
	If @error Then Return 0
	Return $aCall[0]
EndFunc   ;==>_MothUpdateCheckStart


; Состояние проверки: -1 ещё идёт, иначе код выхода Launcher (0 - успех, остальное - @error
; _UpdateCheck_LatestRelease). По завершении дескриптор закрывается и обнуляется
Func _MothUpdateCheckPoll(ByRef $hProcess)
	If Not $hProcess Then Return 1
	Local $aWait = DllCall('kernel32.dll', 'dword', 'WaitForSingleObject', 'handle', $hProcess, 'dword', 0)
	If Not @error And $aWait[0] = 258 Then Return -1 ; WAIT_TIMEOUT: ещё работает
	Local $aCode = DllCall('kernel32.dll', 'bool', 'GetExitCodeProcess', 'handle', $hProcess, 'dword*', 0)
	Local $iCode = @error ? 1 : $aCode[2]
	DllCall('kernel32.dll', 'bool', 'CloseHandle', 'handle', $hProcess)
	$hProcess = 0
	Return $iCode
EndFunc   ;==>_MothUpdateCheckPoll


; Проверка для Launcher.exe checkUpdate: дата пишется и при сбое сети, чтобы без сети
; не стучаться при каждом запуске. Найденная версия - только при ответе GitHub
Func _MothUpdateCheckRun()
	Local $sLatest = _UpdateCheck_LatestRelease($gc_sUpdateRepo, $gc_sUpdateAsset)
	Local $iError = @error
	Local $sToday = @YEAR & '.' & @MON & '.' & @MDAY
	; Нет релиза или архива в нём - новой версии нет, пустое значение. Сбой сети - версию не трогаем
	Local $aPairs[4] = ['LastUpdateCheck', $sToday, 'LatestVersion', $sLatest]
	If $iError = 1 Then ReDim $aPairs[2]
	_MothConfigWrite($aPairs)
	Return $iError
EndFunc   ;==>_MothUpdateCheckRun


; Команды ресайза читают $gc_sMothIni: подключаются после него
#include "MothResize.au3"
