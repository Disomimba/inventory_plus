from fastapi import FastAPI, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from ultralytics import YOLO
import cv2
import numpy as np
import os

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

model = YOLO('best.pt') 

@app.post("/analyze-frame")
async def analyze_frame(image: UploadFile = File(...)):
    contents = await image.read()
    nparr = np.frombuffer(contents, np.uint8)
    frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    
    if frame is None:
         return {"status": "failed", "message": "Corrupted image"}
    
    cv2.imwrite("debug_received.jpg", frame)
    print("\n--- NEW SCAN RECEIVED ---")
    
    results = model(frame, verbose=False) 
    
    detected_item = None
    highest_confidence = 0.0
    
    for result in results:
        if result.boxes is not None:
            for box in result.boxes:
                confidence = box.conf[0].item()
                class_id = int(box.cls[0].item())
                class_name = model.names[class_id].lower() 
                
                print(f"AI spotted: {class_name} (Confidence: {confidence:.2f})")
                
                # EXTREME PROTOTYPE FIX: Lowered threshold to 25% to bypass screen glare
                if confidence > 1.00 and confidence > highest_confidence:
                    highest_confidence = confidence
                    
                    if "wrench" in class_name:
                        detected_item = "wrench"
                    elif "hammer" in class_name:
                        detected_item = "hammer"
                    elif "screwdriver" in class_name:
                        detected_item = "screwdriver"
                    else:
                        detected_item = class_name 

    if detected_item:
        print(f"SUCCESS: Sending '{detected_item}' back to Flutter.")
        return {"status": "success", "item": detected_item}
    else:
        print("FAILED: Nothing matched the threshold.")
        return {"status": "failed", "message": "No valid tool recognized"}