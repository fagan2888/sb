% XXXX  TODO ????
% 1. Subtract mean from samples, as preprocessing step.
% 5. Cache kernel matrices / inspect which part is slow. 
% 6. Increase sample size.
% 7. Check what happens when I combine gaussian kernel with linear (provide
% func to add kernels).
% 8. Get ci and kci linear to give the same results.
% 9. Explore manualy which kernels work well. It's enought to have a paper
% on a good kernel.


% clear all;
global debug
debug = 0;
close all;
bnet = mk_asia_large_arity(5);
K = length(bnet.dag);
arity = get_arity(bnet);

max_S = 2;
triples = gen_triples(K, max_S);

N = 200;
s = samples(bnet, N);

classifiers = {@kci_classifier, @kci_classifier, @ci_classifier, @mi_classifier};
kernels = {@linear_kernel, @gauss_kernel, @empty, @empty};
colors = {'g', 'r', 'b', 'y'};
rho = {};
name = {};
w_acc = zeros(length(classifiers), 1);

indep = zeros(length(triples), 1);
fprintf('Computing ground truth indep.\n');
for t = 1 : length(triples)
    indep(t) = double(dsep(triples{t}(1), triples{t}(2), triples{t}(3:end), bnet.dag));
end

for c = 1:length(classifiers)
    name{c} = sprintf('func = %s, kernel = %s', func2str(classifiers{c}), func2str(kernels{c}));    
    name{c} = strrep(name{c}, '_', ' ');        
    rho{c} = zeros(length(triples), 1);
    options = struct('arity', arity, 'kernel', kernels{c});            
    for t = 1 : length(triples)
        emp = s(triples{t}, :);
        rho{c}(t) = classifiers{c}(emp, options);
    end
    
    % Assumes that we picked the best threshold.    
    for r = 1e-5:1e-5:1
        acc = (sum((rho{c} < r) .* indep) / sum(indep) + sum((rho{c} >= r) .* (1 - indep)) / sum(1 - indep)) / 2;
        w_acc(c) = max(w_acc(c), acc);
    end    
    fprintf('Evaluated classifier %s, acc = %f\n', name{c}, w_acc(c));    
end
