<template>
  <b-form title="Редактировать кол-во отсутств. учащихся">
    <h4>Класс: {{ updatedAbsent.name }}</h4>

    <!--  ORVI  -->

    <b-container>
      <!-- Dropdown for selecting students -->
      <b-dropdown size="sm" variant="outline-secondary" block menu-class="dropdown-scrollable w-100">
        <template #button-content>
          <b-icon icon="person-fill"></b-icon> {{ selectedStudentText }}
        </template>

        <b-dropdown-form @submit.stop.prevent="addNotRespStudent">
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
            :class="{'text-danger': student.fstudent,
                  'text-muted': student.disabled}"
        >
          {{ student.text }}
          <span v-if="student.disabled" class="text-muted">
            (Уже в списке {{ student.list }})
          </span>
          <span v-if="student.fstudent" class="text-warning">(Бесплатник)</span>
        </b-dropdown-item>
      </b-dropdown>

      <b-row>
        <!-- ORVI -->
        <b-col>
          <h6>Список ОРВИ учеников:</h6>
          <b-list-group-item
              v-for="(tag, index) in updatedAbsent.absent.ORVI"
              :key="index"
              class="d-flex justify-content-between align-items-center"
          >
            {{ tag }}
            <b-button variant="link" @click="removeORVITag(index)" class="p-0">
              <b-icon icon="trash"></b-icon>
            </b-button>
          </b-list-group-item>

          <b-button @click="addORVIStudent" variant="primary">Добавить ученика</b-button>

        </b-col>
        <!--   Resp     -->
        <b-col>
          <h6>Список уваж. прич. учеников:</h6>
          <b-list-group-item
              v-for="(tag, index) in updatedAbsent.absent.respectful"
              :key="index"
              class="d-flex justify-content-between align-items-center"
          >
            {{ tag }}
            <b-button variant="link" @click="removeRespTag(index)" class="p-0">
              <b-icon icon="trash"></b-icon>
            </b-button>
          </b-list-group-item>

          <b-button @click="addRespStudent" variant="primary">Добавить ученика</b-button>
        </b-col>
        <!--   NotResp     -->
        <b-col>
          <h6>Список неуваж. прич. учеников:</h6>
          <b-list-group-item
              v-for="(tag, index) in updatedAbsent.absent.not_respectful"
              :key="index"
              class="d-flex justify-content-between align-items-center"
          >
            {{ tag }}
            <b-button variant="link" @click="removeNotRespTag(index)" class="p-0">
              <b-icon icon="trash"></b-icon>
            </b-button>
          </b-list-group-item>

          <b-button @click="addNotRespStudent" variant="primary">Добавить ученика</b-button>
        </b-col>
      </b-row>
    </b-container>

  </b-form>
</template>
<script>
export default {
  name: "editAbsent",
  props: {
    content: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      updatedAbsent: { ...this.content }, // Create a copy of the content
      students: this.content.list_students || [], // Ensure students is an array
      selectedStudent: '',
      searchQuery: '', // Search term for filtering students
    };
  },
  computed: {
    availableStudents() {
      const absentStudents = {
        ORVI: new Set(this.updatedAbsent.absent.ORVI),
        respectful: new Set(this.updatedAbsent.absent.respectful),
        not_respectful: new Set(this.updatedAbsent.absent.not_respectful),
        fstudents: new Set(this.updatedAbsent.absent.fstudents),
      };

      return this.students.map((student) => {
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
    selectStudent(student) {
      this.selectedStudent = student;
    },
    isStudentFree() {
     return (this.selectedStudent &&
         !this.updatedAbsent.absent.ORVI.includes(this.selectedStudent) &&
         !this.updatedAbsent.absent.respectful.includes(this.selectedStudent) &&
         !this.updatedAbsent.absent.not_respectful.includes(this.selectedStudent))
    },
    addORVIStudent() {
      if (this.isStudentFree()) {
        this.updatedAbsent.absent.ORVI.push(this.selectedStudent);
        this.selectedStudent = ''; // Reset selected student
        this.searchQuery = ''; // Clear the search query
      }
    },
    addRespStudent() {
      if (this.isStudentFree()) {
        this.updatedAbsent.absent.respectful.push(this.selectedStudent);
        this.selectedStudent = ''; // Reset selected student
        this.searchQuery = ''; // Clear the search query
      }
    },
    addNotRespStudent() {
      if (this.isStudentFree()) {
        this.updatedAbsent.absent.not_respectful.push(this.selectedStudent);
        this.selectedStudent = ''; // Reset selected student
        this.searchQuery = ''; // Clear the search query
      }
    },
    removeORVITag(index) {
      this.updatedAbsent.absent.ORVI.splice(index, 1); // Remove student by index
    },
    removeRespTag(index) {
      this.updatedAbsent.absent.respectful.splice(index, 1); // Remove student by index
    },
    removeNotRespTag(index) {
      this.updatedAbsent.absent.not_respectful.splice(index, 1); // Remove student by index
    },
    syncAbsents() {
      // Handle any additional logic when absent lists are updated
      console.log(this.updatedAbsent);
    },
  },
  mounted() {
    this.$root.$on("form:confirm", () => {
      // Inserting data (this would typically be an API call or similar)
      console.log("Inserted!");
      console.log(this.updatedAbsent);
    });
  },
};
</script>

<style scoped lang="scss">
input {
  placeholder: '';
}
.text-danger {
  color: red;
}
.text-warning {
  color: orange;
}
</style>
<style>
@media screen and (max-width: 768px) {
  .dropdown-scrollable {
    max-height: 450px; /* Set your desired max height */
    overflow-y: auto;  /* Make it scrollable */
  }
}
</style>