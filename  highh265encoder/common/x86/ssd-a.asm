;*****************************************************************************
;* ssd-a.asm: x86 ssd functions
;*****************************************************************************
;* Copyright (C) 2003-2013 x264 project
;*
;* Authors: Loren Merritt <lorenm@u.washington.edu>
;*          Jason Garrett-Glaser <darkshikari@gmail.com>
;*          Laurent Aimar <fenrir@via.ecp.fr>
;*          Alex Izvorski <aizvorksi@gmail.com>
;*
;* This program is free software; you can redistribute it and/or modify
;* it under the terms of the GNU General Public License as published by
;* the Free Software Foundation; either version 2 of the License, or
;* (at your option) any later version.
;*
;* This program is distributed in the hope that it will be useful,
;* but WITHOUT ANY WARRANTY; without even the implied warranty of
;* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;* GNU General Public License for more details.
;*
;* You should have received a copy of the GNU General Public License
;* along with this program; if not, write to the Free Software
;* Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02111, USA.
;*
;* This program is also available under a commercial proprietary license.
;* For more information, contact us at licensing@x264.com.
;*****************************************************************************

%include "x86inc.asm"
%include "x86util.asm"

SECTION_RODATA 32

SECTION .text

cextern pw_00ff
cextern hsub_mul

;=============================================================================
; SSD
;=============================================================================

%if HIGH_BIT_DEPTH
;-----------------------------------------------------------------------------
; int pixel_ssd_WxH( uint16_t *, intptr_t, uint16_t *, intptr_t )
;-----------------------------------------------------------------------------
%macro SSD_ONE 2
cglobal pixel_ssd_ss_%1x%2, 4,7,8
    FIX_STRIDES r1, r3
%if mmsize == %1*2
    %define offset0_1 r1
    %define offset0_2 r1*2
    %define offset0_3 r5
    %define offset1_1 r3
    %define offset1_2 r3*2
    %define offset1_3 r6
    lea     r5, [3*r1]
    lea     r6, [3*r3]
%elif mmsize == %1
    %define offset0_1 mmsize
    %define offset0_2 r1
    %define offset0_3 r1+mmsize
    %define offset1_1 mmsize
    %define offset1_2 r3
    %define offset1_3 r3+mmsize
%elif mmsize == %1/2
    %define offset0_1 mmsize
    %define offset0_2 mmsize*2
    %define offset0_3 mmsize*3
    %define offset1_1 mmsize
    %define offset1_2 mmsize*2
    %define offset1_3 mmsize*3
%endif
    %assign %%n %2/(2*mmsize/%1)
%if %%n > 1
    mov    r4d, %%n
%endif
    pxor    m0, m0
.loop:
    movu    m1, [r0]
    movu    m2, [r0+offset0_1]
    movu    m3, [r0+offset0_2]
    movu    m4, [r0+offset0_3]
    movu    m6, [r2]
    movu    m7, [r2+offset1_1]
    psubw   m1, m6
    psubw   m2, m7
    movu    m6, [r2+offset1_2]
    movu    m7, [r2+offset1_3]
    psubw   m3, m6
    psubw   m4, m7
%if %%n > 1
    lea     r0, [r0+r1*(%2/%%n)]
    lea     r2, [r2+r3*(%2/%%n)]
%endif
    pmaddwd m1, m1
    pmaddwd m2, m2
    pmaddwd m3, m3
    pmaddwd m4, m4
    paddd   m1, m2
    paddd   m3, m4
    paddd   m0, m1
    paddd   m0, m3
%if %%n > 1
    dec    r4d
    jg .loop
%endif
    HADDD   m0, m5
    movd   eax, xm0
%ifidn movu,movq ; detect MMX
    EMMS
%endif
    RET
%endmacro

%macro SSD_TWO 2
cglobal pixel_ssd_ss_%1x%2, 4,7,8
    FIX_STRIDES r1, r3
    pxor    m0,  m0
    mov     r4d, %2/2
    lea     r5,  [r1 * 2]
    lea     r6,  [r3 * 2]
.loop:
    movu    m1,  [r0]
    movu    m2,  [r0 + 16]
    movu    m3,  [r0 + 32]
    movu    m4,  [r0 + 48]
    movu    m6,  [r2]
    movu    m7,  [r2 + 16]
    psubw   m1,  m6
    psubw   m2,  m7
    movu    m6,  [r2 + 32]
    movu    m7,  [r2 + 48]
    psubw   m3,  m6
    psubw   m4,  m7
    pmaddwd m1,  m1
    pmaddwd m2,  m2
    pmaddwd m3,  m3
    pmaddwd m4,  m4
    paddd   m1,  m2
    paddd   m3,  m4
    paddd   m0,  m1
    paddd   m0,  m3
    movu    m1,  [r0 + 64]
    movu    m2,  [r0 + 80]
    movu    m6,  [r2 + 64]
    movu    m7,  [r2 + 80]
    psubw   m1,  m6
    psubw   m2,  m7
    pmaddwd m1,  m1
    pmaddwd m2,  m2
    paddd   m1,  m2
    paddd   m0,  m1
%if %1 == 64
    movu    m3,  [r0 + 96]
    movu    m4,  [r0 + 112]
    movu    m6,  [r2 + 96]
    movu    m7,  [r2 + 112]
    psubw   m3,  m6
    psubw   m4,  m7
    pmaddwd m3,  m3
    pmaddwd m4,  m4
    paddd   m3,  m4
    paddd   m0,  m3
%endif
    movu    m1,  [r0 + r1]
    movu    m2,  [r0 + r1 + 16]
    movu    m3,  [r0 + r1 + 32]
    movu    m4,  [r0 + r1 + 48]
    movu    m6,  [r2 + r3]
    movu    m7,  [r2 + r3 + 16]
    psubw   m1,  m6
    psubw   m2,  m7
    movu    m6,  [r2 + r3 + 32]
    movu    m7,  [r2 + r3 + 48]
    psubw   m3,  m6
    psubw   m4,  m7
    pmaddwd m1,  m1
    pmaddwd m2,  m2
    pmaddwd m3,  m3
    pmaddwd m4,  m4
    paddd   m1,  m2
    paddd   m3,  m4
    paddd   m0,  m1
    paddd   m0,  m3
    movu    m1,  [r0 + r1 + 64]
    movu    m2,  [r0 + r1 + 80]
    movu    m6,  [r2 + r3 + 64]
    movu    m7,  [r2 + r3 + 80]
    psubw   m1,  m6
    psubw   m2,  m7
    pmaddwd m1,  m1
    pmaddwd m2,  m2
    paddd   m1,  m2
    paddd   m0,  m1
%if %1 == 64
    movu    m3,  [r0 + r1 + 96]
    movu    m4,  [r0 + r1 + 112]
    movu    m6,  [r2 + r3 + 96]
    movu    m7,  [r2 + r3 + 112]
    psubw   m3,  m6
    psubw   m4,  m7
    pmaddwd m3,  m3
    pmaddwd m4,  m4
    paddd   m3,  m4
    paddd   m0,  m3
%endif
    lea     r0,  [r0 + r5]
    lea     r2,  [r2 + r6]
    dec     r4d
    jnz  .loop
    HADDD   m0, m5
    movd   eax, xm0
    RET
%endmacro
%macro SSD_24 2
cglobal pixel_ssd_ss_%1x%2, 4,7,8
    FIX_STRIDES r1, r3
    pxor    m0,  m0
    mov     r4d, %2/2
    lea     r5,  [r1 * 2]
    lea     r6,  [r3 * 2]
.loop:
    movu    m1,  [r0]
    movu    m2,  [r0 + 16]
    movu    m3,  [r0 + 32]
    movu    m5,  [r2]
    movu    m6,  [r2 + 16]
    movu    m7,  [r2 + 32]
    psubw   m1,  m5
    psubw   m2,  m6
    psubw   m3,  m7
    pmaddwd m1,  m1
    pmaddwd m2,  m2
    pmaddwd m3,  m3
    paddd   m1,  m2
    paddd   m0,  m1
    movu    m1,  [r0 + r1]
    movu    m2,  [r0 + r1 + 16]
    movu    m4,  [r0 + r1 + 32]
    movu    m5,  [r2 + r3]
    movu    m6,  [r2 + r3 + 16]
    movu    m7,  [r2 + r3 + 32]
    psubw   m1,  m5
    psubw   m2,  m6
    psubw   m4,  m7
    pmaddwd m1,  m1
    pmaddwd m2,  m2
    pmaddwd m4,  m4
    paddd   m1,  m2
    paddd   m3,  m4
    paddd   m0,  m1
    paddd   m0,  m3
    lea     r0,  [r0 + r5]
    lea     r2,  [r2 + r6]
    dec     r4d
    jnz  .loop
    HADDD   m0, m5
    movd   eax, xm0
    RET
