<template>
  <div class="sidebar">
    <b-calendar :start-weekday="1"></b-calendar>
  </div>
</template>

<script>

export default {
  name: "Calendar"
};
</script>

<style scoped>
.b-calendar {
  padding-bottom: 20px;
  margin-bottom: 20px;
  border-bottom: #2c3e50 1px solid;
}
</style>