// ====================================================================
// REUSABLE COPY FUNCTION (This part is correctly structured)
// ====================================================================
function setupCopyButton(buttonId, contentId) {
    const copyButton = document.getElementById(buttonId);
    const contentToCopy = document.getElementById(contentId);

    if (copyButton && contentToCopy) {
        copyButton.addEventListener('click', () => {
            const textToCopy = contentToCopy.innerText;

            navigator.clipboard.writeText(textToCopy)
                .then(() => {
                    // alert(`Content for ${contentId} copied successfully!`);
                    console.log(`Content from ${contentId} successfully copied.`);
                })
                .catch(err => {
                    console.error('Could not copy text: ', err);
                    alert('Failed to copy content. Please try again.');
                });
        });
    } else {
        // Log errors if the elements are missing in the HTML
        if (!copyButton) {
            console.error(`Copy Button with ID '${buttonId}' was not found.`);
        }
        if (!contentToCopy) {
            console.error(`Content Element with ID '${contentId}' was not found.`);
        }
    }
}

// ====================================================================
// MAIN EXECUTION BLOCK (Runs ONLY when the page is fully loaded)
// ====================================================================

document.addEventListener('DOMContentLoaded', () => {

    // --- 1. SETUP CONFIGURATION BUTTON (CLEANED UP) ---

    // --- 2. SETUP MULTIPLE COPY BUTTONS ---

    // Note: You must ensure 'quoteContent', 'summaryContent', etc., are the
    // correct IDs for the content areas in your HTML.

    setupCopyButton('copyButton0', 'contentToCopy0');
    setupCopyButton('copyButton1', 'contentToCopy1');
    setupCopyButton('copyButton2', 'contentToCopy2');
    setupCopyButton('copyButton3', 'contentToCopy3');
    setupCopyButton('copyButton4', 'contentToCopy4');
    setupCopyButton('copyButton5', 'contentToCopy5');
    // You had multiple setup calls for the same button IDs but different content
    // IDs in your previous code. I've updated these to match the IDs
    // in your provided HTML structure (contentToCopy0, contentToCopy1, etc.).
});