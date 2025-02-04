<template>
  <div id="app">
    <AppNavbar/>
    <router-view class="router-view"/>
    <AppFooter/>
  </div>
</template>

<style lang="scss">
#app {
  height: 100vh;
  font-family: Avenir, Helvetica, Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  color: #2c3e50;
}

#app >.router-view { // Adjusted selector with increased specificity
  min-height: 95vh;
  display: block; // Ensure display is set appropriately
  height: auto; // Optional, for ensuring min-height works as expected
}
</style>
<script setup lang="ts">
import AppNavbar from "@/components/navbar.vue";
import AppFooter from "@/components/footer.vue";
</script>