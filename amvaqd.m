function [Q,X]=amvaqd(L,N,ga,be,Q0)
[M,R]=size(L);

if nargin < 5
    Q = rand(M,R);
    Q = Q ./ repmat(sum(Q,1),size(Q,1),1) .* repmat(N,size(Q,1),1);
else
    Q=Q0;
end
delta  = (sum(N) - 1) / sum(N);
deltar = (N - 1) ./ N;

Q_1 = Q*10;
tol = 1e-6;
while max(max(abs(Q-Q_1))) > tol
    Q_1 = Q;
    for k=1:M
        for r=1:R
            Ak{r}(k) = 1 + delta * sum(Q(k,:));
            Akr(k,r) = 1 + deltar(r) * Q(k,r);
        end
    end
    
    %    Q
    for r=1:R
        g = ga(Ak{r});
        b = be(Akr);
        for k=1:M
            C(k,r) = L(k,r) * g(k) * b(k,r) * (1 + delta * sum(Q(k,:)));
        end
        
        X(r) = N(r) / sum(C(:,r));
        
        for k=1:M
            Q(k,r) = X(r) * C(k,r);
        end
    end
end

end
