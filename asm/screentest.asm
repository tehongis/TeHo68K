 include "HAL.i"

FB_WIDTH    = 640
FB_HEIGHT   = 480

LCG16_MULT  = $10F5
LCG16_ADD   = $3039

;==============================================================================
; fb_scroll_and_random()
;   Clobbers: D0-D4, A0-A2
;==============================================================================
fb_scroll_and_random:
    movem.l   d0-d4/a0-a2, -(sp)

    lea.l     FB_BASE, a1
    lea.l     FB_BASE + FB_WIDTH, a0

    move.l    #(FB_HEIGHT - 1), d0
    mulu.w    #FB_WIDTH, d0

    move.l    d0, d1
    lsr.l     #2, d1
    andi.l    #$3, d0

copy_words:
    move.l    (a0)+, (a1)+
    dbf       d1, copy_words

copy_tail:
    move.b    (a0)+, (a1)+
    dbf       d0, copy_tail

    ;--- Fill bottom row ---
    lea.l     FB_BASE + (FB_HEIGHT - 1) * FB_WIDTH, a2
    move.w    (TIMER_COUNT_REG), d0   ; seed in D0
    move.l    #FB_WIDTH, d4           ; counter in D4

fill_loop:
    move.w    d0, d2
    mulu.w    #LCG16_MULT, d2         ; result in D2:D3 (D3 is free)
    add.w     #LCG16_ADD, d2
    move.w    d2, d0                  ; update seed
    move.b    d2, (a2)+              ; store low byte
    dbf       d4, fill_loop

    movem.l   (sp)+, d0-d4/a0-a2
    rts

;==============================================================================
; fb_scroll_and_random_16bit()
;==============================================================================
fb_scroll_and_random_16bit:
    movem.l   d0-d4/a0-a2, -(sp)

    lea.l     FB_BASE, a1
    lea.l     FB_BASE + FB_WIDTH, a0
    move.l    #(FB_HEIGHT - 1), d0
    mulu.w    #FB_WIDTH, d0
    move.l    d0, d1
    lsr.l     #2, d1
    andi.l    #$3, d0

copy_words_16:
    move.l    (a0)+, (a1)+
    dbf       d1, copy_words_16
copy_tail_16:
    move.b    (a0)+, (a1)+
    dbf       d0, copy_tail_16

    lea.l     FB_BASE + (FB_HEIGHT - 1) * FB_WIDTH, a2
    move.w    (TIMER_COUNT_REG), d0   ; seed in D0
    move.l    #FB_WIDTH, d4
    lsr.l     #1, d4                 ; word count

fill_16:
    move.w    d0, d2
    mulu.w    #LCG16_MULT, d2         ; result in D2:D3
    add.w     #LCG16_ADD, d2
    move.w    d2, d0                  ; update seed
    move.w    d2, (a2)+              ; ← was d3 (bug), now d2
    dbf       d4, fill_16

    movem.l   (sp)+, d0-d4/a0-a2
    rts

;==============================================================================
; fb_scroll_via_hal()
;==============================================================================
fb_scroll_via_hal:
    movem.l   d0-d2/a0, -(sp)

    moveq     #HAL_FB_SCROLL_UP, d0
    trap      #7

    lea.l     FB_BASE + (FB_HEIGHT - 1) * FB_WIDTH, a0
    move.w    (TIMER_COUNT_REG), d1   ; seed in D1
    move.l    #FB_WIDTH, d0           ; counter in D0

hal_fill:
    move.w    d1, d2
    mulu.w    #LCG16_MULT, d2         ; result in D2:D3
    add.w     #LCG16_ADD, d2
    move.w    d2, d1                  ; update seed (was missing!)
    move.b    d2, (a0)+
    dbf       d0, hal_fill           ; D0 is untouched by the LCG

    movem.l   (sp)+, d0-d2/a0
    rts   