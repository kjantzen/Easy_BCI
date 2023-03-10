classdef BCI_Filter
    properties
        Cuttoff
        b
        Hd
        s
        g
    end
    methods 
        function obj = BCI_Filter(SampleRate, Cuttoff, Type)
            obj.Cuttoff = Cuttoff;
            Fn = SampleRate /2 ; %calculate the nyquist
            Wp = obj.Cuttoff/Fn;    %calculate the normalized cuttoff
            
            switch lower(Type)
                case 'high'
                    Wp = Wp(1);
                case 'low'
                    Wp = Wp(2);
            end
            
      
            %use a butter worth filter because it has no passband ripple
            %[z,p,k] = cheby2(10,20,Wp, Type); 
            [z,p,k] = butter(4,Wp,Type);
            [s,g]=zp2sos(z,p,k);%# create second order sections
            obj.Hd=dfilt.df2sos(s,g);%# create a dfilt object.
            obj.s = s;
            obj.g = g;
        end
        function dataOut = filter(obj, dataIn)
            %remove the mean, perform the filter and then add the mean back
            %again
            m = mean(dataIn);
            dataOut = filtfilt(obj.s,obj.g,dataIn-m) + m; 
            
        end
    end
end
