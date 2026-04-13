classdef BCI_TrialBuffer < handle
    % BCI_TRIALBUFFER - creates a buffer object for accumulating trial
    % samples from smaller data packets
    %
    % obj = BCI_TrialBuffer() will create a trial buffer object using the
    % default settings (see below).  
    %
    % obj = BCI_TrialBuffer('Parameter'=value,...) will set the specified
    % paramter when creating the object.
    %
    % Parameters:
    %   'TrialDuration'=duration sets the length of the trial buffer to 
    %       duration seconds.
    %   'TrialSamples'=samples sets the number of samples to collect in the
    %       trial buffer.  When both TrialDuration and TrialSamples is
    %       provided, TrialSamples will take precedence.
    %   'WaitForTrigger'=(true/false) if true, the buffer will only start
    %      adding data to the buffer if TriggerValue is detected on the event
    %       channel.
    %   'TriggerValue'=value. If WaitForTrigger is true, data will only
    %       start being added to the buffer when the the sprcified value is detected
    %       in the event channel.  TriggerValue can be:
    %       0 any trigger will start recording
    %       1 
    %       2
    %       3
    %
    properties (SetAccess = private)
        TrialDuration     %the length of the trial in seconds
        TrialSamples    %the number of samples in the buffer
        SampleRate = 500 %rate at which the data are sampled
        CurrentSamples = 0 %keeps track of the current samples in the trial
        HasCompleteTrial = false;
        WaitForTrigger;
        TriggerValue;
    end
    properties (Access = private)
        TrialBuffer   %the main circular buffer
    end
    methods
        function obj = BCI_TrialBuffer(options)
        % constructor for the class object
            arguments
                options.Duration (1,1) {mustBeNumeric, mustBePositive} = 1;
                options.Samples (1,1) {mustBeInteger} = 0;
                options.WaitForTrigger (1,1) {mustBeNumericOrLogical, mustBeInRange(options.WaitForTrigger, 0, 1)} = 1;
                options.TriggerValue (1,1) {mustBeInteger, mustBeInRange(options.TriggerValue, 0, 3)} = 1
            end

            if options.Samples > 0
                obj.TrialSamples = options.Samples;
            else
                obj.TrialSamples = round(options.Duration * obj.SampleRate);
            end

            obj.TrialDuration = obj.TrialSamples/obj.SampleRate;
            obj.TrialBuffer = zeros(2, obj.TrialSamples);
            obj.WaitForTrigger = options.WaitForTrigger;
            obj.TriggerValue = options.TriggerValue;
            
        end
        % ****************************************************************
        function AddPacket(obj,packet)
        % ADDPACKET adds a new chunk of data to the trial buffer
        %
        % obj.AddPacket(packet) - adds data in the data packet to the trial
        % buffer.  
        % 
        % If the trial buffer is empty (has a new trial) and the
        % WaitForTrigger flag is true, AddPacket will check the
        % packet.Event vector for the first instance of the trigger specified
        % by obj.TriggerValue.  If obj.TriggerValue is found the data will
        % be added starting at the sample at which it is found and extending
        % to the end of the packet.  If obj.TriggerValue is not found, no
        % data are added.
        % 
        % Once the trial buffer is full the obj.HasCompleteTrial will be
        % set to true (1).  Trying to save data to the full Trial Buffer
        % will generate an error.  Use the obj.ReadTrial method to clear
        % the full Trial Buffer before saving more samples.
        %

            %only collect a trial if the previous trial has been read
            if obj.HasCompleteTrial
                error('A new trial cannot be created until the buffer is emptied!');
            end

            % if there is no data currently in the trial, wait for an event
            % marker
            if obj.CurrentSamples == 0  && obj.WaitForTrigger
                if obj.TriggerValue == 0
                    trigIndx = find(packet.Event>0, 1, 'first');
                else
                    trigIndx = find(packet.Event==obj.TriggerValue, 1, 'first');
                end
                %jump out if there is not trigger
                if isempty(trigIndx)
                    return
                end
                d = packet.EEG(trigIndx:end);
                e = packet.Event(trigIndx:end);
                pnts = packet.samples - trigIndx + 1;
            else
                d = packet.EEG;
                e = packet.Event;
                samplesRemaining = obj.TrialSamples - obj.CurrentSamples;
                if samplesRemaining < packet.samples
                    pnts = samplesRemaining;
                else
                    pnts = packet.samples;
                end
            end

            obj.TrialBuffer(1,obj.CurrentSamples+1:obj.CurrentSamples+pnts) = d(1:pnts);
            obj.TrialBuffer(2,obj.CurrentSamples+1:obj.CurrentSamples+pnts) = e(1:pnts);
       
            obj.CurrentSamples = obj.CurrentSamples + pnts;
            if obj.CurrentSamples >= obj.TrialSamples
                obj.HasCompleteTrial = true;
            end

        end
        % *****************************************************************
        function trial = ReadTrial(obj)
        % READTRIAL - returns a complete trial from the trial
        % buffer
        %
        % trial = obj.ReadTrial will return the completed trial in the variable 
        % trial.  Trial will be a 2 x N double array where N is the number
        % of samples in the trial (see obj.TrialSamples).  The first
        % dimension of trial contains the EEG data and the second dimension
        % contains the Event marker data.
        %
        % Successfully calling ReadTrial will reset the trial buffer to
        % allow for collection of the next trial.
        %
        % Trying to call ReadTrial before the trial has been fully collected 
        % will generate an error.
        %
        % The obj.HasCompleteTrial flag to will be set to 1 (true) when a
        % completed trial is available.
        % 
            if ~obj.HasCompleteTrial
                error('The trial buffer is not full yet!');
            end
            trial = obj.TrialBuffer;
            obj.CurrentSamples = 0;
            obj.HasCompleteTrial = false;

        end
   
    end
    
end
