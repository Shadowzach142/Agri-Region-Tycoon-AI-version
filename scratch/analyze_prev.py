with open('scratch/prev_mainmenu_tscn.txt', 'r', encoding='utf-8') as f:
    text = f.read()

for n in ['TopRightMapCard', 'CarouselBar', 'MiddleCard', 'FooterBar', 'LeftMenuVBox', 'ModeHoverCard', 'StartButton']:
    print(n, n in text)
