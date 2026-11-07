import json
with open(r'C:\Users\ADMIN\Documents\agri-region-ai-version\scratch\demo_save_slot1.json') as f:
    d = json.load(f)
m = d['meta']
fg = d['farm_grid']
bm = d['building_manager']
mkt = d['market']

print('=== DEMO SAVE VALIDATION ===')
print('Title   :', m['title'])
print('Region  :', m['region_display'])
print('Mode    :', m['game_mode_title'])
print('Day     :', m['day'])
print('Cash    :', m['cash'])
print('Points  :', m['points'])
print('Parcels :', fg['unlocked_parcels'])
print('Grid    :', str(len(fg['tiles'])) + 'x' + str(len(fg['tiles'][0])))
print('Workers :', bm['active_workers'])
print('Drones  :', bm['active_drones'])
print('Techs   :', bm['unlocked_techs'])
print('Buildings:', len(bm['buildings']))
for b in bm['buildings']:
    print('  -', b['type'], '@', b['grid_pos'], 'fp=', b['footprint'], 'lv=', b['level'])
print('Inventory:', len(mkt['stored_inventory']), 'batches')
for i in mkt['stored_inventory']:
    print('  -', i['crop'].ljust(20), i['quantity'], 'u  Grade-' + i['grade'], 'fresh=' + str(i['freshness']) + '%')

from collections import Counter
state_names = {0:'EMPTY',1:'OBSTACLE',2:'PLOWED',3:'PLANTED',4:'GROWING',5:'READY',6:'HARVESTING',7:'BUILDING'}
counter = Counter()
for col in fg['tiles']:
    for t in col:
        counter[t['s']] += 1
print('Tile states:')
for s, n in sorted(counter.items()):
    print(' ', state_names.get(s, str(s)).ljust(12), ':', n)

