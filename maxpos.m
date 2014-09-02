function pos=maxpos(s,n)
if nargin<2, n=1; end

if n==1
    [~,pos] = max(s);
else
    [~,pos] = sort(s,'descend');
    pos = pos(1:n);
end
    

end