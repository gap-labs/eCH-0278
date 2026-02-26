from fastapi import FastAPI, UploadFile, File
from app.validation import validate_xml

app = FastAPI()

@app.post("/api/validate")
async def validate(file: UploadFile = File(...)):
    content = await file.read()
    result = validate_xml(content)
    return result