classdef BCI_Filter < handle
% BCI_FILTER() creates a filter object for use with the easy_bci toolbox
% 
% obj = BCI_Filter(SR, cutoff, type) creates a BCI_Filter object that will
% filter data with sample rate SR within the frequency range provided in
% cuttoff.  Cuttoff is a 2 elemect vector in the form [low, high] where log
% is the lower edge of the fequency cuttoff and high is the higher edge of
% the frequency cuttoff.  The filter type specifies the type of filter
% which can be one of 'low' (lowpass filter), 'high' (highpass filter), 
% 'stop' (band stop or notch filter), 'bandpass' (bandpass filter - default).
%
% Although Cuttoff must always be a 2 element numeric vector both values 
% may not be used depending on the filter type.  Spefically, wHen creating 
% a high pass filter (type='high') only the low edge of teh filter is 
% required, so Cuttoff(2) is ignored. When creating a low pass filter 
% (type='low'), only the high edge of the filter isrequired to Cuttoff(1)
% is ignored.
% 
% Additional Parameters Name.Value pairs
% 
% 'Window' , (true/false) - if true, a tukey window will be applied to the
%  data before it is filtered. Default = true
%
% 'Continuous', (true/false) - if true, each data segment passed should be
% considered as continuous with the previous segment.  In this case the
% state of the previous filter will be applied to the current filter to
% avoid filter effects associated with abrupt transients due to non-zero
% onsets and offsets.  Default = false
%
% NOTE - Continuous = true precludes the use of windowing and will override
% the settings of Window.
%
% Methods
%
% dataOut = obj.Filter(dataIn) - returns a fitlered version of the [1xn]
% point numeric vector
%
% Filter order is deteremined automatically 

    properties (SetAccess = private)
        Cuttoff
        FiltOrder
        SampleRate
        b
        a
        z
        Window
        Continuous
    end
    methods 
        function obj = BCI_Filter(SampleRate, Cuttoff, Type, options)

            arguments
                SampleRate (1,1) {mustBeInteger, mustBePositive}
                Cuttoff (1,2) {mustBeNumeric}
                Type {mustBeText}
                options.Window (1,1) {mustBeNumericOrLogical, ...
                    mustBeInRange(options.Window, 0,1)} = true;
                options.Continuous (1,1) {mustBeNumericOrLogical, ...
                    mustBeInRange(options.Continuous, 0,1)} = false;
            end
           obj.SampleRate = SampleRate;
           obj.Window = options.Window;
           obj.Continuous = options.Continuous;
    
            obj.Cuttoff = Cuttoff;
            Fn = SampleRate /2 ; %calculate the nyquist
            Wp = obj.Cuttoff/Fn;    %calculate the normalized cuttoff
            
            if obj.Cuttoff(1) > 0
                obj.FiltOrder = 3*fix(SampleRate/Cuttoff(1));
            elseif obj.Cuttoff(2) > 0
                 obj.FiltOrder = 3*fix(SampleRate/Cuttoff(2));
            else    
                 obj.FiltOrder = 15;
            end
            
            if obj.FiltOrder < 15
                obj.FiltOrder = 15;
            end
          
            
            switch lower(Type)
                case 'high'
                    Wp = Wp(1);
                case 'low'
                    Wp = Wp(2);
            end
            
            %[obj.b,obj.a] = butter(obj.FiltOrder,Wp,Type);
            [obj.b,obj.a] = fir1(obj.FiltOrder,Wp,Type);
            obj.z = zeros(obj.FiltOrder,1); 

        end
        % ****************************************************************
        function dataOut = filter(obj, dataIn)
            %remove the mean if not in continuous mode
            if ~obj.Continuous
                m = mean(dataIn);
                dataIn = dataIn - m;
            end

            if obj.Window && ~obj.Continuous
                win = hamming(length(dataIn));
                dataIn = dataIn.*win';
                obj.z = zeros(obj.FiltOrder, 1); %set to zero so they have no impact
            end
            %dataOut = filtfilt(obj.b, obj.a, dataIn);
            [dataOut, obj.z] = filter(obj.b,obj.a,dataIn, obj.z); 
            
        end
    end
end
