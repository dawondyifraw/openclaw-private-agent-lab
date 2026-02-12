
import requests
import time
import sys

def test_translation():
    url = "http://127.0.0.1:18790/translate/amharic"
    payload = {"text": "Hello, my love"}
    
    print(f"Testing {url} with {payload}...")
    
    try:
        # Wait for service to come up
        for i in range(5):
            try:
                requests.get("http://127.0.0.1:18790/health")
                break
            except:
                time.sleep(1)
        
        response = requests.post(url, json=payload, timeout=5)
        print(f"Status: {response.status_code}")
        print(f"Response: {response.json()}")
        
        if response.status_code == 200 and response.json().get("success"):
            print("✅ Translation Service Verified")
            return 0
        else:
            print("❌ Service returned error")
            return 1
    except Exception as e:
        print(f"❌ Connection failed: {e}")
        return 1

if __name__ == "__main__":
    sys.exit(test_translation())
