import time
import random
import json
import sys

def analyze_receipt_image(image_path):
    """
    Dummy custom ML model for receipt scanning.
    In a real scenario, this would use CNNs or OCR (like Tesseract/EasyOCR)
    to extract text, and an NLP model to classify the category and amount.
    """
    print(f"Loading custom ML model weights...")
    time.sleep(1)
    
    print(f"Analyzing image: {image_path}...")
    time.sleep(1.5) # Simulating inference time
    
    # Generate dummy extracted data
    categories = ['Food 🍔', 'Shopping 🛍️', 'Bills 💡', 'Health 💊', 'Travel ✈️']
    amount = round(random.uniform(50.0, 1500.0), 2)
    category = random.choice(categories)
    
    result = {
        "status": "success",
        "amount": amount,
        "category": category,
        "confidence": round(random.uniform(0.85, 0.99), 2)
    }
    
    return json.dumps(result, indent=2)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python receipt_parser.py <path_to_receipt_image>")
        sys.exit(1)
        
    image_file = sys.argv[1]
    output = analyze_receipt_image(image_file)
    print("\n--- Model Output ---")
    print(output)
