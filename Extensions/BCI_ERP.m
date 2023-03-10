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
classdef BCI_ERP
    properties 
        TrialCount  %how many trial in each bin
        ERP         %the actual erp
        TimePnts    %the x axis time values
        SRate
    end
    properties (Access=private)
        erpSum
        lpfilt
    end
    methods
        function obj = BCI_ERP(plotAxis)
            obj.ERP = [];
            obj.lpfilt = BCI_Filter(512,[0,50],"low");
        end
        function obj = UpdateERP(obj, trial, plotRange)
            
            if isempty(obj.TrialCount)
                obj.TrialCount = zeros(1,3);
                obj.erpSum = zeros(3, trial.samples);  
                obj.ERP = obj.erpSum;
                obj.TimePnts = trial.timePnts;
                obj.SRate = trial.sampleRate;


            end
            d = obj.lpfilt.filter(trial.EEG);
            bline = mean(d(1:trial.preSamp));
            d = d - bline;
            obj.TrialCount(trial.evt) = obj.TrialCount(trial.evt) + 1;
            obj.erpSum(trial.evt,:) = obj.erpSum(trial.evt,:) + d;
            obj.ERP(trial.evt,:) = obj.erpSum(trial.evt,:)./obj.TrialCount(trial.evt);
               
        end
    end
end
