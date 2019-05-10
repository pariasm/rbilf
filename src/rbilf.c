#include <assert.h>     // assert
#include <stdlib.h>     // NULL, EXIT_SUCCESS/FAILURE
#include <stdio.h>      // printf, fprintf, stderr
#include <math.h>       // expf, nans (used as boundary value by bicubic interp)
#include <string.h>
#include "rbilf.h"

#define FLT_HUGE 1e10

// bicubic interpolation [[[1

#ifdef NAN
// extrapolate by nan
inline float getsample_nan(float *x, int w, int h, int pd, int i, int j, int l)
{
	assert(l >= 0 && l < pd);
	return (i < 0 || i >= w || j < 0 || j >= h) ? NAN : x[(i + j*w)*pd + l];
}
#endif//NAN

inline float cubic_interpolation(float v[4], float x)
{
	return v[1] + 0.5 * x*(v[2] - v[0]
			+ x*(2.0*v[0] - 5.0*v[1] + 4.0*v[2] - v[3]
			+ x*(3.0*(v[1] - v[2]) + v[3] - v[0])));
}

float bicubic_interpolation_cell(float p[4][4], float x, float y)
{
	float v[4];
	v[0] = cubic_interpolation(p[0], y);
	v[1] = cubic_interpolation(p[1], y);
	v[2] = cubic_interpolation(p[2], y);
	v[3] = cubic_interpolation(p[3], y);
	return cubic_interpolation(v, x);
}

void bicubic_interpolation_nans(float *result,
		float *img, int w, int h, int pd, float x, float y)
{
	x -= 1;
	y -= 1;

	int ix = floor(x);
	int iy = floor(y);
	for (int l = 0; l < pd; l++) {
		float c[4][4];
		for (int j = 0; j < 4; j++)
		for (int i = 0; i < 4; i++)
			c[i][j] = getsample_nan(img, w, h, pd, ix + i, iy + j, l);
		float r = bicubic_interpolation_cell(c, x - ix, y - iy);
		result[l] = r;
	}
}

void warp_bicubic(float *imw, float *im, float *of, float *msk,
		int w, int h, int ch)
{
	// warp previous frame
	for (int y = 0; y < h; ++y)
	for (int x = 0; x < w; ++x)
	if (!msk || (msk &&  msk[x + y*w] == 0))
	{
		float xw = x + of[(x + y*w)*2 + 0];
		float yw = y + of[(x + y*w)*2 + 1];
		bicubic_interpolation_nans(imw + (x + y*w)*ch, im, w, h, ch, xw, yw);
	}
	else
		for (int c = 0; c < ch; ++c)
			imw[(x + y*w)*ch + c] = NAN;

	return;
}

// recursive nl-means parameters [[[1

