%The description will be here.
%
% KJ Jantzen
%January 2023
function plotter()
    %main function that loads the parameters
    %and builds the UI
    
    p.handles = buildUI;
    addPaths;
    p.tempDataFileName = 'temp_plotter_data.dat';
    p.handles.fig.UserData = p;
   
end
% **************************************************************************
function callback_start(src,~)
% starts the data collection process
    fig = ancestor(src, 'figure', 'toplevel');
    p = fig.UserData;
    
    r = checkForExistingTempDataFile(p);
    if ~r; return; end
    
    toggleEnabledStatus(p.handles, true);
    drawnow
    
    switch p.handles.dropdown_mode.Value
        case 'Continuous'
            cont_start(p);
        case 'Single Trial'
            trial_start(p);
    end
end
% **************************************************************************
function cont_start(p)
%initializes data collection for continuous mode
    try
        if ~isfield(p, "Device") || ~isvalid(p.Device)
            p = initializeDevice(p);
            if ~isfield(p, 'Device') || ~isvalid(p.Device)
                toggleEnabledStatus(p.handles, false);
                return;
            end
        end
        
        p.Device.ProcessObjects = initializeContinuousPlot(p, p.Device.ProcessObjects);
        %put the device into continuous collection mode
        p.Device.SetMode("Continuous");
        p.Device.Start   
        p.handles.fig.UserData = p;
    catch ME
        errMsg(p.handles.fig, ME);
        toggleEnabledStatus(p.handles, false);
    end
end
%**************************************************************************
function trial_start(p)
%initializes data collectino for single trial mode
    try
        p = initializeDevice(p);
        p.Device.ProcessObjects = initializeERPPlot(p, p.Device.ProcessObjects);
        pause(1);

        p.Device.SetMode("SingleTrial");
        p.Device.Start
        p.handles.fig.UserData = p;
    catch ME
        errMsg(p.handles.fig, ME);
        toggleEnabledStatus(p.handles, false);
    end
end
% **************************************************************************
function callback_switchmodes(src, ~)
% callback for the dropdown that selects between continuous and single
% trial modes
    fig = ancestor(src, 'figure', 'toplevel');
    p = fig.UserData;

    switch src.Value
        case 'Continuous'
            p.handles.panel_trial.Visible = 'off';
        case 'Single Trial'
            p.handles.panel_trial.Visible = 'on';
    end
end
% **************************************************************************
%% stop the eeg device
function callback_stop(src, ~)
%stopping will close all open streaming files and delete the device to
%force a reinitialization based on the current settings of the device and
%port dropdowns.
%
    fig = ancestor(src, 'figure', 'toplevel');
    stopRecording(fig)
end
%**************************************************************************
function callback_closeRequest(fig, varargin)
    stopRecording(fig);
    closereq;
end
%**************************************************************************
function stopRecording(fig)
    p = fig.UserData;

    if isfield(p, "Device") && isvalid(p.Device)
        if hasActiveStream(p.Device.ProcessObjects)
            p.Device.ProcessObjects.Stream.Close;
        end
        p.Device.Stop
        pause(.5);
        p.Device.Delete
    end
    p.handles.edit_filename.Value = "";
    p.handles.edit_bytessaved.Value = "";
    p.handles.lamp_saving.Color = 'r';
    p.handles.button_save.Enable = true;

    toggleEnabledStatus(p.handles, false)
    fig.UserData = p;
end
%**************************************************************************
function callback_displayPorts(src,~)
    src.Items = parsePorts(serialportlist("all"));

end
%**************************************************************************
function ports = parsePorts(portlist)
    %separates out the cu and tty ports on a mac. does nothing if on pc
    if ismac || isunix
        ports = portlist(contains(portlist, 'cu.'));
    else
        ports = portlist;
    end
end
 
%**************************************************************************

%**************************************************************************
%% callback function for continuous collection
function pStruct = packetReadyCallback(~, pStruct, packet)

    fftXRange = [pStruct.fftStart.Value,pStruct.fftEnd.Value];

    if hasActiveStream(pStruct)   
        pStruct.Stream.Save(packet);
        pStruct.bytesSavedTarget.Value = formatBytes(pStruct.Stream.BytesWritten);
    end
    if pStruct.filterCheck.Value
        packet.EEG = pStruct.Filter.filter(double(packet.EEG));
    end
    pStruct.Chart = pStruct.Chart.UpdateChart(packet.EEG, packet.Event, [-650, 650]);
    pStruct.FFTPlot = pStruct.FFTPlot.UpdateChart(packet.EEG,  'FreqRange',fftXRange,'PlotLog',pStruct.FFTLog.Value);
end
%**************************************************************************
%% callback function for single trial data
function pStruct = trialReadyCallback(~, pStruct, trial)
    
   fftXRange = [pStruct.fftStart.Value,pStruct.fftEnd.Value];
   if hasActiveStream(pStruct)
       pStruct.Stream.Save(trial);
       pStruct.bytesSavedTarget.Value = sprintf('%i trials', pStruct.Stream.PacketsWritten);
   end
   if pStruct.filterCheck.Value
       trial.EEG = pStruct.Filter.filter(double(trial.EEG));
   end
   pStruct.ERPChart.UpdateERPPlot(trial, "FFTRange",fftXRange,...
       'PlotFFTLog', pStruct.FFTLog.Value,...
       'ShowStdErr', pStruct.ShowStdErr.Value);
   pStruct.ERPChart.Legend.TextColor = 'w';
