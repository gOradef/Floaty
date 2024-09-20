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
        :items="table.items"
        :fields="table.fields"
        @export="exportExcel"

        :busy="!isDataLoaded"

        selectable
        select-mode="single"
        @row-selected="onRowSelected"

        hover
        striped
        sticky-header="80vh"
        head-variant="dark"
        bordered
        no-border-collapse

        class="h-100"
        :row-class="rowClass"
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
        <template #custom-foot v-if="isActiveSectionData() && isDataLoaded">
          <tr>
            <td><strong>1-4 классы</strong></td>
            <td> {{table.formulas.data["1_4"].global_amount()}}</td>
            <td> {{table.formulas.data["1_4"].global_absentAmount()}}</td>
          </tr>
          <tr>
            <td><strong>5-11 классы</strong></td>
            <td> {{table.formulas.data["5_11"].global_amount()}}</td>
            <td> {{table.formulas.data["5_11"].global_absentAmount()}}</td>
          </tr>
          <tr>
            <td><strong>Всего</strong></td>
            <td> {{table.formulas.data["global"].global_amount()}}</td>
            <td> {{table.formulas.data["global"].global_absentAmount()}}</td>
          </tr>
        </template>
        <template #table-caption v-if="isActiveSectionData() && isDataLoaded">
          {{ `Данные заполнены для ${table.items.filter(item => item.isClassDataFilled).length} / ${table.items.length} классов (${(table.items.filter(item => item.isClassDataFilled).length / table.items.length * 100).toFixed(2)}%)` }}
        </template>

        <template #table-busy>
          <div class="text-center my-2">
            <b-spinner class="align-middle" ></b-spinner>
            <strong>Loading...</strong>
          </div>
        </template>
      </b-table>
    </div>
  </div>
</template>

