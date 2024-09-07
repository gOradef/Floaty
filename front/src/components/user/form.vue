<template>
  <b-container class="h-100">
    <b-row class="justify-content-center">
      <b-col>
        <notificationsForm/>

        <b-form title="Редактировать отсутств." @submit.prevent="selectStudent">
          <h4>
            Класс: <b>{{ chosenClass.name }}</b>
          </h4>

          <b-container fluid>

            <!-- Dropdown for selecting students -->
            <b-dropdown
                class="mb-3"
                size="sm"
                variant="outline-secondary"
                block
                menu-class="dropdown-scrollable w-100"
            >
              <template #button-content>
                <b-icon icon="person-fill"></b-icon> {{ selectedStudentText }}
              </template>

              <b-dropdown-form>
                <b-form-group
                    label="Поиск ученика:"
                    label-for="student-search-input"
                    label-cols-md="auto"
                    class="mb-0"
                    label-size="sm"
                >
                  <b-form-input
                      v-model="searchQuery"
                      id="student-search-input"
                      type="search"
                      size="sm"
                      autocomplete="off"
                  ></b-form-input>
                </b-form-group>
              </b-dropdown-form>

              <b-dropdown-item
                  v-for="student in availableStudents"
                  :key="student.value"
                  :disabled="student.disabled"
                  @click="!student.disabled && selectStudent(student.value)"
                  :class="{
                  'text-danger': student.fstudent,
                  'text-muted': student.disabled,
                }"
              >
                {{ student.text }}
                <span v-if="student.disabled" class="text-muted">
                  (Уже в списке {{ student.list }})
                </span>
                <span v-if="student.fstudent" class="text-warning">(Бесплатник)</span>
              </b-dropdown-item>
            </b-dropdown>

            <b-row class="g-3">

              <!-- ORVI -->
              <b-col xs="12" md="4">
                <h6>Список ОРВИ учеников:</h6>
                <b-list-group>
                  <b-list-group-item
                      v-for="(tag, index) in chosenClass.absent.ORVI"
                      :key="index"
                      class="d-flex justify-content-between align-items-center"
                  >
                    {{ tag }}
                    <b-button variant="link" @click="removeORVITag(index)" class="p-0">
                      <b-icon icon="trash"></b-icon>
                    </b-button>
                  </b-list-group-item>
                <b-button @click="addORVIStudent" variant="primary" block>
                  Добавить ученика
                </b-button>
                </b-list-group>
              </b-col>

              <b-col xs="12" md="4" class="mt-2">
                <h6>Список уваж. прич. учеников:</h6>
                <b-list-group>
                  <b-list-group-item
                      v-for="(tag, index) in chosenClass.absent.respectful"
                      :key="index"
                      class="d-flex justify-content-between align-items-center"
                  >
                    {{ tag }}
                    <b-button variant="link" @click="removeRespTag(index)" class="p-0">
                      <b-icon icon="trash"></b-icon>
                    </b-button>
                  </b-list-group-item>
                <b-button @click="addRespStudent" variant="primary" block>
                  Добавить ученика
                </b-button>
                </b-list-group>
              </b-col>

              <b-col xs="12" md="4" class="mt-2">
                <h6>Список неуваж. прич. учеников:</h6>
                <b-list-group>
                  <b-list-group-item
                      v-for="(tag, index) in chosenClass.absent.not_respectful"
                      :key="index"
                      class="d-flex justify-content-between align-items-center"
                  >
                    {{ tag }}
                    <b-button variant="link" @click="removeNotRespTag(index)" class="p-0">
                      <b-icon icon="trash"></b-icon>
                    </b-button>
                  </b-list-group-item>
                  <b-button @click="addNotRespStudent" variant="primary" block>
                    Добавить ученика
                  </b-button>
                </b-list-group>
              </b-col>
            </b-row>

          </b-container>

          <div class="mt-4 border-top">
            <b-button block variant="primary" @click="submitForm">
              Отправить
            </b-button>
          </div>
        </b-form>
      </b-col>
    </b-row>
  </b-container>
</template>

