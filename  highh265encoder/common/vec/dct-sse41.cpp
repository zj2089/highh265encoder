/*****************************************************************************
 * Copyright (C) 2013 x265 project
 *
 * Authors: Steve Borho <steve@borho.org>
 *          Mandar Gurav <mandar@multicorewareinc.com>
 *          Deepthi Devaki Akkoorath <deepthidevaki@multicorewareinc.com>
 *          Mahesh Pittala <mahesh@multicorewareinc.com>
 *          Rajesh Paulraj <rajesh@multicorewareinc.com>
 *          Min Chen <min.chen@multicorewareinc.com>
 *          Praveen Kumar Tiwari <praveen@multicorewareinc.com>
 *          Nabajit Deka <nabajit@multicorewareinc.com>
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
#include <xmmintrin.h> // SSE
#include <smmintrin.h> // SSE4.1

using namespace x265;

namespace {
void dequant_scaling(const int32_t* quantCoef, const int32_t *deQuantCoef, int32_t* coef, int num, int per, int shift)
{
    assert(num <= 32 * 32);

    int valueToAdd;

    shift += 4;

    if (shift > per)
    {
        valueToAdd = 1 << (shift - per - 1);
        __m128i IAdd = _mm_set1_epi32(valueToAdd);

        for (int n = 0; n < num; n = n + 8)
        {
            __m128i quantCoef1, quantCoef2, deQuantCoef1, deQuantCoef2, quantCoef12, sign;

            quantCoef1 = _mm_loadu_si128((__m128i*)(quantCoef + n));
            quantCoef2 = _mm_loadu_si128((__m128i*)(quantCoef + n + 4));

            deQuantCoef1 = _mm_loadu_si128((__m128i*)(deQuantCoef + n));
            deQuantCoef2 = _mm_loadu_si128((__m128i*)(deQuantCoef + n + 4));

            quantCoef12 = _mm_packs_epi32(quantCoef1, quantCoef2);
            sign = _mm_srai_epi16(quantCoef12, 15);
            quantCoef1 = _mm_unpacklo_epi16(quantCoef12, sign);
            quantCoef2 = _mm_unpackhi_epi16(quantCoef12, sign);

            quantCoef1 = _mm_sra_epi32(_mm_add_epi32(_mm_mullo_epi32(quantCoef1, deQuantCoef1), IAdd), _mm_cvtsi32_si128(shift - per));
            quantCoef2 = _mm_sra_epi32(_mm_add_epi32(_mm_mullo_epi32(quantCoef2, deQuantCoef2), IAdd), _mm_cvtsi32_si128(shift - per));

            quantCoef12 = _mm_packs_epi32(quantCoef1, quantCoef2);
            sign = _mm_srai_epi16(quantCoef12, 15);
            quantCoef1 = _mm_unpacklo_epi16(quantCoef12, sign);
            _mm_storeu_si128((__m128i*)(coef + n), quantCoef1);
            quantCoef2 = _mm_unpackhi_epi16(quantCoef12, sign);
            _mm_storeu_si128((__m128i*)(coef + n + 4), quantCoef2);
        }
    }
    else
    {
        for (int n = 0; n < num; n = n + 8)
        {
            __m128i quantCoef1, quantCoef2, deQuantCoef1, deQuantCoef2, quantCoef12, sign;

            quantCoef1 = _mm_loadu_si128((__m128i*)(quantCoef + n));
            quantCoef2 = _mm_loadu_si128((__m128i*)(quantCoef + n + 4));

            deQuantCoef1 = _mm_loadu_si128((__m128i*)(deQuantCoef + n));
            deQuantCoef2 = _mm_loadu_si128((__m128i*)(deQuantCoef + n + 4));

            quantCoef12 = _mm_packs_epi32(quantCoef1, quantCoef2);
            sign = _mm_srai_epi16(quantCoef12, 15);
            quantCoef1 = _mm_unpacklo_epi16(quantCoef12, sign);
            quantCoef2 = _mm_unpackhi_epi16(quantCoef12, sign);

            quantCoef1 = _mm_mullo_epi32(quantCoef1, deQuantCoef1);
            quantCoef2 = _mm_mullo_epi32(quantCoef2, deQuantCoef2);

            quantCoef12 = _mm_packs_epi32(quantCoef1, quantCoef2);
            sign = _mm_srai_epi16(quantCoef12, 15);
            quantCoef1 = _mm_unpacklo_epi16(quantCoef12, sign);
            quantCoef2 = _mm_unpackhi_epi16(quantCoef12, sign);

            quantCoef1 = _mm_sll_epi32(quantCoef1, _mm_cvtsi32_si128(per - shift));
            quantCoef2 = _mm_sll_epi32(quantCoef2, _mm_cvtsi32_si128(per - shift));

            quantCoef12 = _mm_packs_epi32(quantCoef1, quantCoef2);
            sign = _mm_srai_epi16(quantCoef12, 15);
            quantCoef1 = _mm_unpacklo_epi16(quantCoef12, sign);
            _mm_storeu_si128((__m128i*)(coef + n), quantCoef1);
            quantCoef2 = _mm_unpackhi_epi16(quantCoef12, sign);
            _mm_storeu_si128((__m128i*)(coef + n + 4), quantCoef2);
        }
    }
}
}

namespace x265 {
void Setup_Vec_DCTPrimitives_sse41(EncoderPrimitives &p)
{
    p.dequant_scaling = dequant_scaling;
}
}
