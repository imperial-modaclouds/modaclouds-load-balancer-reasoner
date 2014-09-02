%clc
%clear;
function [D,Ddetail] = call_des_fullTrace_AC_clean(W,V,data,window)
%W = 1; % max number of jobs in service
%V = 1;
%mu = [2; 4]; %actual service rates

numExp = 1;
%sampleSize = size(data{3,1},1);
sampleSize = 0;
for i = 1:size(data,2)-1
    sampleSize = sampleSize + size(data{3,i},1) - 1;
end

warmUp = 0;

% input_filename = 'simulation/dataFullTrace1_mu24_N22_CS';
% 
% 
% delimiterIn = ',';
% headerlinesIn = 1;
% %load(strcat('simulation/',input_filename));
% load(input_filename);
%load('ec2-eu-west-1a-baseline25-20130219.mat');
%load('ec2-eu-west-1a-single-20130214')
%data = ofbench_convert_defdemest(campaign{1,1}.cdata{1,1});
%data = b;

K = size(data,2) - 1;
sampleNumber = zeros(1,K);

for k = 1:K
    times{k} = [data{3,k}/1000 data{4,k}];
    sampleNumber(k) = size(data{3,k},1);
end

% if min(sampleNumber) < warmUp + numExp*sampleSize
%     fprintf('Too few samples available');
%     break
% end

Ddetail = cell(1,K);
window = window/1000;
[meanST,obs,state_detail] = des_fullTrace_AC_CS(times, numExp, sampleSize, warmUp,W,V);

for i = 1:size(state_detail,1)
    Ddetail{1,state_detail(i,1)} = [Ddetail{1,state_detail(i,1)};state_detail(i,2:4)];
end

% t0 = state_detail(1,2);
% N = floor(state_detail(end,2)-t0)/window;
% for i = 1:N
%     index_data = state_detail(:,2) > t0+(i-1)*window & state_detail(:,2) < t0+i*window;
%     for r = 1:K
%         index_class = state_detail(index_data,1) == r;
%         time = mean(state_detail(index_class,3));
%         Q = sum(state_detail(index_class,4).*state_detail(index_class,3))/window;
%         
%         if Q ~= 0
%             Ddetail{1,r} = [Ddetail{1,r};[time,Q]];
%         end
%     end
% end


D = mean(meanST,2);


%error = abs(meanST - (1./mu)*ones(1,numExp))./(1./mu*ones(1,numExp))*100;


%output = [error' meanST'];

end