classdef BCI_CircBuffer < handle
    properties (SetAccess = private)
        SampleRate = 250;
        BufferDuration
        BufferLen
        Buffer
        TimeAxis
        WritePosition = 1;
    end
    methods 
        function obj = BCI_CircBuffer(opts)
            arguments
                opts.SampleRate (1,1) {mustBeInteger, mustBeNonnegative} = 250;
                opts.BufferDuration (1,1) {mustBeNumeric, mustBeNonnegative} = 1;
                opts.BufferSamples (1,1) {mustBeInteger, mustBeNonnegative} = 0;
            end

            obj.SampleRate = opts.SampleRate;

            if opts.BufferSamples > 0
                obj.BufferLen = opts.BufferSamples;
                obj.BufferDuration = obj.BufferLen / obj.SampleRate;
            else
                obj.BufferDuration = opts.BufferDuration;
                obj.BufferLen = round(obj.BufferDuration * obj.SampleRate);
            end
            
            obj.TimeAxis = (1:obj.BufferLen)./obj.SampleRate;
            %create the buffer
            obj.Buffer = zeros(1,obj.BufferLen);
            obj.WritePosition = 1;
        end
    % *********************************************************************
    function WriteBuffer(obj, data)
            arguments 
                obj
                data (1,:) {mustBeNumeric, mustBeNonempty}
            end

            startPos = obj.WritePosition;
            endPos = startPos + length(data)-1;

            shiftLen = obj.BufferLen - endPos;
            if shiftLen < 0
                startPos = startPos + shiftLen;
                endPos = endPos  + shiftLen;
                obj.TimeAxis = obj.TimeAxis + (abs(shiftLen)/obj.SampleRate); 
            else
                shiftLen = 0;
            end

            obj.Buffer= circshift(obj.Buffer, shiftLen);
            obj.Buffer(startPos:endPos) = data;
            obj.WritePosition = endPos + 1;

    end
    function SetValue(obj, indx, value)
        arguments
            obj
            indx (1,1) {mustBeInteger, mustBePositive, mustBeNonempty}
            value (1,1) {mustBeNumeric, mustBeNonempty}
        end
        if indx > obj.BufferLen
            error("The index exceeds the buffer length ");
        end
        obj.Buffer(indx) = value;
    end

    % *********************************************************************
        function b = get.Buffer(obj)
            b  = obj.Buffer;
        end
    end
 end