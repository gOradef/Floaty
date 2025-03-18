
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
              v-for="owner in usersList"
              :key="owner.id"
              @click="selectOwner(owner)"
              :class="{ 'text-muted': owner.disabled }"
              :disabled="owner.isInList"
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
      <b-table
          :items="editedStudents"
          :fields="[
                      {
                        label: 'Учащийся',
                        key: 'name',
                        sortable: true
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
      <b-modal v-model="showEditModal" size="sm" title="Переименовать ученика">
        <b-form @submit.prevent="renameStudent">
          <b-form-group label="Имя ученика" label-for="edit-student-name">
            <h5>
              {{selectedStudent.name}} -> {{newStudentName}}
            </h5>
            <b-form-input id="edit-student-name" placeholder="Введите новое имя ученика" v-model="newStudentName" autofocus required></b-form-input>
          </b-form-group>
        </b-form>
        <template #modal-footer>
          <b-button @click.stop="showEditModal = false" variant="secondary">Отмена</b-button>
          <b-button @click.prevent="renameStudent" variant="primary"> Переименовать</b-button>
        </template>

      </b-modal>
      <b-alert
          show
          v-if="isNewStudListHasDuplicates"
          variant="warning"
      >
        Текущий список имеет повторяющиеся элементы, пожалуйста, исправьте это
      </b-alert>
    </div>
    <div v-if="action === 'updateOwners'">
      <b-form title="Редактировать владельцев" @submit.prevent="setClassOwners">
        <h5>
          Класс: <i>{{entity_buff.name}}</i>
        </h5>
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
              :class="{ 'text-muted': owner.isHasClasses }"
              :disabled="owner.isInList"
          >
            {{ owner.name }}
            <span v-if="owner.isHasClasses" class="text-muted">
          (Имеет класс: {{ owner.classes.map((cls) => cls.name).join(", ") }})
        </span>
          </b-dropdown-item>
        </b-dropdown>

        <b-button class="w-100"
                  @click.stop="addSelectedOwnerToLocalList"
                  variant="primary"
                  :disabled="!this.selectedOwner"

        > <b-icon icon="plus-lg"></b-icon></b-button>
        <b-list-group
            v-for="(owner, index) in selectedOwnersList"
            :key="index"
        >
          <b-list-group-item
              class="d-flex justify-content-between align-items-center">
            {{owner.name}}
            <span v-if="owner.classes && owner.classes.length !== 0" class="text-muted">
              (Имеет класс: {{ owner.classes.map((cls) => cls.name).join(", ") }})
            </span>
            <b-button variant="link" @click="removeOwner(index)" class="p-0">
              <b-icon icon="trash"></b-icon>
            </b-button>
          </b-list-group-item>
        </b-list-group>
      </b-form>
    </div>
    <div v-if="action === 'rename'">
      <b-form @submit.prevent="renameClass">
        <b-input v-model="newClassName" placeholder="Введите новое имя класса">

        </b-input>
          <b-card-text class="text-center mt-21"> {{entity_buff.name}} -> {{newClassName}}</b-card-text>
      </b-form>
    </div>
<!--   Region delete -->
    <div v-if="action === 'delete'">
      <p>
        При продолжении, класс <b>{{this.entity_buff.name}}</b> будет <b> безвовратно</b> удалён. <br>
        <ul>
          <li>Владелец: <i>{{ this.entity_buff.owners ? this.entity_buff.owners.map(owner => owner.name || '').join(', ') : 'отсутствует' }}</i></li>
          <li>Кол-во учеников: {{this.entity_buff.students.length}}</li>
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
      entity_buff: {...this.entity}, //class

      raw_data: [],
      //Region create new class

      newClass: {
        name: '',
        owner: '',
      },
      isFormValid: false,

      selectedOwner: '',
      searchQuery: '', // Search term for filtering students


      //* edit students
      editedStudents: [],
      selectedStudent: '',
      newStudentName: '',
      showEditModal: false,
      showAddModal: false,

      //* owners
      usersList: [],
      selectedOwnersList: [],

      //* rename
      newClassName: '',
    }
  },
  beforeMount() {
    this.$root.$off('form:confirm');
  },
  mounted() {
    this.entity_buff = {...this.entity}

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
      case "updateOwners":
        this.getOwners();
        this.$root.$on('form:confirm', async () => {
          await this.setClassOwners();
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
    isNewStudListHasDuplicates() {
      const uniqStuds = new Set(this.editedStudents.filter(stud => !stud.isDeleted).map(stud => stud.name));
      // console.log(this.editedStudents);
      return uniqStuds.size !== this.editedStudents.filter(stud => !stud.isDeleted).length;
    },
    availableOwners() {
      // console.log(this.ownersList);
      return this.usersList
          .map(owner => {
            // Check if the current class is in the selected classes
            const isInSelectedOwners = this.selectedOwnersList.some(selectedOwner => {
              // Check if selectedClass has an id

              return selectedOwner.id === owner.id;
            });

            return {
              name: owner.name,
              id: owner.id,
              classes: owner.classes,
              isHasClasses: owner.isHasClasses,
              isInList: isInSelectedOwners, // Use a boolean directly
            };
          })
          // Filter classes based on the search query
          .filter(owner =>
              owner.name.toLowerCase().includes(this.searchQuery.toLowerCase())
          );
    },
  },
  methods: {
    //Region create class
    async getStudents() {
      // Получаем данные студентов
      this.raw_data = await this.$root.$makeApiRequest('/api/org/classes/' + this.entity_buff.id + '/students');

      const { fstudents, students } = this.raw_data;

      // Инициализируем локальные массивы
      this.editedStudents = students.map(student => ({
        name: student,
        isFree: fstudents.includes(student), // Помечаем как бесплатник
        isDeleted: false,
      }));
    },
    async getOwners() {
      this.raw_data = await this.$root.$makeApiRequest('/api/org/users');

      // Map all users to the desired format, marking those with classes as disabled
      this.usersList = this.raw_data.map(user => ({
        name: user.name,
        id: user.id,
        roles: user.roles,
        isHasClasses: user.classes && user.classes.length > 0, // Mark as gray if classes exist
        classes: user.classes
      }))
          // Sort the availableOwners: those without classes come first
          .sort((a, b) => {
            // Sort by 'disabled': false (no classes) should come before true (has classes)
            return (a.isHasClasses === b.isHasClasses) ? 0 : a.isHasClasses ? 1 : -1;
          });
      for (let el in this.entity_buff.owners) {
        const ownerId = this.entity_buff.owners[el].id;
        this.selectedOwnersList.push(...this.usersList.filter(user => user.id === ownerId));
      }

      // console.log(this.selectedOwnersList);
    },

    selectOwner(owner) {
      this.newClass.owner = owner.id;
      this.selectedOwner = owner;
    },
    // triggers on plus button
    addSelectedOwnerToLocalList() {
      this.selectedOwnersList.push(this.selectedOwner);
      this.selectedOwner = '';
    },
    removeOwner(index) {
      this.selectedOwnersList.splice(index, 1);
    },
    //Region edit students
    async addStudent() {
      if (this.newStudentName.trim() === '') return;

      this.editedStudents.push({ name: this.newStudentName, isFree: false });
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
      this.selectedStudent = { ...student }; // Создаем копию выбранного ученика
      this.showEditModal = true;
    },

    async renameStudent() {
      const index = this.editedStudents.findIndex(s => s.name === this.selectedStudent.name);
      if (index !== -1) {
        this.editedStudents[index].name = this.newStudentName;
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
      this.$root.$callNotificationEvent(status === 204);
    },
    async saveNewStudents() {
      if (this.isNewStudListHasDuplicates) {
        alert('Новый список содержит дупликаты. Пожалуйста, исправьте это')
        return;
      }
      const fstudents = this.editedStudents.filter(fstud => fstud.isFree).map(stud => stud.name);

      const dataToSend = {
        students: this.editedStudents.filter(student => !student.isDeleted).map(student => student.name),
        fstudents: fstudents,
      };

      try {
        const status = await this.$root.$makeApiRequest('/api/org/classes/' + this.entity_buff.id + '/students', 'PUT', dataToSend);
        this.$root.$callNotificationEvent(status === 204);
      }
      catch (error) {
        console.error('Ошибка при сохранении изменений:', error);
      }
    },
    async setClassOwners() {
      const status = await this.$root.$makeApiRequest(
          '/api/org/classes/' + this.entity_buff.id + '/owners',
          'PATCH',
          {
            owners: this.selectedOwnersList.map(owner => (owner.id))
          });
      this.$root.$callNotificationEvent(status === 204);
    },
    async renameClass() {
      const status = await this.$root.$makeApiRequest(
          '/api/org/classes/' + this.entity_buff.id + '/name',
          'PATCH',
          {
            name: this.newClassName
          });
      this.$root.$callNotificationEvent(status === 204);
    },
    async deleteClass() {
      const status = await this.$root.$makeApiRequest(
          '/api/org/classes/' + this.entity_buff.id,
          'DELETE')
      this.$root.$callNotificationEvent(status === 204);
    }
  },

}
</script>

<style scoped>

</style>