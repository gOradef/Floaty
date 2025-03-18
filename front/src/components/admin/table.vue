<template>
  <div>
    <div v-if="!isDataExists">
      <h4>Данные отсутствуют.</h4>
      <b> Журнал ещё никто не заполнил</b> <br>
      <i><b-link @click.prevent="genDataForToday">Сгенерировать данные самостоятельно?</b-link></i>
    </div>
    <div v-else>
      <div v-if="isDataLoaded && activeSection === 'data'" class="mt-2">
        <h5>
          Данные за <b>
          {{this.tableDataDates}}
        </b>
        </h5>
      </div>
      <div>

      </div>
        <div class="tableClassParent">
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
          head-variant="dark"
          bordered
          no-border-collapse

          class="h-100 tableClass"
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
                class="d-flex justify-content-center"
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
                    <b-list-group-item >{{ row.item.absent.fstudents.length }} </b-list-group-item>
                  </b-list-group>
                  <b-list-group class="b-list-group-lists">
                    <b-list-group-item>{{ row.item.absent.ORVI.join(", ") || '-'}}</b-list-group-item>
                    <b-list-group-item>{{ row.item.absent.respectful.join(", ") || '-'}}</b-list-group-item>
                    <b-list-group-item>{{ row.item.absent.not_respectful.join(", ") || '-' }}</b-list-group-item>
                    <b-list-group-item>
                      {{ row.item.absent.fstudents.join(', ') || '-' }}
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

            <template #cell(changed_at)="row">
              {{row.item.changed_at.time}} <br>
              {{row.item.changed_at.date}}
            </template>

            <template #cell(context)="row">
              {{row.item.context.category === 'data' && row.item.context.operation === 'edit' ? 'Заполнение журнала' : ''}}

              <!--*               Classes              -->
              {{
                row.item.context.category === 'classes'
                && row.item.context.operation === 'create' ? 'Создание класса' : ''}}
              {{
                row.item.context.category === 'classes'
                && row.item.context.operation === 'edit'
                && row.item.context.changed_property	=== 'name'
                ? 'Редактировать имя класса' : ''}}

              {{
                row.item.context.category === 'classes'
                && row.item.context.operation === 'edit'
                && row.item.context.changed_property	=== 'owners'
                    ? 'Редактировать владельцев класса' : ''}}

              {{
                row.item.context.category === 'classes'
                && row.item.context.operation === 'edit'
                && row.item.context.changed_property	=== 'students'
                    ? 'Редактировать список учащихся в классе' : ''}}

              {{
                row.item.context.category === 'classes'
                && row.item.context.operation === 'delete'
                    ? 'Удаление класса' : ''}}

              <!--*               Users              -->
              {{
                row.item.context.category === 'users'
                && row.item.context.operation === 'create'
                    ? 'Создание пользователя' : ''}}

              {{
                row.item.context.category === 'users'
                && row.item.context.operation === 'edit'
                && row.item.context.changed_property	=== 'name'
                    ? 'Редактировать имя пользователя' : ''}}
              {{
                row.item.context.category === 'users'
                && row.item.context.operation === 'edit'
                && row.item.context.changed_property	=== 'roles'
                    ? 'Редактировать роли пользователя' : ''}}
              {{
                row.item.context.category === 'users'
                && row.item.context.operation === 'edit'
                && row.item.context.changed_property	=== 'classes'
                    ? 'Редактировать классы пользователя' : ''}}
              {{
                row.item.context.category === 'users'
                && row.item.context.operation === 'edit'
                && row.item.context.changed_property	=== 'password'
                    ? 'Редактировать пароль пользователя' : ''}}
              {{
                row.item.context.category === 'users'
                && row.item.context.operation === 'delete'
                    ? 'Удалить пользователя' : ''}}


              {{
                row.item.context.category === 'invites'
                && row.item.context.operation === 'create'
                    ? 'Создать приглашение' : ''}}
              {{
                row.item.context.category === 'invites'
                && row.item.context.operation === 'delete'
                    ? 'Удалить приглашение' : ''}}
            </template>

            <template #cell(log_data)="row">
              <div v-if="row.item.context.category === 'data' &&
              row.item.context.operation === 'edit'" class="align-content-center">

                <div class="text-center">Для даты: <i>{{row.item.log_data.date}}</i></div>
                <b-collapse
                    visible
                    class="d-flex justify-content-center"
                >
                  <b-list-group class="b-list-group-causes">
                    <b-list-group-item style="min-width: 160px"><strong> ОРВИ: </strong> </b-list-group-item>
                    <b-list-group-item style="min-width: 160px"><strong> Уваж. прич.: </strong> </b-list-group-item>
                    <b-list-group-item style="min-width: 160px"><strong> Неуваж. прич.: </strong> </b-list-group-item>
                  </b-list-group>
                  <b-list-group class="b-list-group-nums">
                    <b-list-group-item >{{row.item.log_data.absent.ORVI.length}} </b-list-group-item>
                    <b-list-group-item >{{row.item.log_data.absent.respectful.length}} </b-list-group-item>
                    <b-list-group-item >{{row.item.log_data.absent.not_respectful.length}} </b-list-group-item>
                  </b-list-group>
                  <b-list-group class="b-list-group-lists">
                    <b-list-group-item>{{ row.item.log_data.absent.ORVI.join(", ") || '-'}}</b-list-group-item>
                    <b-list-group-item>{{ row.item.log_data.absent.respectful.join(", ") || '-'}}</b-list-group-item>
                    <b-list-group-item>{{ row.item.log_data.absent.not_respectful.join(", ") || '-' }}</b-list-group-item>
                  </b-list-group>

                </b-collapse>
              </div>
              <div v-else-if="row.item.context.category === 'classes' &&
              row.item.context.operation === 'create'">
                Имя класса: <i>{{row.item.log_data.name}} </i><br>
                Владелец:  <i>{{row.item.log_data.owner.name || '-'}} </i><br>
              </div>

              <div v-else-if="
              row.item.context.category === 'classes' &&
              row.item.context.operation === 'edit' &&
              row.item.context.changed_property === 'students'">

                <b>До: </b>
                Учащиеся: {{(row.item.log_data.old.students).join(', ')}} - ({{row.item.log_data.old.students.length}})<br>
                Учащиеся-бесплатники: {{(row.item.log_data.old.fstudents).join(', ')}} - ({{row.item.log_data.old.fstudents.length}})

                <br>
                <b>После: </b>
                Учащиеся: {{(row.item.log_data.new.students).join(', ')}} - ({{row.item.log_data.new.students.length}})<br>
                Учащиеся-бесплатники: {{(row.item.log_data.new.fstudents).join(', ')}} - ({{row.item.log_data.new.fstudents.length}})
              </div>

              <div v-else-if="
              row.item.context.category === 'classes' &&
              row.item.context.operation === 'edit' &&
              row.item.context.changed_property === 'name'">
                <strike>{{row.item.log_data.old.name}}</strike> <b-icon icon="arrow-right"/> {{row.item.log_data.new.name}}
              </div>

              <div v-else-if="
              row.item.context.category === 'classes' &&
              row.item.context.operation === 'edit' &&
              row.item.context.changed_property === 'owners'">
                <strike>{{row.item.log_data.old.owners.map(owner => owner.name).join(', ')}} </strike> <b-icon icon="arrow-right"/> {{row.item.log_data.new.owners.map(owner => owner.name).join(', ') || '-'}}
              </div>

              <div v-else-if="
              row.item.context.category === 'classes' &&
              row.item.context.operation === 'delete'">
                Имя класса: <i>{{row.item.log_data.name}} </i><br>
                Владелецы: <i>{{row.item.log_data.owners.map(owner => owner.name).join(', ') || '-'}}</i>
              </div>


              <div v-else-if="
              row.item.context.category === 'users' &&
              row.item.context.operation === 'create'">
                Имя пользователя: <i>{{row.item.log_data.name}}</i> <br>
                Роли: <i>{{row.item.log_data.roles.join(', ')}}</i> <br>
                Классы: <i>{{row.item.log_data.classes.map(classt => classt.name).join(', ') || '-'}} </i>
              </div>

              <div v-else-if="
              row.item.context.category === 'users'
              && row.item.context.operation === 'edit'
              && row.item.context.changed_property === 'name'">
                <strike>{{row.item.log_data.old.name}}</strike> <b-icon icon="arrow-right"/> {{row.item.log_data.new.name}}
              </div>

              <div v-else-if="
              row.item.context.category === 'users' &&
              row.item.context.operation === 'edit' &&
              row.item.context.changed_property === 'roles'">
                <strike>{{row.item.log_data.old.roles.join(', ') || '-'}}</strike> <b-icon icon="arrow-right"/> {{row.item.log_data.new.roles.join(', ') || '-'}}
              </div>

              <div v-else-if="
              row.item.context.category === 'users' &&
              row.item.context.operation === 'edit' &&
              row.item.context.changed_property === 'classes'">
                <strike>{{row.item.log_data.old.classes.map(classt => classt.name).join(', ') || '-'}}</strike> <b-icon icon="arrow-right"/> {{row.item.log_data.new.classes.map(classt => classt.name).join(', ') || '-'}}
              </div>
              <div v-else-if="
              row.item.context.category === 'users' &&
              row.item.context.operation === 'edit' &&
              row.item.context.changed_property === 'password'
