%% CRF_test
% Primary author: Chris Magnano
%
% Editors: Teo Gelles
%          Andrew Gilchrist-Scott
%
% This file contains the main script for testing the tissue
% segmentation capabilities of the UGM CRF model with spm8

%Matlab paths that need to be added to run:
%addpath(genpath('/sonigroup/summer2014/USER/brainseg2014/UGM'))
%addpath(genpath('/sonigroup/fmri/spm8'))


function CRF_test(leaveOut,iterations,res,usePriors,useCdist)
    
    if (usePriors == true && useCdist == true)
        exception = MException('Parameters:Conflicting',['Cannot use both Priors ' ...
                            'and Cdist']);
        throw(exception);
    end
    
    close all
    pauses = 0; %turn pausing on/off (used in makeInitPlots)
    plots = 0;

    fold = leaveOut + 1; % Because the condor scripts start 1 step lower
    
    global dir paramDir restarting;
    [dir, paramDir, restarting] = makeDirs(fold, leaveOut, res, ...
                                           usePriors, useCdist);
    

    % Load IBSR Data
    [X, y, nExamples] = load_nifti('/sonigroup/fmri/IBSR_nifti_stripped/', ...
                                   res);

    % numSuperVoxels = 200;
    % shapeParam = 20;
    % superPixels = SLIC_3D(X{1},numSuperVoxels, shapeParam);
    
    % % figure
    % % image(X{1}(:,:,size(X{1}, 3)/2));
    % % colormap gray
    % % figure
    % % image(superPixels(:,:,size(superPixels, 3)/2));
    % % colormap gray
        
    % slicNii = make_nii(superPixels);
    % save_nii(slicNii, strcat('slic', '-', int2str(numSuperVoxels), ...
    %                          '-', int2str(shapeParam), '-', int2str(res), ...
    %                          '-', '1', '.nii'));
    % xNii = make_nii(X{1});
    % save_nii(xNii, strcat('x', '-', int2str(numSuperVoxels), ...
    %                          '-', int2str(shapeParam), '-', int2str(res), ...
    %                          '-', '1', '.nii'));
    % throw('Stupid exception');
    
    % Get data for Cross Folding
    [testing, training] = makeCrossFold(fold, nExamples);
    
    % Initial Plots
    if plots == 1
        makeInitPlots(testing, X, y, pauses);
    end
    
    % Init Features
    if restarting
        %Load everything in if restarting 
    else % if not restarting
        % Make Average Neighbor intensity a feature
        fprintf('Creating Neighborhood feature...\n');
        nBors = make_nBors(X, nExamples);
        cDist = NaN;
        if useCdist % If results of spm8 are being used, there is
                      % not enough memory on the swatcs computers
                      % to use the cDist feature
            
            % Make distance to center a feature
            fprintf('Creating Distance to Center feature...\n')
            cDist = center_distance(X, nExamples);    
        end
    end
    
    
    % Make X,y Into Correct Shape and correct Bias   
    [origX, origY, Zmask, ZmaskFlat, X, y, nStates, sizes, nPixelsArray, ...
     nBors, cDist] = reshapeMatrices(nExamples, X, y, nBors, cDist, ...
                                     useCdist);

    
    % Make edgeStructs COULD PARALLELIZE
    examples = makeEdgeStructs(nExamples, nStates, origX, y, ...
                               sizes, ZmaskFlat);

    origY = save_data(dir, origY, nExamples+1); %save data for later
    clear('y');
    clear('origX');
    clear('sizes')
    
    [examples, w] = prepareExamples(nExamples, examples, res, Zmask, ...
                               nPixelsArray, X, nBors, cDist, ...
                               usePriors, useCdist);
    
    clear('X');
    clear('nBors');
    clear('cDist');
    clear('nPixelsArray');
    clear('Zmask');
    
    % Stochastic gradient descent training
    trainCRF(nExamples, examples, leaveOut, iterations, testing, ...
             training, w, origY, ZmaskFlat, plots, pauses);
end

%% Stats Functions

function M = mcr(L,R)
%L is the labels, R is the results, returns the misclassification rate
    dif = int32(L)-int32(R);
    K = dif(:,:,:) ~= 0;
    M = sum(sum(sum(K)));
    M = (M/numel(R(R~=1)))*100;
    fprintf('\nMCR: %f', M);
end

function [results tani] = vOverlap(L,R)
%L is the labels, R is the results, returns the % volume overlap
    results = [0 0 0];
    tani = [0 0 0];
    for i=2:max(max(max(R)))
        max(max(max(R==i)));
        max(max(max(L==i)));
        V1 = sum(sum(sum(L == i)));
        V2 = sum(sum(sum(R == i)));
        dif = ismember(L,i)+ismember(R,i);
        K = dif(:,:,:) == 2;
        N = sum(sum(sum(K)));
        M =((N*2)/(abs(V1+V2)))*100;
        results(i-1) = M;
        tani(i-1) =(N/(V1+V2-N));
        fprintf('\n%% Volume Overlap: %f, Tanimoto: %f', M, N/(V1+V2-N));
    end
end

function M = vComp(L,R)
    N = 0;
    V1 = 0;
    V2 = 0;
    for i=2:max(max(max(R)))
        V1 = sum(sum(sum(L == i)));
        V2 = sum(sum(sum(R == i)));
        K = abs(V1-V2);
        N = sum(sum(sum(K)));
        M = (N/(abs(V1+V2)/2))*100;
        fprintf('\n%% Volume Difference: %f', M);
    end
    M = (N/(abs(V1+V2)/2))*100;

