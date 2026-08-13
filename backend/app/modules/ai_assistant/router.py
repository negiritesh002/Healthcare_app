import os
import re
import logging
from typing import Optional, List, Dict
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
import httpx

from app.core.config import settings
from app.shared.dependencies import get_current_doctor
from app.modules.auth.models import Doctor

logger = logging.getLogger(__name__)

router = APIRouter()

MANDATORY_DISCLAIMER = (
    "\n\nDisclaimer: This response is general reference information for licensed "
    "healthcare professionals and does not replace clinical judgment or official prescribing information."
)

NON_MEDICAL_KEYWORDS = [
    "weather", "sports", "football", "cricket", "movie", "song", "capital of",
    "joke", "president", "recipe", "car", "travel", "game", "code"
]

MEDICAL_KNOWLEDGE_BASE = {
    "amoxicillin": (
        "Amoxicillin 500mg (Aminopenicillin Antibiotic):\n"
        "• Indications: Bacterial infections (otitis media, sinusitis, pneumonia, skin & urinary tract infections).\n"
        "• Dosage: 250mg - 500mg orally every 8 hours, or 875mg every 12 hours depending on infection severity.\n"
        "• Common Side Effects: Nausea, diarrhea, rash, oral candidiasis.\n"
        "• Key Warnings: Contraindicated in penicillin-hypersensitive patients; monitor renal function in prolonged therapy."
    ),
    "metformin": (
        "Metformin 850mg (Biguanide Antidiabetic):\n"
        "• Indications: First-line oral therapy for Type 2 Diabetes Mellitus.\n"
        "• Dosage: Initial 500mg - 850mg once or twice daily with meals (Max: 2550mg/day).\n"
        "• Common Side Effects: Gastrointestinal upset (abdominal pain, diarrhea, nausea), metallic taste.\n"
        "• Key Warnings: Risk of Lactic Acidosis; withhold prior to iodinated contrast procedures and assess renal eGFR."
    ),
    "lisinopril": (
        "Lisinopril 10mg (ACE Inhibitor):\n"
        "• Indications: Hypertension, Heart Failure, post-Myocardial Infarction care.\n"
        "• Dosage: Initial 10mg once daily; maintenance 20mg - 40mg daily.\n"
        "• Common Side Effects: Dry persistent cough, dizziness, hyperkalemia, headache.\n"
        "• Key Warnings: Contraindicated in pregnancy (fetal toxicity); monitor serum potassium and creatinine."
    ),
    "atorvastatin": (
        "Atorvastatin 20mg (HMG-CoA Reductase Inhibitor / Statin):\n"
        "• Indications: Hypercholesterolemia, Primary Dyslipidemia, Cardiovascular disease prevention.\n"
        "• Dosage: 10mg - 80mg once daily.\n"
        "• Common Side Effects: Myalgia, arthralgia, elevated LFTs, nasopharyngitis.\n"
        "• Key Warnings: Monitor baseline liver enzymes; advise patients to report unexplained muscle pain or weakness (rhabdomyolysis risk)."
    ),
    "omeprazole": (
        "Omeprazole 20mg (Proton Pump Inhibitor / PPI):\n"
        "• Indications: GERD, Peptic Ulcer Disease, Erosive Esophagitis, Zollinger-Ellison Syndrome.\n"
        "• Dosage: 20mg - 40mg once daily before meals (typically 30-60 minutes before breakfast).\n"
        "• Common Side Effects: Headache, abdominal pain, flatulence, nausea.\n"
        "• Key Warnings: Long-term use (> 1 year) associated with hypomagnesemia and B12 deficiency."
    ),
    "paracetamol": (
        "Paracetamol / Acetaminophen 500mg (Analgesic & Antipyretic):\n"
        "• Indications: Mild-to-moderate pain and fever reduction.\n"
        "• Dosage: 500mg - 1000mg every 4 to 6 hours as needed (Max: 4000mg/24 hours).\n"
        "• Common Side Effects: Rare at therapeutic doses; allergic cutaneous reactions.\n"
        "• Key Warnings: Severe hepatotoxicity risk with overdose (> 4g/day) or chronic alcohol consumption."
    ),
    "azithromycin": (
        "Azithromycin 250mg (Macrolide Antibiotic):\n"
        "• Indications: Community-acquired pneumonia, acute bacterial sinusitis, pharyngitis/tonsillitis, urethritis.\n"
        "• Dosage: 500mg on Day 1, followed by 250mg once daily on Days 2–5.\n"
        "• Common Side Effects: Diarrhea, nausea, abdominal cramps, QT prolongation.\n"
        "• Key Warnings: Exercise caution in patients with known proarrhythmic conditions or uncorrected hypokalemia."
    ),
    "ibuprofen": (
        "Ibuprofen 400mg (Non-Steroidal Anti-Inflammatory Drug / NSAID):\n"
        "• Indications: Inflammatory joint conditions, musculoskeletal pain, fever, mild-to-moderate pain.\n"
        "• Dosage: 200mg - 400mg every 4 to 6 hours with food (Max OTC: 1200mg/day, Rx Max: 3200mg/day).\n"
        "• Common Side Effects: Dyspepsia, gastric ulceration, bleeding, dizziness.\n"
        "• Key Warnings: Avoid in severe heart failure, active peptic ulcer disease, or late stage pregnancy."
    ),
}


