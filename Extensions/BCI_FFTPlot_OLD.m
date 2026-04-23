%BCI_FFTPlot - plots the the FFT power of input data packets.
%
%USAGE
%
%   myFFT = BYB_FFT(SRate, BSec, Ax) - creates an instance of the BYB_FFT
%   plotting object for analysing data segments with sample rate SRate and
%   of duration BSec seconds.  Data will be plotted in the axis passed as
%   Ax.
%
%
classdef BCI_FFTPlot < handle
    properties 
        FFT         % a BCI_FFT object for handing FFT calculation
        PlotHandle  %the handle to the actual plot
        Axis        % a handle to the plotting axis
        Units       %contains a string describing the units of the data
    end
    methods
        function obj = BCI_FFTPlot(SampleRate, options)
            arguments
                SampleRate (1,1) {mustBeInteger} = 500;
                options.BufferSeconds (1,1) = 1;
                options.AxisHandle (1,1) matlab.graphics.axis.Axes  = axes()
            end
            
            obj.FFT = BCI_FFT(SampleRate,"BufferSeconds",options.BufferSeconds);
            obj.Axis = options.AxisHandle;
            obj.PlotHandle = line(obj.Axis, obj.FFT.fAxis, obj.FFT.FFTAmplitude);
            obj.PlotHandle.LineWidth = 1.5;
 
        end
        function obj = UpdateChart(obj, dataChunk, options)
            arguments
                obj
                dataChunk (1,:) {mustBeNumeric}
                options.FreqRange  = 'auto';
                options.PlotPower (1,1) {mustBeNumericOrLogical} = true;
                options.PlotLog (1,1) {mustBeNumericOrLogical} = false;
            end
            
            obj.FFT.FFT(dataChunk);
            if options.PlotPower
                obj.PlotHandle.YData = obj.FFT.FFTPower;
            else
                obj.PlotHandle.YData = obj.FFT.FFTAmplitude;
            end
            if options.PlotLog
                obj.Axis.YScale = 'log';
            else 
                obj.Axis.YScale = 'linear';
            end
            if isstring(options.FreqRange) || ischar(options.FreqRange)
                obj.Axis.XLimMode = options.FreqRange;
            else
                obj.Axis.XLim = options.FreqRange; 
            end
            drawnow();
          
        end
    end
end
