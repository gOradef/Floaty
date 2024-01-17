let urlParams = new URLSearchParams(location.search);
let isTableLoaded = false;

function fillTable(jres, date) {
    let rootTable = document.getElementById('rootTableBody');
    let journalTitle = document.getElementById('journalTitle');
    let optRow;
    let classes = jres["classes"];
    let numClass;
    let letterClass;
    let nameClass;


    //Fill date
    journalTitle.innerText = " | " + date;

    //Filling cells
    for(let i in classes) { //num
        numClass = classes[i];
        for (letterClass in numClass) { //num -> letter
            // * Get name of class
            nameClass = numClass[letterClass].name;
            let numAndLetter = nameClass.split('_');
            nameClass = numAndLetter[0] + numAndLetter[1];
            // * Row
            optRow = document.createElement('tr');

            // * Row Name
            let optCellName = document.createElement('td');
            optCellName.innerText = nameClass;
            optRow.append(optCellName);

            // * Row base amount
            let optCellPropAmount = document.createElement('td');
            if (classes[i][letterClass].amount === null || classes[i][letterClass].amount.length === 0) {
                optCellPropAmount.innerText = 0;
            }
            else {
                optCellPropAmount.innerText = classes[i][letterClass].amount;
            }
            optRow.append(optCellPropAmount)

            let mapAbsent = new Map();
            // * Set map of props
            for (let el in classes[i][letterClass].absent) {
                let optCellPropAbsent = document.createElement('td');
                if (classes[i][letterClass].absent[el] === null || classes[i][letterClass].absent[el].length === 0) {
                    if (el !== "amount") optCellPropAbsent.innerText = '-';
                    else optCellPropAbsent.innerText = 0;
                }
                else {
                    optCellPropAbsent.innerText = classes[i][letterClass].absent[el];
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

}

function exportTable (period, type) {
    if (isTableLoaded === false) {
        alert("Сначала загрузите таблицу")
    }
    else {
        const filename = "exportedSheet." + type;
        const table = document.getElementById("rootTable");
        const wb = XLSX.utils.table_to_book(table);

        const ws = wb.Sheets[wb.SheetNames[0]];

        const rowCount = XLSX.utils.sheet_to_json(ws).length;

        let startFormulaRowMed = 2000;
        let endFormulaRowMed =  0;

        let startFormulaRowBeg = 2000;
        let endFormulaRowBeg =  0;


        for (let i = 1; i < rowCount; i++) {
            let nameCellValue = ws[`A${i+2}`]?.v;

            if (nameCellValue && /^[0-9]+[А-Яа-я]$/.test(nameCellValue)) {
                const classNumber = parseInt(nameCellValue);

                if (classNumber < 5 && classNumber >= 1) {
                    if (i+2 > endFormulaRowBeg) {
                        endFormulaRowBeg = i+2;
                    }
                    if (endFormulaRowBeg < startFormulaRowBeg) {
                        startFormulaRowBeg = endFormulaRowBeg;
                    }
                }
                else if (classNumber >= 5 && classNumber <= 11) {
                    if (i+2 > endFormulaRowMed) {
                        endFormulaRowMed = i+2;
                    }
                    if (endFormulaRowMed < startFormulaRowMed) {
                        startFormulaRowMed = endFormulaRowMed;
                    }
                }

            }

        }

        let totalStudents = `=СУММ(B${startFormulaRowBeg}:B${endFormulaRowMed})`;
        let absentStudentsBeg = `=СУММ(C${startFormulaRowBeg}:C${endFormulaRowBeg})`;
        let absentStudentsMed = `=СУММ(C${startFormulaRowMed}:C${endFormulaRowMed})`;
        let absentStudentTotal = `=СУММ(C${startFormulaRowBeg}:C${endFormulaRowMed})`;

        const lastRow = rowCount + 2;

        XLSX.utils.sheet_add_aoa(ws, [['Всего']], {origin: `A${lastRow}`});
        XLSX.utils.sheet_add_aoa(ws, [['1-4 классы']], {origin: `B${lastRow}`});
        XLSX.utils.sheet_add_aoa(ws, [['5-11 классы']], {origin: `C${lastRow}`});
        XLSX.utils.sheet_add_aoa(ws, [['Всего нет']], {origin: `D${lastRow}`});

        XLSX.utils.sheet_add_aoa(ws, [[totalStudents]], {origin: `A${lastRow+1}`});
        XLSX.utils.sheet_add_aoa(ws, [[absentStudentsBeg]], {origin: `B${lastRow+1}`});        
        XLSX.utils.sheet_add_aoa(ws, [[absentStudentsMed]], {origin: `C${lastRow+1}`});
        XLSX.utils.sheet_add_aoa(ws, [[absentStudentTotal]], {origin: `D${lastRow+1}`});

        XLSX.writeFile(wb, filename);
    }
}
function getDataForTable(period = "today", dateRoot = 'none') {
    //delete previous table
    if (isTableLoaded === true) {
        document.getElementById('rootTableBody').innerHTML = '';
    }
    if (period !== 'usercase') {
        fetch('/api/getDataClassesInterface', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                schoolId: urlParams.get("schoolId"),
                period: period,
                method: 'getCommonCase'
            })
        })
            .then(res => {
                const jres = res.json()
                    .then(jres => {
                        fillTable(jres, res.headers.get('date'));
                    })
                isTableLoaded = true;
            })
    } else {
        let splitDate = dateRoot.split('-');
        if (splitDate[1].at(0) === "0") splitDate[1] = splitDate[1].at(1);
        if (splitDate[2].at(0) === "0") splitDate[2] = splitDate[2].at(1);
        fetch('/api/getDataClassesInterface', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                schoolId: urlParams.get("schoolId"),
                period: period,
                date: splitDate[0] + '.' + splitDate[1] + '.' + splitDate[2],
                method: 'getCustomCase'
            })
        })
            .then(res => {
                const jres = res.json()
                    .then(jres => {
                        fillTable(jres, res.headers.get('date'));
                    })
                isTableLoaded = true;
            })
    }
}
