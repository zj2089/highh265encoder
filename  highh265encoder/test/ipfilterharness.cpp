/*****************************************************************************
 * Copyright (C) 2013 x265 project
 *
 * Authors: Deepthi Devaki <deepthidevaki@multicorewareinc.com>,
 *          Rajesh Paulraj <rajesh@multicorewareinc.com>
 *          Praveen Kumar Tiwari <praveen@multicorewareinc.com>
 *          Min Chen <chenm003@163.com> <min.chen@multicorewareinc.com>
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

#include "TLibCommon/TComRom.h"
#include "common.h"
#include "ipfilterharness.h"

#define ITERS  100
#define TEST_CASES 3
#define SMAX (1 << 12)
#define SMIN (-1 << 12)

using namespace x265;

IPFilterHarness::IPFilterHarness()
{
    // Assuming max_height = max_width = max_srcStride = max_dstStride = 100
    ipf_t_size = 200 * 200;

    CHECKED_MALLOC(pixel_buff, pixel, ipf_t_size);
    CHECKED_MALLOC(short_buff, int16_t, ipf_t_size);
    CHECKED_MALLOC(IPF_vec_output_s, int16_t, ipf_t_size);
    CHECKED_MALLOC(IPF_C_output_s, int16_t, ipf_t_size);
    CHECKED_MALLOC(IPF_vec_output_p, pixel, ipf_t_size);
    CHECKED_MALLOC(IPF_C_output_p, pixel, ipf_t_size);

    /* Array of pixel buffers */
    CHECKED_MALLOC(pixel_test_buff, pixel*, TEST_CASES);

    /* Array of short buffers */
    CHECKED_MALLOC(short_test_buff, int16_t*, TEST_CASES);

    for (int i = 0; i < TEST_CASES; i++)
    {
        CHECKED_MALLOC(pixel_test_buff[i], pixel, ipf_t_size);
        CHECKED_MALLOC(short_test_buff[i], int16_t, ipf_t_size);
    }

    /* [0] --- Random values
     * [1] --- Minimum
     * [2] --- Maximum */
    for (int i = 0; i < ipf_t_size; i++)
    {
        pixel_test_buff[0][i] = rand() & PIXEL_MAX;
        short_test_buff[0][i] = (rand() % (2 * SMAX)) - SMAX;

        pixel_test_buff[1][i] = PIXEL_MIN;
        short_test_buff[1][i] = SMIN;

        pixel_test_buff[2][i] = PIXEL_MAX;
        short_test_buff[2][i] = SMAX;
    }

    memset(IPF_C_output_p, 0xCD, ipf_t_size);
    memset(IPF_vec_output_p, 0xCD, ipf_t_size);
    memset(IPF_C_output_s, 0xCD, ipf_t_size * sizeof(int16_t));
    memset(IPF_vec_output_s, 0xCD, ipf_t_size * sizeof(int16_t));

    for (int i = 0; i < ipf_t_size; i++)                         // Initialize input buffer
    {
        int isPositive = rand() & 1;                             // To randomly generate Positive and Negative values
        isPositive = (isPositive) ? 1 : -1;
        pixel_buff[i] = (pixel)(rand() &  ((1 << 8) - 1));
        short_buff[i] = (int16_t)(isPositive) * (rand() &  SHRT_MAX);
    }
    return;

fail:
    exit(1);
}

IPFilterHarness::~IPFilterHarness()
{
    X265_FREE(IPF_vec_output_s);
    X265_FREE(IPF_C_output_s);
    X265_FREE(IPF_vec_output_p);
    X265_FREE(IPF_C_output_p);
    X265_FREE(short_buff);
    X265_FREE(pixel_buff);
    for (int i = 0; i < TEST_CASES; i++)
    {
        X265_FREE(pixel_test_buff[i]);
        X265_FREE(short_test_buff[i]);
    }

    X265_FREE(pixel_test_buff);
    X265_FREE(short_test_buff);
}

