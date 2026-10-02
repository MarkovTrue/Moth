#include-once
#include <WinAPIShellEx.au3>

; ============================================================
; FluentSubclass – сабклассы окон для семейства Fluent
; ============================================================
; Машинные процедуры (x64), чтобы лишние сообщения окна не шли через AutoIt.
; AutoIt посреди выполнения скрипта, в том числе внутри колбэка, сам выбирает очередь
; сообщений. Если колбэк сабкласса получил WM_PAINT, а BeginPaint ещё не вызван, тот же
; WM_PAINT снова в очереди: колбэк вкладывается сам в себя, на пределе вложенности
; AutoIt перестаёт его вызывать, и окно навсегда повисает в холостом цикле WM_PAINT.
; Здесь сообщения фильтруются машинным кодом: в скрипт уходит только нужное.
; На x86 функции фильтров возвращают 0 - вызывающий оставляет обычный колбэк.
;
; Учёт: _FluentSubclass_Set вешает колбэк AutoIt и запоминает его, _FluentSubclass_RemoveAll
; снимает все разом (смена темы, выход).

; Повешенные сабклассы [окно, процедура, id] и колбэки по имени функции
Global $__g_aFluentSubclass[0][3], $__g_iFluentSubclassId = 1000
Global $__g_oFluentCallbacks[]


; Процедура сабкласса: сообщение $iMsg уходит в колбэк $pCallback (DllCallbackGetPtr с сигнатурой
; SUBCLASSPROC), остальные сразу в DefSubclassProc. Указатель для _WinAPI_SetWindowSubclass или 0.
; Освобождать _FluentSubclass_Free только после снятия сабкласса
Func _FluentSubclass_Pass($iMsg, $pCallback)
	If Not @AutoItX64 Then Return 0
	Local $pDef = __FluentSubclass_DefPtr()
	If Not $pDef Then Return 0
	Local $pCode = __FluentSubclass_Alloc(32)
	If Not $pCode Then Return 0

	; cmp edx, $iMsg / jne def / mov rax, callback / jmp rax / def: mov rax, DefSubclassProc / jmp rax
	; Аргументы (в том числе стековые) не трогаются, поэтому оба перехода - хвостовые вызовы
	Local $tCode = DllStructCreate('align 1;byte op[2];dword msg;byte a[4];ptr cb;byte b[4];ptr def;byte c[2]', $pCode)
	$tCode.op = Binary('0x81FA')
	$tCode.msg = $iMsg
	$tCode.a = Binary('0x750C48B8')
	$tCode.cb = $pCallback
	$tCode.b = Binary('0xFFE048B8')
	$tCode.def = $pDef
	$tCode.c = Binary('0xFFE0')
	Return __FluentSubclass_Flush($pCode, 32)
EndFunc   ;==>_FluentSubclass_Pass


; Процедура «курсор-рука»: на WM_SETCURSOR ставит руку, остальное в DefSubclassProc.
; Скрипт не участвует вовсе. Одна на процесс и не освобождается: окна с ней могут получать
; сообщения до самого конца процесса. Указатель для _WinAPI_SetWindowSubclass или 0
Func _FluentSubclass_HandCursor()
	Local Static $pCode = 0
	If $pCode Or Not @AutoItX64 Then Return $pCode
	Local Const $IDC_HAND = 32649
	Local $pDef = __FluentSubclass_DefPtr()
	If Not $pDef Then Return 0
	Local $aCursor = DllCall('user32.dll', 'handle', 'LoadCursorW', 'handle', 0, 'ulong_ptr', $IDC_HAND)
	If @error Or Not $aCursor[0] Then Return 0
	Local $aUser32 = DllCall('kernel32.dll', 'handle', 'GetModuleHandleW', 'wstr', 'user32.dll')
	If @error Or Not $aUser32[0] Then Return 0
	Local $aSetCursor = DllCall('kernel32.dll', 'ptr', 'GetProcAddress', 'handle', $aUser32[0], 'str', 'SetCursor')
	If @error Or Not $aSetCursor[0] Then Return 0
	Local $pNew = __FluentSubclass_Alloc(56)
	If Not $pNew Then Return 0

	; cmp edx, 20h (WM_SETCURSOR) / jne def / sub rsp, 28h / mov rcx, hCursor / mov rax, SetCursor
	; call rax / add rsp, 28h / mov eax, 1 / ret / def: mov rax, DefSubclassProc / jmp rax
	Local $tCode = DllStructCreate('align 1;byte a[14];ptr cur;byte b[2];ptr setcur;byte c[14];ptr def;byte d[2]', $pNew)
	$tCode.a = Binary('0x81FA2000000075244883EC2848B9')
	$tCode.cur = $aCursor[0]
	$tCode.b = Binary('0x48B8')
	$tCode.setcur = $aSetCursor[0]
	$tCode.c = Binary('0xFFD04883C428B801000000C348B8')
	$tCode.def = $pDef
	$tCode.d = Binary('0xFFE0')
	$pCode = __FluentSubclass_Flush($pNew, 56)
	Return $pCode
