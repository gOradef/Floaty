<script>
export default {
  name: "createUser",
  props: {
    entity: {
      type: {},
      required: false,
    },
  },
  data() {
    return {
      form: {
        login: '',
        password: '',
        name: '',
        roles: [],
        classes: [],
      },

      isTeacher: false,
      isAdmin: false,

      raw_data: '',
      availableClassesList: [],
      searchQuery: '',

    };
  },
  beforeMount() {
    this.$root.$off('interface:createUser');
  },
  mounted() {
    this.getClasses();
    this.$root.$on('interface:createUser', async () => {

          if (this.form.login === '' ||
              this.form.password === '' ||
              this.form.name === '')
          {
            this.$root.$emit('notification', 'warning', 'Поля логин, пароль и имя должны быть заполнены');
            return
          }

        if (this.isTeacher)
          this.form.roles.push('teacher');
        if (this.isAdmin)
          this.form.roles.push('admin');

        // console.log(this.form)

        let classes_ids = [];
        this.form.classes.map(classt => {
          classes_ids.push(classt.id);
        })
      this.form.classes = classes_ids;

        const status = await this.$root.$makeApiRequest(
            '/api/org/users',
            'POST',
            {...this.form,
            classes: classes_ids});
        if (status === 204)
          this.$root.$emit('notification', 'success');
        else if (status === 409)
          this.$root.$emit('notification', 'warning', 'Данный логин и пароль уже заняты');
        else
          this.$root.$emit('notification', 'error');
    });
  },
  computed: {
    availableClasses() {
      // console.log(this.form.classes)
      return this.availableClassesList
          .map(classt => {
            // Check if the current class is in the selected classes
            const isInSelectedClasses = this.form.classes.some(selectedClass => {
              // Check if selectedClass has an id

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
      // console.log(this.availableClassesList);
    },
    removeTag(index) {
      this.form.classes.splice(index, 1);
    },
  }
};
</script>

<template>
  <b-form @submit.prevent="">
    <b-form-group label="Имя пользователя">
      <b-form-input
        required
        v-model="form.name"
        placeholder="Введите имя пользователя"
      ></b-form-input>
    </b-form-group>
    <b-form-group label="Данные пользователя">
      <b-form-input
        required
        v-model="form.login"
        placeholder="Введите логин пользователя"
      ></b-form-input>
      <b-form-input
        class="mt-2"
        required
        v-model="form.password"
        placeholder="Введите пароль пользователя"
      ></b-form-input>
    </b-form-group>
    <b-form-group label="Роли пользователя">
      <b-form-checkbox v-model="isTeacher"
        >Классный руководитель</b-form-checkbox
      >
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
          @click="form.classes.push(classt)"
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
        v-for="(classt, index) in form.classes"
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
  </b-form>
</template>

<style scoped></style>