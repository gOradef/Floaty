let isRedactorModeEntered = false;
let dataTable;
let changesList = {
    editChanges: {},
    listChanges: {
        add: [],
        rm: []
    }};
//Region export popup
document.getElementById('openExport-btn').addEventListener('click', function() {
    document.getElementById('popupExport').style.display = 'block';
});

document.querySelector('.closeExport-btn').addEventListener('click', function() {
    document.getElementById('popupExport').style.display = 'none';
});

document.getElementById('submitExport-btn').addEventListener('click', function() {
    let selectElementPeriod = document.getElementById('time');
    let selectedOptionPeriod = selectElementPeriod.options[selectElementPeriod.selectedIndex].value;
    let selectElementType = document.getElementById('file-extension');
    let selectedOptionType = selectElementType.options[selectElementType.selectedIndex].value;

    exportTable(selectedOptionPeriod, selectedOptionType);

    document.getElementById('popupExport').style.display = 'none';
});
//End export popup

//Region redactor mode
document.getElementById("openRedactMode-btn").addEventListener('click', function() {
    let rootTableHeader = document.getElementById('rootTableHeader')
    let rootTable = document.getElementById('rootTableBody');
        

    function getTableData() {
        let data = {};
        for (let row=0;row< rootTable.children.length; row++) {
            for (let cell = 0; cell <  rootTable.children[row].children.length; cell++) {
                rootTable.children[row].children[cell].id = rootTableHeader.children[cell].id;
                }
        }

        for (let row=0;row< rootTable.children.length; row++) {
            for (let cell = 0; cell <  rootTable.children[row].children.length; cell++) {
            const input = document.createElement('input');
            input.type = 'text';
            input.value = rootTable.children[row].children[cell].innerText;
            input.style.width = '80px';
            rootTable.children[row].children[cell].name
            rootTable.children[row].children[cell].innerText = '';
            rootTable.children[row].children[cell].appendChild(input);
            }
        }

        let rowData = [];
        if (JSON.stringify(data).length === 0 || '{}') {
            for (let row= 0;row < rootTable.children.length; row++) {
                for (let cell = 0; cell <  rootTable.children[row].children.length; cell++) {
                    rowData.push(rootTable.children[row].children[cell].firstChild.valueOf().value);
                }
                data[row] = rowData;
                rowData = [];
            }
        }
        return data;
    }
    function insertData(data) {

        let jsonObj = {};

        for (let row=0;row< rootTable.children.length; row++) {
            jsonObj = {};
            for (let cell = 0; cell <  rootTable.children[row].children.length; cell++) {

                rootTable.children[row].children[cell].innerHTML = rootTable.children[row].children[cell].firstChild.valueOf().value;

                if (rootTable.children[row].children[cell].innerHTML !== data[row][cell]) {
                    jsonObj[rootTable.children[row].children[cell].id] = rootTable.children[row].children[cell].innerHTML;
                    rootTable.children[row].children[cell].className += 'modifiedCell';
                }
                if (jsonObj[rootTable.children[row].children[cell].id] !== undefined) {
                    let className = dataTable[row][0];
                    let classNum = className.slice(0, className.length-1);
                    let classLetter = className.charAt(className.length-1);
                    className = classNum + '_' + classLetter;
                    changesList['editChanges'][className] = jsonObj;
                }
            }
        }

        console.log(changesList);

    }
    switch (isRedactorModeEntered) {
        case false:
            document.getElementById("openRedactMode-btn").innerHTML = 'Сохранить изменения у себя';
            document.getElementById('confirmChangesTable-btn').style.display = 'none';
            dataTable = getTableData();
            if(dataTable === undefined) {
                document.getElementById("openRedactMode-btn").innerHTML = 'Редактировать значения';
                return;
            }
            isRedactorModeEntered = true;
            break;

        case true:
            document.getElementById("openRedactMode-btn").innerHTML = 'Редактировать значения';
            document.getElementById('confirmChangesTable-btn').style.display = 'flex';
            isRedactorModeEntered = false;
            insertData(dataTable);
            break;

    }})
document.getElementById('confirmChangesTable-btn').addEventListener('click', function () {
    if (isRedactorModeEntered) {
        alert('Сначала сохраните изменения')
        return;
    }
    if (confirm("Вы уверены? Данные, которые были изменены будут внесены на сервер.")) {
        if (isCommonCaseTableLoaded) {
        fetch('/api/editDataClassesInterface', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                schoolId: urlParams.get("schoolId"),
                method: 'commonCase',
                action: 'edit',
                changesList: changesList
            })
        }).then(res => {
            alert('Запрос отправлен!');
            if (res.status === 200) {
                alert('Данные успешно изменены!');
            }
            changesList = {
                editChanges: {},
                listChanges: {
                    add: [],
                    rm: []
                }
            };
        })
        }
        else if (isCommonCaseTableLoaded === false) {

            fetch('/api/editDataClassesInterface', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    schoolId: urlParams.get("schoolId"),
                    method: 'customCase',
                    action: 'edit',
                    date: userDate,
                    changesList: changesList
                })
            }).then(res => {
                alert('Запрос отправлен!');
                if (res.status === 200) {
                    alert('Данные успешно изменены!');
                }
                changesList = {
                    editChanges: {},
                    listChanges: {
                        add: [],
                        rm: []
                    }
                };
            })
        }
    }
})
//End redactor mode


//Region getTableForDate
document.getElementById('getTable-btn').addEventListener('click', function() {
    document.getElementById('popupTable').style.display = 'block';
});
document.querySelector('.closeTable-btn').addEventListener('click', function() {
    document.getElementById('popupTable').style.display = 'none';
});

document.getElementById('periodTable').addEventListener('change', function() {
    if (document.getElementById('periodTable').value === 'usercase') {
        document.getElementById('userDateCont').style.display = 'flex';
        document.getElementById('userDTDCont').style.display = 'none';

    }
    else if (document.getElementById('periodTable').value === 'DTD') {

        document.getElementById('userDTDCont').style.display = 'flex';
        document.getElementById('userDateCont').style.display = 'none';
    }
    else {
        document.getElementById('userDTDCont').style.display = 'none';
        document.getElementById('userDateCont').style.display = 'none';
    }
})

document.getElementById('submitTable-btn').addEventListener('click', function() {
    let selectElement = document.getElementById('periodTable');
    let selectedOption = selectElement.options[selectElement.selectedIndex].value;
    if (selectedOption === 'usercase') {
        let userCustomDate = document.getElementById('userCustomDate').value;
        userDate = userCustomDate;
        getDataForTable(selectedOption, userCustomDate);
    }
    else if (selectedOption === 'DTD') {
        function getListOfDates(dateStart, dateEnd) {
            dateStart = new Date(dateStart);
            dateEnd = new Date(dateEnd);

            let listDates = [];

            let currentDate = new Date(dateStart);
            while (currentDate <= dateEnd) {
                listDates.push(currentDate.getFullYear() + '.' + currentDate.getMonth() + '.' + currentDate.getDate());
                currentDate.setDate(currentDate.getDate()+1);
            }
            return listDates;
        }

        let dateStart = document.getElementById('userDTDStart').value;
        let dateStop = document.getElementById('userDTDEnd').value;
        console.log(dateStart, dateStop);
        let dateList = getListOfDates(dateStart, dateStop);
        getDataForTable('dateToDate', dateList);

    }
    else {
        userDate = 'today';
        getDataForTable(selectedOption);
    }
    document.getElementById('popupTable').style.display = 'none';
});
//End getTableForDate