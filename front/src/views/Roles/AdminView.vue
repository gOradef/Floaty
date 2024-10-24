<template>
<!--    <b-container class="bv-example-row" fluid>-->
      <b-row class="text-center">
        <b-col
          class="sidebar-l"
          :class="{ compact: compactMode }"
          v-if="hasAccess"
        >
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

          <b-list-group>
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
                    @click.prevent.stop="showMoreData = !showMoreData"
                    v-b-toggle.additionalDataCollapse
                  >
<!--                    Icon switcher-->
                    <b-icon
                      v-if="showMoreData"
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
                                v-model="showCustomDateInput"
                                class="d-flex align-self-center">
                    <b-form-input
                        v-if="showCustomDateInput"
                        v-model="calendarDate"
                        type="date"
                        placeholder="Дата"
                    />
                      <b-button
                          variant="primary"
                          v-if="showCustomDateInput"
                          @click.stop="handleSectionClick('data', 'date')"
                      >
                        <b-icon icon="arrow-return-right"/>
                      </b-button>

                    </b-collapse>
<!--                    Region period -->
                    <b-button
                        v-b-toggle.periodInputCollapse
                    >Период времени
                    </b-button>
                    <b-collapse id="periodInputCollapse" v-model="showPeriodInput" class="d-flex flex-column align-self-center">
                      <b-form-input
                          v-if="showPeriodInput"
                          v-model="periodStartDate"
                          type="date"
                          placeholder="Начальная дата"
                      />
                      <b-form-input
                          v-if="showPeriodInput"
                          v-model="periodEndDate"
                          type="date"
                          placeholder="Конечная дата"
                      />
                      <b-button
                          variant="primary"
                          class="pt-2 border-top"
                          v-if="showPeriodInput"
                          @click.stop="handleSectionClick('data', 'period')"
                      >
                        Запросить
                      </b-button>
                    </b-collapse>
                    <b-button @click.stop="exportDataCall" variant="success">Экспорт</b-button>
                  </b-button-group>
                </b-card-body>
              </b-collapse>
            </div>
          </b-list-group>
        </b-col>
        <b-col class="table" v-if="hasAccess">
          <AdminContent :activeSection="contentSection" />
        </b-col>
        <b-col class="sidebar-r" v-if="hasAccess">
          <b-calendar
            :start-weekday="1"
            class="emptyCalendar"
          ></b-calendar>
          <AdminContextMenu />
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

      compactMode: false,
      showMoreData: false,
      showCalendar: true,
      contentSection: null,

      // Sections
      activeSection: this.contentSection || 'data',
      sections: [
        { label: 'Данные', value: 'data', icon: 'table' },
        { label: 'Классы', value: 'classes', icon: 'layers' },
        { label: 'Пользователи', value: 'users', icon: 'people' },
        { label: 'Приглашения', value: 'invites', icon: 'envelope' }
      ],

      // Calendar data
      calendarDate: '',

      showCustomDateInput: false,
      showPeriodInput: false,
      periodStartDate: null,
      periodEndDate: null,
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

  },
  computed: {
    isDateChosen() {
      return (this.calendarDate.length !== 0);
    }
  },
  methods: {
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
        else if (dataType === 'period') {
          this.$root.$emit('renderContentSection', this.activeSection, this.periodStartDate, this.periodEndDate);
        }
        else {
          this.$root.$emit('renderContentSection', this.activeSection);
      }
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

::v-deep.b-calendar.b-calendar-inner {
  min-width: 100%;
}
@media (min-width: 420px) and (max-width: 1024px) {
  .emptyCalendar {
    display: none;
  }
}
</style>