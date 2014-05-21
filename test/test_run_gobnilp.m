disp('test_run_gobnilp...');


randn('seed',1);
rand('seed',1);
arity = 3;
opt = struct('network', 'Y', 'arity', arity, 'type', 'random', 'moralize', false);
[bnet, opt] = make_bnet(opt);
data = samples(bnet,1000);
S = prune_scores(compute_bic(data, arity, opt.maxpa));
PDAG_pred = dag_to_cpdag(run_gobnilp(S));
PDAG_true = dag_to_cpdag(bnet.dag);
assert( shd(PDAG_pred, PDAG_true) == 0);