%endmacro
%macro SSD_12 2
cglobal pixel_ssd_ss_%1x%2, 4,7,8
    FIX_STRIDES r1, r3
    pxor    m0,  m0
    mov     r4d, %2/4
    lea     r5,  [r1 * 2]
    lea     r6,  [r3 * 2]
.loop:
    movu        m1,  [r0]
    movh        m2,  [r0 + 16]
    movu        m3,  [r0 + r1]
    punpcklqdq  m2,  [r0 + r1 + 16]
    movu        m7,  [r2]
    psubw       m1,  m7
    movh        m4,  [r2 + 16]
    movu        m7,  [r2 + r3]
    psubw       m3,  m7
    punpcklqdq  m4,  [r2 + r3 + 16]
    psubw       m2,  m4
    pmaddwd     m1,  m1
    pmaddwd     m2,  m2
    pmaddwd     m3,  m3
    paddd       m1,  m2
    paddd       m0,  m1

    movu        m1,  [r0 + r5]
    movh        m2,  [r0 + r5 + 16]
    lea         r0,  [r0 + r5]
    movu        m6,  [r0 + r1]
    punpcklqdq  m2,  [r0 + r1 + 16]
    movu        m7,  [r2 + r6]
    psubw       m1,  m7
    movh        m4,  [r2 + r6 + 16]
    lea         r2,  [r2 + r6]
    movu        m7,  [r2 + r3]
    psubw       m6,  m7
    punpcklqdq  m4,  [r2 + r3 + 16]
    psubw       m2,  m4
    pmaddwd     m1,  m1
    pmaddwd     m2,  m2
    pmaddwd     m6,  m6
    paddd       m1,  m2
    paddd       m3,  m6
    paddd       m0,  m1
    paddd       m0,  m3
    lea         r0,  [r0 + r5]
    lea         r2,  [r2 + r6]
    dec         r4d
    jnz     .loop
    HADDD   m0, m5
    movd   eax, xm0
    RET
%endmacro
INIT_MMX mmx2
SSD_ONE     4,  4
SSD_ONE     4,  8
SSD_ONE     4, 16
SSD_ONE     8,  4
SSD_ONE     8,  8
SSD_ONE     8, 16
SSD_ONE    16,  8
SSD_ONE    16, 16
INIT_XMM sse2
SSD_ONE     8,  4
SSD_ONE     8,  8
SSD_ONE     8, 16
SSD_ONE     8, 32
SSD_12     12, 16
SSD_ONE    16,  4
SSD_ONE    16,  8
SSD_ONE    16, 12
SSD_ONE    16, 16
SSD_ONE    16, 32
SSD_ONE    16, 64
SSD_24     24, 32
SSD_ONE    32,  8
SSD_ONE    32, 16
SSD_ONE    32, 24
SSD_ONE    32, 32
SSD_ONE    32, 64
SSD_TWO    48, 64
SSD_TWO    64, 16
SSD_TWO    64, 32
SSD_TWO    64, 48
SSD_TWO    64, 64
INIT_YMM avx2
SSD_ONE    16,  8
SSD_ONE    16, 16
%endif ; HIGH_BIT_DEPTH

;-----------------------------------------------------------------------------
; int pixel_ssd_WxH( uint16_t *, intptr_t, uint16_t *, intptr_t )
;-----------------------------------------------------------------------------
%if HIGH_BIT_DEPTH == 0
%macro SSD_SS 2
cglobal pixel_ssd_ss_%1x%2, 4,7,6
    FIX_STRIDES r1, r3
%if mmsize == %1*4 || mmsize == %1*2
    %define offset0_1 r1*2
    %define offset0_2 r1*4
    %define offset0_3 r5
    %define offset1_1 r3*2
    %define offset1_2 r3*4
    %define offset1_3 r6
    lea     r5, [4*r1]
    lea     r6, [4*r3]
    lea     r5, [r5 + 2*r1]
    lea     r6, [r6 + 2*r3]
%elif mmsize == %1
    %define offset0_1 16
    %define offset0_2 r1*2
    %define offset0_3 r1*2+16
    %define offset1_1 16
    %define offset1_2 r3*2
    %define offset1_3 r3*2+16
%endif
%if %1 == 4
    %assign %%n %2/(mmsize/%1)
%else
    %assign %%n %2/(2*mmsize/%1)
%endif
%if %%n > 1
    mov    r4d, %%n
%endif
    pxor    m0, m0
.loop:
%if %1 == 4
    movh    m1, [r0]
    movh    m2, [r2]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    movh    m1, [r0 + offset0_1]
    movh    m2, [r2 + offset1_1]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    movh    m1, [r0 + offset0_2]
    movh    m2, [r2 + offset1_2]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    movh    m1, [r0 + offset0_3]
    movh    m2, [r2 + offset1_3]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
%else
    movu    m1, [r0]
    movu    m2, [r2]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    movu    m1, [r0 + offset0_1]
    movu    m2, [r2 + offset1_1]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    movu    m1, [r0 + offset0_2]
    movu    m2, [r2 + offset1_2]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    movu    m1, [r0 + offset0_3]
    movu    m2, [r2 + offset1_3]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
%endif
    lea       r0, [r0+r1*(%2/%%n)*2]
    lea       r2, [r2+r3*(%2/%%n)*2]
%if %%n > 1
    dec    r4d
    jg .loop
%endif
%if %1 == 4
    phaddd    m0, m0
%else
    phaddd    m0, m0
    phaddd    m0, m0
%endif
    movd     eax, m0
    RET
%endmacro
%macro SSD_SS_ONE 0
SSD_SS     4,  4
SSD_SS     4,  8
SSD_SS     4, 16
SSD_SS     8,  4
SSD_SS     8,  8
SSD_SS     8, 16
SSD_SS     8, 32
SSD_SS    16,  4
SSD_SS    16,  8
SSD_SS    16, 12
SSD_SS    16, 16
SSD_SS    16, 32
SSD_SS    16, 64
%endmacro

%macro SSD_SS_12x16 0
cglobal pixel_ssd_ss_12x16, 4,7,6
    FIX_STRIDES r1, r3
    mov    r4d, 8
    pxor    m0, m0
.loop:
    movu    m1, [r0]
    movu    m2, [r2]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    movu    m1, [r0 + 16]
    movu    m2, [r2 + 16]
    psubw   m1, m2
    pmaddwd m1, m1
    pslldq  m1, 8
    psrldq  m1, 8
    paddd   m0, m1
    lea       r0, [r0 + 2*r1]
    lea       r2, [r2 + 2*r3]
    movu    m1, [r0]
    movu    m2, [r2]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    movu    m1, [r0 + 16]
    movu    m2, [r2 + 16]
    psubw   m1, m2
    pmaddwd m1, m1
    pslldq  m1, 8
    psrldq  m1, 8
    paddd   m0, m1
    lea       r0, [r0 + 2*r1]
    lea       r2, [r2 + 2*r3]
    dec      r4d
    jnz .loop
    phaddd    m0, m0
    phaddd    m0, m0
    movd     eax, m0
    RET
%endmacro

%macro SSD_SS_32 1
cglobal pixel_ssd_ss_32x%1, 4,7,6
    FIX_STRIDES r1, r3
    mov    r4d, %1/2
    pxor    m0, m0
.loop:
    movu    m1, [r0]
    movu    m2, [r2]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    movu    m1, [r0 + 16]
    movu    m2, [r2 + 16]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    movu    m1, [r0 + 32]
    movu    m2, [r2 + 32]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    movu    m1, [r0 + 48]
    movu    m2, [r2 + 48]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    lea       r0, [r0 + 2*r1]
    lea       r2, [r2 + 2*r3]
    movu    m1, [r0]
    movu    m2, [r2]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    movu    m1, [r0 + 16]
    movu    m2, [r2 + 16]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    movu    m1, [r0 + 32]
    movu    m2, [r2 + 32]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    movu    m1, [r0 + 48]
    movu    m2, [r2 + 48]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    lea       r0, [r0 + 2*r1]
    lea       r2, [r2 + 2*r3]
    dec      r4d
    jnz .loop
    phaddd    m0, m0
    phaddd    m0, m0
    movd     eax, m0
    RET
%endmacro

%macro SSD_SS_32xN 0
SSD_SS_32 8
SSD_SS_32 16
SSD_SS_32 24
SSD_SS_32 32
SSD_SS_32 64
%endmacro

%macro SSD_SS_24 0
cglobal pixel_ssd_ss_24x32, 4,7,6
    FIX_STRIDES r1, r3
    mov    r4d, 16
    pxor    m0, m0
.loop:
    movu    m1, [r0]
    movu    m2, [r2]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    movu    m1, [r0 + 16]
    movu    m2, [r2 + 16]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    movu    m1, [r0 + 32]
    movu    m2, [r2 + 32]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    lea       r0, [r0 + 2*r1]
    lea       r2, [r2 + 2*r3]
    movu    m1, [r0]
    movu    m2, [r2]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    movu    m1, [r0 + 16]
    movu    m2, [r2 + 16]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    movu    m1, [r0 + 32]
    movu    m2, [r2 + 32]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    lea       r0, [r0 + 2*r1]
    lea       r2, [r2 + 2*r3]
    dec      r4d
    jnz .loop
    phaddd    m0, m0
    phaddd    m0, m0
    movd     eax, m0
    RET
