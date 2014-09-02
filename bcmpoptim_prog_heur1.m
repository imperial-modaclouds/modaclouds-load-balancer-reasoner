function [xopt]=bcmpoptim_prog_heur1(S, revenue)

[M,R] = size(S);

mu = 1./S;
for i=1:M
    cmu(i) = max(revenue.*mu(i,:));
end
[~,I]=sort(cmu);
mu = mu(I,:);
%pause
for i=1:M
    rs(i) = maxpos(revenue.*mu(i,:));
end

m = 2; %paropt{1};
pm = zeros(M,R);
for i=m:M
    sump = 0;
    for j=m:M
        if rs(j) == rs(i)
            sump = sump + mu(j,rs(j));
        end
    end
    pm(i,rs(i)) = mu(i,rs(i)) / sump;
end

% assign classes not in rs
rsdiff = setdiff(1:R,unique(rs(m:end))); %classes not covered by rs
for r = rsdiff
    pm(1,r) = m-1;
end
xopt = pm(I,:);
