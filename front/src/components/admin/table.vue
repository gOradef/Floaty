<template>
  <div>
    <div v-if="!isDataExists">
      <h4>Данные отсутствуют.</h4>
      <b> Журнал ещё никто не заполнил</b> <br>
      <i><b-link @click.prevent="genDataForToday">Сгененрировать данные самостоятельно?</b-link></i>
    </div>
    <div v-else>
      <div v-if="isDataLoaded && activeSection === 'data'" class="mt-2">
        <h5>
          Данные за <b>
          {{this.tableDataDates}}
        </b>
        </h5>
      </div>
      <b-table
        selectable
        select-mode="single"
        @row-selected="onRowSelected"
        sticky-header="650px"
        striped
        hover
        :items="table.items"
        :fields="table.fields"
        :row-class="rowClass"
        class="h-100"
        v-if="isDataLoaded"
      >
        <!--  Absent lists -->
        <template #cell(absent)="row">
          <div>
            <p
              style="margin-bottom: 8px"
            >
              {{ row.item.absent.global.join(', ') || '-'}}
              ({{ row.item.absent.global.length || '0'}})
                <BIconArrowDown v-if="!isRowExpanded(row.item.id)" />
                <BIconArrowUp v-if="isRowExpanded(row.item.id)" />
            </p>
            <b-collapse
              visible
              v-if="isRowExpanded(row.item.id)"
              style="display: flex; justify-content: flex-start;"
          >
                <b-list-group class="b-list-group-causes">
                  <b-list-group-item style="min-width: 140px"><strong> ОРВИ: </strong> </b-list-group-item>
                  <b-list-group-item style="min-width: 140px"><strong> Уваж. прич.: </strong> </b-list-group-item>
                  <b-list-group-item style="min-width: 140px"><strong> Неуваж. прич.: </strong> </b-list-group-item>
                  <b-list-group-item style="min-width: 140px"><strong> Бесплатники: </strong> </b-list-group-item>
                </b-list-group>
                <b-list-group class="b-list-group-nums">
                  <b-list-group-item >{{row.item.absent.ORVI.length}} </b-list-group-item>
                  <b-list-group-item >{{row.item.absent.respectful.length}} </b-list-group-item>
                  <b-list-group-item >{{row.item.absent.not_respectful.length}} </b-list-group-item>
                  <b-list-group-item >{{row.item.absent.fstudents.length}} </b-list-group-item>
                </b-list-group>
                <b-list-group class="b-list-group-lists">
                  <b-list-group-item>{{ row.item.absent.ORVI.join(", ") || '-'}}</b-list-group-item>
                  <b-list-group-item>{{ row.item.absent.respectful.join(", ") || '-'}}</b-list-group-item>
                  <b-list-group-item>{{ row.item.absent.not_respectful.join(", ") || '-' }}</b-list-group-item>
                  <b-list-group-item>
                    {{ row.item.absent.global.filter(student =>
                          row.item.absent.fstudents.includes(student)
                      ).join(', ') || '-'
                    }}
                  </b-list-group-item>
                </b-list-group>

          </b-collapse>
          </div>
        </template>

        <!--        Check data filled by teachers -->
        <template #cell(isClassDataFilled)="row">
          <div>
            <BIconCheckCircle
              scale="1.3"
              style="color: #28a745"
              v-if="row.item.isClassDataFilled"
            />
            <BIconDashCircle scale="1.3" style="color: #dc3545" v-else />
          </div>
        </template>

        <!--        -->
        <template #cell(owners)="row">
          <div v-for="(owner, index) in row.item.owners" :key="index">
            {{ owner.name }}
          </div>
        </template>

        <template #cell(classes)="row">
          <div v-for="(owner, index) in row.item.classes" :key="index">
            {{ owner.name }}
          </div>
        </template>

        <template #cell(students)="row">
          {{row.item.students.join(", ")}}
        </template>
        <template #cell(roles)="row">
           {{row.item.roles.join(", ")}}
        </template>
        <!-- Footer for Global Calculations -->
        <template #custom-foot v-if="isActiveSectionData()">
          <tr>
            <td><strong>1-4 классы</strong></td>
            <td></td>
          </tr>
          <tr>
            <td><strong>5-11 классы</strong></td>
            <td></td>
          </tr>
          <tr>
            <td><strong>Всего</strong></td>
            <td></td>
          </tr>
        </template>
      </b-table>
    </div>
  </div>
</template>

<script>
// import axios from "axios";

import {expectedError} from "@babel/core/lib/errors/rewrite-stack-trace";

