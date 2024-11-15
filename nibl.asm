            PAGE 0              ; suppress page headings in ASW listing file

;-----------------------------------------------------------------------------
;  NIBL.ASM - Tiny BASIC for the National Semiconductor SC/MP microprocessor 
;                    (NIBL-P, release date 12/17/76) 
;
; This file has been prepared via OCR and text editor from the original 
; assembly listing; then re-assembled and rigorously checked for errors. 
;
;The following differences exist from the original listing: 
;  - Many original local labels (mostly for short jumps) have been given 
;    new names to insure global uniqueness.
;  - Macros have been modified (or created) to allow compatibility with a 
;    modern, generic, macro-assembler.
;  - After being passed through the OCR process, neatness of the original 
;    text has suffered some cosmetic inconsistency.
;
;Of further note:
;  - The macro-assembler used here is a free tool, "AS", by Alfred Arnold:
;             http://john.ccac.rwth-aachen.de:8000/as/
;  - The cryptic syntax "./256" used as the operand of the instruction at 
;    address 0087 suggests that there may have been "hooks" incorporated 
;    for relocation of the NIBL interpreter code. An assembled operand value 
;    of zero has been retained as in the original. 
;  - On my original hardcopy listing, hand written notations indicate that the 
;    "OR HI(P2)" instructions at addresses 05D3 and 0936 were later changed
;    to "ANI 01". As I recall, this was a minor bug fix that may have been 
;    published in a National Semiconductor newsletter or in an issue of 
;    Dr. Dobb's Journal.
;
; A full assembly listing of this source file is also appended below.
; Enjoy!
; 
; Roger Marin, January 2008
; Portland, Oregon, USA. 
; ramarin(AT)teleport.com  
;
;-----------------------------------------------------------------------------
; 'GECO' and 'PUTC' functions modified for 2400 bps, 7-N-1 - 05/07/2021 jsl
;-----------------------------------------------------------------------------

          CPU SC/MP
          
L FUNCTION VAL16, (VAL16 & 0xFF)
H FUNCTION VAL16, ((VAL16 >> 8) & 0xFF)

JS   MACRO  P,VAL
       LDI    H(VAL-1)
       XPAH   P
       LDI    L(VAL-1)
       XPAL   P
       XPPC   P
     ENDM

LDPI MACRO  P,VAL
       LDI     H(VAL)
       XPAH    P
       LDI     L(VAL)
       XPAL    P
     ENDM

;*****************************************************
;*       WE ARE TIED DOWN TO A LANGUAGE WHICH        *
;*       MAKES  UP IN OBSCURITY WHAT IT LACKS        *
;*       IN  STYLE.                                  *
;*                     - TOM STOPPARD                *
;*                                                   *
;*****************************************************
 
TSTBIT   =        0x20            ;I. L. INSTRUCTION FLAGS
JMPBIT   =        0x40
CALBIT   =        0x80
P1       =        1               ;SC/MP POINTER ASSIGNMENTS
P2       =        2
P3       =        3

 
; DISPLACEMENTS FOR RAM VARIABLES USED BY INTERPRETER
DOPTR    =        -1              ;DO-STACK POINTER
FORPTR   =        -2              ;FOR-STACK POINTER
LSTK     =        -3              ;ARITHMETIC STACK POINTER
SBRPTR   =        -4              ;GOSUB STACK POINTER
PCLOW    =        -5              ;I. L. PROGRAM COUNTER
PCHIGH   =        -6
PCSTK    =        -7              ;I. L. CALL STACK POINTER
LOLINE   =        -8              ;CURRENT LINE NUMBER
HILINE   =        -9
PAGE     =        -10             ;VALUE OF CURRENT PAGE
LISTNG   =        -11             ;LISTING FLAG
RUNMOD   =        -12             ;RUN/EDIT FLAG
LABLLO   =        -13
LABLHI   =        -14
P1L0W    =        -15             ;SPACE TO SAVE CURSOR
P1HIGH   =        -16
LO       =        -17
HI       =        -18
FAILLO   =        -19
FAILHI   =        -20
NUM      =        -21
TEMP     =        -22
TEMP2    =        -23
TEMP3    =        -24
CHRNUM   =        -25
RNDF     =        -26
RNDX     =        -27             ; SEEDS FOR RANDOM NUMBER
RNDY     =        -28
 
; ALLOCATION  OF RAM FOR NIBL VARIABLES, STACKS,
; AND LINE BUFFER
VARS      =  0x1000 +28            ;NIBL VARIABLES A-Z
AESTK:    =  VARS   +52            ;ARITHMETIC STACK  
SBRSTK:   =  AESTK  +26            ;G0SUB STACK   
DOSTAK:   =  SBRSTK +16            ;DO/UNTIL  STACK   
FORSTK:   =  DOSTAK +16            ;FOR/NEXT  STACK    
PCSTAK:   =  FORSTK +28            ;I.L. CALL STACK    
LBUF:     =  PCSTAK +48            ;LINE BUFFER     
PGM:      =  LBUF   +74            ;USER'S PROGRAM            
     
;*************************************
;*      INITIALIZATION OF NIBL       *
;*************************************
          NOP
          LDPI    P2,VARS          ; POINT P2  AT VARIABLES
          LDPI    P1,PGM           ; POINT PI  AT PAGE ONE PROGRAM
          LDI     -1               ; STORE -1  AT START OF PROGRAM
          ST      0(P1)
          ST      1(P1)
          LDI     0x0D             ;ALSO  STORE  A DUMMY
          ST      -1(P1)           ;  CARRIAGE  RETURN
          LDI     2                ;POINT P2  AT PAGE 2,
          ST      PAGE(P2)         ; INITIALLY  SET PAGE TO  2
          XPAL    P1
          LDI     0x20
          XPAH    P1
          DLD     2(P1)            ; CHECK IF  THERE IS REALLY
          XAE                      ; A PROGRAM  IN PAGE 2:
          LD      E(P1)            ; IF FIRST LINE LENGTH
          XRI     0x0D             ; POINTS TO  CARR.  RETURN
          JZ      L000             ; AT END OF  LINE
          DLD     PAGE(P2)         ;IF NOT, PAGE = 1
L000:     LDI     0x20
LOOP1:    XPAH    P1
          LDI     -1               ; STORE -1  IN 2 CONSECUTIVE
          ST      (P1)             ; LOCATIONS  AT START OF PAGE
          ST      1(P1)
          LDI     0x0D             ; ALSO  PUT  A  DUMMY END-OF-LINE
          ST      -1(P1)           ; JUST BEFORE TEXT
          XPAH    P1               ; UPDATE P1 TO POINT TO
          CCL                      ; NEXT PAGE  (UNTIL PAGE=8)
          ADI     0x10             ; REPEAT INITIALIZATION
          XRI     0x80             ; FOR  PAGES  2-7
          JZ      L001
          XRI     0x80
          JMP     LOOP1
L001:     LDI     0                ; CLEAR SOME  FLAGS
          ST      RUNMOD(P2)
          ST      LISTNG(P2)
          LDI     L(BEGIN)         ; INITIALIZE  IL PC  SO  THAT
          ST      PCLOW(P2)        ; NIBL PROGRAM
          LDI     H(BEGIN)         ; IS EXECUTED IMMEDIATELY
          ST      PCHIGH(P2)
CLEAR:    LDI     0
          ST      TEMP(P2)
          XAE
CLEAR1:   LDI     0                ; SET ALL VARIABLES
          ST      E(P2)            ; TO ZERO
          ILD     TEMP(P2)
          XAE
          LDI     52
          XRE
          JNZ     CLEAR1
          LDI     L(AESTK)         ; INITIALIZE  SOME STACKS?
          ST      LSTK(P2)         ; ARITHMETIC STACK,
          LDI     L(DOSTAK)
          ST      DOPTR(P2)        ; DO/UNTIL STACK,
          LDI     L(SBRSTK)
          ST      SBRPTR(P2)       ; GOSUB STACK,
          LDI     L(PCSTAK)
          ST      PCSTK(P2)        ; I. L.  CALL  STACK,
          LDI     L(FORSTK)
          ST      FORPTR(P2)       ; FOR/NEXT STACK

;*************************************
;*   INTERMEDIATE LANGUAGE EXECUTOR  *
;*************************************
EXECIL:   LD      PCLOW(P2)        ;SET P3 TO CURRENT
          XPAL    P3               ; IL PC.
          LD      PCHIGH(P2)
          XPAH    P3
CHEAT:    LD      @1(P3)
          XAE                      ;GET NEW I.L. INSTRUCTION
          LD      @1(P3)           ; INTO P3 THROUGH
          XPAL    P3               ; OBSCURE METHODS
          ST      PCLOW(P2)        ;SIMULTANEOUSLY,  INCREMENT
          LDE                      ; THE  I.L.  PC BY 2
          ANI     0x0F             ;REMOVE FLAG FROM  INSTRUCTION
          ORI     0                ; TURN INTO  ACTUAL ADDRESS, (see note at top of file)
          XPAH    P3               ; PUT  BACK INTO P3
          ST      PCHIGH(P2)
          LDE
          ANI     0xF0             ; CHECK IF I.L.  INSTRUCTION
          XRI     TSTBIT           ; IS A 'TEST'
          JZ      TST
          XRI     CALBIT|TSTBIT    ;CHECK FOR I. L.  CALL
          JZ      ILCALL
          XRI     JMPBIT|CALBIT    ;CHECK FOR I.L.  JUMP
          JZ      CHEAT            ;l.L.  JUMP IS TRIVIAL
NOJUMP:   XPPC    P3               ;MUST BE AN ML SUBROUTINE
          JMP     EXECIL           ;  IF NONE OF THE ABOVE
 
;*************************************
;*     INTERMEDIATE LANGUAGE CALL    *
;*************************************
ILCALL:   LD      PCSTK(P2)
          XRI     L(LBUF)         ;CHECK FOR STACK OVERFLOW
          JNZ     ILC1
          LDI     10         
          JMP     EOA
ILC1:     XRI     L(LBUF)         ;RESTORE ACCUMULATOR
          XPAL    P3              ;SAVE LOW BYTE OF NEW
          ST      TEMP(P2)        ;  I.L.  PC IN TEMP
          LDI     H(PCSTAK)       ;POINT P3 AT I.L.
          XPAH    P3              ;  SUBROUTINE STACK
          XAE                     ;SAVE NEW I.L.  PC HIGH IN EX
          LD      PCLOW(P2)       ;SAVE OLD I.L.  PC ON STACK
          ST      @1(P3)
          LD      PCHIGH(P2)
          ST      @1(P3)
          LD      TEMP(P2)        ;GET LOW BYTE OF NEW
          XPAL    P3              ;  I.L.  PC INTO P3 LOW
          ST      PCSTK(P2)       ;UPDATE I.L.  STACK POINTER
          LDE                     ;GET HIGH BYTE OF NEW
          XPAH    P3              ;  I.L.  PC INTO P3 HIGH
CHEAT1:   JMP     CHEAT
 
;*************************************
;*     I.L.  'TEST' INSTRUCTION      *
;*************************************
TST:      ST      CHRNUM(P2)      ;CLEAR NUMBER OF CHARS SCANNED
SCAN:     LD      @1(P1)          ;SLEW OFF SPACES
          XRI     ' '
          JZ      SCAN
          LD      @-1(P1)         ;REPOSITION CURSOR
          LD      PCHIGH(P2)      ; POINT P3 AT I.L.  TABLE
          XPAH    P3
          ST      FAILHI(P2)      ;OLD P3 BECOMES THE
          LD      PCLOW(P2)       ;  TEST FAIL ADDRESS
          XPAL    P3
          ST      FAILLO(P2)
LOOP2:    LD      @1(P3)
          XAE                       ;SAVE CHAR FROM TABLE
          DLD      CHRNUM(P2)       ;DECREMENT CHAR COUNT
          LDE                       ;GET  CHAR  BACK
          ANI      0x7F             ;SCRUB  OFF FLAG (IF  ANY)
          XOR      @1(P1)           ;IS CHAR EQUAL  TO  TEXT  CHAR?
          JNZ      LNEQ             ;NO - END  TEST
          LDE                       ;YES - BUT IS  IT LAST CHAR?
          JP       LOOP2            ;IF NOT, CONTINUE  TO COMPARE
          JMP      CHEAT            ; IF SO, GET NEXT I. L.  
XO:       JMP      EXECIL           ;  INSTRUCTION
LNEQ:     LD       CHRNUM(P2)       ;RESTORE P1 TO
          XAE                       ;  ORIGINAL VALUE         
          LD       @E(P1)
          LD       FAILLO(P2)       ;LOAD TEST-FAIL ADDRESS
          XPAL     P3               ;  INTO  P3
          LD       FAILHI(P2)
          XPAH     P3
          JMP      CHEAT1           ;GET  NEXT  I. L. INSTRUCTION
 
;*************************************
;*        I.L.  SUBROUTINE RETURN    *
;*************************************
RTN:     LDI      H(PCSTAK)        ; POINT  P3  AT I.L.  PC STACK
         XPAH     P3
         LD       PCSTK(P2)
         XPAL     P3
         LD       @-1(P3)          ;GET  HIGH  PART  OF  OLD PC
         XAE
         LD       @-1(P3)          ;GET  LOW PART OF OLD PC
         XPAL     P3
         ST       PCSTK(P2)        ;UPDATE IL  STACK POINTER
         LDE
         XPAH     P3               ;P3 NOW HAS OLD  IL PC
         JMP      CHEAT1
EOA:     JMP      EO
 
