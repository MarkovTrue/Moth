#include-once
#include "GUIDarkTheme.includes.au3"

; #INDEX# =======================================================================================================================
; Title .........: GUIDarkTheme UDF Library for AutoIt3
; AutoIt Version : 3.3.18.0
; Language ......: English
; Description ...: UDF library for applying dark theme to win32 controls
; Author(s) .....: WildByDesign (including code from NoNameCode, argumentum, UEZ, pixelsearch, ahmet, MattyD, ioa747, Nine and more)
; Version .......: 3.0.0.0
; Notes .........: This UDF is not compatible with WS_EX_COMPOSITED extended style
; ...............: Window messages used for controls:	WM_CTLCOLOR*, WM_NOTIFY, WM_SIZE, WM_SETTINGCHANGE
; ...............: Window messages used for menubar:	WM_DRAWITEM, WM_ACTIVATE, WM_MEASUREITEM, WM_WINDOWPOSCHANGED
; ===============================================================================================================================

Global $__DM_g_Version = "3.0.0.0"

; #CURRENT# =====================================================================================================================
; _GUIDarkMenu_Register
; _GUIDarkMenu_SetColors
; _GUIDarkTheme_AccentColorSet
; _GUIDarkTheme_ApplyAuto
; _GUIDarkTheme_ApplyDark
; _GUIDarkTheme_ApplyLight
; _GUIDarkTheme_AutoTheme
; _GUIDarkTheme_CtrlBorderSet
; _GUIDarkTheme_GUICtrlAllSetDarkTheme
; _GUIDarkTheme_GUICtrlSetDarkTheme
; _GUIDarkTheme_GUISetDarkTheme
; _GUIDarkTheme_MsgBox
; _GUIDarkTheme_MsgBoxSet
; _GUIDarkTheme_SetCornerPref
; _GUIDarkTheme_SwitchTheme
; _GUIDarkTheme_ToolbarSetTrans
; _GUIDarkTheme_Version
; ===============================================================================================================================

; #INTERNAL_USE_ONLY# ===========================================================================================================
; __GUIDarkMenu_CreateFont
; __GUIDarkMenu_GetTopMenuItems
; __GUIDarkMenu_GUICtrlGetFont
; __GUIDarkMenu_GUIGetFontSize
; __GUIDarkMenu_MenuBarBKColor
; __GUIDarkMenu_PaintWhiteLine
; __GUIDarkMenu_WM_ACTIVATE
; __GUIDarkMenu_WM_DRAWITEM
; __GUIDarkMenu_WM_MEASUREITEM
; __GUIDarkMenu_WM_WINDOWPOSCHANGED
; __GUIDarkTheme_AddToSubclass
; __GUIDarkTheme_BrushCleanup
; __GUIDarkTheme_ButtonProc
; __GUIDarkTheme_CheckedPNG
; __GUIDarkTheme_CreateBrushes
; __GUIDarkTheme_CreateDots
; __GUIDarkTheme_CreatePens
; __GUIDarkTheme_CreateSizebox
; __GUIDarkTheme_DateProc
; __GUIDarkTheme_GetCtrlColors
; __GUIDarkTheme_GetCtrlStyleString
; __GUIDarkTheme_GetCtrlStyleString2
; __GUIDarkTheme_GetImages
; __GUIDarkTheme_GetStyleString
; __GUIDarkTheme_GroupProc
; __GUIDarkTheme_hWnd2Styles
; __GUIDarkTheme_IsCtrlInTab
; __GUIDarkTheme_OnExit
; __GUIDarkTheme_PenCleanup
; __GUIDarkTheme_SetBandColor
; __GUIDarkTheme_SizeboxProc
; __GUIDarkTheme_StatusRatio
; __GUIDarkTheme_SubclassCleanup
; __GUIDarkTheme_SubclassProc
; __GUIDarkTheme_TabProc
; __GUIDarkTheme_UncheckedPNG
; __GUIDarkTheme_UpDownProc
; __GUIDarkTheme_WM_CTLCOLOR
; __GUIDarkTheme_WM_NOTIFY
; __GUIDarkTheme_WM_SETTINGCHANGE
; __GUIDarkTheme_WM_SIZE
; ===============================================================================================================================

; #GLOBAL VARIABLES# ============================================================================================================
;										Customize Dark Mode Colors (RGB)			Customize Light Mode Colors (RGB)
Global $__DM_g_iGuiBkColor, 		$__DM_g_iGuiBkColorDark		= 0x202020,		$__DM_g_iGuiBkColorLight     = 0xF0F0F0
Global $__DM_g_iTextColor,			$__DM_g_iTextColorDark		= 0xE0E0E0,		$__DM_g_iTextColorLight      = 0x000000
Global $__DM_g_iCtrlBkColor,		$__DM_g_iCtrlBkColorDark	= 0x383838,		$__DM_g_iCtrlBkColorLight    = 0xFFFFFF
Global $__DM_g_iTabCtrlBkColor,		$__DM_g_iTabCtrlBkColorDark	= 0x202020,		$__DM_g_iTabCtrlBkColorLight = 0xF0F0F0
Global $__DM_g_iBorderColorSel,		$__DM_g_iBorderColorSelDark	= 0xB0B0B0,		$__DM_g_iBorderColorSelLight = 0xB0B0B0
Global $__DM_g_iBorderColor,		$__DM_g_iBorderColorDark	= 0x6B6B6B,		$__DM_g_iBorderColorLight    = 0x3F3F3F
Global $__DM_g_iSizeboxPaint,		$__DM_g_iSizeboxPaintDark	= 0x171717,		$__DM_g_iSizeboxPaintLight   = 0xF0F0F0
Global $__DM_g_iMenuBkColor,		$__DM_g_iMenuBkColorDark	= 0x202020,		$__DM_g_iMenuBkColorLight    = 0xF0F0F0
Global $__DM_g_iMenuHotColor,		$__DM_g_iMenuHotColorDark	= 0x303030,		$__DM_g_iMenuHotColorLight   = 0xE5E5E5
Global $__DM_g_iMenuSelColor,		$__DM_g_iMenuSelColorDark	= 0x272727,		$__DM_g_iMenuSelColorLight   = 0xEFEFEF
Global $__DM_g_iMenuTextColor,		$__DM_g_iMenuTextColorDark	= 0xE0E0E0,		$__DM_g_iMenuTextColorLight  = 0x000000
Global $__DM_g_iStatusBkColor,		$__DM_g_iStatusBkColorDark	= 0x1C1C1C,		$__DM_g_iStatusBkColorLight  = 0x1C1C1C
Global $__DM_g_iButtonColor,		$__DM_g_iButtonColorDark	= 0x333333,		$__DM_g_iButtonColorLight    = 0xF4F4F4
Global $__DM_g_iButtonColorHov,		$__DM_g_iButtonColorHovDark	= 0x454545,		$__DM_g_iButtonColorHovLight = 0xE0EFF9
Global $__DM_g_iButtonColorSel,		$__DM_g_iButtonColorSelDark = 0x666666,		$__DM_g_iButtonColorSelLight = 0xCCE4F7
Global $__DM_g_iButtonColorBor,		$__DM_g_iButtonColorBorDark = 0x9B9B9B,		$__DM_g_iButtonColorBorLight = 0xBCBCBC
Global $__DM_g_iTabColor,			$__DM_g_iTabColorDark 		= 0x303030,		$__DM_g_iTabColorLight       = 0xDBDBDB
Global $__DM_g_iTabColorSel,		$__DM_g_iTabColorSelDark 	= 0x202020,		$__DM_g_iTabColorSelLight    = 0xCFCFCF
Global $__DM_g_iExtraGray,			$__DM_g_iExtraGrayDark 		= 0x5E5E5E,		$__DM_g_iExtraGrayLight      = 0xCFCFCF

Global $__DM_g_iAccentColor = 0x0078D4
Global $__DM_g_iMsgBoxTopColor = 0x323232
Global $__DM_g_iMsgBoxBottomColor = 0x202020
Global $__DM_g_iMsgBoxButtonColor = $__DM_g_iMsgBoxBottomColor
Global $__DM_g_iMsgBoxTextColor = _WinAPI_SwitchColor(0xFFFFFF)

Global $__DM_g_hMsgBoxHook
Global $__DM_g_bUseDarkMode = _WinAPI_ShouldAppsUseDarkMode()
Global $__DM_g_bMsgBoxInitialized = False
Global $__DM_g_hMsgBoxSubProc = 0
Global $__DM_g_pMsgBoxSubProc = 0
Global $__DM_g_bShowCtrlBorder = True
Global $__DM_g_bShowEditActive = True

Global $__DM_g_aControls[150][4] = [[0, 0, 0, 0]] ; [hWnd, hSubclassProc, pSubclassProc, idSubClass]
Global $__DM_g_iControlCount = 0
Global $__DM_g_hSubclassProc = 0, $__DM_g_pSubclassProc = 0
Global $__DM_g_hTabProc = 0, $__DM_g_pTabProc = 0
Global $__DM_g_hSizeboxProc = 0, $__DM_g_pSizeboxProc = 0
Global $__DM_g_hUpDownSub = 0, $__DM_g_pUpDownSub = 0
Global $__DM_g_hButtonProc = 0, $__DM_g_pButtonProc = 0
Global $__DM_g_hGroupProc = 0, $__DM_g_pGroupProc = 0
Global $__DM_g_aButtonSub[1][3]
Global $__DM_g_iButtonCount = 0

Global $__DM_g_iMsgBoxDpi = Round(_WinAPI_GetDPI() / 96, 2)
If @error Then $__DM_g_iMsgBoxDpi = 1
; ===============================================================================================================================

; #INTERNAL_USE_ONLY GLOBAL VARIABLES # =========================================================================================
Global $__DM_g_b24H2Plus = __DM_DarkThemeAvailability()
;$__DM_g_b24H2Plus = False ; just for debugging, simulating older OS during testing
Global $__DM_g_hDateProc, $__DM_g_pDateProc, $__DM_g_hDateProcOld
Global $__DM_g_bHover = False
Global $__DM_g_iGripPos = 1
Global $__DM_g_hStatus, $__DM_g_hGripSize, $__DM_g_hSizebox, $__DM_g_hDots, $__DM_g_iHeight, $__DM_g_aRatioW, $__DM_g_hCursor
Global $__DM_g_aMenuText = []
Global $__DM_g_iDpiScale = 1
Global $__DM_g_iDpi = 100
Global $__DM_g_hMenuFont = 0
Global $__DM_g_aGroupInTab[0]
Global $__DM_g_a_hDateTime[0]
Global $__DM_g_iTimerCycles = 0

Global $__DM_g_hBrushCtrl = 0, $__DM_g_hBrushGui = 0, $__DM_g_hBrushSizebox = 0
Global $__DM_g_hBrushBtn = 0, $__DM_g_hBrushBtnHov = 0, $__DM_g_hBrushBtnSel = 0
Global $__DM_g_hBrushMenuBk = 0, $__DM_g_hBrushMenuSel = 0, $__DM_g_hBrushMenuHot = 0
Global $__DM_g_hBrushAccent = 0, $__DM_g_hBrushAccentHot = 0
Global $__DM_g_hBrushTab = 0, $__DM_g_hBrushTabSel = 0, $__DM_g_hBrushTabBk = 0
Global $__DM_g_hBrushGray = 0
Global $__DM_g_hBrushMsgBoxTop = 0, $__DM_g_hBrushMsgBoxBottom = 0
Global $__DM_g_iBrushHdr = 0, $__DM_g_iBrushHdrHot = 0, $__DM_g_iBrushHdrSel = 0
Global $__DM_g_iBrushBorder = 0

Global $__DM_g_hPenBtnBor = 0, $__DM_g_hPenGui = 0, $__DM_g_hPenBorder = 0, $__DM_g_hPenBorderSel = 0
Global $__DM_g_hPenAccent = 0, $__DM_g_hPenBlack = 0
Global $__DM_g_hPen2Accent = 0, $__DM_g_hPen2Border = 0, $__DM_g_hPen2BorderSel = 0
; ===============================================================================================================================

; #GLOBAL CONSTANTS# ============================================================================================================
Global Const $TVS_EX_DOUBLEBUFFER = 0x0004

Global Const $DWMWCP_DEFAULT = 0
Global Const $DWMWCP_DONOTROUND = 1
Global Const $DWMWCP_ROUND = 2
Global Const $DWMWCP_ROUNDSMALL = 3

Global Const $BP_RADIOBUTTON = 2
Global Const $BP_CHECKBOX = 3
Global Const $BP_GROUPBOX = 4

Global Const $GBS_NORMAL = 1
Global Const $GBS_DISABLED = 2

Global Const $PBST_NORMAL = 0x0001
Global Const $PBST_ERROR  = 0x0002
Global Const $PBST_PAUSED = 0x0003

Global Const $HCBT_MOVESIZE = 0
Global Const $HCBT_MINMAX = 1
Global Const $HCBT_QS = 2
Global Const $HCBT_CREATEWND = 3
Global Const $HCBT_DESTROYWND = 4
Global Const $HCBT_ACTIVATE = 5
Global Const $HCBT_CLICKSKIPPED = 6
Global Const $HCBT_KEYSKIPPED = 7
Global Const $HCBT_SYSCOMMAND = 8
Global Const $HCBT_SETFOCUS = 9

Global Const $CBS_UNCHECKEDNORMAL = 1
Global Const $CBS_UNCHECKEDHOT = 2
Global Const $CBS_UNCHECKEDPRESSED = 3
Global Const $CBS_UNCHECKEDDISABLED = 4
Global Const $CBS_CHECKEDNORMAL = 5
Global Const $CBS_CHECKEDHOT = 6
Global Const $CBS_CHECKEDPRESSED = 7
Global Const $CBS_CHECKEDDISABLED = 8
Global Const $CBS_MIXEDNORMAL = 9
Global Const $CBS_MIXEDHOT = 10
Global Const $CBS_MIXEDPRESSED = 11
Global Const $CBS_MIXEDDISABLED = 12

Global Const $RBS_UNCHECKEDNORMAL = 1
Global Const $RBS_UNCHECKEDHOT = 2
Global Const $RBS_UNCHECKEDPRESSED = 3
Global Const $RBS_UNCHECKEDDISABLED = 4
Global Const $RBS_CHECKEDNORMAL = 5
Global Const $RBS_CHECKEDHOT = 6
Global Const $RBS_CHECKEDPRESSED = 7
Global Const $RBS_CHECKEDDISABLED = 8

Global Const $ODT_MENU = 1
Global Const $ODS_SELECTED = 0x0001
Global Const $ODS_DISABLED = 0x0004
Global Const $ODS_HOTLIGHT = 0x0040
Global Const $PRF_CLIENT = 0x0004

Global Const $TBCDRF_USECDCOLORS = 0x800000
Global Const $TBCDRF_NOBACKGROUND = 0x400000
Global Const $TBCDRF_HILITEHOTTRACK = 0x20000

Global Const $tagNMTBCUSTOMDRAW = $tagNMHDR & ";dword dwDrawStage;handle hdc;" & $tagRECT & ";dword_ptr dwItemSpec;uint uItemState;lparam lItemlParam;" & _
		"ptr hbrMonoDither;ptr hbrLines;ptr hpenLines;dword clrText;dword clrMark;dword clrTextHighlight;dword clrBtnFace;dword clrBtnHighlight;dword clrHighlightHotTrack;" & _
		"long TextLeft;long TextTop;long TextRight;long TextBottom;int nStringBkMode;int nHLStringBkMode;int iListGap;"

Global Const $__DM_tagNMCUSTOMDRAW = _
		$tagNMHDR & ";" & _                                    ; Contains NM_CUSTOMDRAW / NMHDR header among other things
		"dword dwDrawStage;" & _                               ; Current drawing stage (CDDS_*)
		"handle hdc;" & _                                      ; Device Context Handle
		"long left;long top;long right;long bottom;" & _       ; Drawing rectangle
		"dword_ptr dwItemSpec;" & _                            ; Item index or other info (depending on the control)
		"uint uItemState;" & _                                 ; State Flags (CDIS_SELECTED, CDIS_FOCUS etc.)
		"lparam lItemlParam"                                   ; lParam set by the item (e.g., via LVITEM.lParam)

Global Const $__DM_g_Style_Gui[32][2] = _
		[[0x80000000, 'WS_POPUP'], _
		[0x40000000, 'WS_CHILD'], _
		[0x20000000, 'WS_MINIMIZE'], _
		[0x10000000, 'WS_VISIBLE'], _
		[0x08000000, 'WS_DISABLED'], _
		[0x04000000, 'WS_CLIPSIBLINGS'], _
		[0x02000000, 'WS_CLIPCHILDREN'], _
		[0x01000000, 'WS_MAXIMIZE'], _
		[0x00CF0000, 'WS_OVERLAPPEDWINDOW'], _ ; (WS_CAPTION | WS_SYSMENU | WS_SIZEBOX | WS_MINIMIZEBOX | WS_MAXIMIZEBOX) aka 'WS_TILEDWINDOW'
		[0x00C00000, 'WS_CAPTION'], _      ; (WS_BORDER | WS_DLGFRAME)
		[0x00800000, 'WS_BORDER'], _
		[0x00400000, 'WS_DLGFRAME'], _
		[0x00200000, 'WS_VSCROLL'], _
		[0x00100000, 'WS_HSCROLL'], _
		[0x00080000, 'WS_SYSMENU'], _
		[0x00040000, 'WS_SIZEBOX'], _
		[0x00020000, '! WS_MINIMIZEBOX ! WS_GROUP'], _ ; ! GUI ! Control
		[0x00010000, '! WS_MAXIMIZEBOX ! WS_TABSTOP'], _ ; ! GUI ! Control
		[0x00002000, 'DS_CONTEXTHELP'], _
		[0x00001000, 'DS_CENTERMOUSE'], _
		[0x00000800, 'DS_CENTER'], _
		[0x00000400, 'DS_CONTROL'], _
		[0x00000200, 'DS_SETFOREGROUND'], _
		[0x00000100, 'DS_NOIDLEMSG'], _
		[0x00000080, 'DS_MODALFRAME'], _
		[0x00000040, 'DS_SETFONT'], _
		[0x00000020, 'DS_LOCALEDIT'], _
		[0x00000010, 'DS_NOFAILCREATE'], _
		[0x00000008, 'DS_FIXEDSYS'], _
		[0x00000004, 'DS_3DLOOK'], _
		[0x00000002, 'DS_SYSMODAL'], _
		[0x00000001, 'DS_ABSALIGN']]
;
; [0x80880000, 'WS_POPUPWINDOW']
; [0x20000000, 'WS_ICONIC']
; [0x00040000, 'WS_THICKFRAME']
;
; [0x00000000, 'WS_OVERLAPPED'] ; also named 'WS_TILED'

Global Const $__DM_g_Style_GuiExtended[21][2] = _
		[[0x08000000, 'WS_EX_NOACTIVATE'], _
		[0x02000000, 'WS_EX_COMPOSITED'], _
		[0x00400000, 'WS_EX_LAYOUTRTL'], _
		[0x00100000, '! WS_EX_NOINHERITLAYOUT ! GUI_WS_EX_PARENTDRAG'], _ ; ! GUI ! Control (label or pic, AutoIt "draggable" feature on 2 controls)
		[0x00080000, 'WS_EX_LAYERED'], _
		[0x00040000, 'WS_EX_APPWINDOW'], _
		[0x00020000, 'WS_EX_STATICEDGE'], _
		[0x00010000, 'WS_EX_CONTROLPARENT'], _ ; AutoIt adds a "draggable" feature to this GUI extended style behavior
		[0x00004000, 'WS_EX_LEFTSCROLLBAR'], _
		[0x00002000, 'WS_EX_RTLREADING'], _
		[0x00001000, 'WS_EX_RIGHT'], _
		[0x00000400, 'WS_EX_CONTEXTHELP'], _
		[0x00000200, 'WS_EX_CLIENTEDGE'], _
		[0x00000100, 'WS_EX_WINDOWEDGE'], _
		[0x00000080, 'WS_EX_TOOLWINDOW'], _
		[0x00000040, 'WS_EX_MDICHILD'], _
		[0x00000020, 'WS_EX_TRANSPARENT'], _
		[0x00000010, 'WS_EX_ACCEPTFILES'], _
		[0x00000008, 'WS_EX_TOPMOST'], _
		[0x00000004, 'WS_EX_NOPARENTNOTIFY'], _
		[0x00000001, 'WS_EX_DLGMODALFRAME']]
;
; [0x00000300, 'WS_EX_OVERLAPPEDWINDOW']
; [0x00000188, 'WS_EX_PALETTEWINDOW']
;
; [0x00000000, 'WS_EX_LEFT']
; [0x00000000, 'WS_EX_LTRREADING']
; [0x00000000, 'WS_EX_RIGHTSCROLLBAR']

Global Const $__DM_g_Style_Avi[5][2] = _
		[[0x0010, 'ACS_NONTRANSPARENT'], _
		[0x0008, 'ACS_TIMER'], _
		[0x0004, 'ACS_AUTOPLAY'], _
		[0x0002, 'ACS_TRANSPARENT'], _
		[0x0001, 'ACS_CENTER']]

Global Const $__DM_g_Style_Button[28][2] = _
		[[0x8000, 'BS_FLAT'], _
		[0x4000, 'BS_NOTIFY'], _
		[0x2000, 'BS_MULTILINE'], _
		[0x1000, 'BS_PUSHLIKE'], _
		[0x0C00, 'BS_VCENTER'], _
		[0x0800, 'BS_BOTTOM'], _
		[0x0400, 'BS_TOP'], _
		[0x0300, 'BS_CENTER'], _
		[0x0200, 'BS_RIGHT'], _
		[0x0100, 'BS_LEFT'], _
		[0x0080, 'BS_BITMAP'], _
		[0x0040, 'BS_ICON'], _
		[0x0020, 'BS_RIGHTBUTTON'], _
		[0x000F, 'BS_DEFCOMMANDLINK'], _
		[0x000E, 'BS_COMMANDLINK'], _
		[0x000D, 'BS_DEFSPLITBUTTON'], _
		[0x000C, 'BS_SPLITBUTTON'], _
		[0x000B, 'BS_OWNERDRAW'], _
		[0x000A, 'BS_PUSHBOX'], _
		[0x0009, 'BS_AUTORADIOBUTTON'], _
		[0x0008, 'BS_USERBUTTON'], _
		[0x0007, 'BS_GROUPBOX'], _
		[0x0006, 'BS_AUTO3STATE'], _
		[0x0005, 'BS_3STATE'], _
		[0x0004, 'BS_RADIOBUTTON'], _
		[0x0003, 'BS_AUTOCHECKBOX'], _
		[0x0002, 'BS_CHECKBOX'], _
		[0x0001, 'BS_DEFPUSHBUTTON']]

Global Const $__DM_g_Style_Combo[13][2] = _
		[[0x4000, 'CBS_LOWERCASE'], _
		[0x2000, 'CBS_UPPERCASE'], _
		[0x0800, 'CBS_DISABLENOSCROLL'], _
		[0x0400, 'CBS_NOINTEGRALHEIGHT'], _
		[0x0200, 'CBS_HASSTRINGS'], _
		[0x0100, 'CBS_SORT'], _
		[0x0080, 'CBS_OEMCONVERT'], _
		[0x0040, 'CBS_AUTOHSCROLL'], _
		[0x0020, 'CBS_OWNERDRAWVARIABLE'], _
		[0x0010, 'CBS_OWNERDRAWFIXED'], _
		[0x0003, 'CBS_DROPDOWNLIST'], _
		[0x0002, 'CBS_DROPDOWN'], _
		[0x0001, 'CBS_SIMPLE']]

Global Const $__DM_g_Style_Common[12][2] = _ ; "for rebar controls, toolbar controls, and status windows (msdn)"
		[[0x0083, 'CCS_RIGHT'], _
		[0x0082, 'CCS_NOMOVEX'], _
		[0x0081, 'CCS_LEFT'], _
		[0x0080, 'CCS_VERT'], _
		[0x0040, 'CCS_NODIVIDER'], _
		[0x0020, 'CCS_ADJUSTABLE'], _
		[0x0010, 'CCS_NOHILITE'], _
		[0x0008, 'CCS_NOPARENTALIGN'], _
		[0x0004, 'CCS_NORESIZE'], _
		[0x0003, 'CCS_BOTTOM'], _
		[0x0002, 'CCS_NOMOVEY'], _
		[0x0001, 'CCS_TOP']]

Global Const $__DM_g_Style_DateTime[7][2] = _
		[[0x0020, 'DTS_RIGHTALIGN'], _
		[0x0010, 'DTS_APPCANPARSE'], _
		[0x000C, 'DTS_SHORTDATECENTURYFORMAT'], _
		[0x0009, 'DTS_TIMEFORMAT'], _
		[0x0004, 'DTS_LONGDATEFORMAT'], _
		[0x0002, 'DTS_SHOWNONE'], _
		[0x0001, 'DTS_UPDOWN']]
;
; [0x0000, 'DTS_SHORTDATEFORMAT']

Global Const $__DM_g_Style_Edit[13][2] = _
		[[0x2000, 'ES_NUMBER'], _
		[0x1000, 'ES_WANTRETURN'], _
		[0x0800, 'ES_READONLY'], _
		[0x0400, 'ES_OEMCONVERT'], _
		[0x0100, 'ES_NOHIDESEL'], _
		[0x0080, 'ES_AUTOHSCROLL'], _
		[0x0040, 'ES_AUTOVSCROLL'], _
		[0x0020, 'ES_PASSWORD'], _
		[0x0010, 'ES_LOWERCASE'], _
		[0x0008, 'ES_UPPERCASE'], _
		[0x0004, 'ES_MULTILINE'], _
		[0x0002, 'ES_RIGHT'], _
		[0x0001, 'ES_CENTER']]

Global Const $__DM_g_Style_Header[10][2] = _
		[[0x1000, 'HDS_OVERFLOW'], _
		[0x0800, 'HDS_NOSIZING'], _
		[0x0400, 'HDS_CHECKBOXES'], _
		[0x0200, 'HDS_FLAT'], _
		[0x0100, 'HDS_FILTERBAR'], _
		[0x0080, 'HDS_FULLDRAG'], _
		[0x0040, 'HDS_DRAGDROP'], _
		[0x0008, 'HDS_HIDDEN'], _
		[0x0004, 'HDS_HOTTRACK'], _
		[0x0002, 'HDS_BUTTONS']]
;
; [0x0000, '$HDS_HORZ']

Global Const $__DM_g_Style_ListBox[16][2] = _
		[[0x8000, 'LBS_COMBOBOX'], _
		[0x4000, 'LBS_NOSEL'], _
		[0x2000, 'LBS_NODATA'], _
		[0x1000, 'LBS_DISABLENOSCROLL'], _
		[0x0800, 'LBS_EXTENDEDSEL'], _
		[0x0400, 'LBS_WANTKEYBOARDINPUT'], _
		[0x0200, 'LBS_MULTICOLUMN'], _
		[0x0100, 'LBS_NOINTEGRALHEIGHT'], _
		[0x0080, 'LBS_USETABSTOPS'], _
		[0x0040, 'LBS_HASSTRINGS'], _
		[0x0020, 'LBS_OWNERDRAWVARIABLE'], _
		[0x0010, 'LBS_OWNERDRAWFIXED'], _
		[0x0008, 'LBS_MULTIPLESEL'], _
		[0x0004, 'LBS_NOREDRAW'], _
		[0x0002, 'LBS_SORT'], _
		[0x0001, 'LBS_NOTIFY']]
;
; [0xA00003, 'LBS_STANDARD'] ; i.e. (LBS_NOTIFY | LBS_SORT | WS_VSCROLL | WS_BORDER) help file correct, ListBoxConstants.au3 incorrect

Global Const $__DM_g_Style_ListView[17][2] = _
		[[0x8000, 'LVS_NOSORTHEADER'], _
		[0x4000, 'LVS_NOCOLUMNHEADER'], _
		[0x2000, 'LVS_NOSCROLL'], _
		[0x1000, 'LVS_OWNERDATA'], _
		[0x0800, 'LVS_ALIGNLEFT'], _
		[0x0400, 'LVS_OWNERDRAWFIXED'], _
		[0x0200, 'LVS_EDITLABELS'], _
		[0x0100, 'LVS_AUTOARRANGE'], _
		[0x0080, 'LVS_NOLABELWRAP'], _
		[0x0040, 'LVS_SHAREIMAGELISTS'], _
		[0x0020, 'LVS_SORTDESCENDING'], _
		[0x0010, 'LVS_SORTASCENDING'], _
		[0x0008, 'LVS_SHOWSELALWAYS'], _
		[0x0004, 'LVS_SINGLESEL'], _
		[0x0003, 'LVS_LIST'], _
		[0x0002, 'LVS_SMALLICON'], _
		[0x0001, 'LVS_REPORT']]
;
; [0x0000, 'LVS_ICON']
; [0x0000, 'LVS_ALIGNTOP']

Global Const $__DM_g_Style_ListViewExtended[20][2] = _
		[[0x00100000, 'LVS_EX_SIMPLESELECT'], _
		[0x00080000, 'LVS_EX_SNAPTOGRID'], _
		[0x00020000, 'LVS_EX_HIDELABELS'], _
		[0x00010000, 'LVS_EX_DOUBLEBUFFER'], _
		[0x00008000, 'LVS_EX_BORDERSELECT'], _
		[0x00004000, 'LVS_EX_LABELTIP'], _
		[0x00002000, 'LVS_EX_MULTIWORKAREAS'], _
		[0x00001000, 'LVS_EX_UNDERLINECOLD'], _
		[0x00000800, 'LVS_EX_UNDERLINEHOT'], _
		[0x00000400, 'LVS_EX_INFOTIP'], _
		[0x00000200, 'LVS_EX_REGIONAL'], _
		[0x00000100, 'LVS_EX_FLATSB'], _
		[0x00000080, 'LVS_EX_TWOCLICKACTIVATE'], _
		[0x00000040, 'LVS_EX_ONECLICKACTIVATE'], _
		[0x00000020, 'LVS_EX_FULLROWSELECT'], _
		[0x00000010, 'LVS_EX_HEADERDRAGDROP'], _
		[0x00000008, 'LVS_EX_TRACKSELECT'], _
		[0x00000004, 'LVS_EX_CHECKBOXES'], _
		[0x00000002, 'LVS_EX_SUBITEMIMAGES'], _
		[0x00000001, 'LVS_EX_GRIDLINES']]

Global Const $__DM_g_Style_MonthCal[8][2] = _
		[[0x0100, 'MCS_NOSELCHANGEONNAV'], _
		[0x0080, 'MCS_SHORTDAYSOFWEEK'], _
		[0x0040, 'MCS_NOTRAILINGDATES'], _
		[0x0010, 'MCS_NOTODAY'], _
		[0x0008, 'MCS_NOTODAYCIRCLE'], _
		[0x0004, 'MCS_WEEKNUMBERS'], _
		[0x0002, 'MCS_MULTISELECT'], _
		[0x0001, 'MCS_DAYSTATE']]

Global Const $__DM_g_Style_Pager[3][2] = _
		[[0x0004, 'PGS_DRAGNDROP'], _
		[0x0002, 'PGS_AUTOSCROLL'], _
		[0x0001, 'PGS_HORZ']]
;
; [0x0000, 'PGS_VERT']

Global Const $__DM_g_Style_Progress[4][2] = _
		[[0x0010, 'PBS_SMOOTHREVERSE'], _
		[0x0008, 'PBS_MARQUEE'], _
		[0x0004, 'PBS_VERTICAL'], _
		[0x0001, 'PBS_SMOOTH']]

Global Const $__DM_g_Style_Rebar[8][2] = _
		[[0x8000, 'RBS_DBLCLKTOGGLE'], _
		[0x4000, 'RBS_VERTICALGRIPPER'], _
		[0x2000, 'RBS_AUTOSIZE'], _
		[0x1000, 'RBS_REGISTERDROP'], _
		[0x0800, 'RBS_FIXEDORDER'], _
		[0x0400, 'RBS_BANDBORDERS'], _
		[0x0200, 'RBS_VARHEIGHT'], _
		[0x0100, 'RBS_TOOLTIPS']]

