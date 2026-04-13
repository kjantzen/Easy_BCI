%Returns a handle to an chart object for dynamically displaying 
%timeseries data in real-time.
%
%Usage:
%
%   obj = BYB_Chart(Fs) - creates a chart based on data
%   collected at the samplerate Fs.  The default is to create the
%   plotting axis in a new figure.  The default plot length is 3 seconds.
% 
%   obj = BYB_Chart(Fs, ChartLength) - specifies the length of the
%   chart in seconds.  The plot will begin scrolling once
%   ChartLength seconds of data are plotted.
%
%   obj = BYB_Chart(Fs, ChartLength, axis) - specifies the axis
%   into which the data should be plotted.
%
%   pass data to the functions UpdateChart method to add data to
%   the plot
%
% Methods
%
%   chart = chart.UpdateChart(eeg, event) - updates the chart adding the
%   data in eeg the EEG/EMG channel and adding the data in event to the event
%   channel.  The plot is automatically scaled to the range of the data.
%
%   chart = chart.UpdateChart(eeg, event, [min, max]) - optionally scales
%   the data between min and max.  
%
            %
classdef BCI_Chart < handle
    properties 
        scrolling       %flag to know whether the plot is srolling yet
        insertPoint     %the current place that data is being inserted into the plot
        plotHandle      %the handle to the actual plot

        displaySeconds  %the number of seconds to display in the plot
        displayPoints   %the number of points to display in the plot
        tAxis           %the current time axis to display
        sampleRate
        ax
    end
    properties (Access = private)
        eventHandle
    end
    methods
        function obj = BCI_Chart(SampleRate, ChartLength, plotAxis)
            arguments
                SampleRate (1,1) {mustBeInteger} = 250;
                ChartLength (1,1) {mustBeNumeric, mustBeNonnegative} = 3;
                plotAxis = [];
            end
            if isempty(plotAxis)
                f = figure;
                f.Color = 'w';
                plotAxis = axes(f);
            end
            obj.displaySeconds = ChartLength;
            obj.sampleRate = SampleRate;
            
            obj.scrolling = false;
            obj.insertPoint = 1;
            obj.displayPoints = obj.displaySeconds * SampleRate;
            obj.tAxis = (1:obj.displayPoints)./SampleRate;
            h1 = line(plotAxis, obj.tAxis, zeros(1,obj.displayPoints));
            obj.plotHandle =h1; %[h1, h2];
            obj.plotHandle(1).LineWidth = 1;
            
            obj.ax = plotAxis;
                
        end
        function obj = UpdateChart(obj, eegChunk, eventChunk,  plotRange)
            arguments
                obj
                eegChunk(1,:)
                eventChunk = []
                plotRange = []
            end
            %Adds data the the existing plot for this chart object
            %
            %obj = UpdateChart(d) - adds the timeseries data in d to the
            %existing data chart.
            %
            %obj = UpdateChart(d, scaleRange) - adjust the vertical scale
            %of the axis to the values in 1x2 double array scaleRange. Eg -
            %to scale between -1 and 2 pass [-1,2] as the scaleRange
            %parameter
            %
            %Input Parameters
            %   eegChunk - a timeseries of EEG data to add to the current
            %   plot
            %
            %   eventChunk  - an optional variable indicating timeing of
            %   event markers in the EEG singla.  If eventChunk is the same
            %   size as eegChunk, it is assumed that each sample in
            %   eventChunk matches the timing of each sample it eegChunk.
            %   Values of 0 indicate that no event is present and values
            %   other than 0 indicate the presence of an event. If
            %   evenChunk length does not match that of eegChunk, it is
            %   assumed that it is a set of n event indexes where n is the
            %   number of events (length of eventChunk) and the index is
            %   the location of the event in the current eegChunk.
          
            if isempty(plotRange)
                autoScale = true;
            else
                autoScale = false;
            end
            ln = length(eegChunk);
            lt = ln ./ obj.sampleRate;
            d = (obj.insertPoint + ln-1) - obj.displayPoints;

            if length(eventChunk) == ln
                trigLocations = obj.findTriggerOnsets(double(eventChunk));
                plotText = true;
            else
                trigLocations = eventChunk;
                plotText = false;
            end
            dataChunk = eegChunk;%[eegChunk;double(tr)];
            nchans = size(dataChunk,1);


            if obj.scrolling 
                %remove any trigger lines that are to the left of the
                %current window.
                trLine = findobj(obj.ax.Children, 'Tag', 'trigger');
                for ii = 1:length(trLine)
                    dt = trLine(ii).XData(1) - (obj.plotHandle(1).XData(1)+lt);
                    if (dt <= 0); delete(trLine(ii)); end
                end
                %remove any trigger text that is to the left of the current
                %window
                trLine = findobj(obj.ax.Children, 'Tag', 'trigtext');
                for ii = 1:length(trLine)
                    dt = trLine(ii).Position(1) - (obj.plotHandle(1).XData(1)+lt);
                    if (dt <= 0); delete(trLine(ii)); end
                end

                TrigMin = obj.plotHandle(1).XData(end);
                for ii = 1:nchans    
                    obj.plotHandle(ii).YData(1:obj.displayPoints-ln) = obj.plotHandle(ii).YData(ln+1:end);
                    obj.plotHandle(ii).YData(obj.displayPoints-ln+1:obj.displayPoints) = dataChunk(ii,:);
                    obj.plotHandle(ii).XData = obj.plotHandle(ii).XData + lt;
                    
                end             
                   
            elseif d<=0
                for ii = 1:nchans
                    obj.plotHandle(ii).YData(obj.insertPoint: obj.insertPoint + ln-1) = dataChunk(ii,:);
                    obj.plotHandle(ii).YData(obj.insertPoint + ln: end) = mean(dataChunk(ii,:));
                end
                TrigMin = obj.plotHandle(1). XData(obj.insertPoint);
                obj.insertPoint = obj.insertPoint + ln;
                
            else 
                
                TrigMin = obj.plotHandle(1).XData(end);
                for ii = 1:nchans
                    obj.plotHandle(ii).YData(1:obj.displayPoints-ln) = obj.plotHandle(ii).YData(d:obj.displayPoints-ln-1+d);
                    obj.plotHandle(ii).YData(obj.displayPoints-ln+1:obj.displayPoints) = dataChunk(ii,:);
                    obj.plotHandle(ii).XData = obj.plotHandle(ii).XData + (d./obj.sampleRate);
                end

                obj.scrolling = true;
            end
            
            if ~isempty(trigLocations)
                for ii = 1:length(trigLocations)
                    xp = TrigMin + (trigLocations(ii)/obj.sampleRate);
                    line(obj.ax, [xp, xp], obj.ax.YLim, 'Color', 'r', 'Tag', 'trigger');
                    if plotText
                        text(obj.ax, xp, obj.ax.YLim(2), num2str(eventChunk(trigLocations(ii)+1)), 'VerticalAlignment','top', 'Tag', 'trigtext');
                    end

                end
            end

            if ~autoScale
                obj.ax.YLim = plotRange;
            end
            drawnow();            
        end
    end
    methods (Access = private)
        function onsetOffset = findTriggerOnsets(obj, eventChunk)
            
            onsetOffset = find(diff(eventChunk));
            if ~isempty(onsetOffset)
                for ii = length(onsetOffset):-1:1
                    if eventChunk(onsetOffset(ii)+1)== 0
                        onsetOffset(ii) = [];
                    end
                end
            end

        end
    end
end
