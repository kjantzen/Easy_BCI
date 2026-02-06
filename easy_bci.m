%The description will be here.
%
% KJ Jantzen
%January 2023
%**************************************************************************
function easy_bci()
%main function that loads the parameters
%and builds the UI

    addPaths
    p.handles = buildUI;
    set(p.handles.fig, 'UserData', p);

end
%**************************************************************************
function p = initializeParameters(p, fig)
    %call this function whenever some key parameters list below changes

    %hard code these for now, but give the option to select them from a
    %user interface later
        
    p.serialPortName = p.handles.dropdown_port.Value;
    p.bufferDuration = p.handles.dropdown_buffdur.Value;
    p.sampleRate = 250;
    p.handlerName = p.handles.dropdown_handler.Value;
    p.DataHandler = str2func(p.handlerName);
    p.collectionMode = p.handles.dropdown_mode.Value;

    %create the spiker box object here
    %first delete any existing one that may exist
    if isfield(p, 'Device')
        delete(p.Device);
    end
    
    %assume it all goes OK
    p.ErrorInit = false;
    %select a device based on user input
    try
        p.Device = BNS_HBSpiker(p.serialPortName, p.bufferDuration);
        if (p.collectionMode == 0)
            p.Device.SetMode(BNS_HBSpikerModes.Continuous);
            p.Device.PacketReceivedCallback = p.DataHandler;

        else
            p.Device.SetMode(BNS_HBSpikerModes.SingleTrial);
            p.Device.TrialReceivedCallback = p.DataHandler;

        end
    
        %call the initialization version of the data handler, i.e. call it
        %without passing any data.
        p.Device.ProcessObjects = p.DataHandler(p);
        p.ErrorInit = p.Device.ProcessObjects.ErrorInit;
    catch ME
        BCI_Error(ME.message, ME.identifier);
        p.ErrorInit = true;
    end
end
% *************************************************************************
function hlist = getHandlerNames()

    [fpath, ~,~] = fileparts(mfilename('fullpath'));
    handlerPath = fullfile(fpath, 'Handlers','*.m');
    handlers = dir(handlerPath);
    if isempty(handlers)
        error('No handlers were found');
    end

    hlist{length(handlers)} = [];
    for ii = 1:length(handlers)
        hlist{ii} = handlers(ii).name(1:end-2);
    end
     
end
%rebuild the serial port menu each time to make sure it has a 
%current list of the available ports
function callback_fillPortMenu(src,~, h)

    src.Items = parsePorts(serialportlist('all'));

end
% *************************************************************************
function ports = parsePorts(portlist)
    %separates out the cu and tty ports on a mac. does nothing if on pc
    if ismac || isunix
        ports = portlist(contains(portlist, 'cu.'));
    else
        ports = portlist;
    end
end
%************************************************************************
function callback_initButton(src, ~, fig)

    %get the data structure from the figures user data
    p = fig.UserData;
    p = initializeParameters(p, fig); 
    
    if ~p.ErrorInit

        p.handles.button_start.Enable = 'on';
    
        %enable the stop button
        p.handles.button_stop.Enable = 'off';
        p.handles.collect_status.Text = 'Ready to Collect';
        p.handles.collect_status.FontColor = [0,.5,0];
    
        %update the display
        drawnow;
    end
    
    %save the data back to the figures user data
    fig.UserData = p;


end
% *************************************************************************
function callback_startButton(src,~, fig)
 
    %get the handle to the figure
  %  fig = ancestor(src, 'figure', 'toplevel');

    %get the data structure from the figures user data
    p = fig.UserData;

    %disable this button since we are toggling states
    src.Enable = 'off';
    p.handles.button_init.Enable = 'off';

    %turn on acquisition in the Device object
    try
        p.Device.Start();
    catch ME
        BCI_Error(Me.message, ME.identifier);
        src.Enable = 'on';
        p.handles.button_init.Enable = 'on';
    end

    %enable the stop button
    p.handles.button_stop.Enable = 'on';
    p.handles.collect_status.Text = 'Collecting...';
    p.handles.collect_status.FontColor = [0,.5,0];

    %update the display
    drawnow;

    %save the data back to the figures user data
    fig.UserData = p;

    
end
% *************************************************************************
function callback_stopButton(src,~, fig)
 
    %get a handle to the figure
  %  fig = ancestor(src, 'figure', 'toplevel');

    %get all the stored data from the figures user data storage
    p = fig.UserData;

    %toggle the state of this button to off
    src.Enable = 'off';

    %turn on the start button
    p.handles.button_start.Enable = 'on';
    p.handles.button_init.Enable = 'on';
    p.handles.collect_status.Text = 'Collection stopped';
    p.handles.collect_status.FontColor = 'r';

    %stop the data collection process
    p.Device.Stop();

    %update the display
    drawnow();
    
    %save the data again
    fig.UserData = p;
    
