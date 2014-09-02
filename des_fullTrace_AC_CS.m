function [meanST,obs,state_detail] = des_fullTrace_AC_CS(times, numExp, sampleSize, warmUp,W,V)

% times: arrival and response times in proper format as follows
% cell with as many entries as job classes
% cell k contains an m_k times 2 array, where
% m_k is the number of obsrevations for type k jobs
% the first column holds the arrival times stamps 
% the second column holds the response times
% both columns must be in the same time measure (e.g. s or ms)
% returns the mean service times meanST per class

% times is a long trace, and its analyzed in batches, first correcting for
% warmUp and then analizing numExp batches each of size sampleSize

% W: max number of jobs in service
% V: number of processors

K = length(times);


%compute departure times
for k = 1:K
    for i = 1:size(times{k},1)
        times{k}(i,3) = times{k}(i,1) + times{k}(i,2);
    end
end

%build array with all events
%first column: time
%second column: 0-arrival, 1-departure
%third column: class
%fourth column: arrival time (only for departures)
timesOrder = [];
for k = 1:K
    if size(times{k},2) > 2
    %arrivals
    timesOrder = [timesOrder; 
        [times{k}(:,1) zeros(size(times{k},1),1) k*ones(size(times{k},1),1) zeros(size(times{k},1),1) ]
        ];
    %departures
    timesOrder = [timesOrder; 
        [times{k}(:,3) ones(size(times{k},1),1) k*ones(size(times{k},1),1) times{k}(:,1)]
        ];
    end
end

%order events according to time of  
timesOrder = sortrows(timesOrder,1);

%t = timesOrder(warmUp+1,1); %clock
t = 0;
%STATE
 % each row corresponds to a current job
 % first column:  the class of the job
 % second column: the arrival time
 % third column: the elapsed service time
state = [];

%t = timesOrder(1,1); %clock
told = t;

%ACUM
% number of service completions observed for each class (row)
% and total service time per class (second column)
acum = zeros(K,2);
obs = cell(1,K); %holds all the service times observed

%advance until observe warmUp entities minimum of each class
i = 1;
%for i = 1:warmUp%sampleSize%size(timesOrder,1)
while min(acum(:,1)) < warmUp
    %acum(:,1)
    t = timesOrder(i,1);
    telapsed = t - told;
    n = size(state,1);

    % add to each job in process the service time elapsed (divided 
    % by the portion of the server actually dedicated to it in a PS server
    r = min(n,W);
    for j = 1:r
        state(j,3) = state(j,3) + telapsed/r;
    end

    %if the event is an arrival add the job to teh state
    if timesOrder(i,2) == 0
        state = [state; [timesOrder(i,3) t 0] ];
    else
        %find job in progress that must leave
        k = 1; while state(k,2) ~= timesOrder(i,4); k = k+1; end 
        %update stats
        acum(state(k,1),1) = acum(state(k,1),1) + 1;
        acum(state(k,1),2) = acum(state(k,1),2) + state(k,3);
        %obs{state(k,1)} = [obs{state(k,1)}; state(k,3)];
        
        %update state
        state = [state(1:k-1,:); state(k+1:end,:)];
    end
    i = i + 1;
    told = t;
end

state_detail = [];
meanST = zeros(K,numExp);

for e = 1:numExp
    %actually sampled data
    %for i = warmUp+1:warmUp+sampleSize%size(timesOrder,1)
    acum = zeros(K,2);
    seperate = cell(1,K);
    obs = cell(1,K); %holds all the service times observed
    %while min(acum(:,1)) < sampleSize%size(timesOrder,1)
    while sum(acum(:,1)) < sampleSize    
        t = timesOrder(i,1);
        telapsed = t - told;
        n = size(state,1);

        % add to each job in process the service time elapsed (divided 
        % by the portion of the server actually dedicated to it in a PS server
        r = min(n,W);
        for j = 1:r
            if length(state(j,:)) <5
                state(j,4) = 0;
                %state(j,5) = 0;
            end
            if r <= V %at most as many jobs in service as processors
                state(j,3) = state(j,3) + telapsed;
                state(j,4) = state(j,4) + telapsed*r;
            else %more jobs in service than processors
                state(j,3) = state(j,3) + telapsed*V/r;
                state(j,4) = state(j,4) + telapsed*V/r*r;
            end
            %state(j,4) = state(j,4) + telapsed;
            %state(j,5) = state(j,5) + telapsed*r;
        end

        %if the event is an arrival add the job to the state
        if timesOrder(i,2) == 0
            state = [state; [timesOrder(i,3) t 0 0 0] ];
        else
            %find job in progress that must leave
            k = 1; while state(k,2) ~= timesOrder(i,4); k = k+1; end 
            %update stats
            if acum(state(k,1),2) == 0
                acum(state(k,1),2) = eps;
            else
                acum(state(k,1),1) = acum(state(k,1),1) + 1;
                acum(state(k,1),2) = acum(state(k,1),2) + state(k,3);
                seperate{state(k,1)} = [seperate{state(k,1)}; state(k,3)];
                obs{state(k,1)} = [obs{state(k,1)}; state(k,3)];
            end
            %update state
            %temp = state(k,1:2);
            %temp(3) = state(k,4);
            %temp(4) = state(k,5)/state(k,4);
            temp = state(k,:);
            temp(4) = temp(4)/temp(3);
            if temp(3) ~= 0
                state_detail = [state_detail; temp];
            end
            state = [state(1:k-1,:); state(k+1:end,:)];
        end
        %acum(:,1)
        i = i+1;
        told = t;
    end
%     for i = 1:K
%         meanST(i,e) = mean(seperate{1,i}(11:end));
%     end
    meanST(:,e) = acum(:,2)./acum(:,1);
end


end