<script>
export default {
  name: "AppNavbar"
}
</script>

<template>
  <b-navbar variant="faded" type="dark">
    <b-navbar-brand href="/">Floaty</b-navbar-brand>
    <b-nav-item>
      <a href="/home">Home</a>
    </b-nav-item>
    <b-nav-item>
      <a href="/org">Admin</a>
    </b-nav-item>
  </b-navbar>
</template>

<style scoped>
  navbar {
    background-color: #333333;
  }
</style>