end

%% Other Functions
function [train, test] = splitTrainTest(tr,te,number)
    all = randperm(number);
    nTrain = int32((tr/(tr+te)) * number);
    train = all(1:nTrain);
    test = all(nTrain:end);
end

function avg = decode(w,examples,testing,y,plotTitle, ZmaskFlat, plots, dir)
    if plots == 1
        figure;
    end
    lenT = length(testing);
    lenT = sqrt(lenT);
    aGM = 0;
    aWM = 0;
    aCSF = 0;
    aMCR = 0;
    aDif = 0;
    tWM = 0;
    tGM= 0;
    tCSF = 0;
    y = load_data(y);
    for i = 1:length(testing)

        j =testing(i);
        examples{j} = load_data(examples{j});
        [nodePot,edgePot] = UGM_CRF_makePotentials(w,examples{j}.Xnode,examples{j}.Xedge,examples{j}.nodeMap,examples{j}.edgeMap,examples{j}.edgeStruct,1);
        
        %yDecode = UGM_Decode_LBP(nodePot,edgePot,examples{j}.edgeStruct);
        %yDecode = UGM_Decode_ICM(nodePot,edgePot,examples{i}.edgeStruct);
        %yDecode = int32(UGM_Decode_MaxOfMarginals(nodePot,edgePot,edgeStruct,@UGM_Infer_LBP));
        %yDecode2 = UGM_Infer_LBP(nodePot,edgePot,examples{j}.edgeStruct);
        yDecode = UGM_Decode_ICMrestart(nodePot,edgePot,examples{j}.edgeStruct,30); %last value is number of restarts
        yDecode = reImage(yDecode, ZmaskFlat{j});
        yDecode(yDecode == 0) = 1;
        
        %plot marginals
        %     yDecode2 = UGM_Infer_LBP(nodePot,edgePot,examples{j}.edgeStruct);
        %     figure;
        %     for k = 1:4
        %         subplot(2,3,k);
        %         marg = reImage(yDecode2(:,k),ZmaskFlat{j});
        %         imagesc(reshape(marg,nRows,nCols));
        %         colormap gray
        %     end
        
        [nRows, nCols, nSlices] = size(y{testing(i)});
        yDecode = reshape(yDecode, nRows, nCols, nSlices);

        if plots == 1
            subplot(lenT,lenT+1, i);
            imagesc(reshape(yDecode(:,:,3),nRows,nCols));
            colormap gray
        end
        
        %Evaluate
        
        aMCR = aMCR + mcr((reshape(y{testing(i)},nRows,nCols,nSlices)),reshape(yDecode,nRows,nCols,nSlices));
        results = [0 0 0];
        [results, tani] =  vOverlap((reshape(y{testing(i)},nRows,nCols,nSlices)),reshape(yDecode,nRows,nCols,nSlices));
        aCSF = aCSF + results(1);
        aGM = aGM + results(2);
        aWM = aWM + results(3);
        tWM = tWM + tani(3);
        tGM = tGM + tani(2);
        tCSF = tCSF + tani(1);
        aDif = aDif + vComp((reshape(y{testing(i)},nRows,nCols,nSlices)),reshape(yDecode,nRows,nCols,nSlices));
        examples{j} = save_data(dir, examples{j}, j);
        
    end
    fprintf('\n Average MCR: %f\n Average Volume Overlap: %f %f %f\n Average Volume Difference: %f\nAverage Tanimoto %f %f %f\n', aMCR/length(testing), aCSF/length(testing), ...
            aGM/length(testing), aWM/length(testing), aDif/length(testing), ...
            tWM/length(testing), tGM/length(testing), tCSF/length(testing));
    avg = (aWM + aGM)/(2*length(testing));
    
    outputfileName = strcat(dir, 'Results.txt');
    outputfile = fopen(outputfileName, 'w');
    fprintf(outputfile, ['Average MCR: %f\nAverage Volume Overlap: ' ...
    '%f %f %f\nAverage Volume Difference: %f\nAverage Tanimoto %f ' ...
    '%f %f\nOverall Average: %f\n'], aMCR/length(testing), aCSF/length(testing), ...
            aGM/length(testing), aWM/length(testing), aDif/length(testing), ...
            tWM/length(testing), tGM/length(testing), tCSF/ ...
            length(testing), avg);
    
    fclose(outputfile);


    %suptitle(plotTitle);
end

function [origX, origY, Zmask, X, y] = maskZeros(X, y, nExamples)
    Zmask = cell(nExamples,1);
    newX = cell(nExamples,1);
    newY = cell(nExamples,1);
    parfor i = 1:nExamples
        Zmask{i} = X{i} ~= 0;
        newX{i} = X{i}(Zmask{i});
        newY{i} = y{i}(Zmask{i});
    end
    origX = X;
    origY = y;
    X = newX;
    y = newY;
end

function nImage = reImage(masked, ZmaskFlat)
    nImage = int32(ZmaskFlat);
    nImage(:,:,ZmaskFlat) = masked(:,:,:);
end

function M = detect_skull(I)

    [h,w,r] = size(I);

    parfor iCount = 1:r,
        J = imfill(I(:,:,iCount),'holes');
        K = im2bw(J/max(J(:)), 0.3*graythresh(J(:)/max(J(:))));
        [L1,N] = bwlabel(K);
        maxa = 0; maxj=0;
        for jCount=1:N,
            a = sum(sum(L1==jCount));
            if a>maxa,
                maxa=a;
                maxj=jCount;
            end
        end
        L(:,:,iCount) = double(L1==maxj);
    end
    M = L;
