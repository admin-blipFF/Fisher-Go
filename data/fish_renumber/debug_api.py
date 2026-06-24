"""Debug: test OpenRouter image generation API call."""
import requests, os

env_path = r"C:\Users\s0829\xinglan-workspace\.env"
OPENROUTER_KEY = ""
if os.path.exists(env_path):
    for line in open(env_path, encoding="utf-8"):
        if line.strip().startswith("OPENROUTER_API_KEY"):
            OPENROUTER_KEY = line.split("=",1)[1].strip().strip('"\'')
            break

print(f"Key present: {'YES' if OPENROUTER_KEY else 'NO'}, length={len(OPENROUTER_KEY)}")

API_URL = "https://openrouter.ai/api/v1/images/generations"
headers = {"Authorization": f"Bearer {OPENROUTER_KEY}", "Content-Type": "application/json"}
payload = {
    "model": "gpt-image-2",
    "prompt": "A cute cartoon fish badge icon, 1024x1024 PNG, centered facing left, red circle background",
    "n": 1,
    "size": "1024x1024",
}

print("Calling OpenRouter API...")
resp = requests.post(API_URL, json=payload, headers=headers, timeout=60)
print(f"Status: {resp.status_code}")
print(f"Headers: {dict(resp.headers)}")
print(f"Body preview: {resp.text[:500]}")