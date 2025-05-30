% MATLAB 代码框架：WCST 行为数据分析

% 1. 设置文件夹路径
folderPath = 'C:\Users\Desktop';
outputFile = 'C:\Users\Desktop\WCST_results.txt'; % 结果文件

% 2. 获取所有 CSV 文件
csvFiles = dir(fullfile(folderPath, '*.csv'));
numFiles = length(csvFiles);

% 3. 初始化结果存储
headers = {'Participant', 'PhoneNumber', 'IDCard', 'Date', 'ExpName', 'PsychoPyVersion', 'FrameRate', 'trialNum', 'TC', 'TE', 'PR', 'PE', 'NPE', 'CLR', 'CC', 'T1C', 'FMS', 'LL', 'GS',  12223331144};
result = cell(1,length(headers));
results = cell(numFiles + 1, length(headers)); % 预分配空间

% 4. 遍历所有文件
for i = 1:numFiles
    
    % 读取 CSV 文件
    filePath = fullfile(folderPath, csvFiles(i).name);
    data = readtable(filePath);
    
    % 解析必要的变量
    if iscell(data.participant)
        participantID = sprintf('%s', data.participant{1});
    else
        participantID = sprintf('%s', data.participant(1));
    end

    if iscell(data.IDCard)
        idCard = data.IDCard{1};
    else
        idCard = data.IDCard(1);
    end
    phoneNumber = sprintf('%d', data.PhoneNumber(1));
    date = data.date{1};
    expName = data.expName{1};
    psychoPyVersion = data.psychopyVersion{1};
    frameRate = data.frameRate(1);
    
    % 解析额外的被试行为数据
    instructionStarted = data.instruction_started(1);
    keyRespStarted = data.key_resp_started(1);
    keyRespRT = data.key_resp_rt(1);
    
    % 删除数据的第一行和最后一行，一般是PsychoPy的开始routine和结束routine
    data(1, :) = [];
    data(end, :) = [];
    
    % 记录试次数量
    trialNum = height(data);

    % 遍历每个 trial，提取每个 trial 的图像及其维度
    colors = cell(trialNum, 4); % 每个 trial 四个图像的颜色
    shapes = cell(trialNum, 4); % 每个 trial 四个图像的形状
    numbers = zeros(trialNum, 4); % 每个 trial 四个图像的数字
    
    for trialIdx = 1:trialNum
        matchedImages = {data.matched_image1{trialIdx}, data.matched_image2{trialIdx}, data.matched_image3{trialIdx}, data.matched_image4{trialIdx}};
        
        for j = 1:4
            if ~isempty(matchedImages{j})
                parts = split(matchedImages{j}, '_');
                numbers(trialIdx, j) = str2double(parts{1});
                colors{trialIdx, j} = parts{2};
                shapes{trialIdx, j} = erase(parts{3}, '.png');
            end
        end
    end
    
    % 5. 计算各项指标
    TC = sum(data.key_resp_react_corr); % Total Number Correct, 通过加总所有试次的正确响应
    TE = trialNum - TC; % Total Number of Errors, 通过试次数量减去正确响应

    % 初始化变量
    PR = 0; % 初始化Perseverative Responses
    PE = 0; % 初始化Perseverative Errors
    CC = 0; % Number of Categories Completed
    T1C = NaN; % Trials to Complete First Category
    consecutiveCorrect = 0; % 连续正确次数
    firstCategoryCompleted = false; % 是否已经完成第一个分类
    perseveratedToPrinciple = ''; % 当前的perseverated-to principle
    NPE = 0; % Non-perseverative Errors
    CLR = 0; % Conceptual Level Responses
    FMS = 0; % Failure to Maintain Set
    LL = 0; % Learning to Learn
    GS = 0; % Global Score (Laiacona et al., 2000)
    errorRates = []; % 存储每个分类阶段的错误率
    categoryCompletionIndices = []; % 存储每个分类完成时的索引


    % 遍历每个 trial 计算 PR 和 PE
    for trialIdx = 1:trialNum
        correct = data.key_resp_react_corr(trialIdx); % 当前 trial 是否正确
        selectedCardIndex = data.key_resp_react_keys(trialIdx); % 被试选择的卡片索引（1-4）

        % 获取被试选择的卡片的维度信息
        selectedShape = shapes{trialIdx, selectedCardIndex};
        selectedColor = colors{trialIdx, selectedCardIndex};
        selectedNumber = numbers(trialIdx, selectedCardIndex);

        % 获取响应卡片的维度信息
        responseShape = data.response_shape{trialIdx}; % 当前响应的形状
        responseColor = data.response_color{trialIdx}; % 当前响应的颜色
        responseNumber = data.response_number(trialIdx); % 当前响应的数字

        % 检查响应卡片和被试选择的卡片在三个维度上的匹配情况
        isShapeMatch = strcmp(responseShape, selectedShape);
        isColorMatch = strcmp(responseColor, selectedColor);
        isNumberMatch = responseNumber == selectedNumber;

        % 确定响应维度
        responseDimension = '';
        if isShapeMatch
            responseDimension = 'shape';
        elseif isColorMatch
            responseDimension = 'color';
        elseif isNumberMatch
            responseDimension = 'number';
        else
            responseDimension = 'other'; % 其他情况，卡片设置不存在ambiguous的情况，即有三张卡片分别共享颜色、数字、形状，第四张不共享任何，属于others
        end
          
        if ~correct % 如果答错
            if isempty(perseveratedToPrinciple)
                    perseveratedToPrinciple = responseDimension; % 更新 perseverated-to principle
                else
                    if strcmp(responseDimension, perseveratedToPrinciple)
                        PR = PR + 1; % 增加 PR 计数
                        PE = PE + 1; % 增加 PE 计数
                    end
            end
                    
            if consecutiveCorrect == 4 % 参考(Laiacona et al., 2000)，本研究中设置标准为4
                FMS = FMS + 1; % 增加 FMS 计数
            end
            
            consecutiveCorrect = 0; % 重置连续正确次数

        else % 如果正确
            consecutiveCorrect = consecutiveCorrect + 1;
            perseveratedToPrinciple = ''; % 重置 perseverated-to principle

            if consecutiveCorrect == 3
                CLR = CLR + 3;
            end

            if consecutiveCorrect == 4
                CLR = CLR + 1;
            end
            
            if consecutiveCorrect == 5 % 检查是否完成当前分类
                CC = CC + 1; % 增加完成的分类数量

                categoryCompletionIndices(end+1) = trialIdx; % 记录完成分类时的索引
                if ~firstCategoryCompleted
                    T1C = trialIdx; % 记录完成第一个分类所需的试次数
                    firstCategoryCompleted = true;
                end
                consecutiveCorrect = 0; % 重置连续正确次数
            end
        end
    end

    % 计算 Learning to Learn (LL)
    if CC >= 3 % 只有完成三个或三个以上的分类才能计算 LL
        % 计算每个分类阶段的错误率
        for j = 1:CC
            if j == 1
                startIdx = 1;
            else
                startIdx = categoryCompletionIndices(j-1) + 1;
            end
            endIdx = categoryCompletionIndices(j);
            categoryErrors = sum(~data.key_resp_react_corr(startIdx:endIdx));
            errorRates(j) = (categoryErrors / (endIdx - startIdx + 1)) * 100; % 错误率百分比
        end
        % 计算相邻两个分类阶段的错误率差值
        errorDiffs = diff(errorRates);
        % 计算 LL 指标（差值的平均数）
        LL = mean(errorDiffs);
    else
        LL = NaN; % 如果分类数量不足，LL 为 NaN
    end

    NPE = TE - PE; % Non-perseverative Errors = Total Errors - Perseverative Errors
    GS = trialNum - (5 * CC); % Global Score = n of trials – [n of achieved categories × 5]
    
    % 6. 存储结果
    result = {participantID, phoneNumber, idCard, date, expName, psychoPyVersion, frameRate, trialNum, TC, TE, PR, PE, NPE, CLR, CC, T1C, FMS, LL, GS, instructionStarted, keyRespStarted, keyRespRT};
    for j = 1:length(result)
        results{i, j} = result{j};
    end
end

% 7. 保存结果到 CSV 文件

r = cell2table(results,"VariableNames",headers);

% 写入文件
writetable(r, outputFile,'Encoding','UTF-8');

disp('分析完成，结果已保存！');
