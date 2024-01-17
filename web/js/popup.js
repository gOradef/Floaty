let isRedactorModeEntered = false;
let dataTable;
let changesList = {"classes": {}};

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
        
    let cells = document.querySelectorAll('table tr td')

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
        console.log(data);
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
                    changesList['classes'][rootTable.children[row].children[0].innerHTML] = jsonObj;
                }
            }
        }

        console.log(changesList);

    }

    switch (isRedactorModeEntered) {
        case false:
            document.getElementById("openRedactMode-btn").innerHTML = 'Сохранить изменения';
            document.getElementById('confirmChangesTable-btn').style.display = 'none';
            dataTable = getTableData();
            isRedactorModeEntered = true;
            break;

        case true:
            document.getElementById("openRedactMode-btn").innerHTML = 'Редактировать';
            document.getElementById('confirmChangesTable-btn').style.display = 'flex';
            isRedactorModeEntered = false;
            insertData(dataTable);
            break;

    }
    if (isRedactorModeEntered) {
    }

})

document.getElementById('confirmChangesTable-btn').addEventListener('click', function () {
    if (isRedactorModeEntered) {
        alert('Сначало сохраните изменения')
        return;
    }
    if (confirm("Вы уверены? Данные, которые были изменены будут внесены на сервер.")) {

        alert('oke')
    }
    else {
        alert('ne oke')

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
    }
    else document.getElementById('userDateCont').style.display = 'none';
})

document.getElementById('submitTable-btn').addEventListener('click', function() {
    let selectElement = document.getElementById('periodTable');
    let selectedOption = selectElement.options[selectElement.selectedIndex].value;
    if (selectedOption === 'usercase') {
        let userCustomDate = document.getElementById('userCustomDate').value;
        getDataForTable(selectedOption, userCustomDate);
    }
    else {
        getDataForTable(selectedOption);
    }
    document.getElementById('popupTable').style.display = 'none';
});
//End getTableForDate