%endmacro

%macro SSD_SS_48 0
cglobal pixel_ssd_ss_48x64, 4,7,6
    FIX_STRIDES r1, r3
    mov    r4d, 32
    pxor    m0, m0
.loop:
    movu    m1, [r0]
    movu    m2, [r2]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    movu    m1, [r0 + 16]
    movu    m2, [r2 + 16]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    movu    m1, [r0 + 32]
    movu    m2, [r2 + 32]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    movu    m1, [r0 + 48]
    movu    m2, [r2 + 48]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    movu    m1, [r0 + 64]
    movu    m2, [r2 + 64]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    movu    m1, [r0 + 80]
    movu    m2, [r2 + 80]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    lea       r0, [r0 + 2*r1]
    lea       r2, [r2 + 2*r3]
    movu    m1, [r0]
    movu    m2, [r2]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    movu    m1, [r0 + 16]
    movu    m2, [r2 + 16]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    movu    m1, [r0 + 32]
    movu    m2, [r2 + 32]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    movu    m1, [r0 + 48]
    movu    m2, [r2 + 48]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    movu    m1, [r0 + 64]
    movu    m2, [r2 + 64]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    movu    m1, [r0 + 80]
    movu    m2, [r2 + 80]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    lea       r0, [r0 + 2*r1]
    lea       r2, [r2 + 2*r3]
    dec      r4d
    jnz .loop
    phaddd    m0, m0
    phaddd    m0, m0
    movd     eax, m0
    RET
%endmacro

%macro SSD_SS_64 1
cglobal pixel_ssd_ss_64x%1, 4,7,6
    FIX_STRIDES r1, r3
    mov    r4d, %1/2
    pxor    m0, m0
.loop:
    movu    m1, [r0]
    movu    m2, [r2]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    movu    m1, [r0 + 16]
    movu    m2, [r2 + 16]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    movu    m1, [r0 + 32]
    movu    m2, [r2 + 32]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    movu    m1, [r0 + 48]
    movu    m2, [r2 + 48]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    movu    m1, [r0 + 64]
    movu    m2, [r2 + 64]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    movu    m1, [r0 + 80]
    movu    m2, [r2 + 80]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    movu    m1, [r0 + 96]
    movu    m2, [r2 + 96]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    movu    m1, [r0 + 112]
    movu    m2, [r2 + 112]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    lea     r0, [r0 + 2*r1]
    lea     r2, [r2 + 2*r3]
    movu    m1, [r0]
    movu    m2, [r2]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    movu    m1, [r0 + 16]
    movu    m2, [r2 + 16]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    movu    m1, [r0 + 32]
    movu    m2, [r2 + 32]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    movu    m1, [r0 + 48]
    movu    m2, [r2 + 48]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    movu    m1, [r0 + 64]
    movu    m2, [r2 + 64]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    movu    m1, [r0 + 80]
    movu    m2, [r2 + 80]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    movu    m1, [r0 + 96]
    movu    m2, [r2 + 96]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    movu    m1, [r0 + 112]
    movu    m2, [r2 + 112]
    psubw   m1, m2
    pmaddwd m1, m1
    paddd   m0, m1
    lea     r0, [r0 + 2*r1]
    lea     r2, [r2 + 2*r3]
    dec     r4d
    jnz .loop
    phaddd    m0, m0
    phaddd    m0, m0
    movd     eax, m0
    RET
%endmacro

%macro SSD_SS_64xN 0
SSD_SS_64 16
SSD_SS_64 32
SSD_SS_64 48
SSD_SS_64 64
%endmacro

INIT_XMM sse2
SSD_SS_ONE
SSD_SS_12x16
SSD_SS_24
SSD_SS_32xN
SSD_SS_48
SSD_SS_64xN
INIT_XMM sse4
SSD_SS_ONE
SSD_SS_12x16
SSD_SS_24
SSD_SS_32xN
SSD_SS_48
SSD_SS_64xN
INIT_XMM avx
SSD_SS_ONE
SSD_SS_12x16
SSD_SS_24
SSD_SS_32xN
SSD_SS_48
SSD_SS_64xN
%endif ; !HIGH_BIT_DEPTH

%if HIGH_BIT_DEPTH == 0
%macro SSD_LOAD_FULL 5
    mova      m1, [t0+%1]
    mova      m2, [t2+%2]
    mova      m3, [t0+%3]
    mova      m4, [t2+%4]
%if %5==1
    add       t0, t1
    add       t2, t3
%elif %5==2
    lea       t0, [t0+2*t1]
    lea       t2, [t2+2*t3]
%endif
%endmacro

%macro LOAD 5
    movh      m%1, %3
    movh      m%2, %4
%if %5
    lea       t0, [t0+2*t1]
%endif
%endmacro

%macro JOIN 7
    movh      m%3, %5
    movh      m%4, %6
%if %7
    lea       t2, [t2+2*t3]
%endif
    punpcklbw m%1, m7
    punpcklbw m%3, m7
    psubw     m%1, m%3
    punpcklbw m%2, m7
    punpcklbw m%4, m7
    psubw     m%2, m%4
%endmacro

%macro JOIN_SSE2 7
    movh      m%3, %5
    movh      m%4, %6
%if %7
    lea       t2, [t2+2*t3]
%endif
    punpcklqdq m%1, m%2
    punpcklqdq m%3, m%4
    DEINTB %2, %1, %4, %3, 7
    psubw m%2, m%4
    psubw m%1, m%3
%endmacro

%macro JOIN_SSSE3 7
    movh      m%3, %5
    movh      m%4, %6
%if %7
    lea       t2, [t2+2*t3]
%endif
    punpcklbw m%1, m%3
    punpcklbw m%2, m%4
%endmacro

%macro LOAD_AVX2 5
    mova     xm%1, %3
    vinserti128 m%1, m%1, %4, 1
%if %5
    lea       t0, [t0+2*t1]
%endif
%endmacro

%macro JOIN_AVX2 7
    mova     xm%2, %5
    vinserti128 m%2, m%2, %6, 1
%if %7
    lea       t2, [t2+2*t3]
%endif
    SBUTTERFLY bw, %1, %2, %3
%endmacro

%macro SSD_LOAD_HALF 5
    LOAD      1, 2, [t0+%1], [t0+%3], 1
    JOIN      1, 2, 3, 4, [t2+%2], [t2+%4], 1
    LOAD      3, 4, [t0+%1], [t0+%3], %5
    JOIN      3, 4, 5, 6, [t2+%2], [t2+%4], %5
%endmacro

%macro SSD_CORE 7-8
%ifidn %8, FULL
    mova      m%6, m%2
    mova      m%7, m%4
    psubusb   m%2, m%1
    psubusb   m%4, m%3
    psubusb   m%1, m%6
    psubusb   m%3, m%7
    por       m%1, m%2
    por       m%3, m%4
    punpcklbw m%2, m%1, m%5
    punpckhbw m%1, m%5
    punpcklbw m%4, m%3, m%5
    punpckhbw m%3, m%5
%endif
    pmaddwd   m%1, m%1
    pmaddwd   m%2, m%2
    pmaddwd   m%3, m%3
    pmaddwd   m%4, m%4
%endmacro

%macro SSD_CORE_SSE2 7-8
%ifidn %8, FULL
    DEINTB %6, %1, %7, %2, %5
    psubw m%6, m%7
    psubw m%1, m%2
    SWAP %6, %2, %1
    DEINTB %6, %3, %7, %4, %5
    psubw m%6, m%7
    psubw m%3, m%4
    SWAP %6, %4, %3
%endif
    pmaddwd   m%1, m%1
    pmaddwd   m%2, m%2
    pmaddwd   m%3, m%3
    pmaddwd   m%4, m%4
%endmacro

%macro SSD_CORE_SSSE3 7-8
%ifidn %8, FULL
    punpckhbw m%6, m%1, m%2
    punpckhbw m%7, m%3, m%4
    punpcklbw m%1, m%2
    punpcklbw m%3, m%4
    SWAP %6, %2, %3
    SWAP %7, %4
%endif
    pmaddubsw m%1, m%5
    pmaddubsw m%2, m%5
    pmaddubsw m%3, m%5
    pmaddubsw m%4, m%5
    pmaddwd   m%1, m%1
    pmaddwd   m%2, m%2
    pmaddwd   m%3, m%3
    pmaddwd   m%4, m%4
%endmacro

%macro SSD_ITER 6
    SSD_LOAD_%1 %2,%3,%4,%5,%6
    SSD_CORE  1, 2, 3, 4, 7, 5, 6, %1
    paddd     m1, m2
    paddd     m3, m4
    paddd     m0, m1
    paddd     m0, m3
%endmacro