;*************************************
;*     SAVE GOSUB RETURN ADDRESS     *
;*************************************
SAV:     LD      SBRPTR(P2)
         XRI     L(DOSTAK)       ;CHECK FOR  MORE
         JZ      SAV2            ;  THAN 8 SAVES
         ILD     SBRPTR(P2)
         ILD     SBRPTR(P2)
         XPAL    P3              ;SET  P3 TO
         LDI     H(SBRSTK)       ;  SUBROUTINE STACK TOP.
         XPAH    P3
         LD      RUNMOD(P2)      ;IF IMMEDIATE MODE,
         JZ      SAV1            ; SAVE NEGATIVE  ADDRESS.
         XPAH    P1              ;SAVE HIGH  PORTION
         ST      -1(P3)          ;  OF  CURSOR
         XPAH    P1
         XPAL    P1              ;SAVE LOW PORTION
         ST      -2(P3)          ;  OF CURSOR
         XPAL    P1
         JMP     XO              ; RETURN
SAV1:    LDI     -1              ; IMMEDIATE MODE
         ST      -1(P3)          ;  RETURN ADDRESS IS
         JMP     XO              ;  NEGATIVE.
SAV2:    LDI     10              ; ERROR: MORE THAN
         JMP     EO              ;  8 GOSUBS
 
;*************************************
;*     CHECK STATEMENT FINISHED      *                      
;*************************************
DONE:    LD      @1(P1)          ;SKIP SPACES  
         XRI     ' '
         JZ      DONE
         XRI     ' ' | 0x0D      ;IS IT CARRIAGE RETURN?
         JZ      DONE1           ;YES - RETURN
         XRI     0x37            ;IS CHAR A ':'?
         JNZ     DONE2           ;NO - ERROR
DONE1:   XPPC    P3              ;YES - RETURN
DONE2:   LDI     4
         JMP     EO
 
;*************************************
;         RETURN  FROM GOSUB         *
;*************************************
RSTR:    LD      SBRPTR(P2)
         XRI     L(SBRSTK)       ; CHECK FOR RETURN
         JNZ     RSTR1           ;  W/0 GOSUB
         LDI     9
EO:      JMP     El              ; REPORT THE ERROR
RSTR1:   DLD     SBRPTR(P2)
         DLD     SBRPTR(P2)      ;POP GOSUB STACK,
         XPAL    P3              ;  PUT PTR INTO P3
         LDI     H(SBRSTK)
         XPAH    P3
         LD      1(P3)           ;IF ADDRESS NEGATIVE,
         JP      RSTR2           ;  SUBROUTINE WAS CALLED
         LDI     0               ;  FROM EDIT MODE,
         ST      RUNMOD(P2)      ;  SO RETURN TO EDITING
XI:      JMP     XO
RSTR2:   XPAH    P1              ; RESTORE CURSOR HIGH
         LD      0(P3)
         XPAL    P1              ; RESTORE CURSOR LOW
         LDI     1               ;SET RUN MODE
         ST      RUNMOD(P2)
         JMP     XI
 
;*************************************
;*  TRANSFER  TO  NEW  STATEMENT     *
;*************************************
XFER:    LD       LABLHI(P2)      ;CHECK  FOR  NON-EXISTENT LINE
         JP       XFER1
         LDI      8
         JMP      El
XFER1:   LDI      1               ;SET  RUN  MODE  TO  1
         ST       RUNMOD(P2)
         XPPC     P3
 
;*************************************
;*    PRINT STRING IN  TEXT          *
;*************************************
PRS:     LDPI     P3,PUTC-1       ;POINT  P3 AT PUTC ROUTINE
         LD       @1(P1)          ;L0AD NEXT  CHAR
         XRI      '"'             ;IF  ",  END  OF
         JZ       XI              ;  STRING
         XRI      0x2F            ;IF CR, ERROR
         JZ       PRS1
         XRI      0x0D            ;RESTORE  CHAR
         XPPC     P3              ;PRINT  CHAR
         JMP      PRS             ;GET  NEXT CHAR
PRS1:    LDI      7               ;SYNTAX ERROR
El:      JMP      E2
 
;*************************************
;*      PRINT NUMBER ON  STACK       *
;*************************************
; THIS  ROUTINE IS BASED ON DENNIS ALLISON'S BINARY  TO  DECIMAL
; CONVERSION ROUTINE  IN VOL. 1, #1 OF "DR. DOBB'S JOURNAL",
; BUT IS MUCH MORE  OBSCURE BECAUSE OF THE STACK MANIPULATION.
PRN:      LDI      H(AESTK)        ; POINT  P3 AT A. E. STACK
          XPAH     P3
          ILD      LSTK(P2)
          ILD      LSTK(P2)
          XPAL     P3
          LDI      10              ;PUT  10 ON  STACK  (WE'LL BE
          ST       -2(P3)          ;  DIVIDING  BY  IT  LATER)
          LDI      0     
          ST       -1(P3)
          LDI      5               ;SET  CHRNUM TO POINT TO PLACE
          ST       CHRNUM(P2)      ;   IN  STACK  WHERE  WE STORE
          LDI      -1              ;   THE CHARACTERS  TO PRINT
          ST       5(P3)           ;FIRST  CHAR IS A  FLAG (-1)
          LD       -3(P3)          ;CHECK  IF NUMBER  IS NEGATIVE
          JP      LPNOS
          LDI     '-'             ;PUT '-' ON STACK,  AND NEGATE
          ST      4(P3)           ;  THE NUMBER
          LDI     0
          SCL
          CAD     -4(P3)
          ST      -4(P3)
          LDI     0
          CAD     -3(P3)
          ST      -3(P3)
          JMP     XI              ; GO DO DIVISION BY  10
LPNOS:    LDI     ' '             ;IF POSITIVE, PUT ' ' ON
          ST      4(P3)           ;  STACK BEFORE DIVISION
X4:       JMP     XI
E2:       JMP     ERR1
                                                               
;  THE DIVISION IS PERFORMED, THEN CONTROL  IS TRANSFERRED
;  TO PRN1, WHICH FOLLOWS.
PRN1:     ILD     LSTK(P2)        ; POINT P1  AT A. E.  STACK
          ILD     LSTK(P2)
          XPAL    P1
          LDI     H(AESTK)
          XPAH    P1
          ILD     CHRNUM(P2)      ;INCREMENT CHARACTER STACK
          XAE                     ;  POINTER,  PUT IN EX.  REG.
          LD      1(P1)           ;GET REMAINDER FROM DIVIDE,
          ORI     '0'
          ST      E(P1)        ;PUT IT ON THE STACK
          LD      -3(P1)          ;IS THE QUOTIENT ZERO YET?
          OR      -4(P1)
          JZ      QPRNT           ;YES - GO PRINT THE NUMBER
          LDI     H(PRNUM1)       ;N0 - CHANGE THE I. L.  PC
          ST      PCHIGH(P2)      ;  SO THAT DIVIDE IS
          LDI     L(PRNUM1)       ;  PERFORMED AGAIN
          ST      PCLOW(P2)
          JMP     X4              ;G0 DO DIVISION BY 10 AGAIN
QPRNT:    LDPI    P3,PUTC-1       ;POINT P3 AT PUTC ROUTINE
          LD      LISTNG(P2)      ;IF LISTING, SKIP PRINTING
          JNZ     QPRNT2          ;  LEADING SPACE
          LD      4(P1)           ;PRINT EITHER
          XPPC    P3              ;  OR LEADING SPACE
          LD      CHRNUM(P2)      ;GET EX.  REG. VALUE BACK
          XAE
QPRNT2:   LD      @E(P1)       ;POINT P3 AT FIRST CHAR
          LD      (P1)            ;  TO BE PRINTED
LOOP3:    XPPC    P3              ;PRINT THE CHARACTER
          LD      @-1(P1)         ;GET NEXT CHARACTER
          JP      LOOP3           ;REPEAT UNTIL = -1
          LDI     L(AESTK)
          ST      LSTK(P2)        ; CLEAR THE A. E.  STACK
          LD      LISTNG(P2)      ;PRINT A TRAILING SPACE
          JNZ     X4              ;  IF NOT LISTING PROGRAM
          LDI     ' '
          XPPC    P3
          JMP     X4
 
;*************************************
;*      CARRIAGE RETURN/LINE FEED    *
;*************************************
NLINE:    LDPI    P3,PUTC-1       ;POINT P3 AT PUTC ROUTINE
          LDI     0x0D            ;CARRIAGE RETURN
          XPPC    P3
          LDI     0x0A            ;LINE FEED
          XPPC    P3
X5:       JMP     X4
 
;*************************************
;*         ERROR  ROUTINE            *
;*************************************
ERR:      LDI     5                ;SYNTAX ERROR
ERR1:     ST      NUM(P2)          ;SAVE ERROR #
ERR2:     LD      NUM(P2)
          ST      TEMP(P2)
          LDPI    P3,PUTC-1        ;POINT P3 AT PUTC
          LDI     0x0D             ; PRINT CR/LF
          XPPC    P3
          LDI     0x0A
          XPPC    P3
          LDPI    P1,MESGS         ;P1  -> ERROR MESSAGES
QQ1:      DLD     NUM(P2)          ;IS  THIS THE RIGHT MESSAGE?
          JZ      QQMSG            ;YES - GO PRINT  IT
LOOP4:    LD      @1(P1)           ;N0 - SCAN THROUGH TO
          JP      LOOP4            ;  NEXT MESSAGE
          JMP     QQ1
QQMSG:    LD      @1(P1)           ;GET MESSAGE CHAR
          XPPC    P3                ;PRINT IT
          LD      -1(P1)           ; IS  MESSAGE DONE?
          JP      QQMSG            ;N0  - GET NEXT CHAR
          LD      TEMP(P2)         ;WAS THIS A BREAK MESSAGE?
          XRI     14
          JZ      QQ3              ;YES - SKIP PRINTING 'ERROR'
          LDPI    P1,MESGS         ;NO  - PRINT  ERROR
QQ2:      LD      @1(P1)           ;GET CHARACTER
          XPPC    P3               ;PRINT IT
          LD      -1(P1)           ;DONE?
          JP      QQ2              ;NO- REPEAT LOOP
QQ3:      LD      RUNMOD(P2)       ;DON'T PRINT LINE #
          JZ      FIN              ;  IF IMMEDIATE MODE
          LDI     ' '
          XPPC    P3               ;SPACE
          LDI     'A'              ;AT
          XPPC    P3
          LDI     'T'
          XPPC    P3
          LDI     H(AESTK)         ; POINT P3 AT A. E. STACK
          XPAH    P3
          ILD     LSTK(P2)
          ILD     LSTK(P2)
          XPAL    P3
          LD      HILINE(P2)      ;GET HIGH BYTE OF LINE #
          ST      -1(P3)          ;PUT ON STACK
          LD      LOLINE(P2)      ; GET LOW BYTE OF LINE #
          ST      -2(P3)          ;PUT ON STACK
          LDI     L(ERRNUM)       ; GO TO PRN
          ST      PCLOW(P2)
          LDI     H(ERRNUM)                                  
          ST      PCHIGH(P2)
X5A:      JMP     X5
 
;*************************************
;*    BREAK,  NXT,  FIN,  & STRT     *
;*************************************
BREAK:  LDI     14              ;***  CAUSE  A  BREAK  ***
E3A:    JMP     ERR1
                                ;*** NEXT STATEMENT ***
NXT:    LD      RUNMOD(P2)      ; IF IN EDIT MODE,
        JZ      FIN             ;  STOP EXECUTION
        LD      (P1)            ;IF WE HIT END OF FILE,
        ANI     0x80             ;  FINISH UP THINGS
        JNZ     FIN
        CSA                     ; BREAK IF SOMEONE IS
        ANI     0x20            ;  TYPING ON THE CONSOLE
        JZ      BREAK
        LD      -1(P1)          ;GET LAST CHARACTER SCANNED
        XRI     0x0D            ;WAS IT CARRIAGE RETURN?
        JNZ     NXT1            ;YES - SKIP FOLLOWING UPDATES
        LD      @1(P1)          ;GET HIGH BYTE OF NEXT LINE #
        ST      HILINE(P2)      ;SAVE IT
        LD      @2(P1)          ;GET LOW BYTE OF LINE #,  SKIP
        ST      LOLINE(P2)      ;  LINE LENGTH BYTE
NXT1:   LDI     H(STMT)         ; GO TO  STMT  IN IL TABLE
        ST      PCHIGH(P2)
        LDI     L(STMT)
        ST      PCLOW(P2)
        XPPC    P3
 
FIN:    LDI     0               ;*** FINISH EXECUTION ***
        ST      RUNMOD(P2)      ; CLEAR RUN MODE
        LDI     L(AESTK)        ; CLEAR ARITHMETIC STACK
        ST      LSTK(P2)
        LDI     L(START)        ; MODIFY I.L.  PC TO RETURN
        ST      PCLOW(P2)       ;  TO PROMPT FOR COMMAND
        LDI     H(START)
        ST      PCHIGH(P2)
        LDI     L(PCSTAK)
        ST      PCSTK(P2)
        JMP     X5A
                                  ;*** START EXECUTION ***
STRT:   ILD     RUNMOD(P2)      ;RUN MODE = 1
        LD      TEMP2(P2)       ;POINT CURSOR TO
        XPAH    P1              ;  START OF NIBL PROGRAM
        LD      TEMP3(P2)
        XPAL    P1
        LDI     L(SBRSTK)       ;EMPTY SOME STACKS:
        ST      SBRPTR(P2)      ;  GOSUB STACK,
        LDI     L(FORSTK)
        ST      FORPTR(P2)      ;  FOR STACK
        LDI     L(DOSTAK)
        ST      DOPTR(P2)       ;  & DO/UNTIL STACK
        XPPC    P3              ;RETURN
