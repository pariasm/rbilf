% optimize parameters of denoising algorithm using octave sqp

% initial condition
%global hx1=40.263;% 18   ; 22.0  ; 26.5 ;
%global hd1=1.889; % 1.2  ; 1.6   ; 1.6  ;
%global lx1=0.046; % 0.05 ; 0.05  ; 0.05 ;
%global ht1=40.336;% 17   ; 17.5  ; 25   ;
%global lt1=0.002; % 0.03 ; 0.02  ; 0.01 ;
%global ofw=0.204; % 0.25 ; 0.225 ; 0.2  ;
global hx1=18   ;
global hd1=1.2  ;
global lx1=0.05 ;
global ht1=17   ;
global lt1=0.03 ;
global ofw=0.27 ;

x0 = [hx1, hd1, lx1, ht1, lt1, ofw]';
global of_scale = 1;

global sigma = 20;
global out_folder = sprintf('train%d-step1-tvl1',sigma);
global table_file = 'bfgs-all';

% cache to avoid duplicate computations
global cache_grad = zeros(size(x0));
global cache_grad_at = zeros(size(x0));
global cache_fun = 0;
global cache_fun_at = zeros(size(x0));

%% objective function
function mse = rbilf_train(x, mode)

	if nargin == 1, mode='fun'; end
	global out_folder;

	% load fixed parameters
% 	global hx1; x(1) = hx1;
% 	global hd1; x(2) = hd1;
%	global lx1; x(3) = lx1;
% 	global ht1; x(4) = ht1;
%	global lt1; x(5) = lt1;
%	global ofw; x(6) = ofw;

	% check cached function
	global cache_fun_at;
	global cache_fun;

	if norm(x - cache_fun_at) < 1e-6,
		mse = cache_fun;
		saved = 'saved';
	else
		global sigma;
		% rbilf options string
		rbprms = sprintf('"--whx %.20f --whd %.20f --lambdax %.20f', x(1), x(2), x(3));
		rbprms = sprintf('%s --wht %.20f --lambdat %.20f -v 0"', rbprms, x(4), x(5));

		% tvl1 options
		global of_scale;
		ofprms = sprintf('"tvl1flow %d %.20f"', of_scale, x(6));

		cmd = sprintf('bin/rbilf-train-14.sh %f %s %s %s 2> stderr.log', sigma, out_folder, rbprms, ofprms);
		[~, mse] = system(cmd);
		mse = str2num(mse);
		saved = 'compu';
	end

	if mode == 'fun',
		%            hx1   hd1   lx1   ht1   lt1   ofw   mse]';
		s = sprintf('%7.3f %5.3f %5.3f %7.3f %5.3f %6.3f %9.5f',...
		             x(1),  x(2), x(3), x(4), x(5), x(6), mse);
		disp(s);

		global table_file;
		fid = fopen(sprintf('%s/%s',out_folder,table_file), 'a');
		fprintf(fid, [s '\n']); fclose(fid);
	end

	cache_fun = mse;
	cache_fun_at = x;

	return

endfunction

%% gradient of objective function
function grad = rbilf_train_grad(x)

	% check cached gradient
	global cache_grad;
	global cache_grad_at;
	if norm(x - cache_grad_at) < 1e-6, grad = cache_grad; return; end

	% forward difference steps
	steps = 0.001 * ones(size(x));

	mse_x = rbilf_train(x,'grd');
	grad = zeros(size(x));
	steps = diag(steps);
	for i = 1:length(x);
		mse_xi = rbilf_train(x + steps(:,i),'grd');
		grad(i) = (mse_xi - mse_x)/steps(i,i);
	end

	% update cache
	cache_grad = grad;
	cache_grad_at = x;

endfunction

%% minimize -----------------------------------------------------------------------------

%rbilf_train(x0)';
%rbilf_train_grad(x0)'

% bounds
%   [hx1   , hd1, lx1,    ht1, lt1,    ofw]';
if 1,
	b = [0     ,   0,   0,      0,   0,   0.01]';
	B = [255.^2,   5,   1, 255.^2,   1,   5   ]';

	addpath('../lib/optim/');
	[x, histout, costdata] = projbfgs(x0, @rbilf_train, @rbilf_train_grad, B, b, 1e-6, 100)
else
	% initial condition
	% rof-scale 0 % rof-scale 1
	hx1=30.284;
	hd1=1.082; 
	lx1=0.103;
	ht1=20.469;
	lt1=0.000;
	ofw=0.248;
	
	% line searches
	x0 = [hx1, hd1, lx1, ht1, lt1, ofw]';
	table_file = 'ls_hx1'; vs = unique(max(0, hx1 +   4*[-1:.2:1])); x = x0; for v = vs, x(1) = v; rbilf_train(x); end
	table_file = 'ls_hd1'; vs = unique(max(0, hd1 + 1.2*[-1:.2:1])); x = x0; for v = vs, x(2) = v; rbilf_train(x); end
	table_file = 'ls_lx1'; vs = unique(max(0, lx1 + .05*[-1:.2:1])); x = x0; for v = vs, x(3) = v; rbilf_train(x); end
	table_file = 'ls_ht1'; vs = unique(max(0, ht1 +   4*[-1:.2:1])); x = x0; for v = vs, x(4) = v; rbilf_train(x); end
	table_file = 'ls_lt1'; vs = unique(max(0, lt1 + .05*[-1:.2:1])); x = x0; for v = vs, x(5) = v; rbilf_train(x); end
	table_file = 'ls_ofw'; vs = unique(max(0, ofw +   4*[-1:.2:1])); x = x0; for v = vs, x(6) = v; rbilf_train(x); end
end
