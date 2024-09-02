<script>
export default {
  name: "AppNavbar"
}
</script>

<template>
  <b-navbar toggleable="lg" type="light" variant="light" class="w-100">
    <b-navbar-brand href="/home" style="font-family: Arial, Helvetica, sans-serif;">      
      Ⓕ Floaty
    </b-navbar-brand>
    
      <b-navbar-nav class="ml-auto">
        <b-button variant="outline-primary" href="/login">Войти/Выйти</b-button>
        <!-- Чуть не успеваю доделать измения чтобы работало, собирался делать изменение в зависимости от url -->
        <!-- Лого уже не сильно подходит под деловую атмосферу сайта, не обходимо переработать, примерная идея лого видна на сайте, собираюсь ее сделать более красивой что-лт :/ -->
      </b-navbar-nav>
    
  </b-navbar>
</template>

<style scoped>
  navbar {
    background-color: #333333;
  }
</style>
