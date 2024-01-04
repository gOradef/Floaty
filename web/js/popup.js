
//Region export popup
document.getElementById('openExport-btn').addEventListener('click', function() {
    document.getElementById('popupExport').style.display = 'block';
});

document.querySelector('.closeExport-btn').addEventListener('click', function() {
    document.getElementById('popupExport').style.display = 'none';
});

document.getElementById('submitExport-btn').addEventListener('click', function() {
    var selectElement = document.getElementById('parameter-select');
    var selectedOption = selectElement.options[selectElement.selectedIndex].value;

    console.log('Выбрана опция: ' + selectedOption); // Измените эту строку в соответствии с вашей логикой обработки выбранной опции

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

document.getElementById('submitTable-btn').addEventListener('click', function() {
    var selectElement = document.getElementById('periodTable');
    var selectedOption = selectElement.options[selectElement.selectedIndex].value;

    getDataForTable(selectedOption);
    document.getElementById('popupTable').style.display = 'none';
});
//End getTableForDate