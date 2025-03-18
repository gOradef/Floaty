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

      //? classes: [...this.entity.classes], in entity_buff.classes
      roles: [],
      isTeacher: false,
      isAdmin: false,
    };
  },
  beforeMount() {
    this.$root.$off('interface:editUser')
  },
  mounted() {
    this.isTeacher = this.entity_buff.roles.includes('teacher');
    this.isAdmin = this.entity_buff.roles.includes('admin');
    // console.log(this.entity);
    this.getClasses();
    this.$root.$on('interface:editUser', () => {
      this.handleEditConfirm();
    });
  },
  computed: {
    availableClasses() {
      // console.log(this.entity_buff.classes)
      return (
        this.availableClassesList.map(classt => {
            // Check if the current class is in the selected classes
            const isInSelectedClasses = this.entity_buff.classes.some(
              (selectedClass) => {
                // Check if selectedClass has an id

                return selectedClass.id === classt.id;
              }
            );

            return {
              name: classt.name,
              id: classt.id,
              owners: classt.owners,
              isHasOwners: classt.isHasOwners,
              isInList: isInSelectedClasses, // Use a boolean directly
            }
        })
          // Filter classes based on the search query
          .filter(classt =>
              classt.name.toLowerCase().includes(this.searchQuery.toLowerCase())
        )
      )
    }
  },
  methods: {
    async handleEditConfirm() {
      let url;
      let bodyRequest = {};

      // Declare variables outside the switch
      let isNameInvalid;
      let classes_ids;

      switch (this.currentTabIndex) {
        case 0:
          url = "/api/org/users/" + this.entity.id + "/name";

          isNameInvalid =
              !this.newUserName ||
              this.newUserName.trim() === "" ||
              this.entity.name === this.newUserName;
          if (isNameInvalid) {
            this.$root.$callNotificationEvent(
                false,
                "Пожалуйста, введите новое имя пользователя"
            );
            return;
          }
          bodyRequest.name = this.newUserName;
          break;
        case 1:
          url = "/api/org/users/" + this.entity.id + "/classes";

          // Process classes ids
          classes_ids = [];
          this.entity_buff.classes.map((classt) => {
            classes_ids.push(classt.id);
          });

          bodyRequest.classes = classes_ids;
          break;
        case 2:
          url = "/api/org/users/" + this.entity.id + "/roles";

          if (this.isTeacher) this.roles.push("teacher");
          if (this.isAdmin) this.roles.push("admin");

          bodyRequest.roles = this.roles;
          break;
      }

      const status = await this.$root.$makeApiRequest(
          url,
          "PATCH",
          bodyRequest
      );
      this.$root.$callNotificationEvent(status === 204);
    },
    async getClasses() {
      this.raw_data = await this.$root.$makeApiRequest("/api/org/classes");
      this.availableClassesList = this.raw_data
        .map((classt) => ({
          name: classt.name,
          id: classt.id,
          owners: classt.owners,
          isHasOwners: classt.owners && classt.owners.length > 0, // Mark as disabled if classes exist
        }))
        // Sort the availableOwners: those without classes come first
        .sort((a, b) => {
          // Sort by 'disabled': false (no classes) should come before true (has classes)
          return a.isHasOwners === b.isHasOwners ? 0 : a.isHasOwners ? 1 : -1;
        });
      // console.log(this.availableClassesList);
    },
    removeTag(index) {
      this.entity_buff.classes.splice(index, 1);
    },
  },
};
</script>

<template>
  <b-tabs v-model="currentTabIndex" nav-class="mb-4">

    <!--    Region Rename -->
    <b-tab title="Переименовать">
      <div>
        <b-input
          v-model="newUserName"
          placeholder="Введите новое имя пользователя"
        ></b-input>
        <b-card-text class="text-center mt-2">
          {{ entity_buff.name }} <b-icon icon="arrow-right"></b-icon>
          {{ newUserName }}</b-card-text>
      </div>
    </b-tab>
    <!-- Region Classes -->
    <b-tab title="Классы">
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
            @click="entity_buff.classes.push(classt)"
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
          v-for="(classt, index) in entity_buff.classes"
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
    </b-tab>
    <!--Region Roles-->
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

<style scoped></style>