X6:     JMP     X5A
E4:     JMP     E3A
 
;*************************************
;*        LIST NIBL PROGRAM          *
;*************************************
LST:    LD      (P1)            ;CHECK FOR END OF FILE
        XRI     0x80
        JP      LST2
        LDI     H(AESTK)        ;GET LINE NUMBER ONTO STACK
        XPAH    P3
        ILD     LSTK(P2)
        ILD     LSTK(P2)
        XPAL    P3
        LD      @1(P1)
        ST      -1(P3)   
        LD      @1(P1)
        ST      -2(P3)
        LD      @1(P1)          ;SKIP OVER LINE LENGTH
        LDI     1
        ST      LISTNG(P2)      ;SET LISTING FLAG
        JMP     X6              ; GO PRINT LINE NUMBER
LST2:   LDI     0
        ST      LISTNG(P2)      ;CLEAR LISTING FLAG
        JS      P3,NXT          ; GO TO NXT
X6A:    JMP     X6
E5:     JMP     E4
LST3:   LDPI    P3,PUTC-1       ;POINT P3 AT PUTC
LST4:   CSA
        ANI     0x20
        JZ      LST2            ;IF  TYPING, STOP
        LD      @1(P1)          ;GET NEXT CHAR
        XRI     0x0D            ;TEST FOR CR
        JZ      LST5
        XRI     0x0D            ;GET CHARACTER
        XPPC    P3              ;PRINT CHARACTER
        JMP     LST4
LST5:   LDI     0x0D            ; CARRIAGE RETURN
        XPPC    P3
        LDI     0x0A              ;LINE FEED
        XPPC    P3
        CCL
        LDI     L(LIST3)
        ST      PCLOW(P2)
        LDI     H(LIST3)
        ST      PCHIGH(P2)
        JMP     LST             ;GET NEXT LINE
 
;*************************************
;*          ADD AND SUBTRACT         *
;*************************************
ADD:    LDI     H(AESTK)         ;SET P3  TO CURRENT
        XPAH    P3               ;  STACK  LOCATION
        DLD     LSTK(P2)
        DLD     LSTK(P2)
        XPAL    P3
        CCL
        LD      -2(P3)           ; REPLACE TWO TOP  ITEMS
        ADD     0(P3)            ;  ON STACK BY THEIR SUM
        ST      -2(P3)
        LD      -1(P3)
        ADD     1(P3)
        ST      -1(P3)
X7:     JMP     X6A
 
SUB:    LDI     H(AESTK)         ;SET P3  TO CURRENT
        XPAH    P3               ;  STACK  LOCATION
        DLD     LSTK(P2)
        DLD     LSTK(P2)
        XPAL    P3
        SCL
        LD      -2(P3)          ;REPLACE TWO TOP ITEMS
        CAD     0(P3)           ;  ON STACK BY THEIR
        ST      -2(P3)          ;  DIFFERENCE
        LD      -1(P3)
        CAD     1(P3)
        ST      -1(P3)
        JMP     X6A
 
;*************************************
;*           NEGATE                  *
;*************************************
NEG:     LDI     H(AESTK)        ;SET P3  TO CURRENT
         XPAH    P3              ;  STACK  LOCATION
         LD      LSTK(P2)
         XPAL    P3
         SCL
         LDI     0
         CAD     -2(P3)          ; NEGATE TOP ITEM ON STACK
         ST      -2(P3)
         LDI     0
         CAD     -1(P3)
         ST      -1(P3)
X8:      JMP     X7
E6:      JMP     E5
 
;*************************************
;*          MULTIPLY                 *
;*************************************
MUL:    LDI     H(AESTK)        ;SET P3 TO CURRENT
        XPAH    P3              ;  STACK LOCATION
        LD      LSTK(P2)
        XPAL    P3              ; DETERMINE SIGN OF PRODUCT, 
        LD      -1(P3)          ;  SAVE IN TEMP(P2)
        XOR     -3(P3)
        ST      TEMP(P2)
        LD      -1(P3)          ; CHECK FOR NEGATIVE
        JP      MM1             ;  MULTIPLIER
        SCL
        LDI     0               ;IF NEGATIVE,
        CAD     -2(P3)          ;  NEGATE
        ST      -2(P3)
        LDI     0
        CAD     -1(P3)
        ST      -1(P3)
MM1:    LD      -3(P3)          ; CHECK FOR NEGATIVE
        JP      MM2             ;  MULTIPLICAND
        SCL
        LDI     0               ; IF NEGATIVE,
        CAD     -4(P3)          ;  NEGATE
        ST      -4(P3)
        LDI     0
        CAD     -3(P3)
        ST      -3(P3)
MM2:    LDI     0               ; CLEAR WORKSPACE
        ST      0(P3)
        ST      1(P3)
        ST      2(P3)
        ST      3(P3)
        LDI     16              ;SET COUNTER TO 16
        ST      NUM(P2)
LOOP5:  LD      -1(P3)          ; ROTATE MULTIPLIER
        RRL                     ;  RIGHT ONE BIT
        ST      -1(P3)
        LD      -2(P3)
        RRL
        ST      -2(P3)
        CSA                     ;CHECK FOR CARRY BIT
        JP      MM3             ;IF NOT SET, DON'T DO ADD
        CCL
        LD      2(P3)           ;ADD MULTIPLICAND
        ADD     -4(P3)          ;  INTO WORKSPACE
        ST      2(P3)
        LD      3(P3)
        ADD     -3(P3)
        ST      3(P3)
        JMP     MM3
E6A:    JMP     E6
MM3:    CCL
        LD      3(P3)           ;SHIFT WORKSPACE RIGHT BY 1
        RRL
        ST      3(P3)
        LD      2(P3)
        RRL
        ST      2(P3)
        LD      1(P3)
        RRL
        ST      1(P3)
        LD      0(P3)
        RRL
        ST      0(P3)
        DLD     NUM(P2)         ;DECREMENT COUNTER
        JNZ     LOOP5           ;LOOP IF NOT ZERO
        JMP     MM4
X9:     JMP     X8
MM4:    LD      TEMP(P2)        ; CHECK SIGN WORD
        JP      MMEXIT          ;IF BIT7 = 1,  NEGATE PRODUCT
        SCL
        LDI     0
        CAD     0(P3)
        ST      0(P3)
        LDI     0
        CAD     1(P3)
        ST      1(P3)
MMEXIT: LD      0(P3)            ;PUT PRODUCT ON TOP
        ST      -4(P3)           ;  OF STACK
        LD      1(P3)
        ST      -3(P3)
        DLD     LSTK(P2)         ;SUBTRACT 2 FROM
        DLD     LSTK(P2)         ;  LSTK
        JMP     X9
 
;*************************************
;*            DIVIDE                 *
;*************************************
DIV:    LDI     H(AESTK)
        XPAH    P3
        LD      LSTK(P2)  
        XPAL    P3
        LD      -1(P3)          ; CHECK FOR DIVISION BY 0
        OR      -2(P3)
        JNZ     QD0
        LDI     13
        JMP     E6A
QD0:    LD      -3(P3)
        XOR     -1(P3)
        ST      TEMP(P2)        ;SAVE SIGN OF QUOTIENT
        LD      -3(P3)          ; IS DIVIDEND POSITIVE?
        JP      QDPOS           ;YES - JUMP
        LDI     0
        SCL
        CAD     -4(P3)          ;N0 - NEGATE DIVIDEND,
        ST      3(P3)           ;  STORE IN RIGHT HALF
        LDI     0               ;  OF 32-BIT ACCUMULATOR
        CAD     -3(P3)
        ST      2(P3)
        JMP     QD1
X9A:    JMP     X9
QDPOS:  LD      -3(P3)          ; STORE NON-NEGATED DIVIDEND
        ST      2(P3)           ;  IN 32-BIT ACCUMULATOR
        LD      -4(P3)
        ST      3(P3)
QD1:    LD      -1(P3)          ; CHECK FOR NEGATIVE DIVISOR
        JP      QD2
        LDI     0               ; NEGATE DIVISOR
        SCL
        CAD     -2(P3)
        ST      -2(P3)
        LDI     0
        CAD     -1(P3)
        ST      -1(P3)
QD2:    LDI     0               ;PUT  ZERO  IN
        ST      1(P3)           ;   LEFT HALF OF 32-BIT ACC,
        ST      0(P3)
        ST      NUM(P2)         ;   THE COUNTER,  AND
        ST      -3(P3)          ;   IN THE  DIVIDEND,  NOW USED
        ST      -4(P3)          ;   STORE THE QUOTIENT
LOOP6:  CCL                     ; BEGIN MAIN DIVIDE LOOP - 
        LD      -4(P3)          ;   SHIFT QUOTIENT LEFT,
        ADD     -4(P3)
        ST      -4(P3)                       
        LD      -3(P3)
        ADD     -3(P3)
        ST      -3(P3)
        CCL                     ;   SHIFT 32-BIT ACC LEFT,
        LD      3(P3)
        ADD     3(P3)
        ST      3(P3)                                    
        LD      2(P3)
        ADD     2(P3)
        ST      2(P3)
        LD      1(P3)
        ADD     1(P3)
        ST      1(P3)
        LD      (P3)
        ADD     (P3)
        ST      (P3)
        SCL
        LD      1(P3)           ;   SUBTRACT DIVISOR INTO
        CAD     -2(P3)          ;    LEFT HALF OF ACC,   
        ST      1(P3)
        LD      (P3)
        CAD     -1(P3)
        ST      (P3)
        JP      QDENT1          ;   IF RESULT IS NEGATIVE,
        CCL                     ;    RESTORE ORIGINAL CONTENTS
        LD      1(P3)           ;    OF ACC BY ADDING DIVISOR
        ADD     -2(P3)
        ST      1(P3)
        LD      (P3)
        ADD     -1(P3)
        ST      (P3)
        JMP     QD3
X9B:    JMP     X9A
QDENT1: LD      -4(P3)          ;ELSE IF RESULT POSITIVE,
        ORI     1               ;RECORD A 1  IN QUOTIENT
        ST      -4(P3)          ;W/0 RESTORING THE ACC
QD3:    ILD     NUM(P2)         ;INCREMENT THE COUNTER
        XRI     16              ;ARE WE DONE?
        JNZ     LOOP6           ;LOOP IF NOT  DONE
        LD      TEMP(P2)        ;CHECK THE QUOTIENT'S SIGN,
        JP      QDEND           ;  NEGATING IF NECESSARY
        LDI     0
        SCL
        CAD     -4(P3) 
        ST      -4(P3)
        LDI     0
        CAD     -3(P3)
        ST       -3(P3)
QDEND:  DLD     LSTK(P2)        ;DECREMENT THE  STACK POINTER,
        DLD     LSTK(P2)
        JMP     X9B             ;  AND EXIT
 
;*************************************
;*         STORE VARIABLE            *
;*************************************
STORE:  LDI     H(AESTK)      ;SET P3 TO STACK
        XPAH     P3
        LD      LSTK(P2)
        XPAL     P3
        LD      @-3(P3)       ;GET VARIABLE INDEX
        XAE                   ;PUT IN E REG
        LD      1(P3)
        ST      E(P2)      ;STORE LOWER 3  BITS
        CCL                   ;  INTO VARIABLE
        LDE                   ;INCREMENT INDEX
        ADI      1
        XAE
        LD       2(P3)
        ST       E(P2)     ;STORE UPPER 8 BITS
        XPAL     P3           ;INTO VARIABLE
        ST       LSTK(P2)     ;UPDATE STACK POINTER
X10:    JS       P3,EXECIL
 
;*************************************
;*   TEST FOR  VARIABLE  IN TEXT     *
;*************************************
TSTVAR:  LD      @1(P1)
         XRI     ' '             ;SLEW OFF SPACES
         JZ      TSTVAR 
         LD      -1(P1)          ;CHARACTER IN QUESTION
         SCL
         CAI     'Z'+1           ;SUBTRACT 'Z'+l
         JP      TV_FAIL         ;N0T VARIABLE IF POSITIVE
         SCL
         CAI     'A'-'Z'-1       ;SUBTRACT 'A'
         JP      TVMAYBE         ;IF POS,  MAY BE VARIABLE
TV_FAIL: LD      @-1(P1)         ;BACKSPACE CURSOR
         LD      PCLOW(P2)       ;GET TEST-FAIL ADDRESS
         XPAL    P3              ;  FROM I. L.  TABLE,  PUT IT
         LD      PCHIGH(P2)      ;  INTO I.L.  PROGRAM COUNTER
         XPAH    P3
         LD      (P3)
         ST      PCHIGH(P2)
         LD      1(P3)
         ST      PCLOW(P2)
         JMP     X10
TVMAYBE: XAE                     ;SAVE VALUE (0-25)
         LD      (P1)            ;CHECK FOLLOWING CHAR
         SCL                     ;MUST NOT BE A LETTER
         CAI     'Z'+1           ;OTHERWISE WE'D BE LOOKING
         JP      TV_OK           ;AT A KEYWORD, NOT A VARIABLE
         SCL
         CAI     'A'-'Z'-1
         JP      TV_FAIL
TV_OK:   LDI     H(AESTK)        ;SET PS TO CURRENT
         XPAH    P3              ;  STACK LOCATION
         ILD     LSTK(P2)        ;INCR STACK POINTER
         XPAL    P3
         CCL                     ;DOUBLE VARIABLE INDEX
         LDE
         ADE
         ST      -1(P3)          ;PUT INDEX ON STACK
         LDI     2               ; INCREMENT I.L.  PC,  SKIPPING
         CCL                     ;  OVER TEST-FAIL ADDRESS
         ADD     PCLOW(P2)
         ST      PCLOW(P2)
         LDI     0
         ADD     PCHIGH(P2)
         ST      PCHIGH(P2)
         JMP     X10
 
