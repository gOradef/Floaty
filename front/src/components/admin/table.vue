<template>
      <b-table selectable
               select-mode="single"
               @row-selected="onRowSelected"


               sticky-header="500px"
               striped
               hover
               :items="table.items"
               :fields="table.fields"
               :row-class="rowClass"
      >
<!--        Absent Amounts -->
        <template #cell(absent_amounts)="row">

          <div @click.left="toggleDetails(row.item.id)">
            <p style="margin-bottom: 8px"
            >Всего: {{row.item.absent_amounts.global}}
              <BIconArrowDown v-if="!isRowExpanded(row.item.id)" />
              <BIconArrowUp v-if="isRowExpanded(row.item.id)" />
            </p>

            <b-collapse visible v-if="isRowExpanded(row.item.id)">
              <b-list-group>
                <b-list-group-item><strong> ОРВИ: </strong> {{row.item.absent_amounts.ORVI}}</b-list-group-item>
                <b-list-group-item><strong> Уваж. прич.: </strong> {{row.item.absent_amounts.respectful}}</b-list-group-item>
                <b-list-group-item><strong> Неуваж. прич.: </strong> {{row.item.absent_amounts.not_respectful}}</b-list-group-item>
                <b-list-group-item><strong> Бесплатники: </strong> {{row.item.absent_amounts.fstudents}}</b-list-group-item>
              </b-list-group>
            </b-collapse>
          </div>


        </template>

<!--        Absent lists -->
        <template #cell(absent_lists)="row">
          <div @click.stop="toggleDetails(row.item.id)">
          <p  style="margin-bottom: 8px" >Всего: {{row.item.absent_lists.global}}
            <BIconArrowDown v-if="!isRowExpanded(row.item.id)" />
            <BIconArrowUp v-if="isRowExpanded(row.item.id)" />
          </p>

          <b-collapse visible v-if="isRowExpanded(row.item.id)">
            <b-list-group>
              <b-list-group-item><strong> ОРВИ: </strong> {{row.item.absent_lists.ORVI}}</b-list-group-item>
              <b-list-group-item><strong> Уваж. прич.: </strong> {{row.item.absent_lists.respectful}}</b-list-group-item>
              <b-list-group-item><strong> Неуваж. прич.: </strong> {{row.item.absent_lists.not_respectful}}</b-list-group-item>
              <b-list-group-item><strong> Бесплатники: </strong> {{row.item.absent_lists.fstudents}}</b-list-group-item>
            </b-list-group>
          </b-collapse>
          </div>
        </template>

<!--        Check data filled by teachers -->
        <template #cell(isClassDataFilled)="row">
          <div>
            <BIconCheckCircle scale="1.3" style="color: #28a745;" v-if="row.item.isClassDataFilled" />
            <BIconDashCircle scale="1.3" style="color: #dc3545;" v-else />
          </div>

        </template>

<!--        -->
        <template #cell(owners)="row">
          <div v-for="(owner, index) in row.item.owners" :key="index">
            {{ owner.name }}
          </div>
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
            <td>

            </td>
          </tr>
        </template>
      </b-table>

</template>

<script>
// import axios from "axios";

import {expectedError} from "@babel/core/lib/errors/rewrite-stack-trace";

