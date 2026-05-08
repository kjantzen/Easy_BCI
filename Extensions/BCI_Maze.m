classdef BCI_Maze < handle
    properties
        Axes
        MazeRows
        MazeColumns
        Direction
        InternalState
        CompletionTime = 0
    end
    properties (Constant, Hidden)
        Directions = {'N', 'E', 'S', 'W'};
        IDLE = 0;
        RUNNING = 1;
        COMPLETE = 2;
        AsciiArrow = [8593, 8594,  8595, 8592];
    end
    properties (Access = private)
        Maze
        MazeSizeX;
        MazeSizeY;
        RunnerX = 1;
        RunnerY = 2;
        RunnerSize = 20;
        StartTime = 0;
        Speed = 1;
        Sprite;
        SpriteHead;
    end

    methods
        %%
        function obj = BCI_Maze(ax, rows, columns)
            arguments
                ax (1,1) matlab.graphics.axis.Axes
                rows (1,1) {mustBeNumeric, mustBeInteger, mustBeBetween(rows, 2, 20)}
                columns (1,1) {mustBeNumeric, mustBeInteger, mustBeBetween(columns, 2, 20)}
            end
            obj.InternalState = obj.IDLE;
            obj.Axes = ax;
            obj.MazeRows = rows;
            obj.MazeColumns = columns;
            obj.NewMaze();
            obj.Reset()

        end
        %%
        function Start(obj)
            if obj.InternalState == obj.IDLE
                obj.InternalState = obj.RUNNING;
                obj.StartTime = tic;
            end
        end
        %%
        function Reset(obj)
             
            if obj.InternalState == obj.RUNNING
                return
            end
            obj.InternalState = obj.IDLE;
            hold(obj.Axes, 'off');    
            imagesc(obj.Axes, obj.Maze)
            axis equal off
            colormap(gray);
            drawnow
            obj.RunnerSize = obj.alleySize();
            obj.RunnerX = 1;
            obj.RunnerY = 2;
            obj.Direction = 2;
            hold(obj.Axes, 'on');
            obj.Sprite = scatter(obj.Axes, obj.RunnerX, obj.RunnerY, obj.RunnerSize);
            obj.SpriteHead = text(obj.Axes, obj.RunnerX, obj.RunnerY, char(obj.AsciiArrow(obj.Direction)), ...
                "FontSize", sqrt(obj.RunnerSize), "HorizontalAlignment","center",...
                "VerticalAlignment","middle");
            obj.Sprite.MarkerFaceColor = 'r';

        end
        %%
        function NewMaze(obj)
            if obj.InternalState == obj.RUNNING
                return
            end
            obj.Maze = obj.kruskalMaze(obj.MazeRows, obj.MazeColumns);
            obj.MazeSizeY = obj.MazeRows * 2 + 1;
            obj.MazeSizeX = obj.MazeColumns * 2 + 1;
            

        end
        %%
        function Move(obj, direction)

            %ignore subsequent requests if the system is busy or the game
            %has ended
            if (obj.InternalState ~= obj.RUNNING)
                fprintf('NOPE');
                return;
            end

            obj.CompletionTime = toc(obj.StartTime);

            %keep track of which direction the snake is travelling
            %can be either N, S, E or W
            if strcmp(direction,'Left')
                obj.Direction = obj.Direction - 1;
                if obj.Direction < 1; obj.Direction = 4; end
            elseif strcmp(direction,'Right')
                obj.Direction = obj.Direction + 1;
                if obj.Direction > 4; obj.Direction = 1; end
            end

            obj.SpriteHead.String = char(obj.AsciiArrow(obj.Direction));

            %get the new direction by adjusting current values by the
            %object speed
            switch obj.Directions{obj.Direction}
                case "N"                    
                    y = obj.RunnerY - obj.Speed;
                    if obj.Maze(y, obj.RunnerX) == 1
                        obj.RunnerY = y;
                    end
                case "S"
                    y = obj.RunnerY + obj.Speed;
                    if obj.Maze(y, obj.RunnerX) == 1
                        obj.RunnerY = y;
                    end                
                case "E"
                    x = obj.RunnerX + obj.Speed;
                    if x > obj.MazeSizeX
                        obj.InternalState = obj.COMPLETE;
                        fprintf('You finished the maze\n');
                        return;
                    end
                    if obj.Maze(obj.RunnerY, x) == 1
                        obj.RunnerX = x;
                    end
                case "W"
                    if obj.RunnerX > 1
                        x = obj.RunnerX - 1;
                        if obj.Maze(obj.RunnerY, x) == 1
                            obj.RunnerX = x;
                        end
                    end
            end

            obj.Sprite.XData = obj.RunnerX;
            obj.Sprite.YData = obj.RunnerY;
            obj.SpriteHead.Position = [obj.RunnerX, obj.RunnerY];


            drawnow
        end
    end
    methods (Access = private)

    end
    %% Internal helper functions
    methods (Access = private, Sealed = true, Hidden = true)
        function maze = kruskalMaze(obj, rows, cols)
            % KRUSKALMAZE Generate a random maze using Kruskal's algorithm
            %
            %   maze = kruskalMaze(rows, cols)
            %
            %   Input:
            %       rows - number of maze cells vertically
            %       cols - number of maze cells horizontally
            %
            %   Output:
            %       maze - binary matrix representation of the maze
            %              1 = wall
            %              0 = passage
            %
            %   Example:
            %       maze = kruskalMaze(20, 30);

            % Maze dimensions in wall-space
            mazeRows = 2 * rows + 1;
            mazeCols = 2 * cols + 1;

            % Initialize maze with all walls
            maze = ones(mazeRows, mazeCols);

            % Open cell locations
            for r = 1:rows
                for c = 1:cols
                    maze(2*r, 2*c) = 0;
                end
            end

            % Disjoint-set initialization
            parent = 1:(rows * cols);

            % Build wall list
            walls = [];

            for r = 1:rows
                for c = 1:cols

                    cellID = sub2ind([rows, cols], r, c);

                    % Right wall
                    if c < cols
                        neighborID = sub2ind([rows, cols], r, c+1);

                        walls = [walls;
                            r, c, r, c+1, ...
                            2*r, 2*c+1, ...
                            cellID, neighborID];
                    end

                    % Bottom wall
                    if r < rows
                        neighborID = sub2ind([rows, cols], r+1, c);

                        walls = [walls;
                            r, c, r+1, c, ...
                            2*r+1, 2*c, ...
                            cellID, neighborID];
                    end
                end
            end

            % Randomize wall order
            walls = walls(randperm(size(walls,1)), :);

            % Process walls
            for i = 1:size(walls,1)

                wallRow = walls(i, 5);
                wallCol = walls(i, 6);

                cellA = walls(i, 7);
                cellB = walls(i, 8);

                rootA = obj.findSet(parent, cellA);
                rootB = obj.findSet(parent, cellB);

                % Remove wall if cells are not connected
                if rootA ~= rootB

                    maze(wallRow, wallCol) = 0;

                    % Union sets
                    parent(rootB) = rootA;
                end
            end

            % Create entrance and exit
            maze(2,1) = 0;
            maze(2*rows, 2*cols+1) = 0;
            maze = ~maze;
        end

        function root = findSet(~, parent, x)
            % FINDSET Find root of disjoint set with path compression

            root = x;

            while parent(root) ~= root
                root = parent(root);
            end

            % Path compression
            while parent(x) ~= x
                next = parent(x);
                parent(x) = root;
                x = next;
            end
        end
        %%
        function sz = alleySize(obj)
            cUnits = obj.Axes.Units;
            obj.Axes.Units = 'points';

            ih = obj.Axes.InnerPosition(4) - obj.Axes.InnerPosition(2);
            w = ih / (obj.MazeSizeY);
            sz = pi * (w/2)^2;

            obj.Axes.Units = cUnits;

        end
    end
end
