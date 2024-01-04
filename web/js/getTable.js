let periodTable = document.getElementById("periodData");
let urlSchoolId = new URLSearchParams(location.search);

function getDataForTable(period = "today") {
    console.log("period is: " + period);
fetch('/api/getDataClassesInterface?schoolId=' + urlSchoolId.get("schoolId"), {
    method: 'POST',
    headers: {
        'Content-Type': 'application/json',
    },
    body: JSON.stringify({
        schoolId: urlSchoolId.get("schoolId"),
        period: period
    })

})
.then(res => {
    const jres = res.json()
        .then(jres => {
            let rootTable = document.getElementById('rootTableBody');
            let optRow;
            let optPreRowColl = [];
            let classes = jres["classes"];
            let numClass;
            let letterClass;
            let nameClass;
            for(let i in classes) { //num
                numClass = classes[i];
                for (letterClass in numClass) { //num -> letter
                    // * Get name of class
                    nameClass = numClass[letterClass].name;
                    let numAndLetter = nameClass.split('_');

                    // * Row
                    optRow = document.createElement('tr');

                    // * Row Name
                    let optCellName = document.createElement('td');
                    optCellName.innerHTML = numAndLetter[0] + numAndLetter[1];
                    optRow.append(optCellName);

                    // * Row base amount
                    let optCellPropAmount = document.createElement('td');
                    optCellPropAmount.innerHTML = classes[i][letterClass].amount;
                    optRow.append(optCellPropAmount)

                    let mapAbsent = new Map();
                    // * Set map of props
                    for (let el in classes[i][letterClass].absent) {
                        let optCellPropAbsent = document.createElement('td');
                        if (classes[i][letterClass].absent[el] === null || classes[i][letterClass].absent[el].length === 0) {
                            optCellPropAbsent.innerHTML = '-';
                        }
                        else {
                            optCellPropAbsent.innerHTML = classes[i][letterClass].absent[el];
                        }
                        mapAbsent.set(el, optCellPropAbsent);
                    }
                    optRow.append(mapAbsent.get("amount"));
                    optRow.append(mapAbsent.get("listVirusCause"));
                    optRow.append(mapAbsent.get("listRespCause"));
                    optRow.append(mapAbsent.get("listNonRespCause"));
                    optRow.append(mapAbsent.get("listFreeMeal"));

                    rootTable.append(optRow);

                }

            }

        })
})

}
