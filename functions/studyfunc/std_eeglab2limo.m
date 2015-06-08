% std_eeglab2limo() Export and run in LIMO the EEGLAB STUDY design
%
% Usage:
%          Analysis = 'datspec'; design_index = 1; ;
%          LIMO_files = std_eeglab2limo(STUDY,ALLEEG,Analysis,design_index) 
%
% Inputs:
%      STUDY        - studyset structure containing some or all files in ALLEEG
%      ALLEEG       - vector of loaded EEG datasets
%      design_indx  - Index of the design in he STUDY structure
%      Analysis     - 'daterp', 'icaerp', 'datspec', 'icaspec', 'datersp', 'icaersp'
%
% Optional inputs:
%
% Outputs:
%             call limo_batch to create all 1st level LIMO_EEG analysis + RFX
%             LIMO_files a structure with the following fields
%             LIMO_files.LIMO the LIMO folder name where the study is analyzed
%             LIMO_files.mat a list of 1st level LIMO.mat (with path)
%             LIMO_files.Beta a list of 1st level Betas.mat (with path)
%             LIMO_files.con a list of 1st level con.mat (with path)
%
% See also:
%
% Author: Cyril Pernet (LIMO Team), The university of Edinburgh, 2014
%         Ramon Martinez-Cancino, SCCN, 2014
%
% Copyright (C) 2015  Ramon Martinez-Cancino,INC, SCCN
%
% This program is free software; you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation; either version 2 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program; if not, write to the Free Software
% Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

function LIMO_files = std_eeglab2limo(STUDY,ALLEEG,varargin)

if nargin < 2
    help std_eeglab2limo;
    return;
end;

if isstr(varargin{1}) && ( strcmpi(varargin{1}, 'daterp') || strcmpi(varargin{1}, 'datspec'))
    opt.measure  = varargin{1};
    opt.design   = varargin{2};
    opt.erase    = 'on';
    opt.method   = 'OSL';
else
    opt = finputcheck( varargin, ...
        { 'measure'        'string'  { 'daterp' 'datspec' } 'daterp'; ...
        'method'         'string'  { 'OLS' 'WLS'        } 'OLS';
        'design'         'integer' [] STUDY.currentdesign;
        'erase'          'string'  { 'on','off' }   'off' }, ...
        'std_eeglab2limo');
    if isstr(opt), error(opt); end;
end;
Analysis     = opt.measure;
design_index = opt.design;

% 1st level analysis
% ------------------
model.cat_files = [];
model.cont_files = [];
if isempty(STUDY.design(design_index).filepath)
    STUDY.design(design_index).filepath = STUDY.filepath;
end
unique_subjects = unique({STUDY.datasetinfo.subject});
nb_subjects   = length(unique_subjects);

for s = 1:nb_subjects
    nb_sets(s) = numel(find(strcmp(unique_subjects{s},{STUDY.datasetinfo.subject})));
end

% Checking that all subjects use the same sets (should not happen)
% --------------------------------------------
%if length(unique(nb_sets)) ~= 1
%    error('different numbers of datasets (.set) used across subjects - cannot go further')
%else
%    nb_sets = unique(nb_sets);
%end

% simply reshape to read columns
% ------------------------------
for s = 1:nb_subjects
    order{s} = find(strcmp(unique_subjects{s},{STUDY.datasetinfo.subject}));
end

% Detecting type of analysis
% --------------------------
if strncmp(Analysis,'dat',3)
    model.defaults.type = 'Channels';
elseif strncmp(Analysis,'ica',3)
    [STUDY,flags]=std_checkdatasession(STUDY,ALLEEG);
    if sum(flags)>0
        error('some subjects have data from different sessions - can''t do ICA');
    end
    model.defaults.type = 'Components';
    model.defaults.icaclustering = 1;
end

