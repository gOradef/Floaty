 function getLastKnownDataAbClass() {
    //TODO МБ сделать
    console.log("state is changed");
}
window.addEventListener("DOMContentLoaded", (event) => {
        let urlParams = new URLSearchParams (location.search);
        let classesList = document.getElementById("classSelect");
        let submitBtn = document.getElementById("submitBtn");

        fetch('/api/getDataClassesForm?schoolId=' + urlParams.get("schoolId"), {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify( {
                Cookie: document.cookie,
                params: location.search
            })
        })
        //get 'names' attribute of class
            .then(response => {
                if (response.status == 404) {
                    alert("Please wait a litl bit, and reload a page after. Data is generating \n" +
                        "you are the first person, what request data)")
                    location.reload();
                }
                else {
                    const jres = response.json()
                        .then(jres => {
                            let classes = jres["classes"];
                            let numClass;
                            let letterClass;
                            let nameClass;
                            for(let i in classes) {
                                numClass = classes[i];
                                for (letterClass in numClass) {
                                    nameClass = numClass[letterClass].name;
                                    let opt = document.createElement('option');
                                    opt.innerHTML = nameClass;
                                    classesList.appendChild(opt);
                                }
                            }

                    })
                }

            }
            )
            classesList.addEventListener("change", ev => getLastKnownDataAbClass())
    }
)