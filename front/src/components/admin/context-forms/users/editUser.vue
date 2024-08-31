<script>
export default {
  name: "editUser",
  props: {
    entity: {
      type: Object,
      required: true
    }
  },
  data() {
    return {
      entity_buff: {...this.entity}, //classesList, newName, roles
      currentTabIndex: 0,
      newUserName: '',


      raw_data: '',
      availableClassesList: [],
      searchQuery: '',

      isTeacher: false,
      isAdmin: false,
    };
  },
  beforeMount() {
    this.$root.$off('interface:editUser')
  },
  mounted() {
    this.$root.$on('interface:editUser', () => {
      this.handleEditConfirm();
    });
  },
  computed: {
    availableClasses() {
      console.log(this.form.classes)
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
    async handleEditConfirm() {
      switch (this.currentTabIndex) {
        case 0: // Переименовать
          await this.renameUser();
          break;
        case 1: // Классы
          await this.editClasses();
          break;
        case 2: // Роли
          await this.editRoles();
          break;
      }
    },
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
      this.form.classes.splice(index, 1);
    },



    // Region Internal foo's
    // async renameUser() {
    //
    // },
    async editClasses() {

    },
    async editRoles() {
      // Логика редактирования ролей
    },

  }
};
</script>

<template>
  <b-tabs v-model="currentTabIndex" nav-class="mb-4">
    <b-tab title="Переименовать">
      <b-form>
        <b-input v-model="newUserName" placeholder="Введите новое имя пользователя"></b-input>
        <b-card-text class="text-center mt-2"> {{ entity_buff.name }} -> {{ newUserName }}</b-card-text>
      </b-form>
    </b-tab>

    <b-tab title="Классы">

    </b-tab>

    <b-tab title="Роли">
      <b-form-group label="Роли пользователя">
        <b-form-checkbox v-model="isTeacher"
        >Классный руководитель</b-form-checkbox
        >
        <b-form-checkbox v-model="isAdmin">Завуч</b-form-checkbox>
      </b-form-group>
    </b-tab>
  </b-tabs>
</template>

<style scoped>

</style>