<template>
  <b-container class="bv-example-row" fluid>
    <b-row class="text-center">
      <AdminSidebarL />
      <AdminContent :contentSection="contentSection"/>
      <AdminSidebarR />
    </b-row>
  </b-container>
</template>

<script>
import AdminSidebarL from "@/components/admin/sidebar-l.vue";
import AdminSidebarR from "@/components/admin/sidebar-r.vue";
import AdminContent from "@/components/admin/table.vue"
export default {
  name: "AdminView",
  components: {
    AdminSidebarL,
    AdminSidebarR,
    AdminContent
  },
  data() {
    return {
      contentSection: null
    }
  }
};
</script>
<style scoped>
.container-fluid {
  width: 100%;
  min-height: 800px;
}
</style>