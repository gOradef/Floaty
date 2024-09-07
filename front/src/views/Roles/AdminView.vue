<template>
  <b-overlay :show="firstLoading">
    <b-container class="bv-example-row" fluid>
      <b-row class="text-center">
        <b-col class="sidebar-l" :class="{ 'compact': compactMode }" v-if="hasAccess">

          <b-container style="display: flex; align-items: center; padding: 0.5rem; height: 40px" >
            <b-icon style="cursor: pointer;" @click="toggleCompactMode" icon="list" scale="1.8" />
            <b v-if="!compactMode" style="margin-left: 10px;">Разделы</b>
          </b-container>

          <b-list-group>
            <b-list-group-item
                v-for="section in sections"
                :key="section.value"
                :class="{ active: activeSection === section.value }"
                @click="handleClick(section.value)"
            >
              <b-icon :icon="section.icon"/>
<!--              <span v-if="!compactMode">   |   </span>-->
              <span v-if="!compactMode">{{section.label }}</span>
            </b-list-group-item>
          </b-list-group>
        </b-col>
        <b-col class="table" v-if="hasAccess">
          <AdminContent :activeSection="contentSection" />
        </b-col>
        <b-col class="sidebar-r" v-if="hasAccess">
          <CalendarComp />
          <AdminContextMenu />
        </b-col>

        <b-col v-if="!hasAccess && !firstLoading">
          <h1>У вас нет доступа к этой странице.</h1>
        </b-col>
      </b-row>
    </b-container>
  </b-overlay>
</template>

<script>
import CalendarComp from "@/components/admin/calendar.vue";
import AdminContent from "@/components/admin/table.vue";
import AdminContextMenu from "@/components/admin/context.vue";

export default {
  name: "AdminView",
  components: {
    CalendarComp,
    AdminContent,
    AdminContextMenu,
  },
  data() {
    return {
      contentSection: null,
      hasAccess: false,
      firstLoading: true,
      compactMode: false,
      activeSection: this.contentSection || '/org/data',
      sections: [
        { label: 'Данные', value: 'data', icon: 'table' },
        { label: 'Классы', value: 'classes', icon: 'layers' },
        { label: 'Пользователи', value: 'users', icon: 'people' },
        { label: 'Приглашения', value: 'invites', icon: 'envelope' }
      ],
    };
  },
  async mounted() {
    this.firstLoading = true;
    await new Promise(r => setTimeout(r, 600))
    try {
      this.hasAccess = await this.$root.$checkAccessRole('admin');
    } catch (error) {
      console.error("Error checking access:", error);
      this.hasAccess = false;
    } finally {
      this.firstLoading = false;
    }
  },
  methods: {
    updateContentSection(newSection) {
      this.contentSection = newSection;
    },
    handleClick(sectionValue) {
      if (this.activeSection !== sectionValue) {
        this.activeSection = sectionValue;
        this.$root.$emit('renderContentSection', this.activeSection);
      }
    },
    toggleCompactMode() {
      this.compactMode = !this.compactMode;
    },
  }
};
</script>

<style scoped>

body {
  font-size: 1.5rem; /* Установка размера текста */
}

.sidebar-l {
  max-width: 250px;
  min-height: inherit;
  border-right: #2c3e50 1px solid;
  transition: max-width 0.3s ease;
}

.sidebar-l.compact {
  max-width: 50px;
}

.sidebar-l .list-group-item {
  display: flex;
  align-items: center;
  padding: 0.5rem;
}

.sidebar-l .list-group-item .section-icon {
  margin-right: 0.5rem;
}

.sidebar-l .list-group-item .section-label {
  flex-grow: 1;
}
.sidebar-l.compact {
  max-width: 65px; /* Измените максимальную ширину на 80 пикселей */
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
.sidebar-l .list-group-item {
  height: 34px;
}
.list-group > div {
  cursor: pointer;
}
</style>