end
% *************************************************************************
function addPaths()

 thisPath = mfilename('fullpath');
 indx = strfind(thisPath, filesep);
 thisPath = thisPath(1:max(indx)-1);
 
 newFolder{1}  = fullfile(thisPath, 'Extensions');
 newFolder{2}  = fullfile(thisPath, 'Handlers');
 newFolder{3}  = fullfile(thisPath, "Devices");
 newFolder{4}  = fullfile(thisPath, "Tools");
 
 
 
 pathCell = strsplit(path, pathsep);
 for ii = 1:length(newFolder)
     if ispc  % Windows is not case-sensitive
      onPath = any(strcmpi(newFolder{ii}, pathCell));
    else
      onPath = any(strcmp(newFolder{ii}, pathCell));
     end
    if ~onPath
        addpath(newFolder{ii})
    end
 end
 

end
% *************************************************************************
function makeNewDataHandlerFromTemplate(scriptName)

scriptFileName = sprintf('%s.m', scriptName);

homePath = mfilename("fullpath");
[homePath,~,~] = fileparts(homePath);
newFile = fullfile(homePath, 'Handlers', scriptFileName);
if ~isempty(dir(newFile))
    msgbox(sprintf('The handler file %s already exists.\n Please choose a different name.', scriptName));
    return
end
fid = fopen(newFile, 'wt');
  

fprintf(fid, '%%Generic data handler template\n\n');
fprintf(fid, 'function outStruct = %s(inStruct, varargin)\n', scriptName);
fprintf(fid, '\tif nargin == 1\n');
fprintf(fid, '\t\toutStruct = initialize(inStruct);\n');
fprintf(fid, '\telse\n\t\toutStruct = analyze(inStruct, varargin{1}, varargin{2});\n\tend\nend\n');
fprintf(fid, '%%this function gets called when data is passed to the handler\n');
fprintf(fid, 'function p = analyze(p,data, event)\n\n\t%%your analysis code goes here\nend\n\n');
fprintf(fid, '%%this function gets called when the analyse process is initialized\n');
fprintf(fid, 'function p = initialize(p)\n\n%%your initialization code goes here\n\nend\n');

fclose(fid);
edit(newFile);

end
% *************************************************************************
function  callback_port_menu(src, evt, fig)
%    fig = ancestor(src, 'figure', 'toplevel');

    %get all the stored data from the figures user data storage
    p = fig.UserData;

    for ii = 1:length(p.handles.port_option)
        p.handles.port_option(ii).Checked = 'off';
    end
    src.Checked = 'on';

    if isfield(p, 'Device') && p.Device.Collecting
        callback_stopButton(src, evt, fig);
        p.handles.button_start.Enable = 'off';
    end
end
% *************************************************************************
function  callback_buffer_menu(src, evt)
    fig = ancestor(src, 'figure', 'toplevel');

    %get all the stored data from the figures user data storage
    p = fig.UserData;

    for ii = 1:length(p.handles.chunk_option)
        p.handles.chunk_option(ii).Checked = 'off';
    end
    src.Checked = 'on';

    if isfield(p, 'Device') && p.Device.Collecting
        callback_stopButton(src, evt);
        p.handles.button_start.Enable = 'off';
    end
end
% *************************************************************************
function callback_newHandlerFile(~, ~)
    scriptName  = inputdlg('Provde a unique name for the new data handler', 'New Handler');
    if ~isempty(scriptName{1})
        makeNewDataHandlerFromTemplate(scriptName{1});
    end    
end
% *************************************************************************
function callback_loadHandler(src,~)

    fig = ancestor(src, 'figure', 'toplevel');
    p = fig.UserData;
    hname = loadHandler(p);
    if ~isempty(hname)
        p.handlerName = hname;
    end
    fig.UserData = p;
end
% *************************************************************************
function setaot(figHandle)

    drawnow nocallbacks

    %suppres warnings related to java frames and exposing the hidden object
    %properties
    warning('off', 'MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');
    warning('off', 'MATLAB:structOnObject');      
    
    figProps = struct(figHandle);
    controller = figProps.Controller;      % Controller is a private hidden property of Figure
    controllerProps = struct(controller);
    container = struct(controllerProps.PlatformHost);  % Container is a private hidden property of FigureController
    win = container.CEF;   % CEF is a regular (public) hidden property of FigureContainer
    win.setAlwaysOnTop(true);   
