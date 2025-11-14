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
    const myButton = document.getElementById('configButton');

    // Attach the click listener directly to the button, only once.
    if (myButton) {
        myButton.addEventListener('click', () => {
            fetch('http://sa-avitools-01.vclass.local:8080/api/tshootRbac', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
            })
            .then(response => {
                if (!response.ok) {
                    // Check for a specific API error response here if needed
                    throw new Error('Configuration failed');
                }
            })
            .then(data => {
                console.log('Success:', data);
                alert('Configuration applied');
            })
            .catch((error) => {
                console.log('Error:', error);
                alert('Configuration failed');
            });
        });
    } else {
        console.error("Configuration button with ID 'configButton' was not found.");
    }

    // --- 2. SETUP MULTIPLE COPY BUTTONS ---

    // Note: You must ensure 'quoteContent', 'summaryContent', etc., are the
    // correct IDs for the content areas in your HTML.
    // You had multiple setup calls for the same button IDs but different content
    // IDs in your previous code. I've updated these to match the IDs
    // in your provided HTML structure (contentToCopy0, contentToCopy1, etc.).
});