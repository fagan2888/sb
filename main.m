
% XXXX  TODO ????
% 2. Check if glueing would recover results of mutual information
% 4. writes tests for mk_bnet functions
% 5. Cache kernel matrices / inspect which part is slow. 
% 8. Get ci and kci linear to give the same results.
% 9. Explore manually which kernels work well. It's enough to have a paper
% on a good kernel.

clear all;
global debug
debug = 0;
close all;

cpd_type = 'linear'; %%%
discrete = false; %%%
bnet = mk_asia_ggm(0.05); %%%
arity = get_arity(bnet);
if (~discrete)
    disp('not discrete, setting arity separately');
    arity = 10; %%%
end
K = length(bnet.dag);

max_S = 2;
triples = gen_triples(K, max_S);

num_experiments = 3;
num_samples_range = [40 50]; %[50 200 1000];
num_N = length(num_samples_range);
step_size = 1e-3;
range = 0:step_size:1;
%eta_range = log2(1:0.01:1.2);%log2(1:.001:1.1);
%alpha_range = [0 10.^(-3:0.2:3)];%[0 10.^(-3:0.2:3)];

empty = struct('name', 'none');
L = LinearKernel();
G = GaussKernel();
% C1 = CombKernel({L, G}, {-0.1, 1});
LA = LaplaceKernel();
P = PKernel();
Ind = IndKernel();
full_options = {struct('classifier', @kci_classifier, 'kernel', L,'range', range, 'color', 'g' ,'params',[],'normalize',true,'name','KCI, linear kernel'), ...
           struct('classifier', @kci_classifier, 'kernel', G, 'range', range, 'color', 'b','params',[],'normalize',true,'name','KCI, gaussian kernel'), ...
           struct('classifier', @kci_classifier, 'kernel', LA, 'range', range, 'color', 'm' ,'params',[],'normalize',true,'name','KCI, laplace kernel'), ...
           struct('classifier', @kci_classifier, 'kernel', Ind, 'range', range, 'color', 'r' ,'params',[],'normalize',true,'name','KCI, indicator kernel'), ...
           struct('classifier', @kci_classifier, 'kernel', P, 'range', range, 'color', 'k' ,'params',[],'normalize',true,'name','KCI, heavytail kernel'), ...
           struct('classifier', @pc_classifier, 'kernel', empty, 'range', range, 'color', 'm','params',[],'normalize',true,'name','partial correlation'), ...
           struct('classifier', @cc_classifier, 'kernel', empty, 'range', range, 'color', 'c','params',[],'normalize',false,'name','conditional correlation'), ...
           struct('classifier', @mi_classifier, 'kernel', empty, 'range', 0:step_size:log2(arity), 'color', 'y','params',[],'normalize',false,'name','conditional mutual information'), ...
           struct('classifier', @sb_classifier, 'kernel', empty,'range',range, 'color', 'm','params',struct('eta',0.01,'alpha',1.0),'normalize',false,'name','bayesian conditional mutual information')};

%options = full_options([1 2 4:8]);
options = full_options([1 2]);
num_classifiers = length(options);
name = cell(1,num_classifiers);
TPR = cell(num_classifiers, num_N);
FPR = cell(num_classifiers, num_N);

% label each CPD as either independent (1) or dependent (0)
indep = zeros(length(triples), 1);
edge = zeros(length(triples),1);
fprintf('Computing ground truth indep...\n');
tic;
for t = 1 : length(triples)
    i = triples{t}(1);
    j = triples{t}(2);
    indep(t) = double(dsep(i, j, triples{t}(3:end), bnet.dag));
    edge(t) = (bnet.dag(i,j) || bnet.dag(j,i));
end
fprintf('...finished in %d seconds.\n',toc);
% only keep dependent distributions corresponding to an edge (along with
% any conditioning sets)
keep = (indep | edge);
triples = triples(keep);
indep = indep(keep);

num_indep = length(find(indep));
fprintf('Testing %d independent and %d dependent CPDs, arity=%d.\n',num_indep,length(indep)-num_indep,arity);


% allocate
for c = 1:num_classifiers
    o = options{c};
    name{c} = o.name;
    num_thresholds = length(o.range);
    
    param_size{c} = [];
    if (isstruct(o.params))
        fields = fieldnames(o.params);
        for i = 1:length(fields)
            param_size{c} = [param_size{c} length(o.params.(fields{i}))];
        end
    end
    
%     for N_idx = 1:num_N
%         TPR{c,N_idx} = zeros([num_experiments num_thresholds param_size{c}]);
%         FPR{c,N_idx} = zeros([num_experiments num_thresholds param_size{c}]);
%     end
end

total_time = 0;
%time_N = zeros(num_N,1);

for exp = 1:num_experiments
    time_N = zeros(num_N,1);
    time_exp = 0;

    for N_idx = 1:num_N

        
        num_samples = num_samples_range(N_idx);
        fprintf('STARTING N=%d.\n',num_samples);
        
        fprintf('Experiment #%d, N=%d, sampling from bayes net.\n',exp,num_samples);
        s = samples(bnet, num_samples);
        if (~discrete)
            s = discretize(s,arity);
        end
        s_norm = normalize_data(s);
        
        for c = 1:num_classifiers
            tic;
            %fprintf('  Testing %s...\n',name{c});
            o = options{c};
            opt = struct('arity', arity, 'kernel', o.kernel,'range', o.range,'params',o.params,'normalize',o.normalize);
            
            % allocate
            classes = zeros([length(o.range) param_size{c}]);
            num_thresholds = length(o.range);
            scores = zeros([2 2 num_thresholds param_size{c}]);
            
            % apply classifier
            for t = 1 : length(triples)
                if o.normalize
                    emp = s_norm(triples{t}, :);
                else
                    emp = s(triples{t},:);
                end
                
                % evaluate classifier at all thresholds in range
                indep_emp = o.classifier(emp, opt);
                indep_emp = reshape(indep_emp,[1 1 size(indep_emp)]);
                
                % increment scores accordingly (WARNING: HARD-CODED max num
                % params to optimize as 2)
                scores(1 + indep(t),1,:,:,:) = scores(1 + indep(t),1,:,:,:) + ~indep_emp;
                scores(1 + indep(t),2,:,:,:) = scores(1 + indep(t),2,:,:,:) + indep_emp;
            end

            P = scores(2, 1, :, :, :) + scores(2, 2, :, :, :);
            N = scores(1, 1, :, :, :) + scores(1, 2, :, :, :);
            TP = scores(2, 2, :, :, :);
            TN = scores(1, 1, :, :, :);
            FP = scores(1, 2, :, :, :);
            TPR{c, N_idx}(exp, :, :, :) = squeeze(TP ./ P);
            FPR{c, N_idx}(exp, :, :, :) =  squeeze(FP ./ N);

            time_classifier = toc;
            time_N(N_idx) = time_N(N_idx) + time_classifier;
            fprintf('   Finished %s, time = %d seconds.\n',name{c},time_classifier);
        end
  
        fprintf('Time for experiment %d, N=%d is %d\n',exp,num_samples,time_N(N_idx));
    end
    
    clf
    plot_roc_multi
    hold on
    pause(1)
    
    time_exp = time_exp + sum(time_N);
    fprintf('Total time for experiment %d is %d\n',exp,time_exp);
    total_time = total_time + time_exp;
end


fprintf('Total running time for all experiments is %d seconds.\n',total_time);
mat_file_command = sprintf('save asia_linear_ggm_arity_%d.mat',arity);
eval(mat_file_command);
