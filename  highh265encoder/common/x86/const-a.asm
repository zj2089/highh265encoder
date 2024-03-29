;*****************************************************************************
;* const-a.asm: x86 global constants
;*****************************************************************************
;* Copyright (C) 2010-2013 x264 project
;*
;* Authors: Loren Merritt <lorenm@u.washington.edu>
;*          Jason Garrett-Glaser <darkshikari@gmail.com>
;*          Min Chen <chenm003@163.com> <min.chen@multicorewareinc.com>
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

SECTION_RODATA 32

const hsub_mul,    times 16 db 1, -1
const pw_1,        times 16 dw 1
const pw_16,       times 16 dw 16
const pw_32,       times 16 dw 32
const pw_128,      times 16 dw 128
const pw_256,      times 16 dw 256
const pw_512,      times 16 dw 512
const pw_1023,     times 8  dw 1023
const pw_1024,     times 16 dw 1024
const pw_4096,     times 16 dw 4096
const pw_00ff,     times 16 dw 0x00ff
const pw_pixel_max,times 16 dw ((1 << BIT_DEPTH)-1)
const deinterleave_shufd, dd 0,4,1,5,2,6,3,7
const pb_unpackbd1, times 2 db 0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3
const pb_unpackbd2, times 2 db 4,4,4,4,5,5,5,5,6,6,6,6,7,7,7,7
const pb_unpackwq1, db 0,1,0,1,0,1,0,1,2,3,2,3,2,3,2,3
const pb_unpackwq2, db 4,5,4,5,4,5,4,5,6,7,6,7,6,7,6,7
const pw_swap,      times 2 db 6,7,4,5,2,3,0,1

const pb_01,       times  8 db 0,1
const pb_0,        times 16 db 0
const pb_1,        times 32 db 1
const pb_a1,       times 16 db 0xa1
const pb_3,        times 16 db 3
const pb_shuf8x8c, db 0,0,0,0,2,2,2,2,4,4,4,4,6,6,6,6

const pw_2,        times 8 dw 2
const pw_m2,       times 8 dw -2
const pw_4,        times 8 dw 4
const pw_8,        times 8 dw 8
const pw_64,       times 8 dw 64
const pw_256,      times 8 dw 256
const pw_32_0,     times 4 dw 32,
                   times 4 dw 0
const pw_2000,     times 8 dw 0x2000
const pw_8000,     times 8 dw 0x8000
const pw_3fff,     times 8 dw 0x3fff
const pw_ppppmmmm, dw 1,1,1,1,-1,-1,-1,-1
const pw_ppmmppmm, dw 1,1,-1,-1,1,1,-1,-1
const pw_pmpmpmpm, dw 1,-1,1,-1,1,-1,1,-1
const pw_pmmpzzzz, dw 1,-1,-1,1,0,0,0,0
const pd_1,        times 4 dd 1
const pd_2,        times 4 dd 2
const pd_4,        times 4 dd 4
const pd_8,        times 4 dd 8
const pd_16,       times 4 dd 16
const pd_32,       times 4 dd 32
const pd_64,       times 4 dd 64
const pd_128,      times 4 dd 128
const pd_256,      times 4 dd 256
const pd_512,      times 4 dd 512
const pd_1024,     times 4 dd 1024
const pd_2048,     times 4 dd 2048
const pd_ffff,     times 4 dd 0xffff
const pd_n32768,   times 4 dd 0xffff8000
const pw_ff00,     times 8 dw 0xff00

const multi_2Row,  dw 1, 2, 3, 4, 1, 2, 3, 4
const multiL,      dw 1, 2, 3, 4, 5, 6, 7, 8
const multiH,      dw 9, 10, 11, 12, 13, 14, 15, 16
const multiH2,     dw 17, 18, 19, 20, 21, 22, 23, 24
const multiH3,     dw 25, 26, 27, 28, 29, 30, 31, 32

const popcnt_table
%assign x 0
%rep 256
; population count
db ((x>>0)&1)+((x>>1)&1)+((x>>2)&1)+((x>>3)&1)+((x>>4)&1)+((x>>5)&1)+((x>>6)&1)+((x>>7)&1)
%assign x x+1
%endrep

const sw_64,       dd 64
