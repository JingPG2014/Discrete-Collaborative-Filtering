function [B,D,X,Y] = DCF(S, ST, IDX, IDXT, r, alpha, beta, option)
%DCF: Dicrete Collaborative Filtering as

%Input:
%S: user-item score matrix, [m,n] = size(S)
%ST: transpose of ST, for efficient sparse matrix indexing in Matlab, i.e.,
%matlab can only efficiently access sparse matrix by column.
%IDX: nonzero (observed) entry index of S
%IDXT: transpose of IDX for efficient sparse matrix indexing in Matlab.
%r: bit length
%alpha: trade-off paramter. good default = 0.001.
%beta: trade-off paramter. good default = 0.001.
%option:
    %option.maxItr: max iterations. Default = 50.
    %option.maxItr2: max iteration for cylic binary loop. Default = 5.
    %option.tol: tolerance. Default = 1e-5.
    %option.debug: show obj?. Default = false.

%Output:
%B: user codes
%D: item codes
%X: surrogate user vector
%Y: surrogate item vector

%Reference:
%   Hanwang Zhang, Fumin Shen, Wei Liu, Xiangnan He, Huanbo Luan, Tat-seng
%   Chua. "Discrete Collaborative Filtering", SIGIR 2016

%Version: 1.0
%Written by Hanwang Zhang (hanwangzhang AT gmail.com)


[m,n] = size(S);
maxS = max(max(S));
minS = min(min(S));
converge = false;
it = 1;

if isfield(option,'maxItr')
    maxItr = option.maxItr;
else
    maxItr = 50;
end
if isfield(option,'maxItr2')
    maxItr2 = option.maxItr2;
else
    maxItr2 = 5;
end
if isfield(option, 'Init')
   Init = option.Init;
else
   Init = True;
end
if Init
   if (isfield(option,'B0') &&  isfield(option,'D0') && isfield(option,'X0') && isfield(option,'Y0'))
       B0 = option.B0; D0 = option.D0; X0 = option.X0; Y0 = option.Y0;
   else
       [U,V,X0,Y0] = DCFinit(S, ST, IDX, IDXT, r, alpha, beta, option);
       B0 = sign(U); B0(B0 == 0) = 1;
       D0 = sign(V); D0(D0 == 0) = 1;
   end
else
    U = rand(r,m);
    V = rand(r,n);
    B0 = sign(U); B0(B0 == 0) = 1;
    D0 = sign(V); D0(D0 == 0) = 1;
    X0 = UpdateSVD(B0);
    Y0 = UpdateSVD(D0); 
end
if isfield(option,'debug')
    debug = option.debug;
else
    debug = false;
end

B = B0;
D = D0;
X = X0;
Y = Y0;
if debug
   [loss,obj] = DCFobj(maxS,minS,S,IDX,B,D,X,Y,alpha,beta);   
   disp(loss);
   disp(obj);
end


while ~converge
    tic;
    B0 = B;
    D0 = D;
    parfor i = 1:m
        %B(:,i) = DCD(D(:,IDX(i,:)),B(:,i),ScaleScore(full(S(i,IDX(i,:))'),r,maxS,minS), alpha*X(:,i),maxItr2);
        %B(:,i) = DCD(D(:,IDX(i,:)),B(:,i),ScaleScore(nonzeros(ST(:,i)),r,maxS,minS), alpha*X(:,i),maxItr2);
        d = D(:,IDXT(:,i));
        b = B(:,i);
        DCDmex(b,d*d',d*ScaleScore(nonzeros(ST(:,i)),r,maxS,minS), alpha*X(:,i),maxItr2);
        B(:,i) = b;
    end
    parfor j = 1:n
        b = B(:,IDX(:,j));
        d = D(:,j);
        DCDmex(d,b*b',b*ScaleScore(nonzeros(S(:,j)),r,maxS,minS), beta*Y(:,j),maxItr2);
        D(:,j)=d;
    end
    X = UpdateSVD(B);
    Y = UpdateSVD(D);
    toc;
    if debug
        [loss,obj] = DCFobj(maxS,minS,S,IDX,B,D,X,Y,alpha,beta);
        disp(obj);
    end
    disp(['DCF at bit ',int2str(r),' Iteration:',int2str(it)]);

    if it >= maxItr || (sum(sum(B~=B0)) == 0 && sum(sum(D~=D0)) == 0)
        converge = true;
    end
    
    it = it+1;
    
end

end

function [loss,obj] = DCFobj(maxS,minS,S,IDX,B,D,X,Y,alpha,beta)
[~,n] = size(S);
r = size(B,1);
loss = zeros(1,n);
parfor j = 1:n
    dj = D(:,j);
    Bj = B(:,IDX(:,j));
    BBj = Bj*Bj';
    term1 = dj'*BBj*dj;
    Sj = ScaleScore(nonzeros(S(:,j)),r,maxS,minS);
    term2 = 2*dj'*Bj*Sj;
    term3 = sum(Sj.^2);
    loss(j) = term1-term2+term3;
end
loss = sum(loss);
obj = loss-2*alpha*trace(B*X')-2*beta*trace(D*Y');
end