export default {
  name: "AdminContent",
  data() {
    return {
      showDetails: false,
      // Actual data for table
      table: {
        items: [],
        fields: [],
        formula: {
          classes: {
            global_amount: Number,
            global_absentAmount: Number,

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
            key: 'amount',
            label: 'Кол-во',
            sortable: true
          },
          {
            key: 'absent_amounts',
            label: 'Кол-во отсутсвовавших'
          },
          {
            key:"absent_lists",
            label: 'Фамилии отсутствовавших'
          },
          {
            key: "owner.name",
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
            key: 'amount',
            label: 'Кол-во'
          },
          {
            key: 'list_students',
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
      showFormulas: false
    }
  },
  mounted() {
    this.$root.$on('renderContentSection', async (section) => {

      this.activeSection = section;
      this.updateTableFields(section);

      switch (section) {
        case "data":
          this.raw_data = {
            "f501a40b-acd6-4b6e-8428-cb52707f4f94": {
              "list_fstudents": [],
              "isClassDataFilled": true,
              "absent_amounts": {
                "not_respectful": 0,
                "respectful": 1,
                "fstudents": 1,
                "global": 3,
                "ORVI": 1
              },
              "list_students": [
                "Ivanov0",
                "Ivanov1",
                "Ivanov2",
                "Ivanov3",
                "Ivanov4",
                "Ivanov5"
              ],
              "amount": 0,
              "absent_lists": {
                "not_respectful": [],
                "respectful": [
                  "Adminov"
                ],
                "fstudents": [
                  "Setkov"
                ],
                "global": [
                  "Ivanov",
                  "Setkov",
                  "Adminov"
                ],
                "ORVI": [
                  "Ivanov"
                ]
              },
              "owner": {
                "name": "Tester Floatyev Ivanich",
                "id": "ac7d9df6-9141-461b-bd12-f59370fb9826"
              },
              "name": "test3"
            },
            "e3ec4a16-365a-4b6d-ac3f-79182df83701": {
              "list_fstudents": [],
              "isClassDataFilled": false,
              "absent_amounts": {
                "not_respectful": 0,
                "respectful": 0,
                "fstudents": 0,
                "global": 0,
                "ORVI": 0
              },
              "list_students": [],
              "amount": 0,
              "absent_lists": {
                "not_respectful": [],
                "respectful": [],
                "fstudents": [],
                "global": [],
                "ORVI": []
              },
              "owner": {
                "name": "Tester Floatyev Ivanich",
                "id": "ac7d9df6-9141-461b-bd12-f59370fb9826"
              },
              "name": "test2"
            },
            "6c42c322-d434-4639-ae0e-8eb29088dc33": {
              "list_fstudents": [],
              "isClassDataFilled": false,
              "absent_amounts": {
                "not_respectful": 0,
                "respectful": 0,
                "fstudents": 0,
                "global": 0,
                "ORVI": 0
              },
              "list_students": [],
              "amount": 0,
              "absent_lists": {
                "not_respectful": [],
                "respectful": [],
                "fstudents": [],
                "global": [],
                "ORVI": []
              },
              "owner": {
                "name": "Tester Floatyev Ivanich",
                "id": "ac7d9df6-9141-461b-bd12-f59370fb9826"
              },
              "name": "test1"
            }
          };
          break;
        case "classes":
          this.raw_data = {
            "f501a40b-acd6-4b6e-8428-cb52707f4f94": {
              "list_fstudents": [],
              "list_students": [
                "Ivanov0",
                "Ivanov1",
                "Ivanov2",
                "Ivanov3",
                "Ivanov4",
                "Ivanov5"
              ],
              "owners": [
                {
                  "name": "Tester Floatyev Ivanich",
                  "id": "ac7d9df6-9141-461b-bd12-f59370fb9826"
                }
              ],
              "amount": 0,
              "name": "test3"
            },
            "e3ec4a16-365a-4b6d-ac3f-79182df83701": {
              "list_fstudents": [],
              "list_students": [],
              "owners": [
                {
                  "name": "Tester Floatyev Ivanich",
                  "id": "ac7d9df6-9141-461b-bd12-f59370fb9826"
                }
              ],
              "amount": 0,
              "name": "test2"
            },
            "6c42c322-d434-4639-ae0e-8eb29088dc33": {
              "list_fstudents": [],
              "list_students": [],
              "owners": [
                {
                  "name": "Tester Floatyev Ivanich",
                  "id": "ac7d9df6-9141-461b-bd12-f59370fb9826"
                }
              ],
              "amount": 0,
              "name": "test1"
            }
          };
          break;
        case "users":
          this.raw_data = {
            "c7bf75c9-2426-42e0-9cc0-47b8eb1d34d5": {
              "classes": [],
              "roles": [
                "apitest1",
                "teacher"
              ],
              "name": "api-test"
            },
            "ff856428-37b2-4c21-a1d7-ed647b514e27": {
              "classes": [],
              "roles": [],
              "name": "Victorovich"
            },
            "ac7d9df6-9141-461b-bd12-f59370fb9826": {
              "classes": [
                {
                  "name": "test1",
                  "id": "6c42c322-d434-4639-ae0e-8eb29088dc33"
                },
                {
                  "name": "test2",
                  "id": "e3ec4a16-365a-4b6d-ac3f-79182df83701"
                },
                {
                  "name": "test3",
                  "id": "f501a40b-acd6-4b6e-8428-cb52707f4f94"
                }
              ],
              "roles": [
                "tester",
                "teacher",
                "admin"
              ],
              "name": "Tester Floatyev Ivanich"
            }
          };
          break;
        case "invites":
          this.raw_data = {
            "14": {
              "body": {
                "classes": [],
                "roles": [],
                "name": "Victorovich"
              },
              "secret": "726"
            },
            "15": {
              "body": {
                "classes": [],
                "roles": [],
                "name": "Victorovich"
              },
              "secret": "2011"
            },
            "16": {
              "body": {
                "classes": [
                  "e3ec4a16-365a-4b6d-ac3f-79182df83701"
                ],
                "roles": [
                  "teacher"
                ],
                "name": "api-test"
              },
              "secret": "7208"
            },
            "17": {
              "body": {
                "classes": [
                  "e3ec4a16-365a-4b6d-ac3f-79182df83701"
                ],
                "roles": [
                  "teacher"
                ],
                "name": "api-test"
              },
              "secret": "1713"
            },
            "18": {
              "body": {
                "classes": [
                  "e3ec4a16-365a-4b6d-ac3f-79182df83701"
                ],
                "roles": [
                  "teacher"
                ],
                "name": "api-test"
              },
              "secret": "1690"
            },
            "19": {
              "body": {
                "classes": [
                  "e3ec4a16-365a-4b6d-ac3f-79182df83701"
                ],
                "roles": [
                  "teacher"
                ],
                "name": "api-test"
              },
              "secret": "3942"
            }
          };
          break;
        default:
          console.warn(`Unknown section: ${section}`);
          break;
      }


      this.table.items = Object.keys(this.raw_data).map(key => ({
        id: key,
            ...this.raw_data[key]
      }));
      // console.log(this.table.items);
    })
  },
  methods: {

    expectedError,
    //Updates fields for table
    updateTableFields(fieldType) {
      if (this.template_table_fields[fieldType]) {
        this.table.fields = this.template_table_fields[fieldType];
      } else {
        console.warn(`Field type '${fieldType}' does not exist in template_table_fields.`);
      }
    },
    toggleDetails(id) {
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
        this.$root.$emit('context:show', this.activeSection, item);
      }
      else
        this.$root.$emit('context:hide');

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
  min-width: 220px;
  padding: 0 12px 0 12px;

  align-self: center;
}
</style>