;-----------------------------------------------------------------------------
; int pixel_ssd_16x16( uint8_t *, intptr_t, uint8_t *, intptr_t )
;-----------------------------------------------------------------------------
%macro SSD 2
%if %1 != %2
    %assign function_align 8
%else
    %assign function_align 16
%endif
cglobal pixel_ssd_%1x%2, 0,0,0
    mov     al, %1*%2/mmsize/2

%if %1 != %2
    jmp mangle(x265_pixel_ssd_%1x%1 %+ SUFFIX %+ .startloop)
%else

.startloop:
%if ARCH_X86_64
    DECLARE_REG_TMP 0,1,2,3
    PROLOGUE 0,0,8
%else
    PROLOGUE 0,5
    DECLARE_REG_TMP 1,2,3,4
    mov t0, r0m
    mov t1, r1m
    mov t2, r2m
    mov t3, r3m
%endif

%if cpuflag(ssse3)
    mova    m7, [hsub_mul]
%elifidn cpuname, sse2
    mova    m7, [pw_00ff]
%elif %1 >= mmsize
    pxor    m7, m7
%endif
    pxor    m0, m0

ALIGN 16
.loop:
%if %1 > mmsize
    SSD_ITER FULL, 0, 0, mmsize, mmsize, 1
%elif %1 == mmsize
    SSD_ITER FULL, 0, 0, t1, t3, 2
%else
    SSD_ITER HALF, 0, 0, t1, t3, 2
%endif
    dec     al
    jg .loop
%if mmsize==32
    vextracti128 xm1, m0, 1
    paddd  xm0, xm1
    HADDD  xm0, xm1
    movd   eax, xm0
%else
    HADDD   m0, m1
    movd   eax, m0
%endif
%if (mmsize == 8)
    emms
%endif
    RET
%endif
%endmacro

%macro HEVC_SSD 0
SSD 32, 64
SSD 16, 64
SSD 32, 32
SSD 32, 16
SSD 16, 32
SSD 32, 8
SSD 8,  32
SSD 32, 24
SSD 24, 24 ; not used, but resolves x265_pixel_ssd_24x24_sse2.startloop symbol
SSD 8,  4
SSD 8,  8
SSD 16, 16
SSD 16, 12
SSD 16, 8
SSD 8,  16
SSD 16, 4
%endmacro

INIT_MMX mmx
SSD 16, 16
SSD 16,  8
SSD  8,  8
SSD  8, 16
SSD  4,  4
SSD  8,  4
SSD  4,  8
SSD  4, 16
INIT_XMM sse2slow
SSD 16, 16
SSD  8,  8
SSD 16,  8
SSD  8, 16
SSD  8,  4
INIT_XMM sse2
%define SSD_CORE SSD_CORE_SSE2
%define JOIN JOIN_SSE2
HEVC_SSD
INIT_XMM ssse3
%define SSD_CORE SSD_CORE_SSSE3
%define JOIN JOIN_SSSE3
HEVC_SSD
INIT_XMM avx
HEVC_SSD
INIT_MMX ssse3
SSD  4,  4
SSD  4,  8
SSD  4, 16
INIT_XMM xop
SSD 16, 16
SSD  8,  8
SSD 16,  8
SSD  8, 16
SSD  8,  4
%define LOAD LOAD_AVX2
%define JOIN JOIN_AVX2
INIT_YMM avx2
SSD 16, 16
SSD 16,  8
%assign function_align 16
%endif ; !HIGH_BIT_DEPTH

;-----------------------------------------------------------------------------
; int pixel_ssd_12x16( uint8_t *, intptr_t, uint8_t *, intptr_t )
;-----------------------------------------------------------------------------
INIT_XMM sse4
cglobal pixel_ssd_12x16, 4, 5, 7, src1, stride1, src2, stride2

    pxor        m6,     m6
    mov         r4d,    4

.loop:
    movu        m0,    [r0]
    movu        m1,    [r2]
    movu        m2,    [r0 + r1]
    movu        m3,    [r2 + r3]

    punpckhdq   m4,    m0,    m2
    punpckhdq   m5,    m1,    m3

    pmovzxbw    m0,    m0
    pmovzxbw    m1,    m1
    pmovzxbw    m2,    m2
    pmovzxbw    m3,    m3
    pmovzxbw    m4,    m4
    pmovzxbw    m5,    m5

    psubw       m0,    m1
    psubw       m2,    m3
    psubw       m4,    m5

    pmaddwd     m0,    m0
    pmaddwd     m2,    m2
    pmaddwd     m4,    m4

    paddd       m0,    m2
    paddd       m6,    m4
    paddd       m6,    m0

    movu        m0,    [r0 + 2 * r1]
    movu        m1,    [r2 + 2 * r3]
    lea         r0,    [r0 + 2 * r1]
    lea         r2,    [r2 + 2 * r3]
    movu        m2,    [r0 + r1]
    movu        m3,    [r2 + r3]

    punpckhdq   m4,    m0,    m2
    punpckhdq   m5,    m1,    m3

    pmovzxbw    m0,    m0
    pmovzxbw    m1,    m1
    pmovzxbw    m2,    m2
    pmovzxbw    m3,    m3
    pmovzxbw    m4,    m4
    pmovzxbw    m5,    m5

    psubw       m0,    m1
    psubw       m2,    m3
    psubw       m4,    m5

    pmaddwd     m0,    m0
    pmaddwd     m2,    m2
    pmaddwd     m4,    m4

    paddd       m0,    m2
    paddd       m6,    m4
    paddd       m6,    m0

    dec    r4d
    lea       r0,                    [r0 + 2 * r1]
    lea       r2,                    [r2 + 2 * r3]
    jnz    .loop

    HADDD   m6, m1
    movd   eax, m6

    RET

;-----------------------------------------------------------------------------
; int pixel_ssd_24x32( uint8_t *, intptr_t, uint8_t *, intptr_t )
;-----------------------------------------------------------------------------
INIT_XMM sse4
cglobal pixel_ssd_24x32, 4, 5, 8, src1, stride1, src2, stride2

    pxor    m7,     m7
    pxor    m6,     m6
    mov     r4d,    16

.loop:
    movu         m1,    [r0]
    pmovzxbw     m0,    m1
    punpckhbw    m1,    m6
    pmovzxbw     m2,    [r0 + 16]
    movu         m4,    [r2]
    pmovzxbw     m3,    m4
    punpckhbw    m4,    m6
    pmovzxbw     m5,    [r2 + 16]

    psubw        m0,    m3
    psubw        m1,    m4
    psubw        m2,    m5

    pmaddwd      m0,    m0
    pmaddwd      m1,    m1
    pmaddwd      m2,    m2

    paddd        m0,    m1
    paddd        m7,    m2
    paddd        m7,    m0

    movu         m1,    [r0 + r1]
    pmovzxbw     m0,    m1
    punpckhbw    m1,    m6
    pmovzxbw     m2,    [r0 + r1 + 16]
    movu         m4,    [r2 + r3]
    pmovzxbw     m3,    m4
    punpckhbw    m4,    m6
    pmovzxbw     m5,    [r2 + r3 + 16]

    psubw        m0,    m3
    psubw        m1,    m4
    psubw        m2,    m5

    pmaddwd      m0,    m0
    pmaddwd      m1,    m1
    pmaddwd      m2,    m2

    paddd        m0,    m1
    paddd        m7,    m2
    paddd        m7,    m0

    dec    r4d
    lea    r0,    [r0 + 2 * r1]
    lea    r2,    [r2 + 2 * r3]
    jnz    .loop

    HADDD   m7, m1
    movd   eax, m7

    RET

%macro PIXEL_SSD_16x4 0
    movu         m1,    [r0]
    pmovzxbw     m0,    m1
    punpckhbw    m1,    m6
    movu         m3,    [r2]
    pmovzxbw     m2,    m3
    punpckhbw    m3,    m6

    psubw        m0,    m2
    psubw        m1,    m3

    movu         m5,    [r0 + r1]
    pmovzxbw     m4,    m5
    punpckhbw    m5,    m6
    movu         m3,    [r2 + r3]
    pmovzxbw     m2,    m3
    punpckhbw    m3,    m6

    psubw        m4,    m2
    psubw        m5,    m3

    pmaddwd      m0,    m0
    pmaddwd      m1,    m1
    pmaddwd      m4,    m4
    pmaddwd      m5,    m5

    paddd        m0,    m1
    paddd        m4,    m5
    paddd        m4,    m0
    paddd        m7,    m4

    movu         m1,    [r0 + r6]
    pmovzxbw     m0,    m1
    punpckhbw    m1,    m6
    movu         m3,    [r2 + 2 * r3]
    pmovzxbw     m2,    m3
    punpckhbw    m3,    m6

    psubw        m0,    m2
    psubw        m1,    m3

    lea          r0,    [r0 + r6]
    lea          r2,    [r2 + 2 * r3]
    movu         m5,    [r0 + r1]
    pmovzxbw     m4,    m5
    punpckhbw    m5,    m6
    movu         m3,    [r2 + r3]
    pmovzxbw     m2,    m3
    punpckhbw    m3,    m6

    psubw        m4,    m2
    psubw        m5,    m3

    pmaddwd      m0,    m0
    pmaddwd      m1,    m1
    pmaddwd      m4,    m4
    pmaddwd      m5,    m5

    paddd        m0,    m1
    paddd        m4,    m5
    paddd        m4,    m0
    paddd        m7,    m4