// set default parameters as a function of sigma
void rbilf_default_params(struct rbilf_params * p, float sigma, int step)
{
#ifdef OLD_PARAMS
	// the parameters are based on the following parameters
	// found with a parameter search:
	//
	//           wsz hx   hd  ht   hv ltv  lx
	// sigma 10:  10 10.2 4    7.5 0  0.5  0.1 
	// sigma 20:  10 24.4 1.6 14.1 0  0.3  0.1
	// sigma 40:  10 48.0 1.6 27.1 0  0.6  0.02
	if (step == 1)
	{
		if (p->weights_hx0  < 0) p->weights_hx0  = 1.07f * sigma + 66.9;
		if (p->weights_hd0  < 0) p->weights_hd0  = 0.92;
	}
	else
	{
		if (p->weights_hx0  < 0) p->weights_hx0  = 1.71 * sigma - 7.0;
		if (p->weights_hd0  < 0) p->weights_hd0  = 0.09 * sigma + 1.7;
	}
	if (p->weights_hx   < 0) p->weights_hx   = 1.2 * sigma;
	if (p->weights_hd   < 0) p->weights_hd   = 1.6;
	if (p->search_sz    < 0) p->search_sz    = 3*p->weights_hd;
	if (p->weights_thx  < 0) p->weights_thx  = .05f;
	if (p->weights_ht   < 0) p->weights_ht   = 0.7 * sigma;
	if (p->lambda_t     < 0) p->lambda_t    = 0.5;
	if (p->lambda_x < 0)
		p->lambda_x = fmax(0, fmin(0.2, 0.1 - (sigma - 20)/400));
#else
	if (step == 1)
	{
		if (sigma >= 40)
		{
			if (p->weights_hx0  < 0) p->weights_hx0  = 110;
			if (p->weights_hd0  < 0) p->weights_hd0  = 2;
		}
		else
		{
			if (p->weights_hx0  < 0) p->weights_hx0  = 55;
			if (p->weights_hd0  < 0) p->weights_hd0  = 1.6;
		}
	}
	else
	{
		if (p->weights_hx0  < 0) p->weights_hx0  = 1.71 * sigma - 7.0;
		if (p->weights_hd0  < 0) p->weights_hd0  = 0.09 * sigma + 1.7;
	}

	// 30    | 40     sigma
	// 22    | 26.5   whx
	// 1.6   | 1.6    whd
	// 0.05  | 0.05   lx
	// 18    | 25     wht
	// 0.02  | 0.01   lt
	// 0.2   | 0.2    ofw
	if (sigma >= 40) 
	{
		if (p->weights_hx   < 0) p->weights_hx   = 26.0;
		if (p->weights_hd   < 0) p->weights_hd   = 1.8;
		if (p->lambda_x     < 0) p->lambda_x     = .05;
		if (p->weights_ht   < 0) p->weights_ht   = 23;
		if (p->lambda_t     < 0) p->lambda_t     = .01;
		if (p->weights_thx  < 0) p->weights_thx  = .05;
		if (p->search_sz    < 0) p->search_sz    = 3*p->weights_hd;
	}
	else
	{
		if (p->weights_hx   < 0) p->weights_hx   = 18.0;
		if (p->weights_hd   < 0) p->weights_hd   = 1.2;
		if (p->lambda_x     < 0) p->lambda_x     = .05;
		if (p->weights_ht   < 0) p->weights_ht   = 17;
		if (p->lambda_t     < 0) p->lambda_t     = .03;
		if (p->weights_thx  < 0) p->weights_thx  = .05;
		if (p->search_sz    < 0) p->search_sz    = 3*p->weights_hd;
	}


#endif

	// limit search region to prevent too long running times
	p->search_sz = fmin(15, fmin(3*p->weights_hd, p->search_sz));
}