bool IPFilterHarness::check_IPFilter_primitive(filter_p2s_t ref, filter_p2s_t opt, int isChroma, int csp)
{
    intptr_t rand_srcStride;
    int min_size = isChroma ? 2 : 4;
    int max_size = isChroma ? (MAX_CU_SIZE >> 1) : MAX_CU_SIZE;

    if (isChroma && (csp == X265_CSP_I444))
    {
        min_size = 4;
        max_size = MAX_CU_SIZE;
    }

    for (int i = 0; i < ITERS; i++)
    {
        int index = i % TEST_CASES;
        int rand_height = (int16_t)rand() % 100;                 // Randomly generated Height
        int rand_width = (int16_t)rand() % 100;                  // Randomly generated Width

        rand_srcStride = rand_width + rand() % 100;              // Randomly generated srcStride
        if (rand_srcStride < rand_width)
            rand_srcStride = rand_width;

        rand_width &= ~(min_size - 1);
        rand_width = Clip3(min_size, max_size, rand_width);

        rand_height &= ~(min_size - 1);
        rand_height = Clip3(min_size, max_size, rand_height);

        ref(pixel_test_buff[index],
            rand_srcStride,
            IPF_C_output_s,
            rand_width,
            rand_height);

        opt(pixel_test_buff[index],
            rand_srcStride,
            IPF_vec_output_s,
            rand_width,
            rand_height);

        if (memcmp(IPF_vec_output_s, IPF_C_output_s, ipf_t_size))
            return false;
    }

    return true;
}

bool IPFilterHarness::check_IPFilterChroma_primitive(filter_pp_t ref, filter_pp_t opt)
{
    int rand_srcStride, rand_dstStride;

    for (int i = 0; i < ITERS; i++)
    {
        int index = i % TEST_CASES;

        for (int coeffIdx = 0; coeffIdx < 8; coeffIdx++)
        {
            rand_srcStride = rand() % 100 + 2;          // Randomly generated srcStride
            rand_dstStride = rand() % 100 + 32;         // Randomly generated dstStride

            opt(pixel_test_buff[index] + 3 * rand_srcStride,
                rand_srcStride,
                IPF_vec_output_p,
                rand_dstStride,
                coeffIdx);

            ref(pixel_test_buff[index] + 3 * rand_srcStride,
                rand_srcStride,
                IPF_C_output_p,
                rand_dstStride,
                coeffIdx);

            if (memcmp(IPF_vec_output_p, IPF_C_output_p, ipf_t_size))
                return false;
        }
    }

    return true;
}

bool IPFilterHarness::check_IPFilterChroma_ps_primitive(filter_ps_t ref, filter_ps_t opt)
{
    int rand_srcStride, rand_dstStride;

    for (int i = 0; i < ITERS; i++)
    {
        int index = i % TEST_CASES;

        for (int coeffIdx = 0; coeffIdx < 8; coeffIdx++)
        {
            rand_srcStride = rand() % 100;              // Randomly generated srcStride
            rand_dstStride = rand() % 100 + 32;         // Randomly generated dstStride

            ref(pixel_test_buff[index] + 3 * rand_srcStride,
                rand_srcStride,
                IPF_C_output_s,
                rand_dstStride,
                coeffIdx);

            opt(pixel_test_buff[index] + 3 * rand_srcStride,
                rand_srcStride,
                IPF_vec_output_s,
                rand_dstStride,
                coeffIdx);

            if (memcmp(IPF_vec_output_s, IPF_C_output_s, ipf_t_size * sizeof(int16_t)))
                return false;
        }
    }

    return true;
}

