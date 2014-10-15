%% main function, requires the configuration file as input
function main(file)

% the required jar files
javaaddpath(fullfile(pwd,'lib/commons-lang3-3.1.jar'));
javaaddpath(fullfile(pwd,'lib/object-store-api-0.1.jar'))
javaaddpath(fullfile(pwd,'lib/commons-logging-1.1.3.jar'));
javaaddpath(fullfile(pwd,'lib/httpclient-4.3.5.jar'))
javaaddpath(fullfile(pwd,'lib/haproxy-api.jar'))
javaaddpath(fullfile(pwd,'lib/json-simple-1.1.1.jar'))

%objectStoreConnector = it.polimi.modaclouds.monitoring.objectstoreapi.ObjectStoreConnector.getInstance;

startTime = 0;

while 1
    
    if java.lang.System.currentTimeMillis - startTime > 10000
        xDoc = xmlread(file);
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
    
    value = -1;
    
    for s = 1:frontendList.size
        D_combined(:,s) = D{1,s};
    end
    
    switch algorithm
        case 'LI'
            if iscolumn(N)
                N = N';
            end
            if iscolumn(Z)
                Z = Z';
            end
            [fbest, xopt] = bcmpoptim_poc_fmincon(D_combined, N, Z, revenue);
        case 'Heuristic'
            xopt = bcmpoptim_prog_heur1(D_combined, revenue);
    end
    
    xopt_int = round(xopt*100)
    
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
        
        for j = 1:serverIDList{1,s}.size
            content = httpAPI.sendGet(strcat(IP,'/v1/pools/',frontendList.get(s-1),'/targets/',serverIDList{1,s}.get(j-1)));
            
            if isempty(content)
                disp('Not correct end server.')
                break;
            end
            
            parser = javaObject('org.json.simple.parser.JSONParser');
            obj = parser.parse(content);
            
            obj.put('weight',num2str(xopt_int(s,j)));
            temp = obj.get('Address');
            if ~isempty(temp)
                obj.put('address',temp);
            end
            
            obj.toString
            
            response = httpAPI.sendPut(strcat(IP,'/v1/pools/',frontendList.get(s-1),'/targets/',serverIDList{1,s}.get(j-1)),obj.toString);
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
    pause(period);
    
end