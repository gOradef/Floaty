<template>
    <div class="container-fluid d-flex align-items-center justify-content-center min-vh-100 bg-light">
      <div class="card shadow-sm" style="width: 400px;">
        <div class="card-body">
          <h4 class="card-title text-center">Вход</h4>
            <b-form @submit.prevent="onSubmit">
              <b-form-group  label="Логин" label-for="login">
                <b-form-input id="login" type="text" required v-model="username" placeholder="Введите логин">

                </b-form-input>
              </b-form-group>

              <b-form-group label="Пароль" label-for="password">
                <b-form-input id="password" type="password" required v-model="password" placeholder="Введите пароль">

                </b-form-input>
              </b-form-group>
            </b-form>

            <button type="submit" class="btn btn-primary btn-block">Войти</button>

          <div style="display: flex; justify-content: center;">
            <router-link to="#foo" style="color: blue; text-decoration: underline;">
              Есть приглашение?
            </router-link>
          </div>
        </div>
      </div>
    </div>
  </template>
  
  <script>
  export default {
    name: 'LoginPage',
    data() {
      return {
        username: '',
        password: ''
      };
    },
    methods: {
      onSubmit() {
        // Логика обработки отправки формы
        console.log('Username:', this.username);
        console.log('Password:', this.password);
        // Здесь должна быть ваша логика аутентификации
      }
    }
  }
  </script>
  
  <style scoped>
  label {
    text-align: start;
  }
  </style>