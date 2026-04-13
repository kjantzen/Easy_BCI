classdef BCI_BarPlot
    % BCI_BARPLOT - Make and dynamically update a bar plot 
    %
    % obj = BCI_BarPlot() will create a trial buffer object using the
    % default settings (see below).  
    %
    % obj = BCI_TrialBuffer('Parameter', value,...) will set the specified
    % paramter when creating the object.
    %
    % Parameters:
    %   "axisHandle" a handle to the axis for creating the bar plot.  If
    %   not included, a new axes will be created.  A new figure will be
    %   created if there is not current figure.
    %
    %   "XData" values to plot along the x axis of the bar plot
    %
    %   "YData" values to plot along the y axis of the bar plot
    %
    % Properties
    %   ax - a handle to the axis passed to the constructor
    %
    %   Range - a 1 x 2 vector of values indicating the min and max y axis
    %   values
    %
    %   AutoRange - if true ignores the values in Range and automatically
    %   scales the axis
    %
    %  Bar - a (1,N) vector of handles to the bar chart objects (1 for each bar).  
    %  These handles can be used to directly access any bar properties (see
    %  Matlab bar function).
    %
    % METHODS
    %   SetYData(yData) - updates the current Y values with the ones passed
    %   in yData
    %   
    properties 
        ax
        Range = [0, 1];
        AutoRange = true;
        Bar = [];
    end
    methods
        function obj = BCI_BarPlot(options)
            arguments
                options.axisHandle (1,1) matlab.graphics.axis.Axes  = axes()
                options.XData  = [];
                options.YData (1,:) = [];
            end

            obj.ax = options.axisHandle;

            %validate and assign data;
            if isempty(options.YData) 
                options.YData = ones(1,4);
                options.XData = 1:length(options.YData);
            end
            if isempty(options.XData) || (length(options.XData) ~= length(options.YData))
                options.XData = 1:length(options.YData);
            end

            obj.Bar = bar(obj.ax, options.XData, options.YData);
        end
% *************************************************************************
        function obj = SetYData(obj, y)
            xdata = obj.Bar.XData;
            if length(xdata) ~= length(y)
                obj.Bar.XData = 1:length(y);
            end
            obj.Bar.YData = y;
            if obj.AutoRange
                obj.ax.YLimMode = 'Auto';
            else
                obj.ax.YLim = obj.Range;
            end
        end
 
    end
end
