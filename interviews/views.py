import logging
import re
from itertools import product

from django.conf import settings
from django.shortcuts import render
from google.genai import errors as genai_errors

logger = logging.getLogger(__name__)


def _generate_questions(prompt):
    from google import genai

    keys = settings.GEMINI_API_KEYS
    models = ["gemini-2.5-flash", "gemini-2.0-flash", "gemini-flash-latest"]
    last_err = None

    for api_key, model in product(keys, models):
        try:
            client = genai.Client(api_key=api_key)
            response = client.models.generate_content(model=model, contents=prompt)
            return response.text or ""
        except genai_errors.APIError as e:
            last_err = e
            status, msg = str(getattr(e, "status", "")), getattr(e, "message", str(e))
            # Retry on transient, quota, or model-not-found errors
            if any(
                x in status or x in msg
                for x in [
                    "404",
                    "NOT_FOUND",
                    "503",
                    "UNAVAILABLE",
                    "429",
                    "RESOURCE_EXHAUSTED",
                ]
            ):
                logger.warning(f"Skipping {model} on {api_key[:8]}...: {status}")
                continue
            raise
    if last_err:
        raise last_err
    return ""


def index(request):
    job_title = (
        request.POST.get("job_title", "").strip() if request.method == "POST" else ""
    )
    context = {"job_title": job_title}

    if job_title:
        prompt = f"Generate 3 professional interview questions for a {job_title}. Return only the questions, one per line."
        try:
            resp = _generate_questions(prompt)
            questions = [
                re.sub(r"^\s*(?:[-*•]|\d+[\).\-\s]+)\s*", "", l).strip()
                for l in resp.splitlines()
                if l.strip()
            ]
            if len(questions) >= 3:
                context["questions"] = questions[:3]
            else:
                context["error"] = "AI response could not be parsed. Please try again."
        except Exception as e:
            logger.warning(f"Gemini error: {e}")
            status, msg = str(getattr(e, "status", "")), getattr(e, "message", str(e))
            if (
                "429" in status
                or "RESOURCE_EXHAUSTED" in status
                or "RESOURCE_EXHAUSTED" in msg
            ):
                context["error"] = (
                    "Quota reached for all keys. Please wait or check billing."
                )
            elif any(s in status for s in ["400", "401", "403"]):
                context["error"] = "Invalid API key or model access denied."
            else:
                context["error"] = "Could not reach Gemini. Please check connection."
    elif request.method == "POST":
        context["error"] = "Please enter a job title."

    return render(request, "index.html", context)
