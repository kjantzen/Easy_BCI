% Example of a basic easy bci data handler 
%The main landing funciton is a wrapper to allow for selection of the
%constructor or the data callback
function outStruct = SingleChart_Example(inStruct, varargin)
	if nargin == 1
		outStruct = initialize(inStruct);
	else
		outStruct = analyze(inStruct, varargin{1}, varargin{2});
	end
end
% **************************************************************************
% this function gets called when data is passed to the handler
function p = analyze(obj,p,data)
   %add the current data to the chart and scale between +- 650 uV
   p.Chart =  p.Chart.UpdateChart(data.EEG, data.Event, [-700, 700]);
end

% **************************************************************************
% this function gets called when the analyse process is initialized
function p = initialize(p)

    %check to see if the figure already exists
    existingFigure = findobj('Tag', 'Simple chart');
    
    if ~isempty(existingFigure)
        % if it does assign clear any existing plots and assign it to the
        % variable we will use to access it later
        p.handles.outputFigure = existingFigure(1);
        clf(p.handles.outputFigure);
    else
        %if it does not, create a new one
        %create a new figure to hold all the plots etc
        p.handles.outputFigure = figure('Position',[200,200,1000,500]);
        p.handles.outputFigure.Name  = 'Simple scrolling chart example';
        p.handles.outputFigure.Tag = 'Simple chart';
        % any other configuration of the figure goes here
    end

    %create an axes to hold the plot
    axh = axes(p.handles.outputFigure);

    %configure it to look how we want
    axh.FontSize = 14;
    axh.XLimitMethod = 'tight';
    axh.XLabel.String = 'Time (s)';
    axh.YLabel.String = 'Amplitude (uV)';
    

    %these settings are helpful because they keep mouse movement from
    %interfering with the plotting.
    axh.Interactions = [];
    axh.PickableParts = 'none';
    axh.HitTest = 'off';

    %define an onscreen plot length of 5 seconds
    chartDisplayLength = 5;
    %initialize the part object and save it in a variable called Chart that
    %is part of the structure p that is returned to the calling function
    p.Chart = BCI_Chart(p.sampleRate,chartDisplayLength, axh);

end
