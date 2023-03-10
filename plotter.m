%The description will be here.
%
% KJ Jantzen
%January 2023

function plotter()
    %main function that loads the parameters
    %and builds the UI
    
    p.handles = buildUI;
    addPaths;
    set(p.handles.fig, 'UserData', p);
    
    end
%**************************************************************************
%% start collecting continuous data
function callback_cont_start(src,~)
    
    fig = ancestor(src, 'figure', 'toplevel');
    p = fig.UserData;
    
    toggleEnabledStatus(p.handles, 2);
    drawnow;

    try
        if ~isfield(p, "Device") || ~isvalid(p.Device)
            p = initializeDevice(p);
            if ~isfield(p, 'Device') || ~isvalid(p.Device)
                toggleEnabledStatus(p.handles, 0);
                return;
            end
        end
        
        p.Device.ProcessObjects = initializeContinuousPlot(p, p.Device.ProcessObjects);
        %put the device into continuous collection mode
        p.Device.SetMode("Continuous");
        p.Device.Start   
        fig.UserData = p;
    catch ME
        errMsg(p.handles.fig, ME);
        toggleEnabledStatus(p.handles, 0);
    end
end
%**************************************************************************
function callback_trial_start(src, ~)
    fig = ancestor(src, 'figure', 'toplevel');
    p = fig.UserData;
    
    toggleEnabledStatus(p.handles, 2);
    drawnow
    
    try
        %if ~isfield(p, "Device")
            p = initializeDevice(p);
        %end
        p.Device.ProcessObjects = initializeERPPlot(p, p.Device.ProcessObjects);
        pause(1);
        
        %get the trial duration informatation
        [p, resetRequired] = getTrialLimits(p);
        
        %put the device into single trial collection mode
        if resetRequired
            p.Device.SetTrialLimits(p.TrialPreSamples, p.TrialPstSamples);
            fig.UserData = p;
            callback_reset_erp(src);
        end
        p.Device.SetMode("Trial");
        p.Device.Start
        
        fig.UserData = p;
    catch ME
        errMsg(p.handles.fig, ME);
        toggleEnabledStatus(p.handles, 0);
    end
end
%**************************************************************************
function [p, reset] = getTrialLimits(p)
    
    reset = false;
    prestim = p.handles.edit_prestim.Value * p.sampleRate /1000;
    pststim = p.handles.edit_pststim.Value * p.sampleRate /1000;

    if ~isfield(p, "TrialPreSamples")
        p.TrialPreSamples = prestim;
        p.TrialPstSamples = pststim;
        reset = true;
        return
    end        
    if (prestim ~= p.TrialPreSamples) || (pststim ~= p.TrialPstSamples)
        reset = true;
    end

end
%**************************************************************************
function callback_reset_erp(src, ~)
    fig = ancestor(src, 'figure', 'toplevel');
    p = fig.UserData;
    
    if isfield(p, "Device")
       if isfield(p.Device.ProcessObjects, 'ERPChart')
        p.Device.ProcessObjects.ERPChart.clearERP;
        cla(p.handles.axis_plot);
       end
    end
    
end
%**************************************************************************
%% stop the eeg device
function callback_stop(src, ~)
%stopping will close all open streaming files and delete the device to
%force a reinitialization based on the current settings of the device and
%port dropdowns.
%

    fig = ancestor(src, 'figure', 'toplevel');
    p = fig.UserData;
    
    if isfield(p, "Device")
        p.Device.Stop
        pause(1);
        p.Device.Delete
    end
    if isfield(p, "Stream") && isvalid(p.Stream)
        p.Stream.Close;
    end
    p.handles.edit_filename.Value = "";
    p.handles.edit_bytessaved.Value = "";
    p.handles.lamp_saving.Color = 'r';
    p.handles.button_save.Enable = true;

    toggleEnabledStatus(p.handles, 0)
    fig.UserData = p;
end
%**************************************************************************
function callback_pause(src, ~)
%pausing will halt the recording but will not delete teh device, close the
%file or allow for selecting a new port or device.
%
    fig = ancestor(src, 'figure', 'toplevel');
    p = fig.UserData;
    
    %this should actually be used to pause saving of data
    %not streaming of data
    if isfield(p, "Device")
        p.Device.Stop
    end

    toggleEnabledStatus(p.handles, 1)
    fig.UserData = p;
