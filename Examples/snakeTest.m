
close all
f = figure('KeyPressFcn', @kb_callback);
f.Position = [200, 200, 500, 500];
clf
a = axes(f);
axis Square
cla
pause(.5 ...
    )
global haveInputFlag;
global direction;
haveInputFlag = false;
direction = 'Center';

snakeGame = BCI_Snake(a);
snakeGame.FailSignal.Color = [1,.3,.3];

%snakeGame.Speed = 4;
snakeGame.Start();
running = true;

while running

    pause(.1)
    if snakeGame.SnakeState == 2 %this is the ready state
        haveInputFlag = false;
        snakeGame.Move(direction);
        a.Title.String = sprintf("Score: %i,  Highscore: %i Length: %i", snakeGame.Score, snakeGame.HighScore, snakeGame.SnakeLength);
        if haveInputFlag == false
            direction = 'Center';
        end
    elseif snakeGame.SnakeState == 4 %failed
        msg = ["YOU LOSE!",char(13),"Would you like to try again?"];
        response = uiconfirm(f, msg, 'GAME OVER', "Options",["Yes", "No"],...
            'DefaultOption', 1, "CancelOption", 2);
        switch response
            case 'Yes'
                pause(1)
                snakeGame.Reset()
                snakeGame.Start()
                direction = "Center";
            case 'No'
                running = false;
        end
    elseif snakeGame.SnakeState == 3 %win
        snakeGame.SnakeSpeed = snakeGame.SnakeSpeed + 1;
        pause(1)
        snakeGame.Reset;
        snakeGame.Start;
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