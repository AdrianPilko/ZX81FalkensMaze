;;; Falkens Maze game for zx81, can run in 1k ram
;;; by Adrian Pilkington March 2023

;; game title inspired by the film Wargames (1983)
;; "A strange game. The only winning move is not to play"

;some #defines for compatibility with other assemblers
#define         DEFB .byte 
#define         DEFW .word
#define         EQU  .equ
#define         ORG  .org

;; note if assembling with intension of running in an emulator the timings are different
;; at least on my PAL TV zx81, it runs slower on real zx81, so comment in this #defines to 
;; alter delay timings

#define RUN_ON_EMULATOR


;;;;;#define DEBUG_NO_SCROLL

; keyboard port for shift key to v
#define KEYBOARD_READ_PORT_SHIFT_TO_V $FE
; keyboard space to b
#define KEYBOARD_READ_PORT_SPACE_TO_B $7F 
; starting port numbner for keyboard, is same as first port for shift to v
#define KEYBOARD_READ_PORT $FE 

#define PLAYER_CHARACTER 187
#define SPACE_CHARACTER 0
#define MAZE_CHARACTER 128
#define SCREEN_WIDTH 9
#define SCREEN_HEIGHT 18

; character set definition/helpers
__:				EQU	$00	;spacja
_QT:			EQU	$0B	;"
_PD:			EQU	$0C	;funt 
_SD:			EQU	$0D	;$
_CL:			EQU	$0E	;:
_QM:			EQU	$0F	;?
_OP:			EQU	$10	;(
_CP:			EQU	$11	;)
_GT:			EQU	$12	;>
_LT:			EQU	$13	;<
_EQ:			EQU	$14	;=
_PL:			EQU	$15	;+
_MI:			EQU	$16	;-
_AS:			EQU	$17	;*
_SL:			EQU	$18	;/
_SC:			EQU	$19	;;
_CM:			EQU	$1A	;,
_DT:			EQU	$1B	;.
_NL:			EQU	$76	;NEWLINE

_0				EQU $1C
_1				EQU $1D
_2				EQU $1E
_3				EQU $1F
_4				EQU $20
_5				EQU $21
_6				EQU $22
_7				EQU $23
_8				EQU $24
_9				EQU $25
_A				EQU $26
_B				EQU $27
_C				EQU $28
_D				EQU $29
_E				EQU $2A
_F				EQU $2B
_G				EQU $2C
_H				EQU $2D
_I				EQU $2E
_J				EQU $2F
_K				EQU $30
_L				EQU $31
_M				EQU $32
_N				EQU $33
_O				EQU $34
_P				EQU $35
_Q				EQU $36
_R				EQU $37
_S				EQU $38
_T				EQU $39
_U				EQU $3A
_V				EQU $3B
_W				EQU $3C
_X				EQU $3D
_Y				EQU $3E
_Z				EQU $3F


;;;; this is the whole ZX81 runtime system and gets assembled and 
;;;; loads as it would if we just powered/booted into basic

           ORG  $4009             ; assemble to this address
                                                                
VERSN:          DEFB 0
E_PPC:          DEFW 2
D_FILE:         DEFW Display
DF_CC:          DEFW Display+1                  ; First character of display
VARS:           DEFW Variables
DEST:           DEFW 0
E_LINE:         DEFW BasicEnd 
CH_ADD:         DEFW BasicEnd+4                 ; Simulate SAVE "X"
X_PTR:          DEFW 0
STKBOT:         DEFW BasicEnd+5
STKEND:         DEFW BasicEnd+5                 ; Empty stack
BREG:           DEFB 0
MEM:            DEFW MEMBOT
UNUSED1:        DEFB 0
DF_SZ:          DEFB 2
S_TOP:          DEFW $0002                      ; Top program line number
LAST_K:         DEFW $fdbf
DEBOUN:         DEFB 15
MARGIN:         DEFB 55
NXTLIN:         DEFW Line2                      ; Next line address
OLDPPC:         DEFW 0
FLAGX:          DEFB 0
STRLEN:         DEFW 0
T_ADDR:         DEFW $0c8d
SEED:           DEFW 0
FRAMES:         DEFW $f5a3
COORDS:         DEFW 0
PR_CC:          DEFB $bc
S_POSN:         DEFW $1821
CDFLAG:         DEFB $40
MEMBOT:         DEFB 0,0 ;  zeros
UNUNSED2:       DEFW 0

