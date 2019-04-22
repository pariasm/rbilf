% optimize parameters of denoising algorithm using octave sqp

hx1=24; hd1=1.6; lx1=0.1; ht1=14; lt1=0.5;
hx2=24; hd2=1.6; lx2=0.1; ht2=14; lt2=0.5;
ofw=0.4;
x0 = [hx1, hd1, lx1, ht1, lt1, hx2, hd2, lx2, ht2, lt2, ofw]';

global computing_gradient = 0;

% objective function
function mse = rbilf_train(x)

	sigma = 20;
	args = sprintf(   '%.20f %.20f %.20f %.20f %.20f',       x(1), x(2), x(3), x(4),x( 5));
	args = sprintf('%s %.20f %.20f %.20f %.20f %.20f', args, x(6), x(7), x(8), x(9),x(10));
	args = sprintf('%s %.20f', args, x(11));
	cmd = sprintf('bin/rbilf-train-14.sh %f train20 %s 2> stderr.log', sigma, args);
%	disp(cmd)
	[~, mse] = system(cmd);
	mse = str2num(mse);

	global computing_gradient;
	if computing_gradient == 0,
      %               hx1   hd1   lx1   ht1   lt1   hx2   hd2   lx2   ht2   lt2 ofw]';
		disp(sprintf('%7.3f %5.3f %5.3f %7.3f %5.3f %7.3f %5.3f %5.3f %7.3f %5.3f  %6.3f  %9.5f',...
		             x(1),  x(2), x(3), x(4), x(5), x(6), x(7), x(8), x(9), x(10), x(11), mse));
	end

	return

endfunction

% gradient of objective function
function grad = rbilf_train_grad(x)

	% forward difference steps
	steps = [0.001; 0.001];
	steps = 0.001 * ones(size(x));

	global computing_gradient;
	computing_gradient = 1;
	mse_x = rbilf_train(x);

	grad = zeros(size(x));
	steps = diag(steps);
	for i = 1:length(x);
		mse_xi = rbilf_train(x + steps(:,i));
		grad(i) = (mse_xi - mse_x)/steps(i,i);
%		disp([x' + steps(:,i)' , mse_xi])
%		grad(i) = (rbilf_train(x + steps(:,i)) - rbilf_train(x - steps(:,i)))/2/steps(i,i);
	end
	computing_gradient = 0;

%	grad(5) = min(10,max(-10,grad(5)));
%	disp([grad'])

endfunction

%rbilf_train(x0)';
%rbilf_train_grad(x0)'



% bounds
%   [hx1   , hd1, lx1,    ht1, lt1,    hx2, hd2, lx2,    ht2, lt2  ofw]';
b = [0     ,   0,   0,      0,   0,      0,   0,   0,      0,   0,   0]';
B = [255.^2,   5,   1, 255.^2,   1, 255.^2,   5,   1, 255.^2,   1,   5]';

[x, obj, info, iter, nf, lambda] = sqp(x0, {@rbilf_train, @rbilf_train_grad},...
                                       [], [], b, B, 100, 1e-6)