end

%% File I/O

function fName = save_data(dir, data, i)
    fName = strcat(dir, 'ex', int2str(i));
    if ~exist(dir, 'dir')
        mkdir(dir);
    end
    save(fName,'data','-v7.3');
    % f = fopen(fName, 'w');
    % fwrite(f, data, saveClass);
    % fclose(f);
end

function loadData = load_data(fName)
% f = fopen(fName, 'r');
% data = fread(f, inf, loadClass);
% fclose(f);
    loadData = load(fName, 'data');
    loadData = loadData.('data');
end

function cleanup(dir)
    if exist(dir, 'dir')
        rmdir(dir, 's');
    end
end

function [X,y,nExamples] = load_ibsr_Ana(imDir, segDir)
%% load data for ibsr data type
%needs to take 
    bList = dir(strcat(imDir,'*.hdr'));
    rawImages = cell(length(bList),1);
    nExamples = length(bList);
    %rawImages = zeros(length(bList), 256,256);
    for f = 1:length(bList)
        fid = fopen(strcat(imDir,bList(f).name));
        stats = fscanf(fid, '%d');
        %nSlices = stats(3)+2;
        fid = fopen(strcat(imDir,bList(f).name(1:end-4),'.img'));
        I = fread(fid,inf,'uint16=>int32');
        nSlices = size(I,1)/(256*256);
        I = reshape(I, 256, 256, nSlices);
        %rawImages(f,:,:) = reshape(I(:,:,int32(nSlices/2)),256,256);
        rawImages{f} = reshape(I(:,:,int32(nSlices/3)),256,256);
    end

    bList = dir(strcat(segDir,'*seg_ana.hdr'));
    segs = cell(length(bList),1);
    %segs = zeros(length(bList), 256,256);
    for f = 1:length(bList)
        fid = fopen(strcat(segDir,bList(f).name));
        %stats = fscanf(fid, '%d');
        %nSlices = stats(3);
        fid = fopen(strcat(segDir,bList(f).name(1:end-4),'.img'));
        I = fread(fid,inf,'uint16=>int32');
        nSlices = size(I,1)/(256*256);
        I = reshape(I, 256, 256, nSlices);
        %segs(f,:,:) = reshape(I(:,:,int32(nSlices/2)),256,256); %Just grab middle for now
        segs{f} = reshape(I(:,:,int32(nSlices/3)),256,256);
    end
    fclose('all'); %python needs this

    %Create X and Y
    y = segs;
    X = rawImages;
    for i=1:nExamples
        %1 is background, 2 is CSF, 3 is GM, 4 is WM
        y{i} = y{i} + 1;%((y{i}==0) + ((y{i}==128)*2) + ((y{i}==192)*3) + ((y{i}==254)*4)); 
        X{i} = double(X{i});
        y{i} = int32(y{i});
        max(y{i}(:))
    end
end

function [X,y,nExamples] = load_ibsr(imDir, segDir)
    offsets = [0 1 2 1 1 0 0 0 0 3 3 -4 3 2 6 8 1 0 0 2];
    %Load data from ibsr database
    bList = dir(strcat(imDir,'*.hdr'));
    rawImages = cell(length(bList),1);
    nExamples = length(bList)-1; %CAUSE WHAT THE HELL -4



    bList = dir(strcat(segDir,'*.hdr'));
    segs = cell(length(bList),1);
    ends = zeros(nExamples,1);

    for f = 1:length(bList)
        fid = fopen(strcat(segDir,bList(f).name));
        stats = fscanf(fid, '%d');
        nSlices = stats(3);
        ends(f) = nSlices;
        fid = fopen(strcat(segDir,bList(f).name(1:end-4),'.buchar'));
        I = fread(fid,inf,'uint8=>int32');
        I = reshape(I, 256, 256, nSlices);
        if offsets(f) > -1
            segs{f} = I;
        end
    end

    for f = 1:length(bList)
        fid = fopen(strcat(imDir,bList(f).name));
        stats = fscanf(fid, '%d');
        nSlices = stats(3)+2;
        fid = fopen(strcat(imDir,bList(f).name(1:end-4),'.buchar'));
        I = fread(fid,inf,'uint8=>int32');
        I = reshape(I, 256, 256, nSlices);
        if (ends(f) + offsets(f)) > nSlices
            fprintf('herr!, %d, %d\n', nSlices, ends(f));
            a = segs{f};
            segs{f} = a(:,:,1:nSlices-offsets(f));
            rawImages{f} = I(:,:,offsets(f)+1:end);
        else
            if offsets(f) > -1
                rawImages{f} = I(:,:,offsets(f)+1:ends(f)+offsets(f));
            end
        end
    end

    segs{12} = segs{11};
    rawImages{12} = rawImages{11};

    fclose('all'); %python needs this

    %Create X and Y
    y = segs;
    X = rawImages;
    for i=1:nExamples
        %1 is background, 2 is CSF, 3 is GM, 4 is WM
        y{i} = ((y{i}==0) + ((y{i}==128)*2) + ((y{i}==192)*3) + ((y{i}==254)*4)); 
        X{i} = double(X{i});
        y{i} = int32(y{i});
    end
    for i = 1:nExamples
        fprintf('%d, %d, %d\n',size(X{i},3),size(y{i},3), offsets(i))
        X{i} = X{i}(1:2:end,1:4:end,1:2:end);
        y{i} = y{i}(1:2:end,1:4:end,1:2:end);
    end
    % nExamples = 7;
    % X(8:end) = [];
    % y(8:end) = [];
end

