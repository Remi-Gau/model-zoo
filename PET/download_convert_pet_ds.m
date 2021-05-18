function download_convert_pet_ds()
    %
    % downloads the PET dataset from SPM and convert it to BIDS
    %
    % Adapted from its counterpart for MoAE
    % <https://www.fil.ion.ucl.ac.uk/spm/download/data/MoAEpilot/MoAE_convert2bids.m>
    %
    % (C) Copyright 2020 Rémi Gau

    subject = 'sub-01';
    task_name = 'finger opposition';

    opt.indent = '  ';

    % URL of the data set to download
    URL = 'https://www.fil.ion.ucl.ac.uk/spm/download/data/motor/PET_motor.tar.gz';

    working_directory = fileparts(mfilename('fullpath'));
    input_dir = fullfile(working_directory, 'pet_motor', 'inputs', 'source');
    output_dir = fullfile(working_directory, 'pet_motor', 'outputs', 'derivatives');

    % clean previous runs
    try
        rmdir(input_dir, 's');
        rmdir(output_dir, 's');
    catch
    end
    spm_mkdir(input_dir);
    spm_mkdir(output_dir);

    %% Get data
    output_file = fullfile(working_directory, 'finger_opposition_pet_ds.tar.gz');
    fprintf('%-10s:', 'Downloading dataset...');
    urlwrite(URL, output_file);
    fprintf(1, ' Done\n\n');

    fprintf('%-10s:', 'Unzipping dataset...');
    gunzip(output_file, working_directory);
    movefile(fullfile(working_directory, 'PET_motor', 's8*.*'), input_dir);
    movefile(fullfile(working_directory, 'PET_motor', 'README'), input_dir);
    fprintf(1, ' Done\n\n');

    %% PET
    spm_mkdir(output_dir, subject, 'pet');
    
    repetition_time = 0;

    pet_files = spm_select('FPList', input_dir, '^s8np.*\.img$');
    spm_file_merge( ...
                   pet_files, ...
                   fullfile(output_dir, subject, 'pet', ...
                            ['sub-01_task-' strrep(task_name, ' ', '') '_desc-preproc_pet.nii']), ...
                   0, ...
                   repetition_time);
    delete(fullfile(output_dir, subject, 'pet', '*.mat'));

    %% And everything else
    % create_events_tsv_file(input_dir, output_dir, task_name, repetition_time);
    % create_readme(output_dir);
    create_changelog(output_dir);
    create_datasetdescription(output_dir, opt);
    % create_bold_json(output_dir, task_name, repetition_time, nb_slices, echo_time, opt);

end

function create_events_tsv_file(input_dir, output_dir, task_name, repetition_time)

    % TODO
    % add the lag between presentations of each item necessary for the parametric
    % analysis.

    load(fullfile(input_dir, 'all_conditions.mat'), ...
         'names', 'onsets', 'durations');

    onset_column = [];
    duration_column = [];
    trial_type_column = [];

    for iCondition = 1:numel(names)
        onset_column = [onset_column; onsets{iCondition}]; %#ok<*USENS>
        duration_column = [duration_column; durations{iCondition}']; %#ok<*AGROW>
        trial_type_column = [trial_type_column; repmat( ...
                                                       names{iCondition}, ...
                                                       size(onsets{iCondition}, 1), 1)];
    end

    % sort trials by their presentation time
    [onset_column, idx] = sort(onset_column);
    duration_column = duration_column(idx);
    trial_type_column = trial_type_column(idx, :);

    onset_column = repetition_time * onset_column;

    tsv_content = struct( ...
                         'onset', onset_column, ...
                         'duration', duration_column, ...
                         'trial_type', {cellstr(trial_type_column)});

    spm_save(fullfile(output_dir, 'sub-01', 'func', ...
                      ['sub-01_task-' strrep(task_name, ' ', '') '_events.tsv']), ...
             tsv_content);

end

function create_readme(output_dir)

    rdm = {
           ' ___  ____  __  __'
           '/ __)(  _ \(  \/  )  Statistical Parametric Mapping'
           '\__ \ )___/ )    (   Wellcome Centre for Human Neuroimaging'
           '(___/(__)  (_/\/\_)  https://www.fil.ion.ucl.ac.uk/spm/'
           ''
           '               PET single subject example dataset'
           '________________________________________________________________________'
           ''
           'Experimental design:'
           ''
           'Summary:'
           ''
           ''
           ''
           'Subject used left hand to perform finger opposition task:'
           'touch thumb to index finger, to middle finger, to ring finger, to pinky, then repeat.'
           'Subject performed this this at a rate of 2 Hz, as guided by a visual cue.'
           'For baseline, there was no finger movement, but the visual cue was still present.'
           'Odd scans are activation, even scans are baseline.'};

    % TODO
    % use spm_save to actually write this file?
    fid = fopen(fullfile(output_dir, 'README'), 'wt');
    for i = 1:numel(rdm)
        fprintf(fid, '%s\n', rdm{i});
    end
    fclose(fid);

end

function create_changelog(output_dir)

    cg = { ...
          '1.1.0 2021-05-16', ' - BIDS version.', ...
          '1.0.0 1996-01-01', ' - Initial release.'};
    fid = fopen(fullfile(output_dir, 'CHANGES'), 'wt');

    for i = 1:numel(cg)
        fprintf(fid, '%s\n', cg{i});
    end
    fclose(fid);

end

function create_datasetdescription(output_dir, opt)

    descr = struct( ...
                   'BIDSVersion', '1.6.0', ...
                   'Name', 'SPM single subject motor task PET demo dataset', ...
                   'Authors', {{'Paul Kinahan', 'Doug Noll'}}, ...
                   'DatasetType', 'derivative', ...
                   'GeneratedBy', {{'Name', 'spm'}}, ...
                   'ReferencesAndLinks', ...
                   {{'https://www.fil.ion.ucl.ac.uk/spm/data/motor/', ...
                     ['D, Kinahan et al.; (1996)', ...
                      'Comparison of activation response using functional PET and MRI, NeuroImage 3(3):S34.']}} ...
                  );

    spm_save(fullfile(output_dir, 'dataset_description.json'), ...
             descr, ...
             opt);

end

function create_bold_json(output_dir, task_name, repetition_time, nb_slices, echo_time, opt)

    acquisition_time = repetition_time - repetition_time / nb_slices;
    slice_timing = linspace(acquisition_time, 0, nb_slices);

    task = struct( ...
                  'RepetitionTime', repetition_time, ...
                  'EchoTime', echo_time, ...
                  'SliceTiming', slice_timing, ...
                  'NumberOfVolumesDiscardedByScanner', 0, ...
                  'NumberOfVolumesDiscardedByUser', 0, ...
                  'TaskName', task_name, ...
                  'TaskDescription', ...
                  ['2 presentations of 26 Famous and 26 Nonfamous Greyscale photographs, ', ...
                   'for 0.5s, randomly intermixed, for fame judgment task ', ...
                   '(one of two right finger key presses).'], ...
                  'Manufacturer', 'Siemens', ...
                  'ManufacturersModelName', 'MAGNETOM Vision', ...
                  'MagneticFieldStrength', 2);

    spm_save(fullfile(output_dir, ...
                      ['task-' strrep(task_name, ' ', '') '_bold.json']), ...
             task, ...
             opt);

end
