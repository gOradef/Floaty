<template>
  <b-container class="vh-100 p-5">
    <b-card class="">
      <b-card-body>

        <b-row class="justify-content-center">
          <b-col>
            <notificationsForm/>

            <b-form title="Редактировать отсутствие" @submit.prevent="selectStudent">
              <b-modal id="editStudentsList" v-model="showStudentModal" title='Редактировать список учащихся класса'>
                <div>
                  <b-alert show v-if="isSuccessEditStudList && isUserSentEditStudList" variant="success">
                    Список класса успешно обновлён
                  </b-alert>
                  <b-alert show v-else-if="!isSuccessEditStudList && isUserSentEditStudList" variant="danger">
                    Что-то пошло не так, пожалуйста, свяжитесь с нами
                  </b-alert>
                </div>
                <b-table
                    :items="editedStudents"
                    :fields="[
                      {
                        label: 'Учащийся',
                        key: 'name'
                      },
                      {
                        label: 'Бесплатник?',
                        key: 'isFree'
                      },
                      {
                        label: '',
                        key: 'delete'
                      }
                  ]"
                  hover>
                  <template #cell(name)="data">
                  <span :style="{ color: data.item.isDeleted ? 'red' : '#2d84dc', textDecoration: data.item.isDeleted ? 'line-through' : 'underline' }" @click="openEditModal(data.item)">
                  {{ data.item.name }}
                  </span>
                  </template>
                  <template #cell(isFree)="data">
                    <b-form-checkbox
                        v-model="data.item.isFree">
                      Бесплатник
                    </b-form-checkbox>
                  </template>
                  <template #cell(delete)="data">
                    <b-button variant="link" @click.stop="toggleDeleteStudent(data.item)" class="p-0">
                      <b-icon icon="trash" v-if="!data.item.isDeleted"></b-icon>
                      <b-icon icon="arrow-clockwise" v-else></b-icon>
                    </b-button>
                  </template>
                </b-table>

                <b-button @click="showAddModal = true" variant="primary">Добавить ученика</b-button>

                <!-- Модальное окно добавления ученика -->
                <b-modal v-model="showAddModal" size="sm" title="Добавить ученика">
                  <b-form @submit.prevent="addStudent">
                    <b-form-group label="Имя ученика" label-for="new-student-name">
                      <b-form-input id="new-student-name" v-model="newStudentName" autofocus required></b-form-input>
                    </b-form-group>
                  </b-form>
                  <template #modal-footer>
                    <b-button @click.prevent="addStudent" variant="primary">Добавить</b-button>
                    <b-button @click="showAddModal = false" variant="secondary">Отмена</b-button>
                  </template>
                </b-modal>

                <!-- Модальное окно редактирования ученика -->
                <b-modal v-model="showEditModal" size="sm" title="Переименовать ученика">
                  <b-form @submit.prevent="renameStudent">
                    <b-form-group label="Имя ученика" label-for="edit-student-name">
                      <b-form-input id="edit-student-name" v-model="newStudentName" autofocus required></b-form-input>
                    </b-form-group>
                  </b-form>
                  <template #modal-footer>
                    <b-button @click.stop="showEditModal = false" variant="secondary">Отмена</b-button>
                    <b-button @click.prevent="renameStudent" variant="primary"> Переименовать</b-button>
                  </template>
                </b-modal>

                <template #modal-footer>
                  <b-button @click.prevent="showStudentModal = false" variant="secondary">Отмена</b-button>
                  <b-button @click.prevent="saveNewStudents" variant="primary"> Подтвердить изменения </b-button>
                </template>
              </b-modal>


              <h4>
                Класс: <b>{{ chosenClass.name }}</b>
                <b-button variant="link" v-b-modal.editStudentsList>
                  <b-icon variant="dark" icon="pencil"/>
                </b-button>
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
                        placeholder="Введите имя или фамилию ученика"
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
                  <b-col xs="12" md="4" class="mt-2">
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

                <b-row>
                  <div class="mt-4 border-top" style="justify-content: end">
                    <b-button block variant="primary" @click="submitForm">
                      Отправить
                    </b-button>
                  </div>
                </b-row>
              </b-container>
            </b-form>
          </b-col>
        </b-row>
      </b-card-body>
    </b-card>
  </b-container>
</template>

<script>
import notificationsForm from "@/components/admin/notifications.vue";

