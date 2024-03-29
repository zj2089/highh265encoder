/*****************************************************************************
 * Copyright (C) 2013 x265 project
 *
 * Authors: Deepthi Devaki <deepthidevaki@multicorewareinc.com>,
 *          Rajesh Paulraj <rajesh@multicorewareinc.com>
 *          Praveen Kumar Tiwari <praveen@multicorewareinc.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02111, USA.
 *
 * This program is also available under a commercial proprietary license.
 * For more information, contact us at licensing@multicorewareinc.com.
 *****************************************************************************/

#include "primitives.h"
#include "TLibCommon/TComRom.h"
#include "x265.h"

using namespace x265;

#if _MSC_VER
#pragma warning(disable: 4127) // conditional expression is constant, typical for templated functions
#endif

namespace {
template<int dstStride>
void filterConvertPelToShort_c(pixel *src, intptr_t srcStride, int16_t *dst, int width, int height)
{
    int shift = IF_INTERNAL_PREC - X265_DEPTH;
    int row, col;

    for (row = 0; row < height; row++)
    {
        for (col = 0; col < width; col++)
        {
            int16_t val = src[col] << shift;
            dst[col] = val - (int16_t)IF_INTERNAL_OFFS;
        }

        src += srcStride;
        dst += dstStride;
    }
}

void extendCURowColBorder(pixel* txt, intptr_t stride, int width, int height, int marginX)
{
    for (int y = 0; y < height; y++)
    {
#if HIGH_BIT_DEPTH
        for (int x = 0; x < marginX; x++)
        {
            txt[-marginX + x] = txt[0];
            txt[width + x] = txt[width - 1];
        }

#else
        ::memset(txt - marginX, txt[0], marginX);
        ::memset(txt + width, txt[width - 1], marginX);
#endif

        txt += stride;
    }
}

template<int N, int width, int height>
void interp_horiz_pp_c(pixel *src, intptr_t srcStride, pixel *dst, intptr_t dstStride, int coeffIdx)
{
    int16_t const * coeff = (N == 4) ? g_chromaFilter[coeffIdx] : g_lumaFilter[coeffIdx];
    int headRoom = IF_FILTER_PREC;
    int offset =  (1 << (headRoom - 1));
    uint16_t maxVal = (1 << X265_DEPTH) - 1;
    int cStride = 1;

    src -= (N / 2 - 1) * cStride;

    int row, col;
    for (row = 0; row < height; row++)
    {
        for (col = 0; col < width; col++)
        {
            int sum;

            sum  = src[col + 0 * cStride] * coeff[0];
            sum += src[col + 1 * cStride] * coeff[1];
            sum += src[col + 2 * cStride] * coeff[2];
            sum += src[col + 3 * cStride] * coeff[3];
            if (N == 8)
            {
                sum += src[col + 4 * cStride] * coeff[4];
                sum += src[col + 5 * cStride] * coeff[5];
                sum += src[col + 6 * cStride] * coeff[6];
                sum += src[col + 7 * cStride] * coeff[7];
            }
            int16_t val = (int16_t)((sum + offset) >> headRoom);

            if (val < 0) val = 0;
            if (val > maxVal) val = maxVal;
            dst[col] = (pixel)val;
        }

        src += srcStride;
        dst += dstStride;
    }
}

template<int N, int width, int height>
void interp_horiz_ps_c(pixel *src, intptr_t srcStride, int16_t *dst, intptr_t dstStride, int coeffIdx, int isRowExt)
{
    int16_t const * coeff = (N == 4) ? g_chromaFilter[coeffIdx] : g_lumaFilter[coeffIdx];
    int headRoom = IF_INTERNAL_PREC - X265_DEPTH;
    int shift = IF_FILTER_PREC - headRoom;
    int offset = -IF_INTERNAL_OFFS << shift;
    int blkheight = height;

    src -= N / 2 - 1;

    if (isRowExt)
    {
        src -= (N / 2 - 1) * srcStride;
        blkheight += N - 1;
    }

    int row, col;
    for (row = 0; row < blkheight; row++)
    {
        for (col = 0; col < width; col++)
        {
            int sum;

            sum  = src[col + 0] * coeff[0];
            sum += src[col + 1] * coeff[1];
            sum += src[col + 2] * coeff[2];
            sum += src[col + 3] * coeff[3];
            if (N == 8)
            {
                sum += src[col + 4] * coeff[4];
                sum += src[col + 5] * coeff[5];
                sum += src[col + 6] * coeff[6];
                sum += src[col + 7] * coeff[7];
            }

            int16_t val = (int16_t)((sum + offset) >> shift);
            dst[col] = val;
        }

        src += srcStride;
        dst += dstStride;
    }
}

template<int N, int width, int height>
void interp_vert_pp_c(pixel *src, intptr_t srcStride, pixel *dst, intptr_t dstStride, int coeffIdx)
{
    int16_t const * c = (N == 4) ? g_chromaFilter[coeffIdx] : g_lumaFilter[coeffIdx];
    int shift = IF_FILTER_PREC;
    int offset = 1 << (shift - 1);
    uint16_t maxVal = (1 << X265_DEPTH) - 1;

    src -= (N / 2 - 1) * srcStride;

    int row, col;
    for (row = 0; row < height; row++)
    {
        for (col = 0; col < width; col++)
        {
            int sum;

            sum  = src[col + 0 * srcStride] * c[0];
            sum += src[col + 1 * srcStride] * c[1];
            sum += src[col + 2 * srcStride] * c[2];
            sum += src[col + 3 * srcStride] * c[3];
            if (N == 8)
            {
                sum += src[col + 4 * srcStride] * c[4];
                sum += src[col + 5 * srcStride] * c[5];
                sum += src[col + 6 * srcStride] * c[6];
                sum += src[col + 7 * srcStride] * c[7];
            }

            int16_t val = (int16_t)((sum + offset) >> shift);
            val = (val < 0) ? 0 : val;
            val = (val > maxVal) ? maxVal : val;

            dst[col] = (pixel)val;
        }

        src += srcStride;
        dst += dstStride;
    }
}

template<int N, int width, int height>
void interp_vert_ps_c(pixel *src, intptr_t srcStride, int16_t *dst, intptr_t dstStride, int coeffIdx)
{
    int16_t const * c = (N == 4) ? g_chromaFilter[coeffIdx] : g_lumaFilter[coeffIdx];
    int headRoom = IF_INTERNAL_PREC - X265_DEPTH;
    int shift = IF_FILTER_PREC - headRoom;
    int offset = -IF_INTERNAL_OFFS << shift;

    src -= (N / 2 - 1) * srcStride;

    int row, col;
    for (row = 0; row < height; row++)
    {
        for (col = 0; col < width; col++)
        {
            int sum;

            sum  = src[col + 0 * srcStride] * c[0];
            sum += src[col + 1 * srcStride] * c[1];
            sum += src[col + 2 * srcStride] * c[2];
            sum += src[col + 3 * srcStride] * c[3];
            if (N == 8)
            {
                sum += src[col + 4 * srcStride] * c[4];
                sum += src[col + 5 * srcStride] * c[5];
                sum += src[col + 6 * srcStride] * c[6];
                sum += src[col + 7 * srcStride] * c[7];
            }

            int16_t val = (int16_t)((sum + offset) >> shift);
            dst[col] = val;
        }

        src += srcStride;
        dst += dstStride;
    }
}

template<int N, int width, int height>
void interp_vert_sp_c(int16_t *src, intptr_t srcStride, pixel *dst, intptr_t dstStride, int coeffIdx)
{
    int headRoom = IF_INTERNAL_PREC - X265_DEPTH;
    int shift = IF_FILTER_PREC + headRoom;
    int offset = (1 << (shift - 1)) + (IF_INTERNAL_OFFS << IF_FILTER_PREC);
    uint16_t maxVal = (1 << X265_DEPTH) - 1;
    const int16_t *coeff = (N == 8 ? g_lumaFilter[coeffIdx] : g_chromaFilter[coeffIdx]);

    src -= (N / 2 - 1) * srcStride;

    int row, col;
    for (row = 0; row < height; row++)
    {
        for (col = 0; col < width; col++)
        {
            int sum;

            sum  = src[col + 0 * srcStride] * coeff[0];
            sum += src[col + 1 * srcStride] * coeff[1];
            sum += src[col + 2 * srcStride] * coeff[2];
            sum += src[col + 3 * srcStride] * coeff[3];
            if (N == 8)
            {
                sum += src[col + 4 * srcStride] * coeff[4];
                sum += src[col + 5 * srcStride] * coeff[5];
                sum += src[col + 6 * srcStride] * coeff[6];
                sum += src[col + 7 * srcStride] * coeff[7];
            }

            int16_t val = (int16_t)((sum + offset) >> shift);

            val = (val < 0) ? 0 : val;
            val = (val > maxVal) ? maxVal : val;

            dst[col] = (pixel)val;
        }

        src += srcStride;
        dst += dstStride;
    }
}

template<int N, int width, int height>
void interp_vert_ss_c(int16_t *src, intptr_t srcStride, int16_t *dst, intptr_t dstStride, int coeffIdx)
{
    const int16_t *const c = (N == 8 ? g_lumaFilter[coeffIdx] : g_chromaFilter[coeffIdx]);
    int shift = IF_FILTER_PREC;
    int row, col;

    src -= (N / 2 - 1) * srcStride;
    for (row = 0; row < height; row++)
    {
        for (col = 0; col < width; col++)
        {
            int sum;

            sum  = src[col + 0 * srcStride] * c[0];
            sum += src[col + 1 * srcStride] * c[1];
            sum += src[col + 2 * srcStride] * c[2];
            sum += src[col + 3 * srcStride] * c[3];
            if (N == 8)
            {
                sum += src[col + 4 * srcStride] * c[4];
                sum += src[col + 5 * srcStride] * c[5];
                sum += src[col + 6 * srcStride] * c[6];
                sum += src[col + 7 * srcStride] * c[7];
            }

            int16_t val = (int16_t)((sum) >> shift);
            dst[col] = val;
        }

        src += srcStride;
        dst += dstStride;
    }
}

template<int N>
void filterVertical_sp_c(int16_t *src, intptr_t srcStride, pixel *dst, intptr_t dstStride, int width, int height, int coeffIdx)
{
    int headRoom = IF_INTERNAL_PREC - X265_DEPTH;
    int shift = IF_FILTER_PREC + headRoom;
    int offset = (1 << (shift - 1)) + (IF_INTERNAL_OFFS << IF_FILTER_PREC);
    uint16_t maxVal = (1 << X265_DEPTH) - 1;
    const int16_t *coeff = (N == 8 ? g_lumaFilter[coeffIdx] : g_chromaFilter[coeffIdx]);

    src -= (N / 2 - 1) * srcStride;

    int row, col;
    for (row = 0; row < height; row++)
    {
        for (col = 0; col < width; col++)
        {
            int sum;

            sum  = src[col + 0 * srcStride] * coeff[0];
            sum += src[col + 1 * srcStride] * coeff[1];
            sum += src[col + 2 * srcStride] * coeff[2];
            sum += src[col + 3 * srcStride] * coeff[3];
            if (N == 8)
            {
                sum += src[col + 4 * srcStride] * coeff[4];
                sum += src[col + 5 * srcStride] * coeff[5];
                sum += src[col + 6 * srcStride] * coeff[6];
                sum += src[col + 7 * srcStride] * coeff[7];
            }

            int16_t val = (int16_t)((sum + offset) >> shift);

            val = (val < 0) ? 0 : val;
            val = (val > maxVal) ? maxVal : val;

            dst[col] = (pixel)val;
        }

        src += srcStride;
        dst += dstStride;
    }
}

template<int N, int width, int height>
void interp_hv_pp_c(pixel *src, intptr_t srcStride, pixel *dst, intptr_t dstStride, int idxX, int idxY)
{
    short immedVals[(64 + 8) * (64 + 8)];

    interp_horiz_ps_c<N, width, height>(src, srcStride, immedVals, width, idxX, 1);
    filterVertical_sp_c<N>(immedVals + 3 * width, width, dst, dstStride, width, height, idxY);
}
}

