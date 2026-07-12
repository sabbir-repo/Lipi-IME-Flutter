import requests
import json
import os
import threading

# Reuse TCP connections (Keep-Alive) to drastically reduce latency and avoid timeout rates
session = requests.Session()

# Lock for thread-safe cache operations
cache_lock = threading.Lock()

# File paths
OFFLINE_CACHE_FILE = os.path.join(os.path.expanduser("~"), ".lipi_ime_offline_cache.json")

# Dynamic cache storage
offline_cache = {}

def load_offline_cache():
    global offline_cache
    if os.path.exists(OFFLINE_CACHE_FILE):
        try:
            with open(OFFLINE_CACHE_FILE, "r", encoding="utf-8") as f:
                offline_cache = json.load(f)
        except Exception:
            offline_cache = {}
    else:
        offline_cache = {}

def save_offline_cache():
    try:
        with open(OFFLINE_CACHE_FILE, "w", encoding="utf-8") as f:
            json.dump(offline_cache, f, ensure_ascii=False, indent=4)
    except Exception:
        pass

# Initialize cache
load_offline_cache()

# Built-in basic dictionaries for the 5 target languages
BASIC_OFFLINE_DICT = {
    "bn-t-i0-und": {
        "amar": ["আমার", "আমারে", "আমারও", "আমারই"],
        "tumi": ["তুমি", "তুমিও", "তুমিই", "তোমাকে"],
        "ami": ["আমি", "আমিও", "আমিই", "আমাকে"],
        "bhalo": ["ভালো", "ভাল", "ভালোই", "ভালো লাগছে"],
        "dhaka": ["ঢাকা", "ঢাকায়", "ঢাকাই"],
        "bhasha": ["ভাষা", "ভাষার", "ভাষায়"],
        "bangla": ["বাংলা", "বাংলাদেশ", "বাঙালি", "বাঙला"],
        "nam": ["নাম", "নামের", "নামটি"],
        "ki": ["কী", "কি", "কিছু", "কিনা"],
        "kemon": ["কেমন", "কেমন আছো", "কেমন আছেন"],
        "acho": ["আছো", "আছেন", "আছিস"],
        "bari": ["বাড়ি", "বাড়িতে", "বাড়ির"],
        "khabar": ["খাবার", "খাবো", "খাবার দাবাড়"],
        "desh": ["দেশ", "দেশের", "দেশে"],
        "shonar": ["সোনার", "সোনা", "সোনার বাংলা"]
    },
    "hi-t-i0-und": {
        "namaste": ["नमस्ते", "नमस्कार"],
        "aap": ["आप", "आपको", "आपका"],
        "kaise": ["कैसे", "कैसा", "कैसी"],
        "hain": ["हैं", "है", "हूं"],
        "mera": ["मेरा", "मेरे", "मेरी"],
        "naam": ["नाम", "नामों"],
        "hai": ["है", "हैं"],
        "tum": ["तुम", "तुम्हें", "तुम्हारा"],
        "kya": ["क्या", "क्यों", "कब"],
        "kar": ["कर", "करना", "करो", "करते"],
        "rahe": ["रहे", "रहा", "रही"],
        "ho": ["हो", "होता", "होने"],
        "achha": ["अच्छा", "अच्छे", "अच्छी"],
        "bharat": ["भारत", "भारतीय", "भारत माता"]
    },
    "ar-t-i0-und": {
        "marhaban": ["مرحباً", "مرحبا"],
        "shukran": ["شكراً", "شكر"],
        "kaifa": ["كيف", "كيفما"],
        "haluk": ["حالك", "أحوالك"],
        "na'am": ["نعم"],
        "la": ["لا", "لأن"],
        "ismy": ["اسمي", "اسم"],
        "ahlan": ["أهلاً", "اهلا وسلا"],
        "salam": ["سلام", "السلام", "سليم"]
    },
    "ne-t-i0-und": {
        "namaste": ["नमस्ते", "नमस्कार"],
        "sanchai": ["सन्चै", "सन्चै हुनुहुन्छ"],
        "huncha": ["हुन्छ", "हुनेछ"],
        "mero": ["मेरो", "मेरा", "मेरी"],
        "naam": ["नाम", "नाममा"],
        "ho": ["हो", "होइन", "होला"],
        "timi": ["तिमी", "तिमीलाई", "तिम्रो"],
        "kasto": ["कस्तो", "कस्ता", "कस्ती"],
        "cha": ["छ", "छैन", "छन्"],
        "nepal": ["नेपाल", "नेपाली", "नेपालको"]
    },
    "ur-t-i0-und": {
        "salam": ["سلام", "السلام"],
        "shukriya": ["شکریہ", "شکر گزار"],
        "ap": ["آپ", "آپ کا", "آپ کو"],
        "kaise": ["کیسے", "کیسا", "کیسی"],
        "hain": ["ہیں", "ہے", "ہوں"],
        "mera": ["میرا", "میرے", "میری"],
        "nam": ["نام", "ناموں"],
        "hai": ["ہے", "ہیں"],
        "kya": ["کیا", "کیوں", "کب"]
    }
}

def fetch_suggestions(text, lang_code="bn-t-i0-und", offline_enabled=True, online_mode=True):
    """
    Fetches transliteration suggestions.
    Checks API if online; caches results.
    If offline (or API fails), falls back to local cache or built-in dictionary.
    """
    if not text.strip():
        return []
        
    text_lower = text.lower().strip()
    
    url = "https://inputtools.google.com/request"
    params = {
        'text': text,
        'itc': lang_code,
        'num': 5,
        'cp': 0,
        'cs': 1,
        'ie': 'utf-8',
        'oe': 'utf-8',
        'app': 'desktop-ime'
    }
    
    try:
        if not online_mode:
            raise requests.exceptions.ConnectionError("Offline mode explicitly forced by user.")
            
        response = session.get(url, params=params, timeout=1.5) # Shorter timeout for faster offline fallback response
        if response.status_code == 200:
            data = response.json()
            if data[0] == "SUCCESS":
                results = data[1][0][1]
                
                # Update offline cache in background (preserving original case-sensitive text key)
                if offline_enabled and results:
                    with cache_lock:
                        if lang_code not in offline_cache:
                            offline_cache[lang_code] = {}
                        offline_cache[lang_code][text] = results
                        save_offline_cache()
                return results
    except Exception:
        # API is offline or failed
        pass
        
    # Fallback logic (Only if offline_enabled is True)
    if offline_enabled:
        # Check dynamic cache
        with cache_lock:
            lang_cache = offline_cache.get(lang_code, {})
            if text in lang_cache:
                return lang_cache[text]
            elif text_lower in lang_cache:
                return lang_cache[text_lower]
                
        # Check built-in basic offline dictionary
        lang_dict = BASIC_OFFLINE_DICT.get(lang_code, {})
        if text_lower in lang_dict:
            return lang_dict[text_lower]
            
        # If Bengali, fallback to local Avro Phonetic rule-based parsing
        if lang_code == "bn-t-i0-und":
            try:
                import avro
                # Pass the original case-sensitive text for accurate Avro phonetic matching
                avro_val = avro.parse(text)
                if avro_val and avro_val != text:
                    return [avro_val]
            except Exception:
                pass
            
    return []