;*************************************
;*      IND - EVALUATE A VARIABLE    *
;*************************************
IND:      LDI     H(AESTK)        ;SET P3 TO STACK
          XPAH    P3
          ILD     LSTK(P2)
          XPAL    P3
          LD      -2(P3)          ;GET INDEX OFF TOP
          XAE                     ;PUT INDEX IN E REG
          LD      E(P2)        ;GET LOWER 8 BITS
          ST      -2(P3)          ;SAVE ON STACK
          CCL
          LDE                     ; INCREMENT E REG
          ADI     1
          XAE                  
          LD      E(P2)        ;GET UPPER 8 BITS
          ST      -1(P3)          ;SAVE ON STACK
XI1:      JMP     X10

;*************************************
;*      RELATIONAL OPERATORS         *
;*************************************
EQ:      LDI     1                ;EACH RELATIONAL OPERATOR
         JMP     CMP              ;  LOADS A NUMBER USED LATER
NEQ:     LDI     2                ;  AS A CASE SELECTOR, AFTER
         JMP     CMP              ;  THE TWO OPERANDS ARE COM-
LSS:     LDI     3                ;  PARED.   BASED ON THE COM-
         JMP     CMP              ;  PARISON,  FLAGS ARE SET THAT
LEQ:     LDI     4                ;  ARE EQUIVALENT TO THOSE SET
         JMP     CMP              ;  BY THE "CMP" INSTRUCTION IN
GTR:     LDI     5                ;  THE PDP-11.  THESE PSEUDO-
         JMP     CMP              ;  FLAGS ARE USED TO DETERMINE
GEQ:     LDI     6                ;  WHETHER THE PARTICULAR
                                  ; RELATION IS SATISFIED OR NO
CMP:     ST      NUM(P2)
         LDI     H(AESTK)         ;SET P3 -> ARITH STACK
         XPAH    P3
         DLD     LSTK(P2)
         DLD     LSTK(P2)
         XPAL    P3
         SCL
         LD      -2(P3)           ; SUBTRACT THE TWO OPERANDS,
         CAD     (P3)             ;  STORING RESULT IN LO & HI
         ST      LO(P2)
         LD      -1(P3)
         CAD     1(P3)
         ST      HI(P2)
         XOR     -1(P3)           ;OVERFLOW OCCURS IF  SIGNS OF
         XAE                      ;  RESULT AND 1ST OPERAND
         LD      -1(P3)           ;  DIFFER,  AND SIGNS  OF THE
         XOR     1(P3)            ;  TWO OPERANDS DIFFER
         ANE                      ;BIT 7 EQUIVALENT TO V FLAG
         XOR     HI(P2)           ;BIT 7 EQUIVALENT TO N XOR V
         ST      TEMP(P2)         ;STORE IN TEMP
         LD      HI(P2)           ;DETERMINE IF RESULT WAS ZERO
         OR      LO(P2)
         JZ      SETZ             ;IF RESULT=0,  SET Z  FLAG
         LDI     0x80              ;  ELSE CLEAR Z FLAG
SETZ:    XRI     0x80
         XAE                      ;BIT 7 OF EX = Z FLAG
         DLD     NUM(P2)          ;TEST FOR =
         JNZ     NEQ1
         LDE                      ;  EQUAL IF Z = 1
         JMP     CMP1
X12:     JMP     XI1
NEQ1:    DLD     NUM(P2)          ;TEST FOR <>
         JNZ     LSS1
         LDE                      ;  NOT EQUAL IF Z = 0
         XRI     0x80
         JMP     CMP1
LSS1:    DLD     NUM(P2)          ;TEST FOR <                  
         JNZ     LEQ1
         LD      TEMP(P2)         ;  LESS THAN IF (N XOR V)=l
         JMP     CMP1
LEQ1:    DLD     NUM(P2)          ;TEST FOR <=
         JNZ     GTR1
         LDE                      ;  LESS THAN OR EQUAL
         OR      TEMP(P2)         ;   IF (Z OR (N XOR V))=l
         JMP     CMP1
GTR1:    DLD     NUM(P2)          ;TEST FOR >
         JNZ     GEQ1
         LDE                      ;  GREATER THAN
         OR      TEMP(P2)         ;   IF (Z OR (N XOR V))=0
         XRI     0x80
         JMP     CMP1
GEQ1:    LD      TEMP(P2)         ;GREATER THAN OR EQUAL
         XRI     0x80             ;  IF (N XOR V)=0
CMP1:    JP      FALSE1           ;IS RELATION SATISFIED?
         LDI     1                ;YES - PUSH 1  ON STACK
         JMP     CMP2
FALSE1:  LDI     0                ;N0 - PUSH 0 ON STACK
CMP2:    ST      -2(P3)
         LDI     0 
         ST      -1(P3)
         JS      P3,RTN           ;DO AN I. L.  RETURN
         JMP     X12

;*************************************
;*     IF STATEMENT TEST FOR ZERO    *
;*************************************
                                           
CMPR:   LD      LO(P2)          ;GET LOW & HI BYTES OF EXPR.
        OR      HI(P2)          ;TEST IF EXPRESSION IS ZERO (LATER CHANGED TO 'ANI 01'(R.MARIN JAN 2008))
        JZ      FAIL            ;YES - IT IS
        JMP     X12             ;N0 - IT ISN'T SO CONTINUE
FAIL:   LD      @1(P1)          ;SKIP TO NEXT LINE IN PROGRAM
        XRI     0x0D            ;  (I.E.  TIL NEXT CR)
        JNZ     FAIL
        JS      P3,NXT          ;CALL NXT AND RETURN
X12A:   JMP     X12

;*************************************
;*         AND, OR, & NOT            *
;*************************************
ANDOP:  LDI     1               ;EACH OPERATION HAS ITS
        JMP     AON1              ;  OWN CASE SELECTOR.
OROP:   LDI     2   
        JMP     AON1
NOTOP:  LDI     3
AON1:   ST      NUM(P2)                                        
        LDI     H(AESTK)        ;SET P3 -> ARITH. STACK
        XPAH    P3
        DLD     LSTK(P2)
        DLD     LSTK(P2)
        XPAL    P3
        DLD     NUM(P2)         ;TEST FOR  AND
        JNZ     AON_0R
        LD      1(P3)           ; REPLACE TWO TOP ITEMS ON
        AND     -1(P3)          ;  STACK BY THEIR  AND
        ST      -1(P3)
        LD      0(P3)
        AND     -2(P3)
        ST      -2(P3)
        JMP     X12A
AON_0R: DLD     NUM(P2)         ;TEST FOR  OR
        JNZ     AON_NT
        LD      1(P3)           ;REPLACE TWO TOP ITEMS ON
        OR      -1(P3)          ;  STACK BY THEIR 'OR'
        ST      -1(P3)
        LD      0(P3)
        OR      -2(P3)
        ST      -2(P3)
        JMP     X12A
AON_NT: LD      @1(P3)          ; NOT  OPERATION
        XRI     0xFF
        ST      -1(P3)          ; REPLACE TOP ITEM ON STACK
        LD      @1(P3)          ;  BY ITS ONE'S COMPLEMENT
        XRI     0xFF
        ST      -1(P3)
        XPAL    P3
        ST      LSTK(P2)         ;STACK POINTER FIXUP
X12B:   JMP     X12A

;*************************************
;*      EXCHANGE CURSOR WITH RAM     *
;*************************************
XCHGP1: LD      P1L0W(P2)        ;THIS ROUTINE IS HANDY WHEN
        XPAL    P1               ;EXECUTING AN 'INPUT' STMT
        ST      P1L0W(P2)        ;IT EXCHANGES THE CURRENT
        LD      P1HIGH(P2)       ;TEXT CURSOR WITH ONE SAVED
        XPAH    P1               ;IN RAM
        ST      P1HIGH(P2)
        XPPC    P3

;*************************************
;*        CHECK RUN MODE             *
;*************************************
CKMODE: LD      RUNMOD(P2)       ;THIS ROUTINE CAUSES AN ERROR
        JZ      CK1              ;IF CURRENTLY IN EDIT MODE
        XPPC    P3
CK1:    LDI     3
E8:     ST      NUM(P2)          ;ERROR IF RUN MODE = 0
        JS      P3,ERR2          ;MINOR KLUGE

;*************************************
;*     GET  HEXADECIMAL NUMBER       *
;*************************************
HEX:    ILD     LSTK(P2)        ;POINT P3 AT ARITH STACK
        ILD     LSTK(P2)
        XPAL    P3
        LDI     H(AESTK)
        XPAH    P3
        LDI      0              ;NUMBER INITIALLY ZERO
        ST      -1(P3)          ;PUT IT ON STACK
        ST      -2(P3)
        ST      NUM(P2)         ;ZERO NUMBER OF DIGITS
HSKIP:  LD      @1(P1)          ;SKIP ANY SPACES
        XRI     ' '
        JZ      HSKIP
        LD      @-1(P1)
LOOP7:  LD      (P1)            ;GET A CHARACTER
        SCL
        CAI     '9'+1           ;CHECK FOR A NUMERIC CHAR
        JP      HLETR
        SCL
        CAI     '0'-'9'-1       ;IF NUMERIC, SHIFT NUMBER
        JP      HENTER          ;  AND ADD NEW HEX DIGIT
        JMP     HEND
X12C:   JMP     X12B
HLETR:  SCL                     ;CHECK FOR HEX LETTER
        CAI     'G'-'9'-1
        JP      HEND
        SCL
        CAI     'A'-'G'
        JP      HX0K
        JMP     HEND
HX0K:   CCL                     ;ADD 10 TO GET TRUE VALUE
        ADI     10              ;  OF LETTER
HENTER: XAE                     ;NEW DIGIT IN EX REG
        LDI     4               ;SET SHIFT COUNTER
        ST      TEMP(P2)
        ST      NUM(P2)         ;DIGIT COUNT IS NON-ZERO
HSHIFT: LD      -2(P3)          ;SHIFT NUMBER LEFT BY 4
        CCL
        ADD     -2(P3)
        ST      -2(P3)
        LD      -1(P3)
        ADD     -1(P3)
        ST      -1(P3)
        DLD     TEMP(P2)
        JNZ     HSHIFT
        LD      -2(P3)          ;ADD NEW DIGIT
        ORE                     ; INTO NUMBER
        ST      -2(P3)
        LD      @1(P1)          ;ADVANCE THE CURSOR
        JMP     LOOP7           ;GET NEXT CHAR
HEND:   LD      NUM(P2)         ;CHECK IF THERE WERE
        JNZ     X12B            ;MORE THAN 0 CHARACTERS
        LDI     5               ;ERROR IF THERE WERE NONE
E8B:    JMP     E8

;*************************************
;*      TEST FOR NUMBER IN TEXT      *
;*************************************
;  THIS ROUTINE TESTS FOR A NUMBER IN THE TEXT.  IF  NO
;  NUMBER IS FOUND, I.L. CONTROL PASSES TO THE ADDRESS
;  INDICATED IN THE  'TSTN' INSTRUCTION. OTHERWISE, THE
;  NUMBER IS SCANNED AND PUT ON THE ARITHMETIC STACK,
;  WITH I.L. CONTROL PASSING TO THE NEXT INSTRUCTION.
 
TSTNUM: LD      @1(P1)
        XRI     ' '             ;  SKIP OVER ANY SPACES
        JZ      TSTNUM
        LD      @-1(P1)         ;GET FIRST CHAR
        SCL                     ;TEST FOR DIGIT
        CAI     '9'+1
        JP      TNABRT
        SCL
        CAI     '0'-'9'-1
        JP      TNL1
TNABRT: LD      PCLOW(P2)        ;CET TEST-FAIL ADDRESS
        XPAL    P3               ;FROM  I. L. TABLE
        LD      PCHIGH(P2)
        XPAH    P3
        LD      (P3)             ;PUT TEST-FAIL ADDRESS
        ST      PCHIGH(P2)       ;INTO  I. L. PC
        LD      1(P3)
        ST      PCLOW(P2)
        JMP     X12C
TNRET:  LDI     2                ;SKIP OVER ONE IL INSTRUCTION
        CCL                      ;IF NUMBER IS DONE
        ADD     PCLOW(P2)
        ST      PCLOW(P2)
        LDI     0
        ADD     PCHIGH(P2)
        ST      PCHIGH(P2)
X13:    JMP     X12C
ESA:    JMP     E8B
TNL1:   XAE                      ;SAVE DIGIT IN  EX  REG
        LDI     H(AESTK)         ;POINT  P3 AT AE STACK
        XPAH    P3
        ILD     LSTK(P2)
        ILD     LSTK(P2)
        XPAL    P3
        LDI     0
        ST      -1(P3)
        LDE
        ST      -2(P3)
LOOP8:  LD      @1(P1)           ;GET NEXT  CHAR
        LD      (P1)
        SCL                      ;TEST IF IT IS DIGIT
        CAI     '9'+1
        JP      TNRET            ;RETURN  IF IT ISN'T
        SCL
        CAI     '0'-'9'-1
        JP      TNL2
        JMP     TNRET
TNL2:   XAE                      ;SAVE DIGIT
        LD      -1(P3)           ;PUT RESULT IN SCRATCH SPACE
        ST      1(P3)
        LD      -2(P3)
        ST      (P3)
        LDI     2
        ST      TEMP(P2)         ;MULTIPLY RESULT BY 10