Line1:          DEFB $00,$0a                    ; Line 10
                DEFW Line1End-Line1Text         ; Line 10 length
Line1Text:      DEFB $ea                        ; REM
    
firstTimeInit
    ld a, 1
    ld (Score), a    
    ld a, 9
    ld (BombsLeft), a
initVariables
    ld bc,56
	ld de,blankText
	call printstring
    
    ;; some variable initialisation
    ld hl, (DF_CC)
    ld de, 11
    add hl, de
    ld (playerPosAbsolute), hl

    ld a, PLAYER_CHARACTER
    ld hl, (playerPosAbsolute)
    ld (hl), a
    
    ld a, 1
    ld (playerRowPosition), a
    xor a
    ld (playerColPosition), a
    
    call filePlayArea
    call initialiseMaze

    xor a
    ld (firstTime), a
    
    ld a, (Score)
    dec a
    daa
    ld (Score), a
gameLoop    
    ld a, (firstTime)
    cp 1
    jp z, firstTimeInit

    ;; read keys
    ld a, KEYBOARD_READ_PORT_SHIFT_TO_V			
    in a, (KEYBOARD_READ_PORT)					; read from io port	
    bit 1, a                            ; Z
    jp z, drawLeft

    ld a, KEYBOARD_READ_PORT_SPACE_TO_B			
    in a, (KEYBOARD_READ_PORT)					; read from io port		
    bit 2, a						    ; M
    jp z, drawRight							    ; jump to move shape right	

    ld a, KEYBOARD_READ_PORT_SPACE_TO_B			
    in a, (KEYBOARD_READ_PORT)					; read from io port		
    bit 3, a					        ; N
    jp z, drawDown

    ld a, KEYBOARD_READ_PORT_SPACE_TO_B			
    in a, (KEYBOARD_READ_PORT)					; read from io port		
    bit 4, a					        ; B - drop bomb
    jp z, dropBomb

    
    jp checkCollision
    
drawLeft    
    ld a, (playerColPosition) 
    cp 0
    jp z, afterCheckLeft
    dec a
    ld (playerColPosition), a
    
    call erasePlayer
    ld hl, (playerPosAbsolute)
    dec hl
    ld (playerPosAbsolute), hl
afterCheckLeft    
    jp checkCollision        
    
drawRight    
    ld a, (playerColPosition) 
    cp SCREEN_WIDTH
    jp z, afterCheckRight
    inc a
    ld (playerColPosition), a

    call erasePlayer
    ld hl, (playerPosAbsolute)
    inc hl
    ld (playerPosAbsolute), hl        
afterCheckRight
    jp checkCollision    
drawDown    
    call erasePlayer
    ld hl, (playerPosAbsolute)
    ld de, 11
    add hl, de
    ld (playerPosAbsolute), hl
    ld a, (playerRowPosition)
    inc a
    ld (playerRowPosition), a
    ld a, (Score)
    inc a
    daa 
    ld (Score),a 
    jp checkCollision
dropBomb
    ld a, (BombsLeft)
    cp 0
    jp z, checkCollision
    xor a
    ld hl, (playerPosAbsolute)
    push hl    
    inc hl    
    ld (hl), a
    pop hl
    dec hl
    ld (hl), a
    
    ld a, (BombsLeft)
    dec a
    daa
    ld (BombsLeft), a
    call waitLoop
    
    jp checkCollision


checkCollision
    scf
    ld hl, (playerPosAbsolute)
    ld a, (hl)
    cp MAZE_CHARACTER
    jp z, hitGameOver 
    ld a, (playerRowPosition)
    cp 21
    jp z, playerWon    
    
    ld hl, (DF_CC)
    ld de, 248
    add hl, de  
    push hl    ; store
    
    ld a, (Score)
    
    ;;;;;;;;;;; print score
    push af ;store the original value of a for later
    and $f0 ; isolate the first digit
    rra
    rra
    rra
    rra
    add a,$1c ; add 28 to the character code
    ld (hl), a
    inc hl
    pop af ; retrieve original value of a
    and $0f ; isolate the second digit
    add a,$1c ; add 28 to the character code
    ld (hl), a      

    pop hl     
    ld de, 10
    add hl, de  

    ld a, (BombsLeft)    
    and $0f ; isolate the second digit
    add a,$1c ; add 28 to the character code
    ld (hl), a      
    
    jp drawPlayer    
    
