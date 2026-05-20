// Manages the form loading state and clipboard actions for RolePrepAI.

document.addEventListener("DOMContentLoaded", function () {
    const form = document.getElementById("question-form");
    const submitButton = document.getElementById("submit-button");
    const loadingState = document.getElementById("loading-state");
    const results = document.getElementById("results");
    const errorMessage = document.getElementById("error-message");
    const emptyState = document.getElementById("empty-state");

    if (!form || !submitButton || !loadingState) return;

    form.addEventListener("submit", function () {
        submitButton.classList.add("hidden");
        loadingState.classList.remove("hidden");
        loadingState.classList.add("inline-flex");

        if (results) results.classList.add("hidden");
        if (errorMessage) errorMessage.classList.add("hidden");
        if (emptyState) emptyState.classList.add("hidden");
    });

    // Reset loading state on browser back button
    window.addEventListener("pageshow", function () {
        submitButton.classList.remove("hidden");
        loadingState.classList.add("hidden");
        loadingState.classList.remove("inline-flex");
    });
});


/**
 * Copies a single question to the clipboard.
 * @param {HTMLElement} button - The copy button element.
 */
function copyQuestion(button) {
    const text = button.getAttribute("data-question");
    const copyTextSpan = button.querySelector(".copy-text");
    const originalText = copyTextSpan.textContent;

    navigator.clipboard.writeText(text).then(() => {
        copyTextSpan.textContent = "Copied!";
        button.classList.add("text-teal-700", "bg-teal-50");

        setTimeout(() => {
            copyTextSpan.textContent = originalText;
            button.classList.remove("text-teal-700", "bg-teal-50");
        }, 2000);
    });
}


/**
 * Copies all three questions to the clipboard as a numbered list.
 */
function copyAllQuestions() {
    const cards = document.querySelectorAll("[data-question]");
    const copyAllText = document.getElementById("copy-all-text");

    if (!cards.length || !copyAllText) return;

    const text = Array.from(cards)
        .map((btn, i) => `${i + 1}. ${btn.getAttribute("data-question")}`)
        .join("\n");

    navigator.clipboard.writeText(text).then(() => {
        copyAllText.textContent = "Copied!";

        setTimeout(() => {
            copyAllText.textContent = "Copy all";
        }, 2000);
    });
}