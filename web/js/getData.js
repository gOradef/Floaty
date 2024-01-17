
function parseNames(namesRoot) {
    let namesList = [];
    namesRoot = namesRoot.replace(/,/g, ' ');
    let namesSplited = namesRoot.split(' ');
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
        fetch('/api/getDataClassesForm', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify( {
                Cookie: document.cookie,
                schoolId: urlParams.get("schoolId"),
                method: 'getCommonCaseForm'
            })
        })
        //get 'names' attribute of class
            .then(response => {
                if (response.status === 404) {
                    alert("Please wait a litl bit, and reload a page after. Data is generating \n" +
                        "you are the first person, what request data)")
                    location.reload();
                }
                else {
                    const jres = response.json()
                        .then(jres => {
                            let classes = jres;
                            classes.sort(function(a, b) {return a.split('_')[0]-b.split('_')[0];});
                            let nameClass;
                            for(let i in classes) {
                                    nameClass = classes[i].split('_')[0] + classes[i].split('_')[1];

                                    let opt = document.createElement('option');
                                    opt.innerHTML = nameClass;
                                    classesList.appendChild(opt);
                            }

                    })
                }

            }
            )
    document.getElementById('submitBtn').addEventListener("click", async () => {
                    let urlSchoolId = urlParams.get("schoolId");
                    let className = document.getElementById("classSelect").value;
                    let classNum = className.slice(0, className.length-1);
                    let classLetter = className.charAt(className.length-1);
                    className = classNum + '_' + classLetter;

                    let globalNum = document.getElementById("globalNum").value;
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
                            globalNum: globalNum,
                            absentNum: absentNum,
                            absentVir: absentVir,
                            absentRespCause: absentRespCause,
                            absentNonRespCause: absentNonRespCause,
                            absentFreeMeal: absentFreeMeal
                        })
                    })

                        .then(res => {
                        if (res.status === 200) {
                                alert("Form submitted!");
                                location.href += urlParams;
                                location.reload();
                            }
                            else {
                                alert("Form doesn't submitted")
                            }

                        })

                })
            })
