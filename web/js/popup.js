
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