function [X,y,nExamples] = load_ADNI(imDir)

%load WM
%load GM
%load CSF

    bList = dir(strcat(imDir, 'c3*'));

    nExamples = length(bList);
    nExamples = 4;
    X = cell(nExamples,1);
    y = cell(nExamples,1);
    fprintf('\nLoading %d files',nExamples);
    for i = 1:nExamples
        fprintf('.');
        heads = {'m','c1','c2','c3'};
        results = cell(4,1);
        
        for j=1:4
            heads{j} = strcat(imDir, heads{j}, 'patient', int2str(i), '.nii');
            I_t1uncompress = wfu_uncompress_nifti(heads{j});
            I_uncompt1 = spm_vol(I_t1uncompress);
            I_T1 = spm_read_vols(I_uncompt1);
            results{j} = int32(I_T1);
        end

        X{i} = results{1};
        marginals = zeros([3 size(results{4})]);
        marginals(1,:,:,:) = results{2}(:,:,:);
        marginals(2,:,:,:) = results{3}(:,:,:);
        marginals(3,:,:,:) = results{4}(:,:,:);

        [C y{i}] = max(marginals, [], 1);
        y{i} = reshape(((int32(y{i}).*int32(C > 0.5)) + 1), size(X{i})); %Threshold for marginals 

    end
    fprintf('\n');
    for i = 1:nExamples
        % fprintf('%d, %d\n',size(X{i},3),size(y{i},3))
        X{i} = double(X{i}(1:2:end,1:2:end,1:2:end));
        y{i} = double(y{i}(1:2:end,1:2:end,1:2:end));
    end
end

function [X,y,nExamples] = load_nifti(imDir,res)
%Loads IBSR V2 nifti files

    fprintf('Loading Nifti Images');
    bList = dir(strcat(imDir));
    nExamples = 18; %The IBSR_nifti_stripped directory has 18 image
    X = cell(nExamples,1);
    y = cell(nExamples,1);
    parfor i = 1:nExamples
        
        fprintf('.');
        if i < 10
            place = strcat(imDir,'IBSR_0',int2str(i),'/');
            fileHead = strcat('IBSR_0',int2str(i));
        else
            place = strcat(imDir,'IBSR_',int2str(i),'/');
            fileHead = strcat('IBSR_',int2str(i));
        end
        
        %Image
        I_t1uncompress = wfu_uncompress_nifti(strcat(place,fileHead,'_ana_strip.nii'));
        I_uncompt1 = spm_vol(I_t1uncompress);
        I_T1 = spm_read_vols(I_uncompt1);
        X{i} = I_T1;
        
        %Segmentation
        I_t1uncompress = wfu_uncompress_nifti(strcat(place,fileHead,'_segTRI_ana.nii'));
        I_uncompt1 = spm_vol(I_t1uncompress);
        I_T1 = spm_read_vols(I_uncompt1);
        y{i} = I_T1+1;
    end
    
    fprintf('\n');
    
    parfor i = 1:nExamples
        X{i} = X{i}(1:res:end,1:res:end,1:res:end);
        y{i} = y{i}(1:res:end,1:res:end,1:res:end);
    end
end

function [X,y,nExamples] = load_brainweb()
% Currently Only Works for 1 brain. 
    if exist('/home/cmagnan1/phantom_full.rawb', 'file')
        fid = fopen('/home/cmagnan1/phantom_full.rawb');
        I = fread(fid,inf,'uint8=>int32');
        I = reshape(I, 181, 217, 181);
    end

    if exist('/home/cmagnan1/phantom_1.0mm_normal_bck.rawb', 'file')
        fid = fopen('/home/cmagnan1/phantom_1.0mm_normal_bck.rawb');
        bck = fread(fid,inf,'uint8=>int32');
        bck = reshape(bck, 181, 217, 181);
    end

    if exist('/home/cmagnan1/phantom_1.0mm_normal_csf.rawb', 'file')
        fid = fopen('/home/cmagnan1/phantom_1.0mm_normal_csf.rawb');
        csf = fread(fid,inf,'uint8=>int32');
        csf = reshape(csf, 181, 217, 181);
    end

    if exist('/home/cmagnan1/phantom_1.0mm_normal_gry.rawb', 'file')
        fid = fopen('/home/cmagnan1/phantom_1.0mm_normal_gry.rawb');
        gry = fread(fid,inf,'uint8=>int32');
        gry = reshape(gry, 181, 217, 181);
    end

    if exist('/home/cmagnan1/phantom_1.0mm_normal_wht.rawb', 'file')
        fid = fopen('/home/cmagnan1/phantom_1.0mm_normal_wht.rawb');
        wht = fread(fid,inf,'uint8=>int32');
        wht = reshape(wht, 181, 217, 181);
    end


    %Create label data
    bck = (bck>=30) * 1;
    csf = (csf>=30) * 2;
    wht = (wht>=30) * 3;
    gry = (gry>=30) * 4;
    y = bck + wht;
    y(y==3) = 2;
    y = y + gry;
    y(y>3) = 3;
    y = y + csf;
    y(y>4) = 4;

    X = I;
    nExamples = 1;
end

