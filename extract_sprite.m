file = "~/Documents/Easy_BCI/SkaterSprite.png";

[sprite, ~, alpha] = imread(file);

f = figure(1);
clf;
a = axes(f);
cla
a.YDir = "normal";
a.Color = 'g';
axis off;
hold on


x = [1, size(sprite,1)];
y = [size(sprite,2),1];

im = image(x, y, sprite);
im.AlphaData = alpha;

a.XLim = [1,1000];
a.YLim =[1,500];