class MedicineQueryRequest(BaseModel):
    message: str
    conversation_history: Optional[List[Dict[str, str]]] = None


class MedicineQueryResponse(BaseModel):
    reply: str


@router.post("/medicine-query", response_model=MedicineQueryResponse)
async def query_medicine_assistant(
    req: MedicineQueryRequest,
    current_doctor: Doctor = Depends(get_current_doctor),
):
    """
    LLM-backed AI Medicine Assistant endpoint for medical professionals.
    Strictly scoped to medicine and pharmacology queries; declines non-medical queries.
    Appends mandatory clinical reference disclaimer.
    """
    user_msg = req.message.strip().lower()

    # 1. Out of scope check
    for keyword in NON_MEDICAL_KEYWORDS:
        if re.search(rf'\b{re.escape(keyword)}\b', user_msg):
            return MedicineQueryResponse(
                reply=(
                    "I am specialized strictly in medical and pharmaceutical information. "
                    "I cannot answer queries outside the medical scope."
                    + MANDATORY_DISCLAIMER
                )
            )

    # 2. Try LLM API (OpenAI) if API key available
    openai_key = settings.OPENAI_API_KEY or os.getenv("OPENAI_API_KEY")
    if not openai_key or len(openai_key) <= 10:
        logger.warning(f"[AI ASSISTANT] OPENAI_API_KEY is missing or invalid: {repr(openai_key)}")
    else:
        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                system_prompt = (
                    "You are a specialized AI Clinical Medicine Assistant for licensed medical professionals. "
                    "You ONLY answer questions about drugs, medications, clinical dosages, drug interactions, side effects, "
                    "and pharmacology. If asked anything outside medical/pharmaceutical information, decline politely. "
                    "Keep answers structured, concise, and accurate."
                )
                messages = [{"role": "system", "content": system_prompt}]
                if req.conversation_history:
                    for h in req.conversation_history[-4:]:
                        messages.append({"role": h.get("role", "user"), "content": h.get("content", "")})
                messages.append({"role": "user", "content": req.message})

                res = await client.post(
                    "https://api.openai.com/v1/chat/completions",
                    headers={"Authorization": f"Bearer {openai_key.strip()}"},
                    json={
                        "model": "gpt-3.5-turbo",
                        "messages": messages,
                        "temperature": 0.3,
                        "max_tokens": 400,
                    },
                )
                if res.status_code == 200:
                    answer = res.json()["choices"][0]["message"]["content"].strip()
                    if not answer.endswith(MANDATORY_DISCLAIMER):
                        answer += MANDATORY_DISCLAIMER
                    return MedicineQueryResponse(reply=answer)
                else:
                    logger.error(f"[AI ASSISTANT] OpenAI API returned HTTP {res.status_code}: {res.text}")
        except Exception as e:
            logger.error(f"[AI ASSISTANT] OpenAI API call exception: {e}", exc_info=True)

    # 3. Fallback Structured Medical Knowledge Engine
    for drug_key, drug_info in MEDICAL_KNOWLEDGE_BASE.items():
        if drug_key in user_msg:
            return MedicineQueryResponse(reply=drug_info + MANDATORY_DISCLAIMER)

    # Generic clinical response if medical query doesn't match specific drug keyword
    generic_reply = (
        f"Regarding your clinical query on '{req.message.strip()}':\n"
        "Pharmacological considerations: Always verify drug dosages, patient hypersensitivities, "
        "renal/hepatic clearance function, and potential cytochrome P450 drug-drug interactions "
        "before prescribing or administering therapy."
    )
    return MedicineQueryResponse(reply=generic_reply + MANDATORY_DISCLAIMER)
