document.addEventListener('DOMContentLoaded', () => {
        addEventListener('click', () => {


        fetch('https://sa-avitools-01.vclass.local/api/module04bfix', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
        })
        .then(response => {
            if (!response.ok) {
                throw new Error('Configuration failed');
            }
        })
        .then(data => {
            console.log('Success:', data);
            alert('Configuration applied');
        })
        .catch((error) => {
            console.log('Error:', error);
            alert('clean-up error');
        });
    });
});