bool IPFilterHarness::check_IPFilterChroma_hps_primitive(filter_hps_t ref, filter_hps_t opt)
{
    int rand_srcStride, rand_dstStride;

    for (int i = 0; i < ITERS; i++)
    {
        int index = i % TEST_CASES;

        for (int coeffIdx = 0; coeffIdx < 8; coeffIdx++)
        {
            for (int isRowExt = 0; isRowExt < 2; isRowExt++)  // 0 : Interpolate W x H, 1 : Interpolate W x (H + 7)
            {
                rand_srcStride = rand() % 100 + 2;            // Randomly generated srcStride
                rand_dstStride = rand() % 100;                // Randomly generated dstStride

                ref(pixel_test_buff[index] + 3 * rand_srcStride,
                    rand_srcStride,
                    IPF_C_output_s,
                    rand_dstStride,
                    coeffIdx,
                    isRowExt);

                opt(pixel_test_buff[index] + 3 * rand_srcStride,
                    rand_srcStride,
                    IPF_vec_output_s,
                    rand_dstStride,
                    coeffIdx,
                    isRowExt);

                if (memcmp(IPF_vec_output_s, IPF_C_output_s, ipf_t_size * sizeof(int16_t)))
                    return false;
            }
        }
    }

    return true;
}

bool IPFilterHarness::check_IPFilterChroma_sp_primitive(filter_sp_t ref, filter_sp_t opt)
{
    int rand_srcStride, rand_dstStride;

    for (int i = 0; i < ITERS; i++)
    {
        int index = i % TEST_CASES;

        for (int coeffIdx = 0; coeffIdx < 8; coeffIdx++)
        {
            rand_srcStride = rand() % 100;              // Randomly generated srcStride
            rand_dstStride = rand() % 100 + 32;         // Randomly generated dstStride

            ref(short_test_buff[index] + 3 * rand_srcStride,
                rand_srcStride,
                IPF_C_output_p,
                rand_dstStride,
                coeffIdx);

            opt(short_test_buff[index] + 3 * rand_srcStride,
                rand_srcStride,
                IPF_vec_output_p,
                rand_dstStride,
                coeffIdx);

            if (memcmp(IPF_vec_output_p, IPF_C_output_p, ipf_t_size))
                return false;
        }
    }

    return true;
}

bool IPFilterHarness::check_IPFilterChroma_ss_primitive(filter_ss_t ref, filter_ss_t opt)
{
    int rand_srcStride, rand_dstStride;

    for (int i = 0; i < ITERS; i++)
    {
        int index = i % TEST_CASES;

        for (int coeffIdx = 0; coeffIdx < 8; coeffIdx++)
        {
            rand_srcStride = rand() % 100;              // Randomly generated srcStride
            rand_dstStride = rand() % 100 + 32;         // Randomly generated dstStride

            ref(short_test_buff[index] + 3 * rand_srcStride,
                rand_srcStride,
                IPF_C_output_s,
                rand_dstStride,
                coeffIdx);

            opt(short_test_buff[index] + 3 * rand_srcStride,
                rand_srcStride,
                IPF_vec_output_s,
                rand_dstStride,
                coeffIdx);

            if (memcmp(IPF_C_output_s, IPF_vec_output_s, ipf_t_size * sizeof(int16_t)))
                return false;
        }
    }

    return true;
}

bool IPFilterHarness::check_IPFilterLuma_primitive(filter_pp_t ref, filter_pp_t opt)
{
    int rand_srcStride, rand_dstStride;

    for (int i = 0; i < ITERS; i++)
    {
        int index = i % TEST_CASES;

        for (int coeffIdx = 0; coeffIdx < 4; coeffIdx++)
        {
            rand_srcStride = rand() % 100;             // Randomly generated srcStride
            rand_dstStride = rand() % 100 + 64;        // Randomly generated dstStride

            opt(pixel_test_buff[index] + 3 * rand_srcStride + 6,
                rand_srcStride,
                IPF_vec_output_p,
                rand_dstStride,
                coeffIdx);
            ref(pixel_test_buff[index] + 3 * rand_srcStride + 6,
                rand_srcStride,
                IPF_C_output_p,
                rand_dstStride,
                coeffIdx);

            if (memcmp(IPF_vec_output_p, IPF_C_output_p, ipf_t_size))
                return false;
        }
    }

    return true;
}

