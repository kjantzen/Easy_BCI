%Generic data handler template
function outStruct = heartBeat(inStruct, varargin)
    if nargin == 1
        outStruct = initialize(inStruct);
    else
        outStruct = analyze(inStruct, varargin{1}, varargin{2});
    end
end
%this function gets called when data is passed to the handler
function p = analyze(~, p, dStruct)

    
    peaks = [];
    data = dStruct.EEG;
    data = (data.^2)./(600^2); %square the data and scale it to a max of just over 1.
    p.PeakDetect = p.PeakDetect.Detect(data); %find peaks
    if p.PeakDetect.NPeaks > 0
        peaks = [p.PeakDetect.Peaks.index];
        for ii = 1: p.PeakDetect.NPeaks
            p.HBeatIndex(1:end-1) = p.HBeatIndex(2:end);
            p.HBeatIndex(end) = p.PeakDetect.Peaks(ii).absindex;
        end
    end
   
    p.Chart =  p.Chart.UpdateChart(dStruct.EEG, [], [-800, 800]);
    p.ProcessedChart = p.ProcessedChart.UpdateChart(data, peaks, [-.1, 2]);

    %calculate the RRInterval for the 60 samples
    RRInterval = diff(p.HBeatIndex)./p.sampleRate;

    %here is where it could be cleaned up if we wanted to get an NN
    HR = round( 60 / (mean(RRInterval)));
    HRV = round(std(RRInterval * 1000));
    p.handles.HR.Text = sprintf('%i BPM', HR);
    p.handles.HRV.Text = sprintf('%i msec.', HRV);
end

%this function gets called when the analyse process is initialized
function p = initialize(p)

    %create a figure for showing stuff
    existingFigure = findall(0,'Type', 'figure', 'Name', 'Example of heart beat recordings');
    if ~isempty(existingFigure)
        p.handles.outputFigure = existingFigure(1);
        clf(p.handles.outputFigure);
    else
        %create a new figure to hold all the plots etc
        p.handles.outputFigure = uifigure('Position',[400,400,1000,600]);
        %name it so we can recognize it later if the software is rerun
        p.handles.outputFigure.Name  = 'Example of heart beat recordings';
    end
    
    %create an axis for plotting the ACG
   
    ax1 = uiaxes(p.handles.outputFigure, 'Position', [10,10,700,260]);
    ax1.XLabel.String = 'Time (s)';
    ax1.YLabel.String = 'Amplitude (mV)';
    ax1.Title.String = 'Electrocardiogram';
    ax1.XLimitMethod = 'tight';
    ax1.Interactions = [];
    ax1.HitTest = false;
    ax1.PickableParts = 'none';


    ax2 = uiaxes(p.handles.outputFigure, 'Position', [10,300,700,260]);
    ax2.XLabel.String = 'Time (s)';
    ax2.YLabel.String = 'Amplitude (mV)';
    ax2.Title.String = 'Electrocardiogram';
    ax2.XLimitMethod = 'tight';
    ax2.Interactions = [];
    ax2.HitTest = false;
    ax2.PickableParts = 'none';

    uilabel('Parent', p.handles.outputFigure,...
        'Position', [750, 450, 200, 20],...
        'Text', 'Heart Rate (R-R Interval)')

    p.handles.HR = uilabel('Parent', p.handles.outputFigure,...
        'Position', [750, 400, 200, 40],...
        'Text', 'measuring...', ...
        'FontSize', 24);

    uilabel('Parent', p.handles.outputFigure,...
        'Position', [750, 300, 200, 20],...
        'Text', 'Heart Rate Variability (SDRR)')

    p.handles.HRV = uilabel('Parent', p.handles.outputFigure,...
        'Position', [750, 250, 200, 40],...
        'Text', 'measuring...',...
        'FontSize', 24);
    
    
    %create a chart oobject that uses the axis
    p.Chart = BCI_Chart(p.sampleRate,5, ax1);
    p.ProcessedChart = BCI_Chart(p.sampleRate,5, ax2);

    %create a peak detection object
    p.PeakDetect = BCI_Peaks("AmpThreshold",.5, "SmoothPoints",5 ...
        , "WidthThreshold",5, "AdjustThreshold",true, "SearchAcrossChunks",true);
    %create a lowpass filter
    p.BPFilt = BCI_Filter(p.sampleRate, [0, 20], 'low');
        
    %initialize a variable to hold information about when a peak occured
    p.HBeatIndex = zeros(1,30); %average 30 heart beasts to get an average

end
