#include-once

; #INDEX# =======================================================================================================================
; Title .........: UpdateCheck
; AutoIt Version : 3.3.18.0
; Language ......: Русский
; Description ...: Проверка новой версии по релизам GitHub программ MarkovTrue (Moth, VCLauncher).
;                  Два HEAD-запроса без перехода по редиректу: /releases/latest/download/<архив>
;                  отвечает редиректом на /releases/download/<тег>/<архив>, тег и есть версия, а этот
;                  адрес отвечает 404, если архива в релизе нет. Тело ответа не читается, лимитов
;                  API нет, и новая версия засчитывается, только когда её можно скачать.
;                  Запрос идёт через WinINet: он берёт прокси из настроек Windows, как браузер.
;                  WinINet синхронный, поэтому вызывать из отдельного процесса или там, где
;                  подвисание окна на время таймаута не страшно.
; Author(s) .....: MarkovTrue
; ===============================================================================================================================

; #CURRENT# =====================================================================================================================
; _UpdateCheck_LatestRelease
; _UpdateCheck_CompareVersions
; _UpdateCheck_IsDue
; _UpdateCheck_ReleasesUrl
; ===============================================================================================================================


; Версия последнего релиза $sRepo ('Owner/Name'), в котором есть архив $sAsset.
; Тег 'v1.41' и '1.41' дают '1.41'.
; @error: 1 - нет сети или сбой WinINet, 2 - релиза нет, 3 - тег не разобран, 4 - архива в релизе нет.
Func _UpdateCheck_LatestRelease($sRepo, $sAsset, $iTimeoutMs = 15000)
	Local Const $INTERNET_SERVICE_HTTP = 3, $INTERNET_DEFAULT_HTTPS_PORT = 443
	Local Const $INTERNET_OPTION_CONNECT_TIMEOUT = 2, $INTERNET_OPTION_SEND_TIMEOUT = 5, $INTERNET_OPTION_RECEIVE_TIMEOUT = 6

	Local $hDll = DllOpen('wininet.dll')
	If $hDll = -1 Then Return SetError(1, 0, '')

	Local $sVersion = '', $iError = 1, $hConnect = 0, $sLocation, $iStatus
	; 0 = INTERNET_OPEN_TYPE_PRECONFIG: прокси из настроек Windows
	Local $aCall = DllCall($hDll, 'handle', 'InternetOpenW', 'wstr', 'UpdateCheck', 'dword', 0, 'ptr', 0, 'ptr', 0, 'dword', 0)
	Local $hInternet = (@error Or Not $aCall[0]) ? 0 : $aCall[0]

	If $hInternet Then
		Local $aOptions = [$INTERNET_OPTION_CONNECT_TIMEOUT, $INTERNET_OPTION_SEND_TIMEOUT, $INTERNET_OPTION_RECEIVE_TIMEOUT]
		For $iOption In $aOptions
			DllCall($hDll, 'bool', 'InternetSetOptionW', 'handle', $hInternet, 'dword', $iOption, 'dword*', $iTimeoutMs, 'dword', 4)
		Next
		$aCall = DllCall($hDll, 'handle', 'InternetConnectW', 'handle', $hInternet, 'wstr', 'github.com', _
				'word', $INTERNET_DEFAULT_HTTPS_PORT, 'ptr', 0, 'ptr', 0, 'dword', $INTERNET_SERVICE_HTTP, 'dword', 0, 'dword_ptr', 0)
		If Not @error And $aCall[0] Then $hConnect = $aCall[0]
	EndIf

	If $hConnect Then
		; Первый шаг: /releases/latest/download/<архив> -> /releases/download/<тег>/<архив>.
		; GitHub отвечает так для любого имени архива, поэтому это ещё не значит, что он есть
		$iStatus = __UpdateCheck_Head($hDll, $hConnect, '/' & $sRepo & '/releases/latest/download/' & $sAsset, $sLocation)
		If $iStatus Then $iError = 2
		If $iStatus >= 300 And $iStatus < 400 Then
			Local $aTag = StringRegExp($sLocation, '/releases/download/v?([^/]+)/', 1)
			$iError = 3
			If Not @error Then
				; Второй шаг: существующий архив отдаёт редирект на хранилище файлов, а не 404
				$iStatus = __UpdateCheck_Head($hDll, $hConnect, StringRegExpReplace($sLocation, '^https?://[^/]+', ''), $sLocation)
				$iError = 4
				If $iStatus = 0 Then $iError = 1
				If $iStatus >= 200 And $iStatus < 400 Then
					$sVersion = $aTag[0]
					$iError = 0
				EndIf
			EndIf
		EndIf
	EndIf

	Local $aHandles = [$hConnect, $hInternet]
	For $h In $aHandles
		If $h Then DllCall($hDll, 'bool', 'InternetCloseHandle', 'handle', $h)
	Next
	DllClose($hDll)
	Return SetError($iError, 0, $sVersion)
