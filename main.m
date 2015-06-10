function main
% main function for the load balancer reasoner
%
% Parameters:
% file: location of the XML file to parse
%
% Copyright (c) 2012-2014, Imperial College London 
% All rights reserved.

% the required jar files
javaaddpath(fullfile(pwd,'lib/commons-lang3-3.1.jar'));
javaaddpath(fullfile(pwd,'lib/object-store-api-0.1.jar'))
javaaddpath(fullfile(pwd,'lib/commons-logging-1.1.3.jar'));
javaaddpath(fullfile(pwd,'lib/httpclient-4.3.5.jar'))
javaaddpath(fullfile(pwd,'lib/httpcore-4.3.2.jar'))
javaaddpath(fullfile(pwd,'lib/haproxy-api.jar'))
javaaddpath(fullfile(pwd,'lib/json-simple-1.1.1.jar'))

% copy libcurl first
% add in /etc/enviornment
%  MOSAIC_OBJECT_STORE_ENDPOINT_IP=194.102.62.209
%  MOSAIC_OBJECT_STORE_ENDPOINT_PORT=20622
%  MOSAIC_OBJECT_STORE_ENDPOINT_PATH=/v1/collections/c-1/objects/o-3/data

OS_IP = getenv('MOSAIC_OBJECT_STORE_ENDPOINT_IP');
OS_PORT = getenv('MOSAIC_OBJECT_STORE_ENDPOINT_PORT');
OS_PATH = getenv('MOSAIC_OBJECT_STORE_LB_REASONER_PATH');

command = strcat('curl -X GET http://',OS_IP,':',OS_PORT,OS_PATH,' | tee configuration_LB.xml')

status = system(command);
if status ~= 0
    disp('Error getting the configuration file.')
    exit
end

startTime = 0;

while 1
    
    % parse the XML file
    if java.lang.System.currentTimeMillis - startTime > 10000
        %xDoc = xmlread('configuration_LB.xml');
        xDoc = xmlread('configuration_LB.xml');
        rootNode = xDoc.getDocumentElement.getChildNodes;
        node = rootNode.getFirstChild;
        
        while ~isempty(node)
            if strcmp(node.getNodeName, 'path')
                path = char(node.getTextContent);
            end
            if strcmp(node.getNodeName, 'haproxyIPGold')
                haproxyIPGold = char(node.getTextContent);
            end
            if strcmp(node.getNodeName, 'haproxyIPSilver')
                haproxyIPSilver = char(node.getTextContent);
            end
            if strcmp(node.getNodeName, 'frontendNameGold')
                frontendNameGold = char(node.getTextContent);
            end
            if strcmp(node.getNodeName, 'frontendNameSilver')
                frontendNameSilver = char(node.getTextContent);
            end
            if strcmp(node.getNodeName, 'algorithm')
                algorithm = char(node.getTextContent);
            end
            if strcmp(node.getNodeName, 'period')
                period = str2double(node.getTextContent);
            end
            if strcmp(node.getNodeName, 'revenue')
                revenue = char(node.getTextContent);
            end
            node = node.getNextSibling;
        end
    end
    
    try
        load(path)
    catch err
        disp('No file found')
        pause(5)
        continue
    end
    
    revenue = str2double(strsplit(revenue,','));
    if ~strcmp(frontendList.get(0),frontendNameGold)
        revenue = revenue(end:-1:1);
    end
    
    value = -1;
    
    % check vm availability
    offline = [];
    for s = 1:frontendList.size
        
        if strcmp(frontendList.get(s-1),frontendNameGold)
            IP = haproxyIPGold;
        end
        if strcmp(frontendList.get(s-1),frontendNameSilver)
            IP = haproxyIPSilver;
        end
        
        classLoader = com.mathworks.jmi.ClassLoaderManager.getClassLoaderManager;
        httpAPI = javaObject('imperial.modaclouds.HttpAPI');
        
        success = 1;
        
        for j = 1:serverIDListAll.size
            content = httpAPI.sendGet(strcat(IP,'/v1/pools/',frontendList.get(s-1),'/targets/',serverIDListAll.get(j-1),'/check'));
            
            if isempty(content)
                disp('Not correct end server.')
                break;
            end
            
            parser = javaObject('org.json.simple.parser.JSONParser');
            obj = parser.parse(content);
            
            temp = obj.get('Status');
            if ~strcmp(temp,'Online')
                offline = [offline,j];
            end
        end
    end
    
    for s = 1:frontendList.size
        D_combined(:,s) = D{1,s};
    end
    D_combined(offline,:) = [];
    
    D_combined
    
    switch algorithm
        case 'LI'
            if iscolumn(N)
                N = N';
            end
            if iscolumn(Z)
                Z = Z';
            end
            [fbest, xopt] = bcmpoptim_poc_fmincon_li(D_combined, N, Z, revenue);
        case 'Heuristic'
            xopt = bcmpoptim_prog_heur1(D_combined, revenue);
        case 'LD'
            [fbest, xopt] = bcmpoptim_poc_fmincon_ld(D_combined, N, Z, f, F, revenue);
    end
    
    xopt_int = round(xopt*100)
    
    % update the weights in the Haproxy
    for s = 1:frontendList.size
        
        if strcmp(frontendList.get(s-1),frontendNameGold)
            IP = haproxyIPGold;
        end
        if strcmp(frontendList.get(s-1),frontendNameSilver)
            IP = haproxyIPSilver;
        end
        
        classLoader = com.mathworks.jmi.ClassLoaderManager.getClassLoaderManager;
        httpAPI = javaObject('imperial.modaclouds.HttpAPI');
        
        success = 1;
        
        count = 0;
        for j = 1:serverIDListAll.size
            if ismember(j,offline)
                count = count + 1;
                continue
            end
            content = httpAPI.sendGet(strcat(IP,'/v1/pools/',frontendList.get(s-1),'/targets/',serverIDListAll.get(j-1)));
            
            if isempty(content)
                disp('Not correct end server.')
                break;
            end
            
            parser = javaObject('org.json.simple.parser.JSONParser');
            obj = parser.parse(content);
            
            if abs(xopt_int(j-count,s)) < 10^-3
                obj.put('enabled',0);
            else
                obj.put('enabled',1);
            end
            %if abs(xopt_int(j,s) - 0) < 10^-3
            %    obj.put('enabled','false');
            %else
            %    obj.put('enabled','true');
            %end
            obj.put('weight',num2str(xopt_int(j-count,s)));
            temp = obj.get('Address');
            if ~isempty(temp)
                obj.put('address',temp);
            end
            
            obj.toString
            
            response = httpAPI.sendPut(strcat(IP,'/v1/pools/',frontendList.get(s-1),'/targets/',serverIDListAll.get(j-1)),obj.toString);
            if isempty(response)
                disp('Unreachable server');
                break;
            end
            if response.contains(java.lang.String(404))
                disp(response);
                break;
            end
            if ~strfind(char(response), num2str(200))
                success = 0;
            end
            disp(response)
        end
        
        if success == 0
            break;
        end
        
        response = httpAPI.sendPost(strcat(IP,'/v1/controller/commit'), '');
        response
        if isempty(response)
            disp('Unreachable server');
            break;
        end
        if response.contains(java.lang.String(404))
            disp(response);
            break;
        end
    end
    
    % if file does not exist, then wait for 5 seconds to check again. 
    pause(period);
end