% Check if the measures has been computed
% ---------------------------------------
for nsubj = 1 : length(unique_subjects)
    inds     = find(strcmp(unique_subjects{nsubj},{STUDY.datasetinfo.subject}));
    subjpath = fullfile(STUDY.datasetinfo(inds(1)).filepath, [unique_subjects{nsubj} '.' lower(Analysis)]);  
    if exist(subjpath,'file') ~= 2
        error('std_eeglab2limo: Measures must be computed first');
    end
end
 
measureflags = struct('daterp','off',...
                     'datspec','off',...
                     'datersp','off',...
                     'datitc' ,'off',...
                     'icaerp' ,'off',...
                     'icaspec','off',...
                     'icaersp','off',...
                     'icaitc','off');
                 
measureflags.(lower(Analysis))= 'on';
STUDY.etc.measureflags = measureflags;

% Checking if continuous variables
% --------------------------------
if isfield(STUDY.design(design_index).variable,'vartype')
    if any(strcmp(unique({STUDY.design(design_index).variable.vartype}),'continuous'))
        cont_var_flag = 1;
    else
        cont_var_flag = 0;
    end
else
    error('std_eeglab2limo: Define a valid design');
end

for s = 1:nb_subjects     
    % model.set_files: a cell array of EEG.set (full path) for the different subjects
    if nb_sets == 1
        index = STUDY.datasetinfo(order{s}).index;
        names{s} = STUDY.datasetinfo(order{s}).subject;
        
        % Creating fields for limo
        % ------------------------
        ALLEEG(index) = std_lm_seteegfields(STUDY,order{s},'datatype',model.defaults.type,'format', 'cell');
        
        model.set_files{s} = fullfile(ALLEEG(index).filepath,ALLEEG(index).filename);
        
    else
        index = [STUDY.datasetinfo(order{s}).index];
        tmp   = {STUDY.datasetinfo(order{s}).subject};
        if length(unique(tmp)) ~= 1
            error('it seems that sets of different subjects are merged')
        else
            names{s} =  cell2mat(unique(tmp));
        end
        
        % Creating fields for limo
        % ------------------------
        for sets = 1:length(index)
            EEGTMP = std_lm_seteegfields(STUDY,index(sets),'datatype',model.defaults.type,'format', 'cell');
            ALLEEG = eeg_store(ALLEEG, EEGTMP, index(sets));
        end
 
        model.set_files{s} = [ALLEEG(index(1)).filepath filesep 'merged_datasets_design' num2str(design_index) '.set'];
        
        OUTEEG = pop_mergeset(ALLEEG,index,1);
        OUTEEG.filename = ['merged_datasets_design' num2str(design_index) '.set'];
        OUTEEG.datfile = [];
        
        % update EEG.etc
        OUTEEG.etc.merged{1} = ALLEEG(index(1)).filename;
        
        % Def fields
        OUTEEG.etc.datafiles.daterp   = [];
        OUTEEG.etc.datafiles.datspec  = [];
        OUTEEG.etc.datafiles.dattimef = [];
        OUTEEG.etc.datafiles.datitc   = [];
        OUTEEG.etc.datafiles.icaerp   = [];
        OUTEEG.etc.datafiles.icaspec  = [];
        OUTEEG.etc.datafiles.icatimef = [];
        OUTEEG.etc.datafiles.icaitc   = [];
        
        % Filling fields
        if isfield(ALLEEG(index(1)).etc.datafiles,'daterp')
            OUTEEG.etc.datafiles.daterp{1} = ALLEEG(index(1)).etc.datafiles.daterp;
        end
        if isfield(ALLEEG(index(1)).etc.datafiles,'datspec')
            OUTEEG.etc.datafiles.datspec{1} = ALLEEG(index(1)).etc.datafiles.datspec;
        end
        if isfield(ALLEEG(index(1)).etc.datafiles,'dattimef')
            OUTEEG.etc.datafiles.datersp{1} = ALLEEG(index(1)).etc.datafiles.dattimef;
        end
        if isfield(ALLEEG(index(1)).etc.datafiles,'datitc')
            OUTEEG.etc.datafiles.datitc{1} = ALLEEG(index(1)).etc.datafiles.datitc;
        end
        if isfield(ALLEEG(index(1)).etc.datafiles,'icaerp')
            OUTEEG.etc.datafiles.icaerp{1} = ALLEEG(index(1)).etc.datafiles.icaerp;
        end
        if isfield(ALLEEG(index(1)).etc.datafiles,'icaspec')
            OUTEEG.etc.datafiles.icaspec{1} = ALLEEG(index(1)).etc.datafiles.icaspec;
        end
        if isfield(ALLEEG(index(1)).etc.datafiles,'icatimef')
            OUTEEG.etc.datafiles.icaersp{1} = ALLEEG(index(1)).etc.datafiles.icatimef;
        end
        if isfield(ALLEEG(index(1)).etc.datafiles,'icaitc')
            OUTEEG.etc.datafiles.icaitc{1} = ALLEEG(index(1)).etc.datafiles.icaitc;
        end
        
        % Save info
        pop_saveset(OUTEEG, 'filename', OUTEEG.filename, 'filepath',OUTEEG.filepath,'savemode' ,'twofiles');
        clear OUTEEG
    end
    
    % model.cat_files: a cell array of categorial variable
    if nb_sets == 1;
        [catvar_matrix,tmp] = std_lm_getvars(STUDY,STUDY.datasetinfo(order{s}(1)).subject,'design',design_index,'vartype','cat'); clear tmp; %#ok<ASGLU>
    else
        [catvar_matrix,tmp] = std_lm_getvars(STUDY,STUDY.datasetinfo(order{s}(1)).subject,'design',design_index,'vartype','cat');clear tmp; %#ok<ASGLU>
    end
    
    if ~isempty(catvar_matrix)
        if isvector(catvar_matrix) % only one factor of n conditions
            categ = catvar_matrix;
            model.cat_files{s} = catvar_matrix;
        elseif 1
            
            trialinfo = std_combtrialinfo(STUDY.datasetinfo, order{s});
            categ = std_builddesignmat(STUDY.design(design_index), trialinfo);
            model.cat_files{s} = catvar_matrix;
            
        else % multiple factors (=multiple columns)
            X = []; nb_row = size(catvar_matrix,1);
            for cond = 1:size(catvar_matrix,2)
                nb_col(cond) = max(unique(catvar_matrix(:,cond)));
                x = NaN(nb_row,nb_col(cond));
                for c=1:nb_col(cond)
                    x(:,c) = [catvar_matrix(:,cond) == c];
                end
                X = [X x];
            end
            
            tmpX = limo_make_interactions(X, nb_col);
            tmpX = tmpX(:,sum(nb_col)+1:end);
            getnan = find(isnan(catvar_matrix(:,1)));
            if ~isempty(getnan)
                tmpX(getnan,:) = NaN;
            end
            categ = sum(repmat([1:size(tmpX,2)],nb_row,1).*tmpX,2);
            clear x X tmpX; model.cat_files{s} = categ;
        end      
        save(fullfile(ALLEEG(index(1)).filepath, 'categorical_variable.txt'),'categ','-ascii')
    end
    
    % model.cont_files: a cell array of continuous variable files
    if cont_var_flag
        if nb_sets == 1;
            [contvar,tmp] = std_lm_getvars(STUDY,STUDY.datasetinfo(order{s}).subject,'design',design_index,'vartype','cont'); clear tmp; %#ok<ASGLU>
        else
            [contvar_matrix,contvar_info] = std_lm_getvars(STUDY,STUDY.datasetinfo(order(1,s)).subject,'design',design_index,'vartype','cont');
            
            % we need to know the nb of trials in each of the sets
            set_positions = [0];
            getnan = find(isnan(contvar_matrix(:,1)));
            for dataset = 1:nb_sets
                cond_size = cellfun(@length,contvar_info.datasetinfo_trialindx(contvar_info.dataset == index(dataset)));
                set_size = sum(cond_size);
                set_positions(dataset+1) = set_size + sum(getnan<set_size);
                % update getnan as the next loop restart at one
                getnan((getnan - set_size)<0) = [];
            end
            set_positions = cumsum(set_positions);
            
            % create contvar updating with set_positions
            contvar = NaN(size(contvar_matrix));
            for cond = 1:size(contvar_info.datasetinfo_trialindx,2)
                which_dataset = contvar_info.dataset(cond);                    % dataset nb
                dataset_nb = find(which_dataset == order(:,s));                % position in the concatenated data
                position = cell2mat(contvar_info.datasetinfo_trialindx(cond)); % position in the set
                values = contvar_matrix(position+set_positions(dataset_nb));   % covariable values
                contvar(position+set_positions(dataset_nb)) = values;          % position in the set + position in the concatenated data
            end
        end
        
        % --> split per condition and zscore
        if exist('categ','var')
            model.cont_files{s} = limo_split_continuous(categ,contvar);
        end
        
        if size(contvar,2) > 1
            save([ALLEEG(index(1)).filepath filesep 'continuous_variables.txt'],'categ','-ascii')
        else
            save([ALLEEG(index(1)).filepath filesep 'continuous_variable.txt'],'categ','-ascii')
        end
    end
