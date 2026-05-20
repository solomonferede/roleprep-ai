// Manages the form loading state for the RolePrepAI interface.
document.addEventListener("DOMContentLoaded", function () {
    const form = document.getElementById("question-form");
    const submitButton = document.getElementById("submit-button");
    const loadingState = document.getElementById("loading-state");
    const results = document.getElementById("results");
    const errorMessage = document.getElementById("error-message");
    const emptyState = document.getElementById("empty-state");

    if (!form || !submitButton || !loadingState) {
        return;
    }

    form.addEventListener("submit", function () {
        submitButton.classList.add("hidden");
        loadingState.classList.remove("hidden");
        loadingState.classList.add("inline-flex");

        if (results) {
            results.classList.add("hidden");
        }

        if (errorMessage) {
            errorMessage.classList.add("hidden");
        }

        if (emptyState) {
            emptyState.classList.add("hidden");
        }
    });
});
