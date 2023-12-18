window.addEventListener("DOMContentLoaded", (event) => {
  let loginForm = document.getElementById("loginForm");

loginForm.addEventListener("submit", (e) => {
  e.preventDefault();

  let login = document.getElementById("login");
  let password = document.getElementById("password");

  if (login.value == "" || password.value == "") {
    alert("ERROR: Ensure you input a value in both fields!");
  }
  else {
    // Функция для установки cookie
function setCookie(name, value) {
  document.cookie = `${name}=${value}; path=/`;
}

// Выполнение POST-запроса на сервер для аутентификации
  fetch('/login-process', {
    method: 'POST',
    headers: {
        'Content-Type': 'application/json'
    },
    body: JSON.stringify({
        login: login.value,
        password: password.value
    })
  })
  .then(response => {
    if (response.status === 401) {
    login.style = "background-color:#ffdddd;"
    password.style = "background-color:#ffdddd;"
    statusLine = document.getElementById("status");
    statusLine.innerHTML = "Invalid login or password";
    }
    else if(response.status === 200) {
      const jres = response.json()
      .then(jres => {
        const token1 = jres.token;
        setCookie("token", token1);
      })
      .then(token1 => {
        login.style = "background-color:#ddffdd;"
      password.style = "background-color:#ddffdd;"
      
      statusLine = document.getElementById("status");
      statusLine.innerHTML = "U r in!";
      //!TODO remove after testing
      alert("Ur token is: " + document.cookie.valueOf("token"))
      })
      .then(cookie => {
        window.location.assign("/interface");
      })
          }
  })
  .catch(error => console.error(error));

    login.value = "";
    password.value = "";
  }
});
});