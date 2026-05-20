# Handles the RolePrepAI form flow and Gemini-powered question generation.
import logging
import re
from itertools import product as cartesian_product

from django.conf import settings
from django.shortcuts import render
from google.genai import errors as genai_errors

logger = logging.getLogger(__name__)

VALID_DIFFICULTIES = {"Easy", "Medium", "Hard"}


def _build_prompt(job_title, difficulty, question_type):
    """Build the Gemini prompt for interview question generation."""
    return (
        f"Generate 3 professional {difficulty} difficulty {question_type} interview questions "
        f"for a {job_title}. Return only the questions, one per line, "
        "with no introduction or extra commentary."
    )


def _generate_questions(prompt):
    """Try each API key and model combination until one succeeds."""
    from google import genai

    keys = settings.GEMINI_API_KEYS
    models = ["gemini-2.5-flash", "gemini-2.0-flash", "gemini-flash-latest"]
    last_err = None

    for api_key, model in cartesian_product(keys, models):
        try:
            client = genai.Client(api_key=api_key)
            response = client.models.generate_content(
                model=model,
                contents=prompt,
            )
            return response.text or ""
        except genai_errors.APIError as e:
            last_err = e
            status = str(getattr(e, "status", ""))
            msg = getattr(e, "message", str(e))

            retryable = any(
                x in status or x in msg
                for x in [
                    "404",
                    "NOT_FOUND",
                    "503",
                    "UNAVAILABLE",
                    "429",
                    "RESOURCE_EXHAUSTED",
                ]
            )

            if retryable:
                logger.warning("Skipping %s on %s...: %s", model, api_key[:8], status)
                continue

            raise

    if last_err:
        raise last_err

    return ""


def _parse_questions(response_text):
    """Parse Gemini response text into a clean list of 3 questions."""
    return [
        re.sub(r"^\s*(?:[-*•]|\d+[\).\-\s]+)\s*", "", line).strip()
        for line in response_text.splitlines()
        if line.strip()
    ][:3]


def _error_message(error):
    """Return a user-friendly error message for known Gemini API failures."""
    status = str(getattr(error, "status", ""))
    msg = getattr(error, "message", str(error))

    if "429" in status or "RESOURCE_EXHAUSTED" in msg:
        return "Quota reached for all keys. Please wait or check billing."

    if any(s in status for s in ["400", "401", "403"]):
        return "Invalid API key or model access denied."

    return "Could not reach Gemini. Please check your connection."


from django.views.decorators.csrf import csrf_exempt

@csrf_exempt
def index(request):
    """Render homepage and handle interview question generation."""
    job_title = (
        request.POST.get("job_title", "").strip() if request.method == "POST" else ""
    )

    difficulty = request.POST.get("difficulty", "Medium")
    if difficulty not in VALID_DIFFICULTIES:
        difficulty = "Medium"

    question_type = request.POST.get("question_type", "Mixed")

    context = {
        "job_title": job_title,
        "difficulty": difficulty,
        "question_type": question_type,
    }

    if request.method == "POST" and not job_title:
        context["error"] = "Please enter a job title."
        return render(request, "index.html", context)

    if job_title:
        try:
            prompt = _build_prompt(job_title, difficulty, question_type)
            response_text = _generate_questions(prompt)
            questions = _parse_questions(response_text)

            if len(questions) >= 3:
                context["questions"] = questions
            else:
                context["error"] = "AI response could not be parsed. Please try again."

        except Exception as error:
            logger.warning("Gemini error: %s", error)
            context["error"] = _error_message(error)

    return render(request, "index.html", context)
