function counts = cond_emp_to_counts(cond_emp,arity)
% Takes a list of data points over two variables and counts how many
% instantiations are in each category.  Hence converts from a (2 x
% num_samples) array to an (arity x arity) array.

counts = zeros(arity);

    % count 
    for i = 1:arity
        for j = 1:arity
            counts(i,j) = length(find(~sum(cond_emp(1:2,:)~=repmat([i j]',1,size(cond_emp,2)),1)));
        end
    end 