EndFunc   ;==>_UpdateCheck_LatestRelease


; HEAD-запрос без перехода по редиректу. Код ответа или 0 при сбое сети, в $sLocation - заголовок Location
Func __UpdateCheck_Head($hDll, $hConnect, $sPath, ByRef $sLocation)
	; HTTPS, без автоперехода по редиректу, без кэша, куков и окон WinINet
	Local Const $iFlags = BitOR(0x00800000, 0x00200000, 0x80000000, 0x04000000, 0x00080000, 0x00000200)
	Local Const $HTTP_QUERY_LOCATION = 33, $HTTP_QUERY_STATUS_CODE = 19, $HTTP_QUERY_FLAG_NUMBER = 0x20000000
	$sLocation = ''

	Local $aCall = DllCall($hDll, 'handle', 'HttpOpenRequestW', 'handle', $hConnect, 'wstr', 'HEAD', _
			'wstr', $sPath, 'ptr', 0, 'ptr', 0, 'ptr', 0, 'dword', $iFlags, 'dword_ptr', 0)
	If @error Or Not $aCall[0] Then Return 0
	Local $hRequest = $aCall[0], $iStatus = 0

	$aCall = DllCall($hDll, 'bool', 'HttpSendRequestW', 'handle', $hRequest, 'ptr', 0, 'dword', 0, 'ptr', 0, 'dword', 0)
	If Not @error And $aCall[0] Then
		$aCall = DllCall($hDll, 'bool', 'HttpQueryInfoW', 'handle', $hRequest, 'dword', BitOR($HTTP_QUERY_STATUS_CODE, $HTTP_QUERY_FLAG_NUMBER), _
				'dword*', 0, 'dword*', 4, 'ptr', 0)
		If Not @error And $aCall[0] Then $iStatus = $aCall[3]
		Local $tBuf = DllStructCreate('wchar[2048]')
		$aCall = DllCall($hDll, 'bool', 'HttpQueryInfoW', 'handle', $hRequest, 'dword', $HTTP_QUERY_LOCATION, _
				'struct*', $tBuf, 'dword*', DllStructGetSize($tBuf), 'ptr', 0)
		If Not @error And $aCall[0] Then $sLocation = DllStructGetData($tBuf, 1)
	EndIf
	DllCall($hDll, 'bool', 'InternetCloseHandle', 'handle', $hRequest)
	Return $iStatus
EndFunc   ;==>__UpdateCheck_Head


; Версии вида '1.40' покомпонентно как числа: -1, 0 или 1. Недостающий компонент - ноль
Func _UpdateCheck_CompareVersions($s1, $s2)
	Local $a1 = StringSplit($s1, '.', 2), $a2 = StringSplit($s2, '.', 2)
	Local $iMax = UBound($a1) > UBound($a2) ? UBound($a1) : UBound($a2)
	Local $n1, $n2
	For $i = 0 To $iMax - 1
		$n1 = $i < UBound($a1) ? Number($a1[$i]) : 0
		$n2 = $i < UBound($a2) ? Number($a2[$i]) : 0
		If $n1 < $n2 Then Return -1
		If $n1 > $n2 Then Return 1
	Next
	Return 0
EndFunc   ;==>_UpdateCheck_CompareVersions


; Пора ли проверять: дата прошлой проверки 'YYYY.MM.DD' старше $iDays дней или пуста
Func _UpdateCheck_IsDue($sLastDate, $iDays = 7)
	If Not StringRegExp($sLastDate, '^\d{4}\.\d{2}\.\d{2}$') Then Return True
	Local $aDate = StringSplit($sLastDate, '.', 2)
	; Разница дат через FILETIME, без Date.au3
	Local $tLast = DllStructCreate('word Year;word Month;word Dow;word Day;word H;word M;word S;word Ms')
	$tLast.Year = $aDate[0]
	$tLast.Month = $aDate[1]
	$tLast.Day = $aDate[2]
	Local $tFt = DllStructCreate('uint64 v'), $tNow = DllStructCreate('uint64 v')
	DllCall('kernel32.dll', 'bool', 'SystemTimeToFileTime', 'struct*', $tLast, 'struct*', $tFt)
	DllCall('kernel32.dll', 'none', 'GetSystemTimeAsFileTime', 'struct*', $tNow)
	; FILETIME - сотни наносекунд
	Return ($tNow.v - $tFt.v) / 864000000000 >= $iDays
EndFunc   ;==>_UpdateCheck_IsDue


; Страница релизов, куда вести пользователя за новой версией
Func _UpdateCheck_ReleasesUrl($sRepo)
	Return 'https://github.com/' & $sRepo & '/releases/latest'
EndFunc   ;==>_UpdateCheck_ReleasesUrl