Global Const $__DM_g_Style_RichEdit[8][2] = _      ; will also use plenty (not all) of Edit styles
		[[0x01000000, 'ES_SELECTIONBAR'], _
		[0x00400000, 'ES_VERTICAL'], _      ; Asian-language support only (msdn)
		[0x00080000, 'ES_NOIME'], _         ; ditto
		[0x00040000, 'ES_SELFIME'], _       ; ditto
		[0x00008000, 'ES_SAVESEL'], _
		[0x00004000, 'ES_SUNKEN'], _
		[0x00002000, 'ES_DISABLENOSCROLL'], _ ; same value as 'ES_NUMBER' => issue ?
		[0x00000008, 'ES_NOOLEDRAGDROP']]   ; same value as 'ES_UPPERCASE' but RichRdit controls do not support 'ES_UPPERCASE' style (msdn)

Global Const $__DM_g_Style_Scrollbar[5][2] = _
		[[0x0010, 'SBS_SIZEGRIP'], _
		[0x0008, 'SBS_SIZEBOX'], _
		[0x0004, 'SBS_RIGHTALIGN or SBS_BOTTOMALIGN'], _ ; i.e. use SBS_RIGHTALIGN with SBS_VERT, use SBS_BOTTOMALIGN with SBS_HORZ (msdn)
		[0x0002, 'SBS_LEFTALIGN or SBS_TOPALIGN'], _ ; i.e. use SBS_LEFTALIGN  with SBS_VERT, use SBS_TOPALIGN    with SBS_HORZ (msdn)
		[0x0001, 'SBS_VERT']]
;
; [0x0000, 'SBS_HORZ']

Global Const $__DM_g_Style_Slider[13][2] = _ ; i.e. trackbar
		[[0x1000, 'TBS_TRANSPARENTBKGND'], _
		[0x0800, 'TBS_NOTIFYBEFOREMOVE'], _
		[0x0400, 'TBS_DOWNISLEFT'], _
		[0x0200, 'TBS_REVERSED'], _
		[0x0100, 'TBS_TOOLTIPS'], _
		[0x0080, 'TBS_NOTHUMB'], _
		[0x0040, 'TBS_FIXEDLENGTH'], _
		[0x0020, 'TBS_ENABLESELRANGE'], _
		[0x0010, 'TBS_NOTICKS'], _
		[0x0008, 'TBS_BOTH'], _
		[0x0004, 'TBS_LEFT or TBS_TOP'], _ ; i.e. TBS_LEFT tick marks when vertical slider, or TBS_TOP tick marks when horizontal slider
		[0x0002, 'TBS_VERT'], _
		[0x0001, 'TBS_AUTOTICKS']]
;
; [0x0000, 'TBS_RIGHT']
; [0x0000, 'TBS_BOTTOM']
; [0x0000, 'TBS_HORZ']

Global Const $__DM_g_Style_Static[29][2] = _
		[[0xC000, 'SS_WORDELLIPSIS'], _
		[0x8000, 'SS_PATHELLIPSIS'], _
		[0x4000, 'SS_ENDELLIPSIS'], _
		[0x2000, 'SS_EDITCONTROL'], _
		[0x1000, 'SS_SUNKEN'], _
		[0x0800, 'SS_REALSIZEIMAGE'], _
		[0x0400, 'SS_RIGHTJUST'], _
		[0x0200, 'SS_CENTERIMAGE'], _
		[0x0100, 'SS_NOTIFY'], _
		[0x0080, 'SS_NOPREFIX'], _
		[0x0040, 'SS_REALSIZECONTROL'], _
		[0x0012, 'SS_ETCHEDFRAME'], _
		[0x0011, 'SS_ETCHEDVERT'], _
		[0x0010, 'SS_ETCHEDHORZ'], _
		[0x000F, 'SS_ENHMETAFILE'], _
		[0x000E, 'SS_BITMAP'], _
		[0x000D, 'SS_OWNERDRAW'], _
		[0x000C, 'SS_LEFTNOWORDWRAP'], _
		[0x000B, 'SS_SIMPLE'], _
		[0x000A, 'SS_USERITEM'], _
		[0x0009, 'SS_WHITEFRAME'], _
		[0x0008, 'SS_GRAYFRAME'], _
		[0x0007, 'SS_BLACKFRAME'], _
		[0x0006, 'SS_WHITERECT'], _
		[0x0005, 'SS_GRAYRECT'], _
		[0x0004, 'SS_BLACKRECT'], _
		[0x0003, 'SS_ICON'], _
		[0x0002, 'SS_RIGHT'], _
		[0x0001, 'SS_CENTER']]
;
; [0x0000, 'SS_LEFT']

Global Const $__DM_g_Style_StatusBar[2][2] = _
		[[0x0800, 'SBARS_TOOLTIPS'], _
		[0x0100, 'SBARS_SIZEGRIP']]
;
; [0x0800, 'SBT_TOOLTIPS']

Global Const $__DM_g_Style_Tab[17][2] = _
		[[0x8000, 'TCS_FOCUSNEVER'], _
		[0x4000, 'TCS_TOOLTIPS'], _
		[0x2000, 'TCS_OWNERDRAWFIXED'], _
		[0x1000, 'TCS_FOCUSONBUTTONDOWN'], _
		[0x0800, 'TCS_RAGGEDRIGHT'], _
		[0x0400, 'TCS_FIXEDWIDTH'], _
		[0x0200, 'TCS_MULTILINE'], _
		[0x0100, 'TCS_BUTTONS'], _
		[0x0080, 'TCS_VERTICAL'], _
		[0x0040, 'TCS_HOTTRACK'], _
		[0x0020, 'TCS_FORCELABELLEFT'], _
		[0x0010, 'TCS_FORCEICONLEFT'], _
		[0x0008, 'TCS_FLATBUTTONS'], _
		[0x0004, 'TCS_MULTISELECT'], _
		[0x0002, 'TCS_RIGHT'], _
		[0x0002, 'TCS_BOTTOM'], _
		[0x0001, 'TCS_SCROLLOPPOSITE']]
;
; [0x0000, 'TCS_TABS']
; [0x0000, 'TCS_SINGLELINE']
; [0x0000, 'TCS_RIGHTJUSTIFY']

Global Const $__DM_g_Style_Toolbar[8][2] = _
		[[0x8000, 'TBSTYLE_TRANSPARENT'], _
		[0x4000, 'TBSTYLE_REGISTERDROP'], _
		[0x2000, 'TBSTYLE_CUSTOMERASE'], _
		[0x1000, 'TBSTYLE_LIST'], _
		[0x0800, 'TBSTYLE_FLAT'], _
		[0x0400, 'TBSTYLE_ALTDRAG'], _
		[0x0200, 'TBSTYLE_WRAPABLE'], _
		[0x0100, 'TBSTYLE_TOOLTIPS']]

Global Const $__DM_g_Style_TreeView[16][2] = _
		[[0x8000, 'TVS_NOHSCROLL'], _
		[0x4000, 'TVS_NONEVENHEIGHT'], _
		[0x2000, 'TVS_NOSCROLL'], _
		[0x1000, 'TVS_FULLROWSELECT'], _
		[0x0800, 'TVS_INFOTIP'], _
		[0x0400, 'TVS_SINGLEEXPAND'], _
		[0x0200, 'TVS_TRACKSELECT'], _
		[0x0100, 'TVS_CHECKBOXES'], _
		[0x0080, 'TVS_NOTOOLTIPS'], _
		[0x0040, 'TVS_RTLREADING'], _
		[0x0020, 'TVS_SHOWSELALWAYS'], _
		[0x0010, 'TVS_DISABLEDRAGDROP'], _
		[0x0008, 'TVS_EDITLABELS'], _
		[0x0004, 'TVS_LINESATROOT'], _
		[0x0002, 'TVS_HASLINES'], _
		[0x0001, 'TVS_HASBUTTONS']]

Global Const $__DM_g_Style_UpDown[9][2] = _
		[[0x0100, 'UDS_HOTTRACK'], _
		[0x0080, 'UDS_NOTHOUSANDS'], _
		[0x0040, 'UDS_HORZ'], _
		[0x0020, 'UDS_ARROWKEYS'], _
		[0x0010, 'UDS_AUTOBUDDY'], _
		[0x0008, 'UDS_ALIGNLEFT'], _
		[0x0004, 'UDS_ALIGNRIGHT'], _
		[0x0002, 'UDS_SETBUDDYINT'], _
		[0x0001, 'UDS_WRAP']]

; ===============================================================================================================================

; GDI+ Startup
_GDIPlus_Startup()

OnAutoItExitRegister("__GUIDarkTheme_OnExit")

_WinAPI_SetPreferredAppMode($APPMODE_ALLOWDARK)

; Early creation of Dark MsgBox brushes
If Not $__DM_g_hBrushMsgBoxTop Then $__DM_g_hBrushMsgBoxTop = _WinAPI_CreateSolidBrush(_WinAPI_SwitchColor($__DM_g_iMsgBoxTopColor))
If Not $__DM_g_hBrushMsgBoxBottom Then $__DM_g_hBrushMsgBoxBottom = _WinAPI_CreateSolidBrush(_WinAPI_SwitchColor($__DM_g_iMsgBoxBottomColor))

; #FUNCTION# ====================================================================================================================
; Author.........: WildByDesign
; ===============================================================================================================================
Func __GUIDarkTheme_OnExit()
	If $__DM_g_hMenuFont Then _WinAPI_DeleteObject($__DM_g_hMenuFont)
	; statusbar
	If $__DM_g_hDots Then _GDIPlus_BitmapDispose($__DM_g_hDots)
	If $__DM_g_hCursor Then _WinAPI_DestroyCursor($__DM_g_hCursor)
	; dark msgbox
	If $__DM_g_hMsgBoxSubProc Then DllCallbackFree($__DM_g_hMsgBoxSubProc)
	__GUIDarkTheme_SubclassCleanup()
	__GUIDarkTheme_BrushCleanup()
	__GUIDarkTheme_PenCleanup()
	_GDIPlus_Shutdown()
EndFunc   ;==>__GUIDarkTheme_OnExit

; #FUNCTION# ====================================================================================================================
; Author.........: argumentum
; Modified.......: WildByDesign
; ===============================================================================================================================
Func __GUIDarkTheme_GroupProc($hWnd, $iMsg, $wParam, $lParam, $iID, $pData)
    Switch $iMsg
        Case $WM_ERASEBKGND
            Return 1

        Case $WM_PAINT
            Local $tPaint = DllStructCreate($tagPAINTSTRUCT)
            Local $hDC = _WinAPI_BeginPaint($hWnd, $tPaint)

            Local $tClient = _WinAPI_GetClientRect($hWnd)
            Local $iW = $tClient.Right
            Local $iH = $tClient.Bottom

            Local $hMemDC = _WinAPI_CreateCompatibleDC($hDC)
            Local $hBitmap = _WinAPI_CreateCompatibleBitmap($hDC, $iW, $iH)
            Local $hOldBmp = _WinAPI_SelectObject($hMemDC, $hBitmap)

            Local $hFont = _SendMessage($hWnd, $WM_GETFONT, 0, 0)
            If Not $hFont Then $hFont = _WinAPI_GetStockObject($DEFAULT_GUI_FONT)
            Local $hOldFont = _WinAPI_SelectObject($hMemDC, $hFont)

            Local $sText = _WinAPI_GetWindowText($hWnd)
            Local $tTextSize = _WinAPI_GetTextExtentPoint32($hMemDC, $sText)
            Local $iTextWidth = $tTextSize.X
            Local $iTextHeight = $tTextSize.Y

			; exclude clip testing
			Local $tCR = _WinAPI_GetClientRect($hWnd)
			$tCR.Top = $tCR.Top + $iTextHeight + 2
			$tCR.Bottom = $tCR.Bottom - 5
			$tCR.Left = $tCR.Left + 5
			$tCR.Right = $tCR.Right - 5
			_WinAPI_ExcludeClipRect($hDC, $tCR)
			_WinAPI_ExcludeClipRect($hMemDC, $tCR)

            _WinAPI_DrawThemeParentBackground($hWnd, $hMemDC, $tClient)

            Local $hGraphics = _GDIPlus_GraphicsCreateFromHDC($hMemDC)
            _GDIPlus_GraphicsSetSmoothingMode($hGraphics, 2)

            Local $iRadius = 1
            Local $iX = 0
            Local $iY = Int($iTextHeight / 2)
            Local $iWidth = $iW - 1 - $iX
            Local $iHeight = $iH - 1 - $iY - 1

            Local $hPath = _GDIPlus_PathCreate()
            _GDIPlus_PathAddLine($hPath, $iX + $iRadius, $iY, $iX + $iWidth - $iRadius, $iY)
            _GDIPlus_PathAddArc($hPath, $iX + $iWidth - ($iRadius * 2), $iY, $iRadius * 2, $iRadius * 2, 270, 90)
            _GDIPlus_PathAddLine($hPath, $iX + $iWidth, $iY + $iRadius, $iX + $iWidth, $iY + $iHeight - $iRadius)
            _GDIPlus_PathAddArc($hPath, $iX + $iWidth - ($iRadius * 2), $iY + $iHeight - ($iRadius * 2), $iRadius * 2, $iRadius * 2, 0, 90)
            _GDIPlus_PathAddLine($hPath, $iX + $iWidth - $iRadius, $iY + $iHeight, $iX + $iRadius, $iY + $iHeight)
            _GDIPlus_PathAddArc($hPath, $iX, $iY + $iHeight - ($iRadius * 2), $iRadius * 2, $iRadius * 2, 90, 90)
            _GDIPlus_PathAddLine($hPath, $iX, $iY + $iHeight - $iRadius, $iX, $iY + $iRadius)
            _GDIPlus_PathAddArc($hPath, $iX, $iY, $iRadius * 2, $iRadius * 2, 180, 90)
            _GDIPlus_PathCloseFigure($hPath)

            If $sText <> "" Then
                Local $hRegion = _GDIPlus_RegionCreate()
                _GDIPlus_RegionCombineRect($hRegion, 7, 0, $iTextWidth + 4, $iTextHeight, 0)
                _GDIPlus_GraphicsSetClipRegion($hGraphics, $hRegion, 3)
                _GDIPlus_RegionDispose($hRegion)
            EndIf

            Local $hPen = _GDIPlus_PenCreate(0xFF505050, 1)
            _GDIPlus_GraphicsDrawPath($hGraphics, $hPath, $hPen)

            _GDIPlus_GraphicsResetClip($hGraphics)
            _GDIPlus_PenDispose($hPen)
            _GDIPlus_PathDispose($hPath)

            If $sText <> "" Then
                Local $hTheme = _WinAPI_OpenThemeData($hWnd, "DarkMode_Explorer::Button")
                Local $tDTTOPTS = DllStructCreate($tagDTTOPTS)
                DllStructSetData($tDTTOPTS, 'Size', DllStructGetSize($tDTTOPTS))
                DllStructSetData($tDTTOPTS, 'Flags', $DTT_TEXTCOLOR)
                DllStructSetData($tDTTOPTS, 'clrText', 0xFFFFFF)

                Local $iTextFlags = BitOR($DT_SINGLELINE, $DT_LEFT, $DT_TOP)
                Local $tDrawTextRect = _WinAPI_CreateRectEx(9, 0, $iTextWidth, $iTextHeight)

                _WinAPI_DrawThemeTextEx($hTheme, $BP_GROUPBOX, $GBS_NORMAL, $hMemDC, $sText, $tDrawTextRect, $iTextFlags, $tDTTOPTS)
                _WinAPI_CloseThemeData($hTheme)
            EndIf

            _GDIPlus_GraphicsDispose($hGraphics)

            _WinAPI_BitBlt($hDC, 0, 0, $iW, $iH, $hMemDC, 0, 0, $SRCCOPY)

            _WinAPI_SelectObject($hMemDC, $hOldFont)
            _WinAPI_SelectObject($hMemDC, $hOldBmp)
            _WinAPI_DeleteObject($hBitmap)
            _WinAPI_DeleteDC($hMemDC)

            _WinAPI_EndPaint($hWnd, $tPaint)
            Return 0

    EndSwitch

    Return __WinAPI_DefSubclassProc($hWnd, $iMsg, $wParam, $lParam)
EndFunc   ;==>__GUIDarkTheme_GroupProc

; #FUNCTION# ====================================================================================================================
; Author.........: WildByDesign
; ===============================================================================================================================
Func __GUIDarkTheme_ButtonProc($hWnd, $iMsg, $wParam, $lParam, $iID, $pData)
	#forceref $iID
    Switch $iMsg
        Case $WM_ERASEBKGND
            Return 1 ; Prevent background erasing to avoid flickering

        Case $WM_PAINT
			Local $iPartID = $__DM_g_aButtonSub[$pData][0]
			Local $sStyles = $__DM_g_aButtonSub[$pData][1]
			Local $bCtrlInTab = $__DM_g_aButtonSub[$pData][2]

            Local $hTheme = _WinAPI_OpenThemeData($hWnd, "DarkMode_Explorer::Button")
            Local $iStateID = 0

            Local Const $BST_HOT = 0x0200

            Local $tPaint = DllStructCreate($tagPAINTSTRUCT)
            Local $hDC = _WinAPI_BeginPaint($hWnd, $tPaint)

            Local $tClient = _WinAPI_GetClientRect($hWnd)
			Local $iW = $tClient.Right
			Local $iH = $tClient.Bottom

			; Initiate double buffering
			Local $hMemDC = _WinAPI_CreateCompatibleDC($hDC)
			Local $hBitmap = _WinAPI_CreateCompatibleBitmap($hDC, $iW, $iH)
			Local $hOldBmp = _WinAPI_SelectObject($hMemDC, $hBitmap)

            Local $iState = _GUICtrlButton_GetState($hWnd)

            ; Determine StateID from current state
            Switch $iPartID
                Case $BP_CHECKBOX
					Switch _WinAPI_IsWindowEnabled($hWnd)
						Case True
							If BitAND($iState, $BST_INDETERMINATE) Then
								If BitAND($iState, $BST_HOT) Then
									$iStateID = $CBS_MIXEDHOT
								Else
									$iStateID = $CBS_MIXEDNORMAL
								EndIf
							ElseIf BitAND($iState, $BST_CHECKED) Then
								If BitAND($iState, $BST_HOT) Then
									$iStateID = $CBS_CHECKEDHOT
								Else
									$iStateID = $CBS_CHECKEDNORMAL
								EndIf
							Else
								If BitAND($iState, $BST_HOT) Then
									$iStateID = $CBS_UNCHECKEDHOT
								Else
									$iStateID = $CBS_UNCHECKEDNORMAL
								EndIf
							EndIf
						Case False
							If BitAND($iState, $BST_INDETERMINATE) Then
								$iStateID = $CBS_MIXEDDISABLED
							ElseIf BitAND($iState, $BST_CHECKED) Then
								$iStateID = $CBS_CHECKEDDISABLED
							Else
								$iStateID = $CBS_UNCHECKEDDISABLED
							EndIf
					EndSwitch

                Case $BP_RADIOBUTTON
					Switch _WinAPI_IsWindowEnabled($hWnd)
						Case True
							If BitAND($iState, $BST_CHECKED) Then
								If BitAND($iState, $BST_HOT) Then
									$iStateID = $RBS_CHECKEDHOT
								Else
									$iStateID = $RBS_CHECKEDNORMAL
								EndIf
							Else
								If BitAND($iState, $BST_HOT) Then
									$iStateID = $RBS_UNCHECKEDHOT
								Else
									$iStateID = $RBS_UNCHECKEDNORMAL
								EndIf
							EndIf
						Case False
							If BitAND($iState, $BST_CHECKED) Then
								$iStateID = $RBS_CHECKEDDISABLED
							Else
								$iStateID = $RBS_UNCHECKEDDISABLED
							EndIf
					EndSwitch
            EndSwitch

            ; Determine DrawText $DT_* flags based on detected styles
            Local $iTextFlags
            Select
                Case StringInStr($sStyles, "BS_RIGHT") <> 0
                    $iTextFlags = BitOR($DT_SINGLELINE, $DT_NOCLIP, $DT_VCENTER, $DT_RIGHT)
                Case StringInStr($sStyles, "BS_CENTER") <> 0
                    $iTextFlags = BitOR($DT_SINGLELINE, $DT_NOCLIP, $DT_VCENTER, $DT_CENTER)
                Case Else
                    $iTextFlags = BitOR($DT_SINGLELINE, $DT_NOCLIP, $DT_VCENTER, $DT_LEFT)
            EndSelect

            ; GetThemeBackgroundContentRect
            Local $tTextRect = _WinAPI_GetThemeBackgroundContentRect($hTheme, $iPartID, $iStateID, $hMemDC, $tClient)
            Local $tSIZE = _WinAPI_GetThemePartSize($hTheme, $iPartID, 0, Null, Null, $TS_TRUE)

            ; Get text from control
            Local $sText = _WinAPI_GetWindowText($hWnd)

            ; DrawThemeParentBackground
            _WinAPI_DrawThemeParentBackground($hWnd, $hMemDC, $tClient)

			; Paint control background with tab background color if within tab control
			If $bCtrlInTab Then
				Local $hBrush = $__DM_g_hBrushTabBk
				_WinAPI_FillRect($hMemDC, $tClient, $hBrush)
			EndIf

            ; DrawThemeBackground
            Local $iWidth = $tSIZE.X
            Local $iHeight = $tSIZE.Y
            Local $iClientHeight = $tClient.Bottom - $tClient.Top
            Local $iHeightPad = ($iClientHeight - $iHeight)
            Local $tRect = _WinAPI_CreateRectEx(0, 0, $iWidth, $iHeight + $iHeightPad)
            _WinAPI_DrawThemeBackground($hTheme, $iPartID, $iStateID, $hMemDC, $tRect)

            ; Set flags for DTTOPTS structure
            Local $tDTTOPTS = DllStructCreate($tagDTTOPTS)
            DllStructSetData($tDTTOPTS, 'Size', DllStructGetSize($tDTTOPTS))
            DllStructSetData($tDTTOPTS, 'Flags', $DTT_TEXTCOLOR)
            DllStructSetData($tDTTOPTS, 'clrText', _WinAPI_IsWindowEnabled($hWnd) ? 0xFFFFFF : 0x808080)

            ; Setup font
            Local $hFont = _SendMessage($hWnd, $WM_GETFONT, 0, 0)
            If Not $hFont Then $hFont = _WinAPI_GetStockObject($DEFAULT_GUI_FONT)
            Local $hOldFont = _WinAPI_SelectObject($hMemDC, $hFont)

            $tTextRect.Left = $tTextRect.Left + $tSIZE.X + 3
			$tTextRect.Right = $tTextRect.Right + $tSIZE.X + 3

			;_WinAPI_SetBkMode($hMemDC, $TRANSPARENT)
			;_WinAPI_SetBkColor($hMemDC, _WinAPI_SwitchColor($__DM_g_iCtrlBkColor))
			;_WinAPI_SetTextColor($hMemDC, _WinAPI_SwitchColor($__DM_g_iTextColor))

            _WinAPI_DrawThemeTextEx($hTheme, $BP_CHECKBOX, $iStateID, $hMemDC, $sText, $tTextRect, $iTextFlags, $tDTTOPTS)
			;_WinAPI_DrawText($hMemDC, $sText, $tTextRect, $iTextFlags)

            _WinAPI_BitBlt($hDC, 0, 0, $iW, $iH, $hMemDC, 0, 0, $SRCCOPY)

            ; Cleanup
            _WinAPI_CloseThemeData($hTheme)
            _WinAPI_SelectObject($hDC, $hOldFont)
            _WinAPI_SelectObject($hMemDC, $hOldBmp)
			_WinAPI_DeleteObject($hBitmap)
			_WinAPI_DeleteDC($hMemDC)

            _WinAPI_EndPaint($hWnd, $tPaint)
            Return 0

    EndSwitch

    Return __WinAPI_DefSubclassProc($hWnd, $iMsg, $wParam, $lParam)
EndFunc   ;==>__GUIDarkTheme_ButtonProc

; #FUNCTION# ====================================================================================================================
; Author.........: Nine
; Modified.......: WildByDesign
; ===============================================================================================================================
Func __GUIDarkTheme_UpDownProc($hWnd, $iMsg, $wParam, $lParam, $iID, $pData)
	#forceref $iID, $pData
	Local Static $bHover
	Local $bHorz = BitAND(_WinAPI_GetWindowLong($hWnd, $GWL_STYLE), $UDS_HORZ)
	Local $tRectTmp, $iPos, $hBrush
	Switch $iMsg
		Case $WM_PAINT
			Local $tPaint, $hDC = _WinAPI_BeginPaint($hWnd, $tPaint)
			Local $tRect = _WinAPI_GetClientRect($hWnd)
			Local $hMemDC = _WinAPI_CreateCompatibleDC($hDC)
			Local $hBitmap = _WinAPI_CreateCompatibleBitmap($hDC, $tRect.right, $tRect.bottom)
			Local $hOldBmp = _WinAPI_SelectObject($hMemDC, $hBitmap)

			Local $hPen = $__DM_g_hPenBtnBor
			_WinAPI_SelectObject($hMemDC, $hPen)
			$hBrush = $__DM_g_hBrushBtn
			_WinAPI_SetBkMode($hMemDC, $TRANSPARENT)
			_WinAPI_SelectObject($hMemDC, $hBrush)
			_WinAPI_Rectangle($hMemDC, $tRect)
			If $bHorz Then
				_WinAPI_DrawLine($hMemDC, Int($tRect.right / 2), 0, Int($tRect.right / 2), $tRect.bottom)
			Else
				_WinAPI_DrawLine($hMemDC, 0, Int($tRect.bottom / 2), $tRect.right, Int($tRect.bottom / 2))
			EndIf

			If $bHover Then
				If $bHorz Then
					$iPos = Round(_WinAPI_GetMousePos(True, $hWnd).x / _WinAPI_GetClientRect($hWnd).right, 0)
				Else
					$iPos = Round(_WinAPI_GetMousePos(True, $hWnd).y / _WinAPI_GetClientRect($hWnd).bottom, 0)
				EndIf

				If _IsPressed($VK_LBUTTON, 'user32.dll') Then
					$hBrush = $__DM_g_hBrushBtnSel
				Else
					$hBrush = $__DM_g_hBrushBtnHov
				EndIf

				$tRectTmp = _WinAPI_GetClientRect($hWnd)
				If $iPos Then
					If $bHorz Then
						$tRectTmp.left = Int($tRect.right / 2)
					Else
						$tRectTmp.top = Int($tRect.bottom / 2)
					EndIf
				Else
					If $bHorz Then
						$tRectTmp.right = Int($tRect.right / 2)
					Else
						$tRectTmp.bottom = Int($tRect.bottom / 2)
					EndIf
				EndIf
				_WinAPI_SelectObject($hMemDC, $hBrush)
				_WinAPI_Rectangle($hMemDC, $tRectTmp)
			EndIf

			_WinAPI_SetTextColor($hMemDC, $__DM_g_iTextColor)
			$tRectTmp = _WinAPI_GetClientRect($hWnd)
			Local $iFH = 7 * $__DM_g_iDpiScale
			Local $sFontName = "Segoe MDL2 Assets"
			Local $hFont = _WinAPI_CreateFont($iFH, 0, 0, 0, $FW_NORMAL, False, False, False, _
					$DEFAULT_CHARSET, $OUT_DEFAULT_PRECIS, $CLIP_DEFAULT_PRECIS, $PROOF_QUALITY, $DEFAULT_PITCH, $sFontName)
			_WinAPI_SelectObject($hMemDC, $hFont)
			If $bHorz Then
				$tRectTmp.top = Int(($tRect.bottom - $iFH) / 2)
				$tRectTmp.right = $tRect.right / 2
				_WinAPI_DrawText($hMemDC, ChrW(0xEDD9), $tRectTmp, BitOR($DT_CENTER, $DT_VCENTER, $DT_NOCLIP))
				$tRectTmp.left = Int($tRect.right / 2)
				$tRectTmp.right = $tRect.right
				_WinAPI_DrawText($hMemDC, ChrW(0xEDDA), $tRectTmp, BitOR($DT_CENTER, $DT_VCENTER, $DT_NOCLIP))
			Else
				$tRectTmp.top = Int((Round($tRect.bottom / 2) - $iFH) / 2)
				_WinAPI_DrawText($hMemDC, ChrW(0xEDDB), $tRectTmp, BitOR($DT_CENTER, $DT_VCENTER, $DT_NOCLIP))
				$tRectTmp.top += Round($tRect.bottom / 2)
				_WinAPI_DrawText($hMemDC, ChrW(0xEDDC), $tRectTmp, BitOR($DT_CENTER, $DT_VCENTER, $DT_NOCLIP))
			EndIf

			_WinAPI_BitBlt($hDC, 0, 0, $tRect.right, $tRect.bottom, $hMemDC, 0, 0, $SRCCOPY)

			_WinAPI_SelectObject($hMemDC, $hOldBmp)
			_WinAPI_DeleteObject($hBitmap)
			_WinAPI_DeleteDC($hMemDC)
			_WinAPI_DeleteObject($hFont)
			_WinAPI_EndPaint($hWnd, $tPaint)
		Case $WM_MOUSEMOVE
			$bHover = True
			_WinAPI_TrackMouseEvent($hWnd, $TME_LEAVE)
			_WinAPI_InvalidateRect($hWnd, 0, False)
			Return
		Case $WM_MOUSELEAVE
			$bHover = False
			_WinAPI_InvalidateRect($hWnd, 0, False)
			Return
	EndSwitch
	Return __WinAPI_DefSubclassProc($hWnd, $iMsg, $wParam, $lParam)
EndFunc   ;==>__GUIDarkTheme_UpDownProc