end
%**************************************************************************
% initalize the device
function p = initializeDevice(p)
    p.bufferDuration = .1;
    p.sampleRate = 500;
 
    p.deviceName  =  p.handles.dropdown_devices.Value;
    p.serialPortName = p.handles.dropdown_ports.Value;
    p.TrialPreSamples = p.handles.edit_prestim.Value * p.sampleRate /1000;
    p.TrialPstSamples = p.handles.edit_pststim.Value * p.sampleRate /1000;
    p.filterFlag = false;
    
    
    %create the spiker box object here
    %first delete any existing one that may exist
    if isfield(p, 'Device')
        delete(p.Device);
    end
    
    %select a device based on user input
    dfunc = str2func(p.deviceName);
    try
        p.Device = dfunc(p.serialPortName, p.bufferDuration);
        p.Device.PacketReceivedCallback = @packetReadyCallback;
        p.Device.TrialReceivedCallback = @trialReadyCallback;
        p.Device.SetTrialLimits(p.TrialPreSamples, p.TrialPstSamples);
        
    catch ME
        errMsg(p.handles.fig, ME);
    end
end
%**************************************************************************
function errMsg(fig, errorInfo)
    uialert(fig, errorInfo.message, errorInfo.identifier);
end
%**************************************************************************
function str = formatBytes(bytes)
    unit = {'B', 'KB', 'MB', 'GB'};

    bytes = double(bytes);
    count = 1;
    while bytes > 500 && count < 5
        bytes = bytes/(1000);
        count = count + 1;
    end
    str = sprintf('%5.1f %s', bytes, unit{count});


end
%**************************************************************************
function s = hasActiveStream(p)
    if isfield(p, 'Stream') && isvalid(p.Stream) 
        if p.Stream.IsStreaming
            s = true;
        else 
            error('something went wrong');
        end
    else 
        s = false;
    end
end
%**************************************************************************
%change the enabled function of the controls based on the current state
function toggleEnabledStatus(h, isRunning)
%if isRunning = 0 then everything is shutdown
    

if isRunning
    EnabledWhenRunning = 'on';
    EnabledWhenStopped = 'off';
else
    EnabledWhenRunning = 'off';
    EnabledWhenStopped = 'on';
end

 h.edit_contlength.Enable = EnabledWhenStopped;
 h.edit_fftlength.Enable = EnabledWhenStopped;
 h.edit_prestim.Enable = EnabledWhenStopped;
 h.edit_pststim.Enable = EnabledWhenStopped;
 h.button_start.Enable = EnabledWhenStopped;
 h.button_save.Enable = EnabledWhenStopped;
 h.checkbox_window.Enable = EnabledWhenStopped;
 h.edit_lpass.Enable = EnabledWhenStopped;
 h.button_stop.Enable = EnabledWhenRunning;

 h.dropdown_devices.Enable = EnabledWhenStopped;
 h.dropdown_ports.Enable = EnabledWhenStopped;
 h.dropdown_mode.Enable = EnabledWhenStopped;

end
%**************************************************************************
function processObjects = initializeContinuousPlot(p, processObjects)

% get the user defined parameters
    plotDuration = p.handles.edit_contlength.Value;
    fftDuration = p.handles.edit_fftlength.Value;
    windowFlag  = p.handles.checkbox_window.Value;
    lpass = p.handles.edit_lpass.Value;

%reset the plot
    cla(p.handles.axis_plot);
    cla(p.handles.fft_plot);
    deleteLegend(p.handles.fig);

%create the objects
    processObjects.Chart = BCI_Chart(p.sampleRate, plotDuration, p.handles.axis_plot);
    processObjects.FFTPlot = BCI_FFTPlot(p.sampleRate, fftDuration, p.handles.fft_plot);
    p.handles.fft_plot.YScale = 'linear';

    processObjects.bytesSavedTarget = p.handles.edit_bytessaved;
    processObjects.Filter = BCI_Filter(p.sampleRate, [0,lpass], 'low',...
        'Window',windowFlag,'Continuous', true);
    processObjects.filterCheck = p.handles.checkbox_filter;
    processObjects.fftStart = p.handles.edit_contfftstart;
    processObjects.fftEnd = p.handles.edit_contfftend;
    processObjects.FFTLog =  p.handles.checkbox_contfftscale;

    saveFile = createTempSaveFileName(p.tempDataFileName);
    try
        processObjects.Stream = BCI_Stream(saveFile, Overwrite = false);
        if ~hasActiveStream(processObjects)
            error('An error occured when attempting to create the stream');
        end
    catch ME
        errMsg(fig, ME.message, ME.identifier);
        return
    end
    p.handles.edit_filename.Value = saveFile;
    p.handles.lamp_saving.Color = 'g';
    %p.handles.button_save.Enable = false;
    %end
    
