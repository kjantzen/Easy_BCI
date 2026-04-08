% Returns a handle to an BCI_FFT object for calculating the fourier
% transform on time series data in realtime
%
% The BCI_FFT object maintains a circular buffer of time domain data on
% which it calculates and stores the onesided power spectrum and the power
% in standard EEG frequency ranges (delta, theta, alpha, beta, gamma).
%
%
%
%Usage:
%
%   obj = BCI_FFT(Fs) - returns a handle to a new BCI_FFT object
%   that will compute the FFT on data collectd at the samplerate Fs.  
% 
%   obj = BYB_Chart(Fs, "BufferDuration", n) - specifies the length of the
%   data buffer on which to compute the fft (in seconds). New data 
%   passed to the BCI_FFT object is placed at the end of a circular buffer.
%   The FFT is always computed on the entire buffer.  The default buffer
%   length is 1.
%
% Methods
%
%   FFT(dataChunk) - adds the new data chunk to the circular buffer and
%   calculates the one sided FFT and power in individual frequency bins.  
%   The results of the update are accesed by probing the objects properties
%   (see Properties below)
%
% Properties (read only)
%   BufferPoints:   The number of sample points in the circular buffer
%   BufferSeconds:  The duration of the sample buffer in seconds
%   SampleRate:     The sample rate at which samples were acquired
%   DataBuffer:     The circular buffer
%   FFTAmplitude:   The onesided power spectrum.  Update with each buffer
%   update.
%   FFTPoints:      Number of frequencies in FFTAmplitude
%   Nyquist:        Maximum frequency that can be represented
%   Bins            The summed power in each standard frequency bin
%   fAxis           The frequency associated with each FFT sample.
%   FreqBinNames    A cell array of strings returning the standard name for
%                   the calculated frequency bins
%   FreqBinRange    A 2 x 6 array with the boundaries for calculating the
%                   power in the standard frequency bins
% 
classdef BCI_FFT < handle
    properties (SetAccess = private)
        SampleRate
        BufferSeconds
        BufferPoints
        DataBuffer
        FFTAmplitude
        FFTPower
        FFTPoints
        Nyquist
        Bins
        fAxis
    end
    properties (Constant)
        FreqBinNames = {'delta', 'theta', 'alpha', 'beta1', 'beta2', 'gamma'}
        FreqBinRange = [0, 3; 3, 8; 8, 12; 12,20; 20,30;30,50];
    end
    properties (Hidden)
        freqBinPnts
    end
    methods
        function obj = BCI_FFT(SampleRate, options)
            arguments
                SampleRate (1,1) {mustBeInteger, mustBePositive}
                options.BufferSeconds (1,1) {mustBeNumeric, mustBePositive} = 1
            end
            obj.SampleRate = SampleRate;
            obj.BufferSeconds = options.BufferSeconds;            
            obj.Nyquist = obj.SampleRate /2;
            obj.BufferPoints = obj.BufferSeconds * obj.SampleRate;

            %adjust to be a power of two
            obj.BufferPoints = pow2(nextpow2(obj.BufferPoints));
            obj.BufferSeconds = obj.BufferPoints/obj.SampleRate;
       
            obj.FFTPoints = obj.BufferPoints/2+1;
            obj.DataBuffer = zeros(1,obj.BufferPoints);
            obj.FFTAmplitude = zeros(1,obj.FFTPoints);

            obj.fAxis = obj.SampleRate * (0:obj.FFTPoints-1)/obj.BufferPoints;

            %convert the bin range values to actual offsets into the fft
            %array
            obj.freqBinPnts = round(obj.FreqBinRange * obj.BufferPoints / obj.SampleRate);
                
        end
    % *********************************************************************
    function obj = FFT(obj, dataChunk)

            
            ln = length(dataChunk);
            if ln > obj.BufferPoints
                error('The length of a data chunk cannot exceed the FFT buffer size');
            end
            %shift the data down and add the new data chunk
            obj.DataBuffer(1:obj.BufferPoints-ln) = obj.DataBuffer(ln + 1: obj.BufferPoints);
            obj.DataBuffer(obj.BufferPoints-ln+1:obj.BufferPoints) = dataChunk;

            %calculate the fft and take the absolute value
            abs_y = abs(fft(obj.DataBuffer));
            
            % take only the positive side of the spectrum
            onesided = abs_y(1:obj.BufferPoints/2+1);

            %calculate
            obj.FFTPower = onesided.^2./(obj.BufferPoints^2);
            obj.FFTAmplitude = onesided./obj.BufferPoints;

            obj.FFTPower(2:end-1)  = obj.FFTPower(2:end-1) * 2;
            obj.FFTAmplitude(2:end-1)  = obj.FFTAmplitude(2:end-1) * 2;
   
            for ii = 1:size(obj.freqBinPnts, 1)
                obj.Bins(ii) = mean(obj.FFTPower(obj.freqBinPnts(ii,1)+1 : obj.freqBinPnts(ii,2)));
            end
        end
 
    end
end
