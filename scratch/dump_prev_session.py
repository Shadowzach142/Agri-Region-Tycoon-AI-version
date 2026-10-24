import json

transcript_path = r'C:\Users\ADMIN\.gemini\antigravity-ide\brain\bf1aec29-35f3-4398-8b83-35e7fecd62b4\.system_generated\logs\transcript.jsonl'
with open(transcript_path, 'r', encoding='utf-8') as f:
    for line in f:
        try:
            obj = json.loads(line)
            step = obj.get('step_index', 0)
            if step >= 13290 and obj.get('type') == 'USER_INPUT':
                print(f"=== STEP {step} USER_INPUT ===")
                print(obj.get('content'))
                print()
        except Exception:
            pass
