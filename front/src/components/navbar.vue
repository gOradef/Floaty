<script>
export default {
  name: "AppNavbar"
}
</script>

<template>
  <b-navbar toggleable="lg" type="light" variant="light" class="border-bottom">
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
  .navbar {
    background-color: #eaf1f8 !important ;
  }
</style>
