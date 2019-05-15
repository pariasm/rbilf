% optimize parameters of denoising algorithm using octave sqp

% initial condition
global hx1=26;
global hd1=1.8;
global lx1=0.05;
global ht1=23;
global lt1=0.01;
global of1=10;
global of2=2;
x0 = [hx1, hd1, lx1, ht1, lt1, of1, of2]';

global sigma = 40;
global out_folder = sprintf('train%d-rgb-step1-rof',sigma);
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
		args = sprintf('%.20f %.20f %.20f %.20f %.20f %.20f %.20f', x(1), x(2), x(3), x(4), x(5), x(6), x(7));
		cmd = sprintf('bin/rbilf-train-14.sh %f %s %s 2> stderr.log', sigma, out_folder, args);
		[~, mse] = system(cmd);
		mse = str2num(mse);
		saved = 'compu';
	end

	if mode == 'fun',
		%            hx1   hd1   lx1   ht1   lt1   ofw   mse]';
		s = sprintf('%7.3f %5.3f %5.3f %7.3f %5.3f %6.3f %6.3f  %9.5f',...
		             x(1),  x(2), x(3), x(4), x(5), x(6),  x(7), mse);
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
b = [0     ,   0,   0,      0,   0,   0   0]';
B = [255.^2,   5,   1, 255.^2,   1,   100  100]';

addpath('../lib/optim/');
[x, histout, costdata] = projbfgs(x0, @rbilf_train, @rbilf_train_grad, B, b, 1e-6, 100)