bool IPFilterHarness::check_IPFilterLuma_ps_primitive(filter_ps_t ref, filter_ps_t opt)
{
    int rand_srcStride, rand_dstStride;

    for (int i = 0; i < ITERS; i++)
    {
        int index = i % TEST_CASES;

        for (int coeffIdx = 0; coeffIdx < 4; coeffIdx++)
        {
            rand_srcStride = rand() % 100;             // Randomly generated srcStride
            rand_dstStride = rand() % 100 + 64;        // Randomly generated dstStride

            ref(pixel_test_buff[index] + 3 * rand_srcStride,
                rand_srcStride,
                IPF_C_output_s,
                rand_dstStride,
                coeffIdx);
            opt(pixel_test_buff[index] + 3 * rand_srcStride,
                rand_srcStride,
                IPF_vec_output_s,
                rand_dstStride,
                coeffIdx);

            if (memcmp(IPF_vec_output_s, IPF_C_output_s, ipf_t_size * sizeof(int16_t)))
                return false;
        }
    }

    return true;
}

bool IPFilterHarness::check_IPFilterLuma_hps_primitive(filter_hps_t ref, filter_hps_t opt)
{
    int rand_srcStride, rand_dstStride;

    for (int i = 0; i < ITERS; i++)
    {
        int index = i % TEST_CASES;

        for (int coeffIdx = 0; coeffIdx < 4; coeffIdx++)
        {
            for (int isRowExt = 0; isRowExt < 2; isRowExt++)  // 0 : Interpolate W x H, 1 : Interpolate W x (H + 7)
            {
                rand_srcStride = rand() % 100;                // Randomly generated srcStride
                rand_dstStride = rand() % 100 + 64;           // Randomly generated dstStride

                ref(pixel_test_buff[index] + 3 * rand_srcStride + 6,
                    rand_srcStride,
                    IPF_C_output_s,
                    rand_dstStride,
                    coeffIdx,
                    isRowExt);
                opt(pixel_test_buff[index] + 3 * rand_srcStride + 6,
                    rand_srcStride,
                    IPF_vec_output_s,
                    rand_dstStride,
                    coeffIdx,
                    isRowExt);

                if (memcmp(IPF_vec_output_s, IPF_C_output_s, ipf_t_size * sizeof(int16_t)))
                    return false;
            }
        }
    }

    return true;
}

bool IPFilterHarness::check_IPFilterLuma_sp_primitive(filter_sp_t ref, filter_sp_t opt)
{
    int rand_srcStride, rand_dstStride;

    for (int i = 0; i < ITERS; i++)
    {
        int index = i % TEST_CASES;

        for (int coeffIdx = 0; coeffIdx < 4; coeffIdx++)
        {
            rand_srcStride = rand() % 100;             // Randomly generated srcStride
            rand_dstStride = rand() % 100 + 64;        // Randomly generated dstStride

            ref(short_test_buff[index] + 3 * rand_srcStride,
                rand_srcStride,
                IPF_C_output_p,
                rand_dstStride,
                coeffIdx);

            opt(short_test_buff[index] + 3 * rand_srcStride,
                rand_srcStride,
                IPF_vec_output_p,
                rand_dstStride,
                coeffIdx);

            if (memcmp(IPF_vec_output_p, IPF_C_output_p, ipf_t_size))
                return false;
        }
    }

    return true;
}

bool IPFilterHarness::check_IPFilterLuma_ss_primitive(filter_ss_t ref, filter_ss_t opt)
{
    int rand_srcStride, rand_dstStride;

    for (int i = 0; i < ITERS; i++)
    {
        int index = i % TEST_CASES;

        for (int coeffIdx = 0; coeffIdx < 4; coeffIdx++)
        {
            rand_srcStride = rand() % 100;             // Randomly generated srcStride
            rand_dstStride = rand() % 100 + 64;        // Randomly generated dstStride

            ref(short_test_buff[index] + 3 * rand_srcStride,
                rand_srcStride,
                IPF_C_output_s,
                rand_dstStride,
                coeffIdx);

            opt(short_test_buff[index] + 3 * rand_srcStride,
                rand_srcStride,
                IPF_vec_output_s,
                rand_dstStride,
                coeffIdx);

            if (memcmp(IPF_C_output_s, IPF_vec_output_s, ipf_t_size * sizeof(int16_t)))
                return false;
        }
    }

    return true;
}

