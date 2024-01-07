let periodTable = document.getElementById("periodData");
let urlSchoolId = new URLSearchParams(location.search);
let exportBtn = document.getElementById("submitExport-btn");
let isTableLoaded = false;

function fillTable(jres) {
    let rootTable = document.getElementById('rootTableBody');
    let optRow;
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
                    if (el !== "amount") optCellPropAbsent.innerHTML = '-';
                    else optCellPropAbsent.innerHTML = 0;
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

        let startFormulaRow = 200;
        let endFormulaRow =  0;

        for (let i = 1; i < rowCount; i++) {
            let nameCellValue = ws[`A${i+2}`]?.v;

            if (nameCellValue && /^[0-9]+[А-Яа-я]$/.test(nameCellValue)) {
                const classNumber = parseInt(nameCellValue);

                if (classNumber >= 5 && classNumber <= 11) {
                    if (i+2 > endFormulaRow) {
                        endFormulaRow = i+2;
                    }
                    if (endFormulaRow < startFormulaRow) {
                        startFormulaRow = endFormulaRow;
                    }
                }

            }

        }

// Определяем последнюю строку таблицы
        let totalStudents = `=СУММ(B${startFormulaRow}:B${endFormulaRow})`
        let absentStudents = `=СУММ(C${startFormulaRow}:C${endFormulaRow})`

        const lastRow = rowCount + 2;

        XLSX.utils.sheet_add_aoa(ws, [['Всего']], {origin: `A${lastRow}`});
        XLSX.utils.sheet_add_aoa(ws, [[totalStudents]], {origin: `B${lastRow}`});
        XLSX.utils.sheet_add_aoa(ws, [[absentStudents]], {origin: `C${lastRow}`});

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
                schoolId: urlSchoolId.get("schoolId"),
                period: period,
                method: 'getCommonCase'
            })
        })
            .then(res => {
                const jres = res.json()
                    .then(jres => {
                        fillTable(jres);
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
                schoolId: urlSchoolId.get("schoolId"),
                period: period,
                date: splitDate[0] + '.' + splitDate[1] + '.' + splitDate[2],
                method: 'getCustom'
            })
        })
            .then(res => {
                const jres = res.json()
                    .then(jres => {
                        fillTable(jres);
                    })
                isTableLoaded = true;
            })
    }
}
