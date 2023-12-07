

window.addEventListener("DOMContentLoaded", (event) => {
  let loginForm = document.getElementById("loginForm");

loginForm.addEventListener("submit", (e) => {
  e.preventDefault();

  let login = document.getElementById("login");
  let password = document.getElementById("password");

  if (login.value == "" || password.value == "") {
    alert("Ensure you input a value in both fields!");
  }
  else {
    // perform operation with form input
    alert("This form has been successfully submitted!");
    console.log(
      `This form has a login of ${login.value} and password of ${password.value}`
    );

    login.value = "";
    password.value = "";
  }
});
});