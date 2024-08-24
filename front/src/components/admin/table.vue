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

<!--        Absent lists -->
        <template #cell(absent)="row">
          <div>
          <p @click.stop="toggleDetails(row.item.id)" style="margin-bottom: 8px" >Всего: ({{row.item.absent.global.join(", ")}})
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
                  <b-list-group-item>({{row.item.absent.ORVI.join(", ")}}) </b-list-group-item>
                  <b-list-group-item>({{row.item.absent.respectful.join(", ")}}) </b-list-group-item>
                  <b-list-group-item>({{row.item.absent.not_respectful.join(", ")}}) </b-list-group-item>
                  <b-list-group-item>({{row.item.absent.fstudents.join(", ")}}) </b-list-group-item>
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
            key:"absent",
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
              "isClassDataFilled": true,
              "list_students": [
                "Ivanov0",
                "Ivanov1",
                "Ivanov2",
                "Ivanov3",
                "Ivanov4",
                "Ivanov5"
              ],
              "amount": 0,
              "list_fstudents": [],
              "absent": {
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
              "isClassDataFilled": false,
              "list_students": [],
              "amount": 0,
              "list_fstudents": [],
              "absent": {
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
              "isClassDataFilled": false,
              "list_students": [],
              "amount": 0,
              "list_fstudents": [],
              "absent": {
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
  //min-width: 220px;
  padding: 0 12px 0 12px;

  align-self: center;
}
.b-list-group-causes > .list-group-item {
  min-width: 140px;
  .list-group-item {
    min-width: 140px;
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