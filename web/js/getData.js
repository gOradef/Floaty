function parseNames(namesRoot) {
    let namesList = [];
    namesSplited = namesRoot.split(' ');
    for(let el in namesSplited) {
        if(namesSplited[el] !== "") {
            namesList.push(namesSplited[el]);
        }
    }
    return namesList;
}



window.addEventListener("DOMContentLoaded", (event) => {
    let urlParams = new URLSearchParams(location.search);
    let classesList = document.getElementById("classSelect");
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
                                    let numAndLetter = nameClass.split('_');
                                    let opt = document.createElement('option');
                                    opt.innerHTML = numAndLetter[0]+ numAndLetter[1];
                                    classesList.appendChild(opt);
                                }
                            }

                    })
                }

            }
            )
            .then(ev=> {
                window.addEventListener("submit", ev => {
                    let urlSchoolId = urlParams.get("schoolId");
                    console.log(urlSchoolId);
                    let className = document.getElementById("classSelect").value;
                    let classNum = className.slice(0, className.length-1);
                    let classLetter = className.charAt(className.length-1);
                    className = classNum + '_' + classLetter;

                    let absentNum = document.getElementById("absentNum").value;

                    let absentVir = document.getElementById("absentVir").value;
                    absentVir = parseNames(absentVir);

                    let absentRespCause = document.getElementById("absentRespCause").value;
                    absentRespCause = parseNames(absentRespCause);

                    let absentNonRespCause = document.getElementById("absentNonRespCause").value;
                    absentNonRespCause = parseNames(absentNonRespCause);

                    let absentFreeMeal = document.getElementById("absentFreeMeal").value;
                    absentFreeMeal = parseNames(absentFreeMeal);



                    fetch('/api/editDataClassesForm?schoolId=' + urlSchoolId, {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json'
                        },
                        body: JSON.stringify({
                            schoolId: urlSchoolId,
                            className: className,
                            absentNum: absentNum,
                            absentVir: absentVir,
                            absentRespCause: absentRespCause,
                            absentNonRespCause: absentNonRespCause,
                            absentFreeMeal: absentFreeMeal
                        })
                    })
                })
            })

    }
)

