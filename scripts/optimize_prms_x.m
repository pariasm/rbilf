% optimize parameters of denoising algorithm using octave sqp

x0 = [80; 1.4]; % starting point
x0 = [77.63528; 0.92287; 10.07817; 2.59343; 0.0]; % optimum grayscale sigma 10
x0 = [83.06599; 0.91307; 27.19039; 3.49502; 0.0]; % optimum grayscale sigma 20

global computing_gradient = 0;

% objective function
function mse = rbilf_train(x)

	sigma = 40;
	args = sprintf('%.20f %.20f %.20f %.20f %.20f', x(1), x(2), x(3), x(4),x(5));
	cmd = sprintf('bin/rbilf-train-14.sh %f trials40 %s 2> stderr.log', sigma, args);
%	disp(cmd)
	[~, mse] = system(cmd);
	mse = str2num(mse);

	global computing_gradient;
	if computing_gradient == 0, disp([x', mse]); end

	return

endfunction

% gradient of objective function
function grad = rbilf_train_grad(x)

	% forward difference steps
	steps = [0.001; 0.001];
	steps = [0.001; 0.001; 0.001; 0.001; 0.01];

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
	disp([grad'])

endfunction

%rbilf_train_grad(x0)
%rbilf_train(x0)
%rbilf_train(x0 + [0;0;0;0;1e-2])
%rbilf_train(x0 + [0;0;0;0;1e-3])
%rbilf_train(x0 + [0;0;0;0;1e-4])
%rbilf_train(x0 + [0;0;0;0;1e-5])

[x, obj, info, iter, nf, lambda] = sqp(x0, ...
                                       {@rbilf_train, @rbilf_train_grad}, [], [], ...
                                       [    0,  0,     0,  0, 0], ...
                                       [255^2, 10, 255^2, 10, 1], 100, 1e-6)