TNSHFT: CCL                      ;FIRST MULTIPLY BY 4
        LD      -2(P3)
        ADD     -2(P3)
        ST      -2(P3)
        LD      -1(P3)
        ADD     -1(P3)
        ST      -1(P3)
        ANI     0x80            ; MAKE SURE N0 OVERFLOW
        JNZ     TNERR           ;  OCCURRED
        DLD     TEMP(P2)
        JNZ     TNSHFT
        CCL                     ;THEN ADD OLD RESULT,
        LD       -2(P3)         ;  SO WE HAVE RESULT * 5
        ADD     (P3)
        ST       -2(P3)
        LD       -1(P3)
        ADD     1(P3)
        ST       -1(P3)
        ANI     0x80            ;MAKE SURE NO OVERFLOW
        JNZ     TNERR           ;  OCCURRED
        CCL                     ;THEN MULTIPLY, BY TWO
        LD      -2(P3)
        ADD     -2(P3)
        ST      -2(P3)
        LD      -1(P3)
        ADD     -1(P3)
        ST      -1(P3)
        ANI     0x80            ;MAKE SURE NO OVERFLOW
        JNZ     TNERR           ;  OCCURRED
        CCL                     ;THEN ADD IN NEW DIGIT
        LDE
        ADD     -2(P3)
        ST      -2(P3)
        LDI     0
        ADD     -1(P3)
        ST      -1(P3)
        JP      LOOP8           ;REPEAT IF NO OVERFLOW
TNERR:  LDI     6
E9:     JMP     ESA             ;ELSE REPORT ERROR
X14:    JMP     X13

;*************************************
;*      GET LINE  FROM TELETYPE      *
;*************************************
GETL:   LDPI    P1,LBUF        ;SET P1  TO LBUF
        LDI     0              ;CLEAR NO.  OF CHAR
        ST      CHRNUM(P2)
        LDPI    P3,PUTC-1      ;POINT P3 AT PUTC ROUTINE
        LD      RUNMOD(P2)     ;PRINT  '? '  IF RUNNING
        JZ      GETL0          ;  (I.E. DURING  'INPUT')
        LDI     '?'
        XPPC     P3
        LDI     ' '
        XPPC    P3
        JMP     GETL1
GETL0:  LDI     '>'             ; OTHERWISE PRINT '>'
        XPPC    P3   
GETL1:  JS      P3,GECO         ;GET CHARACTER
        LDI     L(PUTC)-1       ; POINT PS AT PUTC AGAIN
        XPAL    P3
        LDE                     ;GET TYPED CHAR
        JZ      GETL1           ; IGNORE NULLS
        XRI     0x0A            ; IGNORE LINE FEED
        JZ      GETL1
        LDE
        XRI     0x0D            ; CHECK FOR CR
        JZ      GETLCR
        LDE
        XRI     'O'+0x10        ; CHECK FOR SHIFT/0
        JZ      GETRUB
        LDE                     ;CHECK FOR CTRL/H
        XRI     8
        JZ      GXH
        LDE
        XRI     0x15            ;CHECK FOR CTRL/U
        JZ      GXU
        LDE
        XRI     3               ;CHECK FOR CTRL/C
        JNZ     GENTR
        LDI     '^'             ;ECHO CONTROL/C AS ^C
        XPPC    P3
        LDI     'C'
        XPPC    P3
        LDI     14              ; CAUSE A BREAK
        JMP     E9
GXU:    LDI     '^'             ;ECHO CONTROL/U AS ^U
        XPPC    P3
        LDI     'U'
        XPPC    P3
        LDI     0x0D            ; PRINT CR/LF
        XPPC    P3                                          
        LDI     0x0A
        XPPC    P3
        JMP     GETL            ; G0 GET ANOTHER LINE
X15:    JMP     X14
GENTR:  LDE
        ST      @1(P1)          ;PUT CHAR IN LBUF
        ILD     CHRNUM(P2)      ; INCREMENT CHRNUM
        XRI     72              ;IF=72,  LINE FULL
        JNZ     GETL1
        LDI     0x0D
        XAE                     ;SAVE CARRIAGE RET
        LDE
        XPPC    P3              ; PRINT IT
        JMP     GETLCR          ; STORE IT IN LBUF
E10:    JMP     E9                                              
GXH:    LDI     ' '             ; BLANK OUT THE CHARACTER
        XPPC    P3
        LDI     8               ; PRINT ANOTHER BACKSPACE
        XPPC    P3
GETRUB: LD      CHRNUM(P2)
        JZ      GETL1
        DLD     CHRNUM(P2)      ;0NE LESS CHAR
        LD      @-1(P1)         ;BACKSPACE CURSOR
        JMP     GETL1
GETLCR: LDE
        ST      @1(P1)          ;STORE CR IN LBUF
        LDI     0x0A            ;PRINT LINE FEED
        XPPC    P3
        LDI     H(LBUF)         ;SET P1 TO BEGIN-
        XPAH    P1              ;  NING OF LBUF
        LDI     L(LBUF)
        XPAL    P1
X16:    JMP     X15

;*************************************
;*     EVAL -- GET MEMORY CONTENTS   *
;*************************************
 ;  THIS ROUTINE IMPLEMENTS THE  '@' OPERATOR IN EXPRESSIONS
 
EVAL:   LDI     H(AESTK)
        XPAH    P3
        LD      LSTK(P2)
        XPAL    P3              ; P3 -> ARITH STACK  
        LD      -1(P3)           ; GET ADDR OFF STACK,
        XPAH    P1              ;  AND INTO P1,
        XAE                     ;  SAVING OLD P1 IN  EX & LO
        LD      -2(P3)                                       
        XPAL    P1
        ST      LO(P2)
        LD      0(P1)           ;GET MEMORY CONTENTS,
        ST      -2(P3)          ;  SHOVE ONTO STACK
        LDI     0
        ST      -1(P3)           ;HIGH ORDER 3 BITS  ZEROED
        LD      LO(P2)
        XPAL    P1              ;RESTORE ORIGINAL P1
        LDE
        XPAH    P1
        JMP     X15

;*************************************
;*    MOVE - STORE INTO MEMORY       *
;*************************************
;  THIS ROUTINE IMPLEMENTS THE STATEMENT:
;      '@'  FACTOR  '='  REL-EXP
 
MOVE:   LDI     H(AESTK)
        XPAH    P3
        LD      LSTK(P2)
        XPAL    P3              ;P3 -> ARITH STACK
        LD      @-2(P3)         ;GET BYTE  TO  BE MOVED
        XAE                                                    
        LD      @-1(P3)         ;NOW GET ADDRESS INTO P3
        ST      TEMP(P2)
        LD      @-1(P3)
        XPAL    P3
        ST      LSTK(P2)        ;STACK PTR UPDATED NOW
        LD      TEMP(P2)
        XPAH    P3
        LDE
        ST      0(P3)           ;MOVE THE  BYTE INTO MEMORY
X17:    JMP     X16
Ell:    JMP     E10
 
;*************************************
;*            TEXT EDITOR            *
;*************************************
                                             
;INPUTS TO THIS ROUTINE: POINTER TO LINE BUFFER IN P1L0W &
;  P1HIGH.   P1 POINTS TO THE INSERTION POINT IN THE TEXT.
;  THE A.E.  STACK HAS THE LINE NUMBER ON IT (STACK POINTER
;  IS ALREADY POPPED).
 
; EACH LINE IN THE NIBL TEXT IS STORED IN THE  FOLLOWING
;  FORMAT:  TWO BYTES CONTAINING THE LINE NUMBER (IN BINARY,
;  HIGH ORDER BYTE FIRST),  THEN ONE BYTE CONTAINING THE
;  LENGTH OF THE LINE., AND FINALLY THE LINE ITSELF FOLLOWED
;  BY A CARRIAGE RETURN.   THE LAST LINE IN  THE TEXT IS
;  FOLLOWED BY TWO CONSECUTIVE BYTES OF XFF.
                      
INSRT:  LDI     H(AESTK)        ;POINT P3  AT  AE STACK,
        XPAH    P3              ;WHICH HAS THE LINE #
        LD      LSTK(P2)        ;ON IT
        XPAL    P3
        LD      1(P3)           ;SAVE NEW  LINE'S NUMBER
        ST      HILINE(P2)
        LD      0(P3)
        ST      LOLINE(P2)
        LD      P1L0W(P2)        ;PUT POINTER  TO LBUF INTO P3
        XPAL    P3
        LD      P1HIGH(P2)
        XPAH    P3
        LDI     4               ;INITIALLY LENGTH OF NEW LINE
        ST      CHRNUM(P2)      ;  = 4.  ADD 1  TO LENGTH FOR
INSRT1: LD      @1(P3)          ;  EACH CHAR IN LINE UP TO,
        XRI     0x0D            ;  BUT NOT  INCLUDING,
        JZ      INSRT2          ;  CARRIAGE RETURN
        ILD     CHRNUM(P2)
        JMP     INSRT1
INSRT2: LD      CHRNUM(P2)      ; IF LENGTH STILL 4,
        XRI     4               ;  WE'LL DELETE A LINE,
        JNZ     INSRT3          ;  SO SET LENGTH = 0
        ST      CHRNUM(P2)
INSRT3: LD      CHRNUM(P2)      ;PUT NEW LINE LENGTH IN EX
        XAE
        LD      LABLHI(P2)       ; IS NEW LINE REPLACING OLD?
        JP      INSRT4          ;YES - DO REPLACE
        ANI     0x7F            ;N0 - WE'LL INSERT LINE HERE,
        ST      LABLHI(P2)       ;  WHERE FNDLBL GOT US
        JMP     AMOVE           ;BUT FIR3T MAKE ROOM
INSRT4: LD      @3(P1)          ;SKIP LINE # AND LENGTH
        LDE                     ;EX,  NOW HOLDING NEW LINE
        CCL                     ;  LENGTH,  WILL SOON HOLD
        ADI     -4              ;  DISPLACEMENT OF LINES
        XAE                     ;  TO BE MOVED
INSRT5: LD      @1(P1)          ;SUBTRACT 1 FROM DISPLACEMENT
        XRI     0x0D            ;  FOR EACH CHAR IN LINE BEING
        JZ      AMOVE           ;  REPLACED
        LDE
        CCL
        ADI      -1
        XAE
        JMP      INSRT5
X19:    JMP      X17
E12:    JMP      Ell
AMOVE:  LDE                       ;IF DISPLACEMENT AND LENGTH
        OR       CHRNUM(P2)       ;  OF NEW LINE ARE 0,  RETURN
        JZ       X19
        LDI      L(DOSTAK)        ; CLEAR SOME STACKS
        ST       DOPTR(P2)
        LDI      L(SBRSTK)
        ST       SBRPTR(P2)
        LDI      L(FORSTK)                                    
        ST       FORPTR(P2)
        LDE
        JZ       INSAD0           ;DON'T NEED TO MOVE LINES
        JP       INSUP0           ;SKIP IF DISP.  POSITIVE
ADOWN:  LD       0(P1)            ; NEGATIVE DISPLACEMENT:
        ST       E(P1)         ;DO;
        LD       @1(P1)           ;    M(P1+DISP)  = M(P1);
        JP       ADOWN            ;    P1 = Pl+1;
        LD       0(P1)            ;UNTIL M(P1)<0 & M(P1-1)<0;
        JP       ADOWN
        ST       E(P1)         ;M(P1+DISP) = M(P1);
        JMP      INSAD0
INSUP0: LD       -2(P1)           ;POSITIVE DISPLACEMENT:
        ST       TEMP(P2)         ;FLAG BEGINNING OF MOVE WITH
        LDI      -1               ;  A -1 FOLLOWED BY 30,  WHICH
        ST       -2(P1)           ;  CAN NEVER APPEAR IN A
        LDI      80               ;  NIBL TEXT
        ST       -1(P1)
INSUP1: LD       @1(P1)          ; ADVANCE P1 TO END OF TEXT
        JP       INSUP1
        LD       0(P1)
        JP       INSUP1
        XPAH     P1              ;SAVE P1 IN LO, HI
        ST       HI(P2)
        XPAH     P1   
        XPAL     P1
        ST       LO(P2)
        XPAL     P1
        LD       LO(P2)          ;ADD DISPLACEMENT TO
        CCL                      ;VALUE OF P1, TO CHECK
        ADE                      ;WHETHER WE'RE OUT OF
        LDI     0                ;RAM FOR USER'S PROGRAM
        ADD     HI(P2)
        XOR     HI(P2)
        ANI     0xF0
        JZ      INSUP2
        LDI     0                ;IF OUT OF RAM,  CHANGE
        XAE                      ;  DISPLACEMENT TO ZERO
INSUP2: LDI     -1
INSUP3: ST      E(P1)         ;MOVE TEXT UP UNTIL WE REACH
        LD      @-1(P1)          ;  THE FLAGS SET ABOVE
        JP      INSUP3
        LD      1(P1)
        XRI     80
        JZ      INSUP4
        LD      0(P1)
        JMP     INSUP3
INSUP4: LD      TEMP(P2)         ;RESTORE THE FLAGGED LOCATION
        ST      0(P1)            ;  TO THEIR ORIGINAL VALUES
        LDI     0x0D
        ST      1(P1)
        LDE                     ;IF DISPLACEMENT = 0,  WE'RE
        JNZ     INSAD0          ;  OUT OF RAM,  SO REPORT ERROR
        LDI     2