end
%**************************************************************************
function processObjects = initializeERPPlot(p, processObjects)

    % get user defined parameters
    fftDuration = p.handles.edit_fftlength.Value;
    windowFlag  = p.handles.checkbox_window.Value;
    lpass = p.handles.edit_lpass.Value;

    %get the filter settings
    processObjects.ERPChart = BCI_ERPplot('AxisHandle', p.handles.axis_plot, 'FFTAxisHandle', p.handles.fft_plot);
    processObjects.ERPChart.RefreshPlot;
    processObjects.Filter = BCI_Filter(p.sampleRate, [0,40], 'low','Window',true,'Continuous',false);
    processObjects.filterCheck = p.handles.checkbox_filter;
    processObjects.fftStart = p.handles.edit_trialfftstart;
    processObjects.fftEnd = p.handles.edit_trialfftend;
    processObjects.bytesSavedTarget = p.handles.edit_bytessaved;
    processObjects.FFTLog =  p.handles.checkbox_trialfftscale;
    processObjects.ShowStdErr = p.handles.checkbox_stderr;
    saveFile = createTempSaveFileName(p.tempDataFileName);
    try
        processObjects.Stream = BCI_Stream(saveFile, Overwrite = false);
        if ~hasActiveStream(processObjects)
            error('An error occured when attempting to create the stream');
        end
        p.handles.edit_filename.Value = saveFile;
        p.handles.lamp_saving.Color = 'g';

    catch ME
        errMsg(p.handles.fig, ME.message, ME.identifier);
        return
    end
    
end
%**************************************************************************
function [fn, status] = hasTempDataFile(p)

    fn = createTempSaveFileName(p.tempDataFileName);
    status = isfile(fn);
   
end
%**************************************************************************
function status = checkForExistingTempDataFile(p)

    status = true;
    [fn, exists] = hasTempDataFile(p);

    if exists
        selection = uiconfirm(p.handles.fig, ...
            'There is unsaved data from a previous collection. What do you want to do with it?', ...
            'Overwrite confirm', 'Icon', 'warning', ...
            'Options', {'Overwrite', 'Save', 'Cancel'}, ...
            'DefaultOption', 2, 'CancelOption',3);
        switch selection
            case 'Overwrite'
                delete(fn);
            case 'Save'
                status = saveToEeglab(fn, p.handles.fig);
                
            case 'Cancel'
                status = false;

        end
    end

end
%**************************************************************************
function callback_save(src, ~)
    fig = ancestor(src, 'figure', 'toplevel');
    p = fig.UserData;
    [fn, exists] = hasTempDataFile(p); 
    if ~exists
        uialert(fig, 'No temp data file was found', 'No data to save')
        src.Enable = 'off';
    end
    status = saveToEeglab(fn, fig);
    %turn off the button if the save was successful
    if status
        src.Enable = 'off';
    end
end
%**************************************************************************
function deleteLegend(f)
    hLegend = findobj(f, 'Type', 'Legend');
    if ~isempty(hLegend)
        delete(hLegend);
    end
end
%**************************************************************************
function fullName = createTempSaveFileName(fname)
    currFile = mfilename('fullpath');
    [currPath, ~,~] = fileparts(currFile);
    fullName = fullfile(currPath, fname);
end
%**************************************************************************
function addPaths()
    f  = mfilename('fullpath');
    [fpath, fname, ~] = fileparts(f);
    newPaths{1} = sprintf('%s%sDevices', fpath, filesep);
    newPaths{2} = sprintf('%s%sExtensions', fpath, filesep);
    newPaths{2} = sprintf('%s%sTools', fpath, filesep);
    
    
    s       = pathsep;
    pathStr = [s, path, s];
    for ii = 1:length(newPaths)
        if ~contains(pathStr, [s, newPaths{ii}, s], 'IgnoreCase', ispc)
            addpath(newPaths{ii});
        end
    end
end
%**************************************************************************
function status = saveToEeglab(fn, fig)

    status = false;
    
    
    %load the EEG data
    EEG = ReadStreamFile(fn);
    if isempty(EEG)
        return
    end

    %get information about where to save it
    fig.Visible = 'off';
    [file, path] = uiputfile('*.set', 'Save File Name');
    fig.Visible = 'on';
     if file==0
         return
      end
    
    saveFile = fullfile(path, file);
    [p, f, ~] = fileparts(saveFile);
    saveFile = fullfile(p, [f, '.set']);%
    
    save(saveFile, 'EEG', '-mat');
    delete(fn);
    status = true;
    