erasePlayer
    ld a, SPACE_CHARACTER
    ld hl, (playerPosAbsolute)
    ld (hl), a
    ret

drawPlayer
    ld a, PLAYER_CHARACTER
    ld hl, (playerPosAbsolute)
    ld (hl), a
    
    call waitLoop
    jp gameLoop    

hitGameOver
    ld a, PLAYER_CHARACTER      ; draw player one last time
    ld hl, (playerPosAbsolute)
    ld (hl), a

	ld bc,57
	ld de,youLostText    
    call printstring
    ld a, 1                 ;; reset score
    ld (Score), a   
    ld a, 9                 ;; reset bomb counter
    ld (BombsLeft), a    
    
#ifdef RUN_ON_EMULATOR
    ld e, 20 
#else
    ld e, 15 
#endif        
    
waitPlayerOver           
    call waitLoop   
    dec e
    jp nz, waitPlayerOver
    jp initVariables
    ;; never gets to here
   
playerWon    
    ld a, PLAYER_CHARACTER      ; draw player one last time
    ld hl, (playerPosAbsolute)
    ld (hl), a

	ld bc,57
	ld de,youWonText
	call printstring   
    
#ifdef RUN_ON_EMULATOR
    ld e, 20 
#else
    ld e, 15 
#endif   
waitPlayerWon     
    call waitLoop   
    dec e
    jp nz, waitPlayerWon
    
    jp initVariables
    ;; never gets to here

filePlayArea
    ld hl, (DF_CC)
    ld de, 22
    add hl, de  
    ld b, 19    ;; loop for 20 rows
outerFilePlayArea                          ; generate random number for col    
    push bc
    ld b, 10
innerFilePlayArea     
    ld a, MAZE_CHARACTER         ; set block
    ld (hl), a
    inc hl    
    djnz innerFilePlayArea
    
    inc hl      ; this extra inc to get past the end of line 
    pop bc
    djnz outerFilePlayArea
    ret 
 
    
initialiseMaze    

    ld hl, (DF_CC)
    ld de, 23
    add hl, de
    
    ld b, 19    ;; loop for 20 rows
    
loopForRowsMazeInit                          ; generate random number for col    
    push bc
    ld b, 8
loopForColMazeInit
    push bc
    ld b, 4
    call rnd    
    cp 1
    jp z, clearBlockNorth   
    cp 2
    jp z, clearBlockSouth    
    cp 3
    jp z, clearBlockEast        
    cp 4
    jp z, clearBlockWest    
    ;cp 5
    ;jp z, clearBlockCurrent
    ;; should never get here
    jp nextInnerLoopMazeInit

clearBlockNorth
    push hl
    ld de, 11
    ld hl, (DF_CC)
    sbc hl, de    
    ld a, 136         ; clear block    
    ld (hl), a
    pop hl
    jp nextInnerLoopMazeInit
    
clearBlockSouth
    push hl
    ld de, 11
    ld hl, (DF_CC)
    add hl, de    
    ld a, 136         ; clear block    
    ld (hl), a
    pop hl
    
    ld a, 136         ; clear block 
    ld (hl), a
    jp nextInnerLoopMazeInit
clearBlockEast    
    push hl
    dec hl
    ld a, 136         ; clear block    
    ld (hl), a
    pop hl
    jp nextInnerLoopMazeInit
clearBlockWest
    push hl
    inc hl
    ld a, 136         ; clear block    
    ld (hl), a
    pop hl
    ld a, 136         ; clear block 
    ld (hl), a    
    jp nextInnerLoopMazeInit

nextInnerLoopMazeInit

;clearBlockCurrent    
;    ld a, 33         ; clear block    
;    ld (hl), a
    
    inc hl
    
    pop bc
    djnz loopForColMazeInit
    
    inc hl      ; this extra inc to get past the end of line
    inc hl
    inc hl   
    pop bc
    
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    
    
    djnz loopForRowsMazeInit
       
    ret
  
    
waitLoop
#ifdef RUN_ON_EMULATOR
    ld bc, $0fff     ; set wait loop delay for emulator
#else
    ld bc, $0eff     ; set wait loop delay 
#endif    
waitloop1
    dec bc
    ld a,b
    or c
    jr nz, waitloop1
    ret
        