export default {
  name: "AdminContent",
  data() {
    return {
      showDetails: false,
      isDataExists: true,
      isDataLoaded: false,
      showFormulas: false,


      // Actual data for table
      table: {
        items: [],
        fields: [],
        formulas: {
          data: {
            "1_4": {
              global_amount: Number,
              global_absentAmount: Number,
            },
            "5_11": {
              global_amount: Number,
              global_absentAmount: Number,
            },
            "global": {
              global_amount: Number,
              global_absentAmount: Number,
            }
          }
        }
      },
      //Template fields
      template_table_fields: {
        data: [ //class, amount, abs_amount, owner.name
          {
            key: 'name', //class_name
            label: 'Класс',
            sortable: true
          },
          {
            key: 'students.length',
            label: 'Кол-во',
            sortable: true
          },
          {
            key:"absent",
            label: 'Фамилии отсутствовавших'
          },
          {
            key: "owners",
            label: "Кл. рук."
          },
          {
            key: 'isClassDataFilled',
            label: 'Заполнено?',
            sortable: true
          }
        ],
        classes: [
          {
            key: 'name',
            label: 'Класс',
            sortable: true
          },
          {
            key: 'students.length',
            label: 'Кол-во'
          },
          {
            key: 'students',
            label: 'Учащиеся'
          },
          {
            key: 'owners',
            label: 'Кл. рук.'
          }
        ],
        users: [
          {
            key: 'name',
            label: 'Пользователь'
          },
          {
            key: 'roles',
            label: 'Роли'
          },
          {
            key: 'classes',
            label: 'Классы'
          }
        ],
        invites: [
          {
            key: 'body.name',
            label: 'Пользователь'
          },
       {
            key: 'id',
            label: 'ID'
          },{
            key: 'secret',
            label: 'Секрет'
          }
        ],
      },

      //Data from request
      raw_data: Object,

      expandedRowIds: [],
      pinedExpandedRowIds: [],
      //todo Dynamic <template>
      template_table_cells: {
        class: '',
        user: '',

      },
      activeSection: String,
      tableDataDates: '', //data or period for dates
      sectionDataMethods: {
        data: this.getData,
        classes: this.getClasses,
        users: this.getUsers,
        invites: this.getInvites
      }
    }
  },
  beforeMount() {
    this.$root.$off('renderContentSection', this.handleRenderContentSection);
  },
  async mounted() {
    // Define the event handler
    this.handleRenderContentSection = async (section, ...dates) => {
      this.activeSection = section;
      this.isDataLoaded = false;
      this.tableDataDates = '';


      console.log(section, '-', dates)
      this.updateTableFields(section);

      if (this.sectionDataMethods[section]) {
        this.raw_data = await this.sectionDataMethods[section](...dates);

        // Logic to handle responses based on section
        if (section === "data") {
          if (this.raw_data !== null) {
            this.table.items = Object.keys(this.raw_data).map(key => ({
              id: key,
              ...this.raw_data[key]
            }));
            this.isDataExists = true;
          }
          else {
            this.isDataExists = false;
          }
        }
        else {
          this.table.items = this.raw_data;
          this.isDataExists = true;
        }

        this.isDataLoaded = true; // Mark data load as complete
      } else {
        console.warn(`Unknown section: ${section}`);
      }
    };
    // Register the event listener
    this.$root.$on('renderContentSection', this.handleRenderContentSection);

  },
  methods: {

    expectedError,
    async getData(date = null, date_start = null, date_end = null) {
      let url = '/api/org/data';
      if (date) {
        url += '/' + date;
        this.tableDataDates = date;
      } else if (date_start && date_end) {
        url = '/api/org/data-summary?startDate=' + date_start + '&endDate=' + date_end;
      }
      return (await this.$root.$makeApiRequest(url)).data;
    },
    async genDataForToday() {
      const status = await this.$root.$makeApiRequest('/api/org/data', 'POST');
      if (status === 204)
        await this.getDataToday();
      else
        alert('Что-то пошло не так. Обратитесь к разработчикам, если это повторится')
    },
    async getClasses() {
      return await this.$root.$makeApiRequest('/api/org/classes');
    },
    async getUsers() {
      return await this.$root.$makeApiRequest('/api/org/users');
    },
    async getInvites() {
      return await this.$root.$makeApiRequest('/api/org/invites');
    },

    //Updates fields for table
    updateTableFields(fieldType) {
      if (this.template_table_fields[fieldType]) {
        this.table.fields = this.template_table_fields[fieldType];
      } else {
        console.warn(`Field type '${fieldType}' does not exist in template_table_fields.`);
      }
    },
    toggleDetails(id) {
      this.expandedRowIds = [];
      const index = this.expandedRowIds.indexOf(id);
      if (index !== -1) {

        // Удаляем идентификатор, если он уже есть
        this.expandedRowIds.splice(index, 1);
      } else {
        // Добавляем идентификатор, если его нет
        this.expandedRowIds.push(id);
      }
    },
    isRowExpanded(id) {
      // Проверяем, находится ли идентификатор в массиве раскрытых строк
      return this.expandedRowIds.includes(id);
    },

    onRowSelected(item) {
      console.log(this.activeSection,' - ', item);


      if (item.length !== 0) {
        this.toggleDetails(item[0].id);
        this.$root.$emit('context:show', this.activeSection, item);
      }
      else {
        this.$root.$emit('context:hide');
        this.expandedRowIds = [];
      }

    },
    isActiveSectionData() {
      return this.activeSection === "data";
    },
    rowClass(item) {
      return {
        'bg-danger text-white': !item.item.isClassDataFilled,
      };
    },
  },
}
</script>
<style scoped>
.list-group-item {
  max-height: 35px;
  //min-width: 220px;
  padding: 0 12px 0 12px;

  align-self: center;
}
.b-list-group-causes > .list-group-item {
  min-width: 150px;
  .list-group-item {
    min-width: 150px;
  }
}
.b-list-group-nums {
  max-width: 40px;
}
.b-list-group-nums > .list-group-item {
  max-width: 40px;
}
.b-list-group-lists > .list-group-item {
  min-width: 100px;
}
</style>