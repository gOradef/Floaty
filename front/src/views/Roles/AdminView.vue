<template>
  <b-overlay :show="firstLoading">
  <b-container class="bv-example-row" fluid>
    <b-row class="text-center">
      <b-col class="sidebar-l" v-if="hasAccess">
        <AdminSections />
      </b-col>
      <b-col class="table" v-if="hasAccess">
        <AdminContent :activeSection="contentSection" />
      </b-col>
      <b-col class="sidebar-r" v-if="hasAccess">
        <CalendarComp />
        <AdminContextMenu />
      </b-col>

      <b-col v-else>
        <h1>You do not have access to this page.</h1>
      </b-col>
    </b-row>
  </b-container>
  </b-overlay>
</template>

<script>
import AdminSections from "@/components/admin/sections.vue";
import CalendarComp from "@/components/admin/calendar.vue";
import AdminContent from "@/components/admin/table.vue";
import AdminContextMenu from "@/components/admin/context.vue";

export default {
  name: "AdminView",
  components: {
    AdminSections,
    CalendarComp,
    AdminContent,
    AdminContextMenu,
  },
  data() {
    return {
      contentSection: null,
      hasAccess: false,
      firstLoading: true, // Track loading state
    };
  },
  async mounted() {
    this.firstLoading = true; // Set loading to true
    await new Promise(r => setTimeout(r, 600))
    try {
      this.hasAccess = await this.$root.$checkAccessRole('admin');
    } catch (error) {
      console.error("Error checking access:", error);
      this.hasAccess = false; // Assume no access on error
    } finally {
      this.firstLoading = false; // Set loading to false when done
    }
  },
  methods: {
    updateContentSection(newSection) {
      this.contentSection = newSection; // Update content section based on emitted event
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