%endmacro

cglobal pixel_ssd_16x16_internal
    PIXEL_SSD_16x4
    lea     r0,    [r0 + r6]
    lea     r2,    [r2 + 2 * r3]
    PIXEL_SSD_16x4
    lea     r0,    [r0 + r6]
    lea     r2,    [r2 + 2 * r3]
    PIXEL_SSD_16x4
    lea     r0,    [r0 + r6]
    lea     r2,    [r2 + 2 * r3]
    PIXEL_SSD_16x4
    ret

;-----------------------------------------------------------------------------
; int pixel_ssd_48x64( uint8_t *, intptr_t, uint8_t *, intptr_t )
;-----------------------------------------------------------------------------
INIT_XMM sse4
cglobal pixel_ssd_48x64, 4, 7, 8, src1, stride1, src2, stride2

    pxor    m7,    m7
    pxor    m6,    m6
    mov     r4,    r0
    mov     r5,    r2
    lea     r6,    [r1 * 2]

    call    pixel_ssd_16x16_internal
    lea     r0,    [r0 + r6]
    lea     r2,    [r2 + 2 * r3]
    call    pixel_ssd_16x16_internal
    lea     r0,    [r0 + r6]
    lea     r2,    [r2 + 2 * r3]
    call    pixel_ssd_16x16_internal
    lea     r0,    [r0 + r6]
    lea     r2,    [r2 + 2 * r3]
    call    pixel_ssd_16x16_internal
    lea     r0,    [r4 + 16]
    lea     r2,    [r5 + 16]
    call    pixel_ssd_16x16_internal
    lea     r0,    [r0 + r6]
    lea     r2,    [r2 + 2 * r3]
    call    pixel_ssd_16x16_internal
    lea     r0,    [r0 + r6]
    lea     r2,    [r2 + 2 * r3]
    call    pixel_ssd_16x16_internal
    lea     r0,    [r0 + r6]
    lea     r2,    [r2 + 2 * r3]
    call    pixel_ssd_16x16_internal
    lea     r0,    [r4 + 32]
    lea     r2,    [r5 + 32]
    call    pixel_ssd_16x16_internal
    lea     r0,    [r0 + r6]
    lea     r2,    [r2 + 2 * r3]
    call    pixel_ssd_16x16_internal
    lea     r0,    [r0 + r6]
    lea     r2,    [r2 + 2 * r3]
    call    pixel_ssd_16x16_internal
    lea     r0,    [r0 + r6]
    lea     r2,    [r2 + 2 * r3]
    call    pixel_ssd_16x16_internal

    HADDD    m7,     m1
    movd     eax,    m7

    RET

;-----------------------------------------------------------------------------
; int pixel_ssd_64x16( uint8_t *, intptr_t, uint8_t *, intptr_t )
;-----------------------------------------------------------------------------
INIT_XMM sse4
cglobal pixel_ssd_64x16, 4, 7, 8, src1, stride1, src2, stride2

    pxor    m7,    m7
    pxor    m6,    m6
    mov     r4,    r0
    mov     r5,    r2
    lea     r6,    [r1 * 2]

    call    pixel_ssd_16x16_internal
    lea     r0,    [r4 + 16]
    lea     r2,    [r5 + 16]
    call    pixel_ssd_16x16_internal
    lea     r0,    [r4 + 32]
    lea     r2,    [r5 + 32]
    call    pixel_ssd_16x16_internal
    lea     r0,    [r4 + 48]
    lea     r2,    [r5 + 48]
    call    pixel_ssd_16x16_internal

    HADDD    m7,      m1
    movd     eax,     m7

    RET

;-----------------------------------------------------------------------------
; int pixel_ssd_64x32( uint8_t *, intptr_t, uint8_t *, intptr_t )
;-----------------------------------------------------------------------------
INIT_XMM sse4
cglobal pixel_ssd_64x32, 4, 7, 8, src1, stride1, src2, stride2

    pxor    m7,    m7
    pxor    m6,    m6
    mov     r4,    r0
    mov     r5,    r2
    lea     r6,    [r1 * 2]

    call    pixel_ssd_16x16_internal
    lea     r0,    [r0 + r6]
    lea     r2,    [r2 + 2 * r3]
    call    pixel_ssd_16x16_internal
    lea     r0,    [r4 + 16]
    lea     r2,    [r5 + 16]
    call    pixel_ssd_16x16_internal
    lea     r0,    [r0 + r6]
    lea     r2,    [r2 + 2 * r3]
    call    pixel_ssd_16x16_internal
    lea     r0,    [r4 + 32]
    lea     r2,    [r5 + 32]
    call    pixel_ssd_16x16_internal
    lea     r0,    [r0 + r6]
    lea     r2,    [r2 + 2 * r3]
    call    pixel_ssd_16x16_internal
    lea     r0,    [r4 + 48]
    lea     r2,    [r5 + 48]
    call    pixel_ssd_16x16_internal
    lea     r0,    [r0 + r6]
    lea     r2,    [r2 + 2 * r3]
    call    pixel_ssd_16x16_internal

    HADDD    m7,     m1
    movd     eax,    m7

    RET

;-----------------------------------------------------------------------------
; int pixel_ssd_64x48( uint8_t *, intptr_t, uint8_t *, intptr_t )
;-----------------------------------------------------------------------------
INIT_XMM sse4
cglobal pixel_ssd_64x48, 4, 7, 8, src1, stride1, src2, stride2

    pxor    m7,    m7
    pxor    m6,    m6
    mov     r4,    r0
    mov     r5,    r2
    lea     r6,    [r1 * 2]

    call    pixel_ssd_16x16_internal
    lea     r0,    [r0 + r6]
    lea     r2,    [r2 + 2 * r3]
    call    pixel_ssd_16x16_internal
    lea     r0,    [r0 + r6]
    lea     r2,    [r2 + 2 * r3]
    call    pixel_ssd_16x16_internal
    lea     r0,    [r4 + 16]
    lea     r2,    [r5 + 16]
    call    pixel_ssd_16x16_internal
    lea     r0,    [r0 + r6]
    lea     r2,    [r2 + 2 * r3]
    call    pixel_ssd_16x16_internal
    lea     r0,    [r0 + r6]
    lea     r2,    [r2 + 2 * r3]
    call    pixel_ssd_16x16_internal
    lea     r0,    [r4 + 32]
    lea     r2,    [r5 + 32]
    call    pixel_ssd_16x16_internal
    lea     r0,    [r0 + r6]
    lea     r2,    [r2 + 2 * r3]
    call    pixel_ssd_16x16_internal
    lea     r0,    [r0 + r6]
    lea     r2,    [r2 + 2 * r3]
    call    pixel_ssd_16x16_internal
    lea     r0,    [r4 + 48]
    lea     r2,    [r5 + 48]
    call    pixel_ssd_16x16_internal
    lea     r0,    [r0 + r6]
    lea     r2,    [r2 + 2 * r3]
    call    pixel_ssd_16x16_internal
    lea     r0,    [r0 + r6]
    lea     r2,    [r2 + 2 * r3]
    call    pixel_ssd_16x16_internal

    HADDD    m7,     m1
    movd     eax,    m7

    RET

