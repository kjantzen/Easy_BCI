%test of the new chart routine

global running

running = true;

f = figure();
set(f, 'KeyPressFcn', @handleKeys);

myAx = axes(f);
sampleRate = 250;
bsize = 25;

myChart = BCI_Chart(sampleRate, 2, myAx);
e = 1;
while running
    tic
    buffer = rand(1,bsize);
    event_buff = zeros(1,bsize);
    event_buff(e) = 1;
    e = e+1;
    if e > bsize
        e = 1;
    end
    myChart.UpdateChart(buffer, event_buff);
    axis tight
    while toc < .1 
        drawnow;
    end
    
end

function handleKeys(src, event)
    running = false;
end