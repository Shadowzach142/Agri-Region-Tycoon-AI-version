with open('autoload/Data.gd', 'r', encoding='utf-8') as f:
    text = f.read()

import re
pros = re.findall(r'"pros":\s*"([^"]+)"', text)
for p in pros:
    print('PROS:', p[:60])
