# Handles the RolePrepAI form flow and Gemini-powered question generation.
import logging
import re
import time

from django.conf import settings
from django.shortcuts import render
from google.genai import errors as genai_errors

logger = logging.getLogger(__name__)


def _parse_questions(response_text):
    """Convert Gemini's text response into a clean list of up to 3 questions."""
    questions = []

    for line in response_text.splitlines():
        cleaned = line.strip()
        if not cleaned:
            continue

        cleaned = re.sub(r"^\s*(?:[-*•]|\d+[\).\-\s]+)\s*", "", cleaned).strip()
        if cleaned:
            questions.append(cleaned)

    if len(questions) < 3:
        fallback_questions = re.findall(r"[^?]+\?", response_text)
        questions = [
            question.strip() for question in fallback_questions if question.strip()
        ]

    return questions[:3]


def _extract_response_text(response):
    """Read Gemini response text safely, even when the SDK omits text output."""
    try:
        return response.text or ""
    except ValueError:
        return ""


def _is_quota_error(error):
    """Identify Gemini quota and rate-limit responses across SDK versions."""
    message = getattr(error, "message", str(error))
    return getattr(error, "status", None) == 429 or "RESOURCE_EXHAUSTED" in message


def _generate_questions_text(prompt):
    """Call Gemini with exponential backoff for transient quota responses."""
    from google import genai

    client = genai.Client(api_key=settings.GEMINI_API_KEY)
    retries = 3
    delay = 2

    for attempt in range(retries):
        try:
            response = client.models.generate_content(
                model="gemini-2.0-flash",
                contents=prompt,
            )
            break
        except genai_errors.APIError as error:
            if not _is_quota_error(error) or attempt == retries - 1:
                raise

            logger.warning(
                "Gemini quota limit hit. Retrying in %s seconds. Attempt %s of %s.",
                delay,
                attempt + 1,
                retries,
            )
            time.sleep(delay)
            delay *= 2

    return _extract_response_text(response)


def _gemini_error_message(error):
    """Return a helpful message for known Gemini API failures."""
    status = getattr(error, "status", None)
    message = getattr(error, "message", str(error))

    if status == 429 or "RESOURCE_EXHAUSTED" in message:
        return (
            "Gemini quota has been reached for this API key. "
            "Please wait a moment or check your Gemini plan and billing details."
        )

    if status in {400, 401, 403}:
        return (
            "Gemini rejected the request. Please check that your API key is valid "
            "and has access to gemini-2.0-flash."
        )

    return "Gemini returned an API error. Please try again in a moment."


def index(request):
    """Render the homepage and generate interview questions on form submission."""
    context = {"job_title": ""}

    if request.method == "POST":
        job_title = request.POST.get("job_title", "").strip()
        context["job_title"] = job_title

        if not job_title:
            context["error"] = "Please enter a job title before generating questions."
            return render(request, "index.html", context)

        prompt = (
            "You are an expert interview coach. Generate exactly 3 thoughtful, "
            f"professional, role-specific interview questions for a {job_title}. "
            "Return only the questions, one per line, with no introduction or extra commentary."
        )

        try:
            questions = _parse_questions(_generate_questions_text(prompt))

            if len(questions) != 3:
                context["error"] = (
                    "The AI response could not be parsed. Please try again."
                )
            else:
                context["questions"] = questions
        except ImportError:
            logger.exception("The google-genai package is not installed.")
            context["error"] = (
                "Gemini support is not installed. Please install the project requirements."
            )
        except genai_errors.APIError as error:
            logger.warning(
                "Gemini API error for job title %s: %s %s",
                job_title,
                getattr(error, "status", "unknown status"),
                getattr(error, "message", str(error)),
            )
            context["error"] = _gemini_error_message(error)
        except Exception:
            logger.exception(
                "Gemini question generation failed for job title: %s", job_title
            )
            context["error"] = (
                "RolePrepAI could not reach Gemini right now. "
                "Please check your API key, model access, and internet connection, then try again."
            )

    return render(request, "index.html", context)
