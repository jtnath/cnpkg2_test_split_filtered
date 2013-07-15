function [output]=cnpkg2_split_process(gpu_id, m, testing_set, split_size)

if ischar(m),
  load(m,'m');
	if ~isequal(m.package,'cnpkg2'),
		warning(['Model trained using ' m.package '. Attempting to test with cnpkg3.'])
		m.package = 'cnpkg2';
	end
end

if ~exist('split_size','var') || isempty(split_size),
	split_size = [150 150 150];
end

% load data
if ~exist('testing_set','var') || isempty(testing_set),
	fprintf(['Loading test data from ' m.data_info.testing_file '... ']);
	testing_set = load(m.data_info.testing_file,'input');
	fprintf([num2str(length(testing_set.input)) ' images found.\n']);
elseif ischar(testing_set),
	fprintf(['Loading test data from ' testing_set '... ']);
    %testing_set_orig = testing_set;
	testing_set = load(testing_set,'input','mask');
    %maskmatrix = load(testing_set,'mask');
	fprintf([num2str(length(testing_set.input)) ' images found.\n']);
elseif isnumeric(testing_set),
	im = testing_set; clear testing_set
	testing_set.input{1} = im; clear im
	fprintf(['Testing 1 image passed as input argument.\n']);
elseif iscell(testing_set),
	im = testing_set; clear testing_set
	testing_set.input = im; clear im
	fprintf(['Testing ' num2str(length(testing_set.input)) ' image(s) passed as input argument.\n']);
else
	error('unknown input. 2nd argument should be the test set. can be either 1) a file with a cell array called input, 2) a cell array of images or 3) a single image')
end
disp('Loaded data file.')
nInput = length(testing_set.input);
disp('Beginning testing...');
% load mask
%if ~exist()

% construct cns model for gpu
m = cnpkg2_mapdim_layers_fwd(m,split_size,1);
% initialize gpu
fprintf(['Initializing device...']),tic
% initialize gpu
if (gpu_id == 1)
    cns('init',m, 'gpu1', 'mean');
else
    cns('init',m, 'gpu0', 'mean');
end
fprintf(' done. ');toc

% go through each image in the input set
for k = 1:nInput,

	imSz = [size(testing_set.input{k},2) size(testing_set.input{k},3) size(testing_set.input{k},4)];	
	bb = [1 size(testing_set.input{k},2); 1 size(testing_set.input{k},3); 1 size(testing_set.input{k},4)];
	output{k} = zeros([m.params.output_units imSz],'single');
	% generate split points
	block_bb = generate_splitpoints(bb, split_size, m.offset);
	if m.params.input_units>1,
		block_bb(4,1,:) = 1;
		block_bb(4,2,:) = m.params.input_units;
	end
	nBlock = size(block_bb,3);
  mask = testing_set.mask{1};
  
  % go through each split box for this image
	for j=1:size(block_bb,3),
        mask1 = mask(:,block_bb(1,1,j):block_bb(1,2,j), block_bb(2,1,j):block_bb(2,2,j));
        mask2 = sum (mask1(:));
        fprintf(['Processing block ' num2str(j) '/' num2str(nBlock) '...']);	
        if sum(mask2 > 0)
            % run the gpu
            
            cns('set',{m.layer_map.input,'val',testing_set.input{k}(:,block_bb(1,1,j):block_bb(1,2,j), block_bb(2,1,j):block_bb(2,2,j), block_bb(3,1,j):block_bb(3,2,j))});
            output{k}(:, ...
                double(block_bb(1,1,j))-1+m.offset(1)+(1:m.layers{m.layer_map.output}.size{2}), ...
                double(block_bb(2,1,j))-1+m.offset(2)+(1:m.layers{m.layer_map.output}.size{3}), ...
                double(block_bb(3,1,j))-1+m.offset(3)+(1:m.layers{m.layer_map.output}.size{4})) ...
                    = cns('step',m.step_map.fwd(1)+1,m.step_map.fwd(end),{m.layer_map.output,'val'});
            fprintf(' done.\n ');
        else
            fprintf(' skipped.\n ');
        end
		
	end

end

cns done

return