<script>
import * as XLSX from 'xlsx';
export default {
  name: "AdminContent",
  data() {
    return {
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
              global_amount: () => {
                return this.table.items.filter(item => {
                  const match = item.name.match(/\d+/);
                  const number = match && parseInt(match[0]);
                  return number!== null && number < 5;
                }).reduce((acc, item) => acc + item.students.length, 0);
              },
              global_absentAmount: () => {
                return this.table.items.filter(item => {
                  const match = item.name.match(/\d+/);
                  const number = match && parseInt(match[0]);
                  return number!== null && number < 5;
                }).reduce((acc, item) => acc + item.absent.global.length, 0);
              },
            },
            "5_11": {
              global_amount: () => {
                return this.table.items.filter(item => {
                  const match = item.name.match(/\d+/);
                  const number = match && parseInt(match[0]);
                  return number!== null && number >= 5;
                }).reduce((acc, item) => acc + item.students.length, 0);
              },
              global_absentAmount: () => {
                return this.table.items.filter(item => {
                  const match = item.name.match(/\d+/);
                  const number = match && parseInt(match[0]);
                  return number!== null && number >= 5;
                }).reduce((acc, item) => acc + item.absent.global.length, 0);
              },
            },
            "global": {
              global_amount: () => {
                return this.table.items.reduce((acc, item) => acc + item.students.length, 0);
              },
              global_absentAmount: () => {
                return this.table.items.reduce((acc, item) => acc + item.absent.global.length, 0);
              },
            }
          }
      }
      },      //Template fields
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

      activeSection: String,
      sectionDataMethods: {
        data: this.getData,
        classes: this.getClasses,
        users: this.getUsers,
        invites: this.getInvites
      },
      tableDataDates: '', //data or period for dates
      calendarDate: '',
    }
  },
  beforeMount() {
    this.$root.$off('renderContentSection', this.handleRenderContentSection);
    this.$root.$off('calendar:call');
    this.$root.$off('exportData');
  },
  async mounted() {
    // Define the event handler
    this.handleRenderContentSection = async (section,...dates) => {
      this.activeSection = section;
      this.isDataLoaded = false;
      this.tableDataDates = '';

      console.log(section, '-', dates);

      if (this.sectionDataMethods[section]) {
        this.raw_data = await this.sectionDataMethods[section](...dates);

        this.isDataExists = (this.raw_data !== null);
        this.updateTableFields(section);
        await new Promise(r => setTimeout(r, 200));

        if (this.raw_data !== null) {
          this.table.items = section === "data"
              ? Object.keys(this.raw_data).map(key => ({ id: key,...this.raw_data[key] }))
              : this.raw_data;
        }


        this.isDataLoaded = true;
      } else {
        console.warn(`Unknown section: ${section}`);
      }
      this.$root.$emit('context:show', section);
    };
    // Register the event listener
    this.$root.$on('renderContentSection', this.handleRenderContentSection);

    this.$root.$on('calendar:call', () => {
      this.$root.$emit('calendar:response', this.calendarDate);
    });
    this.$root.$on('exportData', () => {
      this.exportExcel();
    });

  },
  methods: {
     getCurrentDateFormatted() {
        const date = new Date();
        const year = date.getFullYear();
        const month = String(date.getMonth() + 1).padStart(2, '0'); // +1, потому что месяцы считаются от 0
        const day = String(date.getDate()).padStart(2, '0');

        return `${year}-${month}-${day}`;
    },
    async getData(date = null, date_2 = null) {
      let url = '/api/org/data';
      if (date) {
        if (date_2) {
          url = '/api/org/data-summary?startDate=' + date + '&endDate=' + date_2;
          this.tableDataDates = date + '-' + date_2;
        } else {
          url += '/' + date;
          this.tableDataDates = date;
        }
        this.calendarDate = date;
      } else {
        this.tableDataDates = this.getCurrentDateFormatted();
        this.calendarDate = null;
      }
      return (await this.$root.$makeApiRequest(url)).data;
    },
    async genDataForToday() {
      const status = await this.$root.$makeApiRequest('/api/org/data', 'POST');
      if (status === 204)
        this.$root.$emit('renderContentSection', 'data');
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

        this.expandedRowIds.splice(index, 1);
      } else {
        this.expandedRowIds.push(id);
      }
    },
    isRowExpanded(id) {
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
    // Export
    // ! COMMMIT
    exportExcel() {
      const sortedData = this.table.items.slice().sort((a, b) => {
        const classA = a.name.replace(/_/g, '').toUpperCase();
        const classB = b.name.replace(/_/g, '').toUpperCase();

        // Compare class numbers
        const matchA = classA.match(/^\d+/);
        const numA = matchA?.[0]? parseInt(matchA[0]) : null;

        const matchB = classB.match(/^\d+/);
        const numB = matchB?.[0]? parseInt(matchB[0]) : null;

        if (numA !== numB) {
          return numA - numB;
        }

        // Compare class letters
        const letterA = classA.slice(-1);
        const letterB = classB.slice(-1);
        return letterA.localeCompare(letterB);
      });

      const data = sortedData.map(item => [
        item.name,
        item.students.length,
        item.absent.global.length,
        item.absent.ORVI.join(', ') || '',
        item.absent.respectful.join(', ') || '',
        item.absent.not_respectful.join(', ') || '',
        item.absent.fstudents.join(', ') || '',
        item.owners.map(owner => owner.name).join(', ') || '',
      ]);

      const firstFiveIndex = sortedData.findIndex(item => {
        const match = item.name.match(/\d+/);
        return match && parseInt(match[0]) === 5;
      });

      const header = [
        'Класс',
        'Количество учащихся в классе',
        'Количество отсутствующих в классе',
        'Отсутствуют по ОРВИ (фамилии)',
        'Отсутствуют по уважительной причине (фамилии)',
        'Отсутствуют по неуважительной причине (фамилии)',
        'Из них бесплатники (фамилии)',
        'Классный руководитель (фамилия, инициалы)',
      ];

      const formulas = [
        ['1-4 классы', `=SUM(B2:B${firstFiveIndex + 1})`, `=SUM(C2:C${firstFiveIndex + 1})`, '', '', '', ''],
        ['5-11 классы', `=SUM(B${firstFiveIndex + 2}:B${sortedData.length + 1})`, `=SUM(C${firstFiveIndex + 2}:C${sortedData.length + 1})`, '', '', '', ''],
        ['Всего', `=SUM(B2:B${sortedData.length + 1})`, `=SUM(C2:C${sortedData.length + 1})`, '', '', '', ''],
      ];

// Добавляем фамилии отсутствующих для каждой группы
      const absentFormulas = [];
      for (const group of formulas) {
        const groupName = group[0];
        const startIndex = groupName === '1-4 классы'? 2 : groupName === '5-11 классы'? firstFiveIndex + 2 : 2;
        const endIndex = groupName === '1-4 классы'? firstFiveIndex + 1 : groupName === '5-11 классы'? sortedData.length + 1 : sortedData.length + 1;
        const orvi = `=TEXTJOIN(", ", TRUE, D${startIndex}:D${endIndex})`;
        const respectful = `=TEXTJOIN(", ", TRUE, E${startIndex}:E${endIndex})`;
        const notRespectful = `=TEXTJOIN(", ", TRUE, F${startIndex}:F${endIndex})`;
        const fstudents = `=TEXTJOIN(", ", TRUE, G${startIndex}:G${endIndex})`;
        absentFormulas.push([...group.slice(0, 3), orvi, respectful, notRespectful, fstudents]);
      }
      const ws = XLSX.utils.aoa_to_sheet([header,...data,...absentFormulas.map(row => row.map(cell => {
        if (typeof cell ==='string' && cell.startsWith('=')) {
          return { f: cell, v: 'Обновите ячейку'};
        }
        return cell;
      }))]);

      const wb = XLSX.utils.book_new();
      XLSX.utils.book_append_sheet(wb, ws, 'Sheet1');
      XLSX.utils.sheet_to_formulae(wb);

      XLSX.writeFile(wb, `${this.tableDataDates}.xlsx`);
    }
  },
}
</script>
<style scoped>

/* Busy table styling */
table.b-table[aria-busy='true'] {
  opacity: 0.6;
}

.b-table-sticky-header > .table.b-table > thead > tr > th {
  position: sticky !important;
  top: 0;
  z-index: 2;
}

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