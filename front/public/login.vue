<template>
    <div class="container-fluid d-flex align-items-center justify-content-center min-vh-100 bg-light">
      <div class="card shadow-sm" style="width: 400px;">
        <div class="card-body">
          <h4 class="card-title text-center">Вход</h4>
          <form @submit.prevent="onSubmit">
            <div class="form-group">
              <label for="username">Логин</label>
              <input type="text" id="username" v-model="username" class="form-control" required />
            </div>
  
            <div class="form-group">
              <label for="password">Пароль</label>
              <input type="password" id="password" v-model="password" class="form-control" required />
            </div>
  
            <button type="submit" class="btn btn-primary btn-block">Войти</button>
          </form>
          <div style="display: flex; justify-content: center;">
            <router-link to="#foo" style="color: blue; text-decoration: underline; margin-top: 10px;">
              Есть приглашение?
            </router-link>
          </div>
        </div>
      </div>
    </div>
  </template>
  
  <script>
  export default {
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
  /* Ваши стили, если необходимо */
  </style>
