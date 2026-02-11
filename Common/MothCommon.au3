#include-once

#include <Array.au3>
#include <IniString.au3>

Global Const _
		$FORMAT_AVIF = 'avif', _
		$FORMAT_BMP = 'bmp', _
		$FORMAT_GIF = 'gif', _
		$FORMAT_HEIC = 'heic', _
		$FORMAT_JFIF = 'jfif', _
		$FORMAT_JPE = 'jpe', _
		$FORMAT_JPEG = 'jpeg', _
		$FORMAT_JPG = 'jpg', _
		$FORMAT_PNG = 'png', _
		$FORMAT_WEBP = 'webp'

Global Const _
		$sAppName = 'Moth 1.40', _								; заголовок программы
		$sMothINI = FileRead(@ScriptDir & '\Moth.ini'), _				; путь к файлу настроек
		$sTmpPath = @TempDir & '\Moth', _							; путь к временной папке
		$sImgPath = @TempDir & '\Moth\images', _					; путь к временной папке картинок
		$sLogPathDir = @TempDir & '\Moth\logs', _					; путь к папке списка заданий
		$bRegDarkTheme = RegRead('HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize', 'AppsUseLightTheme') = 0 ? True : False

Global Const $aExtensionWhiteList = [ _
		$FORMAT_AVIF, _
		$FORMAT_BMP, _
		$FORMAT_GIF, _
		$FORMAT_HEIC, _
		$FORMAT_JFIF, _
		$FORMAT_JPG & '.' & $FORMAT_JPE & '.' & $FORMAT_JPEG, _
		$FORMAT_PNG, _
		$FORMAT_WEBP]

Global Const _
		$SUPPORT_FORMATS_COMPRESSION_LOSSLESS = [$FORMAT_AVIF, $FORMAT_BMP, $FORMAT_GIF, $FORMAT_JFIF, $FORMAT_JPEG, $FORMAT_JPE, $FORMAT_JPG, $FORMAT_PNG, $FORMAT_WEBP], _
		$SUPPORT_FORMATS_COMPRESSION_LOSSY = [$FORMAT_AVIF, $FORMAT_BMP, $FORMAT_GIF, $FORMAT_JFIF, $FORMAT_JPEG, $FORMAT_JPE, $FORMAT_JPG, $FORMAT_PNG, $FORMAT_WEBP], _
		$SUPPORT_FORMATS_COMPRESSION_FOR_WEB = [$FORMAT_AVIF, $FORMAT_BMP, $FORMAT_GIF, $FORMAT_JFIF, $FORMAT_JPEG, $FORMAT_JPE, $FORMAT_JPG, $FORMAT_PNG, $FORMAT_WEBP], _
		$SUPPORT_FORMATS_COLOR_QUANTIZATION = [$FORMAT_AVIF, $FORMAT_BMP, $FORMAT_GIF, $FORMAT_JFIF, $FORMAT_JPEG, $FORMAT_JPE, $FORMAT_JPG, $FORMAT_PNG, $FORMAT_WEBP], _
		$SUPPORT_FORMATS_RESIZE = [$FORMAT_AVIF, $FORMAT_BMP, $FORMAT_GIF, $FORMAT_JFIF, $FORMAT_JPEG, $FORMAT_JPE, $FORMAT_JPG, $FORMAT_PNG, $FORMAT_WEBP], _
		$SUPPORT_FORMATS_CONVERT_TO_PNG = [$FORMAT_AVIF, $FORMAT_BMP, $FORMAT_GIF, $FORMAT_HEIC, $FORMAT_JFIF, $FORMAT_JPEG, $FORMAT_JPE, $FORMAT_JPG, $FORMAT_WEBP], _
		$SUPPORT_FORMATS_CONVERT_TO_WEBP = [$FORMAT_AVIF, $FORMAT_BMP, $FORMAT_GIF, $FORMAT_HEIC, $FORMAT_JFIF, $FORMAT_JPEG, $FORMAT_JPE, $FORMAT_JPG, $FORMAT_PNG], _
		$SUPPORT_FORMATS_CONVERT_TO_JPG = [$FORMAT_AVIF, $FORMAT_BMP, $FORMAT_GIF, $FORMAT_HEIC, $FORMAT_JFIF, $FORMAT_PNG, $FORMAT_WEBP]


