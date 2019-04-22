#include "argparse.h"   // command line parser
#include "iio.h"        // image i/o
#include <assert.h>     // assert
#include <stdlib.h>     // NULL, EXIT_SUCCESS/FAILURE
#include <stdio.h>      // printf, fprintf, stderr
#include "rbilf.h"

// 'usage' message in the command line
static const char *const usages[] = {
	"rbilf [options] [[--] args]",
	"rbilf [options]",
	NULL,
};

int main(int argc, const char *argv[])
{
	omp_set_num_threads(2);
	// parse command line [[[2

	// command line parameters and their defaults
	const char *nisy1_path = NULL;
	const char *deno0_path = NULL;
	const char *deno1_path = NULL;
	const char *guid1_path = NULL;
	const char *bflow_path = NULL;
	const char *boccl_path = NULL;
	float sigma = 0.f;
	bool verbose = false;
	int verbose_int = 0;
	struct rbilf_params prms;

	prms.search_sz    = -1; // -1 means automatic value
	prms.weights_hx0  = -1.;
	prms.weights_hd0  = -1.;
	prms.weights_hx   = -1.;
	prms.weights_hd   = -1.;
	prms.weights_thx  = -1.;
	prms.weights_ht   = -1.;
	prms.lambda_x     = -1.;
	prms.lambda_t     = -1.;

	// configure command line parser
	struct argparse_option options[] = {
		OPT_HELP(),
		OPT_GROUP("Algorithm options"),
		OPT_STRING ('i', "nisy"   , &nisy1_path, "noisy input path"),
		OPT_STRING ('o', "flow"   , &bflow_path, "backward flow path"),
		OPT_STRING ('k', "bocc"   , &boccl_path, "input bwd occlusion masks path"),
		OPT_STRING ( 0 , "den0"   , &deno0_path, "previous denoised frame path"),
		OPT_STRING ( 0 , "den1"   , &deno1_path, "denoised output frame path"),
		OPT_STRING ( 0 , "gui1"   , &guid1_path, "guide frame path"),
		OPT_FLOAT  ('s', "sigma"  , &sigma, "noise standard dev"),
		OPT_INTEGER('w', "search" , &prms.search_sz, "search region radius"),
		OPT_FLOAT  ( 0 , "whx0"   , &prms.weights_hx0, "spatial pixel sim. weights param (spatial denoising)"),
		OPT_FLOAT  ( 0 , "whd0"   , &prms.weights_hd0, "spatial distance weights param (spatial denoising)"),
		OPT_FLOAT  ( 0 , "whx"    , &prms.weights_hx, "spatial pixel sim. weights param (spatio-temp denoising)"),
		OPT_FLOAT  ( 0 , "whd"    , &prms.weights_hd, "spatial distance weights param (spatio-temp denoising)"),
		OPT_FLOAT  ( 0 , "wthx"   , &prms.weights_thx, "spatial weights threshold"),
		OPT_FLOAT  ( 0 , "wht"    , &prms.weights_ht, "temporal pixel sim. weights param"),
		OPT_FLOAT  ( 0 , "lambdax", &prms.lambda_x, "noisy pixel weight in spatial pixel distance"),
		OPT_FLOAT  ( 0 , "lambdat", &prms.lambda_t, "noisy pixel weight in temporal pixel distance"),
		OPT_GROUP("Program options"),
		OPT_INTEGER('v', "verbose", &verbose_int, "verbose output"),
		OPT_END(),
	};

	// parse command line
	struct argparse argparse;
	argparse_init(&argparse, options, usages, 0);
	argparse_describe(&argparse, "\nVideo denoiser based on recursive bilateral filter.", "");
	argc = argparse_parse(&argparse, argc, argv);

	verbose = verbose_int;

	// load data [[[2
	int w, h, c;
	float * nisy1 = iio_read_image_float_vec(nisy1_path, &w, &h, &c);
	if (!nisy1)
		return fprintf(stderr, "Error while openning noisy frame\n"),
				 EXIT_FAILURE;

	// load optical flow
	float * bflow = NULL;
	if (bflow_path)
	{
		int w1, h1, c1;
		bflow = iio_read_image_float_vec(bflow_path, &w1, &h1, &c1);

		if (!bflow)
		{
			if (nisy1) free(nisy1);
			fprintf(stderr, "Error while openning bwd optical flow\n");
			return EXIT_FAILURE;
		}

		if (w*h != w1*h1 || c1 != 2)
		{
			fprintf(stderr, "Video and optical flow size missmatch\n");
			if (nisy1) free(nisy1);
			if (bflow) free(bflow);
			return EXIT_FAILURE;
		}
	}

	// load backward occlusion masks [[[3
	float * boccl = NULL;
	if (bflow_path && boccl_path)
	{
		int w1, h1, c1;
		boccl = iio_read_image_float_vec(boccl_path, &w1, &h1, &c1);

		if (!boccl)
		{
			if (nisy1) free(nisy1);
			if (bflow) free(bflow);
			fprintf(stderr, "Error while openning occlusion mask\n");
			return EXIT_FAILURE;
		}

		if (w*h != w1*h1 || c1 != 1)
		{
			fprintf(stderr, "Frame and occlusion mask size missmatch\n");
			if (nisy1) free(nisy1);
			if (bflow) free(bflow);
			if (boccl) free(boccl);
			return EXIT_FAILURE;
		}
	}

	// load filter output from previous frame
	float * deno0 = NULL;
	if (deno0_path)
	{
		int w1, h1, c1;
		deno0 = iio_read_image_float_vec(deno0_path, &w1, &h1, &c1);

		if (!deno0)
			fprintf(stderr, "Warning: previous denoised frame not found\n");

		if (deno0 && w*h*c != w1*h1*c1)
		{
			fprintf(stderr, "Previous denoised output size missmatch\n");
			if (nisy1) free(nisy1);
			if (bflow) free(bflow);
			if (boccl) free(boccl);
			if (deno0) free(deno0);
			return EXIT_FAILURE;
		}
	}

	// load guide for previous frame
	float * guid1 = NULL;
	if (guid1_path)
	{
		int w1, h1, c1;
		guid1 = iio_read_image_float_vec(guid1_path, &w1, &h1, &c1);

		if (!guid1)
			fprintf(stderr, "Warning: guide frame not found\n");

		if (guid1 && w*h*c != w1*h1*c1)
		{
			fprintf(stderr, "Previous denoised output size missmatch\n");
			if (nisy1) free(nisy1);
			if (bflow) free(bflow);
			if (boccl) free(boccl);
			if (deno0) free(deno0);
			if (guid1) free(guid1);
			return EXIT_FAILURE;
		}
	}


	// default value for noise-dependent params [[[2
	int step = guid1 ? 2 : 1;
	rbilf_default_params(&prms, sigma, step);

	// print parameters
	if (verbose)
	{
		printf("data i/o:\n");
		printf("\tnoisy frame:           %s\n", nisy1_path);
		printf("\tguide frame:           %s\n", guid1_path);
		printf("\toptical flow:          %s\n", bflow_path);
		printf("\tocclusions:            %s\n", boccl_path);
		printf("\tprev denoised frame:   %s\n", deno0_path);
		printf("\toutput denoised frame: %s\n", deno1_path);
		printf("parameters:\n");
		printf("\tnoise  %f\n", sigma);
		printf("\tsearch    %d\n", prms.search_sz);
		printf("\tw_hx0     %g\n", prms.weights_hx0);
		printf("\tw_hd0     %g\n", prms.weights_hd0);
		printf("\tw_hx      %g\n", prms.weights_hx);
		printf("\tw_hd      %g\n", prms.weights_hd);
		printf("\tw_thx     %g\n", prms.weights_thx);
		printf("\tw_ht      %g\n", prms.weights_ht);
		printf("\tlambda_x  %g\n", prms.lambda_x);
		printf("\tlambda_t  %g\n", prms.lambda_t);
		printf("\n");
	}


	// run denoiser [[[2
	const int whc = w*h*c, wh2 = w*h*2;
	float * warp0 = malloc(whc*sizeof(float));

	// warp previous denoised frame
	if (deno0 && bflow)
	{
		warp_bicubic(warp0, deno0, bflow, boccl, w, h, c);
		float *tmp = deno0; deno0 = warp0; warp0 = tmp; // swap warp0-deno0
	}

	// run denoising
	float * deno1 = malloc(whc*sizeof(float));
	rbilateral_filter_frame(deno1, nisy1, guid1, deno0, w, h, c, sigma, prms, 0);

	// save output [[[2
	iio_save_image_float_vec(deno1_path, deno1, w, h, c);

	if (deno1) free(deno1);
	if (guid1) free(guid1);
	if (deno0) free(deno0);
	if (warp0) free(warp0);
	if (nisy1) free(nisy1);
	if (bflow) free(bflow);
	if (boccl) free(boccl);

	return EXIT_SUCCESS; // ]]]2
}

// vim:set foldmethod=marker:
// vim:set foldmarker=[[[,]]]:
