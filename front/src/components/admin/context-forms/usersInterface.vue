<template>
  <div>
    <div v-if="action === 'create'">
      <createUser/>
    </div>

    <div v-if="action === 'edit'">
      <editUser :entity="entity_buff"/>
    </div>

    <div v-if="action === 'reset'">
      <b-form>
        <b-form-group title="Новый пароль">
          <b-form-input v-model="newUserPassword" placeholder="Введите новый пароль пользователя"/>
        </b-form-group>
      </b-form>
    </div>

    <div v-if="action === 'delete'">
      <p>
        При продолжении, пользователь <b>{{ this.entity_buff.name }}</b> будет <b>безвозвратно</b> удалён. <br>
        <ul>
          <li>Классы:
            {{ this.entity_buff.classes ? this.entity_buff.classes.map(classt => classt.name || '').join(', ') : '-' }}</li>
          <li>Роли: {{ this.entity_buff.roles ? this.entity_buff.roles.map(role => role).join(', ') : '-' }}</li>
        </ul>
      </p>
    </div>
  </div>
</template>

<script>
import createUser from "@/components/admin/context-forms/users/createUser.vue";
import editUser from "@/components/admin/context-forms/users/editUser.vue";

export default {
  name: 'usersInterface',
  components: {
    createUser,
    editUser
  },
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

      newUserPassword: '',
    };
  },
  beforeMount() {
    this.$root.$off('form:confirm');
  },
  mounted() {
    switch (this.action) {
      case "create":
        this.$root.$on('form:confirm', this.handleCreateUser);
        break;
      case "edit":
        this.$root.$on('form:confirm',
            this.handleEditUser);
        break;
      case "reset":
        this.$root.$on('form:confirm', this.resetPassword);
        break;
      case "delete":
        this.$root.$on('form:confirm', this.deleteUser);
        break;
    }
  },
  computed: {

  },
  methods: {
    // Region Send data
    handleEditUser() {
      this.$root.$emit('interface:editUser')
    },

    async resetPassword() {
      if (this.newUserPassword === "")
        this.$root.$emit('notification', 'warning', 'Пароль не может быть пустым');
      const status = await this.$root.$makeApiRequest(
          '/api/org/users/' + this.entity_buff.id + '/password',
          'PATCH',
          {password: this.newUserPassword}
      );
      this.$root.$callNotificationEvent(status === 204);
    },
    async deleteUser() {
      const status = await this.$root.$makeApiRequest(
          '/api/org/users/' + this.entity.id,
      'DELETE');
      this.$root.$callNotificationEvent(status === 204);
    },
    addClass() {
      const newClass = { id: this.newClassId, name: this.newClassName };
      this.entity_buff.classes.push(newClass);
      this.newClassId = '';
      this.newClassName = '';
    },
    removeClass(index) {
      this.entity_buff.classes.splice(index, 1);
    },
    addRole() {
      if (this.newRole) {
        this.entity_buff.roles.push(this.newRole);
        this.newRole = '';
      }
    },
    removeRole(index) {
      this.entity_buff.roles.splice(index, 1);
    },
    handleCreateUser() {
      this.$root.$emit('interface:createUser');
    }
  },
};
</script>

<style scoped>
</style>