bool IPFilterHarness::check_IPFilterLumaHV_primitive(filter_hv_pp_t ref, filter_hv_pp_t opt)
{
    int rand_srcStride, rand_dstStride;

    for (int i = 0; i < ITERS; i++)
    {
        int index = i % TEST_CASES;

        for (int coeffIdxX = 0; coeffIdxX < 4; coeffIdxX++)    //coeffIdxX in the filter
        {
            for (int coeffIdxY = 0; coeffIdxY < 4; coeffIdxY++)    //coeffIdxY in the filter
            {
                rand_srcStride = rand() % 100;             // Randomly generated srcStride
                rand_dstStride = rand() % 100;             // Randomly generated dstStride

                ref(pixel_test_buff[index] + 3 * rand_srcStride,
                    rand_srcStride,
                    IPF_C_output_p,
                    rand_dstStride,
                    coeffIdxX,
                    coeffIdxY);
                opt(pixel_test_buff[index] + 3 * rand_srcStride,
                    rand_srcStride,
                    IPF_vec_output_p,
                    rand_dstStride,
                    coeffIdxX,
                    coeffIdxY);

                if (memcmp(IPF_vec_output_p, IPF_C_output_p, ipf_t_size))
                    return false;
            }
        }
    }

    return true;
}

bool IPFilterHarness::testCorrectness(const EncoderPrimitives& ref, const EncoderPrimitives& opt)
{
    if (opt.luma_p2s)
    {
        if (!check_IPFilter_primitive(ref.luma_p2s, opt.luma_p2s, 0, 1))   // last parameter does not matter in case of luma
        {
            printf("luma_p2s failed\n");
            return false;
        }
    }

    for (int value = 0; value < NUM_LUMA_PARTITIONS; value++)
    {
        if (opt.luma_hpp[value])
        {
            if (!check_IPFilterLuma_primitive(ref.luma_hpp[value], opt.luma_hpp[value]))
            {
                printf("luma_hpp[%s]", lumaPartStr[value]);
                return false;
            }
        }
        if (opt.luma_hps[value])
        {
            if (!check_IPFilterLuma_hps_primitive(ref.luma_hps[value], opt.luma_hps[value]))
            {
                printf("luma_hps[%s]", lumaPartStr[value]);
                return false;
            }
        }
        if (opt.luma_vpp[value])
        {
            if (!check_IPFilterLuma_primitive(ref.luma_vpp[value], opt.luma_vpp[value]))
            {
                printf("luma_vpp[%s]", lumaPartStr[value]);
                return false;
            }
        }
        if (opt.luma_vps[value])
        {
            if (!check_IPFilterLuma_ps_primitive(ref.luma_vps[value], opt.luma_vps[value]))
            {
                printf("luma_vps[%s]", lumaPartStr[value]);
                return false;
            }
        }
        if (opt.luma_vsp[value])
        {
            if (!check_IPFilterLuma_sp_primitive(ref.luma_vsp[value], opt.luma_vsp[value]))
            {
                printf("luma_vsp[%s]", lumaPartStr[value]);
                return false;
            }
        }
        if (opt.luma_vss[value])
        {
            if (!check_IPFilterLuma_ss_primitive(ref.luma_vss[value], opt.luma_vss[value]))
            {
                printf("luma_vss[%s]", lumaPartStr[value]);
                return false;
            }
        }
        if (opt.luma_hvpp[value])
        {
            if (!check_IPFilterLumaHV_primitive(ref.luma_hvpp[value], opt.luma_hvpp[value]))
            {
                printf("luma_hvpp[%s]", lumaPartStr[value]);
                return false;
            }
        }
    }

    for (int csp = X265_CSP_I420; csp < X265_CSP_COUNT; csp++)
    {
        if (opt.chroma_p2s[csp])
        {
            if (!check_IPFilter_primitive(ref.chroma_p2s[csp], opt.chroma_p2s[csp], 1, csp))
            {
                printf("chroma_p2s[%s]", x265_source_csp_names[csp]);
                return false;
            }
        }
        for (int value = 0; value < NUM_CHROMA_PARTITIONS; value++)
        {
            if (opt.chroma[csp].filter_hpp[value])
            {
                if (!check_IPFilterChroma_primitive(ref.chroma[csp].filter_hpp[value], opt.chroma[csp].filter_hpp[value]))
                {
                    printf("chroma_hpp[%s]", chromaPartStr[value]);
                    return false;
                }
            }
            if (opt.chroma[csp].filter_hps[value])
            {
                if (!check_IPFilterChroma_hps_primitive(ref.chroma[csp].filter_hps[value], opt.chroma[csp].filter_hps[value]))
                {
                    printf("chroma_hps[%s]", chromaPartStr[value]);
                    return false;
                }
            }
            if (opt.chroma[csp].filter_vpp[value])
            {
                if (!check_IPFilterChroma_primitive(ref.chroma[csp].filter_vpp[value], opt.chroma[csp].filter_vpp[value]))
                {
                    printf("chroma_vpp[%s]", chromaPartStr[value]);
                    return false;
                }
            }
            if (opt.chroma[csp].filter_vps[value])
            {
                if (!check_IPFilterChroma_ps_primitive(ref.chroma[csp].filter_vps[value], opt.chroma[csp].filter_vps[value]))
                {
                    printf("chroma_vps[%s]", chromaPartStr[value]);
                    return false;
                }
            }
            if (opt.chroma[csp].filter_vsp[value])
            {
                if (!check_IPFilterChroma_sp_primitive(ref.chroma[csp].filter_vsp[value], opt.chroma[csp].filter_vsp[value]))
                {
                    printf("chroma_vsp[%s]", chromaPartStr[value]);
                    return false;
                }
            }
            if (opt.chroma[csp].filter_vss[value])
            {
                if (!check_IPFilterChroma_ss_primitive(ref.chroma[csp].filter_vss[value], opt.chroma[csp].filter_vss[value]))
                {
                    printf("chroma_vss[%s]", chromaPartStr[value]);
                    return false;
                }
            }
        }
    }

    return true;
}

