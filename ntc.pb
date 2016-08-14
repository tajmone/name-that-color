; ··············································································
; ··············································································
; ··························· NTC (Name That Color) ····························
; ··············································································
; ···················· v1.0.0 by Tristano Ajmone, June 2016 ····················
; ··············································································
; ····························· PureBASIC 5.42 LTS ·····························
; ··············································································
;{··············································································
; This file is part of "Name That Color" source code.
; NTC is Copyright (c) 2016 Tristano Ajmone, released under MIT License:
; -- https://opensource.org/licenses/MIT
; NTC repository is hosted at:
; -- https://github.com/tajmone/name-that-color
; ··············································································
; This is the main file of Name That Color source code, command-line version.
; Compile it in Console + ASCII mode.
;
; NOTE: If compiled in Unicode mode, it will give problems under Windows when
;       redirecting output via scripts -- it will interpose NUL chars between
;       each character. The issue might be solved, but requires further study of
;       Windows CMD limitations in handling unicode; and presently there is no
;       need to employ Unicode anyhow.
; ··············································································
; External files included by this source:
; -- ntc.color-funcs.pbi
; -- ntc.colors-names.pbi
; -- ntc.text-funcs.pbi
; ··············································································
; Tested under Windows 10 64 bit.
; Should work on other versions of Windows, Linux and Mac -- none of them tested
; so far, though. If you encounter any problems compiling on other systems, please
; open an issue on the project repository, so he can fix it.
;}··············································································

;- Compiler Checks
CompilerIf Not #PB_Compiler_ExecutableFormat = #PB_Compiler_Console
  CompilerError "This application must be compiled in Console mode!"
CompilerEndIf
CompilerIf #PB_Compiler_Unicode
  CompilerError "This application must be compiled in ASCII mode!"
CompilerEndIf

