
% XXXX  TODO ????
% 1. Subtract mean from samples, as preprocessing step.
% 2. Check if glueing would recover results of mutual information
% 5. Cache kernel matrices / inspect which part is slow. 
% 6. Increase sample size.
% 7. Check what happens when I combine gaussian kernel with linear (provide
% func to add kernels).
% 8. Get ci and kci linear to give the same results.
% 9. Explore manually which kernels work well. It's enough to have a paper
% on a good kernel.

clear all;
global debug
debug = 0;
close all;
bnet = mk_asia_large_arity(5);
K = length(bnet.dag);
arity = get_arity(bnet);

max_S = 2;
triples = gen_triples(K, max_S);

num_experiments = 30;
num_samples = 300;

%range = 0:1e-2:1;
range = [0:1e-3:2e-2 3e-2:1e-2:1];  
short_range = [1, 2, 3];
options = {struct('classifier', @kci_classifier, 'kernel', @linear_kernel, 'range', range, 'color', 'g' ), ...
           struct('classifier', @kci_classifier, 'kernel', @gauss_kernel, 'range', range, 'color', 'b' )};%, ...
       %    struct('classifier', @ci_classifier, 'kernel', @empty, 'range', range, 'color', 'r' )};%, ...
       %    struct('classifier', @mi_classifier, 'kernel', @empty, 'range', 0:1e-3:log2(arity), 'color', 'y' )};
       %, ... struct('classifier', @sb_classifier, 'kernel', @empty,
       %'range',  short_range, 'color', 'k')};
num_classifiers = length(options);
name = cell(num_classifiers);
TPR = cell(num_classifiers);
FPR = cell(num_classifiers);
w_acc = cell(num_classifiers);

% label each CPD as either independent (1) or dependent (0)
indep = zeros(length(triples), 1);
fprintf('Computing ground truth indep.\n');
for t = 1 : length(triples)
    indep(t) = double(dsep(triples{t}(1), triples{t}(2), triples{t}(3:end), bnet.dag));
end
num_indep = length(find(indep));
fprintf('Testing %d independent and %d dependent CPDs, arity=%d.\n',num_indep,length(indep)-num_indep,arity);

% allocate
for c = 1:num_classifiers
    o = options{c};
    name{c} = sprintf('%s, kernel = %s', func2str(o.classifier), func2str(o.kernel));
    name{c} = strrep(name{c}, '_', ' ');
    num_thresholds = length(o.range);
    
    w_acc{c} = zeros(1,num_experiments);
    TPR{c} = zeros(num_experiments,num_thresholds);
    FPR{c} = zeros(num_experiments,num_thresholds);
end


for exp = 1:num_experiments
    
    fprintf('Experiment #%d, sampling from bayes net.\n',exp);
    s = samples(bnet, num_samples);
    for c = 1:num_classifiers
        o = options{c};

        opt = struct('arity', arity, 'kernel', o.kernel,'range', o.range);
        
        % allocate
        classes = zeros(size(o.range));
        num_thresholds = length(o.range);
        scores = zeros(2,2,num_thresholds);
        
        % apply classifier
        for t = 1 : length(triples)
            emp = s(triples{t}, :);
            
            % evaluate classifier at all thresholds in range
            indep_emp = o.classifier(emp, opt);
            
            % increment scores accordingly
            for i = 1:length(indep_emp)
                scores(1 + indep(t),indep_emp(i)+1,i) = scores(1 + indep(t),indep_emp(i)+1,i) + 1;
            end
        end
        
        % evaluate
        for r = 1 : num_thresholds
            P = scores(2, 1, r) + scores(2, 2, r);
            N = scores(1, 1, r) + scores(1, 2, r);
            TP = scores(2, 2, r);
            TN = scores(1, 1, r);
            %       FN = scores(2, 1, r);
            FP = scores(1, 2, r);
            TPR{c}(exp,r) = TP/P; % = TP / (TP + FN)
            FPR{c}(exp,r) =  FP/N; % = FP / (FP + TN);
            w_acc{c}(exp) = max(w_acc{c}(exp),(TP / P + TN / N) / 2);
        end
        
        % Assumes that we picked the best threshold.
        %     for i = 1:num_thresholds
        %         r = o.range(i);
        %         acc = (sum((rho{c} < r) .* indep) / sum(indep) + sum((rho{c} >= r) .* (1 - indep)) / sum(1 - indep)) / 2;
        %         w_acc(c) = max(w_acc(c), acc);
        %     end
        fprintf('   Finished classifier %s, w_acc=%d.\n',name{c},w_acc{c}(exp));
    end

end

figure
hold on

for c = 1:num_classifiers
    o = options{c};
    tpr = mean(TPR{c});
    tpr_err = std(TPR{c});
    fpr = mean(FPR{c});
    fpr_err = std(FPR{c});
    %plot(fpr,tpr,o.color); %,'linewidth',2);
    errorbarxy(fpr,tpr,fpr_err,tpr_err,{o.color,o.color,o.color});
    hold on
    fprintf('Classifier %s, mean best w_acc = %f\n',name{c},mean(w_acc{c}));
end

legend(name);
xlabel('FPR');
ylabel('TPR');
title(sprintf('ROC on CPDs generated from linear asia network, arity=%d, N=%d',arity,num_samples),'fontsize',14);