;-----------------------------------------------------------------------------
; int pixel_ssd_64x64( uint8_t *, intptr_t, uint8_t *, intptr_t )
;-----------------------------------------------------------------------------
INIT_XMM sse4
cglobal pixel_ssd_64x64, 4, 7, 8, src1, stride1, src2, stride2

    pxor    m7,    m7
    pxor    m6,    m6
    mov     r4,    r0
    mov     r5,    r2
    lea     r6,    [r1 * 2]

    call    pixel_ssd_16x16_internal
    lea     r0,    [r0 + r6]
    lea     r2,    [r2 + 2 * r3]
    call    pixel_ssd_16x16_internal
    lea     r0,    [r0 + r6]
    lea     r2,    [r2 + 2 * r3]
    call    pixel_ssd_16x16_internal
    lea     r0,    [r0 + r6]
    lea     r2,    [r2 + 2 * r3]
    call    pixel_ssd_16x16_internal
    lea     r0,    [r4 + 16]
    lea     r2,    [r5 + 16]
    call    pixel_ssd_16x16_internal
    lea     r0,    [r0 + r6]
    lea     r2,    [r2 + 2 * r3]
    call    pixel_ssd_16x16_internal
    lea     r0,    [r0 + r6]
    lea     r2,    [r2 + 2 * r3]
    call    pixel_ssd_16x16_internal
    lea     r0,    [r0 + r6]
    lea     r2,    [r2 + 2 * r3]
    call    pixel_ssd_16x16_internal
    lea     r0,    [r4 + 32]
    lea     r2,    [r5 + 32]
    call    pixel_ssd_16x16_internal
    lea     r0,    [r0 + r6]
    lea     r2,    [r2 + 2 * r3]
    call    pixel_ssd_16x16_internal
    lea     r0,    [r0 + r6]
    lea     r2,    [r2 + 2 * r3]
    call    pixel_ssd_16x16_internal
    lea     r0,    [r0 + r6]
    lea     r2,    [r2 + 2 * r3]
    call    pixel_ssd_16x16_internal
    lea     r0,    [r4 + 48]
    lea     r2,    [r5 + 48]
    call    pixel_ssd_16x16_internal
    lea     r0,    [r0 + r6]
    lea     r2,    [r2 + 2 * r3]
    call    pixel_ssd_16x16_internal
    lea     r0,    [r0 + r6]
    lea     r2,    [r2 + 2 * r3]
    call    pixel_ssd_16x16_internal
    lea     r0,    [r0 + r6]
    lea     r2,    [r2 + 2 * r3]
    call    pixel_ssd_16x16_internal

    HADDD    m7,     m1
    movd     eax,    m7

    RET

;-----------------------------------------------------------------------------
; int pixel_ssd_sp ( int16_t *, intptr_t, uint8_t *, intptr_t )
;-----------------------------------------------------------------------------

cglobal pixel_ssd_sp_4x4_internal
    movh          m0,    [r0]
    movh          m1,    [r0 + r1]
    punpcklqdq    m0,    m1
    movd          m2,    [r2]
    movd          m3,    [r2 + r3]
    punpckldq     m2,    m3
    pmovzxbw      m2,    m2
    psubw         m0,    m2
    movh          m4,    [r0 + 2 * r1]
    movh          m5,    [r0 + r4]
    punpcklqdq    m4,    m5
    movd          m6,    [r2 + 2 * r3]
    lea           r2,    [r2 + 2 * r3]
    movd          m1,    [r2 + r3]
    punpckldq     m6,    m1
    pmovzxbw      m6,    m6
    psubw         m4,    m6
    pmaddwd       m0,    m0
    pmaddwd       m4,    m4
    paddd         m0,    m4
    paddd         m7,    m0
    ret

;-----------------------------------------------------------------------------
; int pixel_ssd_sp_4x4( int16_t *, intptr_t, uint8_t *, intptr_t )
;-----------------------------------------------------------------------------
INIT_XMM sse4
cglobal pixel_ssd_sp_4x4, 4, 5, 8, src1, stride1, src2, stride2
    pxor     m7,     m7
    add      r1,     r1
    lea      r4,     [r1 * 3]
    call     pixel_ssd_sp_4x4_internal
    HADDD    m7,     m1
    movd     eax,    m7
    RET

;-----------------------------------------------------------------------------
; int pixel_ssd_sp_4x8( int16_t *, intptr_t, uint8_t *, intptr_t )
;-----------------------------------------------------------------------------
INIT_XMM sse4
cglobal pixel_ssd_sp_4x8, 4, 5, 8, src1, stride1, src2, stride2
    pxor     m7,     m7
    add      r1,     r1
    lea      r4,     [r1 * 3]
    call     pixel_ssd_sp_4x4_internal
    lea      r0,     [r0 + 4 * r1]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_4x4_internal
    HADDD    m7,     m1
    movd     eax,    m7
    RET

;-----------------------------------------------------------------------------
; int pixel_ssd_sp_4x16( int16_t *, intptr_t, uint8_t *, intptr_t )
;-----------------------------------------------------------------------------
INIT_XMM sse4
cglobal pixel_ssd_sp_4x16, 4, 5, 8, src1, stride1, src2, stride2
    pxor     m7,     m7
    add      r1,     r1
    lea      r4,     [r1 * 3]
    call     pixel_ssd_sp_4x4_internal
    lea      r0,     [r0 + 4 * r1]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_4x4_internal
    lea      r0,     [r0 + 4 * r1]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_4x4_internal
    lea      r0,     [r0 + 4 * r1]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_4x4_internal
    HADDD    m7,     m1
    movd     eax,    m7
    RET

cglobal pixel_ssd_sp_8x4_internal
    movu         m0,    [r0]
    movu         m1,    [r0 + r1]
    movh         m2,    [r2]
    movh         m3,    [r2 + r3]
    pmovzxbw     m2,    m2
    pmovzxbw     m3,    m3

    psubw        m0,    m2
    psubw        m1,    m3

    movu         m4,    [r0 + 2 * r1]
    movu         m5,    [r0 + r4]
    movh         m2,    [r2 + 2 * r3]
    movh         m3,    [r2 + r5]
    pmovzxbw     m2,    m2
    pmovzxbw     m3,    m3

    psubw        m4,    m2
    psubw        m5,    m3

    pmaddwd      m0,    m0
    pmaddwd      m1,    m1
    pmaddwd      m4,    m4
    pmaddwd      m5,    m5

    paddd        m0,    m1
    paddd        m4,    m5
    paddd        m4,    m0
    paddd        m7,    m4
    ret

;-----------------------------------------------------------------------------
; int pixel_ssd_sp_8x4( int16_t *, intptr_t, uint8_t *, intptr_t )
;-----------------------------------------------------------------------------
INIT_XMM sse4
cglobal pixel_ssd_sp_8x4, 4, 6, 8, src1, stride1, src2, stride2
    pxor     m7,     m7
    add      r1,     r1
    lea      r4,     [r1 * 3]
    lea      r5,     [r3 * 3]
    call     pixel_ssd_sp_8x4_internal
    HADDD    m7,     m1
    movd     eax,    m7
    RET

;-----------------------------------------------------------------------------
; int pixel_ssd_sp_8x8( int16_t *, intptr_t, uint8_t *, intptr_t )
;-----------------------------------------------------------------------------
INIT_XMM sse4
cglobal pixel_ssd_sp_8x8, 4, 6, 8, src1, stride1, src2, stride2
    pxor     m7,     m7
    add      r1,     r1
    lea      r4,     [r1 * 3]
    lea      r5,     [r3 * 3]
    call     pixel_ssd_sp_8x4_internal
    lea      r0,     [r0 + 4 * r1]
    lea      r2,     [r2 + 4 * r3]
    call     pixel_ssd_sp_8x4_internal
    HADDD    m7,     m1
    movd     eax,    m7
    RET

;-----------------------------------------------------------------------------
; int pixel_ssd_sp_8x16( int16_t *, intptr_t, uint8_t *, intptr_t )
;-----------------------------------------------------------------------------
INIT_XMM sse4
cglobal pixel_ssd_sp_8x16, 4, 6, 8, src1, stride1, src2, stride2
    pxor     m7,     m7
    add      r1,     r1
    lea      r4,     [r1 * 3]
    lea      r5,     [r3 * 3]
    call     pixel_ssd_sp_8x4_internal
    lea      r0,     [r0 + 4 * r1]
    lea      r2,     [r2 + 4 * r3]
    call     pixel_ssd_sp_8x4_internal
    lea      r0,     [r0 + 4 * r1]
    lea      r2,     [r2 + 4 * r3]
    call     pixel_ssd_sp_8x4_internal
    lea      r0,     [r0 + 4 * r1]
    lea      r2,     [r2 + 4 * r3]
    call     pixel_ssd_sp_8x4_internal
    HADDD    m7,     m1
    movd     eax,    m7
    RET

;-----------------------------------------------------------------------------
; int pixel_ssd_sp_8x32( int16_t *, intptr_t, uint8_t *, intptr_t )
;-----------------------------------------------------------------------------
INIT_XMM sse4
cglobal pixel_ssd_sp_8x32, 4, 6, 8, src1, stride1, src2, stride2
    pxor     m7,     m7
    add      r1,     r1
    lea      r4,     [r1 * 3]
    lea      r5,     [r3 * 3]
    call     pixel_ssd_sp_8x4_internal
    lea      r0,     [r0 + 4 * r1]
    lea      r2,     [r2 + 4 * r3]
    call     pixel_ssd_sp_8x4_internal
    lea      r0,     [r0 + 4 * r1]
    lea      r2,     [r2 + 4 * r3]
    call     pixel_ssd_sp_8x4_internal
    lea      r0,     [r0 + 4 * r1]
    lea      r2,     [r2 + 4 * r3]
    call     pixel_ssd_sp_8x4_internal
    lea      r0,     [r0 + 4 * r1]
    lea      r2,     [r2 + 4 * r3]
    call     pixel_ssd_sp_8x4_internal
    lea      r0,     [r0 + 4 * r1]
    lea      r2,     [r2 + 4 * r3]
    call     pixel_ssd_sp_8x4_internal
    lea      r0,     [r0 + 4 * r1]
    lea      r2,     [r2 + 4 * r3]
    call     pixel_ssd_sp_8x4_internal
    lea      r0,     [r0 + 4 * r1]
    lea      r2,     [r2 + 4 * r3]
    call     pixel_ssd_sp_8x4_internal
    HADDD    m7,     m1
    movd     eax,    m7
    RET