EndFunc   ;==>_FluentSubclass_HandCursor


; Освобождает процедуру _FluentSubclass_Pass. Сабкласс с ней должен быть уже снят
Func _FluentSubclass_Free($pCode)
	Local Const $MEM_RELEASE = 0x8000
	If $pCode Then DllCall('kernel32.dll', 'bool', 'VirtualFree', 'ptr', $pCode, 'ulong_ptr', 0, 'dword', $MEM_RELEASE)
EndFunc   ;==>_FluentSubclass_Free


; Указатель на колбэк SUBCLASSPROC для функции AutoIt, один на имя
Func _FluentSubclass_Callback($sFunc)
	If Not MapExists($__g_oFluentCallbacks, $sFunc) Then _
			$__g_oFluentCallbacks[$sFunc] = DllCallbackRegister($sFunc, "lresult", "hwnd;uint;wparam;lparam;uint_ptr;dword_ptr")
	Return DllCallbackGetPtr($__g_oFluentCallbacks[$sFunc])
EndFunc   ;==>_FluentSubclass_Callback


; Вешает на окно сабкласс с колбэком $sFunc и запоминает его. $pData уходит колбэку в dwRefData
Func _FluentSubclass_Set($hWnd, $sFunc, $pData = 0)
	If Not $hWnd Then Return False
	Local $pProc = _FluentSubclass_Callback($sFunc)
	Local $iIndex = UBound($__g_aFluentSubclass)
	ReDim $__g_aFluentSubclass[$iIndex + 1][3]
	$__g_aFluentSubclass[$iIndex][0] = $hWnd
	$__g_aFluentSubclass[$iIndex][1] = $pProc
	$__g_aFluentSubclass[$iIndex][2] = $__g_iFluentSubclassId
	_WinAPI_SetWindowSubclass($hWnd, $pProc, $__g_iFluentSubclassId, $pData)
	$__g_iFluentSubclassId += 1
	Return True
EndFunc   ;==>_FluentSubclass_Set


; Снимает все сабклассы _FluentSubclass_Set и освобождает колбэки
Func _FluentSubclass_RemoveAll()
	For $i = 0 To UBound($__g_aFluentSubclass) - 1
		If $__g_aFluentSubclass[$i][0] Then _
				_WinAPI_RemoveWindowSubclass($__g_aFluentSubclass[$i][0], $__g_aFluentSubclass[$i][1], $__g_aFluentSubclass[$i][2])
	Next
	ReDim $__g_aFluentSubclass[0][3]

	For $sFunc In MapKeys($__g_oFluentCallbacks)
		DllCallbackFree($__g_oFluentCallbacks[$sFunc])
	Next
	Local $oEmpty[]
	$__g_oFluentCallbacks = $oEmpty
EndFunc   ;==>_FluentSubclass_RemoveAll


; DefSubclassProc напрямую: _WinAPI_DefSubclassProc в части случаев ронял сабклассы
Func _FluentSubclass_DefProc($hWnd, $iMsg, $wParam, $lParam)
	Local $aRet = DllCall('comctl32.dll', 'lresult', 'DefSubclassProc', 'hwnd', $hWnd, 'uint', $iMsg, 'wparam', $wParam, 'lparam', $lParam)
	If @error Then Return 0
	Return $aRet[0]
EndFunc   ;==>_FluentSubclass_DefProc


; ============================================================
; Внутреннее
; ============================================================

; DefSubclassProc из загруженного comctl32 v6 (сабклассы живут в нём же)
Func __FluentSubclass_DefPtr()
	Local $aModule = DllCall('kernel32.dll', 'handle', 'GetModuleHandleW', 'wstr', 'comctl32.dll')
	If @error Or Not $aModule[0] Then Return 0
	Local $aProc = DllCall('kernel32.dll', 'ptr', 'GetProcAddress', 'handle', $aModule[0], 'str', 'DefSubclassProc')
	If @error Then Return 0
	Return $aProc[0]
EndFunc   ;==>__FluentSubclass_DefPtr


Func __FluentSubclass_Alloc($iSize)
	Local Const $MEM_COMMIT_RESERVE = 0x3000, $PAGE_EXECUTE_READWRITE = 0x40
	Local $aMem = DllCall('kernel32.dll', 'ptr', 'VirtualAlloc', 'ptr', 0, 'ulong_ptr', $iSize, _
			'dword', $MEM_COMMIT_RESERVE, 'dword', $PAGE_EXECUTE_READWRITE)
	If @error Then Return 0
	Return $aMem[0]
EndFunc   ;==>__FluentSubclass_Alloc


Func __FluentSubclass_Flush($pCode, $iSize)
	Local $aProcess = DllCall('kernel32.dll', 'handle', 'GetCurrentProcess')
	DllCall('kernel32.dll', 'bool', 'FlushInstructionCache', 'handle', $aProcess[0], 'ptr', $pCode, 'ulong_ptr', $iSize)
	Return $pCode
EndFunc   ;==>__FluentSubclass_Flush
