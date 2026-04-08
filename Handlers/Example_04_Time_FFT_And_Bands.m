% Example of a basic easy bci data handler 
%The main landing function is a wrapper to allow for selection of the
%constructor or the data callback
function outStruct = FFT_Bands_Example(inStruct, varargin)
	if nargin == 1
		outStruct = initialize(inStruct);
	else
		outStruct = analyze(inStruct, varargin{1}, varargin{2});
	end
end

% **************************************************************************
% this function gets called when data is passed to the handler
function p = analyze(obj,p,data)
   p.EEGChart.UpdateChart(data.EEG, data.Event);
   p.FFTChart.UpdateChart(data.EEG); 
   p.BarChart.SetYData(p.FFTChart.FFT.Bins);

end

% **************************************************************************
% this function gets called once when the analyse process is initialized
function p = initialize(p)

    TAG = 'FFT TIME FREQ & BANDS';
    SAMPLERATE = 250;

    %check to see if the figure already exists
    existingFigure = findobj('Tag', TAG);
    if ~isempty(existingFigure)
        % if it does assign clear any existing plots and assign it to the
        % variable we will use to access it later
        p.handles.outputFigure = existingFigure(1);
        clf(p.handles.outputFigure);
    else
        %if it does not, create a new one
        %create a new figure to hold all the plots etc
        p.handles.outputFigure = figure('Position',[200,200,1000,1000]);
        p.handles.outputFigure.Name  = 'Simple FFT Bands example';
        p.handles.outputFigure.Tag = TAG;
        % any other configuration of the figure goes here
    end

    %create an axes to hold the time plot
    for ii = 1:3
        axh(ii) = subplot(3,1,ii);
    
        %configure it to look how we want
        axh(ii).FontSize = 14;
        axh(ii).XLimitMethod = 'tight';
        if ii ==1
            axh(ii).XLabel.String = 'Time (s)';
        elseif ii == 2
            axh(ii).XLabel.String = 'Frequency';
        else 
            axh(ii).XLabel.String = 'Frequency Bin';
        end
        axh(ii).YLabel.String = 'Power (uV^2)';
        
    
        %these settings are helpful because they keep mouse movement from
        %interfering with the plotting.
        axh(ii).Interactions = [];
        axh(ii).PickableParts = 'none';
        axh(ii).HitTest = 'off';
    end

    p.EEGChart = BCI_Chart(SAMPLERATE, 1, axh(1));
    %initialize the part object and save it in a variable called Chart that
    %is part of the structure p that is returned to the calling function
    p.FFTChart = BCI_FFTPlot_NEW(SAMPLERATE, "BufferSeconds", 2, "axisHandle", axh(2));
    p.BarChart = BCI_BarPlot("axisHandle",axh(3), 'YData', 1:6, 'XData', p.FFTChart.FFT.FreqBinNames);
    p.BarChart.AutoRange = false;
    p.BarChart.Range = [0, 4];


    axh(3).YLabel.String = 'Mean Power (uV^2)';
    axh(3).FontSize = 14;
    axh(3).XLabel.String = 'Frequency Bands';
end
