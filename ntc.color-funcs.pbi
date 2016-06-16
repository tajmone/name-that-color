; ··············································································
; ··············································································
; ···························· ntc.color-funcs.pbi ·····························
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
;}··············································································

Rounding = #False ; if #True, RGB2Lab() will round L*a*b* values to nearest integer

; ******************************************************************************
; *                   `.col` - Color Structure (RGB/L*a*b*)                    *
;{******************************************************************************
; Objects of this type hold colors in RGB and CIE L*a*b* format, plus the color
; name. They are used to pass around color related procedures:
; -- GetRGB()
; -- RGB2Lab()
; -- dE00()
Structure col
  Name.s
  ; ==================================== RGB =====================================
  R.a         ; range: 0-255
  G.a         ; range: 0-255
  B.a         ; range: 0-255
  
  ; ============================ CIELAB / CIE L*a*b* =============================
  CIELAB_L.d  ; range: 0-100
  CIELAB_a.d  ; range: -128 to +127 (256 levels)
  CIELAB_b.d  ; range: -128 to +127 (256 levels)
EndStructure  ;}

; ******************************************************************************
; *                      `ntcQueryObj` - NTC Query Object                      *
;{******************************************************************************
; Objects of this type are used for querying NTC searches. They are passed by
; reference to lookup procedures, and will store query results.
Structure ntcQueryObj
  ; Fields/Values which need to be manually set before a query:
  TargetColor.s   ; hex color value of color to lookup in NTC search (set by user)
                  ; Fields/Values which are used by lookup procedure to store query results:
  MatchedColor.s  ; hex color of nearest match found
  Name.s          ; Color name of neatest match found
  DeltaE.d        ; dE00 diff-val between queried and matched colors
EndStructure      ;}

; ******************************************************************************
; *                                   GetRGB                                   *
; ******************************************************************************
Procedure GetRGB(*Color.col, HexValue$)
  *Color\R = Val("$" + Left(HexValue$, 2))
  *Color\G = Val("$" + Mid(HexValue$, 3, 2))
  *Color\B = Val("$" + Right(HexValue$, 2))
EndProcedure