E12A:   JMP     E12
INSAD0: LD      CHRNUM(P2)      ;INSERT NEW LINE
X19A:   JZ      X19             ;  UNLESS LENGTH IS ZERO
        LD      P1L0W(P2)       ;POINT P1 AT LINE BUFFER
        XPAL    P1
        LD      P1HIGH(P2)
        XPAH    P1
        LD      LABLLO(P2)      ;POINT P3 AT INSERTION PLACE
        XPAL    P3
        LD      LABLHI(P2)
        XPAH    P3
        LD      HILINE(P2)      ;PUT LINE NUMBER INTO TEXT
        ST      @1(P3)
        LD      LOLINE(P2)
        ST      @1(P3)
        LD      CHRNUM(P2)      ;STORE LINE LENGTH IN TEXT
        ST      @1(P3)
INSAD1: LD      @1(P1)          ;PUT REST OF CHARS
        ST      @1(P3)          ;  (INCLUDING OR)  INTO TEXT
        XRI     0x0D
        JNZ     INSAD1
        JMP     X19A            ;RETURN
X20:    JS      P3,EXECIL
E13:    JMP     E12A

;************************************
;*       POP ARITHMETIC STACK       *
;************************************
 
POPAE:  DLD     LSTK(P2)        ;THIS ROUTINE POP  THE  A. E.
        DLD     LSTK(P2)        ;STACK, AND PUTS  THE  RESULT
        XPAL    P3              ;INTO  LO(P2) AND  HI(P2)
        LDI     H(AESTK)
        XPAH    P3
        LD      (P3)
        ST      LO(P2)
        LD      1(P3)
        ST      HI(P2)
        JMP     X20

;*************************************
;*              UNTIL                *
;*************************************
UNTIL:  LD      DOPTR(P2)       ; CHECK  FOR DO-STACK  UNDERFLOW
        XAE
        LDE 
        XRI     L(DOSTAK)
        JNZ     UNTL1
        LDI     15
        JMP     E13                                         
UNTL1:  LD      LO(P2)          ; CHECK  FOR EXPRESSION  = 0
        OR      HI(P2)          ;<- CHANGED AFTER 12/17/76 TO 'ANI 01' (R.MARIN, JAN 2008)
        JZ      SREDO           ;IF ZERO, REPEAT DO-LOOP
        DLD     DOPTR(P2)       ;ELSE POP SAVE STACK
        DLD     DOPTR(P2)
        JMP     X20             ;CONTINUE TO NEXT  STMT
SREDO:  LDE                     ; POINT  P3 AT DO-STACK
        XPAL    P3
        LDI     H(DOSTAK)
        XPAH    P3
        LD      -1(P3)          ;LOAD P1 FROM DO STACK
        XPAH    P1
        LD      -2(P3)
        XPAL    P1              ; CURSOR NOW POINTS TO  FIRST
        JMP     X20             ;  STATEMENT OF DO-LOOP
 
;*************************************
;*     STORE INTO STATUS REGISTER    *
;*************************************
; THIS ROUTINE IMPLEMENTS THE STATEMENT:
;      'STAT' '='  REL-EXP
 
MOVESR:  LD      LO(P2)          ;LOW BYTE GOES TO STATUS
         ANI     0xF7            ;  BUT WITH IEN BIT CLEARED
         CAS
X21:     JMP     X20
E14:     JMP     E13

;*************************************
;*         STAT FUNCTION             *
;*************************************
STATUS: LDI     H(AESTK)
        XPAH    P3              ;POINT P3 AT AE STACK
        ILD     LSTK(P2)
        ILD     LSTK(P2)
        XPAL    P3
        CSA
        ST      -2(P3)          ;STATUS REG IS, LOW BYTE
        LDI     0
        ST      -1(P3)          ;ZERO IS HIGH BYTE
        JMP     X21

;*************************************
;*    MACHINE LANGUAGE SUBROUTINE    *
;*************************************
;  THIS ROUTINE IMPLEMENTS THE 'LINK' STATEMENT
 
CALLML: LD      HI(P2)          ;GET HIGH BYTE OF ADDRESS
        XPAH    P3
        LD      LO(P2)          ;GET LOW BYTE
        XPAL    P3              ;P3 -> USER'S ROUTINE
        LD      @-1(P3)         ;CORRECT P3
        XPPC    P3              ;CALL ROUTINE (PRAY IT WORKS)
        LDPI    P2,VARS         ;RESTORE RAM POINTER
        JMP     X21             ;RETURN

;*************************************
;*        SAVE DO LOOP ADDRESS       *
;*************************************
;  THIS ROUTINE IMPLEMENTS THE 'DO' STATEMENT.
 
SAVEDO: LD      DOPTR(P2)       ;CHECK FOR STACK OVERFLOW
        XRI     L(FORSTK)
        JNZ     SVDO1
        LDI     10
E15:    JMP     E14
SVDO1:  ILD     DOPTR(P2)
        ILD     DOPTR(P2)
        XPAL    P3
        LDI     H(DOSTAK)
        XPAH    P3              ;P3 -> TOP OF DO STACK
        XPAH    P1              ;SAVE CURSOR ON THE STACK
        ST      -1(P3)
        XPAH    P1
        XPAL    P1
        ST      -2(P3)
        XPAL    P1
X22:    JMP     X21

;*************************************
;*        TOP OF RAM FUNCTION        *
;*************************************
TOP:    LD      TEMP2(P2)       ;SET P3 TO POINT TO
        XPAH    P3              ;  START OF NIBL TEXT
        LD      TEMP3(P2)
        XPAL    P3
TOP0:   LD      (P3)            ;HAVE WE HIT END OF TEXT?
        JP      TOP1            ; NO - SKIP TO NEXT LINE
        JMP     TOP2            ; YES - PUT CURSOR ON STACK
TOP1:   LD      2(P3)           ;GET LENGTH OF LINE
        XAE
        LD      @E(P3)       ;SKIP TO NEXT LINE
        JMP     TOP0            ; GO CHECK FOR EOF
TOP2:   LD      @2(P3)          ; P3 := P3 + 2
        ILD     LSTK(P2)        ;SET PS TO STACK,  SAVING
        ILD     LSTK(P2)        ;  OLD P3 (WHICH CONTAINS TOP)
        XPAL    P3              ;  ON IT SOMEHOW
        XAE
        LDI     H(AESTK)
        XPAH    P3
        ST      -1(P3)
        LDE
        ST      -2(P3)
        JMP     X22

;*************************************
;*       SKIP TO NEXT NIBL LINE      *
;*************************************
IGNORE: LD      @1(P1)          ;SCAN TIL WE'RE PAST
        XRI     0x0D            ; CARRIAGE RETURN
        JNZ     IGNORE
        XPPC    P3

;*************************************
;*          MODULO FUNCTION          *
;*************************************
MODULO: LD      LSTK(P2)        ;THIS ROUTINE MUST  BE
        XPAL    P3              ;  IMMEDIATELY AFTER A
        LDI     H(AESTK)        ;  DIVIDE TO WORK CORRECTLY
        XPAH    P3
        LD      3(P3)           ;GET LOW BYTE OF REMAINDER
        ST      -2(P3)          ;PUT ON STACK
        LD      2(P3)           ;GET HIGH  BYTE  OF REMAINDER
        ST      -1(P3)          ;PUT ON STACK
X23:    JMP     X22
E16:    JMP     E15

;*************************************
;*          RANDOM FUNCTION          *
;*************************************
RANDOM: LDI     8               ;LOOP COUNTER FOR MULTIPLY
        ST      NUM(P2)
        LD      RNDX(P2)
        XAE
        LD      RNDY(P2)
        ST      TEMP2(P2)
LOOP9:  LD      RNDX(P2)        ;MULTIPLY  THE SEEDS BY 9
        CCL
        ADE
        XAE
        LD      RNDY(P2)
        CCL
        ADD     TEMP2(P2)
        ST      RNDY(P2)
        DLD     NUM(P2)
        JNZ     LOOP9
        LDE                     ;ADD 7 TO  SEEDS
        CCL
        ADI     7
        XAE
        LD      RNDY(P2)
        CCL
        ADI     7
        RR
        ST      RNDY(P2)
        ILD     RNDF(P2)        ;HAVE WE GONE THROUGH
        JZ      RND1            ;  256 GENERATIONS?
        LDE                     ;IF SO,  SKIP GENERATING
        ST      RNDX(P2)        ;  THE NEW  RNDX
RND1:   LD      LSTK(P2)        ;START MESSING WITH THE STACK
        XPAL    P3
        LDI     H(AESTK)
        XPAH    P3
        LDI     1               ;FIRST PUT 1 ON STACK
        ST      (P3)
        LDI     0
        ST      1(P3)
        LD      -2(P3)           ;PUT EXPR2 ON STACK
        ST      2(P3)
        LD      -1(P3)
        ST      3(P3)
        LD      -4(P3)           ;PUT EXPR1 ON STACK
        ST      4(P3)
        LD      -3(P3)
        ST      5(P3)
        LD      RNDY(P2)         ;PUT RANDOM # ON STACK
        ST      -2(P3)
        LD      RNDX(P2)
        XRI     0xFF
        ANI     0x7F
        ST      -1(P3)
        LD      @6(P3)           ; ADD 6 TO STACK POINTER
        XPAL    P3
        ST      LSTK(P2)
X24:    JMP     X23
E16A:   JMP     E16

;*************************************
;*     PU3H 1 ON ARITHMETIC STACK    *
;*************************************
LIT1:   ILD     LSTK(P2)
        ILD     LSTK(P2)
        XPAL    P3
        LDI     H(AESTK)
        XPAH    P3
        LDI     0
        ST      -1(P3)
        LDI     1
        ST      -2(P3)
        JMP     X24

;*************************************
;*      FOR-LOOP INITIALIZATION      *
;*************************************
SAVFOR: LD       FORPTR(P2)    ; CHECK FOR FOR STACK
        XRI      L(PCSTAK)     ;  OVERFLOW
        JNZ      SFOR1
        LDI      10
E17:    JMP      E16A
SFOR1:  XRI      L(PCSTAK)
        XPAL     P1            ; POINT P1 AT FOR STACK
        ST       P1L0W(P2)     ; SAVING OLD P1
        LDI      H(FORSTK)
        XPAH     P1
        ST       P1HIGH(P2)
        LD       LSTK(P2)      ; POINT P2 AT AE STACK
        XPAL     P3
        LDI      H(AESTK)
        XPAH     P3
        LD       -7(P3)        ;GET  VARIABLE INDEX
        ST       @1(P1)        ;SAVE ON  FOR-STACK
        LD       -4(P3)        ;GET  L(LIMIT)
        ST       @1(P1)        ;SAVE
        LD       -3(P3)        ;GET  H(LIMIT)
        ST       @1(P1)        ;SAVE
        LD       -2(P3)        ;GET  L(STEP)
        ST       @1(P1)        ;SAVE
        LD       -1(P3)        ;GET  H(STEP)
        ST       @1(P1)        ;SAVE
        LD       P1L0W(P2)     ;GET  L(P1)
        ST       @1(P1)        ;SAVE
        LD       P1HIGH(P2)    ;GET  H(P1)
        ST       @1(P1)        ;SAVE
        XPAH     P1            ;RESTORE  OLD P1
        LD       P1L0W(P2)
        XPAL     P1
        ST       FORPTR(P2)    ;UPDATE POR STACK PTR
        LD       @-4(P3)
        XPAL     P3
        ST       LSTK(P2)      ;UPDATE AE STACK  PTR
X25:    JMP      X24

;*************************************
;*    FIRST PART OF  'NEXT VAR'      *
;*************************************
NEXTV:  LD       FORPTR(P2)     ;POINT P1 AT FOR  STACK,
        XRI      L(FORSTK)      ; CHECKING FOR UNDERFLOW
        JNZ      QNXTV1
        LDI      11             ;REPORT ERROR
        JMP      E17
QNXTV1: XRI      L(FORSTK)
        XPAL     P1
        ST       P1L0W(P2)      ;SAVE OLD P1
        LDI      H(FORSTK)
        XPAH     P1
        ST       P1HIGH(P2) 
        LD       LSTK(P2)       ;POINT P3 AT AE STACK
        XPAL     P3
        LDI      H(AESTK)
        XPAH     P3
        LD       @-1(P3)        ;GET  VARIABLE  INDEX
        XOR      -7(P1)         ;COMPARE  WITH  INDEX
        JZ       NXTV10         ; ON  FOR  STACK: ERROR
        LDI      12             ; IF NOT EQUAL
E18:    JMP      E17
NXTV10: XOR      -7(P1)         ;RESTORE  INDEX
        XAE                     ;SAVE IN  E
        LD      E(P2)        ;GET L(VARIABLE)
        CCL          
        ADD     -4(P1)          ;ADD L(STEP)
        ST      E(P2)        ;STORE  IN VARIABLE
        ST      (P3)            ;  AND ON STACK
        LD      @1(P2)          ; INCREMENT RAM PTR
        LD      E(P2)        ;GET H(VARIABLE)
        ADD     -3(P1)          ;ADD H(STEP)
        ST      E(P2)        ; STORE  IN VARIABLE
        ST      1(P3)           ;  AND ON STACK
        LD      @-1(P2)         ; RESTORE RAM POINTER
        LD      -6(P1)          ;GET L(LIMIT)
        ST      2(P3)           ;PUT ON STACK
        LD      -5(P1)          ;GET H(LIMIT)
        ST      3(P3)           ;PUT ON STACK
        LD      -3(P1)          ;GET H(STEP)
        JP      NXTV2           ; IF NEGATIVE, INVERT
        LDI     4               ;  ITEMS ON A. E.  STACK
        ST      NUM(P2)         ;NUM = LOOP  COUNTER