">
                -
              </div>
              <div v-else-if="row.item.context.category === 'users' &&
              row.item.context.operation === 'delete'">
                Имя: <i>{{row.item.log_data.name}}</i> <br>
                Роли: <i>{{row.item.log_data.roles.join(', ') || '-'}}</i> <br>
                Классы: <i>{{row.item.log_data.classes.map(classt => classt.name).join(', ') || '-'}}</i> <br> <!--TODO -->
              </div>

              <div v-else-if="
              row.item.context.category === 'invites' &&
              row.item.context.operation === 'create'
">
                Имя пользователя: <i>{{row.item.log_data.name}}</i> <br>
                Роли пользователя: <i>{{row.item.log_data.roles.join(', ')}}</i> <br>
                Классы пользователя: <i>{{row.item.log_data.classes.map(classt => classt.name).join(', ')}}</i>
              </div>
              <div v-else-if="
              row.item.context.category === 'invites' &&
              row.item.context.operation === 'delete'
">
                ID: <i>{{row.item.log_data.invite.id}}</i> <br>
                Имя пользователя: <i>{{row.item.log_data.invite.body.name}}</i> <br>
                Роли: <i>{{row.item.log_data.invite.body.roles.join(', ') || '-'}}</i> <br>
                Классы: <i>{{row.item.log_data.invite.body.classes.map(classt => classt.name).join(', ') || '-'}}</i>
              </div>

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
              <strong>Загрузка...</strong>
            </div>
          </template>
        </b-table>
      </div>
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
            label: 'Кол-во',
            sortable: true
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
            label: 'Пользователь',
            sortable: true
          },
          {
            key: 'roles',
            label: 'Роли',
            sortable: true
          },
          {
            key: 'classes',
            label: 'Классы',
            sortable: true
          }
        ],
        invites: [
          {
            key: 'body.name',
            label: 'Пользователь',
            sortable: true
          },
          {
            key: 'id',
            label: 'ID'
          },
          {
            key: 'secret',
            label: 'Секрет'
          }
        ],
        logs: [
          {
            key: 'changed_at',
            label: 'Время',
            sortable: true
          },
          {
            key: 'user.name',
            label: 'Пользователь',
          },
          {
            key: 'context',
            label: 'Действие',
          },
          {
            key: 'log_data',
            label: 'Данные'
          }

        ]
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
        invites: this.getInvites,
        logs: this.getLogs
      },
      tableDataDates: '', //data or period for dates
      calendarDate: '',

      //? lastChosenSection: '',
      //? lastChosenDates: null,
    }
  },
  beforeMount() {
    this.$root.$off('renderContentSection', this.handleRenderContentSection);
    this.$root.$off('calendar:call');
    this.$root.$off('exportData');
    this.$root.$off('applyFilter', this.applyFilter);
    //?todo this.$root.$off('refreshTableContent');
  },
  async mounted() {
    // Define the event handler
    this.handleRenderContentSection = async (section,...dates) => {
      //? this.lastChosenSection = section;
      //? if (dates[0] && dates[0] !== null && !dates[0].empty())
      //?   this.lastChosenDates = dates;
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
    this.$root.$on('applyFilter', this.applyFilter)
    //? this.$root.$on('refreshTableContent', this.refreshTableContent);
  },
  methods: {
     getCurrentDateFormatted() {
        const date = new Date();
        const year = date.getFullYear();
        const month = String(date.getMonth() + 1).padStart(2, '0'); // +1, потому что месяцы считаются от 0
        const day = String(date.getDate()).padStart(2, '0');

        return `${day}-${month}-${year}`;
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
    async getLogs(date = null, date_2 = null) {
      let url = '/api/org/logs';
      if (date) {
        if (date_2) {
          url = '/api/org/logs/period/' + date + '/' + date_2;
          this.tableDataDates = date + '-' + date_2;
        } else {
          url += '/date/' + date;
          this.tableDataDates = date;
        }
        this.calendarDate = date;
      } else {
        this.tableDataDates = this.getCurrentDateFormatted();
        this.calendarDate = null;
      }
      return (await this.$root.$makeApiRequest(url));
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
      // console.log(this.activeSection,' - ', item);


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

      let firstFiveIndex = sortedData.findIndex(item => {
        const match = item.name.match(/\d+/) | 0; //return 0 if null
        return match && match >= 5;
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
        const startIndex = groupName === '1-4 классы' ? 2 : groupName === '5-11 классы' ? firstFiveIndex + 2 : 2;
        const endIndex = groupName === '1-4 классы' ? firstFiveIndex + 1 : groupName === '5-11 классы' ? sortedData.length + 1 : sortedData.length + 1;

        const generateFormulaForLetter = (letter) => {
          const diapazon = `${letter}${startIndex}:${letter}${endIndex}`;
          return `=IF(TEXTJOIN(", "; 1; ${diapazon}) = ""; 0; LEN(TEXTJOIN(", "; 1; ${diapazon}))-LEN(SUBSTITUTE(TEXTJOIN(", "; 1; ${diapazon}); ","; ""))+1)`;
        };

        // Получение кол-ва элементов, разделенных ", "
        const orvi = generateFormulaForLetter('D');
        const respectful = generateFormulaForLetter('E');
        const notRespectful = generateFormulaForLetter('F')
        const fstudents = generateFormulaForLetter('G');

        absentFormulas.push([...group.slice(0, 3), orvi, respectful, notRespectful, fstudents]);
      }
      const ws = XLSX.utils.aoa_to_sheet([header,...data,...absentFormulas.map(row => row.map(cell => {
        if (typeof cell ==='string' && cell.startsWith('=')) {
          return { t: 'n', f: cell.slice(1)};
        }
        return cell;
      }))]);

      const wb = XLSX.utils.book_new();
      XLSX.utils.book_append_sheet(wb, ws, 'Sheet1');
      XLSX.utils.sheet_to_formulae(wb);

      XLSX.writeFile(wb, `${this.tableDataDates}.xlsx`);
    },
    applyFilter(filter) {
      // console.log(this.raw_data);

      // Initialize filtered items with all raw data
      let filtered_items = this.raw_data;

      // Filter categories
      if (!filter.categories.data) {
        filtered_items = filtered_items.filter(item => item.context.category !== 'data');
      }
      if (!filter.categories.classes) {
        filtered_items = filtered_items.filter(item => item.context.category !== 'classes');
      }
      if (!filter.categories.users) {
        filtered_items = filtered_items.filter(item => item.context.category !== 'users');
      }
      if (!filter.categories.invites) {
        filtered_items = filtered_items.filter(item => item.context.category !== 'invites');
      }

      // Filter operations
      if (!filter.operations.create) {
        filtered_items = filtered_items.filter(item => item.context.operation !== 'create');
      }
      if (!filter.operations.edit) {
        filtered_items = filtered_items.filter(item => item.context.operation !== 'edit');
      }
      if (!filter.operations.delete) {
        filtered_items = filtered_items.filter(item => item.context.operation !== 'delete');
      }

      // Apply the filtered items to the table
      this.table.items = filtered_items;
    },

    //? refreshTableContent() {
    //?   this.$root.$emit('renderContentSection', this.lastChosenSection, this.lastChosenDates);
    //? },
  }
}
</script>
<style>

/* Busy table styling */
table.b-table[aria-busy='true'] {
  opacity: 0.6;
}

.tableClassParent {
  max-height: 50vh;
  overflow-y: auto;
}

.b-table-sticky-header > .table.b-table > thead > tr > th {
  position: relative !important;
  top: 0;
  z-index: 2;
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

.tableClass {
  /* Existing styles, if any */
  margin-bottom: 0;

  /* Add this to set the height and enable vertical overflow */
  height: 540px; /* Sets the height to 60vh */
  overflow-y: auto; /* Enables vertical scrollbar when content exceeds height */
}

.tableClass.table.b-table thead {
  position: sticky; /* Keeps the header at the top */
  top: 0; /* Ensures it sticks to the top of the container */
  background-color: white; /* Optional: Keeps header background color when scrolling */
}

.tableClass.table.b-table tbody {
  overflow-y: auto; /* Enables scrolling for the tbody */
}
</style>