; #FUNCTION# ====================================================================================================================
; Author.........: UEZ
; Modified.......: mLipok, WildByDesign
; ===============================================================================================================================
Func __GUIDarkTheme_TabProc($hWnd, $iMsg, $wParam, $lParam, $iID, $pData)
	#forceref $iID, $pData
	Local $hBrushTabRecDark
	Switch $iMsg
		Case $WM_ERASEBKGND
			Return 1 ; Prevent background erasing to avoid flickering

		Case $WM_PAINT

			; sending groupbox to bottom of z-order helps with transparency issue
			For $i = 0 To UBound($__DM_g_aGroupInTab) - 1
				If _WinAPI_IsWindowVisible($__DM_g_aGroupInTab[$i]) Then
					_WinAPI_SetWindowPos($__DM_g_aGroupInTab[$i], $HWND_BOTTOM, 0, 0, 0, 0, BitOR($SWP_NOMOVE, $SWP_NOREDRAW, $SWP_NOSIZE))
				EndIf
			Next

			Local $tPaint = DllStructCreate($tagPAINTSTRUCT)
			Local $hDC = _WinAPI_BeginPaint($hWnd, $tPaint)
			If @error Or Not $hDC Then Return __WinAPI_DefSubclassProc($hWnd, $iMsg, $wParam, $lParam)

			Local $tClient = _WinAPI_GetClientRect($hWnd)
			Local $iWidth = $tClient.Right
			Local $iHeight = $tClient.Bottom

			; Prepare Double Buffering
			Local $hMemDC = _WinAPI_CreateCompatibleDC($hDC)
			Local $hBitmap = _WinAPI_CreateCompatibleBitmap($hDC, $iWidth, $iHeight)
			Local $hOldBmp = _WinAPI_SelectObject($hMemDC, $hBitmap)

			; Determine if tab control contains an UpDown (spin) control
			Local $hTabUpDown = _WinAPI_FindWindowEx($hWnd, "msctls_updown32")
			If $hTabUpDown And _WinAPI_IsWindowVisible($hTabUpDown) Then
				Local $tCR = _WinAPI_GetWindowRect($hTabUpDown)
				Local $tPR = _WinAPI_GetWindowRect($hWnd)

				; Exclude UpDown control from being painted over
				DllCall('gdi32.dll', "int", "ExcludeClipRect", "handle", $hDC, "int", $tCR.Left - $tPR.Left, "int", _
						$tCR.Top - $tPR.Top - 100, "int", $tCR.Right - $tPR.Left, "int", $tCR.Bottom - $tPR.Top + 2)
			EndIf

			; Fill entire tab control with GUI background color
			Local $hBrushBg = $__DM_g_hBrushGui
			_WinAPI_FillRect($hMemDC, $tClient, $hBrushBg)

			Local $iTabCount = _SendMessage($hWnd, $TCM_GETITEMCOUNT, 0, 0)
			Local $iCurSel = _SendMessage($hWnd, $TCM_GETCURSEL, 0, 0)

			; Setup font
			Local $hFont = _SendMessage($hWnd, $WM_GETFONT, 0, 0)
			If Not $hFont Then $hFont = _WinAPI_GetStockObject($DEFAULT_GUI_FONT)
			Local $hOldFont = _WinAPI_SelectObject($hMemDC, $hFont)

			; Prepare the Body Frame (The area beneath the tabs)
			Local $tFirstTabRect = DllStructCreate($tagRECT)
			_SendMessage($hWnd, $TCM_GETITEMRECT, 0, DllStructGetPtr($tFirstTabRect))

			Local $tBodyRect = DllStructCreate($tagRECT)
			$tBodyRect.Left = 0
			$tBodyRect.Top = $tFirstTabRect.Bottom  ; Starts at the bottom edge of the tabs
			$tBodyRect.Right = $iWidth
			$tBodyRect.Bottom = $iHeight

			Local $hBrushBorder = $__DM_g_iBrushBorder
			Local $hBrushTabBody = $__DM_g_hBrushTabBk
			_WinAPI_FillRect($hMemDC, $tBodyRect, $hBrushTabBody)
			_WinAPI_FrameRect($hMemDC, $tBodyRect, $hBrushBorder)

			_WinAPI_SetBkMode($hMemDC, $TRANSPARENT)
			_WinAPI_SetTextColor($hMemDC, _WinAPI_SwitchColor($__DM_g_iTextColor))

			; Draw individual tabs
			For $i = 0 To $iTabCount - 1
				Local $bSelected = ($i = $iCurSel)
				Local $hTabBrush = $__DM_g_hBrushTabBk
				Local $hBrushUnSel = $__DM_g_hBrushTab

				Local $tRect = DllStructCreate($tagRECT)
				_SendMessage($hWnd, $TCM_GETITEMRECT, $i, DllStructGetPtr($tRect))
				If $tRect.Right < 0 Or $tRect.Left > $iWidth Then ContinueLoop

				If $bSelected Then
					; Draw selected tab
					$tRect.top -= 2

					; Fill tab background
					_WinAPI_FillRect($hMemDC, $tRect, $hTabBrush)

					; Draw border ONLY for the active tab (Top, Left, Right)
					$hBrushTabRecDark = $__DM_g_iBrushBorder
					_WinAPI_FrameRect($hMemDC, $tRect, $hBrushTabRecDark)

					; OPEN BOTTOM: Draw a line in tab-color over the body-border to merge them
					Local $tOpenLine = DllStructCreate($tagRECT)
					$tOpenLine.Left = $tRect.Left + 1
					$tOpenLine.Top = $tRect.Bottom - 1 ; Exactly on the border line of the body
					$tOpenLine.Right = $tRect.Right - 1
					$tOpenLine.Bottom = $tRect.Bottom + 1
					_WinAPI_FillRect($hMemDC, $tOpenLine, $hTabBrush)

					; Draw selection indicator with accent color
					Local $iLeft = $tRect.Left
					Local $iTop = $tRect.Top
					Local $iRight = $tRect.Right
					Local $hPen = $__DM_g_hPen2Accent
					Local $hOldPen = _WinAPI_SelectObject($hMemDC, $hPen)
					_WinAPI_MoveTo($hMemDC, $iLeft + 1, $iTop)
					_WinAPI_LineTo($hMemDC, $iRight - 2, $iTop + 1)
					_WinAPI_SelectObject($hMemDC, $hOldPen)
				Else
					; draw tab
					$tRect.top -= 0
					$tRect.bottom += 1
					$tRect.Left -= 1
					$tRect.Right += 1

					; Fill tab background
					Local $hTabBrush2 = $hBrushUnSel
					_WinAPI_FillRect($hMemDC, $tRect, $hTabBrush2)

					; Draw rectangle around non active tabs
					$hBrushTabRecDark = $__DM_g_iBrushBorder
					_WinAPI_FrameRect($hMemDC, $tRect, $hBrushTabRecDark)
				EndIf

				; Draw text centered
				Local $sText = _GUICtrlTab_GetItemText($hWnd, $i)
				Local $tTextRect = DllStructCreate($tagRECT)
				With $tTextRect
					.Left = $tRect.Left + 6
					.Top = $tRect.Top + ($bSelected ? 1 : 3)
					.Right = $tRect.Right - 6
					.Bottom = $tRect.Bottom - 3
				EndWith
				DllCall("user32.dll", "int", "DrawTextW", "handle", $hMemDC, "wstr", $sText, "int", -1, "struct*", $tTextRect, "uint", BitOR($DT_CENTER, $DT_VCENTER, $DT_SINGLELINE, $DT_NOCLIP))
			Next

			; Copy memory DC to screen DC (BitBlt)
			_WinAPI_BitBlt($hDC, 0, 0, $iWidth, $iHeight, $hMemDC, 0, 0, $SRCCOPY)

			; redrawing groupbox helps to ensure that it does not get overpainted
			For $i = 0 To UBound($__DM_g_aGroupInTab) - 1
				If _WinAPI_IsWindowVisible($__DM_g_aGroupInTab[$i]) Then
					_WinAPI_RedrawWindow($__DM_g_aGroupInTab[$i], 0, 0, BitOR($RDW_INVALIDATE, $RDW_NOERASE))
				EndIf
			Next

			; Cleanup
			_WinAPI_SelectObject($hMemDC, $hOldBmp)
			_WinAPI_SelectObject($hMemDC, $hOldFont)
			_WinAPI_DeleteObject($hBitmap)
			_WinAPI_DeleteDC($hMemDC)
			_WinAPI_EndPaint($hWnd, $tPaint)
			Return 0

		Case $WM_PARENTNOTIFY
			; Fired when a child window is created inside the tab control.
			; The tab spinner (msctls_updown32) is created lazily by Windows when tabs overflow -
			; it doesn't exist at init time, so we theme it here the moment it appears.
			If _WinAPI_LoWord($wParam) = $WM_CREATE Then
				Local $hNewChild = HWnd($lParam) ; lParam carries the new child's HWND as integer - must cast!
				If _WinAPI_GetClassName($hNewChild) = "msctls_updown32" Then
					If Not $__DM_g_hUpDownSub Then
						$__DM_g_hUpDownSub = DllCallbackRegister(__GUIDarkTheme_UpDownProc, "lresult", _
								"hwnd;uint;wparam;lparam;uint_ptr;dword_ptr")
						$__DM_g_pUpDownSub = DllCallbackGetPtr($__DM_g_hUpDownSub)
					EndIf
					__GUIDarkTheme_AddToSubclass($hNewChild, $__DM_g_hUpDownSub, $__DM_g_pUpDownSub, $__DM_g_iControlCount)
				EndIf
			EndIf
			Return __WinAPI_DefSubclassProc($hWnd, $iMsg, $wParam, $lParam)

	EndSwitch

	Return __WinAPI_DefSubclassProc($hWnd, $iMsg, $wParam, $lParam)
EndFunc   ;==>__GUIDarkTheme_TabProc

; #FUNCTION# ====================================================================================================================
; Author.........: UEZ
; Modified.......: WildByDesign
; ===============================================================================================================================
Func __GUIDarkTheme_DateProc($hWnd, $iMsg, $wParam, $lParam)
	Local $iRet, $hDC
	Switch $iMsg

		Case $WM_NOTIFY
			Local $tNMHDR = DllStructCreate($tagNMHDR, $lParam)
			Local $iCode = $tNMHDR.Code

			; this is needed to remove the white border from MonthCal drop down
			If $iCode = $NM_CUSTOMDRAW Then
				Local $tNMCUSTOMDRAW = DllStructCreate($__DM_tagNMCUSTOMDRAW, $lParam)
				Local $dwDrawStage = $tNMCUSTOMDRAW.dwDrawStage
				$hDC = $tNMCUSTOMDRAW.hdc

				Switch $dwDrawStage
					Case $CDDS_PREPAINT
						Return $CDRF_NOTIFYITEMDRAW
				EndSwitch
			EndIf

		Case $WM_PAINT
			Local $tPaint = DllStructCreate($tagPAINTSTRUCT)
			$hDC = _WinAPI_BeginPaint($hWnd, $tPaint)

			Local $tClient = _WinAPI_GetClientRect($hWnd)
			Local $iW = $tClient.Right
			Local $iH = $tClient.Bottom

			; --- Memory DC for flicker-free rendering ---
			Local $hMemDC = _WinAPI_CreateCompatibleDC($hDC)
			Local $hBitmap = _WinAPI_CreateCompatibleBitmap($hDC, $iW, $iH)
			Local $hOldBmp = _WinAPI_SelectObject($hMemDC, $hBitmap)

			; 1. Let Windows draw the light-mode control into memory DC
			_WinAPI_CallWindowProc($__DM_g_hDateProcOld, $hWnd, $WM_PRINTCLIENT, $hMemDC, $PRF_CLIENT)

			; 2. Invert all pixels (background becomes black, text white, selection orange)
			Local $tRect = DllStructCreate($tagRECT)
			$tRect.right = $iW
			$tRect.bottom = $iH
			_WinAPI_InvertRect($hMemDC, $tRect)

			; --- 3. PIXEL HACK: destroy orange highlight & set background color ---
			Local $iSize = $iW * $iH
			Local $tPixels = DllStructCreate("dword c[" & $iSize & "]")
			; Load pixel array directly from bitmap memory
			Local $iBytes = DllCall('gdi32.dll', "long", "GetBitmapBits", "handle", $hBitmap, "long", $iSize * 4, "ptr", DllStructGetPtr($tPixels))[0]

			If $iBytes = $iSize * 4 Then
				Local $iPixel, $r, $g, $b, $iGray
				For $i = 1 To $iSize
					$iPixel = $tPixels.c(($i))

					; Split into color channels
					$b = BitAND($iPixel, 0xFF)
					$g = BitAND(BitShift($iPixel, 8), 0xFF)
					$r = BitAND(BitShift($iPixel, 16), 0xFF)

					; Convert to grayscale (orange becomes mid-gray)
					$iGray = Int(($r + $g + $b) / 3)

					; Very dark pixel = inverted white background
					If $iGray < 15 Then
						$iPixel = $__DM_g_iGuiBkColor ; Replace with exact GUI background color
					Else
						; Grayscale value for text (white) and selection (gray)
						; (negative BitShift shifts left in AutoIt)
						$iPixel = BitOR(BitShift($iGray, -16), BitShift($iGray, -8), $iGray)
					EndIf

					$tPixels.c(($i)) = $iPixel
				Next
				; Write cleaned pixels back into the bitmap
				DllCall('gdi32.dll', "long", "SetBitmapBits", "handle", $hBitmap, "long", $iSize * 4, "ptr", DllStructGetPtr($tPixels))
			EndIf
			; --- END PIXEL HACK ---

			; --- Border color (hover effect) ---
			Local $tCursorPos = DllStructCreate($tagPOINT)
			DllCall('user32.dll', "bool", "GetCursorPos", "struct*", $tCursorPos)
			DllCall('user32.dll', "bool", "ScreenToClient", "hwnd", $hWnd, "struct*", $tCursorPos)

			; --- Draw border ---
			Local $hPen = $__DM_g_hPenBorder
			Local $hNullBr = _WinAPI_GetStockObject(5)
			Local $hOldPen = _WinAPI_SelectObject($hMemDC, $hPen)
			Local $hOldBr = _WinAPI_SelectObject($hMemDC, $hNullBr)
			DllCall('gdi32.dll', "bool", "Rectangle", "handle", $hMemDC, "int", 0, "int", 0, "int", $iW, "int", $iH)
			_WinAPI_SelectObject($hMemDC, $hOldPen)
			_WinAPI_SelectObject($hMemDC, $hOldBr)

			; --- Copy finished result to screen in one step (no flicker) ---
			_WinAPI_BitBlt($hDC, 0, 0, $iW, $iH, $hMemDC, 0, 0, $SRCCOPY)

			; --- Cleanup ---
			_WinAPI_SelectObject($hMemDC, $hOldBmp)
			_WinAPI_DeleteObject($hBitmap)
			_WinAPI_DeleteDC($hMemDC)
			_WinAPI_EndPaint($hWnd, $tPaint)
			Return 0

		Case $WM_ERASEBKGND
			Return 1

		Case $WM_SETFOCUS, $WM_KILLFOCUS, $WM_LBUTTONDOWN, $WM_LBUTTONUP
			$iRet = _WinAPI_CallWindowProc($__DM_g_hDateProcOld, $hWnd, $iMsg, $wParam, $lParam)
			_WinAPI_InvalidateRect($hWnd, 0, False)
			Return $iRet

		Case $WM_MOUSEMOVE
			$iRet = _WinAPI_CallWindowProc($__DM_g_hDateProcOld, $hWnd, $iMsg, $wParam, $lParam)
			If Not $__DM_g_bHover Then
				$__DM_g_bHover = True
				_WinAPI_InvalidateRect($hWnd, 0, False)
			EndIf
			Return $iRet

		Case $WM_MOUSELEAVE
			$__DM_g_bHover = False
			_WinAPI_InvalidateRect($hWnd, 0, False)

	EndSwitch

	Return _WinAPI_CallWindowProc($__DM_g_hDateProcOld, $hWnd, $iMsg, $wParam, $lParam)
EndFunc   ;==>__GUIDarkTheme_DateProc

; #FUNCTION# ====================================================================================================================
; Author.........: UEZ
; Modified.......: Nine, WildByDesign, argumentum
; ===============================================================================================================================
Func __GUIDarkTheme_WM_NOTIFY($hWnd, $iMsg, $wParam, $lParam)
	#forceref $hWnd, $iMsg, $wParam
	Local $hBrush, $tRect, $hPen
	Local $tNMHDR = DllStructCreate($tagNMHDR, $lParam)
	Local $hFrom = $tNMHDR.hWndFrom
	Local $iCode = $tNMHDR.Code
	If $iCode = $NM_CUSTOMDRAW Then
		If Not $__DM_g_bUseDarkMode Then Return $GUI_RUNDEFMSG
		Local $tNMCD = DllStructCreate($__DM_tagNMCUSTOMDRAW, $lParam)
		Local $dwStage = $tNMCD.dwDrawStage
		Local $hDC = $tNMCD.hdc
		Switch _WinAPI_GetClassName($hFrom)
			Case "ToolbarWindow32"
				Local $tTool = DllStructCreate($tagNMTBCUSTOMDRAW, $lParam)
				Local Static $iGuiWidth = WinGetClientSize($hWnd)[0]
				Local Static $iToolbarWidth = _WinAPI_GetWindowWidth($tTool.hWndFrom)

				; resize toolbar only if toolbar covers full client width
				If $iToolbarWidth = $iGuiWidth And __GUIDarkTheme_GUI_IsResizable($hWnd) Then
					Local $aSize = WinGetClientSize($hWnd)
					WinMove($tTool.hWndFrom, "", 0, 0, $aSize[0])
				EndIf

				Switch $dwStage
					Case $CDDS_PREPAINT
						$hBrush = $__DM_g_hBrushCtrl
						;$hBrush = _GUICtrlToolbar_GetStyleTransparent($tTool.hWndFrom) ? $__DM_g_hBrushGui : $__DM_g_hBrushCtrl
						$hBrush = $__DM_g_hBrushGui
						$tRect = DllStructCreate($tagRECT, DllStructGetPtr($tTool, "left"))
						_WinAPI_FillRect($tTool.hdc, $tRect, $hBrush)

						Return $CDRF_NOTIFYITEMDRAW

					Case $CDDS_ITEMPREPAINT
						Local $iState = $tTool.uItemState

						If BitAND($iState, $CDIS_HOT) Then
							$tTool.clrText = $__DM_g_iTextColor
							$tTool.clrTextHighlight = $__DM_g_iTextColor

							$tRect = DllStructCreate($tagRECT, DllStructGetPtr($tTool, "left"))
							$hPen = $__DM_g_hPenBtnBor
							_WinAPI_SelectObject($tTool.hdc, $hPen)
							$hBrush = BitAND($iState, $CDIS_SELECTED) ? $__DM_g_hBrushBtnSel : $__DM_g_hBrushBtnHov
							_WinAPI_SelectObject($tTool.hdc, $hBrush)
							_WinAPI_RoundRect($tTool.hdc, $tRect, 8, 8)

							; clear item state or else this will not work
							$tTool.uItemState = Null

							Return $TBCDRF_USECDCOLORS
						EndIf

						If BitAND($iState, $CDIS_CHECKED) Then
							$tTool.clrText = $__DM_g_iTextColor
							$tTool.clrTextHighlight = $__DM_g_iTextColor

							$tRect = DllStructCreate($tagRECT, DllStructGetPtr($tTool, "left"))
							$hPen = $__DM_g_hPenBtnBor
							_WinAPI_SelectObject($tTool.hdc, $hPen)
							$hBrush = BitAND($iState, $CDIS_SELECTED) ? $__DM_g_hBrushBtnSel : $__DM_g_hBrushBtnHov
							_WinAPI_SelectObject($tTool.hdc, $hBrush)
							_WinAPI_RoundRect($tTool.hdc, $tRect, 8, 8)

							; clear item state or else this will not work
							$tTool.uItemState = Null

							Return $TBCDRF_USECDCOLORS
						EndIf

						If Not BitAND($iState, $CDIS_DISABLED) Then
							$tTool.clrText = $__DM_g_iTextColor
							$tTool.clrTextHighlight = $__DM_g_iTextColor

							Return $TBCDRF_USECDCOLORS
						EndIf
				EndSwitch

			Case "msctls_trackbar32"
				Local $dwItemSpec = $tNMCD.dwItemSpec

				Switch $dwStage
					Case $CDDS_PREPAINT
						$tNMCD.ItemState = BitXOR($tNMCD.ItemState, $CDIS_FOCUS)
						Return $CDRF_NOTIFYSUBITEMDRAW

					Case 0x00010001         ;BitOR($CDDS_SUBITEM, $CDDS_ITEMPREPAINT)
						Switch $dwItemSpec
							Case $TBCD_THUMB

								; Determine thumb style from control style flags
								Local $iStyle = _WinAPI_GetWindowLong($hFrom, $GWL_STYLE)
								Local $bNoThumb = BitAND($iStyle, $TBS_NOTHUMB) <> 0                    ; no thumb visible
								Local $bTop = BitAND($iStyle, $TBS_TOP) <> 0                            ; tip points up (horizontal)
								Local $bBoth = BitAND($iStyle, $TBS_BOTH) <> 0                          ; rectangular thumb
								Local $bVert = BitAND($iStyle, $TBS_VERT) <> 0                          ; vertical slider
								Local $bDownIsLeft = BitAND($iStyle, $TBS_DOWNISLEFT) <> 0              ; vert: tip points left
								;Local $bBottom      = Not $bTop And Not $bBoth And Not $bVert   ; default: tip points down

								; No thumb style — skip custom drawing, let Windows handle (= invisible)
								If $bNoThumb Then Return $CDRF_SKIPDEFAULT

								Local $iL = $tNMCD.left
								Local $iT = $tNMCD.top
								Local $iR = $tNMCD.right - 1
								Local $iB = $tNMCD.bottom
								Local $iMid = $bVert ? ($iT + $iB) / 2 : ($iL + $iR) / 2
								Local $iSplit = $bVert ? $iR - ($iB - $iT) / 2 : $iB - ($iR - $iL) / 2

								Local $tPt = DllStructCreate($tagPOINT)
								DllCall('user32.dll', "bool", "GetCursorPos", "struct*", $tPt)
								_WinAPI_ScreenToClient($hFrom, $tPt)
								Local $bHot = ($tPt.X >= $iL And $tPt.X <= $iR And $tPt.Y >= $iT And $tPt.Y <= $iB - 1)

								$hBrush = $bHot ? $__DM_g_hBrushAccentHot : $__DM_g_hBrushAccent
								$hPen = $__DM_g_hPenGui
								Local $hOldBrush = _WinAPI_SelectObject($hDC, $hBrush)
								Local $hOldPen = _WinAPI_SelectObject($hDC, $hPen)

								If $bBoth Then
									; rectangular thumb
									DllCall('gdi32.dll', "bool", "Rectangle", "handle", $hDC, "int", $iL, "int", $iT, "int", $iR + 1, "int", $iB)
								ElseIf $bVert Then
									; vertical slider — pentagon tip points right (default) or left (TBS_DOWNISLEFT)
									Local $iMidV = ($iT + $iB) / 2
									Local $iSplitV = $bDownIsLeft ? $iL + ($iB - $iT) / 2 : $iR - ($iB - $iT) / 2
									Local $tPoints = DllStructCreate("int p[10]")
									If $bDownIsLeft Then
										; tip points LEFT
										$tPoints.p((1)) = $iL
										$tPoints.p((2)) = $iMidV
										$tPoints.p((3)) = $iSplitV
										$tPoints.p((4)) = $iT
										$tPoints.p((5)) = $iR
										$tPoints.p((6)) = $iT
										$tPoints.p((7)) = $iR
										$tPoints.p((8)) = $iB
										$tPoints.p((9)) = $iSplitV
										$tPoints.p((10)) = $iB
									Else
										; tip points RIGHT
										$tPoints.p((1)) = $iR
										$tPoints.p((2)) = $iMidV
										$tPoints.p((3)) = $iSplitV
										$tPoints.p((4)) = $iB
										$tPoints.p((5)) = $iL
										$tPoints.p((6)) = $iB
										$tPoints.p((7)) = $iL
										$tPoints.p((8)) = $iT
										$tPoints.p((9)) = $iSplitV
										$tPoints.p((10)) = $iT
									EndIf
									DllCall('gdi32.dll', "bool", "Polygon", "handle", $hDC, "struct*", $tPoints, "int", 5)
								ElseIf $bTop Then
									; TBS_TOP — pentagon tip points UP
									Local $iSplitTop = $iT + ($iR - $iL) / 2
									$tPoints = DllStructCreate("int p[10]")
									$tPoints.p((1)) = $iMid
									$tPoints.p((2)) = $iT
									$tPoints.p((3)) = $iR
									$tPoints.p((4)) = $iSplitTop
									$tPoints.p((5)) = $iR
									$tPoints.p((6)) = $iB
									$tPoints.p((7)) = $iL
									$tPoints.p((8)) = $iB
									$tPoints.p((9)) = $iL
									$tPoints.p((10)) = $iSplitTop
									DllCall('gdi32.dll', "bool", "Polygon", "handle", $hDC, "struct*", $tPoints, "int", 5)
								Else
									; TBS_BOTTOM (default) — pentagon tip points DOWN
									$tPoints = DllStructCreate("int p[10]")
									$tPoints.p((1)) = $iL
									$tPoints.p((2)) = $iT
									$tPoints.p((3)) = $iR
									$tPoints.p((4)) = $iT
									$tPoints.p((5)) = $iR
									$tPoints.p((6)) = $iSplit
									$tPoints.p((7)) = $iMid
									$tPoints.p((8)) = $iB
									$tPoints.p((9)) = $iL
									$tPoints.p((10)) = $iSplit
									DllCall('gdi32.dll', "bool", "Polygon", "handle", $hDC, "struct*", $tPoints, "int", 5)
								EndIf

								_WinAPI_SelectObject($hDC, $hOldBrush)
								_WinAPI_SelectObject($hDC, $hOldPen)
								Return $CDRF_SKIPDEFAULT

							Case $TBCD_CHANNEL
								$hBrush = $__DM_g_hBrushGray
								Local $tRect2 = DllStructCreate($tagRECT)
								$tRect2.Left = $tNMCD.left
								$tRect2.Top = $tNMCD.top
								$tRect2.Right = $tNMCD.right
								$tRect2.Bottom = $tNMCD.bottom
								_WinAPI_FillRect($hDC, $tRect2, $hBrush)
								Return $CDRF_SKIPDEFAULT

							Case Else
								Return $CDRF_DODEFAULT         ; channel + ticks drawn by Windows
						EndSwitch
				EndSwitch
		EndSwitch

	Else
		If _WinAPI_GetClassName($hFrom) = "SysLink" Then
			Local Const $tagLITEM = "struct;uint mask;int iLink;uint state;uint stateMask;wchar szID[48];wchar szURL[2083];endstruct"
    		Local Const $tagNMLINK = "struct;hwnd hwndFrom;uint_PTR idFrom;int code;" & (@AutoItX64 ? "int pad;" : "") & "endstruct;" & $tagLITEM
			If $iCode = $NM_CLICK Or $iCode = $NM_RETURN Then
				Local $tNMLINK = DllStructCreate($tagNMLINK, $lParam)
				Local $sID = DllStructGetData($tNMLINK, "szID")
				Local $sUrl = DllStructGetData($tNMLINK, "szURL")
				If $sID <> "" Then
					ShellExecute($sUrl)
					Return 0
				EndIf
			EndIf
		EndIf
		If _WinAPI_GetClassName($hFrom) = "SysDateTimePick32" Then
			If Not $__DM_g_bUseDarkMode Then Return $GUI_RUNDEFMSG
			Switch $iCode
				Case $DTN_DROPDOWN
					; Remove theme from SysMonthCal32
					Local $hMonthCal = _GUICtrlDTP_GetMonthCal($hFrom)
					_WinAPI_SetWindowTheme($hMonthCal, "", "")
					_SendMessage($hMonthCal, $WM_THEMECHANGED, 0, 0)

					; resize DropDown window for padding (this frames the SysMonthCal32 window)
					Local $hDropDown = _WinAPI_FindWindowEx(Null, "DropDown")
					If $hDropDown Then
						Local $aPos = WinGetPos($hDropDown)
						If IsArray($aPos) Then WinMove($hDropDown, "", $aPos[0], $aPos[1], $aPos[2] + 3, $aPos[3] + 3)
					EndIf

					; set timer to capture SysShadow handle which is created yet
					GUIRegisterMsg($WM_TIMER, "WM_TIMER")
					_Timer_SetTimer($hWnd, 5)

				Case $DTN_CLOSEUP
					; kill timer
					_Timer_KillAllTimers($hWnd)
					GUIRegisterMsg($WM_TIMER, "")
			EndSwitch
		EndIf
	EndIf

	Return $GUI_RUNDEFMSG
EndFunc   ;==>__GUIDarkTheme_WM_NOTIFY

; #FUNCTION# ====================================================================================================================
; Author.........: WildByDesign
; ===============================================================================================================================
Func WM_TIMER($hWnd, $iMsg, $wParam, $lParam)
	#forceref $hWnd, $iMsg, $wParam, $lParam
	Local $hSysShadow = 0
	$hSysShadow = _WinAPI_FindWindowEx(Null, "SysShadow")

	If Not $hSysShadow Then
		$__DM_g_iTimerCycles += 1
		If $__DM_g_iTimerCycles <= 10 Then Return 0 ; shadow not showing yet
		; Else user likely has "Show shadows under windows" disabled, no need to keep trying
	EndIf

	; Find SysMonthCal32 to apply delayed theme removal in case of initial timing issue
	Local $aWindows = _WinAPI_EnumWindows(True)
	If @error = 0 Then
		For $i = 1 To $aWindows[0][0]
			If $aWindows[$i][1] = "SysMonthCal32" Then
				; Remove theme from SysMonthCal32
				_WinAPI_SetWindowTheme($aWindows[$i][0], "", "")
				_SendMessage($aWindows[$i][0], $WM_THEMECHANGED, 0, 0)
			EndIf
		Next
	EndIf

	$__DM_g_iTimerCycles = 0

	If $hSysShadow Then
		; Move SysShadow to align with calendar dropdown
		Local $aPos = WinGetPos($hSysShadow)
		If IsArray($aPos) Then WinMove($hSysShadow, "", $aPos[0] - 3, $aPos[1] - 3, $aPos[2], $aPos[3])
	EndIf

	_Timer_KillAllTimers($hWnd)

	Return 0
EndFunc   ;==>WM_TIMER

; #FUNCTION# ====================================================================================================================
; Author.........: argumentum
; ===============================================================================================================================
Func __GUIDarkTheme_hWnd2Styles($hWnd)
	Return __GUIDarkTheme_GetCtrlStyleString(_WinAPI_GetWindowLong($hWnd, $GWL_STYLE), _WinAPI_GetWindowLong($hWnd, $GWL_EXSTYLE), _WinAPI_GetClassName($hWnd))
EndFunc   ;==>__GUIDarkTheme_hWnd2Styles

; #FUNCTION# ====================================================================================================================
; Author.........: Yashied
; Modified ......: pixelsearch, SmOke_N
; ===============================================================================================================================
Func __GUIDarkTheme_GetStyleString($iStyle, $fExStyle)
	ConsoleWrite('+ Func __GUIDarkTheme_GetStyleString(' & $iStyle & ', ' & $fExStyle & ')' & @CRLF)
	Local $Text = '', $Data = $fExStyle ? $__DM_g_Style_GuiExtended : $__DM_g_Style_Gui

	For $i = 0 To UBound($Data) - 1
		If BitAND($iStyle, $Data[$i][0]) = $Data[$i][0] Then
			$iStyle = BitAND($iStyle, BitNOT($Data[$i][0]))
			If StringLeft($Data[$i][1], 1) <> "!" Then
				$Text &= $Data[$i][1] & ', '
			Else
				; ex. '! WS_MINIMIZEBOX ! WS_GROUP'  =>  'WS_MINIMIZEBOX, '
				$Text &= StringMid($Data[$i][1], 3, StringInStr($Data[$i][1], "!", 2, 2) - 4) & ', '
			EndIf
		EndIf
	Next

	If $iStyle Then $Text = '0x' & Hex($iStyle, 8) & ', ' & $Text

	Return StringRegExpReplace($Text, ',\s\z', '')
EndFunc   ;==>__GUIDarkTheme_GetStyleString

; #FUNCTION# ====================================================================================================================
; Author.........: Yashied
; Modified ......: pixelsearch, SmOke_N
; ===============================================================================================================================
Func __GUIDarkTheme_GetCtrlStyleString($iStyle, $fExStyle, $sClass, $iLVExStyle = 0)

	If $sClass = "AutoIt v3 GUI" Or $sClass = "#32770" Or $sClass = "MDIClient" Then ; control = child GUI, dialog box (msgbox) etc...
		Return __GUIDarkTheme_GetStyleString($iStyle, 0)
	EndIf

	If StringLeft($sClass, 8) = "RichEdit" Then $sClass = "RichEdit" ; RichEdit, RichEdit20A, RichEdit20W, RichEdit50A, RichEdit50W

	Local $Text = ''

	__GUIDarkTheme_GetCtrlStyleString2($iStyle, $Text, $sClass, $iLVExStyle) ; 4th param. in case $sClass = "Ex_SysListView32" (special treatment)

	If $sClass = "ReBarWindow32" Or $sClass = "ToolbarWindow32" Or $sClass = "msctls_statusbar32" Then
		$sClass = "Common" ; "for rebar controls, toolbar controls, and status windows" (msdn)
		__GUIDarkTheme_GetCtrlStyleString2($iStyle, $Text, $sClass)
	ElseIf $sClass = "RichEdit" Then
		$sClass = "Edit" ; "Richedit controls also support many edit control styles (not all)" (msdn)
		__GUIDarkTheme_GetCtrlStyleString2($iStyle, $Text, $sClass)
	EndIf

	Local $Data = $fExStyle ? $__DM_g_Style_GuiExtended : $__DM_g_Style_Gui

	For $i = 0 To UBound($Data) - 1
		If BitAND($iStyle, $Data[$i][0]) = $Data[$i][0] Then
			If (Not BitAND($Data[$i][0], 0xFFFF)) Or ($fExStyle) Then
				$iStyle = BitAND($iStyle, BitNOT($Data[$i][0]))
				If StringLeft($Data[$i][1], 1) <> "!" Then
					$Text &= $Data[$i][1] & ', '
				Else
					; ex. '! WS_MINIMIZEBOX ! WS_GROUP'  =>  'WS_GROUP, '
					$Text &= StringMid($Data[$i][1], StringInStr($Data[$i][1], "!", 2, 2) + 2) & ', '
				EndIf
			EndIf
		EndIf
	Next

	If $iStyle Then $Text = '0x' & Hex($iStyle, 8) & ', ' & $Text

	Return StringRegExpReplace($Text, ',\s\z', '')
EndFunc   ;==>__GUIDarkTheme_GetCtrlStyleString

