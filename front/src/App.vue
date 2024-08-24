<template>
  <div id="app">
    <AppNavbar/>
    <router-view/>
    <AppFooter/>
  </div>
</template>

<style lang="scss">
#app {
  font-family: Avenir, Helvetica, Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  //text-align: center;
  color: #2c3e50;
}

router-view {
  min-height: 3000px;
}
</style>
<script setup lang="ts">
import AppNavbar from "@/components/navbar.vue";
import AppFooter from "@/components/footer.vue";
</script>