end
%**************************************************************************
%% function to create the  user interface
function h = buildUI()
    
    %load the color scheme values
    guiScheme = load('Scheme.mat');

    SIDE_PANEL_WIDTH = 200;
    CONTROL_WIDTH = SIDE_PANEL_WIDTH-40;
    CONTROL_LABEL_OFFSET = 21;
    CONTROL_GROUP_OFFSET = 28;
    LEFT_OFFSET = 10;
    
    ports = parsePorts(serialportlist('all'));

    %see if the figure already exists
    %if it does not create it and if it does clear it and start over
    existingFigureHandle = findall(0,'Tag', 'BNSPlotter');
    
    if ~isempty(existingFigureHandle) && isvalid(existingFigureHandle)
        clf(existingFigureHandle);
        h.fig = existingFigureHandle;
    else
        h.fig = uifigure;
    end
    
    h.fig.WindowState = 'maximized';
    h.fig.Color = guiScheme.Window.BackgroundColor.Value;
    drawnow;
    
    h.fig.Name = 'BNS EEG Plotter';
    h.fig.Tag = 'BNSPlotter';
    h.fig.Resize = true;
    h.fig.CloseRequestFcn = @callback_closeRequest;
    
    progress = uiprogressdlg(h.fig, 'Title', 'BNS EEG Plotter', ...
        'Message', 'Creating the Interface',...
        'Indeterminate','on', ...
        'Cancelable','off');
    drawnow;

    h.grid = uigridlayout(h.fig,[5,2], "ColumnSpacing",10, 'RowSpacing',2);
    h.grid.RowHeight = {'1x','1x','1x','1x'};
    h.grid.ColumnWidth  = {SIDE_PANEL_WIDTH, '1x'};
    h.grid.BackgroundColor = guiScheme.Window.BackgroundColor.Value;
    drawnow;

   
    %panel for the current acquisition status
    h.panel_controls = uipanel('Parent', h.grid, 'Title','Hardware Controls');
    h.panel_controls.Layout.Row = 1;
    h.panel_controls.Layout.Column = 1;
    h.panel_controls.BackgroundColor = guiScheme.Panel.BackgroundColor.Value;
    h.panel_controls.HighlightColor = guiScheme.Panel.BorderColor.Value;
    h.panel_controls.Scrollable = 'on';
    h.panel_controls.ForegroundColor = guiScheme.Panel.FontColor.Value;
    h.panel_controls.FontName = guiScheme.Panel.Font.Value;
    h.panel_controls.FontSize = guiScheme.Panel.FontSize.Value;
    drawnow;
   

    bottom = 10;
    %create a drop down list for the devices    
    h.dropdown_mode = uidropdown('Parent', h.panel_controls,...
        'Items', {'Continuous', 'Single Trial'},...
        'Position', [LEFT_OFFSET, bottom, CONTROL_WIDTH, guiScheme.Dropdown.Height.Value],...
        'Tooltip','Select the colletion mode',...
        'BackgroundColor',guiScheme.Dropdown.BackgroundColor.Value,...
        'FontName', guiScheme.Dropdown.Font.Value,...
        'FontSize', guiScheme.Dropdown.FontSize.Value, ...
        'FontColor', guiScheme.Dropdown.FontColor.Value,...
        'ValueChangedFcn',@callback_switchmodes);

    bottom = bottom + CONTROL_LABEL_OFFSET;
    uilabel('Parent', h.panel_controls,...
        'Position', [LEFT_OFFSET, bottom, CONTROL_WIDTH, 25], ...
        'Text', 'Collection mode', ...
        'FontColor', guiScheme.Label.FontColor.Value,...
        'FontName', guiScheme.Label.Font.Value,...
        'FontSize', guiScheme.Label.FontSize.Value);
    
     bottom = bottom + CONTROL_GROUP_OFFSET;
     h.dropdown_ports = uidropdown('Parent', h.panel_controls,...
        'Position', [LEFT_OFFSET, bottom, CONTROL_WIDTH, 25],...
        'Tooltip', 'Select the port for connecting to your device', ...
        'Items', ports,...
        'DropDownOpeningFcn',@callback_displayPorts,...
        'BackgroundColor',guiScheme.Dropdown.BackgroundColor.Value,...
        'Fontname', guiScheme.Dropdown.Font.Value,...
        'FontSize', guiScheme.Dropdown.FontSize.Value, ...
        'FontColor', guiScheme.Dropdown.FontColor.Value);

    bottom = bottom + CONTROL_LABEL_OFFSET;
    uilabel('Parent', h.panel_controls,...
        'Position', [LEFT_OFFSET, bottom, CONTROL_WIDTH, 25], ...
        'Text', 'Serial Port',...
        'FontColor', guiScheme.Label.FontColor.Value,...
        'FontName', guiScheme.Label.Font.Value,...
        'FontSize', guiScheme.Label.FontSize.Value);
    
    bottom = bottom + CONTROL_GROUP_OFFSET;
    h.dropdown_devices = uidropdown('Parent', h.panel_controls,...
        'Items', {'BNS EEG Spikerbox', 'ERP Mini'},...
        'Position', [LEFT_OFFSET, bottom, CONTROL_WIDTH, guiScheme.Dropdown.Height.Value],...
        'Tooltip','Select a compatible EEG device',...
        'BackgroundColor',guiScheme.Dropdown.BackgroundColor.Value,...
        'FontName', guiScheme.Dropdown.Font.Value,...
        'FontSize', guiScheme.Dropdown.FontSize.Value, ...
        'FontColor', guiScheme.Dropdown.FontColor.Value);
    h.dropdown_devices.ItemsData = {'BNS_HBSpiker', 'ERPminiCont'};
    
    bottom = bottom + CONTROL_LABEL_OFFSET;
    uilabel('Parent', h.panel_controls,...
        'Position', [LEFT_OFFSET, bottom, CONTROL_WIDTH, 25], ...
        'Text', 'EEG Device', ...
        'FontColor', guiScheme.Label.FontColor.Value,...
        'FontName', guiScheme.Label.Font.Value,...
        'FontSize', guiScheme.Label.FontSize.Value);
    
    
    %add the property tabs for the two modes 
    h.panel_cont = uipanel('Parent', h.grid,...
        'Title', 'Continous Properties',...
        'BackgroundColor',guiScheme.Panel.BackgroundColor.Value,...
        'HighlightColor', guiScheme.Panel.BorderColor.Value,...
        'ForegroundColor',guiScheme.Panel.FontColor.Value,...
        'FontName',guiScheme.Panel.Font.Value,...
        'FontSize', guiScheme.Panel.FontSize.Value,...
        'Scrollable','on');
    h.panel_cont.Layout.Column = 1;
    h.panel_cont.Layout.Row = 2;
    drawnow;

    h.panel_trial = uipanel('Parent', h.grid,...
        'Title', 'Single Trial Properties',...
        'BackgroundColor',guiScheme.Panel.BackgroundColor.Value,...
        'HighlightColor', guiScheme.Panel.BorderColor.Value,...
        'ForegroundColor',guiScheme.Panel.FontColor.Value,...
        'FontName',guiScheme.Panel.Font.Value,...
        'FontSize', guiScheme.Panel.FontSize.Value,...
        'Visible','off',...
        'Scrollable','on');
    h.panel_trial.Layout.Column = 1;
    h.panel_trial.Layout.Row = 2;
    drawnow;
    
    %add the continuous controls
    bottom = 10;
    h.checkbox_contfftscale = uicheckbox('Parent', h.panel_cont,...
        'Position', [LEFT_OFFSET, bottom, CONTROL_WIDTH, 30],...
        'Value', false,...
        'Text', 'Plot FFT on a log scale?',...
        'FontName', guiScheme.Checkbox.Font.Value,...
        'FontSize', guiScheme.Checkbox.FontSize.Value,...
        'FontColor', guiScheme.Checkbox.FontColor.Value);

    bottom = bottom + CONTROL_GROUP_OFFSET;
    h.edit_contfftstart = uieditfield(h.panel_cont,'numeric',...
        "Limits", [0, 249],...
        "Value", 0,...
        "ValueDisplayFormat",'%4.2f Hz',...
        "Position", [LEFT_OFFSET, bottom, CONTROL_WIDTH/2-5, guiScheme.Edit.Height.Value],...
        "HorizontalAlignment",'center',...
        "BackgroundColor",guiScheme.Edit.BackgroundColor.Value,...
        "FontName",guiScheme.Edit.Font.Value,...
        "FontSize", guiScheme.Edit.FontSize.Value, ...
        "FontColor", guiScheme.Edit.FontColor.Value);

   h.edit_contfftend = uieditfield(h.panel_cont,'numeric',...
        "Limits", [1, 250],...
        "Value", 250,...
        "ValueDisplayFormat",'%4.2f Hz',...
        "Position", [LEFT_OFFSET+ CONTROL_WIDTH/2+5, bottom, CONTROL_WIDTH/2-5, guiScheme.Edit.Height.Value],...
        "HorizontalAlignment",'center',...
        "BackgroundColor",guiScheme.Edit.BackgroundColor.Value,...
        "FontName",guiScheme.Edit.Font.Value,...
        "FontSize", guiScheme.Edit.FontSize.Value, ...
        "FontColor", guiScheme.Edit.FontColor.Value);
    
   bottom = bottom + CONTROL_LABEL_OFFSET;
   uilabel('Parent', h.panel_cont,...
        'Position', [LEFT_OFFSET, bottom, CONTROL_WIDTH, 45], ...
        'WordWrap','on',...
        'Text', sprintf('Frequency Plot Range\nMIN\t\t\t  MAX'),...
        'FontColor', guiScheme.Label.FontColor.Value,...
        'FontName', guiScheme.Label.Font.Value,...
        'FontSize', guiScheme.Label.FontSize.Value);
    
   bottom = bottom + CONTROL_GROUP_OFFSET +CONTROL_LABEL_OFFSET;
   h.edit_fftlength = uieditfield(h.panel_cont,'numeric',...
        "Limits", [.25, 5],...
        "Value", 1,...
        "ValueDisplayFormat",'%2.1f Seconds',...
        "Position", [LEFT_OFFSET, bottom, CONTROL_WIDTH, guiScheme.Edit.Height.Value],...
        "HorizontalAlignment",'center',...
        "BackgroundColor",guiScheme.Edit.BackgroundColor.Value,...
        "FontName",guiScheme.Edit.Font.Value,...
        "FontSize", guiScheme.Edit.FontSize.Value, ...
        "FontColor", guiScheme.Edit.FontColor.Value);
    
   bottom = bottom + CONTROL_LABEL_OFFSET;
   uilabel('Parent', h.panel_cont,...
        'Position', [LEFT_OFFSET, bottom, CONTROL_WIDTH, 25], ...
        'WordWrap','on',...
        'Text', sprintf('FFT window size'),...
        'FontColor', guiScheme.Label.FontColor.Value,...
        'FontName', guiScheme.Label.Font.Value,...
        'FontSize', guiScheme.Label.FontSize.Value);
   
   bottom = bottom + CONTROL_GROUP_OFFSET ;
   h.edit_contlength = uieditfield(h.panel_cont,'numeric',...
        "Limits", [.25, 30],...
        "Value", 5,...
        "ValueDisplayFormat",'%2.1f Seconds',...
        "Position", [LEFT_OFFSET, bottom, CONTROL_WIDTH, guiScheme.Edit.Height.Value],...
        "HorizontalAlignment",'center',...
        "BackgroundColor",guiScheme.Edit.BackgroundColor.Value,...
        "FontName",guiScheme.Edit.Font.Value,...
        "FontSize", guiScheme.Edit.FontSize.Value, ...
        "FontColor", guiScheme.Edit.FontColor.Value);
    
   bottom = bottom + CONTROL_LABEL_OFFSET;
   uilabel('Parent', h.panel_cont,...
        'Position', [LEFT_OFFSET, bottom, CONTROL_WIDTH, 25], ...
        'WordWrap','on',...
        'Text', sprintf('Time plot length'),...
        'FontColor', guiScheme.Label.FontColor.Value,...
        'FontName', guiScheme.Label.Font.Value,...
        'FontSize', guiScheme.Label.FontSize.Value);
    
    % add the single trial controls
    bottom = 10;
    h.checkbox_trialfftscale = uicheckbox('Parent', h.panel_trial,...
        'Position', [LEFT_OFFSET, bottom, CONTROL_WIDTH, 30],...
        'Value', true,...
        'Text', 'Plot FFT on a log scale?',...
        'FontName', guiScheme.Checkbox.Font.Value,...
        'FontSize', guiScheme.Checkbox.FontSize.Value,...
        'FontColor', guiScheme.Checkbox.FontColor.Value);
    
    bottom = bottom + CONTROL_GROUP_OFFSET;
    h.checkbox_stderr = uicheckbox('Parent', h.panel_trial,...
        'Position', [LEFT_OFFSET, bottom, CONTROL_WIDTH, 30],...
        'Value', true,...
        'Text', 'Show standard error?',...
        'FontName', guiScheme.Checkbox.Font.Value,...
        'FontSize', guiScheme.Checkbox.FontSize.Value,...
        'FontColor', guiScheme.Checkbox.FontColor.Value);

    bottom = bottom + CONTROL_GROUP_OFFSET;
    h.edit_trialfftstart = uieditfield(h.panel_trial,'numeric',...
        "Limits", [0, 249],...
        "Value", 0,...
        "ValueDisplayFormat",'%4.2f Hz',...
        "Position", [LEFT_OFFSET, bottom, CONTROL_WIDTH/2-5, guiScheme.Edit.Height.Value],...
        "HorizontalAlignment",'center',...
        "BackgroundColor",guiScheme.Edit.BackgroundColor.Value,...
        "FontName",guiScheme.Edit.Font.Value,...
        "FontSize", guiScheme.Edit.FontSize.Value, ...
        "FontColor", guiScheme.Edit.FontColor.Value);

   h.edit_trialfftend = uieditfield(h.panel_trial,'numeric',...
        "Limits", [1, 250],...
        "Value", 250,...
        "ValueDisplayFormat",'%4.2f Hz',...
        "Position", [LEFT_OFFSET+ CONTROL_WIDTH/2+5, bottom, CONTROL_WIDTH/2-5, guiScheme.Edit.Height.Value],...
        "HorizontalAlignment",'center',...
        "BackgroundColor",guiScheme.Edit.BackgroundColor.Value,...
        "FontName",guiScheme.Edit.Font.Value,...
        "FontSize", guiScheme.Edit.FontSize.Value, ...
        "FontColor", guiScheme.Edit.FontColor.Value);

      bottom = bottom + CONTROL_LABEL_OFFSET;
      uilabel('Parent', h.panel_trial,...
        'Position', [LEFT_OFFSET, bottom, CONTROL_WIDTH, 45], ...
        'WordWrap','on',...
        'Text', sprintf('Frequency Plot Range\nMIN\t\t\t  MAX'),...
        'FontColor', guiScheme.Label.FontColor.Value,...
        'FontName', guiScheme.Label.Font.Value,...
        'FontSize', guiScheme.Label.FontSize.Value);
 
    bottom = bottom + CONTROL_GROUP_OFFSET + CONTROL_LABEL_OFFSET;
    h.edit_prestim = uieditfield(h.panel_trial, 'numeric',...
        'Position', [LEFT_OFFSET, bottom, CONTROL_WIDTH, guiScheme.Edit.Height.Value],...
        'Value',100,...
        'Limits', [0,1000],...
        'RoundFractionalValue', 'on',...
        'ValueDisplayFormat', '%i ms',...
        'HorizontalAlignment', 'center',...
        "BackgroundColor",guiScheme.Edit.BackgroundColor.Value,...
        "FontName",guiScheme.Edit.Font.Value,...
        "FontSize", guiScheme.Edit.FontSize.Value, ...
        "FontColor", guiScheme.Edit.FontColor.Value);
   
    bottom = bottom + CONTROL_LABEL_OFFSET;
    uilabel('Parent', h.panel_trial, ...
        'Text', 'Pre Stimulus Duration',...
        'Position', [LEFT_OFFSET,bottom, CONTROL_WIDTH, 25],...
        'FontColor', guiScheme.Label.FontColor.Value,...
        'FontName', guiScheme.Label.Font.Value,...
        'FontSize', guiScheme.Label.FontSize.Value);
    
    bottom = bottom + CONTROL_GROUP_OFFSET;
    h.edit_pststim = uieditfield(h.panel_trial, 'numeric',...
        'Position', [LEFT_OFFSET, bottom, CONTROL_WIDTH, guiScheme.Edit.Height.Value],...
        'Value',600,...
        'Limits', [0,1100],...
        'RoundFractionalValue', 'on',...
        'ValueDisplayFormat', '%i ms',...
        'HorizontalAlignment', 'center',...
        "BackgroundColor",guiScheme.Edit.BackgroundColor.Value,...
        "FontName",guiScheme.Edit.Font.Value,...
        "FontSize", guiScheme.Edit.FontSize.Value, ...
        "FontColor", guiScheme.Edit.FontColor.Value);
    
    bottom = bottom + CONTROL_LABEL_OFFSET;
    uilabel('Parent', h.panel_trial, ...
        'Text', 'Post Stimulus Duration',...
        'Position', [LEFT_OFFSET,bottom, CONTROL_WIDTH, 25],...
        'FontColor', guiScheme.Label.FontColor.Value,...
        'FontName', guiScheme.Label.Font.Value,...
        'FontSize', guiScheme.Label.FontSize.Value);
    
    %filter control
    h.panel_filter = uipanel('Parent', h.grid,...
        'Title', 'Filter Setting',...
        'BackgroundColor',guiScheme.Panel.BackgroundColor.Value,...
        'HighlightColor', guiScheme.Panel.BorderColor.Value,...
        'ForegroundColor',guiScheme.Panel.FontColor.Value,...
        'FontName',guiScheme.Panel.Font.Value,...
        'FontSize', guiScheme.Panel.FontSize.Value,...
        'Scrollable','on');
    h.panel_filter.Layout.Column = 1;
    h.panel_filter.Layout.Row = 3;
    drawnow;

    bottom = 10;
    h.edit_lpass = uieditfield(h.panel_filter, 'numeric',...
        'Position', [LEFT_OFFSET, bottom, CONTROL_WIDTH, guiScheme.Edit.Height.Value],...
        'Value',40,...
        'Limits', [10,250],...
        'RoundFractionalValue', 'on',...
        'ValueDisplayFormat', '%i Hz',...
        'HorizontalAlignment', 'center',...
        "BackgroundColor",guiScheme.Edit.BackgroundColor.Value,...
        "FontName",guiScheme.Edit.Font.Value,...
        "FontSize", guiScheme.Edit.FontSize.Value, ...
        "FontColor", guiScheme.Edit.FontColor.Value);
    
    bottom = bottom + CONTROL_LABEL_OFFSET;
    uilabel('Parent', h.panel_filter, ...
        'Text', 'Low pass filter cuttoff',...
        'Position', [LEFT_OFFSET,bottom, CONTROL_WIDTH, 25],...
        'FontColor', guiScheme.Label.FontColor.Value,...
        'FontName', guiScheme.Label.Font.Value,...
        'FontSize', guiScheme.Label.FontSize.Value);

    bottom = bottom + CONTROL_GROUP_OFFSET;
    h.checkbox_window = uicheckbox('Parent', h.panel_filter,...
        'Position', [LEFT_OFFSET, bottom, CONTROL_WIDTH, 30],...
        'Value', true,...
        'Text', 'Window data prior to filtering?',...
        'FontName', guiScheme.Checkbox.Font.Value,...
        'FontSize', guiScheme.Checkbox.FontSize.Value,...
        'FontColor', guiScheme.Checkbox.FontColor.Value);

    bottom = bottom + CONTROL_GROUP_OFFSET;
    h.checkbox_filter = uicheckbox('Parent', h.panel_filter,...
        'Position', [LEFT_OFFSET, bottom, CONTROL_WIDTH, 30],...
        'Value', true,...
        'Text', 'Low pass filter?',...
        'FontName', guiScheme.Checkbox.Font.Value,...
        'FontSize', guiScheme.Checkbox.FontSize.Value,...
        'FontColor', guiScheme.Checkbox.FontColor.Value);
    
    %button control panel
    h.panel_run = uipanel('Parent', h.grid,... 
        'Units', 'pixels', 'BorderType','line',...
        'Title', 'Recording Controls',...
        'BackgroundColor',guiScheme.Panel.BackgroundColor.Value,...
        'HighlightColor', guiScheme.Panel.BorderColor.Value,...
        'ForegroundColor',guiScheme.Panel.FontColor.Value,...
        'FontName',guiScheme.Panel.Font.Value,...
        'FontSize', guiScheme.Panel.FontSize.Value,...
        'Scrollable','on');
    h.panel_run.Layout.Column = 1;
    h.panel_run.Layout.Row = 4;
    
    drawnow
    bottom = 10;
     h.edit_bytessaved = uieditfield('Parent', h.panel_run,...
        'Value', '', ...
        'Position', [LEFT_OFFSET,bottom,CONTROL_WIDTH,guiScheme.Edit.Height.Value],...
        'Editable', 'off',...
        "BackgroundColor",guiScheme.Edit.BackgroundColor.Value,...
        "FontName",guiScheme.Edit.Font.Value,...
        "FontSize", guiScheme.Edit.FontSize.Value, ...
        "FontColor", guiScheme.Edit.FontColor.Value);

     bottom = bottom + CONTROL_LABEL_OFFSET;
      h.label_bytessaved = uilabel('Parent', h.panel_run,...
        'Text', 'Bytes/Trials Saved', ...
        'Position', [LEFT_OFFSET,bottom,CONTROL_WIDTH,20],...
        'FontColor', guiScheme.Label.FontColor.Value,...
        'FontName', guiScheme.Label.Font.Value,...
        'FontSize', guiScheme.Label.FontSize.Value);

     bottom = bottom + CONTROL_GROUP_OFFSET * 2;
     h.button_save = uibutton('Parent', h.panel_run,...
        'Text', 'Save Recording',...
        'Position',[LEFT_OFFSET, bottom, CONTROL_WIDTH, guiScheme.Button.Height.Value],...
        'ButtonPushedFcn',@callback_save,...
        'BackgroundColor',guiScheme.Button.BackgroundColor.Value,...
        'FontSize', guiScheme.Button.FontSize.Value,...
        'FontName',guiScheme.Button.Font.Value,...
        'FontColor', guiScheme.Button.FontColor.Value,...
        'Enable','off'); 
     
     bottom = bottom + CONTROL_GROUP_OFFSET * 2;
     h.button_stop = uibutton('Parent', h.panel_run,...
        'Text', 'Stop Recording',...
        'Position',[LEFT_OFFSET, bottom, CONTROL_WIDTH, guiScheme.Button.Height.Value],...
        'ButtonPushedFcn',@callback_stop,...
        'BackgroundColor',guiScheme.Button.BackgroundColor.Value,...
        'FontSize', guiScheme.Button.FontSize.Value,...
        'FontName',guiScheme.Button.Font.Value,...
        'FontColor', guiScheme.Button.FontColor.Value,...
        'Enable','off'); 

     bottom = bottom + CONTROL_GROUP_OFFSET +20;
     h.button_start = uibutton('Parent', h.panel_run,...
        'Text', 'Start Recording',...
        'Position',[LEFT_OFFSET, bottom, CONTROL_WIDTH, guiScheme.Button.Height.Value],...
        'ButtonPushedFcn',@callback_start,...
        'BackgroundColor',guiScheme.Button.BackgroundColor.Value,...
        'FontSize', guiScheme.Button.FontSize.Value,...
        'FontName',guiScheme.Button.Font.Value,...
        'FontColor', guiScheme.Button.FontColor.Value); 


    % make the axis for plotting   
    h.axis_plot = uiaxes('Parent', h.grid);
    h.axis_plot.FontSize = guiScheme.Axis.FontSize.Value;
    h.axis_plot.Layout.Column = 2;
    h.axis_plot.Layout.Row = [1 2];
    h.axis_plot.XLabel.String = 'Time (seconds)';
    h.axis_plot.XLabel.FontSize = guiScheme.Axis.FontSize.Value * 1.2;
    h.axis_plot.FontName = guiScheme.Axis.Font.Value;
    h.axis_plot.YLabel.String = 'Amplitude (uV)';
    h.axis_plot.YLabel.FontSize = guiScheme.Axis.FontSize.Value * 1.2;
    h.axis_plot.Toolbar.Visible = false;
    h.axis_plot.XLimitMethod = 'tight';
    h.axis_plot.Interactions = [];
    h.axis_plot.PickableParts = 'none';
    h.axis_plot.HitTest = 'off';
    h.axis_plot.PositionConstraint = 'innerposition';  
    h.axis_plot.Color = guiScheme.Axis.BackgroundColor.Value;
    h.axis_plot.XColor = guiScheme.Axis.AxisColor.Value;
    h.axis_plot.YColor = guiScheme.Axis.AxisColor.Value;
    h.axis_plot.Box = 'on';
    h.axis_plot.XGrid = 'on';
    h.axis_plot.YGrid = 'on';
    h.axis_plot.ColorOrder = [0,1,0; 1, .2, 0;0,1,1];

    h.fft_plot = uiaxes('Parent', h.grid);
    h.fft_plot.FontSize = guiScheme.Axis.FontSize.Value;
    h.fft_plot.Layout.Column = 2;
    h.fft_plot.Layout.Row = [3 4];
    h.fft_plot.XLabel.String = 'Frequency (Hz)';
    h.fft_plot.XLabel.FontSize = guiScheme.Axis.FontSize.Value * 1.2;
    h.fft_plot.FontName = guiScheme.Axis.Font.Value;
    h.fft_plot.YLabel.String = 'Power (uV^2)';
    h.fft_plot.YLabel.FontSize = guiScheme.Axis.FontSize.Value * 1.2;
    h.fft_plot.Toolbar.Visible = false;
    h.fft_plot.XLimitMethod = 'tight';
    h.fft_plot.Interactions = [];
    h.fft_plot.PickableParts = 'none';
    h.fft_plot.HitTest = 'off';
    h.fft_plot.PositionConstraint = 'innerposition';  
    h.fft_plot.Color = guiScheme.Axis.BackgroundColor.Value;
    h.fft_plot.XColor = guiScheme.Axis.AxisColor.Value;
    h.fft_plot.YColor = guiScheme.Axis.AxisColor.Value;
    h.fft_plot.Box = 'on';
    h.fft_plot.XGrid = 'on';
    h.fft_plot.YGrid = 'on';
    h.fft_plot.ColorOrder = [0,1,0; 1, .2, 0;0,1,1];

    drawnow;
    delete(progress);

    pos = h.fig.Position;
    pause(.25)
    h.fig.Position = pos;
    drawnow


end