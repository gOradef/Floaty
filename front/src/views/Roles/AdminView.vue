<template>
<!--    <b-container class="bv-example-row" fluid>-->
  <b-row class="text-center w-100 p-0 m-0"  style="flex-wrap: nowrap;"> <!-- Note the added style -->
    <b-col class="sidebar-l" :class="{ compact: compactMode }" v-if="hasAccess" style="flex: 0 0 auto;"> <!-- Added style here as well -->
          <b-container
            style="
              display: flex;
              align-items: center;
              padding: 0.5rem;
              height: 40px;
              cursor: pointer;
            "
            @click="toggleCompactMode"
          >
            <b-icon icon="list" scale="1.8" />
            <b v-if="!compactMode" style="margin-left: 10px">Разделы</b>
          </b-container>

          <b-list-group class="w-100">
            <div v-for="section in sections" :key="section.value" class="pr-0">
              <b-list-group-item
                @click.stop="handleSectionClick(section.value)"
                :class="{
                  active: activeSection === section.value,
                  'd-flex justify-content-between': true,
                }"
              >
                <div class="d-flex align-items-center w-100">
                  <b-icon scale="1" :icon="section.icon" />
                  <div v-if="!compactMode" class="d-flex">
                    <span class="pr-1 pl-1"> | </span>
                    <span>{{ section.label }}</span>
                  </div>
                </div>
<!--                Region context menu for 'data' section -->
                <div v-if="section.value === 'data' && !compactMode">
                  <b-container
                    style="
                      display: flex;
                      align-items: center;
                      justify-content: center;
                      padding: 0.5rem;
                      height: 40px;
                      cursor: pointer;
                    "
                    @click.prevent.stop="showAdditionalDataSettings = !showAdditionalDataSettings"
                    v-b-toggle.additionalDataCollapse
                  >
<!--                    Icon switcher-->
                    <b-icon
                      v-if="showAdditionalDataSettings"
                      icon="chevron-double-down"
                      scale="1.15"
                    />
                    <b-icon v-else icon="chevron-double-up" scale="1.15" />
                  </b-container>
                </div>
                <div v-if="section.value === 'logs' && !compactMode">
                  <b-container
                      style="
                      display: flex;
                      align-items: center;
                      justify-content: center;
                      padding: 0.5rem;
                      height: 40px;
                      cursor: pointer;
                    "
                      @click.prevent.stop="showAdditionalLogsSettings = !showAdditionalLogsSettings"
                      v-b-toggle.additionalLogsCollapse
                  >
                    <!--                    Icon switcher-->
                    <b-icon
                        v-if="showAdditionalLogsSettings"
                        icon="chevron-double-down"
                        scale="1.15"
                    />
                    <b-icon v-else icon="chevron-double-up" scale="1.15" />
                  </b-container>
                </div>
              </b-list-group-item>
              <b-collapse
                  v-if="section.value === 'data' &&!compactMode"
                  id="additionalDataCollapse"
              >
                <b-card-body class="pl-2 pr-2 pt-2 border border-top-0 border-dark">
                  <b-button-group vertical class="w-100">
<!--                    Region custom date -->
                    <b-button
                        v-b-toggle.dateInputCollapse
                    >Конкретная дата</b-button
                    >
                    <b-collapse id="dateInputCollapse"
                                v-model="showDataCustomDateInput"
                                class="d-flex align-self-center">
                    <b-form-input
                        v-if="showDataCustomDateInput"
                        v-model="calendarDataDate"
                        type="date"
                        placeholder="Дата"
                    />
                      <b-button
                          variant="primary"
                          v-if="showDataCustomDateInput"
                          @click.stop="handleSectionClick('data', 'date')"
                      >
                        <b-icon icon="arrow-return-right"/>
                      </b-button>

                    </b-collapse>
<!--                    Region period -->
                    <b-button
                        v-b-toggle.periodDataInputCollapse
                    >Период времени
                    </b-button>
                    <b-collapse id="periodDataInputCollapse" v-model="showDataPeriodInput" class="d-flex flex-column align-self-center">
                      <b-form-input
                          v-if="showDataPeriodInput"
                          v-model="periodDataStartDate"
                          type="date"
                          placeholder="Начальная дата"
                      />
                      <b-form-input
                          v-if="showDataPeriodInput"
                          v-model="periodDataEndDate"
                          type="date"
                          placeholder="Конечная дата"
                      />
                      <b-button
                          variant="primary"
                          class="pt-2 border-top"
                          v-if="showDataPeriodInput"
                          @click.stop="handleSectionClick('data', 'period')"
                      >
                        Запросить
                      </b-button>
                    </b-collapse>
                    <b-button @click.stop="exportDataCall" variant="success">Экспорт</b-button>
                  </b-button-group>
                </b-card-body>
              </b-collapse>
              <b-collapse
                  v-if="section.value === 'logs' &&!compactMode"
                  id="additionalLogsCollapse"
              >
                <b-card-body class="pl-2 pr-2 pt-2 pb-0 border border-top-0 border-dark">
                  <b-button-group vertical class="w-100">
                    <!--                    Region custom date -->
                    <b-button
                        v-b-toggle.filterCollapse
                    >Конкретная дата</b-button
                    >
                    <b-collapse id="filterCollapse"
                                v-model="showLogsCustomDateInput"
                                class="d-flex align-self-center">
                      <b-form-input
                          v-if="showLogsCustomDateInput"
                          v-model="calendarLogsDate"
                          type="date"
                          placeholder="Дата"
                      />
                      <b-button
                          variant="primary"
                          v-if="showLogsCustomDateInput"
                          @click.stop="handleSectionClick('logs', 'date')"
                      >
                        <b-icon icon="arrow-return-right"/>
                      </b-button>

                    </b-collapse>
                    <!--                    Region period -->
                    <b-button
                        v-b-toggle.periodLogsInputCollapse
                    >Период времени
                    </b-button>
                    <b-collapse id="periodLogsInputCollapse" v-model="showLogsPeriodInput" class="d-flex flex-column align-self-center">
                      <b-form-input
                          v-if="showLogsPeriodInput"
                          v-model="periodLogsStartDate"
                          type="date"
                          placeholder="Начальная дата"
                      />
                      <b-form-input
                          v-if="showLogsPeriodInput"
                          v-model="periodLogsEndDate"
                          type="date"
                          placeholder="Конечная дата"
                      />
                      <b-button
                          variant="primary"
                          class="pt-2 border-top"
                          v-if="showLogsPeriodInput"
                          @click.stop="handleSectionClick('logs', 'period')"
                      >
                        Запросить
                      </b-button>
                    </b-collapse>
                    <div class="d-flex btn-group-vertical w-100 border-top pt-1 mt-2">
                      <label for="category" class="mb-0">Раздел</label>
                      <div id="category" class="pl-3 d-flex btn-group-vertical">
                        <b-checkbox v-model="filter.categories.data">Данные</b-checkbox>
                        <b-checkbox v-model="filter.categories.classes">Классы</b-checkbox>
                        <b-checkbox v-model="filter.categories.users">Пользователи</b-checkbox>
                        <b-checkbox v-model="filter.categories.invites">Приглашения</b-checkbox>
                      </div>

                      <label for="operations" class="mb-0">Операция</label>
                      <div class="pl-3 d-flex btn-group-vertical">
                        <b-checkbox v-model="filter.operations.create">Создание</b-checkbox>
                        <b-checkbox v-model="filter.operations.edit">Редактирование</b-checkbox>
                        <b-checkbox v-model="filter.operations.delete">Удаление</b-checkbox>
                      </div>
                      <b-button variant="primary" class="mt-1 mb-1" @click.stop="applyFilterOnTable">Применить фильтр</b-button>
                    </div>
                  </b-button-group>
                </b-card-body>
              </b-collapse>
            </div>
          </b-list-group>

          <a href="#interface" class="moveToInterface">Перейти к интерфейсу</a>
        </b-col>

    <b-col class="pl-0 contentCol2">

      <b-row style="display: flex; flex-grow: 1;" class="m-0">
<!--        TABLE -->
        <b-col style="display: flex;" class="colPreTable">
          <div class="table" style="display: block;" v-if="hasAccess">
            <AdminContent :activeSection="contentSection" />
          </div>
        </b-col>
<!--        INTERACTION -->
        <b-col cols="pl-0DO NOT REMOVE" id="interface">
          <div class="sidebar-r" v-if="hasAccess">
              <b-calendar
                :start-weekday="1"
                class="emptyCalendar"
              ></b-calendar>
              <AdminContextMenu />
            </div>
        </b-col>

      </b-row>
    </b-col>

  </b-row>
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
      hasAccess: false,
      firstLoading: true,
      noAccessReason: '',

      compactMode: window.innerWidth < 768,
      showAdditionalDataSettings: false,
      showAdditionalLogsSettings: false,
      showCalendar: true,
      contentSection: null,

      // Sections
      activeSection: this.contentSection || 'data',
      sections: [
        { label: 'Данные', value: 'data', icon: 'table' },
        { label: 'Классы', value: 'classes', icon: 'layers' },
        { label: 'Пользователи', value: 'users', icon: 'people' },
        { label: 'Приглашения', value: 'invites', icon: 'envelope' },
        { label: 'Журнал', value: 'logs', icon: 'journal-text'}
      ],

      // Calendar data
      calendarDataDate: '',
      calendarLogsDate: null,

      showDataCustomDateInput: false,
      showDataPeriodInput: false,

      showLogsCustomDateInput: false,
      showLogsPeriodInput: false,

      showFilterInput: false,

      filter: {
        categories: {
          data: true,
          classes: true,
          users: true,
          invites: true
        },
        operations: {
          create: true,
          edit: true,
          delete: true
        }
      },

      periodDataStartDate: null,
      periodDataEndDate: null,

      periodLogsStartDate: null,
      periodLogsEndDate: null,
    };
  },
  async mounted() {
    this.firstLoading = true;
    await new Promise(r => setTimeout(r, 600))
    try {
      const response = await this.$root.$checkAccessRole('admin');
      this.hasAccess = response.status;
      if (!this.hasAccess)
        this.noAccessReason = response.reason;
    } catch (error) {
      console.warn("Error checking access:", error);
      this.hasAccess = false;
    } finally {
      this.firstLoading = false;
    }

    await new Promise(r => setTimeout(r, 100))
    if (this.hasAccess)
      this.$root.$emit('renderContentSection', this.activeSection);

    window.addEventListener('resize', this.handleWindowResize);
  },
  beforeMount() {
    window.removeEventListener('resize', this.handleWindowResize);
  },
  computed: {
    isDataDateChosen() {
      return (this.calendarDataDate.length !== 0);
    },
    isLogsDateChosen() {
      return (this.calendarLogsDate.length !== 0);
    }
  },
  methods: {
    handleSectionClick(sectionValue, dataType) {
      // if (this.activeSection !== sectionValue) {
        this.activeSection = sectionValue;
        if (sectionValue === 'data') {

        if (dataType === 'date') {
          if (!this.isDataDateChosen) {
            alert('Выберите дату');
            return;
          }
          else
            this.$root.$emit('renderContentSection', this.activeSection, this.calendarDataDate);
        }
        else if (dataType === 'period') {
          this.$root.$emit('renderContentSection', this.activeSection, this.periodDataStartDate, this.periodDataEndDate);
        }
        else {
          this.$root.$emit('renderContentSection', this.activeSection);
        }
        }
        else if (sectionValue === 'logs') {

          if (dataType === 'date') {
            if (!this.isLogsDateChosen) {
              alert('Выберите дату');
              return;
            }
            else
              this.$root.$emit('renderContentSection', this.activeSection, this.calendarLogsDate);
          }
          else if (dataType === 'period') {
            this.$root.$emit('renderContentSection', this.activeSection, this.periodLogsStartDate, this.periodLogsEndDate);
          }
          else {
            this.$root.$emit('renderContentSection', this.activeSection);
          }
        }
        else {
          this.$root.$emit('renderContentSection', this.activeSection);
        }

    },
    handleWindowResize() {
      this.compactMode = window.innerWidth < 768;
    },
    toggleCompactMode() {
      this.compactMode = !this.compactMode;
    },
    toggleShowCalendar() {
      this.showCalendar = !this.showCalendar;
    },
    exportDataCall() {
      this.$root.$emit('exportData');
    },
    applyFilterOnTable() {
      if (this.activeSection !== 'logs') {
        alert('Для использования фильтра текущий раздел должен быть "Журнал" ')
        return;
      }
      this.$root.$emit('applyFilter', this.filter);
    }
  }
};
</script>

<style scoped lang="scss">
body {
  font-size: 1.5rem; /* Установка размера текста */
}

.sidebar-l {
  position: sticky;
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
  transition: max-height 0.3s ease;
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


.table {
  border-right: #2c3e50 1px solid;
}


.moveToInterface {
  display: none;
}
/* Additional Mobile-Friendly Tweaks */
@media (max-width: 768px) {
  .moveToInterface {
    display: block;
  }

  .table {
    overflow-x: auto;
    border-right: none;
  }
  .emptyCalendar {
    display: none; /* Hide by default on mobile, can be adjusted based on need */
  }
  .contentCol2 {
    margin-top: 50px;
    width: 100% !important;
    padding-right: 0;
  }
  .colPreTable {
    padding-right: 0;
    padding-left: 0;
  }
  .sidebar-l.compact {
    max-width: 100%;

    position: absolute;
    max-height: 200px;
    z-index: 10;

    display: flex;
    flex-direction: row;

    border-bottom: #2c3e50 1px solid;

    .container {
      align-self: center;
      width: auto;
      margin: 0;
    }
    .list-group {
      flex-direction: row;
      padding-top: 4px;
    }
  }
}
</style>