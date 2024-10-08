
<template>
  <div>
<!--    Region create class-->
    <div v-if="action === 'create'">
      <b-form title="Создать новый класс" @submit.prevent="createClass">
        <h5>
          Класс:
        </h5>
          <b-form-group label-for="class-name" invalid-feedback="Имя класса обязательно">
            <b-input
                id="class-name"
                required
                v-model="newClass.name"
                placeholder="Введите имя класса"
                :state="isFormValid ? true : null"
            ></b-input>
          </b-form-group>
        <!--    <b-container>-->

        <!-- Dropdown for selecting owner of class -->
        <b-dropdown
            class="mb-3"
            size="sm"
            variant="outline-secondary"
            block
            menu-class="dropdown-scrollable w-100"
        >
          <template #button-content>
            <b-icon icon="person-fill"></b-icon> {{ selectedOwnerText }}
          </template>

          <b-dropdown-form @submit.stop.prevent="createClass">
            <b-form-group
                label="Поиск владельца:"
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
              v-for="owner in availableOwners"
              :key="owner.id"
              @click="selectOwner(owner)"
              :class="{ 'text-muted': owner.disabled }"
          >
            {{ owner.name }}
            <span v-if="owner.disabled" class="text-muted">
          (Имеет класс: {{ owner.classes.map((cls) => cls.name).join(", ") }})
        </span>
          </b-dropdown-item>
        </b-dropdown>
      </b-form>
    </div>
<!--    Region edit student list -->
    <div v-if="action === 'edit'">
      <b-table :items="students" :fields="[
          {
            label: 'Имя',
            key: 'name'
          },
          {
            label: 'Статус',
            key: 'isFree'
          }
      ]">
        <template #cell(name)="data">
          <span @click="openEditModal(data.item)">{{ data.item.name }}</span>
        </template>
        <template #cell(isFree)="data">
          <b-form-checkbox
              v-model="data.item.isFree"
              @change="toggleFreeStudent(data.item)">
            Бесплатник
          </b-form-checkbox>
        </template>
        <template #cell(actions)="data">
          <b-button size="sm" @click.stop="deleteStudent(data.item)">Удалить</b-button>
        </template>
      </b-table>

      <b-button @click="showAddModal = true" variant="primary">Добавить ученика</b-button>

      <!-- Модальное окно добавления ученика -->
      <b-modal v-model="showAddModal" title="Добавить ученика">
        <b-form @submit.prevent="addStudent">
          <b-form-group label="Имя ученика" label-for="new-student-name">
            <b-form-input id="new-student-name" v-model="newStudentName" required></b-form-input>
          </b-form-group>
        </b-form>
        <template #modal-footer>
          <b-button @click.prevent="addStudent" variant="primary">Добавить</b-button>
          <b-button @click="showAddModal = false" variant="secondary">Отмена</b-button>
        </template>
      </b-modal>

      <!-- Модальное окно редактирования ученика -->
      <b-modal v-model="showEditModal" title="Редактировать ученика">
        <b-form @submit.prevent="updateStudent">
          <b-form-group label="Имя ученика" label-for="edit-student-name">
            <b-form-input id="edit-student-name" v-model="newStudentName" required></b-form-input>
          </b-form-group>
        </b-form>
        <template #modal-footer>
          <b-button @click.prevent="updateStudent" variant="primary"> Подтвердить</b-button>
          <b-button @click="showAddModal = false" variant="secondary">Отмена</b-button>
        </template>
      </b-modal>
    </div>
    <div v-if="action === 'rename'">
      <b-form @submit.prevent="">
        <b-input v-model="newClassName" placeholder="Введите новое имя класса">

        </b-input>
          <b-card-text class="text-center mt-21"> {{entity.name}} -> {{newClassName}}</b-card-text>
      </b-form>
    </div>
<!--   Region delete -->
    <div v-if="action === 'delete'">
      <p>
        При продолжении, класс <b>{{this.entity.name}}</b> будет <b> безвовратно</b> удалён. <br>
        <ul>
          <li>Владелец: <i>{{ this.entity.owners ? this.entity.owners.map(owner => owner.name || '').join(', ') : 'отсутствует' }}</i></li>
          <li>Кол-во учеников: {{this.entity.students.length}}</li>
        </ul>
      </p>
    </div>
  </div>
</template>

