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
        EventMarkerHandles = gobjects(0);
        DataBuffer
        EventBuffer
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
            
            %obj.scrolling = false;
            %obj.insertPoint = 1;
            obj.displayPoints = obj.displaySeconds * SampleRate;
            obj.tAxis = (1:obj.displayPoints)./SampleRate;
            h1 = line(plotAxis, obj.tAxis, zeros(1,obj.displayPoints));
            obj.plotHandle =h1; %[h1, h2];
            obj.plotHandle(1).LineWidth = 1;
            
            obj.ax = plotAxis;

            %create circular data buffers.  One for the data and one for
            %the events.
            obj.DataBuffer = BCI_CircBuffer("SampleRate",SampleRate, "BufferSamples", obj.displayPoints);
            obj.EventBuffer = BCI_CircBuffer("SampleRate",SampleRate, "BufferSamples", obj.displayPoints);
                
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
            
            ln = length(eegChunk); %length of new data in samples

            %check if the event array is the same length as the data array
            if length(eventChunk) == ln
                %if yes we assume that the event array is a time signal and
                %convert them to indexes of onsets
                eventChunk = obj.findTriggerOnsets(double(eventChunk));
            end
            
            %then we convert it to a time signal the same size as the eeg
            %signal and populate with the events
            trigLocations = zeros(1,ln);
            trigLocations(eventChunk(eventChunk>0)) = 1;
           
            %now we manually insert any events that have negative indexes.
            %Negative indexes indicate that the event was in a previous
            %data chunk which can happen with the peak picking algorithm
            offset = obj.EventBuffer.WritePosition-1;
            for ii = eventChunk(eventChunk<=0)
                obj.EventBuffer.SetValue(offset + ii, 1);
            end
            
            %add incoming data to the circular buffers
            obj.DataBuffer.WriteBuffer(eegChunk);
            obj.EventBuffer.WriteBuffer(trigLocations);
            
            %update the plot y data with the new ordered data
            obj.plotHandle.YData = obj.DataBuffer.Buffer;

            %update the time axis information data
            obj.plotHandle.XData = obj.DataBuffer.TimeAxis;

            %update the event markers
            eventIndx =  find(obj.EventBuffer.Buffer);
            tData = obj.EventBuffer.TimeAxis;

            if isempty(obj.EventMarkerHandles)
                nMarkerHandles = 0;
            else
                nMarkerHandles = length(obj.EventMarkerHandles);
            end

            %plot vertical lines by either reusing old handles or creating
            %new ones. 
            if ~isempty(eventIndx)
                for ii = 1:length(eventIndx)
                    if ii <= nMarkerHandles
                        obj.EventMarkerHandles(ii).Value = tData(eventIndx(ii));
                        obj.EventMarkerHandles(ii).Label = obj.EventBuffer.Buffer(eventIndx(ii));
                        obj.EventMarkerHandles(ii).Visible = true;
                    else
                        obj.EventMarkerHandles(ii) = xline(obj.ax, tData(eventIndx(ii)),'Color','r','Label', obj.EventBuffer.Buffer(eventIndx(ii)));
                    end
                end

            else
                ii = 0;
            end
            %hide any extre xlines.  Hiding should be faster than deleting
            %an recreating later
            for jj = ii+1 : nMarkerHandles
                obj.EventMarkerHandles(jj).Visible = false;
            end

            if ~autoScale
                obj.ax.YLim = plotRange;
            end
            drawnow();            

        end
    end
    methods (Access = private)
        function onsetOffset = findTriggerOnsets(~,eventChunk)
            
            onsetOffset = find(diff(eventChunk)>0)+1;
%            if ~isempty(onsetOffset)
%                for ii = length(onsetOffset):-1:1
%                    if eventChunk(onsetOffset(ii)+1)== 0
%                        onsetOffset(ii) = [];
%                    end
%                end
%            end

        end
    end
end