end
%**************************************************************************
function callback_save(src, ~)
%starts streaming of data from the device to disk
    fig = ancestor(src, 'figure', 'toplevel');
    p = fig.UserData;

    %make sure there is not already an open stream
    if hasActiveStream(p)
        if p.IsStreaming
            uialert('Data is already streaming to file %s', p.Stream.Filename)
            return
        end
    end

    po = p.Device.ProcessObjects;
    %get a filename from the user
    fig.Visible = false;
    [sFile, sPath] = uiputfile('*.dat', 'Save EEG data');
    if (sFile ~= 0)
        saveFile = fullfile(sPath, sFile);
        po.Stream = BCI_Stream(saveFile, Overwrite = true);
        p.Device.ProcessObjects = po;
        p.handles.edit_filename.Value = saveFile;
        p.handles.lamp_saving.Color = 'g';
        p.handles.button_save.Enable = false;
    end
    fig.Visible = true;
    fig.UserData = p;

end
%**************************************************************************
function callback_displayPorts(src,~)
    src.Items = serialportlist("all");

end
%**************************************************************************
%% callback function for continuous collection
function pStruct = packetReadyCallback(src, pStruct, packet)


 %   packet.EEG = pStruct.Filter.filter(double(packet.EEG));
    if hasActiveStream(pStruct)
   
        pStruct.Stream.Save(packet);
        pStruct.bytesSavedTarget.Value = formatBytes(pStruct.Stream.BytesWritten);
    end
    pStruct.Chart = pStruct.Chart.UpdateChart(packet.EEG, packet.Event, [-600, 600]);
end
%**************************************************************************
%% callback function for single trial data
function pStruct = trialReadyCallback(src, pStruct, trial)
    
   if hasActiveStream(pStruct)
       pStruct.Stream.Save(trial);
   end
    pStruct.ERPChart.UpdateERPPlot(trial);
end
%**************************************************************************
% initalize the device
function p = initializeDevice(p)
    p.deviceName  =  p.handles.dropdown_devices.Value;
    p.serialPortName = p.handles.dropdown_ports.Value;
    
    p.bufferDuration = .1;
    p.sampleRate = 500;
    
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
    if isfield(p, 'Stream') && isvalid(p.Stream) && p.Stream.IsStreaming
        s = true;
    else 
        s = false;
    end
