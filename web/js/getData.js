window.addEventListener("DOMContentLoaded", (event) => {
        let classesList = document.getElementById("classesList");
        let submitBtn = document.getElementById("submitBtn");

        fetch('/api/getDataClassesForm', {
            method: 'GET',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify( {

            })
        })
    }
)