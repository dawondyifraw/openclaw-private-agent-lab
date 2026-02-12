
import os
import re
import requests
from datetime import datetime

class AmharicTranslationPipeline:
    def __init__(self, model_name="facebook/nllb-200-distilled-600M"):
        self.model_name = model_name
        # This service originally used a mock placeholder translation. That caused the gateway's
        # outbound Amharic enforcement to reject the placeholder and fall back to a fixed message.
        #
        # Use local Ollama instead to produce real Ethiopic output when possible.
        self.ollama_host = os.environ.get("AMHARIC_OLLAMA_HOST", "http://ollama:11434").rstrip("/")
        self.ollama_model = os.environ.get("AMHARIC_OLLAMA_MODEL", "qwen2.5:14b").strip() or "qwen2.5:14b"
        self.timeout_s = float(os.environ.get("AMHARIC_OLLAMA_TIMEOUT_S", "25"))
        print(f"Initializing Amharic Pipeline with {model_name} (ollama={self.ollama_host} model={self.ollama_model})")

    def _has_ethiopic(self, text: str) -> bool:
        return bool(re.search(r"[\u1200-\u137F]", text or ""))

    def _normalize_intent_key(self, text: str) -> str:
        # Lowercase, remove punctuation/emoji, collapse whitespace.
        t = (text or "").lower()
        t = re.sub(r"[^a-z0-9\s]", " ", t)
        t = re.sub(r"\s+", " ", t).strip()
        return t

    def _translate_with_ollama(self, text: str) -> str:
        # Force a terse, Amharic-only response. No tags.
        prompt = (
            "Translate the following into Amharic (Ethiopic script). "
            "Return ONLY the Amharic translation, no English, no quotes, no XML/HTML tags.\n\n"
            f"Text:\n{text}\n"
        )
        r = requests.post(
            f"{self.ollama_host}/api/generate",
            json={
                "model": self.ollama_model,
                "prompt": prompt,
                "stream": False,
                # Keep it short and reduce hallucinated wrappers.
                "options": {"temperature": 0.2},
            },
            timeout=self.timeout_s,
        )
        r.raise_for_status()
        data = r.json() if r.content else {}
        return str(data.get("response") or "").strip()

    def _sanitize_amharic_output(self, text: str) -> str:
        t = (text or "").strip()
        if not t:
            return ""

        # Remove simple tags the model may emit.
        t = re.sub(r"</?[^>]+>", " ", t)

        # Prefer lines that contain Ethiopic chars if the model added commentary.
        lines = [ln.strip() for ln in (text or "").splitlines() if ln.strip()]
        ethiopic_lines = [ln for ln in lines if self._has_ethiopic(ln)]
        if ethiopic_lines:
            t = " ".join(ethiopic_lines)

        # Keep only Ethiopic, digits, and a small punctuation set.
        # This prevents mixed-script junk (Arabic/CJK/Latin) from leaking into Telegram.
        t = re.sub(r"[^\u1200-\u137F0-9\s\.\,\!\?\-\:\(\)]+", " ", t)
        t = re.sub(r"\s+", " ", t).strip()

        # Avoid runaway repeats from a bad model output.
        if len(t) > 400:
            t = t[:400].rstrip()

        # If the string is mostly repetition, drop it (gateway will use a safe fallback).
        words = [w for w in t.split(" ") if w]
        if len(words) >= 12:
            most = max((words.count(w) for w in set(words)), default=0)
            if most / max(len(words), 1) >= 0.5:
                return ""
        return t

    def translate(self, text, enforce_ethiopic=True):
        """
        Translate English -> Amharic.
        Tries heuristics for common greetings first, then uses Ollama.
        """
        try:
            src = (text or "").strip()
            if not src:
                return {"success": False, "amharic": "", "error": "No text provided"}

            key = self._normalize_intent_key(src)

            # High-confidence canned intents (keeps Amharic groups stable even if LLM providers fail).
            if key in {"hello", "hi", "hey"} or "hello" in key or "hi " in (key + " "):
                return {"success": True, "amharic": "ሰላም!", "error": None}
            if "how" in key and "you" in key and ("are" in key or "ar" in key):
                return {"success": True, "amharic": "እኔ ደህና ነኝ፣ አመሰግናለሁ! አንተ/አንቺ እንዴት ነህ/ነሽ?", "error": None}
            if ("what day is today" in key) or ("what day" in key and "today" in key) or (key in {"what is today", "what is todays date", "today"}):
                now = datetime.now()
                dow = ["ሰኞ", "ማክሰኞ", "ረቡዕ", "ሐሙስ", "አርብ", "ቅዳሜ", "እሁድ"][now.weekday()]
                month = [
                    "ጃንዩወሪ", "ፌብሩወሪ", "ማርች", "ኤፕሪል", "ሜይ", "ጁን",
                    "ጁላይ", "ኦገስት", "ሴፕቴምበር", "ኦክቶበር", "ኖቬምበር", "ዲሴምበር"
                ][now.month - 1]
                return {"success": True, "amharic": f"ዛሬ {dow}፣ {month} {now.day}፣ {now.year} ነው።", "error": None}

            # For anything else, be conservative: try Ollama once, but fall back safely if output is noisy.
            translated = self._sanitize_amharic_output(self._translate_with_ollama(src))

            if not translated:
                return {"success": False, "amharic": "", "error": "No safe translation produced"}

            # If enforcement requested, require Ethiopic chars so downstream doesn't fall back.
            if enforce_ethiopic and not self._has_ethiopic(translated):
                return {"success": False, "amharic": "", "error": "Translation missing Ethiopic script"}

            return {"success": True, "amharic": translated, "error": None}
        except Exception as e:
            return {"success": False, "amharic": "", "error": str(e)}

    def get_fallback_message(self, intent):
        return "ይቅርታ (Sorry)"
