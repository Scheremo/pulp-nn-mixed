/*
 * ${config.filename}
 * Nazareno Bruschi <nazareno.bruschi@unibo.it>
 *
 * Copyright (C) 2019-2020 University of Bologna
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "pmsis.h"
#include "pulp_nn_utils.h"

<%
act_prec = int(config.kernel.act_prec[0:2])
act_t = f"int{act_prec}_t"
def su(sgn):
    return 's' if sgn else 'u'
def u_(sgn):
    return '' if sgn else 'u'
def s_(sgn):
    return 's' if sgn else ''


pt_in = f"{u_(config.kernel.in_signed)}int8_t"
vt_in = f"v4{su(config.kernel.in_signed)}"
pt_out = f"{u_(config.kernel.out_signed)}int8_t"
mac_fn = f"SumDotp{s_(config.kernel.in_signed)}4"
out_clip_fn = f"clip{s_(config.kernel.out_signed)}{config.kernel.out_data_t}"
%>

${pt_out} *${config.fn_name}(
                        ${pt_in} *pIn,
                        int8_t *pBias,
                        ${pt_out} *pOut,
                        ${pt_out} *pOut2,
                        int8_t *pWeight,
                        ${act_t} *pKappa,
                        ${act_t} *pLambda,
                        uint16_t out_mult,
                        uint16_t out_shift,
                        uint16_t num_col_im2col,
                        uint16_t ch_out,
                        uint8_t flag_relu,
                        uint8_t flag_batch_norm)
{
%if config.kernel.out_data_t == 2:
  int8_t mask2 = 0x0c;
  int8_t n_mask2 = ~ mask2;
  int8_t mask4 = 0x30;
  int8_t n_mask4 = ~ mask4;
  int8_t mask6 = 0xc0;
  int8_t n_mask6 = ~ mask6;
  int8_t off2 = 2;
  int8_t off4 = 4;
  int8_t off6 = 6;
%elif config.kernel.out_data_t == 4:
  int8_t mask = 0xf0;
  int8_t n_mask = ~ mask;
  int8_t off = 0x04;
%endif
%if config.kernel.wt_data_t == 2:
  v4s vecA[4];
  v4s vecA2[4];
  v4s vecA3[4];
  v4s vecA4[4];
  ${vt_in} vecB3;
  ${vt_in} vecB4;
  ${vt_in} vecB5;
  ${vt_in} vecB6;
  ${vt_in} vecB7;
  ${vt_in} vecB8;
%elif config.kernel.wt_data_t == 4:
  v4s vecA[2];
  v4s vecA2[2];
  v4s vecA3[2];
  v4s vecA4[2];
  ${vt_in} vecB3;
  ${vt_in} vecB4;
%else:
  v4s vecA;
  v4s vecA2;
  v4s vecA3;
  v4s vecA4;
%endif
  ${vt_in} vecB;
  ${vt_in} vecB2;

%if config.kernel.out_data_t == 2:
  uint16_t ch_out_r = ch_out >> 2;
%elif config.kernel.out_data_t == 4:
  uint16_t ch_out_r = ch_out >> 1;
%else:
  uint16_t ch_out_r = ch_out;
%endif
%if config.kernel.wt_data_t == 2:
  uint16_t num_col_im2col_w = num_col_im2col >> 2;
%elif config.kernel.wt_data_t == 4:
  uint16_t num_col_im2col_w = num_col_im2col >> 1;
%else:
  uint16_t num_col_im2col_w = num_col_im2col;
%endif

  //uint8_t *pOut2 = pOut + ch_out_r;
  int8_t *pA = pWeight;

  uint16_t chan_left = ch_out & 0x3;

  for(int i=0; i < (ch_out >> 2); i++)
  {
    ${pt_in} *pB =  pIn;
    ${pt_in} *pB2 = (pB + num_col_im2col);
    int8_t *pA2 = (pA + num_col_im2col_w);
    int8_t *pA3 = (pA2 + num_col_im2col_w);
    int8_t *pA4 = (pA3 + num_col_im2col_w);

    int sum = 0;
    int sum2 = 0;
    int sum3 = 0;
    int sum4 = 0;
    int sum5 = 0;
    int sum6 = 0;
    int sum7 = 0;
    int sum8 = 0;

    if (pBias != NULL)
    {
      sum = *((int*)  pBias);
      pBias+= 4;
      sum2 = *((int*)  pBias);
      pBias+= 4;
      sum3 = *((int*)  pBias);
      pBias+= 4;
      sum4 = *((int*)  pBias);
      pBias+= 4;

      sum5 = sum;
      sum6 = sum2;
      sum7 = sum3;
      sum8 = sum4;
    }

    for(int j=0; j<(num_col_im2col_w >> 2); j++)
    {
%if config.kernel.wt_data_t == 2:
      vecB = *((${vt_in}*)pB);
      vecB2 = *((${vt_in}*)pB2);
      vecB3 = *((${vt_in}*)(pB + 4));
      vecB4 = *((${vt_in}*)(pB2 + 4));
      vecB5 = *((${vt_in}*)(pB + 8));
      vecB6 = *((${vt_in}*)(pB2 + 8));
      vecB7 = *((${vt_in}*)(pB + 12));
      vecB8 = *((${vt_in}*)(pB2 + 12));

      pB+=16;
      pB2+=16;

      pA = ${config.unpack_fn}(pA,vecA);

      sum = ${mac_fn}(vecB, vecA[0], sum);
      sum5 = ${mac_fn}(vecB2, vecA[0], sum5);
      sum = ${mac_fn}(vecB3, vecA[1], sum);
      sum5 = ${mac_fn}(vecB4, vecA[1], sum5);
      sum = ${mac_fn}(vecB5, vecA[2], sum);
      sum5 = ${mac_fn}(vecB6, vecA[2], sum5);
      sum = ${mac_fn}(vecB7, vecA[3], sum);
      sum5 = ${mac_fn}(vecB8, vecA[3], sum5);

      pA2 = ${config.unpack_fn}(pA2,vecA2);

      sum2 = ${mac_fn}(vecB, vecA2[0], sum2);
      sum6 = ${mac_fn}(vecB2, vecA2[0], sum6);
      sum2 = ${mac_fn}(vecB3, vecA2[1], sum2);
      sum6 = ${mac_fn}(vecB4, vecA2[1], sum6);
      sum2 = ${mac_fn}(vecB5, vecA2[2], sum2);
      sum6 = ${mac_fn}(vecB6, vecA2[2], sum6);
      sum2 = ${mac_fn}(vecB7, vecA2[3], sum2);
      sum6 = ${mac_fn}(vecB8, vecA2[3], sum6);

      pA3 = ${config.unpack_fn}(pA3,vecA3);

      sum3 = ${mac_fn}(vecB, vecA3[0], sum3);
      sum7 = ${mac_fn}(vecB2, vecA3[0], sum7);
      sum3 = ${mac_fn}(vecB3, vecA3[1], sum3);
      sum7 = ${mac_fn}(vecB4, vecA3[1], sum7);
      sum3 = ${mac_fn}(vecB5, vecA3[2], sum3);
      sum7 = ${mac_fn}(vecB6, vecA3[2], sum7);
      sum3 = ${mac_fn}(vecB7, vecA3[3], sum3);
      sum7 = ${mac_fn}(vecB8, vecA3[3], sum7);

      pA4 = ${config.unpack_fn}(pA4,vecA4);

      sum4 = ${mac_fn}(vecB, vecA4[0], sum4);
      sum8 = ${mac_fn}(vecB2, vecA4[0], sum8);
      sum4 = ${mac_fn}(vecB3, vecA4[1], sum4);
      sum8 = ${mac_fn}(vecB4, vecA4[1], sum8);
      sum4 = ${mac_fn}(vecB5, vecA4[2], sum4);
      sum8 = ${mac_fn}(vecB6, vecA4[2], sum8);
      sum4 = ${mac_fn}(vecB7, vecA4[3], sum4);
      sum8 = ${mac_fn}(vecB8, vecA4[3], sum8);
%elif config.kernel.wt_data_t == 4:
      vecB = *((${vt_in}*)pB);
      vecB2 = *((${vt_in}*)pB2);
      vecB3 = *((${vt_in}*)(pB + 4));
      vecB4 = *((${vt_in}*)(pB2 + 4));

      pB+=8;
      pB2+=8;

      pA = ${config.unpack_fn}(pA,vecA);

      sum = ${mac_fn}(vecB, vecA[0], sum);
      sum5 = ${mac_fn}(vecB2, vecA[0], sum5);

      sum = ${mac_fn}(vecB3, vecA[1], sum);
      sum5 = ${mac_fn}(vecB4, vecA[1], sum5);

      pA2 = ${config.unpack_fn}(pA2,vecA2);

      sum2 = ${mac_fn}(vecB, vecA2[0], sum2);
      sum6 = ${mac_fn}(vecB2, vecA2[0], sum6);

      sum2 = ${mac_fn}(vecB3, vecA2[1], sum2);
      sum6 = ${mac_fn}(vecB4, vecA2[1], sum6);

      pA3 = ${config.unpack_fn}(pA3,vecA3);

      sum3 = ${mac_fn}(vecB, vecA3[0], sum3);
      sum7 = ${mac_fn}(vecB2, vecA3[0], sum7);

      sum3 = ${mac_fn}(vecB3, vecA3[1], sum3);
      sum7 = ${mac_fn}(vecB4, vecA3[1], sum7);

      pA4 = ${config.unpack_fn}(pA4,vecA4);

      sum4 = ${mac_fn}(vecB, vecA4[0], sum4);
      sum8 = ${mac_fn}(vecB2, vecA4[0], sum8);

      sum4 = ${mac_fn}(vecB3, vecA4[1], sum4);
      sum8 = ${mac_fn}(vecB4, vecA4[1], sum8);
%else:
      vecA = *((v4s*)pA);
      vecA2 = *((v4s*)pA2);
      vecA3 = *((v4s*)pA3);
      vecA4 = *((v4s*)pA4);

      vecB = *((${vt_in}*)pB);
      vecB2 = *((${vt_in}*)pB2);

      sum = ${mac_fn}(vecB, vecA, sum );
      sum2 = ${mac_fn}(vecB, vecA2, sum2);
      sum3 = ${mac_fn}(vecB, vecA3, sum3);
      sum4 = ${mac_fn}(vecB, vecA4, sum4);

      sum5 = ${mac_fn}(vecB2, vecA, sum5);
      sum6 = ${mac_fn}(vecB2, vecA2, sum6);
      sum7 = ${mac_fn}(vecB2, vecA3, sum7);
      sum8 = ${mac_fn}(vecB2, vecA4, sum8);

      pA+=4;
      pA2+=4;
      pA3+=4;
      pA4+=4;

      pB+=4;
      pB2+=4;
%endif
    }
%if config.kernel.wt_data_t == 2:
    uint16_t col_cnt_im2col = num_col_im2col & 0xf;
%elif config.kernel.wt_data_t == 4:
    uint16_t col_cnt_im2col = num_col_im2col & 0x7;
%else:
    uint16_t col_cnt_im2col = num_col_im2col & 0x3;
%endif
    while (col_cnt_im2col > 0)
    {
%if config.kernel.wt_data_t == 2:
      int8_t inA = (int8_t) bitext((int) *pA, 2, 0);
      int8_t inA2 = (int8_t) bitext((int) *pA2, 2, 0);
      int8_t inA3 = (int8_t) bitext((int) *pA3, 2, 0);
      int8_t inA4 = (int8_t) bitext((int) *pA4, 2, 0);
      uint8_t inB = *pB++;
      uint8_t inB2 = *pB2++;
      sum += inA * inB;
      sum2 += inA2 * inB;
      sum3 += inA3 * inB;
      sum4 += inA4 * inB;
      sum5 += inA * inB2;
      sum6 += inA2 * inB2;
      sum7 += inA3 * inB2;
      sum8 += inA4 * inB2;
      inA = (int8_t) bitext((int) *pA, 2, 2);
      inA2 = (int8_t) bitext((int) *pA2, 2, 2);
      inA3 = (int8_t) bitext((int) *pA3, 2, 2);
      inA4 = (int8_t) bitext((int) *pA4, 2, 2);
      inB = *pB++;
      inB2 = *pB2++;
      sum += inA * inB;
      sum2 += inA2 * inB;
      sum3 += inA3 * inB;
      sum4 += inA4 * inB;
      sum5 += inA * inB2;
      sum6 += inA2 * inB2;
      sum7 += inA3 * inB2;
      sum8 += inA4 * inB2;
      inA = (int8_t) bitext((int) *pA, 2, 4);
      inA2 = (int8_t) bitext((int) *pA2, 2, 4);
      inA3 = (int8_t) bitext((int) *pA3, 2, 4);
      inA4 = (int8_t) bitext((int) *pA4, 2, 4);
      inB = *pB++;
      inB2 = *pB2++;
      sum += inA * inB;
      sum2 += inA2 * inB;
      sum3 += inA3 * inB;
      sum4 += inA4 * inB;
      sum5 += inA * inB2;
      sum6 += inA2 * inB2;
      sum7 += inA3 * inB2;
      sum8 += inA4 * inB2;
      inA = (int8_t) bitext((int) *pA, 2, 6);
      inA2 = (int8_t) bitext((int) *pA2, 2, 6);
      inA3 = (int8_t) bitext((int) *pA3, 2, 6);
      inA4 = (int8_t) bitext((int) *pA4, 2, 6);
      inB = *pB++;
      inB2 = *pB2++;
      sum += inA * inB;
      sum2 += inA2 * inB;
      sum3 += inA3 * inB;
      sum4 += inA4 * inB;
      sum5 += inA * inB2;
      sum6 += inA2 * inB2;
      sum7 += inA3 * inB2;
      sum8 += inA4 * inB2;

      pA++;
      pA2++;
      pA3++;
      pA4++;
      col_cnt_im2col-=4;
%elif config.kernel.wt_data_t == 4:
      int8_t inA = (int8_t) bitext((int) *pA, 4, 0);
      int8_t inA2 = (int8_t) bitext((int) *pA2, 4, 0);
      int8_t inA3 = (int8_t) bitext((int) *pA3, 4, 0);
      int8_t inA4 = (int8_t) bitext((int) *pA4, 4, 0);
      uint8_t inB = *pB++;
      uint8_t inB2 = *pB2++;
      sum += inA * inB;
      sum2 += inA2 * inB;
      sum3 += inA3 * inB;
      sum4 += inA4 * inB;
      sum5 += inA * inB2;
      sum6 += inA2 * inB2;
      sum7 += inA3 * inB2;
      sum8 += inA4 * inB2;
      inA = (int8_t) bitext((int) *pA, 4, 4);
      inA2 = (int8_t) bitext((int) *pA2, 4, 4);
      inA3 = (int8_t) bitext((int) *pA3, 4, 4);
      inA4 = (int8_t) bitext((int) *pA4, 4, 4);
      inB = *pB++;
      inB2 = *pB2++;
      sum += inA * inB;
      sum2 += inA2 * inB;
      sum3 += inA3 * inB;
      sum4 += inA4 * inB;
      sum5 += inA * inB2;
      sum6 += inA2 * inB2;
      sum7 += inA3 * inB2;
      sum8 += inA4 * inB2;

      pA++;
      pA2++;
      pA3++;
      pA4++;
      col_cnt_im2col-=2;
%else:
      int8_t inA = *pA++;
      int8_t inA2 = *pA2++;
      int8_t inA3 = *pA3++;
      int8_t inA4 = *pA4++;
      uint8_t inB = *pB++;
      uint8_t inB2 = *pB2++;
      asm volatile("": : :"memory");
      sum += inA * inB;
      sum2 += inA2 * inB;
      sum3 += inA3 * inB;
      sum4 += inA4 * inB;
      sum5 += inA * inB2;
      sum6 += inA2 * inB2;
      sum7 += inA3 * inB2;
      sum8 += inA4 * inB2;

      col_cnt_im2col--;
%endif
    }
%if config.kernel.out_data_t == 8 or config.kernel.quantization == 'shift_clip':
    if (flag_batch_norm && flag_relu)
    {
%if config.kernel.out_data_t == 8:
      *pOut = ${config.bn_fn}(sum, *pKappa, *pLambda, out_shift);
      pOut++;
      *pOut2 = ${config.bn_fn}(sum5, *pKappa, *pLambda, out_shift);
      pOut2++;
      pKappa++;
      pLambda++;

      *pOut = ${config.bn_fn}(sum2, *pKappa, *pLambda, out_shift);
      pOut++;
      *pOut2 = ${config.bn_fn}(sum6, *pKappa, *pLambda, out_shift);
      pOut2++;
      pKappa++;
      pLambda++;

      *pOut = ${config.bn_fn}(sum3, *pKappa, *pLambda, out_shift);
      pOut++;
      *pOut2 = ${config.bn_fn}(sum7, *pKappa, *pLambda, out_shift);
      pOut2++;
      pKappa++;
      pLambda++;

      *pOut = ${config.bn_fn}(sum4, *pKappa, *pLambda, out_shift);
      pOut++;
      *pOut2 = ${config.bn_fn}(sum8, *pKappa, *pLambda, out_shift);
      pOut2++;
      pKappa++;
      pLambda++;
%elif config.kernel.out_data_t == 4:
      sum = ${config.bn_fn}(sum, *pKappa, *pLambda, out_shift);
      sum5 = ${config.bn_fn}(sum5, *pKappa, *pLambda, out_shift);
      pKappa++;
      pLambda++;
      sum2 = ${config.bn_fn}(sum2, *pKappa, *pLambda, out_shift);
      sum6 = ${config.bn_fn}(sum6, *pKappa, *pLambda, out_shift);
      *pOut = bitins(sum, n_mask, sum2, mask, off);
      *pOut2 = bitins(sum5, n_mask, sum6, mask, off);
      pKappa++;
      pLambda++;
      pOut++;
      pOut2++;
      sum3 = ${config.bn_fn}(sum3, *pKappa, *pLambda, out_shift);
      sum7 = ${config.bn_fn}(sum7, *pKappa, *pLambda, out_shift);
      pKappa++;
      pLambda++;
      sum4 = ${config.bn_fn}(sum4, *pKappa, *pLambda, out_shift);
      sum8 = ${config.bn_fn}(sum8, *pKappa, *pLambda, out_shift);
      pKappa++;
      pLambda++;
      *pOut = bitins(sum3, n_mask, sum4, mask, off);
      *pOut2 = bitins(sum7, n_mask, sum8, mask, off);
      pOut++;
      pOut2++;
%elif config.kernel.out_data_t == 2:
      sum = ${config.bn_fn}(sum, *pKappa, *pLambda, out_shift);
      sum5 = ${config.bn_fn}(sum5, *pKappa, *pLambda, out_shift);
      pKappa++;
      pLambda++;
      sum2 = ${config.bn_fn}(sum2, *pKappa, *pLambda, out_shift);
      sum6 = ${config.bn_fn}(sum6, *pKappa, *pLambda, out_shift);
      pKappa++;
      pLambda++;
      sum3 = ${config.bn_fn}(sum3, *pKappa, *pLambda, out_shift);
      sum7 = ${config.bn_fn}(sum7, *pKappa, *pLambda, out_shift);
      pKappa++;
      pLambda++;
      sum4 = ${config.bn_fn}(sum4, *pKappa, *pLambda, out_shift);
      sum8 = ${config.bn_fn}(sum8, *pKappa, *pLambda, out_shift);
      pKappa++;
      pLambda++;
      sum = bitins(sum, n_mask2, sum2, mask2, off2);
      sum = bitins(sum, n_mask4, sum3, mask4, off4);
      *pOut = bitins(sum, n_mask6, sum4, mask6, off6);
      sum5 = bitins(sum5, n_mask2, sum6, mask2, off2);
      sum5 = bitins(sum5, n_mask4, sum7, mask4, off4);
      *pOut2 = bitins(sum5, n_mask6, sum8, mask6, off6);
      pOut2++;
      pOut++;
%endif
    }
    else
    {
      if (flag_relu == 1)
      {
%if config.kernel.out_data_t == 8:
        *pOut = ${config.relu_fn}(sum, out_mult, out_shift);
        pOut++;
        *pOut = ${config.relu_fn}(sum2, out_mult, out_shift);
        pOut++;
        *pOut = ${config.relu_fn}(sum3, out_mult, out_shift);
        pOut++;
        *pOut = ${config.relu_fn}(sum4, out_mult, out_shift);
        pOut++;

        *pOut2 = ${config.relu_fn}(sum5, out_mult, out_shift);
        pOut2++;
        *pOut2 = ${config.relu_fn}(sum6, out_mult, out_shift);
        pOut2++;
        *pOut2 = ${config.relu_fn}(sum7, out_mult, out_shift);
        pOut2++;
        *pOut2 = ${config.relu_fn}(sum8, out_mult, out_shift);
        pOut2++;
%elif config.kernel.out_data_t == 4:
        sum = ${config.relu_fn}(sum, out_mult, out_shift);
        sum2 = ${config.relu_fn}(sum2, out_mult, out_shift);
        *pOut = bitins(sum, n_mask, sum2, mask, off);
        pOut++;
        sum3 = ${config.relu_fn}(sum3, out_mult, out_shift);
        sum4 = ${config.relu_fn}(sum4, out_mult, out_shift);
        *pOut = bitins(sum3, n_mask, sum4, mask, off);
        pOut++;

        sum5 = ${config.relu_fn}(sum5, out_mult, out_shift);
        sum6 = ${config.relu_fn}(sum6, out_mult, out_shift);
        *pOut2 = bitins(sum5, n_mask, sum6, mask, off);
        pOut2++;
        sum7 = ${config.relu_fn}(sum7, out_mult, out_shift);
        sum8 = ${config.relu_fn}(sum8, out_mult, out_shift);
        *pOut2 = bitins(sum7, n_mask, sum8, mask, off);
        pOut2++;
%elif config.kernel.out_data_t == 2:
        sum = ${config.relu_fn}(sum, out_mult, out_shift);
        sum2 = ${config.relu_fn}(sum2, out_mult, out_shift);
        sum3 = ${config.relu_fn}(sum3, out_mult, out_shift);
        sum4 = ${config.relu_fn}(sum4, out_mult, out_shift);
        sum = bitins(sum, n_mask2, sum2, mask2, off2);
        sum = bitins(sum, n_mask4, sum3, mask4, off4);
        *pOut = bitins(sum, n_mask6, sum4, mask6, off6);
        pOut++;
        sum5 = ${config.relu_fn}(sum5, out_mult, out_shift);
        sum6 = ${config.relu_fn}(sum6, out_mult, out_shift);
        sum7 = ${config.relu_fn}(sum7, out_mult, out_shift);
        sum8 = ${config.relu_fn}(sum8, out_mult, out_shift);
        sum5 = bitins(sum5, n_mask2, sum6, mask2, off2);
        sum5 = bitins(sum5, n_mask4, sum7, mask4, off4);
        *pOut2 = bitins(sum5, n_mask6, sum8, mask6, off6);
        pOut2++;
%endif
      }
      else
      {
%if config.kernel.out_data_t == 8:
        *pOut = (uint8_t) clip8(sum >> out_shift);
        pOut++;
        *pOut = (uint8_t) clip8(sum2 >> out_shift);
        pOut++;
        *pOut = (uint8_t) clip8(sum3 >> out_shift);
        pOut++;
        *pOut = (uint8_t) clip8(sum4 >> out_shift);
        pOut++;

        *pOut2 = (uint8_t) clip8(sum5 >> out_shift);
        pOut2++;
        *pOut2 = (uint8_t) clip8(sum6 >> out_shift);
        pOut2++;
        *pOut2 = (uint8_t) clip8(sum7 >> out_shift);
        pOut2++;
        *pOut2 = (uint8_t) clip8(sum8 >> out_shift);
        pOut2++;
%elif config.kernel.out_data_t == 4:
        sum = (uint8_t) clip4(sum >> out_shift);
        sum2 = (uint8_t) clip4(sum2 >> out_shift);
        *pOut = bitins(sum, n_mask, sum2, mask, off);
        pOut++;
        sum3 = (uint8_t) clip4(sum3 >> out_shift);
        sum4 = (uint8_t) clip4(sum4 >> out_shift);
        *pOut = bitins(sum3, n_mask, sum4, mask, off);
        pOut++;

        sum5 = (uint8_t) clip4(sum5 >> out_shift);
        sum6 = (uint8_t) clip4(sum6 >> out_shift);
        *pOut2 = bitins(sum5, n_mask, sum6, mask, off);
        pOut2++;
        sum7 = (uint8_t) clip4(sum7 >> out_shift);
        sum8 = (uint8_t) clip4(sum8 >> out_shift);
        *pOut2 = bitins(sum7, n_mask, sum8, mask, off);
        pOut2++;
%elif config.kernel.out_data_t == 2:
        sum = (uint8_t) clip2(sum >> out_shift);
        sum2 = (uint8_t) clip2(sum2 >> out_shift);
        sum3 = (uint8_t) clip2(sum3 >> out_shift);
        sum4 = (uint8_t) clip2(sum4 >> out_shift);
        sum = bitins(sum, n_mask2, sum2, mask2, off2);
        sum = bitins(sum, n_mask4, sum3, mask4, off4);
        *pOut = bitins(sum, n_mask6, sum4, mask6, off6);
        pOut++;

        sum5 = (uint8_t) clip2(sum5 >> out_shift);
        sum6 = (uint8_t) clip2(sum6 >> out_shift);
        sum7 = (uint8_t) clip2(sum7 >> out_shift);
        sum8 = (uint8_t) clip2(sum8 >> out_shift);
        sum5 = bitins(sum5, n_mask2, sum6, mask2, off2);
        sum5 = bitins(sum5, n_mask4, sum7, mask4, off4);
        *pOut2 = bitins(sum5, n_mask6, sum8, mask6, off6);
        pOut2++;
%endif
      }
    }
%elif config.kernel.out_data_t == 4:
    sum = pulp_nn_i4_quant(sum, pThr);
    sum5 = pulp_nn_i4_quant(sum5, pThr);

    pThr+=16;

    sum2 = pulp_nn_i4_quant(sum2, pThr);
    sum6 = pulp_nn_i4_quant(sum6, pThr);

    pThr+=16;

    sum3 = pulp_nn_i4_quant(sum3, pThr);
    sum7 = pulp_nn_i4_quant(sum7, pThr);

    pThr+=16;

    sum4 = pulp_nn_i4_quant(sum4, pThr);
    sum8 = pulp_nn_i4_quant(sum8, pThr);


    pThr+=16;

    *pOut = bitins(sum, n_mask, sum2, mask, off);

    pOut++;

    *pOut2 = bitins(sum5, n_mask, sum6, mask, off);

    pOut2++;

    *pOut = bitins(sum3, n_mask, sum4, mask, off);

    pOut++;

    *pOut2 = bitins(sum7, n_mask, sum8, mask, off);

    pOut2++;
%elif config.kernel.out_data_t == 2:
    sum = pulp_nn_i2_quant(sum, pThr);
    sum5 = pulp_nn_i2_quant(sum5, pThr);

    pThr+=4;

    sum2 = pulp_nn_i2_quant(sum2, pThr);
    sum6 = pulp_nn_i2_quant(sum6, pThr);

    sum = bitins(sum, n_mask2, sum2, mask2, off2);
    sum5 = bitins(sum5, n_mask2, sum6, mask2, off2);

    pThr+=4;

    sum3 = pulp_nn_i2_quant(sum3, pThr);
    sum7 = pulp_nn_i2_quant(sum7, pThr);

    sum = bitins(sum, n_mask4, sum3, mask4, off4);
    sum5 = bitins(sum5, n_mask4, sum7, mask4, off4);

    pThr+=4;

    sum4 = pulp_nn_i2_quant(sum4, pThr);
    sum8 = pulp_nn_i2_quant(sum8, pThr);

    pThr+=4;

    *pOut = bitins(sum, n_mask6, sum4, mask6, off6);

    pOut++;

    *pOut2 = bitins(sum5, n_mask6, sum8, mask6, off6);

    pOut2++;
%endif
    pA+=(3 * num_col_im2col_w);
  }
%if config.kernel.out_data_t != 2:
  %if config.kernel.out_data_t == 4:
   uint16_t i = 0;
  %endif
   while(chan_left)
  {
    ${pt_in} *pB = pIn;
    ${pt_in} *pB2 = (pB + num_col_im2col);
    int sum = 0;
    if (pBias != NULL){
      sum = *((int*) pBias);
      pBias += 4;
    }
    int sum2 = sum;

%if config.kernel.out_data_t == 4:
    ${pt_out} out[2];
    ${pt_out} out2[2];
%endif
    for(int j=0; j < (num_col_im2col_w >> 2); j++)
    {
%if config.kernel.wt_data_t == 2:
      vecB = *((${vt_in}*)pB);
      vecB2 = *((${vt_in}*)pB2);
      vecB3 = *((${vt_in}*)(pB + 4));
      vecB4 = *((${vt_in}*)(pB2 + 4));
      vecB5 = *((${vt_in}*)(pB + 8));
      vecB6 = *((${vt_in}*)(pB2 + 8));
      vecB7 = *((${vt_in}*)(pB + 12));
      vecB8 = *((${vt_in}*)(pB2 + 12));

      pA = ${config.unpack_fn}(pA,vecA);

      sum = ${mac_fn}(vecB, vecA[0], sum);
      sum2 = ${mac_fn}(vecB2, vecA[0], sum2);
      sum = ${mac_fn}(vecB3, vecA[1], sum);
      sum2 = ${mac_fn}(vecB4, vecA[1], sum2);
      sum = ${mac_fn}(vecB5, vecA[2], sum);
      sum2 = ${mac_fn}(vecB6, vecA[2], sum2);
      sum = ${mac_fn}(vecB7, vecA[3], sum);
      sum2 = ${mac_fn}(vecB8, vecA[3], sum2);

      pB+=16;
      pB2+=16;
%elif config.kernel.wt_data_t == 4:
      vecB = *((${vt_in}*)pB);
      vecB2 = *((${vt_in}*)pB2);
      vecB3 = *((${vt_in}*)(pB + 4));
      vecB4 = *((${vt_in}*)(pB2 + 4));

      pA = ${config.unpack_fn}(pA,vecA);

      sum = ${mac_fn}(vecB, vecA[0], sum);
      sum2 = ${mac_fn}(vecB2, vecA[0], sum2);

      sum = ${mac_fn}(vecB3, vecA[1], sum);
      sum2 = ${mac_fn}(vecB4, vecA[1], sum2);

      pB+=8;
      pB2+=8;
%else:
      vecA = *((v4s*) pA);
      vecB = *((${vt_in}*) pB);
      vecB2 = *((${vt_in}*) pB2);

      sum = ${mac_fn}(vecB, vecA, sum);
      sum2 = ${mac_fn}(vecB2, vecA, sum2);

      pA+=4;
      pB+=4;
      pB2+=4;
%endif
    }
%if config.kernel.wt_data_t == 2:
    uint16_t col_cnt_im2col = num_col_im2col & 0xf;
%elif config.kernel.wt_data_t == 4:
    uint16_t col_cnt_im2col = num_col_im2col & 0x7;
%else:
    uint16_t col_cnt_im2col = num_col_im2col & 0x3;
%endif
    while(col_cnt_im2col > 0)
    {
%if config.kernel.wt_data_t == 2:
      int8_t inA = (int8_t) bitext((int) *pA, 2, 0);
      uint8_t inB = *pB++;
      uint8_t inB2 = *pB2++;
      sum += inA * inB;
      sum2 += inA * inB2;
      inA = (int8_t) bitext((int) *pA, 2, 2);
      inB = *pB++;
      inB2 = *pB2++;
      sum += inA * inB;
      sum2 += inA * inB2;
      inA = (int8_t) bitext((int) *pA, 2, 4);
      inB = *pB++;
      inB2 = *pB2++;
      sum += inA * inB;
      sum2 += inA * inB2;
      inA = (int8_t) bitext((int) *pA, 2, 6);
      inB = *pB++;
      inB2 = *pB2++;
      sum += inA * inB;
      sum2 += inA * inB2;

      pA++;
      col_cnt_im2col-=4;
%elif config.kernel.wt_data_t == 4:
      int8_t inA = (int8_t) bitext((int) *pA, 4, 0);
      ${pt_out} inB = *pB++;
      ${pt_out} inB2 = *pB2++;
      sum += inA * inB;
      sum2 += inA * inB2;
      inA = (int8_t) bitext((int) *pA, 4, 4);
      inB = *pB++;
      inB2 = *pB2++;
      sum += inA * inB;
      sum2 += inA * inB2;

      pA++;
      col_cnt_im2col-=2;
%else:
      int8_t inA = *pA++;
      ${pt_out} inB = *pB++;
      ${pt_out} inB2 = *pB2++;
      asm volatile("": : :"memory");
      sum += inA * inB;
      sum2 += inA * inB2;

      col_cnt_im2col--;
%endif
    }
%if config.kernel.out_data_t == 8 or config.kernel.quantization == 'shift_clip':
    if (flag_batch_norm && flag_relu)
    {
%if config.kernel.out_data_t == 8:
      *pOut = ${config.bn_fn}(sum, *pKappa, *pLambda, out_shift);
      pOut++;
      *pOut2 = ${config.bn_fn}(sum2, *pKappa, *pLambda, out_shift);
      pOut2++;
      pKappa++;
      pLambda++;
%elif config.kernel.out_data_t == 4:
      uint8_t i_o = i & 0x01;
      out[i_o] = ${config.bn_fn}(sum, *pKappa, *pLambda, out_shift);
      out2[i_o] = ${config.bn_fn}(sum2, *pKappa, *pLambda, out_shift);
      pKappa++;
      pLambda++;
      if(i_o == 0x01)
      {
        *pOut = bitins(out[0], n_mask, out[1], mask, off);
        *pOut2 = bitins(out2[0], n_mask, out2[1], mask, off);
        pOut++;
        pOut2++;
      }
%endif
    }
    else
    {
      if (flag_relu == 1)
      {
%if config.kernel.out_data_t == 8:
        *pOut = ${config.relu_fn}(sum, out_mult, out_shift);
        pOut++;
        *pOut2 = ${config.relu_fn}(sum2, out_mult, out_shift);
        pOut2++;
%elif config.kernel.out_data_t == 4:
        uint8_t i_o = i & 0x01;
        out[i_o] = ${config.relu_fn}(sum, out_mult, out_shift);
        out2[i_o] = ${config.relu_fn}(sum2, out_mult, out_shift);
        if(i_o == 0x01)
        {
          *pOut = bitins(out[0], n_mask, out[1], mask, off);
          *pOut2 = bitins(out2[0], n_mask, out2[1], mask, off);
          pOut++;
          pOut2++;
        }
%endif
      }
      else
      {
%if config.kernel.out_data_t == 8:
        *pOut = (${pt_out}) ${out_clip_fn}(sum >> out_shift);
        pOut++;
        *pOut2 = (${pt_out}) ${out_clip_fn}(sum2 >> out_shift);
        pOut2++;
%elif config.kernel.out_data_t == 4:
        uint8_t i_o = i & 0x01;
        out[i_o] = (${pt_out}) ${out_clip_fn}(sum >> out_shift);
        out2[i_o] = (${pt_out}) ${out_clip_fn}(sum2 >> out_shift);
        if(i_o == 0x01)
        {
          *pOut = bitins(out[0], n_mask, out[1], mask, off);
          *pOut2 = bitins(out2[0], n_mask, out2[1], mask, off);
          pOut++;
          pOut2++;
        }
%endif
      }
    }
%elif config.kernel.out_data_t == 4:
    uint8_t i_o = i & 0x01;
    out[i_o] = pulp_nn_i4_quant(sum, pThr);
    out2[i_o] = pulp_nn_i4_quant(sum2, pThr);
    pThr+=16;
    if(i_o == 0x01)
    {
      *pOut = bitins(out[0], n_mask, out[1], mask, off);
      *pOut2 = bitins(out2[0], n_mask, out2[1], mask, off);
      pOut++;
      pOut2++;
    }
%endif
%if config.kernel.out_data_t == 4:
    i++;
%endif
    chan_left--;
  }
%endif
  pOut+=ch_out_r;
  return pOut;
}
