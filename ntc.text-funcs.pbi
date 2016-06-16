; ··············································································
; ··············································································
; ····························· ntc.text-funcs.pbi ·····························
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
; This module contains procedures for formatting and wrapping text for console
; output.
;}··············································································

; ··············································································
; ······················· PUBLIC PROCEDURES & CONSTANTS ························
; ··············································································
DeclareModule TextFuncs
  #BLOCK_SEP = ~"\n\n"
  #PAR_SEP = ~"\n"
  Declare.s TextWrap(txt$, lineWidth.i =80)
  Declare.s TwoColumnsWrap(left$, right$, leftWidth.i = -1, lineWidth.i = 80, colSep$ = " ")
  Declare.s Heading(txt$, lev =1)
  Declare.s BulletList(txt$, bullet$ = "*", lineWidth.i =80)
  Declare.s CenterTextBlock(txt$, lineWidth.i =80, padFill$ = " ")
  Declare.s ErrorMsg(txt$)
EndDeclareModule

Module TextFuncs
  ; ··············································································
  ; ·························· PRIVATE PROCEDURES DECL. ··························
  ; ··············································································
  #SPACE$ = " "
  Declare Max(A, B)
  ; ******************************************************************************
  ; *                              PRIVATE :: Max()                              *
  ; ******************************************************************************
  Procedure Max(A, B)
    If A > B
      ProcedureReturn A
    Else
      ProcedureReturn B
    EndIf
  EndProcedure
  ; ******************************************************************************
  ; *                       PRIVATE :: FindWrapPosition()                        *
  ; ******************************************************************************
  Procedure.i FindWrapPosition(txt$, linePos.i)
    ; Finds Right-Most Wrappable Position on left-side of string. Ie: scans string
    ; from `start + max line width`, moving backwards one char at the time; stops
    ; at first whitespace found and returns its position.
    ; ············································································
    ; linePos starts as lineWidth (max position allowed)
    While Mid(txt$, linePos, 1) <> #SPACE$ And Len(txt$) > linePos And linePos > 0
      linePos-1
    Wend
    If linePos > 0
      ProcedureReturn linePos
    Else
      ProcedureReturn Len(Trim(txt$))
    EndIf
  EndProcedure
  ; ******************************************************************************
  ; *                         PRIVATE :: WrapParagraph()                         *
  ; ******************************************************************************
  Procedure.s WrapParagraph(paragraph$, lineWidth.i)
    If Len(paragraph$)
      wPos = FindWrapPosition(paragraph$, lineWidth)
      result_ahead$ + WrapParagraph(LTrim(Right(paragraph$, Len(paragraph$)-wPos)), lineWidth)
      If result_ahead$
        ; paragraph$ is not last line: pad it with spaces up to lineWidth
        result$ + LSet(Mid(paragraph$, 1, wPos), lineWidth) + #PAR_SEP
        result$ + result_ahead$
      Else
        ; self-recursion returned nothing: paragraph$ is last line, don't pad.
        result$ + RTrim(paragraph$) + #PAR_SEP
      EndIf
      ProcedureReturn result$
    EndIf
  EndProcedure
  ; ******************************************************************************
  ; *                          PRIVATE :: LongestWord()                          *
  ; ******************************************************************************
  Procedure.i LongestWord(txt$)
    ; Parse a text and return Len of its longest word.
    ; ············································································
    For i=1 To CountString(txt$, #SPACE$)+1
      word$ = LTrim(StringField(txt$, i, #SPACE$))
      wordLen = Len(word$)
      If wordLen > longestMatch
        longestMatch = wordLen
      EndIf    
    Next
    ProcedureReturn longestMatch
  EndProcedure
  
  ; ******************************************************************************
  ; *                            PUBLIC :: TextWrap()                            *
  ; ******************************************************************************
  Procedure.s TextWrap(txt$, lineWidth.i =80)
    ; ============================= Check Longest Word =============================   
    minLen = LongestWord(ReplaceString(txt$, #PAR_SEP, #SPACE$)) ; LongestWord() sees only space as separator: convert LF to space.
    If lineWidth < minLen
      lineWidth = minLen
    EndIf
    ; ============================== Multiline Check ===============================
    lineBreaks = CountString(txt$, #PAR_SEP)
    i = 1
    Repeat
      paragraph$ = StringField(txt$, i, #PAR_SEP)
      result$ + WrapParagraph(paragraph$,lineWidth)
      i +1
    Until i > lineBreaks +1
    ProcedureReturn result$
  EndProcedure
  ; ******************************************************************************
  ; *                         PUBLIC :: TwoColumnsWrap()                         *
  ; ******************************************************************************
  Procedure.s TwoColumnsWrap(left$, right$, leftWidth.i = -1, lineWidth.i = 80, colSep$ = " ")
    ; Works like a 2 Columns Table where Raws are separated by "\n\n".
    ; Each "cell" can have any number of paragraphs split by "\n".
    ; Left and Right column might have different number of raws -- they will be
    ; filled with empty space. Also, each cell might have different num of paragraphs.
    ; ===================== (-1) Auto-Calculate Left Col Width =====================
    If leftWidth = -1
      lineBreaks = CountString(left$, #PAR_SEP) +1
      i = 1
      Repeat
        currLen = Len(StringField(left$, i, #PAR_SEP))
        If currLen > leftWidth
          leftWidth = currLen
        EndIf
        i +1
      Until i > lineBreaks
    EndIf
    ; ======================= Check Longest Word on Left Col =======================
    minLen = LongestWord(ReplaceString(left$, #PAR_SEP, #SPACE$)) ; LongestWord() sees only space as separator: convert LF to space.
    If leftWidth < minLen
      leftWidth = minLen 
    EndIf                                                  
    ; ========================= Calculate Right Col Width ==========================
    colSepLen = Len(colSep$)
    rightWidth = lineWidth - leftWidth - colSepLen
    ; ============================== Multi Raws Check ==============================
    ; In case one column has more raws than the other...
    leftRaws  = CountString(left$,  #BLOCK_SEP) +1
    rightRaws = CountString(right$, #BLOCK_SEP) +1
    maxRaws = Max(leftRaws, rightRaws)
    i = 1
    Repeat
      leftRaw$ = StringField(left$, i, #BLOCK_SEP)
      rightRaw$ = StringField(right$, i, #BLOCK_SEP)
      ; ============================ Left Multiline Check ============================
      resultsLeft$ = #Empty$
      lineBreaks  = CountString(leftRaw$, #PAR_SEP) +1
      j = 1
      Repeat
        leftParag$ = StringField(leftRaw$, j, #PAR_SEP)
        resultsLeft$  + WrapParagraph(leftParag$,leftWidth)
        j +1
      Until j > lineBreaks
      ; =========================== Right Multiline Check ============================
      resultsRight$ = #Empty$
      lineBreaks = CountString(rightRaw$, #PAR_SEP) +1
      j = 1
      Repeat
        rightParag$ = StringField(rightRaw$, j, #PAR_SEP)
        resultsRight$ + WrapParagraph(rightParag$,rightWidth)
        j +1
      Until j > lineBreaks      
      ; =========================== Join Raws Horizontally ===========================
      leftLines  = CountString(resultsLeft$,  #PAR_SEP) +1
      rightLines = CountString(resultsRight$, #PAR_SEP) +1
      maxLines = Max(leftLines, rightLines)
      j = 1
      Repeat
        leftLine$  = StringField(resultsLeft$, j, #PAR_SEP)
        rightLine$ = StringField(resultsRight$,  j, #PAR_SEP)
        joined$ = LSet(leftLine$, leftWidth) + colSep$ + LSet(rightLine$, rightWidth) + #PAR_SEP
        result$ + joined$
        j +1
      Until j >= maxLines ; because wrapped text always ends with "\n"!
      
      ; ==============================================================================
      i +1
    Until i > maxRaws
    ProcedureReturn result$
  EndProcedure
  
  ; ******************************************************************************
  ; *                            PUBLIC :: Heading()                             *
  ; ******************************************************************************
  Procedure.s Heading(txt$, lev =1)
    Select lev
      Case 1
        under$ = "="
      Default
        under$ = "-"
    EndSelect
    txtLen = Len(txt$)
    txt$ + #PAR_SEP + LSet("", txtLen, under$) + #PAR_SEP
    ProcedureReturn txt$
  EndProcedure
  ; ******************************************************************************
  ; *                           PUBLIC :: BulletList()                           *
  ; ******************************************************************************
  Procedure.s BulletList(txt$, bullet$ = "*", lineWidth.i =80)
    leftWidth = Len(bullet$)
    elemWidth = lineWidth - leftWidth
    ; ============================= Check Longest Word =============================   
    minLen=LongestWord(ReplaceString(txt$, #PAR_SEP, #SPACE$)) ; LongestWord() sees only space as separator: convert LF to space.
    If elemWidth < minLen
      elemWidth = minLen
    EndIf
    ; ============================ Multi Elements Check ============================
    elems = CountString(txt$,  #BLOCK_SEP) +1
    i = 1
    Repeat
      elem$ = StringField(txt$, i, #BLOCK_SEP)
      ; ============================== Multiline Check ===============================
      unbulleted$ = #Empty$
      lineBreaks  = CountString(elem$, #PAR_SEP) +1
      j = 1
      Repeat
        rawParag$ = StringField(elem$, j, #PAR_SEP)
        unbulleted$ + WrapParagraph(rawParag$,elemWidth)
        j +1
      Until j > lineBreaks
      ; ================================= add bullet =================================
      lineBreaks  = CountString(unbulleted$, #PAR_SEP) +1
      j = 1
      Repeat
        If j = 1
          leftSide$ = bullet$
        Else
          leftSide$ = Space(leftWidth)
        EndIf
        rightSide$ = StringField(unbulleted$, j, #PAR_SEP)
        joined$ = leftSide$ + LSet(rightSide$, elemWidth) + #PAR_SEP
        result$ + joined$
        j +1
      Until j >= lineBreaks ; because wrapped text always ends with "\n"!
      
      ; ==============================================================================
      i +1
    Until i > elems
    ProcedureReturn result$    
  EndProcedure
  ; ******************************************************************************
  ; *                        PUBLIC :: CenterTextBlock()                         *
  ; ******************************************************************************
  Procedure.s CenterTextBlock(txt$, lineWidth.i =80, padFill$ = " ")
    ; takes a block of lines and centers it. Optionally, padding character can be
    ; specified (defaults to space). All empty space surrounding source lines in
    ; centered block will be filled with padding char, up to line-width.
    ; ============================ Measure Longest Line ============================
    lineNumbers  = CountString(txt$, #PAR_SEP) +1
    i = 1
    Repeat
      lineLen = Len(StringField(txt$, i, #PAR_SEP))
      If lineLen > MaxLen
        MaxLen = lineLen
      EndIf
      i +1
    Until i > lineNumbers
    freeSpace = lineWidth - MaxLen
    padLeft  = freeSpace/2
    padRight = padLeft + (freeSpace % 2)
    ; ================================= Pad Lines ==================================
    i = 1
    Repeat
      result$ + LSet("", padLeft, padFill$) +  LSet(StringField(txt$, i, #PAR_SEP), MaxLen + padRight, padFill$) + #PAR_SEP
      i +1
    Until i > lineNumbers
    ProcedureReturn result$    
  EndProcedure
  ; ******************************************************************************
  ; *                            PUBLIC :: ErrorMsg()                            *
  ; ******************************************************************************
  Procedure.s ErrorMsg(txt$)
    result$ = #PAR_SEP + "ERROR -- " + txt$ + #BLOCK_SEP
    ProcedureReturn result$
  EndProcedure
EndModule