; #FUNCTION# ====================================================================================================================
; Author.........: Yashied
; Modified ......: pixelsearch, SmOke_N
; ===============================================================================================================================
Func __GUIDarkTheme_GetCtrlStyleString2(ByRef $iStyle, ByRef $Text, $sClass, $iLVExStyle = 0)

	Local $Data

	Switch $sClass  ; $Input[16]
		Case "Button"
			$Data = $__DM_g_Style_Button
		Case "ComboBox", "ComboBoxEx32"
			$Data = $__DM_g_Style_Combo
		Case "Common"
			$Data = $__DM_g_Style_Common ; "for rebar controls, toolbar controls, and status windows (msdn)"
		Case "Edit"
			$Data = $__DM_g_Style_Edit
		Case "ListBox"
			$Data = $__DM_g_Style_ListBox
		Case "msctls_progress32"
			$Data = $__DM_g_Style_Progress
		Case "msctls_statusbar32"
			$Data = $__DM_g_Style_StatusBar
		Case "msctls_trackbar32"
			$Data = $__DM_g_Style_Slider
		Case "msctls_updown32"
			$Data = $__DM_g_Style_UpDown
		Case "ReBarWindow32"
			$Data = $__DM_g_Style_Rebar
		Case "RichEdit"
			$Data = $__DM_g_Style_RichEdit
		Case "Scrollbar"
			$Data = $__DM_g_Style_Scrollbar
		Case "Static"
			$Data = $__DM_g_Style_Static
		Case "SysAnimate32"
			$Data = $__DM_g_Style_Avi
		Case "SysDateTimePick32"
			$Data = $__DM_g_Style_DateTime
		Case "SysHeader32"
			$Data = $__DM_g_Style_Header
		Case "SysListView32"
			$Data = $__DM_g_Style_ListView
		Case "Ex_SysListView32" ; special treatment below
			$Data = $__DM_g_Style_ListViewExtended
		Case "SysMonthCal32"
			$Data = $__DM_g_Style_MonthCal
		Case "SysPager"
			$Data = $__DM_g_Style_Pager
		Case "SysTabControl32", "SciTeTabCtrl"
			$Data = $__DM_g_Style_Tab
		Case "SysTreeView32"
			$Data = $__DM_g_Style_TreeView
		Case "ToolbarWindow32"
			$Data = $__DM_g_Style_Toolbar
		Case Else
			Return
	EndSwitch

	If $sClass <> "Ex_SysListView32" Then
		For $i = 0 To UBound($Data) - 1
			If BitAND($iStyle, $Data[$i][0]) = $Data[$i][0] Then
				$iStyle = BitAND($iStyle, BitNOT($Data[$i][0]))
				$Text = $Data[$i][1] & ', ' & $Text
			EndIf
		Next
	Else
		For $i = 0 To UBound($Data) - 1
			If BitAND($iLVExStyle, $Data[$i][0]) = $Data[$i][0] Then
				$iLVExStyle = BitAND($iLVExStyle, BitNOT($Data[$i][0]))
				$Text = $Data[$i][1] & ', ' & $Text
				If BitAND($iStyle, $Data[$i][0]) = $Data[$i][0] Then
					$iStyle = BitAND($iStyle, BitNOT($Data[$i][0]))
				EndIf
			EndIf
		Next
		If $iLVExStyle Then $Text = 'LVex: 0x' & Hex($iLVExStyle, 8) & ', ' & $Text
		; next test bc LVS_EX_FULLROWSELECT (default AutoIt LV ext style) and WS_EX_TRANSPARENT got both same value 0x20 (hard to solve in some cases)
		If BitAND($iStyle, $WS_EX_TRANSPARENT) = $WS_EX_TRANSPARENT Then ; note that $WS_EX_TRANSPARENT has nothing to do with listview
			$iStyle = BitAND($iStyle, BitNOT($WS_EX_TRANSPARENT))
		EndIf
	EndIf
EndFunc   ;==>__GUIDarkTheme_GetCtrlStyleString2

; #FUNCTION# ====================================================================================================================
; Name ..........: _GUIDarkTheme_GUISetDarkTheme
; Description ...: Sets the theme for a specified window to either dark or light mode on Windows 10/11.
; Syntax ........: _GUIDarkTheme_GUISetDarkTheme($hGui, $bEnableDarkTheme = True)
; Parameters ....: $hGui          		- The handle to the window.
;				   $bEnableDarkTheme	- If True, sets dark theme. If False, sets light theme. Default is True.
; Return values .: None
; Author ........: DK12000, NoNameCode
; Modified ......: WildByDesign
; Example .......: No
; ===============================================================================================================================
Func _GUIDarkTheme_GUISetDarkTheme($hGui, $bEnableDarkTheme = Default)
	Local Const $DWMWA_USE_IMMERSIVE_DARK_MODE = 20
	If $bEnableDarkTheme = Default Then $bEnableDarkTheme = True
	Local $iPreferredAppMode = ($bEnableDarkTheme == True) ? $APPMODE_FORCEDARK : $APPMODE_FORCELIGHT
	Dim $__DM_g_aGroupInTab[0]
	Dim $__DM_g_a_hDateTime[0]
	Dim $__DM_g_aButtonSub[1][3]
	$__DM_g_iButtonCount = 0
	$__DM_g_iTimerCycles = 0
	_WinAPI_SetPreferredAppMode($iPreferredAppMode)
	_WinAPI_RefreshImmersiveColorPolicyState()
	_WinAPI_FlushMenuThemes()
	_GUIDarkTheme_GUICtrlSetDarkTheme($hGui, $bEnableDarkTheme)
	_WinAPI_DwmSetWindowAttribute($hGui, $DWMWA_USE_IMMERSIVE_DARK_MODE, $bEnableDarkTheme)
	$__DM_g_bUseDarkMode = _WinAPI_ShouldAppsUseDarkMode()
	; reset dark mode and light mode colors
	$__DM_g_iStatusBkColor = $__DM_g_bUseDarkMode ? $__DM_g_iStatusBkColorDark : $__DM_g_iStatusBkColorLight
	$__DM_g_iGuiBkColor = $__DM_g_bUseDarkMode ? $__DM_g_iGuiBkColorDark : $__DM_g_iGuiBkColorLight
	$__DM_g_iTextColor = $__DM_g_bUseDarkMode ? $__DM_g_iTextColorDark : $__DM_g_iTextColorLight
	$__DM_g_iCtrlBkColor = $__DM_g_bUseDarkMode ? $__DM_g_iCtrlBkColorDark : $__DM_g_iCtrlBkColorLight
	$__DM_g_iBorderColorSel = $__DM_g_bUseDarkMode ? $__DM_g_iBorderColorSelDark : $__DM_g_iBorderColorSelLight
	$__DM_g_iBorderColor = $__DM_g_bUseDarkMode ? $__DM_g_iBorderColorDark : $__DM_g_iBorderColorLight
	$__DM_g_iSizeboxPaint = $__DM_g_bUseDarkMode ? $__DM_g_iSizeboxPaintDark : $__DM_g_iSizeboxPaintLight
	$__DM_g_iMenuBkColor = $__DM_g_bUseDarkMode ? $__DM_g_iMenuBkColorDark : $__DM_g_iMenuBkColorLight
	$__DM_g_iMenuHotColor = $__DM_g_bUseDarkMode ? $__DM_g_iMenuHotColorDark : $__DM_g_iMenuHotColorLight
	$__DM_g_iMenuSelColor = $__DM_g_bUseDarkMode ? $__DM_g_iMenuSelColorDark : $__DM_g_iMenuSelColorLight
	$__DM_g_iMenuTextColor = $__DM_g_bUseDarkMode ? $__DM_g_iMenuTextColorDark : $__DM_g_iMenuTextColorLight
	$__DM_g_iButtonColor = $__DM_g_bUseDarkMode ? $__DM_g_iButtonColorDark : $__DM_g_iButtonColorLight
	$__DM_g_iButtonColorHov = $__DM_g_bUseDarkMode ? $__DM_g_iButtonColorHovDark : $__DM_g_iButtonColorHovLight
	$__DM_g_iButtonColorSel = $__DM_g_bUseDarkMode ? $__DM_g_iButtonColorSelDark : $__DM_g_iButtonColorSelLight
	$__DM_g_iButtonColorBor = $__DM_g_bUseDarkMode ? $__DM_g_iButtonColorBorDark : $__DM_g_iButtonColorBorLight
	$__DM_g_iTabColor = $__DM_g_bUseDarkMode ? $__DM_g_iTabColorDark : $__DM_g_iTabColorLight
	$__DM_g_iTabColorSel = $__DM_g_bUseDarkMode ? $__DM_g_iTabColorSelDark : $__DM_g_iTabColorSelLight
	$__DM_g_iExtraGray = $__DM_g_bUseDarkMode ? $__DM_g_iExtraGrayDark : $__DM_g_iExtraGrayLight
	$__DM_g_iTabCtrlBkColor = $__DM_g_bUseDarkMode ? $__DM_g_iTabCtrlBkColorDark : $__DM_g_iTabCtrlBkColorLight

	; create brushes and pens
	__GUIDarkTheme_CreateBrushes()
	__GUIDarkTheme_CreatePens()

	Local $iGUI_BkColor = $__DM_g_iGuiBkColor
	GUISetBkColor($iGUI_BkColor, $hGui)
	Local $hMenu = _GUICtrlMenu_GetMenu($hGui)
	If $hMenu Then __GUIDarkMenu_MenuBarBKColor($hMenu, $__DM_g_iMenuBkColor)

	; subclass controls
	If Not $__DM_g_hSubclassProc Then
		$__DM_g_hSubclassProc = DllCallbackRegister(__GUIDarkTheme_SubclassProc, "lresult", "hwnd;uint;wparam;lparam;uint_ptr;dword_ptr")
		$__DM_g_pSubclassProc = DllCallbackGetPtr($__DM_g_hSubclassProc)
	EndIf

	; set titlebar color to match GUI color
	If @OSBuild >= 22000 Then _WinAPI_DwmSetWindowAttribute($hGui, $DWMWA_CAPTION_COLOR, _WinAPI_SwitchColor($__DM_g_iGuiBkColor))
EndFunc   ;==>_GUIDarkTheme_GUISetDarkTheme