end
%*************************************************************************
%% function to create the simple user interface
function h = buildUI()
      
    [schemePath, ~, ~] = fileparts(mfilename("fullpath"));
    guiScheme = load(fullfile(schemePath,'Tools','Scheme.mat'));

    sz = get(0, 'ScreenSize');
    buff_durations = [.05, .1, .25, .5, 1, 1.2];
    buff_dur_labels = {'50 ms', '100 ms', '250 ms', '500 ms', '1 sec', '1.2 sec'};

    %see if the figure already exists
    %if it does not create it and if it does clear it and start over
    existingFigureHandle = findall(0,'Tag', 'easyBCIController');
     
    if ~isempty(existingFigureHandle) 
        close(existingFigureHandle(1));
    end
    
    h.fig = uifigure;
    h.fig.WindowStyle = 'alwaysontop';
    h.fig.Resize = false;
    h.fig.Position = [0,50,200,sz(4)-70];
    drawnow;
    h.fig.Tag = 'easyBCIController';
    h.fig.Color = guiScheme.Window.BackgroundColor.Value;

    panelHeight = 160;
    ip = h.fig.InnerPosition;
    btm_pos = ip(4) - panelHeight;
    wdth = ip(3);

    h.panel_config = uipanel('parent', h.fig,...
        'Position', [5, btm_pos, wdth-10,panelHeight],...
        'Title','CONFIGURE DEVICE', 'FontSize',12,...
        'FontWeight','bold',...
        'BackgroundColor',guiScheme.Panel.BackgroundColor.Value,...
        'ForegroundColor',guiScheme.Panel.FontColor.Value,...
        'FontName', guiScheme.Panel.Font.Value,...
        'BorderType','none');
    
    btm_pos = panelHeight-40;
    uilabel('Parent', h.panel_config,...
        'Position', [10, btm_pos, wdth-20, 20],...
        'Text', 'communications port',...
        'FontSize', guiScheme.Label.FontSize.Value,...
        'FontName', guiScheme.Label.Font.Value,...
        'FontColor', guiScheme.Label.FontColor.Value,...
        'HorizontalAlignment','right');

    btm_pos = btm_pos - 23;
    h.dropdown_port = uidropdown('Parent',h.panel_config,...
        'Position', [5, btm_pos,  wdth-15, guiScheme.Dropdown.Height.Value],...
        'BackgroundColor',guiScheme.Dropdown.BackgroundColor.Value,...
        'FontColor',guiScheme.Dropdown.FontColor.Value,...
        'FontName', guiScheme.Dropdown.Font.Value,...
        'FontSize', guiScheme.Dropdown.FontSize.Value,...
        'Placeholder','serial port',...
        'Items',parsePorts(serialportlist("all")),...
        'DropDownOpeningFcn',{@callback_fillPortMenu,h.fig});

    btm_pos = btm_pos - 25;
    uilabel('Parent', h.panel_config,...
        'Position', [10, btm_pos, wdth-20, 20],...
        'Text', 'buffer duration',...
        'FontSize', guiScheme.Label.FontSize.Value,...
        'FontName', guiScheme.Label.Font.Value,...
        'FontColor', guiScheme.Label.FontColor.Value,...
        'HorizontalAlignment','right');

    btm_pos = btm_pos - 23;
    h.dropdown_buffdur = uidropdown('Parent',h.panel_config,...
        'Position', [5, btm_pos,  wdth-15, 25],...
        'BackgroundColor',guiScheme.Dropdown.BackgroundColor.Value,...
        'FontColor',guiScheme.Dropdown.FontColor.Value,...
        'FontName', guiScheme.Dropdown.Font.Value,...
        'FontSize', guiScheme.Dropdown.FontSize.Value,...
        'Placeholder','buffer duration',...
        'Items',buff_dur_labels,...
        'ItemsData', buff_durations);

    btm_pos = btm_pos - 25;
    uilabel('Parent', h.panel_config,...
        'Position', [10, btm_pos, wdth-20, 20],...
        'Text', 'collection mode',...
        'FontSize', guiScheme.Label.FontSize.Value,...
        'FontName', guiScheme.Label.Font.Value,...
        'FontColor', guiScheme.Label.FontColor.Value,...
        'HorizontalAlignment','right');

    btm_pos = btm_pos - 23;
    h.dropdown_mode = uidropdown('Parent',h.panel_config,...
        'Position', [5, btm_pos,  wdth-15, 25],...
        'BackgroundColor',guiScheme.Dropdown.BackgroundColor.Value,...
        'FontColor',guiScheme.Dropdown.FontColor.Value,...
        'FontName', guiScheme.Dropdown.Font.Value,...
        'FontSize', guiScheme.Dropdown.FontSize.Value,...
        'Placeholder','collection mode',...
        'Items',{'continuous', 'single trial'},...
        'ItemsData',[0,1]);
  
      % the handler panel
    panelHeight = 60;
    btm_pos = ip(4) - 240;

    h.panel_handler = uipanel('parent', h.fig,...
        'Position', [5, btm_pos, wdth-10,panelHeight],...
        'Title','DATA HANDLER', 'FontSize',12,...
        'FontWeight','bold',...
        'BackgroundColor',guiScheme.Panel.BackgroundColor.Value,...
        'ForegroundColor',guiScheme.Panel.FontColor.Value,...
        'FontName', guiScheme.Panel.Font.Value,...
        'BorderType','none')   ; 
  
    btm_pos = 5;
    h.dropdown_handler = uidropdown('Parent',h.panel_handler,...
        'Position', [5, btm_pos,  wdth-15, 25],...
        'BackgroundColor',guiScheme.Dropdown.BackgroundColor.Value,...
        'FontColor',guiScheme.Dropdown.FontColor.Value,...
        'FontName', guiScheme.Dropdown.Font.Value,...
        'FontSize', guiScheme.Dropdown.FontSize.Value,...
        'Placeholder','serial port',...
        'Items',getHandlerNames);
  
    %the control panel
    panelHeight = 150;
    btm_pos = ip(4) - 420;

    h.panel_control = uipanel('parent', h.fig,...
        'Position', [5, btm_pos, wdth-10,panelHeight],...
        'Title','CONTROL', 'FontSize',12,...
         'FontWeight','bold',...
        'BackgroundColor',guiScheme.Panel.BackgroundColor.Value,...
        'ForegroundColor',guiScheme.Panel.FontColor.Value,...
        'FontName', guiScheme.Panel.Font.Value,...
        'BorderType','none');
    
    h.button_init = uibutton('Parent', h.panel_control,...
        'Position', [10,85,wdth-25,guiScheme.Button.Height.Value],...
        'BackgroundColor',guiScheme.Button.BackgroundColor.Value,...
        'FontColor', guiScheme.Button.FontColor.Value, ...
        'FontSize', guiScheme.Button.FontSize.Value,...
        'Fontname', guiScheme.Button.Font.Value,...
        'Text','Initialize',...
        'ButtonPushedFcn',{@callback_initButton, h.fig});

    h.button_start = uibutton('Parent', h.panel_control,...
        'Position', [10,45,wdth-25,guiScheme.Button.Height.Value],...
      'BackgroundColor',guiScheme.Button.BackgroundColor.Value,...
        'FontColor', guiScheme.Button.FontColor.Value, ...
        'FontSize', guiScheme.Button.FontSize.Value,...
        'Fontname', guiScheme.Button.Font.Value,...
        'Text','Start',...
        'Enable', 'off',...
        'ButtonPushedFcn',{@callback_startButton, h.fig});
    
     h.button_stop = uibutton('Parent', h.panel_control,...
        'Position', [10,5,wdth-25,guiScheme.Button.Height.Value],...
      'BackgroundColor',guiScheme.Button.BackgroundColor.Value,...
        'FontColor', guiScheme.Button.FontColor.Value, ...
        'FontSize', guiScheme.Button.FontSize.Value,...
        'FontName', guiScheme.Button.Font.Value,...
        'Text','Stop',...
        'Enable', 'off',...
        'ButtonPushedFcn',{@callback_stopButton, h.fig});

      %the status panel
    panelHeight = 60;
    btm_pos = ip(4) - 510;

    h.panel_status = uipanel('parent', h.fig,...
        'Position', [5, btm_pos, wdth-10,panelHeight],...
        'Title','STATUS', 'FontSize',12,...
        'FontWeight','bold',...
        'BackgroundColor',guiScheme.Panel.BackgroundColor.Value,...
        'ForegroundColor',guiScheme.Panel.FontColor.Value,...
        'FontName', guiScheme.Panel.Font.Value,...
        'BorderType','none');
    
    h.collect_status = uilabel('Parent', h.panel_status,...
        'Text', 'No Device Initialized',...
       'FontSize', guiScheme.Label.FontSize.Value,...
        'FontName', guiScheme.Label.Font.Value,...
        'FontColor', guiScheme.Label.FontColor.Value,...
        'Position', [10,0,wdth-25,20],...
        'HorizontalAlignment', 'center',...
        'VerticalAlignment', 'center');
end