; ==============================================================================
;                           Semantic Versioning 2.0.0                           
;                               http://semver.org/                              
; ==============================================================================
#NTC_MAJOR = 1 ; MAJOR ver incr. w/ incompatible changes to NTC's CLI usage,
#NTC_MINOR = 0 ; MINOR ver incr. w/ added functionality in a backwards-compatible manner,
#NTC_PATCH = 0 ; PATCH ver incr. w/ backwards-compatible bug fixes & internal optimization.
NTC_VERSION$ = Str(#NTC_MAJOR) +"."+ Str(#NTC_MINOR) +"."+ Str(#NTC_PATCH)
NTC$ = "Name That Color v" + NTC_VERSION$

; ******************************************************************************
; *                   INCLUDE CORE PROCEDURES AND STRUCTURES                   *
;{******************************************************************************
XIncludeFile "ntc.colors-names.pbi" ; List of 1566 colors [hex-value + name] (string format)
                                    ; -- from Chirag Mehta’s “ntc js” (Name that Color JavaScript)
                                    ; NOTE: use `BuildNTCList()` to create Global NTC() map!
XIncludeFile "ntc.color-funcs.pbi"  ; `.col` Structure + Procedures: `dE00()`, `GetRGB()`, `RGB2Lab()`

;{ After these two files inclusions, these following core elements are ready to use:
; Structured types:
;   -- `ntcQueryObj`: A query object which is passed (by reference) to the NTC
;                     lookup procedure. Target color to lookup is set by asigning
;                     the hex color string to `ntcQueryObj\TargetColor`. Lookup
;                     procedure provides its results by setting the other fields
;                     in the passed query object.
;       ntcQueryObj\TargetColor.s  -- Hex color to lookup for matching name.
;       ntcQueryObj\MatchedColor.s -- Hex color of found match
;       ntcQueryObj\Name.s         -- Name of found match color
;       ntcQueryObj\DeltaE.d       -- dE00 distance between target color and found 
;                                     match (set to 0 if colors are exactly the same)
; Procedures:
;}  -- SearchColorName()

XIncludeFile "ntc.text-funcs.pbi"   ; Some Text procedures for Formatting shell output
UseModule TextFuncs
;} INCLUDES <<< ****************************************************************
OpenConsole()

; ==============================================================================
;                            NOTES ABOUT REDIRECTION                            
;{==============================================================================
;- WORK NOTES: stdstreams redirection under Windows CMD!
;- WORK NOTES: stdstreams redirection under Windows CMD!
; Left here for future uses...
; https://en.wikipedia.org/wiki/Standard_streams
; REDIRECTING STDOUT: "1>" or ">"
; REDIRECTING STDERR: "2>"
; REDIRECTING BOTH: "1> 2>&1" (note: '2>&1' must come AFETR '1>' + filename)
; -- Ex.1: "ntc #23e055 1> outputfile.txt 2>&1"
; USE "nul" TO DUMP:
; -- Ex.1: "ntc #23e055 2> nul" (dump stderr)
; -- Ex.2: "ntc #23e055 1> nul" (dump stdout)
;}

; ==============================================================================
;                           Exit Code / Return Status                           
; ==============================================================================
Enumeration
  #Success  ; = 0
  #Failure  ; = 1
  #No_Match ; = 2 -- In case user restricted Max dE value for valid matching
EndEnumeration
ExitCode = #Success ; ie: assume Errorlevel returned is `0`

; ==============================================================================
;                                Default Options                                
; ==============================================================================
optShow_dE = #False
optMax_dE.d = -2 ; Max acceptable dE distance for color match (-2=OFF | -1=ExactMatch)
Enumeration
  #EOL_None
  #EOL_LF
  #EOL_CRLF
  #EOL_CR
EndEnumeration
optEOL = #EOL_None
; ==============================================================================
;                                     RegEx                                     
; ==============================================================================
; NOTE: RegExes are not manually freed from mem: they'll be freed at program exit.
Enumeration
  #RE_HexColor ; Sanitize Hex Color Syntax
  #RE_RGBColor ; Sanitize RGB Color Syntax
  #RE_Options  ; Catch Option & Value
  #RE_Float    ; Sanitize Float in '-dE=' option
EndEnumeration

Restore RegEx_Definitions
For i = 0 To #PB_Compiler_EnumerationValue -1
  Read.s RegEx$
  If Not CreateRegularExpression(i, RegEx$)
    Debug("RegEx creation failed: RegEx number " + Str(i) + " = `" + RegEx$ + "`")
    End
  EndIf
Next i

DataSection
  RegEx_Definitions:
  Data.s "^#[A-F0-9]+$"                             ; #RE_HexColor
  Data.s "^(\d{1,3}),(\d{1,3}),(\d{1,3})$"          ; #RE_HexColor
  Data.s "-(?<option>\w+)(?:=(?<value>.+))?"        ; #RE_Options
  Data.s "^(?:0|[1-9]\d*)(?:\.\d*)?(?:e\d+)?$"      ; #RE_Float
EndDataSection


; ------------------------------------------------------------------------------

TargetColor.ntcQueryObj ; Create Query Object

; ******************************************************************************
; *                                PARSE PARAMS                                *
;{******************************************************************************
numParams = CountProgramParameters()
; ==============================================================================
;                           NO PARAMETERS WERE PASSED                           
; ==============================================================================
If numParams = 0
  Goto QUICK_REF: 
EndIf

For i = 1 To numParams
  currParam.s = ProgramParameter() 
  ; ==============================================================================
  ;                                 HANDLE OPTIONS                                
  ;{==============================================================================
  If MatchRegularExpression(#RE_Options, currParam); Left(currParam, 1) = "-" 
    ExamineRegularExpression(#RE_Options, currParam)
    While NextRegularExpressionMatch(#RE_Options)
      option$ = LCase(RegularExpressionNamedGroup(#RE_Options, "option"))
      optionval$ = LCase(RegularExpressionNamedGroup(#RE_Options, "value"))
      Select option$ ; all checks in lower-case!
        Case "h", "help"
          ;{================================= ( -help ) ==================================
          Select optionval$
            Case #Empty$
              Goto SHOW_HELP
              ; ----------------------------------- TOPICS -----------------------------------
            Case "topics"
              Goto LIST_TOPICS
            Case "de", "deltae"
              Goto DELTA_E
            Default
              Goto BAD_TOPIC
          EndSelect ;}
        Case "about"
          ;{================================= ( -about ) =================================
          Goto ABOUT ;}
        Case "credits"
          ;{================================ ( -credits ) ================================
          Goto CREDITS ;}
        Case "de"
          ;{================================== ( -dE ) ===================================
          optShow_dE = #True
          If optionval$
            If MatchRegularExpression(#RE_Float, optionval$)
              ; --------------------------- Float is well defined ----------------------------
              optMax_dE = ValD(optionval$)
              If optMax_dE = 0
                optMax_dE = -1 ; Only exact matches will be returned!
              EndIf
            Else
              ; ---------------------------- Float is ill defined ----------------------------
              Goto BAD_MAX_DE
            EndIf
          EndIf ;}
        Case "eol"
          ;{================================== ( -EOL ) ==================================
          Select optionval$
            Case #Empty$, "lf"
              optEOL = #EOL_LF
            Case "crlf"
              optEOL = #EOL_CRLF
            Case "cr"
              optEOL = #EOL_CR
            Default
              Goto BAD_EOL
          EndSelect ;}
        Default
          Goto BAD_OPTION
      EndSelect
    Wend
    ;{ HANDLE OPTS <<< ===========================================================
  ElseIf Left(currParam, 1) = "#"    
    ; ==============================================================================
    ;                                 HANDLE COLORS                                 
    ;{==============================================================================
    ; ------------------------------------------------------------------------------
    ;                               Sanitize Hex Color                              
    ;{------------------------------------------------------------------------------
    If Not (Len(currParam) = 4 Or Len(currParam) = 7) ; must be either 4 or 7 chars (#FFF / #FFFFFF)
      Goto BAD_HEX_COLOR
    EndIf
    currParam = UCase(currParam)
    If Not MatchRegularExpression(#RE_HexColor, currParam) ; Test with RegEx if it's a valid color
      Goto BAD_HEX_COLOR
    EndIf ; ================= COLOR IS VALID =================
    If TargetColor.ntcQueryObj\TargetColor
      Goto TOO_MANY_COLS
    ElseIf Len(currParam) = 4 ; It's a 3-digits color definition...
      temp$ = Mid(currParam, 2)
      For x = 3 To 1 Step -1
        temp$ = InsertString(temp$, Mid(temp$, x, 1), x)
      Next
      TargetColor.ntcQueryObj\TargetColor = temp$      
    Else
      TargetColor.ntcQueryObj\TargetColor = Mid(currParam, 2)
    EndIf 
    ;} SAN HEX COL <<< -------------------------------------------------------------
  ElseIf MatchRegularExpression(#RE_RGBColor, currParam)
    ; ------------------------------------------------------------------------------
    ;                               Sanitize RGB Color                              
    ;{------------------------------------------------------------------------------
    ExamineRegularExpression(#RE_RGBColor, currParam)
    Dim RGBcol.i(2)
    OutOfRange = #False
    temp$ = ""
    While NextRegularExpressionMatch(#RE_RGBColor)
      For n = 1 To 3
        RGBcol(n-1) = Val(RegularExpressionGroup(#RE_RGBColor, n))
        If RGBcol(n-1) > 255
          OutOfRange = #True
        EndIf
        temp$ + RSet(Hex(RGBcol(n-1)), 2, "0") 
      Next
    Wend
    If OutOfRange
      Goto BAD_RGB_COLOR
    EndIf ; ================= COLOR IS VALID =================
    If TargetColor.ntcQueryObj\TargetColor
      Goto TOO_MANY_COLS
    EndIf
    TargetColor.ntcQueryObj\TargetColor = temp$ 
    ;} SAN RGB COL <<< -------------------------------------------------------------
    ;} HANDLE COLORS <<< ===========================================================
  Else
    ; ==============================================================================
    ;                               UNKNOWN PARAMETER                               
    ; ==============================================================================
    Goto BAD_PARAM
  EndIf
Next

; ==============================================================================
;                              No Color Defined...                              
; ==============================================================================
If TargetColor.ntcQueryObj\TargetColor = #Empty$
  Goto NO_COLOR
EndIf
;} PARSE PARAMS <<< ************************************************************

BuildNTCList()  ; Builds Global Map `NTC()`: now ready to use.
                ; -- keys are hex color-values (eg: "FF0000")
                ; -- elements are color names  (eg: "Red")

ExactMatch = SearchColorName(@TargetColor)

If optMax_dE = -2 Or TargetColor\DeltaE <= optMax_dE ; If user has set a Max dE for a match
  STDOUT$ = TargetColor\Name
Else
  ExitCode = #No_Match
EndIf

If optShow_dE ; Check is dE value should be printed on stderr
  STDERR$ = StrD(TargetColor\DeltaE)
EndIf

; ******************************************************************************
; *                              WRAP UP AND EXIT                              *
; ******************************************************************************

WRAP_UP:

Select optEOL
  Case #EOL_LF
    EOL$ = #LF$    
  Case #EOL_CR
    EOL$ = #CR$    
  Case #EOL_CRLF
    EOL$ = #CR$ + #LF$    
  Default
    EOL$ = #Empty$
EndSelect

If STDOUT$ 
  Print(STDOUT$ + EOL$)
EndIf
If STDERR$ 
  ConsoleError(STDERR$)
EndIf

CloseConsole()
End ExitCode ; NOTE: Under Windows CMD, can capture it with `%errorlevel%` (test: `echo %errorlevel%`)

; <<< MAIN EXECUTION :: END ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


; ··············································································
; ··············································································
; ··························· TEXT OUTPUT PROCEDURES ···························
; ··············································································
; ··············································································

; ··············································································
; ································ HELP / INFO ·································
;{··············································································
; ******************************************************************************
; *                                 ABOUT NTC                                  *
;{******************************************************************************
ABOUT:

STDOUT$ = #PAR_SEP + Heading("About " + NTC$)
STDOUT$ + TextWrap(~"ntc is a free open source utility developed in PureBASIC (v5.42) by Tristano Ajmone in June 2016, "+
                   "and released under the MIT License:" + #PAR_SEP +
                   " -- https://opensource.org/licenses/MIT") + #PAR_SEP
STDOUT$ + TextWrap(~"You are therefore free to copy, change, and redistribute this binary file and/or its "+
                   "source code (or part of it), even for commercial use, under the permissive terms of the MIT License. "+
                   "Basically, you can do what you want with it as long as you provide due credits and don't hold the author liable.") + #PAR_SEP
STDOUT$ + TextWrap(~"ntc was inspired by Chirag Mehta's \"ntc js\", and  was developed using third parties' code as references "+
                   "points -- without their precious contributions  this project wouldn't have been possible. "+
                   "For a full list of credits, please type:"+ #PAR_SEP + 
                   ~"    ntc -credits") + #PAR_SEP
STDOUT$ + TextWrap(~"The ntc project is hosted at GitHub:" + #PAR_SEP +
                   " -- https://github.com/tajmone/name-that-color")

Goto WRAP_UP ;{

; ******************************************************************************
; *                                  CREDITS                                   *
;{******************************************************************************
CREDITS:

LIST_BULL$ = " [#] "

STDOUT$ = #PAR_SEP + Heading(NTC$ + " -- Due Credits")
STDOUT$ + TextWrap("The author of ntc expresses gratitude and attributes due credits to all those "+
                   "people whose work has rendered this project possible by sharing their source codes "+
                   "or by providing crucial information.")

; ============================= Source Code Reuse ==============================

STDOUT$ + #PAR_SEP + Heading("Source Code Reuse", 2)

LISTELEM$ = ~"\"ntc js\" (Name that Color JavaScript) by Chirag Mehta, 2007 (CC BY 2.5) -- This is the project that inspired "+
            "the creation of ntc. It's both an online tool and a JS script. The color names list "+
            "used here is taken from ntc js, unaltered; but a different algorithm was used for comparing "+
            "color similarity, yelding more accurate matches. Only the list of color names and values pairs was taken "+
            "from this project, which Chirag Mehta compiled from different sources (see below)." + #PAR_SEP +
            "NOTE: ntc js's algorithm, and design are copyrighted to Chirag Mehta, 2007." + #PAR_SEP +
            "-- http://chir.ag/projects/ntc/" + #PAR_SEP +
            "-- http://creativecommons.org/licenses/by/2.5/" + #BLOCK_SEP
LISTELEM$ + ~"\"php-color-difference\" by @renasboy (no license claims) -- ntc's dE00 algorithm is a port of this PHP class." + #PAR_SEP +
            "-- https://github.com/renasboy/php-color-difference" + #BLOCK_SEP
LISTELEM$ + ~"\"dE00.js\" by Zachary Schuessler (public domain) -- This dE00 JavaScript implementation was heavily referenced while "+
            ~"porting \"php-color-difference\" to PureBASIC; its comments eased understanding of the alogrithm, and "+
            "its variables names were adopted instead of @renasboy's." + #PAR_SEP +
            "-- https://github.com/zschuessler/DeltaE" + #BLOCK_SEP
LISTELEM$ + ~"\"RGB-LAB\" (JavaScript) by Kevin Kwok (no license claims) -- ntc's RGB2Lab() procedure was built on an adaptation of its "+
            "rgb2lab() function." + #PAR_SEP +
            "-- https://github.com/antimatter15/rgb-lab"
STDOUT$ + BulletList(LISTELEM$, LIST_BULL$)

; ================================ Colors Names ================================
STDOUT$ + #PAR_SEP + Heading("Colors Names", 2)

STDOUT$ + TextWrap("Regarding the colors in this list, Chirag Mehta mentions in his credits the following sources:")

LISTELEM$ = ~"\"The Resene RGB Values List\", copyrighted to Resene Paints Ltd, 2001:" + #PAR_SEP +
            "-- http://people.csail.mit.edu/jaffer/Color/resenecolours.txt" + #BLOCK_SEP
LISTELEM$ + ~"Wikipedia's entries for \"Lists of colors\" and \"List of Crayola crayon colors\":" + #PAR_SEP +
            "-- https://en.wikipedia.org/wiki/Lists_of_colors" + #PAR_SEP +
            "-- https://en.wikipedia.org/wiki/List_of_Crayola_crayon_colors" + #BLOCK_SEP
LISTELEM$ + ~"Color-Name Dictionaries:" + #PAR_SEP +
            "-- http://www-swiss.ai.mit.edu/~jaffer/Color/Dictionaries.html" + #PAR_SEP +
            "[ above link now redirects to: ]" + #PAR_SEP +
            "-- http://people.csail.mit.edu/jaffer/Color/Dictionaries.html"
STDOUT$ + BulletList(LISTELEM$, LIST_BULL$)

; ============================== Useful Resources ==============================
STDOUT$ + #PAR_SEP + Heading("Useful Resources", 2)

LISTELEM$ = ~"delta E Calculators -- These online tools have been invaluable for "+
            "testing accuracy of results during development:" + #PAR_SEP +
            "-- http://www.boscarol.com/DeltaE.html" + #PAR_SEP +
            "-- http://colormine.org/delta-e-calculator/cie2000" + #BLOCK_SEP
LISTELEM$ + "For insights into the code workings, I've been relying on Zachary Schuessler's "+
            ~"well commented \"dE00.js\" JavaScript implementation, and his informative "+
            "website dedicated to Delta E Color Difference Algorithms:"+ #PAR_SEP +
            "-- https://github.com/zschuessler/DeltaE" + #PAR_SEP +
            "-- http://zschuessler.github.io/DeltaE/learn/" + #BLOCK_SEP
LISTELEM$ + ~"EasyRGB -- This website is a gold mine when it comes to digital colors math and "+
            "formulas, providing lots of valuable pseudocode examples:" + #PAR_SEP +
            "-- http://www.easyrgb.com/index.php?X=MATH"

STDOUT$ + BulletList(LISTELEM$, LIST_BULL$)

Goto WRAP_UP ;{

; ******************************************************************************
; *                                 QUICK REF                                  *
;{******************************************************************************
QUICK_REF:

STDOUT$ = #PAR_SEP + Heading(NTC$ +" -- Quick Usage Guide")
STDOUT$ + ~"ntc [options] <color>\n\n"

LT$ + "<color>" + #BLOCK_SEP
RT$ + ~"Hexadecimal (eg: #FF00AA or #F0A) or RGB notation (comma separated, no spaces; eg: 255,0,170)." + #BLOCK_SEP

LT$ + "-de" + #BLOCK_SEP
RT$ + "Print (on stderr) dE distance of matched color." + #BLOCK_SEP

LT$ + "-de=<dE_max>" + #BLOCK_SEP
RT$ + "Set roof dE value (unsigned float): matches with dE > than <dE_max> will be discarded." + #BLOCK_SEP

LT$ + "-eol" + #BLOCK_SEP
RT$ + "Enables a trailing LF after color name match result (on stdout). "+
      "Doesn't affect behaviour of error or help messages."+ #BLOCK_SEP

LT$ + "-eol=(lf|cr|crlf)" 
RT$ + "Same as above, but specifies which type of EOL to use. Choices are: "+
      ~"\"lf\" for Line Feed (\"\\n\" = 0x0A, *nix style), \"cr\" for Carriage Return (\"\\r\" = 0x0D), "+
      ~" or \"crlf\" for CR+LF (\"\\r\\n\" = 0x0D0A, Win style). Example: ntc #42bc08 -eol=crlf"   

STDOUT$ + TwoColumnsWrap(LT$, RT$) + #PAR_SEP

STDOUT$ + TextWrap(~"Type \"ntc -h\" to view full Help and more options.")

Goto WRAP_UP ;{

; ******************************************************************************
; *                                 SHOW HELP                                  *
;{******************************************************************************
SHOW_HELP:

STDOUT$ = #PAR_SEP + NTC$ + #BLOCK_SEP +
          "ntc [options] <color>" + #BLOCK_SEP

; ================================ Basic Usage =================================
STDOUT$ + Heading("Basic Usage:")
LT$ = "ntc <color>" + #BLOCK_SEP
RT$ = "ntc looks up <color> in its color-names list and prints on stdout the name of closest match found "+
      "(by default, no newline characters added). The list contains " +Str(#TOTAL_NTC_COLORS)+ " color names, and was compiled by "+
      "Chirag Mehta." + #BLOCK_SEP

LT$ + "<color>" + #BLOCK_SEP
RT$ + "Color can be passed in either hexadecimal or RGB notation." + #BLOCK_SEP

LT$ + "<hexcolor>" + #BLOCK_SEP
RT$ + "Hexadecimal color can be passed as a six-digit triplet (eg. #FF00AA) or in shorthand "+
      "three-digit format (eg. #F0A). Color strings are case-insensitive." + #BLOCK_SEP

LT$ + "<RGB color>"
RT$ + "RGB color must be passed as three unspaced comma-separated integer numbers, "+
      "ranging 0-255 (eg. 255,0,170)."

STDOUT$ + TwoColumnsWrap(LT$, RT$) + #PAR_SEP
; ==============================================================================
STDOUT$ + Heading("Exit Status and Errors:", 2)
STDOUT$ + TextWrap("On succesfull color match ntc will return zero, in case "+
                   "of failure exit code will be greater than zero.") + #PAR_SEP

LT$ = "exit code = 0" + #BLOCK_SEP
RT$ = "ntc found a color-name match. Result is printed on stdout." + #BLOCK_SEP

LT$ + "exit code = 1" + #BLOCK_SEP
RT$ + "Failure to execute command due to invalid parameters. Error details are printed on stderr." + #BLOCK_SEP

LT$ + "exit code = 2" 
RT$ + ~"(only applies to \"-de:<max_de>\" option) ntc executed correctly, but "+
      "couldn't find a match within the specified dE range. "+
      "Nothing is printed on stdout, dE of failed match is printed on stdout." 

STDOUT$ + TwoColumnsWrap(LT$, RT$) + #PAR_SEP
; =============================== Advanced Usage ===============================
STDOUT$ + Heading("Advanced Usage:")

STDOUT$ + "ntc [-option | -option=arg]... <color>" + #BLOCK_SEP
STDOUT$ + TextWrap(~"Options follow the hyphenated syntax \"-option_name\", some of them allowing "+
                   ~"or requiring additional arguments via the equal sign: \"-option=argument\".")+ #PAR_SEP 
; ---------------------------------- ( -dE ) -----------------------------------

LT$ = "-de" + #BLOCK_SEP
RT$ = "Delta E -- print on stderr the dE color distance between target color and found match. "+
      "dE is a double precision float number, so you might consider rounding its value. "+ #PAR_SEP +
      "In case of an exact match (target and match have same RGB values), no dE00 comparisons "+
      "are made, and -1 is returned as dE value. "+
      "The rationale behind this is to be able to discern between exact matches and near-zero "+
      "dE vals when rounding results. If such distinction is not needed, -1 will still eval as "+
      "less than any dE floor you might employ (as well as <=0)." + #BLOCK_SEP

LT$ + "-de=<dE_max>" + #BLOCK_SEP
RT$ + ~"Max dE -- (same as above, plus:) sets a Delta E roof value beyond which a match is "+
      "discarded as being too far apart from target color. With this option enabled, ntc is "+
      "not guaranteed to produce a match; in case of failure, and exit code of 2 will be returned, "+
      "nothing will be printed to stdout, but dE value of discarded match will still be passed to stderr."+ #PAR_SEP +
      "<dE_max> must be an unsigned positive number, either integer or float (double "+
      "precision, in decimal or scientific/ exponent notation)."+ #PAR_SEP +
      "Since this option deals with tollerance to color difference, usually you should be loooking "+
      "for a <dE_max value> within the ranges 0-1 (difference not perceptible by the human eye) "+
      "or 1-2 (perceptible through close observation)."+ #PAR_SEP +
      "Type `ntc -h=de` for more info on dE ranges." + #BLOCK_SEP

LT$ + "-de=0" + #BLOCK_SEP
RT$ + ~"If you set <dE_max> to absolute zero, ntc will filter out all non exact matchs "+
      "-- ie: it will set <dE_max> to -1, which is its internal reference for color matches that "+
      "have identical color value of target color."+ #BLOCK_SEP

; ---------------------------------- ( -EOL ) ----------------------------------
LT$ + "-eol" + #BLOCK_SEP
RT$ + "Add EOL Char -- by default, ntc doesn't add any EOL char to its results. "+
      ~"This option enables a trailing LF (\"\\n\", 0x0A) after the matched color name "+
      "result (on stdout). It's useful when using ntc via scripts "+
      "automation, allowing file redirection of results on separate lines."+ #PAR_SEP +
      "It doesn't affect the behaviour of returned dE value (on stderr) nor of error or help messages "+
      "(which always employ default OS newline char)."+ #BLOCK_SEP

LT$ + "-eol=(lf|cr|crlf)" + #BLOCK_SEP
RT$ + "Same as above, but allows to specify which EOL char to use:" + #PAR_SEP +
      ~"--\"lf\"   = Use LF (Line Feed = \"\\n\" = 0x0A)" + #PAR_SEP +
      ~"--\"cr\"   = Use CR (Carriage Return = \"\\r\" = 0x0D)" + #PAR_SEP +
      ~"--\"crlf\" = Use CRLF (CR+LF = \"\\r\\n\" = 0x0D0A)" + #PAR_SEP +
      ~"Example: ntc 24,120,200 -eol=crlf" + #BLOCK_SEP  

STDOUT$ + TwoColumnsWrap(LT$, RT$)

; ================================ Help & Info =================================
STDOUT$ + Heading("Help And Info:")
STDOUT$ + "Invoke ntc without arguments to view the Quick Usage Guide." + #BLOCK_SEP

LT$ = "-about" + #BLOCK_SEP
RT$ = "Show information about ntc." + #BLOCK_SEP

LT$ + "-credits" + #BLOCK_SEP
RT$ + "Show credits and acknowledgements for ntc." + #BLOCK_SEP

LT$ + "-h, -help" + #BLOCK_SEP
RT$ + "Show this Help document." + #BLOCK_SEP

LT$ + "-h=<topic>" + #BLOCK_SEP
RT$ + "Show help for a specific topic. <topic> must be one of the topics listed below." + #BLOCK_SEP

LT$ + "-h=topics"
RT$ + "List all available help topics."

STDOUT$ + TwoColumnsWrap(LT$, RT$) + #PAR_SEP


STDOUT$ + Heading("Available Help Topics:", 2)
Gosub SHARED_TOPICS ; RETIVE LIST OF TOPICS (SHARED WITH "HELP")


Goto WRAP_UP ;}

; ··············································································
; ································ HELP TOPICS ·································
;{··············································································

; \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;                               SHARED DEFINITIONS                              
; //////////////////////////////////////////////////////////////////////////////

SHARED_TOPICS:

LT$ = "de" + #BLOCK_SEP
RT$ = "Delta E -- Info about the dE algorithm used by ntc to calculate color difference between the target "+
      "color being looked up and the colors in its inner list." + #BLOCK_SEP


LT$ + "topics"
RT$ + "Topics List -- Prints the list of all available help topics and instructions on how to access them."

STDOUT$ + TwoColumnsWrap(LT$, RT$, 10)

Return

; ******************************************************************************
; *                                TOPICS LIST                                 *
;{******************************************************************************
LIST_TOPICS:

STDOUT$ = #PAR_SEP + "ntc -h=<topic>" + #BLOCK_SEP
STDOUT$ + Heading("Help Topics")

STDOUT$ + TextWrap("Help topics provide additional information on subjects related to ntc and its usage. "+
                   "These are the available topics:") + #PAR_SEP
Gosub SHARED_TOPICS ; RETIVE LIST OF TOPICS (SHARED WITH "HELP")

Goto WRAP_UP ;}



; ******************************************************************************
; *                                  DELTA E                                   *
;{******************************************************************************
DELTA_E:

STDOUT$ = #PAR_SEP + Heading("About Delta E")
STDOUT$ + TextWrap(~"Delta E (dE) is a metric for measuring the change in visual perception of two "+
                   "given colors, ie: for understanding how the human eye perceives color difference. " + 
                   "It's commonly employed in computing for determining if the difference (distance) between two colors "+
                   "falls within an acceptable range. As a guideline, the following dE value ranges constitute "+
                   "a good reference to work with dE color difference:") + #PAR_SEP

STDOUT$ + CenterTextBlock(~".====================================================.\n"+
                          ~"|  Delta E  |            Perception                  |\n"+
                          ~"|----------------------------------------------------|\n"+
                          ~"| <= 1.0    | Not perceptible by human eyes.         |\n"+
                          ~"|    1 - 2  | Perceptible through close observation. |\n"+
                          ~"|    2 - 10 | Perceptible at a glance.               |\n"+
                          ~"|   11 - 49 | Colors are more similar than opposite. |\n"+
                          ~"|  100      | Colors are exact opposite.             |\n"+
                          ~"|----------------------------------------------------|\n"+
                          ~"| taken from Z.Schuessler:                           |\n"+
                          ~"| -- http://zschuessler.github.io/DeltaE/learn/      |\n"+
                          ~"`===================================================='") + #PAR_SEP

STDOUT$ + TextWrap("In 1976 the International Commission on Illumination (CIE) addressed the issue of color difference, "+
                   "introducing the concept of Delta E. Along the years, it came up with a number of increasingly more "+
                   ~"efficient formulas (or algorithms) to calculate Delta E:\n  -- dE76 (1976)\n  -- dE94 (1994)\n  -- dE00 (2001)") + #PAR_SEP
STDOUT$ + TextWrap(~"ntc uses the CIEDE2000 algorithm (aka \"Delta E 2000\" or \"dE00\") to measure color difference. When you look up a "+
                   "color with ntc, it runs it against its inner table of colors name/value pairs. "+
                   "If an exact color match is found, that color will be returned; otherwise the nearest dE match "+
                   "will be returned. This means that ntc calculates the dE distance between the target color and "+
                   "every color in its list, returning the one with the smallest dE distance (or an exact match, if "+
                   "one was found).") + #PAR_SEP
STDOUT$ + TextWrap("Although the list of color names contains " + #TOTAL_NTC_COLORS + " colors, some matches might "+
                   "have a dE value outside the range of what you might consider an acceptable color similarity. " +
                   "For this reason, you should consider using the `-de=<dE_Max>` option to narrow the range of "+
                   "accepted matches to a value that suits your needs or tastes. Beware that by setting a dE_Max roof value, "+
                   "not every ntc lookup will grant a result!")
Goto WRAP_UP ;}

;} HELP TOPICS <<<······························································
;} HELP / INFO <<<······························································


; ··············································································
; ······························· ERROR REPORTS ································
;{··············································································
; ******************************************************************************
; *                       MALFORMED HEX COLOR DEFINITION                       *
;{******************************************************************************
BAD_HEX_COLOR:

ExitCode = #Failure

STDERR$ = ErrorMsg("Malformed Hex color: " + currParam)
STDERR$ + ~"Color definitions in hexadecimal format must be in the form \"#FFFFFF\":\n"
STDERR$ + ~" -- suffixed by a pund symbol (\"#\")\n"
STDERR$ + ~" -- followed by 3 or 6 hex digits in the range 0-F"

Goto WRAP_UP ;}

; ******************************************************************************
; *                       MALFORMED RGB COLOR DEFINITION                       *
;{******************************************************************************

BAD_RGB_COLOR:

ExitCode = #Failure

STDERR$ = ErrorMsg("Malformed RGB color: " + currParam)
STDERR$ + ~"Color definitions in RGB format must be in the form \"255,255,255\":\n"
STDERR$ + ~" -- three comma-separated numeric values ranging 0-255\n"
STDERR$ + ~" -- definition mustn't contain whitespaces"

Goto WRAP_UP ;}

; ******************************************************************************
; *                              NO COLOR DEFINED                              *
;{******************************************************************************
NO_COLOR:

ExitCode = #Failure

STDERR$ = ErrorMsg("No color defined!")
STDERR$ + "You must define a target color to lookup."

Goto WRAP_UP ;}

; ******************************************************************************
; *                               BAD PARAMETER                                *
;{******************************************************************************
BAD_PARAM:

ExitCode = #Failure

STDERR$ = ErrorMsg("Unknown parameter: " + currParam)

STDERR$ + ~"Type \"ntc -h\" for a full list of valid options and their arguments."

Goto WRAP_UP ;}

; ******************************************************************************
; *                                 BAD OPTION                                 *
;{******************************************************************************
BAD_OPTION:

ExitCode = #Failure

STDERR$ = ErrorMsg("Unknown option: -" + option$)

STDERR$ + ~"Type \"ntc -h\" for a full list of valid options."

Goto WRAP_UP ;}

; ******************************************************************************
; *                              TOO MANY COLORS                               *
;{******************************************************************************
TOO_MANY_COLS:

ExitCode = #Failure

STDERR$ = ErrorMsg("Too many colors: " + currParam)
STDERR$ + ~"You can only pass one color at the time."

Goto WRAP_UP ;}

; ******************************************************************************
; *                            BAD FLOAT FOR MAX_DE                            *
;{******************************************************************************
BAD_MAX_DE:

ExitCode = #Failure

STDERR$ = ErrorMsg("Invalid dE-Max specification: -de=" + optionval$)
STDERR$ + ~"Delta E max value must be a validly formatted float number:\n"
STDERR$ + ~" -- Positive, unsigned (no \"-\" or \"+\")\n"
STDERR$ + ~" -- In decimal or in scientific (exponent) format (\"e\" allowed)\n"
STDERR$ + ~" -- Decimal mark separator must be full stop symbol (\".\")\n"
STDERR$ + ~" -- Value greater than zero (>0)"

Goto WRAP_UP ;}

; ******************************************************************************
; *                             INVALID EOL VALUE                              *
;{******************************************************************************
BAD_EOL:

ExitCode = #Failure

STDERR$ = ErrorMsg("Invalid EOL specification: -eol=" + optionval$)
STDERR$ + ~"End-of-line value can be one of:\n"
STDERR$ + ~" -- \"LF\" (Line Feed = \"\\n\" = 0x0A)\n"
STDERR$ + ~" -- \"CR\" (Carriage Return = \"\\r\" = 0x0D)\n"
STDERR$ + ~" -- \"CRLF\" (CR+LF = \"\\r\\n\" = 0x0D0A):\n"
STDERR$ + TextWrap(~"If no EOL is specified for this option (ie: \"-eol\"), LF will be used by default.")

Goto WRAP_UP ;}

; ******************************************************************************
; *                           INVALID TOPIC REQUEST                            *
;{******************************************************************************

BAD_TOPIC:

ExitCode = #Failure

STDERR$ = ErrorMsg("Invalid help topic: " + optionval$)
STDERR$ + TextWrap(~"The topic requested doesn't exist, or you made a typing mistake. The available topics are:") + #PAR_SEP

Gosub SHARED_TOPICS
STDERR$ + STDOUT$ ; SHARED_TOPICS returns them in STDOUT$!
STDOUT$ = #Null$

Goto WRAP_UP ;}

;} ERR.REPORTS <<<······························································
