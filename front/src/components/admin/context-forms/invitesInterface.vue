<template>
  <div>
    <div v-if="action === 'create'">
      <b-form>
        <b-form-group label="Имя пользователя">
          <b-form-input v-model="userName" placeholder="Введите имя пользователя">

          </b-form-input>
        </b-form-group>
        <b-form-group label="Роли">
          <b-form-checkbox v-model="isTeacher">Классный руководитель</b-form-checkbox>
          <b-form-checkbox v-model="isAdmin">Завуч</b-form-checkbox>
        </b-form-group>
        <b-form-group label="Классы пользователя">
          <b-dropdown
              class="mb-3"
              size="sm"
              variant="outline-secondary"
              block
              menu-class="dropdown-scrollable w-100"
          >
            <template #button-content>
              <b-icon icon="inboxes"></b-icon> Классы
            </template>

            <b-dropdown-form>
              <b-form-group
                  label="Поиск класса:"
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
                v-for="classt in availableClasses"
                :key="classt.value"
                @click="userClasses.push(classt)"
                :disabled="classt.isInList"
                :class="{ 'text-muted': classt.isHasOwners }"
            >
              {{ classt.name }}
              <span v-if="classt.isHasOwners" class="text-muted">
              (Владеет:
              {{
                  classt.owners
                      .map((owner) => {
                        return owner.name;
                      })
                      .join(", ")
                }})
            </span>
            </b-dropdown-item>
          </b-dropdown>

          <!--     Display classes     -->
          <b-list-group-item
              v-for="(classt, index) in userClasses"
              :key="index"
              class="d-flex justify-content-between align-items-center"
          >
            {{ classt.name }}
            <span v-if="classt.isHasOwners" class="text-muted"
            >Владеет
            {{
                classt.owners
                    .map((owner) => {
                      return owner.name;
                    })
                    .join(", ")
              }}</span
            >
            <b-button variant="link" @click="removeTag(index)" class="p-0">
              <b-icon icon="trash"></b-icon>
            </b-button>
          </b-list-group-item>
        </b-form-group>
        <b-form-checkbox v-model="isForceCreate">Продолжить без предупреждений?</b-form-checkbox>
      </b-form>
    </div>
    <div v-if="action === 'delete'">
      <p>
        При продолжении, приглашение пользователя <b>{{ this.entity_buff.body.name }}</b> будет <b>безвозвратно</b> удалено. <br>
        <ul>
          <li>Данные приглашения:
            <ul>
              <li>ID: {{this.entity_buff.id}}</li>
              <li>Секрет: {{this.entity_buff.secret}}</li>
            </ul>
          </li>
          <li>Классы:
            {{ this.entity_buff.body.classes ? this.entity_buff.body.classes.map(classt => classt.name || '').join(', ') : '-' }}</li>
          <li>Роли: {{ this.entity_buff.body.roles ? this.entity_buff.body.roles.map(role => role).join(', ') : '-' }}</li>
        </ul>
      </p>

    </div>
  </div>
</template>

<script>

export default {
  name: 'invitesInterface',
  props: {
    action: {
      type: String,
      required: true
    },
    entity: {
      type: Object,
      required: true
    }
  },
  data() {
    return {
      raw_data: {},
      currentTabIndex: 0,
      entity_buff: {...this.entity},

      userName: '',
      userRoles: [],
      userClasses: [],
      isTeacher: false,
      isAdmin: false,
      isForceCreate: false,

      searchQuery: '',
      availableClassesList: [],
    };
  },
  beforeMount() {
    this.$root.$off('form:confirm');
  },
  mounted() {
    switch (this.action) {
      case "create":
        this.$root.$on('form:confirm', this.handleCreateInvite);
          this.getClasses();
        break;
      case "delete":
        this.$root.$on('form:confirm', this.deleteInvite);
        break;
    }
  },
  computed: {
    availableClasses() {
      // console.log(this.entity_buff.classes)
      return this.availableClassesList
          .map(classt => {
            // Check if the current class is in the selected classes
            const isInSelectedClasses = this.userClasses.some(selectedClass => {
            //   // Check if selectedClass has an id
            //
              return selectedClass.id === classt.id;
            });

            return {
              name: classt.name,
              id: classt.id,
              owners: classt.owners,
              isHasOwners: classt.isHasOwners,
              isInList: isInSelectedClasses, // Use a boolean directly
            };
          })
          // Filter classes based on the search query
          .filter(classt =>
              classt.name.toLowerCase().includes(this.searchQuery.toLowerCase())
          );
    }
  },
  methods: {
    async getClasses() {
      this.raw_data = await this.$root.$makeApiRequest('/api/org/classes');
      this.availableClassesList = this.raw_data.map(classt => ({
        name: classt.name,
        id: classt.id,
        owners: classt.owners,
        isHasOwners: classt.owners && classt.owners.length > 0, // Mark as disabled if classes exist
      }))
          // Sort the availableOwners: those without classes come first
          .sort((a, b) => {
            // Sort by 'disabled': false (no classes) should come before true (has classes)
            return (a.isHasOwners === b.isHasOwners) ? 0 : a.isHasOwners ? 1 : -1;
          });
      console.log(this.availableClassesList);
    },
    removeTag(index) {
      this.userClasses.splice(index, 1);
    },
    // Region Send data
    async handleCreateInvite() {
      this.userRoles = [];
      if (this.isTeacher)
        this.userRoles.push('teacher');
      if (this.isAdmin)
        this.userRoles.push('admin');

      if (this.userName === "") {
        this.$root.$emit('notification', 'warning', 'Пожалуйста, введите имя пользователя');
        return;
      }
      if (!this.isForceCreate) {
        if (this.userRoles.length === 0) {
          this.$root.$emit('notification', 'warning', 'Пользователь без ролей не сможет взаимодействовать с данными ');
          return;
        }
        if (this.userClasses.length === 0 && this.userRoles.length !== 0) {
          this.$root.$emit('notification', 'warning', 'Пользователь не сможет заполнять данные, если вы не выделите ему класс');
          return;
        }
      }
        let classes_buff = [];
        this.userClasses.map(classt => {
          classes_buff.push(classt.id);
        });

      const status = await this.$root.$makeApiRequest(
          '/api/org/invites',
      'POST',
          {
            name: this.userName,
            classes: classes_buff,
            roles: this.userRoles
          });
      if (status === 204)
        this.$root.$emit('notification', 'success');
      else
        this.$root.$emit('notification', 'error');

    },
    async deleteInvite() {
      const status = await this.$root.$makeApiRequest(
          '/api/org/invites/' + this.entity.id,
          'DELETE');
      if (status === 204)
        this.$root.$emit('notification', 'success');
      else
        this.$root.$emit('notification', 'error');
    },
  },
};
</script>

<style scoped>
</style>