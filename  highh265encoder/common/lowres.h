/*****************************************************************************
 * Copyright (C) 2013 x265 project
 *
 * Authors: Gopu Govindaswamy <gopu@multicorewareinc.com>
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

#ifndef X265_LOWRES_H
#define X265_LOWRES_H

#include "primitives.h"
#include "common.h"
#include "mv.h"

namespace x265 {
// private namespace

class TComPicYuv;

struct ReferencePlanes
{
    ReferencePlanes() { memset(this, 0, sizeof(ReferencePlanes)); }

    pixel* fpelPlane;
    pixel* lowresPlane[4];

    bool isWeighted;
    bool isLowres;
    int  lumaStride;
    int  weight;
    int  offset;
    int  shift;
    int  round;

    /* lowres motion compensation, you must provide a buffer and stride for QPEL averaged pixels
     * in case QPEL is required.  Else it returns a pointer to the HPEL pixels */
    inline pixel *lowresMC(intptr_t blockOffset, const MV& qmv, pixel *buf, intptr_t& outstride)
    {
        if ((qmv.x | qmv.y) & 1)
        {
            int hpelA = (qmv.y & 2) | ((qmv.x & 2) >> 1);
            pixel *frefA = lowresPlane[hpelA] + blockOffset + (qmv.x >> 2) + (qmv.y >> 2) * lumaStride;

            MV qmvB = qmv + MV((qmv.x & 1) * 2, (qmv.y & 1) * 2);
            int hpelB = (qmvB.y & 2) | ((qmvB.x & 2) >> 1);

            pixel *frefB = lowresPlane[hpelB] + blockOffset + (qmvB.x >> 2) + (qmvB.y >> 2) * lumaStride;
            primitives.pixelavg_pp[LUMA_8x8](buf, outstride, frefA, lumaStride, frefB, lumaStride, 32);
            return buf;
        }
        else
        {
            outstride = lumaStride;
            int hpel = (qmv.y & 2) | ((qmv.x & 2) >> 1);
            return lowresPlane[hpel] + blockOffset + (qmv.x >> 2) + (qmv.y >> 2) * lumaStride;
        }
    }

    inline int lowresQPelCost(pixel *fenc, intptr_t blockOffset, const MV& qmv, pixelcmp_t comp)
    {
        if ((qmv.x | qmv.y) & 1)
        {
            ALIGN_VAR_16(pixel, subpelbuf[8 * 8]);
            int hpelA = (qmv.y & 2) | ((qmv.x & 2) >> 1);
            pixel *frefA = lowresPlane[hpelA] + blockOffset + (qmv.x >> 2) + (qmv.y >> 2) * lumaStride;
            MV qmvB = qmv + MV((qmv.x & 1) * 2, (qmv.y & 1) * 2);
            int hpelB = (qmvB.y & 2) | ((qmvB.x & 2) >> 1);
            pixel *frefB = lowresPlane[hpelB] + blockOffset + (qmvB.x >> 2) + (qmvB.y >> 2) * lumaStride;
            primitives.pixelavg_pp[LUMA_8x8](subpelbuf, 8, frefA, lumaStride, frefB, lumaStride, 32);
            return comp(fenc, FENC_STRIDE, subpelbuf, 8);
        }
        else
        {
            int hpel = (qmv.y & 2) | ((qmv.x & 2) >> 1);
            pixel *fref = lowresPlane[hpel] + blockOffset + (qmv.x >> 2) + (qmv.y >> 2) * lumaStride;
            return comp(fenc, FENC_STRIDE, fref, lumaStride);
        }
    }
};

/* lowres buffers, sizes and strides */
struct Lowres : public ReferencePlanes
{
    pixel *buffer[4];

    int    frameNum;         // Presentation frame number
    int    sliceType;        // Slice type decided by lookahead
    int    width;            // width of lowres frame in pixels
    int    lines;            // height of lowres frame in pixel lines
    int    leadingBframes;   // number of leading B frames for P or I

    bool   bIntraCalculated;
    bool   bScenecut;        // Set to false if the frame cannot possibly be part of a real scenecut.
    bool   bKeyframe;
    bool   bLastMiniGopBFrame;

    /* lookahead output data */
    int64_t   costEst[X265_BFRAME_MAX + 2][X265_BFRAME_MAX + 2];
    int64_t   costEstAq[X265_BFRAME_MAX + 2][X265_BFRAME_MAX + 2];
    int32_t*  rowSatds[X265_BFRAME_MAX + 2][X265_BFRAME_MAX + 2];
    int       intraMbs[X265_BFRAME_MAX + 2];
    int32_t*  intraCost;
    int64_t   satdCost;
    uint16_t* lowresCostForRc;
    uint16_t(*lowresCosts[X265_BFRAME_MAX + 2][X265_BFRAME_MAX + 2]);
    int32_t*  lowresMvCosts[2][X265_BFRAME_MAX + 1];
    MV*       lowresMvs[2][X265_BFRAME_MAX + 1];
    int       plannedType[X265_LOOKAHEAD_MAX + 1];
    int64_t   plannedSatd[X265_LOOKAHEAD_MAX + 1];
    int       bframes;

    /* rate control / adaptive quant data */
    double*   qpAqOffset;      // qp Aq offset values for each Cu
    int*      invQscaleFactor; // qScale values for qp Aq Offsets
    double*   qpOffset;
    uint64_t  wp_ssd[3];       // This is different than SSDY, this is sum(pixel^2) - sum(pixel)^2 for entire frame
    uint64_t  wp_sum[3];

    uint16_t* propagateCost;
    double    weightedCostDelta[X265_BFRAME_MAX + 2];

    bool create(TComPicYuv *orig, int _bframes, bool bAqEnabled);
    void destroy();
    void init(TComPicYuv *orig, int poc, int sliceType);
};
}

#endif // ifndef X265_LOWRES_H
