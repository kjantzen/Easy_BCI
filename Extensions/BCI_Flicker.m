classdef BCI_Flicker < handle
% BCI_FICKER constructs a flicker stimulus object for use as the
% front end of a brain computer interface.
%
% obj = BCI_FLicker() creates a full screen presentation of the flicker
% stimuli presented at a size of 100x100 pixels
%
% The following parameters can be passed
%   'WindowPosition'=[left, right, width, height] - default fullscreen
%   'TargetSize'=[width, height] - default 100x100
%   'ScreenNumber'= screen - an integer indicating the screen to present
%      to.  The default is the primary display (0).
%   'TriggerPort'='comport' where comport is a string containing the name
%      of the port (e.g. 'Com3').
%   'TriggerValue'=value where value is an integer from 1 to 3 indicating
%       what value to write to the trigger port at the onset of stimulus
%       presenation.
%
% METHODS
%   obj.Play(duration) - plays the flicker stimulus for duration seconds
%
%   obj.PlayFeedback(Target, Duration) - shows a single target on screen for
%   duration seconds.  The target number shown is given by Target where:
%       1 = top
%       2 = right
%       3 = bottom
%       4 = left
%
%   f.Close - closes the window and deletes the objecta
%
    properties (SetAccess = private)
        Frequencies = [8.57, 10, 12, 15];
        Phases = [0,0,0,0];
        ActualFreqs
        WindowPosition
        TargetSize
        ScreenNumber
        TriggerPort
        TriggerValue
    end
    properties (Constant = true)
        RefreshRate = 60;
    end
    properties (Access = private)
        Frames;
        FramePattern
        FlickerTimeSeries
        ScreenTextures
        FeedbackTextures
        WinHandle
        MaxFrames
        Serial
        HasSerial = false;
    end
    methods

        function obj = BCI_Flicker(options)
        %constructor function for the class object
            arguments
                options.WindowPosition (1,4) {mustBeNumeric} = get(0, 'ScreenSize');
                options.TargetSize (1,2) {mustBeNumeric} = [100,100];
                options.ScreenNumber (1,1) {mustBeNumeric, mustBeInteger} = 0;
                options.TriggerPort (1,:) {mustBeText}  = 'none';
                options.TriggerValue  (1,1) {mustBeInteger, mustBeInRange(options.TriggerValue, 1, 3)} = 1;
            end

            obj.WindowPosition = options.WindowPosition;
            %input coordinates are in left, top, width and height - but
            %psychtoolbox wants then in absolute relative coordinates
            obj.WindowPosition(3) = obj.WindowPosition(1) + obj.WindowPosition(3);
            obj.WindowPosition(4) = obj.WindowPosition(2) + obj.WindowPosition(4);
            
            obj.TargetSize = options.TargetSize;
            obj.ScreenNumber = options.ScreenNumber;
            obj.TriggerValue = uint8(options.TriggerValue);
            obj.TriggerPort = options.TriggerPort;

            obj.FramePattern{1} = [1,1,1,0,0,0,0];
            obj.FramePattern{2} = [1,1,1,0,0,0];
            obj.FramePattern{3} = [1,1,0,0,0];
            obj.FramePattern{4} = [1,1,0,0];

            %calculate how many frames for a single cycle at each frequency
            %may make frequency and refresh rate variables in future
            obj.Frames = round(obj.RefreshRate./obj.Frequencies);

            %get the lowest common multiple so that long display periods
            %are no discontinuous.
            obj.MaxFrames = obj.myLCM;


            obj.FlickerTimeSeries = zeros(4,obj.MaxFrames );
            t = 1:obj.MaxFrames;
            t = t./obj.RefreshRate;

            %create a square wave of 1s (on) or 0s (off) at each frequency
            for ii = 1:4
                obj.FlickerTimeSeries(ii,:) = ((square(2*pi*obj.Frequencies(ii)*t+obj.Phases(ii))+1)./2);
           %     obj.FlickerTimeSeries(ii,:) = repmat(obj.FramePattern{ii},1,obj.MaxFrames /obj.Frames(ii));
            end

            %initialize a serial port object for triggering
            try
                if ~contains(obj.TriggerPort, 'none')
                    obj.Serial = serialport(obj.TriggerPort, 9600);
                    obj.HasSerial = true;
                end
            catch ME
                rethrow(ME);
            end

            %create the window and initialize the textures
            try         
                obj.WinHandle = Screen('OpenWindow', obj.ScreenNumber, [100,100,100], obj.WindowPosition);
                rect = Screen('rect', obj.WinHandle);
                %define the textures
                for ii = 1:16
                    obj.ScreenTextures(ii) = Screen('MakeTexture', obj.WinHandle, ...
                        obj.buildTextureLayout(ii-1, rect(3), ...
                        rect(4), obj.TargetSize(1), obj.TargetSize(2)));
                end
                
                %create screens with just he buttons on them for feedback
                for ii = 1:4
                    obj.FeedbackTextures(ii) = Screen('MakeTexture', obj.WinHandle, ...
                        obj.buildTextureLayout(2^(ii-1), rect(3), ...
                        rect(4), obj.TargetSize(1), obj.TargetSize(2)));
                end

                
                %get the frame rate and compute a corrected stim frequency
                ifi = Screen('GetFlipInterval', obj.WinHandle);
                obj.ActualFreqs = 1./ (obj.Frames.*ifi);

                Screen('DrawTexture', obj.WinHandle, obj.ScreenTextures(1));
                Screen('DrawingFinished', obj.WinHandle);
                Screen('Flip', obj.WinHandle);
            catch
                Screen('Close');
                Screen('CloseAll');
                psychrethrow(psychlasterror);
            
            end
  
        end
        % *****************************************************************
        function Play(obj, duration)
            arguments
                obj
                duration (1,1) {mustBeNumeric, mustBePositive};
            end

            try
                flipIndex = 1;
                Priority(1);
                offTime = GetSecs + duration;
    
                if obj.HasSerial
                    write(obj.Serial, obj.TriggerValue, 'uint8')
                end
                while GetSecs < offTime
                    textureValue = obj.bits2dec(obj.FlickerTimeSeries(:, flipIndex)) + 1;
                    Screen('DrawTexture', obj.WinHandle, obj.ScreenTextures(textureValue));
                    %Tell PTB no more drawing commands will be issued until the next flip
                    Screen('DrawingFinished', obj.WinHandle);
                    
                    % Flipping
                    Screen('Flip', obj.WinHandle);
                    flipIndex = flipIndex+1;
    
                    %Reset index at the end of freq matrix
                    if flipIndex > obj.MaxFrames 
                        flipIndex = 1;
                    end
                end
                
                %put the screen back to black
                Screen('DrawTexture', obj.WinHandle, obj.ScreenTextures(1));
                Screen('DrawingFinished', obj.WinHandle);
                Screen('Flip', obj.WinHandle);
                drawnow;
            catch
                Screen('Close');
                Screen('CloseAll');
                psychrethrow(psychlasterror);
            end
        end
        % *****************************************************************
        function PlayFeedback(obj, Target, Duration)
           
            arguments
                obj
                Target (1,1) {mustBeInteger, mustBeInRange(Target, 1,4)}
                Duration (1,1) {mustBeNumeric, mustBePositive}
            end
            
            Screen('DrawTexture', obj.WinHandle, obj.FeedbackTextures(Target))
            Screen('DrawingFinished', obj.WinHandle);
            Screen('Flip', obj.WinHandle);
            startTime = GetSecs;
            
            WaitSecs(Duration);
            
            Screen('DrawTexture', obj.WinHandle, obj.ScreenTextures(1))
            Screen('DrawingFinished', obj.WinHandle);
            Screen('Flip', obj.WinHandle);
            
        end
        % *****************************************************************
        function Close(obj)
            Screen('Close');
            Screen('CloseAll');
            delete(obj);
        end
    end
    %%
    methods (Access = private)
        % *****************************************************************
        function dec = bits2dec(~,x)
            dec = bin2dec(fliplr(dec2bin(x)'));
        end
        % *****************************************************************
        function layout = buildTextureLayout(~,textureNumber, width, height, targetwidth, targetheight)


            temp = width;
            width = height;
            height = temp;

            temp = targetwidth;
            targetwidth  = targetheight;
            targetheight = temp;

            drawFlags = dec2bin(textureNumber, 4);

            left = [1, (width-targetwidth)/2, width-targetwidth, (width-targetwidth)/2];
            bottom = [(height - targetheight)/2, height-targetheight,(height - targetheight)/2,1];

            layout = uint8(zeros(width, height));

            for jj = 1:4
                if strcmp(drawFlags(5-jj), '1')
                    layout(left(jj) : left(jj)+targetwidth-1, bottom(jj) : bottom(jj)+targetheight-1) = 255;
                end
            end

        end
        % *****************************************************************
        function output = myLCM(obj)

            numberArray = reshape(obj.Frames, 1, []);

            % prime factorization array
            for i = 1:size(numberArray,2)
                temp = factor(numberArray(i));

                for j = 1:size(temp,2)
                    output(i,j) = temp(1,j);
                end
            end

            % generate prime number list
            p = primes(max(max(output)));
            % prepare list of occurences of each prime number
            q = zeros(size(p));

            % generate the list of the maximum occurences of each prime number
            for i = 1:size(p,2)
                for j = 1:size(output,1)
                    temp = length(find(output(j,:) == p(i)));
                    if(temp > q(1,i))
                        q(1,i) = temp;
                    end
                end
            end

            %% the algorithm
            z = p.^q;

            output = 1;

            for i = 1:size(z,2)
                output = output*z(1,i);
            end
        end



    end

end
