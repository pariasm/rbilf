% optimize parameters of denoising algorithm using octave sqp

% start from another initial condition
global hx1=22.3;
global hd1=1.6;
global lx1=0.05;
global ht1=17;
global lt1=0.01;
global ofw=0.2;
x0 = [hx1, hd1, lx1, ht1, lt1, ofw]';

global sigma = 30;
global out_folder = sprintf('train%d-rgb-step1', sigma);
global table_file = 'table';

% cache to avoid duplicate computations
global cache_grad = zeros(size(x0));
global cache_grad_at = zeros(size(x0));
global cache_fun = 0;
global cache_fun_at = zeros(size(x0));

% objective function
function mse = rbilf_train(x, mode)

%	if nargin == 1, verbose=0; end
	if nargin == 1, mode='fun'; end

	global cache_fun_at;
	global cache_fun;
	global out_folder;

	if norm(x - cache_fun_at) < 1e-6,
		mse = cache_fun;
		saved = 'saved';
	else
		global sigma;
		args = sprintf('%.20f %.20f %.20f %.20f %.20f %.20f', x(1), x(2), x(3), x(4),x(5), x(6));
		cmd = sprintf('bin/rbilf-train-14.sh %f %s %s 2> stderr.log', sigma, out_folder, args);
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

% gradient of objective function
function grad = rbilf_train_grad(x)

	global cache_grad;
	global cache_grad_at;
	if norm(x - cache_grad_at) < 1e-6,
		grad = cache_grad;
%		fid = fopen('train20/table', 'a'); fprintf(fid, 'grad already computed \n'); fclose(fid);
		return
	end

	% forward difference steps
	steps = [0.001; 0.001];
	steps = 0.001 * ones(size(x));

	mse_x = rbilf_train(x,'grd');

	grad = zeros(size(x));
	steps = diag(steps);
	for i = 1:length(x);
		mse_xi = rbilf_train(x + steps(:,i),'grd');
		grad(i) = (mse_xi - mse_x)/steps(i,i);
%		disp([x' + steps(:,i)' , mse_xi])
%		grad(i) = (rbilf_train(x + steps(:,i)) - rbilf_train(x - steps(:,i)))/2/steps(i,i);
	end

	cache_grad = grad;
	cache_grad_at = x;

%	grad(5) = min(10,max(-10,grad(5)));
%	disp([grad'])

endfunction

%rbilf_train(x0)';
%rbilf_train_grad(x0)'

% % bounds
% %   [hx1   , hd1, lx1,    ht1, lt1  ofw]';
% b = [0     ,   0,   0,      0,   0,   0.01]';
% B = [255.^2,   5,   1, 255.^2,   1,   5]';
% 
% %[x, obj, info, iter, nf, lambda] = sqp(x0, {@rbilf_train, @rbilf_train_grad},...
% %                                       [], [], b, B, 100, 1e-6)
% 
% 
% 
% 
% addpath('../lib/optim/');
% [x, histout, costdata] = projbfgs(x0, @rbilf_train, @rbilf_train_grad, B, b, 1e-6, 100)


%% optimum found in bouncatrin
%hx1=25.324; hd1=1.597; lx1=0.142; ht1=19.287; lt1=0.000;
%ofw=0.273;
%hx1=24.285; hd1=1.386; lx1=0.100; ht1=20.000; lt1=0.000;
%ofw=0.219;
%hx1=23.953; hd1=0.923; lx1=0.050; ht1=20.000; lt1=0.000;
%ofw=0.242;
%hx1=26.5; hd1=1.6; lx1=0.050; ht1=27.000; lt1=0.000;
%ofw=0.210;
hx1=22.3; hd1=1.6; lx1=0.050; ht1=17.000; lt1=0.010;
ofw=0.200;
x0 = [hx1, hd1, lx1, ht1, lt1, ofw]';

%rbilf_train(x0)';
%rbilf_train_grad(x0)'

% line searches
table_file = 'ls_lx1'; vs = [0.0:.02:0.2];  x = x0; for v = vs, x(3) = v; rbilf_train(x); end
table_file = 'ls_lt1'; vs = [0:.01:0.1];    x = x0; for v = vs, x(5) = v; rbilf_train(x); end
table_file = 'ls_ofw'; vs = [0.05:.05:0.4]; x = x0; for v = vs, x(6) = v; rbilf_train(x); end
table_file = 'ls_hx1'; vs = [20:.2:24];     x = x0; for v = vs, x(1) = v; rbilf_train(x); end
table_file = 'ls_hd1'; vs = [0.6:.2:2.6];   x = x0; for v = vs, x(2) = v; rbilf_train(x); end
table_file = 'ls_ht1'; vs = [ 7:.5:27];     x = x0; for v = vs, x(4) = v; rbilf_train(x); end
