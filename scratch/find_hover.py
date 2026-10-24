import json

with open(r'C:\Users\ADMIN\.gemini\antigravity-ide\brain\bf1aec29-35f3-4398-8b83-35e7fecd62b4\.system_generated\logs\transcript_full.jsonl', 'r', encoding='utf-8') as f:
    for i, line in enumerate(f):
        if 'const MODE_EXPLANATIONS: Dictionary =' in line or 'MODE_EXPLANATIONS = {' in line:
            obj = json.loads(line)
            txt = str(obj.get('content', ''))
            idx = txt.find('MODE_EXPLANATIONS')
            if idx != -1:
                with open(r'C:\Users\ADMIN\Documents\agri-region-ai-version\scratch\mode_explanations.txt', 'w', encoding='utf-8') as out:
                    out.write(txt[idx:idx+2500])
                print("FOUND MODE_EXPLANATIONS")
                break
