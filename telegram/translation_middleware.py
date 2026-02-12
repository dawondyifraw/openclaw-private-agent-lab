#!/usr/bin/env python3
"""
Telegram Translation Middleware for Amharic Groups
Intercepts responses from g-hello and merry-bot, translates to Amharic
"""

import json
import sys
import os
from pathlib import Path

sys.path.insert(0, "/home/devbox/.openclaw/services/amharic-translation")
from amharic_translation import AmharicTranslationPipeline

AMHARIC_GROUPS = ["TG_GROUP_MERRY_ID", "TG_GROUP_HELLO_ID"]
TRANSLATION_PIPELINE = AmharicTranslationPipeline()

def process_response(chat_id, agent_response):
    """
    If chat_id is in Amharic groups, translate JSON response
    """
    if chat_id not in AMHARIC_GROUPS:
        return agent_response
    
    try:
        data = json.loads(agent_response)
        english_text = data.get("reply_en", "")
        
        if not english_text:
            return agent_response
        
        result = TRANSLATION_PIPELINE.translate(english_text)
        
        if result["success"]:
            data["reply_am"] = result["amharic"]
            data["translation_applied"] = True
            return json.dumps(data, ensure_ascii=False)
        else:
            return agent_response
            
    except Exception as e:
        print(f"Translation error: {e}", file=sys.stderr)
        return agent_response

if __name__ == "__main__":
    # Test mode
    test_response = '{"reply_en": "Hello, how are you?", "tone": "warm", "intent": "greeting"}'
    print(process_response("TG_GROUP_HELLO_ID", test_response))