LOOP10: LD      @1(P3)          ;GET BYTE FROM STACK
        XRI     0xFF            ; INVERT IT
        ST      -1(P3)          ;PUT BACK ON STACK
        DLD     NUM(P2)         ; DO UNTIL NUM = 0
        JNZ     LOOP10
        JMP     NXTV3
NXTV2:  LD      @4(P3)          ;UPDATE AE STACK POINTER
NXTV3:  XPAL    P3
        ST      LSTK(P2)
        LD      P1L0W(P2)       ; RESTORE OLD P1
        XPAL    P1
        LD      P1HIGH(P2)
        XPAH    P1
X26:    JMP     X25

;*************************************
;*     SECOND PART OF 'NEXT VAR'     *
;*************************************
NEXTV1: LD      LO(P2)        ;IS FOR-LOOP  OVER WITH?
        JZ      X_REDO        ;N0 - REPEAT LOOP
        LD      FORPTR(P2)    ;YES - POP FOR-STACK
        CCL
        ADI     -7
        ST      FORPTR(P2)
        XPPC    P3            ; RETURN TO I.L. INTERPRETER
X_REDO: LD      FORPTR(P2)    ; POINT P3 AT FOR STACK
        XPAL    P3                                            
        LDI     H(FORSTK)
        XPAH    P3                              
        LD      -1(P3)        ;GET OLD P1 OFF STACK
        XPAH    P1
        LD      -2(P3)
        XPAL    P1
        JMP     X26
E19:    JMP     E18

;************************************
;*      PRINT MEMORY AS STRING      *
;************************************
 
;  THIS ROUTINE IMPLEMENTS THE STATEMENT:
;      'PRINT' '$' FACTOR
 
PSTRNG: LD      HI(P2)          ;POINT P1 AT STRING TO PRINT
        XPAH    P1
        LD      LO(P2)
        XPAL    P1
        LDPI    P3,PUTC-1       ;POINT P3 AT PUTC ROUTINE
PRSTR1: LD      @1(P1)          ;GET A CHARACTER
        XRI     0x0D            ;IS IT A CARRIAGE RETURN?
        JZ      X26             ;YES - WE'RE DONE
        XRI     0x0D            ;NO - PRINT THE CHARACTER
        XPPC    P3
        CSA                     ;MAKE SURE NO ONE IS
        ANI     0x20            ;TYPING ON THE TTY
        JNZ     PRSTR1          ;BEFORE REPEATING LOOP
        JMP     X26

;************************************
;*        INPUT A STRING            *
;************************************
 
;  THIS ROUTINE IMPLEMENTS THE STATEMENT:
;       'INPUT' '$' FACTOR
 
ISTRNG: LD      HI(P2)          ;GET ADDRESS TO STORE THE
        XPAH    P3              ;  STRING,  PUT IT INTO P3
        LD      LO(P2)
        XPAL    P3
INPST2: LD      @1(P1)          ;GET A BYTE FROM LINE BUFFER
        ST      @1(P3)          ;PUT IT IN SPECIFIED LOCATION
        XRI     0x0D            ;DO UNTIL CHAR = CARR.  RETURN
        JNZ     INPST2
X27:    JMP     X26

;************************************
;*   STRING CONSTANT ASSIGNMENT     *
;************************************
 
;  THIS ROUTINE IMPLEMENTS THE STATEMENT:
;       '$'  FACTOR  '=' STRING
         
PUTSTR: LD      LO(P2)          ;GET ADDRESS TO STORE STRING,
        XPAL    P3              ;  PUT IT INTO P3
        LD      HI(P2)
        XPAH    P3
LOOP11: LD      @1(P1)         ;GET A BYTE FROM STRING
        XRI     '"'            ;CHECK FOR END OF STRING
        JZ      STREND
        XRI     '"' | 0x0D     ;MAKE SURE THERE'S NO CR
        JNZ     PTSTR1
        LDI     7
        JMP     E19            ;ERROR IF CARRIAGE RETURN
PTSTR1: XRI     0x0D           ;RESTORE CHARACTER
        ST      @1(P3)         ;PUT IN SPECIFIED LOCATION
        JMP     LOOP11         ;GET NEXT CHARACTER
STREND: LDI     0x0D           ;APPEND CARRIAGE RETURN
        ST      (P3)           ;  TO STRING
        JMP     X27

;************************************
;*           MOVE STRING            *
;************************************
 
;  THIS  ROUTINE  IMPLEMENTS  THE  STATEMENT:
;       '$' FACTOR  '='  '$' FACTOR
 
MOVSTR: LD      LSTK(P2)        ; POINT P3 AT A. E.  STACK
        XPAL    P3
        LDI     H(AESTK)
        XPAH    P3
        LD      @-1(P3)         ;GET ADDRESS OF SOURCE STRING
        XPAH    P1              ;  INTO P1
        LD      @-1(P3)
        XPAL    P1
        LD      @-1(P3)         ;GET ADDRESS OF DESTINATION
        XAE                     ;  STRING INTO P3
        LD      @-1(P3)
        XPAL    P3
        ST      LSTK(P2)        ;UPDATE STACK POINTER
        LDE
        XPAH    P3
LOOP12: LD      @1(P1)           ;GET A SOURCE CHARACTER
        ST      @1(P3)           ;SEND IT TO DESTINATION
        XRI     0x0D              ;REPEAT UNTIL CARRIAGE RET.
        JZ      X27
        CSA                      ;  OR KEYBOARD INTERRUPT
        ANI     0x20
        JNZ     LOOP12
        JMP     X27                                          
 
;************************************
;*    PUT PAGE NUMBER ON STACK      *
;************************************
 
PUTPGE:  ILD     LSTK(P2)
         ILD     LSTK(P2)
         XPAL    P3
         LDI     H(AESTK)
         XPAH    P3
         LD      PAGE(P2)
         ST      -2(P3)
         LDI     0
         ST      -1(P3)
         JMP     X27

;************************************
;*        ASSIGN NEW PAGE           *
;************************************
 
NUPAGE:  LD      LO(P2)         ;GET PAGE  #  FROM  STACK,
         ANI     7              ;GET  THE  LOW  3 BITS
         JNZ     NUPGE0         ;PAGE  0 BECOMES PAGE  1
         LDI     1
NUPGE0:  ST      PAGE(P2)
         XPPC    P3             ; RETURN
 
;*************************************
;*         FIND START OF PAGE        *
;*************************************
;  THIS ROUTINE COMPUTES THE START OF THE CURRENT TEXT PAGE,
;  STORING THE ADDRESS IN TEMP2(P2) [THE HIGH BYTE], AND
;  TEMP3(P2) [THE LOW BYTE].
 
FNDPGE:  LD      PAGE(P2)
         XRI     1               ;SPECIAL CASE IS PAGE 1, BUT
         JNZ     FPGE1           ;OTHERS ARE CONVENTIONAL
         LDI     H(PGM)          ;PAGE 1 STARTS AT 'PGM'
         ST      TEMP2(P2)
         LDI     L(PGM)
         ST      TEMP3(P2)
         XPPC    P3              ;RETURN
FPGE1:   XRI     1               ;RESTORE PAGE  #
         XAE                     ;SAVE  IT
         LDI     4               ;LOOP  COUNTER  = 4
         ST      NUM(P2)
LOOP13:  LDE                     ; MULTIPLY  PAGE# BY  16
         CCL                                 
         ADE
         XAE
         DLD     NUM(P2)
         JNZ     LOOP13
         LDE
         ST      TEMP2(P2)       ;TEMP2 HAS HIGH BYTE
         LDI     2               ;  OF ADDRESS NOW
         ST      TEMP3(P2)       ;LOW BYTE IS ALWAYS 2
         XPPC    P3

;************************************
;*      MOVE CURSOR TO NEW PAGE     *
;************************************
 
CHPAGE: LD      TEMP2(P2)       ;PUT START OF PAGE
        XPAH    P1              ;  INTO P1.   THIS ROUTINE
        LD      TEMP3(P2)       ;  MUST BE CALLED RIGHT
        XPAL    P1              ;  AFTER 'FNDPGE'
        XPPC    P3              ; RETURN

;************************************
;*      DETERMINE CURRENT PAGE      *
;************************************
 
DETPGE: XPAH    P1              ;CURRENT PAGE IS HIGH
        XAE                     ;  PART OF CURSOR DIVIDED
        LDE                     ;  BY 16
        XPAH    P1
        LDE
        SR
        SR
        SR
        SR
        ST      PAGE(P2)
        XPPC    P3              ;RETURN

;************************************
;*         CLEAR CURRENT PAGE       *
;************************************
 
NEWPGM: LD      TEMP2(P2)       ;POINT P1 AT CURRENT PAGE
        XPAH    P1
        LD      TEMP3(P2)
        XPAL    P1
        LDI     0x0D            ;PUT DUMMY END-OF-LINE
        ST      -1(P1)          ;  JUST BEFORE TEXT
        LDI     -1              ;PUT -1 AT START OF TEXT
        ST      (P1)
        ST      1(P1)
        XPPC    P3              ;RETURN

;*************************************
;*      FIND LINE NUMBER IN TEXT     *
;*************************************
; INPUTS:  THE START OF THE CURRENT PAGE  IN TEMP2 AND TEMPS,
;          THE LINE NUMBER TO LOOK FOR  IN LO AND HI.
; OUTPUTS: THE ADDRESS OF THE FIRST LINE  IN THE NIBL TEXT
;          WHOSE LINE NUMBER IS GREATER THAN OR EQUAL TO THE
;          NUMBER IN HI AND LO,  RETURNED  IN P1 AND  ALSO IN
;          IN THE RAM VARIABLES LABLLO AND LABLHI.   THE SIGN
;          BIT OF LABLHI IS SET IF EXACT LINE  IS NOT FOUND.
        
FNDLBL: LD      TEMP2(P2)       ; POINT P1 AT START OF TEXT
        XPAH    P1
        LD      TEMP3(P2)
        XPAL    P1
FLBL1:  LD      (P1)            ;HAVE WE HIT END OF TEXT?
        XRI     0xFF
        JP      FLBL2           ;YES - STOP  LOOKING
        SCL                     ; NO - COMPARE LINE NUMBERS
        LD      1(P1)           ;  BY SUBTRACTING
        CAD     LO(P2)
        LD      0(P1)
        CAD     HI(P2)          ;IS TEXT LINE # >= LINE #?
        JP      FLBL2           ;YES - STOP  LOOKING.
        LD      2(P1)           ;NO - TRY NEXT LINE IN TEXT
        XAE
        LD      @E(P1)       ;  SKIP LENGTH OF  LINE
        JMP     FLBL1
FLBL2:  XPAL    P1              ;SAVE ADDRESS OF FOUND LINE
        ST      LABLLO(P2)      ;  IN LABLHI  AND LABLLO
        XPAL    P1
        XPAH    P1
        ST      LABLHI(P2)
        XPAH    P1
        LD      LO(P2)          ;WAS THERE AN EXACT MATCH?
        XOR     1(P1)
        JNZ     FLBL3
        LD      HI(P2)
        XOR     0(P1)
        JNZ     FLBL3           ;NO - FLAG THE ADDRESS
        XPPC    P3              ;YES - RETURN NORMALLY
FLBL3:  LD      LABLHI(P2)      ;SET SIGN BIT OF  HIGH PART
        ORI     0x80            ;  OF ADDRESS TO INDICATE
        ST      LABLHI(P2)      ;  INEXACT MATCH OF LINE #'S
        XPPC    P3
 
        
                     
;***********************************
;*       I. L.  MACROS             *
;***********************************
 
TSTBITH =        TSTBIT*256
CALBITH =        CALBIT*256
JMPBITH =        JMPBIT*256
 

TSTR     MACRO   FAIL,A,B 
         DB      H((FAIL & 0x0FFF)| TSTBITH)
         DB      L((FAIL & 0x0FFF)| TSTBITH)
         IFB     B
           DB    A |0x80 
         ELSE
           DB    A 
           DB    B |0x80
         ENDIF
         ENDM
 
TSTCR    MACRO   FAIL
         DB      H(FAIL & 0x0FFF | TSTBITH)
         DB      L(FAIL & 0x0FFF | TSTBITH)
         DB      0x0D|0x80
         ENDM
 
TSTV     MACRO   FAIL
         DB      H((TSTVAR-1) & 0x0FFF)
         DB      L((TSTVAR-1) & 0x0FFF)
         DB      H(FAIL)
         DB      L(FAIL)
         ENDM
 
TSTN     MACRO   FAIL
         DB      H((TSTNUM-1) & 0x0FFF)
         DB      L((TSTNUM-1) & 0x0FFF)
         DB      H(FAIL)
         DB      L(FAIL)
         ENDM
 
JUMP     MACRO   ADR
         DB      H(ADR & 0x0FFF  | JMPBITH)
         DB      L(ADR & 0x0FFF  | JMPBITH)
         ENDM
 
CALL     MACRO   ADR
         DB      H(ADR & 0x0FFF  | CALBITH)
         DB      L(ADR & 0x0FFF  | CALBITH)
         ENDM

DO       MACRO   ADR
         IFNB    ADR 
         DB      H((ADR-1) & 0x0FFF)
         DB      L((ADR-1) & 0x0FFF)
         SHIFT
         DO      ALLARGS
         ENDIF
         ENDM 

        
;*************************************
;*           I. L. TABLE             *
;*************************************
START:  DO       NLINE
PROMPT: DO       GETL
        TSTCR    PRMPT1
        JUMP     PROMPT
PRMPT1: TSTN     LIST
        DO       FNDPGE,XCHGP1,POPAE,FNDLBL,INSRT
        JUMP     PROMPT
 
LIST:   TSTR     RUN,"LIS",'T'
        DO       FNDPGE
        TSTN     LIST1
        DO       POPAE,FNDLBL
        JUMP     LIST2
