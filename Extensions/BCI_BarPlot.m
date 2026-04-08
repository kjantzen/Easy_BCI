
classdef BCI_BarPlot
    properties 
        ax
        Range = [0, 1];
        AutoRange = true;
        Value = 0;
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
