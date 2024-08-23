<template>
  <b-container class="bv-example-row" fluid>
    <b-row class="text-center">
      <b-col class="sidebar-l">
        <AdminSidebarL />
      </b-col>
      <b-col class="table">
        <AdminContent :activeSection="contentSection"/>
      </b-col>
      <b-col class="sidebar-r">
        <Calendar />
        <AdminContextMenu/>
      </b-col>
    </b-row>
  </b-container>
</template>

<script>
import AdminSidebarL from "@/components/admin/sidebar-l.vue";
import Calendar from "@/components/admin/sidebar-r.vue";
import AdminContent from "@/components/admin/table.vue"
import AdminContextMenu from "@/components/admin/context.vue"
export default {
  name: "AdminView",
  components: {
    AdminSidebarL,
    Calendar,
    AdminContent,
    AdminContextMenu
  },
  data() {
    return {
      contentSection: null
    }
  }
};
</script>
<style scoped>
.sidebar-l {
  max-width: 300px;

  min-height: inherit;
  border-right: #2c3e50 1px solid;
  resize: horizontal;
}

.sidebar-r {
  min-width: 300px;
  max-width: 300px;

  border-left: #2c3e50 1px solid;
}

.container-fluid {
  width: 100%;
  min-height: 800px;
}
</style>