Global $sHKLM = 'HKEY_LOCAL_MACHINE64'
Global $sRegKey = $sHKLM & '\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\CommandStore\shell\'


; Функция проверки поддержки формата
Func _IsFormatSupported($sExtensionFile, ByRef $sActionName)
	Local $aSupportedFormats = Null

	If StringInStr($sActionName, "CompressionLossless") Then
		$aSupportedFormats = $SUPPORT_FORMATS_COMPRESSION_LOSSLESS
	ElseIf StringInStr($sActionName, "CompressionLossy") Then
		$aSupportedFormats = $SUPPORT_FORMATS_COMPRESSION_LOSSY
	ElseIf StringInStr($sActionName, "CompressionWeb") Then
		$aSupportedFormats = $SUPPORT_FORMATS_COMPRESSION_FOR_WEB
	ElseIf StringInStr($sActionName, "ColorQuantization") Then
		$aSupportedFormats = $SUPPORT_FORMATS_COLOR_QUANTIZATION
	ElseIf StringInStr($sActionName, "Resize") Then
		$aSupportedFormats = $SUPPORT_FORMATS_RESIZE
	ElseIf StringInStr($sActionName, "ConvertToPng") Then
		$aSupportedFormats = $SUPPORT_FORMATS_CONVERT_TO_PNG
	ElseIf StringInStr($sActionName, "ConvertToWebp") Then
		$aSupportedFormats = $SUPPORT_FORMATS_CONVERT_TO_WEBP
	ElseIf StringInStr($sActionName, "ConvertToJpg") Then
		$aSupportedFormats = $SUPPORT_FORMATS_CONVERT_TO_JPG
	EndIf

	If $aSupportedFormats = Null Then Return False

	For $sFormat In $aSupportedFormats
		If $sExtensionFile = $sFormat Then
			Return True
		EndIf
	Next

	Return False
EndFunc   ;==>_IsFormatSupported


Func _GetExtensionListExpanded()
	Return StringSplit(_ArrayToString($aExtensionWhiteList, '.'), '.', 2)
EndFunc   ;==>_GetExtensionListExpanded


Func _IsDarkTheme()
	Local $sTheme = _IniString_Read($sMothINI, 'Config', 'ThemeGUI')
	Return $sTheme = 'System' ? $bRegDarkTheme : $sTheme = 'Dark'
EndFunc   ;==>_IsDarkTheme


Func _GetThemePath()
	Return @ScriptDir & '\themes\' & (_IsDarkTheme() ? 'dark' : 'light')
EndFunc   ;==>_GetThemePath


Func _GetIconPath()
	Local $sTheme = _IniString_Read($sMothINI, 'Config', 'ThemeIcons')

	If $sTheme = 'System' Then
		$sTheme = $bRegDarkTheme ? 'Dark' : 'Light'
	EndIf

	Return @ScriptDir & '\themes\' & StringLower($sTheme)
EndFunc   ;==>_GetIconPath


Func _GetFilterNameByIndx($nIndx)
	Switch $nIndx
		Case 0
			Return 'Lanczos'
		Case 1
			Return 'RobidouxSharp'
		Case 2
			Return 'Catrom'
		Case 3
			Return 'Mitchell'
		Case 4
			Return 'Point'
		Case 5
			Return 'Box'
	EndSwitch
	Return 'Lanczos'
EndFunc   ;==>_GetFilterNameByIndx


; Расширение файла без точки
Func _GetFileExtension($sPathFile)
	Return StringRegExpReplace($sPathFile, '^.*\.', '')
EndFunc   ;==>_GetFileExtension


; Имя файла с расширением
Func _GetFileName($sPathFile)
	Return StringRegExpReplace($sPathFile, '^.*\\', '')
EndFunc   ;==>_GetFileName


; True если это директория, иначе False
Func _IsDir($sTmp)
	$sTmp = FileGetAttrib($sTmp & "\")
	Return StringInStr($sTmp, 'D', 2) > 0
EndFunc   ;==>_IsDir