void IPFilterHarness::measureSpeed(const EncoderPrimitives& ref, const EncoderPrimitives& opt)
{
    int height = 64;
    int width = 64;
    int16_t srcStride = 96;
    int16_t dstStride = 96;
    int maxVerticalfilterHalfDistance = 3;

    if (opt.luma_p2s)
    {
        printf("luma_p2s\t");
        REPORT_SPEEDUP(opt.luma_p2s, ref.luma_p2s,
                       pixel_buff, srcStride, IPF_vec_output_s, width, height);
    }

    for (int value = 0; value < NUM_LUMA_PARTITIONS; value++)
    {
        if (opt.luma_hpp[value])
        {
            printf("luma_hpp[%s]\t", lumaPartStr[value]);
            REPORT_SPEEDUP(opt.luma_hpp[value], ref.luma_hpp[value],
                           pixel_buff + srcStride, srcStride, IPF_vec_output_p, dstStride, 1);
        }

        if (opt.luma_hps[value])
        {
            printf("luma_hps[%s]\t", lumaPartStr[value]);
            REPORT_SPEEDUP(opt.luma_hps[value], ref.luma_hps[value],
                           pixel_buff + maxVerticalfilterHalfDistance * srcStride, srcStride,
                           IPF_vec_output_s, dstStride, 1, 1);
        }

        if (opt.luma_vpp[value])
        {
            printf("luma_vpp[%s]\t", lumaPartStr[value]);
            REPORT_SPEEDUP(opt.luma_vpp[value], ref.luma_vpp[value],
                           pixel_buff + maxVerticalfilterHalfDistance * srcStride, srcStride,
                           IPF_vec_output_p, dstStride, 1);
        }

        if (opt.luma_vps[value])
        {
            printf("luma_vps[%s]\t", lumaPartStr[value]);
            REPORT_SPEEDUP(opt.luma_vps[value], ref.luma_vps[value],
                           pixel_buff + maxVerticalfilterHalfDistance * srcStride, srcStride,
                           IPF_vec_output_s, dstStride, 1);
        }

        if (opt.luma_vsp[value])
        {
            printf("luma_vsp[%s]\t", lumaPartStr[value]);
            REPORT_SPEEDUP(opt.luma_vsp[value], ref.luma_vsp[value],
                           short_buff + maxVerticalfilterHalfDistance * srcStride, srcStride,
                           IPF_vec_output_p, dstStride, 1);
        }

        if (opt.luma_vss[value])
        {
            printf("luma_vss[%s]\t", lumaPartStr[value]);
            REPORT_SPEEDUP(opt.luma_vss[value], ref.luma_vss[value],
                           short_buff + maxVerticalfilterHalfDistance * srcStride, srcStride,
                           IPF_vec_output_s, dstStride, 1);
        }

        if (opt.luma_hvpp[value])
        {
            printf("luma_hv [%s]\t", lumaPartStr[value]);
            REPORT_SPEEDUP(opt.luma_hvpp[value], ref.luma_hvpp[value],
                           pixel_buff + 3 * srcStride, srcStride, IPF_vec_output_p, srcStride, 1, 3);
        }
    }

    for (int csp = X265_CSP_I420; csp < X265_CSP_COUNT; csp++)
    {
        printf("= Color Space %s =\n", x265_source_csp_names[csp]);
        if (opt.chroma_p2s[csp])
        {
            printf("chroma_p2s\t");
            REPORT_SPEEDUP(opt.chroma_p2s[csp], ref.chroma_p2s[csp],
                           pixel_buff, srcStride, IPF_vec_output_s, width, height);
        }
        for (int value = 0; value < NUM_CHROMA_PARTITIONS; value++)
        {
            if (opt.chroma[csp].filter_hpp[value])
            {
                printf("chroma_hpp[%s]", chromaPartStr[value]);
                REPORT_SPEEDUP(opt.chroma[csp].filter_hpp[value], ref.chroma[csp].filter_hpp[value],
                               pixel_buff + srcStride, srcStride, IPF_vec_output_p, dstStride, 1);
            }
            if (opt.chroma[csp].filter_hps[value])
            {
                printf("chroma_hps[%s]", chromaPartStr[value]);
                REPORT_SPEEDUP(opt.chroma[csp].filter_hps[value], ref.chroma[csp].filter_hps[value],
                               pixel_buff + srcStride, srcStride, IPF_vec_output_s, dstStride, 1, 1);
            }
            if (opt.chroma[csp].filter_vpp[value])
            {
                printf("chroma_vpp[%s]", chromaPartStr[value]);
                REPORT_SPEEDUP(opt.chroma[csp].filter_vpp[value], ref.chroma[csp].filter_vpp[value],
                               pixel_buff + maxVerticalfilterHalfDistance * srcStride, srcStride,
                               IPF_vec_output_p, dstStride, 1);
            }
            if (opt.chroma[csp].filter_vps[value])
            {
                printf("chroma_vps[%s]", chromaPartStr[value]);
                REPORT_SPEEDUP(opt.chroma[csp].filter_vps[value], ref.chroma[csp].filter_vps[value],
                               pixel_buff + maxVerticalfilterHalfDistance * srcStride, srcStride,
                               IPF_vec_output_s, dstStride, 1);
            }
            if (opt.chroma[csp].filter_vsp[value])
            {
                printf("chroma_vsp[%s]", chromaPartStr[value]);
                REPORT_SPEEDUP(opt.chroma[csp].filter_vsp[value], ref.chroma[csp].filter_vsp[value],
                               short_buff + maxVerticalfilterHalfDistance * srcStride, srcStride,
                               IPF_vec_output_p, dstStride, 1);
            }
            if (opt.chroma[csp].filter_vss[value])
            {
                printf("chroma_vss[%s]", chromaPartStr[value]);
                REPORT_SPEEDUP(opt.chroma[csp].filter_vss[value], ref.chroma[csp].filter_vss[value],
                               short_buff + maxVerticalfilterHalfDistance * srcStride, srcStride,
                               IPF_vec_output_s, dstStride, 1);
            }
        }
    }
}