<script>
import notificationsForm from "@/components/admin/notifications.vue";
export default {
  name: "userForm",
  components: {
    notificationsForm
  },
  data() {
    return {
      classID: '',
      chosenClass: {
        absent: {
          ORVI: [],
          respectful: [],
          not_respectful: []
        },
      },
      classData: {},
      students: [],
      selectedStudent: '',
      searchQuery: '',
    };
  },
  async mounted() {
    this.classID = this.$route.params.classID;

    this.chosenClass = {
      ...await this.$root.$makeApiRequest('/api/user/classes/' + this.classID),
      absent: {
        ORVI: [],
        respectful: [],
        not_respectful: []
      }
    }
    console.log(this.chosenClass);
  },
  computed: {
    availableStudents() {
      const absentStudents = {
        ORVI: new Set(this.chosenClass.absent.ORVI),
        respectful: new Set(this.chosenClass.absent.respectful),
        not_respectful: new Set(this.chosenClass.absent.not_respectful),
        fstudents: new Set(this.chosenClass.absent.fstudents),
      };

      return this.chosenClass.students.map((student) => {
        const inORVI = absentStudents.ORVI.has(student);
        const inRespectful = absentStudents.respectful.has(student);
        const inNotRespectful = absentStudents.not_respectful.has(student);
        const inFStudent = absentStudents.fstudents.has(student);

        return {
          value: student,
          text: student,
          disabled: inORVI || inRespectful || inNotRespectful,
          fstudent: inFStudent, // Add property to check if it's a fstudent
          list: inORVI
              ? 'ОРВИ'
              : inRespectful
                  ? 'Уваж. прич.'
                  : inNotRespectful
                      ? 'Неуваж. прич.'
                      : ''
        };
      }).filter(student => student.text.toLowerCase().includes(this.searchQuery.toLowerCase()));
    },
    selectedStudentText() {
      // Return the selected student's name or the default text
      return this.selectedStudent || 'Выберите ученика';
    }
  },
  methods: {
    async submitForm() {
      const status = await this.$root.$makeApiRequest('/api/user/classes/' + this.chosenClass.id + '/data', 'PUT',{
        absent: {...this.chosenClass.absent}
      });
      if (status === 200 || status === 204)
        this.$root.$emit('notification', 'success')
      else
        this.$root.$emit('notification', 'error', 'Что-то пошло не так. Попробуйте позже')
    },
    selectStudent(student) {
      this.selectedStudent = student;
    },
    isStudentFree() {
      return (this.selectedStudent &&
          !this.chosenClass.absent.ORVI.includes(this.selectedStudent) &&
          !this.chosenClass.absent.respectful.includes(this.selectedStudent) &&
          !this.chosenClass.absent.not_respectful.includes(this.selectedStudent))
    },
    addORVIStudent() {
      if (this.isStudentFree()) {
        this.chosenClass.absent.ORVI.push(this.selectedStudent);
        this.selectedStudent = ''; // Reset selected student
        this.searchQuery = ''; // Clear the search query
      }
    },
    addRespStudent() {
      if (this.isStudentFree()) {
        this.chosenClass.absent.respectful.push(this.selectedStudent);
        this.selectedStudent = ''; // Reset selected student
        this.searchQuery = ''; // Clear the search query
      }
    },
    addNotRespStudent() {
      if (this.isStudentFree()) {
        this.chosenClass.absent.not_respectful.push(this.selectedStudent);
        this.selectedStudent = ''; // Reset selected student
        this.searchQuery = ''; // Clear the search query
      }
    },
    removeORVITag(index) {
      this.chosenClass.absent.ORVI.splice(index, 1); // Remove student by index
    },
    removeRespTag(index) {
      this.chosenClass.absent.respectful.splice(index, 1); // Remove student by index
    },
    removeNotRespTag(index) {
      this.chosenClass.absent.not_respectful.splice(index, 1); // Remove student by index
    }
  },
};
</script>
<style>
.dropdown-scrollable {
  max-height: 300px; /* Задайте нужную высоту */
  overflow-y: auto; /* Включите вертикальную прокрутку */
}
</style>