namespace x265 {
// x265 private namespace

#define CHROMA_420(W, H) \
    p.chroma[X265_CSP_I420].filter_hpp[CHROMA_ ## W ## x ## H] = interp_horiz_pp_c<4, W, H>; \
    p.chroma[X265_CSP_I420].filter_hps[CHROMA_ ## W ## x ## H] = interp_horiz_ps_c<4, W, H>; \
    p.chroma[X265_CSP_I420].filter_vpp[CHROMA_ ## W ## x ## H] = interp_vert_pp_c<4, W, H>;  \
    p.chroma[X265_CSP_I420].filter_vps[CHROMA_ ## W ## x ## H] = interp_vert_ps_c<4, W, H>;  \
    p.chroma[X265_CSP_I420].filter_vsp[CHROMA_ ## W ## x ## H] = interp_vert_sp_c<4, W, H>;  \
    p.chroma[X265_CSP_I420].filter_vss[CHROMA_ ## W ## x ## H] = interp_vert_ss_c<4, W, H>;

#define CHROMA_444(W, H) \
    p.chroma[X265_CSP_I444].filter_hpp[LUMA_ ## W ## x ## H] = interp_horiz_pp_c<4, W, H>; \
    p.chroma[X265_CSP_I444].filter_hps[LUMA_ ## W ## x ## H] = interp_horiz_ps_c<4, W, H>; \
    p.chroma[X265_CSP_I444].filter_vpp[LUMA_ ## W ## x ## H] = interp_vert_pp_c<4, W, H>;  \
    p.chroma[X265_CSP_I444].filter_vps[LUMA_ ## W ## x ## H] = interp_vert_ps_c<4, W, H>;  \
    p.chroma[X265_CSP_I444].filter_vsp[LUMA_ ## W ## x ## H] = interp_vert_sp_c<4, W, H>;  \
    p.chroma[X265_CSP_I444].filter_vss[LUMA_ ## W ## x ## H] = interp_vert_ss_c<4, W, H>;

#define LUMA(W, H) \
    p.luma_hpp[LUMA_ ## W ## x ## H]     = interp_horiz_pp_c<8, W, H>; \
    p.luma_hps[LUMA_ ## W ## x ## H]     = interp_horiz_ps_c<8, W, H>; \
    p.luma_vpp[LUMA_ ## W ## x ## H]     = interp_vert_pp_c<8, W, H>;  \
    p.luma_vps[LUMA_ ## W ## x ## H]     = interp_vert_ps_c<8, W, H>;  \
    p.luma_vsp[LUMA_ ## W ## x ## H]     = interp_vert_sp_c<8, W, H>;  \
    p.luma_vss[LUMA_ ## W ## x ## H]     = interp_vert_ss_c<8, W, H>;  \
    p.luma_hvpp[LUMA_ ## W ## x ## H]    = interp_hv_pp_c<8, W, H>;

void Setup_C_IPFilterPrimitives(EncoderPrimitives& p)
{
    LUMA(4, 4);
    LUMA(8, 8);
    CHROMA_420(4,  4);
    LUMA(4, 8);
    CHROMA_420(2,  4);
    LUMA(8, 4);
    CHROMA_420(4,  2);
    LUMA(16, 16);
    CHROMA_420(8,  8);
    LUMA(16,  8);
    CHROMA_420(8,  4);
    LUMA(8, 16);
    CHROMA_420(4,  8);
    LUMA(16, 12);
    CHROMA_420(8,  6);
    LUMA(12, 16);
    CHROMA_420(6,  8);
    LUMA(16,  4);
    CHROMA_420(8,  2);
    LUMA(4, 16);
    CHROMA_420(2,  8);
    LUMA(32, 32);
    CHROMA_420(16, 16);
    LUMA(32, 16);
    CHROMA_420(16, 8);
    LUMA(16, 32);
    CHROMA_420(8,  16);
    LUMA(32, 24);
    CHROMA_420(16, 12);
    LUMA(24, 32);
    CHROMA_420(12, 16);
    LUMA(32,  8);
    CHROMA_420(16, 4);
    LUMA(8, 32);
    CHROMA_420(4,  16);
    LUMA(64, 64);
    CHROMA_420(32, 32);
    LUMA(64, 32);
    CHROMA_420(32, 16);
    LUMA(32, 64);
    CHROMA_420(16, 32);
    LUMA(64, 48);
    CHROMA_420(32, 24);
    LUMA(48, 64);
    CHROMA_420(24, 32);
    LUMA(64, 16);
    CHROMA_420(32, 8);
    LUMA(16, 64);
    CHROMA_420(8,  32);

    CHROMA_444(4,  4);
    CHROMA_444(8,  8);
    CHROMA_444(4,  8);
    CHROMA_444(8,  4);
    CHROMA_444(16, 16);
    CHROMA_444(16, 8);
    CHROMA_444(8,  16);
    CHROMA_444(16, 12);
    CHROMA_444(12, 16);
    CHROMA_444(16, 4);
    CHROMA_444(4,  16);
    CHROMA_444(32, 32);
    CHROMA_444(32, 16);
    CHROMA_444(16, 32);
    CHROMA_444(32, 24);
    CHROMA_444(24, 32);
    CHROMA_444(32, 8);
    CHROMA_444(8,  32);
    CHROMA_444(64, 64);
    CHROMA_444(64, 32);
    CHROMA_444(32, 64);
    CHROMA_444(64, 48);
    CHROMA_444(48, 64);
    CHROMA_444(64, 16);
    CHROMA_444(16, 64);
    p.luma_p2s = filterConvertPelToShort_c<MAX_CU_SIZE>;

    p.chroma_p2s[X265_CSP_I444] = filterConvertPelToShort_c<MAX_CU_SIZE>;
    p.chroma_p2s[X265_CSP_I420] = filterConvertPelToShort_c<MAX_CU_SIZE / 2>;

    p.extendRowBorder = extendCURowColBorder;
}
}
