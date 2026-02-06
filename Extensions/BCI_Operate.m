classdef BCI_Operate
    properties
    end
    methods
        function obj = BCI_Operate()
            %general purpose wrapper for holding several common processing
            %functions
            %to initialize the object use the sytax
            %myobj = BYB_Operate();
            %
            %call the objects methods to use the object.  For example, to
            %remove the offset from the values in the vector d by removing 
            %the mean of the first 100 data points you would
            %use the following syntax. 
            %
            %newd = myobj.RemoveOfsset(d, [1:100])
            %
            %the new values are in the vector newd

        end
        
        function dataOut = RemoveOffset(obj, dataIn, varargin)
        %remove the offset from the data chunk
        %
        % Usage:
        %
        %result = RemoveOffset(d) - removes the mean of the data d from
        %each data point in d and returns the new valued in result
        %
        %result = RemoveOffset(d, pnts) - calcuates the mean of the
        %datapoints specificed in the vector pnts and subtracts it from
        %all values in d.
        %

            if nargin < 3
                bpts = 1:1:length(dataIn);
            else
                bpts = varargin{1};
            end

            dataOut = dataIn - mean(dataIn(bpts));

        end
        function x = Combine(obj, data, varargin)
            %combines values and returns a single value result
            %
            % Usage:
            %
            %result = Combine(d) - Calculates the mean (x) of the values in
            %vector d
            %
            %result = Combine(d, methods) - combines the values in vector d using 
            %the method(s) indicates in the cell array "methods" and
            %returns a 1 x n vector where n is the number of methods
            %specified.  
            %e.g. r = obj.Combine(data, {'mean', 'sd', 'rms'}) - returns a 1x3
            %vector r in which the first value is the mean of data and the
            %second is the standard deviation and the third is the root
            %mean square.
            %valid options for methods are
            %   mean    -  mean or average
            %   sd      - standard deviation
            %   rms     - the root mean square
            %   sum     - sum of all points
            %   min     - the smallest value
            %   max     - the largest value
            %   absmin  - the smallest absolute value
            %   absmax  - the largest absolute value

            if nargin < 3
                operations = {'mean'};
            else
                operations = varargin{1};
            end

            x = [];
            for ii = 1:length(operations)
                switch operations{ii}
                    case 'mean'
                        f = @(d) mean(d);
                    case 'sd'
                        f = @(d) std(d);
                    case 'rms'
                        f = @(d) rms(d);
                    case 'sum'
                        f = @(d) sum(d);
                    case 'min'
                        f = @(d) min(d);
                    case 'max'
                        f = @(d) max(d);
                    case 'absmin'
                        f = @(d) min(abs(d));
                    case 'absmax'
                        f = @(d) max(abs(d));
                    otherwise
                        warning('The combining operation %s is not valid', operations{ii});
                        continue
                end
                x = [x,f(data)];

            end
        end
        function r = Power(obj, data, varargin)
            %raises each value in data to the power specified in p.  If p
            %is omitted a power of 2 (squaring) is assumed. 
            %
            %Usage
            %
            % r = Power(d) - squares each value in d and returns the result
            % in r.  r and d will be the same size
            %
            %r = Power(d, p) raises each value in d to the power p.
            %
            %Note, to calculate the nth root pass a value of p that is 1/n
            %e.g.  r = Power(d, .5) - calculates the square root of d because 1/2 = .5
            
            if narargin < 3
                p = 2;
            else
                p = varargin{1};
            end

            r = data.^p;

            
        end
        function r = Abs(obj, data)
            %raises each value in data to the power specified in p.  If p
            %is omitted a power of 2 (squaring) is assumed. 
            %
            %Usage
            %
            % r = Power(d) - squares each value in d and returns the result
            % in r.  r and d will be the same size
            %
            %r = Power(d, p) raises each value in d to the power p.
            %
            %Note, to calculate the nth root pass a value of p that is 1/n
            %e.g.  r = Power(d, .5) - calculates the square root of d because 1/2 = .5

            r = abs(data);

        end
        function [th_flag, th_count, th_first] = Threshold(obj, data, threshold, varargin)
            %determines if the data exceeds a threshold
            %[t, c, p] = Threshold(data, threshold) - determines the values
            %in data that exceed "threshold". 
            %returns:
            %   t = true if the threshold was exceeded, false otherwise
            %   c = a count of the number of points that exceeded the
            %   threshold
            %   p = the location of the first point in teh vector to exceed
            %   the threshold
            %
            %   just ask if you want more output information
            %
            %[t, c, p] = Threshold(data, threshold, method) will
            %optionally use "method" to determine the threshold
            %valid options for method are:
            %   'high' - searches for values that exceed threshold
            %   'low' - searches for values less than threshold
            %   'abs' - takes the absolute value before searching for
            %   values that exceed threshold.

            if nargin < 4
                method = 'high';
            else
                method = varargin{1};
            end

            switch method
                case 'low'
                    data = -data;
                case 'abs'
                    data = abs(data);
                case 'high'
                otherwise
                    warning('%s is an invalid threshold method.  Defaulting to "high"', method);
            end

            x = data>=threshold;
            th_flag = any(x);
            th_count = sum(x);
            th_first = find(x, 1);
            
        end
    end
end