export default {
  name: "userForm",
  components: { notificationsForm },
  data() {
    return {
      classID: '' ,
      chosenClass: { //Absent data fill only
        absent: {
          ORVI: [],
          respectful: [],
          not_respectful: []
        },
      },
      selectedStudent: '',
      searchQuery: '',

      newStudentName: '', // New data property for the new student's name

      showStudentModal: false,
      showAddModal: false,
      showEditModal: false,
      isSuccessEditStudList: null,
      isUserSentEditStudList: false,

      //Used only for editing class list
      editedStudents: [],
      // For editing student in edit modal
      selectedEditStudent: '',
    };
  },
  async mounted() {
    this.classID = this.$route.params.classID;

    this.chosenClass = {
      ...await this.$root.$makeApiRequest('/api/user/classes/' + this.classID),
      absent: { ORVI: [], respectful: [], not_respectful: [] }
    };
    this.editedStudents = this.getStudents();
  },
  computed: {
    availableStudents() {
      const absentStudents = {
        ORVI: new Set(this.chosenClass.absent.ORVI),
        respectful: new Set(this.chosenClass.absent.respectful),
        not_respectful: new Set(this.chosenClass.absent.not_respectful),
        fstudents: new Set(this.chosenClass.absent.fstudents),
      };

      if (this.chosenClass.students) {

      return this.chosenClass.students.map((student) => {
        const inORVI = absentStudents.ORVI.has(student);
        const inRespectful = absentStudents.respectful.has(student);
        const inNotRespectful = absentStudents.not_respectful.has(student);
        const inFStudent = absentStudents.fstudents.has(student);

        return {
          value: student,
          text: student,
          disabled: inORVI || inRespectful || inNotRespectful,
          fstudent: inFStudent,
          list: inORVI ? 'ОРВИ' : inRespectful ? 'Уваж. прич.' : inNotRespectful ? 'Неуваж. прич.' : ''
        };
      }).filter(student => student.text.toLowerCase().includes(this.searchQuery.toLowerCase()));
      }
      return {}
    },
    selectedStudentText() {
      return this.selectedStudent || 'Выберите ученика';
    }
  },
  methods: {
    getStudents() {
      const students = this.chosenClass.students || [];
      const fstudents = this.chosenClass.fstudents || [];

      return students.map(student => ({
        name: student,
        isFree: fstudents.includes(student),
        isDeleted: false,
      }));

    },
    async addStudent() {
      if (this.newStudentName.trim() === '') return;

      this.editedStudents.push({
        name: this.newStudentName,
        isFree: false,
        isDeleted: false
      });
      this.newStudentName = ''; // Сбросить поле ввода
      this.showAddModal = false; // Закрыть модальное окно
    },

    toggleDeleteStudent(student) {
      const index = this.editedStudents.indexOf(student);
      if (index !== -1) {
        this.editedStudents[index].isDeleted = !this.editedStudents[index].isDeleted; // Удалить ученика из локального массива
      }
    },

    openEditModal(student) {
      this.selectedEditStudent = { ...student }; // Создаем копию выбранного ученика
      this.showEditModal = true;
    },

    renameStudent() {
      const index = this.editedStudents.findIndex(s => s.name === this.selectedEditStudent.name);
      if (index !== -1 && this.selectedEditStudent.name !== '') {
        this.editedStudents[index].name = this.newStudentName;
      }
      this.newStudentName = '';
      this.showEditModal = false;
    },
    async saveNewStudents() {

      const dataToSend = {
        students: this.editedStudents.filter(student => !student.isDeleted).map(student => student.name),
        fstudents: this.editedStudents.filter(student => student.isFree && !student.isDeleted).map(student => student.name),
      };

      try {
        console.log('data is send!')
        console.log(dataToSend)
        const status = await this.$root.$makeApiRequest('/api/org/classes/' + this.classID + '/students', 'PUT', dataToSend);
        this.isUserSentEditStudList = true;
        this.isSuccessEditStudList = (status === 204);
      }
      catch (error) {
        console.error('Ошибка при сохранении изменений:', error);
      }
    },
    async submitForm() {
      const status = await this.$root.$makeApiRequest('/api/user/classes/' + this.chosenClass.id + '/data', 'PUT', {
        absent: {...this.chosenClass.absent}
      });
      this.$root.$callNotificationEvent(status === 203);
    },
    selectStudent(student) {
      this.selectedStudent = student;
    },
    isStudentFree() {
      return (this.selectedStudent &&
        !this.chosenClass.absent.ORVI.includes(this.selectedStudent) &&
        !this.chosenClass.absent.respectful.includes(this.selectedStudent) &&
        !this.chosenClass.absent.not_respectful.includes(this.selectedStudent));
    },
    addORVIStudent() {
      if (this.isStudentFree()) {
        this.chosenClass.absent.ORVI.push(this.selectedStudent);
        this.selectedStudent = '';
        this.searchQuery = '';
      }
    },
    addRespStudent() {
      if (this.isStudentFree()) {
        this.chosenClass.absent.respectful.push(this.selectedStudent);
        this.selectedStudent = '';
        this.searchQuery = '';
      }
    },
    addNotRespStudent() {
      if (this.isStudentFree()) {
        this.chosenClass.absent.not_respectful.push(this.selectedStudent);
        this.selectedStudent = '';
        this.searchQuery = '';
      }
    },
    removeORVITag(index) {
      this.chosenClass.absent.ORVI.splice(index, 1);
    },
    removeRespTag(index) {
      this.chosenClass.absent.respectful.splice(index, 1);
    },
    removeNotRespTag(index) {
      this.chosenClass.absent.not_respectful.splice(index, 1);
    },
  },
};
</script>

<style>
.dropdown-scrollable {
  max-height: 300px;
  overflow-y: auto;
}
</style>
