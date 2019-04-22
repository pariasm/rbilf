#ifndef RBILF_H
#define RBILF_H
// recursive nl-means parameters [[[1

// struct for storing the parameters of the algorithm
struct rbilf_params
{
	int search_sz;       // search window radius
	float weights_hx0;   // spatial patch similarity weights parameter for spatial denoising
	float weights_hd0;   // spatial distance weights parameter for spatial denoising
	float weights_hx;    // spatial patch similarity weights parameter for spatio-temporal denoising
	float weights_hd;    // spatial distance weights parameter for spatio-temporal denoising
	float weights_thx;   // spatial weights threshold
	float weights_ht;    // temporal patch similarity weights parameter
	float lambda_x;      // weight of current frame in patch distance
	float lambda_t;      // weight of current frame in patch distance
};

// set default parameters as a function of sigma
void rbilf_default_params(struct rbilf_params * p, float sigma, int step);

// recursive bilateral filter for frame t [[[1
void rbilateral_filter_frame(float *deno1, float *nisy1, float *guid1, float *deno0,
		int w, int h, int ch, float sigma,
		const struct rbilf_params prms, int frame);

void warp_bicubic(float *imw, float *im, float *of, float* msk, int w, int h, int ch);

#endif // RBILF_H
// vim:set foldmethod=marker:
// vim:set foldmarker=[[[,]]]:
