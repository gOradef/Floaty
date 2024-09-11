<template>
  <b-overlay :show="firstLoading">
    <b-container class="bv-example-row" fluid>
      <b-row class="text-center">
        <b-col class="sidebar-l" :class="{ 'compact': compactMode }" v-if="hasAccess">

          <b-container style="display: flex; align-items: center; padding: 0.5rem; height: 40px; cursor: pointer; " @click="toggleCompactMode">
            <b-icon icon="list" scale="1.8" />
            <b v-if="!compactMode" style="margin-left: 10px;">Разделы</b>
          </b-container>

          <b-list-group-item
              v-for="section in sections"
              :key="section.value"
              :class="{ active: activeSection === section.value, 'd-flex justify-content-between': true }"
              class="pr-0"
              @click.stop="handleSectionClick(section.value)"
          >
            <div class="d-flex align-items-center w-100">
              <b-icon scale="1.0625" :icon="section.icon" />
              <div v-if="!compactMode" class="d-flex">
                <span class="pr-1 pl-1"> | </span>
                <span>{{section.label}}</span>
              </div>
            </div>
            <!-- Add dropdown menu for "Data" tab -->
            <template v-if="section.value === 'data'" >
              <b-dropdown v-if="!compactMode"
                  class="m-0"
                  style="width: inherit; height: inherit;"
              >
                <b-dropdown-item @click.stop="handleSectionClick('data', 'date')">За дату</b-dropdown-item>
                <b-dropdown-item @click.stop="handleSectionClick('data', 'period')">За период</b-dropdown-item>
              </b-dropdown>
            </template>
          </b-list-group-item>
        </b-col>
        <b-col class="table" v-if="hasAccess">
          <AdminContent :activeSection="contentSection" />
        </b-col>
        <b-col class="sidebar-r" v-if="hasAccess">
          <b-container style="display: flex; align-items: center; justify-content: center; padding: 0.5rem; height: 40px; cursor: pointer; " @click="toggleShowCalendar">
            <b style="margin-right: 5px;">Календарь</b>
            <b-icon v-if="showCalendar" icon="chevron-double-down" scale="1.15" />
            <b-icon v-else icon="chevron-double-up" scale="1.15" />
          </b-container>

            <b-calendar v-if="showCalendar" v-model="calendarDate" :start-weekday="1"></b-calendar>

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
import AdminContent from "@/components/admin/table.vue";
import AdminContextMenu from "@/components/admin/context.vue";

export default {
  name: "AdminView",
  components: {
    AdminContent,
    AdminContextMenu,
  },
  data() {
    return {
      contentSection: null,
      hasAccess: false,
      firstLoading: true,
      compactMode: false,
      showCalendar: true,

      // Sections
      activeSection: this.contentSection || 'dashboard',
      sections: [
        { label: 'Данные', value: 'data', icon: 'table' },
        { label: 'Классы', value: 'classes', icon: 'layers' },
        { label: 'Пользователи', value: 'users', icon: 'people' },
        { label: 'Приглашения', value: 'invites', icon: 'envelope' }
      ],

      // Calendar data
      calendarDate: '',
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
  computed: {
    isDateChosen() {
      return (this.calendarDate.length !== 0);
    }
  },
  methods: {
    updateContentSection(newSection) {
      this.contentSection = newSection;
    },
    handleSectionClick(sectionValue, dataType) {
      // if (this.activeSection !== sectionValue) {
        this.activeSection = sectionValue;
        if (dataType === 'date') {
          if (!this.isDateChosen) {
            alert('Выберите дату');
            return;
          }
          else
            this.$root.$emit('renderContentSection', this.activeSection, this.calendarDate);
        }
        else if (dataType === 'period')
          this.$root.$emit('renderContentSection', this.activeSection, this.calendarDate);
        else {
          this.$root.$emit('renderContentSection', this.activeSection);
      }
      // }
    },
    toggleCompactMode() {
      this.compactMode = !this.compactMode;
    },
    toggleShowCalendar() {
      this.showCalendar = !this.showCalendar;
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
  max-width: 65px;
}

.sidebar-r {
  max-width: 300px;
  border-left: #2c3e50 1px solid;
  transition: max-height 0.3s ease;
}
.sidebar-r.compact {
  max-height: 0;
}

.container-fluid {
  width: 100%;
  min-height: 800px;
}
.sidebar-l .list-group-item {
  height: 34px;
}
.list-group-item {
  cursor: pointer;
}

.b-calendar {
  padding-bottom: 20px;
  margin-bottom: 20px;
  border-bottom: #2c3e50 1px solid;
}
</style>