;-----------------------------------------------------------------------------
; int pixel_ssd_sp_12x16( int16_t *, intptr_t, uint8_t *, intptr_t )
;-----------------------------------------------------------------------------
INIT_XMM sse4
cglobal pixel_ssd_sp_12x16, 4, 7, 8, src1, stride1, src2, stride2
    pxor     m7,     m7
    add      r1,     r1
    lea      r4,     [r1 * 3]
    mov      r5,     r0
    mov      r6,     r2
    call     pixel_ssd_sp_4x4_internal
    lea      r0,     [r0 + 4 * r1]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_4x4_internal
    lea      r0,     [r0 + 4 * r1]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_4x4_internal
    lea      r0,     [r0 + 4 * r1]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_4x4_internal
    lea      r0,     [r5 + 8]
    lea      r2,     [r6 + 4]
    lea      r5,     [r3 * 3]
    call     pixel_ssd_sp_8x4_internal
    lea      r0,     [r0 + 4 * r1]
    lea      r2,     [r2 + 4 * r3]
    call     pixel_ssd_sp_8x4_internal
    lea      r0,     [r0 + 4 * r1]
    lea      r2,     [r2 + 4 * r3]
    call     pixel_ssd_sp_8x4_internal
    lea      r0,     [r0 + 4 * r1]
    lea      r2,     [r2 + 4 * r3]
    call     pixel_ssd_sp_8x4_internal
    HADDD    m7,     m1
    movd     eax,    m7
    RET

%macro PIXEL_SSD_SP_16x4 0
    movu         m0,    [r0]
    movu         m1,    [r0 + 16]
    movu         m3,    [r2]
    pmovzxbw     m2,    m3
    punpckhbw    m3,    m6

    psubw        m0,    m2
    psubw        m1,    m3

    movu         m4,    [r0 + r1]
    movu         m5,    [r0 + r1 +16]
    movu         m3,    [r2 + r3]
    pmovzxbw     m2,    m3
    punpckhbw    m3,    m6

    psubw        m4,    m2
    psubw        m5,    m3

    pmaddwd      m0,    m0
    pmaddwd      m1,    m1
    pmaddwd      m4,    m4
    pmaddwd      m5,    m5

    paddd        m0,    m1
    paddd        m4,    m5
    paddd        m4,    m0
    paddd        m7,    m4

    movu         m0,    [r0 + 2 * r1]
    movu         m1,    [r0 + 2 * r1 + 16]
    movu         m3,    [r2 + 2 * r3]
    pmovzxbw     m2,    m3
    punpckhbw    m3,    m6

    psubw        m0,    m2
    psubw        m1,    m3

    lea          r0,    [r0 + 2 * r1]
    lea          r2,    [r2 + 2 * r3]
    movu         m4,    [r0 + r1]
    movu         m5,    [r0 + r1 + 16]
    movu         m3,    [r2 + r3]
    pmovzxbw     m2,    m3
    punpckhbw    m3,    m6

    psubw        m4,    m2
    psubw        m5,    m3

    pmaddwd      m0,    m0
    pmaddwd      m1,    m1
    pmaddwd      m4,    m4
    pmaddwd      m5,    m5

    paddd        m0,    m1
    paddd        m4,    m5
    paddd        m4,    m0
    paddd        m7,    m4
%endmacro

;-----------------------------------------------------------------------------
; int pixel_ssd_sp_16x4( int16_t *, intptr_t, uint8_t *, intptr_t )
;-----------------------------------------------------------------------------
INIT_XMM sse4
cglobal pixel_ssd_sp_16x4, 4, 6, 8, src1, stride1, src2, stride2

    pxor        m6,     m6
    pxor        m7,     m7
    add         r1,     r1
    PIXEL_SSD_SP_16x4
    HADDD   m7, m1
    movd   eax, m7

    RET

;-----------------------------------------------------------------------------
; int pixel_ssd_sp_16x8( int16_t *, intptr_t, uint8_t *, intptr_t )
;-----------------------------------------------------------------------------
INIT_XMM sse4
cglobal pixel_ssd_sp_16x8, 4, 4, 8, src1, stride1, src2, stride2

    pxor    m6,     m6
    pxor    m7,     m7
    add     r1,     r1
    PIXEL_SSD_SP_16x4
    lea     r0,    [r0 + 2 * r1]
    lea     r2,    [r2 + 2 * r3]
    PIXEL_SSD_SP_16x4
    HADDD   m7,     m1
    movd    eax,    m7
    RET

;-----------------------------------------------------------------------------
; int pixel_ssd_sp_16x12( int16_t *, intptr_t, uint8_t *, intptr_t )
;-----------------------------------------------------------------------------
INIT_XMM sse4
cglobal pixel_ssd_sp_16x12, 4, 6, 8, src1, stride1, src2, stride2

    pxor    m6,     m6
    pxor    m7,     m7
    add     r1,     r1
    lea     r4,     [r1 * 2]
    lea     r5,     [r3 * 2]
    PIXEL_SSD_SP_16x4
    lea     r0,     [r0 + r4]
    lea     r2,     [r2 + r5]
    PIXEL_SSD_SP_16x4
    lea     r0,     [r0 + r4]
    lea     r2,     [r2 + r5]
    PIXEL_SSD_SP_16x4
    HADDD   m7,     m1
    movd    eax,    m7
    RET

;-----------------------------------------------------------------------------
; int pixel_ssd_sp_16x16( int16_t *, intptr_t, uint8_t *, intptr_t )
;-----------------------------------------------------------------------------
INIT_XMM sse4
cglobal pixel_ssd_sp_16x16, 4, 6, 8, src1, stride1, src2, stride2

    pxor    m6,     m6
    pxor    m7,     m7
    add     r1,     r1
    lea     r4,     [r1 * 2]
    lea     r5,     [r3 * 2]
    PIXEL_SSD_SP_16x4
    lea     r0,     [r0 + r4]
    lea     r2,     [r2 + r5]
    PIXEL_SSD_SP_16x4
    lea     r0,     [r0 + r4]
    lea     r2,     [r2 + r5]
    PIXEL_SSD_SP_16x4
    lea     r0,     [r0 + r4]
    lea     r2,     [r2 + r5]
    PIXEL_SSD_SP_16x4
    HADDD   m7,     m1
    movd    eax,    m7
    RET

cglobal pixel_ssd_sp_16x16_internal
    PIXEL_SSD_SP_16x4
    lea     r0,    [r0 + r4]
    lea     r2,    [r2 + 2 * r3]
    PIXEL_SSD_SP_16x4
    lea     r0,    [r0 + r4]
    lea     r2,    [r2 + 2 * r3]
    PIXEL_SSD_SP_16x4
    lea     r0,    [r0 + r4]
    lea     r2,    [r2 + 2 * r3]
    PIXEL_SSD_SP_16x4
    ret

;-----------------------------------------------------------------------------
; int pixel_ssd_sp_16x32( int16_t *, intptr_t, uint8_t *, intptr_t )
;-----------------------------------------------------------------------------
INIT_XMM sse4
cglobal pixel_ssd_sp_16x32, 4, 5, 8, src1, stride1, src2, stride2

    pxor     m6,     m6
    pxor     m7,     m7
    add      r1,     r1
    lea      r4,     [r1 * 2]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_16x16_internal
    HADDD    m7,     m1
    movd     eax,    m7
    RET

;-----------------------------------------------------------------------------
; int pixel_ssd_sp_16x64( int16_t *, intptr_t, uint8_t *, intptr_t )
;-----------------------------------------------------------------------------
INIT_XMM sse4
cglobal pixel_ssd_sp_16x64, 4, 6, 8, src1, stride1, src2, stride2

    pxor     m6,     m6
    pxor     m7,     m7
    add      r1,     r1
    lea      r4,     [r1 * 2]
    lea      r5,     [r3 * 2]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + r5]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + r5]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + r5]
    call     pixel_ssd_sp_16x16_internal

    HADDD    m7,     m1
    movd     eax,    m7
    RET