end
%% function to create the  user interface
%**************************************************************************
function h = buildUI()
    BUTTON_BG_COLOR = [.8,.8,.8];
    BUTTON_FG_COLOR = [0,0,0];
    BUTTON_TXT_SIZE = 16;
    
    sz = get(0, 'ScreenSize');
    ports = serialportlist;
    
    %see if the figure already exists
    %if it does not create it and if it does clear it and start over
    existingFigureHandle = findall(0,'Tag', 'BNSPlotter');
    
    if ~isempty(existingFigureHandle)
        close(existingFigureHandle(1));
    end
    
    h.fig = uifigure;
    
    h.fig.Position = [0,0,sz(3),sz(4)];
    h.fig.Name = 'BNS EEG Plotter';
    h.fig.Tag = 'BNSPlotter';
    h.fig.Resize = true;
    
    h.grid = uigridlayout(h.fig,[4,2]);
    h.grid.RowHeight = {115,240,200,'1x'};
    h.grid.ColumnWidth  = {200, '1x'};

    drawnow;
    progress = uiprogressdlg(h.fig, 'Title', 'BNS Plotter EEG Plotter', ...
        'Message', 'Creating the Interface',...
        'Indeterminate','on', ...
        'Cancelable','off');
    drawnow;

    %panel for the current acquisition status
    h.panel_controls = uipanel('Parent', h.grid);
    h.panel_controls.Layout.Row = 1;
    h.panel_control.Layout.Column = 1;
    
    %create a drop down list for the devices    
    uilabel('Parent', h.panel_controls,...
        'Position', [10, 85, 180, 25], ...
        'Text', 'EEG Device');
    
    h.dropdown_devices = uidropdown('Parent', h.panel_controls,...
        'Items', {'BNS EEG Spikerbox', 'ERP Mini'},...
        'Position', [10, 60, 180, 25],...
        'Tooltip','Select a compatible EEG device');
    h.dropdown_devices.ItemsData = {'BNS_HBSpiker', 'ERPminiCont'};
    h.dropdown_devices.ClickedFcn = @testing;
    
    uilabel('Parent', h.panel_controls,...
        'Position', [10, 35, 180, 25], ...
        'Text', 'Serial Port');
    
    h.dropdown_ports = uidropdown('Parent', h.panel_controls,...
        'Position', [10, 10, 180, 25],...
        'Tooltip', 'Select the port for connecting to your device', ...
        'Items', ports,...
        'DropDownOpeningFcn',@callback_displayPorts);
    
    %add the mode tabs
    h.tab_mode = uitabgroup('Parent', h.grid,...
        'TabLocation','top');
    h.tab_mode.Layout.Row = 2;
    h.tab_mode.Layout.Column = 1;
    
    h.tab_cont = uitab('Parent', h.tab_mode,...
        'Title', 'Continuous');
    h.tab_trial = uitab('Parent', h.tab_mode,...
        'Title', 'ERP');
    drawnow;
    pause(2);

    h.panel_cont = uipanel('Parent', h.tab_cont,...
        'Position', h.tab_cont.InnerPosition,...
        'Units', 'pixels');
    
    h.panel_trial = uipanel('Parent', h.tab_trial,...
        'Position', h.tab_trial.InnerPosition,...
        'Units', 'pixels');
    
    %add the continuous controls
    %this will be an start/stop and save button
    btm = h.panel_cont.InnerPosition(4) - 40;
    h.button_cont_start = uibutton('Parent', h.panel_cont,...
        'Text', 'Start',...
        'Position',[20, btm, 160, 30],...
        'BackgroundColor',BUTTON_BG_COLOR,...
        'FontColor',BUTTON_FG_COLOR,...
        'ButtonPushedFcn',@callback_cont_start,...
        'FontSize', BUTTON_TXT_SIZE);

    
    %add the single trial controls
    btm = h.panel_trial.InnerPosition(4) - 35;
    uilabel('Parent', h.panel_trial, ...
        'Text', 'Pre Stimulus Duration',...
        'Position', [10,btm, 180, 25]);
    
    btm = btm - 30;
    h.edit_prestim = uieditfield(h.panel_trial, 'numeric',...
        'Position', [10, btm, 180, 25],...
        'Value',100,...
        'Limits', [2,1500],...
        'RoundFractionalValue', 'on',...
        'ValueDisplayFormat', '%i ms',...
        'HorizontalAlignment', 'center');
    
    btm = btm - 30;
    uilabel('Parent', h.panel_trial, ...
        'Text', 'Post Stimulus Duration',...
        'Position', [10,btm, 180, 25]);
    
    btm = btm - 25;
    h.edit_pststim = uieditfield(h.panel_trial, 'numeric',...
        'Position', [10, btm, 180, 25],...
        'Value',600,...
        'Limits', [2,1500],...
        'RoundFractionalValue', 'on',...
        'ValueDisplayFormat', '%i ms',...
        'HorizontalAlignment', 'center');

    btm = btm - 40;
    h.button_trial_start = uibutton('Parent', h.panel_trial,...
        'Text', 'Start',...
        'Position',[20, btm, 160, 30],...
        'BackgroundColor',BUTTON_BG_COLOR,...
        'FontColor',BUTTON_FG_COLOR,...
        'ButtonPushedFcn',@callback_trial_start,...
        'FontSize', BUTTON_TXT_SIZE);
   
    btm = btm - 40;
    h.button_trial_reset = uibutton('Parent', h.panel_trial,...
        'Text', 'Reset ERP',...
        'Position',[20, btm, 160, 30],...
        'BackgroundColor',BUTTON_BG_COLOR,...
        'FontColor',BUTTON_FG_COLOR,...
        'ButtonPushedFcn',@callback_reset_erp,...
        'FontSize',BUTTON_TXT_SIZE);

    %save button panel
    h.panel_save = uipanel('Parent', h.grid,... 
        'Units', 'pixels', 'BorderType','line', ...
        'Enable', 'off');
    h.panel_save.Layout.Column = 1;
    h.panel_save.Layout.Row = 3;
    
    h.button_save = uibutton('Parent', h.panel_save,...
        'Text', 'Save',...
        'Position',[10, 160, 140, 30],...
        'BackgroundColor',BUTTON_BG_COLOR,...
        'FontColor',BUTTON_FG_COLOR,...
        'ButtonPushedFcn',@callback_save,...
        'FontSize', BUTTON_TXT_SIZE);
    
    h.lamp_saving = uilamp('Parent', h.panel_save,...
        'Position', [160,160, 30, 30],...
        'Color','r',...
        'Enable','on');

    uilabel('Parent', h.panel_save,...
        'Text', 'Data File ', ...
        'Position', [10,120,180,20]);

    h.edit_filename = uieditfield('Parent', h.panel_save,...
        'Value', '', ...
        'Position', [10,90,180,30],...
        'BackgroundColor','w',...
        'Editable', 'off',...
        'HorizontalAlignment','right');

    h.label_bytessaved = uilabel('Parent', h.panel_save,...
        'Text', 'Bytes Saved', ...
        'Position', [10,60,180,20]);
    
    h.edit_bytessaved = uieditfield('Parent', h.panel_save,...
        'Value', '', ...
        'Position', [10,30,180,30],...
        'BackgroundColor','w',...
        'Editable', 'off');
    
    %stop button panel
    h.panel_stop = uipanel('Parent', h.grid,... 
        'Units', 'pixels', 'BorderType','none');
    h.panel_stop.Layout.Column = 1;
    h.panel_stop.Layout.Row = 4;
   
    btm = h.panel_stop.Position(4) - 50; 
    h.button_stop = uibutton('Parent', h.panel_stop,...
        'Text', 'Stop',...
        'Position',[10, btm, 180, 40],...
        'BackgroundColor',BUTTON_BG_COLOR,...
        'FontColor',BUTTON_FG_COLOR,...
        'ButtonPushedFcn',@callback_stop,...
        'FontSize', BUTTON_TXT_SIZE); 

    h.axis_plot = uiaxes('Parent', h.grid);
    h.axis_plot.Layout.Column = 2;
    h.axis_plot.Layout.Row = [1 4];
    h.axis_plot.XLabel.String = 'Time (seconds)';
    h.axis_plot.XLabel.FontSize = 16;
    h.axis_plot.YLabel.String = 'Amplitude (uV)';
    h.axis_plot.YLabel.FontSize = 16;
    h.axis_plot.Toolbar.Visible = false;
    %h.axis_plot.XLimMode = 'manual';
    %h.axis_plot.YLimMode = 'manual';
    h.axis_plot.XLimitMethod = 'tight';
    h.axis_plot.Interactions = [];
    h.axis_plot.PickableParts = 'none';
    h.axis_plot.HitTest = 'off';
    
    %disableDefaultInteractivity(h.axis_plot);
    

    drawnow;
    delete(progress);