; #FUNCTION# ====================================================================================================================
; Name ..........: _GUIDarkTheme_GUICtrlAllSetDarkTheme
; Description ...: Sets the dark theme to all existing sub Controls from a GUI
; Syntax ........: _GUIDarkTheme_GUICtrlAllSetDarkTheme($hGui[, $bEnableDarkTheme = True)
; Parameters ....: $hGui                - GUI handle
;                  $bEnableDarkTheme    - [optional] a boolean value. Default is True.
; Return values .: None
; Author ........: NoName
; Modified ......: WildByDesign
; Example .......: No
; ===============================================================================================================================
Func _GUIDarkTheme_GUICtrlAllSetDarkTheme($hGui, $bEnableDarkTheme = Default)
	If $bEnableDarkTheme = Default Then $bEnableDarkTheme = True
	Local $aCtrls = _WinAPI_EnumChildWindows($hGui, False)
	If @error = 0 Then
		For $i = 1 To $aCtrls[0][0]
			_GUIDarkTheme_GUICtrlSetDarkTheme($hGui, $aCtrls[$i][0], $bEnableDarkTheme)
			;ConsoleWrite("EnumChildWindows: " & @TAB & @TAB & "Handle: " & $aCtrls[$i][0] & " : " & "Class: " & $aCtrls[$i][1] & @CRLF)
		Next
	EndIf

	Local $aCtrlsEx = _WinAPI_EnumProcessWindows(0, False) ; allows getting handles for tooltips_class32, ComboLBox, etc.
	If @error = 0 Then
		For $i = 1 To $aCtrlsEx[0][0]
			If $aCtrlsEx[$i][1] = 'tooltips_class32' Then _GUIDarkTheme_GUICtrlSetDarkTheme($hGui, $aCtrlsEx[$i][0], $bEnableDarkTheme)
		Next
	EndIf

	Return $aCtrls
EndFunc   ;==>_GUIDarkTheme_GUICtrlAllSetDarkTheme

; #FUNCTION# ====================================================================================================================
; Name ..........: _GUIDarkTheme_GUICtrlSetDarkTheme
; Description ...: Sets the dark theme for a specified control.
; Syntax ........: _GUIDarkTheme_GUICtrlSetDarkTheme($hGui, $hCtrl, $bEnableDarkTheme = True)
; Parameters ....: $hGui             - The GUI handle.
;                  $hCtrl            - The control handle.
;                  $bEnableDarkTheme - If True, enables the dark theme; if False, disables it.
;                                      (Default is True for enabling dark theme.)
; Return values .: Success: True
;                  Failure: False and sets the @error flag:
;                           1: Invalid control handle.
;                           2: Error while allowing dark mode for the window.
;                           3: Error while setting the window theme.
;                           4: Error while sending the WM_THEMECHANGED message.
; Author ........: NoNameCode
; Modified ......: WildByDesign
; Remarks .......: This function requires the _WinAPI_SetWindowTheme and __DM_WinAPI_AllowDarkModeForWindow functions.
; Example .......: Yes
; ===============================================================================================================================
Func _GUIDarkTheme_GUICtrlSetDarkTheme($hGui, $hCtrl, $bEnableDarkTheme = Default)
	If $bEnableDarkTheme = Default Then $bEnableDarkTheme = True
	Local $sThemeName = Null, $sThemeList = Null
	Local $iGUI_Ctrl_Color = $__DM_g_iTextColor
	Local $iGUI_Ctrl_BkColor = $__DM_g_iCtrlBkColor
	Local $bSpecialLV = False, $bSpecialTV = False
	Local $sStyles, $iBuddyPos
	Local Const $UDM_GETBUDDY = 1130
	Local Static $bBuddyMoved = False
	Local $hTabControl, $bCtrlInTab = False
	; determine if control is within a tab control
	$hTabControl = _WinAPI_FindWindowEx($hGui, "SysTabControl32")
	If $hTabControl Then $bCtrlInTab = __GUIDarkTheme_IsCtrlInTab($hTabControl, $hCtrl)
	Local $hTheme, $tSIZE
	If Not IsHWnd($hCtrl) Then $hCtrl = GUICtrlGetHandle($hCtrl)
	If Not IsHWnd($hCtrl) Then Return SetError(1, 0, False)
	_WinAPI_AllowDarkModeForWindow($hCtrl, $bEnableDarkTheme)
	If @error <> 0 Then Return SetError(2, @error, False)
	;=========
	;ConsoleWrite(@CRLF & _WinAPI_GetClassName($hCtrl))
	Switch _WinAPI_GetClassName($hCtrl)
		Case 'Button'
			$sStyles = __GUIDarkTheme_hWnd2Styles($hCtrl)
			Local $bSubclassButton = False
			Local $bSubclassGroup = False
			If StringInStr($sStyles, "BS_AUTORADIOBUTTON") Or StringInStr($sStyles, "CHECKBOX") Or StringInStr($sStyles, "BS_AUTO3STATE") Then
				; Subclass checkbox and radio buttons only when run older OS
				If Not $__DM_g_b24H2Plus Then $bSubclassButton = True
			EndIf
			If StringInStr($sStyles, "BS_GROUPBOX") Then
				; Subclass groupbox and when run older OS
				If Not $__DM_g_b24H2Plus Then $bSubclassGroup = True
			EndIf

			Switch $bEnableDarkTheme
				Case True
					If $bSubclassGroup Then
						If Not $__DM_g_hGroupProc Then
							$__DM_g_hGroupProc = DllCallbackRegister(__GUIDarkTheme_GroupProc, "lresult", "hwnd;uint;wparam;lparam;uint_ptr;dword_ptr")
							$__DM_g_pGroupProc = DllCallbackGetPtr($__DM_g_hGroupProc)
						EndIf
						_WinAPI_SetWindowTheme($hCtrl, "DarkMode_Explorer", "Button")
						__GUIDarkTheme_AddToSubclass($hCtrl, $__DM_g_hGroupProc, $__DM_g_pGroupProc, $__DM_g_iControlCount)

						Return True
					EndIf

					If $bSubclassButton Then
						If Not $__DM_g_hButtonProc Then
							$__DM_g_hButtonProc = DllCallbackRegister(__GUIDarkTheme_ButtonProc, "lresult", "hwnd;uint;wparam;lparam;uint_ptr;dword_ptr")
							$__DM_g_pButtonProc = DllCallbackGetPtr($__DM_g_hButtonProc)
						EndIf
						_WinAPI_SetWindowTheme($hCtrl, "DarkMode_Explorer", "Button")
						; Increase the width of controls based on part size plus padding (TODO: causing button growth after theme changes)
						;Local $iPadding = 3
						;Local $aPos = WinGetPos($hCtrl)
						;If Not @error Then _WinAPI_SetWindowPos($hCtrl, 0, $aPos[0], $aPos[1], $aPos[2] + $iPadding, $aPos[3], $SWP_NOMOVE)
						$__DM_g_iButtonCount += 1
						Local $iPartID
						If StringInStr($sStyles, "BS_AUTORADIOBUTTON") Then $iPartID = $BP_RADIOBUTTON
						If StringInStr($sStyles, "CHECKBOX") Then $iPartID = $BP_CHECKBOX
						If StringInStr($sStyles, "BS_AUTO3STATE") Then $iPartID = $BP_CHECKBOX
						Local $aUpdate[1][3] = [[$iPartID, $sStyles, $bCtrlInTab]]
						_ArrayAdd($__DM_g_aButtonSub, $aUpdate)
						__GUIDarkTheme_AddToSubclass($hCtrl, $__DM_g_hButtonProc, $__DM_g_pButtonProc, $__DM_g_iControlCount, $__DM_g_iButtonCount)

						Return True
					EndIf

					$sThemeName = 'DarkMode_Explorer'

					If StringInStr($sStyles, "BS_GROUPBOX") Or StringInStr($sStyles, "BS_AUTORADIOBUTTON") Then
						If Not $__DM_g_b24H2Plus Then _WinAPI_SetWindowTheme($hCtrl, "", "")
						$sThemeName = $__DM_g_b24H2Plus ? 'DarkMode_DarkTheme' : 'DarkMode_Explorer'
						If $bCtrlInTab Then
							If StringInStr($sStyles, "BS_GROUPBOX") Then __DM_GroupboxInTab($hCtrl)
							GUICtrlSetColor(_WinAPI_GetDlgCtrlID($hCtrl), $iGUI_Ctrl_Color)
							GUICtrlSetBkColor(_WinAPI_GetDlgCtrlID($hCtrl), $__DM_g_iTabCtrlBkColor)
						Else
							GUICtrlSetColor(_WinAPI_GetDlgCtrlID($hCtrl), $iGUI_Ctrl_Color)
						EndIf
						If Not $__DM_g_b24H2Plus Then Return True
					Else
						If $bCtrlInTab And StringInStr($sStyles, "CHECKBOX") Then
							GUICtrlSetBkColor(_WinAPI_GetDlgCtrlID($hCtrl), $__DM_g_iTabCtrlBkColor)
						EndIf
					EndIf
				Case False
					$sThemeName = 'Explorer'
					If StringInStr($sStyles, "BS_GROUPBOX") Or StringInStr($sStyles, "BS_AUTORADIOBUTTON") Then
						If $bCtrlInTab Then
							If StringInStr($sStyles, "BS_GROUPBOX") Then __DM_GroupboxInTab($hCtrl)
							GUICtrlSetColor(_WinAPI_GetDlgCtrlID($hCtrl), $iGUI_Ctrl_Color)
							GUICtrlSetBkColor(_WinAPI_GetDlgCtrlID($hCtrl), $__DM_g_iTabCtrlBkColor)
						Else
							GUICtrlSetColor(_WinAPI_GetDlgCtrlID($hCtrl), $iGUI_Ctrl_Color)
						EndIf
					Else
						If $bCtrlInTab And StringInStr($sStyles, "CHECKBOX") Then
							GUICtrlSetBkColor(_WinAPI_GetDlgCtrlID($hCtrl), $__DM_g_iTabCtrlBkColor)
						EndIf
					EndIf
			EndSwitch

			GUIRegisterMsg($WM_CTLCOLORBTN, "__GUIDarkTheme_WM_CTLCOLOR")

		Case 'ReBarWindow32'
			_WinAPI_SetWindowTheme($hCtrl, "", "")
			_SendMessage($hCtrl, $WM_THEMECHANGED, 0, 0)
			_GUICtrlRebar_SetColorScheme($hCtrl, $iGUI_Ctrl_BkColor, $iGUI_Ctrl_BkColor)
			For $i = 0 To _GUICtrlRebar_GetBandCount($hCtrl) - 1
				__GUIDarkTheme_SetBandColor($hCtrl, $i, $iGUI_Ctrl_BkColor, $iGUI_Ctrl_Color)
			Next
			; Style fixes to improve theme design
			_WinAPI_SetWindowLong($hCtrl, $GWL_STYLE, BitOR(_WinAPI_GetWindowLong($hCtrl, $GWL_STYLE), $CCS_NODIVIDER))
			_WinAPI_SetWindowLong($hCtrl, $GWL_STYLE, BitXOR(_WinAPI_GetWindowLong($hCtrl, $GWL_STYLE), $RBS_BANDBORDERS))
			_WinAPI_SetWindowPos($hCtrl, 0, 0, 0, 0, 0, $SWP_NOMOVE)
			__GUIDarkTheme_AddToSubclass($hCtrl, $__DM_g_hSubclassProc, $__DM_g_pSubclassProc, $__DM_g_iControlCount)

			Return True

		Case 'ToolbarWindow32'
			If _GUICtrlToolbar_GetStyleFlat($hCtrl) And _GUICtrlToolbar_GetStyleTransparent($hCtrl) Then
				; remove the transparent bit in the case of default AutoIt created toolbar (transparent should not be default)
				_GUICtrlToolbar_SetStyleTransparent($hCtrl, False)
				_GUICtrlToolbar_SetStyleFlat($hCtrl, False)
			EndIf
			If _GUICtrlToolbar_GetStyleTransparent($hCtrl) Then
				_GUICtrlToolbar_SetColorScheme($hCtrl, $__DM_g_iGuiBkColor, $__DM_g_iGuiBkColor)
			Else
				;_GUICtrlToolbar_SetColorScheme($hCtrl, $iGUI_Ctrl_BkColor, $iGUI_Ctrl_BkColor)
				_GUICtrlToolbar_SetColorScheme($hCtrl, $__DM_g_iGuiBkColor, $__DM_g_iGuiBkColor)
			EndIf

			GUIRegisterMsg($WM_NOTIFY, "__GUIDarkTheme_WM_NOTIFY")

			Return True

		Case 'SysIPAddress32'
			ConsoleWrite("IP Address control detected." & @CRLF)
			__GUIDarkTheme_AddToSubclass($hCtrl, $__DM_g_hSubclassProc, $__DM_g_pSubclassProc, $__DM_g_iControlCount)

			Return True

		Case 'msctls_hotkey32'
			ConsoleWrite("HotKey control detected." & @CRLF)

			Return True

		Case 'msctls_trackbar32'
			GUICtrlSetColor(_WinAPI_GetDlgCtrlID($hCtrl), $iGUI_Ctrl_Color)
			GUICtrlSetBkColor(_WinAPI_GetDlgCtrlID($hCtrl), $__DM_g_iGuiBkColor)

			GUIRegisterMsg($WM_NOTIFY, "__GUIDarkTheme_WM_NOTIFY")

			; remove focus rectangle from slider control
			_SendMessage($hCtrl, $WM_CHANGEUISTATE, 65537, 0)

		Case 'SysLink'
			If $bEnableDarkTheme Then
				GUIRegisterMsg($WM_CTLCOLORSTATIC, "__GUIDarkTheme_WM_CTLCOLOR")
			Else
				GUIRegisterMsg($WM_CTLCOLORSTATIC, "")
			EndIf

			GUIRegisterMsg($WM_NOTIFY, "__GUIDarkTheme_WM_NOTIFY")

			Return True

		Case 'msctls_updown32'
			If $bEnableDarkTheme Then
				;$sThemeName = 'DarkMode_Explorer'
				$sThemeName = $__DM_g_b24H2Plus ? 'DarkMode_DarkTheme' : 'DarkMode_Explorer'
			Else
				$sThemeName = 'Explorer'
			EndIf

			; move UpDown control by 2 pixel to prevent clipping
			If BitAND(_WinAPI_GetWindowLong($hCtrl, $GWL_STYLE), $UDS_ALIGNLEFT) Then
				$iBuddyPos = -2
			Else
				$iBuddyPos = 2
			EndIf
			Local $hBuddy = HWnd(_SendMessage($hCtrl, $UDM_GETBUDDY))
			If $hBuddy And _WinAPI_GetClassName($hBuddy) = "Edit" Then
				If Not $bBuddyMoved Then GUICtrlSetPos(_WinAPI_GetDlgCtrlID($hCtrl), ControlGetPos("", "", $hCtrl)[0] + $iBuddyPos)
				$bBuddyMoved = True
			EndIf
			If Not $__DM_g_hUpDownSub Then
				$__DM_g_hUpDownSub = DllCallbackRegister(__GUIDarkTheme_UpDownProc, "lresult", "hwnd;uint;wparam;lparam;uint_ptr;dword_ptr")
				$__DM_g_pUpDownSub = DllCallbackGetPtr($__DM_g_hUpDownSub)
			EndIf
			__GUIDarkTheme_AddToSubclass($hCtrl, $__DM_g_hUpDownSub, $__DM_g_pUpDownSub, $__DM_g_iControlCount)

		Case 'ListBox'
			_WinAPI_SetWindowLong($hCtrl, $GWL_EXSTYLE, BitAND(_WinAPI_GetWindowLong($hCtrl, $GWL_EXSTYLE), BitNOT($WS_EX_CLIENTEDGE)))
			__GUIDarkTheme_AddToSubclass($hCtrl, $__DM_g_hSubclassProc, $__DM_g_pSubclassProc, $__DM_g_iControlCount)
			_WinAPI_SetWindowPos($hCtrl, 0, 0, 0, 0, 0, BitOR($SWP_NOMOVE, $SWP_NOSIZE, $SWP_NOZORDER, $SWP_FRAMECHANGED))

			Switch $bEnableDarkTheme
				Case True
					$sThemeName = $__DM_g_b24H2Plus ? 'DarkMode_DarkTheme' : 'DarkMode_Explorer'
				Case False
					$sThemeName = 'Explorer'
			EndSwitch

			GUIRegisterMsg($WM_CTLCOLORLISTBOX, "__GUIDarkTheme_WM_CTLCOLOR")

		Case 'SysTreeView32'
			$sStyles = __GUIDarkTheme_hWnd2Styles($hCtrl)
			__GUIDarkTheme_AddToSubclass($hCtrl, $__DM_g_hSubclassProc, $__DM_g_pSubclassProc, $__DM_g_iControlCount)
			_WinAPI_SetWindowPos($hCtrl, 0, 0, 0, 0, 0, BitOR($SWP_NOMOVE, $SWP_NOSIZE, $SWP_NOZORDER, $SWP_FRAMECHANGED))

			Switch $bEnableDarkTheme
				Case True
					;$sThemeName = $__DM_g_b24H2Plus ? 'DarkMode_DarkTheme' : 'DarkMode_Explorer' ; DarkMode_DarkTheme still has some bugs
					$sThemeName = $__DM_g_b24H2Plus ? 'DarkMode_Explorer' : 'DarkMode_Explorer'

					; dark mode checkboxes
					If StringInStr($sStyles, "TVS_CHECKBOXES") Then
						$bSpecialTV = True
					EndIf
				Case False
					$sThemeName = 'Explorer'
					; light mode checkboxes
					If StringInStr($sStyles, "TVS_CHECKBOXES") Then
						$bSpecialTV = True
					EndIf
			EndSwitch

			GUICtrlSetColor(_WinAPI_GetDlgCtrlID($hCtrl), $iGUI_Ctrl_Color)
			GUICtrlSetBkColor(_WinAPI_GetDlgCtrlID($hCtrl), $iGUI_Ctrl_BkColor)

			; Add TVS_EX_DOUBLEBUFFER extended style to TreeView control
			_GUICtrlTreeView_SetExtendedStyle($hCtrl, $TVS_EX_DOUBLEBUFFER)

		Case 'SysListView32'
			; Add LVS_EX_DOUBLEBUFFER to ListView control
			Local $iExStyle = _GUICtrlListView_GetExtendedListViewStyle($hCtrl)
			_GUICtrlListView_SetExtendedListViewStyle($hCtrl, BitOR($iExStyle, $LVS_EX_DOUBLEBUFFER))

			Switch $bEnableDarkTheme
				Case True
					;$sThemeName = $__DM_g_b24H2Plus ? 'DarkMode_DarkTheme' : 'DarkMode_Explorer' ; DarkMode_DarkTheme border is not great
					$sThemeName = 'DarkMode_Explorer'

					; checkbox dark mode
					If (BitAND(_GUICtrlListView_GetExtendedListViewStyle($hCtrl), $LVS_EX_CHECKBOXES) = $LVS_EX_CHECKBOXES) Then
						$bSpecialLV = True
					EndIf
				Case False
					$sThemeName = 'Explorer'
					; checkbox light mode
					If (BitAND(_GUICtrlListView_GetExtendedListViewStyle($hCtrl), $LVS_EX_CHECKBOXES) = $LVS_EX_CHECKBOXES) Then
						$bSpecialLV = True
					EndIf
			EndSwitch

			__GUIDarkTheme_AddToSubclass($hCtrl, $__DM_g_hSubclassProc, $__DM_g_pSubclassProc, $__DM_g_iControlCount)
			_WinAPI_SetWindowLong($hCtrl, $GWL_EXSTYLE, BitAND(_WinAPI_GetWindowLong($hCtrl, $GWL_EXSTYLE), BitNOT($WS_EX_CLIENTEDGE)))
			_WinAPI_SetWindowPos($hCtrl, 0, 0, 0, 0, 0, BitOR($SWP_NOMOVE, $SWP_NOSIZE, $SWP_NOZORDER, $SWP_FRAMECHANGED))

			GUICtrlSetColor(_WinAPI_GetDlgCtrlID($hCtrl), $iGUI_Ctrl_Color)
			GUICtrlSetBkColor(_WinAPI_GetDlgCtrlID($hCtrl), $iGUI_Ctrl_BkColor)

		Case 'Edit'
			Local $sEditParent = _WinAPI_GetClassName(_WinAPI_GetParent($hCtrl))
			If $sEditParent <> "ComboBox" Then
				_WinAPI_SetWindowLong($hCtrl, $GWL_EXSTYLE, BitAND(_WinAPI_GetWindowLong($hCtrl, $GWL_EXSTYLE), BitNOT($WS_EX_CLIENTEDGE)))
				__GUIDarkTheme_AddToSubclass($hCtrl, $__DM_g_hSubclassProc, $__DM_g_pSubclassProc, $__DM_g_iControlCount)
				_WinAPI_SetWindowPos($hCtrl, 0, 0, 0, 0, 0, BitOR($SWP_NOMOVE, $SWP_NOSIZE, $SWP_NOZORDER, $SWP_FRAMECHANGED))
			EndIf

			Switch $bEnableDarkTheme
				Case True
					$sThemeName = $__DM_g_b24H2Plus ? 'DarkMode_DarkTheme' : 'DarkMode_Explorer'
				Case False
					$sThemeName = 'Explorer'
			EndSwitch

			GUIRegisterMsg($WM_CTLCOLOREDIT, "__GUIDarkTheme_WM_CTLCOLOR")
			GUIRegisterMsg($WM_CTLCOLORSTATIC, "__GUIDarkTheme_WM_CTLCOLOR")

		Case 'SysHeader32'
			Switch $bEnableDarkTheme
				Case True
					$sThemeName = $__DM_g_b24H2Plus ? 'DarkMode_DarkTheme' : 'DarkMode_ItemsView'
					;$sThemeName = 'DarkMode_ItemsView'
				Case False
					$sThemeName = 'ItemsView'
			EndSwitch
			$sThemeList = 'Header'

		Case 'Static'
			Local $iTextColor, $iBkColor, $iBkMode
			__GUIDarkTheme_GetCtrlColors($hCtrl, $iTextColor, $iBkColor, $iBkMode)

			Switch $iTextColor
				Case 0x000000
					GUICtrlSetColor(_WinAPI_GetDlgCtrlID($hCtrl), $iGUI_Ctrl_Color)
				Case $__DM_g_iTextColorDark
					GUICtrlSetColor(_WinAPI_GetDlgCtrlID($hCtrl), $iGUI_Ctrl_Color)
				Case $__DM_g_iTextColorLight
					GUICtrlSetColor(_WinAPI_GetDlgCtrlID($hCtrl), $iGUI_Ctrl_Color)
				Case Else
					; skip swapping any custom colors
					GUICtrlSetColor(_WinAPI_GetDlgCtrlID($hCtrl), $iTextColor)
			EndSwitch

			If $hTabControl Then
				If $bCtrlInTab Then
					Switch $iBkColor
						Case $__DM_g_iTabCtrlBkColorDark
							GUICtrlSetBkColor(_WinAPI_GetDlgCtrlID($hCtrl), $__DM_g_iTabCtrlBkColor)
						Case $__DM_g_iTabCtrlBkColorLight
							GUICtrlSetBkColor(_WinAPI_GetDlgCtrlID($hCtrl), $__DM_g_iTabCtrlBkColor)
						Case $__DM_g_iCtrlBkColorDark
							GUICtrlSetBkColor(_WinAPI_GetDlgCtrlID($hCtrl), $__DM_g_iTabCtrlBkColor)
						Case $__DM_g_iCtrlBkColorLight
							GUICtrlSetBkColor(_WinAPI_GetDlgCtrlID($hCtrl), $__DM_g_iTabCtrlBkColor)
						Case $__DM_g_iGuiBkColor
							GUICtrlSetBkColor(_WinAPI_GetDlgCtrlID($hCtrl), $__DM_g_iTabCtrlBkColor)
						Case Else
							Switch $iBkMode
								Case $TRANSPARENT
									GUICtrlSetBkColor(_WinAPI_GetDlgCtrlID($hCtrl), $__DM_g_iTabCtrlBkColor)
								Case $OPAQUE
									; skip making any custom colors transparent
									GUICtrlSetBkColor(_WinAPI_GetDlgCtrlID($hCtrl), $iBkColor)
							EndSwitch
					EndSwitch
				Else
					Switch $iBkColor
						Case $__DM_g_iCtrlBkColor
							GUICtrlSetBkColor(_WinAPI_GetDlgCtrlID($hCtrl), $GUI_BKCOLOR_TRANSPARENT)
						Case $__DM_g_iGuiBkColor
							GUICtrlSetBkColor(_WinAPI_GetDlgCtrlID($hCtrl), $GUI_BKCOLOR_TRANSPARENT)
						Case Else
							Switch $iBkMode
								Case $TRANSPARENT
									GUICtrlSetBkColor(_WinAPI_GetDlgCtrlID($hCtrl), $GUI_BKCOLOR_TRANSPARENT)
								Case $OPAQUE
									; skip making any custom colors transparent
									GUICtrlSetBkColor(_WinAPI_GetDlgCtrlID($hCtrl), $iBkColor)
							EndSwitch
					EndSwitch
				EndIf
			Else
				Switch $iBkColor
					Case $__DM_g_iCtrlBkColor
						GUICtrlSetBkColor(_WinAPI_GetDlgCtrlID($hCtrl), $GUI_BKCOLOR_TRANSPARENT)
					Case $__DM_g_iGuiBkColor
						GUICtrlSetBkColor(_WinAPI_GetDlgCtrlID($hCtrl), $GUI_BKCOLOR_TRANSPARENT)
					Case Else
						Switch $iBkMode
							Case $TRANSPARENT
								GUICtrlSetBkColor(_WinAPI_GetDlgCtrlID($hCtrl), $GUI_BKCOLOR_TRANSPARENT)
							Case $OPAQUE
								; skip making any custom colors transparent
								GUICtrlSetBkColor(_WinAPI_GetDlgCtrlID($hCtrl), $iBkColor)
						EndSwitch
				EndSwitch
			EndIf

			Return True

		Case 'SysDateTimePick32'
			If $bEnableDarkTheme Then
				; TODO: there is a crash in DateProc when Date ctrl in Rebar and rebar gets resized
				__DM_DateTimeCtrlHandles($hCtrl)
				If Not $__DM_g_hDateProc Then $__DM_g_hDateProc = DllCallbackRegister(__GUIDarkTheme_DateProc, 'ptr', 'hwnd;uint;wparam;lparam')
				If Not $__DM_g_pDateProc Then $__DM_g_pDateProc = DllCallbackGetPtr($__DM_g_hDateProc)
				If Not $__DM_g_hDateProcOld Then
					$__DM_g_hDateProcOld = _WinAPI_SetWindowLong($hCtrl, $GWL_WNDPROC, $__DM_g_pDateProc)
				Else
					_WinAPI_SetWindowLong($hCtrl, $GWL_WNDPROC, $__DM_g_pDateProc)
				EndIf
				; set colors for dropdown calendar
				_GUICtrlDTP_SetMCColor($hCtrl, 0, $__DM_g_iCtrlBkColor)
				_GUICtrlDTP_SetMCColor($hCtrl, 1, $__DM_g_iTextColor)
				_GUICtrlDTP_SetMCColor($hCtrl, 2, _WinAPI_SwitchColor(0x0078D4))
				_GUICtrlDTP_SetMCColor($hCtrl, 3, $__DM_g_iTextColor)
				_GUICtrlDTP_SetMCColor($hCtrl, 4, $__DM_g_iCtrlBkColor)
				_GUICtrlDTP_SetMCColor($hCtrl, 5, $__DM_g_iTextColor)
			EndIf

			GUIRegisterMsg($WM_NOTIFY, "__GUIDarkTheme_WM_NOTIFY")

		Case 'msctls_progress32'
			Local $iProgressHide = False
			; Get state and progress position
			Local $iProgressPos = _SendMessage($hCtrl, $PBM_GETPOS, 0, 0)
			Local $iProgressState = _SendMessage($hCtrl, $PBM_GETSTATE, 0, 0)
			Local $iCtrlState = GUICtrlGetState(_WinAPI_GetDlgCtrlID($hCtrl))
			If BitAND($iCtrlState, $GUI_HIDE) Then $iProgressHide = True

			; Remove theme and WS_EX_STATICEDGE extended style
			_WinAPI_SetWindowTheme($hCtrl, "", "")
			_WinAPI_SetWindowLong($hCtrl, $GWL_EXSTYLE, BitXOR(_WinAPI_GetWindowLong($hCtrl, $GWL_EXSTYLE), $WS_EX_STATICEDGE))

			; Determine bar color based on state
			; TODO: bar color can't seem to be changed for PBST_ERROR or PBST_PAUSED
			Local $iBarColor
			Switch $iProgressState
				Case BitAND($iProgressState, $PBST_NORMAL)
					$iBarColor = _WinAPI_SwitchColor($__DM_g_iAccentColor)
				Case BitAND($iProgressState, $PBST_ERROR)
					$iBarColor = _WinAPI_SwitchColor(0xFF2222)
				Case BitAND($iProgressState, $PBST_PAUSED)
					$iBarColor = _WinAPI_SwitchColor(0xFCE100)
				Case Else
					$iBarColor = _WinAPI_SwitchColor($__DM_g_iAccentColor)
			EndSwitch

			_SendMessage($hCtrl, $PBM_SETBARCOLOR, 0, $iBarColor)
			_SendMessage($hCtrl, $PBM_SETBKCOLOR, 0, $__DM_g_iCtrlBkColor)

			; Add WS_BORDER style
			If BitAND(_WinAPI_GetWindowLong($hCtrl, $GWL_STYLE), $PBM_SETMARQUEE) Then
				GUICtrlSetStyle(_WinAPI_GetDlgCtrlID($hCtrl), BitOR($PBM_SETMARQUEE, $WS_BORDER))
			Else
				GUICtrlSetStyle(_WinAPI_GetDlgCtrlID($hCtrl), $WS_BORDER)
			EndIf

			; SetWindowPos is needed to allow the WS_BORDER change
			_WinAPI_SetWindowPos($hCtrl, 0, 0, 0, 0, 0, BitOR($SWP_NOMOVE, $SWP_NOSIZE, $SWP_NOZORDER, $SWP_FRAMECHANGED))

			; Restore progress to original value since progress is lost after SetWindowLong
			_SendMessage($hCtrl, $PBM_SETPOS, $iProgressPos, 0)
			GUICtrlSetData(_WinAPI_GetDlgCtrlID($hCtrl), $iProgressPos)

			If $iProgressHide Then GUICtrlSetState(_WinAPI_GetDlgCtrlID($hCtrl), $GUI_HIDE)

			Return True

		Case 'Scrollbar'
			If $bEnableDarkTheme Then $sThemeName = 'DarkMode_Explorer'

		Case 'AutoIt v3 GUI'
			If $bEnableDarkTheme Then
				$sThemeName = 'DarkMode_Explorer'
			EndIf

		Case 'msctls_statusbar32'
			; get handle for statusbar
			$__DM_g_hStatus = $hCtrl
			Local Const $SP_GRIPPER = 3
			Local Const $TS_TRUE = 1
			$hTheme = _WinAPI_OpenThemeData($hGui, 'Status')
			$tSIZE = _WinAPI_GetThemePartSize($hTheme, $SP_GRIPPER, 0, Null, Null, $TS_TRUE)
			$__DM_g_hGripSize = $tSIZE.X
			_WinAPI_CloseThemeData($hTheme)

			If $bEnableDarkTheme Then
				$sThemeName = $__DM_g_b24H2Plus ? 'DarkMode_DarkTheme' : 'DarkMode'
				$sThemeList = $__DM_g_b24H2Plus ? 'Status' : 'ExplorerStatusBar'
				$__DM_g_iStatusBkColor = $__DM_g_b24H2Plus ? 0x3b3b3b : 0x1C1C1C
				$__DM_g_iGripPos = $__DM_g_b24H2Plus ? 0 : 1
			EndIf

			; create sizebox/sizegrip and register WM_SIZE only if GUI is resizable
			If __GUIDarkTheme_GUI_IsResizable($hGui) Then
				GUIRegisterMsg($WM_SIZE, "__GUIDarkTheme_WM_SIZE")
				__GUIDarkTheme_StatusRatio($hGui)
				__GUIDarkTheme_CreateSizebox($hGui)

				Switch $bEnableDarkTheme
					Case True
						_WinAPI_ShowWindow($__DM_g_hSizebox, @SW_SHOW)
					Case False
						_WinAPI_ShowWindow($__DM_g_hSizebox, @SW_HIDE)
				EndSwitch
				_WinAPI_RedrawWindow($__DM_g_hSizebox)
			EndIf

		Case 'tooltips_class32'
			If $bEnableDarkTheme Then
				;$sThemeName = $__DM_g_b24H2Plus ? 'DarkMode_DarkTheme' : 'DarkMode_Explorer' ; works but is faded
				$sThemeName = $__DM_g_b24H2Plus ? 'DarkMode_Explorer' : 'DarkMode_Explorer'
				$sThemeList = 'ToolTip'
			EndIf

		Case 'ComboBox'
			If $bEnableDarkTheme Then
				$sThemeName = $__DM_g_b24H2Plus ? 'DarkMode_DarkTheme' : 'DarkMode_CFD'
				$sThemeList = 'Combobox'
				_WinAPI_SetWindowTheme($hCtrl, $sThemeName, $sThemeList)
				_SendMessage($hCtrl, $WM_THEMECHANGED, 0, 0)
				__GUIDarkTheme_AddToSubclass($hCtrl, $__DM_g_hSubclassProc, $__DM_g_pSubclassProc, $__DM_g_iControlCount)
			EndIf

			If Not $bEnableDarkTheme Then
				$sThemeName = 'CFD'
				$sThemeList = 'Combobox'
				_WinAPI_SetWindowTheme($hCtrl, $sThemeName, $sThemeList)
				_SendMessage($hCtrl, $WM_THEMECHANGED, 0, 0)
			EndIf

			; Fix for focus rectangle showing on disabled combo
			Local $iState = WinGetState($hCtrl)
			If Not BitAND($iState, $WIN_STATE_ENABLED) Then
				WinSetState($hCtrl, "", @SW_ENABLE)
				ControlFocus($hCtrl, "", "")
    			ControlSend($hCtrl, "", "", "{END}")
				WinSetState($hCtrl, "", @SW_DISABLE)
			Else
				ControlFocus($hCtrl, "", "")
    			ControlSend($hCtrl, "", "", "{END}")
			EndIf

			Return True

		Case 'SysMonthCal32'
			_GUICtrlMonthCal_SetColor($hCtrl, $MCSC_TEXT, $__DM_g_iTextColor)
			_GUICtrlMonthCal_SetColor($hCtrl, $MCSC_TITLEBK, _WinAPI_SwitchColor(0x0078D4))
			_GUICtrlMonthCal_SetColor($hCtrl, $MCSC_TITLETEXT, $__DM_g_iTextColor)
			_GUICtrlMonthCal_SetColor($hCtrl, $MCSC_BACKGROUND, $__DM_g_iCtrlBkColor)
			_GUICtrlMonthCal_SetColor($hCtrl, $MCSC_MONTHBK, $__DM_g_iCtrlBkColor)
			_GUICtrlMonthCal_SetColor($hCtrl, $MCSC_TRAILINGTEXT, $__DM_g_iTextColor)
			_WinAPI_SetWindowTheme($hCtrl, "", "")
			_SendMessage($hCtrl, $WM_THEMECHANGED, 0, 0)

			Return True

		Case 'SysTabControl32'
			If $bEnableDarkTheme Then
				$sThemeName = $__DM_g_b24H2Plus ? 'DarkMode_DarkTheme' : 'DarkMode_Explorer'
				$sThemeList = 'Tab'
			Else
				$sThemeName = 'Explorer'
			EndIf

			If Not $__DM_g_hTabProc Then
				_WinAPI_SetWindowPos($hCtrl, $HWND_BOTTOM, 0, 0, 0, 0, BitOR($SWP_NOMOVE, $SWP_NOREDRAW, $SWP_NOSIZE))
				$__DM_g_hTabProc = DllCallbackRegister(__GUIDarkTheme_TabProc, "lresult", "hwnd;uint;wparam;lparam;uint_ptr;dword_ptr")
				$__DM_g_pTabProc = DllCallbackGetPtr($__DM_g_hTabProc)
			EndIf
			__GUIDarkTheme_AddToSubclass($hCtrl, $__DM_g_hTabProc, $__DM_g_pTabProc, $__DM_g_iControlCount)

			; remove focus rectangle from tab items
			_SendMessage($hCtrl, $WM_CHANGEUISTATE, 65537, 0)

		Case Else
			$sThemeName = 'DarkMode_Explorer'

	EndSwitch
	;ConsoleWrite(@CRLF & 'Class:' & _WinAPI_GetClassName($hCtrl) & ' Theme:' & $sThemeName & '::' & $sThemeList)
	;=========
	_WinAPI_SetWindowTheme($hCtrl, $sThemeName, $sThemeList)
	If @error <> 0 Then Return SetError(3, @error, False)
	_SendMessage($hCtrl, $WM_THEMECHANGED, 0, 0)
	If @error <> 0 Then Return SetError(4, @error, False)

	Local $iSize, $hChecked, $hUnchecked
	If $bSpecialLV Then
		Local $hImageListLV = _GUICtrlListView_GetImageList($hCtrl, 2)
		$iSize = _GUIImageList_GetIconHeight($hImageListLV)
		_GUIImageList_Remove($hImageListLV)
		If @OSBuild >= 22000 Then
			$hUnchecked = __GUIDarkTheme_GetImages($hGui, 0, 3, $iSize, $iSize)
			$hChecked = __GUIDarkTheme_GetImages($hGui, 5, 3, $iSize, $iSize)
			_GUIImageList_Add($hImageListLV, $hUnchecked)
			_GUIImageList_Add($hImageListLV, $hChecked)
			_WinAPI_DeleteObject($hChecked)
			_WinAPI_DeleteObject($hUnchecked)
		Else
			$hChecked = _GDIPlus_BitmapCreateFromMemory(__GUIDarkTheme_CheckedPNG($iSize), True)
			$hUnchecked = _GDIPlus_BitmapCreateFromMemory(__GUIDarkTheme_UncheckedPNG($iSize), True)
			_GUIImageList_Add($hImageListLV, $hUnchecked)
			_GUIImageList_Add($hImageListLV, $hChecked)
		EndIf
	EndIf
	If $bSpecialTV Then
		Local $hImageListTV = _GUICtrlTreeView_GetStateImageList($hCtrl)
		$iSize = _GUIImageList_GetIconHeight($hImageListTV)
		_GUIImageList_Remove($hImageListTV)
		If @OSBuild >= 22000 Then
			$hUnchecked = __GUIDarkTheme_GetImages($hGui, 0, 3, $iSize, $iSize)
			$hChecked = __GUIDarkTheme_GetImages($hGui, 5, 3, $iSize, $iSize)
			_GUIImageList_Add($hImageListTV, $hUnchecked)
			_GUIImageList_Add($hImageListTV, $hUnchecked)
			_GUIImageList_Add($hImageListTV, $hChecked)
			_WinAPI_DeleteObject($hChecked)
			_WinAPI_DeleteObject($hUnchecked)
		Else
			$hChecked = _GDIPlus_BitmapCreateFromMemory(__GUIDarkTheme_CheckedPNG($iSize), True)
			$hUnchecked = _GDIPlus_BitmapCreateFromMemory(__GUIDarkTheme_UncheckedPNG($iSize), True)
			_GUIImageList_Add($hImageListTV, $hUnchecked)
			_GUIImageList_Add($hImageListTV, $hUnchecked)
			_GUIImageList_Add($hImageListTV, $hChecked)
		EndIf
	EndIf

	Return True
EndFunc   ;==>_GUIDarkTheme_GUICtrlSetDarkTheme

; #FUNCTION# ====================================================================================================================
; Author.........: WildByDesign
; ===============================================================================================================================
Func _GUIDarkTheme_ApplyAuto($hGui)
	If $__DM_g_bUseDarkMode Then
		_GUIDarkTheme_GUISetDarkTheme($hGui, True)
		_GUIDarkTheme_GUICtrlAllSetDarkTheme($hGui, True)
	Else
		_GUIDarkTheme_GUISetDarkTheme($hGui, False)
		_GUIDarkTheme_GUICtrlAllSetDarkTheme($hGui, False)
	EndIf

	; register WM_SETTINGCHANGE to monitor for system color mode changes
	_GUIDarkTheme_AutoTheme()

	; GUIDarkMenu register
	_GUIDarkMenu_Register($hGui)
EndFunc   ;==>_GUIDarkTheme_ApplyAuto

; #FUNCTION# ====================================================================================================================
; Name ..........: _GUIDarkTheme_ApplyDark
; Description ...: Automatically sets dark theme for GUI and all controls (with automatic subclassing when necessary)
; Syntax ........: _GUIDarkTheme_ApplyDark($hGui)
; Parameters ....: $hGui          		- The handle to the window.
; Return values .: None
; Author ........: WildByDesign
; Example .......: No
; ===============================================================================================================================
Func _GUIDarkTheme_ApplyDark($hGui)
	_GUIDarkTheme_GUISetDarkTheme($hGui, True)
	_GUIDarkTheme_GUICtrlAllSetDarkTheme($hGui, True)

	; GUIDarkMenu register
	_GUIDarkMenu_Register($hGui)
EndFunc   ;==>_GUIDarkTheme_ApplyDark

; #FUNCTION# ====================================================================================================================
; Name ..........: _GUIDarkTheme_ApplyLight
; Description ...: Automatically sets light theme for GUI and all controls (with automatic subclassing when necessary)
; Syntax ........: _GUIDarkTheme_ApplyLight($hGui)
; Parameters ....: $hGui          		- The handle to the window.
; Return values .: None
; Author ........: WildByDesign
; Example .......: No
; ===============================================================================================================================
Func _GUIDarkTheme_ApplyLight($hGui)
	_GUIDarkTheme_GUISetDarkTheme($hGui, False)
	_GUIDarkTheme_GUICtrlAllSetDarkTheme($hGui, False)
	; GUIDarkMenu register
	_GUIDarkMenu_Register($hGui)
EndFunc   ;==>_GUIDarkTheme_ApplyLight

; #FUNCTION# ====================================================================================================================
; Author.........: WildByDesign
; Modified.......: UEZ, argumentum
; ===============================================================================================================================
Func __GUIDarkTheme_CheckedPNG($iSize = 16, $sSavePath = Default)
	Local $Base64String, $iExt = (IsKeyword($sSavePath) ? 0 : 2) ; "BitAND(@extended, 2)" meant that the user wanted to save to disk
	Switch $iSize
		Case 13
			$Base64String &= 'iVBORw0KGgoAAAANSUhEUgAAAA0AAAANCAYAAABy6+R8AAAAAXNSR0IB2cksfwAAAARnQU1BAACxjwv8YQUAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAAAlwSFlzAAAOwwAADsMBx2+oZAAAAAd0SU1FB+oDAxcYOepp4t4AAADpSURBVCjPY2RgYGAwSG9o0IrMz2fjFRBgwAF+ff7w4c7mBQtO9RYWMpuVTJigm1BezszOwcGABzCzc3CI6lpYMDAwMDBGHXj/Hp8N2GxkIkUDAwMDAxuvgAATMQrvbF6Awieo6Uh9AgMDIyNuTY8ObMDQIGHqyKDiE49b06/PHxiONCTi1cDAwMDAgsxR8U1gYGBgYFjjq8hgkN6AVQMDAwMDY8LZ//+xBCsDGy/uQGX69fnDByzBijeemJnZODgkTBwciI2nm2tnzGB+cfbgQTZeAQF+BQ0NfEnp1+cPHy4v6Og4O6WyEgBYG0pIgbNupgAAAABJRU5ErkJggg=='
		Case 20
			$Base64String &= 'iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAAAXNSR0IB2cksfwAAAARnQU1BAACxjwv8YQUAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAAAlwSFlzAAAOwwAADsMBx2+oZAAAAAd0SU1FB+oDAxcZJn563moAAAEdSURBVDjLY2RgYFDilVZUs66f3yqkpq/GxivAw0AieHRg46FTvQXtX58/vMXII6Vg5bfs/A42XgFeBgrAr88fPm2KNPRktmlYMFNI3UCbgULAzM7BLqRuoMGYcPb/fwYqgV+fP3xkYqAiYOMV4KeqgQwMDAyDw8B3ty4wbIo0xCrHQo5h+4oCGZz61lPuQmTDhNQMiDdwU6Qhw7tbF0g2DKeBNo3zGfYVB8INJdYwBgYGBpwJ+92tCwz7igMZDNLqGS7MbCTKMLwGkuoyogwcHAn71+cPH6hq4LtbFy5Qy7BHBzZsYOSRUlDwW3b+PBuvgACFRdeHTZGGhsy/Pn/4cH/XypU8UgoK/AoaGuQY9PryiRO7cz09vzx/8AAAGLWDCCvF1IEAAAAASUVORK5CYII='
		Case 26
			$Base64String &= 'iVBORw0KGgoAAAANSUhEUgAAABoAAAAaCAYAAACpSkzOAAAAAXNSR0IB2cksfwAAAARnQU1BAACxjwv8YQUAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAAAlwSFlzAAAOwwAADsMBx2+oZAAAAAd0SU1FB+oDAxcaCxCI0dwAAAF1SURBVEjH7da9a8JAGAbwJ1pSh1iyFGqmG5wKHaQgDh10c7FTF7e4uCr4D+heyKpOuhQculgH6WICTgU1q0Uwk41Dy0EChVvs0JamBa3mQyj0mY/8eLjcy8vhI4JEyGm+VIrnZJmPiiI8xF4YhjlSVb1Rq9lPhgEAHADEc7KcrCiKV+BnmEXpw3W5POu125wgEXJ5M5n4jTixbj6RCCcrinJ8lkohoIQPIxEA4K5687kQIwQBhlmUcvJotcIeEsKe8g+tu2z0i2kMq4W1Zw78QTJgNsVFrRVMIyeSbQ4gxIj/0C7IRkhvVNHNJ8As6hnZCMVz8tcHHZgbZCMkSATZ5uAb5hYBgF9HkL0w0C9mwEffh7sbZKufwdnMLbJVI2czcHCF7PRgBYn8kVnHLEqDRuyFYYRmd61W0JA5UtX9LSfMovT1ebk8OU+nPxcJv9ctc6xpYQB4edT1+X2nw0dFkT8SRa/tmEXp9LZeH1YLBXOsaQDwBivy2deCjE70AAAAAElFTkSuQmCC'
		Case 32
			$Base64String &= 'iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAAXNSR0IB2cksfwAAAARnQU1BAACxjwv8YQUAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAAAlwSFlzAAAOwwAADsMBx2+oZAAAAAd0SU1FB+oDAxccGixiVqgAAAGaSURBVFjD7dcxaMJQFIXhk6Skdgh9tAiZSqcigmARxKFD7OTYVad2EbcguDdduolxjEu3bNLSyUy+oSAIgUyBdJKCNJMG7ORipxSxFKOGBIp3CiHh/wgXwmOwNGJOktIVWRZzksQLhCDEmc88zzUptfV22zUp9e8z/kW+oarpsiwjgrF1VR0263UA4KKOA0AyUyjwAiHjgWEwYk6SSp1+HzFMr1oscvlGq3V8nkrFAeAFQpgKnU7DXrhNFpONK+5/ARYxzx7wfwG2rmLYrMcDsDQFw2YdE8eKHmBpCqzOA04usrhuPkcLWI6XOn3wAokOsE08EOC1fLl2mbaNBwKcFW9g6yrelLvQ4wBwsO6BbPX+JwQAV8pTaPFAgL8QYcQDA1YRE8fC5N3aOb4RYBURRhwAmFtzsdj0pQ/6AjEn7RzfGrD/G4YKmM88L674fOZ57PIxKepxTUpZW2+34wLYuqpyX5+jES8QkswUClHHna6mcQAwHhhGlIhfh1Mf4ZqU8gIhR6eiyB0mEmEv3HjQ6w0eazWnq2n+/W+c6MNyCJEgYgAAAABJRU5ErkJggg=='
		Case 40
			$Base64String &= 'iVBORw0KGgoAAAANSUhEUgAAACgAAAAoCAYAAACM/rhtAAAAAXNSR0IB2cksfwAAAARnQU1BAACxjwv8YQUAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAAAlwSFlzAAAOwwAADsMBx2+oZAAAAAd0SU1FB+oDAxccOPkCF0wAAAHRSURBVFjD7dg9a8JAGAfwRwPBgkKwFNRB4mKhUAgIxTHZHFrM0KVbXdKtDv0Ams3NrPoBBMEh0kVdVCh0Em4SdPEIVDtJwAwiFDtZ0mCLUaNXmv8UuOF+PPeS4/GAJaEEz0f5dDoqiKI/zLJwgEyHCE0HCKGSLBsTjM1jntUHHWAY7iGfv7jLZuGI6VcUBZVleTHT9S8gHWCYVLndDsY5DgjIdIhQQxKExUzXKQCAxGOhEOVFEQjJyWkoRNE+39trs+nxR1j29nk0AgLTkASBunoqFoPnZCytNYuZrntJxQEARHlR9Nz3lksgOF4gPC7QBbpAkoDGGEPtOga1mxh5QGOMoSEJYEwweRU04/wRFlLlNjnAdTh/mCUDuCvOUeA+cLaAq9O3ySbfF852BTc5ifvE2QKuJvoNuW+cLaB5wnVIJ3C2l/gnpFM4AICtXtRWECzBEdzW14y1kk7hdroHzSCncFsvsfsedIH/CmhtGJKU6QAhr9ZWVWKBQ4S8WqdeJxWISrJMGROM6QDDnF0mkyTh+hVFGbWq1b/RAv5YzOejVrVK0T7fsSvZryjKSz6T+dZEt/xjWU7K5YJxjjtUc9MYY6x1VFXrqOp7r9s1j30CYTArpz88OJ4AAAAASUVORK5CYII='
		Case 52
			$Base64String &= 'iVBORw0KGgoAAAANSUhEUgAAADQAAAA0CAYAAADFeBvrAAAAAXNSR0IB2cksfwAAAARnQU1BAACxjwv8YQUAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAAAlwSFlzAAAOwwAADsMBx2+oZAAAAAd0SU1FB+oDAxcdEaKrvmEAAAKqSURBVGje7dq/b9pAFAfwh6kIg1FQJseDdQOKGIkcdWI4MjUDwWsnPFGWSo3yB4QsmdJmbhbK0ipTnKZD1ErNZYoUQTErQuqFARypRZawFIklXeqKumkbwPiX/N18guGjOz/7WS8CfwknYizgQoFbw5hdRiiWSCbBxYyGum70KdXqhHROa7VBW1Xv+13EusDyCGUr1SonYgweTpcoytX+1pbRp3R8PTp+kcrL8vrL4+NFlE6Dx7OI0ulUXpZvv2naoN1q/QFK5WU5W6lWowvxOPgk0YV4XMhJktGj1ERFzGO2+bbZdPs+meX+ev90ddXoU8oAADzePjjwKwYAIJZIJrO71SoAQGRpJZPZfNdsQgByVsrlmFS+WISARMCFAsOtebs8TxJOxJhhlxEKCojlEWL8XAzuKw4MBCwhKASFoBAUghzNoK3C520JukSZ6v+PvIY5K+VgNNRh0G6BgCX/7tA45mfD6d8jZ8VknlUgU9rxJ8hOjOsguzGuguaBcQ00L8zUoKv9F/BGjID6uuIpzNQg86GnHu5OhJo3ZmrQ+isFYonkRCgnMFODllYy8OTw/MEopzAzFYWHopzEzFzl/odyGgMAEJEbd3e2l+HSDgg5yXGMbaD7ULFE0nGMrQ9W6/FzA2P7m4IV5TTG1iM3HqNHwehT4ETs+GvVXDpWlkfA8ij8phCCQpAfQaOhrgcFMxrqOmOdxPBzjB6ljFYnJCggrUEI0yUnJ0EBdU5rNUZrEKI1/L9L3XNFGbRVNXCjMVFz4fb7zY2AJcmPoMu9cln7cnEBMDaN'
			$Base64String &= 'NWirqtG/vuZEjP0ykTUa6vrlXrnc+VCrmWtRS5Omfv14dMTyCHl9Zk6rE/Lp+caGuTO/2od/9DaZVL5Y5ESMWd4jI5o9SrUGIV2iKFrjd4iZH07DnAm7lTVAAAAAAElFTkSuQmCC'
		Case Else ; 16
			If $iSize <> 16 Then $iExt = BitOR($iExt, 1)
			$Base64String &= 'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAAXNSR0IB2cksfwAAAARnQU1BAACxjwv8YQUAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAAAlwSFlzAAAOwwAADsMBx2+oZAAAAAd0SU1FB+oDAxcZFLatj+oAAAEPSURBVDjLY2RgYGDQiioo0IrKz+eRVFBgIAK8u3XhwrWlEybc2bJwIaOKb0KCTcP8+QxkgFO9hYWMfsvPnxdSMzAgx4Avzx48YEw4+/8/AwWAiYFCQJIBdzYvYPj1+QN5BlyY2cBwbdlEBjZeAdINuDCzgeHRgY0MHrP24/fCl2cPGNb4KjJ8ef4Aq2Z02zEM4JFSYDBIq2fYkebI8OX5A4KaGRgYGFjQBVR8ExgYGBgYNkUaMvBIKuDVzMDAwIAzHby7eYGBR0oBr2asLoABIXXiEifTl+cPHpCbiN7dvHCBmYGBkVHaysODHAPOTq6oYH59+cSJL88fPuSRVFDgFJGQIDYTXZjZ0HBz3cyZABhkZ7hwets3AAAAAElFTkSuQmCC'
	EndSwitch
	Local $bString = _WinAPI_Base64Decode($Base64String)
	If @error Then Return SetError(1, $iExt, 0)
	$bString = Binary($bString)
	If Not $iExt Then
		Local Const $hFile = FileOpen($sSavePath & "\checked.png", $FO_BINARY + $FO_OVERWRITE)
		If @error Then Return SetError(2, $iExt, $bString)
		FileWrite($hFile, $bString)
		FileClose($hFile)
	EndIf
	Return SetError(0, $iExt, $bString)
EndFunc   ;==>__GUIDarkTheme_CheckedPNG

; #FUNCTION# ====================================================================================================================
; Author.........: WildByDesign
; Modified.......: UEZ, argumentum
; ===============================================================================================================================
Func __GUIDarkTheme_UncheckedPNG($iSize = 16, $sSavePath = Default)
	Local $Base64String, $iExt = (IsKeyword($sSavePath) ? 0 : 2) ; "BitAND(@extended, 2)" meant that the user wanted to save to disk
	Switch $iSize
		Case 13
			$Base64String &= 'iVBORw0KGgoAAAANSUhEUgAAAA0AAAANCAYAAABy6+R8AAAAAXNSR0IB2cksfwAAAARnQU1BAACxjwv8YQUAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAAAlwSFlzAAAOwwAADsMBx2+oZAAAAAd0SU1FB+oDAxcfHO4soF4AAAC3SURBVCjP7dIhDoMwGMXx1y0kX1pDFUdBsgRDgsb3BmThAuwEQyAmwWOruQQWjdxn2lROTbKR6f31+7knAKCqqrYsy1pKGWMn7z3P8zyM43gVxpguSZLaWosQwp6B1hp5nmNd11YMw/Ds+z5mZnyLiNA0DZ+klIcAAIQQoJSKT/ihP3oj7z0T0aGx1hrOOT5HUURpml62bfv4CCJCURRYluUhAMAYc8+yzCildr/nnGNrbTdN0+0FDuRGAoicao0AAAAASUVORK5CYII='
		Case 20
			$Base64String &= 'iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAAAXNSR0IB2cksfwAAAARnQU1BAACxjwv8YQUAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAAAlwSFlzAAAOwwAADsMBx2+oZAAAAAd0SU1FB+oDAxcgFyEgU+oAAAD6SURBVDjL7dUhboRAFMbxB2smYAjJJMi5AVuSCYaEEEwlvQHFoirgEpDUYcsNukdoBWNIaBUWLBkzBjJiRNW6ihIq+R/gl++ppwEAYIxJnudvhJCrYRgW7Kzv+1vbti+c81nDGJOqqr4YYxZjDKSUuzCEEHieB1EUibIsH7SiKN6XZUkYY3CkOI7BcZwPnVKaDMMAR+u6DgghVx0Adp/5W1JKME3T0uGfO8ETPME/gdu2CYTQYehuXFzXfbRtm0zTdAj0fR+EELfLOI6fWZalSinEOQel1O5lYRhCEASirusn7f4C0jR9pZQme5et6yrmef5umuaZcz7/AC65XdIkaSqyAAAAAElFTkSuQmCC'
		Case 26
			$Base64String &= 'iVBORw0KGgoAAAANSUhEUgAAABoAAAAaCAYAAACpSkzOAAAAAXNSR0IB2cksfwAAAARnQU1BAACxjwv8YQUAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAAAlwSFlzAAAOwwAADsMBx2+oZAAAAAd0SU1FB+oDAxcgMfMt1hcAAAEzSURBVEjH7dahbsJAAIfxf28VCyTNnbgqRPWh5uo4LB5FxfEEm8Iu6AqCR3RJXTXo4wmmeqYGTUXPlGAaZkaCL12ypN8L/Ozn4DfOeTCbzd6n06kaDAYULSrL8pTnuc6ybF2W5QkAHACQUiql1IYQQvM8h7W2jQPGGIQQaJrGJknycTwevxzOeRDH8be1lqZp2hp5xKIogud5drVavb0opTaj0Sjc7XZPQwDger2iKAqEYfjqui7IeDyWxpinIveqqoIxBlJKRTjnQRfIIzYcDinBH9VDPdRDPdRD/xK6XC6WUtoZwBjD+Xw+Ea11IoRAF9h9Uowxmuz3++3tdrNRFD0VY4xhsVigaRqbZdnaAYDJZKKWy2W3u/U4kPP5/FMIIX3fD9pAdV1brXVyOBy294H8AUHOkTVbUaKIAAAAAElFTkSuQmCC'
		Case 32
			$Base64String &= 'iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAAXNSR0IB2cksfwAAAARnQU1BAACxjwv8YQUAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAAAlwSFlzAAAOwwAADsMBx2+oZAAAAAd0SU1FB+oDAxciEmN8xecAAAF/SURBVFjD7ZexiqtAFIb/mFsYheA8gt0y8wDZLpIpAuNL2KTe7JOsWy23tMgjjEWQ4EJe4UxpLqRMoY1ikeJWguUWidvMVw2HA/8Hc5p/hhFCiEgp9SaEiDzPC/BAuq5riKjM8/yTiMphPhseSZKkSqm3vu9BRGia5pH5YIwhDEMwxqC1TrMseweAP+Pw8/mM0+mEvu/xLDabDeI43gNAlmXvcyFEtNvtvoqiwPF4xP1+xzO5XC5wXRdSylci+p4nSfLhed7L4XDAVFyvV6xWKyyXy8ARQkRVVWFK+r6HMQZCiMjxPC949MH9hLqu4ft+4OCXsQJWwApYAStgBayAFbACTtd1TRAEkwczxtC2beMQUck5h+u6kwqEYQgiKh2t9edisYCUcrJwKSUYY8jzPJ3fbrd/vu8HUsrXobk8C9d1sd1usV6vobVOi6L4Oy6nH0qpfV3XqKrqKeV0+OpxOZ2Nlzjn6ziO95zzyPf9h15m27aNMabUWqfGmO9h/h/YFp4sUeI9ggAAAABJRU5ErkJggg=='
		Case 40
			$Base64String &= 'iVBORw0KGgoAAAANSUhEUgAAACgAAAAoCAYAAACM/rhtAAAAAXNSR0IB2cksfwAAAARnQU1BAACxjwv8YQUAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAAAlwSFlzAAAOwwAADsMBx2+oZAAAAAd0SU1FB+oDAxciKdJ3LMMAAAIZSURBVFjD7dg9q9pQAMbx5/oC1SDEIXAzeZIxLiG+cDFLuxWXOqiLiwX3+g2u2br1gqAfoZQsdnDoVC5IoAbfBuMgmDgJOphB5YBLJ0UunVXo+U+Bs/zI4SzPA96UTCbfp9PpT9lstiAIAsEV8jxv7Hne2DRNY7PZeJdnD6ePaDTKl8vlRj6f/4Ib1u12X0zTNA6Hg38GRqNRvtFo/CaEqJRS9Ho9uK4L13WvghJFEbquQ9M0AIDrumPDMD4cDgc/CACVSuVrJpMpbLdbtNttzGYz+L5/tb+22+3gOA6GwyEURYEoio/hcPjdZDL5FRQEgdTr9e8A0Gw2rwp7G6UUs9kMqVQKiqI8TafT12C1Wv1GCFEHgwFGoxFuHaUUoVAIsixjv9/7AUmSVACwLAv30mKxAABks9lCIJFIqACwWq3uBnh6nIIgkADuPAZkQAZkQAZkQAZkQAZkQAZkQAZkwP8aeBoMJUm6G5QoiqeFYRywbbsDALIs3w1Q13UAwHK5HAf6/f5PAMjlcuB5/ua4eDx+HjJN0zSCm83G4ziOVxTlSVEUOI4DSunNcLVaDZFIBN1u98WyrB9BAJjP539UVf0oiuKjruvgeR6+72O3210FJssyNE1DsVhELBaD67rjVqv1+Xg80vOIznEcXyqVnvP5fP2WV/zPEf0yQRBIqVR6JoSohBD1Gqj1eu3Ztt2xbbvjOM7r5dlfsTLTT1G4ptgAAAAASUVORK5CYII='
		Case 52
			$Base64String &= 'iVBORw0KGgoAAAANSUhEUgAAADQAAAA0CAYAAADFeBvrAAAAAXNSR0IB2cksfwAAAARnQU1BAACxjwv8YQUAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAAAlwSFlzAAAOwwAADsMBx2+oZAAAAAd0SU1FB+oDAxcjAxDX1FQAAAKhSURBVGje7dqxbtpQGAXgg5tICBYzGMmejEd7SRPIksFXYmAMDwCK2apkaRZeIkOmsDAkFi+QPgDIlpLFCDWLPWKzxKo9xIuRxw7RRYQmkSpVAlf3bFw83E/31z+dAj6IpmmkXq+fappGqtWqXCqVeGwxy+UyiaIocF3Xsm3bDILg6b3vCpsHgiDIFxcXt6qqEuxwHMe5N03zMo7j4EMQIcQwDON6/TXm8znCMESWZVsFFItFiKIIRVFWZ2maJnd3d99t2zb/ABFCjPPz81v6++HhAZPJZOuQzVQqFTSbTRweHq7Obm5uDIoq0DG7urr6WSqV+CzLMBqN4Pv+Lk8carUaut0uisUi0jRN+v3+1ziOAw4A1scsDxgA8H0fo9EIAFAul3k6XZwsyweNRqMNALPZLBeYddTj4+NqK6uqSjhCyBn9YDweI29Zv3Oj0TjlNE0jdJslSZI7UJZlmM/nAABVVQknCIIMAGEYIq+hd69WqzJHl8Guree/fSW6HDj8Z2EgBmIgBmIgBmIgBmIgBmIgBmIgBmIgBmIgBmIgBmIgBmIgBvrHoOVymQCvPYC8ht49TdOEo00MURRzC5IkCQAQRVHAua5rAYCiKLl8pUqlglqtBgDwPM/iHMf5Qf9sNpu5A63f2bIsk/M8z6KvdHJystLmIYqirCoyjuPcLxaLJw4ABoNBjy6HTqeTC5SiKOh0OqtlYJrmJQB8AV67aC8vL7+Oj4/b+/v7ODo6As/zO9HCem+jtVottNtt7O3tAQCGw+E3z/NsYKNepuu60ev13tTLfN/H'
			$Base64String &= '8/PzTtTLJEl6Mz2f1stoBEGQDcO4pv2fXY3rutZgMOh9WgBcjyzLB7qun2maRgRBkMvl8lYrmmmaJnEcB67rWtPp9J6O2GZ+A6oXHMXfWhlTAAAAAElFTkSuQmCC'
		Case Else ; 16
			If $iSize <> 16 Then $iExt = BitOR($iExt, 1)
			$Base64String &= 'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAAXNSR0IB2cksfwAAAARnQU1BAACxjwv8YQUAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAAAlwSFlzAAAOwwAADsMBx2+oZAAAAAd0SU1FB+oDAxcfO0smFTUAAADBSURBVDjL7cyhDYNAGIbhD1qFqzhxijsmYAOQDZcQgkIg2IDK7oBou0HrCYIEsGxQNvjPkYBlgK5wpJbXP68FAEqpWxRFJWNMwCCt9dT3/XMcx885DMMijuNHXdcgIhMPzrmf5/nbcZyLVVXVt21bf55n7ElKiSRJtO267m4MAEQExpiw8WfH4BgAgL2uq5ZS7oaccxDRdAJgpWl6JSJs22aEPc9DlmVomuZuAUAQBIVSqhRC+CaDZVl013XPYRheP/vGQ/mk4/+CAAAAAElFTkSuQmCC'
	EndSwitch
	Local $bString = _WinAPI_Base64Decode($Base64String)
	If @error Then Return SetError(1, $iExt, 0)
	$bString = Binary($bString)
	If Not $iExt Then
		Local Const $hFile = FileOpen($sSavePath & "\unchecked.png", $FO_BINARY + $FO_OVERWRITE)
		If @error Then Return SetError(2, $iExt, $bString)
		FileWrite($hFile, $bString)
		FileClose($hFile)
	EndIf
	Return SetError(0, $iExt, $bString)
EndFunc   ;==>__GUIDarkTheme_UncheckedPNG

; #FUNCTION# ====================================================================================================================
; Author.........: Andreik
; Modified.......: WildByDesign
; ===============================================================================================================================
Func __GUIDarkTheme_SizeboxProc($hWnd, $iMsg, $wParam, $lParam, $iID, $pData) ; Andreik
	#forceref $iID, $pData

	If $iMsg = $WM_PAINT Then
		Local $tPAINTSTRUCT
		Local $hDC = _WinAPI_BeginPaint($hWnd, $tPAINTSTRUCT)
		Local $hGraphics = _GDIPlus_GraphicsCreateFromHDC($hDC)
		_GDIPlus_GraphicsDrawImageRect($hGraphics, $__DM_g_hDots, 0, 0, $__DM_g_hGripSize + 2, $__DM_g_hGripSize + 2)
		_GDIPlus_GraphicsDispose($hGraphics)
		_WinAPI_EndPaint($hWnd, $tPAINTSTRUCT)
		Return 0
	EndIf

	Return __WinAPI_DefSubclassProc($hWnd, $iMsg, $wParam, $lParam)
EndFunc   ;==>__GUIDarkTheme_SizeboxProc

; #FUNCTION# ====================================================================================================================
; Author.........: Andreik
; Modified.......: WildByDesign
; ===============================================================================================================================
Func __GUIDarkTheme_CreateDots($hGui, $iWidth, $iHeight, $iBackgroundColor)
	#forceref $iBackgroundColor
	If $__DM_g_hDots Then _GDIPlus_BitmapDispose($__DM_g_hDots)
	Local $hTheme = _WinAPI_OpenThemeData($hGui, 'Status')
	Local $hBitmap = _GDIPlus_BitmapCreateFromScan0($iWidth, $iHeight)
	Local $hGraphics = _GDIPlus_ImageGetGraphicsContext($hBitmap)
	_GDIPlus_GraphicsClear($hGraphics, $iBackgroundColor)
	; draw SP_GRIPPER directly on graphics object
	Local $hDC = _GDIPlus_GraphicsGetDC($hGraphics)
	Local $tRect = _WinAPI_CreateRectEx($__DM_g_hGripSize + 2 - $__DM_g_hGripSize + $__DM_g_iGripPos, $__DM_g_hGripSize + 2 - $__DM_g_hGripSize + $__DM_g_iGripPos, $__DM_g_hGripSize, $__DM_g_hGripSize)
	_WinAPI_DrawThemeBackground($hTheme, 3, 0, $hDC, $tRect)
	_GDIPlus_GraphicsReleaseDC($hGraphics, $hDC)
	_GDIPlus_GraphicsDispose($hGraphics)
	_WinAPI_CloseThemeData($hTheme)
	Return $hBitmap
EndFunc   ;==>__GUIDarkTheme_CreateDots

; #FUNCTION# ====================================================================================================================
; Author.........: pixelsearch
; Modified.......: WildByDesign
; ===============================================================================================================================
Func __GUIDarkTheme_WM_SIZE($hWnd, $iMsg, $wParam, $lParam)
	#forceref $iMsg, $wParam, $lParam

	If $__DM_g_hSizebox And _WinAPI_GetParent($__DM_g_hSizebox) = $hWnd Then
		If Not $__DM_g_bUseDarkMode Then _WinAPI_ShowWindow($__DM_g_hSizebox, @SW_HIDE)
		Local Static $bIsSizeBoxShown = True
		Local $aSize = WinGetClientSize($hWnd)
		Local $aGetParts = _GUICtrlStatusBar_GetParts($__DM_g_hStatus)
		Local $aParts[$aGetParts[0]]
		For $i = 0 To $aGetParts[0] - 1
			$aParts[$i] = Int($aSize[0] * $__DM_g_aRatioW[$i])
		Next
		If BitAND(WinGetState($hWnd), $WIN_STATE_MAXIMIZED) Then
			_GUICtrlStatusBar_SetParts($__DM_g_hStatus, $aParts)
			_WinAPI_ShowWindow($__DM_g_hSizebox, @SW_HIDE)
			$bIsSizeBoxShown = False
		Else
			If $__DM_g_aRatioW[UBound($aParts) - 1] <> 1 Then $aParts[UBound($aParts) - 1] = $aSize[0] - $__DM_g_iHeight
			_GUICtrlStatusBar_SetParts($__DM_g_hStatus, $aParts)
			WinMove($__DM_g_hSizebox, "", $aSize[0] - $__DM_g_hGripSize - 2 - $__DM_g_iGripPos, $aSize[1] - $__DM_g_hGripSize - 2 - $__DM_g_iGripPos, $__DM_g_hGripSize + 2, $__DM_g_hGripSize + 2)
			If Not $bIsSizeBoxShown Then
				_WinAPI_ShowWindow($__DM_g_hSizebox, @SW_SHOW)
				$bIsSizeBoxShown = True
			EndIf
			_WinAPI_RedrawWindow($__DM_g_hSizebox)
		EndIf
	EndIf

	Return $GUI_RUNDEFMSG
EndFunc   ;==>__GUIDarkTheme_WM_SIZE

; #FUNCTION# ====================================================================================================================
; Author.........: WildByDesign
; ===============================================================================================================================
Func __GUIDarkTheme_StatusRatio($hGui)
	; calculate ratio need for the resizing of statusbar parts
	Local $iGuiWidth = WinGetClientSize($hGui)[0]
	Local $aParts = _GUICtrlStatusBar_GetParts($__DM_g_hStatus)
	_ArrayDelete($aParts, 0)
	Dim $__DM_g_aRatioW[UBound($aParts)]
	For $i = 0 To UBound($aParts) - 1
		$__DM_g_aRatioW[$i] = $aParts[$i] / $iGuiWidth
	Next
EndFunc   ;==>__GUIDarkTheme_StatusRatio

; #FUNCTION# ====================================================================================================================
; Author.........: WildByDesign
; ===============================================================================================================================
Func __GUIDarkTheme_CreateSizebox($hGui)
	; clean up previous sizebox resources (for theme change) if they exist
	If $__DM_g_hDots Then _GDIPlus_BitmapDispose($__DM_g_hDots)
	If $__DM_g_hSizebox Then _WinAPI_DestroyWindow($__DM_g_hSizebox)
	; create grip
	$__DM_g_iHeight = WinGetPos($__DM_g_hStatus)[3] - 3
	$__DM_g_hDots = __GUIDarkTheme_CreateDots($hGui, $__DM_g_hGripSize + 2, $__DM_g_hGripSize + 2, 0xFF000000 + $__DM_g_iStatusBkColor)

	Local Const $SBS_SIZEBOX = 0x08
	; Create a sizebox window (Scrollbar class)
	$__DM_g_hSizebox = _WinAPI_CreateWindowEx(0, "Scrollbar", "", $WS_CHILD + $WS_VISIBLE + $SBS_SIZEBOX, _
			0, 0, 0, 0, $hGui) ; $SBS_SIZEBOX or $SBS_SIZEGRIP

	; Subclass the sizebox (by changing the window procedure associated with the Scrollbar class)
	If Not $__DM_g_hSizeboxProc Then
		$__DM_g_hSizeboxProc = DllCallbackRegister(__GUIDarkTheme_SizeboxProc, "lresult", "hwnd;uint;wparam;lparam;uint_ptr;dword_ptr")
		$__DM_g_pSizeboxProc = DllCallbackGetPtr($__DM_g_hSizeboxProc)
	EndIf
	__GUIDarkTheme_AddToSubclass($__DM_g_hSizebox, $__DM_g_hSizeboxProc, $__DM_g_pSizeboxProc, $__DM_g_iControlCount)

	$__DM_g_hCursor = _WinAPI_LoadCursor(0, $OCR_SIZENWSE)
	_WinAPI_SetClassLongEx($__DM_g_hSizebox, $GCL_HCURSOR, $__DM_g_hCursor)

	; Add WS_EX_TRANSPARENT to sizebox
	_WinAPI_SetWindowLong($__DM_g_hSizebox, $GWL_EXSTYLE, BitOR(_WinAPI_GetWindowLong($__DM_g_hSizebox, $GWL_EXSTYLE), $WS_EX_TRANSPARENT))

	; Fix Z-order of Sizebox (needed for cursor)
	_WinAPI_SetWindowPos($__DM_g_hSizebox, $HWND_TOP, 0, 0, 0, 0, BitOR($SWP_NOMOVE, $SWP_NOREDRAW, $SWP_NOSIZE))

	; Add WS_CLIPSIBLINGS to statusbar (needed for cursor)
	_WinAPI_SetWindowLong($__DM_g_hStatus, $GWL_STYLE, BitOR(_WinAPI_GetWindowLong($__DM_g_hStatus, $GWL_STYLE), $WS_CLIPSIBLINGS))

	; Trigger move and redraw of sizebox (needed mostly after theme changes)
	Local $aSize = WinGetClientSize($hGui)
	WinMove($__DM_g_hSizebox, "", $aSize[0] - $__DM_g_hGripSize - 2 - $__DM_g_iGripPos, $aSize[1] - $__DM_g_hGripSize - 2 - $__DM_g_iGripPos, $__DM_g_hGripSize + 2, $__DM_g_hGripSize + 2)
	_WinAPI_RedrawWindow($__DM_g_hSizebox)
EndFunc   ;==>__GUIDarkTheme_CreateSizebox

; #FUNCTION# ====================================================================================================================
; Author.........: UEZ
; Modified.......: WildByDesign
; ===============================================================================================================================
Func __GUIDarkTheme_GetImages($hGui, $iState, $iPart = 3, $iWidth = 16, $iHeight = 16)
	Local $hTheme = _WinAPI_OpenThemeData($hGui, $__DM_g_bUseDarkMode ? "DarkMode_Explorer::Button" : "Button")
	If @error Then Return SetError(1, 0, 0)
	Local $hDC = _WinAPI_GetDC($hGui)
	Local $hHBitmap = _WinAPI_CreateCompatibleBitmap($hDC, $iWidth, $iHeight)
	Local $hMemDC = _WinAPI_CreateCompatibleDC($hDC)
	Local $hObjOld = _WinAPI_SelectObject($hMemDC, $hHBitmap)
	Local $tRect = _WinAPI_CreateRectEx(0, 0, $iWidth, $iHeight)
	_WinAPI_DrawThemeBackground($hTheme, $iPart, $iState, $hMemDC, $tRect)
	If @error Then
		_WinAPI_CloseThemeData($hTheme)
		Return SetError(2, 0, 0)
	EndIf
	_WinAPI_SelectObject($hMemDC, $hObjOld)
	_WinAPI_ReleaseDC($hGui, $hDC)
	_WinAPI_DeleteDC($hMemDC)
	_WinAPI_CloseThemeData($hTheme)
	Return $hHBitmap
EndFunc   ;==>__GUIDarkTheme_GetImages

; #FUNCTION# ====================================================================================================================
; Author.........: UEZ
; Modified.......: WildByDesign
; ===============================================================================================================================
Func __GUIDarkMenu_WM_MEASUREITEM($hWnd, $iMsg, $wParam, $lParam)
	#forceref $iMsg, $wParam
	Local $tagMEASUREITEM = "uint CtlType;uint CtlID;uint itemID;uint itemWidth;uint itemHeight;ulong_ptr itemData"
	Local $t = DllStructCreate($tagMEASUREITEM, $lParam)
	If Not IsDllStruct($t) Then Return $GUI_RUNDEFMSG

	If $t.CtlType <> $ODT_MENU Then Return $GUI_RUNDEFMSG

	Local $itemID = $t.itemID

	; itemID is the control ID, not the position!
	; We must derive the position from the itemID
	Local $iPos = -1
	For $i = 0 To UBound($__DM_g_aMenuText) - 1
		If $itemID = $__DM_g_aMenuText[$i][0] Then
			$iPos = $i
			ExitLoop
		EndIf
	Next

	; Fallback: try the itemID directly
	If $iPos < 0 Then $iPos = $itemID
	If $iPos < 0 Or $iPos >= UBound($__DM_g_aMenuText) Then $iPos = 0

	Local $sText = $__DM_g_aMenuText[$iPos][1]

	; Calculate text dimensions
	Local $hDC = _WinAPI_GetDC($hWnd)
	_WinAPI_SelectObject($hDC, $__DM_g_hMenuFont)
	Local $tSIZE = _WinAPI_GetTextExtentPoint32($hDC, $sText)
	Local $iTextWidth = $tSIZE.X
	Local $iTextHeight = $tSIZE.Y

	_WinAPI_ReleaseDC($hWnd, $hDC)

	; Set dimensions with padding (with high DPI)
	$t.itemWidth = $iTextWidth - (8 * $__DM_g_iDpiScale)
	$t.itemHeight = $iTextHeight + 1

	Return $GUI_RUNDEFMSG
EndFunc   ;==>__GUIDarkMenu_WM_MEASUREITEM

; #FUNCTION# ====================================================================================================================
; Author.........: UEZ
; Modified.......: WildByDesign
; ===============================================================================================================================
Func __GUIDarkMenu_WM_DRAWITEM($hWnd, $iMsg, $wParam, $lParam)
	#forceref $hWnd, $iMsg, $wParam
	Local $tagDRAWITEM = "uint CtlType;uint CtlID;uint itemID;uint itemAction;uint itemState;ptr hwndItem;handle hDC;" & _
			"long left;long top;long right;long bottom;ulong_ptr itemData"
	Local $t = DllStructCreate($tagDRAWITEM, $lParam)
	If Not IsDllStruct($t) Then Return $GUI_RUNDEFMSG

	If $t.CtlType <> $ODT_MENU Then Return $GUI_RUNDEFMSG

	Local $hDC = $t.hDC
	Local $iLeft = $t.left
	Local $iTop = $t.top
	Local $iRight = $t.right
	Local $iBottom = $t.bottom
	Local $state = $t.itemState
	Local $itemID = $t.itemID

	; convert itemID to position
	Local $iPos = -1
	For $i = 0 To UBound($__DM_g_aMenuText) - 1
		If $itemID = $__DM_g_aMenuText[$i][0] Then
			$iPos = $i
			ExitLoop
		EndIf
	Next

	If $iPos < 0 Then $iPos = $itemID
	If $iPos < 0 Or $iPos >= UBound($__DM_g_aMenuText) Then $iPos = 0

	Local $sText = $__DM_g_aMenuText[$iPos][1]
	$sText = StringReplace($sText, "&", "")

	; Colors
	Local $clrText = _WinAPI_SwitchColor($__DM_g_iMenuTextColor)

	; Draw item background (selected = lighter)
	Local $bSelected = BitAND($state, $ODS_SELECTED)
	Local $bHot = BitAND($state, $ODS_HOTLIGHT)
	Local $hBrush

	If $bSelected Then
		$hBrush = $__DM_g_hBrushMenuSel
	ElseIf $bHot Then
		$hBrush = $__DM_g_hBrushMenuHot
	Else
		$hBrush = $__DM_g_hBrushMenuBk
	EndIf

	Local $tItemRect = DllStructCreate($tagRECT)
	With $tItemRect
		.left = $iLeft
		.top = $iTop
		.right = $iRight
		.bottom = $iBottom
	EndWith

	_WinAPI_FillRect($hDC, $tItemRect, $hBrush)

	; Setup font
	_WinAPI_SelectObject($hDC, $__DM_g_hMenuFont)

	_WinAPI_SetBkMode($hDC, $TRANSPARENT)
	If _WinAPI_GetForegroundWindow() <> $hWnd Then
		$clrText = $__DM_g_bUseDarkMode ? _WinAPI_ColorAdjustLuma($clrText, -30) : 0x6d6d6d
	EndIf
	_WinAPI_SetTextColor($hDC, $clrText)

	; Draw text
	Local $tTextRect = DllStructCreate($tagRECT)
	With $tTextRect
		.left = $iLeft
		.top = $iTop
		.right = $iRight
		.bottom = $iBottom
	EndWith

	DllCall('user32.dll', "int", "DrawTextW", "handle", $hDC, "wstr", $sText, "int", -1, "ptr", _
			DllStructGetPtr($tTextRect), "uint", BitOR($DT_SINGLELINE, $DT_VCENTER, $DT_CENTER, $DT_NOCLIP))

	Return $GUI_RUNDEFMSG
EndFunc   ;==>__GUIDarkMenu_WM_DRAWITEM

; #FUNCTION# ====================================================================================================================
; Author.........: WildByDesign
; ===============================================================================================================================
Func _GUIDarkMenu_Register($hGui)
	; get top menu handle
	Local $hMenu = _GUICtrlMenu_GetMenu($hGui)
	; return from function if no top menu exists
	If Not $hMenu Then Return False

	GUIRegisterMsg($WM_ACTIVATE, "__GUIDarkMenu_WM_ACTIVATE")
	GUIRegisterMsg($WM_WINDOWPOSCHANGED, "__GUIDarkMenu_WM_WINDOWPOSCHANGED")
	GUIRegisterMsg($WM_MEASUREITEM, "__GUIDarkMenu_WM_MEASUREITEM")
	GUIRegisterMsg($WM_DRAWITEM, "__GUIDarkMenu_WM_DRAWITEM")

	; create font
	If Not $__DM_g_hMenuFont Then $__DM_g_hMenuFont = __GUIDarkMenu_CreateFont("Segoe UI", 9)

	; get window DPI for measurement adjustments
	$__DM_g_iDpiScale = Round(_WinAPI_GetDPIForWindow($hGui) / 96, 2)
	If @error Then $__DM_g_iDpiScale = 1
	$__DM_g_iDpi = Round(_WinAPI_GetDPIForWindow($hGui) / 96, 2) * 100
	If @error Then $__DM_g_iDpi = 100

	$__DM_g_aMenuText = __GUIDarkMenu_GetTopMenuItems($hGui)

	For $i = 0 To UBound($__DM_g_aMenuText) - 1
		_GUICtrlMenu_SetItemType($hMenu, $i, $MFT_OWNERDRAW, True)
	Next
	__GUIDarkMenu_MenuBarBKColor($hMenu, $__DM_g_iMenuBkColor)
EndFunc   ;==>_GUIDarkMenu_Register

; #FUNCTION# ====================================================================================================================
; Author.........: Nine
; Modified.......: WildByDesign, argumentum
; ===============================================================================================================================
Func __GUIDarkMenu_GetTopMenuItems($hWnd)
	Local $iItemID = 10000
	Local $hMenu = _GUICtrlMenu_GetMenu($hWnd)
	Local $nItem = _GUICtrlMenu_GetItemCount($hMenu)
	Local $aList[$nItem][2], $tInfo
	Local $tText, $iLen
	For $i = 0 To $nItem - 1
		$tInfo = _GUICtrlMenu_GetItemInfo($hMenu, $i)
		If Not $tInfo.ID Then
			_GUICtrlMenu_SetItemID($hMenu, $i, $iItemID)
			$aList[$i][0] = _GUICtrlMenu_GetItemID($hMenu, $i)
			$iItemID += 1
		Else
			$aList[$i][0] = $tInfo.ID
		EndIf
		;$aList[$i][1] = _GUICtrlMenu_GetItemText($hMenu, $i)
		; retrieve text via GetMenuStringW (works better than _GUICtrlMenu_GetItemText)
		$tText = DllStructCreate("wchar s[256]")
		$iLen = DllCall('user32.dll', "int", "GetMenuStringW", _
				"handle", $hMenu, _
				"uint", $i, _
				"struct*", $tText, _
				"int", 255, _
				"uint", $MF_BYPOSITION)

		If IsArray($iLen) And $iLen[0] > 0 Then
			$aList[$i][1] = $tText.s
		Else
			$aList[$i][1] = ""
		EndIf
	Next
	Return $aList
EndFunc   ;==>__GUIDarkMenu_GetTopMenuItems

; #FUNCTION# ====================================================================================================================
; Author.........: WildByDesign
; ===============================================================================================================================
Func _GUIDarkMenu_SetColors($hWnd, $MenuBG, $MenuHot, $MenuSel, $MenuText)
	Local $hMenu = _GUICtrlMenu_GetMenu($hWnd)
	$__DM_g_iMenuBkColor = $MenuBG
	$__DM_g_iMenuHotColor = $MenuHot
	$__DM_g_iMenuSelColor = $MenuSel
	$__DM_g_iMenuTextColor = $MenuText
	; redraw menubar background area
	__GUIDarkMenu_MenuBarBKColor($hMenu, $__DM_g_iMenuBkColor)
	; redraw menubar and force refresh
	_GUICtrlMenu_DrawMenuBar($hWnd)
	_WinAPI_RedrawWindow($hWnd, 0, 0, BitOR($RDW_INVALIDATE, $RDW_UPDATENOW))
EndFunc   ;==>_GUIDarkMenu_SetColors

; #FUNCTION# ====================================================================================================================
; Author.........: UEZ
; Modified.......: WildByDesign
; ===============================================================================================================================
Func __GUIDarkMenu_WM_WINDOWPOSCHANGED($hWnd, $iMsg, $wParam, $lParam)
	#forceref $iMsg, $wParam, $lParam
	__GUIDarkMenu_PaintWhiteLine($hWnd)

	Return $GUI_RUNDEFMSG
EndFunc   ;==>__GUIDarkMenu_WM_WINDOWPOSCHANGED

; #FUNCTION# ====================================================================================================================
; Author.........: ahmet
; Modified.......: WildByDesign
; ===============================================================================================================================
Func __GUIDarkMenu_PaintWhiteLine($hWnd)
	; Make sure GUI has menu (needed in case of child GUIs)
	If Not _GUICtrlMenu_GetMenu($hWnd) Then Return

	Local $rcClient = _WinAPI_GetClientRect($hWnd)

	DllCall('user32.dll', "int", "MapWindowPoints", _
			"hwnd", $hWnd, _ ; hWndFrom
			"hwnd", 0, _ ; hWndTo
			"ptr", DllStructGetPtr($rcClient), _
			"uint", 2)   ;number of points - 2 for RECT structure

	If @error Then Return

	Local $rcWindow = _WinAPI_GetWindowRect($hWnd)

	_WinAPI_OffsetRect($rcClient, -$rcWindow.left, -$rcWindow.top)

	Local $rcAnnoyingLine = DllStructCreate($tagRECT)
	$rcAnnoyingLine.left = $rcClient.left
	$rcAnnoyingLine.top = $rcClient.top
	$rcAnnoyingLine.right = $rcClient.right
	$rcAnnoyingLine.bottom = $rcClient.bottom

	$rcAnnoyingLine.bottom = $rcAnnoyingLine.top
	$rcAnnoyingLine.top = $rcAnnoyingLine.top - 1

	Local $hRgn = _WinAPI_CreateRectRgn(-20000, -20000, 20000, 20000)

	Local $hDC = _WinAPI_GetDCEx($hWnd, $hRgn, BitOR($DCX_WINDOW, $DCX_INTERSECTRGN))
	Local $hBrush = $__DM_g_hBrushGui
	_WinAPI_FillRect($hDC, $rcAnnoyingLine, $hBrush)
	_WinAPI_ReleaseDC($hWnd, $hDC)

EndFunc   ;==>__GUIDarkMenu_PaintWhiteLine

; #FUNCTION# ====================================================================================================================
; Author.........: ioa747
; Modified.......: WildByDesign
; ===============================================================================================================================
Func __GUIDarkMenu_WM_ACTIVATE($hWnd, $iMsg, $wParam, $lParam)
	#forceref $iMsg, $wParam, $lParam
	__GUIDarkMenu_PaintWhiteLine($hWnd)

	Return $GUI_RUNDEFMSG
EndFunc   ;==>__GUIDarkMenu_WM_ACTIVATE

; #FUNCTION# ====================================================================================================================
; Author.........: ProgAndy
; Modified.......: WildByDesign
; ===============================================================================================================================
Func __GUIDarkMenu_MenuBarBKColor($hMenu, $nColor)
	#forceref $nColor
	Local $hBrush = $__DM_g_hBrushMenuBk
	Local $tInfo = DllStructCreate("int Size;int Mask;int Style;int YMax;handle hBack;int ContextHelpID;ptr MenuData")
	DllStructSetData($tInfo, "Mask", 2)
	DllStructSetData($tInfo, "hBack", $hBrush)
	DllStructSetData($tInfo, "Size", DllStructGetSize($tInfo))
	DllCall('user32.dll', "int", "SetMenuInfo", "hwnd", $hMenu, "ptr", DllStructGetPtr($tInfo))
EndFunc   ;==>__GUIDarkMenu_MenuBarBKColor

; #FUNCTION# ====================================================================================================================
; Author.........: Nine
; Modified.......: MattyD
; ===============================================================================================================================
Func __GUIDarkMenu_GUICtrlGetFont($hWnd)
	If Not IsHWnd($hWnd) Then $hWnd = GUICtrlGetHandle($hWnd)
	Local Const $LOGPIXELSY = 90
	Local $aFont[6], $hDC = _WinAPI_GetDC($hWnd)
	Local $hFont = _SendMessage($hWnd, $WM_GETFONT), $tFont = DllStructCreate($tagLOGFONT)

	_WinAPI_GetObject($hFont, DllStructGetSize($tFont), $tFont)

	$aFont[0] = Round(-(($tFont.Height * 72) / _WinAPI_GetDeviceCaps($hDC, $LOGPIXELSY)) / 0.5) * 0.5
	$aFont[1] = $tFont.Weight
	$aFont[2] = BitOR(2 * ($tFont.Italic <> 0), 4 * ($tFont.Underline <> 0), 8 * ($tFont.Strikeout) <> 0)
	$aFont[3] = $tFont.FaceName
	$aFont[4] = $tFont.Quality
	$aFont[5] = $hFont

	_WinAPI_ReleaseDC($hWnd, $hDC)
	Return $aFont
EndFunc   ;==>__GUIDarkMenu_GUICtrlGetFont

; #FUNCTION# ====================================================================================================================
; Author.........: Nine
; ===============================================================================================================================
Func __GUIDarkMenu_GUIGetFontSize()
	Local $idTest = GUICtrlCreateLabel("Test", -100, -100, -1, -1)
	Local $aFont = __GUIDarkMenu_GUICtrlGetFont($idTest)
	GUICtrlDelete($idTest)
	Return $aFont
EndFunc   ;==>__GUIDarkMenu_GUIGetFontSize

; #FUNCTION# ====================================================================================================================
; Author.........: ???
; ===============================================================================================================================
Func __GUIDarkMenu_CreateFont($sFontName, $nHeight = 9, $nWidth = 400)
	Local $stFontName = DllStructCreate("char[260]")
	DllStructSetData($stFontName, 1, $sFontName)
	Local $hDC = _WinAPI_GetDC(0)        ; Get the Desktops DC
	Local $nPixel = _WinAPI_GetDeviceCaps($hDC, 90)
	$nHeight = 0 - _WinAPI_MulDiv($nHeight, $nPixel, 72)
	_WinAPI_ReleaseDC(0, $hDC)
	Local $hFont = _WinAPI_CreateFont($nHeight, 0, 0, 0, $nWidth, False, False, False, _
			$DEFAULT_CHARSET, $OUT_DEFAULT_PRECIS, $CLIP_DEFAULT_PRECIS, $PROOF_QUALITY, $DEFAULT_PITCH, $sFontName)
	Return $hFont
EndFunc   ;==>__GUIDarkMenu_CreateFont

; #FUNCTION# ====================================================================================================================
; Author.........: UEZ
; Modified.......: WildByDesign, MattyD
; ===============================================================================================================================
Func __DM_MsgBoxProc($hWnd, $iMsg, $wParam, $lParam, $iSubClsID, $pData)
	#forceref $pData
	Local Const $DWMWA_USE_IMMERSIVE_DARK_MODE = 20
	Local Static $hBkColorBrush, $hFooterBrush

	Switch $iMsg

		Case $WM_NCCREATE
			If $__DM_g_bUseDarkMode Then _WinAPI_DwmSetWindowAttribute($hWnd, $DWMWA_USE_IMMERSIVE_DARK_MODE, True)

		Case $WM_INITDIALOG
			$hBkColorBrush = $__DM_g_hBrushMsgBoxTop
			$hFooterBrush = $__DM_g_hBrushMsgBoxBottom

		Case $WM_CTLCOLORSTATIC, $WM_CTLCOLORDLG
			If $__DM_g_bUseDarkMode Then
				_WinAPI_SetBkMode($wParam, $TRANSPARENT)
				_WinAPI_SetTextColor($wParam, $__DM_g_iMsgBoxTextColor)
				Return $hBkColorBrush
			EndIf

		Case $WM_CTLCOLORBTN
			If $__DM_g_bUseDarkMode Then
				_WinAPI_SetTextColor($wParam, $__DM_g_iMsgBoxBottomColor)
				Return $hFooterBrush
			EndIf

		Case $WM_PAINT
			If $__DM_g_bUseDarkMode Then
				Local $tPS = DllStructCreate($tagPAINTSTRUCT)
				Local $hDC = _WinAPI_BeginPaint($hWnd, $tPS)
				Local $tPaintRect = DllStructCreate($tagRECT, DllStructGetPtr($tPS, "rPaint"))
				$tPaintRect.Top = ($tPaintRect.Bottom - (48 * $__DM_g_iMsgBoxDpi)) ; this depends on DPI scale
				_WinAPI_FillRect($hDC, $tPaintRect, $hFooterBrush)
				_WinAPI_EndPaint($hWnd, $tPS)
				Return True
			EndIf

		Case $WM_COMMAND
			Local $iNotifCode = _WinAPI_HiWord($wParam)
			Local $iItemID = _WinAPI_LoWord($wParam)
			If (Not $lParam) Or ($iNotifCode = $BN_CLICKED) Then
				Return _WinAPI_EndDialog($hWnd, $iItemID)
			EndIf

		Case $WM_DESTROY
			_WinAPI_RemoveWindowSubclass($hWnd, $__DM_g_pMsgBoxSubProc, $iSubClsID)
			_WinAPI_SetActiveWindow(_WinAPI_GetParent($hWnd))
	EndSwitch
	Return __WinAPI_DefSubclassProc($hWnd, $iMsg, $wParam, $lParam)
EndFunc   ;==>__DM_MsgBoxProc

; #FUNCTION# ====================================================================================================================
; Author.........: UEZ
; Modified.......: WildByDesign, MattyD
; ===============================================================================================================================
Func __DM_CBTHookProc($nCode, $wParam, $lParam)
	Local Const $hWnd = HWnd($wParam)
	If $nCode < 0 Then Return _WinAPI_CallNextHookEx($__DM_g_hMsgBoxHook, $nCode, $wParam, $lParam)
	Switch $nCode
		Case $HCBT_CREATEWND
			Switch _WinAPI_GetClassName($hWnd)
				Case "#32770"
					_WinAPI_SetWindowSubclass($hWnd, $__DM_g_pMsgBoxSubProc, 1000)
				Case "Button"
					If $__DM_g_bUseDarkMode Then
						Local $sThemeName = $__DM_g_b24H2Plus ? 'DarkMode_DarkTheme' : 'DarkMode_Explorer'
						_WinAPI_SetWindowTheme($hWnd, $sThemeName)
					EndIf
			EndSwitch
	EndSwitch
	Return _WinAPI_CallNextHookEx($__DM_g_hMsgBoxHook, $nCode, $wParam, $lParam)
EndFunc   ;==>__DM_CBTHookProc

; #FUNCTION# ====================================================================================================================
; Author.........: UEZ
; Modified.......: WildByDesign, MattyD, argumentum
; ===============================================================================================================================
Func _GUIDarkTheme_MsgBox($iFlag, $sTitle, $sText, $iTimeout = 0, $hParentHWND = "")
	If Not $__DM_g_hMsgBoxSubProc Then $__DM_g_hMsgBoxSubProc = DllCallbackRegister(__DM_MsgBoxProc, "lresult", "hwnd;uint;wparam;lparam;uint_ptr;dword_ptr")
	If Not $__DM_g_pMsgBoxSubProc Then $__DM_g_pMsgBoxSubProc = DllCallbackGetPtr($__DM_g_hMsgBoxSubProc)
	; check for any DPI changes
	$__DM_g_iMsgBoxDpi = Round(_WinAPI_GetDPI() / 96, 2)
	If @error Then $__DM_g_iMsgBoxDpi = 1
	$__DM_g_bUseDarkMode = _WinAPI_ShouldAppsUseDarkMode()
	$__DM_g_bMsgBoxInitialized = False
	If $iFlag = Default Then $iFlag = BitOR($MB_TOPMOST, $MB_ICONINFORMATION)
	Local $hMsgProc = DllCallbackRegister(__DM_CBTHookProc, "int", "uint;wparam;lparam")
	Local Const $hThreadID = _WinAPI_GetCurrentThreadId()
	$__DM_g_hMsgBoxHook = _WinAPI_SetWindowsHookEx($WH_CBT, DllCallbackGetPtr($hMsgProc), Null, $hThreadID)
	If $sTitle = Default Then $sTitle = "Information"
	Local Const $iReturn = MsgBox($iFlag, $sTitle, $sText, $iTimeout, $hParentHWND)
	If $__DM_g_hMsgBoxHook Then _WinAPI_UnhookWindowsHookEx($__DM_g_hMsgBoxHook)
	DllCallbackFree($hMsgProc)
	While GUIGetMsg()
	WEnd
	Return $iReturn
EndFunc   ;==>_GUIDarkTheme_MsgBox

; #FUNCTION# ====================================================================================================================
; Name ..........: _GUIDarkTheme_MsgBoxSet
; Description ...: Sets custom colors
; Syntax ........: _GUIDarkTheme_MsgBoxSet($iBgColorTop, $iBgColorBottom, $iBgColorButton)
; Parameters ....: $iBgColorTop       - [optional] 0xRRGGBB (RGB value). Default is $__DM_g_iMsgBoxTopColor.
;                  $iBgColorBottom    - [optional] 0xRRGGBB (RGB value). Default is $__DM_g_iMsgBoxBottomColor.
;                  $iBgColorButton 	  - [optional] 0xRRGGBB (RGB value). Default is $__DM_g_iMsgBoxButtonColor.
; Return values .: None
; Author ........: WildByDesign
; Example .......: Yes
; ===============================================================================================================================
Func _GUIDarkTheme_MsgBoxSet($iBgColorTop = Default, $iBgColorBottom = Default, $iBgColorButton = Default)
	If $iBgColorTop <> Default Then $__DM_g_iMsgBoxTopColor = _WinAPI_SwitchColor($iBgColorTop)
	If $iBgColorBottom <> Default Then $__DM_g_iMsgBoxBottomColor = _WinAPI_SwitchColor($iBgColorBottom)
	If $iBgColorButton <> Default Then $__DM_g_iMsgBoxButtonColor = _WinAPI_SwitchColor($iBgColorButton)
EndFunc   ;==>_GUIDarkTheme_MsgBoxSet

; #FUNCTION# ====================================================================================================================
; Author.........: MattyD
; ===============================================================================================================================
Func _WinAPI_EndDialog($hWnd, $iReturn)
	Local $aCall = DllCall('user32.dll', "bool", "EndDialog", "hwnd", $hWnd, "int_ptr", $iReturn)
	If @error Then Return SetError(@error, @extended, False)
	Return $aCall[0]
EndFunc   ;==>_WinAPI_EndDialog

; #FUNCTION# ====================================================================================================================
; Author.........: UEZ
; Modified.......: WildByDesign
; ===============================================================================================================================
Func __GUIDarkTheme_AddToSubclass($hCtrl, $hSubclassProc, $pSubclassProc, $idSubClass, $pData = "")
	If $hCtrl Then
		$__DM_g_aControls[$__DM_g_iControlCount][0] = $hCtrl            ; hWnd
		$__DM_g_aControls[$__DM_g_iControlCount][1] = $hSubclassProc    ; hSubclassProc
		$__DM_g_aControls[$__DM_g_iControlCount][2] = $pSubclassProc    ; pSubclassProc
		$__DM_g_aControls[$__DM_g_iControlCount][3] = $idSubClass       ; idSubClass

		Switch $pSubclassProc
			Case $__DM_g_pUpDownSub
				_WinAPI_SetWindowSubclass($hCtrl, $__DM_g_pUpDownSub, $__DM_g_iControlCount)
			Case $__DM_g_pSubclassProc
				_WinAPI_SetWindowSubclass($hCtrl, $__DM_g_pSubclassProc, $__DM_g_iControlCount)
			Case $__DM_g_pTabProc
				_WinAPI_SetWindowSubclass($hCtrl, $__DM_g_pTabProc, $__DM_g_iControlCount)
			Case $__DM_g_pSizeboxProc
				_WinAPI_SetWindowSubclass($hCtrl, $__DM_g_pSizeboxProc, $__DM_g_iControlCount)
			Case $__DM_g_pButtonProc
				_WinAPI_SetWindowSubclass($hCtrl, $__DM_g_pButtonProc, $__DM_g_iControlCount, $pData)
			Case $__DM_g_pGroupProc
				_WinAPI_SetWindowSubclass($hCtrl, $__DM_g_pGroupProc, $__DM_g_iControlCount)
		EndSwitch

		$__DM_g_iControlCount += 1
	EndIf
EndFunc   ;==>__GUIDarkTheme_AddToSubclass

; #FUNCTION# ====================================================================================================================
; Author.........: UEZ
; Modified.......: WildByDesign
; ===============================================================================================================================
Func __GUIDarkTheme_SubclassCleanup()
	Local $hCtrl, $hSubclassProc, $pSubclassProc, $idSubClass
	#forceref $hSubclassProc
	; Remove all subclasses
	For $i = 0 To $__DM_g_iControlCount - 1
		$hCtrl = $__DM_g_aControls[$i][0]
		$hSubclassProc = $__DM_g_aControls[$i][1]
		$pSubclassProc = $__DM_g_aControls[$i][2]
		$idSubClass = $__DM_g_aControls[$i][3]
		If $hCtrl Then
			_WinAPI_RemoveWindowSubclass($hCtrl, $pSubclassProc, $idSubClass)
		EndIf
	Next

	If $__DM_g_hGroupProc Then DllCallbackFree($__DM_g_hGroupProc)
	$__DM_g_hGroupProc = 0
	$__DM_g_pGroupProc = 0
	If $__DM_g_hButtonProc Then DllCallbackFree($__DM_g_hButtonProc)
	$__DM_g_hButtonProc = 0
	$__DM_g_pButtonProc = 0
	If $__DM_g_hUpDownSub Then DllCallbackFree($__DM_g_hUpDownSub)
	$__DM_g_hUpDownSub = 0
	$__DM_g_pUpDownSub = 0
	If $__DM_g_hSubclassProc Then DllCallbackFree($__DM_g_hSubclassProc)
	$__DM_g_hSubclassProc = 0
	$__DM_g_pSubclassProc = 0
	If $__DM_g_hTabProc Then DllCallbackFree($__DM_g_hTabProc)
	$__DM_g_hTabProc = 0
	$__DM_g_pTabProc = 0
	If $__DM_g_hSizeboxProc Then DllCallbackFree($__DM_g_hSizeboxProc)
	$__DM_g_hSizeboxProc = 0
	$__DM_g_pSizeboxProc = 0
	; reset array
	Global $__DM_g_aControls[150][4] = [[0, 0, 0, 0]]
	$__DM_g_iControlCount = 0
	; clear date time picker subclasses
	If $__DM_g_hDateProcOld Then
		For $i = 0 To UBound($__DM_g_a_hDateTime) - 1
			_WinAPI_SetWindowLong($__DM_g_a_hDateTime[$i], $GWL_WNDPROC, $__DM_g_hDateProcOld)
		Next
		$__DM_g_hDateProcOld = 0
	EndIf
	If $__DM_g_hDateProc Then
		DllCallbackFree($__DM_g_hDateProc)
		$__DM_g_hDateProc = 0
		$__DM_g_pDateProc = 0
	EndIf
EndFunc   ;==>__GUIDarkTheme_SubclassCleanup

; #FUNCTION# ====================================================================================================================
; Author.........: UEZ
; Modified.......: WildByDesign
; ===============================================================================================================================
Func __GUIDarkTheme_SubclassProc($hWnd, $iMsg, $wParam, $lParam, $iID, $pData)
	#forceref $iID, $pData
	Local $hDC, $sClass, $iRet, $tRect, $hBrush
	Switch $iMsg
		Case $WM_CTLCOLORLISTBOX
			$hDC = $wParam
			_WinAPI_SetTextColor($hDC, _WinAPI_SwitchColor($__DM_g_iTextColor))
			$hBrush = $__DM_g_hBrushCtrl
			_WinAPI_SetBkColor($hDC, _WinAPI_SwitchColor($__DM_g_iCtrlBkColor))
			_WinAPI_SetBkMode($hDC, $TRANSPARENT)
			Return $hBrush

		Case $WM_CTLCOLOREDIT
			$hDC = $wParam
			_WinAPI_SetTextColor($hDC, _WinAPI_SwitchColor($__DM_g_iTextColor))
			_WinAPI_SetBkMode($hDC, $TRANSPARENT)
			$hBrush = $__DM_g_hBrushCtrl
			Return $hBrush

		Case $WM_NOTIFY
			If Not $__DM_g_bUseDarkMode Then Return __WinAPI_DefSubclassProc($hWnd, $iMsg, $wParam, $lParam)
			Local $tNMHDR = DllStructCreate($tagNMHDR, $lParam)
			Local $hFrom = $tNMHDR.hWndFrom
			Local $iCode = $tNMHDR.Code
			If $iCode = $NM_CUSTOMDRAW Then
				Local $tNMCD = DllStructCreate($__DM_tagNMCUSTOMDRAW, $lParam)
				Local $dwStage = $tNMCD.dwDrawStage
				$hDC = $tNMCD.hdc
				Switch _WinAPI_GetClassName($hFrom)
					Case "sysheader32"
						Switch $dwStage
							Case $CDDS_PREPAINT
								Return $CDRF_NOTIFYITEMDRAW
							Case $CDDS_ITEMPREPAINT
								_WinAPI_SetTextColor($hDC, _WinAPI_SwitchColor($__DM_g_iTextColor))
								_WinAPI_SetBkColor($hDC, _WinAPI_SwitchColor(0x000000))
								Return BitOR($CDRF_NEWFONT, $CDRF_NOTIFYPOSTPAINT)
						EndSwitch
				EndSwitch
			EndIf

		Case $WM_PAINT
			$sClass = _WinAPI_GetClassName($hWnd)
			If $sClass = "syslistview32" Or $sClass = "systreeview32" Or $sClass = "edit" Then
				$iRet = __WinAPI_DefSubclassProc($hWnd, $iMsg, $wParam, $lParam)
				Local $iWinStyle = _WinAPI_GetWindowLong($hWnd, $GWL_STYLE)
				If BitAND($iWinStyle, $WS_HSCROLL) And BitAND($iWinStyle, $WS_VSCROLL) Then
					$hDC = _WinAPI_GetWindowDC($hWnd)
					__GUIDarkTheme_PaintSizeBox($hWnd, $hDC)
					_WinAPI_ReleaseDC($hWnd, $hDC)
				EndIf
				Return $iRet
			Else
				Return __WinAPI_DefSubclassProc($hWnd, $iMsg, $wParam, $lParam)
			EndIf

		Case $WM_NCPAINT
			; WS_EX_CLIENTEDGE border is drawn in WM_NCPAINT (non-client area), not WM_CTLCOLOR.
			; We let Windows draw the default frame first, then overdraw it with our dark border.
			Local $hPen
			$sClass = _WinAPI_GetClassName($hWnd)
			If _IsBorderedControl($sClass) Then
				$iRet = __WinAPI_DefSubclassProc($hWnd, $iMsg, $wParam, $lParam)
				$hDC = _WinAPI_GetWindowDC($hWnd)
				$tRect = _WinAPI_GetWindowRect($hWnd)
				Local $iW = $tRect.Right - $tRect.Left
				Local $iH = $tRect.Bottom - $tRect.Top
				If $__DM_g_bShowCtrlBorder Then
					$hPen = $__DM_g_bUseDarkMode ? $__DM_g_hPenBorder : $__DM_g_hPenBorderSel
				Else
					$hPen = $__DM_g_hPenGui
				EndIf
				Local $hOldPen = _WinAPI_SelectObject($hDC, $hPen)
				Local $hNull = _WinAPI_GetStockObject(5)
				Local $hOldBr = _WinAPI_SelectObject($hDC, $hNull)
				DllCall('gdi32.dll', "bool", "Rectangle", "handle", $hDC, "int", 0, "int", 0, "int", $iW, "int", $iH)
				Local $hPen2 = (_WinAPI_GetFocus() = $hWnd) ? $__DM_g_hPen2Accent : $__DM_g_bUseDarkMode ? $__DM_g_hPen2Border : $__DM_g_hPen2BorderSel
				Local $hOldPen2 = _WinAPI_SelectObject($hDC, $hPen2)
				If _WinAPI_GetClassName($hWnd) = "Edit" Then
					If $__DM_g_bShowEditActive Then _WinAPI_DrawLine($hDC, 0, $iH - 1, $tRect.Right, $iH - 1)
				EndIf
				Local $hPen3 = (_WinAPI_GetFocus() = $hWnd) ? $__DM_g_hPenAccent : $__DM_g_hPenGui
				Local $hOldPen3 = _WinAPI_SelectObject($hDC, $hPen3)
				If _WinAPI_GetClassName($hWnd) = "Edit" And _WinAPI_GetFocus() <> $hWnd Then
					If $__DM_g_bShowEditActive Then _WinAPI_DrawLine($hDC, 0, $iH - 1, $tRect.Right, $iH - 1)
				EndIf
				_WinAPI_SelectObject($hDC, $hOldPen)
				_WinAPI_SelectObject($hDC, $hOldBr)
				_WinAPI_SelectObject($hDC, $hOldPen2)
				_WinAPI_SelectObject($hDC, $hOldPen3)
				__GUIDarkTheme_PaintSizeBox($hWnd, $hDC)
				_WinAPI_ReleaseDC($hWnd, $hDC)
				Return $iRet
			EndIf

		Case $WM_NCMOUSEMOVE
			; Scrollbar hot-tracking animates via WM_TIMER and paints the sizebox directly,
			; bypassing both WM_PAINT and WM_NCPAINT.  Re-stamp the corner on every NC mouse
			; move so the dark fill is never lost while the cursor is over the control.
			$sClass = _WinAPI_GetClassName($hWnd)
			If $sClass = "edit" Or $sClass = "listbox" Or $sClass = "syslistview32" Or $sClass = "systreeview32" Then
				$iRet = __WinAPI_DefSubclassProc($hWnd, $iMsg, $wParam, $lParam)
				$hDC = _WinAPI_GetWindowDC($hWnd)
				__GUIDarkTheme_PaintSizeBox($hWnd, $hDC)
				_WinAPI_ReleaseDC($hWnd, $hDC)
				Return $iRet
			EndIf

		Case $WM_NCCALCSIZE ;generate non-client area to ensure borders are not overpainted because no WS_EX_CLIENTEDGE
			$sClass = _WinAPI_GetClassName($hWnd)
			If _IsBorderedControl($sClass) And $wParam Then
				$iRet = __WinAPI_DefSubclassProc($hWnd, $iMsg, $wParam, $lParam)
				$tRect = DllStructCreate($tagRECT, $lParam)
				If $sClass = "ListBox" Then Return $iRet
				$tRect.left += 1
				$tRect.top += 1
				$tRect.right -= 1
				If $sClass = "Edit" Then
					$tRect.bottom -= $__DM_g_bShowEditActive ? 2 : 1
				Else
					$tRect.bottom -= 1
				EndIf

				Return $iRet
			EndIf
	EndSwitch
	Return __WinAPI_DefSubclassProc($hWnd, $iMsg, $wParam, $lParam)
EndFunc   ;==>__GUIDarkTheme_SubclassProc

; #FUNCTION# ====================================================================================================================
; Author.........: UEZ
; ===============================================================================================================================
Func _IsBorderedControl($sClass)
	Return ($sClass = "edit" Or $sClass = "listbox" Or $sClass = "syslistview32" Or $sClass = "systreeview32")
EndFunc   ;==>_IsBorderedControl

; #FUNCTION# ====================================================================================================================
; Author.........: UEZ
; Modified.......: WildByDesign
; ===============================================================================================================================
Func __GUIDarkTheme_PaintSizeBox($hWnd, $hDC)
	Local $iWinStyle = _WinAPI_GetWindowLong($hWnd, $GWL_STYLE)

	; Only proceed if both horizontal and vertical scrollbars are active
	If Not (BitAND($iWinStyle, $WS_HSCROLL) And BitAND($iWinStyle, $WS_VSCROLL)) Then Return False

	; 1. Retrieve exact Window and Client dimensions
	Local $tRW = _WinAPI_GetWindowRect($hWnd)
	Local $tRC = _WinAPI_GetClientRect($hWnd)

	; 2. Map Client coordinates to Window-DC space
	Local $tPoint = DllStructCreate($tagPOINT)
	$tPoint.X = 0
	$tPoint.Y = 0
	_WinAPI_ClientToScreen($hWnd, $tPoint)

	; Calculate border offsets
	Local $iOffL = $tPoint.X - $tRW.Left
	Local $iOffT = $tPoint.Y - $tRW.Top

	; Calculate total window dimensions
	Local $iWinW = $tRW.Right - $tRW.Left
	Local $iWinH = $tRW.Bottom - $tRW.Top

	; 3. Define the SizeBox Rect
	Local $tCorner = DllStructCreate($tagRECT)

	; LEFT/TOP: Start exactly where the client area ends (scrollbar junction)
	$tCorner.Left = $iOffL + $tRC.Right
	$tCorner.Top = $iOffT + $tRC.Bottom

	; RIGHT/BOTTOM: Align with the inner edge of the window border.
	$tCorner.Right = $iWinW - $iOffL
	$tCorner.Bottom = $iWinH - $iOffT

	; Adjust for Edit the size of the box
	If _WinAPI_GetClassName($hWnd) = "Edit" Then
		$tCorner.Bottom -= $__DM_g_bShowEditActive ? 1 : 0
	EndIf

	; 4. Paint the box using the dark theme color
	Local $hBrush = $__DM_g_hBrushSizebox
	_WinAPI_FillRect($hDC, $tCorner, $hBrush)

	Return True
EndFunc   ;==>__GUIDarkTheme_PaintSizeBox

; #FUNCTION# ====================================================================================================================
; Author.........: ioa747
; Modified.......: WildByDesign
; ===============================================================================================================================
Func __GUIDarkTheme_GUI_IsResizable($hWnd)
	Local $iStyle = _WinAPI_GetWindowLong($hWnd, $GWL_STYLE)
	; Check if the WS_SIZEBOX (0x00040000) bit is set
	; $WS_SIZEBOX and $WS_THICKFRAME are the same constant
	If BitAND($iStyle, $WS_SIZEBOX) Then
		Return True
	Else
		Return False
	EndIf
EndFunc   ;==>__GUIDarkTheme_GUI_IsResizable

; #FUNCTION# ====================================================================================================================
; Author.........: WildByDesign
; ===============================================================================================================================
Func _GUIDarkTheme_SwitchTheme($hWnd)
	_WinAPI_LockWindowUpdate($hWnd)
	$__DM_g_bUseDarkMode = _WinAPI_ShouldAppsUseDarkMode()
	Switch $__DM_g_bUseDarkMode
		Case True
			__GUIDarkTheme_SubclassCleanup()
			__GUIDarkTheme_BrushCleanup()
			__GUIDarkTheme_PenCleanup()
			_GUIDarkTheme_ApplyLight($hWnd)
		Case False
			__GUIDarkTheme_SubclassCleanup()
			__GUIDarkTheme_BrushCleanup()
			__GUIDarkTheme_PenCleanup()
			_GUIDarkTheme_ApplyDark($hWnd)
	EndSwitch
	; redraw window and menubar
	_WinAPI_RedrawWindow($hWnd, 0, 0, BitOR($RDW_INVALIDATE, $RDW_UPDATENOW, $RDW_ALLCHILDREN))
	Local $hMenu = _GUICtrlMenu_GetMenu($hWnd)
	If $hMenu Then _GUICtrlMenu_DrawMenuBar($hWnd)
	_WinAPI_LockWindowUpdate(0)
	_WinAPI_SetWindowPos($hWnd, 0, 0, 0, 0, 0, BitOR($SWP_NOMOVE, $SWP_NOSIZE, $SWP_NOZORDER, $SWP_FRAMECHANGED))
EndFunc   ;==>_GUIDarkTheme_SwitchTheme

; #FUNCTION# ====================================================================================================================
; Author.........: argumentum
; ===============================================================================================================================
Func _GUIDarkTheme_Version()
	Return $__DM_g_Version
EndFunc   ;==>_GUIDarkTheme_Version

; #FUNCTION# ====================================================================================================================
; Author.........: WildByDesign
; ===============================================================================================================================
Func _GUIDarkTheme_SetCornerPref($hWnd, $iCornerPref)
	; Requires Windows 11 Build 22000 or higher
	; Options $DWMWCP_DEFAULT, $DWMWCP_DONOTROUND, $DWMWCP_ROUND, $DWMWCP_ROUNDSMALL
	Local Const $DWMWA_WINDOW_CORNER_PREFERENCE = 33
	If @OSBuild >= 22000 Then
		_WinAPI_DwmSetWindowAttribute($hWnd, $DWMWA_WINDOW_CORNER_PREFERENCE, $iCornerPref)
	EndIf
EndFunc   ;==>_GUIDarkTheme_SetCornerPref

; #FUNCTION# ====================================================================================================================
; Name ..........: _GUIDarkTheme_CtrlBorderSet
; Description ...: Sets whether or not border is shown around controls or if Edit controls have active color on bottom.
; Syntax ........: _GUIDarkTheme_CtrlBorderSet($bShowCtrlBorder = Default, $bShowEditActive = Default)
; Parameters ....: $bShowCtrlBorder		- Boolean. True to show borders around controls, False to now show. Default is True.
;				   $bShowEditActive		- Boolean. True to show active color on Edit control, False not. Default is True.
; Return values .: None
; Author ........: WildByDesign
; Example .......: No
; ===============================================================================================================================
Func _GUIDarkTheme_CtrlBorderSet($bShowCtrlBorder = Default, $bShowEditActive = Default)
	If $bShowCtrlBorder = Default Then $__DM_g_bShowCtrlBorder = True
	If $bShowCtrlBorder <> Default Then $__DM_g_bShowCtrlBorder = $bShowCtrlBorder
	If $bShowEditActive = Default Then $__DM_g_bShowEditActive = True
	If $bShowEditActive <> Default Then $__DM_g_bShowEditActive = $bShowEditActive
EndFunc   ;==>_GUIDarkTheme_CtrlBorderSet

; #FUNCTION# ====================================================================================================================
; Author.........: WildByDesign
; ===============================================================================================================================
Func __GUIDarkTheme_CreatePens()
	If Not $__DM_g_hPenBlack Then $__DM_g_hPenBlack = _WinAPI_CreatePen($PS_SOLID, 1, 0x000000)
	If Not $__DM_g_hPenBtnBor Then $__DM_g_hPenBtnBor = _WinAPI_CreatePen($PS_SOLID, 1, _WinAPI_SwitchColor($__DM_g_iButtonColorBor))
	If Not $__DM_g_hPenGui Then $__DM_g_hPenGui = _WinAPI_CreatePen($PS_SOLID, 1, _WinAPI_SwitchColor($__DM_g_iGuiBkColor))
	If Not $__DM_g_hPenBorder Then $__DM_g_hPenBorder = _WinAPI_CreatePen($PS_SOLID, 1, _WinAPI_SwitchColor($__DM_g_iBorderColor))
	If Not $__DM_g_hPenBorderSel Then $__DM_g_hPenBorderSel = _WinAPI_CreatePen($PS_SOLID, 1, _WinAPI_SwitchColor($__DM_g_iBorderColorSel))
	If Not $__DM_g_hPenAccent Then $__DM_g_hPenAccent = _WinAPI_CreatePen($PS_SOLID, 1, _WinAPI_SwitchColor($__DM_g_iAccentColor))
	If Not $__DM_g_hPen2Accent Then $__DM_g_hPen2Accent = _WinAPI_CreatePen($PS_SOLID, 2, _WinAPI_SwitchColor($__DM_g_iAccentColor))
	If Not $__DM_g_hPen2Border Then $__DM_g_hPen2Border = _WinAPI_CreatePen($PS_SOLID, 2, _WinAPI_SwitchColor($__DM_g_iBorderColor))
	If Not $__DM_g_hPen2BorderSel Then $__DM_g_hPen2BorderSel = _WinAPI_CreatePen($PS_SOLID, 2, _WinAPI_SwitchColor($__DM_g_iBorderColorSel))
EndFunc   ;==>__GUIDarkTheme_CreatePens

; #FUNCTION# ====================================================================================================================
; Author.........: WildByDesign
; ===============================================================================================================================
Func __GUIDarkTheme_PenCleanup()
	If $__DM_g_hPenBlack Then
		_WinAPI_DeleteObject($__DM_g_hPenBlack)
		$__DM_g_hPenBlack = 0
	EndIf
	If $__DM_g_hPen2Accent Then
		_WinAPI_DeleteObject($__DM_g_hPen2Accent)
		$__DM_g_hPen2Accent = 0
	EndIf
	If $__DM_g_hPen2Border Then
		_WinAPI_DeleteObject($__DM_g_hPen2Border)
		$__DM_g_hPen2Border = 0
	EndIf
	If $__DM_g_hPen2BorderSel Then
		_WinAPI_DeleteObject($__DM_g_hPen2BorderSel)
		$__DM_g_hPen2BorderSel = 0
	EndIf
	If $__DM_g_hPenAccent Then
		_WinAPI_DeleteObject($__DM_g_hPenAccent)
		$__DM_g_hPenAccent = 0
	EndIf
	If $__DM_g_hPenBorderSel Then
		_WinAPI_DeleteObject($__DM_g_hPenBorderSel)
		$__DM_g_hPenBorderSel = 0
	EndIf
	If $__DM_g_hPenBorder Then
		_WinAPI_DeleteObject($__DM_g_hPenBorder)
		$__DM_g_hPenBorder = 0
	EndIf
	If $__DM_g_hPenGui Then
		_WinAPI_DeleteObject($__DM_g_hPenGui)
		$__DM_g_hPenGui = 0
	EndIf
	If $__DM_g_hPenBtnBor Then
		_WinAPI_DeleteObject($__DM_g_hPenBtnBor)
		$__DM_g_hPenBtnBor = 0
	EndIf
EndFunc   ;==>__GUIDarkTheme_PenCleanup

; #FUNCTION# ====================================================================================================================
; Author.........: WildByDesign
; ===============================================================================================================================
Func _GUIDarkTheme_AutoTheme($bFollowSystemTheme = True)
	If $bFollowSystemTheme Then
		GUIRegisterMsg($WM_SETTINGCHANGE, "__GUIDarkTheme_WM_SETTINGCHANGE")
	Else
		GUIRegisterMsg($WM_SETTINGCHANGE, "")
	EndIf
EndFunc   ;==>_GUIDarkTheme_AutoTheme

; #FUNCTION# ====================================================================================================================
; Author.........: argumentum
; Modified.......: WildByDesign
; ===============================================================================================================================
Func __GUIDarkTheme_WM_SETTINGCHANGE($hWnd, $iMsg, $wParam, $lParam)
	#forceref $hWnd, $iMsg, $wParam
	; lParam is a pointer to a string indicating what changed
	Local $tString = DllStructCreate("wchar[256]", $lParam)
	Local $sParam = DllStructGetData($tString, 1)
	Local Static $iModePrev

	; "ImmersiveColorSet" indicates a Light/Dark mode change
	If $sParam = "ImmersiveColorSet" Then
		Local $iMode = RegRead("HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme")
		If $iModePrev <> $iMode Then
			$iModePrev = $iMode
			_GUIDarkTheme_SwitchTheme($hWnd)
		Else
			Return $GUI_RUNDEFMSG
		EndIf
	EndIf

	Return $GUI_RUNDEFMSG
EndFunc   ;==>__GUIDarkTheme_WM_SETTINGCHANGE

; #FUNCTION# ====================================================================================================================
; Author.........: WildByDesign
; ===============================================================================================================================
Func __GUIDarkTheme_CreateBrushes()
	If Not $__DM_g_hBrushGui Then $__DM_g_hBrushGui = _WinAPI_CreateSolidBrush(_WinAPI_SwitchColor($__DM_g_iGuiBkColor))
	If Not $__DM_g_hBrushCtrl Then $__DM_g_hBrushCtrl = _WinAPI_CreateSolidBrush(_WinAPI_SwitchColor($__DM_g_iCtrlBkColor))
	If Not $__DM_g_hBrushBtn Then $__DM_g_hBrushBtn = _WinAPI_CreateSolidBrush(_WinAPI_SwitchColor($__DM_g_iButtonColor))
	If Not $__DM_g_hBrushBtnHov Then $__DM_g_hBrushBtnHov = _WinAPI_CreateSolidBrush(_WinAPI_SwitchColor($__DM_g_iButtonColorHov))
	If Not $__DM_g_hBrushBtnSel Then $__DM_g_hBrushBtnSel = _WinAPI_CreateSolidBrush(_WinAPI_SwitchColor($__DM_g_iButtonColorSel))
	If Not $__DM_g_hBrushMenuBk Then $__DM_g_hBrushMenuBk = _WinAPI_CreateSolidBrush(_WinAPI_SwitchColor($__DM_g_iMenuBkColor))
	If Not $__DM_g_hBrushMenuSel Then $__DM_g_hBrushMenuSel = _WinAPI_CreateSolidBrush(_WinAPI_SwitchColor($__DM_g_iMenuSelColor))
	If Not $__DM_g_hBrushMenuHot Then $__DM_g_hBrushMenuHot = _WinAPI_CreateSolidBrush(_WinAPI_SwitchColor($__DM_g_iMenuHotColor))
	If Not $__DM_g_hBrushAccent Then $__DM_g_hBrushAccent = _WinAPI_CreateSolidBrush(_WinAPI_SwitchColor(0x0078D4))
	If Not $__DM_g_hBrushAccentHot Then $__DM_g_hBrushAccentHot = _WinAPI_CreateSolidBrush(_WinAPI_SwitchColor(0x2FA7FF))
	If Not $__DM_g_hBrushTab Then $__DM_g_hBrushTab = _WinAPI_CreateSolidBrush(_WinAPI_SwitchColor($__DM_g_iTabColor))
	If Not $__DM_g_hBrushTabSel Then $__DM_g_hBrushTabSel = _WinAPI_CreateSolidBrush(_WinAPI_SwitchColor($__DM_g_iTabColorSel))
	If Not $__DM_g_hBrushSizebox Then $__DM_g_hBrushSizebox = _WinAPI_CreateSolidBrush(_WinAPI_SwitchColor($__DM_g_iSizeboxPaint))
	If Not $__DM_g_hBrushGray Then $__DM_g_hBrushGray = _WinAPI_CreateSolidBrush(_WinAPI_SwitchColor($__DM_g_iExtraGray))
	If Not $__DM_g_hBrushMsgBoxTop Then $__DM_g_hBrushMsgBoxTop = _WinAPI_CreateSolidBrush(_WinAPI_SwitchColor($__DM_g_iMsgBoxTopColor))
	If Not $__DM_g_hBrushMsgBoxBottom Then $__DM_g_hBrushMsgBoxBottom = _WinAPI_CreateSolidBrush(_WinAPI_SwitchColor($__DM_g_iMsgBoxBottomColor))
	If Not $__DM_g_hBrushTabBk Then $__DM_g_hBrushTabBk = _WinAPI_CreateSolidBrush(_WinAPI_SwitchColor($__DM_g_iTabCtrlBkColor))
	If Not $__DM_g_iBrushBorder Then $__DM_g_iBrushBorder = _WinAPI_CreateSolidBrush(_WinAPI_SwitchColor($__DM_g_iBorderColor))
EndFunc   ;==>__GUIDarkTheme_CreateBrushes

; #FUNCTION# ====================================================================================================================
; Author.........: WildByDesign
; ===============================================================================================================================
Func __GUIDarkTheme_BrushCleanup()
	If $__DM_g_iBrushBorder Then
		_WinAPI_DeleteObject($__DM_g_iBrushBorder)
		$__DM_g_iBrushBorder = 0
	EndIf
	If $__DM_g_hBrushTabBk Then
		_WinAPI_DeleteObject($__DM_g_hBrushTabBk)
		$__DM_g_hBrushTabBk = 0
	EndIf
	If $__DM_g_iBrushHdr Then
		_WinAPI_DeleteObject($__DM_g_iBrushHdr)
		$__DM_g_iBrushHdr = 0
	EndIf
	If $__DM_g_iBrushHdrHot Then
		_WinAPI_DeleteObject($__DM_g_iBrushHdrHot)
		$__DM_g_iBrushHdrHot = 0
	EndIf
	If $__DM_g_iBrushHdrSel Then
		_WinAPI_DeleteObject($__DM_g_iBrushHdrSel)
		$__DM_g_iBrushHdrSel = 0
	EndIf
	If $__DM_g_hBrushMsgBoxBottom Then
		_WinAPI_DeleteObject($__DM_g_hBrushMsgBoxBottom)
		$__DM_g_hBrushMsgBoxBottom = 0
	EndIf
	If $__DM_g_hBrushMsgBoxTop Then
		_WinAPI_DeleteObject($__DM_g_hBrushMsgBoxTop)
		$__DM_g_hBrushMsgBoxTop = 0
	EndIf
	If $__DM_g_hBrushGray Then
		_WinAPI_DeleteObject($__DM_g_hBrushGray)
		$__DM_g_hBrushGray = 0
	EndIf
	If $__DM_g_hBrushTabSel Then
		_WinAPI_DeleteObject($__DM_g_hBrushTabSel)
		$__DM_g_hBrushTabSel = 0
	EndIf
	If $__DM_g_hBrushTab Then
		_WinAPI_DeleteObject($__DM_g_hBrushTab)
		$__DM_g_hBrushTab = 0
	EndIf
	If $__DM_g_hBrushAccentHot Then
		_WinAPI_DeleteObject($__DM_g_hBrushAccentHot)
		$__DM_g_hBrushAccentHot = 0
	EndIf
	If $__DM_g_hBrushAccent Then
		_WinAPI_DeleteObject($__DM_g_hBrushAccent)
		$__DM_g_hBrushAccent = 0
	EndIf
	If $__DM_g_hBrushMenuBk Then
		_WinAPI_DeleteObject($__DM_g_hBrushMenuBk)
		$__DM_g_hBrushMenuBk = 0
	EndIf
	If $__DM_g_hBrushMenuSel Then
		_WinAPI_DeleteObject($__DM_g_hBrushMenuSel)
		$__DM_g_hBrushMenuSel = 0
	EndIf
	If $__DM_g_hBrushMenuHot Then
		_WinAPI_DeleteObject($__DM_g_hBrushMenuHot)
		$__DM_g_hBrushMenuHot = 0
	EndIf
	If $__DM_g_hBrushSizebox Then
		_WinAPI_DeleteObject($__DM_g_hBrushSizebox)
		$__DM_g_hBrushSizebox = 0
	EndIf
	If $__DM_g_hBrushGui Then
		_WinAPI_DeleteObject($__DM_g_hBrushGui)
		$__DM_g_hBrushGui = 0
	EndIf
	If $__DM_g_hBrushBtnSel Then
		_WinAPI_DeleteObject($__DM_g_hBrushBtnSel)
		$__DM_g_hBrushBtnSel = 0
	EndIf
	If $__DM_g_hBrushBtnHov Then
		_WinAPI_DeleteObject($__DM_g_hBrushBtnHov)
		$__DM_g_hBrushBtnHov = 0
	EndIf
	If $__DM_g_hBrushBtn Then
		_WinAPI_DeleteObject($__DM_g_hBrushBtn)
		$__DM_g_hBrushBtn = 0
	EndIf
	If $__DM_g_hBrushCtrl Then
		_WinAPI_DeleteObject($__DM_g_hBrushCtrl)
		$__DM_g_hBrushCtrl = 0
	EndIf
EndFunc   ;==>__GUIDarkTheme_BrushCleanup

; #FUNCTION# ====================================================================================================================
; Author.........: WildByDesign
; ===============================================================================================================================
Func __GUIDarkTheme_WM_CTLCOLOR($hWnd, $iMsg, $wParam, $lParam)
	Local $hDC = $wParam
	Local $hCtrl = $lParam
	Local $hBrush

	Switch $iMsg
		Case $WM_CTLCOLORLISTBOX
			$hDC = $wParam
			_WinAPI_SetTextColor($hDC, _WinAPI_SwitchColor($__DM_g_iTextColor))
			$hBrush = $__DM_g_hBrushCtrl
			_WinAPI_SetBkMode($hDC, $TRANSPARENT)
			Return $hBrush

		Case $WM_CTLCOLORBTN
			Local $hTabControl = _WinAPI_FindWindowEx($hWnd, "SysTabControl32")
			If $hTabControl Then
				If __GUIDarkTheme_IsCtrlInTab($hTabControl, $hCtrl) Then
					$hBrush = $__DM_g_hBrushTabBk
					Return $hBrush
				Else
					Return $GUI_RUNDEFMSG
				EndIf
			EndIf

		Case $WM_CTLCOLOREDIT
			_WinAPI_SetTextColor($hDC, _WinAPI_SwitchColor($__DM_g_iTextColor))
			_WinAPI_SetBkMode($hDC, $TRANSPARENT)
			$hBrush = $__DM_g_hBrushCtrl
			Return $hBrush

		Case $WM_CTLCOLORSTATIC
			If _WinAPI_GetClassName($hCtrl) = "Edit" Then
				_WinAPI_SetTextColor($hDC, _WinAPI_SwitchColor($__DM_g_iTextColor))
				_WinAPI_SetBkMode($hDC, $TRANSPARENT)
				$hBrush = $__DM_g_hBrushCtrl
				Return $hBrush
			EndIf

			If _WinAPI_GetClassName($hCtrl) = "SysLink" Then
				_WinAPI_SetBkMode($hDC, $TRANSPARENT)
				$hBrush = $__DM_g_hBrushGui
				Return $hBrush
			EndIf

			Return $GUI_RUNDEFMSG

	EndSwitch

	Return $GUI_RUNDEFMSG
EndFunc   ;==>__GUIDarkTheme_WM_CTLCOLOR

; #FUNCTION# ====================================================================================================================
; Author.........: WildByDesign
; ===============================================================================================================================
Func __GUIDarkTheme_GetCtrlColors($hWnd, ByRef $iTextColor, ByRef $iBkColor, ByRef $iBkMode)
	Local $hDC = _WinAPI_GetDC($hWnd)
	Local $hBrushTemp = _SendMessage(_WinAPI_GetParent($hWnd), $WM_CTLCOLORSTATIC, $hDC, $hWnd)
	$iTextColor = "0x" & Hex(_WinAPI_GetTextColor($hDC), 6)
	$iBkColor = "0x" & Hex(_WinAPI_GetBkColor($hDC), 6)
	$iBkMode = _WinAPI_GetBkMode($hDC)
	$hBrushTemp = _WinAPI_SelectObject($hDC, $hBrushTemp)
	_WinAPI_ReleaseDC($hWnd, $hDC)
EndFunc   ;==>__GUIDarkTheme_GetCtrlColors

; #FUNCTION# ====================================================================================================================
; Author.........: ioa747
; Modified.......: WildByDesign
; ===============================================================================================================================
Func __GUIDarkTheme_IsCtrlInTab($hTab, $hCtrl)
	; Get the bounding rectangles of the Tab and the Control
	Local $tRectTab = _WinAPI_GetWindowRect($hTab)
	Local $tRectCtrl = _WinAPI_GetWindowRect($hCtrl)

	; Get the intersection of the two rectangles
	Local $tIntersect = _WinAPI_IntersectRect($tRectTab, $tRectCtrl)

	; Check if the intersection rectangle is NOT empty
	If DllStructGetData($tIntersect, "Left") <> 0 Or DllStructGetData($tIntersect, "Right") <> 0 Then
		; If it intersects, return the current selected Tab Index (0, 1, etc.) in @extended
		Return SetError(0, $hTab, True)
	EndIf

	Return SetError(0, 0, False) ; Not within the Tab area
EndFunc   ;==>__GUIDarkTheme_IsCtrlInTab

; #FUNCTION# ====================================================================================================================
; Author.........: ioa747
; Modified.......: WildByDesign
; ===============================================================================================================================
Func __GUIDarkTheme_IsCtrlInRebar($hRebar, $hCtrl)
	; Get the bounding rectangles of the Rebar and the Control
	Local $tRectRebar = _WinAPI_GetWindowRect($hRebar)
	Local $tRectCtrl = _WinAPI_GetWindowRect($hCtrl)

	; Get the intersection of the two rectangles
	Local $tIntersect = _WinAPI_IntersectRect($tRectRebar, $tRectCtrl)

	; Check if the intersection rectangle is NOT empty
	If DllStructGetData($tIntersect, "Left") <> 0 Or DllStructGetData($tIntersect, "Right") <> 0 Then
		; If it intersects, return the current selected Tab Index (0, 1, etc.) in @extended
		Return SetError(0, $hRebar, True)
	EndIf

	Return SetError(0, 0, False) ; Not within the Rebar area
EndFunc   ;==>__GUIDarkTheme_IsCtrlInRebar

; #FUNCTION# ====================================================================================================================
; Author.........: WildByDesign
; ===============================================================================================================================
Func __DM_DarkThemeAvailability()
	Local $iRet = __DM_QueryDarkMode()
	Switch $iRet
		Case 2
			; DarkMode_DarkTheme is available
			Return True
		Case 1
			; DarkMode_Explorer is available, used only when DarkMode_DarkTheme is not available
			Return False
		Case Else
			; Fallback, OS may not support dark mode or detection failed
			Return False
	EndSwitch
EndFunc   ;==>__DM_DarkThemeAvailability

; #FUNCTION# ====================================================================================================================
; Author.........: argumentum
; Modified.......: WildByDesign
; ===============================================================================================================================
Func __DM_QueryDarkMode()
	Local $iColor
	If Not _WinAPI_IsThemeActive() Then Return SetError(0, 1, False)
	Local $hWnd = GUICreate("GUIDarkTheme")
	Local $iCOLOR_WINDOW = _WinAPI_SwitchColor(_WinAPI_GetSysColor($COLOR_WINDOW))  ; because of alt. themes
	$iColor = __DM_QueryThemeColors("DarkMode_DarkTheme::Edit", $hWnd)
	If Not @error And Hex($iColor, 6) <> Hex($iCOLOR_WINDOW, 6) Then
		GUIDelete($hWnd)
		Return 2 ; DarkMode_DarkTheme is available
	EndIf
	$iColor = __DM_QueryThemeColors("DarkMode_Explorer::Edit", $hWnd)
	If Not @error And Hex($iColor, 6) <> Hex($iCOLOR_WINDOW, 6) Then
		GUIDelete($hWnd)
		Return 1 ; DarkMode_Explorer is available, used only when DarkMode_DarkTheme is not available
	EndIf
	GUIDelete($hWnd)
	Return 0
EndFunc   ;==>__DM_QueryDarkMode

; #FUNCTION# ====================================================================================================================
; Author.........: argumentum
; Modified.......: WildByDesign
; ===============================================================================================================================
Func __DM_QueryThemeColors($sClass, $hWnd = Default)
	Local Const $TMT_FILLCOLOR = 3802
	Local Const $EP_BACKGROUND = 3
	Local Const $EBS_NORMAL = 1
	Local $hWndWas = $hWnd
	If IsKeyword($hWnd) Then $hWnd = GUICreate("Simple_GetThemeColor")
	Local $hTheme = _WinAPI_OpenThemeData($hWnd, $sClass)
	If @error Then
		If IsKeyword($hWndWas) Then GUIDelete($hWnd)
		Return SetError(1, 0, False)
	EndIf
	Local $iColor = _WinAPI_GetThemeColor($hTheme, $EP_BACKGROUND, $EBS_NORMAL, $TMT_FILLCOLOR)
	If @error Then
		If IsKeyword($hWndWas) Then GUIDelete($hWnd)
		Return SetError(2, 0, False)
	EndIf
	_WinAPI_CloseThemeData($hTheme)
	Return $iColor
EndFunc   ;==>__DM_QueryThemeColors

; #FUNCTION# ====================================================================================================================
; Author.........: WildByDesign
; ===============================================================================================================================
Func __DM_GroupboxInTab($hWnd)
	_ArrayAdd($__DM_g_aGroupInTab, $hWnd)
EndFunc   ;==>__DM_GroupboxInTab

; #FUNCTION# ====================================================================================================================
; Author.........: WildByDesign
; ===============================================================================================================================
Func __DM_DateTimeCtrlHandles($hWnd)
	_ArrayAdd($__DM_g_a_hDateTime, $hWnd)
EndFunc   ;==>__DM_DateTimeCtrlHandles

; #FUNCTION# ====================================================================================================================
; Name ..........: _GUIDarkTheme_AccentColorSet
; Description ...: Sets the accent color used by certain controls
; Syntax ........: _GUIDarkTheme_AccentColorSet($iColor = Default)
; Parameters ....: $hGui is GUI handle.
;                ; $iColor	- 0xRRGGBB, Default is 0x0078D4.
; Return values .: None
; Author ........: WildByDesign
; Example .......: No
; ===============================================================================================================================
Func _GUIDarkTheme_AccentColorSet($hGui, $iColor = Default)
	If $iColor = Default Then $__DM_g_iAccentColor = 0x0078D4
	If Not $iColor Then $__DM_g_iAccentColor = 0x0078D4
	If $iColor <> Default Then $__DM_g_iAccentColor = $iColor
	__GUIDarkTheme_PenCleanup()
	$__DM_g_iAccentColor = $iColor
	__GUIDarkTheme_CreatePens()
	; redraw GUI
	_WinAPI_RedrawWindow($hGui, 0, 0, BitOR($RDW_INVALIDATE, $RDW_UPDATENOW, $RDW_ALLCHILDREN))
EndFunc   ;==>_GUIDarkTheme_AccentColorSet

; #FUNCTION# ====================================================================================================================
; Author.........: MattyD
; ===============================================================================================================================
Func _GUICtrlTreeView_SetExtendedStyle($hTreeView, $iExStyle)
	Local Const $TVM_SETEXTENDEDSTYLE = 0x112C
	Local $iResult = _SendMessage($hTreeView, $TVM_SETEXTENDEDSTYLE, 0x07FD, $iExStyle)
	Return SetError(@error, @extended, $iResult)
EndFunc   ;==>_GUICtrlTreeView_SetExtendedStyle

; #FUNCTION# ====================================================================================================================
; Author.........: UEZ
; ===============================================================================================================================
Func _WinAPI_GetDPI($hWnd = 0)
	Local Const $LOGPIXELSX = 88
	$hWnd = Not $hWnd ? _WinAPI_GetDesktopWindow() : $hWnd
	Local Const $hDC = _WinAPI_GetDC($hWnd)
	If @error Then Return SetError(1, 0, 0)
	Local Const $iDPI = _WinAPI_GetDeviceCaps($hDC, $LOGPIXELSX)
	If @error Or Not $iDPI Then
		_WinAPI_ReleaseDC($hWnd, $hDC)
		Return SetError(2, 0, 0)
	EndIf
	_WinAPI_ReleaseDC($hWnd, $hDC)
	Return $iDPI
EndFunc   ;==>_WinAPI_GetDPI

; #FUNCTION# ====================================================================================================================
; Author.........: UEZ
; ===============================================================================================================================
Func _WinAPI_SetProcessDpiAwarenessContext($DPI_AWARENESS_CONTEXT_value)
	Local $aResult = DllCall('user32.dll', "bool", "SetProcessDpiAwarenessContext", @AutoItX64 ? "int64" : "int", $DPI_AWARENESS_CONTEXT_value) ;requires Win10 v1703+ / Windows Server 2016+
	If Not IsArray($aResult) Or @error Then Return SetError(1, @extended, 0)
	If Not $aResult[0] Then Return SetError(2, @extended, 0)
	Return $aResult[0]
EndFunc   ;==>_WinAPI_SetProcessDpiAwarenessContext

; #FUNCTION# ====================================================================================================================
; Author.........: UEZ
; ===============================================================================================================================
Func _WinAPI_GetDpiFromDpiAwarenessContext($DPI_AWARENESS_CONTEXT_value)
	Local $aResult = DllCall('user32.dll', "uint", "GetDpiFromDpiAwarenessContext", @AutoItX64 ? "int64" : "int", $DPI_AWARENESS_CONTEXT_value) ;requires Win10 v1803+ / Windows Server 2016+
	If Not IsArray($aResult) Or @error Then Return SetError(1, @extended, 0)
	If Not $aResult[0] Then Return SetError(2, @extended, 0)
	Return $aResult[0]
EndFunc   ;==>_WinAPI_GetDpiFromDpiAwarenessContext

; #FUNCTION# ====================================================================================================================
; Author.........: UEZ
; ===============================================================================================================================
Func _WinAPI_Base64Decode($sB64String)
	Local $aCrypt = DllCall("Crypt32.dll", "bool", "CryptStringToBinaryA", "str", $sB64String, "dword", 0, "dword", 1, "ptr", 0, "dword*", 0, "ptr", 0, "ptr", 0)
	If @error Or Not $aCrypt[0] Then Return SetError(1, 0, "")
	Local $bBuffer = DllStructCreate("byte[" & $aCrypt[5] & "]")
	$aCrypt = DllCall("Crypt32.dll", "bool", "CryptStringToBinaryA", "str", $sB64String, "dword", 0, "dword", 1, "struct*", $bBuffer, "dword*", $aCrypt[5], "ptr", 0, "ptr", 0)
	If @error Or Not $aCrypt[0] Then Return SetError(2, 0, "")
	Return DllStructGetData($bBuffer, 1)
EndFunc   ;==>_WinAPI_Base64Decode

; #FUNCTION# ====================================================================================================================
; Author.........: UEZ
; ===============================================================================================================================
Func _WinAPI_FindWindowEx($hParent, $sClass, $sTitle = "", $hAfter = 0)
	Local $ret = DllCall('user32.dll', "hwnd", "FindWindowExW", "hwnd", $hParent, "hwnd", $hAfter, "wstr", $sClass, "wstr", $sTitle)
	If @error Or Not IsArray($ret) Then Return 0
	Return $ret[0]
EndFunc   ;==>_WinAPI_FindWindowEx

; #FUNCTION# ====================================================================================================================
; Author.........: UEZ
; ===============================================================================================================================
Func _WinAPI_GetDPIForWindow($hWnd)
	Local $aResult = DllCall('user32.dll', "uint", "GetDpiForWindow", "hwnd", $hWnd) ;requires Win10 v1607+ / no server support
	If Not IsArray($aResult) Or @error Then Return SetError(1, @extended, 0)
	If Not $aResult[0] Then Return SetError(2, @extended, 0)
	Return $aResult[0]
EndFunc   ;==>_WinAPI_GetDPIForWindow

; #FUNCTION# ====================================================================================================================
; Author.........: WildByDesign
; ===============================================================================================================================
Func _GUIDarkTheme_ToolbarSetTrans($hToolbar, $bTransparency = Default)
	If $bTransparency = Default Then $bTransparency = True
	If $bTransparency <> Default Then $bTransparency = $bTransparency

	_GUICtrlToolbar_SetStyleTransparent($hToolbar, $bTransparency)

	; fix top line above toolbar
	If _GUICtrlToolbar_GetStyleTransparent($hToolbar) Then
		_GUICtrlToolbar_SetColorScheme($hToolbar, $__DM_g_iGuiBkColor, $__DM_g_iGuiBkColor)
	Else
		_GUICtrlToolbar_SetColorScheme($hToolbar, $__DM_g_iCtrlBkColor, $__DM_g_iCtrlBkColor)
	EndIf

	; trigger refresh of toolbar
	_WinAPI_SetWindowPos($hToolbar, 0, 0, 0, 0, 0, BitOR($SWP_NOMOVE, $SWP_NOSIZE, $SWP_NOZORDER, $SWP_FRAMECHANGED))
EndFunc   ;==>_GUIDarkTheme_ToolbarSetTrans

; #FUNCTION# ====================================================================================================================
; Author.........: Nine
; ===============================================================================================================================
Func __GUIDarkTheme_SetBandColor($hWnd, $iIndex, $nClrBack, $nClrFore)
	Local $tInfo = DllStructCreate($tagREBARBANDINFO)

	$tInfo.cbSize = DllStructGetSize($tInfo)
	$tInfo.fMask = $RBBIM_COLORS
	$tInfo.clrBack = $nClrBack
	$tInfo.clrFore = $nClrFore

	_SendMessage($hWnd, $RB_SETBANDINFOA, $iIndex, $tInfo, 0, "wparam", "struct*")
EndFunc   ;==>__GUIDarkTheme_SetBandColor

; #FUNCTION# ====================================================================================================================
; Author.........: jugador
; Notes..........: This fixed version of the _WinAPI_DefSubclassProc function prevents some subclassing crashes
; ===============================================================================================================================
Func __WinAPI_DefSubclassProc($hWnd, $iMsg, $wParam, $lParam)
	Return DllCall('comctl32.dll', 'lresult', 'DefSubclassProc', 'hwnd', $hWnd, 'uint', $iMsg, 'wparam', $wParam, _
			'lparam', $lParam)[0]
EndFunc   ;==>__WinAPI_DefSubclassProc

; #FUNCTION# ====================================================================================================================
; Author.........: WildByDesign
; Modified.......: argumentum
; ===============================================================================================================================
Func __DM_GetThemeDetails($sSep = @TAB, $sLastCRLF = @CRLF)
    Local $iRevision = RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion", "UBR")
    Local $iOSBuild = @OSBuild & "." & $iRevision
    Local $sRet = " OSBuild.rev:" & $sSep & $iOSBuild & @CRLF
    Local $sUxThemeDll = @SystemDir & "\uxtheme.dll"
    Local $iUxThemeVer = StringReplace(FileGetVersion($sUxThemeDll), "10.0.", "")
    $sRet &= "     UxTheme:" & $sSep & $iUxThemeVer & @CRLF
    Local $sAeroMsStyles = @WindowsDir & "\Resources\Themes\aero\aero.msstyles"
    Local $iAeroVer = StringReplace(FileGetVersion($sAeroMsStyles), "10.0.", "")
    $sRet &= "  Aero Theme:" & $sSep & $iAeroVer & $sLastCRLF
    Return $sRet
EndFunc   ;==>__DM_GetThemeDetails