; this prints at to any offset (stored in bc) from the top of the screen Display, using string in de
printstring
    ld hl,Display
    add hl,bc	
printstring_loop
    ld a,(de)
    cp $ff
    jp z,printstring_end
    ld (hl),a
    inc hl
    inc de
    jr printstring_loop
printstring_end	
    ret  

;;;adapted from file:///C:/Users/computer/Downloads/Game_52%20Weedkiller%20(4).pdf
rnd     
    push hl
    push bc
    push de
    ld hl,(FRAMES) 
rseed 
    ld de,0
    add hl,de
    dec hl
    ld a,h
    and $1f
    ld h,a
    ld (rseed+1),hl
    ld a,(hl)
frnd 
    sub b
    jr nc,frnd
    adc a,b  
    pop de
    pop bc
    pop hl
    ret 

    
                DEFB $76                        ; Newline        
Line1End
Line2			DEFB $00,$14
                DEFW Line2End-Line2Text
Line2Text     	DEFB $F9,$D4                    ; RAND USR
				DEFB $1D,$22,$21,$1D,$20        ; 16514                
                DEFB $7E                        ; Number
                DEFB $8F,$01,$04,$00,$00        ; Numeric encoding
                DEFB $76                        ; Newline
Line2End            
endBasic
                                                                
Display        	DEFB $76     
                DEFB 8,9,_F,_A,_L,_K,_E,_N,9,8,$76 ; Line 0
                DEFB 0,0,0,0,0,0,0,0,0,0,$76 ; Line 1
                DEFB 0,0,0,0,0,0,0,0,0,0,$76 ; Line 2                                
                DEFB 0,0,0,0,0,0,0,0,0,0,$76 ; Line 3
                DEFB 0,0,0,0,0,0,0,0,0,0,$76 ; Line 4
                DEFB 0,0,0,0,0,0,0,0,0,0,$76 ; Line 5
                DEFB 0,0,0,0,0,0,0,0,0,0,$76 ; Line 6
                DEFB 0,0,0,0,0,0,0,0,0,0,$76 ; Line 7
                DEFB 0,0,0,0,0,0,0,0,0,0,$76 ; Line 8
                DEFB 0,0,0,0,0,0,0,0,0,0,$76 ; Line 9
                DEFB 0,0,0,0,0,0,0,0,0,0,$76 ; Line 10
                DEFB 0,0,0,0,0,0,0,0,0,0,$76 ; Line 11
                DEFB 0,0,0,0,0,0,0,0,0,0,$76 ; Line 12
                DEFB 0,0,0,0,0,0,0,0,0,0,$76  ; Line 13
                DEFB 0,0,0,0,0,0,0,0,0,0,$76 ; Line 14
                DEFB 0,0,0,0,0,0,0,0,0,0,$76  ; Line 15
                DEFB 0,0,0,0,0,0,0,0,0,0,$76 ; Line 16
                DEFB 0,0,0,0,0,0,0,0,0,0,$76  ; Line 17
                DEFB 0,0,0,0,0,0,0,0,0,0,$76 ; Line 18
                DEFB 0,0,0,0,0,0,0,0,0,0,$76  ; Line 19
                DEFB 0,0,0,0,0,0,0,0,0,0,$76 ; Line 20
                DEFB 9,9,9,9,0,0,9,9,9,9,$76  ; Line 21
                DEFB _S,_C,_O,_R,_E,0,0,0,$76  ; Line 22
                DEFB _B,_O,_M,_B,_S,0,0,0,$76  ; Line 23 ; we can only print here because we're doing it manually               
                                 
                                                                
Variables:      
youWonText    
    DEFB	_Y,_O,_U,__,_W,_O,_N,$ff
youLostText    
    DEFB	_Y,_O,_U,__,_L,_O,_S,_T,$ff
blankText    
    DEFB	__,__,__,__,__,__,__,__,$ff    
tempChar
    DEFB 0
mazeDrawAbasolute    
    DEFB 0
playerPosAbsolute
    DEFB 0,0
playerRowPosition
    DEFB 0
playerColPosition
    DEFB 0
firstCharFirstRow
    DEFB 0,0
lastCharFirstRow    
    DEFB 0,0
firstTime    
    DEFB 1
Score    
    DEFB 0
BombsLeft
    DEFB 0
VariablesEnd:   DEFB $80
BasicEnd: 
#END
