function results = RLICA(X, ref, S, w_init, t, k)
% RLICA - perform ROI-wise longitudinal ICA
%    Solves for the RL-ICA objective function:
%    argmin_{w} \sum_i{J(X_i*w_i) + alpha * ||X_i*w_i - ref_i||^2} s.t.
%               S * X*w = 0
%
% Inputs:
%    X: whitenned BOLD of all sessions (after dimension reduction) 
%
%    ref: group estimation of all ICs
%
%    S: p * V matrix; p indicator functions for the p parcels
%
%    w_init: initial values for w
%
%    k: weighting parameter for group-level guidance
%
% To Do:
%    automatic set parameters for Bregman Itreations
% 
% Author: Qingyu Zhao, Ph.D., 
% Stanford University / SRI international
% email address: qingyuz@stanford.edu
% Last Modified: May, 2018
    
    %% numerical algorithm settings

    % numerical parameters for Bregman Iteration (ADMM-like)
    % needs exploration for the optimization method to converge correctly
    ro1 = 1; 
    ro2 = 25;
    iterMax = 15;
    
    % 1: use Null Space to construct longitudinal constraint
    % 2: use ADMM to construct longitudinal constraint
    nullSpaceConstruction = 2;
    
    % 1: return strictly orthogonal w
    % 2: return longitudinally consistent w
    orthogonalConstraint = 1; 
    
    %% collect data info
    sessionNum = length(X);
    maskVoxNum = size(X{1},2);
    numEigs = size(X{1},1);
    parcelNum = size(S,1);
    ICNum = size(ref,1);
	
    %% constructing the constraint matrix
    t = t(2:end) - t(1:end-1); % transform time into time interval
    T = zeros(maskVoxNum*(sessionNum-1), numEigs*sessionNum);
    A = zeros(parcelNum * (sessionNum - 1), numEigs * sessionNum);
    for i = 1:sessionNum - 2
        T(maskVoxNum*(i-1)+1: maskVoxNum*i, numEigs*(i-1)+1:numEigs*(i+2)) = ...
            [-t(i+1)*X{i}',(t(i)+t(i+1))*X{i+1}',-t(i)*X{i+2}'];
        A(parcelNum*(i-1)+1: parcelNum*i,   numEigs*(i-1)+1:numEigs*(i+2)) = ...
            S*[-t(i+1)*X{i}',(t(i)+t(i+1))*X{i+1}',-t(i)*X{i+2}'];
    end    

    %% Initialize Breagman Iteration
    for i = 1:sessionNum    
        bi{i} = zeros(numEigs,ICNum); 
        wi{i} = w_init{i};
        [u,s,v] = svd(wi{i}+bi{i});	
        pi{i} = u * eye(numEigs,ICNum) * v'; 
    end
    bp = zeros(parcelNum * (sessionNum - 1),ICNum);
    
	for i = 1:sessionNum
        XX{i} = X{i}*X{i}';
	end
    
    AA = A'*A;
    
	v = randn(maskVoxNum,1); 
    v = (v - mean(v))/std(v);
    v = repmat(v,1,ICNum);
	exv = exp(-v.^2/2);
    
    %% Breagman Iteration
	iter = 1;
    alpha = k/maskVoxNum;    
    
    if nullSpaceConstruction == 2

        while iter < iterMax
            options = struct('GradObj','on','Display','off','LargeScale','on','HessUpdate','lbfgs','InitialHessType','identity','MaxIter',200);
        
            p = []; b = []; w = [];
            for i = 1:sessionNum
                p = [p;pi{i}];
                b = [b;bi{i}];
                w = [w;wi{i}];
            end
            Abp = A'*bp;
        
            fun = @(w)primalProblemUncMultiGeneral(w,X,XX,A,bp,AA,Abp,p,b,ref,exv,alpha,ro1,ro2,maskVoxNum,sessionNum,numEigs);
            %fun = @(nw)primalProblemUncMultiNull(nw,X1,X2,X3,XX1,XX2,XX3,B,p,b,ref1,ref2,ref3,exv,alpha,ro,numSamples,numEigs);
            w = fminlbfgs(fun,p,options);
        
            fprintf('Iteration %d , orthonogal contraint error: ', iter);
            for i = 1:sessionNum
                wi{i} = w(numEigs*(i-1)+1:numEigs*i,:);
                [u,s,v] = svd(wi{i}+bi{i});	
                pi{i} = u * eye(numEigs,ICNum) * v'; 
                bi{i} = bi{i} + wi{i} - pi{i};
                ci{i} = wi{i}' * wi{i} - eye(ICNum); 
                fprintf('%f ', sum(sum(abs(ci{i}))));
            end
            bp = bp + A*w;
                
            cl = sum(sum(abs(A*w)))/parcelNum;
            fprintf('; longitudinal constraint error %f\n',cl);

            iter = iter + 1;
        end
    end
    
    if (orthogonalConstraint == 1)
        results = pi;
    else 
        results = wi;
    end

end