%% Feature Making
function nBors = make_nBors(X, nExamples)
%Make Neighbor Intensities another feature
    nBors = cell(nExamples,1);
    rNbor = cell(nExamples,1);
    lNbor = cell(nExamples,1);
    uNbor = cell(nExamples,1);
    dNbor = cell(nExamples,1);

    for i = 1:nExamples
        rNbor{i} = zeros(size(X{i}));
        lNbor{i} = zeros(size(X{i}));
        uNbor{i} = zeros(size(X{i}));
        dNbor{i} = zeros(size(X{i}));
        
        rNbor{i}(1:end-1,:) = rNbor{i}(1:end-1,:) + X{i}(2:end,:);
        lNbor{i}(2:end,:) = lNbor{i}(2:end,:) + X{i}(1:end-1,:);
        uNbor{i}(:,1:end-1) = uNbor{i}(:,1:end-1) + X{i}(:,2:end);
        dNbor{i}(:,2:end) = dNbor{i}(:,2:end) + X{i}(:,1:end-1);
        
        nBors{i} = rNbor{i} + lNbor{i} + uNbor{i} + dNbor{i};
        nBors{i} = nBors{i} ./ 4;
    end
end

function cDist = center_distance(X,nExamples)
    cDist = cell(nExamples,1);
    for i=1:nExamples
        xlen = size(X{i},1);
        ylen = size(X{i},2);
        zlen = size(X{i},3);
        [A,B,C] = meshgrid(1:xlen,1:ylen,1:zlen);
        cDist{i}=sqrt(((A-xlen/2).^2)+((B-ylen/2).^2)+((C-zlen).^2));
    end
    cDist = cor_bias(cDist,nExamples);
end


function X = cor_bias(X, nExamples)
%Intensity Bias Correction
    for i=1:nExamples
        %     notZ = X{i}((X{i} ~= 0)); 
        %     ignoreStd = std(notZ);
        %     ignoreMean = mean(notZ);
        %     X{i} = (X{i}-ignoreMean)/ignoreStd + 4;
        X{i} = UGM_standardizeCols(X{i},1);
    end
end

function [WMMin, GMMin, CFMin, BGMin] = min_bins(X, y, nExamples, training)
    GM = 0;
    WM = 0;
    CF = 0;
    BG = 0;
    parfor i = 1:length(training)
        GMbin = (y{training(i)} == 3);
        GM = GM + sum(sum(X{training(i)} .* GMbin))/sum(sum(GMbin)); %average GM value
        
        WMbin = (y{training(i)} == 4);
        WM = WM + sum(sum(X{training(i)} .* WMbin))/sum(sum(WMbin));
        
        BGbin = (y{training(i)} == 1);
        if sum(sum(BGbin == 0))
            BG = BG + -5;
        else
            BG = BG + sum(sum(X{training(i)}.* BGbin))/sum(sum(BGbin));
        end
        
        CFbin = (y{training(i)} == 2);
        CF = CF + sum(sum(X{training(i)} .* CFbin))/sum(sum(CFbin));
    end

    WM = WM/length(training);
    GM = GM/length(training) - 1;
    CF = CF/length(training) - 1;
    BG = BG/length(training);

    fprintf('Average Values: %f, %f, %f, %f \n', WM, GM, BG, CF);

    BGMin = cell(nExamples,1);
    WMMin = cell(nExamples,1);
    GMMin = cell(nExamples,1);
    CFMin = cell(nExamples,1);
    p = 1;
    figure;
    parfor i = 1:nExamples
        WMDif = abs(X{i} - WM);
        GMDif = abs(X{i} - GM);
        BGDif = abs(X{i} - BG);
        CFDif = abs(X{i} - CF);
        
        BGMin{i} = BGDif < (((GMDif < WMDif) .* GMDif) + ((WMDif <= GMDif) .* WMDif));
        WMMin{i} = WMDif <= (((GMDif < BGDif) .* GMDif) + ((BGDif <= GMDif) .* BGDif));
        GMMin{i} = GMDif < (((BGDif < WMDif) .* BGDif) + ((WMDif <= BGDif) .* WMDif));
        CFMin{i} = CFDif < (((GMDif < WMDif) .* GMDif) + ((WMDif <= GMDif) .* WMDif));
        
        BGMin{i} = BGMin{i} .* (BGDif <= CFDif);
        WMMin{i} = WMMin{i} .* (WMDif <= CFDif);
        GMMin{i} = GMMin{i} .* (GMDif <= CFDif);
        CFMin{i} = CFMin{i} .* (CFDif <= BGDif);
    end
end

function [xCor yCor] = cor_feats(nRows, nCols, nNodes)
%% Make x and y positions another feature
    xCor = 1:nCols;
    yCor = 1:nRows;
    xCor = reshape(xCor, nCols, 1);
    yCor = reshape(yCor, nRows, 1);
    xCor = reshape(repmat(xCor, [1 nRows]),nRows,nCols);
    yCor = repmat(yCor, [1 nCols]);
    xCor = double(reshape(xCor,1,1,nNodes));
    yCor = double(reshape(yCor,1,1,nNodes)); 
    xCor = abs(xCor - nCols/2);
    yCor = abs(yCor - nRows/2);

    yCor = repmat(yCor, [1 1 1]);
    xCor = repmat(xCor, [1 1 1]);
    %cDist = sqrt(xCor.^2 + yCor.^2); %change to single distance from center\
end

function adj = make_adj(nRows, nCols, nSlices, nNodes)
    [ii jj] = sparse_adj_matrix([nRows nCols nSlices], 1, inf);
    adj = sparse(ii, jj, ones(1,numel(ii)), nNodes, nNodes);
    % %Need to test diagonal edges more
    % adj = sparse(nNodes,nNodes);
    % 
    % % Add Down Edges
    % ind = 1:nNodes-1;
    % exclude = sub2ind([nRows nCols],repmat(nRows,[1 nCols]),1:nCols); % No Down edge for last row
    % ind = setdiff(ind,exclude);
    % adj(sub2ind([nNodes nNodes],ind,ind+1)) = 1;
    % 
    % % Add Down-Right Edges
    % ind = 1:nNodes-1;
    % exclude = union(sub2ind([nRows nCols],repmat(nRows,[1 nCols]),1:nCols), ...
    %     sub2ind([nRows nCols],1:nRows,repmat(nCols,[1 nRows]))); % No Down edge for last row or Column
    % ind = setdiff(ind,exclude);
    % adj(sub2ind([nNodes nNodes],ind,ind+1+nRows)) = 1;
    % 
    % 
    % %adj(sub2ind([nNodes nNodes], ind, ind+(nRows*nCols))) = 1;
    % 
    % % Add Down-Left Edges
    % ind = 1:nNodes-1;
    % exclude = union(sub2ind([nRows nCols],repmat(nRows,[1 nCols]),1:nCols), ...
    %     sub2ind([nRows nCols],1:nRows,repmat(1,[1 nRows]))); % No Down edge for last row or Column
    % ind = setdiff(ind,exclude);
    % adj(sub2ind([nNodes nNodes],ind,ind+1-nRows)) = 1;
    % 
    % % Add Right Edges
    % ind = 1:nNodes-1;
    % exclude = sub2ind([nRows nCols],1:nRows,repmat(nCols,[1 nRows])); % No right edge for last column
    % ind = setdiff(ind,exclude);
    % adj(sub2ind([nNodes nNodes],ind,ind+nRows)) = 1;
    % 
    % % Add Up/Left Edges
    % adj = adj+adj';
end

function [ii jj] = sparse_adj_matrix(sz, r, p)
%
% Construct sparse adjacency matrix (provides ii and jj indices into the
% matrix)
%
% Copyright (c) Bagon Shai
% Department of Computer Science and Applied Mathmatics
% Wiezmann Institute of Science
% http://www.wisdom.weizmann.ac.il/
% 
% Permission is hereby granted, free of charge, to any person obtaining a copy
% of this software and associated documentation files (the "Software"), to deal
% in the Software without restriction, subject to the following conditions:
% 
% The above copyright notice and this permission notice shall be included in 
% all copies or substantial portions of the Software.
%
% The Software is provided "as is", without warranty of any kind.

% number of variables
    n = prod(sz);
    % number of dimensions
    ndim = numel(sz);

    tovec = @(x) x(:);
    N=cell(ndim,1);
    I=cell(ndim,1);

    % construct the neighborhood
    fr=floor(r);
    for di=1:ndim
        N{di}=-fr:fr;
        I{di}=1:sz(di);
    end

    [N{1:ndim}]=ndgrid(N{:});
    [I{1:ndim}]=ndgrid(I{:});
    N = cellfun(tovec, N, 'UniformOutput',false);
    N=[N{:}];
    I = cellfun(tovec, I, 'UniformOutput',false);
    I=[I{:}];
    % compute N radius according to p
    switch lower(p)
      case {'1','l1',1}
        R = sum(abs(N),2);
      case {'2','l2',2}
        R = sum(N.*N,2);
        r=r*r;
      case {'inf',inf}
        R = max(abs(N),[],2);
      otherwise
        error('sparse_adj_matrix:norm_type','Unknown norm p (should be either 1,2 or inf');
    end
    N = N(R<=r+eps,:);

    % "to"-index (not linear indices)
    ti = bsxfun(@plus, permute(I,[1 3 2]), permute(N, [3 1 2]));
    sel = all(ti >= 1, 3) & all( bsxfun(@le, ti, permute(sz, [1 3 2])), 3);
    csz = cumprod([1 sz(1:(ndim-1))]);
    jj = sum( bsxfun(@times, ti-1, permute(csz, [1 3 2])), 3)+1; % convert to linear indices
    ii = repmat( (1:n)', [1 size(jj,2)]);
    jj = jj(sel(:));

    ii = ii(sel(:));

end

function priors = load_spm8_matrix(res, tissueNum, imageNum, Zmask, ...
                                   nPixelsArray)
    
    priorsx = load_spm8_priors(res, tissueNum,imageNum);
    
    restarting = 0;
    
    nPixels = nPixelsArray(imageNum);
    
    if restarting == 0
        
        priorsx = priorsx(Zmask{imageNum});
        priorsx = reshape(priorsx,1,1,nPixels);
    end
    
    priors = priorsx;
end

function X = load_spm8_priors(res, tissueNum, imageNum)
% We will only use one of either X or y, but we are unsure of which
% to use as of yet    

    file = '/sonigroup/fmri/IBSR_nifti_stripped/new_Segment_MRF2_dist2/';
    % Directory we use for the
    % spm8 tissue segmpentation
    % images

        
    filename = file;
    if (imageNum<10)
        imageNum = strcat('0', int2str(imageNum));
    else
        imageNum = int2str(imageNum);
    end
    
    if (tissueNum == 1)
        filename = strcat(filename, 'rc1IBSR_');
        filename = strcat(filename, imageNum);
        filename = strcat(filename, '_ana.nii');
    elseif (tissueNum == 2)
        filename = strcat(filename, 'rc2IBSR_');
        filename = strcat(filename, imageNum);
        filename = strcat(filename, '_ana.nii');
    elseif (tissueNum == 3)
        filename = strcat(filename, 'rc3IBSR_');
        filename = strcat(filename, imageNum);
        filename = strcat(filename, '_ana.nii');
    end
    
    %Image
    I_t1uncompress = wfu_uncompress_nifti(filename);
    I_uncompt1 = spm_vol(I_t1uncompress);
    I_T1 = spm_read_vols(I_uncompt1);
    X = I_T1;
    

    %fprintf('%d',size(X,3),size(y,3))
    X = X(1:res:end,1:res:end,1:res:end);
    
end

function [dir, paramDir, restarting] = makeDirs(fold, leaveOut, ...
                                                res, usePriors, useCdist)
    global dir paramDir restarting;
    
    f = 1;
    found = 0;
    restarting = 0;
    
    %%makes temp dirs to store temp files
    while ~found
        dir = strcat('/scratch/tgelles1/summer2014/testing/', ...
                     int2str(fold),'res',int2str(res),'num', ...
                     'pr',int2str(usePriors),...
                     'Cd',int2str(useCdist),...
                     int2str(f),'/'); %directory for temp files
        paramDir = dir; %directory for parameter filesx
        
        if exist(paramDir, 'dir') || exist(dir, 'dir') 
            rmdir(paramDir, 's')
        end
        break; % A hack that must be removed before the world ends
        
        
        % if exist(paramDir, 'dir') || exist(dir, 'dir') 
        %     f = f + 1;
        % else
        %     break;
        % end
    end
    
    if f > 1
        dir = strcat('/scratch/tgelles1/summer2014/testing/', ...
                     int2str(fold),'res',int2str(res),'num', ...
                     'pr',int2str(usePriors),...
                     'Cd',int2str(useCdist),...
                     int2str(f-1),'/'); %directory for temp files
        paramDir = dir; %directory for parameter files
        restarting = 1;
    else
        mkdir(paramDir);
    end
end

function [testing, training] = makeCrossFold(fold, nExamples)

    global dir paramDir restarting;
    
    testing = [fold];
    if fold == 1
        training = 2:nExamples;
    elseif fold == nExamples
        training = 1:(nExamples-1);
    else
        training = [1:(fold-1) (fold + 1):nExamples];
    end
end

function makeInitPlots(testing, X, y, pauses)
    
    if plots == 1
        figure;
        lenT = length(testing);
        lenT = sqrt(lenT);
        for j = 1:numel(testing)
            subplot(lenT, lenT+1, j);
            size(X{testing(j)})
            i = testing(j);
            imagesc(reshape((X{testing(j)}(:,:,floor(size(X{i},3)/2))), ...
                            size(X{i},1),size(X{i},2))); %Should
                                                         %not
                                                         %hardcode
                                                         %these
            colormap gray
        end
        suptitle('MRI Images');
        if pauses
            fprintf('(paused)\n');
            pause
        end;
        title('Original MRI');
        
        %Segmentations
        figure;
        lenT = length(testing);
        lenT = sqrt(lenT);
        for j = 1:numel(testing)
            subplot(lenT, lenT+1, j);
            i = testing(j);
            imagesc(reshape((y{testing(j)}(:,:,floor(size(y{i},3)/2))), ...
                            size(y{i},1),size(y{i},2)));
            colormap gray
        end
        suptitle('Segmentation Truth');
        if pauses
            fprintf('(paused)\n');
            pause
        end
    end
end

function [origX, origY, Zmask, ZmaskFlat, X, y, nStates, sizes, ...
          nPixelsArray, nBors, cDist] = reshapeMatrices(nExamples, ...
                                                      X, y, nBors, ...
                                                      cDist, ...
                                                      useCdist);
    global dir paramDir restarting;
    
    sizes = zeros(nExamples);
    parfor i=1:nExamples
        [nRows,nCols,nSlices] = size(X{i});
        sizes(i) = nRows*nCols*nSlices;
    end

    fprintf('Masking Zeros...\n');
    [origX, origY, Zmask, X, y] = maskZeros(X, y, nExamples);

    nStates = max(y{1}(:)); %assume y{1} has all states 
    ZmaskFlat = cell(nExamples,1);
    
    nPixelsArray = zeros(1, nExamples);

    fprintf('Reshaping Matricies');
    for i=1:nExamples
        fprintf('.');
        nPixels = size(X{i},1);
        nPixelsArray(i) = nPixels;
        
        y{i} = reshape(y{i},[1, 1 nPixels]);
        X{i} = reshape(X{i},1,1,nPixels);
        
        if restarting == 0
            nBors{i} = nBors{i}(Zmask{i});
            nBors{i} = reshape(nBors{i},1,1,nPixels);
            
            if (useCdist)
                cDist{i} = cDist{i}(Zmask{i});
                cDist{i} = reshape(cDist{i},1,1,nPixels);
            end
        end
        
        ZmaskFlat{i} = reshape(Zmask{i}, 1, 1, sizes(i));
    end
    fprintf('\n');
    
    %clear Zmask;
    %we choose to use Zmask later, so it is not cleared here
    fprintf('Correcting Bias...\n');
    X = cor_bias(X,nExamples);
end

function examples = makeEdgeStructs(nExamples, nStates, origX, y, ...
                                    sizes, ZmaskFlat);
    
    global dir paramDir restarting;
    
    fprintf('Creating Adj Matrix');
    
    if restarting == 0
        examples = cell(nExamples,1);
        
        for i=1:nExamples
            fprintf('.');
            adj = make_adj(size(origX{i},1), size(origX{i},2), size(origX{i},3),sizes(i));
            adj = adj + adj';
            adj(adj==2) = 1;
            maskAdj = adj;
            maskAdj = maskAdj(ZmaskFlat{i},:);
            maskAdj = maskAdj(:,ZmaskFlat{i});
            clear adj;  %clear things once not needed    
            examples{i}.edgeStruct = UGM_makeEdgeStruct(maskAdj,nStates,1,100);
            clear maskAdj;
            examples{i}.Y = int32(y{i});
            examples{i} = save_data(dir, examples{i}, i);
        end
    end
    fprintf('\n');
end

function [examples, w] = prepareExamples(nExamples, examples, res, ...
                                         Zmask, nPixelsArray, X, ...
                                         nBors, cDist, usePriors,useCdist);
    
    global dir paramDir restarting;
    
    tied = 1;

    if restarting == 0
        
        fprintf('Creating Xnode, Xedge, and maps');
        
        %Here all the features are put into the final structure
        for i = 1:nExamples
            fprintf('.');
            examples{i} = load_data(examples{i});
            
            %Load spm8 Priors
            if (usePriors)
                % Note: to test space requirements, this code has
                % been changed such that only one priors matrix is loaded
                c1priors = load_spm8_matrix(res, 1, i, Zmask, ...
                                            nPixelsArray);
                %c2priors = load_spm8_matrix(res, 2, i, Zmask, ...
                %                            nPixelsArray);
                %c3priors = load_spm8_matrix(res, 3, i, Zmask, ...
                %                            nPixelsArray);
                
                
                %Make Xnode
                examples{i}.Xnode = [ones(1,1,size(X{i},3)) X{i} ...
                                    UGM_standardizeCols(nBors{i},tied), ...
                                    c1priors]; %c2priors,
                                                         %c3priors];
                                                         %GMMin{i}
                                                         %WMMin{i}
                                                         %BGMin{i}
                                                         %CFMin{i}];
                %add feature matricies
                sharedFeatures = [1 0 1 0]; % 0 0]; %needs to reflect number
                                              %of features
            elseif (useCdist)
                % We know that useCdist and usePriors are
                % mututally exclusive
                examples{i}.Xnode = [ones(1,1,size(X{i},3)) X{i} ...
                                    UGM_standardizeCols(nBors{i},tied) ...
                                    cDist{i}];

                %add feature matricies
                sharedFeatures = [1 0 1 1];
                
            else
                examples{i}.Xnode = [ones(1,1,size(X{i},3)) X{i} ...
                                    UGM_standardizeCols(nBors{i},tied)];

                %add feature matricies
                sharedFeatures = [1 0 1];
                
            end
            
            examples{i}.Xedge = ...
                 UGM_makeEdgeFeatures(examples{i}.Xnode, ...
                                     examples{i}.edgeStruct ...
                                      .edgeEnds,sharedFeatures(:));
            
            %Makes mapping of features to parameters
            [examples{i}.nodeMap examples{i}.edgeMap w] = ...
                UGM_makeCRFmaps(examples{i}.Xnode, ...
                                examples{i}.Xedge, ...
                                examples{i}.edgeStruct,0,tied,1,1);
            
            examples{i} = save_data(dir, examples{i}, i);
            
            if (usePriors)
                clear('c1priors')
                %clear('c2priors')
                %clear('c3priors')
            end
        end

        fprintf('\n');
        save(strcat(paramDir,'paramsIter',int2str(0)),'w','-v7.3');
    end
end

function trainCRF(nExamples, examples, leaveOut, iterations, testing, ...
                  training, w, origY, ZmaskFlat, plots, pauses);
    
    global dir paramDir restarting;
        
    fprintf('\nBeginning Training\n');
    stepSize = 1e-3;
    iterStart = 1;

    %Load saved parameters if restarting
    if restarting == 1
        examples = cell(nExamples,1);
        for i = 1:nExamples
            examples{i} = strcat(dir, 'ex', int2str(i));
        end
        fprintf(strcat(paramDir,'paramsIter',int2str(iterStart)));
        while (exist(strcat(paramDir,'paramsIter', ...
                           int2str(iterStart),'.mat'),'file') ...
               && iterStart<iterations)
            
            iterStart = iterStart + 1;
            fprintf(strcat(paramDir,'paramsIter',int2str(iterStart)));
        end
        if iterStart > 1
            iterStart = iterStart -1;
            tempData = load(strcat(paramDir,'paramsIter',int2str(iterStart)),'w');
            w = tempData.('w');
            fprintf('\nRestarting From %d\n',iterStart);
        end
    end


    %Actual training 
    for iter = iterStart:iterations
        i = training(randi(length(training),1));
        
        examples{i} = load_data(examples{i});
        %Uncomment to not use mex
        %examples{i}.edgeStruct.useMex = 0;
        %calculate training step
        
        funObj = @(w)UGM_CRF_NLL(w,...
                                 examples{i}.Xnode, ...
                                 examples{i}.Xedge, ...
                                 examples{i}.Y+int32(examples{i}.Y==1), ...
                                 examples{i}.nodeMap, ...
                                 examples{i}.edgeMap, ...
                                 examples{i}.edgeStruct,...
                                 @UGM_Infer_LBP);


        examples{i} = save_data(dir, examples{i}, i);
        [f,g] = funObj(w); %calculate gradient from training step
        fprintf('Iter = %d of %d (fsub = %f) on %d\n',iter,iterations,f,i);
        w = w - stepSize*g; %take small step in direction of gradient
        save(strcat(paramDir,'paramsIter',int2str(iter)),'w','-v7.3');
        
    end

    %origY = load_data(origY);

    avg = decode(w, examples, testing, origY, 'SGM Decoding', ...
                 ZmaskFlat, plots, dir);
    avg
    if pauses
        fprintf('(paused)\n');
        pause
    end
end