<script>
export default {
  name: 'classesInterface',
  props: {
      action: {
        type: String,
        required: true,
      },
      entity: {
        type: Object,
        required: true,
      }
    },
  data() {
    return {
      formData: {...this.entity},

      raw_data: [],
      //Region create new class

      newClass: {
        name: '',
        owner: '',
      },
      isFormValid: false,

      selectedOwner: '',
      searchQuery: '', // Search term for filtering students

      availableOwners: [],

      //Region edit students
      students: [],
      selectedStudent: '',
      newStudentName: '',
      showEditModal: false,
      showAddModal: false,

      //Region rename
      newClassName: '',
    }
  },
  beforeMount() {
    this.$root.$off('form:confirm');
  },
  mounted() {
    switch(this.action) {
      case "create":
        this.getOwners();
        this.$root.$on('form:confirm', () => {
          this.createClass();
        });
        break;
      case "edit":
          this.getStudents();
        this.$root.$on('form:confirm', async () => {
          await this.saveNewStudents();
        });
        break;
      case "rename":
        this.$root.$on('form:confirm', async () => {
          await this.renameClass();
        });
        break;
      case "delete":
        this.$root.$on('form:confirm', async () => {
          await this.deleteClass();
        });
        break;
    }
  },
  computed: {
    selectedOwnerText() {
      // Return the selected student's name or the default text
      return this.selectedOwner.name || 'Выберите владельца';
    },

  },
  methods: {
    //Region create class
    async getStudents() {
      // Получаем данные студентов
      this.raw_data = await this.$root.$makeApiRequest('/api/org/classes/' + this.entity.id + '/students');

      const { fstudents, students } = this.raw_data;

      // Инициализируем локальные массивы
      this.students = students.map(student => ({
        name: student,
        isFree: fstudents.includes(student), // Помечаем как бесплатник
      }));

      // Локальный массив бесплатников для обновлений
      this.localFreeStudents = new Set(fstudents); // Добавим в сет для удобства
    },
    async getOwners() {
      this.raw_data = await this.$root.$makeApiRequest('/api/org/users');

      // Map all users to the desired format, marking those with classes as disabled
      this.availableOwners = this.raw_data.map(user => ({
        name: user.name,
        id: user.id,
        roles: user.roles,
        disabled: user.classes && user.classes.length > 0, // Mark as disabled if classes exist
        classes: user.classes
      }))
          // Sort the availableOwners: those without classes come first
          .sort((a, b) => {
            // Sort by 'disabled': false (no classes) should come before true (has classes)
            return (a.disabled === b.disabled) ? 0 : a.disabled ? 1 : -1;
          });
    },

    selectOwner(owner) {
      this.selectedOwner = owner;
      this.newClass.owner = owner.id;
    },
    //Region edit students
    toggleFreeStudent(student) {
      // Если студент стал бесплатником, добавляем его в локальный массив, иначе удаляем
      if (student.isFree) {
        this.localFreeStudents.add(student.name);
      } else {
        this.localFreeStudents.delete(student.name);
      }
    },
    // Редактирование ученика
    editStudent(student) {
      this.selectedStudent = { ...student };
      this.showEditModal = true;
    },

    async addStudent() {
      if (this.newStudentName.trim() === '') return;

      this.students.push({ name: this.newStudentName, isFree: false });
      this.localFreeStudents.delete(this.newStudentName); // По умолчанию не бесплатник
      this.newStudentName = ''; // Сбросить поле ввода
      this.showAddModal = false; // Закрыть модальное окно
    },

    deleteStudent(student) {
      const index = this.students.indexOf(student);
      if (index !== -1) {
        this.students.splice(index, 1); // Удалить ученика из локального массива
        this.localFreeStudents.delete(student.name); // Удалить из бесплатников, если он был
      }
    },

    openEditModal(student) {
      this.selectedStudent = { ...student }; // Создаем копию выбранного ученика
      this.showEditModal = true;
    },

    async updateStudent() {
      const index = this.students.findIndex(s => s.name === this.selectedStudent.name);
      if (index !== -1) {
        this.students[index].name = this.newStudentName; // Обновить имя ученика
      }
      this.newStudentName = '';
      this.showEditModal = false;
    },

    //Region send data
    async createClass() {
      if (!this.newClass.name) {
        this.isFormValid = false;
        this.$root.$emit('notification', 'warning', "Введите имя класса");
        return;
      }

      const status = await this.$root.$makeApiRequest('/api/org/classes', 'POST', this.newClass)
      if (status === 204)
        this.$root.$emit('notification', 'success', '');
      else
        this.$root.$emit('notification', 'error', '');

    },
    async saveNewStudents() {
      const fstudents = Array.from(this.localFreeStudents);

      const dataToSend = {
        students: this.students.map(student => student.name),
        fstudents: fstudents,
      };

      try {
        const status = await this.$root.$makeApiRequest('/api/org/classes/' + this.entity.id + '/students', 'PUT', dataToSend);
        if (status === 204)
          this.$root.$emit('notification', 'success');
        else
          this.$root.$emit('notification', 'error');
      }
      catch (error) {
        console.error('Ошибка при сохранении изменений:', error);
      }
    },
    async renameClass() {
      const status = await this.$root.$makeApiRequest(
          '/api/org/classes/' + this.entity.id,
          'PATCH',
          {
            name: this.newClassName
          });
      if (status === 204)
        this.$root.$emit('notification', 'success');
      else
        this.$root.$emit('notification', 'error');
    },
    async deleteClass() {
      const status = await this.$root.$makeApiRequest(
          '/api/org/classes/' + this.entity.id,
          'DELETE')
      if (status === 204)
        this.$root.$emit('notification', 'success');
      else
        this.$root.$emit('notification', 'error');
    }
  },

}
</script>

<style scoped>

</style>