// recursive bilateral filter for frame t [[[1
void rbilateral_filter_frame(float *deno1, float *nisy1, float* guid1, float *deno0,
		int w, int h, int ch, float sigma,
		const struct rbilf_params prms, int frame)
{
	// definitions [[[2
	const float weights_ht2 = prms.weights_ht * prms.weights_ht;
	const float sigma2 = sigma * sigma;

	// set output and aggregation weights to 0
	for (int i = 0; i < w*h*ch; ++i) deno1[i] = 0.;

	// wrap images with nice pointers to vlas
	float (*d1)[w][ch] = (void *)deno1;       // denoised frame t (output)
	const float (*d0)[w][ch] = (void *)deno0; // denoised frame t-1
	const float (*n1)[w][ch] = (void *)nisy1; // noisy frame at t
	const float (*g1)[w][ch] = (void *)(guid1 ? guid1 : nisy1); // guide frame at t

	// loop on image pixels [[[2
	#pragma omp parallel for
	for (int py = 0; py < h; ++py)
	for (int px = 0; px < w; ++px)
	{
		// determine which parameters to use for spatial averaging
		float weights_hx2, weights_hd2;
		if (d0 && !isnan(d0[py][px][0]))
		{
			// params for spatio-temporal bilateral filter
			weights_hx2 = prms.weights_hx * prms.weights_hx;
			weights_hd2 = prms.weights_hd * prms.weights_hd * 2;
		}
		else
		{
			// params for spatial bilateral filter
			weights_hx2 = prms.weights_hx0 * prms.weights_hx0;
			weights_hd2 = prms.weights_hd0 * prms.weights_hd0 * 2;
		}

		// spatial average: loop on search region [[[3
		float D1[ch]; // denoised pixel at p in frame t
		for (int c = 0; c < ch ; ++c)	D1[c] = 0;
		float cp = 0.; // sum of similarity weights, used for normalization
		if (weights_hx2)
		{
			const int wsz = prms.search_sz;
			const int wx[2] = {fmax(px - wsz, 0), fmin(px + wsz + 1, w)};
			const int wy[2] = {fmax(py - wsz, 0), fmin(py + wsz + 1, h)};
			for (int qy = wy[0]; qy < wy[1]; ++qy)
			for (int qx = wx[0]; qx < wx[1]; ++qx)
			{
				// compute pixel distance [[[4
				float alpha = 0;
				const float l = prms.lambda_x;
				if (d0 && l != 1 && !isnan(d0[qy][qx][0]) && !isnan(d0[py][px][0]))
					// use noisy and denoised patches from previous frame
					for (int c = 0; c < ch ; ++c)
					{
						const float eN1 = g1[qy][qx][c] - g1[py][px][c];
						const float eD0 = d0[qy][qx][c] - d0[py][px][c];
						alpha += l * eN1 * eN1 + (1 - l) * eD0 * eD0;
					}
				else
					// use only noisy from current frame
					for (int c = 0; c < ch ; ++c)
					{
						const float eN1 = g1[qy][qx][c] - g1[py][px][c];
						alpha += eN1 * eN1;
					}

				// compute spatial similarity weight ]]]4[[[4
				alpha = expf(-1 / weights_hx2 * alpha / (float)(ch));

				if (weights_hd2 < FLT_HUGE)
				{
					if (weights_hd2)
					{
						const float dx = (px - qx), dy = (py - qy);
						alpha *= expf(-1 / weights_hd2 * (dx * dx + dy * dy) );
					}
					else
						alpha = (qx == px && qy == py) ? 1. : 0.;
				}

				// accumulate on output pixel ]]]4[[[4
				if (alpha > prms.weights_thx)
				{
					cp += alpha;
					for (int c = 0; c < ch; ++c)
						D1[c] += n1[qy][qx][c] * alpha;
				}// ]]]4
			}
		}
		else
		{
			// copy noisy pixel to output
			cp = 1.;
			for (int c = 0; c < ch; ++c)
				D1[c] = n1[py][px][c];
		}

		// store denoised pixel on output image
		float icp = 1. / fmax(cp, 1e-6);
		for (int c = 0; c < ch ; ++c )
			d1[py][px][c] = D1[c] * icp;


		// temporal average with frame t-1 [[[3
		if (d0 && !isnan(d0[py][px][0]))
		{
			// estimate temporal weight
			float beta = 0.;
			const float l01 = prms.lambda_t;
			for (int c = 0; c < ch; ++c)
			{
				const float eD = d1[py][px][c] - d0[py][px][c];
				const float eN = g1[py][px][c] - d0[py][px][c];
				beta += l01 * fmax(eN * eN - sigma2, 0.f) + (1 - l01) * eD * eD;
			}

			// normalize by number of channels
			beta /= (float)ch;

			// compute exponential weights
			beta = fmin(1, fmax(0, expf( - 1./weights_ht2 * beta )));

			// update pixel value
			for (int c = 0; c < ch; ++c)
				d1[py][px][c] = d0[py][px][c] * beta + d1[py][px][c] * (1 - beta);
		}
	}

	return; // ]]]2
}


// vim:set foldmethod=marker:
// vim:set foldmarker=[[[,]]]:
