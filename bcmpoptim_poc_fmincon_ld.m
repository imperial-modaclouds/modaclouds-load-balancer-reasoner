function [fopt, xopt, iter,Q,X] = bcmpoptim_poc_fmincon_ld(S, N, Z, f, F, revenue)
%% number of variables
[M,R,~]=size(S);
n = R*M;
V = zeros(M,R);
%% initial point
x0 = init_rand(M,R);

%temp(1,:) = x0;
for i = 1:10
    temp(i,:) = init_rand(M,R);
end

x0Set = CustomStartPointSet(temp);

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
%options.OutputFcn =  @outfun;

XLB = zeros(size(x0)); % lower bounds on x variables
XUB = ones(size(x0)); % upper bounds on x variables

T0 = tic; % needed for outfun
%% optimization program

ms=MultiStart('Display','iter','UseParallel','always');
problem=createOptimProblem('fmincon','objective',@objfun,'x0',x0,'lb',XLB,'ub',XUB,'nonlcon',@nnlcon,'options',options);

[x,~,~,output]=run(ms,problem,x0Set);

iter = output.funcCount
V = reshape(x,M,R);
L = S.*V;

[Q,X] = amvaqd([Z;L],N,f,F);
fopt = sum(-revenue*X')
xopt = reshape(x,M,R);

    function [c,ceq] = nnlcon(x)
        V = reshape(x,M,R);
        c = [];
        ceq = V'*ones(M,1)-1;
    end

    function r = objfun(x)
        V = reshape(x,M,R);
        L = S.*V;
        
        [~,X]=amvaqd([Z;L],N,f,F);
        
        r = -revenue*X';
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