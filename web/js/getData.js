
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
        fetch('/api/form', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                schoolId: urlParams.get("schoolId"),
                method: 'common',
                Cookie: document.cookie,
                action: "get"
            }})
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

    document.getElementById('overlay').addEventListener('click', () => {
            document.getElementById('overlay').style.display = 'none';
            document.getElementById('preSubmitWindow').style.display = 'none';
    })
    document.getElementById('submitBtn').addEventListener("click",  async () => {
    async function showPreSubmitWindow() {

        return new Promise((resolve, reject) => {
        let preSubmitWindow = document.getElementById('preSubmitWindow');
        let overlay = document.getElementById('overlay');

        let ProceedClass = document.getElementById('ProceedClass').innerHTML = className;

        let ProceedClassNum = document.getElementById('ProceedClassNum').innerHTML = globalNum;
        if (isNaN(globalNum)) {
            let ProceedClassNum = document.getElementById('ProceedClassNum').innerHTML = "по умолчанию";
            globalNum = "";
        }

        // let ProceedFIO = document.getElementById('ProceedFIO').innerHTML; //TODO
        let ProceedAbsentNum = document.getElementById('ProceedAbsentNum').innerHTML = absentNum;
        let ProceedAbsentVir = document.getElementById('ProceedAbsentVir').innerHTML = absentVir;
        let ProceedAbsentRespCause = document.getElementById('ProceedAbsentRespCause').innerHTML = absentRespCause;
        let ProceedAbsentNonRespCause = document.getElementById('ProceedAbsentNonRespCause').innerHTML = absentNonRespCause;
        let ProceedAbsentFreeMeal = document.getElementById('ProceedAbsentFreeMeal').innerHTML = absentFreeMeal;




        overlay.style.display = 'flex'
        preSubmitWindow.style.display = 'flex';


        document.getElementById('overlay').addEventListener('click', () => {
            return resolve(false);
        })

        document.getElementById('breakSubmit').addEventListener('click', () => {
            overlay.style.display = 'none'
            preSubmitWindow.style.display = 'none';
            return resolve(false);
        })

        document.getElementById('proceedSubmit').addEventListener('click', () => {
            overlay.style.display = 'none'
            preSubmitWindow.style.display = 'none';
            return resolve(true);
        })

        })
    }


    let urlSchoolId = urlParams.get("schoolId");
    let className;
    //check - isClassChoosed?
    if (document.getElementById("classSelect").value === "-1") {
        alert('Вы забыли выбрать класс');
        return;
    }
    else {
        className = document.getElementById("classSelect").value;
    }
    let classNum = className.slice(0, className.length-1);
    let classLetter = className.charAt(className.length-1);
    className = classNum + '_' + classLetter;

    let globalNum = parseInt(document.getElementById("globalNum").value);
    let absentNum = parseInt(document.getElementById("absentNum").value);


    //check on valid inputs
    if (isNaN(absentNum) || !(Number.isInteger(globalNum) || Number.isInteger(absentNum))) {
        alert('Пожалуйста, введите число в поля для кол-ва учащихся');
        return;
    }


    let absentVir = document.getElementById("absentVir").value;
    absentVir = parseNames(absentVir);

    let absentRespCause = document.getElementById("absentRespCause").value;
    absentRespCause = parseNames(absentRespCause);

    let absentNonRespCause = document.getElementById("absentNonRespCause").value;
    absentNonRespCause = parseNames(absentNonRespCause);

    let absentFreeMeal = document.getElementById("absentFreeMeal").value;
    absentFreeMeal = parseNames(absentFreeMeal);


    if (await showPreSubmitWindow()) {
        await fetch('/api/form', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            schoolId: urlParams.get("schoolId"),
            method: 'common',
            Cookie: document.cookie,
            action: "edit"
        },
        body: JSON.stringify({
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
                alert("Данные успешно внесены ✔");
            }
        else {
            alert("Произошла непредвиденная ошибка")
        }

        })
    }

})
})