LIST1:  DO       CHPAGE
LIST2:  DO       LST
LIST3:  CALL     PRNUM
        DO       LST3
        JUMP     START
RUN:    TSTR     CLR,"RU",'N'
        DO       DONE
BEGIN:  DO       FNDPGE,CHPAGE,STRT,NXT
CLR:    TSTR     NEW,"CLEA",'R'
        DO       DONE,CLEAR,NXT
NEW:    TSTR     STMT,"NE",'W'
        TSTN     DFAULT
        JUMP     NEW1
DFAULT: DO       LIT1
NEW1:   DO       DONE,POPAE,NUPAGE,FNDPGE,NEWPGM,NXT
STMT:   TSTR     LET,"LE",'T'
LET:    TSTV     AT
        TSTR     SYNTAX,'='
        CALL     RELEXP
        DO       STORE,DONE,NXT
AT:     TSTR     IF, '@'
        CALL     FACTOR
        TSTR     SYNTAX,'='
        CALL     RELEXP
        DO       MOVE,DONE,NXT
 
IF:     TSTR     UNT,"I",'F'
        CALL     RELEXP
        TSTR     IF1,"THE",'N'
IF1:    DO       POPAE,CMPR
        JUMP     STMT
                      
UNT:    TSTR    DOSTMT,"UNTI",'L'
        DO      CKMODE
        CALL    RELEXP
        DO      DONE,POPAE,UNTIL,DETPGE,NXT
 
DOSTMT: TSTR    GOTO,"D",'O'
        DO      CKMODE,DONE,SAVEDO,NXT
GOTO:   TSTR    RETURN,"G",'O'
        TSTR    GOSUB,"T",'O'
        CALL    RELEXP
        DO      DONE
        JUMP    TBL001
GOSUB:  TSTR    SYNTAX,"SU",'B'
        CALL    RELEXP
        DO      DONE,SAV
TBL001: DO      FNDPGE, POPAE,FNDLBL,XFER,NXT
 
RETURN: TSTR    NEXT,"RETUR",'N'
        DO      DONE,RSTR,DETPGE,NXT
NEXT:   TSTR    FOR,"NEX",'T'
        DO      CKMODE
        TSTV    SYNTAX
        DO      DONE,NEXTV
        CALL    GTROP
        DO      POPAE, NEXTV1,DETPGE,NXT
 
FOR:    TSTR    STAT,"FO",'R'
        DO      CKMODE
        TSTV    SYNTAX
        TSTR    SYNTAX,'='
        CALL    RELEXP
        TSTR    SYNTAX,"T",'O'
        CALL    RELEXP
        TSTR    FORI,"STE",'P'
        CALL    RELEXP
        JUMP    FOR2
FORI:   DO      LIT1
FOR2:   DO      DONE,SAVFOR,STORE,NXT
 
STAT:   TSTR    PGE,"STA",'T'
        TSTR    SYNTAX,'='
        CALL    RELEXP
        DO      POPAE,MOVESR
        DO      DONE,NXT
 
PGE:    TSTR    DOLLAR,"PAG",'E'
        TSTR    SYNTAX,'='
        CALL    RELEXP
        DO      DONE,POPAE,NUPAGE,FNDPGE,CHPAGE,NXT
 
DOLLAR: TSTR    PRINT,'$'
        CALL    FACTOR
        TSTR    SYNTAX,'='
        TSTR    DOLR1, '"'
        DO      POPAE,PUTSTR
        JUMP    DOLR2
DOLR1:  TSTR    SYNTAX,'$'
        CALL    FACTOR
        DO      XCHGP1,MOVSTR,XCHGP1
DOLR2:  DO      DONE,NXT
 
PRINT:  TSTR    INPUT,"P",'R'
        TSTR    PR1,"IN",'T'
PR1:    TSTR    PR2,'"'
        DO      PRS
        JUMP    COMMA
PR2:    TSTR    PR3,'$'
        CALL    FACTOR
        DO      XCHGP1,POPAE,PSTRNG,XCHGP1
        JUMP    COMMA
PR3:    CALL    RELEXP
        CALL    PRNUM
COMMA:  TSTR    PR4,','
        JUMP    PR1
PR4:    TSTR    PR5,';'
        JUMP    PR6
PR5:    DO      NLINE
PR6:    DO      DONE, NXT
INPUT:  TSTR    END,"INPU",'T'
        DO      CKMODE
        TSTV    IN2
        DO      XCHGP1,GETL
IN1:    CALL    RELEXP
        DO      STORE,XCHGP1
        TSTR    IN3,','
        TSTV    SYNTAX
        DO      XCHGP1
        TSTR    SYNTAX,','
        JUMP    IN1
IN2:    TSTR    SYNTAX,'$'
        CALL    FACTOR
        DO      XCHGP1,GETL,POPAE,ISTRNG,XCHGP1
IN3:    DO      DONE,NXT
 
END:    TSTR    ML,"EN",'D'
        DO      DONE,BREAK
 
ML:     TSTR    REM,"LIN",'K'
        CALL    RELEXP
        DO      DONE,XCHGP1,POPAE,CALLML,XCHGP1,NXT           
                                                              
REM:    TSTR    SYNTAX,"RE",'M'
        DO      IGNORE,NXT
 
SYNTAX: DO       ERR
ERRNUM: CALL     PRNUM
        DO       FIN
 
; NOTE: EACH RELATIONAL OPERATOR (EQ,  LEQ,  ETC. )  DOES AN
; AUTOMATIC 'RTN' (THIS SAVES VALUABLE BYTES AND TIME)
 
RELEXP: CALL     EXPR
        TSTR     REL1,'='
        CALL     EXPR
        DO       EQ
REL1:   TSTR     REL4,'<'
        TSTR     REL2,'='
        CALL     EXPR
        DO       LEQ
REL2:   TSTR     REL3,'>'
        CALL     EXPR
        DO       NEQ
REL3:   CALL     EXPR
        DO       LSS
REL4:   TSTR     RETEXP,'>'
        TSTR     REL5,'='
        CALL     EXPR
        DO       GEQ
REL5:   CALL     EXPR
GTROP:  DO       GTR
 
EXPR:   TSTR     EX1,'-'
        CALL     TERM
        DO       NEG
        JUMP     EX3
EX1:    TSTR     EX2,'+'
EX2:    CALL     TERM
EX3:    TSTR     EX4,'+'
        CALL     TERM
        DO       ADD
        JUMP     EX3
EX4:    TSTR     EX5,'-'
        CALL     TERM
        DO       SUB
        JUMP     EX3
EX5:    TSTR     RETEXP,"O",'R'
        CALL     TERM
        DO       OROP
        JUMP     EX3
RETEXP: DO       RTN
 
TERM:   CALL    FACTOR
Tl:     TSTR    T2,'*'
        CALL    FACTOR
        DO      MUL
        JUMP    Tl
T2:     TSTR    T3,'/'
        CALL    FACTOR
        DO      DIV  
        JUMP    Tl
T3:     TSTR    RETEXP,"AN",'D'
        CALL    FACTOR
        DO      ANDOP
        JUMP    Tl
 
FACTOR: TSTV     Fl
        DO       IND,RTN
Fl:     TSTN     F2
        DO       RTN
F2:     TSTR     F3,'#'
        DO       HEX,RTN
F3:     TSTR     F4,'('
        CALL     RELEXP
        TSTR     SYNTAX,')'
        DO       RTN
F4:     TSTR     F5,'@'
        CALL     FACTOR
        DO       EVAL,RTN
F5:     TSTR     F6,"NO",'T'
        CALL     FACTOR
        DO       NOTOP,RTN
F6:     TSTR     F7,"STA",'T'
        DO       STATUS,RTN
F7:     TSTR     F8,"TO",'P'
        DO       FNDPGE,TOP,RTN
F8:     TSTR     F9,"MO",'D'
        CALL     DOUBLE
        DO       DIV,MODULO,RTN
F9:     TSTR     F10,"RN",'D'
        CALL     DOUBLE
        DO       RANDOM,SUB,ADD,DIV,MODULO,ADD,RTN
F10:    TSTR     SYNTAX,"PAG",'E'
        DO       PUTPGE,RTN
 
DOUBLE: TSTR     SYNTAX,'('
        CALL     RELEXP
        TSTR     SYNTAX,','
        CALL     RELEXP
        TSTR     SYNTAX,')'
        DO       RTN
 
PRNUM:  DO       XCHGP1,PRN
PRNUM1: DO       DIV,PRN1,XCHGP1,RTN

 
;*************************************
;*           ERROR MESSAGES          *
;*************************************
MESSAGE  MACRO A,B
          DB  A
          DB  B |0x80
         ENDM
 
MESGS:  MESSAGE " ERRO",'R'   ;  1
        MESSAGE "ARE",'A'     ;  2
        MESSAGE "STM",'T'     ;  3
        MESSAGE "CHA",'R'     ;  4
        MESSAGE "SNT",'X'     ;  5
        MESSAGE "VAL",'U'     ;  6
        MESSAGE "END",'"'     ;  7
        MESSAGE "NOG",'O'     ;  8
        MESSAGE "RTR",'N'     ;  9
        MESSAGE "NES",'T'     ;  10
        MESSAGE "NEX",'T'     ;  11
        MESSAGE "FO" ,'R'     ;  12
        MESSAGE "DIV",'0'     ;  13
        MESSAGE "BR" ,'K'     ;  14
        MESSAGE "UNT",'L'     ;  15
        ;
 
;*************************************
;*     GET CHARACTER AND ECHO IT     *
;*************************************
GECO:   LDI     8               ;SET COUNT = 8
        ST      NUM(P2)
        CSA                     ;SET READER RELAY
        ORI     2
        CAS
GETCO1: CSA                     ;WAIT FOR START BIT
        ANI     0x20
        JNZ     GETCO1          ;NOT FOUND
        LDI     0x3D            ; DELAY 1/2 BIT TIME    -jsl 0xC3=110bps, 0x29=300bps, 0x8A=600bps, 0xBB=1200bps, 0x3D=2400bps
        DLY     0x00            ;                       -jsl 0x08=110bps, 0x03=300bps, 0x01=600bps, 0x00=1200bps, 0x00=2400bps
        CSA                     ; IS START BIT STILL THERE?
        ANI     0x20
        JNZ     GETCO1          ; NO
        CSA                     ;SEND START BIT
        ANI     0xFD            ; RESET READER RELAY
        ORI     1
        CAS
GETCO2: LDI     0x76            ; DELAY 1 BIT TIME      -jsl 0x45=110bps, 0x11=300bps, 0xD4=600bps, 0x34=1200bps, 0x76=2400bps
        DLY     0x00            ;                       -jsl 0x11=110bps, 0x06=300bps, 0x02=600bps, 0x01=1200bps, 0x00=2400bps
        CSA                     ;GET BIT (SENSED)
        ANI     0x20
        JZ      GETCO3
        LDI     1
        JMP     GETCO4
GETCO3: LDI     0
        JNZ     GETCO4
GETCO4: ST      TEMP(P2)        ;SAVE BIT VALUE (0 OR 1)
        RRL                     ;ROTATE INTO LINK
        XAE
        SRL                     ; SHIFT INTO CHARACTER
        XAE                     ; RETURN CHAR TO E
        CSA                     ;ECHO BIT TO OUTPUT
        ORI     1
        XOR     TEMP(P2)
        CAS
        DLD     NUM(P2)         ;DECREMENT BIT COUNT
        JNZ     GETCO2          ;LOOP UNTIL 0
        CSA                     ;SET STOP BIT
        ANI     0xFE
        CAS
        DLY     0x02            ; DELAY APPROX. 1 BIT TIME -jsl 0x11=110bps, 0x06=300bps, 0x03=600bps, 0x01=1200bps, 0x02=2400bps
        LDE                     ; AC HAS INPUT CHARACTER
        ANI     0x7F
        XAE
        LDE
        XPPC    P3              ;RETURN
        JMP     GECO
        
;*************************************
;*     PRINT CHARACTER  AT  TTY      *
;*************************************
PUTC:   XAE
        LDI     0x86             ; DELAY ALMOST         -jsl 0xBB=110bps, 0x6C=300bps, 0x2D=600bps, 0x99=1200bps, 0x86=2400bps
        DLY     0x01             ; 3  BIT  TIMES        -jsl 0x2F=110bps, 0x06=300bps, 0x03=600bps, 0x01=1200bps, 0x01=2400bps
        CSA                      ; SET OUTPUT  BIT  TO  LOGIC  0
        ORI     1                ; FOR START  BIT
        CAS
        LDI     9                ; INITIALIZE BIT COUNT
        ST      TEMP3(P2)
PUTC1:  LDI     0x81             ; DELAY 1 BIT TIME     -jsl 0x54=110bps, 0x21=300bps, 0xE5=600bps, 0x44=1200bps, 0x81=2400bps
        DLY     0x00             ;                      -jsl 0x11=110bps, 0x06=300bps, 0x02=600bps, 0x01=1200bps, 0x00=2400bps  
        DLD     TEMP3(P2)        ; DECREMENT BIT COUNT
        JZ      PUTC2
        LDE                      ; PREPARE NEXT BIT
        ANI     1
        ST      TEMP2(P2)
        XAE
        SR
        XAE
        CSA                      ; SET UP OUTPUT BIT
        ORI    1
        XOR    TEMP2(P2)
        CAS                      ; PUT BIT INTO TTY
        JMP    PUTC1
PUTC2:  CSA                      ; SET STOP BIT
        ANI    0xFE
        CAS
        XPPC   P3  
        JMP    PUTC
        
        END   0
