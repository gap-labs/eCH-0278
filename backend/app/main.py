from fastapi import FastAPI, UploadFile, File
from app.comparison import compare_xml
from app.validation import validate_xml

app = FastAPI()

@app.post("/api/validate")
async def validate(file: UploadFile = File(...)):
    content = await file.read()
    result = validate_xml(content)
    return result


@app.post("/api/compare")
async def compare(xml1: UploadFile = File(...), xml2: UploadFile = File(...)):
    xml1_content = await xml1.read()
    xml2_content = await xml2.read()
    result = compare_xml(xml1_content, xml2_content)
    return result