end

model.set_files = model.set_files';
model.cat_files = model.cat_files';
if cont_var_flag
    model.cont_files = model.cont_files';
end

% set model.defaults - all conditions no bootstrap
% -----------------------------------------------------------------
% to update passing the timing/frequency from STUDY - when computing measures
% -----------------------------------------------------------------
if strcmp(Analysis,'daterp') || strcmp(Analysis,'icaerp')
    model.defaults.analysis= 'Time';
    model.defaults.start = -10; % ALLEEG(index).xmin*1000;
    model.defaults.end = ALLEEG(index(1)).xmax*1000;
    model.defaults.lowf = [];
    model.defaults.highf = [];
    
elseif strcmp(Analysis,'datspec') || strcmp(Analysis,'icaspec')
    
    model.defaults.analysis= 'Frequency';
    model.defaults.start = -10;
    model.defaults.end = ALLEEG(index(1)).xmax*1000;
    model.defaults.lowf = [];
    model.defaults.highf = [];
    
elseif strcmp(Analysis,'datersp') || strcmp(Analysis,'icaersp')
    model.defaults.analysis= 'Time-Frequency';
    model.defaults.start = [];
    model.defaults.end = [];
    model.defaults.lowf = [];
    model.defaults.highf = [];
end

model.defaults.fullfactorial = 0;                    % factorial only for single subject analyses - not included for studies
model.defaults.zscore = 0;                           % done that already
model.defaults.bootstrap = 0 ;                       % only for single subject analyses - not included for studies
model.defaults.tfce = 0;                             % only for single subject analyses - not included for studies
model.defaults.method = opt.method;                  % default is OLS - to be updated to 'WLS' once validated
model.defaults.Level= 1;                             % 1st level analysis
model.defaults.type_of_analysis = 'Mass-univariate'; % future version will allow other techniques

STUDY.design_info = STUDY.design(design_index).variable;
STUDY.design_index = design_index;
STUDY.names = names;

% contrast
if cont_var_flag && exist('categ','var')
    limocontrast.mat = [zeros(1,max(categ)) ones(1,max(categ)) 0];
    LIMO_files = limo_batch('both',model,limocontrast,STUDY);
else
    limocontrast.mat = [];
    LIMO_files = limo_batch('model specification',model,limocontrast,STUDY);
end
rmfield(STUDY,'design_index');
rmfield(STUDY,'design_info');
rmfield(STUDY,'names');

% Cleaning

