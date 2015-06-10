%function [ data ] = parseFile( input_args )
clear


path = 'haproxy.log';

import java.io.File;
import java.io.RandomAccessFile;
import java.util.ArrayList;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Collections;

file = RandomAccessFile( path, 'r' );
filePointer = 0;
expression=['(\w+ \d+ \S+) (\S+) (\S+)\[(\d+)\]: (\S+):(\d+) \[(\S+)\] ' ...
    '(\S+) (\S+)/(\S+) (\S+) (\S+) (\S+) *(\S+) (\S+) (\S+) (\S+) (\S+) '...
    '"(\S+) ([^"]+) (\S+)" *$'];
categoryList = ArrayList;
sessionIDList = ArrayList;
sessionTimes = zeros(2,1);
thinkTimes = zeros(1,2);
sessionsList = ArrayList;
data = cell(1,4);
data_session = cell(7,1);


nbCores = [1,1,1,2];

try
    if file.length < filePointer
        file = RandomAccessFile( path, 'r' );
    else
        file.seek( filePointer );
        line = file.readLine;
        while ~isempty(line)
            line = file.readLine;
            output = regexp(char(line),expression,'tokens');
            
            if isempty(output)
                continue
            end
            
            if ~isempty(strfind(output{1,1}{1,14},'JSESSIONID'))
                server = output{1,1}{1,10};
                switch server
                    case 's1'
                        serverID = 1;
                    case 's2'
                        serverID = 2;
                    case 's3'
                        serverID = 3;
                    case 's4'
                        serverID = 4;
                end
                
                str_cookie = java.lang.String(output{1,1}{1,14});
                str = java.lang.String(output{1,1}{1,20});
                
                if str.contains(java.lang.String('.css'))
                    continue;
                end
                
                if str.contains(java.lang.String(';jsessionid'))
                    categoryName = str.substring(0,str.indexOf(';jsessionid'));
                else
                    categoryName = str;
                end
                
                if categoryName.equals(java.lang.String('/ecommerce/'))
                    continue
                end
                
                sessionID = char(str_cookie.substring(str_cookie.indexOf('JSESSIONID=')+11));
                
                if ~categoryList.contains(categoryName)
                    categoryList.add(categoryName);
                end
                
                categoryIndex = categoryList.indexOf(categoryName) + 1;
                
                df = SimpleDateFormat('dd/MMM/yyyy:HH:mm:ss.S');
                date = df.parse(output{1,1}{1,7});
                arrival = date.getTime;
                
                str = java.lang.String(output{1,1}{1,11});
                response = str2double(str.substring(str.lastIndexOf('/')+1))/1000;
                
                if size(data{1,serverID},2) < categoryIndex
                    data{1,serverID}{6,categoryIndex} = [];
                end
                
                data{1,serverID}{3,categoryIndex} = [data{1,serverID}{3,categoryIndex};arrival];
                data{1,serverID}{4,categoryIndex} = [data{1,serverID}{4,categoryIndex};response];
                
                if sessionIDList.contains(sessionID)
                    index = sessionIDList.indexOf(sessionID);
                    sessionsList.get(index).add(categoryIndex-1);
                    sessionTimes(index+1,2) = arrival + response*1000;
                    thinkTimes(index+1,2) = thinkTimes(index+1,2) + arrival - thinkTimes(index+1,1);
                    thinkTimes(index+1,1) = arrival + response*1000;
                else
                    sessionIDList.add(sessionID);
                    temp = ArrayList;
                    temp.add(categoryIndex-1);
                    sessionsList.add(temp);
                    index = sessionIDList.indexOf(sessionID);
                    sessionTimes(index+1,1) = arrival;
                    thinkTimes(index+1,1) = arrival+response*1000;
                end
            end
        end
        
        for i = 1:size(data,2)
            if ~isempty(data{1,i})
                data{1,i}{2,size(data{1,i},2)+1} = [];
                [D_request{1,i},D_detail{1,i}] = call_des_fullTrace_AC_clean(100,nbCores(i),data{1,i},100000);
                for j = 1:categoryList.size
                    if j > length(D_request{1,i}) || isnan(D_request{1,i}(j))
                        D_request{1,i}(j) = 0.1;
                    end
                end
            end
        end
        
        uniSessions = ArrayList;
        uniSessions.add(sessionsList.get(0));
        for i = 0:sessionsList.size - 1
            flag = 0;
            for j = 0:uniSessions.size - 1
                if sessionsList.get(i).equals(uniSessions.get(j))
                    
                    if size(data_session,2) < j+1
                        data_session{7,j+1} = [];
                    end
                    data_session{3,j+1} = [data_session{3,j+1};sessionTimes(i+1,1)];
                    data_session{4,j+1} = [data_session{4,j+1};(sessionTimes(i+1,2)-sessionTimes(i+1,1))/1000];
                    data_session{7,j+1} = [data_session{7,j+1};thinkTimes(i+1,2)];
                    flag = 1;
                    break;
                end
            end
            if flag == 0
                uniSessions.add(sessionsList.get(i));
                data_session{6,j+2} = [];
                data_session{3,j+2} = [data_session{3,j+2};sessionTimes(i+1,1)];
                data_session{4,j+2} = [data_session{4,j+2};(sessionTimes(i+1,2)-sessionTimes(i+1,1))/1000];
                data_session{7,j+2} = [data_session{7,j+2};thinkTimes(i+1,2)];
            end
        end
        
        count = 0;
        delete = [];
        for i = 1:size(data_session,2)
            if length(data_session{3,i}) < 11
                delete = [delete,i];
                uniSessions.remove(i-count-1);
                count = count + 1;
            end
        end
        data_session(:,delete) = [];
        
        
        data_session{2,size(data_session,2)+1} = zeros(10,1);
        data_session = dataFormat(data_session,60000);
        
        for i = 1:uniSessions.size
            temp = [];
            temp{3,1} = data_session{3,i};
            temp{4,1} = data_session{4,i};
            temp{2,2} = zeros(10,1);
            [~,D_session_detail] = call_des_fullTrace_AC_clean(100,1,temp,100000);
            N(i) = max(D_session_detail{1,1}(:,3));
            R(i) = mean(data_session{5,i});
            X(i) = mean(data_session{6,i});
            Z_request(i) = mean(data_session{7,i})/1000;
            uniAraay{1,i} = arrayfun(@(e)e, uniSessions.get(i-1).toArray())+1;
        end
        
        Z_session = N./X-R;
        Z = Z_session + Z_request;
        
        for i = 1:size(data,2)
            for j = 1:uniSessions.size
                D(i,j) = sum(D_request{1,i}(uniAraay{1,j}));
            end
        end
        
        filePointer = file.getFilePointer;
    end
    file.close;
catch err
    file.close;
    rethrow(err)
end



%end