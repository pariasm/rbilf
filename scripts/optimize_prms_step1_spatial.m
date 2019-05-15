% optimize parameters of denoising algorithm using octave sqp

% initial condition
global hx1=100;
global hd1=1.7;
x0 = [hx1, hd1]';

global sigma = 10;
global out_folder = sprintf('train%d-rgb-step1',sigma);
global table_file = 'bfgs-hx0-hd0-seed3';

% cache to avoid duplicate computations
global cache_grad = zeros(size(x0));
global cache_grad_at = zeros(size(x0));
global cache_fun = 0;
global cache_fun_at = zeros(size(x0));

%% objective function
function mse = rbilf_train(x, mode)

	if nargin == 1, mode='fun'; end
	global out_folder;

	% check cached function
	global cache_fun_at;
	global cache_fun;

	if norm(x - cache_fun_at) < 1e-6,
		mse = cache_fun;
		saved = 'saved';
	else
		global sigma;
		args = sprintf('%.20f %.20f', x(1), x(2));
		cmd = sprintf('bin/rbilf-train-14-spatial.sh %f %s %s 2> stderr.log', sigma, out_folder, args);
		[~, mse] = system(cmd);
		mse = str2num(mse);
		saved = 'compu';
	end

	if mode == 'fun',
		%            hx1   hd1   mse]';
		s = sprintf('%7.3f %5.3f %9.5f',...
		             x(1),  x(2), mse);
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
%   [hx1   , hd1]';
b = [0     ,   0]';
B = [255.^2,   5]';

addpath('../lib/optim/');
[x, histout, costdata] = projbfgs(x0, @rbilf_train, @rbilf_train_grad, B, b, 1e-6, 100)
