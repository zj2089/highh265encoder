/* The copyright in this software is being made available under the BSD
 * License, included below. This software may be subject to other third party
 * and contributor rights, including patent rights, and no such rights are
 * granted under this license.
 *
 * Copyright (c) 2010-2013, ITU/ISO/IEC
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *  * Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 *  * Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *  * Neither the name of the ITU/ISO/IEC nor the names of its contributors may
 *    be used to endorse or promote products derived from this software without
 *    specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 */

/** \file     TComWeightPrediction.h
    \brief    weighting prediction class (header)
*/

#ifndef X265_TCOMWEIGHTPREDICTION_H
#define X265_TCOMWEIGHTPREDICTION_H

// Include files
#include "TComPic.h"
#include "TComMotionInfo.h"
#include "TComPattern.h"

namespace x265 {
// private namespace

class TComYuv;

// ====================================================================================================================
// Class definition
// ====================================================================================================================
/// weighting prediction class
class TComWeightPrediction
{
public:

    TComWeightPrediction();

    void  getWpScaling(TComDataCU* cu, int refIdx0, int refIdx1, wpScalingParam *&wp0, wpScalingParam *&wp1);

    void  addWeightBi(TComYuv* srcYuv0, TComYuv* srcYuv1, uint32_t partUnitIdx, uint32_t width, uint32_t height, wpScalingParam *wp0, wpScalingParam *wp1, TComYuv* outDstYuv, bool bRound = true, bool bLuma = true, bool bChroma = true);
    void  addWeightBi(ShortYuv* srcYuv0, ShortYuv* srcYuv1, uint32_t partUnitIdx, uint32_t width, uint32_t height, wpScalingParam *wp0, wpScalingParam *wp1, TComYuv* outDstYuv, bool bRound = true, bool bLuma = true, bool bChroma = true);
    void  addWeightUni(TComYuv* srcYuv0, uint32_t partUnitIdx, uint32_t width, uint32_t height, wpScalingParam *wp0, TComYuv* outDstYuv, bool bLuma = true, bool bChroma = true);
    void  addWeightUni(ShortYuv* srcYuv0, uint32_t partUnitIdx, uint32_t width, uint32_t height, wpScalingParam *wp0, TComYuv* outDstYuv, bool bLuma = true, bool bChroma = true);

    void  xWeightedPredictionUni(TComDataCU* cu, TComYuv* srcYuv, uint32_t partAddr, int width, int height, int picList, TComYuv*& outPredYuv, int refIdx = -1, bool bLuma = true, bool bChroma = true);
    void  xWeightedPredictionUni(TComDataCU* cu, ShortYuv* srcYuv, uint32_t partAddr, int width, int height, int picList, TComYuv*& outPredYuv, int refIdx = -1, bool bLuma = true, bool bChroma = true);
    void  xWeightedPredictionBi(TComDataCU* cu, TComYuv* srcYuv0, TComYuv* srcYuv1, int refIdx0, int refIdx1, uint32_t partIdx, int width, int height, TComYuv* outDstYuv, bool bLuma = true, bool bChroma = true);
    void  xWeightedPredictionBi(TComDataCU* cu, ShortYuv* srcYuv0, ShortYuv* srcYuv1, int refIdx0, int refIdx1, uint32_t partIdx, int width, int height, TComYuv* outDstYuv, bool bLuma = true, bool bChroma = true);
};
}

#endif // ifndef X265_TCOMWEIGHTPREDICTION_H