end
%**************************************************************************
%change the enabled function of the controls based on the current state
function toggleEnabledStatus(h, runState)
%if isRunning = 0 then everything is shutdown
if runState == 0
    isRunning = false;
    isPaused = false;
elseif runState == 1  %this is the paused state
    isRunning = false;
    isPaused = true;
else
    isRunning = true; %this is the running state
    isPaused = false;
end
    
    h.panel_cont.Enable = ~isRunning;
    h.panel_trial.Enable = ~isRunning;
   
    h.dropdown_devices.Enable = ~bitor(isPaused, isRunning);
    h.dropdown_ports.Enable = ~bitor(isPaused, isRunning);

    h.panel_save.Enable = isRunning;
     

end
%**************************************************************************
function processObjects = initializeContinuousPlot(p, processObjects)
    processObjects.Chart = BCI_Chart(p.sampleRate, 5, p.handles.axis_plot);
    processObjects.bytesSavedTarget = p.handles.edit_bytessaved;
   % processObjects.Filter = BCI_Filter(500, [58,62], 'stop');
end
%**************************************************************************
function processObjects = initializeERPPlot(p, processObjects)
    if ~isfield(processObjects, "ERPChart")
        processObjects.ERPChart = BCI_ERPplot(p.handles.axis_plot);
    end
    processObjects.ERPChart.refreshPlot;
  % processObjects.Filter = BCI_Filter(500, [0,40], 'low');
end
%**************************************************************************
function addPaths()
    f  = mfilename('fullpath');
    [fpath, fname, ~] = fileparts(f);
    newPaths{1} = sprintf('%s%sDevices', fpath, filesep);
    newPaths{2} = sprintf('%s%sExtensions', fpath, filesep);
    
    s       = pathsep;
    pathStr = [s, path, s];
    for ii = 1:length(newPaths)
        if ~contains(pathStr, [s, newPaths{ii}, s], 'IgnoreCase', ispc)
            addpath(newPaths{ii});
        end
    end
end
%**************************************************************************