; ******************************************************************************
; *                                  RGB2Lab                                   *
; ******************************************************************************
Procedure RGB2Lab(*Color.col, Rounding = #False)
  ; This procedure was built on an adaptation of Kevin Kwok’s `rgb2lab()` function
  ; taken from:
  ; -- “RGB-LAB” (JavaScript)
  ; -- https://github.com/antimatter15/rgb-lab
  ; ------------------------------------------------------------------------------
  Protected.d R, G, B, X, Y, Z
  R = *Color\R / 255
  G = *Color\G / 255
  B = *Color\B / 255
  ; ==============================================================================
  ;                                 RGB —> CIE-XYZ                                
  ; ==============================================================================
  ; Ref: http://www.easyrgb.com/index.php?X=MATH&H=02#text2
  If R > 0.04045
    R = Pow((r + 0.055) / 1.055, 2.4)
  Else
    R / 12.92
  EndIf
  If G > 0.04045
    G = Pow((G + 0.055) / 1.055, 2.4) 
  Else
    G / 12.92
  EndIf 
  If B > 0.04045
    B = Pow((b + 0.055) / 1.055, 2.4)
  Else
    B / 12.92
  EndIf
  ; Observer. = 2°, Illuminant = D65
  X = (R * 0.4124 + G * 0.3576 + B * 0.1805) / 0.95047  ; // ref_X =  95.047
  Y = (R * 0.2126 + G * 0.7152 + B * 0.0722) / 1.00000  ; // ref_Y = 100.000
  Z = (R * 0.0193 + G * 0.1192 + B * 0.9505) / 1.08883  ; // ref_Z = 108.883
  
  ; NOTE: Kevin Kwok cleverly optimized XYZ->Lab conversion in the previous lines.
  ;       If you look at the referenced links for the independent formulas proposed
  ;       at EasyRGB.com, you'll see that Kwok’s code spares a few passages.
  ; ==============================================================================
  ;                             CIE-XYZ —> CIE-L*a*b*                             
  ; ==============================================================================
  ; Ref: http://www.easyrgb.com/index.php?X=MATH&H=07#text7
  If X > 0.008856
    X = Pow(X, 1/3)
  Else
    X = (7.787 * X) + 16/116
  EndIf
  If Y > 0.008856
    Y = Pow(Y, 1/3)
  Else
    Y = (7.787 * Y) + 16/116
  EndIf
  If Z > 0.008856
    Z = Pow(Z, 1/3)
  Else
    Z = (7.787 * Z) + 16/116
  EndIf
  ; ------------------------------------------------------------------------------
  ;                               Rounding results?                               
  ; ------------------------------------------------------------------------------
  ; If procedure was invoked with `Rounding` parameter (optional) set to true, L*a*b*
  ; values will be rounded to the nearest integer number.
  If Rounding ; === TEST ROUNDING ===
    *Color\CIELAB_L = Round((116 * Y) - 16, #PB_Round_Nearest)
    *Color\CIELAB_a = Round(500 * (X - Y),  #PB_Round_Nearest)
    *Color\CIELAB_b = Round(200 * (Y - Z),  #PB_Round_Nearest)
  Else
    *Color\CIELAB_L = (116 * Y) - 16
    *Color\CIELAB_a = 500 * (X - Y)
    *Color\CIELAB_b = 200 * (Y - Z)
  EndIf
EndProcedure

; ******************************************************************************
; *                           `dE00()` — CIE DE2000                            *
; ******************************************************************************
Procedure.d dE00(*Color1.col, *Color2.col)
  ; NAME:        double dE00(pointer to Color1, pointer to Color2)
  ; VERSION:     1.0 (2016/05/13) by Tristano Ajmone.
  ; PB-VERSION:  PureBASIC 5.42
  ; DESCRIPTION: Computes the measure of change in visual perception of two given
  ;              L*a*b* colors according to CIEDE2000 (ΔE*00) algorytm.
  ; ACCEPTS:     Two pointers to `col` structures (color objects), each containing
  ;              the L*a*b* values (either int, float or double -- double being 
  ;              the preferred type). No changes are done to the `col` structures.
  ; RETURNS:     `deltaE00`, a double-precision (64-bit) measurement (range 0-100)
  ;              of how the human eye perceives the difference of the two colors
  ;              passed to the procedure. As a guideline, `deltaE00` can be read:
  ;                        +-----------+----------------------------------------+
  ;                        |  Delta E  |               Perception               |
  ;                        +-----------+----------------------------------------+
  ;                        | <= 1.0    | Not perceptible by human eyes.         |
  ;                        |    1 - 2  | Perceptible through close observation. |
  ;                        |    2 - 10 | Perceptible at a glance.               |
  ;                        |   11 - 49 | Colors are more similar than opposite. |
  ;                        |  100      | Colors are exact opposite.             |
  ;                        +-----------+----------------------------------------+
  ;       [ taken from Z.Schuessler: http://zschuessler.github.io/DeltaE/learn/ ]
  ; NOTES: No sanitation checks are carried out on the color objects passed to
  ;     the Procedure -- they are expected To contain correct L*a*b* values.
  ;     In Case of out-of-range Lab values, the Procedure will be computing and
  ;     returning a wrong dE00 value, without warnings: it's up to the caller to 
  ;     make sure that the referenced color objects are properly defined.
  ;     In case of null or mismatching L*a*b* data, the function might crash or
  ;     misbehave without warnings nor error throwbacks!
  ; ==============================================================================
  ; This procedure is an adaptation of @renasboy’s `color_difference` class:
  ; -- “php-color-difference” (PHP)
  ; -- https://github.com/renasboy/php-color-difference
  ; Variables have been renamed according to Schuessler’s `dE00.js` for easier
  ; code readability.
  ; ------------------------------------------------------------------------------
  ; For insights into the code workings, I’ve been relying on Zachary Schuessler’s
  ; well commented `dE00.js` JavaScript implementation, and his informative
  ; website dedicated to Delta E Color Difference Algorithms:
  ; -- https://github.com/zschuessler/DeltaE
  ; -- http://zschuessler.github.io/DeltaE/learn/
  ; ------------------------------------------------------------------------------
  ; For testing accuracy of results, I’ve used these online calculators:
  ; -- http://colormine.org/delta-e-calculator/cie2000
  ; -- http://www.boscarol.com/DeltaE.html
  ; ------------------------------------------------------------------------------
  Protected.d Lab1_L, Lab1_a, Lab1_b, Lab2_L, Lab2_a, Lab2_b
  Protected.d LBar, deltaLPrime, aPrime1, aPrime2 
  Protected.d C1, C2, CPrime1, CPrime2, CBar, CBarPrime, deltaCPrime
  Protected.d hPrime1, hPrime2, HBarPrime, deltahPrime
  Protected.d SsubL, SsubC, SsubH, RsubC, RsubT
  Protected.d g, T, deltaRO, deltaE00
  Protected.d kL, kC, kH
  
  Lab1_L = *Color1\CIELAB_L
  Lab1_a = *Color1\CIELAB_a
  Lab1_b = *Color1\CIELAB_b
  Lab2_L = *Color2\CIELAB_L
  Lab2_a = *Color2\CIELAB_a
  Lab2_b = *Color2\CIELAB_b
  
  LBar      = (Lab1_L + Lab2_L) / 2                             ; L Bar       (L¯)
  C1        = Sqr(Pow(Lab1_a, 2) + Pow(Lab1_b, 2))              ; C1
  C2        = Sqr(Pow(Lab2_a, 2) + Pow(Lab2_b, 2))              ; C2
  CBar      = (C1 + C2) / 2                                     ; C Bar
  g         = (1 - Sqr(Pow(CBar, 7) / (Pow(CBar, 7) + Pow(25, 7)))) / 2
  aPrime1   = Lab1_a * (1 + g)                                  ; a Prime 1   (a′1)
  aPrime2   = Lab2_a * (1 + g)                                  ; a Prime 2   (a′2)
  CPrime1   = Sqr(Pow(aPrime1, 2) + Pow(Lab1_b, 2))             ; C Prime 1   (C′1)
  CPrime2   = Sqr(Pow(aPrime2, 2) + Pow(Lab2_b, 2))             ; C Prime 2   (C′2)
  CBarPrime = (CPrime1 + CPrime2) / 2                           ; C Bar Prime (C¯′)
  
  ; ------------------------------------------------------------------------------
  ;                                h Prime 1 (h′1)                                
  ; ------------------------------------------------------------------------------
  hPrime1 = Degree(ATan2(aPrime1, Lab1_b))
  If (hPrime1 < 0)
    hPrime1 + 360
  EndIf
  ; ------------------------------------------------------------------------------
  ;                                h Prime 2 (h′2)                                
  ; ------------------------------------------------------------------------------
  hPrime2 = Degree(ATan2(aPrime2, Lab2_b))
  If (hPrime2 < 0) 
    hPrime2 + 360
  EndIf 
  ; ------------------------------------------------------------------------------
  ;                               H Bar Prime (H¯′)                               
  ; ------------------------------------------------------------------------------
  If  Abs(hPrime1 - hPrime2) > 180
    HBarPrime = (hPrime1 + hPrime2 + 360) / 2
  Else
    HBarPrime = (hPrime1 + hPrime2) / 2
  EndIf
  ; ------------------------------------------------------------------------------
  T = 1 - 0.17 * Cos(Radian(HBarPrime - 30)) + 0.24 * Cos(Radian(2 * HBarPrime)) + 0.32 * Cos(Radian(3 * HBarPrime + 6)) - 0.2 * Cos(Radian(4 * HBarPrime - 63))
  ; ------------------------------------------------------------------------------
  ;                              Delta h Prime (Δh′)                              
  ; ------------------------------------------------------------------------------
  deltahPrime = hPrime2 - hPrime1 
  If (Abs(deltahPrime) > 180)
    If (hPrime2 <= hPrime1) 
      deltahPrime + 360
    Else 
      deltahPrime - 360
    EndIf
  EndIf
  ; ------------------------------------------------------------------------------ 
  deltaLPrime = Lab2_L - Lab1_L                                           ; Delta L Prime (ΔL′)
  deltaCPrime = CPrime2 - CPrime1                                         ; Delta C Prime (ΔC′) 
  deltahPrime = 2 * Sqr(CPrime1 * CPrime2) * Sin(Radian(deltahPrime) / 2) ; Delta H Prime (ΔH′)
  SsubL = 1 + ((0.015 * Pow(LBar - 50, 2)) / Sqr(20 + Pow(LBar - 50, 2))) ; S sub L (SL)
  SsubC = 1 + 0.045 * CBarPrime                                           ; S sub C (SC)
  SsubH = 1 + 0.015 * CBarPrime * T                                       ; S sub H (SH)
  
  ; ------------------------------------------------------------------------------
  ;                                  R sub T (RT)                                 
  ; ------------------------------------------------------------------------------
  deltaRO = 30 * Exp(-(Pow((HBarPrime - 275) / 25, 2)))                   ; (Δθ) 
  RsubC = 2 * Sqr(Pow(CBarPrime, 7) / (Pow(CBarPrime, 7) + Pow(25, 7)))   ; R sub C (RC)
  RsubT = -RsubC * Sin(2 * Radian(deltaRO))                               ; R sub T (RT)
  
  ; ------------------------------------------------------------------------------
  ;                             weights configuration                             
  ; ------------------------------------------------------------------------------
  kL = 1.0    ; A weight factor to apply to lightness.
  kC = 1.0    ; A weight factor to apply to chroma.
  kH = 1.0    ; A weight factor to apply to hue.  
  
  ; ------------------------------------------------------------------------------
  ;                              Delta E 2000 (ΔE*00)                             
  ; ------------------------------------------------------------------------------
  deltaE00 = Sqr(Pow(deltaLPrime / (SsubL * kL), 2) + Pow(deltaCPrime / (SsubC * kC), 2) + Pow(deltahPrime / (SsubH * kH), 2) + RsubT * (deltaCPrime / (SsubC * kC)) * (deltahPrime / (SsubH * kH)))
  ProcedureReturn deltaE00
EndProcedure

; ******************************************************************************
; *        `SearchColorName()` - Lookup a Color in NTC Color Names List        *
; ******************************************************************************
Procedure.i SearchColorName(*PlaceHolder.ntcQueryObj)
  ; NAME:        bool SearchColorName(pointer to NTC Query Object)
  ; VERSION:     1.0 (2016/05/14) by Tristano Ajmone.
  ; PB-VERSION:  PureBASIC 5.42
  ; DESCRIPTION: Looks up a Target Color in the NTC Color Names List for the closest
  ;              matching color by means of dE00. Query results are handed back
  ;              by modifying the `ntcQueryObj` object passed to the Procedure.
  ; ACCEPTS:     A pointer to an NTC Query Object: its `\TargetColor` field will
  ;              be used as the color value to lookup in the query; its other 
  ;              fields will be used as a means to pass back query results.
  ; RETURNS:     boolean int (`#True`/`#False`) to indicate if the query found an
  ;              identical matching color (True) or an approximately similar one
  ;              (false).  
  ; NOTES:       -- NTC() must be already present as Global Map
  ;              -- In case of an identical match, NTC Query Object's `\DeltaE`
  ;                 field will be set to `-1`. In all other cases dE value will
  ;                 range 0-100.
  ;              -- Identical matches are established by comparing hex values of
  ;                 target color and NTC List entries -- thus bypassing Delta E
  ;                 evaluation. Therefore, don't ever expect a dE of `0` value--
  ;                 identical matches will always report a dE of `-1`; any approx.
  ;                 match will be dE>0.
  ; ------------------------------------------------------------------------------
  Protected       TargetColor$, Comparison$
  Protected.col   Color1, Color2
  Protected.d     curr_dE, dE00_result
  ; ------------------------------------------------------------------------------
  ;                               Setup Target Color                              
  ; ------------------------------------------------------------------------------
  TargetColor$ = *PlaceHolder\TargetColor
  GetRGB(@Color1, TargetColor$)
  RGB2Lab(@Color1, Rounding)
  ; ------------------------------------------------------------------------------
  ;                               Setup work vars...                              
  ; ------------------------------------------------------------------------------
  ResetMap(NTC())
  curr_dE = -1
  i = 1
  While NextMapElement(NTC())
    GetRGB(@Color2, MapKey(NTC()))
    RGB2Lab(@Color2, Rounding)
    Comparison$ = MapKey(NTC())
    If TargetColor$ = Comparison$ ; Target color and current NTC List color are identical
      
      ; ------------------------------------------------------------------------------
      ;                            Found and exact match...                           
      ; ------------------------------------------------------------------------------
      *PlaceHolder\MatchedColor = Comparison$   ; Store match hex color-value
      *PlaceHolder\Name = NTC()                 ; Store match color name
      *PlaceHolder\DeltaE = -1                  ; Set Delta-E to negative (ie: exact match = no dE distance)
      ProcedureReturn #True                     ; Exit query procedure, returning `True` (exact match)
    Else
      ; ------------------------------------------------------------------------------
      ;                                Colors differ...                               
      ; ------------------------------------------------------------------------------
      dE00_result = dE00(@Color1, @Color2) ; Calculate Delta-E of Target and current NTC List color
      If curr_dE <0 Or curr_dE > dE00_result
        ; ------------------------------------------------------------------------------
        ;           Current NTC List color is nearer than previous finding...           
        ; ------------------------------------------------------------------------------
        ; Set curr NTC List color as best match found so far...
        curr_dE = dE00_result                     ; Current dE is best similarity value found
        *PlaceHolder\MatchedColor = Comparison$   ; Store match hex color-value
        *PlaceHolder\Name = NTC()                 ; Store match color name
        *PlaceHolder\DeltaE = dE00_result         ; Store match dE00 value
      EndIf
    EndIf
    i + 1
  Wend
  ProcedureReturn #False ; Exit query procedure, returning `False` (approximate match)
EndProcedure  





