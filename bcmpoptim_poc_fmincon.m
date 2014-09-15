function [fopt, xopt, iter] = bcmpoptim_poc_fmincon(S, N, Z, revenue)
%% number of variables
[M,R]=size(S);
n = R*M;
V = zeros(M,R);
%% initial point
x0 = init_rand(M,R);

%% options
MaxCheckIter=1000;
options = optimset();
options.Display = 'iter';
options.LargeScale = 'off';
options.MaxIter =  1000;
options.MaxFunEvals = 1e10;
options.MaxSQPIter = 500;
options.TolCon = 1e-8;
options.Algorithm = 'interior-point';
options.OutputFcn =  @outfun;

XLB = zeros(size(x0)); % lower bounds on x variables
XUB = ones(size(x0)); % upper bounds on x variables

T0 = tic; % needed for outfun
%% optimization program
[x, f, ~, output]=fmincon(@objfun,x0,[],[],[],[],XLB,XUB,@nnlcon,options);
iter = output.iterations
V = reshape(x,M,R);
L = S.*V;
c = 1;
%[X] = aql(L,c*N,Z);
%fopt = -revenue*X'
fopt = f
xopt = reshape(x,M,R)

    function [c,ceq] = nnlcon(x)
        V = reshape(x,M,R);
        c = [];
        ceq = V'*ones(M,1)-1;
    end

    function f = objfun(x)
        V = reshape(x,M,R);
        L = S.*V;
        c = 1;
        [X] = amvabs(L,c*N,Z);
        f = -revenue*X';
    end

    function x0 = init_rand(M,R)
        for r=1:R
            V(:,r) = rand(M,1); V(:,r)=V(:,r)/sum(V(:,r));
        end
        x0 = reshape(V,1,n); % state variable is P matrix
    end

    function stop = outfun(x, optimValues, state)
        global MAXTIME;
        
        stop = false;
        if strcmpi(state,'iter')
            if mod(optimValues.iteration,MaxCheckIter)==0 && optimValues.iteration>1
                reply = input('Do you want more? Y/N [Y]: ', 's');
                if isempty(reply)
                    reply = 'Y';
                end
                if strcmpi(reply,'N')
                    stop=true;
                end
            end
            if toc(T0)>MAXTIME
                fprintf('Time limit reached. Aborting.\n');
                stop = true;
            end
        end
    end
end