;-----------------------------------------------------------------------------
; int pixel_ssd_sp_24x32( int16_t *, intptr_t, uint8_t *, intptr_t )
;-----------------------------------------------------------------------------
INIT_XMM sse4
cglobal pixel_ssd_sp_24x32, 4, 7, 8, src1, stride1, src2, stride2
    pxor     m6,     m6
    pxor     m7,     m7
    add      r1,     r1
    lea      r4,     [r1 * 2]
    mov      r5,     r0
    mov      r6,     r2
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r5 + 32]
    lea      r2,     [r6 + 16]
    lea      r4,     [r1 * 3]
    lea      r5,     [r3 * 3]
    call     pixel_ssd_sp_8x4_internal
    lea      r0,     [r0 + 4 * r1]
    lea      r2,     [r2 + 4 * r3]
    call     pixel_ssd_sp_8x4_internal
    lea      r0,     [r0 + 4 * r1]
    lea      r2,     [r2 + 4 * r3]
    call     pixel_ssd_sp_8x4_internal
    lea      r0,     [r0 + 4 * r1]
    lea      r2,     [r2 + 4 * r3]
    call     pixel_ssd_sp_8x4_internal
    lea      r0,     [r0 + 4 * r1]
    lea      r2,     [r2 + 4 * r3]
    call     pixel_ssd_sp_8x4_internal
    lea      r0,     [r0 + 4 * r1]
    lea      r2,     [r2 + 4 * r3]
    call     pixel_ssd_sp_8x4_internal
    lea      r0,     [r0 + 4 * r1]
    lea      r2,     [r2 + 4 * r3]
    call     pixel_ssd_sp_8x4_internal
    lea      r0,     [r0 + 4 * r1]
    lea      r2,     [r2 + 4 * r3]
    call     pixel_ssd_sp_8x4_internal
    HADDD    m7,     m1
    movd     eax,    m7
    RET

;-----------------------------------------------------------------------------
; int pixel_ssd_32x8( uint8_t *, intptr_t, uint8_t *, intptr_t )
;-----------------------------------------------------------------------------
INIT_XMM sse4
cglobal pixel_ssd_sp_32x8, 4, 7, 8, src1, stride1, src2, stride2

    pxor     m7,     m7
    pxor     m6,     m6
    mov      r5,     r0
    mov      r6,     r2
    add      r1,     r1
    lea      r4,     [r1 * 2]
    PIXEL_SSD_SP_16x4
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + 2 * r3]
    PIXEL_SSD_SP_16x4
    lea      r0,     [r5 + 32]
    lea      r2,     [r6 + 16]
    PIXEL_SSD_SP_16x4
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + 2 * r3]
    PIXEL_SSD_SP_16x4
    HADDD    m7,     m1
    movd     eax,    m7
    RET

;-----------------------------------------------------------------------------
; int pixel_ssd_32x16( uint8_t *, intptr_t, uint8_t *, intptr_t )
;-----------------------------------------------------------------------------
INIT_XMM sse4
cglobal pixel_ssd_sp_32x16, 4, 7, 8, src1, stride1, src2, stride2

    pxor     m7,     m7
    pxor     m6,     m6
    mov      r5,     r0
    mov      r6,     r2
    add      r1,     r1
    lea      r4,     [r1 * 2]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r5 + 32]
    lea      r2,     [r6 + 16]
    call     pixel_ssd_sp_16x16_internal
    HADDD    m7,     m1
    movd     eax,    m7
    RET

;-----------------------------------------------------------------------------
; int pixel_ssd_32x24( uint8_t *, intptr_t, uint8_t *, intptr_t )
;-----------------------------------------------------------------------------
INIT_XMM sse4
cglobal pixel_ssd_sp_32x24, 4, 7, 8, src1, stride1, src2, stride2

    pxor     m7,     m7
    pxor     m6,     m6
    mov      r5,     r0
    mov      r6,     r2
    add      r1,     r1
    lea      r4,     [r1 * 2]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + 2 * r3]
    PIXEL_SSD_SP_16x4
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + 2 * r3]
    PIXEL_SSD_SP_16x4
    lea      r0,     [r5 + 32]
    lea      r2,     [r6 + 16]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + 2 * r3]
    PIXEL_SSD_SP_16x4
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + 2 * r3]
    PIXEL_SSD_SP_16x4
    HADDD    m7,     m1
    movd     eax,    m7
    RET

;-----------------------------------------------------------------------------
; int pixel_ssd_32x32( uint8_t *, intptr_t, uint8_t *, intptr_t )
;-----------------------------------------------------------------------------
INIT_XMM sse4
cglobal pixel_ssd_sp_32x32, 4, 7, 8, src1, stride1, src2, stride2

    pxor     m7,     m7
    pxor     m6,     m6
    mov      r5,     r0
    mov      r6,     r2
    add      r1,     r1
    lea      r4,     [r1 * 2]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r5 + 32]
    lea      r2,     [r6 + 16]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_16x16_internal
    HADDD    m7,     m1
    movd     eax,    m7
    RET

;-----------------------------------------------------------------------------
; int pixel_ssd_32x64( uint8_t *, intptr_t, uint8_t *, intptr_t )
;-----------------------------------------------------------------------------
INIT_XMM sse4
cglobal pixel_ssd_sp_32x64, 4, 7, 8, src1, stride1, src2, stride2

    pxor     m7,     m7
    pxor     m6,     m6
    mov      r5,     r0
    mov      r6,     r2
    add      r1,     r1
    lea      r4,     [r1 * 2]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r5 + 32]
    lea      r2,     [r6 + 16]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_16x16_internal
    HADDD    m7,     m1
    movd     eax,    m7
    RET

;-----------------------------------------------------------------------------
; int pixel_ssd_48x64( uint8_t *, intptr_t, uint8_t *, intptr_t )
;-----------------------------------------------------------------------------
INIT_XMM sse4
cglobal pixel_ssd_sp_48x64, 4, 7, 8, src1, stride1, src2, stride2

    pxor     m7,     m7
    pxor     m6,     m6
    mov      r5,     r0
    mov      r6,     r2
    add      r1,     r1
    lea      r4,     [r1 * 2]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r5 + 32]
    lea      r2,     [r6 + 16]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r5 + 64]
    lea      r2,     [r6 + 32]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_16x16_internal
    HADDD    m7,     m1
    movd     eax,    m7
    RET

;-----------------------------------------------------------------------------
; int pixel_ssd_64x16( uint8_t *, intptr_t, uint8_t *, intptr_t )
;-----------------------------------------------------------------------------
INIT_XMM sse4
cglobal pixel_ssd_sp_64x16, 4, 7, 8, src1, stride1, src2, stride2

    pxor     m7,     m7
    pxor     m6,     m6
    mov      r5,     r0
    mov      r6,     r2
    add      r1,     r1
    lea      r4,     [r1 * 2]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r5 + 32]
    lea      r2,     [r6 + 16]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r5 + 64]
    lea      r2,     [r6 + 32]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r5 + 96]
    lea      r2,     [r6 + 48]
    call     pixel_ssd_sp_16x16_internal
    HADDD    m7,     m1
    movd     eax,    m7
    RET

;-----------------------------------------------------------------------------
; int pixel_ssd_64x32( uint8_t *, intptr_t, uint8_t *, intptr_t )
;-----------------------------------------------------------------------------
INIT_XMM sse4
cglobal pixel_ssd_sp_64x32, 4, 7, 8, src1, stride1, src2, stride2

    pxor     m7,     m7
    pxor     m6,     m6
    mov      r5,     r0
    mov      r6,     r2
    add      r1,     r1
    lea      r4,     [r1 * 2]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r5 + 32]
    lea      r2,     [r6 + 16]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r5 + 64]
    lea      r2,     [r6 + 32]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r5 + 96]
    lea      r2,     [r6 + 48]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_16x16_internal
    HADDD    m7,     m1
    movd     eax,    m7
    RET

;-----------------------------------------------------------------------------
; int pixel_ssd_64x48( uint8_t *, intptr_t, uint8_t *, intptr_t )
;-----------------------------------------------------------------------------
INIT_XMM sse4
cglobal pixel_ssd_sp_64x48, 4, 7, 8, src1, stride1, src2, stride2

    pxor     m7,     m7
    pxor     m6,     m6
    mov      r5,     r0
    mov      r6,     r2
    add      r1,     r1
    lea      r4,     [r1 * 2]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r5 + 32]
    lea      r2,     [r6 + 16]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r5 + 64]
    lea      r2,     [r6 + 32]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r5 + 96]
    lea      r2,     [r6 + 48]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_16x16_internal
    HADDD    m7,     m1
    movd     eax,    m7
    RET

;-----------------------------------------------------------------------------
; int pixel_ssd_64x64( uint8_t *, intptr_t, uint8_t *, intptr_t )
;-----------------------------------------------------------------------------
INIT_XMM sse4
cglobal pixel_ssd_sp_64x64, 4, 7, 8, src1, stride1, src2, stride2

    pxor     m7,     m7
    pxor     m6,     m6
    mov      r5,     r0
    mov      r6,     r2
    add      r1,     r1
    lea      r4,     [r1 * 2]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r5 + 32]
    lea      r2,     [r6 + 16]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r5 + 64]
    lea      r2,     [r6 + 32]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r5 + 96]
    lea      r2,     [r6 + 48]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_16x16_internal
    lea      r0,     [r0 + r4]
    lea      r2,     [r2 + 2 * r3]
    call     pixel_ssd_sp_16x16_internal
    HADDD    m7,     m1
    movd     eax,    m7
    RET
