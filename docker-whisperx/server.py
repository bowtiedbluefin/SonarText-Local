import os
import tempfile
import whisperx
from fastapi import FastAPI, UploadFile, File, Query, HTTPException
from fastapi.responses import JSONResponse
from typing import Optional

app = FastAPI(title="WhisperX API", version="1.0.0")

device = "cpu"
compute_type = "int8"
hf_token = os.environ.get("HF_TOKEN")

model = None
align_model = None
align_metadata = None
diarize_model = None


def get_model(model_name: str = "small"):
    global model
    if model is None:
        model = whisperx.load_model(model_name, device, compute_type=compute_type)
    return model


def get_align_model(language_code: str):
    global align_model, align_metadata
    if align_model is None:
        align_model, align_metadata = whisperx.load_align_model(
            language_code=language_code, device=device
        )
    return align_model, align_metadata


def get_diarize_model():
    global diarize_model
    if diarize_model is None:
        if not hf_token:
            raise HTTPException(
                status_code=400,
                detail="HF_TOKEN environment variable required for diarization"
            )
        from whisperx.diarize import DiarizationPipeline
        diarize_model = DiarizationPipeline(use_auth_token=hf_token, device=device)
    return diarize_model


@app.get("/")
async def root():
    return {"status": "ok", "service": "whisperx-api"}


@app.get("/docs")
async def docs_redirect():
    from fastapi.responses import RedirectResponse
    return RedirectResponse(url="/docs")


@app.get("/health")
async def health():
    return {"status": "healthy"}


@app.post("/asr")
async def transcribe(
    audio_file: UploadFile = File(...),
    output: str = Query("json", enum=["json", "text", "srt", "vtt"]),
    language: Optional[str] = Query(None),
    diarize: bool = Query(False),
    min_speakers: Optional[int] = Query(None),
    max_speakers: Optional[int] = Query(None),
    model_name: str = Query("small"),
    encode: bool = Query(True),
    word_timestamps: bool = Query(True),
):
    with tempfile.NamedTemporaryFile(delete=False, suffix=".audio") as tmp:
        content = await audio_file.read()
        tmp.write(content)
        tmp_path = tmp.name

    try:
        audio = whisperx.load_audio(tmp_path)
        
        asr_model = get_model(model_name)
        result = asr_model.transcribe(audio, batch_size=4, language=language)
        
        detected_language = result.get("language", language or "en")
        
        if word_timestamps:
            align_model_inst, metadata = get_align_model(detected_language)
            result = whisperx.align(
                result["segments"], 
                align_model_inst, 
                metadata, 
                audio, 
                device,
                return_char_alignments=False
            )
        
        if diarize and hf_token:
            diarize_pipe = get_diarize_model()
            diarize_segments = diarize_pipe(
                audio,
                min_speakers=min_speakers,
                max_speakers=max_speakers
            )
            result = whisperx.assign_word_speakers(diarize_segments, result)
        
        segments = result.get("segments", []) if result else []
        if not segments:
            return JSONResponse(content={
                "text": "",
                "segments": [],
                "language": detected_language
            })
        full_text = " ".join([s.get("text", "") for s in segments])
        
        if output == "text":
            return JSONResponse(content={"text": full_text})
        
        formatted_segments = []
        for seg in segments:
            formatted_seg = {
                "start": seg.get("start"),
                "end": seg.get("end"),
                "text": seg.get("text", "").strip(),
                "speaker": seg.get("speaker"),
            }
            if "words" in seg:
                formatted_seg["words"] = seg["words"]
            formatted_segments.append(formatted_seg)
        
        return JSONResponse(content={
            "text": full_text,
            "segments": formatted_segments,
            "language": detected_language
        })
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        os.unlink(tmp_path)


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=9000)
