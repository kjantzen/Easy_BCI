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
        Line      %the handle to the actual plot
    end
    properties (SetAccess = private)
        DisplaySeconds  %the number of seconds to display in the plot
        DisplayPoints   %the number of points to display in the plot
        TimeAxis           %the current time axis to display
        SampleRate
        Axes  
        LineData
        EventData
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
            obj.DisplaySeconds = ChartLength;
            obj.SampleRate = SampleRate;
            
            obj.DisplayPoints = obj.DisplaySeconds * SampleRate;
            tAxis = (1:obj.DisplayPoints)./SampleRate;
            obj.Line = line(plotAxis, tAxis, zeros(1,obj.DisplayPoints));
            obj.Line(1).LineWidth = 1;
            
            obj.Axes = plotAxis;

            %create circular data buffers.  One for the data and one for
            %the events.
            obj.DataBuffer = BCI_CircBuffer("SampleRate",SampleRate, "BufferSamples", obj.DisplayPoints);
            obj.EventBuffer = BCI_CircBuffer("SampleRate",SampleRate, "BufferSamples", obj.DisplayPoints);
                
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
                mx = max(obj.DataBuffer.Buffer);
                mn = min(obj.DataBuffer.Buffer);
                margin = (mx-mn) * .1;
                mx = mx + margin;
                mn = mn - margin;
                if (mx == 0 && mn == 0)
                    plotRange = [-1,1];
                else
                    plotRange = [mn,mx];
                end
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
            obj.Line.YData = obj.DataBuffer.Buffer;

            %update the time axis information data
            obj.Line.XData = obj.DataBuffer.TimeAxis;

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
                        obj.EventMarkerHandles(ii).XData = [tData(eventIndx(ii)),tData(eventIndx(ii))];
                        %obj.EventMarkerHandles(ii).Label = obj.EventBuffer.Buffer(eventIndx(ii));
                        obj.EventMarkerHandles(ii).Visible = true;
                    else
                        obj.EventMarkerHandles(ii) = line(obj.Axes, "XData", [tData(eventIndx(ii)), tData(eventIndx(ii))],...
                            'YData',plotRange, 'Color','r');
                        
                    end
                end

            else
                ii = 0;
            end

            if nMarkerHandles < 5
                %hide any extre xlines.  Hiding should be faster than deleting
                %an recreating later
                for jj = ii+1 : nMarkerHandles
                    obj.EventMarkerHandles(jj).Visible = false;
                end
            else
                for jj = nMarkerHandles:-1: ii+1
                    delete(obj.EventMarkerHandles(jj));
                    obj.EventMarkerHandles(jj) = [];
                end
            end

            if ~autoScale
                obj.Axes.YLim = plotRange;
            end
            drawnow();            

        end

        % getters for exposing data to the user
        function value = get.LineData(obj)
            value = obj.DataBuffer.Buffer;
        end
        function value = get.EventData(obj)
            value = obj.EventBuffer.Buffer;
        end
        function value = get.TimeAxis(obj)
            value = obj.DataBuffer.TimeAxis;
        end
    end
    % private methods
    methods (Access = private)
        function onsetOffset = findTriggerOnsets(~,eventChunk)
            onsetOffset = find(diff(eventChunk)>0)+1;
        end
    end
end
