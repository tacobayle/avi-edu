document.addEventListener('DOMContentLoaded', () => {
        addEventListener('click', () => {


        fetch('http://sa-avitools-01.vclass.local:8080/api/upgrade', {
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
            alert('Configuration failed');
        });
    });
});