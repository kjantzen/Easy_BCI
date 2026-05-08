function maze = kruskalMaze(rows, cols)
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

        rootA = findSet(parent, cellA);
        rootB = findSet(parent, cellB);

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

    % Display maze
    figure;
    imagesc(maze);
    colormap(gray);
    axis equal off;
    title('Random Maze Generated with Kruskal''s Algorithm');

end

function root = findSet(parent, x)
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