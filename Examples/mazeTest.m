
close all
f = figure('KeyPressFcn', @kb_callback);
f.Position = [200, 200, 500, 500];
clf
a = axes(f);
axis Square
cla
pause(.5)
global haveInputFlag;
global direction;
haveInputFlag = false;
direction = 'Center';

mazeGame = BCI_Maze(a,5,5);
mazeGame.Start();
running = true;

while running
    pause(.5)
    if mazeGame.InternalState == 1 %this is the running state
        haveInputFlag = false;
        mazeGame.Move(direction);
        if haveInputFlag == false
            direction = 'Center';
        end

    elseif mazeGame.InternalState == 2 %win
       
       a.Title.String = sprintf("You finished in %0.2f Seconds", mazeGame.CompletionTime);
       mazeGame.MazeRows = mazeGame.MazeRows;
       mazeGame.MazeColumns = mazeGame.MazeColumns + 1;
       mazeGame.NewMaze;
       mazeGame.Reset;
       pause(1)
       mazeGame.Start;
    end
end
function kb_callback(src, event)
    global direction
    global haveInputFlag
    
    if strcmp(event.Key, 'leftarrow')
        direction = 'Left';
    elseif strcmp(event.Key, 'rightarrow')
        direction = 'Right';
    end
    haveInputFlag = true;
end